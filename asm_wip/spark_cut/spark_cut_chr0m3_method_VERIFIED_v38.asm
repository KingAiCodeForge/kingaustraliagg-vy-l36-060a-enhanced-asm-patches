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
; ⚠️⚠️⚠️ CRITICAL: THIS HOOK POINT ($3618 / STD $194C) IS INEFFECTIVE! ⚠️⚠️⚠️
;
; The Enhanced v1.0a 128KB binary has been properly bank-split into 3 banks
; and disassembled using our HC11 bank splitter script (split_and_disassemble.py).
; The resulting bank disassemblies are now the ground truth for all ASM work:
;
;   bank_split_output/Enhanced_v1.0a_bank1.asm  — Bank 1 (file 0x08000-0x0FFFF)
;     CPU $8000-$FFFF. FREE SPACE $C468-$FFBF (15,192 bytes of $00).
;     Identical between stock and Enhanced (0 bytes differ).
;     This is where our patch code lives ($C500).
;
;   bank_split_output/Enhanced_v1.0a_bank2.asm  — Bank 2 (file 0x10000-0x17FFF)
;     CPU $8000-$FFFF. Main engine control code.
;     Contains the dwell calculation hook point at CPU $81E1 (file 0x101E1).
;     The STD $017B instruction we replace with JSR $C500 lives here.
;
;   bank_split_output/Enhanced_v1.0a_bank3.asm  — Bank 3 (file 0x18000-0x1FFFF)
;     CPU $8000-$FFFF. Transmission + diagnostics code.
;     Contains the TIC3 ISR with the $194C init at $3618 (DO NOT hook here).
;
; All previous ASM files in asm_wip/ were written BEFORE the bank splits
; existed and have been corrected against them. The bank disassemblies and
; the HC11 bank splitter script are both published on the GitHub repo.
;
;==============================================================================
; CORRECTION (2026-02-07): Binary analysis proved that STD $194C at $3618 is
; the COLD-START INITIALIZATION PATH ONLY. During normal engine operation:
;   - $194A != 0, so BNE at $360C skips PAST $3618 entirely
;   - D = $0000 at $3618 (A=0 from BEQ path, B=0 from CLRB)
;   - Real period updates come from filter sub $050C via indexed STD 0,X
;   - Any fake period injected at $3618 gets OVERWRITTEN by the filter
;
; USE INSTEAD: Hook STD $017B at file offset 0x101E1 (dwell intermediate)
;   - $017B is in the dwell calculation path, runs every cycle
;   - Injecting fake value directly starves dwell → no spark
;   - See: spark_cut_dwell_hook_v39.asm (TODO: create this file)
;==============================================================================
;
;==============================================================================
; VY V6 SPARK CUT - 3X PERIOD MANIPULATION METHOD - v38 (⚠️ HOOK POINT WRONG)
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Updated: February 7, 2026
; Status: ❌ HOOK POINT INEFFECTIVE - Code logic correct but hooks init path only
;
; CRITICAL BUG FIX (2026-02-07, from v40 analysis):
;   The LDAA $A2 instruction overwrites register A which contains the
;   real period value from stock code. When taking STORE_NORMAL path,
;   STD stores corrupted D (RPM:00) instead of (period:00).
;   FIX: Added PSHA at entry, PULA before STD/LDD to save/restore A.
;
; Based on Chr0m3 Motorsport's CONCEPT (crank period manipulation):
;   "If you set the 3x period astronomically high the dwell gets really
;    really small (if I recall like 100µs) opposed to the usual 600 odd"
;
; Implementation by Jason King:
;   - All reverse engineering done independently
;   - Addresses verified using custom Python HC11 disassembler
;   - NOT verified with IDA Pro or Ghidra (yet)
;
; Chr0m3's concept (from forum/video):
;   1. "Scrapped everything fuel cut" - Removed stock fuel cut logic, we are leaving the stock limiter as a safety net.
;   2. "Rewrote my own logic for rev limiter" - Custom implementation
;   3. "Used a free bit in RAM" - Found unused bit for on/off flag
;   4. "Moved entire dwell functions to add my flag"
;   
; This version uses:
;   ✅ Verified free flag bit at $0046 bit 7 (ENGINE_MODE_FLAGS)
;   ✅ 8-bit RPM comparison (correct for ≤6375 RPM)
;   ❌ Hook at 0x13618 (STD $194C) = INIT PATH ONLY — ineffective!
;   ✅ Verified free space at $0C500
;   ✅ Chr0m3's concept: fake period value ($3E80 = 16000)
;   ⚠️ Correct hook: 0x101E1 (STD $017B) = dwell intermediate
;
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; Verification Method:
;   - Custom Python HC11 disassembler (hc11_disassembler_complete.py)
;   - Binary verification via hex dump and grep analysis
;   - Cross-referenced with STOCK 92118883 binary
;   - NOT yet verified with IDA Pro or Ghidra
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES (CORRECTED 2026-02-02)
;------------------------------------------------------------------------------
; Address   | Verification                | Purpose
; ----------|-----------------------------|---------------------------------
; $00A2     | 82 reads (LDAA $A2)         | RPM/25 (8-bit, max 255=6375 RPM)
; $194C     | Init STD @ $3618; real updates via $050C filter | 24X crank period (16-bit µs)
; $017B     | STD at 0x101E1              | Dwell intermediate (CORRECT HOOK TARGET!) ✅
; $0199     | LDD at 0x1007C (FC 01 99)   | Dwell time RAM
; $0046     | Bit 7 FREE (no BRSET/BCLR)  | Engine mode flags - USE BIT 7!
;
; ⚠️ $194C at $3618 = init path only (D=$0000), NOT the real period write!
; ✅ $017B at 0x101E1 = dwell intermediate, BEST hook target for spark cut
;------------------------------------------------------------------------------

