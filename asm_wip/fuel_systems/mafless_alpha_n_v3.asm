;==============================================================================
; VY V6 MAFLESS ALPHA-N CONVERSION v3 - MINIMAL ROM FOOTPRINT
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 16, 2026
; Method: Force MAF sensor failure to enable fallback Alpha-N mode
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: EXPERIMENTAL - Requires extensive dyno tuning after implementation
; ⚠️ This will trigger MAF failure DTC (Code M32) - expected behavior
;
;==============================================================================
; OEM TUNING PHILOSOPHY (Alpina/BMW/Bosch-Siemens Analysis)
;==============================================================================
;
; 🏁 "ZERO THE COMPLEX, TUNE THE SIMPLE" - Professional OEM Approach
;
; Key Discovery from Alpina B3 3.3L Stroker (M52TUB33) vs Stock M52TUB28:
;
; ALPINA ZEROED THESE TABLES:
;   ❌ ip_iga_ron_98_pl_ivvt = ALL ZEROS (no RON98 timing)
;   ❌ ip_iga_ron_91_pl_ivvt = ALL ZEROS (no RON91 timing)
;   ❌ ip_iga_tco_2_is_ivvt  = ALL ZEROS (no temp timing)
;   ❌ ip_maf_vo_1 to vo_7   = ALL ZEROS (7 of 8 VANOS VE tables)
;
; ALPINA TUNED THESE FALLBACK TABLES:
;   ✅ ip_maf_1_diag__n__tps_av = PRIMARY airflow (tuned for 3.3L)
;   ✅ ip_iga_knk_diag          = PRIMARY timing
;   ✅ ip_maf_vo_2              = ONLY VE table used
;
; WHY THIS WORKS:
;   - Stock has 50+ interacting tables - changing one affects others
;   (by this the x and y is linked in the xdf for tunerpro, for some ms42 ger partial and full bins. (cal the holden community would call the partial) and eng and ms42 version.
;   vy v6 flashing uses padded to 128kb for the cal flash and read version. so it flashes just the cal not the full os like a full write does for both flash tools for both ecus.)
;   - Alpina zeros complex tables, leaving predictable fallback path
;   - Diagnostic/fallback systems are designed robust and conservative
;   - Tune 3-5 tables instead of 50+ = faster, more predictable
;
; VY V6 PARALLEL:
;   - Set $56D4 bit 6 = 1 (like Alpina zeroing RON tables)
;   - ECU enters MAF failure fallback mode
;   - Tune $7F1B "Minimum Airflow For Default Air" or inject TPS×RPM table
;   - Same philosophy, different platform!
;
;==============================================================================
;
; Description:
;   v3 focuses on MINIMAL CODE SIZE to maximize free ROM space for other patches.
;   Unlike v1/v2 (feature-rich), v3 is the bare minimum needed for Alpha-N.
;   Converts MAF-based fuel to Alpha-N (TPS+RPM) via MAF failure fallback.
;
; v3 Differences from v1/v2:
;   ✅ Smaller code footprint (~30 bytes vs ~50+ bytes)
;   ✅ No optional features (airflow override removed)
;   ✅ Simplified initialization (single-pass flag set)
;   ✅ Removed placeholder routines (cleaner binary injection)
;   ❌ Less flexible than v1/v2 (tuning via XDF tables only)
;
; Why MAFless Alpha-N?
;   - MAF sensor maxes out at ~450 g/s (limits high-power builds)
;   - Alpha-N handles high-lift cams (rough idle breaks MAF signal)
;   - ITB (Individual Throttle Bodies) require Alpha-N
;   - Turbo/supercharger BOV causes MAF false readings
;   - Eliminates intake restriction from MAF housing
;
; How It Works:
;   1. Set "M32 MAF Failure" flag at 0x56D4 = 1 (force failure state)
;   2. Set "BYPASS MAF FILTERING" at 0x5795 = 1 (skip MAF logic)
;   3. ECU enters fallback mode using "Maximum Airflow Vs RPM" table
;   4. Tune XDF tables to match actual engine airflow
;
; XDF Addresses (CORRECTED January 25, 2026 - verified against 92118883_STOCK.bin):
;
;   ⚠️ CRITICAL CORRECTION: These are DTC MASK BYTES, not runtime flags!
;
;   - 0x56D4: KKMASK4 - DTC ENABLE mask, bit 6 = M32 logging (stock=0xCC)
;   - 0x56DE: Check Trans Light mask, bit 6 = M32 CEL (stock=0xC0)
;   - 0x56F3: KKACT3 - ACTION mask, bit 6 = M32 fallback action (stock=0x00) ← KEY!
;   - 0x5795: Option word, multiple bits (stock=0xFC)
;   - 0x7F1B: "Minimum Airflow For Default Air" (16-bit BE, stock=0x01C0 = 3.5 g/s)
;   - 0x6D1D: "Maximum Airflow Vs RPM" table (17 elements)
;
;   ⚠️ KEY FINDING: Stock has 0x56F3 bit 6 = 0, meaning NO ACTION taken on M32!
;      To enable MAFless fallback, you MUST set 0x56F3 bit 6 = 1 (value 0x40)!
;
; Tuning Requirements After Patch:
;   1. Increase "Minimum Airflow For Default Air" from 3.5 to ~150-200 g/s
;   2. Tune "Maximum Airflow Vs RPM" table (VE substitute, 17 columns)
;   3. Adjust "Power Enrichment Enable TPS Vs RPM" (0x74D1)
;   4. Retune closed-loop AFR targets (O2 sensors still work!)
;   5. Disable MAF failure DTC if desired (cosmetic only)
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
MIN_AIRFLOW_CAL     EQU $7F1B   ; Minimum Airflow For Default Air (ROM, 16-bit, stock=0x01C0)
MAX_AIRFLOW_TABLE   EQU $6D1D   ; Maximum Airflow Vs RPM table (17 elements)

