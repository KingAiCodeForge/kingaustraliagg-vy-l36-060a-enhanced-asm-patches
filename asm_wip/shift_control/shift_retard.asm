;==============================================================================
; VY V6 NO-THROTTLE SHIFT PATCH v31 - LIFT-OFF SPARK RETARD (AUTO)
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: Spark retard on deceleration/no-load shifts for automatic trans
; Source: Concept from broken DFI plate behavior + MS43X TTC
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with 4L60E
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: SPECIALTY for specific shift feel
; ⚠️ NOTE: Different from v30 - this is for DECEL/coast shifts
;
;==============================================================================
; WHAT THIS PATCH DOES
;==============================================================================
;
; When you lift off the throttle and the trans shifts (coast downshift
; or tip-in upshift), this patch applies spark retard to:
;
; 1. Reduce engine braking harshness on downshift
; 2. Smooth out tip-in upshifts (like when slowly accelerating in traffic)
; 3. Create "broken DFI" feel where ignition seems disconnected from throttle
;
; The "broken DFI plate" effect:
; - DFI plate connects throttle signal to ignition timing
; - When broken, timing doesn't follow throttle instantly
; - Creates lazy/soft throttle response with delayed spark
; - Some people like this "floaty" feel
;
;==============================================================================
; USE CASES
;==============================================================================
;
; USE THIS PATCH IF YOU WANT:
; ✓ Smoother coast-down shifts (no lurch when trans downshifts)
; ✓ Softer tip-in response (less aggressive at light throttle)
; ✓ "Broken DFI" retro muscle car feel
; ✓ Reduced drivetrain shock on part-throttle shifts
;
; DO NOT USE IF YOU WANT:
; ✗ Maximum performance response
; ✗ Sharp throttle feel
; ✗ Aggressive downshift engine braking
;
;==============================================================================
; RAM VARIABLES
;==============================================================================

RAM_NTS_ACTIVE      EQU     $00D8   ; No-throttle shift active
RAM_NTS_RETARD      EQU     $00D9   ; Current retard amount
RAM_NTS_TIMER       EQU     $00DA   ; Retard duration timer
RAM_NTS_PREV_TPS    EQU     $00DB   ; Previous TPS for rate detection

;==============================================================================
; CALIBRATION CONSTANTS
;==============================================================================

CAL_NTS_ENABLE      EQU     $7ED0   ; Enable patch (1 = on)
CAL_NTS_TPS_MAX     EQU     $7ED1   ; Maximum TPS to activate (e.g., 64 = 25%)
CAL_NTS_TPS_RATE    EQU     $7ED2   ; TPS rate of change threshold (lift-off speed)
CAL_NTS_RETARD_DEG  EQU     $7ED3   ; Retard amount (degrees, e.g., 10-15)
CAL_NTS_RETARD_TIME EQU     $7ED4   ; Retard duration (10ms units)
CAL_NTS_COAST_ONLY  EQU     $7ED5   ; 1 = only on coast shifts, 0 = any low-TPS shift

;==============================================================================
; EXISTING ECU ADDRESSES
;==============================================================================

TPS_VAR             EQU     $00DA   ; Throttle position (0-255)
RPM_VAR             EQU     $00F0   ; Engine RPM / 25
CURRENT_GEAR        EQU     $00E2   ; Current gear
SHIFT_IN_PROG       EQU     $00E3   ; Shift in progress flag
DECEL_FLAG          EQU     $00E4   ; Deceleration mode flag (DFCO)

;==============================================================================
; NO-THROTTLE SHIFT MAIN ROUTINE
;==============================================================================

NO_THROTTLE_SHIFT:
    ; Check if enabled
    LDAA    CAL_NTS_ENABLE
    BEQ     NTS_DISABLED
    
    ; Check if already active
    LDAA    RAM_NTS_ACTIVE
    BNE     NTS_CHECK_END
    
;----------------------------------------------------------------------
; ACTIVATION CHECKS
;----------------------------------------------------------------------
NTS_CHECK_ACTIVATE:
    ; Condition 1: Shift in progress
    LDAA    SHIFT_IN_PROG
    BEQ     NTS_UPDATE_TPS      ; No shift, just update TPS history
    
    ; Condition 2: TPS below threshold (light throttle or closed)
    LDAA    TPS_VAR
    CMPA    CAL_NTS_TPS_MAX
    BHI     NTS_UPDATE_TPS      ; TPS too high, not a low-throttle shift
    
    ; Condition 3: Check coast-only mode
    LDAA    CAL_NTS_COAST_ONLY
    BEQ     NTS_ACTIVATE        ; Not coast-only, any low-TPS shift triggers
    
    ; Coast-only mode: Check TPS rate (must be decreasing)
    LDAA    RAM_NTS_PREV_TPS
    SUBA    TPS_VAR             ; A = prev - current (positive if closing)
    CMPA    CAL_NTS_TPS_RATE    ; Check against rate threshold
    BLO     NTS_UPDATE_TPS      ; Not closing fast enough
    
    ; All conditions met - ACTIVATE
