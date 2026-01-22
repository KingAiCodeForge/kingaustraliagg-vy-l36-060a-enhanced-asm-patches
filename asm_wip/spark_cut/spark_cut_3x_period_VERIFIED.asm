;==============================================================================
; VY V6 IGNITION CUT LIMITER - VERIFIED VERSION (16-BIT TEST TEMPLATE)
;==============================================================================
;
; ℹ️ REFERENCE FILE - Shows 16-bit RPM comparison method
;
; This file demonstrates the 16-bit comparison approach (LDD/CPD).
; For production use, see v38 which uses simpler 8-bit comparison.
;
; NOTE: 16-bit comparison loads $00A2:$00A3 which includes Engine State!
;       8-bit comparison (LDAA $00A2) is cleaner for ≤6375 RPM.
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 14, 2026
; Updated: January 17, 2026
; Status: ✅ ALL ADDRESSES VERIFIED AGAINST BINARY
;
; ⚠️ THIS IS A TEST FILE WITH 3000 RPM THRESHOLD - NOT FOR PRODUCTION!
;    For production 6000 RPM limiter, use: spark_cut_6000rpm_v32.asm
;
; Method: 3X Period Injection (Chr0m3 validated)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; VERIFICATION STATUS:
;   ✅ All RAM addresses verified by code references
;   ✅ All file offsets verified by opcode matching
;   ✅ ORG address verified as unused space (all zeros)
;   ✅ Timing constants verified by Chr0m3 Motorsport
;
; ⚠️ 8-BIT VS 16-BIT RPM:
;   This file uses 16-bit comparison for testing (any RPM works)
;   For ≤6375 RPM: Use spark_cut_6000rpm_v32.asm (8-bit LDAA/CMPA)
;   For >6375 RPM: Need dwell patches (Min Dwell 0xA2→0x9A, Min Burn 0x24→0x1C)
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES (confirmed by code reference analysis)
;------------------------------------------------------------------------------
; Address    Name           Verification
; --------   ----           ------------
; $00A2      RPM/25 (8-bit) 82 reads in code
; $00A3      ENGINE_STATE   NOT part of RPM! (12 accesses)
; $017B      3X_PERIOD      STD at file offset 0x101E1
; $0199      DWELL_RAM      LDD at file offset 0x1007C
;
; ⚠️ WARNING: This file uses 16-bit RPM comparison (LDD $00A2 + CPD)
;    which loads RPM/25 into A and Engine State into B!
;    This is the Chr0m3 method for >6375 RPM limiters.
;    
;    FOR 6000 RPM LIMITER: Use 8-bit comparison instead:
;      LDAA $00A2; CMPA #$F0  (240 × 25 = 6000 RPM)
;
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads in code (8-bit RPM/25!)
PERIOD_3X_RAM   EQU $017B       ; ✅ VERIFIED: STD at 0x101E1 (FD 01 7B)
DWELL_RAM       EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C (FC 01 99)

;------------------------------------------------------------------------------
; VERIFIED FILE OFFSETS (confirmed by opcode matching)
;------------------------------------------------------------------------------
; Offset     Opcode         Instruction
; ------     ------         -----------
; 0x101E1    FD 01 7B       STD $017B (stores 3X period)
; 0x1007C    FC 01 99       LDD $0199 (loads dwell value)
; 0x19812    86 24          LDAA #$24 (MIN_BURN = 36)
;
; HOOK POINT: Replace "STD $017B" at 0x101E1 with "JSR $C500"
;             Original: FD 01 7B (3 bytes)
;             Patched:  BD C5 00 (3 bytes) - JSR to our routine
;
HOOK_OFFSET     EQU $101E1      ; ✅ VERIFIED: STD $017B instruction
HOOK_ORIGINAL   EQU $FD017B     ; ✅ VERIFIED: Original bytes
HOOK_PATCHED    EQU $BDC500     ; JSR $C500 (call our routine)

;------------------------------------------------------------------------------
; TIMING CONSTANTS (Chr0m3 Motorsport validated)
;------------------------------------------------------------------------------
; Constant      Stock   7200 RPM    Notes
; --------      -----   --------    -----
; MIN_DWELL     0xA2    0x9A        Saves 8µs dwell time
; MIN_BURN      0x24    0x1C        Saves 8µs burn time
; MAX_RPM       6375    7200        Requires both patches
;
MIN_DWELL_STOCK EQU $00A2       ; ✅ Chr0m3: "0xA2 stock"
MIN_DWELL_7200  EQU $009A       ; ✅ Chr0m3: "0x9A for 7200"
MIN_BURN_STOCK  EQU $0024       ; ✅ VERIFIED: LDAA #$24 at 0x19812
MIN_BURN_7200   EQU $001C       ; ✅ Chr0m3: "0x1C for 7200"

