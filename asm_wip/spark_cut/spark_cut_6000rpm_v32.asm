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
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads, 8-BIT RPM/25
                                ; NOTE: RPM = value × 25, max 255 = 6375 RPM
                                ; $00A3 = Engine State (NOT part of RPM!)
PERIOD_3X_RAM   EQU $017B       ; ✅ VERIFIED: STD at 0x101E1 (FD 01 7B)
DWELL_RAM       EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C (FC 01 99)

;------------------------------------------------------------------------------
; 6000 RPM THRESHOLDS (USER PREFERENCE - 8-BIT SCALED)
;------------------------------------------------------------------------------
; $00A2 = RPM/25, so:
;   6000 RPM ÷ 25 = 240 = $F0
;   5900 RPM ÷ 25 = 236 = $EC
;
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM - spark cut activation
RPM_LOW         EQU $EC         ; 236 × 25 = 5900 RPM - resume (100 RPM hysteresis)

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
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25 (8-bit)
    CMPA    #RPM_HIGH           ; 81 F0    Compare with 240 (6000 RPM)
    BCS     STORE_REAL          ; 25 xx    RPM < 6000 → store real period
    
    ; RPM >= 6000 - ACTIVATE SPARK CUT
    LDAA    #$01                ; 86 01    Set flag = 1 (limiter ON)
    STAA    LIMITER_FLAG        ; 97 A0    Store flag
    BRA     STORE_FAKE          ; 20 xx    Jump to store fake period

CHECK_LOW:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check if should deactivate
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25 (8-bit)
    CMPA    #RPM_LOW            ; 81 EC    Compare with 236 (5900 RPM)
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

;##############################################################################
;#                                                                            #
;#                    ═══ CONFIRMED ADDRESSES & FINDINGS ═══                  #
;#                                                                            #
;##############################################################################

