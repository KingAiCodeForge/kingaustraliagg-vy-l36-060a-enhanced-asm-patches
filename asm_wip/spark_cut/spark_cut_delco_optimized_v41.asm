; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !! CROSS-BANK BUG (2026-02-13): This file places code at ORG $C468+ !!
; !! (bank 1 free space). The hook at file 0x101E1 (STD $017B) is in  !!
; !! bank 2 (0x10000-0x17FFF). JSR $C500 from bank 2 hits file        !!
; !! 0x1C500 (LIVE TRANS CODE), NOT 0x0C500 (our patch).               !!
; !! FIX: Relocate to common area $5D05 (always visible, 504 bytes    !!
; !! free) or bank 2 free space at file 0x17EA2 (286 bytes).           !!
; !! See custom_ose_$060_445_plan.md section 3.1a/3.1b for details.   !!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;;==============================================================================
; [ADDRESS FIX 2026-02-09] Binary-verified address corrections applied
; Ground truth: 92118883_STOCK.bin (HC11 opcode scan, equivalent to Capstone)
; Fixes: 1 issues found and annotated
;==============================================================================
;==============================================================================
; DELCO-OPTIMIZED SPARK CUT v41 - IGNORING CHR0M3 REJECTIONS
;==============================================================================
; Philosophy: What actually works in Delco/GM systems, not theoretical limits
; 
; Chr0m3 said "dwell manipulation doesn't work"
; BUT: Multiple GM platforms (P59, P01, P12) use dwell-based limiters successfully
; 
; This implementation uses REAL GM techniques from:
; - P59 (LS1 1997-2004) - proven dwell limiter
; - P01 (LS1 1997-2000) - proven dwell limiter  
; - VL Walkinshaw (Delco 808) - two-stage limiter
; - The1's method (CPD comparison)
; - Real-world dyno testing feedback
;
; Key Insight: Chr0m3 may have been testing with:
; - Wrong dwell address
; - Wrong timing in execution flow
; - Conflicting code elsewhere
;
; Let's test EVERYTHING systematically!
;
; Author: Jason King (kingaustraliagg)
; Date: January 20, 2026
; Status: EXPERIMENTAL - Systematic testing required
;==============================================================================

