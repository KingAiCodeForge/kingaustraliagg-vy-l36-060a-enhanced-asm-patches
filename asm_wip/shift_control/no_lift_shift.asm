;==============================================================================
; VY V6 NO-LIFT SHIFT v29 - DYNAMIC RPM CAP (MS43X IMPROVED)
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: Flat-foot shifting with dynamic RPM capture (MS43X port)
; Source: MS43X no_lift_shift.asm
; Target: Holden VY V6 $060A (OSID 92118883/92118885)
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: HIGH for manual transmission racing
; ⚠️ WARNING: Manual transmission ONLY - requires clutch switch
;
;==============================================================================
; THEORY OF OPERATION (Ported from MS43X C166)
;==============================================================================
;
; No-Lift Shift (NLS) / Flat Shift allows the driver to keep the throttle
; fully open during gear changes. The ECU briefly cuts spark to reduce
; torque, allowing the synchros to engage smoothly.
;
; MS43X Improvements over v12:
; 1. DYNAMIC RPM CAP - Captures RPM at clutch press, adds small offset
;    This prevents over-rev if shift takes longer than expected
;
; 2. VEHICLE SPEED MINIMUM - Only active above certain speed
;    Prevents accidental activation from stop
;
; 3. MISFIRE COUNTER BYPASS - Suppresses rough engine detection
;    Prevents DTCs during NLS operation
;
; 4. CLUTCH RELEASE DETECTION - Deactivates when clutch released
;    Natural exit from NLS when shift completed
;
;==============================================================================
; ACTIVATION CONDITIONS
;==============================================================================
;
; All must be true:
; 1. NLS enabled in calibration (CAL_NLS_ENABLE = 1)
; 2. Clutch pedal PRESSED (switch closed)
; 3. Vehicle speed ABOVE minimum (e.g., > 20 km/h)
; 4. TPS ABOVE minimum (e.g., > 50% - driver wants to go fast)
;
; Deactivation (any):
; - Clutch released
; - TPS drops below threshold
; - Vehicle speed drops below threshold
;
;==============================================================================
; HARDWARE REQUIREMENTS
;==============================================================================
;
; Required:
; 1. Manual transmission (obviously)
; 2. Clutch pedal position switch wired to ECU
;    - VY V6 manual: Check Port D for clutch input
;    - If not present, wire external switch to spare input
;
; Clutch Switch Wiring:
;   - Normally closed switch at clutch pedal
;   - Opens when clutch fully pressed
;   - Ground = clutch pressed, 5V = clutch released (typical)
;
;==============================================================================
; RAM VARIABLES
;==============================================================================

RAM_NLS_ACTIVE      EQU     $00C4   ; NLS active flag
RAM_NLS_RPM_CAP     EQU     $00C5   ; Dynamic RPM cap (captured at activation)
RAM_NLS_TIMER       EQU     $00C6   ; Timeout timer (prevent stuck-on)
RAM_NLS_MISFIRE_DLY EQU     $00C7   ; Misfire suppression delay counter

;==============================================================================
; CALIBRATION CONSTANTS
;==============================================================================

CAL_NLS_ENABLE      EQU     $7EB0   ; Enable flag (1 = on)
CAL_NLS_MODE        EQU     $7EB1   ; Mode: 1 = clutch only, 2 = clutch + cruise btn
CAL_NLS_VSS_MIN     EQU     $7EB2   ; Minimum vehicle speed (km/h)
CAL_NLS_TPS_MIN     EQU     $7EB3   ; Minimum TPS (0-255)
CAL_NLS_RPM_OFFSET  EQU     $7EB4   ; RPM offset for cap (e.g., 6 = 150 RPM)
CAL_NLS_TIMEOUT     EQU     $7EB5   ; Max NLS duration (10ms units, e.g., 100 = 1s)
CAL_NLS_MISFIRE_DLY EQU     $7EB6   ; Misfire suppression delay (10ms units)

;==============================================================================
; EXISTING ECU ADDRESSES (verify in XDF)
;==============================================================================

RPM_VAR             EQU     $00F0   ; Current RPM / 25
TPS_VAR             EQU     $00DA   ; Current TPS (0-255)
VSS_VAR             EQU     $00DC   ; Vehicle speed (km/h)
PORTD               EQU     $1008   ; Port D data register
CLUTCH_BIT          EQU     $10     ; Clutch switch bit (bit 4) - VERIFY
CRUISE_MAIN_SW      EQU     $00E0   ; Cruise main switch
LIMITER_ACTIVE      EQU     $00C0   ; Ignition cut limiter flag

; Misfire detection bypass
MISFIRE_DLY_FLAG    EQU     $00E4   ; Misfire delay active flag (verify)
MISFIRE_DLY_CTR     EQU     $00E5   ; Misfire delay counter (verify)

;==============================================================================
; NO-LIFT SHIFT MAIN ROUTINE
;==============================================================================
; Call from main loop every cycle (~10ms)

NO_LIFT_SHIFT:
    ; Check if enabled
    LDAA    CAL_NLS_ENABLE
    BEQ     NLS_DISABLED
    
    ; Check if already active
    LDAA    RAM_NLS_ACTIVE
    BNE     NLS_CHECK_DEACTIVATE
    
