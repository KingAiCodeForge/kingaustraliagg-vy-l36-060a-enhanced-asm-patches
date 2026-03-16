;==============================================================================
; VY V6 SPARK CUT v44 — 11P STYLE, CROSS-BANK BUG FIXED
;==============================================================================
;
; v44 CHANGES from v42:
;   FIXED: Code relocated from $C500 (bank1 overlay) to $5D05 (always visible)
;          The hook at 0x101E1 is in BANK 2. JSR $C500 from bank2 would hit
;          bank2's $C500 (file 0x1C500 = LIVE TRANS CODE), not our patch.
;          $5D05 is in the always-visible $2000-$7FFF range — works from
;          any bank context. No cross-bank issues possible.
;
;   Source: VL400's OSE 11P dwell starvation method
;   Port by: Jason King (kingaustraliagg) — Feb 25, 2026
;   Target: VX/VY V6 $060A Enhanced v1.0a (92118883)
;   Processor: 68HC11FC0 (IPCM-6)
;
; HOW IT WORKS:
;   Hook the STD $017B instruction at file 0x101E1 (dwell intermediate store)
;   When RPM >= threshold: inject fake 3X period $3E80 → dwell starves to
;   ~100-200µs → coil can't build enough field → no spark
;   When RPM drops below return threshold: restore real dwell value
;   EST line continues — no bypass mode, no DFI takeover (same as 11P)
;
; DWELL PATCHING NOT NEEDED at 3000 or 6000 RPM:
;   Timer budget: MIN_DWELL($A2=162) + MIN_BURN($24=36) = 198 counts
;   At 3000 RPM: 3X period = 437 counts → 239 count margin → safe
;   At 6000 RPM: 3X period = 219 counts →  21 count margin → safe
;   Only needed above ~6500 RPM where period < 198 and burn wraps
;
; CAL vs BIN FLASH:
;   Hook is in Sector 4 (bank2, file 0x10000-0x13FFF)
;   Code is in Sector 1 (always-visible, file 0x04000-0x07FFF) ← CAL area!
;   BUT the hook modification itself is NOT in the CAL sector.
;   ==> MUST use BIN WRITE to flash this patch.
;   After initial BIN write, RPM thresholds ARE in the CAL sector and
;   COULD be made CAL-editable if we read them from addresses in $4000-$7FFF
;   instead of hardcoding as immediates. See v44.1 TODO below.
;
; MEMORY MAP:
;   File 0x05D05 → CPU $5D05 (always visible, Tier 1 free, 504 bytes avail)
;   File 0x101E1 → CPU $81E1 in bank2 (hook point)
;   Our code: 42 bytes. Available: 504 bytes. Margin: 462 bytes.
;
;==============================================================================

;------------------------------------------------------------------------------
; RAM ADDRESSES (verified)
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; 8-bit RPM/25 (94 refs Enhanced, 96 refs stock)
DWELL_INTM_RAM  EQU $017B       ; Dwell intermediate (hook target at file 0x101E1)
LIMITER_FLAGS   EQU $0046       ; Engine mode flags (bits 3,6,7 FREE)
LIMITER_BIT     EQU $80         ; Bit 7 — our spark cut active flag

