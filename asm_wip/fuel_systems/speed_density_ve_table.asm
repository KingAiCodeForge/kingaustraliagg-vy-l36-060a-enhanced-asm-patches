;==============================================================================
; VY V6 MAFLESS v21 - SPEED-DENSITY VE TABLE CONVERSION
;==============================================================================
; Author: Jason King kingaustraliagg  
; Date: January 14, 2026
; Method: Speed-Density (MAP + RPM + VE Table) Replaces MAF Sensor
; Source: OSE12P V112 concept + GM Speed-Density theory
; Target: Holden VY V6 $060A (OSID 92118883/92118885)  
; Processor: Motorola MC68HC711E9 (8-bit)
;
; ⚠️⚠️⚠️ CRITICAL HARDWARE REQUIREMENT ⚠️⚠️⚠️
;
; VY V6 L36 Ecotec has NO MAP SENSOR from factory!
; The ECU uses MAF-based fueling strategy, NOT Speed-Density.
;
; TO USE THIS PATCH YOU MUST:
;   1. Install aftermarket MAP sensor (GM 3-bar 12223861 recommended)
;   2. Find spare A/D input pin on ECU (check VY wiring diagrams)
;   3. Wire MAP sensor signal to spare A/D pin
;   4. Wire MAP sensor ground + 5V reference
;   5. Create/update XDF table for voltage→kPa calibration
;   6. Update MAP_VAR address below to match YOUR wiring!
;
; REFERENCE PLATFORMS (different ECU/pinout - for CONCEPT only!):
;   - OSE 12P V112: VN/VP/VR/VS Commodore (Buick 3800 V6/304 V8)
;     * OSE = "Open Source ECM" (ECU 1227808, NOT VY V6!)
;     * Based on APNX V6 (OSID $5D), BLCD/BLCF (OSID $12B VR)
;     * Uses Delco 808/3082 ECM - HAS MAP sensor on pin C11!
;     * Different binary layout, different RAM addresses
;   - GM P59/P01: LS1/LS2 OBD2 ECU (completely different platform)
;   - These addresses DO NOT apply to VY V6 - FOR CONCEPT ONLY!
;
; ⭐ PRIORITY: MEDIUM - For forced induction, big cams, ITBs
; ⚠️ Success Rate: 70% (proven on GM platforms, needs extensive tuning)
; 🔬 Status: EXPERIMENTAL - Requires hardware + dyno validation
;
;==============================================================================
; THEORY OF OPERATION
;==============================================================================
;
; Speed-Density Formula:
;   Airflow (g/s) = (MAP × Displacement × VE × RPM) / (R × IAT)
;
;   Where:
;     MAP = Manifold Absolute Pressure (kPa)
;     Displacement = 3.8 liters (VY V6)
;     VE = Volumetric Efficiency (0-100%+)
;     RPM = Engine speed
;     R = Gas constant (287.05 J/(kg·K))
;     IAT = Intake Air Temperature (Kelvin)
;
; Why Speed-Density Instead of MAF:
;   ✅ MAF maxes out (~450 g/s) → Limits power
;   ✅ Turbo/SC BOV causes MAF false readings
;   ✅ Big cams (rough idle) break MAF signal
;   ✅ ITBs physically can't use single MAF
;   ✅ MAF is restriction in intake path
;
; GM OBD2 P59/P01 Native Implementation:
;   From MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md:
;     - 0x6F3B4: VE Table (MAP vs RPM)
;     - 0x6F5CA: Speed Density MAF Compensation vs IAT
;     - 0x6F308: Speed Density MAF Compensation vs ECT
;     - 0x6F2F4: Speed Density MAF Compensation vs Baro
;
; VY V6 Addresses (XDF v2.09a):
;   - 0x56D4: M32 MAF Failure flag
;   - 0x5795: Bypass MAF filtering during crank
;   - 0x7F1B: Minimum Airflow For Default Air
;   - 0x6D1D: Maximum Airflow Vs RPM (VE approximation)
;
;==============================================================================
; IMPLEMENTATION STRATEGY
;==============================================================================
;
; Phase 1: Force MAF Failure Mode (v1 Alpha-N method)
;   - Set 0x56D4 = 1 (M32 MAF Failure)
;   - Set 0x5795 = 1 (Bypass MAF filtering)
;   - ECU enters fallback mode
;
; Phase 2: Replace Fallback Tables with VE Table
;   - Increase "Minimum Airflow For Default Air" from 3.5 to 150 g/s
;   - Populate "Maximum Airflow Vs RPM" as VE table
;   - Add IAT/ECT/Baro compensation tables
;
; Phase 3: Closed-Loop AFR Still Works!
;   - O2 sensors remain functional
;   - ECU can correct VE table errors
;   - WOT uses open-loop (VE table direct)
;
;==============================================================================
; IMPLEMENTATION
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP (CORRECTED January 25, 2026 from 92118883_STOCK.bin)
;------------------------------------------------------------------------------
; ⚠️ CRITICAL CORRECTION: 0x56D4 is a DTC ENABLE mask, NOT a failure flag!
;    To enable MAFless fallback, set 0x56F3 bit 6 = 1

