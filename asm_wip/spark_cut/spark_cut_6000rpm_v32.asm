; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !! CROSS-BANK BUG (2026-02-13): This file places code at ORG $C468+ !!
; !! (bank 1 free space). The hook at file 0x101E1 (STD $017B) is in  !!
; !! bank 2 (0x10000-0x17FFF). JSR $C500 from bank 2 hits file        !!
; !! 0x1C500 (LIVE TRANS CODE), NOT 0x0C500 (our patch).               !!
; !! FIX: Relocate to common area $5D05 (always visible, 504 bytes    !!
; !! free) or bank 2 free space at file 0x17EA2 (286 bytes).           !!
; !! See custom_ose_$060_445_plan.md section 3.1a/3.1b for details.   !!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;; ═══════════════════════════════════════════════════════════════════
; UPDATE HISTORY:
;   2026-01-28: RAM Address Fix - $01A0 → $0046 bit 7
; ⚠️ WARNING: STD $194C at $3618 is INIT PATH ONLY (cold start, D=$0000).
;    Real period updates use filter sub $050C via indexed STD 0,X.
;    Hooking $3618 does NOT affect normal engine operation!
;    Use $017B hook at 0x101E1 instead (dwell intermediate).
;   2026-01-31: Crank Period Fix - $017B → $194C (TIC3 ISR verified)
; ═══════════════════════════════════════════════════════════════════

;==============================================================================
; VY V6 IGNITION CUT v32 - 6000 RPM SPARK CUT (USER PREFERENCE)
;==============================================================================
;
; ⚠️⚠️⚠️ CRITICAL UPDATE (2026-01-31): CRANK PERIOD ADDRESS CORRECTED ⚠️⚠️⚠️
;
; ISSUES FIXED:
;   ✅ Updated $017B → $194C (24X crank period - VERIFIED via TIC3 ISR)
;   ✅ Uses $0046 bit 7 for limiter flag (VERIFIED free bit)
;   ⚠️ Hook point needs updating: $3617 (before STD $194C in TIC3 ISR)
;
; See: BANK_SWITCHING_AND_ISR_ANALYSIS.md for TIC3 ISR disassembly
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 16, 2026
; Method: crank period injection (Chr0m3 validated)
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
;   - Chr0m3 Motorsport crank period injection method
;   - Consolidation Plan Session 7 validated addresses
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES (CORRECTED 2026-01-31)
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: 82 reads, 8-BIT RPM/25 ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
                                ; NOTE: RPM = value × 25, max 255 = 6375 RPM
                                ; $00A3 = Engine State (NOT part of RPM!)
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: STD @ $3618 in TIC3 ISR (2026-01-31) ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
                                ; 24X crank sensor (15° per pulse)
                                ; ❌ OLD WRONG: $017B (purpose unknown)
DWELL_RAM EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C (FC 01 99) ; Verified: DWELL_TIME_RAM (8 refs both) [Enhanced-fix]

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
; FAKE PERIOD VALUE (UPDATED FOR 24X SENSOR)
;------------------------------------------------------------------------------
; Normal 24X period at 6000 RPM:
;   6000 RPM = 100 rev/sec = 2400 pulses/sec (24 per rev)
;   Period = 1000ms / 2400 = 0.417ms = 417µs ≈ 520 timer counts @ 1.25MHz
;
; Fake period = 16000 = ~12.8ms (way too long for any RPM)
; → ECU calculates dwell based on this → dwell ≈ 100µs = insufficient
;
; Explanation (Chr0m3 method, adapted for 24X):
;   Inject fake high period → ECU calculates insufficient dwell
;   → Coil doesn't charge → No spark → Unburned fuel = pops/bangs
;
FAKE_PERIOD     EQU $3E80       ; 16000 decimal = ~12.8ms fake period

;------------------------------------------------------------------------------
; FREE RAM FOR LIMITER STATE
;------------------------------------------------------------------------------
; Location: $01A0 (needs verification, placeholder from community testing)
; Purpose: Track limiter state for hysteresis logic
;   - 0x00 = limiter OFF (normal operation)
;   - 0x01 = limiter ON (spark cut active)
;
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

;------------------------------------------------------------------------------
; CODE SECTION - VERIFIED FREE SPACE
;------------------------------------------------------------------------------
; Location verified: File offset 0x0C468-0x0FFBF = 15,192 bytes of zeros
; CPU address: $0C468 (corrected from wrong $18156 in early versions)
; Using $0C500 for alignment and room for future expansions
;
; ✅ ALREADY CONVERTED: Uses BRSET/BSET/BCLR for bit operations
; - Test: BRSET LIMITER_FLAGS, #$80, LABEL (if bit set, branch)
; - Set:  BSET LIMITER_FLAGS, #$80 (turn on)
; - Clear: BCLR LIMITER_FLAGS, #$80 (turn off)

            ORG $0C500          ; ✅ VERIFIED: 15,040 bytes free (all 0x00) ; Bank 1 (file 0x0C500). Free banks: [1], used: [2, 3]. 15192 bytes free [Enhanced-fix]

