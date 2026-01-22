;==============================================================================
; VY V6 BOOST CONTROLLER v26 - PID CLOSED-LOOP WASTEGATE CONTROL
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: PWM wastegate solenoid with PID control (MS43X concept port)
; Source: MS43X boost_controller.asm + get_pressure_request.asm (REFERENCE ONLY)
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with turbo
; Processor: Motorola MC68HC711E9 (8-bit)
;
; ⚠️ MS43X = BMW Siemens C166 ECU - completely different CPU!
;    Code here is CONCEPT PORT only - addresses/opcodes differ!
;
; ⚠️⚠️⚠️ CRITICAL ISSUES - NOT USABLE AS-IS ⚠️⚠️⚠️
;
; ISSUE 1: NO MAP SENSOR ON VY V6!
;   VY V6 uses MAF-based fueling. There is NO manifold pressure sensor.
;   TO FIX: Install aftermarket 3-bar MAP sensor (GM 12223861 or equiv)
;           Wire to spare A/D input, then update addresses below.
;
; ISSUE 2: RAM ADDRESSES CONFLICT WITH STOCK ECU!
;   $00A2 = RPM/25 (8-bit engine speed) - CANNOT USE FOR BOOST TARGET!
;   $00A3 = Engine state flags - CANNOT USE FOR ACTUAL BOOST!
;   All addresses $00A0-$00AC need remapping to unused RAM.
;
; ISSUE 3: REQUIRES PWM OUTPUT HARDWARE
;   Need wastegate solenoid driver circuit + available ECU output pin.
;
; ⬜ STATUS: TEMPLATE ONLY - Requires hardware + RAM remapping!
;
; ⭐ PRIORITY: HIGH for turbo builds (once hardware installed)
;==============================================================================
;
;==============================================================================
; THEORY OF OPERATION (Ported from MS43X C166)
;==============================================================================
;
; The MS43X boost controller uses:
; 1. Open-loop mode: RPM-based PWM lookup table (basic boost control)
; 2. Closed-loop mode: PID controller with MAP target vs actual error
;
; PID Formula:
;   output = pilot_pwm + (P_gain * error) + (I_term * ∑error) + (D_gain * Δerror)
;
; Where:
;   - pilot_pwm = base PWM from 3D table (RPM × target_boost)
;   - error = target_boost - actual_boost
;   - I_term integrates error over time (with anti-windup)
;   - D_term responds to rate of change
;
; HC11 Limitations:
;   - No hardware PWM (must use timer ISR)
;   - 8-bit math limits resolution
;   - Slower execution than C166 (adapt gains accordingly)
;
;==============================================================================
; HARDWARE REQUIREMENTS - DERIVED FROM VY_V6_PINOUT_MASTER_MAPPING.csv
;==============================================================================
;
; ⚠️ VY V6 L36 Ecotec has NO MAP sensor from factory!
; ⚠️ OSE 11P/12P examples are for VN-VS Buick 3800 (HAS MAP at C11)
; ⚠️ MS43X examples are for BMW M54 (completely different ECU!)
;
; Required Hardware:
;   1. MAC wastegate solenoid (3-port) or similar
;   2. 3-bar MAP sensor (GM 12575832/12223861 or similar)
;   3. Flying lead from ECU to solenoid driver (10A relay or MOSFET)
;
; MAP SENSOR WIRING OPTIONS (from VY_V6_PINOUT_MASTER_MAPPING.csv):
;
; ⚠️ PINOUT CSV MAY HAVE ERRORS - VERIFY BEFORE WIRING!
; ⚠️ Cross-reference with wiring diagrams + physical ECU inspection!
;
;   OPTION A - Enhanced Mod EEI Input (RECOMMENDED):
;     Pin: C16 (Enhanced Mod claims PE4/AN4 = EEI A5) - VERIFY THIS!
;     Wire: PURPLE/WHITE (claimed - verify with multimeter!)
;     Signal: 0-5V analog → 0-255 ADC count
;     Formula: kPa = (ADC_count × 5V / 255) × MAP_scale_factor
;     Note: Requires Enhanced Mod v1.0a bin + case drilling to HC11 pin 59
;     ⚠️ HC11 QFP-64 pin mapping NOT fully verified - check datasheet!
;
;   OPTION B - Enhanced Mod Secondary Input:
;     Pin: C17 (Enhanced Mod claims PE5/AN5 = EEI B10) - VERIFY THIS!
;     Wire: User-supplied (wire from ECU case to HC11 pin 60)
;     Note: Can use A5 for wideband AND B10 for MAP (or vice versa)
;
;   OPTION C - Repurpose unused analog:
;     PE0/AN0, PE1/AN1, PE2/AN2, PE3/AN3 show ZERO explicit selections
;     in binary analysis - may be available but UNCONFIRMED
;
; PWM OUTPUT OPTIONS:
;   - PA4/OC4 = Low speed fan relay (Pin 42) - could repurpose
;   - PA6/OC2 = High speed fan relay (Pin 33) - could repurpose
;   - PA3/OC5 = Possibly unused (needs verification)
;
;==============================================================================
; RAM VARIABLES - ⚠️ CONFLICTS WITH STOCK ECU - NEED REMAPPING!
;==============================================================================

