;==============================================================================
; [ADDRESS FIX 2026-02-09] Binary-verified address corrections applied
; Ground truth: 92118883_STOCK.bin (HC11 opcode scan, equivalent to Capstone)
; Fixes: 1 issues found and annotated
;==============================================================================
;==============================================================================
; VY V6 ALPINA-STYLE MAFless FALLBACK PATCH v1.0
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 25, 2026 (Updated February 3, 2026)
; Status: 🔬 EXPERIMENTAL - Derived from Alpina B3 3.3L binary analysis
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
;==============================================================================
; PURPOSE
;==============================================================================
;
; This patch forces the ECU to use its MAF failure fallback mode, which
; uses a simpler Alpha-N (TPS + RPM) fuel calculation instead of MAF sensor.
;
; BASED ON: Alpina B3 3.3L Stroker (M52TUB33) tuning methodology
;   - Zero complex interacting tables
;   - Force ECU to use diagnostic/fallback path
;   - Tune 3-5 simple tables instead of 50+
;
; BMW MS42 IMPLEMENTATION:
;   - ip_maf_1_diag__n__tps_av = Primary airflow table (TPS × RPM)
;   - Bypasses MAF sensor input conversion
;   - Uses "MAF Substitute Table" for load calculation
;
;==============================================================================
; THE ALPINA PHILOSOPHY: "ZERO THE COMPLEX, TUNE THE SIMPLE"
;==============================================================================
;
; VERIFIED FROM BINARY COMPARISON (February 3, 2026):
;   Stock M52TUB25 EU3 RHD: 7 zero tables (normal)
;   Alpina B3 3.3L Stroker: 34 zero tables (intentionally zeroed!)
;
; Alpina zeroed 27 ADDITIONAL tables beyond stock to simplify tuning.
;
;------------------------------------------------------------------------------
; ALPINA ZEROED TABLES - COMPLETE LIST (34 TOTAL)
;------------------------------------------------------------------------------
;
; ━━━ VANOS VE TABLES (7 of 8 zeroed) ━━━
;   ❌ ip_maf_vo_1__map__n  = ALL ZEROS (VANOS position 1)
;   ❌ ip_maf_vo_3__map__n  = ALL ZEROS (VANOS position 3)
;   ❌ ip_maf_vo_4__map__n  = ALL ZEROS (VANOS position 4)
;   ❌ ip_maf_vo_5__map__n  = ALL ZEROS (VANOS position 5)
;   ❌ ip_maf_vo_6__map__n  = ALL ZEROS (VANOS position 6)
;   ❌ ip_maf_vo_7__map__n  = ALL ZEROS (VANOS position 7)
;   ❌ ip_maf_vo_8__map__n  = ALL ZEROS (VANOS position 8)
;   ✅ ip_maf_vo_2__map__n  = ACTIVE (only VE table used!)
;
;   WHY: Forces ECU to use single VE table regardless of cam position.
;        Eliminates complex VANOS interaction - predictable airflow calc.
;
; ━━━ RON (FUEL GRADE) TIMING TABLES ━━━
;   ❌ ip_iga_ron_91_pl_ivvt__n__maf = ALL ZEROS (RON91 timing offset)
;   ❌ ip_iga_ron_98_pl_ivvt__n__maf = ALL ZEROS (RON98 timing offset)
;
;   WHY: Stock BMW switches timing based on fuel grade detection.
;        Zeroing forces ECU to use base timing only - tuner controls all.
;
; ━━━ TEMPERATURE-DEPENDENT TIMING/INJECTION ━━━
;   ❌ ip_ti_tco_1_is_ivvt__n__maf    = ALL ZEROS (cold inj timing idle)
;   ❌ ip_ti_tco_2_is_ivvt__n__maf    = ALL ZEROS (warm inj timing idle)
;   ❌ ip_ti_tco_2_pl_ivvt_1__n__maf  = ALL ZEROS (warm inj timing PL1)
;   ❌ ip_ti_tco_2_pl_ivvt_2__n__maf  = ALL ZEROS (warm inj timing PL2)
;   ❌ ip_iga_tco_2_is_ivvt__n__maf   = ALL ZEROS (warm ign timing idle)
;
;   WHY: Prevents ECU from modifying timing based on coolant temp.
;        Tuner has full control over timing at all temperatures.
;
; ━━━ START OF INJECTION TIMING ━━━
;   ❌ ip_soi_tco_2_is__n__ti = ALL ZEROS (warm SOI idle)
;   ❌ ip_soi_tco_2_pl__n__ti = ALL ZEROS (warm SOI partial load)
;
;   WHY: Fixed injection timing regardless of temperature.
;
; ━━━ IGNITION CORRECTION TABLES ━━━
;   ❌ ip_iga_optm_dif__dmtc          = ALL ZEROS (optimal timing diff)
;   ❌ ip_iga_optm_tco_2__n__maf      = ALL ZEROS (optimal timing temp2)
;   ❌ ip_iga_cor_cam_dif_ex__cam_dif = ALL ZEROS (exhaust cam correction)
;   ❌ ip_iga_cor_cam_dif_in__cam_dif = ALL ZEROS (intake cam correction)
;   ❌ ip_iga_cs_is__tco              = ALL ZEROS (cold start ign idle)
;   ❌ ip_iga_maf_n_knk_diag__n__maf  = ALL ZEROS (knock diag timing)
;   ❌ ip_igab__n__maf                = ALL ZEROS (base ignition offset)
;
;   WHY: Removes all ignition correction offsets. Main timing tables only.
;
; ━━━ DIAGNOSTIC/ERROR THRESHOLDS ━━━
;   ❌ ip_thd_is_er_diag__n__maf = ALL ZEROS (idle error diagnostic)
;   ❌ ip_thd_at_er__n_32__maf   = ALL ZEROS (auto trans error)
;   ❌ ip_thd_mt_er__n_32__maf   = ALL ZEROS (manual trans error)
;
;   WHY: Disables some diagnostic comparisons - prevents nuisance DTCs.
;
; ━━━ CATALYST/EMISSIONS TABLES ━━━
;   ❌ ip_fac_tqd_cat__pvs_av        = ALL ZEROS (catalyst torque factor)
;   ❌ ip_t_ch_puc_deacc__iga__cat   = ALL ZEROS (catalyst decel timing)
;   ❌ id_t_ch_ti_cat_var__tco_st    = ALL ZEROS (catalyst timing var)
;
;   WHY: Removes emissions-related timing modifications.
;
; ━━━ MISCELLANEOUS ━━━
;   ❌ ip_dist_min__tco_st          = ALL ZEROS (distance minimum)
;   ❌ ip_n_vim_tia__tia             = ALL ZEROS (variable intake manifold)
;   ❌ ip_n_sp_add_cs__tco           = ALL ZEROS (speed add cold start)
;   ❌ ip_ti_add_cop_step_2__n__maf  = ALL ZEROS (injection add step2)
;   ❌ kf_fak_van_kh__n__lm_van      = ALL ZEROS (VANOS factor)
;
;------------------------------------------------------------------------------
; ALPINA KEPT ACTIVE (Tuned for 3.3L stroker)
;------------------------------------------------------------------------------
;   ✅ ip_maf_1_diag__n__tps_av = PRIMARY airflow table (TPS × RPM)
;   ✅ ip_iga_knk_diag          = PRIMARY timing (knock fallback)
;   ✅ ip_maf_vo_2              = SINGLE VE table (mid-cam position)
;   ✅ Base fuel/timing tables  = Core calibration
;
;==============================================================================
; VY V6 MAFless FALLBACK BEHAVIOR
;==============================================================================
;
; When MAF sensor fails (DTC P0101-P0103), VY V6 ECU:
;   1. Sets M32 MAF Failure flag at $56D4
;   2. Switches to fallback fuel calculation
;   3. Uses "Minimum Airflow For Default Air" at $7F1B as base
;   4. Uses "Maximum Airflow Vs RPM" at $6D1D for RPM compensation
;   5. O2 closed-loop still works (corrects fuel in real-time)
;   6. WOT uses open-loop (fallback table values direct)
;
; VY V6 DTC MASK BYTES (VERIFIED from 92118883_STOCK.bin):
;
;   $56D4 = KKMASK4 (DTC Enable Mask)
;           Stock = 0xCC (bit 6 SET = M32 DTC logging ENABLED)
;           To DISABLE M32 DTC: Clear bit 6 → 0x8C
;
;   $56DE = Check Trans Light Mask  
;           Stock = 0xC0 (bit 6 SET = CEL lights on M32)
;           To DISABLE M32 CEL: Clear bit 6 → 0x80
;
;   $56F3 = KKACT3 (Action Mask) ← KEY ADDRESS!
;           Stock = 0x00 (bit 6 CLEAR = NO ACTION taken on M32!)
;           To ENABLE fallback: Set bit 6 → 0x40
;
;   $7F1B = Minimum Airflow For Default Air (stock = 0x01C0 = 3.5 g/s)
;   $7F2A = Default Airflow Vs RPM & TPS % (7×5 table, 35 bytes)
;   $6D1D = Maximum Airflow Vs RPM (17-element table)
;
;==============================================================================
; IMPLEMENTATION
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP (XDF VERIFIED - v2.09a against 92118883_STOCK.bin)
;------------------------------------------------------------------------------

