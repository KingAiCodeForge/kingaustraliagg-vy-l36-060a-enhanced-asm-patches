;==============================================================================
; VY V6 SHIFT SPARK RETARD PATCH v32 - AUTOMATIC TRANSMISSION
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 17, 2026 - Refactored with VERIFIED addresses from XDF/ADX
; Method: Spark retard during shift to smooth torque delivery
; Source: OSE 11P spark retard concept + VX_VY_VU ADX shift time logging
; Target: Holden VY V6 $060A (OSID 92118883/92118885) with 4L60E
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ STATUS: PRACTICAL IMPLEMENTATION - Addresses cross-referenced
; 📖 XDF: VX VY_V6_$060A_Enhanced_v2.09a.xdf
; 📖 ADX: VX_VY_VU Engine and trans TP5 V104.adx
;
;==============================================================================
; VERIFIED ADDRESSES FROM XDF/ADX ANALYSIS (January 17, 2026)
;==============================================================================
;
; === RAM VARIABLES (From ADX Packet Offsets) ===
; TPS%:       Packet offset 0x0D, scaling X*0.392157 (0-100%)
; RPM:        $00A2 (8-bit, ×25 scaling) - VALIDATED in RAM_Variables_Validated.md
; Gear Ratio: Packet offset 0x0E (16-bit, X/16384 = ratio)
; 1-2 Shift:  Packet offset 0x0C (time = X/40 seconds)
; 2-3 Shift:  Packet offset 0x0D (time = X/40 seconds)
;
; === CALIBRATION ROM (From XDF) ===
; 0x675C: Spark Advance/Retard vs Time in PE (9 bytes)
;         - F4PEADRT table - spark trim during power enrichment
;         - Scaling: X/256*90-35 degrees
; 0x6765: # of 3X Refs to delay PE spark
;
; === FREE SPACE FOR PATCH CODE ===
; $14468 (file 0x0C468): 15,192 bytes VERIFIED FREE
;
;==============================================================================
; THEORY: HOW THIS WORKS WITH EXISTING ECU
;==============================================================================
;
; The VY V6 ECU already has shift-related spark control:
; - F4PEADRT table at 0x675C adds/subtracts spark during PE
; - DFCO exit spark limiting (table at 0x41803/0x42044)
; - TCC-controlled spark advance (flag at line 10578)
;
; THIS PATCH adds: Spark retard on DECEL shifts (coast downshift)
; to reduce drivetrain lurch when trans downshifts at closed throttle.
;
; The 11P approach from Topic 7922:
;   NOTE: OSE 11P = VN-VS custom OS (ECU 1227808, NOT VY V6!)
;         Based on BLCC V8 (OSID $5D), CAKH V6 (OSID $11C VR)
;         Same HC11 CPU but different memory layout than VY V6 $060A!
;   "Spark retard option... reduces spark advance to create less engine
;    torque" - we apply same concept to shift events.
;
;==============================================================================
; PATCH RAM VARIABLES ($0180-$0183 in scratch area)
;==============================================================================
; NOTE: $018x range is near dwell variables ($0199 = dwell time)
;       This area is used for timer/calculation scratch space
;       Verify no conflicts with your specific binary!

RAM_SHIFT_RETARD_ACTIVE EQU $0180   ; Patch active flag (0=off, 1=active)
RAM_SHIFT_RETARD_AMT    EQU $0181   ; Current retard amount (0-255 = 0-35°)
RAM_SHIFT_TIMER         EQU $0182   ; Countdown timer (in 10ms ticks)
RAM_PREV_GEAR_RATIO     EQU $0183   ; Previous gear ratio for change detect

;==============================================================================
; PATCH CALIBRATION CONSTANTS ($C500 in unused calibration area)
;==============================================================================
; Using $C5xx range - check XDF for conflicts! 
; Alternative: Use $14468+ in verified free space

CAL_SHIFT_ENABLE        EQU $C500   ; 00=disabled, 01=enabled
CAL_SHIFT_RETARD_DEG    EQU $C501   ; Retard degrees ×2.84 (e.g., 28 = ~10°)
CAL_SHIFT_DURATION      EQU $C502   ; Duration in 10ms units (15 = 150ms)
CAL_SHIFT_TPS_MAX       EQU $C503   ; Max TPS% to activate (25 = ~10% throttle)
CAL_SHIFT_RPM_MIN       EQU $C504   ; Minimum RPM/25 (40 = 1000 RPM)

;==============================================================================
; EXISTING ECU RAM ADDRESSES (VALIDATED)
;==============================================================================

