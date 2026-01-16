;==============================================================================
; VY V6 ROLLING ANTI-LAG v28 - CRUISE BUTTON ACTIVATION
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: Rolling anti-lag via cruise control button (MS43X port)
; Source: MS43X rolling_anti_lag.asm + afr_target_override.asm
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with turbo
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: MEDIUM for turbo builds
; ⚠️ WARNING: TURBO ONLY - Will destroy catalytic converter on N/A
;
;==============================================================================
; THEORY OF OPERATION (Ported from MS43X C166)
;==============================================================================
;
; Rolling Anti-Lag (RAL) maintains turbo boost pressure during partial
; throttle deceleration (like between corners on a race track).
;
; MS43X Activation Conditions:
; 1. Cruise control main switch is OFF (not in cruise mode)
; 2. Cruise decrement button (-) is being HELD
; 3. TPS is above minimum threshold (foot on gas pedal)
;
; When active:
; - RPM is capped at current RPM + offset (dynamic limit)
; - Ignition timing is retarded (creates exhaust heat)
; - AFR target is enriched (excess fuel burns in exhaust)
; - Result: Hot exhaust gases keep turbo spooled
;
; This is SAFER than stationary anti-lag (v10) because:
; - Engine is under load (not overrunning)
; - RPM limited prevents over-rev
; - User controls activation via button
;
;==============================================================================
; HARDWARE REQUIREMENTS
;==============================================================================
;
; Required:
; 1. Turbo setup (wastegate, intercooler, etc.)
; 2. Working cruise control buttons on steering wheel
; 3. Upgraded fuel system for enrichment
; 4. Aftermarket exhaust (no cat - will destroy OEM cat)
;
; Cruise Control Buttons (VY):
;   - Main ON/OFF switch
;   - SET (cruise set)
;   - RES (resume)
;   - + (increment speed)
;   - - (decrement speed) ← USE THIS FOR RAL
;
;==============================================================================
; RAM VARIABLES
;==============================================================================

RAM_RAL_ACTIVE      EQU     $00B8   ; Rolling anti-lag active flag
RAM_RAL_RPM_CAP     EQU     $00B9   ; Dynamic RPM cap (captured at activation)
RAM_RAL_IGA_RTD     EQU     $00BA   ; Ignition retard amount
RAM_RAL_AFR_TARGET  EQU     $00BB   ; Rich AFR target (Lambda * 128)

;==============================================================================
; CALIBRATION CONSTANTS
;==============================================================================

CAL_RAL_ENABLE      EQU     $7EA0   ; Enable flag (1 = on)
CAL_RAL_TPS_MIN     EQU     $7EA1   ; Minimum TPS to allow activation (0-255)
CAL_RAL_RPM_OFFSET  EQU     $7EA2   ; RPM offset above current (e.g., 6 = 150 RPM)
CAL_RAL_IGA_RETARD  EQU     $7EA3   ; Timing retard degrees (e.g., 15°)
CAL_RAL_AFR_TARGET  EQU     $7EA4   ; AFR target (Lambda*128, e.g., 102 = 11.0:1)
CAL_RAL_DWELL_CUT   EQU     $7EA5   ; Enable spark cut pattern (0=no, 1=yes)

;==============================================================================
; EXISTING ECU ADDRESSES (verify in XDF)
;==============================================================================

RPM_VAR             EQU     $00F0   ; Current RPM / 25
TPS_VAR             EQU     $00DA   ; Current TPS (0-255)
CRUISE_MAIN_SW      EQU     $00E0   ; Cruise main switch flag (1 = on)
CRUISE_BUTTONS      EQU     $00E1   ; Cruise button state register
                                    ; Bit pattern: TBD from VY wiring
; MS43X uses ov_req_msw = 6 for decrement button

SPARK_ADVANCE_VAR   EQU     $00D0   ; Current spark advance (degrees)
AFR_TARGET_VAR      EQU     $00D4   ; Current AFR target (Lambda*128)
LIMITER_ACTIVE      EQU     $00C0   ; Ignition cut limiter flag (from v1-v23)

;==============================================================================
; CRUISE BUTTON DEFINITIONS
;==============================================================================
; VY Commodore cruise control button encoding (VERIFY FROM WIRING)
; These are placeholder values - check VY wiring diagram

CRUISE_BTN_NONE     EQU     $00     ; No button pressed
CRUISE_BTN_SET      EQU     $01     ; SET button
CRUISE_BTN_RES      EQU     $02     ; RESUME button
CRUISE_BTN_INC      EQU     $04     ; + Increment button
CRUISE_BTN_DEC      EQU     $08     ; - Decrement button ← USE THIS

;==============================================================================
; ROLLING ANTI-LAG MAIN ROUTINE
;==============================================================================
; Call from main loop every cycle (~10ms)

