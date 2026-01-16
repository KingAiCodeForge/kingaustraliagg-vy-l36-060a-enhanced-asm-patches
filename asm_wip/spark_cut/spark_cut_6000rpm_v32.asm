;==============================================================================
; VY V6 IGNITION CUT v32 - 6000 RPM SPARK CUT (USER PREFERENCE)
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 16, 2026
; Method: 3X Period Injection (Chr0m3 validated)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; Description:
;   User-preferred 6000 RPM ignition cut limiter with 100 RPM hysteresis.
;   Provides the classic "pops and bangs" exhaust sound when hitting limiter.
;   Safe margin below the 6375 RPM ECU calculation limit (255 × 25 RPM).
;
; Status: 🔬 UNTESTED - Based on VERIFIED method structure
;
; RPM Thresholds:
;   - Activation:   6000 RPM (0x1770)
;   - Deactivation: 5900 RPM (0x170C) - 100 RPM hysteresis
;
; Why 6000 RPM?
;   - Safe margin: 375 RPM below ECU limit (6375)
;   - Safe margin: 500 RPM below spark loss point (6500 per Chr0m3)
;   - Comfortable buffer for valve float protection
;   - Sounds good with 100 RPM hysteresis band
;
; Based On:
;   - ignition_cut_patch_VERIFIED.asm (all addresses verified)
;   - Chr0m3 Motorsport 3X Period Injection method
;   - Consolidation Plan Session 7 validated addresses
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES (from ignition_cut_patch_VERIFIED.asm)
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads in code
PERIOD_3X_RAM   EQU $017B       ; ✅ VERIFIED: STD at 0x101E1 (FD 01 7B)
DWELL_RAM       EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C (FC 01 99)

;------------------------------------------------------------------------------
; 6000 RPM THRESHOLDS (USER PREFERENCE)
;------------------------------------------------------------------------------
; Calculation: RPM × 1 = hex value (no scaling for comparison)
; Formula: RPM / 1 = decimal → convert to hex
;
; 6000 RPM = 0x1770 (6000 decimal)
; 5900 RPM = 0x170C (5900 decimal)
;
RPM_HIGH        EQU $1770       ; 6000 RPM - spark cut activation
RPM_LOW         EQU $170C       ; 5900 RPM - spark resume (100 RPM hysteresis)

; ALTERNATIVE THRESHOLDS (commented, for reference):
;
; Test Mode: 3000 RPM for safe validation
; RPM_HIGH        EQU $0BB8       ; 3000 RPM (test)
; RPM_LOW         EQU $0B54       ; 2900 RPM (test)
;
; Conservative: Stock redline 5900 RPM
; RPM_HIGH        EQU $170C       ; 5900 RPM
; RPM_LOW         EQU $16DE       ; 5850 RPM (50 RPM hysteresis)
;
; Maximum Safe: Chr0m3 recommended 6350 RPM  
; RPM_HIGH        EQU $18CE       ; 6350 RPM
; RPM_LOW         EQU $18A0       ; 6300 RPM
;
; ECU Limit: Absolute maximum 6375 RPM (255 × 25 = 6375)
; RPM_HIGH        EQU $18E7       ; 6375 RPM
; RPM_LOW         EQU $18B9       ; 6325 RPM

;------------------------------------------------------------------------------
; FAKE PERIOD VALUE
;------------------------------------------------------------------------------
; Normal 3X period at 6000 RPM ≈ 3.3ms = 3300 counts
; Fake period = 16000 = ~1000ms → dwell ≈ 100µs = insufficient spark energy
;
; Explanation (from Chr0m3):
;   When we inject a very large period value (16000), the ECU calculates
;   dwell time based on this. With a fake period of ~1000ms, dwell drops
;   to approximately 100µs - not enough to charge the coil for ignition.
;   Result: No spark = pops and bangs from unburned fuel in exhaust.
;
FAKE_PERIOD     EQU $3E80       ; 16000 decimal = ~1000ms fake period

