;==============================================================================
; [ADDRESS FIX 2026-02-09] Binary-verified address corrections applied
; Ground truth: 92118883_STOCK.bin (HC11 opcode scan, equivalent to Capstone)
; Fixes: 1 issues found and annotated
;==============================================================================
; ============================================================================
; VY V6 MAFless Alpha-N TPS Fallback (v25 - Gearhead_EFI TPI Method)
; ============================================================================
; Purpose: Full MAFless conversion using TPS-based Alpha-N fueling
; Inspired by: Gearhead_EFI 86-89 TPI bins (bin/86tpi.bin, bin/86TPI32.BIN)
; References: Topic 3892 - VS 3 MAFless Tune, TPI XDF definitions
; Author: Adapted from GM TPI/TBI speed-density concepts
; Date: 2026-01-15 (Updated February 3, 2026)
; Status: UNTESTED - Requires TPS calibration and VE table tuning
; ============================================================================
;
; ALPINA "ZERO COMPLEX, TUNE SIMPLE" - CROSS-PLATFORM VALIDATION
; ============================================================================
;
; BINARY COMPARISON (February 3, 2026):
;   Stock BMW M52TUB25:   7 zero tables (normal)
;   Alpina B3 3.3L:      34 zero tables (27 intentionally zeroed!)
;
; Alpina uses ip_maf_1_diag__n__tps_av (TPS × RPM) as PRIMARY airflow table
; after zeroing 7 of 8 VANOS VE tables. Same concept as TPI Alpha-N!
;
; Key Alpina zeroed tables (matching TPI philosophy):
;   ❌ 7/8 VANOS VE tables → Forces single VE path
;   ❌ RON91/RON98 timing → Tuner controls all timing
;   ❌ Temp timing corrections → Predictable at all temps
;
; See MAFLESS_VARIANTS_COMPARISON.md for complete list.
;
; ============================================================================
; ALPHA-N CONCEPT:
; - Engine load estimated from TPS position + RPM
; - No MAF sensor required (delete or ignore)
; - 2D lookup table: TPS% vs RPM → Load estimate
; - Proven on 1986-1989 TPI Corvette/Camaro/Firebird
;
; TPI REFERENCE BINS (Gearhead_EFI):
; - 86tpi.bin: Original 1986 TPI with Alpha-N fallback
; - 86TPI32.BIN: 32K version with enhanced tables
; - 88CORV32.BIN: 1988 Corvette TPI MAFless conversion
; - 89vets.bin / 89vets 6E.bin: Speed-density + Alpha-N hybrid
;
; VY V6 vs TPI DIFFERENCES:
; TPI:
;   - Sequential port injection (8 injectors)
;   - Batch-fire ignition
;   - Simple Alpha-N: TPS + RPM → Load
;
; VY V6:
;   - Sequential injection (6 injectors)
;   - Waste spark (3 coil packs)
;   - Has MAF sensor input (need to force failure or ignore)
;
; IMPLEMENTATION STRATEGY:
; 1. Set $56F3 = 0x40 (enable M32 fallback action)
; 2. Disconnect MAF sensor (or ground signal wire)
; 3. ECU uses fallback table at $7F2A (TPS × RPM)
; 4. Compensate for IAT/BARO changes (O2 closed-loop handles most)
;
; *** FEBRUARY 2026 UPDATE ***
; Stock fallback table at $7F2A is LIMITED:
;   - Only 7×5 (35 bytes): 0-50% TPS, 0-4800 RPM
;   - NO WOT coverage (>50% TPS)
;   - NO high RPM coverage (>4800 RPM)
;   - For full TPI-style Alpha-N, need to relocate table (see v4)
;
; To activate fallback mode:
;   $56D4 = 0x8C (disable M32 DTC logging)
;   $56F3 = 0x40 (enable M32 fallback ACTION - stock is 0x00!)
;   $577C = 0x00 (keep Hot Open Loop enabled)
;   $577D = 0x00 (keep Accel Enrichment enabled)
;   Then disconnect MAF sensor
;
; ============================================================================

        ORG $C468          ; Verified free space region ; FIXED: $14468 is a FILE OFFSET, not CPU addr. CPU=$C468 bank 2 (file 0x14468) [Enhanced-fix]

; ============================================================================
; Constants and Addresses
; ============================================================================

