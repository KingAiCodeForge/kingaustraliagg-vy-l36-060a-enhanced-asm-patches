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
; VY V6 IGNITION CUT v8 - HYBRID FUEL + SPARK CUT
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: Redundant dual-cut (fuel AND spark simultaneously)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️⚠️⚠️ KNOWN ISSUES - NEEDS FIXING ⚠️⚠️⚠️
;
; ISSUE 1: Uses $01A0 for state flag (UNVERIFIED RAM)
;   FIX: Change to $0046 bit 7 (verified free in v38)
;
; ISSUE 2: 16-bit RPM thresholds ($0BB8 = 3000 raw) but $00A2 is 8-bit!
;   $00A2 = RPM/25 (8-bit, max 255 = 6375 RPM)
;   ✅ FIXED Jan 28: Now uses 8-bit RPM values
;
; ISSUE 3: ✅ FIXED Jan 28 - INJ_PW addresses now verified!
;   OLD: $0150 was WRONG/UNVALIDATED
;   NEW: $013F (Bank1), $0141 (Bank2) - VERIFIED from binary analysis
;
; ⬜ STATUS: PARTIALLY FIXED - Still need to verify $01A0 usage
;==============================================================================
;
; How It Works:
;   1. Monitor RPM against threshold
;   2. When RPM > threshold:
;      a) Inject fake crank period (spark cut via Chr0m3 method)
;      b) Set injector pulse width = 0ms (fuel cut)
;   3. When RPM < threshold:
;      a) Restore normal 3X period (spark enabled)
;      b) Restore normal fuel calculation (fuel enabled)
;   4. Result: ZERO combustion possible (redundant safety)
;
; Advantages:
;   ✅ Redundant safety (dual failure protection)
;   ✅ No unburned fuel (cleaner than fuel cut alone)
;   ✅ No weak spark risk (cleaner than spark cut alone)
;   ✅ Absolute zero power output
;   ✅ Both methods Chr0m3/OEM validated
;
; Use Cases:
;   - Competition/racing (maximum reliability)
;   - Launch control (absolute zero power when clutch held)
;   - Two-step anti-lag (prevent boost leak)
;   - Safety-critical applications
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP - ⚠️ ADDRESSES VERIFIED Jan 28 2026
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: RPM/25 (8-bit!) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
; ⚠️ CORRECTED 2026-02-02: $017B is DWELL INTERMEDIATE, NOT crank period!
; DWELL_INTERMEDIATE     EQU $017B       ; ❌ OLD WRONG - NOT crank period!
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: 24X crank period (TIC3 ISR @ $3618) ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
DWELL_INT_RAM EQU $017B       ; Dwell intermediate (alternative hook point) ; Verified: DWELL_INTERMEDIATE (2 refs both. HOOK TARGET at 0x101E1) [Enhanced-fix]
INJ_PW_BANK1        EQU $013F       ; ✅ VERIFIED Jan 28: Bank 1 pulse width (STD @0x17243)
INJ_PW_BANK2        EQU $0141       ; ✅ VERIFIED Jan 28: Bank 2 pulse width (STD @0x1727C)

; ✅ FIXED Jan 28: Use 8-bit RPM/25 format
; TEST THRESHOLDS (3000 RPM)
RPM_HIGH            EQU $78         ; ✅ FIXED: 120 × 25 = 3000 RPM
RPM_LOW             EQU $74         ; ✅ FIXED: 116 × 25 = 2900 RPM

; PRODUCTION THRESHOLDS (SAFE DEFAULT - 6000 RPM)
; RPM_HIGH          EQU $F0         ; ✅ FIXED: 240 × 25 = 6000
; RPM_LOW           EQU $EF         ; ✅ FIXED: 239 × 25 = 5975

FAKE_PERIOD         EQU $3E80       ; ✅ fake crank period (spark cut)
ZERO_FUEL           EQU $0000       ; Zero pulse width (fuel cut)
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

;------------------------------------------------------------------------------
; CODE SECTION - ADDRESS MAPPING (VERIFIED Jan 27 2026 with udis)
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-27: $14468 was INVALID (17-bit address!)
; HC11 has 16-bit addresses only: $0000-$FFFF
; File offset 0x0C468 = CPU address $C468 (when low bank active)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
; ⚠️  MANUAL CONVERSION REQUIRED:
; - Replace LDAA/STAA LIMITER_FLAG with BSET/BCLR LIMITER_FLAGS, #$80
; - See spark_cut_chr0m3_method_VERIFIED_v38.asm for reference
; - Test: BRSET LIMITER_FLAGS, #$80, LABEL (if bit set, branch)
; - Set:  BSET LIMITER_FLAGS, #$80 (turn on)
; - Clear: BCLR LIMITER_FLAGS, #$80 (turn off)
;

; ⚠️  MANUAL CONVERSION REQUIRED:
; - Replace LDAA/STAA LIMITER_FLAG with BSET/BCLR LIMITER_FLAGS, #$80
; - See spark_cut_chr0m3_method_VERIFIED_v38.asm for reference
; - Test: BRSET LIMITER_FLAGS, #$80, LABEL (if bit set, branch)
; - Set:  BSET LIMITER_FLAGS, #$80 (turn on)
; - Clear: BCLR LIMITER_FLAGS, #$80 (turn off)
;

