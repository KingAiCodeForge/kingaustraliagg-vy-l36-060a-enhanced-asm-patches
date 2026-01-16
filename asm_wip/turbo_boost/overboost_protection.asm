;==============================================================================
; VY V6 OVERBOOST PROTECTION v27 - SAFETY FUEL CUT
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: Fuel cut on overboost detection (MS43X port)
; Source: MS43X overboost_protection.asm
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with turbo
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: HIGH for turbo builds - SAFETY CRITICAL
; ⚠️ WARNING: Requires 3-bar MAP sensor for accurate boost reading
;
;==============================================================================
; THEORY OF OPERATION (Ported from MS43X C166)
;==============================================================================
;
; The overboost protection system:
; 1. Monitors MAP sensor continuously
; 2. Compares to threshold with hysteresis
; 3. Requires 2 consecutive readings above threshold (debounce)
; 4. Activates fuel cut to reduce engine power
; 5. Deactivates when boost drops below (threshold - hysteresis)
;
; MS43X adds E85/RON98 blend for thresholds - simplified here
;
;==============================================================================
; HARDWARE REQUIREMENTS
;==============================================================================
;
; Required: 3-bar MAP sensor wired to MAP input (C11)
; The stock 1-bar MAP saturates at 100 kPa (atmospheric)
; 3-bar MAP range: 0-300 kPa (0-200 kPa boost)
;
; MAP Sensor Options:
;   - GM 12575832 (3-bar, 0-5V)
;   - GM 12223861 (3-bar, -14.7 to 29.4 psi)
;   - Omni Power 3-bar (aftermarket)
;
;==============================================================================
; RAM VARIABLES
;==============================================================================

RAM_OB_ACTIVE       EQU     $00B0   ; Overboost active flag
RAM_OB_COUNT        EQU     $00B1   ; Debounce counter (2 cycles needed)
RAM_OB_MAP_PREV     EQU     $00B2   ; Previous MAP reading
RAM_OB_MAP_PREV2    EQU     $00B3   ; 2-cycle-old MAP reading

;==============================================================================
; CALIBRATION CONSTANTS
;==============================================================================

; Overboost threshold (kPa) - e.g., 200 kPa = 1 bar boost (at sea level)
CAL_OB_THRESHOLD    EQU     $7E90   ; Overboost cut threshold (kPa)
CAL_OB_HYSTERESIS   EQU     $7E91   ; Hysteresis (kPa) - e.g., 20 kPa
CAL_OB_ENABLE       EQU     $7E92   ; Enable flag (1 = on, 0 = off)

;==============================================================================
; EXISTING ECU ADDRESSES
;==============================================================================

MAP_VAR             EQU     $00D8   ; Current MAP (kPa) - verify in XDF
FUEL_CUT_FLAG       EQU     $00F8   ; Fuel cut request flag - verify address
                                    ; Set to 1 = fuel cut active

;==============================================================================
; OVERBOOST PROTECTION MAIN ROUTINE
;==============================================================================
; Call from main loop every cycle (~10ms)

OVERBOOST_PROTECTION:
    ; Check if enabled
    LDAA    CAL_OB_ENABLE
    BEQ     OB_DISABLED
    
    ; Shift MAP history
    LDAA    RAM_OB_MAP_PREV
    STAA    RAM_OB_MAP_PREV2
    LDAA    MAP_VAR
    STAA    RAM_OB_MAP_PREV
    
    ; Check if already in overboost mode
    LDAA    RAM_OB_ACTIVE
    BNE     OB_CHECK_DEACTIVATE
    
;----------------------------------------------------------------------
; ACTIVATION CHECK
;----------------------------------------------------------------------
OB_CHECK_ACTIVATE:
    ; Check if current MAP > threshold
    LDAA    MAP_VAR
    CMPA    CAL_OB_THRESHOLD
    BLO     OB_RESET_COUNT      ; Below threshold, reset counter
    
    ; Check if previous MAP (2 cycles ago) was also > threshold
    ; This provides 2-cycle debounce (MS43X method)
    LDAA    RAM_OB_MAP_PREV2
    CMPA    CAL_OB_THRESHOLD
    BLO     OB_INCREMENT_COUNT  ; Only 1 cycle above, wait for 2nd
    
    ; Both current and 2-cycle-old readings above threshold
    ; ACTIVATE OVERBOOST PROTECTION
    JMP     OB_ACTIVATE
    
OB_INCREMENT_COUNT:
    INC     RAM_OB_COUNT
    LDAA    RAM_OB_COUNT
    CMPA    #2                  ; Need 2 consecutive cycles
    BLO     OB_EXIT             ; Not enough cycles yet
    JMP     OB_ACTIVATE
    
OB_RESET_COUNT:
    CLR     RAM_OB_COUNT
    BRA     OB_EXIT
    
;----------------------------------------------------------------------
; DEACTIVATION CHECK
;----------------------------------------------------------------------
OB_CHECK_DEACTIVATE:
    ; Calculate deactivation threshold = threshold - hysteresis
    LDAA    CAL_OB_THRESHOLD
    SUBA    CAL_OB_HYSTERESIS
    TAB                         ; B = deactivation threshold
    
    ; Check if current MAP < deactivation threshold
    LDAA    MAP_VAR
    CBA                         ; Compare A to B
    BHS     OB_EXIT             ; Still above, stay in overboost mode
    
    ; DEACTIVATE OVERBOOST PROTECTION
    JMP     OB_DEACTIVATE
    
