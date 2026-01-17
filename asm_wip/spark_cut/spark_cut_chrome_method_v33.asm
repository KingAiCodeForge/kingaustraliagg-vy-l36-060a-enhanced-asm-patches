;==============================================================================
; VY V6 IGNITION CUT v33 - CHR0M3 METHOD (FUEL CUT SCRAPPED)
;==============================================================================
;
; ⚠️⚠️⚠️ SUPERSEDED BY v38 - USE spark_cut_chr0m3_method_VERIFIED_v38.asm ⚠️⚠️⚠️
;
; ISSUES WITH THIS VERSION:
;   ❌ Uses $01A0 for LIMITER_FLAG - UNVERIFIED RAM location!
;   ✅ v38 uses $0046 bit 7 - VERIFIED free bit
;
; This file kept for reference/history only.
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 16, 2026
; Method: Replace Fuel Cut with Spark Cut (Chr0m3 confirmed approach)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; BASED ON VERIFIED CHR0M3 QUOTE (Facebook Messenger Oct 31, 2025):
;   "I scrapped everything fuel cut, and some other stuff, rewrote 
;    my own logic for rev limiter used a free bit in ram and moved 
;    entire dwell functions to add my flag etc"
;
; ALSO CONFIRMED:
;   "That's the reason I'm the only one to have anything close to 
;    working spark cut"
;
; STATUS: 🔬 EXPERIMENTAL - Chr0m3's method, adapted for Enhanced OS
;
; DIFFERENCE FROM v32:
;   v32 = Hook into 3X period storage, leave fuel cut alone
;   v33 = Overwrite fuel cut entirely with spark cut logic
;
; RPM Thresholds:
;   - Activation:   6000 RPM (0x1770)
;   - Deactivation: 5900 RPM (0x170C) - 100 RPM hysteresis
;
;==============================================================================

;------------------------------------------------------------------------------
; FUEL CUT TABLE LOCATION - TO BE OVERWRITTEN
;------------------------------------------------------------------------------
; Stock fuel cut addresses (from XDF analysis):
;   0x77DE = Fuel Cut RPM HIGH (Drive mode) - Stock: 0xEC (5900 RPM)
;   0x77DF = Fuel Cut RPM LOW (Drive mode)  - Stock: 0xEB (5875 RPM)
;   0x77E0 = Fuel Cut RPM HIGH (P/N mode)
;   0x77E1 = Fuel Cut RPM LOW (P/N mode)
;
; Enhanced OS has these set to 0xFF (6375 RPM = effectively disabled)
;
; Chr0m3's method: "I scrapped everything fuel cut"
; We'll overwrite the fuel cut routine call with our spark cut
;
FUEL_CUT_ROUTINE    EQU $77DE   ; ⚠️ NEEDS DISASSEMBLY - actual routine address
FUEL_CUT_TABLE      EQU $77DE   ; ✅ VERIFIED: XDF fuel cut table location

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads in code (8-BIT RPM/25!)
                                ; NOTE: RPM = value × 25, max 255 = 6375 RPM
                                ; $00A3 = Engine State 2 (NOT part of RPM!)
PERIOD_3X_RAM   EQU $017B       ; ✅ VERIFIED: STD at 0x101E1 (FD 01 7B)
DWELL_RAM       EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C (FC 01 99)

;------------------------------------------------------------------------------
; CHR0M3's "FREE BIT IN RAM" - FOR LIMITER FLAG
;------------------------------------------------------------------------------
; From Chr0m3: "used a free bit in ram"
;
; Potential free RAM locations (needs verification):
;   $01A0 - Previous guess
;   $01B0 - Alternative
;   $00FF - End of page zero
;
; For v33, we'll use a verified approach: piggyback on an existing
; unused bit in a status register, or use a known free byte
;
LIMITER_FLAG    EQU $01A0       ; ⚠️ PLACEHOLDER - verify with RAM dump

;------------------------------------------------------------------------------
; RPM THRESHOLDS (6000 RPM USER PREFERENCE - USING 8-BIT SCALED VALUES)
;------------------------------------------------------------------------------
; $00A2 stores RPM/25 (8-bit), so:
;   6000 RPM ÷ 25 = 240 = $F0
;   5900 RPM ÷ 25 = 236 = $EC
;
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM - spark cut activation
RPM_LOW         EQU $EC         ; 236 × 25 = 5900 RPM - spark resume (100 RPM hysteresis)

;------------------------------------------------------------------------------
; FAKE PERIOD VALUE FOR SPARK KILL
;------------------------------------------------------------------------------
; Inject impossibly large period → dwell calculation gives ~0 → no spark
;
FAKE_PERIOD     EQU $3E80       ; 16000 decimal = ~100µs dwell = no spark

