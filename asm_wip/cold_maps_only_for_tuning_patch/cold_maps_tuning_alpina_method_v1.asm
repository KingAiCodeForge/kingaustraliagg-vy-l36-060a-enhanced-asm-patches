;==============================================================================
; VY V6 COLD MAPS ONLY TUNING PATCH v1 - ALPINA/OEM METHOD
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026 (Updated January 25, 2026)
; Status: 📋 CONCEPT/OVERVIEW DOCUMENT - See separate patches below
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
;==============================================================================
; ⭐ THIS FILE IS NOW A CONCEPT/OVERVIEW DOCUMENT
;==============================================================================
;
; The actual patches have been split into separate files:
;
; 1. cold_maps_force_cold_spark_v1.asm
;    - Forces cold spark compensation at ALL temperatures
;    - 4-byte binary patch (0x64D1-0x64D4) + optional ASM routine
;    - XDF-only method possible (no ASM needed)
;    - Simplifies spark tuning
;
; 2. alpina_mafless_fallback_v1.asm
;    - Forces MAF failure fallback mode (Alpha-N)
;    - Binary patches at 0x56D4, 0x5795, 0x7F1B
;    - For big cams, ITBs, turbo with BOV
;    - Requires tuning "Maximum Airflow Vs RPM" table
;
; 3. VY_V6_COLD_MAPS_ONLY_XDF_PATCH.md
;    - Documentation for XDF-only cold maps method
;    - No ASM or code injection required
;    - TunerPro-based tuning workflow
;
;==============================================================================
; THE ALPINA METHOD: "ZERO THE COMPLEX, TUNE THE SIMPLE"
;==============================================================================
; Key Discovery from Alpina B3 3.3L Stroker (M52TUB33) vs Stock M52TUB28:
;
; Problem: Stock ECU has 50+ interacting tables
;   - Changing one affects others
;   - Tuning takes weeks of dyno time
;   - Unpredictable interactions
;
;==============================================================================
; MS4X WIKI RESEARCH (January 2026)
;==============================================================================
;
; From ms4x.net/index.php?title=Siemens_MS43:
;
; BMW MS43 ECU has TWO separate sets of maps for COLD and WARM engine:
;
; COLD ENGINE (tco_1) - Used when coolant temp below threshold:
;   - ip_ti_tco_1_is_ivvt__n__maf   = Cold engine INJECTION TIME at idle
;   - ip_ti_tco_1_pl_ivvt_1__n__maf = Cold engine injection time bank 1 part load
;   - ip_ti_tco_1_pl_ivvt_2__n__maf = Cold engine injection time bank 2 part load
;   - ip_iga_tco_1_is_ivvt__n__maf  = Cold engine IGNITION at idle
;   - ip_iga_tco_1_pl_ivvt__n__maf  = Cold engine ignition part/full load
;
; WARM ENGINE (tco_2 / ron_9x) - Used when at operating temperature:
;   - ip_iga_tco_2_is_ivvt__n__maf  = Warm engine IGNITION at idle
;   - ip_iga_ron_91_pl_ivvt__n__maf = RON91 fuel ignition part load
;   - ip_iga_ron_98_pl_ivvt__n__maf = RON98 fuel ignition part load
;
; "COLD MAPS ONLY" TUNING METHOD:
;   - Zero out or ignore the warm (tco_2/ron_9x) tables
;   - Tune the cold (tco_1) tables for your modified engine
;   - Force ECU to never transition to warm maps
;   - Result: Single predictable calculation path
;   - fuel trims remain active. and level it out when warm if to rich once closed loop and o2 are warm, if you have cats and there blocked cold start enrichment fixs temporarily the STARTUP misfire you get till it works out the o2 banks are to lean or rich and broken throwing faults. till you replace or gut cats.
;==============================================================================
; ALPINA/OEM IMPLEMENTATION (verified from binary comparison)
;==============================================================================
;
; Zero the warm maps, tune the cold maps:
;   - Cold/diagnostic maps are designed robust and conservative
;   - Force ECU to use simplified calculation path
;   - Tune 3-5 tables instead of 50+
;
; ALPINA ZEROED THESE (BMW MS42):
;   ❌ ip_iga_ron_98_pl_ivvt = ALL ZEROS (no RON98 timing)
;   ❌ ip_iga_ron_91_pl_ivvt = ALL ZEROS (no RON91 timing)
;   ❌ ip_iga_tco_2_is_ivvt  = ALL ZEROS (no warm temp timing)
;   ❌ ip_maf_vo_1 to vo_7   = ALL ZEROS (7 of 8 VANOS VE tables)
;
; ALPINA TUNED THESE (kept active):
;   ✅ ip_maf_1_diag__n__tps_av = PRIMARY airflow (tuned for 3.3L)
;   ✅ ip_iga_knk_diag          = PRIMARY timing (knock fallback)
;   ✅ ip_maf_vo_2              = ONLY VE table used (mid-cam)
;
;==============================================================================
; VY V6 EQUIVALENT STRATEGY
;==============================================================================
;
; The VY V6 has similar warm/cold table structure:
;
; WARM TABLES (stock tuned for factory engine):
;   - Main Spark vs RPM vs MGC (complex 3D table)
;   - Main VE vs RPM vs MAP (complex 3D table)
;   - Various correction tables (IAT, ECT, baro, etc.)
;
; COLD TABLES (conservative fallback):
;   - MAIN SPARK COLD LOAD CORRECTION VS RPM VS MGC
;   - MAIN SPARK COLD LOAD MULTIPLIER VS ECT
;   - CRANKING PULSEWIDTH VS ENGINE TEMP
;   - OPEN LOOP IDLE AFR VS ENGINE TEMP
;
; STRATEGY: Force ECU to think it's always "cold"
;   - Zero warm correction multipliers
;   - Tune cold tables for your modified engine
;   - Result: Predictable, single-path tuning
;
;==============================================================================
; VY V6 XDF ADDRESSES (from ghost_lumpy_idle_cam_asm.md research)
;==============================================================================
;
; COLD START FUEL TABLES:
;   Line 3022: CRANKING PULSEWIDTH VS ENGINE TEMP
;   Line 3088: OPEN LOOP IDLE AFR VS ENGINE TEMP
;   Line 3145: OPEN LOOP AFR VS MGC VS RPM (warmup cruise)
;   Line 2951: DESIRED IDLE AIR RATE VS ECT - START UP
;
; COLD SPARK TABLES:
;   Line 1255: MAIN SPARK COLD LOAD CORRECTION VS RPM VS MGC
;   Line 1318: MAIN SPARK COLD LOAD MULTIPLIER VS ECT
;
; CONTROL FLAGS:
;   0x752C: STFT ENABLE COOLANT TEMP-STARTUP (delay closed-loop)
;   0x7635: LTFT ENABLE LOWER COOLANT TEMP (delay learning)
;
;==============================================================================
; IMPLEMENTATION OPTIONS
;==============================================================================

