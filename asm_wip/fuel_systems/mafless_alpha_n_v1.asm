; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !! CROSS-BANK BUG (2026-02-13): This file places code at ORG $C468+ !!
; !! (bank 1 free space). The hook at file 0x101E1 (STD $017B) is in  !!
; !! bank 2 (0x10000-0x17FFF). JSR $C500 from bank 2 hits file        !!
; !! 0x1C500 (LIVE TRANS CODE), NOT 0x0C500 (our patch).               !!
; !! FIX: Relocate to common area $5D05 (always visible, 504 bytes    !!
; !! free) or bank 2 free space at file 0x17EA2 (286 bytes).           !!
; !! See custom_ose_$060_445_plan.md section 3.1a/3.1b for details.   !!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;;==============================================================================
; VY V6 MAFLESS ALPHA-N CONVERSION v1 - FORCE MAF FAILURE MODE
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 13, 2026 (Updated February 3, 2026)
; Method: Force MAF sensor failure to enable fallback Alpha-N mode
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: EXPERIMENTAL - Requires extensive dyno tuning after implementation
; ⚠️ This will trigger MAF failure DTC (Code M32) - expected behavior
;
;==============================================================================
; ALPINA "ZERO COMPLEX, TUNE SIMPLE" - VERIFIED DATA
;==============================================================================
;
; BINARY COMPARISON (February 3, 2026):
;   Stock M52TUB25 EU3 RHD:   7 zero tables (normal)
;   Alpina B3 3.3L Stroker: 34 zero tables (27 intentionally zeroed!)
;
; 🏁 ALPINA STRATEGY: Zero complex interacting tables, tune fallback tables
;
; ALPINA ZEROED (key categories):
;   ❌ ip_maf_vo_1, vo_3-vo_8 = ALL ZEROS (7 of 8 VANOS VE tables)
;   ❌ ip_iga_ron_91, ip_iga_ron_98 = ALL ZEROS (fuel grade timing)
;   ❌ ip_ti_tco_1/tco_2 tables = ALL ZEROS (temp timing corrections)
;   ❌ ip_iga_optm/cor tables = ALL ZEROS (ignition corrections)
;   ❌ Plus 15 more tables (see MAFLESS_VARIANTS_COMPARISON.md)
;
; ALPINA KEPT ACTIVE:
;   ✅ ip_maf_1_diag__n__tps_av = PRIMARY airflow (TPS × RPM Alpha-N)
;   ✅ ip_iga_knk_diag = PRIMARY timing (knock fallback)
;   ✅ ip_maf_vo_2 = SINGLE VE table (mid-cam position)
;
; WHY: Modified engine needs recalibration. Instead of 50+ tables → 3-5 tables.
;      Force ECU to use simpler fallback path = faster, predictable tuning.
;
;==============================================================================
;
; Description:
;   Converts MAF-based fuel system to Alpha-N (TPS+RPM) by forcing MAF
;   sensor failure mode. ECU will use fallback "Minimum Airflow For Default Air"
;   table and TPS-based fuel calculations instead of MAF sensor readings.
;
; Why MAFless?
;   - MAF sensor limits power (maxes out at ~450 g/s)
;   - Alpha-N better for high-lift cams (rough idle breaks MAF)
;   - ITB (Individual Throttle Bodies) conversions require Alpha-N
;   - Turbo/supercharger with BOV causes MAF false readings
;   - Simpler, more predictable fuel delivery
;
; How It Works:
;   1. Set $56F3 bit 6 = 1 (enable M32 fallback ACTION)
;   2. Disconnect MAF sensor (or set DTC mask at $56D4)
;   3. ECU detects MAF failure, switches to fallback mode
;   4. Uses "Default Airflow Table" at $7F2A (TPS × RPM)
;   5. Tune fallback table to match actual engine airflow
;
; XDF Evidence (VERIFIED February 2026):
;   - 0x56D4: KKMASK4 - M32 DTC ENABLE mask (bit 6=1 logs DTCs, stock=0xCC)
;   - 0x56DE: Check Trans Light mask (bit 6=1 lights CEL on M32)
;   - 0x56F3: KKACT3 - M32 ACTION mask (bit 6=1 enables fallback!) ← KEY!
;   - 0x577C: Hot Open Loop disable on M32 (set to 0x00 to keep HOL)
;   - 0x577D: Accel Enrichment disable on M32 (set to 0x00 to keep AE)
;   - 0x7F1B: "Minimum Airflow For Default Air" = 3.5 g/s (16-bit, stock=0x01C0)
;   - 0x7F2A: "Default Airflow Table" (7×5, TPS × RPM, 35 bytes)
;   - 0x6D1D: "Maximum Airflow Vs RPM" (17-element)
;
; ⚠️ KEY INSIGHT:
;   - Stock $56F3 = 0x00 (bit 6 CLEAR) = NO ACTION on MAF fail!
;   - Setting $56F3 = 0x40 (bit 6 SET) ENABLES the fallback path
;   - This is the PRIMARY patch for Alpha-N operation
;
; Tuning Requirements After Patch:
;   1. Set $56F3 = 0x40 (enable M32 action)
;   2. Set $56D4 = 0x8C (disable M32 DTC logging - cosmetic)
;   3. Set $577C = 0x00, $577D = 0x00 (keep enrichments active)
;   4. Disconnect MAF sensor
;   5. Tune "Default Airflow Table" at $7F2A on dyno
;   6. Note: Table limited to 0-50% TPS, 0-4800 RPM (see v4 for expansion)
;
; Implementation Status: 🔬 EXPERIMENTAL - Requires dyno validation
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP (CORRECTED January 25, 2026 from 92118883_STOCK.bin)
;------------------------------------------------------------------------------
; DTC Mask Bytes (ROM calibration data, not runtime flags!)
M32_DTC_ENABLE      EQU $56D4   ; KKMASK4 bit 6 = M32 DTC logging (stock=0xCC)
M32_CEL_MASK        EQU $56DE   ; Check Trans Light bit 6 = M32 CEL (stock=0xC0)
M32_ACTION_MASK     EQU $56F3   ; KKACT3 bit 6 = M32 action enable (stock=0x00) ← KEY!
MAF_OPTION_WORD     EQU $5795   ; Option word, multiple bits (stock=0xFC)

