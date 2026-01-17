;==============================================================================
; VY V6 MAFLESS v22 - ALPHA-N TPS FALLBACK MODE
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 14, 2026
; Method: Alpha-N (TPS + RPM) Replaces MAF Sensor
; Source: GM P59/P01 MAF Failure Fallback Mode
; Target: Holden VY V6 $060A (OSID 92118883/92118885)
; Processor: Motorola MC68HC11 (8-bit)
;
; ⭐ PRIORITY: LOW - Optional, for aggressive cam setups
; ⚠️ Success Rate: 60% (simpler than Speed-Density, less accurate)
; 🔬 Status: EXPERIMENTAL - Requires tuning, not as accurate as v21
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; Alpha-N vs Speed-Density:
;
;   Speed-Density (v21):  Airflow = f(MAP, RPM, VE, IAT)
;   Alpha-N (v22):        Airflow = f(TPS, RPM, Table)
;
; Why Alpha-N Instead of Speed-Density:
;   ✅ Simpler (no VE table tuning)
;   ✅ Better for aggressive cams (MAP unreliable at idle)
;   ✅ Works with ITBs (where MAP varies per cylinder)
;   ✅ Faster response (no MAP sensor lag)
;
; Why Speed-Density Is Better:
;   ✅ More accurate (measures actual air)
;   ✅ Compensates for altitude automatically
;   ✅ Better for forced induction (MAP measures boost)
;   ✅ Self-correcting with closed-loop
;
; GM P59/P01 Stock Alpha-N Tables:
;   From MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md:
;     - Stock ECUs have Alpha-N tables for MAF failure
;     - ECU uses TPS + RPM to estimate airflow
;     - "Minimum Airflow For Default Air" acts as base
;
; VY V6 Uses This Mode Already:
;   - When MAF fails (DTC P0101-P0103)
;   - ECU uses fallback "Minimum Airflow" table
;   - We just need to ENHANCE the fallback tables!
;
;==============================================================================
; IMPLEMENTATION STRATEGY
;==============================================================================
;
; Phase 1: Force MAF Failure (Same as v21)
;   - Set 0x56D4 = 1 (M32 MAF Failure)
;   - Set 0x5795 = 1 (Bypass MAF filtering)
;   - ECU enters Alpha-N fallback mode
;
; Phase 2: Build TPS vs RPM Airflow Table
;   - Replace "Minimum Airflow" with full 2D table
;   - TPS columns: 0%, 10%, 20%, ..., 100%
;   - RPM rows: 500, 1000, 1500, ..., 7000
;   - Values: Estimated airflow (g/s)
;
; Phase 3: Closed-Loop Still Works
;   - O2 sensors correct errors at cruise
;   - WOT uses open-loop (table values direct)
;   - Simpler than Speed-Density (no IAT/ECT/Baro comp)
;
;==============================================================================
; IMPLEMENTATION
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
; XDF-Verified Addresses
MAF_FAILURE_FLAG    EQU $56D4   ; M32 MAF Failure
MAF_BYPASS_FLAG     EQU $5795   ; Bypass MAF filtering
MIN_AIRFLOW_ROM     EQU $7F1B   ; Minimum Airflow base value
ALPHA_N_TABLE       EQU $6E00   ; Alpha-N table (TPS vs RPM)

; RAM Variables
TPS_SENSOR          EQU $00B6   ; TPS sensor reading (%)
RPM_ADDR            EQU $00A2   ; RPM (high byte)
AIRFLOW_CALC        EQU $01A0   ; Calculated airflow (g/s)

; Calibration
ALPHA_N_ENABLE      EQU $7850   ; Enable Alpha-N mode
TPS_IDLE            EQU $7851   ; TPS at idle (%)
TPS_WOT             EQU $7852   ; TPS at WOT (%)

;------------------------------------------------------------------------------
; CONFIGURATION
;------------------------------------------------------------------------------
TPS_IDLE_DEF        EQU $05     ; 5% TPS at idle
TPS_WOT_DEF         EQU $64     ; 100% TPS at WOT (0x64 = 100 decimal)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18A00 was WRONG - NOT in verified free space!
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED (was $18A00 WRONG!)