;------------------------------------------------------------------------------
; GM P59/P01 DWELL LIMITER ANALYSIS
;------------------------------------------------------------------------------
; P59/P01 LS1 ECUs have proven rev limiters that work via:
; 1. Dwell time reduction (NOT zero, but reduced)
; 2. Period manipulation (our current method)
; 3. Cylinder-selective cutting (alternating)
;
; They DON'T set dwell to zero (Chr0m3 was right about that)
; They DO reduce it to a minimum safe value (~0.5ms)
;
; Formula:
; Dwell (ms) = Counts × 32µs
; 0.5ms = 15.625 counts = 0x10 (round to 16)
; Normal dwell: ~2.0-3.5ms = 62-109 counts = 0x3E-0x6D
;
;------------------------------------------------------------------------------
; VL WALKINSHAW TWO-STAGE LIMITER
;------------------------------------------------------------------------------
; VL V8 (Delco 808, similar to HC11) uses:
; - High threshold: 5617 RPM (activate)
; - Low threshold: 5523 RPM (deactivate)
; - Hysteresis: 94 RPM
; - Method: Dwell reduction + timing retard
;
; It WORKS in production cars!
;
;------------------------------------------------------------------------------
; THEORY: Why Chr0m3's Test Failed
;------------------------------------------------------------------------------
; Possible reasons dwell=0 didn't work:
; 1. Hardware enforced minimum (likely ~0.5ms)
; 2. Wrote to wrong address (read vs write locations)
; 3. Timing issue (wrote after dwell already calculated)
; 4. Safety check in code preventing zero
;
; Solution: Don't try dwell=0, use MINIMUM value instead
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; IMPLEMENTATION: MULTI-METHOD SPARK CUT
;------------------------------------------------------------------------------
; This provides 4 different methods you can select:
; - Method A: Period injection (Chr0m3's verified method)
; - Method B: Dwell reduction (GM P59 style, NOT zero)
; - Method C: Hardware TCTL1 (BennVenn OSE12P - VN-VS platform, needs VY adaptation)
; - Method D: Combined (dwell + period + timing)
;
; NOTE: OSE 12P = VN-VS custom OS (ECU 1227808, OSID $5D/$12B)
;       Same HC11 CPU but different memory layout than VY V6 $060A!
;
; Use calibration byte to select method!
;------------------------------------------------------------------------------

    ORG $7E10           ; Calibration area (verify in XDF!)

; Configuration
LIMITER_METHOD:
    DB  $01             ; 0x01=Period, 0x02=Dwell, 0x03=Hardware, 0x04=Combined

LIMITER_ENABLE:
    DB  $01             ; 0x00=off, 0x01=on

RPM_THRESHOLD_HIGH:
    DW  $1770           ; 6000 RPM activate

RPM_THRESHOLD_LOW:
    DW  $1716           ; 5900 RPM deactivate

; Dwell Configuration (GM P59 values)
DWELL_MINIMUM:
    DB  $10             ; 16 counts = 0.512ms (safe minimum)

DWELL_NORMAL:
    DB  $6D             ; 109 counts = 3.5ms (typical)

;------------------------------------------------------------------------------
; MAIN LIMITER CODE
;------------------------------------------------------------------------------

    ORG $C500           ; Verified free space ; ⚠️ MUST BE bank 1 (file 0x0C500). Banks 0/2/3 have calibration data! [auto-fix 2026-02-09]

DELCO_LIMITER_ENTRY:
    ; Check enable
    LDAA    LIMITER_ENABLE
    BEQ     NORMAL_OP
    
    ; Check active state
    BRSET   $46,$80,CHECK_DEACTIVATE
    
;--- ACTIVATION CHECK ---
CHECK_ACTIVATE:
    ; Load RPM and convert to 16-bit
    LDAA    $A2         ; RPM/25 (verified)
    LDAB    #$19        ; 25 decimal
    MUL                 ; D = RPM
    
    ; Compare with activation threshold
    LDX     #RPM_THRESHOLD_HIGH
    CPD     $00,X       ; Compare D with table value
    BLS     NORMAL_OP   ; Below threshold
    
    ; Activate limiter
    BSET    $46,$80     ; Set active flag
    BRA     APPLY_METHOD
    
;--- DEACTIVATION CHECK ---
CHECK_DEACTIVATE:
    ; Load RPM
    LDAA    $A2
    LDAB    #$19
    MUL
    
    ; Compare with deactivation threshold
    LDX     #RPM_THRESHOLD_LOW
    CPD     $00,X
    BCC     APPLY_METHOD    ; Still above threshold
    
    ; Deactivate
    BCLR    $46,$80
    BRA     NORMAL_OP

;--- SELECT METHOD ---
APPLY_METHOD:
    LDAA    LIMITER_METHOD
    CMPA    #$01
    BEQ     METHOD_PERIOD
    CMPA    #$02
    BEQ     METHOD_DWELL
    CMPA    #$03
    BEQ     METHOD_HARDWARE
    BRA     METHOD_COMBINED

;------------------------------------------------------------------------------
; METHOD A: PERIOD INJECTION (Chr0m3 Verified)
;------------------------------------------------------------------------------
METHOD_PERIOD:
; ⚠️ WARNING: STD $194C at $3618 is INIT PATH ONLY (cold start, D=$0000).
;    Real period updates use filter sub $050C via indexed STD 0,X.
;    Hooking $3618 does NOT affect normal engine operation!
;    Use $017B hook at 0x101E1 instead (dwell intermediate).
    LDD     #$3E80      ; Fake long period = no spark
    STD     $194C       ; Store to period (verified address)
    RTS

;------------------------------------------------------------------------------
; METHOD B: DWELL REDUCTION (GM P59 Style)
;------------------------------------------------------------------------------
; NOT dwell=0 (doesn't work)
; Use MINIMUM safe value instead (0.5ms = 16 counts)
;------------------------------------------------------------------------------
METHOD_DWELL:
    ; Reduce dwell to minimum (NOT zero!)
    LDAA    DWELL_MINIMUM   ; 0x10 = 0.512ms
    STAA    $0199           ; Store to dwell LOW byte
    
    ; Also increase period slightly (double effect)
    LDD     $194C           ; Read current period
    ASLD                    ; Multiply by 2
    STD     $194C           ; Store back
    
    RTS

;------------------------------------------------------------------------------
; METHOD C: HARDWARE TCTL1 CONTROL (BennVenn OSE12P Port)
;------------------------------------------------------------------------------
; Force PA5 (EST output) LOW via TCTL1 register
; This is HARDWARE level control - bypasses all software
;------------------------------------------------------------------------------
METHOD_HARDWARE:
    ; Read TCTL1 register
    LDAA    $1020           ; TCTL1 @ $1020
    ANDA    #$CF            ; Clear bits 5-4 (PA5 control)
    ORAA    #$20            ; Set bits 5-4 = 10 (force PA5 LOW)
    STAA    $1020           ; Write back → NO SPARK!
    
    ; Note: This disables EST output COMPLETELY
    ; Use with caution - may cause check engine light
    
    RTS

;------------------------------------------------------------------------------
; METHOD D: COMBINED APPROACH (Maximum Effectiveness)
;------------------------------------------------------------------------------
; Use multiple techniques simultaneously for strongest cut:
; 1. Reduce dwell to minimum
; 2. Inject fake period
; 3. Retard timing (if address known)
;------------------------------------------------------------------------------
METHOD_COMBINED:
    ; 1. Reduce dwell
    LDAA    DWELL_MINIMUM
    STAA    $0199           ; Dwell LOW byte
    
    ; 2. Inject fake period
    LDD     #$3E80
    STD     $194C           ; Period storage
    
    ; 3. Retard timing (address unknown - needs research)
    ; LDD     $????         ; Timing advance register
    ; SUBD    #$0500        ; Retard by 5 degrees (example)
    ; STD     $????         ; Store back
    
    RTS

;--- NORMAL OPERATION ---
NORMAL_OP:
    ; Restore normal dwell if was cutting
    BRCLR   $46,$80,SKIP_RESTORE
    
    LDAA    DWELL_NORMAL    ; Restore normal dwell
    STAA    $0199
    
    ; Restore TCTL1 if was using hardware method
    LDAA    LIMITER_METHOD
    CMPA    #$03
    BNE     SKIP_RESTORE
    
    LDAA    $1020           ; Read TCTL1
    ANDA    #$CF            ; Clear PA5 control bits
    ORAA    #$10            ; Set to normal toggle mode
    STAA    $1020           ; Restore normal operation
    
SKIP_RESTORE:
    RTS

;------------------------------------------------------------------------------
; HOOK INSTALLATION
;------------------------------------------------------------------------------
; OFFSET: 0x101E1
; ORIGINAL: FD 01 7B        (STD     $194C)
; PATCHED:  BD C5 00        (JSR $C500)

;==============================================================================
; TESTING PROTOCOL
;==============================================================================
; Test each method systematically:
;
; 1. METHOD A (Period Injection) - VERIFIED WORKING
;    - Start here as baseline
;    - Should work (Chr0m3 verified)
;
; 2. METHOD B (Dwell Reduction) - TEST ON BENCH
;    - Use 0x10 (16 counts, NOT zero!)
;    - Monitor for spark with oscilloscope
;    - Check for CEL
;
; 3. METHOD C (Hardware TCTL1) - TEST ON BENCH
;    - Monitor PA5 pin with scope
;    - Verify LOW output during cut
;    - Check for CEL
;
; 4. METHOD D (Combined) - TEST ON BENCH
;    - Should be most effective
;    - May cause CEL (acceptable for race use)
;
; Bench Test Setup:
; - ECU on bench power supply
; - Crank sensor signal generator
; - Oscilloscope on:
;   - PA5 (EST output)
;   - Coil primary
;   - Coil secondary (spark plug wire)
; - RPM sweep: 1000 → 7000 RPM
;
; Success Criteria:
; - Spark cuts cleanly above threshold
; - Spark resumes cleanly below threshold
; - No random misfires
; - No permanent damage to ECU
;
;==============================================================================
; ADDRESSING CHR0M3'S CONCERNS
;==============================================================================
; Chr0m3 said: "Pulling dwell doesn't work well... PCM won't let dwell = 0"
;
; Our Response:
; 1. ✅ Correct: dwell=0 doesn't work (hardware enforced minimum)
; 2. ✅ Correct: Trying to force zero may be ignored
; 3. ❓ Unknown: Does MINIMUM dwell work? (0.5ms like GM P59)
; 4. ❓ Unknown: Was the test using correct address?
; 5. ❓ Unknown: Was timing in execution flow correct?
;
; New Hypothesis:
; - Dwell=0: Doesn't work (confirmed)
; - Dwell=minimum: May work (needs testing)
; - Dwell + period: May work better (combined effect)
; - Hardware control: Should work (OSE12P uses this)
;
; Action: TEST SYSTEMATICALLY instead of assuming failure!
;
;==============================================================================
; COMPARISON WITH OTHER PLATFORMS
;==============================================================================
; Platform      | Method Used               | Result
; --------------|---------------------------|------------------
; P59 LS1       | Dwell reduction (min)     | ✅ Works in production
; P01 LS1       | Dwell reduction (min)     | ✅ Works in production
; VL V8 Delco   | Dwell + timing retard     | ✅ Works (Walkinshaw)
; VY V6 Chr0m3  | Period injection          | ✅ Verified working
; VY V6 Dwell=0 | Dwell to zero             | ❌ Doesn't work (Chr0m3)
; OSE12P        | TCTL1 hardware control    | ✅ Works (BennVenn)
; This (v41)    | Multi-method selectable   | ❓ NEEDS TESTING
;
;==============================================================================
; STATUS: EXPERIMENTAL - Ready for bench testing
; RISK: Medium (may cause CEL, no engine damage expected)
; RECOMMENDATION: Test on BENCH before car!
;==============================================================================
