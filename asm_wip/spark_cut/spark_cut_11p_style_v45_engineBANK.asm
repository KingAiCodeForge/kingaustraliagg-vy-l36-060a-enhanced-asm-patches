;==============================================================================
; VY V6 SPARK CUT v45 — 11P STYLE, ENGINE BANK FEASIBILITY ANALYSIS
;==============================================================================
;
; v45 CHANGES from v44:
;   INVESTIGATED: Can we place code in engine bank1 overlay ($C468-$FFBF,
;   15,192 bytes free) instead of always-visible Tier 1 ($5D05, 504 bytes)?
;
;   ANSWER: NO — not from the $017B hook. YES — from a bank1-only hook.
;   See BANK PLACEMENT ANALYSIS below for full reasoning.
;
;   v45 ALSO ADDS: Bank2 $FEA2 alternative (same-bank-as-hook placement)
;   for maximum safety. 286 bytes free, hook and code in same bank overlay.
;
;   Source: VL400's OSE 11P dwell starvation method
;   Port by: Jason King (kingaustraliagg) — Feb 25, 2026
;   Target: VX/VY V6 $060A Enhanced v1.0a (92118883)
;   Processor: 68HC11FC0 (IPCM-6)
;
;==============================================================================
; BANK PLACEMENT ANALYSIS — "CAN WE USE ENGINE BANK?"
;==============================================================================
;
; The question: v44 uses $5D05 (always-visible, 504 bytes). Bank1 overlay
; at $C468 has 15,192 bytes — 30x more space. Can we use it?
;
; ── THE HOOK DETERMINES THE ANSWER ──────────────────────────────────────
;
;   Hook: file 0x101E1 → CPU $81E1 → this is in BANK 2 ($8000-$FFFF)
;   When this code executes, bank2 overlay is active at $8000-$FFFF.
;
;   JSR $C468 from bank2 context:
;     CPU fetches from $C468 → bank2 is paged → file 0x10000 + ($C468-$8000)
;     = file 0x14468 → this is BANK2's $C468, NOT bank1's $C468!
;     Bank2 at file 0x14468 has REAL CODE (97% dense). CRASH.
;
;   JSR $5D05 from bank2 context (v44 approach):
;     CPU fetches from $5D05 → always-visible area ($2000-$7FFF)
;     = file 0x05D05 → our patch code. WORKS from ANY bank.
;
;   JSR $FEA2 from bank2 context (v45 new option):
;     CPU fetches from $FEA2 → bank2 is paged → file 0x10000 + ($FEA2-$8000)
;     = file 0x17EA2 → verified 286 bytes free. WORKS — same bank.
;
; ── BANK1 OVERLAY ($C468): WHEN WOULD IT WORK? ─────────────────────────
;
;   Bank1 overlay at $C468 (file 0x0C468) IS accessible when bank1 is the
;   active overlay. This happens when:
;     - Code in $2000-$7FFF calls JSR $C468 (always-visible calls bank1)
;     - Code in bank1 $8000-$C467 calls JSR $C468 (bank1 calls bank1)
;
;   NOT when: bank2 code at $81E1 calls JSR $C468 (sees bank2, not bank1)
;
;   So bank1 $C468 is usable IF we find a hook point that executes in
;   bank1 context OR in the always-visible $2000-$3FFF common code area.
;   The dwell hook at 0x101E1 is in bank2 → bank1 overlay is invisible.
;
; ── SUMMARY TABLE ───────────────────────────────────────────────────────
;
;   Placement         CPU Addr    File Offset  Size     Hook $81E1?   Notes
;   ────────────────  ──────────  ───────────  ───────  ──────────── ──────
;   v44: Tier 1       $5D05       0x05D05      504 B    ✅ YES       Safest, always visible
;   v45a: Bank2       $FEA2       0x17EA2      286 B    ✅ YES       Same bank as hook
;   v45b: Bank1       $C468       0x0C468      15,192B  ❌ NO        Only from bank1/common hooks
;   v45c: Bank3       $CE3F       0x1CE3F      12,659B  ❌ NO        Only from bank3 hooks
;
; ── CONCLUSION ──────────────────────────────────────────────────────────
;
;   For the spark cut (42 bytes), v44's $5D05 remains the best choice:
;     - Always visible from any bank, zero bank-switching risk
;     - 504 bytes is more than enough (42 used, 462 margin)
;     - CAL sector location means code bytes survive CAL writes
;
;   Bank2 $FEA2 is a valid alternative (286 bytes, same-bank safety).
;   Bank1 $C468 (15KB) is reserved for LARGE patches that hook from
;   bank1 or common code — e.g. ghost cam, fuel system patches, or
;   future multi-feature patches that need more than 504 bytes.
;
;   The 15KB at bank1 $C468 IS usable — just not from a bank2 hook.
;   Any hook in $2000-$7FFF (common code) or $8000-$C467 (bank1 overlay)
;   can safely JSR to $C468. Many XDF cal routines and idle spark code
;   have hook candidates in these regions.
;
;==============================================================================
; HOW IT WORKS (unchanged from v44)
;==============================================================================
;
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
;   ==> MUST use BIN WRITE to flash this patch (hook is outside CAL sector).
;   TODO: Check OSE flash tool — what does it write during CAL vs BIN flash?
;
;==============================================================================
; MEMORY MAP — TWO PLACEMENT OPTIONS
;==============================================================================
;
; OPTION A (v44 approach — RECOMMENDED):
;   Code:  file 0x05D05 → CPU $5D05 (Tier 1, always visible, 504 bytes)
;   Hook:  file 0x101E1 → JSR $5D05 (BD 5D 05)
;
; OPTION B (v45 bank2 same-bank approach):
;   Code:  file 0x17EA2 → CPU $FEA2 (Bank2 free space, 286 bytes)
;   Hook:  file 0x101E1 → JSR $FEA2 (BD FE A2)
;   Note:  Hook and code both in bank2 = zero crossing risk.
;          But code is NOT in CAL sector — survives CAL writes as-is.
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
; OPTION A: CODE AT $5D05 — ALWAYS-VISIBLE (same as v44, RECOMMENDED)
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
                                ; Opcode: 12 46 80 0B

            ;=== NOT CUTTING: has RPM hit the cut threshold? ===
            LDAA  RPM_ADDR      ; [3] Load RPM/25
                                ; Opcode: 96 A2
            CMPA  #RPM_CUT      ; [2] RPM >= cut point?
                                ; Opcode: 81 78  (3000 RPM test)
            BCS   SC_STORE_REAL ; [3] No → store real dwell, done
                                ; Opcode: 25 0E

            ;--- RPM >= CUT: activate spark cut ---
            BSET  LIMITER_FLAGS,LIMITER_BIT
                                ; [6] Set flag = we are cutting
                                ; Opcode: 14 46 80
            BRA   SC_INJECT     ; [3] Go starve the dwell
                                ; Opcode: 20 0E