;------------------------------------------------------------------------------
; OPTION A: FORCE PERMANENT "COLD" MODE
;------------------------------------------------------------------------------
;
; Set ECT reading to always report cold temperature
; This forces all cold tables to remain active
;
; Method: Intercept ECT reading and clamp to cold value
;
; Pros:
;   - All cold compensation stays active
;   - Simple single-point modification
;
; Cons:
;   - Loses real ECT data for protection
;   - Fans won't work properly
;   - Not recommended for daily driver
;

; ECT clamp patch - forces ECU to think engine is always cold
ECT_ADDR            EQU $00B4       ; Engine Coolant Temperature RAM
ECT_FAKE_COLD       EQU $40         ; 64 = ~20°C (forces cold tables active)

; This would require hooking the ECT read routine
; NOT RECOMMENDED - breaks thermal protection

;------------------------------------------------------------------------------
; OPTION B: ZERO WARM CORRECTION MULTIPLIERS (ALPINA METHOD)
;------------------------------------------------------------------------------
;
; Set the warm-side multipliers to 1.0 so cold corrections always apply
; Cold tables remain active even when engine is warm
;
; Target: MAIN SPARK COLD LOAD MULTIPLIER VS ECT @ $64CF (6 bytes)
;
; Stock table (VERIFIED from VX-VY_V6_$060A_Enhanced_v1.0a.bin January 25, 2026):
;   Coolant:   -40°C  -16°C    8°C   32°C   56°C   80°C
;   Raw:        0xFF   0xFF   0xFF   0xAB   0x55   0x00
;   Multiplier: 1.00   1.00   1.00   0.67   0.33   0.00
;
; Modified (keep cold active at ALL temps):
;   Coolant:   -40°C  -16°C    8°C   32°C   56°C   80°C
;   Raw:        0xFF   0xFF   0xFF   0xFF   0xFF   0xFF
;   Multiplier: 1.00   1.00   1.00   1.00   1.00   1.00
;                                    ^^^^   ^^^^   ^^^^
;                           Changed from 0xAB, 0x55, 0x00
;
; Result: Cold spark correction always applies 100% even when hot
;
; Binary patch (only 3 bytes change):
;   0x64D2: AB → FF (32°C multiplier)
;   0x64D3: 55 → FF (56°C multiplier)
;   0x64D4: 00 → FF (80°C multiplier) ← MOST IMPORTANT!
;

COLD_SPARK_MULT_TABLE   EQU $64CF   ; VERIFIED address (6-byte table)

