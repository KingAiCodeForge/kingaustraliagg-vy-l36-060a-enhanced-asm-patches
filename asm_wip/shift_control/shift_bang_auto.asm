;==============================================================================
; VY V6 SHIFT BANG / FIRM SHIFT PATCH v30 - AUTOMATIC TRANSMISSION
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 15, 2026
; Method: Spark retard during gear shift to create "bang" effect
; Source: HP Tuners LS1 Torque Management + VL400 $11P beta concepts
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with 4L60E
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: FUN/PERFORMANCE for 4L60E automatic builds
; ⚠️ WARNING: Requires strong transmission internals (servo upgrade minimum)
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; Stock VY V6 has TORQUE MANAGEMENT which REDUCES torque during shifts
; to protect the transmission. This makes shifts feel soft/mushy.
; 
; For "shift bangs" like a broken DFI plate (direct fire ignition), we need
; to either:
;
; Option A: DISABLE torque management + increase line pressure
;           Result: HARD shifts, less slip, more "thunk" than "bang"
;
; Option B: ADD spark retard during shift, then SNAP back timing
;           Result: Engine torque dips, then SURGES = "BANG" effect
;           This is what factory performance cars do (Corvette, etc.)
;
; Option C: SPARK CUT during shift (alternating cylinders)
;           Result: Aggressive bark/crackle during shift
;           WARNING: Can damage drivetrain if too aggressive
;
; This patch implements Option B (spark retard snap) with Option C available
;
;==============================================================================
; WHAT MAKES A "SHIFT BANG"?
;==============================================================================
;
; The "bang" sound comes from:
; 1. Spark timing retarded during clutch apply (torque drops)
; 2. Transmission clutch pack engages firmly
; 3. Spark timing SNAPS back to full advance (torque surges)
; 4. Drivetrain shock loads = audible "bang" from exhaust/tires
;
; Additional factors:
; - High line pressure = clutches engage faster = sharper bang
; - WOT shifts = more torque available = louder bang
; - Performance converter = less slip absorption = harder hit
;
;==============================================================================
; HARDWARE CONSIDERATIONS
;==============================================================================
;
; REQUIRED for aggressive shift bangs:
; 1. Corvette servo (2-3 shift firmness)
; 2. TransGo HD2 or similar shift kit (line pressure boost)
; 3. Performance torque converter OR stock with high stall
; 4. Upgraded axles/diff if doing burnouts
;
; RECOMMENDED:
; - Hardened input shaft
; - 3-4 clutch pack upgrade
; - Upgraded 2-4 band
;
;==============================================================================
; RAM VARIABLES
;==============================================================================

RAM_SHIFT_ACTIVE    EQU     $00D0   ; Shift in progress flag
RAM_SHIFT_PHASE     EQU     $00D1   ; Shift phase: 0=idle, 1=retard, 2=snap
RAM_SHIFT_TIMER     EQU     $00D2   ; Shift phase timer
RAM_SHIFT_RETARD    EQU     $00D3   ; Current retard amount (degrees)
RAM_PREV_GEAR       EQU     $00D4   ; Previous gear for shift detection
RAM_SHIFT_TYPE      EQU     $00D5   ; 0=upshift, 1=downshift

;==============================================================================
; CALIBRATION CONSTANTS
;==============================================================================

CAL_SB_ENABLE       EQU     $7EC0   ; Enable shift bang (1 = on)
CAL_SB_MODE         EQU     $7EC1   ; Mode: 1=retard only, 2=retard+cut, 3=cut only
CAL_SB_RETARD_DEG   EQU     $7EC2   ; Retard during shift (degrees, e.g., 15-25)
CAL_SB_RETARD_TIME  EQU     $7EC3   ; Retard phase duration (10ms units, e.g., 10=100ms)
CAL_SB_SNAP_TIME    EQU     $7EC4   ; Snap-back duration (10ms units, e.g., 5=50ms)
CAL_SB_TPS_MIN      EQU     $7EC5   ; Minimum TPS to enable (e.g., 50% = firm shifts only at WOT)
CAL_SB_CUT_PATTERN  EQU     $7EC6   ; Spark cut pattern (for mode 2/3): 0x55=alternating

;==============================================================================
; EXISTING ECU ADDRESSES (verify in XDF)
;==============================================================================

TPS_VAR             EQU     $00DA   ; Throttle position (0-255)
CURRENT_GEAR        EQU     $00E2   ; Current gear (1-4, 0=park/neutral)
SHIFT_IN_PROG       EQU     $00E3   ; Stock shift in progress flag (verify)
SPARK_ADVANCE_VAR   EQU     $00D0   ; Current commanded spark (needs offset)
LIMITER_ACTIVE      EQU     $00C0   ; Ignition cut flag (from v1-v23)