; Fallback Fuel Tables
MIN_AIRFLOW_CAL     EQU $7F1B   ; Minimum Airflow For Default Air (16-bit, stock=0x01C0 = 3.5 g/s)
MAX_AIRFLOW_TABLE   EQU $6D1D   ; Maximum Airflow Vs RPM table address

;------------------------------------------------------------------------------
; ROM CONSTANTS TO PATCH (Binary Hex Editor or TunerPro)
;------------------------------------------------------------------------------
; These must be patched in the binary file for MAFless operation:
;
; Address   | Original | Patched | Description
; ----------|----------|---------|----------------------------------------------
; 0x56D4    | 0xCC     | 0x8C    | Disable M32 DTC logging (clear bit 6)
; 0x56F3    | 0x00     | 0x40    | Enable M32 fallback ACTION (set bit 6) ← KEY!
; 0x577C    | 0x01     | 0x00    | Keep Hot Open Loop enabled during M32
; 0x577D    | 0x01     | 0x00    | Keep Accel Enrichment enabled during M32
;
; HARDWARE: Disconnect MAF sensor (or ground signal wire)
;
; *** FEBRUARY 2026 DISCOVERY ***
; The fallback table at $7F2A is LIMITED: 7×5 (0-50% TPS, 0-4800 RPM only!)
; Output goes to RAM $0128 (CYLAIR) - same variable as MAF path.
; For full WOT and high RPM coverage, see mafless_alpha_v4.asm table relocation.
;
;------------------------------------------------------------------------------
; ASSEMBLY CODE SECTION
;------------------------------------------------------------------------------
            ; CODE SECTION - ALPHA-N TPS-BASED CONVERSION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $C468          ; Free space VERIFIED (was $18156 WRONG!) ; FIXED: $14468 is a FILE OFFSET, not CPU addr. CPU=$C468 bank 2 (file 0x14468) [Enhanced-fix]