; ❌ WRONG: These addresses overlap stock ECU RAM!
; $00A2 = RPM/25 (verified), $00A3 = Engine State, etc.
; TODO: Find UNUSED RAM in VY V6 binary for boost controller variables
;
; Possible unused RAM regions to investigate:
;   - $00B0-$00BF (check for stock usage)
;   - $0180-$01FF (extended RAM, less used)
;
RAM_BC_ENABLE       EQU     $00A0   ; ❌ CONFLICT - find unused addr!
RAM_BC_MODE         EQU     $00A1   ; ❌ CONFLICT - find unused addr!
RAM_BC_TARGET       EQU     $00A2   ; ❌ CONFLICT with RPM! MUST CHANGE!
RAM_BC_ACTUAL       EQU     $00A3   ; ❌ CONFLICT with Engine State!
RAM_BC_ERROR        EQU     $00A4   ; ❌ CONFLICT - find unused addr!
RAM_BC_ERROR_SUM    EQU     $00A5   ; ❌ CONFLICT - find unused addr!
RAM_BC_ERROR_PREV   EQU     $00A7   ; ❌ CONFLICT - find unused addr!
RAM_BC_P_TERM       EQU     $00A8   ; ❌ CONFLICT - find unused addr!
RAM_BC_I_TERM       EQU     $00A9   ; ❌ CONFLICT - find unused addr!
RAM_BC_D_TERM       EQU     $00AA   ; ❌ CONFLICT - find unused addr!
RAM_BC_PWM_OUT      EQU     $00AB   ; ❌ CONFLICT - find unused addr!
RAM_BC_PILOT        EQU     $00AC   ; ❌ CONFLICT - find unused addr!

;==============================================================================
; CALIBRATION CONSTANTS (Define in XDF-accessible area)
;==============================================================================

; Find tunable area in binary (suggest $7E00-$7FFF unused calibration)
CAL_BC_CONF         EQU     $7E00   ; Configuration byte
                                    ; Bit 0: Enable (1 = on)
                                    ; Bit 1: Mode (0 = open-loop, 1 = closed-loop)
                                    ; Bit 2: Safety enable
CAL_BC_MAP_MIN      EQU     $7E01   ; Minimum MAP to activate (kPa) - e.g., 110
CAL_BC_PWM_MIN      EQU     $7E02   ; Minimum PWM output (0-255)
CAL_BC_PWM_MAX      EQU     $7E03   ; Maximum PWM output (0-255)
CAL_BC_P_GAIN       EQU     $7E04   ; Proportional gain (x/16)
CAL_BC_I_GAIN       EQU     $7E05   ; Integral gain (x/256)
CAL_BC_D_GAIN       EQU     $7E06   ; Derivative gain (x/16)
CAL_BC_I_MAX        EQU     $7E07   ; Max integral term (anti-windup)

; Boost Target Table (RPM × TPS) - 8x8 = 64 bytes
CAL_BC_TARGET_TABLE EQU     $7E10   ; Boost target vs RPM/TPS (kPa values)

; Pilot PWM Table (RPM × Target) - 8x8 = 64 bytes  
CAL_BC_PILOT_TABLE  EQU     $7E50   ; Base PWM duty vs RPM/Target

;==============================================================================
; EXISTING ECU ADDRESSES (from VY XDF)
;==============================================================================

RPM_VAR             EQU     $00F0   ; Current RPM / 25 (verify in XDF)
MAP_VAR             EQU     $00D8   ; Current MAP (kPa) (verify in XDF)
TPS_VAR             EQU     $00DA   ; Current TPS (0-255) (verify in XDF)