; MAF Control Flags
M32_MAF_FAILURE EQU     $56D4   ; M32 MAF Failure flag address (XDF verified)
MAF_FAILURE_BIT EQU     $40     ; Bit 6 = MAF failure

; TPS Input
TPS_RAW_ADC     EQU     $1031   ; A/D Converter Result 1 (TPS input)
TPS_VOLTAGE_RAM EQU $00B0   ; Scaled TPS voltage (0-5V, example address) ; Verified: MAP_OR_TPS_RAW (7 refs Enhanced. STOCK uses this!) [Enhanced-fix]
TPS_PERCENT_RAM EQU $00B1   ; TPS percentage (0-100%, calculated) ; Verified: TPS_PERCENT (45 refs both. STOCK uses this!) [Enhanced-fix]

; RPM Input
; ⚠️ IMPORTANT: $00A2 stores RPM/25 as 8-bit! NOT 16-bit RPM!
;    Actual RPM = value × 25. Max = 255 × 25 = 6375 RPM
;    $00A3 = Engine State 2 (12 accesses) - NOT RPM low byte!
ENGINE_RPM EQU $00A2   ; RPM/25 (8-bit, verified, 82 references) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
; ENGINE_RPM_LO   EQU     $00A3   ; ❌ WRONG! This is Engine State 2!

; Airflow Output
CALCULATED_AIRFLOW EQU $0180   ; Calculated airflow (G/S) output to fuel calc ; Verified: CALC_AIRFLOW_REF (1 ref both) [Enhanced-fix]
DEFAULT_AIRFLOW EQU     $7F1B   ; Minimum Airflow For Default Air (XDF)

; IAT/BARO Compensation
IAT_TEMP_RAM    EQU     $00C0   ; Intake air temperature (example)
BARO_PRESSURE   EQU     $00C1   ; Barometric pressure (example)

; Alpha-N Table Pointer
ALPHA_N_TABLE   EQU     $22300  ; TPS vs RPM load table (needs allocation)

; Table Dimensions
TPS_AXIS_COUNT  EQU     11      ; 0%, 10%, 20%, ... 100% TPS
RPM_AXIS_COUNT  EQU     17      ; 500, 750, 1000, ... 6500 RPM

; ============================================================================
; Force MAF Failure Mode (Called at ECU startup)
; ============================================================================

force_maf_failure:
        ; Set M32 MAF Failure flag (bit 6 of $56D4)
        LDAA    M32_MAF_FAILURE
        ORAA    #MAF_FAILURE_BIT ; Set bit 6
        STAA    M32_MAF_FAILURE
        
        ; Set default airflow to minimum
        LDAA    #$23            ; 3.5 G/S (from XDF @ $7F1B)
        STAA    $0182           ; Store as fallback airflow
        
        RTS

; ============================================================================
; Read and Scale TPS Input
; ============================================================================

read_tps:
        ; Read TPS A/D converter (8-bit, 0-255)
        LDAA    TPS_RAW_ADC     ; Load A/D result
        
        ; Scale to 0-5V: (ADC / 255) * 5.0
        ; Simplified: ADC / 51 ≈ voltage
        LDAB    #51
        MUL                     ; D = A * B (voltage * 10)
        STAA    TPS_VOLTAGE_RAM ; Store scaled voltage
        
        ; Convert voltage to percentage
        ; TPS @ 0.5V = 0%, TPS @ 4.5V = 100%
        ; Percentage = (V - 0.5) / 4.0 * 100
        
        LDAA    TPS_VOLTAGE_RAM
        SUBA    #5              ; Subtract 0.5V (5 units)
        BCC     tps_positive    ; If carry clear, positive result
        CLRA                    ; Else clamp to zero
        
tps_positive:
        ; Divide by 4 to get approximate percentage
        LSRA                    ; Divide by 2
        LSRA                    ; Divide by 4
        STAA    TPS_PERCENT_RAM ; Store TPS%
        
        RTS

; ============================================================================
; Alpha-N Load Calculation (TPS + RPM → Airflow)
; ============================================================================