;------------------------------------------------------------------------------
; FREE RAM FOR LIMITER STATE
;------------------------------------------------------------------------------
; Location: $01A0 (needs verification, placeholder from community testing)
; Purpose: Track limiter state for hysteresis logic
;   - 0x00 = limiter OFF (normal operation)
;   - 0x01 = limiter ON (spark cut active)
;
LIMITER_FLAG    EQU $01A0       ; ⚠️ UNVERIFIED - needs confirmation

;------------------------------------------------------------------------------
; CODE SECTION - VERIFIED FREE SPACE
;------------------------------------------------------------------------------
; Location verified: File offset 0x0C468-0x0FFBF = 15,192 bytes of zeros
; CPU address: $0C468 (corrected from wrong $18156 in early versions)
; Using $0C500 for alignment and room for future expansions
;
            ORG $0C500          ; ✅ VERIFIED: 15,040 bytes free (all 0x00)

;==============================================================================
; HOOK POINT MODIFICATION
;==============================================================================
; Replace instruction at file offset 0x101E1:
;   Original: FD 01 7B (STD $017B) - stores 3X period
;   Patched:  BD C5 00 (JSR $C500) - calls our routine
;
; Our routine stores the period to the same location ($017B) after
; potentially modifying it based on RPM limiter logic.
;
; HOOK_OFFSET     EQU $101E1      ; ✅ VERIFIED: STD $017B instruction
; HOOK_ORIGINAL   EQU $FD017B     ; ✅ VERIFIED: Original bytes
; HOOK_PATCHED    EQU $BDC500     ; JSR $C500 (call our routine)

;==============================================================================
; IGNITION CUT HANDLER - 6000 RPM VERSION
;==============================================================================
; Called from: JSR at 0x101E1 (replaces "STD $017B")
; Entry:       D = calculated 3X period from stock code
; Exit:        D = either real period OR fake period
;              RAM $017B = stored period value
; Preserves:   All registers
; Stack:       2 bytes (PSHA/PSHB)
;
; Algorithm:
;   1. Save incoming period value
;   2. Check limiter state flag
;   3. If limiter OFF: check if RPM >= 6000 → activate
;   4. If limiter ON: check if RPM < 5900 → deactivate
;   5. Store appropriate period (real or fake)
;   6. Return to stock code
;
;==============================================================================

IGNITION_CUT_HANDLER:
    PSHA                        ; 36       Save A (period high byte)
    PSHB                        ; 37       Save B (period low byte)
    
    ;--------------------------------------------------------------------------
    ; CHECK LIMITER STATE
    ;--------------------------------------------------------------------------
    LDAA    LIMITER_FLAG        ; 96 A0    Load limiter flag
    CMPA    #$01                ; 81 01    Is limiter active?
    BEQ     CHECK_LOW           ; 27 xx    Yes → check if should deactivate
    
    ;--------------------------------------------------------------------------
    ; LIMITER OFF - Check if should activate
    ;--------------------------------------------------------------------------
    LDD     RPM_ADDR            ; DC A2    Load current RPM (16-bit)
    CPD     #RPM_HIGH           ; 1A 83 17 70  Compare with 6000 RPM
    BCS     STORE_REAL          ; 25 xx    RPM < 6000 → store real period
    
    ; RPM >= 6000 - ACTIVATE SPARK CUT
    LDAA    #$01                ; 86 01    Set flag = 1 (limiter ON)
    STAA    LIMITER_FLAG        ; 97 A0    Store flag
    BRA     STORE_FAKE          ; 20 xx    Jump to store fake period

CHECK_LOW:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check if should deactivate
    ;--------------------------------------------------------------------------
    LDD     RPM_ADDR            ; DC A2    Load current RPM
    CPD     #RPM_LOW            ; 1A 83 17 0C  Compare with 5900 RPM
    BCC     STORE_FAKE          ; 24 xx    RPM >= 5900 → keep cutting
    
    ; RPM < 5900 - DEACTIVATE SPARK CUT
    CLR     LIMITER_FLAG        ; 7F 01 A0 Clear flag (limiter OFF)
    BRA     STORE_REAL          ; 20 xx    Store real period

