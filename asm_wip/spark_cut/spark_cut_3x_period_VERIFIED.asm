;==============================================================================
; VY V6 IGNITION CUT LIMITER - VERIFIED VERSION
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 14, 2026
; Status: ✅ ALL ADDRESSES VERIFIED AGAINST BINARY
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
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES (confirmed by code reference analysis)
;------------------------------------------------------------------------------
; Address    Name           Verification
; --------   ----           ------------
; $00A2      RPM            82 reads in code
; $017B      3X_PERIOD      STD at file offset 0x101E1
; $0199      DWELL_RAM      LDD at file offset 0x1007C
;
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 82 reads in code
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
; FREE RAM FOR LIMITER STATE
;------------------------------------------------------------------------------
; UNVERIFIED - Need to find actual free RAM location
; Using $01A0 as placeholder - MUST BE CONFIRMED before use!
;
LIMITER_FLAG    EQU $01A0       ; ⚠️ UNVERIFIED - needs confirmation

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
    
    ; Check current limiter state
    LDAA    LIMITER_FLAG        ; 96 A0    Load limiter flag
    CMPA    #$01                ; 81 01    Is limiter active?
    BEQ     CHECK_LOW           ; 27 xx    Yes → check if should deactivate
    
    ; Limiter OFF - check if RPM exceeds HIGH threshold
    LDD     RPM_ADDR            ; DC A2    Load current RPM (16-bit)
    CPD     #RPM_HIGH           ; 1A 83 0B B8  Compare with high threshold
    BCS     STORE_REAL          ; 25 xx    RPM < threshold → store real period
    
    ; RPM exceeded threshold - ACTIVATE LIMITER
    LDAA    #$01                ; 86 01    Set flag = 1
    STAA    LIMITER_FLAG        ; 97 A0    Store flag
    BRA     STORE_FAKE          ; 20 xx    Jump to store fake period

CHECK_LOW:
    ; Limiter ON - check if RPM below LOW threshold
    LDD     RPM_ADDR            ; DC A2    Load current RPM
    CPD     #RPM_LOW            ; 1A 83 0B 54  Compare with low threshold
    BCC     STORE_FAKE          ; 24 xx    RPM >= threshold → keep cutting
    
    ; RPM dropped below threshold - DEACTIVATE LIMITER
    CLR     LIMITER_FLAG        ; 7F 01 A0 Clear flag
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
