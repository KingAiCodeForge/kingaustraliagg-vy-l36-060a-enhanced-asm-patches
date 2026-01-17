;==============================================================================
; VY V6 FLAT FOOT SHIFT / NO-LIFT SHIFT PATCH v31 - MANUAL TRANSMISSION
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 17, 2026
; Method: Spark cut/retard during clutch-in for flat-foot shifting
; Source: PCMTec HOWTO, HP Tuners forums, Holley flat shift methods
; Target: Holden VY V6 $060A (OSID 92118883) with T56/Getrag/M78 manual
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: PERFORMANCE - Faster shifts, no throttle lift required
; ⚠️ WARNING: Increased clutch wear if used aggressively
;
;==============================================================================
; ⚠️⚠️⚠️ TEMPLATE FILE - PLACEHOLDER ADDRESSES ⚠️⚠️⚠️
;==============================================================================
;
; THIS IS A QUICK TEMPLATE - MANY ADDRESSES ARE MADE UP AND UNVERIFIED!
;
; BEFORE USING:
; 1. Verify RAM addresses $0180-$0185 are actually FREE (not used by ECU)
; 2. Verify CAL addresses $C500-$C506 are in FREE ROM space
; 3. Cross-reference with RAM_Variables_Validated.md
; 4. Cross-reference with XDF free space analysis
;
; HARDWARE REQUIRED:
; - Clutch switch wired to digital input (cruise control models have this)
; - Wire to spare HC11 port pin (PORTD bit recommended)
;
;==============================================================================
; WHY MANUAL TRANS IS BETTER FOR POPS/BANGS/FLAT SHIFT
;==============================================================================
;
; MANUAL TRANSMISSION ADVANTAGES:
; 1. Direct mechanical connection - driver controls shift timing precisely
; 2. Clutch switch input available for shift detection
; 3. No torque converter to absorb/mask the effect
; 4. No TCM (Transmission Control Module) interference
; 5. Instant throttle response without converter slip delay
;
; WHAT THIS PATCH DOES:
; - Detects clutch pedal pressed (via clutch switch input)
; - When clutch pressed + TPS high = FLAT FOOT SHIFT mode
; - Cuts spark OR retards timing to prevent over-rev
; - Creates pops/bangs/crackle in exhaust during shift
; - Engine RPM holds steady instead of flaring to redline
;
; BENEFITS:
; - Faster shifts (no throttle lift = no turbo lag/boost loss)
; - Dramatic exhaust sound during shifts
; - Reduced synchro wear (engine speed matched better)
; - Consistent launch RPM for drag racing
;
; RISKS:
; ⚠️ Increased clutch wear (dumping clutch at WOT)
; ⚠️ Synchro damage if shift technique is poor
; ⚠️ Exhaust heat (unburned fuel if using fuel+spark method)
;
;==============================================================================
; THEORY OF OPERATION - FLAT FOOT SHIFTING
;==============================================================================
;
; Normal manual shift sequence:
; 1. Lift throttle (engine RPM drops)
; 2. Push clutch in
; 3. Move gear lever
; 4. Release clutch
; 5. Re-apply throttle
;
; Flat foot shift sequence (with this patch):
; 1. Keep throttle PINNED (WOT)
; 2. Push clutch in → ECU detects clutch switch + high TPS
; 3. ECU cuts spark → RPM stops rising, holds steady
; 4. Move gear lever (RPM stays constant)
; 5. Release clutch → spark resumes → instant power
;
; The "pops and bangs" come from:
; - Unburned fuel entering hot exhaust during spark cut
; - Late combustion from retarded timing
; - Exhaust resonance during decel-like conditions at WOT
;
;
;==============================================================================
; RAM VARIABLES - ⚠️ PLACEHOLDERS - VERIFY BEFORE USE!
;==============================================================================
; These addresses are MADE UP and may conflict with ECU variables!
; Find actual free RAM by analyzing binary with disassembler.

RAM_FLATSHIFT_ACTIVE EQU    $0180   ; ⚠️ PLACEHOLDER - Flat shift in progress flag
RAM_FLATSHIFT_MODE   EQU    $0181   ; ⚠️ PLACEHOLDER - 0=off, 1=cutting, 2=resuming
RAM_FLATSHIFT_TIMER  EQU    $0182   ; ⚠️ PLACEHOLDER - Timeout counter (prevents stuck)
RAM_CLUTCH_DEBOUNCE  EQU    $0183   ; ⚠️ PLACEHOLDER - Clutch switch debounce counter
RAM_PREV_CLUTCH      EQU    $0184   ; ⚠️ PLACEHOLDER - Previous clutch state
RAM_SHIFT_RETARD     EQU    $0185   ; ⚠️ PLACEHOLDER - Current timing retard amount