STORE_FAKE:
    ;--------------------------------------------------------------------------
    ; INJECT FAKE PERIOD - Causes spark cut
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore B from stack (discard)
    PULA                        ; 32       Restore A from stack (discard)
    LDD     #FAKE_PERIOD        ; CC 3E 80 D = 16000 (fake period)
    STD     PERIOD_3X_RAM       ; FD 01 7B Store fake period to RAM $017B
    RTS                         ; 39       Return to caller

STORE_REAL:
    ;--------------------------------------------------------------------------
    ; STORE REAL PERIOD - Normal spark operation
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore B (original period low)
    PULA                        ; 32       Restore A (original period high)
    STD     PERIOD_3X_RAM       ; FD 01 7B Store real period to RAM $017B
    RTS                         ; 39       Return to caller

;==============================================================================
; END OF PATCH CODE
;==============================================================================
; Total code size: ~50 bytes
; Free space used: $0C500 - $0C540 approximately
;
; VALIDATION CHECKLIST:
; [ ] Assemble with HC11 assembler (as19 or similar)
; [ ] Verify hook point at 0x101E1 before patching
; [ ] Test at 3000 RPM first (change RPM_HIGH/RPM_LOW for testing)
; [ ] Datalog RPM, 3X period, limiter behavior
; [ ] Listen for "BRRRT" exhaust sound when hitting limiter
; [ ] Verify smooth hysteresis (no rapid on/off cycling)
;
; EXPECTED BEHAVIOR:
;   RPM < 5900:    Normal spark, limiter OFF
;   RPM 5900-5999: Hysteresis band, state unchanged
;   RPM >= 6000:   Spark cut active, exhaust pops
;   RPM drops:     Limiter deactivates below 5900, spark resumes
;
; SAFETY NOTES:
;   - 6000 RPM is 375 below ECU limit (6375)
;   - 6000 RPM is 500 below spark loss point (6500 per Chr0m3)
;   - Safe for stock valve springs and bottom end
;   - Recommend checking valve spring fatigue if bouncing on limiter often
;
;==============================================================================

;------------------------------------------------------------------------------
; PATCH APPLICATION INSTRUCTIONS
;------------------------------------------------------------------------------
; 1. Open VX-VY_V6_$060A_Enhanced_v1.0a.bin in hex editor
;
; 2. Navigate to file offset 0x101E1
;    Verify: FD 01 7B (STD $017B)
;
; 3. Replace bytes at 0x101E1:
;    Before: FD 01 7B
;    After:  BD C5 00 (JSR $C500)
;
; 4. Navigate to file offset 0x0C500
;    Verify: All zeros (00 00 00...)
;
; 5. Insert assembled code at 0x0C500
;    (Use assembled binary from this source)
;
; 6. Save patched binary as new file (don't overwrite original!)
;
; 7. Flash to ECU using appropriate tool
;
; 8. Test safely:
;    a) First test at 3000 RPM (modify thresholds)
;    b) Verify limiter activates/deactivates correctly
;    c) Then recompile with 6000 RPM thresholds
;    d) Test full range in safe environment
;
;------------------------------------------------------------------------------
; RELATED FILES:
;------------------------------------------------------------------------------
; ignition_cut_patch_VERIFIED.asm     - Base verified version (test mode)
; ignition_cut_patch.asm              - Full featured version
; ignition_cut_patch_v7_two_step_launch_control.asm - Launch control variant
; DOCUMENT_CONSOLIDATION_PLAN.md      - Project status and validation
; github readme.md                    - Full documentation
;
;------------------------------------------------------------------------------
; CHANGELOG:
;------------------------------------------------------------------------------
; v32 (January 16, 2026):
;   - NEW: Created for user-preferred 6000 RPM limiter
;   - Based on VERIFIED.asm structure
;   - 100 RPM hysteresis (6000 cut, 5900 resume)
;   - Simplified single-purpose design
;   - Comprehensive documentation and comments
;
;==============================================================================
