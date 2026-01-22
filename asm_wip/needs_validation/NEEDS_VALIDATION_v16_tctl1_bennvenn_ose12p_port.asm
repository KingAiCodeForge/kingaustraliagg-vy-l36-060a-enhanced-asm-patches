;==============================================================================
; VY V6 IGNITION CUT - v16: TCTL1 BENNVENN OSE12P PORT
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ⚠️ NEEDS VALIDATION - Port from OSE12P, requires bench testing
;
; ⚠️ IMPORTANT: This method is THEORETICAL for VY V6. It was proven on
;    OSE12P custom OS but needs validation on VY V6 Enhanced v1.0a
;
;==============================================================================
; OSE 11P/12P PLATFORM REFERENCE (FOR CLARITY)
;==============================================================================
;
; OSE = "Open Source ECM" - Custom firmware for VN-VS Commodore ECUs
; DIFFERENT ECU hardware than VX/VY! Uses 1227808 ECU (VN-VS era)
;
; OSE 11P V104 Base Calibrations (ECU 1227808):
;   - BLCC V8 = VN V8 (OSID $5D) - VL Walkinshaw Group A SS
;   - CAKH V6 = VR V6 Auto (OSID $11C) - Final VR fix calibration
;
; OSE 12P V112 Base Calibrations (ECU 1227808 / 16183082):
;   - APNX V6 = VN V6 (OSID $5D) - Production Run Change, Backfire fix
;   - BLCD V6 = VR V6 Manual (OSID $12B) - Serial Data Fixes
;   - BLCF V8 = VR V8 Manual (OSID $12B) - O2 Malfunction Fix
;
; ⚠️ OSE uses same MC68HC11 CPU but DIFFERENT hardware layout:
;   - 808 timer IC for dwell (external, not internal TIO)
;   - Different EST output routing
;   - Different memory map for calibration data
;   - Addresses from OSE12P do NOT directly map to VY V6 $060A!
;
;==============================================================================
; SOURCE & EVIDENCE
;==============================================================================
;
; Primary Source: PCMHacking Topic 7922 - BennVenn's OSE12P spark cut
; Forum Quote: "Bit 1 at 0x3FFC = 1 = spark cut enabled"
; Evidence Level: ⭐⭐⭐ (proven on OSE12P, but OSE12P ≠ VY V6!)
;
; Method: TCTL1 register bits 5-4 = 10 forces PA5 (EST) LOW
; Why this might work: Hardware-level control, no dwell manipulation
; Why Chr0m3 didn't reject: He never mentioned this method specifically
;
; BennVenn's OSE12P Implementation:
;   - Uses 808 timer IC for dwell control (DIFFERENT from VY V6!)
;   - Sets TCTL1 to force EST output LOW
;   - Proven to produce 300µs minimum dwell (spark cut threshold)
;
;==============================================================================
; VY V6 ADAPTATION NOTES
;==============================================================================
;
; Key Differences from OSE12P:
;   - OSE12P uses external 808 timer IC for dwell
;   - VY V6 has HC11 internal TIO module (hardware-controlled)
;   - TCTL1 register IS present on HC11 at $1020
;   - PA5 (OC3) IS the EST output on VY V6 (validated)
;
; Risk Assessment:
;   - LOW hardware risk (register manipulation only)
;   - MEDIUM software risk (may not produce spark cut on VY)
;   - Requires oscilloscope validation before use
;
;==============================================================================
; MEMORY MAP
;==============================================================================

; Timer Control Registers (MC68HC11 Reference Manual Section 10)
TCTL1           EQU $1020       ; Timer Control Register 1 (OC2-OC5 mode)
TCTL2           EQU $1021       ; Timer Control Register 2 (OC1 mode, edge config)
TMSK1           EQU $1022       ; Timer Mask Register 1 (interrupt enables)
TFLG1           EQU $1023       ; Timer Flag Register 1 (interrupt flags)
PORTA           EQU $1000       ; Port A data register

; Port A Pin Assignments (VY V6 Enhanced v1.0a)
; PA7 = PAI (Pulse Accumulator Input) / OC1
; PA6 = OC2 (High speed fan control)
; PA5 = OC3 (EST Output) ← TARGET FOR SPARK CUT
; PA4 = OC4 (Low speed fan control)
; PA3 = OC5 / IC4

; TCTL1 Bit Definitions for OC3 (Bits 5-4)
; OMx OLx Mode
;  0   0  OC3 disconnected from output pin
;  0   1  Toggle OC3 on successful compare
;  1   0  Clear OC3 on successful compare (force LOW) ← SPARK CUT
;  1   1  Set OC3 on successful compare (force HIGH)