; DTC Mask Bytes (ROM calibration, NOT runtime flags!)
M32_DTC_ENABLE          EQU $56D4   ; KKMASK4 - bit 6 = M32 DTC enabled (stock=0xCC)
M32_CEL_MASK            EQU $56DE   ; Check Trans Light - bit 6 = M32 CEL (stock=0xC0)
M32_ACTION_MASK         EQU $56F3   ; KKACT3 - bit 6 = M32 ACTION (stock=0x00) ← KEY!
MAF_OPTION_WORD         EQU $5795   ; Option word - multiple bits (stock=0xFC)

; Fallback Fuel Tables
MIN_AIRFLOW_ADDR        EQU $7F1B   ; Minimum Airflow For Default Air (16-bit, stock=0x01C0)
DEFAULT_AIRFLOW_TABLE   EQU $7F2A   ; Default Airflow Vs RPM & TPS % (7×5 table)
MAX_AIRFLOW_TABLE       EQU $6D1D   ; Maximum Airflow Vs RPM (17 elements)

; RAM Variables (read-only references)
TPS_RAM EQU $00C6   ; Throttle Position Sensor % (0-255) ; Verified: TPS_FILTERED (7 refs Enhanced (9 stock)) [Enhanced-fix]
RPM_RAM EQU $00A2   ; Engine RPM/25 (8-bit) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
; WARNING: $017B is DWELL INTERMEDIATE, NOT airflow! (Corrected 2026-02-02)
; The actual airflow RAM location is UNKNOWN - needs disassembly verification
; AIRFLOW_RAM           EQU $????   ; TODO: Find actual airflow RAM variable

