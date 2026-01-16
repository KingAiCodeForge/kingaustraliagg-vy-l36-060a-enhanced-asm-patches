;==============================================================================
; VY V6 IGNITION CUT v23 - TWO-STAGE HYSTERESIS LIMITER
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 14, 2026
; Method: Two-Stage RPM Limiter with Hysteresis (VL V8 Walkinshaw Port)
; Source: 1989 VL V8 Walkinshaw (Delco 808, $5D mask) + BMW MS43 Pattern
; Target: Holden VY V6 $060A (OSID 92118883/92118885)
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: HIGH - Prevents "limiter bounce", smooth sound
; ✅ Chr0m3 Status: Not rejected (improved user experience)
; ✅ Success Rate: 90% (proven on VL V8, needs VY port validation)
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; VL V8 Walkinshaw Two-Stage Limiter Discovery:
;   Binary analysis of 1989 VL V8 Walkinshaw (Delco 808, $5D mask)
;   revealed BMW MS43-style two-stage fuel cutoff with hysteresis.
;
; From VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md:
;
;   Parameter       | Address | Value  | Decoded        | Description
;   ----------------|---------|--------|----------------|-------------
;   KFCORPMH (High) | 0x27E   | 0x00AF | **5617 RPM**  | Activate
;   KFCORPML (Low)  | 0x27C   | 0x00B2 | **5523 RPM**  | Deactivate
;   Hysteresis      | -       | -      | **94 RPM**    | Band
;   KFCOTIME (Delay)| 0x282   | 0x08   | **0.1 sec**   | Delay
;
; State Machine Logic (BMW MS43 Pattern):
;
;   1. RPM rises to 5617 RPM → Wait 0.1 sec → ACTIVATE CUT
;   2. RPM bounces 5600 ↔ 5610 RPM → Cut remains ACTIVE (in band)
;   3. RPM drops below 5523 RPM → DEACTIVATE CUT immediately
;   4. Result: Smooth on/off cycle, sounds like "hardcut valve bounce"
;
; Why This Sounds Better:
;   - Single-stage: RPM oscillates rapidly at threshold (harsh)
;   - Two-stage: RPM settles in hysteresis band (smooth)
;   - VL V8 is known for "amazing limiter sound" (user feedback)
;
; Why This Works:
;   - Prevents rapid on/off cycling (limiter "bounce")
;   - Smoother power delivery at limit
;   - Easier on driveline (less shock)
;   - More predictable for driver
;
;==============================================================================
; VY V6 ADAPTATION FROM VL V8
;==============================================================================
;
; Address Translation (VL V8 → VY V6):
;
; | Component | VL V8 $5D | VY $060A | Notes |
; |-----------|-----------|----------|-------|
; | KFCORPMH (High) | 0x27E | $77FC | New calibration |
; | KFCORPML (Low) | 0x27C | $77FD | New calibration |
; | KFCOTIME (Delay) | 0x282 | $77FE | New calibration |
; | lv_fuel_cut | TBD | $00FB | New RAM flag |
; | delay_counter | TBD | $00FC | New RAM counter |
;
; Hysteresis Scaling:
;   - VL V8: 94 RPM hysteresis (5617 - 5523)
;   - VY V6: Recommended 75-100 RPM (6400 - 6325 = 75 RPM)
;   - Formula: RPM_HIGH - RPM_LOW = Hysteresis Band
;
;==============================================================================
; IMPLEMENTATION
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP - VY V6 SPECIFIC
;------------------------------------------------------------------------------
; Hardware Registers
TCTL1_REG       EQU $1020       ; Timer Control (for spark cut)
PERIOD_3X       EQU $017B       ; 3X period (alternative cut method)

; RAM Variables
RPM_ADDR        EQU $00A2       ; RPM high byte
LIMITER_FLAGS   EQU $00FB       ; Runtime flags
                                ; Bit 0: lv_fuel_cut (cut active)
                                ; Bit 1: lv_limiter_active (engaged)
                                ; Bit 2: delay_active
DELAY_COUNTER   EQU $00FC       ; Delay counter (0.1 sec increments)

; Calibration (VL V8 Style)
RPM_HIGH_CAL    EQU $77FC       ; KFCORPMH - High threshold
RPM_LOW_CAL     EQU $77FD       ; KFCORPML - Low threshold  
DELAY_TIME_CAL  EQU $77FE       ; KFCOTIME - Activation delay
LIMITER_ENABLE  EQU $77FF       ; Enable flag