;==============================================================================
; CALIBRATION CONSTANTS - ⚠️ VERIFY FREE ROM SPACE ($C468-$FFBF)
;==============================================================================

CAL_FS_ENABLE       EQU     $C500   ; ⚠️ PLACEHOLDER - Enable flat shift (1 = on)
CAL_FS_MODE         EQU     $C501   ; ⚠️ PLACEHOLDER - 1=spark cut, 2=retard, 3=both
CAL_FS_RETARD_DEG   EQU     $C502   ; ⚠️ PLACEHOLDER - Retard degrees (15-30 typical)
CAL_FS_TPS_MIN      EQU     $C503   ; ⚠️ PLACEHOLDER - Min TPS to activate (e.g., 80%)
CAL_FS_RPM_MIN      EQU     $C504   ; ⚠️ PLACEHOLDER - Min RPM to activate (e.g., 3000)
CAL_FS_TIMEOUT      EQU     $C505   ; ⚠️ PLACEHOLDER - Max cut time (10ms units, 50=500ms)
CAL_FS_DEBOUNCE     EQU     $C506   ; ⚠️ PLACEHOLDER - Clutch debounce (10ms units)

;==============================================================================
; EXISTING ECU ADDRESSES - ⚠️ VERIFY IN XDF/ADX BEFORE USE!
;==============================================================================

; RPM - VERIFIED from copilot-instructions.md
ENGINE_RPM          EQU     $00A2   ; ✅ VERIFIED - RPM/25 (8-bit, max 6375 RPM)

; TPS - needs XDF verification
TPS_VAR             EQU     $00DA   ; ⚠️ UNVERIFIED - Throttle position (0-255)

; Clutch Switch Input - HC11 PORTD
; VY with cruise control has clutch switch wired to disable cruise
; Need to identify which port bit - likely PORTD or PORTE
CLUTCH_SWITCH_PORT  EQU     $1008   ; HC11 PORTD data register
CLUTCH_SWITCH_BIT   EQU     $04     ; ⚠️ GUESS - Bit 2 of PORTD (verify hardware!)

; Limiter flag for spark cut integration
LIMITER_ACTIVE      EQU     $00C0   ; ⚠️ From v1-v23 patches (may need verify)

;==============================================================================
; FLAT FOOT SHIFT MAIN ROUTINE - MANUAL TRANSMISSION
;==============================================================================
; Call from main loop every cycle (~10ms)
; Logic: Clutch pressed + TPS high + RPM above min = CUT SPARK

FLAT_SHIFT:
    ; Check if feature enabled
    LDAA    CAL_FS_ENABLE
    BEQ     FS_DISABLED
    
    ; Read clutch switch
    LDAA    CLUTCH_SWITCH_PORT  ; Read PORTD
    ANDA    #CLUTCH_SWITCH_BIT  ; Mask clutch bit
    BNE     FS_CLUTCH_OUT       ; Bit set = clutch released (not pressed)
    
    ; Clutch is PRESSED - check TPS threshold