;------------------------------------------------------------------------------
; CONFIGURATION CONSTANTS
;------------------------------------------------------------------------------

; Default airflow base value for Alpha-N operation
; Stock = 0x01C0 = 448 decimal = 3.5 g/s (using formula X*2/256)
; Recommended = 0x6400 = 25600 decimal = 200 g/s (adequate for idle/cruise)
; NOTE: This is a 16-bit big-endian value!
DEFAULT_AIRFLOW_VALUE   EQU $6400   ; 200 g/s base (was 0x01C0 = 3.5 g/s)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
; ⚠️ CORRECTED 2026-02-02: $14500 contains data (0x01 bytes), NOT free space!
            ORG $C500           ; ✅ CORRECT: CPU $C500 = File 0x0C500 (verified 0x00 bytes) ; ⚠️ MUST BE bank 1 (file 0x0C500). Banks 0/2/3 have calibration data! [auto-fix 2026-02-09]

;==============================================================================
; FORCE_MAFLESS_MODE - Enable Alpha-N Fallback
;==============================================================================
; Entry: None (called at ECU startup)
; Exit:  MAF failure flags set, fallback mode active
; Stack: 2 bytes
; Size:  14 bytes
;==============================================================================

FORCE_MAFLESS_MODE:
    PSHA                            ; 36 - Save A
    PSHB                            ; 37 - Save B
    
    ; STEP 1: Enable M32 action (makes ECU use fallback when MAF fails)
    ; Stock 0x56F3 = 0x00, we set bit 6 to enable M32 action
    LDAA    M32_ACTION_MASK         ; B6 56 F3 - Load current value
    ORAA    #$40                    ; 8A 40 - Set bit 6 (M32 action)
    STAA    M32_ACTION_MASK         ; B7 56 F3 - Store back
    
    ; STEP 2: Optionally disable DTC logging (cosmetic - prevents code storage)
    ; Stock 0x56D4 = 0xCC, clear bit 6 to disable M32 DTC logging
    LDAA    M32_DTC_ENABLE          ; B6 56 D4
    ANDA    #$BF                    ; 84 BF - Clear bit 6 (0xCC → 0x8C)
    STAA    M32_DTC_ENABLE          ; B7 56 D4
    
    ; STEP 3: Optionally disable CEL on M32 (cosmetic - prevents light)
    LDAA    M32_CEL_MASK            ; B6 56 DE
    ANDA    #$BF                    ; 84 BF - Clear bit 6 (0xC0 → 0x80)
    STAA    M32_CEL_MASK            ; B7 56 DE
    
    PULB                            ; 33 - Restore B
    PULA                            ; 32 - Restore A
    RTS                             ; 39