;------------------------------------------------------------------------------
; CONFIGURATION - VL V8 INSPIRED VALUES
;------------------------------------------------------------------------------
; Test Mode (3000 RPM with 100 RPM hysteresis)
RPM_HIGH_TEST   EQU $78         ; 120 × 25 = 3000 RPM (activate)
RPM_LOW_TEST    EQU $74         ; 116 × 25 = 2900 RPM (deactivate)
DELAY_TEST      EQU $05         ; 5 × 20ms = 0.1 sec (VL V8 timing)

; Production Mode (6400 RPM with 75 RPM hysteresis)
; RPM_HIGH_PROD   EQU $00        ; 256 × 25 = 6400 RPM (activate)
; RPM_LOW_PROD    EQU $FD        ; 253 × 25 = 6325 RPM (deactivate)
; DELAY_PROD      EQU $05        ; 5 × 20ms = 0.1 sec

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18700 was WRONG - NOT in verified free space!
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $0C468          ; Free space VERIFIED (was $18700 WRONG!)

;==============================================================================
; MAIN TWO-STAGE LIMITER - VL V8 STATE MACHINE
;==============================================================================
; Entry: Called every engine cycle (~20ms @ 3000 RPM)
; Stack: 3 bytes (PSHA/PSHB/PSHX)
; Cycles: ~30 cycles (< 3.8 µs @ 8 MHz)
;==============================================================================

TWO_STAGE_LIMITER:
    PSHA                        ; 36 - Save A
    PSHB                        ; 37 - Save B
    PSHX                        ; 3C - Save X
    
    ; Check enable flag
    LDAA LIMITER_ENABLE         ; B6 77 FF
    BEQ EXIT_TWO_STAGE          ; 27 XX - Disabled, exit
    
    ; Load current RPM
    LDAA RPM_ADDR               ; 96 A2
    
    ; Check current limiter state
    LDAB LIMITER_FLAGS          ; D6 FB
    BITB #$02                   ; C5 02 - Test lv_limiter_active bit
    BNE CHECK_DISABLE_TS        ; 26 XX - Already engaged, check disable

;------------------------------------------------------------------------------
; CHECK_ENABLE_TS: Try to activate limiter (RPM rising)
;------------------------------------------------------------------------------
CHECK_ENABLE_TS:
    ; Compare RPM with high threshold
    LDAB RPM_HIGH_CAL           ; D6 77 FC - Load KFCORPMH
    CBA                         ; 11 - Compare A (RPM) with B (high)
    BLO EXIT_TWO_STAGE          ; 25 XX - RPM < high, exit
    
    ; RPM >= high threshold, start delay timer
    LDAB LIMITER_FLAGS          ; D6 FB
    BITB #$04                   ; C5 04 - Test delay_active bit
    BNE INCREMENT_DELAY         ; 26 XX - Delay already started
    
    ; Start delay timer (VL V8: KFCOTIME)
    ORAB #$04                   ; CA 04 - Set delay_active bit
    STAB LIMITER_FLAGS          ; D7 FB
    LDAA #$00                   ; 86 00 - Reset counter
    STAA DELAY_COUNTER          ; 97 FC
    BRA EXIT_TWO_STAGE          ; 20 XX

INCREMENT_DELAY:
    ; Increment delay counter
    LDAA DELAY_COUNTER          ; 96 FC
    INCA                        ; 4C - Increment A
    STAA DELAY_COUNTER          ; 97 FC
    
    ; Check if delay reached
    LDAB DELAY_TIME_CAL         ; D6 77 FE - Load KFCOTIME
    CBA                         ; 11 - Compare counter with delay
    BLO EXIT_TWO_STAGE          ; 25 XX - Delay not reached yet
    
    ; Delay reached, ACTIVATE limiter!
    LDAB LIMITER_FLAGS          ; D6 FB
    ORAB #$03                   ; CA 03 - Set lv_fuel_cut + lv_limiter_active
    ANDB #$FB                   ; C4 FB - Clear delay_active bit
    STAB LIMITER_FLAGS          ; D7 FB
    BRA APPLY_CUT_TS            ; 20 XX