OC3M_DISCONNECT EQU %00000000   ; Bits 5-4 = 00 (disconnect)
OC3M_TOGGLE     EQU %00010000   ; Bits 5-4 = 01 (toggle)
OC3M_CLEAR      EQU %00100000   ; Bits 5-4 = 10 (force LOW) ← SPARK CUT
OC3M_SET        EQU %00110000   ; Bits 5-4 = 11 (force HIGH)
OC3M_MASK       EQU %11001111   ; Mask to clear bits 5-4

; RPM Variables
RPM_ADDR        EQU $00A2       ; 8-BIT RPM/25 (NOT 16-bit!)
LIMITER_FLAG    EQU $77F4       ; Runtime flags byte

; Threshold Constants - CORRECTED to 8-bit scaled
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM activation
RPM_LOW         EQU $EB         ; 235 × 25 = 5875 RPM deactivation

;==============================================================================
; SPARK CUT PATCH - TCTL1 METHOD
;==============================================================================
;
; Theory: Force PA5 (EST) LOW via TCTL1 OC3 mode bits
;
; Normal operation: OC3 mode = 00 or 01 (firmware controls EST)
; Spark cut: OC3 mode = 10 (force LOW, no EST pulses)
;
;==============================================================================

SPARK_CUT_CHECK:
        ; Read 8-bit RPM/25 (CORRECTED from 16-bit)
        LDAA    RPM_ADDR            ; A = current RPM/25 (8-bit)
        TAB                         ; Save to B for later
        
        ; Check if already cutting
        LDAA    LIMITER_FLAG
        BITA    #$01                ; Test bit 0 (spark cut active)
        TBA                         ; Restore RPM to A
        BNE     CHECK_DEACTIVATE    ; If active, check for deactivation

CHECK_ACTIVATE:
        CMPA    #RPM_HIGH           ; Compare with 240 (6000 RPM)
        
CHECK_ACTIVATE:
        ; Not cutting - check if we should start
        CPD     #RPM_HIGH           ; Compare RPM to high threshold
        BLO     EXIT_NO_CHANGE      ; RPM < 6000, no action
        
        ; RPM >= 6000 - activate spark cut
        BSET    LIMITER_FLAG,#$01   ; Set spark cut flag
        
        ; Force OC3 (PA5/EST) LOW via TCTL1
        LDAA    TCTL1               ; Read current TCTL1
        ANDA    #OC3M_MASK          ; Clear bits 5-4
        ORAA    #OC3M_CLEAR         ; Set bits 5-4 = 10 (force LOW)
        STAA    TCTL1               ; Write back → NO SPARK
        
        BRA     EXIT_CUT_ACTIVE
        
CHECK_DEACTIVATE:
        ; Currently cutting - check if we should stop
        CPD     #RPM_LOW            ; Compare RPM to low threshold
        BHS     EXIT_CUT_ACTIVE     ; RPM >= 5924, keep cutting (hysteresis)
        
        ; RPM < 5924 - deactivate spark cut
        BCLR    LIMITER_FLAG,#$01   ; Clear spark cut flag
        
        ; Restore OC3 to firmware control (disconnect)
        LDAA    TCTL1               ; Read current TCTL1
        ANDA    #OC3M_MASK          ; Clear bits 5-4 = 00 (disconnect)
        STAA    TCTL1               ; Write back → firmware controls EST
        
EXIT_NO_CHANGE:
EXIT_CUT_ACTIVE:
        RTS

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; Before flashing to car:
;   1. Bench test with oscilloscope on PA5 (EST output)
;   2. Verify PA5 goes LOW when spark cut activates
;   3. Verify PA5 returns to normal operation when deactivating
;   4. Monitor for any DTC codes (EST circuit errors)
;   5. Compare waveforms with stock ECU operation
;
; Expected Results:
;   - PA5 should show EST pulses during normal operation
;   - PA5 should go LOW during spark cut
;   - No hardware damage expected (register-only manipulation)
;
; If this doesn't work, try:
;   - v17 OC1D forced output (more aggressive)
;   - v33 Chr0m3 3X period injection (validated)
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - ASM_VARIANTS_NEEDED_ANALYSIS.md (priority assessment)
;   - adding_dwell_est_3x_to_xdf.md (register documentation)
;   - MC68HC11_Reference.md (hardware specs)
;
; Archive Sources:
;   - PCMHacking Topic 7922 (BennVenn OSE12P)
;   - PCMHacking Topic 8567 (Chr0m3 spark cut discussion)
;
; Chr0m3 Status: NOT TESTED - He did not reject this method specifically
;   but warned about hardware control: "Hardware controlled by TIO"
;
;==============================================================================