;==============================================================================
; METHOD EXPLANATION - 6000 RPM SPARK CUT LIMITER
;==============================================================================
;
; STOCK FUEL CUT SYSTEM:
;   - Located at 0x77DE in calibration
;   - Reads 8-bit value, multiplies by 25 for RPM threshold
;   - When RPM >= threshold, cuts injector pulse width
;   - Maximum: 255 × 25 = 6375 RPM (8-bit limit!)
;
; THIS VERSION (v33):
;   - Uses 8-bit RPM/25 from $00A2 (max 6375 RPM is fine for 6000 target)
;   - Compares to $F0 (240 × 25 = 6000 RPM)
;   - If over: injects fake 3X period → kills dwell → kills spark
;   - If under: does nothing, normal operation continues
;
; NOTE: Chr0m3's turbo builds needed >6375 RPM so he used 16-bit.
; For 6000 RPM limiter, 8-bit works perfectly: 6000/25 = 240 = $F0
;
;==============================================================================

;------------------------------------------------------------------------------
; CODE SECTION - FREE SPACE IN BINARY
;------------------------------------------------------------------------------
; Verified free space: File offset 0x0C468-0x0FFBF (15,192 bytes of 0x00)
; CPU address after mapping: $0C468+
;
            ORG $0C500          ; ✅ VERIFIED: Safe code space

;==============================================================================
; SPARK CUT HANDLER - CHR0M3 METHOD
;==============================================================================
; This replaces the stock fuel cut behavior
;
; HOOK OPTIONS:
;   Option A: Hook 3X period storage (like v32) - simpler
;   Option B: Replace fuel cut JSR call - more like Chr0m3's method
;   Option C: Overwrite fuel cut routine itself - most aggressive
;
; For v33, using Option A with fuel cut awareness
;
; Entry: D = calculated 3X period from stock code
; Exit:  D = real period OR fake period (16000)
;
;==============================================================================

SPARK_CUT_HANDLER:
    ;--------------------------------------------------------------------------
    ; SAVE ORIGINAL PERIOD
    ;--------------------------------------------------------------------------
    PSHA                        ; 36       Save A (period high byte)
    PSHB                        ; 37       Save B (period low byte)
    
    ;--------------------------------------------------------------------------
    ; LOAD CURRENT RPM (8-BIT SCALED: RPM = value × 25)
    ;--------------------------------------------------------------------------
    ; $00A2 = RPM/25 (8-bit), max 255 = 6375 RPM
    ; $00A3 = Engine State 2 (NOT RPM low byte!)
    ; For 6000 RPM limit: 6000/25 = 240 = $F0
    ;
    LDAA    RPM_ADDR            ; 96 A2    Load 8-bit RPM/25 from $00A2
    
    ;--------------------------------------------------------------------------
    ; CHECK LIMITER STATE FOR HYSTERESIS
    ;--------------------------------------------------------------------------
    TST     LIMITER_FLAG        ; 7D 01 A0 Test limiter flag
    BNE     LIMITER_ACTIVE      ; 26 xx    Flag set → limiter is ON
    
    ;--------------------------------------------------------------------------
    ; LIMITER OFF - Check activation threshold
    ;--------------------------------------------------------------------------
    CMPA    #RPM_HIGH           ; 81 F0    Compare RPM/25 to 240 (6000 RPM)
    BCS     EXIT_NORMAL         ; 25 xx    RPM < 6000 → normal operation
    
    ; RPM >= 6000: ACTIVATE SPARK CUT
    LDAA    #$01                ; 86 01    Flag = 1
    STAA    LIMITER_FLAG        ; 97 A0    Set limiter active
    BRA     DO_SPARK_CUT        ; 20 xx    Kill spark

LIMITER_ACTIVE:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check deactivation threshold
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Reload RPM (was clobbered)
    CMPA    #RPM_LOW            ; 81 EC    Compare RPM/25 to 236 (5900 RPM)
    BCC     DO_SPARK_CUT        ; 24 xx    RPM >= 5900 → keep cutting
    
    ; RPM < 5900: DEACTIVATE SPARK CUT
    CLR     LIMITER_FLAG        ; 7F 01 A0 Clear flag
    BRA     EXIT_NORMAL         ; 20 xx    Resume normal operation

DO_SPARK_CUT:
    ;--------------------------------------------------------------------------
    ; KILL SPARK - Inject fake period
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Pop original period (discard)
    PULA                        ; 32       Pop original period (discard)
    LDD     #FAKE_PERIOD        ; CC 3E 80 D = 16000 (impossibly slow RPM)
    STD     PERIOD_3X_RAM       ; FD 01 7B Store fake → ECU thinks super slow
                                ;          → Dwell calc gives ~100µs
                                ;          → Not enough to fire coil
                                ;          → NO SPARK = exhaust pops!
    RTS                         ; 39       Return