; Port registers
PORTA               EQU     $1000   ; Port A data register
DDRA                EQU     $1001   ; Port A direction register

;==============================================================================
; BOOST CONTROLLER MAIN ROUTINE
;==============================================================================
; Call this from main loop (every 10-20ms)

BOOST_CONTROLLER:
    ; Check if boost controller enabled
    LDAA    CAL_BC_CONF
    ANDA    #$01                ; Check enable bit
    BEQ     BC_DISABLED         ; Exit if disabled
    
    ; Check if MAP above activation threshold
    LDAA    MAP_VAR
    CMPA    CAL_BC_MAP_MIN
    BLO     BC_BELOW_THRESHOLD  ; Below threshold, set minimum PWM
    
    ; Store actual boost
    STAA    RAM_BC_ACTUAL
    
    ; Get boost target from table (RPM × TPS lookup)
    JSR     BC_GET_TARGET
    
    ; Check mode (open-loop vs closed-loop)
    LDAA    CAL_BC_CONF
    ANDA    #$02                ; Check mode bit
    BEQ     BC_OPEN_LOOP        ; Mode = 0: open-loop only
    
    ; Closed-loop mode
    JSR     BC_CLOSED_LOOP_PID
    BRA     BC_OUTPUT
    
BC_OPEN_LOOP:
    ; Open-loop: PWM from pilot table only
    JSR     BC_GET_PILOT_PWM
    LDAA    RAM_BC_PILOT
    STAA    RAM_BC_PWM_OUT
    BRA     BC_OUTPUT
    
BC_BELOW_THRESHOLD:
    ; Below boost threshold - minimum PWM (valve closed)
    LDAA    CAL_BC_PWM_MIN
    STAA    RAM_BC_PWM_OUT
    BRA     BC_OUTPUT
    
BC_DISABLED:
    ; Controller disabled - zero PWM
    CLR     RAM_BC_PWM_OUT
    BRA     BC_EXIT
    
BC_OUTPUT:
    ; Clamp output to min/max
    LDAA    RAM_BC_PWM_OUT
    CMPA    CAL_BC_PWM_MIN
    BHS     BC_CHECK_MAX
    LDAA    CAL_BC_PWM_MIN
    BRA     BC_SET_OUTPUT
    
BC_CHECK_MAX:
    CMPA    CAL_BC_PWM_MAX
    BLS     BC_SET_OUTPUT
    LDAA    CAL_BC_PWM_MAX
    
BC_SET_OUTPUT:
    STAA    RAM_BC_PWM_OUT
    
    ; Output PWM to solenoid (via timer ISR or port toggle)
    ; For now, store value - PWM ISR reads RAM_BC_PWM_OUT
    
BC_EXIT:
    RTS

;==============================================================================
; GET BOOST TARGET FROM TABLE
;==============================================================================
; Lookup boost target from RPM × TPS 2D table
; Output: RAM_BC_TARGET

BC_GET_TARGET:
    ; Calculate table index from RPM and TPS
    ; Simplified: RPM/1000 = 0-7, TPS/32 = 0-7
    
    LDAA    RPM_VAR             ; RPM / 25
    LSRA                        ; Divide by 8 for 8-row table
    LSRA
    LSRA
    ANDA    #$07                ; Clamp to 0-7
    TAB                         ; Save row index in B
    
    LDAA    TPS_VAR             ; TPS 0-255
    LSRA                        ; Divide by 32 for 8-column table
    LSRA
    LSRA
    LSRA
    LSRA
    ANDA    #$07                ; Clamp to 0-7
    
    ; Calculate table offset: (row * 8) + column
    PSHA                        ; Save column
    LDAA    #8
    MUL                         ; D = B * 8 = row offset
    TBA                         ; A = row offset (low byte enough)
    PULB                        ; B = column
    ABA                         ; A = row offset + column
    
    ; Add table base address
    LDX     #CAL_BC_TARGET_TABLE
    ABX                         ; X = table base + offset
    
    LDAA    0,X                 ; Load target from table
    STAA    RAM_BC_TARGET
    RTS

;==============================================================================
; GET PILOT PWM FROM TABLE
;==============================================================================
; Lookup base PWM from RPM × Target 2D table
; Output: RAM_BC_PILOT