RPM_ADDR EQU $00A2       ; ✅ VERIFIED: 82 reads (8-bit RPM/25) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
PERIOD_24X_RAM EQU $194C       ; 24X period RAM (init @ $3618; real updates via filter $050C) ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
DWELL_INTM_RAM EQU $017B       ; ✅ CORRECT HOOK TARGET: dwell intermediate @ 0x101E1 ; Verified: DWELL_INTERMEDIATE (2 refs both. HOOK TARGET at 0x101E1) [Enhanced-fix]
DWELL_RAM EQU $0199       ; ✅ VERIFIED: LDD at 0x1007C ; Verified: DWELL_TIME_RAM (8 refs both) [Enhanced-fix]

;------------------------------------------------------------------------------
; VERIFIED FREE FLAG BIT
;------------------------------------------------------------------------------
; Analysis of $0046 (Engine Mode Flags):
;   Used bits: 0, 1, 2, 4, 5 (mask $37)
;   FREE bits: 3, 6, 7 (mask $C8)
;   
; We use bit 7 ($80) because:
;   - Top bit, easy to test with BMI/BPL
;   - No stock code uses BRSET/BRCLR/BSET/BCLR on bit 7
;------------------------------------------------------------------------------

LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE (unused in stock)

;------------------------------------------------------------------------------
; HOOK POINT (RE-CORRECTED 2026-02-07)
;------------------------------------------------------------------------------
; ❌ v38 HOOK (WRONG — init path only, filter overwrites fake period):
;   File offset 0x13618: FD 19 4C = STD $194C — cold-start init, D=$0000
;   Real period written by filter sub $050C via indexed STD 0,X
;
; ✅ CORRECT HOOK POINT (restored from pre-v38):
;   File offset 0x101E1: FD 01 7B = STD $017B — dwell intermediate
;   This is in the dwell calculation path, runs every dwell cycle
;   Replace with: BD C5 00 = JSR $C500
;
; History: v1-v37 used $017B (right address, wrong reason "crank period")
;          v38 changed to $194C (wrong — init path only)
;          v39+ should use $017B (right address, right reason "dwell intermediate")
;------------------------------------------------------------------------------

; ❌ WRONG HOOK (v38 — kept for reference):
;HOOK_TIC3_ISR   EQU $3618       ; Init path only, DO NOT USE
;HOOK_FILE_OFF   EQU $13618      ; Init path only, DO NOT USE
;HOOK_ORIGINAL   EQU $FD194C     ; Init path only, DO NOT USE