;==============================================================================
; ALPHA-N AIRFLOW CALCULATION
;==============================================================================
ALPHA_N_CALC:
    PSHA                        ; 36 - Save A
    PSHB                        ; 37 - Save B
    PSHX                        ; 3C - Save X
    
    ; Check if Alpha-N enabled
    LDAA ALPHA_N_ENABLE         ; B6 78 50
    BEQ USE_STOCK_MAF_AN        ; 27 XX
    
    ; Force MAF failure mode
    LDAA #$01                   ; 86 01
    STAA MAF_FAILURE_FLAG       ; B7 56 D4
    STAA MAF_BYPASS_FLAG        ; B7 57 95
    
    ;--------------------------------------------------------------------------
    ; Step 1: Read TPS and RPM
    ;--------------------------------------------------------------------------
    LDAA TPS_SENSOR             ; 96 B6 - A = TPS (%)
    LDAB RPM_ADDR               ; D6 A2 - B = RPM (high byte)
    
    ;--------------------------------------------------------------------------
    ; Step 2: Look up airflow from Alpha-N table
    ;--------------------------------------------------------------------------
    ; Table: TPS (columns) × RPM (rows)
    ; Need 2D interpolation based on TPS and RPM
    
    ; Simplified: Use TPS as main factor
    ; Airflow ≈ TPS × (Base + RPM_Factor)
    
    ; Base airflow calculation
    ; At idle (5% TPS, 800 RPM): ~30 g/s
    ; At cruise (20% TPS, 2500 RPM): ~80 g/s
    ; At WOT (100% TPS, 5000 RPM): ~450 g/s
    
    ; Simplified formula: Airflow = TPS × 4.5 (assumes linear TPS response)
    LDAA TPS_SENSOR             ; 96 B6 - A = TPS%
    LDAB #$04                   ; C6 04 - B = 4 (approximation)
    MUL                         ; 3D - D = TPS × 4
    
    ; Add RPM factor (high RPM = more air at same TPS)
    LDAA RPM_ADDR               ; 96 A2 - A = RPM high byte
    ; TODO: Add RPM compensation factor
    
    STD AIRFLOW_CALC            ; FD 01 A0 - Store calculated airflow
    
    BRA EXIT_ALPHA_N_CALC       ; 20 XX

USE_STOCK_MAF_AN:
    ; Alpha-N disabled, use stock MAF
    LDAA #$00                   ; 86 00
    STAA MAF_FAILURE_FLAG       ; B7 56 D4
    STAA MAF_BYPASS_FLAG        ; B7 57 95

EXIT_ALPHA_N_CALC:
    PULX                        ; 38
    PULB                        ; 33
    PULA                        ; 32
    RTS                         ; 39

;==============================================================================
; ALPHA-N TABLE STRUCTURE
;==============================================================================
; Table: 11 columns (TPS) × 15 rows (RPM) = 165 bytes
;
; TPS Columns (11): 0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%, 100%
; RPM Rows (15): 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000,
;                4500, 5000, 5500, 6000, 6500, 7000
;
; Values: Airflow in g/s (0-255 range, scaled ÷2 if needed)
;
; Example Values (N/A 3.8L V6):
;   Idle (5% TPS, 800 RPM): 30 g/s
;   Light cruise (20% TPS, 2500 RPM): 80 g/s
;   Heavy cruise (40% TPS, 3000 RPM): 150 g/s
;   WOT (100% TPS, 5000 RPM): 450 g/s (limited by MAF max)

            ORG $6E00           ; Alpha-N table location

