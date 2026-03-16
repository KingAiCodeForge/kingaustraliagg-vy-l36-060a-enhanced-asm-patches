;==============================================================================
; VY V6 GHOST CAM v1 — RPM DELTA SPARK MODULATION (ASM PATCH)
;==============================================================================
; Author:   Jason King (kingaustraliagg / KingAI)
; Date:     January 18, 2026 (refactored February 25, 2026)
; Status:   NEEDS RESEARCH — Hook points not verified in disassembly
; Target:   Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary:   VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB, 3-bank HC11)
; Processor: Motorola MC68HC11
;
; PURPOSE:
;   Implement ghost cam via RPM-delta spark correction, based on the
;   BMW MS42 ip_iga_n_dif_is method. Applies a spark advance/retard
;   correction proportional to how far actual RPM is from target idle.
;   The correction is deliberately INVERTED from normal PID behavior —
;   underspeed gets retard (not advance), overspeed gets advance (not retard).
;   This makes the idle oscillate instead of stabilize.
;
; TERMINOLOGY:
;   "Lumpy Idle" = XDF-only approach, slow ~1Hz lope, no ASM patch
;   "Ghost Cam"  = Fast aggressive lopey sound, requires ASM patching
;
; COMPANION FILES:
;   ghost_cam_rpm_rotating_idle.asm — Theory/concepts/idea bank
;
; WARNINGS:
;   - EXPERIMENTAL — creates intentional misfires for "lopey" sound
;   - Improper tuning = exhaust pops, flames, catalytic converter damage
;   - Rhysk94 (RKGarage) has a working ghost cam on VY V6 but states he
;     does NOT use timing. We DO NOT KNOW his method. This file is our own
;     theoretical approach based on BMW MS42 and HPTuners LS research.
;   - THIS FILE IS UNTESTED — use at your own risk.
;==============================================================================
; RESEARCH SOURCES
;==============================================================================
;
; 1. BMW MS42 ip_iga_n_dif_is__n_dif_cor table (Ghost Cam key table)
;    - Input: RPM delta from target idle (negative = under, positive = over)
;    - RPM delta range: -320 to +200 RPM from target
;    - Output: Spark correction (signed degrees)
;    - Spark swing: -27.4° (underspeed) to +19.5° (overspeed)
;    - Total swing: 47° — VERY aggressive
;    - KEY: The correction is INVERTED from normal PID. Under target = RETARD.
;      This is what makes it oscillate instead of stabilize.
;
; 2. HPTuners LS Ghost Cam (Idle Adaptive Spark Control)
;    - Two separate tables: Overspeed and Underspeed
;    - Overspeed P/N: +30° across all cells (advance when above target)
;    - Underspeed P/N: -15° across all cells (retard when below target)
;    - Total swing: 45°
;    - Simpler than BMW — flat values, not proportional to delta
;
; 3. Ford EL Intech XDF comment:
;    "For bogans looking to make their Intech sound lumpy, make the spark
;     correction values on the right very aggressive. Your welcome ;)"
;    - Confirms the spark correction approach works across platforms
;
; 4. HPA Academy Ghost Cam Webinar:
;    "Basically, you turn the controller into a really bad controller. LOL."
;    - The core insight: ghost cam = intentional PID instability
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
; VY V6 XDF ADDRESSES — CONFIRMED (v3 audit Feb 25, 2026)
;==============================================================================
;
; All addresses below confirmed present in v3 labeled ASM with correct
; equations and raw values. Verified by _check_ghost_cam_addrs.py.
;
; ── CALIBRATION ADDRESSES (BANK1) ────────────────────────────────────────
;
; $6523: RPM Filter Coefficient = 2560.0 COEFF | eq=X*256 | stock=$0A
;        *** CRITICAL: controls how fast ECU sees RPM changes.
;        Reduce for faster ghost cam response.
;
; $6524: IAC Spark Correction Lower Coolant Threshold = -40.0°C
;        eq=X/256*192-40 | stock=$00. Below this = no spark correction.
;
; $6525-$6526: KSARPMHI = 0.044 DEG%/RPM (2-byte)
;        eq=X/256/256*90 | stock=$0020
;        Spark correction gain for overspeed.
;        Ghost cam: $0075=0.16, $00C4=0.27 DEG%/RPM
;
; $6527-$6528: KSARPMLO = 0.044 DEG%/RPM (2-byte)
;        eq=X/256/256*90 | stock=$0020
;        Spark correction gain for underspeed. Match KSARPMHI.
;
; $6529-$652A: RPM Error Limit = 512.0 RPM (2-byte, straight RPM)
;        stock=$0200. Ghost cam: $00FA (250 RPM).
;
; $652B: KSCORLIM — Idle Spark Correction Limit = 5.27 DEG
;        eq=X/256*90 | stock=$0F
;        *** MAIN LIMITER. Stock 5° means ±5° max swing.
;        Ghost cam: $47=25°, $63=35°.
;
; $652C: Load Threshold For Closed Throttle Spark = 250.0 MG/CYL
;        eq=X*3.90625 | stock=$40
;
; $6536-$6540: Idle Spark Advance Vs Coolant (11x1 table)
;        eq=X/256*90-35 | stock warm=$AF (26.5°)
;
; $6541-$654B: Retarded Idle Spark Vs Coolant (11x1 table)
;        eq=X/256*90-35 | stock warm=$AF (26.5°)
;
; $654C-$6555: Idle Spark Multiplier Vs CYLAIR50 (1x11 table)
;        eq=X/128 | stock=$80 (1.0 = unity)
;
; ── CODE XREFS (BANK2) — idle spark calculation routine ──────────────────
;
;   $F835: CMPB $652C  — load vs closed throttle threshold
;   $F85D: CMPB $652C  — second load check
;   $F8D2: CMPA $6524  — coolant vs IAC spark threshold
;   $F8D7: LDD  $6525  — *** load KSARPMHI (HOOK POINT A)
;   $F8E0: CPX  $6529  — RPM error vs limit
;   $F8E5: LDD  $6527  — load KSARPMLO
;   $F8F7: CMPA $652B  — correction vs KSCORLIM (HOOK POINT B)
;   $F8FC: LDAA $652B  — load KSCORLIM to clamp
;
;   HOOK POINT A ($F8D7): 3-byte LDD $6525 → replace with JSR patch
;     This intercepts where the ECU loads the spark correction multiplier.
;     Our patch can compute a ghost cam correction and return it in D.
;
;   HOOK POINT B ($F8F7): 3-byte CMPA $652B → replace with JSR patch
;     This intercepts the clamp comparison. Our patch can widen the
;     clamp dynamically or return a different KSCORLIM value.
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP — VERIFIED RAM ADDRESSES
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; Engine RPM high byte (×25 scaling, 94 refs)
                                    ; RPM = value × 25. So $24 = 900 RPM.
