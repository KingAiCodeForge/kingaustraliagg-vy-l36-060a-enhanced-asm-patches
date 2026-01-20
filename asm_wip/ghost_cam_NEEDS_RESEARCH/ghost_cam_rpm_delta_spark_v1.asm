;==============================================================================
; VY V6 GHOST CAM / LUMPY IDLE v1 - RPM DELTA SPARK MODULATION
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Status: 🔬 NEEDS RESEARCH - Hook points not verified
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: EXPERIMENTAL - Creates intentional misfires for "lopey" sound
; ⚠️ WARNING: Improper tuning = exhaust pops, flames, CAT damage!
; this is a community project please push a new .asm if you have a better method of patching.
;==============================================================================
; RESEARCH SOURCES
;==============================================================================
;
; 1. BMW MS42 ip_iga_n_dif_is__n_dif_cor table (Ghost Cam key table)
;    - RPM Delta: -320 to +200 from target
;    - Spark swing: -27.4° (underspeed) to +19.5° (overspeed)
;    - Total swing: 47° - VERY aggressive
;
; 2. HPTuners LS Ghost Cam (Idle Adaptive Spark Control)
;    - Overspeed P/N: +30° across all cells
;    - Underspeed P/N: -15° across all cells
;    - Total swing: 45°
;
; 3. Ford EL Intech XDF comment:
;    "For bogans looking to make their Intech sound lumpy, make the spark
;     correction values on the right very aggressive. Your welcome ;)"
;
; 4. HPA Academy Ghost Cam Webinar:
;    "Basically, you turn the controller into a really bad controller. LOL."
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; Normal Idle Spark Control:
;   - RPM drops below target → add 2-5° spark → strong combustion → RPM recovers
;   - RPM rises above target → remove 2-5° spark → weak combustion → RPM drops
;   - Result: Smooth idle, barely audible oscillation
;
; Ghost Cam Spark Control:
;   - RPM drops below target → RETARD 15-20° → very weak combustion → RPM drops more
;   - RPM rises above target → ADVANCE 15-30° → very strong combustion → RPM overshoots
;   - Result: Engine "hunts" with 200-400 RPM swings = classic lopey idle
;
; WHY THIS WORKS:
;   - Creates intentional oscillation around target RPM
;   - The "lope" sound is the engine hunting back and forth
;   - No actual cam change - pure spark timing manipulation
;
; DANGER WITHOUT FUEL COMPENSATION:
;   - Weak combustion cycles leave unburned fuel in exhaust
;   - Next strong cycle ignites it → BACKFIRE/FLAME
;   - Solution: Richen idle AFR 0.5-1.0 to compensate
;
;==============================================================================
; VY V6 XDF ADDRESSES (Enhanced v2.09a) - VERIFIED
;==============================================================================
;
; VERIFIED Idle Spark Tables (from XDF and binary analysis):
;   0x6536-0x6540: Idle Spark Advance Vs Coolant (11 cells)
;                  Stock warm: 0x79 = 12.5 deg
;   0x6541-0x654B: Retarded Idle Spark Vs Coolant (11 cells)
;                  Stock: 0x64 = 1.4 deg
;   0x652C bit 2:  Enable Retarded Idle Spark flag (stock = 0)
;
; Encoding: x/256*90-35 (degrees)
;   0x60 = 0 deg, 0x79 = 12.5 deg, 0x64 = 1.4 deg, 0x54 = -5 deg
;
; FROM XDF v2.09a (addresses verified from ghost_lumpy_idle_cam_asm.md):
;   0x6524: IAC Spark Correction Lower Coolant Threshold (~40°C stock)
;   0x6525: High RPM Spark Correction Multiplier (KSARPMHI) - 0.04 DEG%/RPM stock
;   0x6527: Low RPM Spark Correction Multiplier (KSARPMLO) - 0.04 DEG%/RPM stock
;   0x6529: RPM Error Limit For Spark Advance Correction - 512 RPM stock
;   0x652B: Idle Spark Correction Limit (KSCORLIM) - ~15° stock
;
; Ghost Cam recommended values:
;   0x6525: 0.15-0.25 DEG%/RPM (increase for more lope)
;   0x6527: 0.15-0.25 DEG%/RPM (match high RPM)
;   0x6529: 200-300 RPM (narrow deadband for faster engagement)
;   0x652B: 25-35° (allow bigger swings)
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP - VERIFIED
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; Engine RPM (high byte, ×25 scaling)
ECT_ADDR            EQU $00B4       ; Engine Coolant Temperature
TPS_ADDR            EQU $00B6       ; Throttle Position Sensor

