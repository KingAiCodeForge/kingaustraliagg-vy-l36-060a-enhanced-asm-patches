;==============================================================================
; VY V6 IGNITION CUT LIMITER - v3
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: November 26, 2025
; Method: 3X Period Injection (validated on VY V6 Ecotec)
; Video Reference: "300 HP 3.8L N/A Ecotec Burnout Car Project: Week 5" (mxoHSRijWds)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (RECOMMENDED)
;         Enhanced has fuel cut disabled (0xFF = 6375 RPM)
;         Stock has fuel cut at 5900 RPM - would conflict with ignition cut we could remove stock fuel cut entirely and put in ignition cut logic if we know where to put it and remove it
; Processor: Motorola MC68HC11
;
; Description:
;   Implements two-stage hard-cut rev limiter by injecting fake 3X period
;   values during high RPM. This causes dwell calculation to produce
;   insufficient coil charging time, preventing spark without triggering
;   ECU failsafe systems.
;
; Theory:
;   Normal:  3X period = 10ms  → dwell = 600µs → SPARK ✅
;   Cut:     3X period = 1000ms (fake) → dwell = 100µs → NO SPARK ❌
;
; CRITICAL HARDWARE LIMITS (Chr0m3 Validated):
;   - 6375 RPM (0xFF × 25) = Factory ECU MAXIMUM (fuel cut table limit)
;   - 6350 RPM = Hard ignition control limit ("above 6350 you lose the limiter")
;   - 6500 RPM = Total spark control loss (dwell+burn timer overflow)
;   - Timer overflow: Min Dwell (0xA2/162µs) + Min Burn (0x24/36µs) = 880µs total
;   - At 6500 RPM: 3X period = 3080µs, combined timing = 880µs → overflow = 0 = no spark
;   - 7200 RPM = Achievable ONLY with Chr0m3's min burn/dwell patches
;
; Chr0m3's 7200 RPM Patches (addresses unknown):
;   - Min Dwell: 0xA2 (162) → 0x9A (154) = saves 8µs
;   - Min Burn: 0x24 (36) → 0x1C (28) = saves 8µs
;   - Result: 880µs → 864µs allows 7200 RPM operation
;
; STATUS: ✅ Chr0m3 APPROVED - "More robust than pulling dwell"
; VERSION: v3 - Enhanced with hysteresis (RECOMMENDED)
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; RPM address (confirmed 82R/2W)
PERIOD_3X_RAM   EQU $017B       ; 3X period storage (confirmed 1W @ 0x181E1)
DWELL_RAM       EQU $0199       ; Dwell time storage
; TEST THRESHOLDS (3000 RPM for in-car validation - Moates doesn't work on VY V6)
RPM_HIGH        EQU $0BB8       ; 3000 RPM activation threshold (test)
RPM_LOW         EQU $0B54       ; 2900 RPM deactivation threshold (100 RPM hysteresis)

; PRODUCTION THRESHOLDS (uncomment after validation)
; === Validated Options ===
; Option A: Conservative - Stock ECU Limit (RECOMMENDED for testing)
; RPM_HIGH        EQU $18E7       ; 6375 RPM activation (factory limit)
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
LIMITER_FLAG    EQU $01A0       ; Free RAM byte for limiter state (0=off, 1=on)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains JSR $24AB active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED by binary analysis (was $18156 WRONG!)

;==============================================================================
; IGNITION CUT MAIN HANDLER
;==============================================================================
; This routine is called INSTEAD of the stock "STD $017B" instruction at
; address 0x181E1. The D register contains the real 3X period calculated
; by the stock code.
;
; Entry: D register = real 3X period from stock calculation
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
    STD  PERIOD_3X_RAM          ; Store fake period to RAM 0x017B
    RTS                         ; Return to caller (stock code continues)
    
    ;--------------------------------------------------------------------------
    ; Use real 3X period (normal operation)
    ;--------------------------------------------------------------------------
RESTORE_NORMAL:
    PULB                        ; Restore B from stack (real period low byte)
    PULA                        ; Restore A from stack (real period high byte)
    ; D register now contains original real 3X period
    STD  PERIOD_3X_RAM          ; Store real period to RAM 0x017B
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
; 3. Modify hook point at 0x181E1:
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
