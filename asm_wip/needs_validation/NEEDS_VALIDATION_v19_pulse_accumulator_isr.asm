;==============================================================================
; VY V6 IGNITION CUT - v19: PULSE ACCUMULATOR ISR
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ⚠️ NEEDS VALIDATION - Experimental, requires extensive testing
;
; ⚠️ IMPORTANT: This is a HIGHLY EXPERIMENTAL method based on HC11 hardware
;    capabilities. It has NOT been tested and may cause instability.
;
;==============================================================================
; SOURCE & EVIDENCE
;==============================================================================
;
; Primary Source: MC68HC11 PACTL register ($1026) analysis
; Evidence Level: ⭐⭐⭐ (60% confidence - hardware capable, untested)
;
; Method: Hijack Pulse Accumulator overflow ISR for fast response
; Why this might work: Sub-millisecond activation time
; Risk: HIGH - ISR hijacking may cause system instability
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; The HC11 Pulse Accumulator can count external events on PA7 or use
; gated time accumulation mode. The PA Overflow interrupt fires when
; the 8-bit counter overflows (every 256 events or time periods).
;
; For spark cut, we could:
;   1. Configure PA to count at high frequency
;   2. Hook the PAOV (Pulse Accumulator Overflow) ISR
;   3. On each overflow, check RPM and disable spark if needed
;
; This would give very fast response time (sub-millisecond) but
; requires careful ISR timing to avoid disrupting other operations.
;
;==============================================================================
; MEMORY MAP
;==============================================================================

; Pulse Accumulator Registers
PACTL           EQU $1026       ; Pulse Accumulator Control Register
PACNT           EQU $1027       ; Pulse Accumulator Count Register
TMSK2           EQU $1024       ; Timer Mask 2 (PAOVI enable)
TFLG2           EQU $1025       ; Timer Flag 2 (PAOVF flag)

; PACTL Bit Definitions
DDRA7           EQU $80         ; Bit 7: PA7 data direction (0=input, 1=output)
PAEN            EQU $40         ; Bit 6: Pulse Accumulator Enable
PAMOD           EQU $20         ; Bit 5: Mode select (0=event, 1=gated time)
PEDGE           EQU $10         ; Bit 4: Edge select (0=falling, 1=rising)
; Bits 3-2: Unused
RTR1            EQU $02         ; Bit 1: RTI rate select 1
RTR0            EQU $01         ; Bit 0: RTI rate select 0

; TMSK2 Bit Definitions
PAOVI           EQU $20         ; Bit 5: PA Overflow Interrupt Enable

; TFLG2 Bit Definitions
PAOVF           EQU $20         ; Bit 5: PA Overflow Flag

; Timer Control
TCTL1           EQU $1020       ; Timer Control Register 1 (OC modes)

; RPM and Flag Variables
RPM_ADDR        EQU $00A2       ; 16-bit RPM
LIMITER_FLAG    EQU $77F4       ; Runtime flags byte
PA5_MASK        EQU $20         ; Bit 5 = PA5 (EST output)
OC3M_MASK       EQU %11001111   ; Mask for TCTL1 OC3 bits

; Threshold Constants
RPM_HIGH        EQU $1770       ; 6000 RPM activation
RPM_LOW         EQU $1724       ; 5924 RPM deactivation

; Interrupt Vectors (stock locations - MAY NEED ADJUSTMENT)
PAOV_VECTOR     EQU $FFDA       ; Pulse Accumulator Overflow Vector

;==============================================================================
; INSTALLATION NOTES
;==============================================================================
;
; This patch requires modifying the PAOV interrupt vector at $FFDA to
; point to our custom ISR. The original vector contents must be saved
; so we can chain to the stock handler after our code runs.
;
; Steps:
;   1. Find unused RAM for our ISR
;   2. Copy ISR code to RAM (or patch in ROM if space available)
;   3. Save original PAOV vector
;   4. Patch PAOV vector to point to our ISR
;   5. Configure PACTL for high-frequency operation
;   6. Enable PAOV interrupt in TMSK2
;
;==============================================================================