FS_CLUTCH_IN:
    LDAA    TPS_VAR
    CMPA    CAL_FS_TPS_MIN      ; TPS above threshold?
    BLO     FS_CONDITIONS_NOT_MET
    
    ; Check RPM threshold (8-bit: value × 25 = actual RPM)
    LDAA    ENGINE_RPM          ; Load RPM/25 (8-bit) - CORRECT METHOD
    CMPA    CAL_FS_RPM_MIN      ; RPM above minimum?
    BLO     FS_CONDITIONS_NOT_MET
    
    ; ALL CONDITIONS MET: Clutch in + TPS high + RPM high
    ; Activate flat shift mode!
    LDAA    #$01
    STAA    RAM_FLATSHIFT_ACTIVE
    
    ; Check timeout (safety - don't cut forever)
    INC     RAM_FLATSHIFT_TIMER
    LDAA    RAM_FLATSHIFT_TIMER
    CMPA    CAL_FS_TIMEOUT
    BHI     FS_TIMEOUT          ; Exceeded max cut time
    
    ; Apply effect based on mode
    LDAA    CAL_FS_MODE
    CMPA    #$01
    BEQ     FS_SPARK_CUT
    CMPA    #$02
    BEQ     FS_SPARK_RETARD
    CMPA    #$03
    BEQ     FS_BOTH
    BRA     FS_EXIT

;----------------------------------------------------------------------
; CLUTCH RELEASED - Resume normal operation
;----------------------------------------------------------------------
FS_CLUTCH_OUT:
FS_CONDITIONS_NOT_MET:
    ; Clear flat shift state
    CLR     RAM_FLATSHIFT_ACTIVE
    CLR     RAM_FLATSHIFT_TIMER
    CLR     RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE
    BRA     FS_EXIT

;----------------------------------------------------------------------
; TIMEOUT - Clutch held too long, resume to prevent damage
;----------------------------------------------------------------------
FS_TIMEOUT:
    ; Clear flat shift but leave timer maxed (requires clutch release to reset)
    CLR     RAM_FLATSHIFT_ACTIVE
    CLR     RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE
    BRA     FS_EXIT

;----------------------------------------------------------------------
; MODE 1: SPARK CUT (Most aggressive - loudest pops)
;----------------------------------------------------------------------
FS_SPARK_CUT:
    ; Set limiter active flag - spark routine will cut all spark
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    BRA     FS_EXIT

;----------------------------------------------------------------------
; MODE 2: TIMING RETARD (Smoother - less stress on drivetrain)
;----------------------------------------------------------------------
FS_SPARK_RETARD:
    ; Store retard value for spark calculation to subtract
    LDAA    CAL_FS_RETARD_DEG
    STAA    RAM_SHIFT_RETARD
    ; Spark routine should read RAM_SHIFT_RETARD and subtract from advance
    CLR     LIMITER_ACTIVE      ; Don't cut spark, just retard
    BRA     FS_EXIT

;----------------------------------------------------------------------
; MODE 3: BOTH CUT + RETARD (Alternating - crackle effect)
;----------------------------------------------------------------------
FS_BOTH:
    ; Alternate between cut and retard for "machine gun" effect
    LDAA    RAM_FLATSHIFT_TIMER
    ANDA    #$01                ; Toggle every loop
    BEQ     FS_BOTH_CUT
    
    ; Odd cycles: Retard only
    LDAA    CAL_FS_RETARD_DEG
    STAA    RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE
    BRA     FS_EXIT
    
FS_BOTH_CUT:
    ; Even cycles: Full cut
    LDAA    #$01
    STAA    LIMITER_ACTIVE
    CLR     RAM_SHIFT_RETARD
    BRA     FS_EXIT

;----------------------------------------------------------------------
; FEATURE DISABLED
;----------------------------------------------------------------------
FS_DISABLED:
    CLR     RAM_FLATSHIFT_ACTIVE
    CLR     RAM_FLATSHIFT_TIMER
    CLR     RAM_SHIFT_RETARD
    CLR     LIMITER_ACTIVE

FS_EXIT:
    RTS

;==============================================================================
; SPARK RETARD HOOK - Call from spark advance calculation
;==============================================================================
; Returns the flat-shift timing retard to subtract from calculated advance
; Spark routine should: final_advance = calculated_advance - FS_GET_RETARD()

FS_GET_RETARD:
    LDAA    RAM_FLATSHIFT_ACTIVE
    BEQ     FS_RETARD_ZERO
    
    ; Return retard value (0-30 degrees typically)
    LDAA    RAM_SHIFT_RETARD
    RTS
    
FS_RETARD_ZERO:
    CLRA
    RTS

;==============================================================================
; ALTERNATIVE: DECEL POPS & BANGS (Throttle Lift-Off)
;==============================================================================
; For pops/bangs on DECEL (throttle lift-off, not during shift):
;
; Method 1: Disable Overrun Fuel Cut (DFCO)
;   - Stock ECU cuts fuel on decel to save fuel
;   - Disabling this keeps fuel flowing = combustion in exhaust
;   - In XDF: Find "Decel Fuel Cut" or "DFCO" tables, disable or increase delay
;
; Method 2: Retard timing on decel
;   - Add 10-20 degrees retard when TPS = 0 and RPM dropping
;   - Late combustion = exhaust pops
;
; Method 3: Add fuel on decel
;   - Opposite of fuel cut - inject extra fuel
;   - Burns in hot exhaust = flames
;   - ⚠️ WARNING: Catalytic converter damage!
;
; Reference: Equilibrium Tuning - "Burbles achieved by increasing fuel
;            overrun delay and retarding ignition timing"

;==============================================================================
; MANUAL TRANS WIRING - CLUTCH SWITCH
;==============================================================================
;
; VY V6 with cruise control already has clutch switch:
; - Clutch switch is normally closed (grounded when clutch released)
; - When clutch pressed, switch opens (goes high)
; - This disables cruise control
;
; To use for flat shift:
; 1. Find which ECU pin the clutch switch connects to
; 2. Trace to HC11 port (likely PORTD $1008 or PORTE $100A)
; 3. Update CLUTCH_SWITCH_PORT and CLUTCH_SWITCH_BIT above
;
; If no clutch switch installed:
; 1. Install normally-open switch on clutch pedal
; 2. Wire to spare digital input on ECU
; 3. Switch should ground the input when clutch pressed
;
; Alternative: Use a momentary button on steering wheel/shifter
;   - Press button while shifting = activate flat shift
;   - More control, but requires driver input

;==============================================================================
; PCMTEC REFERENCE (auF2035 - Flat Shift Enable)
;==============================================================================
;
; From PCMTec forum (Topic 158):
; "If you have enabled a multi tune you can add auF2035 to different tunes
;  and set it out of range. This allows you to make flat shifting only
;  available on certain tunes."
;
; auF2035 = Flat Shift Enable parameter in LS1/LS2 ECUs
; This patch replicates similar functionality for HC11-based VY V6

;==============================================================================
; XDF DEFINITION TEMPLATE - FLAT SHIFT CALIBRATION
;==============================================================================
;
; <XDFCONSTANT title="Flat Shift Enable" ... >
;   <EMBEDDEDDATA mmedaddress="0xC500" mmedelementsizebits="8" />
;   <description>1 = Enable flat foot shift (clutch + WOT = spark cut)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Flat Shift Mode" ... >
;   <EMBEDDEDDATA mmedaddress="0xC501" mmedelementsizebits="8" />
;   <description>1=Spark cut (loud), 2=Retard (smooth), 3=Both (crackle)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Flat Shift Retard Degrees" ... >
;   <EMBEDDEDDATA mmedaddress="0xC502" mmedelementsizebits="8" />
;   <description>Timing retard when flat shifting (15-30 deg typical)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Flat Shift Min TPS" ... >
;   <EMBEDDEDDATA mmedaddress="0xC503" mmedelementsizebits="8" />
;   <MATH equation="X * 100 / 255" />
;   <description>Minimum TPS to activate (204 = 80%, 230 = 90%)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Flat Shift Min RPM" ... >
;   <EMBEDDEDDATA mmedaddress="0xC504" mmedelementsizebits="8" />
;   <MATH equation="X * 25" />
;   <description>Minimum RPM to activate (120 = 3000 RPM, 160 = 4000 RPM)</description>
; </XDFCONSTANT>
;
; <XDFCONSTANT title="Flat Shift Timeout" ... >
;   <EMBEDDEDDATA mmedaddress="0xC505" mmedelementsizebits="8" />
;   <MATH equation="X * 10" />
;   <description>Max cut duration in ms (50 = 500ms safety limit)</description>
; </XDFCONSTANT>

;==============================================================================
; TUNING NOTES - MANUAL TRANSMISSION
;==============================================================================
;
; RECOMMENDED STARTING POINTS:
;
; Street/Mild (T56/Getrag):
;   Mode = 2 (retard only)
;   Retard degrees = 15
;   Min TPS = 204 (80%)
;   Min RPM = 120 (3000 RPM)
;   Timeout = 50 (500ms)
;   Result: Smooth shifts, mild crackle, synchro-friendly
;
; Track/Aggressive (T56/M78):
;   Mode = 1 (spark cut)
;   Min TPS = 230 (90%)
;   Min RPM = 160 (4000 RPM)
;   Timeout = 30 (300ms)
;   Result: Loud pops, fast shifts, holds RPM perfectly
;
; Maximum Attack (Drag racing, sequential):
;   Mode = 3 (cut + retard alternating)
;   Retard degrees = 25
;   Min TPS = 245 (96% = WOT only)
;   Min RPM = 200 (5000 RPM)
;   Timeout = 20 (200ms)
;   Result: Machine-gun crackle, maximum drama
;
; CLUTCH WEAR NOTES:
; - Higher Min TPS = less clutch wear (only activates at WOT)
; - Lower timeout = less time under load
; - Retard mode is gentler than cut mode on drivetrain
; - Use with performance clutch (Exedy, Clutch Masters, etc.)
;
; EXHAUST NOTES:
; - Mode 1 (cut) = loudest pops (fuel enters exhaust, ignites)
; - Mode 2 (retard) = crackle/burble (late combustion)
; - Mode 3 (both) = machine-gun effect (alternating)
; - ⚠️ Catalytic converter damage possible with Mode 1/3
; - Consider decat/high-flow cat for serious use

;==============================================================================
; END OF FILE
;==============================================================================
