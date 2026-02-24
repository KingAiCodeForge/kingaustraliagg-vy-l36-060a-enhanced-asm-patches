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
; VY V6 IGNITION CUT LIMITER v2 - OUTPUT COMPARE FORCE-LOW METHOD
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: November 26, 2025
; Method: Alternative - EST Pin Force-Low (REQUIRES HARDWARE VALIDATION)
; Reference: IGNITION_CUT_VIABLE_METHODS_ANALYSIS.md - Method B
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (RECOMMENDED)
;         Enhanced has fuel cut disabled (0xFF = 6375 RPM)
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: This method is SPECULATIVE and requires oscilloscope validation!
; ⚠️ EST pin assignment (PA5/OC3) must be confirmed before use
; ⚠️ May trigger failsafe systems if ECU monitors EST feedback
;
; Description:
;   Alternative ignition cut method that forces EST output pin LOW during
;   high RPM, preventing coil firing entirely. Simpler than 3X period
;   injection but UNVALIDATED on VY V6 hardware.
;
; Theory:
;   Normal:  EST pin toggles HIGH/LOW → coil fires → SPARK ✅
;   Cut:     EST pin forced LOW → coil never fires → NO SPARK ❌
;
; vs Method v1 (crank period injection):
;   v1: Works WITH hardware (manipulates dwell calculation inputs)
;   v2: Forces hardware output LOW (may conflict with TIO module)
;
; vs Method v3 (Timing Retard):
;   v2: Complete spark cut (no combustion)
;   v3: Spark occurs but at wrong timing (partial combustion)
;
; Notes:
;   - Stock ECU hard limit: 6,375 RPM
;   - WARNING: "Flipping EST off turns bypass on" (failsafe risk!)
;   - This method requires validation (use v1 for proven approach)
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; RPM address (confirmed 82R/2W) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
DWELL_INTERMEDIATE  EQU $017B       ; Dwell intermediate calc (CORRECTED: was wrongly called 3X period)
DWELL_RAM EQU $0199       ; Dwell time storage ; Verified: DWELL_TIME_RAM (8 refs both) [Enhanced-fix]
; TEST THRESHOLDS (3000 RPM for in-car validation - Moates doesn't work on VY V6)
RPM_HIGH        EQU $0BB8       ; 3000 RPM activation threshold (test)
RPM_LOW         EQU $0B54       ; 2900 RPM deactivation threshold (100 RPM hysteresis)

; PRODUCTION THRESHOLDS (uncomment after validation)
; === Chr0m3-Validated Options ===
; Option A: Conservative - Stock ECU Limit (RECOMMENDED for testing)
; RPM_HIGH        EQU $18E7       ; 6375 RPM activation (Chr0m3: factory limit)
; RPM_LOW         EQU $18D3       ; 6355 RPM deactivation (20 RPM hysteresis)

; Option B: Moderate - Chr0m3's Tested Maximum (requires dwell/burn patches!)
; RPM_HIGH        EQU $1C20       ; 7200 RPM activation (Chr0m3: tested on VY V6)
; RPM_LOW         EQU $1C0C       ; 7180 RPM deactivation (20 RPM hysteresis)
; WARNING: Requires minimum dwell (0xA2→0x9A) and burn (0x24→0x1C) patches first!

; === Community Options ===
; Option C: Community Consensus (SAFE for N/A)
; RPM_HIGH        EQU $18A4       ; 6300 RPM activation (PCMhacking tested)
; RPM_LOW         EQU $1890       ; 6280 RPM deactivation (20 RPM hysteresis)

; Option D: Match stock fuel cut (CONSERVATIVE)
; RPM_HIGH        EQU $170C       ; 5900 RPM activation (stock redline)
; RPM_LOW         EQU $16F8       ; 5875 RPM deactivation (25 RPM hysteresis)
FAKE_PERIOD     EQU $3E80       ; 16000 = 1000ms fake period
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains JSR $24AB active code)
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

            ORG $C468          ; Free space VERIFIED by binary analysis (was $18156 WRONG!) ; FIXED: $14468 is a FILE OFFSET, not CPU addr. CPU=$C468 bank 2 (file 0x14468) [Enhanced-fix]

;==============================================================================
; IGNITION CUT MAIN HANDLER
;==============================================================================
; This routine is called INSTEAD of the stock "STD $017B" instruction at
; address 0x101E1. The D register contains the real crank period calculated
; by the stock code.
;
; Entry: D register = real crank period from stock calculation
; Exit:  D register = either real period OR fake period (depending on RPM)
;        RAM 0x017B = stored period value
;
; Stack usage: 2 bytes (PSHA + PSHB)
;==============================================================================

IGNITION_CUT_MAIN:
    PSHA                        ; Save A register (high byte of period)
    PSHB                        ; Save B register (low byte of period)
    
    ; Load current limiter state
    LDAA LIMITER_FLAG           ; A = current state (0=off, 1=on)
    CMPA #$01                   ; Is limiter currently active?
    BEQ  CHECK_LOW_THRESHOLD    ; Yes, check if we should deactivate
    
    ;--------------------------------------------------------------------------
    ; Limiter OFF - Check if we should activate
    ;--------------------------------------------------------------------------