; Transmission addresses (need verification from XDF)
LINE_PRESSURE_VAR   EQU     $00E6   ; Current line pressure command
SHIFT_TIME_VAR      EQU     $00E8   ; Shift time accumulator

;==============================================================================
; SHIFT BANG MAIN ROUTINE
;==============================================================================
; Call from main loop every cycle (~10ms)

SHIFT_BANG:
    ; Check if enabled
    LDAA    CAL_SB_ENABLE
    BEQ     SB_DISABLED
    
    ; Check for gear change
    LDAA    CURRENT_GEAR
    CMPA    RAM_PREV_GEAR
    BEQ     SB_CHECK_PHASE      ; No gear change, check current phase
    
    ; Gear changed! Start shift bang sequence
    STAA    RAM_PREV_GEAR       ; Update previous gear
    
    ; Determine shift type
    CMPA    RAM_PREV_GEAR
    BHI     SB_UPSHIFT
    ; Downshift detected
    LDAA    #$01
    STAA    RAM_SHIFT_TYPE
    BRA     SB_CHECK_TPS
    
SB_UPSHIFT:
    CLR     RAM_SHIFT_TYPE      ; 0 = upshift
    
SB_CHECK_TPS:
    ; Only enable shift bang if TPS above threshold
    LDAA    TPS_VAR
    CMPA    CAL_SB_TPS_MIN
    BLO     SB_EXIT             ; TPS too low, no bang
    
    ; Start shift bang sequence
    LDAA    #$01
    STAA    RAM_SHIFT_ACTIVE
    STAA    RAM_SHIFT_PHASE     ; Phase 1 = retard
    LDAA    CAL_SB_RETARD_TIME
    STAA    RAM_SHIFT_TIMER
    LDAA    CAL_SB_RETARD_DEG
    STAA    RAM_SHIFT_RETARD
    BRA     SB_APPLY_RETARD
    
SB_CHECK_PHASE:
    ; Check if shift in progress
    LDAA    RAM_SHIFT_ACTIVE
    BEQ     SB_EXIT
    
    ; Decrement timer
    DEC     RAM_SHIFT_TIMER
    BNE     SB_APPLY_EFFECTS
    
    ; Timer expired - advance to next phase
    LDAA    RAM_SHIFT_PHASE
    CMPA    #$01
    BEQ     SB_START_SNAP
    CMPA    #$02
    BEQ     SB_END_SHIFT
    BRA     SB_EXIT
    
SB_START_SNAP:
    ; Transition to snap-back phase
    LDAA    #$02
    STAA    RAM_SHIFT_PHASE
    LDAA    CAL_SB_SNAP_TIME
    STAA    RAM_SHIFT_TIMER
    CLR     RAM_SHIFT_RETARD    ; Remove retard (timing snaps back)
    BRA     SB_EXIT
    
SB_END_SHIFT:
    ; Shift complete
    CLR     RAM_SHIFT_ACTIVE
    CLR     RAM_SHIFT_PHASE
    CLR     RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE      ; Clear any spark cut
    BRA     SB_EXIT

SB_APPLY_EFFECTS:
    ; Check mode and apply effects
    LDAA    CAL_SB_MODE
    CMPA    #$01
    BEQ     SB_APPLY_RETARD
    CMPA    #$02
    BEQ     SB_APPLY_BOTH
    CMPA    #$03
    BEQ     SB_APPLY_CUT
    BRA     SB_EXIT

;----------------------------------------------------------------------
; MODE 1: RETARD ONLY
;----------------------------------------------------------------------
SB_APPLY_RETARD:
    ; Apply spark retard by modifying spark advance variable
    ; Actual implementation needs to hook into spark calculation routine
    ; This stores the retard value for the spark routine to read
    LDAA    RAM_SHIFT_RETARD
    ; STAA    SHIFT_SPARK_RETARD  ; Hook into spark calculation
    BRA     SB_EXIT

;----------------------------------------------------------------------
; MODE 2: RETARD + SPARK CUT
;----------------------------------------------------------------------
SB_APPLY_BOTH:
    ; Apply retard
    LDAA    RAM_SHIFT_RETARD
    ; STAA    SHIFT_SPARK_RETARD
    
    ; Apply alternating spark cut during retard phase
    LDAA    RAM_SHIFT_PHASE
    CMPA    #$01
    BNE     SB_EXIT             ; Only cut during retard phase
    
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    BRA     SB_EXIT

;----------------------------------------------------------------------
; MODE 3: SPARK CUT ONLY (AGGRESSIVE)
;----------------------------------------------------------------------
SB_APPLY_CUT:
    ; Alternating cylinder spark cut
    LDAA    RAM_SHIFT_PHASE
    CMPA    #$01
    BNE     SB_CLEAR_CUT
    
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    BRA     SB_EXIT
    
