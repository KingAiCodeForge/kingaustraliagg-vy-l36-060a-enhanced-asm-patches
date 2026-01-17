;==============================================================================
; VY V6 IGNITION CUT - v17: OC1D FORCED OUTPUT
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 17, 2026
; Status: ⚠️ NEEDS VALIDATION - Datasheet method, requires bench testing
;
; ⚠️ IMPORTANT: This is a THEORETICAL method based on MC68HC11 datasheet.
;    It has NOT been tested on VY V6 or any Holden ECU.
;
;==============================================================================
; SOURCE & EVIDENCE
;==============================================================================
;
; Primary Source: MC68HC11 Reference Manual Section 10.3.6
; Evidence Level: ⭐⭐⭐⭐ (80% confidence - datasheet verified)
;
; Method: OC1M/OC1D registers force output override on any OC pin
; Why this might work: More aggressive than TCTL1, bypasses ALL timer logic
; Risk: Medium - may interfere with other timer functions
;
; HC11 Datasheet Description:
;   "The OC1 output compare function can be configured to affect
;    any combination of the five output compare (OC) pins. When a
;    successful OC1 compare occurs, the output pins are set or
;    cleared according to the OC1D data register."
;
;==============================================================================
; HOW OC1M/OC1D WORKS
;==============================================================================
;
; OC1M ($100C) - Output Compare 1 Mask Register
;   Bit 7: OC1M7 - Enable OC1 control of PA7
;   Bit 6: OC1M6 - Enable OC1 control of PA6
;   Bit 5: OC1M5 - Enable OC1 control of PA5 ← EST PIN
;   Bit 4: OC1M4 - Enable OC1 control of PA4
;   Bit 3: OC1M3 - Enable OC1 control of PA3
;
; OC1D ($100D) - Output Compare 1 Data Register
;   When OC1M bit is set, corresponding OC1D bit determines output:
;   OC1D = 0 → Force pin LOW
;   OC1D = 1 → Force pin HIGH
;
; For spark cut: Set OC1M5=1, OC1D5=0 → Force PA5 (EST) LOW
;
;==============================================================================
; MEMORY MAP
;==============================================================================

; Timer Control Registers
OC1M            EQU $100C       ; Output Compare 1 Mask Register
OC1D            EQU $100D       ; Output Compare 1 Data Register
TOC1            EQU $1016       ; Timer Output Compare 1 Register (16-bit)
TCNT            EQU $100E       ; Timer Counter Register (16-bit)
TCTL1           EQU $1020       ; Timer Control Register 1
TMSK1           EQU $1022       ; Timer Mask Register 1
TFLG1           EQU $1023       ; Timer Flag Register 1

; Port A Bit Masks
PA7_MASK        EQU $80         ; Bit 7 - OC1/PAI
PA6_MASK        EQU $40         ; Bit 6 - OC2 (high speed fan)
PA5_MASK        EQU $20         ; Bit 5 - OC3 (EST OUTPUT) ← TARGET
PA4_MASK        EQU $10         ; Bit 4 - OC4 (low speed fan)
PA3_MASK        EQU $08         ; Bit 3 - OC5/IC4

; RPM Variables
RPM_ADDR        EQU $00A2       ; 8-BIT RPM/25 (NOT 16-bit!)
LIMITER_FLAG    EQU $77F4       ; Runtime flags byte

; Threshold Constants - CORRECTED to 8-bit scaled
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM activation
RPM_LOW         EQU $EB         ; 235 × 25 = 5875 RPM deactivation

;==============================================================================
; SPARK CUT PATCH - OC1D FORCED OUTPUT METHOD
;==============================================================================
;
; Theory: Use OC1 master output to force PA5 (EST) LOW
;
; This is MORE AGGRESSIVE than TCTL1 method because:
;   - OC1 can override other OC functions
;   - Forces output state on every OC1 compare
;   - Completely bypasses firmware EST control
;
; Normal: OC1M5=0 (firmware controls PA5 via OC3)
; Cut:    OC1M5=1, OC1D5=0 (OC1 forces PA5 LOW)
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
        ; Not cutting - check if we should start
        CMPA    #RPM_HIGH           ; Compare RPM/25 to high threshold
        BLO     EXIT_NO_CHANGE      ; RPM < 6000, no action
        
        ; RPM >= 6000 - activate spark cut
        BSET    LIMITER_FLAG,#$01   ; Set spark cut flag
        
        ; Enable OC1 control of PA5 (EST)
        LDAA    OC1M                ; Read current OC1M
        ORAA    #PA5_MASK           ; Set bit 5 = enable OC1 control of PA5
        STAA    OC1M                ; Write back
        
        ; Set OC1D5 = 0 to force PA5 LOW
        LDAA    OC1D                ; Read current OC1D
        ANDA    #~PA5_MASK          ; Clear bit 5 = force PA5 LOW
        STAA    OC1D                ; Write back → NO SPARK
        
        ; Set TOC1 to trigger immediately
        LDD     TCNT                ; Read current timer
        ADDD    #$0010              ; Add small offset (immediate trigger)
        STD     TOC1                ; Set OC1 compare value
        
        BRA     EXIT_CUT_ACTIVE
        
CHECK_DEACTIVATE:
        ; Currently cutting - check if we should stop
        CPD     #RPM_LOW            ; Compare RPM to low threshold
        BHS     EXIT_CUT_ACTIVE     ; RPM >= 5924, keep cutting
        
        ; RPM < 5924 - deactivate spark cut
        BCLR    LIMITER_FLAG,#$01   ; Clear spark cut flag
        
        ; Release OC1 control of PA5
        LDAA    OC1M                ; Read current OC1M
        ANDA    #~PA5_MASK          ; Clear bit 5 = release PA5 to OC3
        STAA    OC1M                ; Write back → firmware controls EST
        
EXIT_NO_CHANGE:
EXIT_CUT_ACTIVE:
        RTS

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; Before flashing to car:
;   1. Bench test with oscilloscope on PA5 (EST output)
;   2. Verify OC1 compare is actually occurring
;   3. Verify PA5 goes LOW when spark cut activates
;   4. Check for conflicts with OC1 used elsewhere in firmware
;   5. Monitor for DTC codes (EST circuit errors)
;
; Expected Results:
;   - PA5 should be forced LOW during spark cut
;   - Should be more reliable than TCTL1 method
;   - May cause issues if OC1 is used for other purposes
;
; If this doesn't work, try:
;   - v16 TCTL1 method (less aggressive)
;   - v33 Chr0m3 3X period injection (validated)
;
;==============================================================================
; WARNINGS
;==============================================================================
;
; Chr0m3 Warning (applies to all hardware methods):
;   "Hardware controlled by TIO, that's half the problems we get"
;   "Can't entirely control the TIO"
;
; This method may:
;   - Conflict with other OC1 uses in firmware
;   - Not produce reliable spark cut if OC1 isn't firing fast enough
;   - Require firmware analysis to find safe OC1 timing
;
; RECOMMENDED: Use v33 Chr0m3 3X period injection first
;              This method is for research/validation only
;
;==============================================================================
; CROSS-REFERENCE
;==============================================================================
;
; Related Files:
;   - ASM_VARIANTS_NEEDED_ANALYSIS.md (priority assessment)
;   - MC68HC11_Reference.md (hardware specs)
;   - ALDL_PACKET_OFFSET_CROSSREFERENCE.md ($100C/$100D docs)
;
; HC11 Datasheet Sections:
;   - Section 10.3.6: Output Compare 1
;   - Section 10.4: Timer Control Registers
;
;==============================================================================