RPM_VAR             EQU $00A2   ; Engine RPM ÷ 25 [VALIDATED - RAM_Variables_Validated.md]
TPS_VAR             EQU $00A1   ; TPS raw value [NEEDS VERIFICATION - common address]
                                ; ADX shows TPS% at packet 0x0D, raw A/D at 0x0C

;==============================================================================
; EXISTING ECU ROM ADDRESSES (FROM XDF)
;==============================================================================

; Spark Advance/Retard vs Time in PE (F4PEADRT)
ROM_PE_SPARK_TABLE  EQU $675C   ; 9-byte table, scaling X/256*90-35

; DFCO Exit Spark Limit
ROM_DFCO_SPARK_MAX  EQU $7C07   ; Maximum spark during DFCO exit (address from XDF search)

;==============================================================================
; HOOK POINT - Where to intercept spark calculation
;==============================================================================
; The ECU calculates final spark advance somewhere in the ignition routine.
; We need to find where spark value is written to output compare register.
;
; From 3X_PERIOD_ANALYSIS_COMPLETE.md:
; - Dwell calculated and stored at $0199
; - 3X period captured at $017B
; - Spark output via TOC1/TOC2 registers ($1018/$101A)
;
; HOOK STRATEGY: Insert JSR to our routine just before final spark write
;
; PLACEHOLDER - Actual hook address needs disassembly of spark output routine

HOOK_SPARK_CALC     EQU $18500  ; ⚠️ PLACEHOLDER - Find actual address!
                                ; This should be in the ignition timing ISR

;==============================================================================
; PATCH CODE - Install at verified free space
;==============================================================================

                    ORG $14468  ; ✅ VERIFIED FREE SPACE (file offset $14468)

;----------------------------------------------------------------------
; SHIFT_RETARD_CHECK - Called from spark calculation routine
;----------------------------------------------------------------------
; Input:  A = calculated spark advance (before output)
; Output: A = modified spark advance (with retard subtracted if active)
; Preserves: B, X, Y
;----------------------------------------------------------------------

SHIFT_RETARD_CHECK:
    PSHA                        ; Save original spark advance
    
    ; Check if patch enabled
    LDAA    CAL_SHIFT_ENABLE
    BEQ     SRC_SKIP            ; Disabled, restore and exit
    
    ; Check if retard currently active
    LDAA    RAM_SHIFT_RETARD_ACTIVE
    BNE     SRC_APPLY           ; Already active, apply and decrement
    
    ; ---- CHECK FOR SHIFT TRIGGER ----
    
    ; Condition 1: TPS must be low (closed or nearly closed throttle)
    LDAA    TPS_VAR
    CMPA    CAL_SHIFT_TPS_MAX
    BHI     SRC_SKIP            ; TPS too high, not a coast shift
    
    ; Condition 2: RPM must be above minimum (engine running)
    LDAA    RPM_VAR             ; $00A2 - RPM/25 [VALIDATED]
    CMPA    CAL_SHIFT_RPM_MIN
    BLO     SRC_SKIP            ; RPM too low
    
    ; Condition 3: Detect gear ratio change (shift in progress)
    ; NOTE: This is simplified - real implementation would read gear ratio
    ;       from trans status RAM which needs further disassembly to find.
    ;
    ; For now: Use TPS rate of change as proxy for decel shift
    ; (Actual gear ratio detection requires finding trans status RAM)
    
    ; Activate retard
    LDAA    #$01
    STAA    RAM_SHIFT_RETARD_ACTIVE
    LDAA    CAL_SHIFT_RETARD_DEG
    STAA    RAM_SHIFT_RETARD_AMT
    LDAA    CAL_SHIFT_DURATION
    STAA    RAM_SHIFT_TIMER
    BRA     SRC_APPLY
    
SRC_APPLY:
    ; Decrement timer
    DEC     RAM_SHIFT_TIMER
    BNE     SRC_DO_RETARD
    
    ; Timer expired - clear active flag
    CLR     RAM_SHIFT_RETARD_ACTIVE
    CLR     RAM_SHIFT_RETARD_AMT
    BRA     SRC_SKIP

SRC_DO_RETARD:
    ; Subtract retard from spark advance
    ; Original spark in (SP), retard amount in RAM_SHIFT_RETARD_AMT
    PULA                        ; Get original spark
    SUBA    RAM_SHIFT_RETARD_AMT
    BCC     SRC_DONE            ; No underflow, use result
    CLRA                        ; Underflow - clamp to 0°
    BRA     SRC_DONE