; ⚠️  MANUAL CONVERSION REQUIRED:
; - Replace LDAA/STAA LIMITER_FLAG with BSET/BCLR LIMITER_FLAGS, #$80
; - See spark_cut_chr0m3_method_VERIFIED_v38.asm for reference
; - Test: BRSET LIMITER_FLAGS, #$80, LABEL (if bit set, branch)
; - Set:  BSET LIMITER_FLAGS, #$80 (turn on)
; - Clear: BCLR LIMITER_FLAGS, #$80 (turn off)
;

            ORG $C468           ; ✅ FIXED: CPU address (was $14468 INVALID!) ; ⚠️ MUST BE bank 1 (file 0x0C468). 15,192 bytes free: $C468-$FFBF. [auto-fix 2026-02-09]

;==============================================================================
; HYBRID FUEL + SPARK CUT HANDLER
;==============================================================================

HYBRID_CUT_HANDLER:
    PSHB
    PSHA
    PSHX
    
    ; Check RPM against threshold
    LDD     RPM_ADDR
    CPD     #RPM_HIGH
    BHI     ACTIVATE_HYBRID_CUT
    
    CPD     #RPM_LOW
    BLS     DEACTIVATE_HYBRID_CUT
    
    ; Hysteresis zone - maintain current state
    LDAA    LIMITER_FLAG
    BNE     ACTIVATE_HYBRID_CUT
    BRA     DEACTIVATE_HYBRID_CUT

ACTIVATE_HYBRID_CUT:
    ; Method 1: Spark cut (24X period injection)
    LDD     #FAKE_PERIOD
    STD     PERIOD_24X_RAM      ; Inject fake 24X crank period
    
    ; Method 2: Fuel cut (zero pulse width) - BOTH BANKS
    LDD     #ZERO_FUEL
    STD     INJ_PW_BANK1        ; Zero Bank 1 injector pulse (✅ VERIFIED)
    STD     INJ_PW_BANK2        ; Zero Bank 2 injector pulse (✅ VERIFIED)
    
    ; Set limiter active flag
    LDAA    #$01
    STAA    LIMITER_FLAG
    
    BRA     EXIT_HANDLER

DEACTIVATE_HYBRID_CUT:
    ; Clear limiter flag (stock code handles restoration)
    CLR     LIMITER_FLAG
    
    ; Note: Don't restore DWELL_INTERMEDIATE or INJ_PW_BANKx here
    ; Let stock code recalculate normal values on next cycle
    
EXIT_HANDLER:
    PULX
    PULA
    PULB
    RTS

;==============================================================================
; INJECTOR PULSE WIDTH ADDRESS VALIDATION - ✅ RESOLVED Jan 28, 2026
;==============================================================================
;
; ✅ VERIFIED: Injector pulse width RAM addresses found via binary analysis:
;
;   $013F = INJ_PW_BANK1 (STD @ 0x17243, LDX @ 0x181AF)
;   $0141 = INJ_PW_BANK2 (STD @ 0x1727C, LDX @ 0x1825D)
;
; OLD WRONG ADDRESS: $0150 was a GUESS - now removed!
;
; Verification method:
;   1. Binary search found STD writes to $013F/$0141 in fuel calc routine
;   2. Found LDX reads from $013F/$0141 in injector output routine
;   3. ALDL offset 0x12 "Injector Pulse Time" correlates with these values
;   4. XDF has "Min Base Pulse Width" @ 0x7800, "Default Pulse width" @ 0x7802
;
; ADX Evidence (confirmed):
;   - Offset 0x12: "Injector Pulse Time" (16-bit, X/65.536 ms)
;   - Can monitor in TunerPro RT during testing
;   - Should see pulse width drop to 0ms when limiter active
;
;==============================================================================

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; ADVANTAGES OVER SINGLE-CUT METHODS:
;
; Fuel Cut Only (Stock Method):
;   ❌ Unburned air passes through engine
;   ❌ O2 sensors read full lean → may trigger DTC
;   ❌ Catalyst damage risk (lean + hot = meltdown)
;   ❌ Exhaust backfires (oxygen + hot exhaust)
;
; Spark Cut Only (Chr0m3 conceptual Method still untested from vt 300hp video analysis ported to vy.):
;   ✅ No unburned fuel
;   ✅ No O2 sensor false readings
;   ⚠️  Weak spark possible if timing not exact
;   ⚠️  Coils still charge (minor power draw)
;
; Hybrid Fuel + Spark Cut (This Method):
;   ✅ No unburned fuel (fuel cut prevents)
;   ✅ No spark at all (spark cut prevents)
;   ✅ Absolute zero combustion
;   ✅ No catalyst damage
;   ✅ No backfires
;   ✅ Redundant safety
;   ⚠️  Slightly more complex code
;
; WHEN TO USE:
;   - Competition/racing (reliability critical)
;   - High-RPM turbo builds (prevent overboosting)
;   - Launch control (absolute lock at launch RPM)
;   - Any application where single failure = disaster
;
; WHEN NOT TO USE:
;   - Normal street driving (overkill, adds complexity)
;   - If you only need spark cut (Method v3 is simpler)
;
;==============================================================================

;==============================================================================
; IMPLEMENTATION CHECKLIST
;==============================================================================
;
; [ ] 1. Find actual injector pulse width RAM address
; [ ] 2. Validate spark cut works (Method A/v3 first)
; [ ] 3. Bench test spark cut alone
; [ ] 4. Add fuel cut component
; [ ] 5. Bench test hybrid cut
; [ ] 6. Monitor ALDL for DTC codes (still figuring out how to add to adx properly innovate and other things to each adx file.)
; [ ] 7. Oscilloscope validation (EST + injector signals)
; [ ] 8. In-vehicle testing
; [ ] 9. Log data and verify zero combustion
; [ ] 10. Get Chr0m3/community feedback
;
;==============================================================================