; Original vector storage (in RAM)
ORIG_PAOV_H     EQU $0080       ; High byte of original PAOV handler
ORIG_PAOV_L     EQU $0081       ; Low byte of original PAOV handler

;==============================================================================
; PULSE ACCUMULATOR OVERFLOW ISR
;==============================================================================
;
; This ISR is called on every PA overflow. At high frequencies, this
; could be several thousand times per second - must be VERY fast!
;
;==============================================================================

PAOV_ISR:
        ; Save registers (minimal - must be fast!)
        PSHA
        PSHB
        
        ; Clear the overflow flag immediately
        LDAA    #PAOVF
        STAA    TFLG2               ; Clear PAOVF by writing 1
        
        ; Read 16-bit RPM
        LDD     RPM_ADDR
        
        ; Check current state
        TST     LIMITER_FLAG        ; Quick check - any flags set?
        BNE     ISR_CHECK_DEACT     ; If flag set, check deactivation
        
ISR_CHECK_ACT:
        ; Not cutting - should we start?
        CPD     #RPM_HIGH
        BLO     ISR_EXIT            ; RPM < 6000, exit fast
        
        ; Activate spark cut
        LDAA    #$01
        STAA    LIMITER_FLAG
        
        ; Force PA5 (EST) LOW via TCTL1
        LDAA    TCTL1
        ANDA    #OC3M_MASK          ; Clear OC3 mode bits
        ORAA    #$20                ; Set bits 5-4 = 10 (force LOW)
        STAA    TCTL1
        
        BRA     ISR_EXIT
        
ISR_CHECK_DEACT:
        ; Currently cutting - should we stop?
        CPD     #RPM_LOW
        BHS     ISR_EXIT            ; RPM >= 5924, keep cutting
        
        ; Deactivate spark cut
        CLR     LIMITER_FLAG
        
        ; Release PA5 to firmware control
        LDAA    TCTL1
        ANDA    #OC3M_MASK          ; Clear OC3 mode bits (disconnect)
        STAA    TCTL1
        
ISR_EXIT:
        ; Restore registers
        PULB
        PULA
        
        ; Chain to original PAOV handler (if any)
        JMP     [ORIG_PAOV_H]       ; Indirect jump through saved vector

;==============================================================================
; INITIALIZATION CODE
;==============================================================================
;
; Call this once at startup to configure the Pulse Accumulator
;
;==============================================================================

PA_INIT:
        ; Save original PAOV vector
        LDD     PAOV_VECTOR
        STAA    ORIG_PAOV_H
        STAB    ORIG_PAOV_L
        
        ; Configure PACTL
        ; PAEN=1, PAMOD=1 (gated time mode), PEDGE=0
        LDAA    #(PAEN|PAMOD)
        STAA    PACTL
        
        ; Enable PAOV interrupt
        LDAA    TMSK2
        ORAA    #PAOVI
        STAA    TMSK2
        
        ; Clear any pending flag
        LDAA    #PAOVF
        STAA    TFLG2
        
        ; Clear limiter flag
        CLR     LIMITER_FLAG
        
        RTS

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; Before ANY testing:
;   1. Verify PAOV vector location in VY V6 firmware
;   2. Find safe RAM location for ISR code
;   3. Test on bench with ECU simulator if possible
;   4. Have recovery method ready (stock binary flash)
;
; This method is EXPERIMENTAL because:
;   - ISR timing may conflict with other interrupts
;   - PA is likely used for other purposes in stock firmware
;   - Fast ISR execution is critical (may cause timing issues)
;   - JMP indirect may not work as expected
;
; NOT RECOMMENDED for first-time testing
; Use v33 Chr0m3 3X period injection instead
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - ASM_VARIANTS_NEEDED_ANALYSIS.md (priority: LOW)
;   - MC68HC11_Reference.md (Section 11: Pulse Accumulator)
;   - INTERRUPT_VECTORS_AND_TIMING_ANALYSIS.md
;
;==============================================================================