; ✅ CORRECT HOOK (v39+):
HOOK_DWELL_CPU  EQU $A1E1       ; CPU address (0x101E1 - 0x10000 + 0x8000)
HOOK_FILE_OFF   EQU $101E1      ; ✅ CORRECT: File offset (dwell calc path)
HOOK_ORIGINAL   EQU $FD017B     ; ✅ CORRECT: Original bytes (STD $017B)
HOOK_PATCHED    EQU $BDC500     ; JSR $C500 (call our routine)

;------------------------------------------------------------------------------
; RPM THRESHOLDS (8-bit - max 255 = 6375 RPM)
;------------------------------------------------------------------------------
; Formula: RPM = Value × 25
;
; ⚠️ 8-BIT LIMIT: $00A2 is RPM/25 (8-bit), so max representable = 6375 RPM!
; ⚠️ ABOVE 6375 RPM: The dwell+burn timer OVERFLOWS → NO SPARK!
;    Chr0m3: "Above 6,350 you lose the limiter"
;    The1: "ends up overflowing, dwell + burn ends up as 0 = no spark"
;
; FOR >6375 RPM OPERATION (turbo builds) you MUST also patch:
;   File Offset 0x171AA: Change 0xA2 → 0x9A (Min Dwell: 162→154)
;   File Offset 0x19813: Change 0x24 → 0x1C (Min Burn: 36→28)
;   See: spark_cut_dwell_patch_v37.asm for full instructions
;   Result: Stable operation to ~7200 RPM
;
; Examples:
;   120 ($78) × 25 = 3000 RPM (test)
;   236 ($EC) × 25 = 5900 RPM (stock fuel cut)
;   240 ($F0) × 25 = 6000 RPM (recommended spark cut)
;   254 ($FE) × 25 = 6350 RPM (safe maximum without dwell patches)
;   255 ($FF) × 25 = 6375 RPM (AVOID - 8-bit overflow boundary!)
;------------------------------------------------------------------------------

; PRODUCTION: 6000 RPM spark cut (safe, proven)
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM - ACTIVATE spark cut
RPM_LOW         EQU $EC         ; 236 × 25 = 5900 RPM - RESUME (100 RPM hysteresis)

; TEST MODE: Uncomment for 3000 RPM testing
; RPM_HIGH        EQU $78         ; 120 × 25 = 3000 RPM
; RPM_LOW         EQU $74         ; 116 × 25 = 2900 RPM

; AGGRESSIVE: Chr0m3's maximum (requires dwell patches for >6375!)
; RPM_HIGH        EQU $FE         ; 254 × 25 = 6350 RPM
; RPM_LOW         EQU $FA         ; 250 × 25 = 6250 RPM

;------------------------------------------------------------------------------
; FAKE PERIOD VALUE (Chr0m3 concept)
;------------------------------------------------------------------------------
; Normal 3X period at 6000 RPM ≈ 3.3ms = 3300 counts
; Fake period = 16000 ($3E80) = ~1000ms apparent
; Result: Dwell calculation produces ~100µs = NO SPARK
;
; Chr0m3: "if you set the 3x period astronomically high the dwell gets 
;          really really small (if I recall like 100µs)"
;------------------------------------------------------------------------------

FAKE_PERIOD     EQU $3E80       ; ✅ Chr0m3: 16000 = ~100µs dwell = no spark

;------------------------------------------------------------------------------
; CODE SECTION - VERIFIED FREE SPACE
;------------------------------------------------------------------------------
; File offsets 0x0C468 to 0x0FFBF = 15,192 bytes of zeros
; CPU addresses $1C468 to $1FFBF (banked ROM)
; We use $C500 which maps to file offset 0x0C500
;------------------------------------------------------------------------------

            ORG $0C500          ; ✅ VERIFIED: 15,040+ bytes free (all 0x00) ; Bank 1 (file 0x0C500). Free banks: [1], used: [2, 3]. 15192 bytes free [Enhanced-fix]