;==============================================================================
; MAF FAILURE FORCE ROUTINE
;==============================================================================
; This routine is called during ECU initialization to ensure MAF failure
; mode is ALWAYS active, even if the MAF sensor is physically present.
;
; Entry: None (called at startup)
; Exit:  MAF_FAILURE_FLAG = 1 (forced failure state)
;        MAF_BYPASS_FLAG = 1 (bypass filtering)
;
; Stack usage: 1 byte (LDAA)
;==============================================================================

FORCE_MAF_FAILURE:
    LDAA #$01                   ; A = 1 (failure state)
    STAA MAF_FAILURE_FLAG       ; Force M32 MAF Failure = 1
    STAA MAF_BYPASS_FLAG        ; Bypass MAF filtering = 1
    RTS                         ; Return to caller

;==============================================================================
; MAF READ OVERRIDE ROUTINE
;==============================================================================
; This routine intercepts MAF sensor reads and returns a fixed "safe" value
; to prevent ECU from clearing the failure flag if sensor is still connected.
;
; Entry: None (called when ECU tries to read MAF Hz)
; Exit:  D register = 0x0000 (0 Hz = sensor disconnected)
;
; Stack usage: 0 bytes (LDD immediate)
;==============================================================================

MAF_READ_OVERRIDE:
    LDD  #$0000                 ; D = 0 Hz (simulate disconnected sensor)
    RTS                         ; Return with fake MAF reading

;==============================================================================
; AIRFLOW CALCULATION OVERRIDE (OPTIONAL - FOR ADVANCED USERS)
;==============================================================================
; This routine replaces the stock airflow calculation with a simple
; TPS-based approximation. Use this if "Maximum Airflow Vs RPM" table
; doesn't provide enough resolution.
;
; Entry: B = TPS% (0-100)
;        A = RPM high byte
; Exit:  D = Calculated airflow in g/s
;
; Formula: Airflow = (TPS% × RPM × 0.002) + Min_Airflow
;          Example: 50% TPS @ 3000 RPM = (50 × 3000 × 0.002) + 20 = 320 g/s
;
; Stack usage: 6 bytes (PSHA, PSHB, math operations)
;==============================================================================

ALPHA_N_AIRFLOW_CALC:
    PSHA                        ; Save A (RPM high byte)
    PSHB                        ; Save B (TPS%)
    
    ; Load TPS% (0-255 where 255 = 100%)
    LDAB TPS_ADDR               ; B = TPS% (from RAM - address TBD)
    
    ; Load RPM/25 (8-BIT! $00A2 stores RPM/25, NOT 16-bit RPM!)
    ; ⚠️ WARNING: $00A3 = Engine State 2, NOT RPM low byte!
    LDAA RPM_ADDR               ; A = RPM/25 (actual RPM = A × 25)
    
    ; Multiply TPS × (RPM/25) (simplified - needs 8x8 multiply routine)
    ; This is a PLACEHOLDER - actual implementation requires:
    ;   1. 8-bit × 8-bit multiply (MUL instruction)
    ;   2. Scale result appropriately
    ;   3. Add minimum airflow base
    
    ; For now, use lookup table approach (recommended)
    ; JSR  LOOKUP_AIRFLOW_TABLE   ; Call table lookup instead
    
    PULB                        ; Restore B
    PULA                        ; Restore A
    RTS                         ; Return with calculated airflow in D