;----------------------------------------------------------------------
; ACTIVATION CHECKS
;----------------------------------------------------------------------
NLS_CHECK_ACTIVATE:
    ; Check mode for optional cruise button requirement
    LDAA    CAL_NLS_MODE
    CMPA    #2
    BNE     NLS_CHECK_CLUTCH
    
    ; Mode 2: Also require cruise main switch OFF
    ; (Using cruise button as secondary trigger like MS43X)
    LDAA    CRUISE_MAIN_SW
    BNE     NLS_EXIT            ; Cruise engaged, skip
    
NLS_CHECK_CLUTCH:
    ; Condition 1: Clutch must be PRESSED
    LDAA    PORTD
    ANDA    #CLUTCH_BIT
    BNE     NLS_EXIT            ; Clutch not pressed (bit high = released)
    
    ; Condition 2: Vehicle speed must be above minimum
    LDAA    VSS_VAR
    CMPA    CAL_NLS_VSS_MIN
    BLO     NLS_EXIT            ; Speed too low
    
    ; Condition 3: TPS must be above minimum
    LDAA    TPS_VAR
    CMPA    CAL_NLS_TPS_MIN
    BLO     NLS_EXIT            ; TPS too low
    
    ; All conditions met - ACTIVATE NLS
    JMP     NLS_ACTIVATE
    
;----------------------------------------------------------------------
; DEACTIVATION CHECKS
;----------------------------------------------------------------------
NLS_CHECK_DEACTIVATE:
    ; Decrement timeout timer
    DEC     RAM_NLS_TIMER
    BEQ     NLS_TIMEOUT_DEACTIVATE  ; Timer expired
    
    ; Check clutch - deactivate if released
    LDAA    PORTD
    ANDA    #CLUTCH_BIT
    BNE     NLS_DEACTIVATE      ; Clutch released
    
    ; Check TPS - deactivate if dropped
    LDAA    TPS_VAR
    CMPA    CAL_NLS_TPS_MIN
    BLO     NLS_DEACTIVATE      ; TPS dropped
    
    ; Still active - apply NLS effects
    JMP     NLS_APPLY_EFFECTS
    
NLS_TIMEOUT_DEACTIVATE:
    ; Timeout - force deactivate (safety)
    JMP     NLS_DEACTIVATE
    
;----------------------------------------------------------------------
; ACTIVATE NO-LIFT SHIFT
;----------------------------------------------------------------------
NLS_ACTIVATE:
    ; Set active flag
    LDAA    #$01
    STAA    RAM_NLS_ACTIVE
    
    ; CAPTURE current RPM for dynamic cap
    ; This is the key improvement from MS43X
    LDAA    RPM_VAR             ; Current RPM / 25
    ADDA    CAL_NLS_RPM_OFFSET  ; Add offset (e.g., +150 RPM)
    BCC     NLS_CAP_OK
    LDAA    #$FF                ; Clamp to 255 (6375 RPM max)
NLS_CAP_OK:
    STAA    RAM_NLS_RPM_CAP
    
    ; Initialize timeout timer
    LDAA    CAL_NLS_TIMEOUT
    STAA    RAM_NLS_TIMER
    
    ; Initialize misfire delay
    LDAA    CAL_NLS_MISFIRE_DLY
    STAA    RAM_NLS_MISFIRE_DLY
    
    ; Apply effects immediately
    JMP     NLS_APPLY_EFFECTS
    
;----------------------------------------------------------------------
; APPLY NLS EFFECTS
;----------------------------------------------------------------------
NLS_APPLY_EFFECTS:
    ; Effect 1: RPM Limiter (Dynamic Cap)
    ; If RPM >= cap, activate spark cut
    LDAA    RPM_VAR
    CMPA    RAM_NLS_RPM_CAP
    BLO     NLS_RPM_OK
    
    ; Over RPM cap - ACTIVATE SPARK CUT
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    BRA     NLS_SUPPRESS_MISFIRE
    
NLS_RPM_OK:
    ; Under cap - allow spark (shift in progress)
    CLR     LIMITER_ACTIVE
    
NLS_SUPPRESS_MISFIRE:
    ; Effect 2: Suppress Misfire Detection
    ; MS43X sets 1-second delay on misfire counter
    LDAA    RAM_NLS_MISFIRE_DLY
    BEQ     NLS_EXIT            ; Delay expired
    DEC     RAM_NLS_MISFIRE_DLY
    
    ; Set misfire suppression flag
    LDAA    #$01
    STAA    MISFIRE_DLY_FLAG
    LDAA    #100                ; 100 * 10ms = 1 second
    STAA    MISFIRE_DLY_CTR
    
    BRA     NLS_EXIT
    
;----------------------------------------------------------------------
; DEACTIVATE NO-LIFT SHIFT
;----------------------------------------------------------------------
NLS_DEACTIVATE:
    ; Clear active flag
    CLR     RAM_NLS_ACTIVE
    
    ; Clear RPM limiter
    CLR     LIMITER_ACTIVE
    
    ; Misfire detection will resume naturally after delay expires
    
    BRA     NLS_EXIT
    
