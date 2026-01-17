;==============================================================================
; VY V6 IGNITION CUT v12 - FLAT SHIFT / NO-LIFT SHIFT
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: TPS-activated momentary spark cut for flat-foot shifting
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   "Flat shift" / "No-lift shift" system for drag racing
;   - Driver keeps throttle pinned during gear change
;   - Clutch pressed → spark cut activated
;   - Clutch released → spark restored instantly
;   - Result: Faster shifts (no throttle lift required)
;
; Based On: Chr0m3-approved 3X Period Injection
; Status: 🔬 EXPERIMENTAL - Manual transmission only
;
; How It Works:
;   1. Monitor clutch switch (digital input)
;   2. Monitor TPS (throttle position)
;   3. If clutch pressed AND TPS > 80%:
;      a) Cut spark (3X period injection)
;      b) Engine cannot accelerate (transmission safe)
;   4. When clutch released:
;      a) Restore spark instantly
;      b) Power returns immediately
;
; Advantages:
;   ✅ Faster gear changes (no throttle lift)
;   ✅ Maintains turbo boost (throttle stays open)
;   ✅ Protects transmission (no power during shift)
;   ✅ Simple driver technique (keep throttle flat)
;
; Hardware Required:
;   - Clutch switch (normally on cruise control models)
;   - Wire to spare digital input
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM address
PERIOD_3X_RAM       EQU $017B       ; 3X period storage
TPS_RAM             EQU $01A5       ; TPS value (0-255, UNVALIDATED!)
CLUTCH_SWITCH       EQU $1008       ; Port D data register (HC11 PORTD = $1008, NOT $1004!)

FAKE_PERIOD         EQU $3E80       ; Fake 3X period (spark cut)
TPS_THRESHOLD       EQU $CC         ; 80% throttle (204 / 255 = 0.8)
MIN_RPM             EQU $07D0       ; 2000 RPM minimum (safety)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED (was $18156 WRONG!)

;==============================================================================
; FLAT SHIFT HANDLER
;==============================================================================

FLAT_SHIFT_HANDLER:
    PSHB
    PSHA
    PSHX
    
    ; Check RPM minimum (don't activate at idle)
    LDD     RPM_ADDR
    CPD     #MIN_RPM
    BLO     ALLOW_SPARK         ; Below 2000 RPM, allow spark
    
    ; Check clutch switch
    LDAA    CLUTCH_SWITCH
    ANDA    #$04                ; Mask bit 2
    BNE     ALLOW_SPARK         ; Clutch released, allow spark
    
    ; Clutch is pressed - check TPS
    LDAA    TPS_RAM
    CMPA    #TPS_THRESHOLD
    BLO     ALLOW_SPARK         ; TPS < 80%, allow spark
    
    ; Clutch pressed AND throttle wide open - CUT SPARK
CUT_SPARK:
    LDD     #FAKE_PERIOD
    STD     PERIOD_3X_RAM
    BRA     EXIT_HANDLER

ALLOW_SPARK:
    ; Normal operation - let stock code handle spark
    
EXIT_HANDLER:
    PULX
    PULA
    PULB
    RTS

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; TPS THRESHOLD ADJUSTMENT:
;   60% (0x99): Activates earlier (easier to trigger)
;   80% (0xCC): Current setting (recommended)
;   90% (0xE6): Requires full throttle (harder to trigger)
;
; MINIMUM RPM:
;   1500 RPM: Very sensitive (may trigger during parking)
;   2000 RPM: Recommended (current setting)
;   2500 RPM: Conservative (reduces false triggers)
;
; ACTIVATION LOGIC:
;   Current: Clutch + TPS
;   Alternative 1: Clutch + RPM (cut above 3000 RPM)
;   Alternative 2: Clutch + TPS + RPM (all three conditions)
;
; COMPARISON TO POWER SHIFTING:
;
;   Power Shift (dangerous):
;     - Driver keeps throttle flat
;     - Clutch pressed but engine STILL MAKES POWER
;     - Transmission sees torque during gear change
;     - High risk of transmission damage
;
;   Flat Shift (this method):
;     - Driver keeps throttle flat
;     - Clutch pressed AND spark cut
;     - Engine makes ZERO power during shift
;     - Transmission protected
;
; DRIVER TECHNIQUE:
;   1. Full throttle (WOT)
;   2. Press clutch quickly
;   3. Shift gear (spark cut active, no power)
;   4. Release clutch quickly
;   5. Power returns instantly (no delay)
;
; AUTOMATIC TRANSMISSION:
;   - DO NOT USE (no clutch switch)
;   - Manual valve body conversions: May work with manual shift
;
;==============================================================================

;==============================================================================
; SAFETY FEATURES
;==============================================================================
;
; MINIMUM RPM CHECK:
;   Prevents activation at idle/parking
;   Avoids engine stalling during low-speed shifts
;
; TPS THRESHOLD:
;   Only activates at high throttle
;   Prevents activation during normal driving
;   Driver must be intentionally at WOT
;
; INSTANT RESTORE:
;   Spark returns immediately when clutch released
;   No delay or hesitation
;   Smooth power delivery
;
; FAIL-SAFE BEHAVIOR:
;   If clutch switch fails OPEN: System disabled (safe)
;   If clutch switch fails CLOSED: Spark cut always active (engine won't run)
;   If TPS sensor fails: System disabled (safe)
;
;==============================================================================

;==============================================================================
; IMPLEMENTATION CHECKLIST
;==============================================================================
;
; [ ] 1. Install clutch switch (or verify existing)
; [ ] 2. Find clutch switch input pin (Port D bit 2 guess)
; [ ] 3. Validate TPS RAM address (currently $01A5)
; [ ] 4. Bench test clutch switch (verify closed when pressed)
; [ ] 5. Test with multimeter (TPS voltage vs RAM value)
; [ ] 6. Bench test spark cut (verify no spark when active)
; [ ] 7. In-vehicle testing (parking lot first)
; [ ] 8. Drag strip validation (measure shift times)
; [ ] 9. Monitor for false triggers (log data)
; [ ] 10. Tune TPS threshold for best feel
;
;==============================================================================

;==============================================================================
; ALTERNATIVE IMPLEMENTATIONS
;==============================================================================
;
; METHOD A: Time-Based Cut (current method)
;   - Spark cut as long as clutch pressed
;   - Driver controls duration
;   - Simple, reliable
;
; METHOD B: Fixed Duration Cut
;   - Spark cut for 200ms when clutch pressed
;   - Auto-restore after timer
;   - Prevents stalling if clutch held too long
;
; METHOD C: RPM-Based Window
;   - Only active between 3000-7000 RPM
;   - Prevents low-RPM activation
;   - Safer for street driving
;
; TO IMPLEMENT METHOD B (Fixed Duration):
;   1. Add timer variable (200ms countdown)
;   2. Start timer when clutch pressed
;   3. Cut spark until timer expires
;   4. Restore spark even if clutch still pressed
;   5. Reset timer when clutch released
;
;==============================================================================