;==============================================================================
; SPARK CUT HANDLER - Chr0m3 crank period injection Method (CORRECTED 2026-02-02)
;==============================================================================
; ⚠️ v38 hooks $3618 (init path) — see top of file for why this is wrong.
; For v39+, this should be called from JSR at file 0x101E1 (replaces "STD $017B")
; 
; Entry conditions (if hooked at 0x101E1):
;   D = Calculated dwell intermediate value from stock dwell calc
;   Stack = Return address
;
; Exit conditions:
;   D = Either real value OR fake value (based on RPM)
;   $017B = Value stored (real or fake)
;   $0046 bit 7 = Limiter state (1=cutting, 0=normal)
;
; Cycle count: ~28 cycles worst case (acceptable for ISR)
; Stack usage: 1 byte (PSHA/PULA for A register preservation)
;
; v38 FIX (2026-02-07): Save A at entry, restore before STD on normal path,
;   clean stack before LDD on fake path. Prevents corrupted D on STORE_NORMAL.
;==============================================================================

SPARK_CUT_HANDLER:
    PSHA                        ; 36       SAVE A (contains real period!)
    
    ; Check if limiter is currently active
    BRSET   LIMITER_FLAGS,LIMITER_BIT,CHECK_RESUME  ; If bit 7 set, check resume
    
    ;--- LIMITER OFF: Check if RPM exceeds HIGH threshold ---
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25 (now safe, A saved!)
    CMPA    #RPM_HIGH           ; 81 F0    Compare with high threshold
    BCS     STORE_NORMAL        ; 25 xx    RPM < threshold → store real period
    
    ; RPM exceeded threshold → ACTIVATE LIMITER
    BSET    LIMITER_FLAGS,LIMITER_BIT  ; 14 46 80  Set bit 7 = limiter active
    BRA     INJECT_FAKE         ; 20 xx    Go inject fake period

CHECK_RESUME:
    ;--- LIMITER ON: Check if RPM dropped below LOW threshold ---
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25
    CMPA    #RPM_LOW            ; 81 EC    Compare with low threshold  
    BCC     INJECT_FAKE         ; 24 xx    RPM >= threshold → keep cutting
    
    ; RPM dropped below threshold → DEACTIVATE LIMITER
    BCLR    LIMITER_FLAGS,LIMITER_BIT  ; 15 46 80  Clear bit 7 = limiter off
    ; Fall through to store normal period

STORE_NORMAL:
    ;--- Store REAL value (normal operation) ---
    PULA                        ; 32       RESTORE A (real dwell intermediate!)
    ; Now D = A:B = original value restored
    ; v38: STD $194C (WRONG - init path only)
    ; v39: STD $017B (CORRECT - dwell intermediate)
    STD     DWELL_INTM_RAM      ; FD 01 7B  Store real value to dwell RAM ($017B)
    RTS                         ; 39        Return to caller

INJECT_FAKE:
    ;--- Store FAKE value (spark cut active) ---
    PULA                        ; 32       Clean up stack (discard saved A)
    LDD     #FAKE_PERIOD        ; CC 3E 80  Load fake dwell value (16000)
    ; v38: STD $194C (WRONG - init path only)
    ; v39: STD $017B (CORRECT - dwell intermediate)
    STD     DWELL_INTM_RAM      ; FD 01 7B  Store fake value to dwell RAM ($017B)
    RTS                         ; 39        Return to caller

;==============================================================================
; ASSEMBLED BYTES (FIXED 2026-02-07 - A register preservation)
;==============================================================================
; Address  | Hex Bytes              | Instruction
; ---------|------------------------|------------------------------------------
; $C500    | 36                     | PSHA (save A = real period!)
; $C501    | 12 46 80 0B            | BRSET $46,$80,CHECK_RESUME ($C510)
; $C505    | 96 A2                  | LDAA $A2 (load RPM)
; $C507    | 81 F0                  | CMPA #$F0 (compare 6000 RPM) [or $78 for 3000]
; $C509    | 25 0E                  | BCS STORE_NORMAL ($C519)
; $C50B    | 14 46 80               | BSET $46,$80 (set limiter flag)
; $C50E    | 20 0E                  | BRA INJECT_FAKE ($C51E)
; CHECK_RESUME:
; $C510    | 96 A2                  | LDAA $A2
; $C512    | 81 EC                  | CMPA #$EC (compare 5900 RPM) [or $74 for 2900]
; $C514    | 24 08                  | BCC INJECT_FAKE ($C51E)
; $C516    | 15 46 80               | BCLR $46,$80 (clear limiter flag)
; STORE_NORMAL:
; $C519    | 32                     | PULA (restore A = real period!)
; $C51A    | FD 01 7B               | STD $017B (store real dwell intermediate) ✅
; $C51D    | 39                     | RTS
; INJECT_FAKE:
; $C51E    | 32                     | PULA (clean stack)
; $C51F    | CC 3E 80               | LDD #$3E80 (load fake period)
; $C522    | FD 01 7B               | STD $017B (store fake dwell value) ✅
; $C525    | 39                     | RTS
; SIGNATURE:
; $C526    | 4A 4B 26 xx            | "JK" v38 variant (01=3000, 02=6000)
;
; Total: 42 bytes (38 code + 4 signature)
;==============================================================================
;
; PATCH BYTES - v39 CORRECTED ($017B hook), 6000 RPM:
; 36 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0E
; 96 A2 81 EC 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 26 02
;
; PATCH BYTES - v39 CORRECTED ($017B hook), 3000 RPM (TEST):
; 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E
; 96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC
; 3E 80 FD 01 7B 39 4A 4B 26 01
;
; ❌ OLD v38 PATCH BYTES (WRONG - used $194C init path):
; 36 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0E
; 96 A2 81 EC 24 08 15 46 80 32 FD 19 4C 39 32 CC
; 3E 80 FD 19 4C 39 4A 4B 26 02
;==============================================================================