SC_CHECK_RESUME:
            ;=== CUTTING: has RPM dropped below return threshold? ===
            LDAA  RPM_ADDR      ; [3] Load RPM/25
                                ; Opcode: 96 A2
            CMPA  #RPM_RETURN   ; [2] RPM < return point?
                                ; Opcode: 81 74  (2900 RPM test)
            BCC   SC_INJECT     ; [3] No (still high) → keep cutting
                                ; Opcode: 24 08

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
            FCB   $2D           ; $2D = 45 decimal = v45
            FCB   $01           ; sub-version: 01 = 3000 RPM test

;==============================================================================
; EXACT BYTE-BY-BYTE LAYOUT — OPTION A ($5D05)
;==============================================================================
;
; $5D05: 36                   PSHA                    (1 byte)
; $5D06: 12 46 80 0B          BRSET $46,$80,SC_CHECK  (4 bytes) → $5D06-$5D09
; $5D0A: 96 A2                LDAA $A2                (2 bytes) → $5D0A-$5D0B
; $5D0C: 81 78                CMPA #$78               (2 bytes) → $5D0C-$5D0D
; $5D0E: 25 0E                BCS SC_STORE_REAL       (2 bytes) → $5D0E-$5D0F
; $5D10: 14 46 80             BSET $46,$80            (3 bytes) → $5D10-$5D12
; $5D13: 20 0E                BRA SC_INJECT           (2 bytes) → $5D13-$5D14
;
; SC_CHECK_RESUME = $5D15:
; $5D15: 96 A2                LDAA $A2                (2 bytes) → $5D15-$5D16
; $5D17: 81 74                CMPA #$74               (2 bytes) → $5D17-$5D18
; $5D19: 24 08                BCC SC_INJECT           (2 bytes) → $5D19-$5D1A
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
; $5D2B: 4A 4B 2D 01          "JK" v45.01             (4 bytes) → $5D2B-$5D2E
;
; Total: $5D05 to $5D2E = 42 bytes (38 code + 4 sig). Fits in 504 bytes.
;
;==============================================================================
; BRANCH OFFSET VERIFICATION — OPTION A ($5D05)
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
; OPTION A PATCH BYTES — v45 3000 RPM TEST
;==============================================================================
;
; At file offset 0x05D05 (42 bytes):
;
; 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
; 96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 2D 01
;
; Hook at file offset 0x101E1 (3 bytes):
; BD 5D 05  (JSR $5D05 — replaces FD 01 7B = STD $017B)
;
;==============================================================================
; OPTION A 6000 RPM PRODUCTION (change 2 bytes from test)
;==============================================================================
;
; Offset +4 (RPM_CUT):    78 → F0  (3000 → 6000 RPM)
; Offset +14 (RPM_RETURN): 74 → EC  (2900 → 5900 RPM)
; Sig byte: 01 → 02  (01=3000rpm test, 02=6000rpm prod)
;
; 36 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0E
; 96 A2 81 EC 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 2D 02
;
; Hook at 0x101E1 same: BD 5D 05