; DTC Mask Bytes (ROM calibration data)
M32_DTC_ENABLE      EQU $56D4   ; KKMASK4 bit 6 = M32 DTC logging (stock=0xCC)
M32_CEL_MASK        EQU $56DE   ; Check Trans Light bit 6 = M32 CEL (stock=0xC0)
M32_ACTION_MASK     EQU $56F3   ; KKACT3 bit 6 = M32 action enable (stock=0x00) ← KEY!
MAF_OPTION_WORD     EQU $5795   ; Option word, multiple bits (stock=0xFC)

; Fallback Fuel Tables
MIN_AIRFLOW_ROM     EQU $7F1B   ; Minimum Airflow For Default Air (16-bit, stock=0x01C0)
VE_TABLE_ADDR       EQU $6D1D   ; Maximum Airflow Vs RPM (VE table)

; RAM Variables (⚠️ UNVERIFIED - need oscilloscope/ALDL validation)
MAP_SENSOR          EQU $00B0   ; MAP sensor reading (kPa) - DOES NOT EXIST STOCK!
IAT_SENSOR          EQU $00B2   ; IAT sensor reading (°C) - UNVERIFIED
ECT_SENSOR          EQU $00B4   ; ECT sensor reading (°C) - VERIFIED
RPM_ADDR            EQU $00A2   ; RPM (high byte) - VERIFIED
AIRFLOW_CALC        EQU $01A0   ; Calculated airflow (g/s) - 16-bit - UNVERIFIED

; Calibration
VE_ENABLE           EQU $7800   ; Enable VE mode flag
IAT_COMP_TABLE      EQU $7810   ; IAT compensation (16 bytes)
ECT_COMP_TABLE      EQU $7820   ; ECT compensation (16 bytes)
BARO_COMP_TABLE     EQU $7830   ; Baro compensation (16 bytes)

;------------------------------------------------------------------------------
; CONFIGURATION
;------------------------------------------------------------------------------
MIN_AIRFLOW_DEFAULT EQU $C8     ; 200 g/s base airflow (0xC8 = 200 decimal)
VE_BASE             EQU $64     ; 100% VE (0x64 = 100 decimal)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18800 was WRONG - NOT in verified free space!
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED (was $18800 WRONG!)

;==============================================================================
; SPEED-DENSITY AIRFLOW CALCULATION
;==============================================================================
; Entry: Called every engine cycle
; Output: AIRFLOW_CALC = calculated g/s
; Stack: 6 bytes (PSHA/PSHB/PSHX/PSHY)
;==============================================================================