;==============================================================================
; INSTALLATION INSTRUCTIONS (CORRECTED 2026-02-02)
;==============================================================================
;
; STEP 1: Copy our code to free space
;         File offset 0x0C500: Write the assembled bytes above
;
; STEP 2: Patch the hook point in dwell calculation
;         File offset 0x101E1: Change FD 01 7B → BD C5 00
;         (Changes "STD $017B" to "JSR $C500")
;         ❌ OLD v38: 0x13618 (STD $194C) — init path only, DO NOT USE
;
; STEP 3: Update checksum (if required by flash tool)
;
; VERIFICATION:
;   - At idle: $0046 bit 7 should be 0 (limiter off)
;   - Rev to 6000+ RPM: $0046 bit 7 should be 1 (cutting)
;   - RPM should bounce at ~6000 RPM
;   - Exhaust note: Should sound like ignition cut (pops/burble)
;
;==============================================================================

;==============================================================================
; FOR >6375 RPM LIMITERS (Chr0m3's 7200 RPM mod)
;==============================================================================
; The 8-bit RPM variable overflows at 255 × 25 = 6375 RPM
; For higher limits, Chr0m3 patched these dwell constants:
;
; Location      | Stock | 7200 RPM | Purpose
; --------------|-------|----------|---------------------------
; MIN_DWELL     | $A2   | $9A      | Saves 8µs dwell time
; MIN_BURN      | $24   | $1C      | Saves 8µs burn time
;
; These patches allow the TIO to handle shorter dwell times at high RPM
; WITHOUT these patches, spark will fail above ~6400 RPM regardless
;
; Chr0m3: "ones that control min dwell and max burn and then I believe 
;          there's hard coded thresholds in the TIO microcode"
;==============================================================================

            END

;##############################################################################
;#              VERIFICATION SUMMARY (2026-02-02, fixed 2026-02-07)           #
;##############################################################################
;
; ✅ RPM_ADDR ($00A2)      - 82 code references, 8-bit value
; ✅ DWELL_INTM ($017B)    - STD @ 0x101E1, dwell intermediate (CORRECT HOOK)
; ✅ PERIOD_24X ($194C)    - Init @ $3618; real updates via filter sub $050C
; ✅ LIMITER_FLAGS ($0046) - Bit 7 confirmed FREE (no stock usage)
; ✅ FAKE_PERIOD ($3E80)   - Chr0m3 validated value
; ✅ Free space ($C500)    - 15,000+ bytes of zeros confirmed
; ✅ Hook point (0x101E1)  - FD 01 7B = STD $017B (dwell calc path)
;
; ❌ WRONG: Hook at 0x13618 (STD $194C) = init path only, filter overwrites!
; ❌ v38 incorrectly switched from $017B to $194C — this is reversed in v38.1+ bins
;
; ⚠️ REQUIRES BENCH TESTING BEFORE VEHICLE USE
; ⚠️ Monitor $0046 bit 7 via ALDL to confirm operation
;
;##############################################################################