;##############################################################################
;
; OPTION B: BANK2 SAME-BANK PLACEMENT ($FEA2)
;
;##############################################################################
;
; WHY: Code and hook in the SAME bank2 overlay. Eliminates even the
; theoretical concern of calling across bank boundaries.
;
; File offset: 0x17EA2 → CPU $FEA2 (when bank2 is active)
; Free space: 286 bytes ($FEA2-$FFBF). We use 42. Margin: 244 bytes.
; Hook at 0x101E1 (same bank): JSR $FEA2 (BD FE A2)
;
; TRADEOFF vs Option A:
;   + Hook and code in identical bank context — zero ambiguity
;   + Code is NOT in CAL sector — unaffected by CAL writes
;   - Only 286 bytes (vs 504 at $5D05) — still plenty for spark cut
;   - Bank2-only: code invisible from bank1/bank3 context
;     (not a problem — this code only runs from the bank2 hook)
;
; The code is IDENTICAL — only the ORG and branch offsets change.
; Since all branches are relative (short offsets), the assembled bytes
; are IDENTICAL except for the signature and the hook JSR target.
;
; Option B assembled bytes at file 0x17EA2 (42 bytes):
;
; 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
; 96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 2D 03
;
; (sig $03 = v45 bank2 variant)
;
; Hook at file offset 0x101E1 (3 bytes):
; BD FE A2  (JSR $FEA2 — replaces FD 01 7B = STD $017B)
;
; Option B branch offsets are IDENTICAL to Option A because all branches
; are PC-relative within the 42-byte block — no absolute addresses except
; the direct-page LDAA $A2, BRSET $46, and extended STD $017B which are
; all in the always-visible $0000-$7FFF range (RAM/IO + CAL).

;==============================================================================
; OPTION B BYTE-BY-BYTE LAYOUT ($FEA2)
;==============================================================================
;
; $FEA2: 36                   PSHA                    (1 byte)
; $FEA3: 12 46 80 0B          BRSET $46,$80,SC_CHECK  (4 bytes) → $FEA3-$FEA6
; $FEA7: 96 A2                LDAA $A2                (2 bytes) → $FEA7-$FEA8
; $FEA9: 81 78                CMPA #$78               (2 bytes) → $FEA9-$FEAA
; $FEAB: 25 0E                BCS SC_STORE_REAL       (2 bytes) → $FEAB-$FEAC
; $FEAD: 14 46 80             BSET $46,$80            (3 bytes) → $FEAD-$FEAF
; $FEB0: 20 0E                BRA SC_INJECT           (2 bytes) → $FEB0-$FEB1
;
; SC_CHECK_RESUME = $FEB2:
; $FEB2: 96 A2                LDAA $A2                (2 bytes) → $FEB2-$FEB3
; $FEB4: 81 74                CMPA #$74               (2 bytes) → $FEB4-$FEB5
; $FEB6: 24 08                BCC SC_INJECT           (2 bytes) → $FEB6-$FEB7
; $FEB8: 15 46 80             BCLR $46,$80            (3 bytes) → $FEB8-$FEBA
;
; SC_STORE_REAL = $FEBB:
; $FEBB: 32                   PULA                    (1 byte)
; $FEBC: FD 01 7B             STD $017B               (3 bytes) → $FEBC-$FEBE
; $FEBF: 39                   RTS                     (1 byte)
;
; SC_INJECT = $FEC0:
; $FEC0: 32                   PULA                    (1 byte)
; $FEC1: CC 3E 80             LDD #$3E80              (3 bytes) → $FEC1-$FEC3
; $FEC4: FD 01 7B             STD $017B               (3 bytes) → $FEC4-$FEC6
; $FEC7: 39                   RTS                     (1 byte)
;
; SIGNATURE = $FEC8:
; $FEC8: 4A 4B 2D 03          "JK" v45.03             (4 bytes) → $FEC8-$FECB
;
; Total: $FEA2 to $FECB = 42 bytes. Fits in 286 bytes.
;
;==============================================================================
; OPTION B BRANCH OFFSET VERIFICATION ($FEA2)
;==============================================================================
;
; 1) BRSET at $FEA3 → SC_CHECK_RESUME at $FEB2
;    Offset byte at $FEA6
;    rr = $FEB2 - ($FEA6 + 1) = $FEB2 - $FEA7 = $0B  ✅
;
; 2) BCS at $FEAB → SC_STORE_REAL at $FEBB
;    Offset byte at $FEAC
;    rr = $FEBB - ($FEAC + 1) = $FEBB - $FEAD = $0E  ✅
;
; 3) BRA at $FEB0 → SC_INJECT at $FEC0
;    Offset byte at $FEB1
;    rr = $FEC0 - ($FEB1 + 1) = $FEC0 - $FEB2 = $0E  ✅
;
; 4) BCC at $FEB6 → SC_INJECT at $FEC0
;    Offset byte at $FEB7
;    rr = $FEC0 - ($FEB7 + 1) = $FEC0 - $FEB8 = $08  ✅
;
; All offsets identical to Option A (expected — relative branches are
; position-independent within the block).