BC_GET_PILOT_PWM:
    ; Similar lookup as target, but using RPM × current target
    LDAA    RPM_VAR
    LSRA
    LSRA
    LSRA
    ANDA    #$07
    TAB
    
    LDAA    RAM_BC_TARGET       ; Use target as column axis
    LSRA                        ; Scale to 0-7 range
    LSRA
    LSRA
    LSRA
    LSRA
    ANDA    #$07
    
    PSHA
    LDAA    #8
    MUL
    TBA
    PULB
    ABA
    
    LDX     #CAL_BC_PILOT_TABLE
    ABX
    
    LDAA    0,X
    STAA    RAM_BC_PILOT
    RTS

;==============================================================================
; CLOSED-LOOP PID CONTROLLER
;==============================================================================
; Full PID control: output = pilot + P + I + D
; Output: RAM_BC_PWM_OUT

BC_CLOSED_LOOP_PID:
    ; Get pilot PWM as feedforward term
    JSR     BC_GET_PILOT_PWM
    
    ; Calculate error = target - actual
    LDAA    RAM_BC_TARGET
    SUBA    RAM_BC_ACTUAL
    STAA    RAM_BC_ERROR        ; Signed error
    
    ;----- P TERM -----
    ; P_term = error * P_gain / 16
    LDAB    CAL_BC_P_GAIN
    JSR     BC_SIGNED_MUL_8     ; D = A * B (signed)
    ASRA                        ; Divide by 16
    RORA
    ASRA
    RORA
    ASRA
    RORA
    ASRA
    RORA
    STAA    RAM_BC_P_TERM
    
    ;----- I TERM -----
    ; I_term = I_term + (error * I_gain / 256)
    LDAA    RAM_BC_ERROR
    LDAB    CAL_BC_I_GAIN
    JSR     BC_SIGNED_MUL_8     ; D = A * B
    ; Result in D, divide by 256 = take high byte A
    ; Add to I_term with saturation
    ADDA    RAM_BC_I_TERM
    BVC     BC_I_NO_OVERFLOW
    ; Overflow - clamp to max/min
    BPL     BC_I_CLAMP_NEG
    LDAA    #$7F                ; Max positive
    BRA     BC_I_STORE
BC_I_CLAMP_NEG:
    LDAA    #$80                ; Max negative
    BRA     BC_I_STORE
BC_I_NO_OVERFLOW:
    ; Anti-windup: clamp I_term to ±I_MAX
    CMPA    CAL_BC_I_MAX
    BLE     BC_I_CHECK_MIN
    LDAA    CAL_BC_I_MAX
    BRA     BC_I_STORE
BC_I_CHECK_MIN:
    NEGA
    CMPA    CAL_BC_I_MAX        ; Check against negative limit
    NEGA
    BGE     BC_I_STORE
    LDAA    CAL_BC_I_MAX
    NEGA
BC_I_STORE:
    STAA    RAM_BC_I_TERM
    
    ;----- D TERM -----
    ; D_term = (error - prev_error) * D_gain / 16
    LDAA    RAM_BC_ERROR
    SUBA    RAM_BC_ERROR_PREV
    LDAB    CAL_BC_D_GAIN
    JSR     BC_SIGNED_MUL_8
    ASRA                        ; Divide by 16
    RORA
    ASRA
    RORA
    ASRA
    RORA
    ASRA
    RORA
    STAA    RAM_BC_D_TERM
    
    ; Store current error as previous for next cycle
    LDAA    RAM_BC_ERROR
    STAA    RAM_BC_ERROR_PREV
    
    ;----- SUM ALL TERMS -----
    ; output = pilot + P + I + D
    LDAA    RAM_BC_PILOT
    ADDA    RAM_BC_P_TERM
    BVC     BC_SUM1_OK
    BPL     BC_SUM1_MIN
    LDAA    #$FF
    BRA     BC_SUM2
BC_SUM1_MIN:
    CLRA
BC_SUM1_OK:
BC_SUM2:
    ADDA    RAM_BC_I_TERM
    BVC     BC_SUM2_OK
    BPL     BC_SUM2_MIN
    LDAA    #$FF
    BRA     BC_SUM3
BC_SUM2_MIN:
    CLRA
BC_SUM2_OK:
BC_SUM3:
    ADDA    RAM_BC_D_TERM
    BVC     BC_SUM3_OK
    BPL     BC_SUM3_MIN
    LDAA    #$FF
    BRA     BC_STORE_OUTPUT