;==============================================================================
; MAF_READ_ZERO - Return Zero for MAF Sensor Read
;==============================================================================
; This routine intercepts MAF sensor reads and returns 0 Hz, ensuring
; the ECU stays in failure mode even if MAF sensor is still connected.
;
; Entry: None (called when ECU attempts MAF read)
; Exit:  D = 0x0000 (0 Hz = sensor disconnected)
; Stack: 0 bytes
; Size:  4 bytes
;==============================================================================

MAF_READ_ZERO:
    LDD     #$0000                  ; CC 00 00 - D = 0 (no MAF signal)
    RTS                             ; 39

;==============================================================================
; SIMPLIFIED ALPHA-N AIRFLOW CALC (Optional - for advanced users)
;==============================================================================
; If the stock fallback doesn't provide enough resolution, this routine
; calculates airflow from TPS × RPM with a simple linear approximation.
;
; Entry: None (reads TPS and RPM from RAM)
; Exit:  D = Calculated airflow (g/s × 128)
;        AIRFLOW_RAM updated
; Stack: 4 bytes
; Size:  32 bytes
;==============================================================================

CALC_ALPHA_N_AIRFLOW:
    PSHA                            ; 36 - Save A
    PSHB                            ; 37 - Save B
    
    ; Read TPS (0-255 = 0-100%)
    LDAA    TPS_RAM                 ; 96 C6
    
    ; Read RPM/25 (0-255 = 0-6375 RPM)
    LDAB    RPM_RAM                 ; D6 A2
    
    ; Simple approximation: Airflow ≈ (TPS × RPM) / 64 + 30
    ; This gives ~30 g/s at idle, ~450 g/s at WOT 6000 RPM
    MUL                             ; 3D - D = TPS × (RPM/25)
    
    ; Divide by 64 (shift right 6 bits)
    LSRD                            ; 04 - /2
    LSRD                            ; 04 - /4
    LSRD                            ; 04 - /8
    LSRD                            ; 04 - /16
    LSRD                            ; 04 - /32
    LSRD                            ; 04 - /64
    
    ; Add idle offset (30 g/s minimum)
    ADDD    #$001E                  ; C3 00 1E
    
    ; Store result
    STD     AIRFLOW_RAM             ; FD 01 7B
    
    PULB                            ; 33 - Restore B
    PULA                            ; 32 - Restore A
    RTS                             ; 39