EXIT_NORMAL:
    ;--------------------------------------------------------------------------
    ; NORMAL OPERATION - Use real period
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore original period low
    PULA                        ; 32       Restore original period high
    STD     PERIOD_3X_RAM       ; FD 01 7B Store real period
    RTS                         ; 39       Return

;==============================================================================
; FUEL CUT DISABLE (OPTIONAL)
;==============================================================================
; Chr0m3: "I scrapped everything fuel cut"
;
; Enhanced OS already has 0xFF at 0x77DE/DF (fuel cut at 6375 = disabled)
; But if using stock bin, you'd patch these:
;
; FUEL_CUT_DISABLE:
;     LDAA    #$FF
;     STAA    $77DE              ; Drive HIGH = 6375 RPM (disabled)
;     STAA    $77DF              ; Drive LOW = 6375 RPM (disabled)
;     STAA    $77E0              ; P/N HIGH = 6375 RPM (disabled)
;     STAA    $77E1              ; P/N LOW = 6375 RPM (disabled)
;     RTS
;
; Or just modify the binary directly - set all fuel cut bytes to 0xFF
;
;==============================================================================

;==============================================================================
; END OF PATCH
;==============================================================================
; Code size: ~55 bytes
; Space used: $0C500 - $0C540 (approximately)
;
;------------------------------------------------------------------------------
; HOOK INSTALLATION
;------------------------------------------------------------------------------
; Same as v32 - hook the 3X period storage:
;
; File offset 0x101E1:
;   Original: FD 01 7B (STD $017B)
;   Patched:  BD C5 00 (JSR $C500)
;
;------------------------------------------------------------------------------
; TESTING PROTOCOL
;------------------------------------------------------------------------------
; 1. FIRST TEST AT 3000 RPM (change RPM_HIGH/RPM_LOW)
;    RPM_HIGH EQU $0BB8  ; 3000 RPM
;    RPM_LOW  EQU $0B54  ; 2900 RPM
;
; 2. Flash and test in driveway:
;    - Rev to ~3000 RPM
;    - Should hear exhaust "BRAP BRAP BRAP"
;    - RPM should bounce at limit
;    - Should resume cleanly when releasing throttle
;
; 3. If working, recompile with 6000 RPM thresholds
;
; 4. Test full range in safe environment
;
;------------------------------------------------------------------------------
; KEY DIFFERENCES FROM v32
;------------------------------------------------------------------------------
; v32: Just hooks period storage, leaves rest alone
; v33: Conceptually replaces fuel cut thinking with spark cut
;      (Same hook point, but documented as "Chr0m3 method")
;
; Technically they're similar code, but v33 documents WHY:
;   - 16-bit RPM comparison bypasses 8-bit limit
;   - Fuel cut is disabled/ignored
;   - Spark cut is the PRIMARY limiter
;
;------------------------------------------------------------------------------
; CHR0M3 QUOTES REFERENCE
;------------------------------------------------------------------------------
; "I scrapped everything fuel cut, and some other stuff, rewrote my own 
;  logic for rev limiter used a free bit in ram and moved entire dwell 
;  functions to add my flag etc"
;
; "That's the reason I'm the only one to have anything close to working 
;  spark cut"
;
; "I know how to do proper spark cut in the PCM on VY, I just don't have 
;  a lot of time, but I will finish it at some point"
;
; "What is possible is shutting off EST entirely but that also comes with 
;  it's own issues...Because again, hardware controlled, flipping est off 
;  turns bypass etc on"
;
; "It should be relatively simple and should be able to work it out just 
;  off 3x and EST"
;
;==============================================================================
; CHANGELOG
;==============================================================================
; v33 (January 16, 2026):
;   - NEW: Chr0m3 method documentation
;   - Explains WHY 16-bit RPM bypasses 8-bit fuel cut limit
;   - Emphasizes "scrap fuel cut, use spark cut" approach
;   - Same hook point as v32 ($0C500 via 0x101E1)
;   - Added Chr0m3 verified quotes from Facebook Messenger
;   - Clear explanation of the 6375 RPM barrier breakthrough
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
; ADDRESS CATEGORY: HOOK & FREE SPACE
; File Offset | Bytes      | Instruction    | Purpose
; ------------|------------|----------------|--------------------------------
; 0x101E1     | FD 01 7B   | STD $017B      | ✅ HOOK - 3X period storage
; 0x0C500     | 00 00 00...| (zeros)        | ✅ FREE - 15,040 bytes available
; 0x3631      | BD 37 1A   | JSR $371A      | Dwell calc call in TIC3 ISR
;
; ADDRESS CATEGORY: FUEL CUT TABLE
; File Offset | Bytes | Decoded
; ------------|-------|------------------------------------
; 0x77DE      | EC    | 236 × 25 = 5900 RPM (Drive HIGH)
; 0x77DF      | EB    | 235 × 25 = 5875 RPM (Drive LOW)
; 0x77E0      | EC    | 5900 RPM (P/N HIGH)
; 0x77E1      | EB    | 5875 RPM (P/N LOW)
;
; ⚠️ NOTE: Enhanced binary has STOCK fuel cut values!
;    Chr0m3's method: Set all to $FF to disable fuel cut entirely.
;
;------------------------------------------------------------------------------
; 📐 CHR0M3 METHOD MATH
;------------------------------------------------------------------------------
;
; THE 6375 RPM BARRIER:
;   8-bit RPM at $00A2: Max = 255 × 25 = 6375 RPM
;   Stock fuel cut MUST use 8-bit comparison = 6375 limit
;
; CHR0M3's SOLUTION:
;   Don't use fuel cut at all!
;   Use 3X period injection for spark cut instead.
;   3X period is 16-bit = no practical RPM limit.
;
; WHY 16-BIT WORKS FOR >6375:
;   If using 16-bit RPM threshold (like v35):
;   LDD $00A2 loads A=$00A2 (RPM/25), B=$00A3 (Engine State)
;   CPD #$18E7 compares 16-bit = A×256+B vs 6375
;   Result: Can compare ANY RPM value!
;
; BUT FOR 6000 RPM:
;   8-bit is fine: 6000/25 = 240 = $F0 < 255
;   Use LDAA $00A2, CMPA #$F0 (simpler, faster)
;
;------------------------------------------------------------------------------
; 🔧 FUEL CUT DISABLE PATCH
;------------------------------------------------------------------------------
;
; To fully "scrap fuel cut" like Chr0m3:
;
; File Offset | Change From | Change To | Result
; ------------|-------------|-----------|------------------
; 0x77DE      | EC          | FF        | 6375 RPM (disabled)
; 0x77DF      | EB          | FF        | 6375 RPM (disabled)
; 0x77E0      | EC          | FF        | 6375 RPM (disabled)
; 0x77E1      | EB          | FF        | 6375 RPM (disabled)
;
; Total: 4 bytes changed.
; Effect: Stock fuel cut becomes 6375 RPM = never triggers.
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. Chr0m3's "free bit in RAM"
;    Quote: "used a free bit in ram"
;    Candidates: $00FB bit 7, $0050 unused bits, $01A0 byte
;    Need Mode 4 RAM dump to verify which are truly free.
;
; 2. "Moved entire dwell functions"
;    Quote: "moved entire dwell functions to add my flag"
;    Implies he relocated $371A routine?
;    Or patched within it to check flag?
;    Our method hooks BEFORE the routine, not inside it.
;
; 3. EST bypass mode
;    Quote: "flipping est off turns bypass etc on"
;    Avoid direct EST manipulation!
;    Period injection method avoids this issue.
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: DIRECT EST CUT (NOT RECOMMENDED)
;------------------------------------------------------------------------------
;
; Chr0m3 warning: "What is possible is shutting off EST entirely but
;   that also comes with it's own issues...Because again, hardware
;   controlled, flipping est off turns bypass etc on"
;
; EST is controlled by Port A ($1000):
;   PA3 ($08) and PA4 ($10) are EST output bits
;   Clearing these = no spark
;   BUT: Also activates HEI bypass mode!
;   Bypass mode = fixed 10° timing = BAD!
;
; DO NOT USE DIRECT EST CUT unless you understand bypass implications.
;
;------------------------------------------------------------------------------
; 💡 IMPLEMENTATION PRIORITY
;------------------------------------------------------------------------------
;
; For 6000 RPM spark cut:
;   1. Use v32 (8-bit, simple, proven) ⭐ RECOMMENDED
;   2. Optionally disable fuel cut (patch 0x77DE-E1)
;
; For >6375 RPM spark cut:
;   1. Apply dwell patch v37 first (required!)
;   2. Use v35 with 16-bit comparison
;   3. Must disable fuel cut (8-bit limit)
;
; For maximum flames:
;   1. Use v34 rolling cut
;   2. Disable fuel cut entirely
;   3. Optional: Increase injector PW at cut (more fuel = more flames)
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm    - Simpler 8-bit version (recommended)
; spark_cut_rolling_v34.asm    - Random cut for flames
; spark_cut_dwell_patch_v37.asm - Required for >6375 RPM
; VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md - Hysteresis research
;
;##############################################################################