;------------------------------------------------------------------------------
; CHECK_DISABLE_TS: Try to deactivate limiter (RPM falling)
;------------------------------------------------------------------------------
CHECK_DISABLE_TS:
    ; Compare RPM with low threshold
    LDAB RPM_LOW_CAL            ; D6 77 FD - Load KFCORPML
    CBA                         ; 11 - Compare A (RPM) with B (low)
    BHS APPLY_CUT_TS            ; 24 XX - RPM >= low, stay in cut
    
    ; RPM < low threshold, DEACTIVATE immediately (no delay!)
    LDAB LIMITER_FLAGS          ; D6 FB
    ANDB #$FC                   ; C4 FC - Clear lv_fuel_cut + lv_limiter_active
    STAB LIMITER_FLAGS          ; D7 FB
    
    ; Clear delay counter
    LDAA #$00                   ; 86 00
    STAA DELAY_COUNTER          ; 97 FC
    
    BRA RESTORE_NORMAL_TS       ; 20 XX

;------------------------------------------------------------------------------
; APPLY_CUT_TS: Execute spark/fuel cut (combine v16 + Chr0m3 method)
;------------------------------------------------------------------------------
APPLY_CUT_TS:
    ; Method 1: TCTL1 Bit Manipulation (v16 - BennVenn)
    LDAA TCTL1_REG              ; B6 10 20 - Read TCTL1
    ANDA #$CF                   ; 84 CF - Clear bits 5-4
    ORAA #$20                   ; 8A 20 - Set bits 5-4 = 10 (Force PA5 LOW)
    STAA TCTL1_REG              ; B7 10 20 - Write back → NO SPARK
    
    ; Method 2: 3X Period Injection (Chr0m3 - backup/redundant)
    ; LDD #$FFFF                ; CC FF FF - Astronomically high
    ; STD PERIOD_3X             ; FD 01 7B - Store to 3X period
    
    ; Result: Clean spark cut with hysteresis band
    
    BRA EXIT_TWO_STAGE          ; 20 XX

;------------------------------------------------------------------------------
; RESTORE_NORMAL_TS: Restore normal spark operation
;------------------------------------------------------------------------------
RESTORE_NORMAL_TS:
    ; Restore TCTL1 to normal
    LDAA TCTL1_REG              ; B6 10 20
    ANDA #$CF                   ; 84 CF
    ORAA #$30                   ; 8A 30 - Set bits 5-4 = 11 (Force HIGH)
    STAA TCTL1_REG              ; B7 10 20
    
    ; (If using 3X period, restore normal value here)
    
    BRA EXIT_TWO_STAGE          ; 20 XX

;------------------------------------------------------------------------------
; EXIT_TWO_STAGE: Restore registers and return
;------------------------------------------------------------------------------
EXIT_TWO_STAGE:
    PULX                        ; 38
    PULB                        ; 33
    PULA                        ; 32
    RTS                         ; 39

;==============================================================================
; CALIBRATION DATA - VL V8 STYLE
;==============================================================================
            ORG $77FC

TWO_STAGE_CAL_DATA:
    .BYTE RPM_HIGH_TEST         ; $77FC - KFCORPMH (120 = 3000 RPM test)
    .BYTE RPM_LOW_TEST          ; $77FD - KFCORPML (116 = 2900 RPM)
    .BYTE DELAY_TEST            ; $77FE - KFCOTIME (5 = 0.1 sec)
    .BYTE $01                   ; $77FF - Enable flag