;------------------------------------------------------------------------------
; OPTION C: EXTEND CLOSED-LOOP DISABLE TEMPERATURE
;------------------------------------------------------------------------------
;
; Keep fuel trims disabled until much higher temperature
; Forces open-loop (table-based) fuel longer
;
; 0x752C: STFT ENABLE COOLANT TEMP-STARTUP
;   Stock: 40-60°C (STFT kicks in once warm)
;   Tuning: 100°C+ (STFT never kicks in, OL forever)
;
; 0x7635: LTFT ENABLE LOWER COOLANT TEMP
;   Stock: 60-70°C (learning starts warm)
;   Tuning: 100°C+ (learning disabled)
;
; Pros:
;   - Open-loop = direct table control
;   - No trim corrections fighting your tune
;   - Easier to dial in exact AFR
;
; Cons:
;   - No automatic correction for wear/altitude
;   - Requires accurate tune from start
;   - alpha n is used to make this even easier
; sometimes combined with cold maps only patch and then cold start enrichment to get the perfect start first shot with no misfires at the price of blowing a puff of black smoke instead when it first starts.
;==============================================================================
STFT_ENABLE_ECT     EQU $752C       ; STFT enable coolant temp
STFT_STOCK          EQU $A0         ; 0xA0 = 90°C (formula: (X-40)/256*192)
STFT_TUNING         EQU $D0         ; 0xD0 ≈ 113°C (never enables)

LTFT_ENABLE_ECT     EQU $7635       ; LTFT enable coolant temp  
LTFT_STOCK          EQU $50         ; 0x50 = 20°C (formula: X/256*192-40)
LTFT_TUNING         EQU $D0         ; 0xD0 ≈ 120°C (never enables)
;
; VERIFIED from 92118883_STOCK.bin January 25, 2026

;==============================================================================
; COLD SPARK TABLE TUNING STRATEGY
;==============================================================================
;
; Once cold tables are forced active, tune them for your engine:
;
; MAIN SPARK COLD LOAD CORRECTION VS RPM VS MGC (Line 1255)
;   - Add degrees where you need more timing
;   - This is the PRIMARY timing table now
;
; Stock purpose: "MUST BE LESS THAN 80 DEG C" - only active when cold
; Tuned purpose: Primary timing table (with multiplier at 1.0 always)
;
; Example modification for bigger cam:
;   - Increase idle timing cells (+5°)
;   - Decrease high-load cells (-5°) for detonation margin
;
;==============================================================================
; COLD FUEL TABLE TUNING STRATEGY
;==============================================================================
;
; CRANKING PULSEWIDTH VS ENGINE TEMP (Line 3022)
;   - Increase for bigger injectors
;   - Increase for E85 (more fuel needed)
;   - BMW MS42 used +30% for ghost cam stability
;
; Stock (typical):
;   Coolant:    -40°C  -20°C   0°C   20°C   40°C   60°C   80°C  100°C
;   Crank PW:    12.0    9.5   7.0    5.5    4.0    3.0    2.5    2.0  (ms)
;
; Modified (+30%):
;   Coolant:    -40°C  -20°C   0°C   20°C   40°C   60°C   80°C  100°C
;   Crank PW:    15.6   12.4   9.1    7.2    5.2    3.9    3.3    2.6  (ms)
;
; OPEN LOOP IDLE AFR VS ENGINE TEMP (Line 3088)
;   - This becomes PRIMARY idle fueling when STFT disabled
;   - Tune to your target AFR (13.5-14.2 typical)
;
;==============================================================================
; HEX PATCH SUMMARY - OPTION C (SIMPLEST)
;==============================================================================
;
; These patches delay closed-loop fuel forever, forcing open-loop tuning:
;
; | Offset | Stock | Tuning | Parameter                          |
; |--------|-------|--------|-------------------------------------|
; | 0x752C | 0xA0  | 0xD0   | STFT Enable ECT (90°C → 113°C)      |
; | 0x7635 | 0x50  | 0xD0   | LTFT Enable ECT (20°C → 120°C)      |
;
; VERIFIED from 92118883_STOCK.bin January 25, 2026
;
; Then tune these tables via XDF:
;   - OPEN LOOP IDLE AFR VS ENGINE TEMP
;   - OPEN LOOP AFR VS MGC VS RPM
;   - CRANKING PULSEWIDTH VS ENGINE TEMP
;
;==============================================================================
; WHY THIS WORKS FOR MODIFIED ENGINES
;==============================================================================
;
; Stock VY V6 has trim corrections for:
;   - Altitude changes (baro)
;   - Aging sensors (MAF drift)
;   - Wear (injector flow changes)
;
; Modified engines break these assumptions:
;   - Bigger injectors = wrong trim learning
;   - Different cam = wrong airflow calculation
;   - Turbo/SC = MAF maxed out
;
; Solution: Disable trims, tune open-loop tables directly
;   - You KNOW your engine's characteristics
;   - No ECU "learning" fighting your tune
;   - Predictable behavior on dyno and street
;
;==============================================================================
; SAFETY CONSIDERATIONS
;==============================================================================
;
; ⚠️ Disabling fuel trims means:
;   - ECU won't compensate for vacuum leaks
;   - ECU won't compensate for altitude
;   - ECU won't compensate for worn sensors
;   - You MUST tune correctly or risk damage
; RECOMMENDED:
;   - Use wideband O2 for tuning verification
;   - Tune conservatively (slightly rich)
;   - Keep knock sensor active for protection
;   - Test thoroughly before street use
;
;==============================================================================
; END OF FILE
;==============================================================================