;------------------------------------------------------------------------------
; RAM VARIABLES (for reference - not modified by this patch)
;------------------------------------------------------------------------------
TPS_RAM             EQU $00C6   ; Throttle Position Sensor % (0-255)
RPM_RAM             EQU $00A2   ; Engine RPM (16-bit)
AIRFLOW_RAM         EQU $017B   ; Calculated airflow storage (g/s scaled)

;------------------------------------------------------------------------------
; BINARY HEX PATCHES REQUIRED (Apply with hex editor BEFORE code injection)
;------------------------------------------------------------------------------
; Address   | Original | Patched | Description
; ----------|----------|---------|----------------------------------------------
; 0x7F1B    | 0x00 0x23| 0x00 0xC8| Min Airflow: 3.5 g/s → 200 g/s (16-bit)
; 0x56D4    | 0x00     | 0x01    | Force MAF failure flag = 1
; 0x5795    | 0x00     | 0x01    | Bypass MAF filtering = 1 (always)
;
; NOTE: Min Airflow at 0x7F1B is 16-bit - patch both bytes if needed

;------------------------------------------------------------------------------
; CODE SECTION - MINIMAL ALPHA-N ENABLER
;------------------------------------------------------------------------------
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED

;==============================================================================
; FORCE_MAF_FAILURE - Minimal Alpha-N Enable Routine
;==============================================================================
; Sets both MAF failure flags to force ECU into Alpha-N fallback mode.
; This is the ONLY routine needed for basic Alpha-N operation.
;
; Entry: None (called at ECU startup via hook)
; Exit:  MAF_FAILURE_FLAG = 1, MAF_BYPASS_FLAG = 1
; Stack: 0 bytes (no pushes)
; Size:  8 bytes total
;==============================================================================

FORCE_MAF_FAILURE:
    LDAA    #$01                ; A = 1 (failure state)
    STAA    MAF_FAILURE_FLAG    ; Force M32 MAF Failure = 1
    STAA    MAF_BYPASS_FLAG     ; Bypass MAF filtering = 1
    RTS                         ; Return (8 bytes total)

