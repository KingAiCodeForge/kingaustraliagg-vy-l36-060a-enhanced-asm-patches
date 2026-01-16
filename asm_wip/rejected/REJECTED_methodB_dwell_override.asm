;==============================================================================
; VY V6 IGNITION CUT - Method B: DWELL OVERRIDE
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ❌ REJECTED BY CHR0M3 - DO NOT USE FOR PRODUCTION
;
; ⚠️⚠️⚠️ THIS METHOD DOES NOT WORK! ⚠️⚠️⚠️
;
; Kept for DOCUMENTATION and RESEARCH purposes only.
; Use ignition_cut_patch_v33_chrome_method.asm instead!
;
;==============================================================================
; CHR0M3 REJECTION QUOTES (Facebook Messenger, October-November 2025)
;==============================================================================
;
; Direct quotes from Chr0m3 Motorsport explaining why this fails:
;
; ❌ "Just pulling dwell doesn't work very well, it's been tried."
;
; ❌ "Pulling dwell only works so well as you can't truly command 0,
;     PCM won't let it"
;
; ❌ "The dwell is hardware controlled by the TIO, that's half of the
;     problems we get, don't have full control over it."
;
; ❌ "Anyway back to the original point, dwell is a dead end just 
;     wasting your time"
;
;==============================================================================
; WHY DWELL OVERRIDE FAILS
;==============================================================================
;
; 1. HARDWARE ENFORCEMENT
;    The HC11 Timer Interface (TIO) enforces minimum dwell times
;    in hardware. Software cannot command truly zero dwell.
;
; 2. MINIMUM DWELL PROTECTION
;    Even if you write 0x00 to dwell registers, the TIO module
;    enforces a minimum (approximately 200-300µs) to prevent
;    coil damage and ensure EST signal integrity.
;
; 3. FIRMWARE OVERRIDE
;    Stock firmware continuously recalculates and writes dwell
;    values. Any value you write is overwritten within 1-2 loop
;    cycles (typically <10ms).
;
; 4. PARTIAL EFFECTIVENESS ONLY
;    Chr0m3 tested this extensively. At best, dwell can be reduced
;    to ~600µs by writing specific values, but this is NOT enough
;    for reliable spark cut. The coil still charges enough to fire.
;
;==============================================================================
; MEMORY MAP (For Reference Only)
;==============================================================================

; Dwell-related RAM addresses
DWELL_TIME      EQU $00C4       ; Calculated dwell time (may be incorrect)
MIN_DWELL       EQU $00C6       ; Minimum dwell value
BURN_TIME       EQU $00C8       ; Burn time after spark

; These addresses need validation - they may not be correct for VY V6
DWELL_TABLE_L   EQU $5D02       ; Dwell table base (unverified)
DWELL_TABLE_H   EQU $5D12       ; Dwell table high values (unverified)

; Timer Output Compare (hardware control)
TOC2            EQU $1018       ; Timer Output Compare 2
TOC3            EQU $101A       ; Timer Output Compare 3 (EST)

;==============================================================================
; THE FAILED APPROACH
;==============================================================================
;
; What we tried (and what doesn't work):
;
;   ; Try to set dwell to zero
;   CLR     DWELL_TIME          ; Write 0 to dwell
;   CLR     MIN_DWELL           ; Write 0 to min dwell
;   
;   ; Result: TIO enforces minimum, coil still fires
;   ; Result: Firmware overwrites these values immediately
;   ; Result: At best, dwell reduced to ~600µs (still sparks)
;
;==============================================================================
; WHAT CHR0M3 ACTUALLY DOES (THE WORKING METHOD)
;==============================================================================
;
; Chr0m3's approach (3X Period Injection) works because:
;
;   1. He doesn't try to control dwell directly
;   2. Instead, he injects a FAKE 3X period value
;   3. The ECU calculates dwell based on (fake) period
;   4. Fake period = very long → calculated dwell = ~100µs
;   5. 100µs is below TIO minimum enforcement threshold
;   6. Result: NO SPARK (reliable spark cut!)
;
; See: ignition_cut_patch_v33_chrome_method.asm
;
;==============================================================================
; DOCUMENTATION CODE (NON-FUNCTIONAL EXAMPLE)
;==============================================================================

; This code is provided for DOCUMENTATION ONLY
; DO NOT FLASH THIS TO A CAR

FAILED_DWELL_OVERRIDE:
        ; Read RPM
        LDD     $00A2               ; RPM address
        CPD     #$1770              ; 6000 RPM threshold
        BLO     EXIT_NO_ACTION
        
        ; THIS DOES NOT WORK:
        CLR     DWELL_TIME          ; TIO ignores this
        CLR     MIN_DWELL           ; Firmware overwrites this
        
        ; The coil STILL fires because:
        ; - Hardware enforces minimum dwell
        ; - Firmware continuously updates these values
        ; - TIO module has independent control
        
EXIT_NO_ACTION:
        RTS

;==============================================================================
; RECOMMENDED ALTERNATIVE
;==============================================================================
;
; Use the Chr0m3 validated 3X Period Injection method:
;
;   File: ignition_cut_patch_v33_chrome_method.asm
;   File: ignition_cut_patch_v32_6000rpm_spark_cut.asm
;   File: ignition_cut_patch_VERIFIED.asm
;
; These methods work because they trick the ECU's dwell CALCULATION
; rather than trying to override the dwell OUTPUT.
;
;==============================================================================
; RESEARCH NOTES
;==============================================================================
;
; Minimum dwell test results (from Chr0m3):
;   - Stock minimum: ~2.5ms
;   - Writing 0x00: ~300µs (TIO enforced minimum)
;   - Writing 0x96 (150): ~600µs (Chr0m3 tested)
;   - Coil fires at any dwell above ~200µs
;
; The 200µs threshold is the "spark cut" point. To achieve this,
; you need the 3X Period Injection method which causes the ECU
; to CALCULATE a ~100µs dwell (below the threshold).
;
; If someone finds a way to make dwell override work, document it
; here and update the status. Until then, this method is REJECTED.
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - ignition_cut_patch_v33_chrome_method.asm (WORKING method)
;   - Chr0m3_Spark_Cut_Analysis_Critical_Findings.md
;   - WHY_ZEROS_CANT_BE_USED_Chrome_Explanation.md
;
; Forum Sources:
;   - PCMHacking Topic 8567 (dwell discussion)
;   - Facebook Messenger logs (Oct-Nov 2025)
;
;==============================================================================