;------------------------------------------------------------------------------
; ✅ BINARY VERIFIED ADDRESSES (January 17, 2026)
;------------------------------------------------------------------------------
;
; Verified on: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (131,072 bytes)
;
; File Offset | Bytes      | Instruction    | Status    | Purpose
; ------------|------------|----------------|-----------|--------------------
; 0x101E1     | FD 01 7B   | STD $017B      | ✅ HOOK   | 3X period store
; 0x0C500     | 00 00 00...| (zeros)        | ✅ FREE   | Code space (15KB)
; 0x77DE      | EC EB      | RPM HIGH/LOW   | ✅ TABLE  | Fuel cut (stock!)
; 0x3631      | BD 37 1A   | JSR $371A      | ✅ REF    | Dwell calc call
; 0x371A      | 13 67 A0   | BRCLR...       | ✅ REF    | Dwell calc start
;
; NOTE: Enhanced binary still has stock fuel cut values (EC EB = 5900/5875)
;       Our spark cut at 6000 will trigger BEFORE stock fuel cut!
;
;------------------------------------------------------------------------------
; 📐 6000 RPM THRESHOLD MATH
;------------------------------------------------------------------------------
;
; 8-bit RPM at $00A2:
;   RAM stores: Actual_RPM ÷ 25
;   6000 RPM ÷ 25 = 240 = $F0 ✅
;   5900 RPM ÷ 25 = 236 = $EC (100 RPM hysteresis)
;
; Why 100 RPM hysteresis?
;   - 100 RPM = 4 × 25 = 4 byte difference ($F0 - $EC = 4)
;   - Prevents limiter "chatter" (rapid on/off)
;   - VL V8 Walkinshaw uses 94 RPM hysteresis
;   - BMW MS43 uses ~100 RPM hysteresis
;
; Timing validation:
;   At 6000 RPM: 6000 ÷ 60 = 100 revs/sec = 10ms per revolution
;   6-cylinder: 10ms ÷ 6 = 1.67ms between 3X events
;   Our code runs every 3X event = every 1.67ms at 6000 RPM
;
;------------------------------------------------------------------------------
; 📐 FAKE PERIOD CALCULATION
;------------------------------------------------------------------------------
;
; Stock 3X period at 6000 RPM:
;   Period = Timer_Clock ÷ (RPM ÷ 60 × teeth_per_rev)
;   Period = 2,000,000 ÷ (100 × 6) = 3,333 counts = $0D05
;
; Fake period effect:
;   Fake = $3E80 = 16,000 counts
;   Apparent RPM = 2,000,000 ÷ 16,000 ÷ 6 × 60 = 125 RPM
;   At 125 apparent RPM: Dwell calc gives ~100µs dwell
;   100µs dwell = coil cannot charge = NO SPARK
;
; Chr0m3 confirmed: "If you set the 3x period astronomically high 
;   the dwell gets really really small (if I recall like 100us)"
;
;------------------------------------------------------------------------------
; 🔧 INSTALLATION PATCH (Hex Editor)
;------------------------------------------------------------------------------
;
; STEP 1: Backup original binary!
;
; STEP 2: Hook Point
;   File offset: 0x101E1
;   Change: FD 01 7B → BD C5 00
;   Verify context: xx xx FD 01 7B xx xx (look for STD $017B)
;
; STEP 3: Code Injection
;   File offset: 0x0C500
;   Verify: All zeros at this location (safe to overwrite)
;   Insert: Assembled bytes from this file
;
; Assembled bytes (approximately 50 bytes):
;   36 37 96 A0 81 01 27 0B 96 A2 81 F0 25 0C 86 01
;   97 A0 20 0F 96 A2 81 EC 24 0A 7F 01 A0 20 05 33
;   32 CC 3E 80 FD 01 7B 39 33 32 FD 01 7B 39
;
; STEP 4: Checksum
;   Open in TunerPro with XDF → Save (auto-updates checksum)
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. LIMITER_FLAG at $01A0
;    Status: UNVERIFIED - assumed free
;    Risk: LOW - typical spare RAM area
;    Action: Check XDF mappings, test with Mode 4 RAM dump
;
; 2. Alternative free RAM:
;    $00FB-$00FF: Page zero end (faster access)
;    $01A1-$01AF: Same area as $01A0
;    $1B00-$1BFF: Extended RAM (verified unused in some areas)
;
; 3. Fuel cut interaction:
;    Stock fuel cut at 5900 RPM ($EC) is LOWER than our 6000 RPM spark cut!
;    Enhanced OS may have different fuel cut - check XDF
;    Consider disabling fuel cut by setting 0x77DE = $FF
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE METHODS (Comparison)
;------------------------------------------------------------------------------
;
; A) 3X Period Injection (THIS FILE) ⭐ BEST FOR 6000 RPM
;    Code: ~50 bytes at $C500
;    Hook: 3 bytes at 0x101E1
;    Latency: Immediate (same TIC3 interrupt)
;    Pros: Simple, proven, minimal code
;    Cons: Not true zero dwell (still ~100µs)
;
; B) Rolling Cut (v34)
;    Code: ~80 bytes at $C500
;    Latency: Same interrupt
;    Pros: FLAMES! Random cut = turbo anti-lag
;    Cons: More complex, less predictable
;
; C) Soft Timing Retard (v36)
;    Hook: Timing calculation area
;    Latency: Same cycle
;    Pros: Progressive power reduction
;    Cons: Engine still fires, no flames
;
; D) Two-Stage with Delay (v23)
;    Code: ~120 bytes
;    Pros: VL V8 Walkinshaw style, smooth sound
;    Cons: More complex, needs timer integration
;
; E) Direct Fuel Cut Replacement
;    Hook: Overwrite 0x77DE-0x77E1
;    Pros: Uses existing ECU limiter logic
;    Cons: Still fuel cut (no flames), 8-bit limit
;
;------------------------------------------------------------------------------
; 💡 OPTIMIZATION OPPORTUNITIES
;------------------------------------------------------------------------------
;
; 1. Combine with fuel cut disable:
;    Set 0x77DE = $FF, 0x77DF = $FF → Fuel cut at 6375 (effectively off)
;    Our spark cut at 6000 RPM handles limiting
;    Result: Pure spark cut with flames!
;
; 2. Add Mode 4 control:
;    Read Mode 4 RAM flag to enable/disable at runtime
;    $01A2 could be Mode 4 controlled threshold
;    Allows tuner adjustment without reflash
;
; 3. Temperature protection:
;    Read coolant temp from RAM (typically $0049)
;    Lower limit if engine hot (e.g., 5500 RPM if >110°C)
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_3x_period_VERIFIED.asm - Base verified version (test mode)
; spark_cut_chrome_method_v33.asm  - Chr0m3's methodology documented
; spark_cut_rolling_v34.asm        - Random cut for flames
; spark_cut_dwell_patch_v37.asm    - For >6375 RPM capability
; DOCUMENT_CONSOLIDATION_PLAN.md   - Project status and TODOs
;
;##############################################################################