SB_CLEAR_CUT:
    CLR     LIMITER_ACTIVE
    BRA     SB_EXIT

SB_DISABLED:
    CLR     RAM_SHIFT_ACTIVE
    CLR     RAM_SHIFT_PHASE
    CLR     RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE

SB_EXIT:
    RTS

;==============================================================================
; SPARK RETARD HOOK
;==============================================================================
; This routine should be called from spark advance calculation
; Returns the shift-related timing retard to subtract

SB_GET_RETARD:
    LDAA    RAM_SHIFT_ACTIVE
    BEQ     SB_RETARD_ZERO
    
    ; Return retard value
    LDAA    RAM_SHIFT_RETARD
    RTS
    
SB_RETARD_ZERO:
    CLRA
    RTS

;==============================================================================
; ALTERNATIVE: STOCK TCC RELEASE DURING SHIFT
;==============================================================================
; Another way to get shift "bang" is to release TCC earlier
; This causes engine to flare slightly, then snap back when TCC re-engages
;
; In XDF, look for:
; - TCC Release tables
; - TCC slip during shift
; - Increase "TCC Slip During Shift" value

;==============================================================================
; XDF ENTRIES THAT AFFECT SHIFT FIRMNESS (Stock Tables)
;==============================================================================
;
; From VY V6 Enhanced v2.09a XDF:
;
; Category 0x19 "Torque Mgmt" - Contains:
;   - Maximum Engine Torque Reduction Mode (0x6F7C)
;   - Maximum Engine Torque (0x6F7D)
;   - Adaptive Adjustment Factor For TCMAXTRQ
;
; Category 0x1A "TCC" - Contains:
;   - Enable TCC Conditions (multiple flags)
;   - TCC slip during shift
;   - TCC release delay
;
; Category 0x28 "Shift" - Contains:
;   - Shift time targets
;   - Shift firmness by TPS
;
; To get firmer shifts without this patch:
;   1. Increase line pressure tables
;   2. Reduce shift time targets
;   3. Disable or reduce torque management values
;   4. Increase TCC slip allowed during shift

;==============================================================================
; VL400 $11P BETA INFO (from PCMHacking Topic 5692)
;==============================================================================
;
; VL400 confirmed:
; - "$11P V104 has NO spark retard on shift"
; - "But it can in the beta version I run, light blue is advance..."
; - Beta version adds spark retard table for shift events
;
; This means OSE 11P public version doesn't have shift spark retard,
; but VL400's internal beta does. This patch adds similar functionality
; to VY V6 $060A.

;==============================================================================
; XDF DEFINITION TEMPLATE
;==============================================================================
;
; <XDFCONSTANT title="Shift Bang Enable" ... >
;   <XDFDATA startaddress="0x7EC0" sizeb="1" />
;   <description>1 = Enable shift bang/firm shift patch</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Shift Bang Mode" ... >
;   <XDFDATA startaddress="0x7EC1" sizeb="1" />
;   <description>1=Retard only, 2=Retard+Cut, 3=Cut only</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Shift Retard Degrees" ... >
;   <XDFDATA startaddress="0x7EC2" sizeb="1" />
;   <description>Timing retard during shift (15-25 deg typical)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Retard Duration (10ms)" ... >
;   <XDFDATA startaddress="0x7EC3" sizeb="1" />
;   <description>How long to retard timing (10 = 100ms)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Snap Duration (10ms)" ... >
;   <XDFDATA startaddress="0x7EC4" sizeb="1" />
;   <description>How long to snap timing back (5 = 50ms)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Min TPS for Shift Bang (%)" ... >
;   <XDFDATA startaddress="0x7EC5" sizeb="1" />
;   <MATH equation="X * 100 / 255" />
;   <description>Only enable at this TPS or higher (128 = 50%)</description>
; </XDFCONSTANT>

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; For "broken DFI plate" feel:
;   Mode = 3 (spark cut only)
;   Retard time = 15 (150ms)
;   This gives aggressive bark/crackle during shift
;
; For "Corvette ZR1" feel:
;   Mode = 1 (retard only)
;   Retard degrees = 20
;   Retard time = 10 (100ms)
;   Snap time = 5 (50ms)
;   This gives firm "thunk" with torque surge
;
; For "Best of both" feel:
;   Mode = 2 (retard + cut)
;   Retard degrees = 15
;   Retard time = 8 (80ms)
;   Snap time = 5 (50ms)
;   Alternates between cylinders for crackle + surge
;
; ALWAYS combine with:
;   - Increased line pressure (FM tables)
;   - Reduced shift time targets
;   - TCC slip reduction

;==============================================================================
; END OF FILE
;==============================================================================
