;==============================================================================
; VY V6 IGNITION CUT - Method C: OUTPUT COMPARE DIRECT MANIPULATION
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ⚠️ NEEDS VALIDATION - Hardware method, requires oscilloscope
;
; ⚠️ IMPORTANT: This is a THEORETICAL method. It may partially work or 
;    conflict with the TIO module. Requires bench testing with scope.
;
;==============================================================================
; SOURCE & EVIDENCE
;==============================================================================
;
; Primary Source: MC68HC11 Reference Manual Section 10.4
; Evidence Level: ⭐⭐⭐ (70% confidence - hardware capable)
;
; Method: Direct manipulation of Timer Output Compare registers (TOC1-TOC5)
;         to force EST pin state
;
; Related to: v16 TCTL1 method, v17 OC1D method
;
;==============================================================================
; CHR0M3 WARNINGS ABOUT HARDWARE METHODS
;==============================================================================
;
; Chr0m3 said about hardware timer control:
;
;   "The dwell is hardware controlled by the TIO, that's half of the 
;    problems we get, don't have full control over it."
;
;   "Hardware controlled, flipping EST off turns bypass etc on"
;
; This means:
;   - Direct hardware manipulation may trigger bypass mode
;   - DFI (Distributorless Ignition) may lock timing at 10°
;   - Results may be inconsistent or cause other issues
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; The Output Compare registers (TOC1-TOC5) control when Port A pins
; change state. By manipulating TOC3 (which controls PA5/EST), we
; might be able to prevent EST pulses from occurring.
;
; Approach A: Set TOC3 to a value that never matches TCNT
; Approach B: Use TCTL1 to force the output state
; Approach C: Use OC1M/OC1D to override (see v17)
;
; This file implements Approach A - setting TOC3 to an unreachable value.
;
;==============================================================================
; MEMORY MAP
;==============================================================================

; Timer Registers
TCNT            EQU $100E       ; Timer Counter (16-bit, free-running)
TOC1            EQU $1016       ; Timer Output Compare 1 (16-bit)
TOC2            EQU $1018       ; Timer Output Compare 2 (16-bit)
TOC3            EQU $101A       ; Timer Output Compare 3 (16-bit) ← EST
TOC4            EQU $101C       ; Timer Output Compare 4 (16-bit)
TOC5            EQU $101E       ; Timer Output Compare 5 (16-bit)

; Timer Control
TCTL1           EQU $1020       ; Timer Control 1 (OC2, OC3, OC4, OC5 modes)
TCTL2           EQU $1021       ; Timer Control 2 (OC1, edge config)
TMSK1           EQU $1022       ; Timer Mask 1 (interrupt enables)
TFLG1           EQU $1023       ; Timer Flag 1 (interrupt flags)

; Port A
PORTA           EQU $1000       ; Port A data
DDRA            EQU $1001       ; Port A direction

; Port A Pin Assignments
PA7_MASK        EQU $80         ; OC1/PAI
PA6_MASK        EQU $40         ; OC2 (high speed fan)
PA5_MASK        EQU $20         ; OC3 (EST OUTPUT) ← TARGET
PA4_MASK        EQU $10         ; OC4 (low speed fan)
PA3_MASK        EQU $08         ; OC5/IC4

; TCTL1 OC3 Mode Bits (5-4)
OC3M_DISCONNECT EQU %00000000   ; 00 = disconnect from pin
OC3M_TOGGLE     EQU %00010000   ; 01 = toggle on compare
OC3M_CLEAR      EQU %00100000   ; 10 = clear on compare (force LOW)
OC3M_SET        EQU %00110000   ; 11 = set on compare (force HIGH)
OC3M_MASK       EQU %11001111   ; Mask to clear OC3 mode bits

; RPM Variables
RPM_ADDR        EQU $00A2       ; 8-BIT RPM/25 (NOT 16-bit!)
                                ; KNOWN BUG: Code below incorrectly uses LDD
LIMITER_FLAG    EQU $77F4       ; Runtime flags

; Thresholds - CORRECTED to 8-bit scaled
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM
RPM_LOW         EQU $EB         ; 235 × 25 = 5875 RPM

; Special Constants
TOC_NEVER       EQU $FFFF       ; A value that TCNT rarely matches

;==============================================================================
; OUTPUT COMPARE SPARK CUT - APPROACH A
;==============================================================================
;
; Theory: Set TOC3 to a value that never matches TCNT
;
; Problem: Firmware continuously writes to TOC3 for normal EST timing
; Solution needed: Find where firmware writes TOC3 and intercept
;
;==============================================================================

SPARK_CUT_OC:
        ; Read 8-bit RPM/25 (CORRECTED from 16-bit)
        LDAA    RPM_ADDR        ; 96 A2 - Load RPM/25
        
        ; Check current state
        PSHA                    ; Save RPM value
        LDAA    LIMITER_FLAG
        BITA    #$01
        PULA                    ; Restore RPM to A
        BNE     OC_CHECK_DEACT
        
OC_CHECK_ACT:
        CMPA    #RPM_HIGH       ; Compare with 240 (6000 RPM)
        ; Not cutting - should we start?
        CPD     #RPM_HIGH
        BLO     OC_EXIT
        
        ; Activate spark cut
        BSET    LIMITER_FLAG,#$01
        
        ; Method A: Set TOC3 to never-match value
        ; NOTE: Firmware may overwrite this immediately!
        LDD     #TOC_NEVER
        STD     TOC3
        
        ; Method B (alternative): Force OC3 output LOW via TCTL1
        LDAA    TCTL1
        ANDA    #OC3M_MASK          ; Clear OC3 mode bits
        ORAA    #OC3M_CLEAR         ; Set mode = clear (force LOW)
        STAA    TCTL1
        
        BRA     OC_EXIT
        
OC_CHECK_DEACT:
        ; Cutting - should we stop?
        CPD     #RPM_LOW
        BHS     OC_EXIT
        
        ; Deactivate
        BCLR    LIMITER_FLAG,#$01
        
        ; Restore OC3 to normal mode (toggle for EST)
        LDAA    TCTL1
        ANDA    #OC3M_MASK          ; Clear OC3 mode bits
        ORAA    #OC3M_TOGGLE        ; Set mode = toggle (normal EST)
        STAA    TCTL1
        
OC_EXIT:
        RTS

;==============================================================================
; FREQUENCY REFERENCE
;==============================================================================
;
; EST frequency at various RPMs (waste-spark, 6-cylinder):
;
; RPM     Frequency     Period
; --------------------------------
; 1000    25 Hz         40 ms
; 3000    75 Hz         13.3 ms
; 6000    150 Hz        6.67 ms
; 6375    159 Hz        6.28 ms
;
; Formula: f = RPM × 3 / 60 = RPM / 20
;          (3 ignition events per revolution for waste-spark V6)
;
;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; 1. Bench test with oscilloscope on PA5 (EST)
; 2. Monitor TCNT and TOC3 relationship
; 3. Verify TCTL1 mode changes take effect
; 4. Check for DTC codes (EST circuit faults)
; 5. Verify DFI module doesn't enter bypass mode
;
; Expected Issues:
;   - Firmware continuously writes TOC3 (Method A may fail)
;   - TCTL1 changes may be overwritten by ISRs
;   - DFI bypass may trigger if EST goes static
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm (similar TCTL1 approach)
;   - NEEDS_VALIDATION_v17_oc1d_forced_output.asm (OC1 override)
;   - MC68HC11_Reference.md (timer documentation)
;
; This method overlaps with v16 TCTL1 method. If testing, start with v16.
;
;==============================================================================
