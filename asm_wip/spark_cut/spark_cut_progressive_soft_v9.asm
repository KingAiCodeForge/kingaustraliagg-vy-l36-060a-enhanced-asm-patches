;==============================================================================
; VY V6 IGNITION CUT v9 - PROGRESSIVE SOFT LIMITER
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: Gradual power reduction instead of hard cut
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   Progressive "soft" limiter that gradually reduces power instead of
;   harsh on/off cut. Creates smoother limiter feel, less drivetrain shock.
;   Uses proportional spark cut based on RPM above threshold.
;  need to have expert knowledge of ose 11p 12p or hc11 to implement.
; vy v6 is different to them but hc11 code is hc11 code only thing stopping is hardcoded unknown limits.
; Based On: Chr0m3-approved 3X Period Injection (Method A)
; Status: 🔬 EXPERIMENTAL - Variation of proven method
;
; How It Works:
;   1. 6200-6250 RPM: 100% power (no cut)
;   2. 6250-6275 RPM: 75% power (25% spark cut - cut 1 in 4 cylinders)
;   3. 6275-6300 RPM: 50% power (50% spark cut - cut 1 in 2 cylinders)  
;   4. 6300+ RPM: 25% power (75% spark cut - cut 3 in 4 cylinders)
;
; Implementation:
;   - Cycle counter: tracks ignition events (0-3)
;   - RPM zone determines cut ratio
;   - Higher RPM = more frequent cuts
;   - Creates "soft wall" instead of "brick wall"
;
; Advantages:
;   ✅ Smooth power reduction (no harsh bounce)
;   ✅ Less drivetrain shock (transmission friendly)
;   ✅ Better for dyno testing (controlled power limit)
;   ✅ Easier to hold at limiter (drift/burnout)
;
; Disadvantages:
;   ⚠️  More complex than hard cut
;   ⚠️  Still produces some power at limiter (not true limit)
;   ⚠️  Not tested by Chr0m3 yet
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM address
PERIOD_3X_RAM       EQU $017B       ; 3X period storage
CYCLE_COUNTER       EQU $01A0       ; Ignition event counter (0-3)

; PROGRESSIVE THRESHOLDS (SAFE DEFAULT - 6000 RPM ZONE)
RPM_ZONE1           EQU $1748       ; 5960 RPM (no cut)
RPM_ZONE2           EQU $175C       ; 5980 RPM (25% cut starts)
RPM_ZONE3           EQU $1770       ; 6000 RPM (50% cut starts)
RPM_ZONE4           EQU $1784       ; 6020 RPM (75% cut starts)

FAKE_PERIOD         EQU $3E80       ; Fake 3X period (spark cut)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $0C468          ; Free space VERIFIED (was $18156 WRONG!)

;==============================================================================
; PROGRESSIVE SOFT LIMITER HANDLER
;==============================================================================

SOFT_LIMITER_HANDLER:
    PSHB
    PSHA
    PSHX
    
    ; Increment cycle counter (0-3 wrap-around)
    LDAA    CYCLE_COUNTER
    INCA
    ANDA    #$03                ; Mask to 0-3
    STAA    CYCLE_COUNTER
    
    ; Check RPM zone
    LDD     RPM_ADDR
    
    ; Zone 1: < 6250 RPM → No cut
    CPD     #RPM_ZONE2
    BLO     NO_CUT
    
    ; Zone 2: 6250-6270 RPM → 25% cut (cut every 4th event)
    CPD     #RPM_ZONE3
    BLO     CUT_25_PERCENT
    
    ; Zone 3: 6270-6290 RPM → 50% cut (cut every 2nd event)
    CPD     #RPM_ZONE4
    BLO     CUT_50_PERCENT
    
    ; Zone 4: 6290+ RPM → 75% cut (cut 3 out of 4 events)
    BRA     CUT_75_PERCENT

NO_CUT:
    ; Allow all spark events
    BRA     EXIT_HANDLER