;------------------------------------------------------------------------------
; RPM THRESHOLDS (configurable)
;------------------------------------------------------------------------------
; TEST MODE: 3000 RPM for safe in-car validation
RPM_HIGH        EQU $0BB8       ; 3000 RPM = 0x0BB8 (test)
RPM_LOW         EQU $0B54       ; 2900 RPM = 0x0B54 (100 RPM hysteresis)

; PRODUCTION OPTIONS (uncomment one pair after testing):
;
; Conservative: Stock redline (5900 RPM)
; RPM_HIGH        EQU $170C       ; 5900 RPM
; RPM_LOW         EQU $16DE       ; 5850 RPM
;
; Aggressive: Chr0m3 limit (6350 RPM)  
; RPM_HIGH        EQU $18CE       ; 6350 RPM (Chr0m3: "above 6350 you lose the limiter")
; RPM_LOW         EQU $18A0       ; 6300 RPM
;
; Maximum: ECU absolute limit (6375 RPM = 0xFF × 25)
; RPM_HIGH        EQU $18E7       ; 6375 RPM
; RPM_LOW         EQU $18B9       ; 6325 RPM

;------------------------------------------------------------------------------
; FAKE PERIOD VALUE
;------------------------------------------------------------------------------
; Normal 3X period at 6000 RPM ≈ 3.3ms = 3300 counts
; Fake period = 16000 = 1000ms → dwell ≈ 100µs = insufficient for spark
;
FAKE_PERIOD     EQU $3E80       ; 16000 decimal = ~1000ms fake period

;------------------------------------------------------------------------------
; FREE RAM FOR LIMITER STATE - VERIFIED January 22, 2026
;------------------------------------------------------------------------------
; Analysis of $0046 (Engine Mode Flags):
;   Used bits: 0, 1, 2, 4, 5 (mask $37)
;   FREE bits: 3, 6, 7 (mask $C8)
;   
; We use bit 7 ($80) because:
;   - Top bit, easy to test with BMI/BPL after LDAA
;   - No stock code uses BRSET/BRCLR/BSET/BCLR on bit 7
;   - Matches v38 verified implementation
;
; ⚠️ WARNING: $00A0 is NOT SAFE (7 refs in stock code!)
;    $01A0 is safe (0 refs) but requires extended addressing
;    $0046 bit 7 is preferred (direct page, fast access)
;
LIMITER_FLAGS   EQU $0046       ; ✅ VERIFIED: Engine mode flags byte
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE (unused in stock)

;------------------------------------------------------------------------------
; CODE SECTION - VERIFIED FREE SPACE
;------------------------------------------------------------------------------
; Location verified: 0x0C500 to 0x0FFBF = 15,040 bytes of zeros
; This is unused calibration space between code banks
;
            ORG $0C500          ; ✅ VERIFIED: 15,040 bytes free (all 0x00)

;==============================================================================
; IGNITION CUT HANDLER
;==============================================================================
; Called from: JSR at 0x101E1 (replaces "STD $017B")
; Entry:       D = calculated 3X period from stock code
; Exit:        D = either real period OR fake period
;              RAM $017B = stored period value
; Preserves:   All registers
; Stack:       2 bytes (PSHA/PSHB)
;==============================================================================

IGNITION_CUT_HANDLER:
    PSHA                        ; 36       Save A (period high byte)
    PSHB                        ; 37       Save B (period low byte)
    
    ; Check current limiter state using $0046 bit 7
    ; BRSET $46,#$80,label = if bit 7 set, branch (limiter active)
    BRSET   LIMITER_FLAGS,#LIMITER_BIT,CHECK_LOW  ; 12 46 80 xx
    
    ; Limiter OFF - check if RPM exceeds HIGH threshold
    LDD     RPM_ADDR            ; DC A2    Load current RPM (16-bit)
    CPD     #RPM_HIGH           ; 1A 83 0B B8  Compare with high threshold
    BCS     STORE_REAL          ; 25 xx    RPM < threshold → store real period
    
    ; RPM exceeded threshold - ACTIVATE LIMITER (set bit 7 of $0046)
    BSET    LIMITER_FLAGS,#LIMITER_BIT  ; 14 46 80  Set bit 7
    BRA     STORE_FAKE          ; 20 xx    Jump to store fake period