calculate_alpha_n_load:
        ; Step 1: Read TPS percentage
        JSR     read_tps
        LDAA    TPS_PERCENT_RAM ; Load TPS%
        
        ; Step 2: Read RPM/25 (8-bit value, actual RPM = value × 25)
        LDAB    ENGINE_RPM      ; Load RPM/25 (8-bit)
        
        ; Step 3: Lookup in 2D table (TPS% vs RPM)
        ; Table structure: 11 TPS rows × 17 RPM columns
        ; Each cell = estimated airflow in G/S
        
        ; Calculate table index: (TPS_row * 17) + RPM_col
        ; TPS_row = TPS% / 10 (0-10)
        ; RPM_col = RPM/25 / 16 = (RPM/400) roughly (0-16)
        
        ; Get TPS row
        LDAA    TPS_PERCENT_RAM
        LDAB    #10
        IDIV                    ; X = TPS% / 10 (row index)
        XGDX                    ; D = row index
        
        ; Multiply row by 17 (columns)
        LDAB    #17
        MUL                     ; D = row * 17
        PSHD                    ; Save row offset
        
        ; Get RPM column (RPM/25 ÷ 16 ≈ RPM/400)
        LDAA    ENGINE_RPM      ; Load RPM/25 (8-bit)
        LSRA                    ; Divide by 2
        LSRA                    ; Divide by 4  
        LSRA                    ; Divide by 8
        LSRA                    ; Divide by 16 → A = RPM/400 (column 0-16)
        CLRB                    ; Clear B for indexing
        XGDX                    ; X = RPM column (0-16)
        
        ; Add row offset + column offset
        PULD                    ; Restore row offset
        STX     $0185           ; Temp store column
        LDX     $0185
        LEAX    D,X             ; X = row_offset + column
        
        ; Load table value
        LDX     #ALPHA_N_TABLE  ; Base table address
        LDAA    X               ; Load airflow value from table
        STAA    CALCULATED_AIRFLOW ; Store calculated airflow
        
        RTS

; ============================================================================
; IAT/BARO Compensation
; ============================================================================
; Correct airflow estimate for air density changes

compensate_air_density:
        ; Load calculated airflow
        LDAA    CALCULATED_AIRFLOW
        
        ; IAT Compensation: Hotter air = less dense
        ; Correction factor = (IAT_nominal / IAT_actual)
        ; Simplified: subtract 1% per 5°C above 25°C
        
        LDAB    IAT_TEMP_RAM    ; Load IAT (in °C + 40 offset)
        SUBB    #65             ; Subtract nominal (25°C + 40)
        BLS     iat_comp_done   ; If <= nominal, no reduction
        
        LSRB                    ; Divide by 2
        LSRB                    ; Divide by 4 (approximate /5)
        SBA                     ; A = A - B (reduce airflow)
        
iat_comp_done:
        ; BARO Compensation: Lower pressure = less dense
        ; Correction factor = (BARO_actual / BARO_nominal)
        ; Nominal = 101 kPa, scale airflow proportionally
        
        LDAB    BARO_PRESSURE   ; Load BARO (in kPa)
        CMPB    #101            ; Compare to nominal
        BEQ     baro_comp_done  ; If equal, no adjustment
        BLO     baro_low        ; If lower, reduce airflow
        
        ; BARO high (forced induction?) - increase airflow
        SUBB    #101
        ABA                     ; A = A + (BARO - 101)
        BRA     baro_comp_done
        
baro_low:
        ; BARO low (high altitude) - reduce airflow
        LDAB    #101
        SUBB    BARO_PRESSURE   ; B = 101 - BARO
        SBA                     ; A = A - B
        
baro_comp_done:
        ; Store compensated airflow
        STAA    CALCULATED_AIRFLOW
        RTS

; ============================================================================
; Override MAF Airflow with Alpha-N Calculation
; ============================================================================
; Hook into fuel calculation routine to replace MAF reading

override_maf_airflow:
        ; Calculate Alpha-N load
        JSR     calculate_alpha_n_load
        
        ; Apply IAT/BARO compensation
        JSR     compensate_air_density
        
        ; Load compensated airflow
        LDAA    CALCULATED_AIRFLOW
        
        ; Store to airflow RAM location used by fuel calc
        ; (This address needs to be found via disassembly)
        STAA    $0180           ; Example airflow output address
        
        ; Clear any MAF error codes
        LDAA    M32_MAF_FAILURE
        ORAA    #MAF_FAILURE_BIT ; Keep failure bit set
        STAA    M32_MAF_FAILURE
        
        RTS

; ============================================================================
; Alpha-N Lookup Table (TPS% vs RPM → Airflow G/S)
; ============================================================================
; This table must be calibrated on dyno with wideband O2 sensor
; Initial values based on L36 3.8L V6 displacement and VE estimates

        ORG $A300          ; Alpha-N table storage ; FIXED: $22300 is a FILE OFFSET, not CPU addr. CPU=$A300 bank 4 (file 0x22300) [Enhanced-fix]

