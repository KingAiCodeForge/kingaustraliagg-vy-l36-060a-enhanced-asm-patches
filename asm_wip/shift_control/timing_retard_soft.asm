;==============================================================================
; VY V6 IGNITION CUT v15 - SOFT CUT (TIMING RETARD LIMITER)
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Inspiration: Cadillac LS community standard practice
; Target: Holden VY V6 (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   Implements "soft cut" rev limiter using progressive timing retard before
;   hard spark cut. This is the method used on high-end GM platforms and
;   preferred by professional tuners for smoother power transition.
;
; Community Quote (Cadillac LS):
;   > "I have my soft cut zeroed out. Rev limit runs at 7K and sounds sick."
;   > "Yeah, you probably wouldn't notice the soft cut if you had it set to
;   > 50 RPM below the limiter"
;
; Soft Cut vs Hard Cut:
;   - Soft cut = Timing retard (spark still fires, but delayed)
;   - Hard cut = Complete spark removal (no combustion)
;   - Professional approach: Soft cut zone → Hard cut
;
; Status: 🔬 EXPERIMENTAL - Requires spark advance table address
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM address
PERIOD_3X_RAM       EQU $017B       ; 3X period storage
SPARK_ADVANCE       EQU $019B       ; Spark advance (degrees BTDC) - UNCONFIRMED

; FLAGS
SOFT_CUT_FLAG       EQU $0FFF       ; Free RAM for soft cut active flag
HARD_CUT_FLAG       EQU $0FFE       ; Free RAM for hard cut active flag

;------------------------------------------------------------------------------
; RPM THRESHOLDS (SAFE DEFAULT - 6000 RPM)
;------------------------------------------------------------------------------
RPM_ZONE1           EQU $1720       ; 5920 RPM (normal operation)
RPM_ZONE2           EQU $175C       ; 5980 RPM (soft cut starts - mild retard)
RPM_ZONE3           EQU $1770       ; 6000 RPM (soft cut medium - aggressive retard)
RPM_ZONE4           EQU $1784       ; 6020 RPM (hard spark cut activation)
RPM_HYSTERESIS      EQU $170C       ; 5900 RPM (deactivation - all normal)

;------------------------------------------------------------------------------
; TIMING RETARD VALUES (Degrees BTDC)
;------------------------------------------------------------------------------
; Normal: 20-30° BTDC (depends on RPM/load)
; Soft cut reduces power by retarding timing progressively

RETARD_ZONE2        EQU 5           ; 5° retard (5980-6000 RPM) - subtle
RETARD_ZONE3        EQU 15          ; 15° retard (6000-6020 RPM) - aggressive
RETARD_ZONE4        EQU 0           ; No timing (hard cut at 6020 RPM)

;==============================================================================
; SOFT CUT LIMITER METHOD
;==============================================================================

            ;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $0C468          ; Free space VERIFIED (was $18156 WRONG!)

SOFT_CUT_HANDLER:
    PSHA
    PSHB
    
    ; Load current RPM
    LDD     RPM_ADDR
    
    ; Check which zone we're in
    CPD     #RPM_ZONE4
    BHS     ZONE_HARD_CUT       ; RPM >= 6020, hard spark cut
    
    CPD     #RPM_ZONE3
    BHS     ZONE_AGGRESSIVE     ; RPM >= 6000, aggressive retard
    
    CPD     #RPM_ZONE2
    BHS     ZONE_MILD           ; RPM >= 5980, mild retard
    
    CPD     #RPM_HYSTERESIS
    BHS     ZONE_NORMAL         ; RPM >= 5900, normal operation
    
    ; Below hysteresis - restore everything
    BRA     RESTORE_NORMAL

;------------------------------------------------------------------------------
; ZONE 1: Normal Operation (< 5980 RPM)
;------------------------------------------------------------------------------
ZONE_NORMAL:
    CLR     SOFT_CUT_FLAG       ; Clear soft cut flag
    CLR     HARD_CUT_FLAG       ; Clear hard cut flag
    ; No timing modification
    BRA     EXIT_HANDLER

;------------------------------------------------------------------------------
; ZONE 2: Mild Soft Cut (5980-6000 RPM) - 5° Retard
;------------------------------------------------------------------------------
ZONE_MILD:
    LDAA    #1
    STAA    SOFT_CUT_FLAG       ; Set soft cut flag
    CLR     HARD_CUT_FLAG       ; Clear hard cut flag
    
    ; Apply mild timing retard
    LDAA    SPARK_ADVANCE       ; Load current spark advance
    SUBA    #RETARD_ZONE2       ; Subtract 5° retard
    STAA    SPARK_ADVANCE       ; Store modified advance
    
    BRA     EXIT_HANDLER

;------------------------------------------------------------------------------
; ZONE 3: Aggressive Soft Cut (6000-6020 RPM) - 15° Retard
;------------------------------------------------------------------------------
ZONE_AGGRESSIVE:
    LDAA    #2
    STAA    SOFT_CUT_FLAG       ; Set soft cut flag (level 2)
    CLR     HARD_CUT_FLAG       ; Clear hard cut flag
    
    ; Apply aggressive timing retard
    LDAA    SPARK_ADVANCE       ; Load current spark advance
    SUBA    #RETARD_ZONE3       ; Subtract 15° retard
    BPL     STORE_RETARD        ; If result positive, store it
    CLRA                        ; If negative, clamp to 0°
STORE_RETARD:
    STAA    SPARK_ADVANCE       ; Store modified advance
    
    BRA     EXIT_HANDLER

;------------------------------------------------------------------------------
; ZONE 4: Hard Spark Cut (>= 6020 RPM)
;------------------------------------------------------------------------------
ZONE_HARD_CUT:
    LDAA    #1
    STAA    HARD_CUT_FLAG       ; Set hard cut flag
    
    ; Use Chr0m3's proven 3X period injection method
    LDD     #$FFFF              ; Maximum period value (fake slow RPM)
    STD     PERIOD_3X_RAM       ; Store fake 3X period
    
    ; Result: Dwell calculation produces insufficient coil charge → no spark
    
    BRA     EXIT_HANDLER

;------------------------------------------------------------------------------
; RESTORE NORMAL (< 5900 RPM Hysteresis)
;------------------------------------------------------------------------------
RESTORE_NORMAL:
    CLR     SOFT_CUT_FLAG       ; Clear soft cut flag
    CLR     HARD_CUT_FLAG       ; Clear hard cut flag
    ; Spark advance restored by normal firmware calculations
    ; Fall through to exit

EXIT_HANDLER:
    PULB
    PULA
    RTS

;==============================================================================
; ALTERNATIVE: PROGRESSIVE RETARD CALCULATION
;==============================================================================
;
; For smoother transition, calculate retard proportionally to RPM:
;
; PROGRESSIVE_RETARD:
;     ; Calculate: Retard = (RPM - 5980) / 10
;     ; At 5980 RPM: 0° retard
;     ; At 5990 RPM: 1° retard
;     ; At 6000 RPM: 2° retard
;     ; At 6010 RPM: 3° retard
;     ; At 6020 RPM: 4° retard + hard cut
;     
;     LDD     RPM_ADDR
;     SUBD    #RPM_ZONE2          ; RPM - 5980
;     LSRD                        ; Divide by 2
;     LSRD                        ; Divide by 4
;     LSRD                        ; Divide by 8 (≈ divide by 10)
;     
;     ; D now contains retard degrees
;     TBA                         ; Transfer to A
;     LDAB    SPARK_ADVANCE       ; Load current advance
;     SBA                         ; B = B - A (subtract retard)
;     BPL     STORE_PROGRESSIVE
;     CLRB                        ; Clamp to 0
; STORE_PROGRESSIVE:
;     STAB    SPARK_ADVANCE
;     RTS
;
;==============================================================================

;==============================================================================
; ADVANTAGES vs HARD CUT ONLY
;==============================================================================
;
; Soft Cut + Hard Cut (This Method):
;   ✅ Smoother power transition (less violent)
;   ✅ Professional "ignition wall" feel
;   ✅ Less drivetrain shock (transmission/diff friendly)
;   ✅ Easier to "ride the limiter" (drift/burnout control)
;   ✅ Sounds better (progressive burble → bang)
;   ⚠️ More complex (two stages to tune)
;
; Hard Cut Only (Method v1-v3):
;   ✅ Simple (binary on/off)
;   ✅ Maximum safety (complete spark removal)
;   ✅ Proven working (Chr0m3 validated)
;   ⚠️ Harsh transition (sudden power cut)
;   ⚠️ Drivetrain shock (hard on trans/diff)
;
; Best Use Cases:
;   - Soft cut: Dyno testing, drift events, street driving
;   - Hard cut: Drag racing, competition, maximum safety
;   - Combined: Best of both worlds (professional setup)
;
;==============================================================================

;==============================================================================
; COMMUNITY INSIGHTS
;==============================================================================
;
; From Cadillac LS Tuning Discussion:
;
; User 1:
;   > "right, raised limiter to 7000 and enabled spark cut. still works fine..."
;
; User 2:
;   > "I have my soft cut zeroed out. Rev limit runs at 7K and sounds sick."
;
; User 3:
;   > "Yeah, you probably wouldn't notice the soft cut if you had it set to
;   > 50 RPM below the limiter"
;
; Key Takeaway:
;   - Soft cut zone should be narrow (20-50 RPM)
;   - Too wide = noticeable power loss
;   - Too narrow = feels like hard cut anyway
;   - This implementation: 40 RPM soft cut zone (5980-6020)
;
;==============================================================================

;==============================================================================
; TERMINOLOGY CLARIFICATION
;==============================================================================
;
; Chr0m3's Important Distinction:
;   > "Somewhere an ECU / Calibration engineer cries every time ignition
;   > timing retard near the rev limiter gets called a spark cut limiter.
;   > I don't know who needs to hear this, but one still fires the spark…
;   > and one doesn't."
;
; Correct Terminology:
;   - Soft cut = Timing retard (spark fires, just delayed)
;   - Ignition wall = Timing retard zone before limiter
;   - Spark cut = Complete spark removal (no ignition event)
;   - Hard cut = Complete removal (fuel or spark)
;
; This Method Combines:
;   1. Soft cut (5980-6020 RPM) - timing retard
;   2. Hard cut (>6020 RPM) - spark removal
;
;==============================================================================

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; Critical: Spark advance address MUST be confirmed
;   - Listed as $019B (UNCONFIRMED)
;   - Need to find in binary disassembly
;   - Or use TunerPro logging to observe address
;
; Bench Test Procedure:
;   1. Log spark advance while revving engine
;   2. Identify RAM address that changes with advance
;   3. Update SPARK_ADVANCE EQU to correct address
;   4. Flash this patch
;   5. Test soft cut zone (5980-6000 RPM)
;   6. Verify timing retards progressively
;   7. Test hard cut zone (>6020 RPM)
;   8. Verify complete spark removal
;
; Success Criteria:
;   - 5980 RPM: Timing retards 5° (engine slows slightly)
;   - 6000 RPM: Timing retards 15° (engine power drops)
;   - 6020 RPM: Complete spark cut (hard limit)
;   - 5900 RPM: Normal timing restored
;   - No DTC codes, smooth transitions
;
;==============================================================================

;==============================================================================
; TUNING RECOMMENDATIONS
;==============================================================================
;
; Conservative Setup (Street/Dyno):
;   RPM_ZONE2 = 5950 RPM (30 RPM before limit)
;   RPM_ZONE3 = 5975 RPM (25 RPM before limit)
;   RPM_ZONE4 = 6000 RPM (hard limit)
;   RETARD_ZONE2 = 3° (subtle)
;   RETARD_ZONE3 = 8° (moderate)
;
; Aggressive Setup (Drift/Burnout):
;   RPM_ZONE2 = 5980 RPM (20 RPM before limit)
;   RPM_ZONE3 = 5995 RPM (5 RPM before limit)
;   RPM_ZONE4 = 6000 RPM (hard limit)
;   RETARD_ZONE2 = 5° (noticeable)
;   RETARD_ZONE3 = 15° (aggressive)
;
; Competition Setup (Drag Racing):
;   Skip soft cut entirely, use hard cut only
;   See Method v3 (3X Period with Hysteresis)
;
;==============================================================================

;==============================================================================
; COMBINATION WITH OTHER METHODS
;==============================================================================
;
; This method can be combined with:
;
; 1. Launch Control (Method v7):
;    - Soft cut at main limiter (6000 RPM)
;    - Hard cut at launch limiter (3500 RPM)
;
; 2. Flat Shift (Method v12):
;    - Soft cut during normal driving
;    - No-lift shift uses hard cut temporarily
;
; 3. Progressive Limiter (Method v9):
;    - Already implements progressive approach
;    - This method adds timing retard dimension
;
;==============================================================================