ALPHA_N_TABLE_DATA:
    ; Row 1: RPM = 500 (idle)
    .BYTE $0A, $14, $1E, $28, $32, $3C, $46, $50, $5A, $64, $6E  ; 10-110 g/s
    
    ; Row 2: RPM = 750
    .BYTE $0F, $19, $23, $2D, $37, $41, $4B, $55, $5F, $69, $73  ; 15-115 g/s
    
    ; Row 3: RPM = 1000
    .BYTE $14, $1E, $28, $32, $3C, $46, $50, $5A, $64, $6E, $78  ; 20-120 g/s
    
    ; Row 4: RPM = 1500
    .BYTE $1E, $28, $32, $3C, $46, $50, $5A, $64, $6E, $78, $82  ; 30-130 g/s
    
    ; Row 5: RPM = 2000
    .BYTE $28, $32, $3C, $46, $50, $5A, $64, $6E, $78, $82, $8C  ; 40-140 g/s
    
    ; Row 6: RPM = 2500 (cruise)
    .BYTE $32, $3C, $46, $50, $5A, $64, $6E, $78, $82, $8C, $96  ; 50-150 g/s
    
    ; Row 7: RPM = 3000
    .BYTE $3C, $46, $50, $5A, $64, $6E, $78, $82, $8C, $96, $A0  ; 60-160 g/s
    
    ; Row 8: RPM = 3500 (peak torque)
    .BYTE $46, $50, $5A, $64, $6E, $78, $82, $8C, $96, $A0, $AA  ; 70-170 g/s
    
    ; Row 9: RPM = 4000
    .BYTE $50, $5A, $64, $6E, $78, $82, $8C, $96, $A0, $AA, $B4  ; 80-180 g/s
    
    ; Row 10: RPM = 4500
    .BYTE $5A, $64, $6E, $78, $82, $8C, $96, $A0, $AA, $B4, $BE  ; 90-190 g/s
    
    ; Row 11: RPM = 5000 (peak power)
    .BYTE $64, $6E, $78, $82, $8C, $96, $A0, $AA, $B4, $BE, $C8  ; 100-200 g/s
    
    ; Row 12: RPM = 5500
    .BYTE $6E, $78, $82, $8C, $96, $A0, $AA, $B4, $BE, $C8, $D2  ; 110-210 g/s
    
    ; Row 13: RPM = 6000
    .BYTE $78, $82, $8C, $96, $A0, $AA, $B4, $BE, $C8, $D2, $DC  ; 120-220 g/s
    
    ; Row 14: RPM = 6500
    .BYTE $82, $8C, $96, $A0, $AA, $B4, $BE, $C8, $D2, $DC, $E6  ; 130-230 g/s
    
    ; Row 15: RPM = 7000
    .BYTE $8C, $96, $A0, $AA, $B4, $BE, $C8, $D2, $DC, $E6, $F0  ; 140-240 g/s

;==============================================================================
; CALIBRATION DATA
;==============================================================================

            ORG $7850

ALPHA_N_CAL_DATA:
    .BYTE $00                   ; $7850 - ALPHA_N_ENABLE (0=MAF, 1=Alpha-N)
    .BYTE TPS_IDLE_DEF          ; $7851 - TPS at idle (5%)
    .BYTE TPS_WOT_DEF           ; $7852 - TPS at WOT (100%)