BC_SUM3_MIN:
    CLRA
BC_SUM3_OK:
BC_STORE_OUTPUT:
    STAA    RAM_BC_PWM_OUT
    RTS

;==============================================================================
; SIGNED 8-BIT MULTIPLY HELPER
;==============================================================================
; Input: A = signed multiplicand, B = unsigned multiplier
; Output: D = A * B (16-bit result)

BC_SIGNED_MUL_8:
    TSTA
    BPL     BC_MUL_POS
    ; A is negative - negate, multiply, negate result
    NEGA
    MUL                         ; D = |A| * B
    COMA                        ; Negate 16-bit result
    COMB
    ADDD    #1
    RTS
BC_MUL_POS:
    MUL                         ; D = A * B
    RTS

;==============================================================================
; PWM OUTPUT ISR (Timer-based)
;==============================================================================
; This ISR should be called at ~1kHz from timer interrupt
; Generates software PWM by comparing counter to duty cycle
;
; RAM_BC_PWM_CTR  - 8-bit counter 0-255 (one PWM cycle)
; RAM_BC_PWM_OUT  - Duty cycle 0-255

RAM_BC_PWM_CTR      EQU     $00AD   ; PWM counter

BC_PWM_ISR:
    ; Increment counter
    INC     RAM_BC_PWM_CTR
    
    ; Compare counter to duty cycle
    LDAA    RAM_BC_PWM_CTR
    CMPA    RAM_BC_PWM_OUT
    BHS     BC_PWM_OFF
    
    ; Counter < duty: output HIGH
    LDAA    PORTA
    ORAA    #$40                ; Set bit 6 (PA6) HIGH
    STAA    PORTA
    RTI
    
BC_PWM_OFF:
    ; Counter >= duty: output LOW
    LDAA    PORTA
    ANDA    #$BF                ; Clear bit 6 (PA6) LOW
    STAA    PORTA
    RTI

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; Add these entries to VY V6 XDF:
;
; <XDFTABLE title="Boost Controller Enable" ... >
;   <XDFAXIS ... />
;   <XDFDATA startaddress="0x7E00" sizeb="1" type="UBYTE" />
; </XDFTABLE>
;
; <XDFTABLE title="Boost Target vs RPM/TPS" ... >
;   <XDFAXIS id="x" count="8" ... /> <!-- TPS -->
;   <XDFAXIS id="y" count="8" ... /> <!-- RPM -->
;   <XDFDATA startaddress="0x7E10" sizeb="64" />
; </XDFTABLE>
;
; <XDFTABLE title="Boost Pilot PWM vs RPM/Target" ... >
;   <XDFAXIS id="x" count="8" ... /> <!-- Target Boost -->
;   <XDFAXIS id="y" count="8" ... /> <!-- RPM -->
;   <XDFDATA startaddress="0x7E50" sizeb="64" />
; </XDFTABLE>
;
; <XDFCONSTANT title="Boost P Gain" ... >
;   <XDFDATA startaddress="0x7E04" sizeb="1" />
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Boost I Gain" ... >
;   <XDFDATA startaddress="0x7E05" sizeb="1" />
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Boost D Gain" ... >
;   <XDFDATA startaddress="0x7E06" sizeb="1" />
; </XDFCONSTANT>

;==============================================================================
; NOTES
;==============================================================================
;
; 1. RAM addresses ($00A0-$00AD) need verification in VY binary
;    Check for unused RAM in $0080-$00FF range
;
; 2. Calibration area ($7E00-$7E8F) needs verification
;    May need to use different area based on binary layout
;
; 3. PWM frequency ~4Hz at 1kHz ISR with 8-bit counter
;    May need faster ISR for responsive boost control
;
; 4. P/I/D gains need tuning on dyno:
;    - Start with P=16, I=8, D=4 (divide by 16/256/16)
;    - Increase P for faster response
;    - Increase I to eliminate steady-state error
;    - Increase D to reduce overshoot
;
; 5. This is based on MS43X C166 code - differences:
;    - MS43X has hardware PWM, VY V6 needs software PWM
;    - MS43X uses 16-bit math, VY V6 limited to 8-bit
;    - MS43X runs faster, adjust gains for VY V6 timing
;
;==============================================================================
; END OF FILE
;==============================================================================