;----------------------------------------------------------------------
; ACTIVATE OVERBOOST
;----------------------------------------------------------------------
OB_ACTIVATE:
    ; Set overboost active flag
    LDAA    #$01
    STAA    RAM_OB_ACTIVE
    
    ; ACTIVATE FUEL CUT
    ; Method 1: Set stock fuel cut flag (if available)
    LDAA    #$01
    STAA    FUEL_CUT_FLAG
    
    ; Method 2: Clear injector pulsewidth directly
    ; (more aggressive, needs injector PW address)
    ; CLR     INJECTOR_PW_VAR
    
    ; Method 3: Force PE (Power Enrichment) multiplier to 0
    ; (table-based approach)
    
    BRA     OB_EXIT
    
;----------------------------------------------------------------------
; DEACTIVATE OVERBOOST
;----------------------------------------------------------------------
OB_DEACTIVATE:
    ; Clear overboost active flag
    CLR     RAM_OB_ACTIVE
    CLR     RAM_OB_COUNT
    
    ; Clear fuel cut flag
    CLR     FUEL_CUT_FLAG
    
    BRA     OB_EXIT
    
;----------------------------------------------------------------------
; DISABLED - Clear all flags
;----------------------------------------------------------------------
OB_DISABLED:
    CLR     RAM_OB_ACTIVE
    CLR     RAM_OB_COUNT
    CLR     FUEL_CUT_FLAG
    
OB_EXIT:
    RTS

;==============================================================================
; ALTERNATIVE: COMBINED FUEL + SPARK CUT
;==============================================================================
; For more aggressive protection, cut both fuel AND spark

OB_ACTIVATE_AGGRESSIVE:
    ; Set overboost active flag
    LDAA    #$01
    STAA    RAM_OB_ACTIVE
    
    ; Fuel cut
    LDAA    #$01
    STAA    FUEL_CUT_FLAG
    
    ; Spark cut via ignition cut patch (if installed)
    ; Set limiter active flag to enable spark cut
    ; This integrates with v1-v23 ignition cut patches
    LDAA    #$01
    STAA    $00C0               ; LIMITER_ACTIVE (verify address from v1)
    
    RTS

OB_DEACTIVATE_AGGRESSIVE:
    ; Clear all flags
    CLR     RAM_OB_ACTIVE
    CLR     RAM_OB_COUNT
    CLR     FUEL_CUT_FLAG
    CLR     $00C0               ; Clear LIMITER_ACTIVE
    
    RTS

;==============================================================================
; 3-BAR MAP SENSOR SCALING
;==============================================================================
; Stock ECU expects 1-bar MAP (0-100 kPa = 0-255 counts)
; 3-bar MAP outputs 0-300 kPa = 0-255 counts
;
; Conversion factor: 3-bar_count / 2.94 = equivalent 1-bar reading
; Or: 3-bar_kPa = count * 300 / 255 = count * 1.176
;
; For overboost detection, we can use raw count directly
; Just set CAL_OB_THRESHOLD in 3-bar scale:
;   - 170 counts = 200 kPa (1 bar boost)
;   - 213 counts = 250 kPa (1.5 bar boost)
;   - 255 counts = 300 kPa (2 bar boost - MAP maxed)
;
; Threshold examples:
;   CAL_OB_THRESHOLD = 170 = ~200 kPa = 1.0 bar boost (14.7 psi)
;   CAL_OB_THRESHOLD = 191 = ~225 kPa = 1.25 bar boost (18.4 psi)
;   CAL_OB_THRESHOLD = 213 = ~250 kPa = 1.5 bar boost (22 psi)

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; <XDFCONSTANT title="Overboost Enable" ... >
;   <XDFDATA startaddress="0x7E92" sizeb="1" type="UBYTE" />
;   <units>bool</units>
;   <description>1 = Overboost protection enabled, 0 = disabled</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Overboost Threshold (3-bar scale)" ... >
;   <XDFDATA startaddress="0x7E90" sizeb="1" type="UBYTE" />
;   <units>kPa (raw)</units>
;   <MATH equation="X * 1.176" />
;   <description>MAP threshold for overboost fuel cut (3-bar: 170=200kPa)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Overboost Hysteresis" ... >
;   <XDFDATA startaddress="0x7E91" sizeb="1" type="UBYTE" />
;   <units>kPa (raw)</units>
;   <description>Hysteresis for deactivation (e.g., 20 = ~24 kPa)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Overboost Active (Live)" ... >
;   <XDFDATA startaddress="0x00B0" sizeb="1" type="UBYTE" />
;   <description>READ ONLY - 1 = overboost protection active</description>
; </XDFCONSTANT>

;==============================================================================
; INTEGRATION WITH v26 BOOST CONTROLLER
;==============================================================================
;
; If using v26 boost controller, add this check at start of BOOST_CONTROLLER:
;
; BOOST_CONTROLLER:
;     ; Check overboost protection first
;     LDAA    RAM_OB_ACTIVE
;     BNE     BC_OVERBOOST_ACTIVE
;     
;     ; ... normal boost controller code ...
;     
; BC_OVERBOOST_ACTIVE:
;     ; Force minimum PWM (close wastegate fully)
;     CLR     RAM_BC_PWM_OUT
;     RTS
;
; This ensures wastegate opens fully during overboost to dump boost pressure

;==============================================================================
; NOTES
;==============================================================================
;
; 1. 2-cycle debounce prevents false triggers from electrical noise
;    MS43X uses ov_map_prev_2 (2 cycles ago) for verification
;
; 2. Hysteresis prevents oscillation at threshold boundary
;    Typical value: 15-25 kPa (10-15% of threshold)
;
; 3. FUEL_CUT_FLAG address needs verification in VY binary
;    Look for stock fuel cut logic and find the flag
;
; 4. For safety, consider adding DTC logging:
;    - Set Code 48 (high boost) like OSE 12P
;    - Requires DTC table modification
;
; 5. Test thoroughly on dyno with boost gauge verification!
;
;==============================================================================
; END OF FILE
;==============================================================================
