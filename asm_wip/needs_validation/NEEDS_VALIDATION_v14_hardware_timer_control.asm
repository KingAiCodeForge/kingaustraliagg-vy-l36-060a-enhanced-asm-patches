;==============================================================================
; VY V6 IGNITION CUT - v14: HARDWARE TIMER CONTROL
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ⚠️ NEEDS VALIDATION - Comprehensive timer approach
;
; ⚠️ IMPORTANT: This combines multiple timer control techniques.
;    It's a research file exploring all hardware timer options.
;
;==============================================================================
; SOURCE & EVIDENCE
;==============================================================================
;
; Primary Source: MC68HC11 Reference Manual Chapters 10-11
; Evidence Level: ⭐⭐⭐ (70% confidence - datasheet verified)
;
; This file consolidates all known hardware timer control approaches:
;   1. TCTL1/TCTL2 output mode control
;   2. OC1M/OC1D forced output
;   3. TMSK1 interrupt mask manipulation
;   4. Direct TOCx register manipulation
;
;==============================================================================
; HC11 TIMER SUBSYSTEM OVERVIEW
;==============================================================================
;
; The MC68HC11 has a sophisticated timer subsystem:
;
; ┌─────────────────────────────────────────────────────────────────┐
; │ TCNT ($100E) - 16-bit free-running counter at E-clock rate     │
; │                E-clock = 2 MHz on VY V6 (8 MHz crystal / 4)    │
; │                TCNT counts 0x0000 to 0xFFFF, then overflows    │
; │                Period = 65536 / 2 MHz = 32.768 ms              │
; └─────────────────────────────────────────────────────────────────┘
;                               │
;       ┌───────────────────────┼───────────────────────────┐
;       │                       │                           │
;       ▼                       ▼                           ▼
; ┌─────────────┐       ┌─────────────┐             ┌─────────────┐
; │ TOC1 ($1016)│       │ TOC3 ($101A)│             │ TIC1 ($1010)│
; │ Master OC   │       │ EST Output  │             │ 3X Input    │
; │ OC1M/OC1D   │       │ via PA5     │             │ Capture     │
; └─────────────┘       └─────────────┘             └─────────────┘
;       │                       │
;       ▼                       ▼
; ┌─────────────────────────────────────────┐
; │ TCTL1 ($1020) - Output Compare Modes    │
; │ Bits 7-6: OC2 mode (PA6, high fan)      │
; │ Bits 5-4: OC3 mode (PA5, EST) ← TARGET  │
; │ Bits 3-2: OC4 mode (PA4, low fan)       │
; │ Bits 1-0: OC5 mode (PA3)                │
; └─────────────────────────────────────────┘
;
;==============================================================================
; MEMORY MAP
;==============================================================================

; Core Timer Registers
TCNT            EQU $100E       ; Timer Counter (16-bit)
TOC1            EQU $1016       ; Output Compare 1 (master)
TOC2            EQU $1018       ; Output Compare 2 (PA6)
TOC3            EQU $101A       ; Output Compare 3 (PA5/EST) ← TARGET
TOC4            EQU $101C       ; Output Compare 4 (PA4)
TOC5            EQU $101E       ; Output Compare 5 (PA3)

; Input Capture (for reference)
TIC1            EQU $1010       ; Input Capture 1 (3X signal)
TIC2            EQU $1012       ; Input Capture 2
TIC3            EQU $1014       ; Input Capture 3

; OC1 Master Control
OC1M            EQU $100C       ; OC1 Mask (which pins OC1 controls)
OC1D            EQU $100D       ; OC1 Data (what state to force)

; Timer Control
TCTL1           EQU $1020       ; OC2-OC5 output modes
TCTL2           EQU $1021       ; OC1 mode, input edge config
TMSK1           EQU $1022       ; Timer interrupt enables
TFLG1           EQU $1023       ; Timer interrupt flags
TMSK2           EQU $1024       ; Timer interrupt enables 2
TFLG2           EQU $1025       ; Timer interrupt flags 2
PACTL           EQU $1026       ; Pulse Accumulator Control

; Port A
PORTA           EQU $1000       ; Port A data register

; Pin Masks
PA5_MASK        EQU $20         ; Bit 5 = PA5 = OC3 = EST

; TCTL1 OC3 Mode Constants (bits 5-4)
OC3_DISCONNECT  EQU %00000000   ; 00 = OC3 disconnected from PA5
OC3_TOGGLE      EQU %00010000   ; 01 = Toggle PA5 on OC3 match
OC3_CLEAR       EQU %00100000   ; 10 = Clear PA5 on OC3 match (LOW)
OC3_SET         EQU %00110000   ; 11 = Set PA5 on OC3 match (HIGH)
OC3_MASK        EQU %11001111   ; Mask to clear OC3 mode bits

; RPM Variables
RPM_ADDR        EQU $00A2       ; 8-BIT RPM/25 (NOT 16-bit!)
LIMITER_FLAG    EQU $77F4       ; Flags byte

; Thresholds - CORRECTED to 8-bit scaled
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM
RPM_LOW         EQU $EB         ; 235 × 25 = 5875 RPM