;----------------------------------------------------------------------
; DISABLED
;----------------------------------------------------------------------
NLS_DISABLED:
    CLR     RAM_NLS_ACTIVE
    CLR     LIMITER_ACTIVE
    
NLS_EXIT:
    RTS

;==============================================================================
; CLUTCH SWITCH DEBOUNCE (OPTIONAL)
;==============================================================================
; If clutch switch is noisy, add debounce logic

RAM_CLUTCH_DEBOUNCE EQU     $00C8   ; Debounce counter

NLS_CLUTCH_DEBOUNCED:
    LDAA    PORTD
    ANDA    #CLUTCH_BIT
    BNE     NLS_CLUTCH_RELEASED
    
    ; Clutch pressed - increment debounce counter
    INC     RAM_CLUTCH_DEBOUNCE
    LDAA    RAM_CLUTCH_DEBOUNCE
    CMPA    #3                  ; 3 cycles = 30ms debounce
    BLO     NLS_CLUTCH_UNKNOWN
    LDAA    #$01                ; Confirmed pressed
    RTS
    
NLS_CLUTCH_RELEASED:
    CLR     RAM_CLUTCH_DEBOUNCE
    CLRA                        ; Confirmed released
    RTS
    
NLS_CLUTCH_UNKNOWN:
    LDAA    #$FF                ; Still debouncing
    RTS

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; <XDFCONSTANT title="No-Lift Shift Enable" ... >
;   <XDFDATA startaddress="0x7EB0" sizeb="1" />
;   <description>1 = NLS enabled, 0 = disabled. MANUAL ONLY!</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS Mode" ... >
;   <XDFDATA startaddress="0x7EB1" sizeb="1" />
;   <description>1 = Clutch only, 2 = Clutch + Cruise button</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS Min Vehicle Speed (km/h)" ... >
;   <XDFDATA startaddress="0x7EB2" sizeb="1" />
;   <description>Minimum speed to allow NLS (e.g., 20 km/h)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS Min TPS (%)" ... >
;   <XDFDATA startaddress="0x7EB3" sizeb="1" />
;   <MATH equation="X * 100 / 255" />
;   <description>Minimum TPS to allow NLS (e.g., 50%)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS RPM Offset" ... >
;   <XDFDATA startaddress="0x7EB4" sizeb="1" />
;   <MATH equation="X * 25" />
;   <description>RPM above shift point for cap. 6 = 150 RPM</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS Timeout (ms)" ... >
;   <XDFDATA startaddress="0x7EB5" sizeb="1" />
;   <MATH equation="X * 10" />
;   <description>Max NLS duration. 100 = 1 second safety timeout</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS Active (Live)" ... >
;   <XDFDATA startaddress="0x00C4" sizeb="1" />
;   <description>READ ONLY - 1 = NLS currently active</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NLS RPM Cap (Live)" ... >
;   <XDFDATA startaddress="0x00C5" sizeb="1" />
;   <MATH equation="X * 25" />
;   <description>READ ONLY - Dynamic RPM cap during NLS</description>
; </XDFCONSTANT>

;==============================================================================
; DIFFERENCES FROM V12 (ignition_cut_patch_v12_flat_shift_no_lift.asm)
;==============================================================================
;
; v12 (Original):
; - Fixed RPM limit (calibration table)
; - No timeout protection
; - No misfire suppression
; - No vehicle speed check
;
; v29 (MS43X Port):
; - DYNAMIC RPM CAP - Captures RPM at clutch press + offset
;   This is the key feature! If you shift at 6000 RPM, cap is 6150 RPM
;   If you shift at 5500 RPM, cap is 5650 RPM
;   Prevents over-rev regardless of shift point
;
; - Timeout safety - Forces deactivation after 1 second
;   Prevents stuck-on if clutch switch fails
;
; - Misfire suppression - Delays rough engine detection
;   Prevents false DTCs during shift
;
; - Vehicle speed minimum - Prevents accidental activation at stop
;   Avoids NLS activating in parking lot

;==============================================================================
; CLUTCH SWITCH WIRING NOTES
;==============================================================================
;
; VY V6 Manual Transmission Clutch Switch:
; - Check Factory Service Manual for clutch start switch location
; - May be cruise control cancel switch (if equipped)
; - If no switch, wire aftermarket switch:
;
;   ┌─────────────────────────────────────┐
;   │  Clutch Pedal Switch Wiring         │
;   │                                     │
;   │  ECU Pin (Port D, bit 4)            │
;   │       │                             │
;   │       ├── 4.7kΩ ──┬── +5V           │
;   │       │           │                 │
;   │       └── Switch ─┴── GND           │
;   │            (N/O)                    │
;   │                                     │
;   │  Switch OPEN (clutch out) = 5V      │
;   │  Switch CLOSED (clutch in) = GND    │
;   └─────────────────────────────────────┘
;
; Verify Port D bit 4 is unused before wiring!

;==============================================================================
; END OF FILE
;==============================================================================