;------------------------------------------------------------------------------
; MEMORY MAP - NEED RESEARCH (suspected from XDF analysis)
;------------------------------------------------------------------------------
RPM_TARGET_IDLE     EQU $01A4       ; 🔬 SUSPECTED: Target idle RPM (from XDF tables)
SPARK_BASE          EQU $01B0       ; 🔬 SUSPECTED: Base spark advance before corrections
SPARK_FINAL         EQU $01B2       ; 🔬 SUSPECTED: Final spark advance after all corrections
ENGINE_STATE        EQU $01C0       ; 🔬 SUSPECTED: Engine state flags (idle, run, crank)

;------------------------------------------------------------------------------
; PATCH LOCATION
;------------------------------------------------------------------------------
FREE_SPACE          EQU $C600       ; Free space for patch code
; Hook point needs research - where does idle spark calculation occur?

;------------------------------------------------------------------------------
; CONFIGURATION - AGGRESSIVE GHOST CAM VALUES
;------------------------------------------------------------------------------
; Based on BMW MS42 and HPTuners research
SPARK_RETARD_MAX    EQU $E0         ; -32° retard maximum (when underspeed)
SPARK_ADVANCE_MAX   EQU $1E         ; +30° advance maximum (when overspeed)
RPM_DEADBAND        EQU $14         ; ±20 RPM deadband (no correction)
COOLANT_ENABLE      EQU $3C         ; 60°C minimum for ghost cam (warm only)

;------------------------------------------------------------------------------
; RPM DELTA TO SPARK CORRECTION TABLE
;------------------------------------------------------------------------------
; X-axis: RPM error from target (signed, ×25 scaling)
; Y-axis: Spark correction in degrees (signed, 0.5° per bit)
;
; Based on BMW ip_iga_n_dif_is__n_dif_cor values
;
GHOST_CAM_TABLE:
    ; RPM Delta: -400  -300  -200  -100   -50     0   +50  +100  +200  +300  +400
    ;            -16   -12    -8    -4    -2     0    +2    +4    +8   +12   +16 (÷25)
    .DB $D0, $D8, $E0, $E8, $F0, $00, $10, $18, $20, $28, $30
    ; Spark:  -24°  -20°  -16°  -12°   -8°   0°   +8°  +12°  +16°  +20°  +24°

;==============================================================================
; GHOST CAM SPARK HOOK - CONCEPT CODE
;==============================================================================
; This code would hook into the idle spark calculation routine
; Hook point needs to be discovered via disassembly
;
                    ORG FREE_SPACE

GhostCamSparkHook:
;------------------------------------------------------------------------------
; Step 1: Check if engine is warm enough for ghost cam
;------------------------------------------------------------------------------
                    LDAA    ECT_ADDR            ; Load coolant temp
                    CMPA    #COOLANT_ENABLE     ; Compare to 60°C
                    BLO     .exit_no_ghost      ; Too cold, skip ghost cam

;------------------------------------------------------------------------------
; Step 2: Check if engine is in idle mode
;------------------------------------------------------------------------------
                    LDAA    TPS_ADDR            ; Load throttle position
                    CMPA    #$10                ; Compare to ~6% TPS
                    BHI     .exit_no_ghost      ; Not idle, skip