;==============================================================================
; APPROACH 1: TCTL1 OC3 MODE CONTROL (Same as v16)
;==============================================================================

APPROACH1_TCTL1:
        ; Force OC3 mode = 10 (clear on match = force LOW)
        LDAA    TCTL1
        ANDA    #OC3_MASK           ; Clear bits 5-4
        ORAA    #OC3_CLEAR          ; Set bits 5-4 = 10
        STAA    TCTL1
        ; PA5 (EST) will go LOW on next TOC3 match
        RTS

APPROACH1_RESTORE:
        ; Restore OC3 mode = 01 (toggle for normal EST)
        LDAA    TCTL1
        ANDA    #OC3_MASK
        ORAA    #OC3_TOGGLE
        STAA    TCTL1
        RTS

;==============================================================================
; APPROACH 2: OC1 MASTER OVERRIDE (Same as v17)
;==============================================================================

APPROACH2_OC1M:
        ; Enable OC1 control of PA5
        LDAA    OC1M
        ORAA    #PA5_MASK           ; OC1M5 = 1 (OC1 controls PA5)
        STAA    OC1M
        
        ; Set OC1D5 = 0 to force PA5 LOW
        LDAA    OC1D
        ANDA    #~PA5_MASK          ; OC1D5 = 0 (force LOW)
        STAA    OC1D
        
        ; Trigger OC1 immediately
        LDD     TCNT
        ADDD    #$0010
        STD     TOC1
        RTS

APPROACH2_RESTORE:
        ; Release OC1 control of PA5
        LDAA    OC1M
        ANDA    #~PA5_MASK          ; OC1M5 = 0 (release)
        STAA    OC1M
        RTS

;==============================================================================
; APPROACH 3: TMSK1 INTERRUPT DISABLE
;==============================================================================
;
; Theory: Disable OC3 interrupt to prevent firmware from updating EST
;
; Problem: This may not work because:
;   - Firmware may poll TOC3 instead of using interrupts
;   - Other code paths may update TOC3
;   - May cause other timing issues
;
;==============================================================================

OC3I_MASK       EQU $20             ; Bit 5 = OC3 interrupt enable

APPROACH3_TMSK1:
        ; Disable OC3 interrupt
        LDAA    TMSK1
        ANDA    #~OC3I_MASK         ; Clear OC3I bit
        STAA    TMSK1
        ; OC3 ISR will no longer fire
        RTS

APPROACH3_RESTORE:
        ; Re-enable OC3 interrupt
        LDAA    TMSK1
        ORAA    #OC3I_MASK
        STAA    TMSK1
        RTS

;==============================================================================
; APPROACH 4: DIRECT PORTA MANIPULATION (Probably won't work)
;==============================================================================
;
; Theory: Directly write to PORTA to force PA5 LOW
;
; Problem: OC3 hardware will override PORTA writes on next compare
;          This approach is documented for completeness only
;
;==============================================================================

APPROACH4_PORTA:
        ; Try to force PA5 LOW directly
        LDAA    PORTA
        ANDA    #~PA5_MASK          ; Clear bit 5
        STAA    PORTA
        ; OC3 will probably override this on next match
        RTS

;==============================================================================
; COMBINED APPROACH: USE ALL METHODS
;==============================================================================

SPARK_CUT_COMBINED:
        LDD     RPM_ADDR
        CPD     #RPM_HIGH
        BLO     COMBINED_CHECK_DEACT
        
        ; Check if already active
        LDAA    LIMITER_FLAG
        BITA    #$01
        BNE     COMBINED_EXIT
        
        ; Activate using all approaches
        BSET    LIMITER_FLAG,#$01
        
        ; Approach 1: TCTL1
        BSR     APPROACH1_TCTL1
        
        ; Approach 2: OC1M (more aggressive)
        BSR     APPROACH2_OC1M
        
        BRA     COMBINED_EXIT
        
COMBINED_CHECK_DEACT:
        LDAA    LIMITER_FLAG
        BITA    #$01
        BEQ     COMBINED_EXIT
        
        CPD     #RPM_LOW
        BHS     COMBINED_EXIT
        
        ; Deactivate all
        BCLR    LIMITER_FLAG,#$01
        BSR     APPROACH2_RESTORE
        BSR     APPROACH1_RESTORE
        
COMBINED_EXIT:
        RTS

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; Test each approach individually:
;   1. TCTL1 only (v16 method)
;   2. OC1M only (v17 method)
;   3. Combined approaches
;   4. Compare with Chr0m3 3X period method
;
; Equipment needed:
;   - Oscilloscope (4-channel preferred)
;   - Probe PA5 (EST output)
;   - Probe TOC3 (internal, may need logic analyzer)
;   - Probe DFI bypass signal
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm
;   - NEEDS_VALIDATION_v17_oc1d_forced_output.asm
;   - NEEDS_VALIDATION_methodC_output_compare.asm
;   - MC68HC11_Reference.md
;   - INTERRUPT_VECTORS_AND_TIMING_ANALYSIS.md
;
;==============================================================================