;==============================================================================
; WHICH PATCHES CAN USE BANK1 $C468 (15KB FREE)?
;==============================================================================
;
; The 15,192-byte bank1 overlay at $C468-$FFBF is the largest free region.
; It's usable for patches that hook from bank1 or common code context.
;
; USABLE from bank1 $C468:
;
;   ghost_cam_rpm_delta_spark_v1.asm
;     Hook: $F8D7 in bank2 (LDD $6525 — idle spark calc)
;     PROBLEM: Hook is in bank2 → same cross-bank issue!
;     FIX: Need to find the common-area ($2000-$3FFF) subroutine that
;     CALLS the bank2 idle spark routine. Hook THAT instead.
;     Or: use Tier 1 space ($5D05 or $6559) for a small trampoline that
;     switches to bank1 context, then JSR $C468 for the big lookup table.
;     The ghost cam table (11 bytes) + code (~60 bytes) = 71 bytes.
;     This fits in Tier 1 alone — bank1 not needed unless we add features.
;
;   lumpy_idle_xdf_parameters_v2.asm
;     No hook needed — XDF-only calibration changes. Bank irrelevant.
;
;   cold_maps_force_cold_spark_v1.asm
;     Patch: 3 bytes at $64D2-$64D4 (CAL area, always visible)
;     No code placement — direct byte edits. Bank irrelevant.
;
;   cold_maps_tuning_alpina_method_v1.asm
;     Patch: CAL byte edits only. Bank irrelevant.
;
;   fuel_cut_enhanced.asm
;     Patch: Stock table at $77DE (CAL area). XDF-only. Bank irrelevant.
;
;   mafless_alpha_n_v1-v4.asm (all variants)
;     Hook: 0x101E1 (bank2) or 0x117AF (bank2) NOP approach
;     PROBLEM: ALL hooks are in bank2 → cross-bank to bank1 $C468 fails.
;     FIX (v4 table relocation): Relocate VE table to $5C31 or $6559
;     (Tier 1, 136+383=519 bytes). 16x16 VE = 256 bytes, fits at $6559.
;     Code (14 bytes) fits at $5D05 alongside spark cut (42+14=56 of 504).
;
;   shift_control/*.asm (all 8 files)
;     Hook: ALL use 0x101E1 (bank2 dwell hook)
;     PROBLEM: All have cross-bank bug → bank1 $C468 is NOT usable.
;     FIX: Relocate to Tier 1 or bank2 $FEA2.
;
;   turbo_boost/*.asm (all 7 files)
;     Hook: Most use 0x101E1 (bank2 dwell hook)
;     PROBLEM: Same cross-bank issue.
;     EXCEPTION: boost_controller_pid.asm and overboost_protection.asm
;     are standalone modules needing their own hook discovery.
;
; ACTUALLY USABLE from bank1 $C468 (hook in common or bank1 code):
;
;   Any patch that hooks a subroutine CALLED from the common area
;   ($2000-$3FFF) into bank1 overlay code. The 96 JSR references from
;   common code that target bank2 addresses (like JSR $DEC5) execute
;   when bank2 is paged in. We'd need to find JSRs that execute when
;   bank1 is still the active overlay.
;
;   Candidate: The code at $8000-$C467 IS bank1. If we find a hook
;   within that region, JSR $C468 from there stays in bank1. The dwell
;   calculation STARTS in common code, transitions through bank2.
;   To use bank1 $C468, we need to intercept BEFORE the bank switch.
;
;   RESEARCH NEEDED: Trace the dwell calc call chain from common area
;   through to bank2. Find the last common-area JSR before bank2 paging.
;   That JSR's target in bank1 overlay is our bank1-safe hook point.
;
;==============================================================================
; CROSS-REFERENCE: ALL ASM FILES WITH CROSS-BANK BUG
;==============================================================================
;
; Every file below places code at $C468+ (bank1) but hooks at 0x101E1
; (bank2). JSR from bank2 to $C468 hits bank2's code, not the patch.
;
; ── spark_cut/ ──────────────────────────────────────────────────────────
;   spark_cut_11p_style_v42.asm        — FIXED in v44 → $5D05
;   spark_cut_bmw_inspired_v40.asm     — NEEDS FIX → relocate to $5D05
;   spark_cut_delco_optimized_v41.asm  — NEEDS FIX → relocate to $5D05
;   spark_cut_chrome_method_v33.asm    — NEEDS FIX → relocate to $5D05
;   All other spark_cut/*.asm          — NEEDS FIX
;
; ── fuel_systems/ ───────────────────────────────────────────────────────
;   alpha_n_tps_fallback.asm           — NEEDS FIX → relocate to $5D05
;   e85_dual_map_toggle.asm            — NEEDS FIX → relocate to $5D05
;   mafless_alpha_n_v1-v4.asm          — NEEDS FIX → relocate to $5D05/$6559
;   mafless_tpi_method.asm             — NEEDS FIX → relocate to $5D05
;   speed_density_fallback_v1.asm      — NEEDS FIX (also needs MAP hardware)
;   speed_density_ve_table.asm         — NEEDS FIX (also needs MAP hardware)
;
; ── shift_control/ ──────────────────────────────────────────────────────
;   flat_shift_no_lift.asm             — NEEDS FIX → relocate to $5D05
;   launch_control_two_step.asm        — NEEDS FIX + 16-bit RPM bug
;   shift_bang_auto.asm                — TEMPLATE — placeholder addrs
;   shift_bang_manual.asm              — TEMPLATE — placeholder addrs
;   shift_launch_v1.asm                — NEEDS FIX → relocate to $5D05
;   shift_retard.asm                   — NEEDS FIX → relocate to $5D05
;   timing_retard_soft.asm             — NEEDS FIX + unverified RAM
;   no_lift_shift.asm                  — Not annotated (may be clean)
;
; ── turbo_boost/ ────────────────────────────────────────────────────────
;   antilag_rolling.asm                — NEEDS FIX + DFI limitation
;   antilag_turbo.asm                  — NEEDS FIX + unverified $0160
;   hybrid_fuel_spark_limiter.asm      — NEEDS FIX → relocate to $5D05
;   turbo_limiter_v1.asm               — NEEDS FIX + DFI limitation
;   antilag_cruise_button.asm          — RAM conflicts with stock vars
;   boost_controller_pid.asm           — TEMPLATE — needs MAP hardware
;   overboost_protection.asm           — TEMPLATE — needs MAP hardware
;
; ── ghost_cam/ ──────────────────────────────────────────────────────────
;   ghost_cam_rpm_delta_spark_v1.asm   — Hook in bank2 ($F8D7) → FIX
;   ghost_cam_rpm_rotating_idle.asm    — Theory only, no code placement
;
; ── cold_maps/ (3 DISTINCT CONCEPTS, all CAL byte edits) ────────────── 
;
;   cold_maps_force_cold_spark_v1.asm  — COLD MAPS: Force cold spark
;     compensation at ALL temps. 3 cal byte edits at $64D2-$64D4 (set
;     cold spark multiplier to 1.0 at 32/56/80°C). Optional ASM routine
;     at $C468 has cross-bank bug but ISN'T NEEDED — the 3-byte cal
;     patch alone does the job. Simplifies SPARK tuning only.
;     ALSO: Option C (STFT/LTFT temp raise at $752C/$7635) forces
;     permanent open-loop fuel — separate from cold spark.
;
;   cold_maps_tuning_alpina_method_v1  — ALPINA METHOD: Overview/concept
;     doc. "Zero the complex, tune the simple" philosophy from Alpina
;     B3 3.3L binary (34 zeroed tables vs stock 7). Covers BMW MS42/43
;     cold-vs-warm map architecture. NOT a patch itself — references
;     the other two files + the XDF doc as actual implementations.
;     VY V6 equivalent: zero warm correction multipliers so cold
;     tables become primary. Broader scope than just cold spark.
;
;   alpina_mafless_fallback_v1.asm     — ALPINA MAFless: Force MAF
;     failure fallback mode (Alpha-N / TPS+RPM fuel calc). Cal byte
;     patches at $56D4, $5795, $7F1B. For big cams, ITBs, turbo+BOV
;     where MAF sensor can't read airflow accurately. Uses stock 7x5
;     "Maximum Airflow Vs RPM" fallback table at $7F2A. Has cross-bank
;     bug warning header but the cal patches themselves are safe —
;     only the optional ASM routine (which isn't needed) would break.
;
;   NO CROSS-BANK BUG for any cal-only edits in this folder.
;
; ── needs_validation/ ───────────────────────────────────────────────────
;   All 5 files use $77F4 as runtime flag (ROM area — suspicious)
;   All have mixed 8/16-bit RPM comparison bugs (LDD/CPD on 8-bit $00A2)
;   None specify ORG — code placement TBD
;
;==============================================================================
; WHAT OTHER METHODS COULD BE DONE — BY CATEGORY
;==============================================================================
;
; Based on bank split analysis, XDF parameters, and free space reality:
;
; ── SPARK CUT (this file's category) ───────────────────────────────────
;
;   DONE:   v44/v45 dwell starvation at $5D05 (42 bytes, verified)
;   COULD:  Soft-cut timing retard zone BEFORE hard cut
;           - Add 20-30 bytes at $5D2F (after v45 sig, still in Tier 1)
;           - Read $01B0 (SPARK_BASE, verified 5 refs), subtract 10-15°
;           - Activate at RPM_CUT - 200 RPM ($E4 = 5700 RPM for 6000 prod)
;           - Total: v45 (42) + soft zone (30) = 72 bytes of 504. Fits.
;   COULD:  CAL-editable thresholds (v44 suggested at $6559)
;           - Store RPM_CUT at $6560, RPM_RETURN at $6561
;           - Code: LDAB $6560 / CBA instead of CMPA #imm
;           - Adds 6 bytes (3 per threshold). Total: 48 bytes. Fits.
;           - XDF definitions for TunerPro: 2 new scalars
;           - After initial BIN write, thresholds changeable via CAL write!
;   COULD:  Dual-threshold (2-step): 3000 RPM launch + 6000 RPM limiter
;           - Read TPS or speed to select which threshold set
;           - Extra ~20 bytes. Total: ~62 bytes. Fits at $5D05.
;
; ── GHOST CAM ──────────────────────────────────────────────────────────
;
;   BEST:   XDF-only approach (lumpy_idle_xdf_parameters_v2.asm)
;           - Crank KSARPMHI/LO ($6525/$6527) to 0.16-0.27 DEG%/RPM
;           - Widen KSCORLIM ($652B) from 5° to 25-35°
;           - Tighten RPM error limit ($6529) to 250 RPM
;           - Reduce RPM filter ($6523) from $0A to $02-$04
;           - ZERO CODE PATCH. All TunerPro XDF. Flash with CAL write.
;           - RISK: Slow ~1Hz lope, not fast ghost cam. Test first.
;   COULD:  ASM oscillating idle target (Method 4 from rotating_idle)
;           - Hook: need to find where idle RPM target is loaded
;           - ~40 bytes code + 8 bytes sine table = 48 bytes
;           - Placement: $5D2F (after spark cut). Separate hook needed.
;           - CHALLENGE: Finding the idle target load instruction
;   COULD:  ASM spark delta table (ghost_cam_rpm_delta_spark_v1.asm)
;           - Hook: $F8D7 in bank2 (LDD $6525)
;           - Code: ~60 bytes + 11-byte table = 71 bytes
;           - CHALLENGE: Hook is bank2, code needs bank2 or Tier 1
;           - $5D05 has room for BOTH spark cut (42) and ghost cam (71)
;             = 113 bytes of 504. Fits.
;   PROBABLY WON'T WORK: Skip-fire (Method 6) — DFI single-EST architecture
;           means ECU cannot control individual cylinders
;   PROBABLY WON'T WORK: Waste spark offset (Method 7) — theoretical only
;
; ── COLD MAPS (force cold spark compensation always active) ───────────
;
;   DONE:   Cold maps patch (cold_maps_force_cold_spark_v1.asm)
;           - 3 cal bytes at $64D2-$64D4: set cold spark multiplier
;             to 1.0 (0xFF) at 32°C, 56°C, 80°C breakpoints
;           - Effect: Cold Spark Offset table ($646D, 7x14) ALWAYS
;             applies to Final Spark, even when engine is at 80°C
;           - Simplifies SPARK tuning: tune one offset table instead
;             of balancing Main Spark + Cold Spark interaction
;           - CAL write safe. No ASM needed.
;   DONE:   Open-loop fuel force (Option C in same file)
;           - $752C STFT enable temp → 0xD0 (~113°C, never enables)
;           - $7635 LTFT enable temp → 0xD0 (~120°C, never enables)
;           - Effect: ECU stays in open loop forever, no trim fighting
;           - Separate from cold spark — can use independently
;   COULD:  Combine cold maps + open-loop for full "tune the simple"
;           - Cold spark offset = primary timing adjustment
;           - Open-loop tables = primary fuel adjustment
;           - Knock sensor still active for protection
;
; ── ALPINA METHOD (zero 27+ warm tables — BMW philosophy) ─────────────
;
;   CONCEPT: cold_maps_tuning_alpina_method_v1.asm (overview doc)
;           - Alpina B3 3.3L zeroed 27 additional tables beyond stock
;           - VANOS VE (7 of 8 zeroed), RON timing (2 zeroed),
;             temp timing/injection (5), ignition corrections (7),
;             catalyst/emissions (3), SOI timing (2), diagnostics (3),
;             misc (5) = 34 total zero tables
;           - Kept only: ip_maf_1_diag (primary airflow),
;             ip_iga_knk_diag (knock timing), ip_maf_vo_2 (one VE table)
;           - VY V6 equivalent: zero all warm correction multipliers
;             so cold/fallback tables become the ONLY active path
;           - MORE AGGRESSIVE than cold maps patch — cold maps just
;             forces one multiplier table; Alpina method zeros everything
;   COULD:  Apply Alpina full zero method to VY V6
;           - Zero all VY V6 equivalent warm correction tables in CAL
;           - No ASM patch — TunerPro XDF zero-fill across CAL sector
;           - REQUIRES: Accurate base tune (no closed-loop correction)
;           - REQUIRES: Mapping VY V6 table equivalents to BMW tables
;
; ── ALPINA MAFless FALLBACK (force Alpha-N fuel calculation) ──────────
;
;   DONE:   alpina_mafless_fallback_v1.asm
;           - Cal byte patches at $56D4, $5795, $7F1B
;           - Forces MAF failure fallback → TPS+RPM fuel calculation
;           - Uses stock 7x5 "Max Airflow Vs RPM" table at $7F2A
;           - For: big cams, ITBs, turbo+BOV, deleted/damaged MAF
;           - LIMITATION: Fallback table only covers 0-50% TPS
;             (no WOT coverage — may run lean above 50% throttle)
;   COULD:  MAFless expanded VE table (mafless_alpha_v4)
;           - Relocate 16x16 VE table to $6559 (383 bytes, Tier 1)
;           - 256-byte VE table + 14 bytes code = 270 bytes. Fits.
;           - Full TPS range coverage including WOT
;           - REQUIRES: Cross-bank fix (code must be in Tier 1 or bank2)
;           - REQUIRES: Pointer patches + interpolation code modification
;   COULD:  MAFless via DTC force (mafless_alpha_n_v1 simplest)
;           - 4 cal byte patches: $56F3, $56D4, $56DE, option word
;           - Forces stock 7x5 fallback table at $7F2A
;           - Same 0-50% TPS limitation as Alpina MAFless above
;
; ── SHIFT CONTROL ─────────────────────────────────────────────────────
;
;   BEST:   Shift spark retard via existing F4PEADRT table ($675C)
;           - Stock ECU already has shift-related spark tables!
;           - XDF-editable, no ASM patch needed
;           - Adjust: PE spark advance/retard timing values
;   COULD:  Flat-foot shift (manual trans only)
;           - Reuse spark cut code at $5D05 with TPS qualification
;           - Add clutch switch input read (~15 bytes extra)
;           - Total: spark cut (42) + clutch check (15) = 57 bytes. Fits.
;           - REQUIRES: Clutch switch wired to Port D input
;   COULD:  Launch control two-step
;           - Same spark cut mechanism at lower RPM (3000-4000 RPM)
;           - Activate only when: clutch in + brake on + TPS > 50%
;           - Extra ~25 bytes of qualifying logic
;           - CHALLENGE: Finding brake switch and clutch RAM addresses
;   TEMPLATE ONLY: shift_bang_auto, shift_bang_manual
;           - Made-up RAM addresses ($00D0-$00D5, $0180-$0185)
;           - Need complete rewrite with verified addresses
;
; ── TURBO / BOOST ─────────────────────────────────────────────────────
;
;   BLOCKER: VY V6 HAS NO MAP SENSOR. All boost/SD patches need hardware.
;   COULD:  Anti-lag spark cut (reuse v45 spark cut mechanism)
;           - Cut spark while keeping injectors active
;           - Unburned fuel ignites in exhaust → maintains turbo spool
;           - REQUIRES: Verified injector PW addresses ($013F/$0141 confirmed)
;           - RISK: Extreme — exhaust/turbo/manifold damage possible
;   COULD:  Overboost fuel cut (if MAP sensor added)
;           - Simple threshold comparison on MAP reading
;           - ~30 bytes code at $5D05 or $6559
;           - Enhanced binary has $00B0 MAP_SENSOR var (Enhanced-only!)
;   WON'T WORK: Cylinder-selective cut — DFI module limitation
;           (single EST → DFI → 3 coilpacks, no individual control)
;
; ── HARDWARE EST METHODS (needs_validation/) ──────────────────────────
;
;   MOST PROMISING: TCTL1 OC3 mode (v16, BennVenn OSE12P port)
;           - Proven on OSE12P platform, theoretical on VY V6
;           - Sets TCTL1 bits 5-4 = 10 to force PA5/EST LOW
;           - RISK: May trigger DFI bypass mode (10° locked timing)
;           - REQUIRES: Oscilloscope bench testing before in-car use
;   LESS PROMISING: OC1D master override (v17)
;           - More aggressive but interferes with other OC functions
;   AVOID: Pulse accumulator ISR (v19) — too experimental, ISR hijacking
;   ALL HAVE: Mixed 8/16-bit RPM comparison bug (fixable)
;   ALL HAVE: $77F4 runtime flag in ROM area (change to $0046 bit 6)
;
;==============================================================================
; TIER 1 FREE SPACE ALLOCATION PLAN (MULTI-PATCH)
;==============================================================================
;
; If we install multiple patches, here's how they fit in Tier 1:
;
;   $5D05-$5D2E: Spark cut v45 (42 bytes)
;   $5D2F-$5D76: [AVAILABLE] Soft-cut zone or ghost cam (72 bytes)
;   $5D77-$5EFC: [AVAILABLE] Future patches (390 bytes)
;   ────────────────────────────────────────
;   $6559-$66D7: Tier 1 Region B (383 bytes)
;                [AVAILABLE] VE table (256B) or CAL-editable scalars
;
;   Total Tier 1: 504 + 383 = 887 bytes across 2 regions
;   With spark cut: 887 - 42 = 845 bytes remaining
;
;   If we need MORE: Bank2 $FEA2 (286 bytes) for bank2-hooked code
;   If we need MUCH MORE: Bank1 $C468 (15,192 bytes) for bank1-hooked code
;
;==============================================================================
; INSTALLATION (same as v44)
;==============================================================================
;
; OPTION A ($5D05 — recommended):
; 1. Open VX-VY_V6_$060A_Enhanced_v1.0a.bin in hex editor
; 2. Go to 0x05D05 — should see all 00s
;    Write: 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
;           96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
;           3E 80 FD 01 7B 39 4A 4B 2D 01
; 3. Go to 0x101E1 — should see FD 01 7B
;    Write: BD 5D 05
; 4. Flash with "write bin" (NOT "write cal")
; 5. Test: rev to ~3000 RPM, should bounce/cut
; 6. ALDL verify: $0046 bit 7 toggles at threshold
; 7. If good → change to 6000 RPM production values and re-flash
;
; OPTION B ($FEA2 — bank2 same-bank):
; 1. Go to 0x17EA2 — should see all 00s
;    Write: 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
;           96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
;           3E 80 FD 01 7B 39 4A 4B 2D 03
; 2. Go to 0x101E1 — should see FD 01 7B
;    Write: BD FE A2
; 3. Flash with "write bin"
;
;==============================================================================

            END