;------------------------------------------------------------------------------
; Step 3: Calculate RPM delta (current - target)
;------------------------------------------------------------------------------
                    LDAA    RPM_ADDR            ; Load current RPM (÷25)
                    LDAB    RPM_TARGET_IDLE     ; Load target idle RPM (÷25)
                    SBA                         ; A = A - B (signed delta)
                    STAA    RPM_DELTA           ; Store delta for lookup

;------------------------------------------------------------------------------
; Step 4: Check if within deadband (no correction needed)
;------------------------------------------------------------------------------
                    CMPA    #RPM_DEADBAND       ; Compare to +20 RPM
                    BLE     .check_negative     ; Not above deadband
                    BRA     .do_lookup          ; Above deadband, apply correction

.check_negative:
                    CMPA    #-RPM_DEADBAND      ; Compare to -20 RPM (signed)
                    BGE     .exit_no_ghost      ; Within deadband, no correction

;------------------------------------------------------------------------------
; Step 5: Lookup spark correction from table
;------------------------------------------------------------------------------
.do_lookup:
                    ; Scale RPM delta to table index (0-10)
                    ; Delta is -16 to +16 (in ÷25 units)
                    ; Need to map to 0-10 table index
                    ADDA    #$10                ; Shift to 0-32 range
                    LSRA                        ; Divide by 2
                    LSRA                        ; Divide by 4
                    LSRA                        ; Divide by 8 → 0-4 range
                    ; TODO: Better scaling for 11-element table
                    
                    LDX     #GHOST_CAM_TABLE    ; Load table base
                    ABX                         ; X = X + A (index into table)
                    LDAA    0,X                 ; Load spark correction

;------------------------------------------------------------------------------
; Step 6: Apply correction to base spark
;------------------------------------------------------------------------------
                    ADDA    SPARK_BASE          ; Add correction to base
                    
                    ; Clamp to limits
                    CMPA    #$28                ; Max +40° (0x28 = 40)
                    BLE     .check_min
                    LDAA    #$28
                    BRA     .store_spark

.check_min:
                    CMPA    #$F0                ; Min -16° (0xF0 = -16 signed)
                    BGE     .store_spark
                    LDAA    #$F0

.store_spark:
                    STAA    SPARK_FINAL         ; Store final spark value
                    RTS

;------------------------------------------------------------------------------
; Exit without ghost cam modification
;------------------------------------------------------------------------------
.exit_no_ghost:
                    ; Execute original idle spark code here
                    ; (replaced bytes from hook point)
                    ; TODO: Fill in when hook point is known
                    RTS

;------------------------------------------------------------------------------
; RAM Variables (if needed)
;------------------------------------------------------------------------------
RPM_DELTA           EQU $0201               ; RAM: Calculated RPM delta

;==============================================================================
; TODO: RESEARCH REQUIRED
;==============================================================================
;
; 1. Find idle spark calculation routine in binary
;    - Search for references to 0x6525 (KSARPMHI)
;    - Search for LDA/LDB patterns near idle spark tables
;
; 2. Identify hook point for intercepting spark calculation
;    - Needs 3-byte JSR $C600 injection
;    - Must preserve original behavior when ghost cam disabled
;
; 3. Verify RPM_TARGET_IDLE address in RAM
;    - Check what address receives data from idle RPM tables
;
; 4. Add fuel compensation to prevent backfires
;    - See ghost_cam_fuel_compensation_v1.asm (TODO: create)(most likely not needed can be done in xdf with idle fuel in O/l or other methods.)
;    - or tune pre ignition and
     - wall wetting etc usually just the pre ignition and the time it lasts when key is set to pos 2. \
     - and then cranked/started fuel trims can reach over 10 
     - but start up will be great sound and no flames.
; 5. Add P/N vs Drive differentiation
;    - Ghost cam in P/N only, smooth in Drive
;    - Need GEAR_STATE flag address
;    - if the concept is ported to other memcal based ecotecs the moates could 
;      theoretically let this be on bank 2 but again different cpu address and xdf addresses.
;==============================================================================
; END OF FILE
;==============================================================================
