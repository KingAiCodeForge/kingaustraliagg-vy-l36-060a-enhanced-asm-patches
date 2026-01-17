;==============================================================================
; VY V6 IGNITION CUT v7 - LAUNCH CONTROL TWO-STEP
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: Clutch-activated two-step launch control
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   Two-step launch control for drag racing / burnouts
;   - Normal driving: Rev limiter at 6300 RPM (main limiter)
;   - Clutch pressed: Rev limiter at 3500 RPM (launch limiter)
;   - Allows building boost/RPM with clutch in
;   - Release clutch = instant power at optimum launch RPM
;
; Based On: Chr0m3-approved 3X Period Injection (Method A)
; Status: 🔬 EXPERIMENTAL - Builds on proven method
;
; How It Works:
;   1. Monitor clutch switch input (needs hardware connection)
;   2. If clutch pressed + RPM > 3500: Inject fake 3X period (spark cut)
;   3. If clutch released + RPM > 6300: Inject fake 3X period (main limiter)
;   4. Creates "two-step" behavior: 3500 RPM launch, 6300 RPM main
;
; Hardware Required:
;   - Clutch switch (normally on cruise control models)
;   - Wire clutch switch to spare digital input
;   - Ground when clutch pressed, open when released
;
; XDF Configuration:
;   - Launch RPM: 3500 RPM (adjustable for turbo boost building)
;   - Main RPM: 6300 RPM (community consensus safe limit)
;   - Hysteresis: 100 RPM (prevents bounce)
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM address
PERIOD_3X_RAM       EQU $017B       ; 3X period storage
CLUTCH_SWITCH       EQU $1008       ; Port D data register (HC11 PORTD = $1008, NOT $1004!)

; LAUNCH CONTROL THRESHOLDS
LAUNCH_RPM_HIGH     EQU $0DAC       ; 3500 RPM (launch limiter activation)
LAUNCH_RPM_LOW      EQU $0D48       ; 3400 RPM (hysteresis)

; MAIN LIMITER THRESHOLDS (SAFE DEFAULT - 6000 RPM)
MAIN_RPM_HIGH       EQU $1770       ; 6000 RPM (main limiter activation - SAFE)
MAIN_RPM_LOW        EQU $175C       ; 5980 RPM (hysteresis)

FAKE_PERIOD         EQU $3E80       ; 16000 = 1000ms fake period
LIMITER_STATE       EQU $01A0       ; State flag (0=off, 1=launch, 2=main)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED (was $18156 WRONG!)

;==============================================================================
; TWO-STEP LAUNCH CONTROL HANDLER
;==============================================================================

LAUNCH_CONTROL_HANDLER:
    PSHB
    PSHA
    PSHX
    
    ; Read clutch switch
    LDAA    CLUTCH_SWITCH       ; Read port D
    ANDA    #$04                ; Mask bit 2 (clutch input)
    BEQ     CLUTCH_PRESSED      ; 0 = pressed (grounded)
    
    ; Clutch released - use main limiter
CLUTCH_RELEASED:
    LDD     RPM_ADDR
    CPD     #MAIN_RPM_HIGH
    BHI     ACTIVATE_MAIN_LIMITER
    
    CPD     #MAIN_RPM_LOW
    BLS     DEACTIVATE_LIMITER
    
    ; Hysteresis zone - maintain current state
    LDAA    LIMITER_STATE
    CMPA    #$02                ; Check if main limiter active
    BEQ     ACTIVATE_MAIN_LIMITER
    BRA     DEACTIVATE_LIMITER
    
    ; Clutch pressed - use launch limiter
CLUTCH_PRESSED:
    LDD     RPM_ADDR
    CPD     #LAUNCH_RPM_HIGH
    BHI     ACTIVATE_LAUNCH_LIMITER
    
    CPD     #LAUNCH_RPM_LOW
    BLS     DEACTIVATE_LIMITER
    
    ; Hysteresis zone
    LDAA    LIMITER_STATE
    CMPA    #$01                ; Check if launch limiter active
    BEQ     ACTIVATE_LAUNCH_LIMITER
    BRA     DEACTIVATE_LIMITER

ACTIVATE_LAUNCH_LIMITER:
    LDD     #FAKE_PERIOD        ; Load fake 3X period
    STD     PERIOD_3X_RAM       ; Store (cuts spark)
    LDAA    #$01
    STAA    LIMITER_STATE       ; State = launch active
    BRA     EXIT_HANDLER

ACTIVATE_MAIN_LIMITER:
    LDD     #FAKE_PERIOD
    STD     PERIOD_3X_RAM
    LDAA    #$02
    STAA    LIMITER_STATE       ; State = main active
    BRA     EXIT_HANDLER

DEACTIVATE_LIMITER:
    CLR     LIMITER_STATE       ; State = off
    ; Don't modify PERIOD_3X_RAM, let stock code handle it
    
EXIT_HANDLER:
    PULX
    PULA
    PULB
    RTS

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; LAUNCH RPM SELECTION:
;   NA Engine: 3000-4000 RPM (tire grip limited)
;   Turbo: 3500-5000 RPM (build boost before launch)
;   Supercharger: 3000-3500 RPM (instant boost, lower RPM)
;
; CLUTCH SWITCH WIRING:
;   VT/VX/VY cruise control models have clutch switch
;   Non-cruise models: Add switch to clutch pedal bracket
;   Wire to spare ECU input (check VY_V6_PINOUT_MASTER_MAPPING)
;
; ANTI-LAG (advanced):
;   Combine with fuel cut disable during launch
;   Allows unburned fuel into exhaust
;   Ignites in hot exhaust = maintains turbo boost
;   ⚠️ HIGH RISK - exhaust/turbo damage possible
;
;==============================================================================