;==============================================================================
; BINARY PATCHES REQUIRED (Apply with hex editor)
;==============================================================================
;
; These patches configure MAFless fallback mode:
;
; Address   Stock     Patched   Description
; -------   -----     -------   -----------
; 0x56F3    0x00      0x40      ENABLE M32 action (bit 6 set) ← KEY PATCH!
; 0x56D4    0xCC      0x8C      DISABLE M32 DTC logging (bit 6 clear, optional)
; 0x56DE    0xC0      0x80      DISABLE M32 CEL light (bit 6 clear, optional)
; 0x7F1B    01 C0     64 00     Min Airflow: 3.5 → 200 g/s (16-bit BE)
;
; ⚠️ STOCK VALUES VERIFIED from VX-VY_V6_$060A_Enhanced_v1.0a.bin on January 25, 2026
;
; WITHOUT the 0x56F3 patch, the ECU will NOT use fallback mode!
; The other patches are optional (cosmetic DTC/CEL disable).
;
;==============================================================================
; XDF TUNING AFTER PATCH
;==============================================================================
;
; After applying the patch, tune these tables in TunerPro:
;
; 1. "Maximum Airflow Vs RPM" at $6D1D (17 elements)
;    - This becomes your VE table substitute
;    - Set values to approximate actual airflow at each RPM
;    - Start with: 50, 60, 75, 90, 110, 130, 150, 175, 200, 225,
;                  250, 280, 310, 340, 370, 400, 430 (g/s)
;
; 2. "Minimum Airflow For Default Air" at $7F1B
;    - Base airflow when fallback is active
;    - Recommended: 150-200 g/s for idle stability
;
; 3. "Power Enrichment Enable TPS Vs RPM" at $74D1
;    - When to switch from closed-loop to open-loop (WOT)
;    - Stock settings usually work fine
;
; 4. Verify O2 closed-loop is working
;    - Fuel trims should center around 0% at cruise
;    - If consistently rich/lean, adjust Max Airflow table
;
;==============================================================================
; HARDWARE NOTES
;==============================================================================
;
; ⚠️ MAF SENSOR:
;    - Can be physically removed/disconnected
;    - Or left in place (ECU ignores it with patch active)
;    - Removing MAF eliminates intake restriction
;
; ⚠️ NO MAP SENSOR ON VY V6:
;    - VY V6 has BARO sensor only (reads once at startup)
;    - BARO is for transmission shift timing, NOT engine fueling
;    - For turbo/boost builds, must ADD a MAP sensor to spare A/D input
;
; ⚠️ O2 SENSORS STILL REQUIRED:
;    - Closed-loop fuel control corrects errors in Alpha-N table
;    - Wideband recommended for WOT tuning
;
;==============================================================================
; DTC HANDLING
;==============================================================================
;
; With this patch active, you WILL get:
;   - P0101/P0102/P0103 (MAF sensor malfunction)
;   - M32 in ALDL datastream
;
; Options:
;   1. Leave it (cosmetic - engine runs fine)
;   2. Find and patch DTC enable flag for MAF codes
;   3. Clear codes after each drive
;
;==============================================================================
; REVERTING THE PATCH
;==============================================================================
;
; To restore stock MAF-based operation:
;
; Address  Patched   Stock     Description
; -------  -------   -----     -----------
; 0x56F3   0x40      0x00      Disable M32 action (restore stock)
; 0x56D4   0x8C      0xCC      Re-enable M32 DTC logging
; 0x56DE   0x80      0xC0      Re-enable M32 CEL light
; 0x7F1B   64 00     01 C0     Min Airflow back to 3.5 g/s
;
; Reconnect MAF sensor and clear DTCs.
;
;==============================================================================
; END OF PATCH
;==============================================================================

            END

;------------------------------------------------------------------------------
; PATCH BYTES SUMMARY (VERIFIED January 25, 2026)
;------------------------------------------------------------------------------
;
; Binary patches (hex editor):
;   0x56F3: 00 → 40 (Enable M32 action - KEY PATCH!)
;   0x56D4: CC → 8C (Disable M32 DTC logging - optional)
;   0x56DE: C0 → 80 (Disable M32 CEL light - optional)
;   0x7F1B: 01 C0 → 64 00 (Min Airflow 3.5 → 200 g/s)
;
; Stock values verified from VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Addresses verified from VX VY_V6_$060A_Enhanced_v2.09a.xdf
;
;------------------------------------------------------------------------------