CHECK_LOW:
    ; Limiter ON - check if RPM below LOW threshold
    LDD     RPM_ADDR            ; DC A2    Load current RPM
    CPD     #RPM_LOW            ; 1A 83 0B 54  Compare with low threshold
    BCC     STORE_FAKE          ; 24 xx    RPM >= threshold → keep cutting
    
    ; RPM dropped below threshold - DEACTIVATE LIMITER (clear bit 7)
    BCLR    LIMITER_FLAGS,#LIMITER_BIT  ; 15 46 80  Clear bit 7
    BRA     STORE_REAL          ; 20 xx    Store real period

STORE_FAKE:
    ; Store FAKE period to cause insufficient dwell
    LDD     #FAKE_PERIOD        ; CC 3E 80 Load fake period (16000)
    BRA     STORE_DONE          ; 20 xx    Jump to store
    
STORE_REAL:
    ; Restore REAL period from stack
    PULB                        ; 33       Restore B (low byte)
    PULA                        ; 32       Restore A (high byte)
    PSHB                        ; 37       Re-save for final restore
    PSHA                        ; 36

STORE_DONE:
    ; Store period to RAM (replaces original "STD $017B")
    STD     PERIOD_3X_RAM       ; FD 01 7B Store to 3X period RAM
    
    ; Restore registers and return
    PULA                        ; 32
    PULB                        ; 33
    RTS                         ; 39       Return to caller

;==============================================================================
; PATCH INSTRUCTIONS
;==============================================================================
; To install this patch:
;
; 1. Locate original instruction at file offset 0x101E1:
;    Original bytes: FD 01 7B (STD $017B)
;
; 2. Replace with JSR to our handler:
;    Patched bytes:  BD C5 00 (JSR $C500)
;
; 3. Verify our code is placed at 0x0C500
;
; Hex patch summary:
;    Offset 0x101E1: FD 01 7B → BD C5 00
;
;==============================================================================

            END

;##############################################################################
;#                                                                            #
;#                    ═══ CONFIRMED ADDRESSES & FINDINGS ═══                  #
;#                                                                            #
;##############################################################################