ECT_ADDR            EQU $00B4       ; Engine Coolant Temperature (ADC reading)
TPS_ADDR            EQU $00B6       ; Throttle Position Sensor (ADC, 47 refs)

;------------------------------------------------------------------------------
; MEMORY MAP — SUSPECTED RAM (need disassembly confirmation)
;------------------------------------------------------------------------------
RPM_TARGET_IDLE     EQU $01A4       ; SUSPECTED: Target idle RPM (working copy)
SPARK_BASE          EQU $01B0       ; SUSPECTED → Verified: SPARK_BASE_ADV (5 refs)
SPARK_FINAL         EQU $01B2       ; SUSPECTED → Verified: SPARK_FINAL_ADV (2 refs)
ENGINE_STATE        EQU $01C0       ; SUSPECTED → Verified: ENGINE_STATE_WORD (4 refs)

;------------------------------------------------------------------------------
; PATCH LOCATION & HOOK POINTS (confirmed from bank2 disassembly)
;------------------------------------------------------------------------------
FREE_SPACE          EQU $C600       ; Free space for patch code (MUST VERIFY)
                                    ; Need ≈60 bytes clear ($C600-$C63F)
                                    ; Scan bank2 binary for $FF-filled runs.
;
; HOOK POINT A: $F8D7 in bank2  (LDD $6525 → 3 bytes: FC 65 25)
;   Replace with: JSR $C600  (BD C6 00 → also 3 bytes, perfect fit)
;   This is where KSARPMHI is loaded. Our routine can:
;   - Load KSARPMHI ourselves
;   - Compute ghost cam spark delta
;   - Return modified value in D register
;   - Original behavior restored by loading $6525 ourselves in the patch
;
; HOOK POINT B: $F8F7 in bank2  (CMPA $652B → 3 bytes: B1 65 2B)
;   Replace with: JSR $C620  (BD C6 20)
;   This is the KSCORLIM clamp. Our routine can:
;   - Widen the clamp for ghost cam mode
;   - Do the CMPA ourselves with a larger limit and RTS
;   - The flags from CMPA are preserved through RTS

;------------------------------------------------------------------------------
; CONFIGURATION — GHOST CAM PARAMETERS
;------------------------------------------------------------------------------
; These define the ghost cam behavior. Tunable in the binary.
; Based on BMW MS42 (-27° to +19°) and HPTuners LS (-15° to +30°) research.

SPARK_RETARD_MAX    EQU $E0         ; -32° maximum retard (when underspeed)
SPARK_ADVANCE_MAX   EQU $1E         ; +30° maximum advance (when overspeed)
RPM_DEADBAND        EQU $14         ; ±20 RPM deadband (±500 RPM real)
                                    ; No correction within this window
COOLANT_ENABLE      EQU $3C         ; 60°C minimum coolant for ghost cam
                                    ; Keeps normal idle below operating temp

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
                    ; A contains signed RPM delta (÷25 units)
                    ; Range: approx -16 to +16 (i.e. -400 to +400 RPM)
                    ; Table has 11 entries indexed 0-10
                    ; Map: delta(-16) → index 0,  delta(0) → index 5,  delta(+16) → index 10
                    ;
                    ; Algorithm: index = (delta + 16) / 3
                    ;   -16+16=0  /3=0   ✓  (maps to -400 RPM entry)
                    ;    0+16=16  /3=5   ✓  (maps to  0 RPM entry)
                    ;   +16+16=32 /3=10  ✓  (maps to +400 RPM entry)

                    ADDA    #$10                ; shift to 0-32 range (unsigned)
                    ; Clamp to prevent table overrun
                    BPL     .not_neg
                    CLRA                        ; clamp below to 0