;==============================================================================
; MAF_READ_ZERO - Return Zero for MAF Sensor Read
;==============================================================================
; Returns 0 Hz to any MAF sensor read attempt, ensuring ECU stays in
; failure mode even if MAF sensor is still physically connected.
;
; Entry: None (called when ECU attempts MAF read)
; Exit:  D = 0x0000 (0 Hz = sensor disconnected)
; Stack: 0 bytes
; Size:  4 bytes total
;==============================================================================

MAF_READ_ZERO:
    LDD     #$0000              ; D = 0 Hz (simulate disconnected)
    RTS                         ; Return (4 bytes total)

;==============================================================================
; END OF v3 MINIMAL CODE - Total: 12 bytes
;==============================================================================
; v3 does NOT include:
;   - Airflow calculation override (use XDF tables instead)
;   - TPS-based interpolation (ECU handles this in fallback mode)
;   - VE table lookup (repurpose "Maximum Airflow Vs RPM" via XDF)
;
; This leaves 15,180 bytes free at 0x0C474+ for other patches!
;==============================================================================
;==============================================================================
; REFERENCE: BMW MS43 ALPHA-N TABLE (DYNO-TUNED BY RACEMODE)
;==============================================================================
; Source: MS43 Community Patchlist v2.9.2 with [PATCH] Alpha/N applied
; Table: ip_maf_1_diag__n__tps_av (Address 0x7ABBA in 512KB binary)
;
; BMW M52TUB25 Build (Racemode, Poland):
;   - Stock: 170hp → Tuned: 235hp
;   - MS43 swap, M54B30 intake manifold + injectors, DBW conversion
;
; ⚠️ MS4X.NET WARNING: Stock ip_maf_1_diag__n__tps_av runs ~10-15% LEAN!
;    The values below are RICHER (dyno-tuned), not stock BMW.
;
; UNIT CONVERSION (BMW mg/stk → VY V6 g/s):
;   VY_g/s = MS43_mg/stk × RPM × 6_cylinders / 120000
;   Example: 302.4 mg/stk @ 2016 RPM = 302.4 × 2016 × 6 / 120000 = 30.5 g/s
;------------------------------------------------------------------------------
;
; BMW MS43 DYNO-TUNED VALUES (mg/stroke):
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
;==============================================================================
; VY V6 ALPHA-N STARTING POINT TABLE (SCALED FROM BMW MS43)
;==============================================================================
; Engine Comparison:
;   BMW M52TUB28: 2.8L I6, 193hp @ 5500 RPM, ~250 g/s max airflow  
;   Holden L36:   3.8L V6, 200hp @ 5200 RPM, ~275 g/s max airflow
;
; Scaling Factor: VY V6 = BMW × 1.35 (38% larger displacement)
; VY V6 RPM range: 800-6200 (lower redline than BMW)
;
; Enter these values into "Maximum Airflow Vs RPM" table at 0x6D1D (17 cols):
;
;  RPM: 800  1200  1600  2000  2400  2800  3200  3600  4000  4400  4800  5200  5600  6000
; 100%: 205   305   410   515   595   660   705   745   770   775   765   730   690   645
;  80%: 165   245   330   415   485   540   580   615   640   645   640   615   580   545
;  60%: 125   185   250   315   375   420   460   490   510   515   510   490   465   440
;  40%:  85   125   170   215   260   295   325   350   365   370   365   355   340   315
;  20%:  45    65    90   115   140   165   185   200   210   215   210   200   185   170
;
; ⚠️ CRITICAL: These are ESTIMATES - DYNO TUNING MANDATORY!
;    Start 10% RICH and lean out while watching wideband AFR + knock sensor.
;==============================================================================