CHECK_HIGH_THRESHOLD:
    LDD  RPM_ADDR               ; D = current RPM (16-bit)
    CMPD #RPM_HIGH              ; Compare with 6400 RPM
    BLS  RESTORE_NORMAL         ; RPM <= 6400, use normal period (branch)
    
    ; RPM > 6400: Activate limiter
ACTIVATE_LIMITER:
    LDAA #$01                   ; Set limiter flag to 1 (active)
    STAA LIMITER_FLAG           ; Store to RAM
    BRA  INJECT_FAKE_PERIOD     ; Jump to fake period injection
    
    ;--------------------------------------------------------------------------
    ; Limiter ON - Check if we should deactivate
    ;--------------------------------------------------------------------------
CHECK_LOW_THRESHOLD:
    LDD  RPM_ADDR               ; D = current RPM (16-bit)
    CMPD #RPM_LOW               ; Compare with 6300 RPM
    BHI  INJECT_FAKE_PERIOD     ; RPM > 6300, keep cutting (branch)
    
    ; RPM <= 6300: Deactivate limiter (hysteresis band)
DEACTIVATE_LIMITER:
    LDAA #$00                   ; Clear limiter flag to 0 (inactive)
    STAA LIMITER_FLAG           ; Store to RAM
    BRA  RESTORE_NORMAL         ; Use real period
    
    ;--------------------------------------------------------------------------
    ; Inject fake high period (creates insufficient dwell)
    ;--------------------------------------------------------------------------
INJECT_FAKE_PERIOD:
    PULB                        ; Restore B from stack (discard real period low byte)
    PULA                        ; Restore A from stack (discard real period high byte)
    LDD  #FAKE_PERIOD           ; D = 16000 (1000ms fake period)
    STD  DWELL_INTERMEDIATE          ; Store fake dwell value to $017B (dwell intermediate)
    RTS                         ; Return to caller (stock code continues)
    
    ;--------------------------------------------------------------------------
    ; Use real crank period (normal operation)
    ;--------------------------------------------------------------------------
RESTORE_NORMAL:
    PULB                        ; Restore B from stack (real period low byte)
    PULA                        ; Restore A from stack (real period high byte)
    ; D register now contains original real crank period
    STD  DWELL_INTERMEDIATE          ; Store real dwell value to $017B (dwell intermediate)
    RTS                         ; Return to caller

;==============================================================================
; END OF PATCH
;==============================================================================

;------------------------------------------------------------------------------
; INSTALLATION INSTRUCTIONS
;------------------------------------------------------------------------------
; 1. Assemble this file:
;    as11 ignition_cut_patch.asm -o ignition_cut_patch.s19
;
; 2. Extract binary from S19 file and inject into stock binary at 0x18156
;
; 3. Modify hook point at 0x101E1:
;    Original: FD 01 7B  (STD $017B)
;    Modified: BD 18 156 (JSR $18156)
;
; 4. Recalculate checksum for ECU
;
; 5. In-car validation testing (Moates Ostrich 2.0 incompatible with VY V6)
;    - Flash to ECU via OSE Flash Tool or EFI Live
;    - Test at 3000 RPM first (SAFE threshold for validation)
;    - After validation, re-compile with production thresholds (6400/6300 RPM)
;
;------------------------------------------------------------------------------
; EXPECTED BEHAVIOR (TEST MODE - 3000 RPM)
;------------------------------------------------------------------------------
; RPM < 2900: Normal spark, limiter inactive
; RPM 2900-3000: Hysteresis band (100 RPM), limiter state unchanged
; RPM > 3000: Limiter activates, spark cut via short dwell (~100µs)
; RPM drops < 2900: Limiter deactivates instantly, spark restored
;
; EXPECTED BEHAVIOR (PRODUCTION - 6400 RPM - AFTER VALIDATION)
; RPM < 6300: Normal spark, limiter inactive
; RPM 6300-6400: Hysteresis band (100 RPM), limiter state unchanged  
; RPM > 6400: Limiter activates, spark cut via short dwell (~100µs)
; RPM drops < 6300: Limiter deactivates instantly, spark restored
;
;------------------------------------------------------------------------------
; VALIDATION CHECKLIST
;------------------------------------------------------------------------------
; [ ] Oscilloscope shows ~600µs dwell at idle (normal operation)
; [ ] Oscilloscope shows ~100µs dwell at 3000+ RPM (test threshold - cut active)
; [ ] EST signal continues firing during cut (no failsafe triggered)
; [ ] No DTC codes generated (P0300-P0306 misfire codes)
; [ ] Smooth RPM bounce at 3000 RPM limiter (not harsh stutter like stock fuel cut)
; [ ] Instant recovery when RPM drops below 2900 RPM (hysteresis working)
; [ ] After validation, re-compile with 6400/6300 RPM for production use
;
;------------------------------------------------------------------------------

would 5900rpm be better for production.
instead of 6300 rpm
do we remove the spark cut in the assembly in the enhanced bin and then place our ignition cut logic there?