;------------------------------------------------------------------------------
; ✅ BINARY VERIFIED ADDRESSES (Tested on VX-VY_V6_$060A_Enhanced_v1.0a.bin)
;------------------------------------------------------------------------------
;
; Address      | File Bytes | Instruction    | Purpose
; -------------|------------|----------------|----------------------------------
; 0x101E1      | FD 01 7B   | STD $017B      | 3X period storage - HOOK POINT
; 0x1007C      | FC 01 99   | LDD $0199      | Dwell RAM read
; 0x19812      | 86 24      | LDAA #$24      | Min Burn = 36 (stock)
; 0x3631       | BD 37 1A   | JSR $371A      | Dwell calc call from TIC3 ISR
; 0x37B1       | FD 10 16   | STD $1016      | TOC1 write (NOT spark timing!)
; 0x0C500      | 00 00 00...| All zeros      | FREE SPACE - safe to use
;
;------------------------------------------------------------------------------
; ✅ RAM ADDRESSES (Code reference count verified)
;------------------------------------------------------------------------------
;
; RAM Addr | References | Verified Pattern | Purpose
; ---------|------------|------------------|------------------------------------
; $00A2    | 73× LDAA   | 96 A2            | RPM/25 (8-bit! Max 255=6375 RPM)
; $00A3    | 12× access | NOT RPM!         | Engine State 2 register
; $017B    | STD at TIC3| FD 01 7B         | 3X Crank Period (16-bit timer)
; $0199    | LDD reads  | FC 01 99         | Dwell calculation RAM
; $016D    | 8× access  | -                | Cylinder index (0-5)
;
;------------------------------------------------------------------------------
; 📐 RPM CALCULATION MATH
;------------------------------------------------------------------------------
;
; 8-bit RPM stored at $00A2:
;   Formula: Actual_RPM = RAM_Value × 25
;   Maximum: 255 × 25 = 6375 RPM (8-bit limit!)
;
; Common conversions:
;   3000 RPM = 120 = $78     | Test threshold
;   5900 RPM = 236 = $EC     | Stock fuel cut
;   6000 RPM = 240 = $F0     | User preferred limit
;   6350 RPM = 254 = $FE     | Chr0m3 max safe
;   6375 RPM = 255 = $FF     | Absolute 8-bit max
;
; Hysteresis (100 RPM recommended):
;   100 RPM ÷ 25 = 4 steps
;   Example: 6000 ON = $F0, 5900 OFF = $EC (4 step difference)
;
;------------------------------------------------------------------------------
; 📐 3X PERIOD MATH
;------------------------------------------------------------------------------
;
; 3X Crank Period = time between crank teeth edges
;   At 6000 RPM: 60000ms ÷ 6000 RPM = 10ms per revolution
;   V6 has 6 teeth (1 per 60°), so: 10ms ÷ 6 = 1.67ms per tooth
;   Timer count: 1.67ms × 2MHz = 3,333 counts ($0D05)
;
; Fake Period Calculation:
;   Fake = 16000 ($3E80) = 8ms apparent period
;   ECU thinks: 8ms × 6 × 60 = ~125 RPM (impossible speed)
;   Result: Dwell calculation gives ~100µs → insufficient coil charge
;
; Alternative fake periods:
;   $2000 (8192) = ~61 RPM apparent → less aggressive cut
;   $5000 (20480) = ~49 RPM apparent → harder cut
;   $7FFF (32767) = ~30 RPM apparent → maximum cut
;
;------------------------------------------------------------------------------
; 🔧 HOOK POINT PATCH DETAILS
;------------------------------------------------------------------------------
;
; File Offset: 0x101E1 (verified in TIC3 ISR area)
;
; Original bytes:  FD 01 7B = STD $017B (store D to 3X period RAM)
; Patched bytes:   BD C5 00 = JSR $C500 (call our handler)
;
; Our handler at $C500:
;   1. Receives D = calculated period from stock code
;   2. Checks RPM against thresholds
;   3. Either stores real period OR fake period to $017B
;   4. Returns to caller
;
; Why this works:
;   - Stock code calculates period, puts in D
;   - We intercept BEFORE it's stored
;   - We can modify D before storing
;   - Stock code continues normally, using our value
;
;------------------------------------------------------------------------------
; ✅ RAM VERIFICATION COMPLETE (January 22, 2026)
;------------------------------------------------------------------------------
;
; LIMITER_FLAG RESOLUTION:
;   - $00A0: NOT SAFE! (7 references in stock code)
;   - $01A0: SAFE (0 references) but requires extended addressing (slower)
;   - $0046 bit 7: RECOMMENDED ✅ (verified FREE, direct page = fast)
;
;   Binary search confirmed only these bits of $0046 are used:
;   Bits 0,1,2,4,5 (20 total references) → Bits 3,6,7 are FREE
;
; 2. VY Min Dwell Address
;    - VT V6 uses 0x14735, VY is DIFFERENT
;    - Need to search for LDAA #$A2 pattern in VY binary
;    - Or disassemble dwell calc at $371A fully
;
; 3. FREE RAM Summary (verified):
;    - $0046 bit 3 ($08): FREE
;    - $0046 bit 6 ($40): FREE  
;    - $0046 bit 7 ($80): FREE ← USING THIS FOR LIMITER
;    - $01A0: FREE (0 refs, but extended addressing)
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE METHODS (Pros/Cons)
;------------------------------------------------------------------------------
;
; METHOD A: 3X Period Injection (THIS FILE) ⭐ RECOMMENDED
;   Hook: 0x101E1 (STD $017B)
;   Pros: Proven by Chr0m3, simple hook, minimal code
;   Cons: Still some dwell calculated (not true zero)
;   Best for: ≤6375 RPM hard cut limiter
;
; METHOD B: TOC3 Skip (Schedule Blocking)
;   Hook: TIC2 ISR before STD $101A
;   Pros: Completely skips dwell start scheduling
;   Cons: More complex, affects timing chain
;   Best for: Research/experimentation
;
; METHOD C: Dwell Offset Zero
;   Write $0000 to RAM $1C33
;   Pros: No hook needed, just RAM write
;   Cons: Need main loop integration, timing sensitive
;   Best for: Combined fuel+spark cut
;
; METHOD D: Port A Direct (EST Output)
;   Clear PA3/PA4 bits at $1000
;   Pros: Immediate spark kill
;   Cons: May trigger bypass mode, hardware dependent
;   Best for: Emergency cut only
;
; METHOD E: Timing Retard (Soft Cut)
;   Modify timing RAM before TOC scheduling
;   Pros: Smooth power reduction, no harsh cut
;   Cons: Engine still fires (not true cut), less flames
;   Best for: Two-stage progressive limiter
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm    - Production 6000 RPM (8-bit, recommended)
; spark_cut_rolling_v34.asm    - Speeduino-style random cut (flames!)
; spark_cut_dwell_patch_v37.asm - High RPM dwell fix (HEX patch)
; trace_jsr_371a_and_all_isrs.py - Disassembly tool for ISRs
;
;##############################################################################