alpha_n_table:
        ; Columns: RPM (500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500, 8000)
        ; Rows: TPS% (0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%, 100%)
        ; Values: Airflow in G/S (0-255)

        ; TPS 0% (Idle)
        FCB     $03, $03, $03, $04, $04, $05, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F

        ; TPS 10% (Light throttle)
        FCB     $05, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $10, $11, $12, $13, $14

        ; TPS 20%
        FCB     $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $10, $12, $14, $16, $18, $1A, $1C, $1E, $20

        ; TPS 30%
        FCB     $0A, $0B, $0C, $0D, $0F, $11, $13, $15, $17, $19, $1B, $1D, $1F, $21, $23, $25, $27

        ; TPS 40%
        FCB     $0D, $0E, $10, $12, $14, $16, $18, $1A, $1D, $20, $23, $26, $29, $2C, $2F, $32, $35

        ; TPS 50% (Half throttle)
        FCB     $10, $12, $14, $17, $1A, $1D, $20, $23, $27, $2B, $2F, $33, $37, $3B, $3F, $43, $47

        ; TPS 60%
        FCB     $14, $16, $19, $1D, $21, $25, $29, $2D, $32, $37, $3C, $41, $46, $4B, $50, $55, $5A

        ; TPS 70%
        FCB     $18, $1B, $1F, $24, $29, $2E, $33, $38, $3E, $44, $4A, $50, $56, $5C, $62, $68, $6E

        ; TPS 80%
        FCB     $1D, $21, $26, $2C, $32, $38, $3E, $44, $4B, $52, $59, $60, $67, $6E, $75, $7C, $83

        ; TPS 90%
        FCB     $23, $28, $2E, $35, $3C, $43, $4A, $51, $59, $61, $69, $71, $79, $81, $89, $91, $99

        ; TPS 100% (WOT)
        FCB     $2A, $30, $37, $40, $49, $52, $5B, $64, $6E, $78, $82, $8C, $96, $A0, $AA, $B4, $BE

; ============================================================================
; TPS Calibration Constants
; ============================================================================

        ORG $A400          ; TPS calibration data ; FIXED: $22400 is a FILE OFFSET, not CPU addr. CPU=$A400 bank 4 (file 0x22400) [Enhanced-fix]

tps_cal_min_voltage:
        FCB     $05             ; 0.5V = 0% TPS (closed throttle)

tps_cal_max_voltage:
        FCB     $2D             ; 4.5V = 100% TPS (WOT)

tps_cal_idle_position:
        FCB     $02             ; 2% TPS = idle position