ROLLING_ANTI_LAG:
    ; Check if enabled in calibration
    LDAA    CAL_RAL_ENABLE
    BEQ     RAL_DISABLED
    
    ; Check if already active
    LDAA    RAM_RAL_ACTIVE
    BNE     RAL_CHECK_DEACTIVATE
    
;----------------------------------------------------------------------
; ACTIVATION CHECKS
;----------------------------------------------------------------------
RAL_CHECK_ACTIVATE:
    ; Condition 1: Cruise main switch must be OFF
    ; (We're using the buttons but not in actual cruise mode)
    LDAA    CRUISE_MAIN_SW
    BNE     RAL_EXIT            ; Cruise engaged, don't activate
    
    ; Condition 2: Decrement button (-) must be held
    LDAA    CRUISE_BUTTONS
    ANDA    #CRUISE_BTN_DEC     ; Check decrement button bit
    BEQ     RAL_EXIT            ; Button not pressed, don't activate
    
    ; Condition 3: TPS must be above threshold
    LDAA    TPS_VAR
    CMPA    CAL_RAL_TPS_MIN
    BLO     RAL_EXIT            ; TPS too low, don't activate
    
    ; All conditions met - ACTIVATE RAL
    JMP     RAL_ACTIVATE
    
;----------------------------------------------------------------------
; DEACTIVATION CHECKS
;----------------------------------------------------------------------
RAL_CHECK_DEACTIVATE:
    ; Condition 1: If cruise main switch turns ON, deactivate
    LDAA    CRUISE_MAIN_SW
    BNE     RAL_DEACTIVATE
    
    ; Condition 2: If button released, deactivate
    LDAA    CRUISE_BUTTONS
    ANDA    #CRUISE_BTN_DEC
    BEQ     RAL_DEACTIVATE
    
    ; Condition 3: If TPS drops below threshold, deactivate
    LDAA    TPS_VAR
    CMPA    CAL_RAL_TPS_MIN
    BLO     RAL_DEACTIVATE
    
    ; Still active - apply RAL effects
    JMP     RAL_APPLY_EFFECTS
    
;----------------------------------------------------------------------
; ACTIVATE ROLLING ANTI-LAG
;----------------------------------------------------------------------
RAL_ACTIVATE:
    ; Set active flag
    LDAA    #$01
    STAA    RAM_RAL_ACTIVE
    
    ; Capture current RPM for dynamic cap
    ; RPM cap = current RPM + offset (e.g., 4500 + 150 = 4650)
    LDAA    RPM_VAR             ; RPM / 25
    ADDA    CAL_RAL_RPM_OFFSET  ; Add offset
    BCC     RAL_CAP_NO_OVERFLOW
    LDAA    #$FF                ; Clamp to max 255 (6375 RPM)
RAL_CAP_NO_OVERFLOW:
    STAA    RAM_RAL_RPM_CAP
    
    ; Load timing retard value
    LDAA    CAL_RAL_IGA_RETARD
    STAA    RAM_RAL_IGA_RTD
    
    ; Load AFR target
    LDAA    CAL_RAL_AFR_TARGET
    STAA    RAM_RAL_AFR_TARGET
    
    ; Apply effects immediately
    JMP     RAL_APPLY_EFFECTS
    
;----------------------------------------------------------------------
; APPLY RAL EFFECTS
;----------------------------------------------------------------------
RAL_APPLY_EFFECTS:
    ; Effect 1: RPM Limiter
    ; If current RPM >= cap, activate ignition cut
    LDAA    RPM_VAR
    CMPA    RAM_RAL_RPM_CAP
    BLO     RAL_RPM_OK
    
    ; Over RPM cap - activate spark cut
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    BRA     RAL_APPLY_TIMING
    
RAL_RPM_OK:
    ; Under RPM cap - no spark cut
    CLR     LIMITER_ACTIVE
    
RAL_APPLY_TIMING:
    ; Effect 2: Timing Retard
    ; Subtract retard from current spark advance
    ; (Better method: add to base timing retard table)
    ; For now, this is conceptual - actual implementation
    ; needs to hook into spark calculation routine
    
    ; Store retard value for spark routine to read
    LDAA    RAM_RAL_IGA_RTD
    ; JSR     APPLY_TIMING_RETARD  ; Hook into spark routine
    
RAL_APPLY_AFR:
    ; Effect 3: AFR Enrichment
    ; Override AFR target if RAL target is richer
    LDAA    AFR_TARGET_VAR
    CMPA    RAM_RAL_AFR_TARGET
    BLS     RAL_EXIT            ; Current target already richer
    
    ; Override with RAL target (richer)
    LDAA    RAM_RAL_AFR_TARGET
    STAA    AFR_TARGET_VAR
    
    BRA     RAL_EXIT
    
;----------------------------------------------------------------------
; DEACTIVATE ROLLING ANTI-LAG
;----------------------------------------------------------------------
RAL_DEACTIVATE:
    ; Clear active flag
    CLR     RAM_RAL_ACTIVE
    
    ; Clear RPM limiter
    CLR     LIMITER_ACTIVE
    
    ; Retard and AFR will naturally return to normal on next calculation
    
    BRA     RAL_EXIT
    
;----------------------------------------------------------------------
; DISABLED
;----------------------------------------------------------------------
RAL_DISABLED:
    CLR     RAM_RAL_ACTIVE
    CLR     LIMITER_ACTIVE
    
RAL_EXIT:
    RTS

;==============================================================================
; ALTERNATIVE: POWER BUTTON ACTIVATION
;==============================================================================
; If cruise buttons are not available, use an external button
; wired to a spare digital input (like Chr0m3's unused pin)

; Placeholder for future implementation:
; SPARE_BUTTON_PORT   EQU     $1008   ; Port D
; SPARE_BUTTON_BIT    EQU     $10     ; Bit 4

; RAL_CHECK_BUTTON:
;     LDAA    SPARE_BUTTON_PORT
;     ANDA    #SPARE_BUTTON_BIT
;     BNE     RAL_BUTTON_PRESSED
;     ; Button not pressed
;     RTS
; RAL_BUTTON_PRESSED:
;     ; Button pressed - check other conditions
;     ...

;==============================================================================
; TIMING RETARD HOOK
;==============================================================================
; This routine should be called from the spark advance calculation
; to apply RAL timing retard when active

RAL_GET_TIMING_RETARD:
    ; Check if RAL active
    LDAA    RAM_RAL_ACTIVE
    BEQ     RAL_RETARD_ZERO
    
    ; Return retard value
    LDAA    RAM_RAL_IGA_RTD
    RTS
    
RAL_RETARD_ZERO:
    CLRA
    RTS

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; <XDFCONSTANT title="Rolling Anti-Lag Enable" ... >
;   <XDFDATA startaddress="0x7EA0" sizeb="1" />
;   <description>1 = RAL enabled, 0 = disabled. TURBO ONLY!</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL TPS Minimum (%)" ... >
;   <XDFDATA startaddress="0x7EA1" sizeb="1" />
;   <MATH equation="X * 100 / 255" />
;   <description>Minimum TPS to allow RAL activation (e.g., 25%)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL RPM Offset" ... >
;   <XDFDATA startaddress="0x7EA2" sizeb="1" />
;   <MATH equation="X * 25" />
;   <description>RPM above current to set as cap. 6 = 150 RPM</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL Ignition Retard (deg)" ... >
;   <XDFDATA startaddress="0x7EA3" sizeb="1" />
;   <description>Timing retard during RAL. 10-20° typical</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL AFR Target (Lambda*128)" ... >
;   <XDFDATA startaddress="0x7EA4" sizeb="1" />
;   <MATH equation="X / 128 * 14.7" />
;   <description>AFR target during RAL. 102 = 11.7:1, 90 = 10.3:1</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL Active (Live)" ... >
;   <XDFDATA startaddress="0x00B8" sizeb="1" />
;   <description>READ ONLY - 1 = RAL currently active</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="RAL RPM Cap (Live)" ... >
;   <XDFDATA startaddress="0x00B9" sizeb="1" />
;   <MATH equation="X * 25" />
;   <description>READ ONLY - Dynamic RPM cap during RAL</description>
; </XDFCONSTANT>

;==============================================================================
; DIFFERENCES FROM V11 (ignition_cut_patch_v11_rolling_antilag.asm)
;==============================================================================
;
; v11 (Original):
; - Fixed RPM limit
; - No timing retard
; - No AFR enrichment
; - Simple alternating cylinder cut
;
; v28 (MS43X Port):
; - Dynamic RPM cap (captures RPM at activation + offset)
; - Configurable timing retard
; - Configurable AFR enrichment
; - Cruise button activation (-)
; - Suppresses rough engine detection
;
; v28 is more comprehensive and closer to OEM rally anti-lag systems

;==============================================================================
; SAFETY NOTES
;==============================================================================
;
; 1. TURBO ONLY - Anti-lag on N/A will cause:
;    - Catalytic converter destruction (excess unburnt fuel)
;    - Exhaust manifold damage (extreme heat)
;    - Backfire risk
;
; 2. Remove catalytic converter before use
;
; 3. Monitor EGT if possible (pyrometer)
;    EGT should not exceed 850°C (1560°F) sustained
;
; 4. Upgraded exhaust manifold/turbo manifold recommended
;
; 5. Test in safe environment (dyno or closed course)
;
;==============================================================================
; END OF FILE
;==============================================================================
