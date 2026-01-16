;==============================================================================
; VY V6 IGNITION CUT LIMITER v4 - COIL SATURATION PREVENTION METHOD
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: November 26, 2025
; Method: Alternative - Prevent Coil Saturation (THEORETICAL - UNTESTED)
; Video Reference: "300 HP 3.8L N/A Ecotec Burnout Car Project: Week 5" (mxoHSRijWds)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: This method is THEORETICAL and NOT validated by Chr0m3
; ⚠️ Requires bench testing with oscilloscope before vehicle use
;
; Description:
;   Instead of preventing spark entirely, this method manipulates the coil
;   charge time to prevent proper saturation. By reducing dwell time to 
;   absolute minimum (200-300µs), coil doesn't build sufficient magnetic
;   field to produce a strong spark, effectively "weak spark" = no combustion.
;
; Theory:
;   Normal:  Dwell = 600µs → Full coil saturation → 30kV spark ✅
;   Cut:     Dwell = 200µs → Partial saturation → 5kV spark ❌ (too weak)
;
; Advantages:
;   ✅ No failsafe activation (EST still fires)
;   ✅ No DTC codes (coil still operates)
;   ✅ Gradual power reduction (soft limiter feel)
;   ✅ Coil safe from over-saturation
;
; Disadvantages:
;   ❌ NOT validated (theoretical approach)
;   ❌ May still produce some combustion (not 100% cut)
;   ❌ Requires precise dwell time calculation
;   ❌ Minimum dwell is hardware controlled, hard to override
;
; Technical Notes:
;   - Minimum dwell: 0xA2 (162 decimal) enforced by hardware
;   - Minimum burn: 0x24 (36 decimal) enforced by hardware
;   - "You can't just pull dwell to zero, PCM won't let you"
;   - At 6,500 RPM: Dwell drops naturally but spark still occurs
;
; Implementation Status: ⚠️ THEORETICAL - Related to REJECTED dwell method
;
; ⛔ WARNING: This method is similar to Method B (Dwell Override)
; Chr0m3 Quote: "Pulling dwell is a dead end just wasting your time"
;
; Why This May Not Work:
;   - Reducing dwell time is essentially "pulling dwell"
;   - TIO hardware enforces minimum dwell = 0xA2 (162) ~600µs
;   - Cannot force dwell below hardware minimum
;   - Even "weak spark" at 200µs likely impossible
;   - Chr0m3: "PCM won't let dwell = 0", implies can't go below min
;
; IF YOU STILL WANT TO TEST:
;   1. Get Chr0m3's approval first
;   2. Bench test only (oscilloscope required)
;   3. Expect it to fail based on dwell override findings
;   4. Use Method A (3X Period) instead - proven to work
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; RPM address (VERIFIED: 82R/2W in binary)
DWELL_RAM       EQU $0199       ; Dwell time storage (VERIFIED from code analysis)
DWELL_TARGET    EQU $019A       ; Target dwell calculation (suspected)
MIN_BURN_ROM    EQU $19813      ; Min burn constant ROM location (VERIFIED: LDAA #$24)
DWELL_THRESH    EQU $6776       ; "If Delta Cylair > This - Then Max Dwell" (XDF VERIFIED)

; TEST THRESHOLDS
RPM_HIGH        EQU $0BB8       ; 3000 RPM activation threshold (test)
RPM_LOW         EQU $0B54       ; 2900 RPM deactivation threshold (100 RPM hysteresis)

; PRODUCTION THRESHOLDS (uncomment after validation)
; === Chr0m3-Validated Options ===
; Option A: Conservative - Stock ECU Limit (RECOMMENDED for testing)
; RPM_HIGH        EQU $18E7       ; 6375 RPM activation (Chr0m3: factory limit)
; RPM_LOW         EQU $18D3       ; 6355 RPM deactivation (20 RPM hysteresis)

; Option B: Moderate - Chr0m3's Tested Maximum (requires dwell/burn patches!)
; RPM_HIGH        EQU $1C20       ; 7200 RPM activation (Chr0m3: tested on VY V6)
; RPM_LOW         EQU $1C0C       ; 7180 RPM deactivation (20 RPM hysteresis)
; WARNING: Requires minimum dwell (0xA2→0x9A) and burn (0x24→0x1C) patches first!

; === Community Options ===
; Option C: Community Consensus (SAFE for N/A)
; RPM_HIGH        EQU $18A4       ; 6300 RPM activation (PCMhacking tested)
; RPM_LOW         EQU $1890       ; 6280 RPM deactivation (20 RPM hysteresis)

WEAK_DWELL      EQU $00C8       ; 200µs weak dwell (may not saturate coil)
LIMITER_FLAG    EQU $01A0       ; Free RAM byte for limiter state (0=off, 1=on)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
            ORG $0C468          ; Free space VERIFIED: 15,192 bytes of 0x00 (was $18156 WRONG!)

ignition_cut_handler:
    ; Read current RPM
    LDD  RPM_ADDR               ; Load RPM (0x00A2)
    
    ; Check limiter state
    LDAA LIMITER_FLAG           ; Load current state
    BEQ  check_activation       ; If 0, check for activation
    BRA  check_deactivation     ; If 1, check for deactivation

check_activation:
    ; Compare RPM >= RPM_HIGH
    CMPD RPM_HIGH               ; Compare D (RPM) with high threshold
    BLO  normal_dwell           ; Branch if RPM < threshold (unsigned)
    
    ; Activate ignition cut
    LDAA #$01                   ; Set flag = 1
    STAA LIMITER_FLAG
    BRA  apply_weak_dwell

check_deactivation:
    ; Compare RPM < RPM_LOW (hysteresis)
    CMPD RPM_LOW                ; Compare D (RPM) with low threshold
    BHS  apply_weak_dwell       ; Branch if RPM >= threshold (stay in cut)
    
    ; Deactivate ignition cut
    CLR  LIMITER_FLAG           ; Clear flag = 0
    BRA  normal_dwell

apply_weak_dwell:
    ; ⚠️ CRITICAL: This may not work if minimum dwell is hardware enforced
    ; Chr0m3: "PCM won't let dwell = 0, there's a minimum threshold"
    
    ; Attempt to override dwell calculation
    LDD  #WEAK_DWELL            ; Load 200µs weak dwell
    STD  DWELL_TARGET           ; Store to target dwell RAM
    
    ; May need to also modify:
    ; - Minimum dwell lookup table pointer
    ; - Dwell calculation scaling factor
    ; - Hardware TIO compare register directly
    
    RTS

normal_dwell:
    ; Let ECU calculate normal dwell
    ; (Don't modify DWELL_TARGET, let stock routine handle it)
    RTS

;------------------------------------------------------------------------------
; INSTALLATION NOTES
;------------------------------------------------------------------------------
; 1. This method is THEORETICAL and may not work due to hardware constraints
; 2. Chr0m3 confirmed: "Minimum dwell is enforced by hardware/firmware"
; 3. HC11 TIO module may override software dwell calculations
; 4. Requires mapping:
;    - MIN_DWELL_ADDR (where minimum dwell threshold is stored)
;    - DWELL_TARGET (where calculated dwell is stored before TIO use)
;    - Dwell calculation routine location
;
; 5. Bench testing protocol:
;    a. Scope coil primary winding during cut activation
;    b. Measure dwell time (should drop to ~200µs)
;    c. Measure spark voltage (should drop to <10kV)
;    d. If spark still strong, this method doesn't work
;
; 6. Alternative approach (if minimum dwell is enforced):
;    - Manipulate dwell calculation INPUTS (RPM, battery voltage)
;    - Force ECU to think RPM is 10,000+ (dwell naturally drops)
;    - But this may trigger other issues (fuel/timing calculations)
;
;------------------------------------------------------------------------------
; HARDWARE VALIDATION REQUIRED
;------------------------------------------------------------------------------
; Tools needed:
;   - Oscilloscope (measure coil dwell time)
;   - Spark tester (measure spark voltage/strength)
;   - Bench ECU setup (no vehicle testing until validated)
;
; Expected results if working:
;   - Dwell drops to 200-300µs during cut
;   - Spark voltage drops to <10kV (insufficient to fire plug)
;   - Smooth recovery when RPM drops below threshold
;
; Expected results if NOT working:
;   - Dwell stays at ~600µs (hardware override)
;   - Spark voltage remains 25-30kV (normal)
;   - This method is NOT viable on HC11 hardware
;
;------------------------------------------------------------------------------
; STATUS: 🔬 EXPERIMENTAL - DO NOT USE IN VEHICLE
;------------------------------------------------------------------------------
; This method requires validation of:
;   1. Dwell calculation routine location and inputs
;   2. Minimum dwell enforcement mechanism (software vs hardware)
;   3. TIO module override capability
;   4. Chr0m3 consultation (he may have already tested this)
;
; Recommendation: Ask Chr0m3 directly if he tried dwell manipulation
;                 His response: "Pulling dwell doesn't work very well"
;                 → This suggests method may not be viable
;
;==============================================================================