;==============================================================================
; LOOKUP TABLE APPROACH (RECOMMENDED FOR ALPHA-N)
;==============================================================================
; Instead of real-time calculation, use 2D table lookup:
;   X-axis: RPM (1000-7000 in 500 RPM steps = 13 columns)
;   Y-axis: TPS% (0-100% in 10% steps = 11 rows)
;   Z-data: Airflow in g/s
;
; This table should be added to ROM space and tuned on dyno.
; XDF entry: "Alpha-N Airflow Table (MAFless Mode)"
;==============================================================================
; BMW MS43 ALPHA-N REFERENCE TABLE (ip_maf_1_diag__n__tps_av)
;==============================================================================
; Source: MS43 Community Patchlist v2.9.2 with [PATCH] Alpha/N applied
; Binary: racemodes alpha n m52tub28_MS43_430069_512KB.bin (TUNED BY RACEMODE)
; Table Address: 0x7ABBA (512KB binary)
; Extracted: January 14, 2026
;
; ⚠️ IMPORTANT: This is a DYNO-TUNED table from Racemode (Poland)
;    The M52TUB25 went from 170hp stock to 235hp with:
;    - MS43 swap from MS42
;    - M54B30 intake manifold
;    - M54B30 injectors
;    - DBW (Drive-By-Wire) instead of CBW
;
; ⚠️ MS4X.NET WARNING about stock ip_maf_1_diag__n__tps_av:
;    "This table tends to run a bit lean from factory."
;    Stock values are ~10-15% LEANER than what's shown here! confirm this to a stock m54b30 export ms43 and ms42 exports of that table 
;
; BMW MS43 Alpha-N table uses mg/stk (milligrams per stroke) units
; VY V6 uses g/s (grams per second) for airflow
;
; CONVERSION FORMULA:
;   VY_g/s = MS43_mg/stk × RPM × 6_cylinders / 120000
;   Example: 302.4 mg/stk @ 2016 RPM = 302.4 × 2016 × 6 / 120000 = 30.5 g/s
;
;------------------------------------------------------------------------------
; BMW MS43 ALPHA-N TABLE (DYNO-TUNED VALUES FROM RACEMODE M52TUB25 BUILD)
;------------------------------------------------------------------------------
; X-Axis (TPS %): 0.000  2.499  5.001  7.500  9.999  12.501 15.000 17.499 20.001 24.000 28.000 32.000 36.000 39.999 50.001 69.999
; Y-Axis (RPM):   512    704    992    1248   1504   1728   2016   2528   3008   3296   4064   4512   4832   5600   6016   6400
;
; RACEMODE DYNO-TUNED Alpha-N Table (mg/stk) - ACTUAL VALUES FROM TUNERPRO SCREENSHOT:
; (Note: Stock BMW values are ~10-15% LEANER than these tuned values per MS4X.net warning)
;
;  RPM\TPS  0.000  2.499  5.001  7.500  9.999 12.501 15.000 17.499 20.001 24.000 28.000 32.000 36.000 39.999 50.001 69.999
;  ------  ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------ ------
;   512     74.3  138.0  212.2  329.0  403.3  456.3  477.6  482.9  482.9  488.2  488.2  488.2  488.2  488.2  488.2  560.0
;   704     70.0  138.0  222.8  275.9  329.0  376.7  413.9  429.8  440.4  451.0  461.6  466.9  466.9  466.9  466.9  560.0
;   992     47.7  138.0  217.5  281.2  329.0  376.7  413.9  440.4  456.3  472.2  482.9  493.5  498.8  498.8  498.8  560.0
;  1248     40.3  116.7  169.8  212.2  265.3  318.4  360.8  387.3  403.3  424.5  440.4  456.3  461.6  466.9  466.9  560.0
;  1504     36.1   95.5  153.9  201.6  254.7  307.8  360.8  398.0  440.4  477.6  509.4  514.7  514.7  514.7  560.0  560.0
;  1728     32.9   90.2  143.3  201.6  249.4  302.4  355.5  387.3  419.2  456.3  482.9  498.8  504.1  514.7  520.0  560.0
;  2016     31.8   79.6  127.4  175.1  222.8  265.3  302.4  339.6  376.7  419.2  445.7  466.9  477.6  488.2  498.8  560.0
;  2528     34.0   53.1  100.8  148.6  201.6  249.4  297.2  334.3  366.1  413.9  456.3  482.9  488.2  498.8  509.4  560.0
;  3008     29.7   42.4   84.9  127.4  169.8  212.2  260.0  307.8  360.8  408.6  451.0  482.2  504.1  520.0  541.2  560.0
;  3296     26.6   42.4   74.3  111.4  159.2  201.6  249.4  302.4  355.5  413.9  466.9  509.4  530.6  541.2  562.4  560.0
;  4064     26.6   37.1   63.7   95.5  132.7  180.4  233.5  286.5  329.0  403.3  440.4  472.2  498.8  520.0  541.2  560.0
;  4512     15.9   31.8   47.7   79.6  116.7  164.5  222.8  275.9  323.7  398.0  445.7  488.2  514.7  535.9  557.1  560.0
;  4832     15.9   29.7   47.7   79.6  116.7  153.9  212.2  260.0  307.8  382.0  445.7  482.9  509.4  535.9  551.8  560.0
;  5600     15.9   31.8   47.7   69.0  100.8  132.7  175.1  212.2  265.3  344.9  403.3  445.7  472.2  498.8  541.2  560.0
;  6016     15.9   26.6   40.3   58.4   84.9  116.7  159.2  206.9  249.4  323.7  382.0  435.1  472.2  504.1  541.2  560.0
;  6400     15.9   26.6   37.1   53.1   84.9  116.7  153.9  196.3  238.8  307.8  371.4  408.6  435.1  461.6  493.5  560.0
;
;------------------------------------------------------------------------------
; VY V6 ALPHA-N TABLE (CONVERTED FROM BMW MS43 VALUES)
;------------------------------------------------------------------------------
; Engine Comparison:
;   BMW M52TUB28: 2.8L I6, 193hp @ 5500 RPM, ~250 g/s max airflow  
;   Holden L36:   3.8L V6, 200hp @ 5200 RPM, ~275 g/s max airflow
;
; VY V6 has ~35% larger displacement, needs ~35% more airflow at same RPM
; VY V6 RPM range: 800-6200 (lower redline than BMW)
;
; SCALED VY V6 ALPHA-N TABLE (g/s) - STARTING POINT FOR DYNO TUNING:
;
;        RPM: 800  1200  1600  2000  2400  2800  3200  3600  4000  4400  4800  5200  5600  6000
; TPS%  0%:   3.0   3.5   4.0   4.5   5.0   5.5   6.0   6.0   6.0   5.5   5.0   4.5   4.0   3.5
;      10%:  25.0  35.0  50.0  65.0  80.0  95.0 110.0 120.0 125.0 125.0 120.0 110.0 100.0  90.0
;      20%:  45.0  65.0  90.0 115.0 140.0 165.0 185.0 200.0 210.0 215.0 210.0 200.0 185.0 170.0
;      30%:  65.0  95.0 130.0 165.0 200.0 230.0 255.0 275.0 290.0 295.0 290.0 280.0 265.0 245.0
;      40%:  85.0 125.0 170.0 215.0 260.0 295.0 325.0 350.0 365.0 370.0 365.0 355.0 340.0 315.0
;      50%: 105.0 155.0 210.0 265.0 320.0 360.0 395.0 420.0 440.0 445.0 440.0 425.0 405.0 380.0
;      60%: 125.0 185.0 250.0 315.0 375.0 420.0 460.0 490.0 510.0 515.0 510.0 490.0 465.0 440.0
;      70%: 145.0 215.0 290.0 365.0 430.0 480.0 520.0 555.0 575.0 580.0 575.0 555.0 525.0 495.0
;      80%: 165.0 245.0 330.0 415.0 485.0 540.0 580.0 615.0 640.0 645.0 640.0 615.0 580.0 545.0
;      90%: 185.0 275.0 370.0 465.0 540.0 600.0 645.0 680.0 705.0 710.0 700.0 670.0 635.0 595.0
;     100%: 205.0 305.0 410.0 515.0 595.0 660.0 705.0 745.0 770.0 775.0 765.0 730.0 690.0 645.0
;
; ⚠️ CRITICAL: These values are ESTIMATES based on BMW MS43 data!
;    Must dyno-tune for actual VY V6 engine breathing characteristics.
;    Start 10% RICH and lean out while watching AFR and knock!


