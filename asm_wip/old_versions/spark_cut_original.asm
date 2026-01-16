;==============================================================================
; VY V6 IGNITION CUT LIMITER - 3X PERIOD INJECTION METHOD
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: November 26, 2025 (Updated: January 14, 2026)
; Method: 3X Period Injection (validated on VY V6 Ecotec)
; Video Reference: "300 HP 3.8L N/A Ecotec Burnout Car Project: Week 5" (mxoHSRijWds)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (RECOMMENDED)
;         Enhanced has fuel cut disabled (0xFF = 6375 RPM)
;         Stock has fuel cut at 5900 RPM - would conflict with ignition cut (can be deleted out entirely the fuel cut stuff. chr0m3 said he has done this before.)
; Processor: Motorola MC68HC711E9 (NOT 68332 - no TPU/TIO coprocessor!)
;
; ARCHITECTURE NOTES (from Freescale MC68HC711E9 Bootloader ROM listing):
;   - Standard timer subsystem (Output Compare OC1-OC5, Input Capture IC1-IC3)
;   - NO separate TIO microcode - all timing controlled by main CPU code
;   - Pseudo-vector table: Interrupt vectors point to RAM, firmware places JMPs
;   - TIC3 (3X crank) vector → $00C4 in RAM
;   - TIC2 (24X crank) vector → $00E5 in RAM
;   - This means ignition timing ISRs ARE in user-flashable code, NOT mask ROM!
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
; Chr0m3's 7200 RPM Patches (addresses need binary search):
;   - Min Dwell: 0xA2 (162) → 0x9A (154) = saves 8µs
;   - Min Burn: 0x24 (36) → 0x1C (28) = saves 8µs
;   - Result: 880µs → 864µs allows 7200 RPM operation
;
; STATUS: ✅ Chr0m3 APPROVED - "More robust than pulling dwell"
;
;==============================================================================
;
; ⚠️⚠️⚠️ CRITICAL WARNING - FREE SPACE USAGE RISKS ⚠️⚠️⚠️
;
; This patch uses "free space" at $0C468 (file offset 0x0C468-0x0FFBF).
; While this region APPEARS as zeros in the binary, using it may affect:
;
;   • Unknown ISR (Interrupt Service Routine) pseudo-vector tables
;   • Memory-mapped calibration lookup paths the ECU scans at runtime
;   • Banking/bridging logic for bank switching coordination
;   • Diagnostic/bootloader reserved space for service tool access
;   • Enhanced v1.0a specific features (The1's modifications)
;   • Future calibration expansion expected by tuning software
;   • Checksum calculation dependencies (zeros may be intentional)
;
; ENHANCED v1.0a (OSID 92118883) UNKNOWN MODIFICATIONS:
;   - Base: Stock Delco 92118883 firmware
;   - Modified by: "The1" from PCMHacking.net
;   - Known additions: Higher-rate logging, modified knock, diagnostics
;   - UNKNOWN additions: May use "free" space for runtime features
;
; HC11 PSEUDO-VECTOR BRIDGE SYSTEM (Why "free" space is risky):
;   Hardware Vectors ($FFD6-$FFFE) → Pseudo-Vectors ($1FFC0-$1FFFF)
;   Pseudo-vectors contain JMP instructions to actual ISR code
;   Example: $FFEA (TI3/3X crank) → JMP $AAC5 (actual ISR handler)
;   Enhanced v1.0a may have ADDITIONAL ISRs using zero regions!
;
; BANKING ARCHITECTURE (Why injection location matters):
;   - 128KB flash divided into Bank 0 (0x00000-0x0FFFF) and Bank 1 (0x10000-0x1FFFF)
;   - Both banks map to CPU address space $0000-$FFFF via A16/A17 switching
;   - Code at file 0x0C468 = CPU $0C468 ONLY when Bank 0 is active
;   - If dwell routine runs from Bank 1, it CANNOT reach this patch!
;
; CHR0M3'S RECOMMENDED METHOD (NOT used in this patch):
;   "Modify existing calibration VALUES, not inject new CODE"
;   Example: Min Dwell ROM address → change 0xA2 to 0x9A (single byte)
;   This avoids ALL the risks above but requires finding exact ROM locations.
;
; WHY THIS PATCH USES CODE INJECTION ANYWAY:
;   - Demonstrates the 3X period injection technique
;   - Educational/experimental purpose
;   - May work on some ECUs, may fail on others
;   - BENCH TEST REQUIRED before in-car use!
;
; FOR COMPLETE TECHNICAL EXPLANATION:
;   See: WHY_ZEROS_CANT_BE_USED_Chrome_Explanation.md
;
; VALIDATION REQUIREMENTS:
;   1. Oscilloscope verification of EST signal
;   2. Confirm no DTC codes triggered (P1345, P0300, P0327, P1374)
;   3. Test on bench harness before vehicle installation
;   4. Verify dwell timing at various RPMs (1000-6500)
;   5. Monitor for ECU failsafe activation
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP (VERIFIED 2026-01-14 from XDF v2.09a + binary analysis)
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; RPM address (VERIFIED: 82R/2W in binary)
PERIOD_3X_RAM   EQU $017B       ; 3X period storage (VERIFIED: 1W @ 0x181E1)
DWELL_RAM       EQU $0199       ; Dwell time storage (VERIFIED from code analysis)
MIN_BURN_ROM    EQU $19813      ; Min burn constant ROM (VERIFIED: LDAA #$24 = 36 decimal)
DWELL_THRESH    EQU $6776       ; Dwell threshold CAL (VERIFIED: XDF "Delta Cylair > This")
; TEST THRESHOLDS (3000 RPM for in-car validation - Moates doesn't work on VY V6)
RPM_HIGH        EQU $0BB8       ; 3000 RPM activation threshold (test)
RPM_LOW         EQU $0B54       ; 2900 RPM deactivation threshold (100 RPM hysteresis)

; PRODUCTION THRESHOLDS (uncomment after validation)
; === RECOMMENDED: 5900 RPM (matches stock redline) ===
; RPM_HIGH        EQU $170C       ; 5900 RPM activation (stock redline - SAFEST)
; RPM_LOW         EQU $16DE       ; 5850 RPM deactivation (50 RPM hysteresis)

; === CONSERVATIVE: 6300 RPM (near ECU limit) ===
; RPM_HIGH        EQU $18A4       ; 6300 RPM activation
; RPM_LOW         EQU $1876       ; 6250 RPM deactivation (50 RPM hysteresis)
; ⚠️ WARNING: Close to Chr0m3's 6350 RPM limit!

; === MAXIMUM SAFE: 6375 RPM (factory ECU maximum) ===
; RPM_HIGH        EQU $18E7       ; 6375 RPM activation (0xFF × 25)
; RPM_LOW         EQU $18B9       ; 6325 RPM deactivation (50 RPM hysteresis)
; ⚠️ WARNING: At absolute ECU limit, no margin for error!

; === EXTREME: 7200 RPM (Chr0m3's tested max) ===
; RPM_HIGH        EQU $1C20       ; 7200 RPM activation
; RPM_LOW         EQU $1BF2       ; 7150 RPM deactivation (50 RPM hysteresis)
; 🔴 DANGER: REQUIRES min burn/dwell patches or ECU loses spark control!
FAKE_PERIOD     EQU $3E80       ; 16000 = 1000ms fake period
LIMITER_FLAG    EQU $01A0       ; Free RAM byte for limiter state (0=off, 1=on)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
            ORG $0C468          ; Free space VERIFIED: 15,192 bytes (was $18156 WRONG!)

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
; EXPECTED BEHAVIOR (PRODUCTION - 6000 RPM - AFTER VALIDATION)
; RPM < 6000: Normal spark, limiter inactive
; RPM 6000-6100: Hysteresis band (100 RPM), limiter state unchanged
; RPM > 6100: Limiter activates, spark cut via short dwell (~100µs)
; RPM drops < 6000: Limiter deactivates instantly, spark restored
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
; [ ] After validation, re-compile with 5900 RPM for production use
;
;------------------------------------------------------------------------------
; NOTES ON ENHANCED BIN
;------------------------------------------------------------------------------
; The Enhanced bin already has fuel cut DISABLED (0xFF = 6375 RPM at $77DE-$77E9)
; There is NO stock spark cut to remove - VY V6 uses fuel cut only
; Your ignition cut logic ADDS new functionality, it doesn't replace anything
; The hook at 0x181E1 intercepts the 3X period write to inject fake values
;
;------------------------------------------------------------------------------
; HC711E9 ARCHITECTURE (from Freescale bootloader ROM listing)
;------------------------------------------------------------------------------
; This ECU uses a standard 68HC711E9 timer, NOT a 68332 with TPU coprocessor
; There is NO separate "TIO microcode" burned into silicon
; All timing logic is in the main CPU code space (user-flashable EPROM/Flash) (eeprom or there could be a second needs confirming. mcu cpu and the ram and rom?)
; 
; Pseudo-Vector System:
;   Interrupt vectors point to RAM locations, firmware places JMP instructions:
;   $00C4 = SCI interrupt handler (serial comms)
;   $00E2 = TIC3 (3X crank) interrupt handler ← YOUR INJECTION POINT
;   $00E5 = TIC2 (24X crank) interrupt handler
;   $00DF = TOC1 (Output Compare 1) ← Dwell/EST control
;
; This means Chr0m3's statement about "TIO microcode" is technically incorrect
; for the HC711E9. The timing routines ARE modifiable via the bin file.
; question for another .asm version is will 6000rpm work for ignition cut or only above the 6350rpm stock hard limit.
; as i (jason king) am not chasing high rpm i am chasing stock rpm with ignition cut.
;------------------------------------------------------------------------------