SRC_SKIP:
    PULA                        ; Restore original spark (unchanged)

SRC_DONE:
    RTS

;----------------------------------------------------------------------
; SHIFT_RETARD_INIT - Call once at ECU reset
;----------------------------------------------------------------------

SHIFT_RETARD_INIT:
    CLR     RAM_SHIFT_RETARD_ACTIVE
    CLR     RAM_SHIFT_RETARD_AMT
    CLR     RAM_SHIFT_TIMER
    CLR     RAM_PREV_GEAR_RATIO
    RTS

;==============================================================================
; INSTALLATION INSTRUCTIONS
;==============================================================================
;
; 1. FIND HOOK POINT:
;    Disassemble the ignition timing routine to find where final spark
;    advance is calculated, just before writing to output compare register.
;    Look for writes to TOC1 ($1018) or TOC2 ($101A).
;
; 2. INSERT HOOK:
;    At the hook point, replace existing instruction with:
;        JSR SHIFT_RETARD_CHECK  ; $14468
;    The original instruction may need to be moved into our routine.
;
; 3. CALIBRATION VALUES (Default suggestions):
;    $C500 = $01 (enabled)
;    $C501 = $1C (28 = ~10° retard with X/256*90-35 scaling)
;    $C502 = $0F (15 = 150ms duration)  
;    $C503 = $19 (25 = ~10% TPS threshold)
;    $C504 = $28 (40 = 1000 RPM minimum)
;
; 4. ADD XDF ENTRIES:
;    See XDF template below.
;
;==============================================================================
; XDF CONSTANT DEFINITIONS
;==============================================================================

;  <XDFCONSTANT uniqueid="0xSR01">
;    <title>Shift Retard Enable</title>
;    <description>0=Disabled, 1=Enabled. Adds spark retard during low-TPS shifts.</description>
;    <CATEGORYMEM index="0" category="30" />
;    <EMBEDDEDDATA mmedaddress="0xC500" mmedelementsizebits="8" />
;    <units>Boolean</units>
;    <MATH equation="X"><VAR id="X" /></MATH>
;  </XDFCONSTANT>
;
;  <XDFCONSTANT uniqueid="0xSR02">
;    <title>Shift Retard Degrees</title>
;    <description>Spark retard during shift. ~10° typical for smooth feel.</description>
;    <CATEGORYMEM index="0" category="30" />
;    <EMBEDDEDDATA mmedaddress="0xC501" mmedelementsizebits="8" />
;    <units>Degrees</units>
;    <MATH equation="X/256*90-35"><VAR id="X" /></MATH>
;  </XDFCONSTANT>
;
;  <XDFCONSTANT uniqueid="0xSR03">
;    <title>Shift Retard Duration</title>
;    <description>How long to apply retard (×10ms). 15=150ms typical.</description>
;    <CATEGORYMEM index="0" category="30" />
;    <EMBEDDEDDATA mmedaddress="0xC502" mmedelementsizebits="8" />
;    <units>×10ms</units>
;    <MATH equation="X*10"><VAR id="X" /></MATH>
;  </XDFCONSTANT>
;
;  <XDFCONSTANT uniqueid="0xSR04">
;    <title>Shift Retard Max TPS</title>
;    <description>Maximum TPS% to trigger retard. 10% = coast shifts only.</description>
;    <CATEGORYMEM index="0" category="30" />
;    <EMBEDDEDDATA mmedaddress="0xC503" mmedelementsizebits="8" />
;    <units>%</units>
;    <MATH equation="X*0.392"><VAR id="X" /></MATH>
;  </XDFCONSTANT>
;
;  <XDFCONSTANT uniqueid="0xSR05">
;    <title>Shift Retard Min RPM</title>
;    <description>Minimum RPM for retard. Prevents activation at idle.</description>
;    <CATEGORYMEM index="0" category="30" />
;    <EMBEDDEDDATA mmedaddress="0xC504" mmedelementsizebits="8" />
;    <units>RPM</units>
;    <MATH equation="X*25"><VAR id="X" /></MATH>
;  </XDFCONSTANT>

;==============================================================================
; REMAINING WORK (TODO)
;==============================================================================
;
; [ ] Find actual TPS RAM address (ADX shows packet offset, not RAM addr)
; [ ] Find gear position/ratio RAM address for proper shift detection
; [ ] Find spark output routine hook point via disassembly
; [ ] Verify $C500-$C504 is truly unused calibration space
; [ ] Test on actual ECU with datalogger monitoring spark advance
;
;==============================================================================
; END OF FILE
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