; These values are SCALED from BMW MS43 Alpha-N data, adapted for VY V6!
; Must be dyno-tuned for your specific engine configuration.
;
;==============================================================================
; KEY OBSERVATIONS FROM BMW MS43 ALPHA-N TABLE
;==============================================================================
;
; 1. IDLE/LOW TPS (0-5%):
;    - BMW values: 15-75 mg/stk across all RPM
;    - Values DECREASE with higher RPM (engine pumping losses)
;    - VY V6 equivalent: 3-7 g/s at 0% TPS
;
; 2. MID-RANGE (20-50% TPS):
;    - BMW values: 200-500 mg/stk
;    - Peak efficiency zone, smooth curve
;    - VY V6 equivalent: ~100-450 g/s
;
; 3. HIGH RPM ROLL-OFF (Above 5000 RPM):
;    - BMW values DROP at high RPM, high TPS
;    - Engine breathing limits (VE decreases)
;    - VY V6 will show same pattern (max ~775 g/s @ 4400 RPM)
;
; 4. WOT COLUMN (70%+ TPS):
;    - BMW caps at 560 mg/stk (hardware limit M52TU)
;    - VY V6 with 162cc injectors: max ~775 g/s sustainable
;    - Turbo builds need larger injectors!
;
; 5. CRITICAL DIFFERENCE:
;    - BMW has smooth S-curve (efficient breathing)
;    - VY V6 may need different curve shape (port flow differences)
;    - Start with BMW shape, adjust based on AFR feedback
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; HOOK POINTS (Binary Patches Required)
;------------------------------------------------------------------------------
; To activate this code, replace existing MAF read routines with JSR calls:
;
; 1. Find MAF Hz read routine (search for: LDAA $xxxx, LDAB $xxxx pattern)
; 2. Replace with: JSR MAF_READ_OVERRIDE ; NOP ; NOP (if needed for alignment)
; 3. Find ECU init routine
; 4. Add: JSR FORCE_MAF_FAILURE at startup
;
; **WARNING:** These hook points are NOT yet identified in disassembly!
; Requires further binary analysis to locate exact addresses.