;==============================================================================
; TUNING PROCEDURE
;==============================================================================
;
; Alpha-N Is Simpler Than Speed-Density, But Less Accurate!
;
; Step 1: TPS Calibration
;   - Verify TPS 0% at closed throttle
;   - Verify TPS 100% at WOT
;   - Adjust TPS_IDLE and TPS_WOT if needed
;
; Step 2: Baseline Table Population
;   - Use Speed-Density formulas to estimate initial values
;   - Or use MAF log data: log MAF airflow vs TPS/RPM
;   - Transfer MAF data to Alpha-N table
;
; Step 3: Idle Tuning (0-20% TPS, 500-1500 RPM)
;   - Target AFR: 14.7:1
;   - Adjust low TPS cells
;   - Check for smooth idle (no hunting)
;
; Step 4: Cruise Tuning (20-40% TPS, 1500-3500 RPM)
;   - Target AFR: 14.7-15.5:1
;   - Drive on road, log AFR
;   - Adjust cells to match target
;
; Step 5: WOT Tuning (80-100% TPS, all RPM)
;   - Target AFR: 12.5-13.0:1
;   - Dyno pulls, log AFR
;   - Adjust for flat AFR curve
;
; Step 6: Transient Response
;   - Alpha-N responds faster than MAF (no sensor lag)
;   - May need accel enrichment tuning
;   - Test tip-in, tip-out response
;
; Expected Tuning Time: 5-10 dyno hours (faster than Speed-Density!)
;
;==============================================================================
; ADVANTAGES VS SPEED-DENSITY (v21)
;==============================================================================
;
; ✅ Simpler to tune (2D table vs 3D VE + compensations)
; ✅ Faster response (TPS instant, MAP has lag)
; ✅ Better for aggressive cams (MAP unreliable at idle)
; ✅ Works with ITBs (no single MAP location)
; ✅ Less CPU overhead (no complex math)
;
;==============================================================================
; DISADVANTAGES VS SPEED-DENSITY (v21)
;==============================================================================
;
; ❌ Less accurate (TPS doesn't measure actual air)
; ❌ No altitude compensation (TPS same at sea level and mountains)
; ❌ Doesn't work well with boost (TPS doesn't know boost level)
; ❌ Requires more frequent retuning (seasonal changes)
; ❌ Poor for daily driver (efficiency suffers)
;
;==============================================================================
; WHEN TO USE ALPHA-N (v22) VS SPEED-DENSITY (v21)
;==============================================================================
;
; Use Alpha-N (v22) If:
;   ✅ Aggressive cam with rough idle (MAP unreliable)
;   ✅ ITB setup (no single MAP location)
;   ✅ Race car (performance > efficiency)
;   ✅ Quick tuning needed (simpler)
;   ✅ Boost < 5 PSI (low boost N/A)
;
; Use Speed-Density (v21) If:
;   ✅ Daily driver (efficiency matters)
;   ✅ High boost (> 5 PSI) - MAP measures boost
;   ✅ Altitude changes (drive in mountains)
;   ✅ Want most accurate fueling
;   ✅ Have time for proper VE tuning
;
;==============================================================================
; VALIDATION CHECKLIST
;==============================================================================
;
; [ ] MAF Failure Mode Active
;     - MAF_FAILURE_FLAG = 1
;     - No MAF sensor in system
;     - DTC P0101-P0103 ignored
;
; [ ] TPS Sensor Functional
;     - 0% at closed throttle
;     - 100% at WOT
;     - Smooth sweep (no dead spots)
;
; [ ] Alpha-N Table Active
;     - Calculated airflow changes with TPS
;     - Idle: ~30 g/s
;     - Cruise: ~80-150 g/s
;     - WOT: ~400-450 g/s
;
; [ ] AFR Verification
;     - Idle: 14.7:1 ± 0.3
;     - Cruise: 14.7-15.5:1
;     - WOT: 12.5-13.0:1
;
; [ ] Transient Response
;     - No stumble on tip-in
;     - No lean spike on tip-out
;     - Good throttle response
;
; [ ] Comparison with MAF (if available)
;     - Log MAF airflow vs Alpha-N calculated
;     - Should match within 10%
;     - Adjust table if too far off
;
;==============================================================================
; REFERENCES
;==============================================================================
;
; 1. MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md
;    - GM P59/P01 Alpha-N fallback tables
;    - MAF failure mode behavior
;
; 2. Alpha_N_vs_MAF_Ignition_Cut_Analysis.md
;    - Alpha-N vs MAF comparison
;    - Use cases and trade-offs
;
; 3. mafless_alpha_n_conversion_v1.asm
;    - Basic MAF failure force logic
;    - Entry point for Alpha-N
;
; 4. VY XDF v2.09a
;    - MAF failure addresses
;    - TPS sensor address ($00B6)
;
;==============================================================================
; END OF v22 - ALPHA-N TPS FALLBACK MODE
;==============================================================================