.not_neg:
                    CMPA    #$20                ; > 32?
                    BLS     .not_over
                    LDAA    #$20                ; clamp above to 32
.not_over:
                    ; Divide by 3: approximate with (A * 85) >> 8
                    ; Simpler on HC11: just use a small division loop
                    TAB                         ; B = A (save shifted delta)
                    CLRA                        ; A = quotient
.div3:
                    CMPB    #$03
                    BLO     .div3_done
                    INCA
                    SUBB    #$03
                    BRA     .div3
.div3_done:
                    ; A = table index (0-10)
                    CMPA    #$0A                ; clamp to max index 10
                    BLS     .idx_ok
                    LDAA    #$0A
.idx_ok:
                    TAB                         ; B = index (for ABX)
                    LDX     #GHOST_CAM_TABLE    ; load table base address
                    ABX                         ; X = X + B (index into table)
                    LDAA    0,X                 ; load spark correction (signed)

;------------------------------------------------------------------------------
; Step 6: Apply correction to base spark and clamp
;------------------------------------------------------------------------------
                    ADDA    SPARK_BASE          ; add correction to base advance
                    
                    ; Clamp to safe limits (CRITICAL — prevents engine damage)
                    CMPA    #$28                ; max +40° advance
                    BLE     .check_min          ; signed compare
                    LDAA    #$28                ; clamp to +40°
                    BRA     .store_spark

.check_min:
                    CMPA    #$F0                ; min -16° retard (signed: $F0 = -16)
                    BGE     .store_spark        ; signed compare
                    LDAA    #$F0                ; clamp to -16°

.store_spark:
                    STAA    SPARK_FINAL         ; store final spark value
                    RTS                         ; return to caller

;------------------------------------------------------------------------------
; Exit — engine too cold, not at idle, or within deadband
; Execute the ORIGINAL instruction that was replaced by the JSR hook
;------------------------------------------------------------------------------
.exit_no_ghost:
                    ; Execute the original instruction we replaced with JSR.
                    ; HOOK A replaced: LDD $6525 (FC 65 25) at $F8D7
                    ; So we execute it here to preserve stock behavior:
                    LDD     $6525               ; original: load KSARPMHI
                    RTS                         ; return to $F8DA (next instr)

;------------------------------------------------------------------------------
; RAM Variables for this patch
;------------------------------------------------------------------------------
RPM_DELTA           EQU $0201       ; RAM: Calculated RPM delta (signed)

;==============================================================================
; RESEARCH STATUS — NEXT STEPS (updated Feb 25, 2026)
;==============================================================================
;
; 1. FIND IDLE SPARK CALCULATION ROUTINE
;    STATUS: ✅ DONE. Found in BANK2 at $F835-$F8FC.
;    All xrefs to $6524/$6525/$6527/$6529/$652B confirmed in v3 labeled ASM.
;    The routine reads KSARPMHI at $F8D7, KSARPMLO at $F8E5, clamps at $F8F7.
;
; 2. IDENTIFY THE HOOK POINT
;    STATUS: ✅ DONE. Two candidate hooks identified:
;    HOOK A: $F8D7 (LDD $6525 → FC 65 25 → 3 bytes → JSR $C600)
;    HOOK B: $F8F7 (CMPA $652B → B1 65 2B → 3 bytes → JSR $C620)
;    Both are exact 3-byte replacements, no alignment issues.
;
; 3. VERIFY RPM_TARGET_IDLE ADDRESS
;    STATUS: ⚠️ TODO. Search bank2 disassembly for code loading from
;    idle RPM cal tables and trace to RAM working copy.
;
; 4. FIND FREE ROM SPACE IN BANK2
;    STATUS: ⚠️ TODO. The hook is in bank2 ($F8D7), so the patch must
;    also be in bank2 ($8000-$FFFF range). Scan for $FF-filled runs.
;    Need ≈60 bytes for the ghost cam routine + lookup table.
;    Common gap locations: end-of-bank padding before $FFD0 vectors.
;
; 5. FIND FREE RAM
;    STATUS: ⚠️ TODO. Need 2-3 bytes for:
;    - RPM_DELTA ($0201 suspected)
;    - Ghost cam state/counter (1 byte)
;    Check labeled disassembly for unused RAM in $01E0-$01FF.
;
; 6. FUEL COMPENSATION
;    STATUS: ✅ LIKELY NOT NEEDED. Can be handled via XDF O/L idle fuel.
;
; 7. P/N vs DRIVE MODE
;    STATUS: ⚠️ TODO. Need GEAR_STATE or PRNDL flag address in RAM.
;
; 8. PORTABILITY
;    STATUS: Notes only. VX/VY/L67 use same code structure.
;    Memcal Ecotecs have same PID concept, different CPU/addresses.
;
;==============================================================================
; END OF FILE
;==============================================================================