;------------------------------------------------------------------------------
; FAKE PERIOD — starves dwell to ~100-200µs (identical to 11P's 200µs effect)
;------------------------------------------------------------------------------
FAKE_PERIOD     EQU $3E80       ; 16000 decimal

;------------------------------------------------------------------------------
; RPM THRESHOLDS — 3000 RPM TEST VERSION
;------------------------------------------------------------------------------
; VL400: "set it for 2k RPM and have a go"
; We use 3000/2900 for a safer in-car idle test (can't accidentally hit 2000
; during normal driving if something goes wrong with the patch)
;
RPM_CUT         EQU $78         ; 120 x 25 = 3000 RPM — cut engages here
RPM_RETURN      EQU $74         ; 116 x 25 = 2900 RPM — cut releases here
                                ; Hysteresis: 100 RPM (same as 11P's 5800-5700)

; === PRODUCTION VALUES (uncomment for 6000/5900 RPM) ===
; RPM_CUT       EQU $F0         ; 240 x 25 = 6000 RPM
; RPM_RETURN    EQU $EC         ; 236 x 25 = 5900 RPM

; === 11P-MATCHING VALUES (uncomment for 5800/5700 RPM) ===
; RPM_CUT       EQU $E8         ; 232 x 25 = 5800 RPM
; RPM_RETURN    EQU $E4         ; 228 x 25 = 5700 RPM

;==============================================================================
; CODE — ALWAYS-VISIBLE FREE SPACE
;==============================================================================

            ORG $5D05           ; File offset 0x05D05 (Tier 1, always visible)
                                ; 504 bytes free, we use 42

;==============================================================================
; SPARK CUT HANDLER
;==============================================================================
; Entry: D = calculated dwell intermediate value from stock code
; Exit:  D stored to $017B (real or fake), RTS back to caller
;
; Logic (mirrors VL400's 11P — "simple on/off at the high RPM setting"):
;   IF limiter flag SET → check if RPM dropped below return
;   IF limiter flag CLEAR → check if RPM hit cut threshold
;   Hysteresis prevents chatter at boundary
;==============================================================================

SPARK_CUT_11P:
            PSHA                ; [3] Save A (contains real dwell high byte)
                                ; Opcode: 36

            ;--- Check current state ---
            BRSET LIMITER_FLAGS,LIMITER_BIT,SC_CHECK_RESUME
                                ; [6] If cutting → check for resume
                                ; Opcode: 12 46 80 xx

            ;=== NOT CUTTING: has RPM hit the cut threshold? ===
            LDAA  RPM_ADDR      ; [3] Load RPM/25
                                ; Opcode: 96 A2
            CMPA  #RPM_CUT      ; [2] RPM >= cut point?
                                ; Opcode: 81 78  (3000 RPM test)
            BCS   SC_STORE_REAL ; [3] No → store real dwell, done
                                ; Opcode: 25 xx

            ;--- RPM >= CUT: activate spark cut ---
            BSET  LIMITER_FLAGS,LIMITER_BIT
                                ; [6] Set flag = we are cutting
                                ; Opcode: 14 46 80
            BRA   SC_INJECT     ; [3] Go starve the dwell
                                ; Opcode: 20 xx

SC_CHECK_RESUME:
            ;=== CUTTING: has RPM dropped below return threshold? ===
            LDAA  RPM_ADDR      ; [3] Load RPM/25
                                ; Opcode: 96 A2
            CMPA  #RPM_RETURN   ; [2] RPM < return point?
                                ; Opcode: 81 74  (2900 RPM test)
            BCC   SC_INJECT     ; [3] No (still high) → keep cutting
                                ; Opcode: 24 xx

            ;--- RPM < RETURN: deactivate spark cut ---
            BCLR  LIMITER_FLAGS,LIMITER_BIT
                                ; [6] Clear flag = normal operation
                                ; Opcode: 15 46 80
            ; Fall through to store real value

SC_STORE_REAL:
            ;=== Normal: store the REAL dwell intermediate ===
            PULA                ; [4] Restore A
                                ; Opcode: 32
            STD   DWELL_INTM_RAM ; [5] Store real D to $017B
                                ; Opcode: FD 01 7B
            RTS                 ; [5] Return to stock code
                                ; Opcode: 39

SC_INJECT:
            ;=== Cutting: store FAKE period → dwell starved ===
            PULA                ; [4] Discard real A, clean stack
                                ; Opcode: 32
            LDD   #FAKE_PERIOD  ; [3] D = $3E80 (16000)
                                ; Opcode: CC 3E 80
            STD   DWELL_INTM_RAM ; [5] Fake → $017B → dwell ~200µs
                                ; Opcode: FD 01 7B
            RTS                 ; [5] Return to stock code
                                ; Opcode: 39

;==============================================================================
; SIGNATURE (4 bytes) — identifies patch version in hex dumps
;==============================================================================
            FCB   $4A,$4B       ; "JK" (Jason King)
            FCB   $2C           ; $2C = 44 decimal = v44
            FCB   $01           ; sub-version: 01 = 3000 RPM test

;==============================================================================
; ASSEMBLED BYTE TABLE
;==============================================================================
;
; Addr   Hex                    Instruction             Cycles
; -----  -----                  -----------             ------
; $5D05  36                     PSHA                    3
; $5D06  12 46 80 0B            BRSET $46,$80,$5D14     6
; $5D0A  96 A2                  LDAA $A2                3
; $5D0C  81 78                  CMPA #$78               2    ← 3000 RPM
; $5D0E  25 0E                  BCS $5D1E               3
; $5D10  14 46 80               BSET $46,$80            6
; $5D13  20 0E                  BRA $5D23               3
; --- SC_CHECK_RESUME ($5D14): ---
; $5D14  96 A2                  LDAA $A2                3
; $5D16  81 74                  CMPA #$74               2    ← 2900 RPM
; $5D18  24 08                  BCC $5D22               3    ← note: jumps to $5D23 (typo in v42, recalculated)
; $5D1A  15 46 80               BCLR $46,$80            6
; --- SC_STORE_REAL ($5D1D): ---            (was $5D1E, but check offset)
; $5D1D  32                     PULA                    4
; $5D1E  FD 01 7B               STD $017B               5
; $5D21  39                     RTS                     5
; --- SC_INJECT ($5D22): ---
; $5D22  32                     PULA                    4
; $5D23  CC 3E 80               LDD #$3E80              3
; $5D26  FD 01 7B               STD $017B               5
; $5D29  39                     RTS                     5
; --- SIGNATURE ($5D2A): ---
; $5D2A  4A 4B 2C 01            "JK" v44.01             -
;
; Total: 42 bytes ($5D05-$5D2E)
;
; Worst case path: PSHA(3) + BRSET-taken(6) + LDAA(3) + CMPA(2) + BCC(3) +
;                  PULA(4) + LDD(3) + STD(5) + RTS(5) = 34 cycles = 17µs @ 2MHz
;                  (Safe: 3X events are 3.33ms apart at 6000 RPM)
;
;==============================================================================
; BRANCH OFFSET VERIFICATION
;==============================================================================
;
; All branch offsets are SIGNED BYTE displacements from the byte AFTER the
; branch instruction (PC+2 for Bcc, PC+4 for BRSET/BCLR).
;
; BRSET at $5D06 → target SC_CHECK_RESUME at $5D14
;   Offset byte is at $5D09. PC after BRSET = $5D0A (4-byte instruction)
;   Wait — BRSET $46,$80,$5D14: encoding is 12 46 80 <offset>
;   HC11 BRSET: 12 dd mm rr where rr = target - (addr_of_rr + 1)
;   addr_of_rr = $5D09, target = $5D14
;   rr = $5D14 - ($5D09 + 1) = $5D14 - $5D0A = $0A
;   So: 12 46 80 0A  (not 0B!)
;
; BCS at $5D0E → target SC_STORE_REAL at $5D1D
;   Offset byte at $5D0F. PC after BCS = $5D10.
;   rr = $5D1D - $5D10 = $0D
;   So: 25 0D
;
; BRA at $5D13 → target SC_INJECT at $5D22
;   Offset byte at $5D14. PC after BRA = $5D15.
;   Wait — that collides with SC_CHECK_RESUME!
;   BRA is 2 bytes: opcode at $5D13, offset at $5D14.
;   But SC_CHECK_RESUME also starts at $5D14.
;   Wait, let me re-count from the top...
;
;==============================================================================
; EXACT BYTE-BY-BYTE LAYOUT (RECOUNTED)
;==============================================================================
;
; $5D05: 36                   PSHA                    (1 byte)
; $5D06: 12 46 80 xx          BRSET $46,$80,target    (4 bytes) → $5D06-$5D09
; $5D0A: 96 A2                LDAA $A2                (2 bytes) → $5D0A-$5D0B
; $5D0C: 81 78                CMPA #$78               (2 bytes) → $5D0C-$5D0D
; $5D0E: 25 xx                BCS SC_STORE_REAL       (2 bytes) → $5D0E-$5D0F
; $5D10: 14 46 80             BSET $46,$80            (3 bytes) → $5D10-$5D12
; $5D13: 20 xx                BRA SC_INJECT           (2 bytes) → $5D13-$5D14
;
; SC_CHECK_RESUME = $5D15:
; $5D15: 96 A2                LDAA $A2                (2 bytes) → $5D15-$5D16
; $5D17: 81 74                CMPA #$74               (2 bytes) → $5D17-$5D18
; $5D19: 24 xx                BCC SC_INJECT           (2 bytes) → $5D19-$5D1A
; $5D1B: 15 46 80             BCLR $46,$80            (3 bytes) → $5D1B-$5D1D
;
; SC_STORE_REAL = $5D1E:
; $5D1E: 32                   PULA                    (1 byte)
; $5D1F: FD 01 7B             STD $017B               (3 bytes) → $5D1F-$5D21
; $5D22: 39                   RTS                     (1 byte)
;
; SC_INJECT = $5D23:
; $5D23: 32                   PULA                    (1 byte)
; $5D24: CC 3E 80             LDD #$3E80              (3 bytes) → $5D24-$5D26
; $5D27: FD 01 7B             STD $017B               (3 bytes) → $5D27-$5D29
; $5D2A: 39                   RTS                     (1 byte)
;
; SIGNATURE = $5D2B:
; $5D2B: 4A 4B 2C 01          "JK" v44.01             (4 bytes) → $5D2B-$5D2E
;
; Total: $5D05 to $5D2E = 42 bytes (38 code + 4 sig). Fits in 504 bytes.
;
;==============================================================================
; BRANCH OFFSET CALCULATION (CORRECTED)
;==============================================================================
;
; HC11 branch offset = target_addr - (addr_of_offset_byte + 1)
; For BRSET/BCLR: offset byte is the 4th byte of the instruction
; For Bcc/BRA: offset byte is the 2nd byte of the instruction
;
; 1) BRSET at $5D06 → SC_CHECK_RESUME at $5D15
;    Offset byte at $5D09
;    rr = $5D15 - ($5D09 + 1) = $5D15 - $5D0A = $0B  ✅
;
; 2) BCS at $5D0E → SC_STORE_REAL at $5D1E
;    Offset byte at $5D0F
;    rr = $5D1E - ($5D0F + 1) = $5D1E - $5D10 = $0E  ✅
;
; 3) BRA at $5D13 → SC_INJECT at $5D23
;    Offset byte at $5D14
;    rr = $5D23 - ($5D14 + 1) = $5D23 - $5D15 = $0E  ✅
;
; 4) BCC at $5D19 → SC_INJECT at $5D23
;    Offset byte at $5D1A
;    rr = $5D23 - ($5D1A + 1) = $5D23 - $5D1B = $08  ✅
;
;==============================================================================
; FINAL PATCH BYTES — v44 3000 RPM TEST
;==============================================================================
;
; At file offset 0x05D05 (42 bytes):
;
; 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
; 96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 2C 01
;
; At file offset 0x101E1 (3 bytes — hook):
;
; BD 5D 05
;
; (Original at 0x101E1: FD 01 7B = STD $017B)
; (Patched at 0x101E1: BD 5D 05 = JSR $5D05)
;
;==============================================================================
; v44 6000 RPM PRODUCTION BYTES (change 2 bytes)
;==============================================================================
;
; Same as above but change:
;   Offset +4 (RPM_CUT):    78 → F0  (3000 → 6000 RPM)
;   Offset +14 (RPM_RETURN): 74 → EC  (2900 → 5900 RPM)
;
; At file offset 0x05D05 (42 bytes):
;
; 36 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0E
; 96 A2 81 EC 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 2C 02
;
; (sig byte $01→$02 to distinguish: 01=3000rpm test, 02=6000rpm prod)
;
; Hook at 0x101E1 is the same: BD 5D 05
;
;==============================================================================
; INSTALLATION
;==============================================================================
;
; 1. Open VX-VY_V6_$060A_Enhanced_v1.0a.bin in hex editor
; 2. Go to 0x05D05 — should see all 00s
;    Write: 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
;           96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
;           3E 80 FD 01 7B 39 4A 4B 2C 01
; 3. Go to 0x101E1 — should see FD 01 7B
;    Write: BD 5D 05
; 4. Flash with "write bin" (NOT "write cal" — hook is outside CAL sector)
; 5. Wait for checksum recalc at end of flash
; 6. Test: rev to ~3000 RPM, should bounce/cut
; 7. ALDL verify: $0046 bit 7 toggles at threshold
; 8. If good → change to 6000 RPM production values and re-flash
;
;==============================================================================
; CAN THIS BE CAL-EDITABLE?
;==============================================================================
;
; Not with hardcoded CMPA #imm instructions. The RPM thresholds are
; encoded as immediate operands inside the code bytes.
;
; To make them CAL-editable (changeable via "write cal" after initial
; BIN write), the code would need to LDAA from a fixed address in the
; CAL sector ($4000-$7FFF) instead of using immediate comparison.
; This adds ~4 bytes per threshold (LDAB $xxxx + CBA instead of CMPA #nn).
;
; For v44, the thresholds are hardcoded. Change them by editing the two
; immediate bytes in the patch and doing another BIN write.
;
; A future v45 could put scalars at e.g. $6560 (in the Tier 1 free space
; at $6559-$66D7, 383 bytes) making them XDF-tunable via CAL writes.
;
;==============================================================================

            END