;==============================================================================
; HOOK INSTALLATION (Binary Patch Required)
;==============================================================================
; To activate FORCE_MAF_FAILURE, add JSR call to ECU init routine:
;
; 1. Find ECU init routine (search for reset vector @ 0xFFFE)
; 2. Locate safe injection point after stack setup
; 3. Add: JSR $0C468 (or assembled address of FORCE_MAF_FAILURE)
;
; Optional: Hook MAF_READ_ZERO at MAF Hz read routine:
;   Replace: LDAA <maf_port> with JSR $0C470 (MAF_READ_ZERO)
;
; ⚠️ Hook points NOT YET VALIDATED - requires disassembly analysis

;==============================================================================
; IMPLEMENTATION STEPS (v3 Minimal)
;==============================================================================
;
; Step 1: Apply binary hex patches (hex editor)
;   - 0x56D4: 00 → 01 (Force MAF failure)
;   - 0x5795: 00 → 01 (Bypass MAF filtering)
;   - 0x7F1B: Increase Min Airflow to ~200 g/s
;
; Step 2: Assemble and inject code at 0x0C468
;   as11 mafless_alpha_n_conversion_v3.asm -o v3_patch.s19
;
; Step 3: Add startup hook (JSR FORCE_MAF_FAILURE)
;
; Step 4: Tune "Maximum Airflow Vs RPM" table (0x6D1D) on dyno
;
; Step 5: Verify with wideband O2 - target 14.7:1 cruise, 12.5:1 WOT
;
;==============================================================================
; TUNING QUICK REFERENCE
;==============================================================================
;
; 1. START RICH: Initial values 10-15% richer, prevents lean damage
; 2. IDLE FIRST: 0% TPS cells must hit 14.7:1 AFR before other tuning
; 3. WOT LAST: 100% TPS row targets 12.5:1 (NA) or 11.5:1 (turbo)
; 4. USE O2 TRIMS: STFT/LTFT still work - if LTFT >±5%, retune base table
; 5. VERIFY TPS: 0%=closed, 100%=WOT - Alpha-N is useless if TPS wrong!
;
; Closed-loop O2 feedback STILL WORKS in Alpha-N mode!
; ECU will self-correct minor table errors via fuel trims.
;
;==============================================================================
; ALPHA-N PROS/CONS SUMMARY
;==============================================================================
;
; ✅ ADVANTAGES:
;   - Unlimited power potential (no MAF limit ~450 g/s)
;   - Works with high-lift cams, ITBs, turbo/supercharger
;   - No MAF housing restriction in intake
;   - Eliminates BOV reversion issues
;
; ❌ DISADVANTAGES:
;   - Requires dyno tuning (10-20 hours typical)
;   - Less accurate at part-throttle than MAF
;   - Must retune after engine mods
;   - M32 MAF failure DTC always present (cosmetic)
;
;==============================================================================
; PATCH COMPATIBILITY
;==============================================================================
;
; ✅ Works with: Ignition cut limiters, timing patches, boost control
; ⚠️ Conflicts: MAF-based anti-lag (delete that code first)
;
;==============================================================================
; v3 SUMMARY
;==============================================================================
;
; Total Code Size: 12 bytes (FORCE_MAF_FAILURE: 8 bytes, MAF_READ_ZERO: 4 bytes)
; Free Space Used: $0C468-$0C473 (12 bytes of 15,192 available)
; Remaining Free:  15,180 bytes at $0C474+ for additional patches
;
; v3 is the MINIMAL implementation - relies entirely on:
;   - Binary hex patches for flag values
;   - XDF table tuning for airflow calibration
;   - ECU's built-in Alpha-N fallback logic
;
; For feature-rich version with custom airflow calculation, use v1 or v2.
;
; Implementation Status: 🔬 EXPERIMENTAL
; Chr0m3 Approval: ❓ NOT YET VALIDATED
;
; Author: Jason King (kingaustraliagg)
; Date: January 16, 2026
;
;==============================================================================
; END OF MAFLESS ALPHA-N CONVERSION v3 - MINIMAL ROM FOOTPRINT
;==============================================================================