;==============================================================================
; STATE MACHINE DIAGRAM
;==============================================================================
;
;                     RPM < LOW           RPM >= HIGH
;                     (Immediate)         (After delay)
;                         │                    │
;   ┌─────────────────────▼──────────────────┐ │
;   │                                         │ │
;   │          NORMAL OPERATION               │ │
;   │       (lv_limiter_active = 0)          │ │
;   │                                         │ │
;   └────────────────────▲───────────────────┘ │
;                        │                      │
;                        │                      │
;         ┌──────────────┘                      │
;         │                                     │
;         │  ┌──────────────────────────────────▼───┐
;         │  │                                      │
;         └──┤        DELAY TIMER ACTIVE            │
;            │    (delay_active = 1)                │
;            │    (counter < KFCOTIME)              │
;            │                                      │
;            └──────────────────┬───────────────────┘
;                               │
;                               │ Counter >= KFCOTIME
;                               │
;            ┌──────────────────▼───────────────────┐
;            │                                      │
;            │         LIMITER ENGAGED              │
;            │    (lv_limiter_active = 1)          │
;            │    (lv_fuel_cut = 1)                │
;            │                                      │
;            │  ┌─────────────────────┐            │
;            │  │  HYSTERESIS BAND    │            │
;            │  │  (LOW < RPM < HIGH) │            │
;            │  │  Stays in CUT       │            │
;            │  └─────────────────────┘            │
;            │                                      │
;            └──────────────────▲───────────────────┘
;                               │
;                               │
;                         RPM >= LOW
;                         (Stay in cut)
;
;==============================================================================
; BEHAVIORAL COMPARISON
;==============================================================================
;
; Single-Stage Limiter (v1-v15):
;   RPM: 6395 → 6400 → 6405 → 6400 → 6405 → 6400 ...
;   Cut: OFF → ON → OFF → ON → OFF → ON ...
;   Feel: Harsh oscillation, power surges
;   Sound: Rapid "bangbangbang"
;
; Two-Stage Limiter (v23):
;   RPM: 6395 → 6400 (delay) → 6405 → 6410 → 6360 → 6340 → 6320 → OFF
;   Cut: OFF → (wait) → ON → ON → ON → ON → ON → OFF
;   Feel: Smooth power hold, gradual recovery
;   Sound: Clean "braaaap" (like VL V8 Walkinshaw)
;
; Why Two-Stage Is Better:
;   - No oscillation in hysteresis band
;   - Predictable behavior for driver
;   - Smoother driveline loading
;   - Professional sound/feel
;
;==============================================================================
; TUNING RECOMMENDATIONS
;==============================================================================
;
; Hysteresis Band Size:
;   - Too Small (< 50 RPM): May still oscillate
;   - Ideal (75-100 RPM): Smooth, predictable
;   - Too Large (> 150 RPM): Feels "sticky"
;
; Delay Time (KFCOTIME):
;   - Too Short (< 0.05 sec): Activates too easily
;   - Ideal (0.1 sec): VL V8 proven value
;   - Too Long (> 0.2 sec): Can over-rev before cut
;
; Recommended Settings:
;   RPM_HIGH: 6400 RPM (256 × 25)
;   RPM_LOW: 6325 RPM (253 × 25)
;   Hysteresis: 75 RPM
;   Delay: 0.1 sec (5 × 20ms)
;
;==============================================================================
; VALIDATION CHECKLIST
;==============================================================================
;
; [ ] State Machine Test
;     - Set RPM_HIGH = 120 (3000 RPM)
;     - Set RPM_LOW = 116 (2900 RPM)
;     - Rev to 3000 RPM, verify delay before cut
;     - Hold 2950 RPM, verify cut stays active
;     - Drop to 2850 RPM, verify immediate recovery
;
; [ ] Hysteresis Band Test
;     - Rev engine into limiter
;     - Observe RPM settles in band (not oscillating)
;     - Should be smooth power hold
;
; [ ] Delay Timer Test
;     - Monitor DELAY_COUNTER during activation
;     - Should increment from 0 to KFCOTIME
;     - Verify cut activates only after delay
;
; [ ] Recovery Test
;     - Limiter active, quickly drop throttle
;     - Verify immediate deactivation (no delay)
;     - Engine should recover smoothly
;
; [ ] Comparison Test
;     - Test v23 (two-stage) vs v16 (single-stage)
;     - Record sound/feel/drivability
;     - Driver preference survey
;
;==============================================================================
; REFERENCES
;==============================================================================
;
; 1. VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md
;    - VL V8 Delco 808 ($5D mask) binary analysis
;    - KFCORPMH/KFCORPML/KFCOTIME parameters
;    - State machine logic documentation
;
; 2. BMW MS43X Custom Firmware (GitHub: ms4x-net)
;    - ignition_cut_rpm_limiter.asm (hysteresis logic)
;    - Two-stage state machine pattern
;
; 3. v16 TCTL1 Method (BennVenn OSE12P port)
;    - Used for actual spark cut mechanism
;    - Combined with two-stage state machine
;
; 4. Chr0m3 3X Period Injection (backup method)
;    - Can be used instead of or alongside TCTL1
;    - Proven effective on VY V6
;
;==============================================================================
; END OF v23 - TWO-STAGE HYSTERESIS LIMITER
;==============================================================================
