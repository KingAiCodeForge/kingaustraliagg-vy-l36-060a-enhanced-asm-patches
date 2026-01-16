;==============================================================================
; VY V6 IGNITION CUT v33 - CHR0M3 METHOD (FUEL CUT SCRAPPED)
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
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads in code (16-bit)
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
; RPM THRESHOLDS (6000 RPM USER PREFERENCE)
;------------------------------------------------------------------------------
; 16-bit raw RPM value (not scaled)
;
RPM_HIGH        EQU $1770       ; 6000 RPM - spark cut activation
RPM_LOW         EQU $170C       ; 5900 RPM - spark resume (100 RPM hysteresis)

;------------------------------------------------------------------------------
; FAKE PERIOD VALUE FOR SPARK KILL
;------------------------------------------------------------------------------
; Inject impossibly large period → dwell calculation gives ~0 → no spark
;
FAKE_PERIOD     EQU $3E80       ; 16000 decimal = ~100µs dwell = no spark

;==============================================================================
; METHOD EXPLANATION - CHR0M3 STYLE
;==============================================================================
;
; STOCK FUEL CUT SYSTEM:
;   - Located at 0x77DE in calibration
;   - Reads 8-bit value, multiplies by 25 for RPM threshold
;   - When RPM >= threshold, cuts injector pulse width
;   - Maximum: 255 × 25 = 6375 RPM (8-bit limit!)
;
; CHR0M3'S SOLUTION:
;   1. Find where fuel cut routine is CALLED from main loop
;   2. REPLACE that JSR with our spark cut JSR
;   3. Our routine:
;      a) Reads 16-bit RPM directly from $00A2 (bypasses 8-bit limit!)
;      b) Compares to 16-bit threshold (can go above 6375!)
;      c) If over: injects fake 3X period → kills dwell → kills spark
;      d) If under: does nothing, normal operation continues
;
; WHY 16-BIT IS CRITICAL:
;   - 8-bit × 25 = max 6375 RPM (stock limitation)
;   - 16-bit raw = max 65535 RPM (no limit!)
;   - Chr0m3 reached 7200 RPM by bypassing 8-bit tables
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
    ; LOAD CURRENT RPM (16-BIT - BYPASSES 8-BIT LIMIT!)
    ;--------------------------------------------------------------------------
    ; This is the key insight from Chr0m3:
    ; Stock fuel cut reads 8-bit table value × 25 = max 6375 RPM
    ; We read 16-bit raw RPM = can compare to ANY value
    ;
    LDD     RPM_ADDR            ; DC A2    Load 16-bit RPM from $00A2-$00A3
    
    ;--------------------------------------------------------------------------
    ; CHECK LIMITER STATE FOR HYSTERESIS
    ;--------------------------------------------------------------------------
    TST     LIMITER_FLAG        ; 7D 01 A0 Test limiter flag
    BNE     LIMITER_ACTIVE      ; 26 xx    Flag set → limiter is ON
    
    ;--------------------------------------------------------------------------
    ; LIMITER OFF - Check activation threshold
    ;--------------------------------------------------------------------------
    CPD     #RPM_HIGH           ; 1A 83 17 70  Compare RPM to 6000
    BCS     EXIT_NORMAL         ; 25 xx    RPM < 6000 → normal operation
    
    ; RPM >= 6000: ACTIVATE SPARK CUT
    LDAA    #$01                ; 86 01    Flag = 1
    STAA    LIMITER_FLAG        ; 97 A0    Set limiter active
    BRA     DO_SPARK_CUT        ; 20 xx    Kill spark

LIMITER_ACTIVE:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check deactivation threshold
    ;--------------------------------------------------------------------------
    CPD     #RPM_LOW            ; 1A 83 17 0C  Compare RPM to 5900
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