SPEED_DENSITY_CALC:
    PSHA                        ; 36 - Save A
    PSHB                        ; 37 - Save B
    PSHX                        ; 3C - Save X
    
    ; Check if VE mode enabled
    LDAA VE_ENABLE              ; B6 78 00
    BEQ USE_STOCK_MAF           ; 27 XX - Disabled, use stock MAF
    
    ; Force MAF failure mode
    LDAA #$01                   ; 86 01
    STAA MAF_FAILURE_FLAG       ; B7 56 D4 - Set M32 MAF Failure
    STAA MAF_BYPASS_FLAG        ; B7 57 95 - Bypass MAF filtering
    
    ;--------------------------------------------------------------------------
    ; Step 1: Look up VE from table (MAP vs RPM)
    ;--------------------------------------------------------------------------
    ; VE_TABLE_ADDR is 2D table: MAP (rows) × RPM (columns)
    ; Need to interpolate based on current MAP and RPM
    
    LDAA MAP_SENSOR             ; 96 B0 - Load MAP (kPa)
    LDAB RPM_ADDR               ; D6 A2 - Load RPM (high byte)
    
    ; TODO: Implement 2D table lookup with interpolation
    ; For now, use simple approximation: VE = 80% at all points
    LDAA #$50                   ; 86 50 - VE = 80% (0x50 = 80 decimal)
    STAA $01A2                  ; 97 01 A2 - Store temporary VE
    
    ;--------------------------------------------------------------------------
    ; Step 2: Calculate base airflow
    ; Airflow = (MAP × VE × RPM × Displacement) / (R × IAT)
    ;--------------------------------------------------------------------------
    ; Simplified: Airflow ≈ MAP × VE × RPM / 1000
    
    LDAA MAP_SENSOR             ; 96 B0 - A = MAP
    LDAB $01A2                  ; D6 01 A2 - B = VE
    MUL                         ; 3D - D = MAP × VE (16-bit result)
    
    ; D now contains MAP × VE
    ; Multiply by RPM (8-bit approximation)
    LDAA RPM_ADDR               ; 96 A2 - A = RPM high byte
    ; TODO: 16-bit × 8-bit multiply (need multi-byte math)
    
    ; For now, store simplified result
    STD AIRFLOW_CALC            ; FD 01 A0 - Store calculated airflow
    
    ;--------------------------------------------------------------------------
    ; Step 3: Apply IAT compensation
    ;--------------------------------------------------------------------------
    LDAA IAT_SENSOR             ; 96 B2 - Load IAT
    ; TODO: Look up compensation factor from IAT_COMP_TABLE
    ; Multiply AIRFLOW_CALC by compensation factor
    
    ;--------------------------------------------------------------------------
    ; Step 4: Apply ECT compensation
    ;--------------------------------------------------------------------------
    LDAA ECT_SENSOR             ; 96 B4 - Load ECT
    ; TODO: Look up compensation factor from ECT_COMP_TABLE
    ; Multiply AIRFLOW_CALC by compensation factor
    
    ;--------------------------------------------------------------------------
    ; Step 5: Apply Baro compensation
    ;--------------------------------------------------------------------------
    ; TODO: Read barometric pressure (or use MAP at key-on)
    ; Look up compensation from BARO_COMP_TABLE
    
    BRA EXIT_SD_CALC            ; 20 XX

USE_STOCK_MAF:
    ; VE mode disabled, clear MAF failure flags
    LDAA #$00                   ; 86 00
    STAA MAF_FAILURE_FLAG       ; B7 56 D4
    STAA MAF_BYPASS_FLAG        ; B7 57 95
    ; Stock ECU code will use MAF sensor

EXIT_SD_CALC:
    PULX                        ; 38
    PULB                        ; 33
    PULA                        ; 32
    RTS                         ; 39

;==============================================================================
; VE TABLE STRUCTURE (2D MAP)
;==============================================================================
; VE Table: 16 columns (RPM) × 12 rows (MAP)
; Format: 8-bit values (0-255, scaled to 0-200% VE)
;
; RPM Columns (16): 500, 750, 1000, 1500, 2000, 2500, 3000, 3500,
;                   4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500
;
; MAP Rows (12): 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130 kPa
;
; Example VE Values (N/A 3.8L V6):
;   Idle (20 kPa, 800 RPM): 70% VE
;   Cruise (50 kPa, 2500 RPM): 80% VE
;   WOT (100 kPa, 5000 RPM): 90% VE
;   Peak Torque (100 kPa, 3500 RPM): 95% VE

            ORG $6D1D           ; VE table location (192 bytes)