NTS_ACTIVATE:
    LDAA    #$01
    STAA    RAM_NTS_ACTIVE
    LDAA    CAL_NTS_RETARD_DEG
    STAA    RAM_NTS_RETARD
    LDAA    CAL_NTS_RETARD_TIME
    STAA    RAM_NTS_TIMER
    BRA     NTS_APPLY_RETARD
    
;----------------------------------------------------------------------
; CHECK FOR END OF RETARD
;----------------------------------------------------------------------
NTS_CHECK_END:
    ; Decrement timer
    DEC     RAM_NTS_TIMER
    BEQ     NTS_END             ; Timer expired
    
    ; Check if throttle opened (driver wants power again)
    LDAA    TPS_VAR
    CMPA    CAL_NTS_TPS_MAX
    BHI     NTS_END             ; TPS opened, cancel retard
    
    ; Continue retard
    BRA     NTS_APPLY_RETARD
    
NTS_END:
    ; End of retard - return to normal
    CLR     RAM_NTS_ACTIVE
    CLR     RAM_NTS_RETARD
    BRA     NTS_UPDATE_TPS
    
;----------------------------------------------------------------------
; APPLY SPARK RETARD
;----------------------------------------------------------------------
NTS_APPLY_RETARD:
    ; Retard stored in RAM_NTS_RETARD for spark routine to read
    ; Actual implementation hooks into spark advance calculation
    LDAA    RAM_NTS_RETARD
    ; Store for spark routine...
    BRA     NTS_UPDATE_TPS
    
NTS_DISABLED:
    CLR     RAM_NTS_ACTIVE
    CLR     RAM_NTS_RETARD
    
NTS_UPDATE_TPS:
    ; Store current TPS for next cycle's rate calculation
    LDAA    TPS_VAR
    STAA    RAM_NTS_PREV_TPS
    
NTS_EXIT:
    RTS

;==============================================================================
; SPARK RETARD HOOK
;==============================================================================

NTS_GET_RETARD:
    LDAA    RAM_NTS_ACTIVE
    BEQ     NTS_RETARD_ZERO
    LDAA    RAM_NTS_RETARD
    RTS
NTS_RETARD_ZERO:
    CLRA
    RTS

;==============================================================================
; "BROKEN DFI PLATE" SIMULATION
;==============================================================================
; If you want constant delayed throttle response (not just on shifts):

; Option A: Add fixed retard based on TPS opening rate
;   - Calculate d(TPS)/dt
;   - If TPS opening fast, add more retard
;   - Makes throttle feel "disconnected" like worn cable
;
; Option B: Low-pass filter on spark advance
;   - Smooth changes to spark timing
;   - Prevents instant response to throttle
;
; These would be separate patches, not included here

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; <XDFCONSTANT title="No-Throttle Shift Enable" ... >
;   <XDFDATA startaddress="0x7ED0" sizeb="1" />
;   <description>1 = Enable retard on low-TPS shifts</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NTS Max TPS (%)" ... >
;   <XDFDATA startaddress="0x7ED1" sizeb="1" />
;   <MATH equation="X * 100 / 255" />
;   <description>Maximum TPS to trigger (64 = 25%)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NTS TPS Rate Threshold" ... >
;   <XDFDATA startaddress="0x7ED2" sizeb="1" />
;   <description>Min TPS closing rate to trigger (coast-only mode)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NTS Retard Degrees" ... >
;   <XDFDATA startaddress="0x7ED3" sizeb="1" />
;   <description>Timing retard during NTS (10-15 deg typical)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="NTS Retard Duration (10ms)" ... >
;   <XDFDATA startaddress="0x7ED4" sizeb="1" />
;   <description>How long to retard (15 = 150ms)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Coast Only Mode" ... >
;   <XDFDATA startaddress="0x7ED5" sizeb="1" />
;   <description>1 = Only on closing throttle shifts</description>
; </XDFCONSTANT>

;==============================================================================
; COMPARISON: v30 vs v31
;==============================================================================
;
; v30 (Shift Bang):
;   - Activates on HIGH TPS shifts
;   - Creates aggressive "bang" feel
;   - For performance driving
;
; v31 (No-Throttle Shift):
;   - Activates on LOW TPS shifts
;   - Creates smooth/soft feel
;   - For comfort/cruise driving
;
; You can run BOTH patches together:
;   - High TPS shifts = v30 bangs
;   - Low TPS shifts = v31 smooth
;   - Different feels for different situations

;==============================================================================
; END OF FILE
;==============================================================================