; ============================================================================
; Integration Points
; ============================================================================
;
; 1. STARTUP: Call force_maf_failure during ECU initialization
;    - Set M32 MAF Failure flag permanently
;    - Initialize default airflow
;
; 2. MAIN LOOP: Call override_maf_airflow every loop iteration
;    - Before fuel pulse width calculation
;    - Replace MAF reading with Alpha-N calculation
;
; 3. FUEL CALC: Ensure fuel routine uses $0180 (calculated airflow)
;    - Trace fuel calculation in disassembly
;    - Verify it reads from our output address
;
; 4. DIAGNOSTIC: Disable MAF-related DTCs
;    - P0101 - MAF range/performance
;    - P0102 - MAF low input
;    - P0103 - MAF high input
;
; ============================================================================
; XDF Entries Needed
; ============================================================================
;
; 1. Alpha-N Lookup Table @ $1A300
;    - Title: "Alpha-N Load Table (TPS% vs RPM)"
;    - Type: 2D table, 11 rows × 17 columns
;    - X-Axis: RPM (500-8000 in 500 RPM steps)
;    - Y-Axis: TPS% (0-100 in 10% steps)
;    - Units: Airflow (G/S)
;
; 2. TPS Calibration Min @ $1A400
;    - Title: "TPS Minimum Voltage (0% TPS)"
;    - Value: 0.5V (default), adjust per sensor
;
; 3. TPS Calibration Max @ $1A401
;    - Title: "TPS Maximum Voltage (100% TPS)"
;    - Value: 4.5V (default), adjust per sensor
;
; 4. TPS Idle Position @ $1A402
;    - Title: "TPS Idle Position (%)"
;    - Value: 2% (default), adjust after throttle body cleaning
;
; 5. Calculated Airflow Monitor @ $0180 (RAM)
;    - Title: "Alpha-N Calculated Airflow (Live)"
;    - Type: Display-only
;    - Units: G/S
;
; ============================================================================
; Calibration Procedure
; ============================================================================
;
; STEP 1: TPS Calibration
;   - Key ON, engine OFF
;   - Monitor TPS voltage with multimeter
;   - Closed throttle = 0.5V (adjust tps_cal_min_voltage)
;   - WOT = 4.5V (adjust tps_cal_max_voltage)
;   - If voltage out of range, replace TPS sensor
;
; STEP 2: Idle Calibration
;   - Start engine, warm to operating temperature
;   - Monitor calculated airflow (should be 3-4 G/S)
;   - Adjust TPS 0% row in Alpha-N table for stable idle
;   - Target AFR: 14.7:1 (stoichiometric)
;
; STEP 3: Part-Throttle Calibration
;   - Road test with wideband O2 sensor
;   - Log TPS%, RPM, AFR at various throttle positions
;   - Adjust Alpha-N table cells to achieve target AFR
;   - Target: 14.0-14.7:1 for cruise, 13.5-14.0:1 for acceleration
;
; STEP 4: WOT Calibration
;   - Dyno recommended (or safe road test area)
;   - Full throttle pulls at various RPMs
;   - Monitor AFR, adjust TPS 100% row
;   - Target: 12.5-13.0:1 for N/A V6
;   - Check for knock, retard timing if needed
;
; STEP 5: IAT/BARO Verification
;   - Test in different ambient conditions
;   - Hot day vs cold day (IAT compensation)
;   - Sea level vs high altitude (BARO compensation)
;   - Adjust compensation factors if needed
;
; ============================================================================
; Testing Notes
; ============================================================================
;
; ✅ ADVANTAGES of Alpha-N:
;   - No MAF sensor = one less failure point
;   - Works well for modified engines (big cams, ported heads)
;   - MAF can't measure large airflow changes accurately
;   - Cost savings (no expensive LS7 MAF upgrade needed)
;
; ⚠️ DISADVANTAGES:
;   - Requires extensive dyno tuning
;   - Less accurate than MAF at part-throttle cruise
;   - IAT/BARO compensation is approximate
;   - TPS failure = no fueling (need redundancy)
;
; 🔬 ALTERNATIVE: Speed-Density (MAP sensor)
;   - More accurate than Alpha-N
;   - Accounts for manifold pressure directly
;   - Requires MAP sensor installation ($50-100)
;   - See: ignition_cut_patch_v21_speed_density_ve_table.asm
;
; ============================================================================
; Safety Warnings
; ============================================================================
;
; ⚠️ CRITICAL: TPS sensor failure = LEAN CONDITION
;   - If TPS reads 0% (failed low), engine will run LEAN at WOT
;   - If TPS reads 100% (failed high), engine will flood at idle
;   - Monitor TPS signal integrity, replace at first sign of issues
;
; ⚠️ DO NOT USE on turbo/supercharged engines
;   - Boost pressure changes airflow independent of TPS
;   - Alpha-N cannot compensate for boost
;   - Use Speed-Density (MAP sensor) for forced induction
;
; ⚠️ WIDEBAND O2 SENSOR REQUIRED for calibration
;   - Stock narrowband cannot provide accurate AFR
;   - Budget: $200-400 for wideband kit
;   - Innovate LC-2, AEM X-Series, or similar
;
; ============================================================================
; References
; ============================================================================
;
; Gearhead_EFI Bins:
;   - R:\gearhead_efi_complete\bin\86tpi.bin
;   - R:\gearhead_efi_complete\bin\86TPI32.BIN
;   - R:\gearhead_efi_complete\bin\88CORV32.BIN
;   - R:\gearhead_efi_complete\bin\89vets.bin
;
; XDF Definitions:
;   - R:\gearhead_efi_complete\def\xdf\*TPI*.xdf (18 files)
;
; PCMHacking Topics:
;   - Topic 3892: VS 3 MAFless Tune - Possible?
;   - Topic 3392: GM V6 OBD2 PCM (Alpha-N references)
;
; ============================================================================
; END OF MAFless Alpha-N TPS Fallback PATCH
; ============================================================================