CUT_25_PERCENT:
    ; Cut spark on cycle 0 only (1 out of 4)
    LDAA    CYCLE_COUNTER
    CMPA    #$00
    BEQ     INJECT_FAKE_PERIOD
    BRA     EXIT_HANDLER

CUT_50_PERCENT:
    ; Cut spark on cycles 0 and 2 (2 out of 4)
    LDAA    CYCLE_COUNTER
    ANDA    #$01                ; Check if even (0 or 2)
    BEQ     INJECT_FAKE_PERIOD
    BRA     EXIT_HANDLER

CUT_75_PERCENT:
    ; Cut spark on cycles 0, 1, 2 (3 out of 4)
    LDAA    CYCLE_COUNTER
    CMPA    #$03
    BEQ     EXIT_HANDLER        ; Only fire on cycle 3
    ; Fall through to inject fake period

INJECT_FAKE_PERIOD:
    LDD     #FAKE_PERIOD
    STD     PERIOD_3X_RAM       ; Inject fake period (cuts spark)

EXIT_HANDLER:
    PULX
    PULA
    PULB
    RTS

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; RPM ZONE ADJUSTMENT:
;   Narrow zones (20 RPM): Sharp soft limiter (quick transition)
;   Wide zones (100 RPM): Gentle soft limiter (smooth transition)
;
; CUT RATIOS:
;   25% cut: Still makes ~75% power (safe for dyno testing)
;   50% cut: Makes ~50% power (good for holding at limiter)
;   75% cut: Makes ~25% power (prevents RPM climb)
;
; CYCLE COUNTING:
;   VY V6 is wastespark (3 coils, 6 cylinders)
;   Each "ignition event" fires 2 cylinders
;   Cutting 1 in 4 events = cutting 2 in 8 cylinders = 25% cut
;
; COMPARISON TO HARD CUT:
;   Hard Cut (Method v3):
;     - 6299 RPM: 100% power
;     - 6300 RPM: 0% power (instant)
;     - Harsh bounce, transmission shock
;
;   Soft Cut (This Method):
;     - 6250 RPM: 100% power
;     - 6275 RPM: 50% power
;     - 6300 RPM: 25% power
;     - Smooth transition, easier to control
;
; WHEN TO USE:
;   - Dyno testing (controlled power limit)
;   - Burnouts (easier to hold at limiter)
;   - Drift events (smooth power control)
;   - Transmission protection (less shock)
;
; WHEN NOT TO USE:
;   - Drag racing (need instant hard cut)
;   - Competition (absolute limit preferred)
;   - If you want "brick wall" limiter feel
;
;==============================================================================

;==============================================================================
; ADVANCED TUNING: CUSTOM CUT PATTERNS
;==============================================================================
;
; Instead of linear 25-50-75% progression, you can customize:
;
; Pattern A: Aggressive (quick ramp)
;   6280 RPM: 100% power
;   6290 RPM: 50% power  
;   6300 RPM: 10% power
;
; Pattern B: Gentle (slow ramp)
;   6200 RPM: 100% power
;   6250 RPM: 75% power
;   6300 RPM: 50% power
;
; Pattern C: Two-stage (soft then hard)
;   6250-6290: Soft limiter (50% power)
;   6290+: Hard limiter (0% power)
;
; To implement custom patterns, modify RPM_ZONEx values
; and cut ratios in the comparison sections
;
;==============================================================================

;==============================================================================
; IGNITION EVENT TRACKING
;==============================================================================
;
; IMPORTANT: This code assumes it's called EVERY ignition event
;
; Hook point options:
;   1. Main 3X period write (@ 0x181E1) - called every ignition
;   2. Spark advance calculation routine - called every ignition
;   3. Timer ISR - may be called more/less frequently
;
; If hooked at wrong location, cycle counting will be incorrect
; and cut ratios won't match expected percentages
;
; VALIDATION:
;   - Use oscilloscope on EST pin
;   - Count spark events vs cut events
;   - Verify ratios match code (25%, 50%, 75%)
;   - Adjust CYCLE_COUNTER logic if needed
;
;==============================================================================