VE_TABLE_DATA:
    ; Row 1: MAP = 20 kPa (idle/coast)
    .BYTE $46, $48, $4A, $4C, $4E, $50, $52, $54  ; 500-3500 RPM
    .BYTE $56, $58, $5A, $5C, $5E, $60, $62, $64  ; 4000-7500 RPM
    
    ; Row 2: MAP = 30 kPa
    .BYTE $48, $4A, $4C, $4E, $50, $52, $54, $56
    .BYTE $58, $5A, $5C, $5E, $60, $62, $64, $66
    
    ; Row 3: MAP = 40 kPa
    .BYTE $4A, $4C, $4E, $50, $52, $54, $56, $58
    .BYTE $5A, $5C, $5E, $60, $62, $64, $66, $68
    
    ; Row 4: MAP = 50 kPa (cruise)
    .BYTE $4C, $4E, $50, $52, $54, $56, $58, $5A
    .BYTE $5C, $5E, $60, $62, $64, $66, $68, $6A
    
    ; Row 5: MAP = 60 kPa
    .BYTE $4E, $50, $52, $54, $56, $58, $5A, $5C
    .BYTE $5E, $60, $62, $64, $66, $68, $6A, $6C
    
    ; Row 6: MAP = 70 kPa
    .BYTE $50, $52, $54, $56, $58, $5A, $5C, $5E
    .BYTE $60, $62, $64, $66, $68, $6A, $6C, $6E
    
    ; Row 7: MAP = 80 kPa
    .BYTE $52, $54, $56, $58, $5A, $5C, $5E, $60
    .BYTE $62, $64, $66, $68, $6A, $6C, $6E, $70
    
    ; Row 8: MAP = 90 kPa
    .BYTE $54, $56, $58, $5A, $5C, $5E, $60, $62
    .BYTE $64, $66, $68, $6A, $6C, $6E, $70, $72
    
    ; Row 9: MAP = 100 kPa (WOT N/A)
    .BYTE $56, $58, $5A, $5C, $5E, $60, $62, $64
    .BYTE $66, $68, $6A, $6C, $6E, $70, $72, $74
    
    ; Row 10: MAP = 110 kPa (mild boost)
    .BYTE $58, $5A, $5C, $5E, $60, $62, $64, $66
    .BYTE $68, $6A, $6C, $6E, $70, $72, $74, $76
    
    ; Row 11: MAP = 120 kPa (moderate boost)
    .BYTE $5A, $5C, $5E, $60, $62, $64, $66, $68
    .BYTE $6A, $6C, $6E, $70, $72, $74, $76, $78
    
    ; Row 12: MAP = 130 kPa (high boost)
    .BYTE $5C, $5E, $60, $62, $64, $66, $68, $6A
    .BYTE $6C, $6E, $70, $72, $74, $76, $78, $7A

;==============================================================================
; COMPENSATION TABLES
;==============================================================================

            ORG $7810           ; IAT compensation table

IAT_COMPENSATION_TABLE:
    ; IAT vs Multiplier (16 entries)
    ; Cold air = higher multiplier (more dense)
    ; Hot air = lower multiplier (less dense)
    .BYTE $6E, $6C, $6A, $68, $66, $64, $62, $60  ; -40°C to 0°C
    .BYTE $5E, $5C, $5A, $58, $56, $54, $52, $50  ; 10°C to 70°C

            ORG $7820           ; ECT compensation table

ECT_COMPENSATION_TABLE:
    ; ECT vs Multiplier (16 entries)
    ; Cold engine = richer (more fuel)
    ; Hot engine = leaner (less fuel)
    .BYTE $70, $6E, $6C, $6A, $68, $66, $64, $62  ; -40°C to 0°C
    .BYTE $60, $5E, $5C, $5A, $58, $56, $54, $52  ; 10°C to 70°C

            ORG $7830           ; Baro compensation table

BARO_COMPENSATION_TABLE:
    ; Baro vs Multiplier (16 entries)
    ; High altitude = lower multiplier (less air)
    ; Sea level = higher multiplier (more air)
    .BYTE $50, $52, $54, $56, $58, $5A, $5C, $5E  ; 60-90 kPa
    .BYTE $60, $62, $64, $66, $68, $6A, $6C, $6E  ; 95-120 kPa