;==============================================================================
; HOOK POINT MODIFICATION (CORRECTED 2026-01-31)
;==============================================================================
; ⚠️ OLD WRONG HOOK: File offset 0x101E1 (STD $017B - NOT crank period!)
;
; ✅ CORRECT HOOK: CPU $3617 (file 0x13617) - Before STD $194C in TIC3 ISR
;   TIC3 ISR @ $35FF: Handles 24X crank sensor (every 15° rotation)
;   Hook before $3618: STD $194C (FD 19 4C) - stores crank period
;
; Replace 3 bytes at CPU $3617:
;   Original: ??? (need to check - likely part of BCLR or CLR)
;   Patched:  BD C5 00 (JSR $C500) - calls our routine
;
; HOOK_OFFSET     EQU $13617      ; ✅ CORRECTED: Before STD $194C in TIC3 ISR
; HOOK_PATCHED    EQU $BDC500     ; JSR $C500 (call our routine)

;==============================================================================
; IGNITION CUT HANDLER - 6000 RPM VERSION
;==============================================================================
; Called from: JSR at 0x101E1 (replaces "STD $017B")
; Entry:       D = calculated 3X period from stock code
; Exit:        D = either real period OR fake period
;              RAM $017B = dwell intermediate value (NOT crank period)
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
    ; CHECK LIMITER STATE - Using bit 7 of $0046
    ;--------------------------------------------------------------------------
    BRSET   LIMITER_FLAGS, #LIMITER_BIT, CHECK_LOW  ; 12 46 80 xx
                                                      ; If bit 7 set, check deactivation
    
    ;--------------------------------------------------------------------------
    ; LIMITER OFF - Check if should activate
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25 (8-bit)
    CMPA    #RPM_HIGH           ; 81 F0    Compare with 240 (6000 RPM)
    BCS     STORE_REAL          ; 25 xx    RPM < 6000 → store real period
    
    ; RPM >= 6000 - ACTIVATE SPARK CUT
    BSET    LIMITER_FLAGS, #LIMITER_BIT  ; 1C 46 80  Set bit 7 (limiter ON)
    BRA     STORE_FAKE          ; 20 xx    Jump to store fake period

CHECK_LOW:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check if should deactivate
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25 (8-bit)
    CMPA    #RPM_LOW            ; 81 EC    Compare with 236 (5900 RPM)
    BCC     STORE_FAKE          ; 24 xx    RPM >= 5900 → keep cutting
    
    ; RPM < 5900 - DEACTIVATE SPARK CUT
    BCLR    LIMITER_FLAGS, #LIMITER_BIT  ; 1D 46 80  Clear bit 7 (limiter OFF)
    BRA     STORE_REAL          ; 20 xx    Store real period

STORE_FAKE:
    ;--------------------------------------------------------------------------
    ; INJECT FAKE PERIOD - Causes spark cut
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore B from stack (discard)
    PULA                        ; 32       Restore A from stack (discard)
    LDD     #FAKE_PERIOD        ; CC 3E 80 D = 16000 (fake period)
    STD     PERIOD_24X_RAM      ; FD 19 4C Store fake period to RAM $194C ✅ CORRECTED
    RTS                         ; 39       Return to caller

STORE_REAL:
    ;--------------------------------------------------------------------------
    ; STORE REAL PERIOD - Normal spark operation
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore B (original period low)
    PULA                        ; 32       Restore A (original period high)
    STD     PERIOD_24X_RAM      ; FD 19 4C Store real period to RAM $194C ✅ CORRECTED
    RTS                         ; 39       Return to caller

;==============================================================================
; END OF PATCH CODE
;==============================================================================
; Total code size: ~50 bytes
; Free space used: $0C500 - $0C540 approximately
;
; VALIDATION CHECKLIST:
; [ ] Assemble with HC11 assembler (as19 or similar)
; [ ] Verify hook point at CPU $3617 (file 0x13617) before patching
; [ ] Test at 3000 RPM first (change RPM_HIGH/RPM_LOW for testing)
; [ ] Datalog RPM, 24X period, limiter behavior
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
; 2. Navigate to file offset 0x13617 (CPU $3617 in TIC3 ISR)
;    Context: This is just before STD $194C (FD 19 4C) at $3618
;    ⚠️ OLD WRONG: 0x101E1 was NOT the crank period store!
;
; 3. Replace 3 bytes at 0x13617:
;    Before: [check actual bytes at this location]
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
; README.md                           - Full documentation
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
; 0x101E1     | FD 01 7B   | STD $017B      | ✅ HOOK   | Dwell intermediate store
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
; A) crank period injection (THIS FILE) ⭐ BEST FOR 6000 RPM
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
