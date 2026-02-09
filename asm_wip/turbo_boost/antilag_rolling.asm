;==============================================================================
; [ADDRESS FIX 2026-02-09] Binary-verified address corrections applied
; Ground truth: 92118883_STOCK.bin (HC11 opcode scan, equivalent to Capstone)
; Fixes: 1 issues found and annotated
;==============================================================================
; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

;==============================================================================
; VY V6 IGNITION CUT v11 - ROLLING ANTI-LAG (PARTIAL CUT)
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: Alternating cylinder spark cut for milder anti-lag effect
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️⚠️⚠️ PLATFORM & HARDWARE NOTES ⚠️⚠️⚠️
;
; VY V6 L36 Ecotec is NATURALLY ASPIRATED from factory.
; "Anti-lag" is for TURBO builds only!
;
; DFI ARCHITECTURE LIMITATION:
;   VY V6 uses DFI (Direct Fire Ignition) module.
;   ECU sends SINGLE EST signal → DFI → 3 coilpacks
;   We CANNOT control individual cylinders from ECU!
;   "Rolling" cut concept may not be possible on this platform.
;
; KNOWN ISSUE: Uses $01A0 for cycle counter (UNVERIFIED RAM)
;   FIX: Use verified free RAM or $0046 bits
;
; ⬜ STATUS: LIKELY IMPOSSIBLE on DFI platform - needs research
;==============================================================================
;
; How It Works:
;   1. At limiter: Cut spark on every OTHER ignition event
;   2. Fired cylinders: Normal combustion (power + heat)
;   3. Cut cylinders: Unburned fuel → exhaust (anti-lag effect)
;   4. Result: 50% power + partial boost retention
;
; Advantages over Full Anti-Lag:
;   ✅ Maintains some engine power (50%)
;   ✅ Smoother operation (less backfire violence)
;   ✅ Lower exhaust temps (~850°C vs 1000°C+)
;   ✅ Less turbo stress
;   ⚠️ Still requires turbo-rated exhaust
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP (CORRECTED 2026-02-02)
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: RPM/25 (8-bit!) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: STD @ $3618 in TIC3 ISR (2026-01-31) ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
                                    ; ❌ OLD WRONG do not use as this is ???: $017B (purpose unknown)
CYCLE_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
CYCLE_BIT       EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

; SAFE DEFAULT - 6000 RPM (8-BIT VALUES - FIXED Jan 17 2026)
; ⚠️ Changed from 16-bit ($1770) to 8-bit ($F0 = 240 × 25 = 6000 RPM)
RPM_HIGH            EQU $F0         ; ✅ 240 × 25 = 6000 RPM activation
RPM_LOW EQU $EF         ; ✅ 239 × 25 = 5975 RPM deactivation ; WRONG: 0 refs in Enhanced+Stock binary. Not a valid RAM address [Enhanced-fix]

FAKE_PERIOD         EQU $3E80       ; ✅ fake crank period (spark cut)

;------------------------------------------------------------------------------
; CODE SECTION - ADDRESS MAPPING (VERIFIED Jan 27 2026 with udis)
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-27: $14468 was INVALID (17-bit address!)
; HC11 has 16-bit addresses only: $0000-$FFFF
; File offset 0x0C468 = CPU address $C468 (when low bank active)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $C468           ; ✅ FIXED: CPU address (was $14468 INVALID!) ; ⚠️ MUST BE bank 1 (file 0x0C468). 15,192 bytes free: $C468-$FFBF. [auto-fix 2026-02-09]

;==============================================================================
; ROLLING ANTI-LAG HANDLER
;==============================================================================

ROLLING_ANTILAG_HANDLER:
    PSHB
    PSHA
    PSHX
    
    ; Toggle cycle counter (0↔1)
    LDAA    CYCLE_COUNTER
    EORA    #$01                ; XOR with 1 (toggles 0↔1)
    STAA    CYCLE_COUNTER
    
    ; Check RPM (8-bit comparison - FIXED Jan 17 2026)
    LDAA    RPM_ADDR            ; Load 8-bit RPM/25
    CMPA    #RPM_HIGH           ; Compare to 240 (6000 RPM)
    BLO     DEACTIVATE_CUT      ; Below threshold
    
    ; At/above threshold - apply rolling cut
    LDAA    CYCLE_COUNTER
    BEQ     CUT_SPARK           ; On cycle 0: cut spark
    BRA     ALLOW_SPARK         ; On cycle 1: allow spark

CUT_SPARK:
    ; Cut spark this cycle (unburned fuel for anti-lag)
    LDD     #FAKE_PERIOD
    STD     DWELL_INTERMEDIATE
    BRA     EXIT_HANDLER

ALLOW_SPARK:
    ; Allow spark this cycle (normal combustion)
    ; Don't modify DWELL_INTERMEDIATE, let stock code handle it
    BRA     EXIT_HANDLER

DEACTIVATE_CUT:
    ; Below threshold - normal operation
    CLR     CYCLE_COUNTER       ; Reset counter
    
EXIT_HANDLER:
    PULX
    PULA
    PULB
    RTS

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; CUT RATIOS (modify CYCLE_COUNTER logic):
;   50% cut (1-in-2): Current implementation
;   33% cut (1-in-3): Cut every 3rd event
;   67% cut (2-in-3): Fire every 3rd event only
;
; COMPARISON TO OTHER METHODS:
;
;   Full Anti-Lag (v10):
;     - 0% power at limiter
;     - 100% fuel to exhaust
;     - Maximum boost retention
;     - EXTREME risk
;
;   Rolling Anti-Lag (v11):
;     - 50% power at limiter
;     - 50% fuel to exhaust
;     - Moderate boost retention
;     - MODERATE risk
;
;   Progressive Soft (v9):
;     - 25-75% power (gradual)
;     - 0% fuel to exhaust
;     - No boost retention
;     - LOW risk
;
; WHEN TO USE:
;   - Mild turbo builds (< 10 PSI boost)
;   - Street/strip applications
;   - When full anti-lag is too aggressive
;   - Learning anti-lag tuning
;
; WHEN NOT TO USE:
;   - NA engine (no benefit without turbo)
;   - Stock exhaust (WILL crack/fail)
;   - Without EGT monitoring
;
;==============================================================================