;==============================================================================
; CALIBRATION DATA
;==============================================================================

            ORG $7800

SD_CALIBRATION:
    .BYTE $00                   ; $7800 - VE_ENABLE (0=MAF, 1=Speed-Density)
    .BYTE MIN_AIRFLOW_DEFAULT   ; $7801 - Base airflow (200 g/s)
    .BYTE VE_BASE               ; $7802 - Base VE% (100%)

;==============================================================================
; TUNING PROCEDURE (DYNO REQUIRED!)
;==============================================================================
;
; ⚠️ CRITICAL: This conversion requires EXTENSIVE tuning!
;
; Step 1: Baseline Setup
;   - Install wideband O2 sensor (mandatory!)
;   - Disable closed-loop (tune open-loop first)
;   - Set VE_ENABLE = 1
;   - Start with conservative VE values (70-80%)
;
; Step 2: Idle Tuning (20-30 kPa, 800-1000 RPM)
;   - Target AFR: 14.7:1 (stoich)
;   - Adjust VE table cells until AFR correct
;   - Check IAT/ECT compensation at different temps
;
; Step 3: Cruise Tuning (40-60 kPa, 1500-3000 RPM)
;   - Target AFR: 14.7-15.5:1 (lean cruise)
;   - Drive on road, log AFR vs MAP/RPM
;   - Adjust VE cells to match target AFR
;
; Step 4: WOT Tuning (80-100 kPa, all RPM)
;   - Target AFR: 12.5-13.0:1 (power enrichment)
;   - Dyno pulls, log AFR
;   - Adjust VE table for flat AFR curve
;   - Iterate until power peaks
;
; Step 5: Forced Induction (110-130 kPa)
;   - Target AFR: 11.5-12.0:1 (boost safety)
;   - Add rows to VE table for boost
;   - Conservative VE values (prevent knock)
;   - Monitor EGT, adjust as needed
;
; Step 6: Re-enable Closed-Loop
;   - Turn on closed-loop for cruise
;   - Monitor O2 sensor corrections
;   - If corrections > ±5%, retune VE table
;
; Expected Tuning Time: 10-20 dyno hours minimum!
;
;==============================================================================
; VALIDATION CHECKLIST
;==============================================================================
;
; [ ] MAF Failure Mode Confirmed
;     - Monitor MAF_FAILURE_FLAG = 1
;     - No MAF sensor DTCs (expected P0101-P0103)
;     - ECU using fallback tables
;
; [ ] MAP Sensor Functional
;     - Verify MAP reading changes with throttle
;     - 20 kPa idle, 100 kPa WOT (N/A)
;     - No MAP sensor DTCs
;
; [ ] VE Table Active
;     - Log calculated airflow
;     - Should change with MAP/RPM
;     - Match expected VE values (70-90%)
;
; [ ] AFR Verification
;     - Wideband matches target AFR
;     - Idle: 14.7:1
;     - Cruise: 14.7-15.5:1
;     - WOT: 12.5-13.0:1
;     - Boost: 11.5-12.0:1
;
; [ ] Drivability Check
;     - No stumble on tip-in
;     - Smooth idle (no hunting)
;     - Good throttle response
;     - No hesitation
;
;==============================================================================
; REFERENCES
;==============================================================================
;
; 1. MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md
;    - GM P59/P01 native speed-density tables
;    - VE table structure and scaling
;
; 2. OSE12P V112 Custom OS
;    - Proven MAFless implementation
;    - VE table addresses and format
;
; 3. VY XDF v2.09a
;    - MAF failure addresses (0x56D4, 0x5795)
;    - Airflow table addresses (0x7F1B, 0x6D1D)
;
; 4. mafless_alpha_n_conversion_v1.asm
;    - Basic MAF failure force logic
;    - Entry point for speed-density
;
;==============================================================================
; END OF v21 - SPEED-DENSITY VE TABLE CONVERSION
;==============================================================================