;==============================================================================
; IMPLEMENTATION NOTES
;==============================================================================
;
; Step 1: Binary Hex Patches (BEFORE assembling this code)
; --------------------------------------------------------
; Use hex editor to patch:
;   0x7F1B: 23 → C8 (Min Airflow: 3.5 → 200 g/s)
;   0x56D4: 00 → 01 (Force MAF failure)
;   0x5795: 00 → 01 (Bypass MAF filtering)
;
; Step 2: Assemble and inject this code at 0x0C500 (engine bank free space)
; --------------------------------------------------------
; as11 mafless_alpha_n_conversion_v1.asm -o mafless_patch.s19
; (Use TunerPro or hex editor to inject S19 at 0x0C500)
;
; Step 3: Create XDF entries for Alpha-N table
; --------------------------------------------------------
; Add new 2D table in XDF:
;   Title: "Alpha-N Airflow Table (MAFless Mode)"
;   Address: (TBD - use free ROM space after 0x0C600)
;   X-axis: RPM (0-7000 in 13 steps)
;   Y-axis: TPS% (0-100 in 11 steps)
;   Z-data: Airflow g/s (uint8 or uint16)
;
; Step 4: Dyno tune the Alpha-N table
; --------------------------------------------------------
; 1. Start with conservative values (table above is baseline)
; 2. Datalog: RPM, TPS%, O2 voltage, knock count
; 3. Adjust table cells to hit target AFR (14.7:1 cruise, 12.5:1 WOT)
; 4. Iterate until AFR stable across entire RPM/TPS range
; 5. Road test and fine-tune for drivability
;
; Step 5: Disable MAF failure DTC (optional)
; --------------------------------------------------------
; If you don't want CEL/DTC M32:
;   Find DTC set routine for M32 (grep "56D4" in disassembly)
;   NOP out the "Set DTC" instruction
;   (This is cosmetic only - doesn't affect function)
;
;==============================================================================
; TUNING TIPS FOR ALPHA-N
;==============================================================================
;
; 1. Start Rich, Then Lean Out
;    - Initial values 10-15% richer than calculated
;    - Prevents lean-out damage during tuning
;    - Use wideband O2 to verify actual AFR
;
; 2. Idle Must Be Perfect First
;    - 0% TPS cells (idle) are most critical
;    - Should hit 14.7:1 AFR at all idle RPMs
;    - If idle hunts, increase values slightly
;
; 3. WOT Tuning Is Easiest
;    - 100% TPS row should hit 12.5:1 AFR (NA) or 11.5:1 (turbo)
;    - Use dyno pulls to validate power curve
;    - Watch for knock - retard timing if needed
;
; 4. Part-Throttle Is Hardest
;    - 10-50% TPS range most sensitive to tuning
;    - Small changes (±5 g/s) make big AFR differences
;    - Cruise AFR should be 14.7:1 for fuel economy
;
; 5. Closed-Loop O2 Still Works!
;    - Don't disable O2 feedback (STFT/LTFT)
;    - Let ECU trim your base table automatically
;    - Monitor LTFT - if >±5%, retune base table
;
; 6. TPS Calibration Is Critical
;    - 0% TPS = throttle fully closed (idle)
;    - 100% TPS = throttle wide open (WOT)
;    - If TPS out of range, Alpha-N will be wrong!
;
;==============================================================================
; ADVANTAGES OF ALPHA-N OVER MAF
;==============================================================================
;
; ✅ Unlimited power potential (no MAF sensor limit)
; ✅ Better for high-lift cams (lumpy idle doesn't confuse ECU)
; ✅ Allows ITB (Individual Throttle Bodies) conversion
; ✅ Eliminates MAF sensor failure point
; ✅ Simpler, more predictable fuel delivery
; ✅ Easier to tune for forced induction (turbo/supercharger)
; ✅ No BOV/BPV issues (MAF reads backwards airflow as false load)
;
;==============================================================================
; DISADVANTAGES OF ALPHA-N
;==============================================================================
;
; ❌ Requires extensive dyno tuning (10-20 hours)
; ❌ Less accurate than MAF at part-throttle
; ❌ Drivability can suffer if poorly tuned
; ❌ Must retune if engine mods change VE (cam, heads, exhaust)
; ❌ Altitude compensation less effective
; ❌ Cold start enrichment needs manual tuning
; ❌ MAF failure DTC always present (can be disabled)
;
;==============================================================================
; COMPATIBILITY WITH OTHER PATCHES
;==============================================================================
;
; ✅ Works with ignition cut rev limiter patches
; ✅ Works with timing advance mods
; ✅ Works with boost control patches (turbo/supercharger)
; ⚠️  May conflict with MAF-based anti-lag (delete anti-lag code)
; ⚠️  May conflict with MAF Hz-based fuel cut logic (already disabled in Enhanced OS)
;
;==============================================================================

; END OF MAFless Alpha-N Conversion v1
; Total code size: ~50 bytes (fits in ~15KB free space @ 0x0C468-0x0FFBF)
; Additional ROM space needed: ~143 bytes for Alpha-N lookup table
; Total ROM usage: ~193 bytes

; Next Steps:
; 1. Locate MAF read routine in disassembly (grep "LDAA.*102F" or similar)
; 2. Locate ECU init routine (search for reset vector @ 0xFFFE)
; 3. Test on bench with Ostrich 2.0 (if available)
; 4. Dyno tune Alpha-N table (mandatory before vehicle use)
; 5. Document final results for community

; Implementation Status: 🔬 EXPERIMENTAL
; Chr0m3 Approval: ❓ NOT YET VALIDATED - Requires expert review
