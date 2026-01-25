;==============================================================================
; VY V6 COLD MAPS ONLY PATCH v1.0 - FORCE COLD SPARK ALWAYS
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 25, 2026
; Status: 🔬 EXPERIMENTAL - Derived from BMW MS42/MS43 "Map Reduction" patch
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
;==============================================================================
; PURPOSE
;==============================================================================
;
; This patch forces the ECU to ALWAYS use cold spark compensation tables,
; regardless of actual coolant temperature. This simplifies tuning by:
;
;   1. Reducing the number of interacting tables to tune
;   2. Using the conservative "cold" maps as the primary tuning target
;   3. Providing predictable behavior at all temperatures
;
; BASED ON: BMW MS42/MS43 Community Patchlist "Map Reduction Force Cold Maps"
;   - Category 0x8: Map Reduction
;   - Forces ECU to use tco_1 (cold temperature) tables
;   - Sets ip_fac_* multipliers to constant value
;
;==============================================================================
; HOW VY V6 COLD SPARK WORKS (STOCK BEHAVIOR)
;==============================================================================
;
; Stock ECU calculates spark timing as:
;
;   Final Spark = Main Spark Table + (Cold Spark Offset × Cold Spark Multiplier)
;
; Where:
;   - Main Spark Table = Base timing (RPM × Load 3D table)
;   - Cold Spark Offset = Temperature compensation (0x646D, 7×14 table)
;   - Cold Spark Multiplier = ECT-based scalar (0x64CF, 6 elements)
;
; Cold Spark Multiplier vs ECT (VERIFIED from VX-VY_V6_$060A_Enhanced_v1.0a.bin):
;   -40°C → 1.00 (0xFF)   Cold engine, full offset applied
;   -16°C → 1.00 (0xFF)   Still cold
;     8°C → 1.00 (0xFF)   Still cold (stock runs cold maps to 8°C!)
;    32°C → 0.67 (0xAB)   Partial warmup
;    56°C → 0.33 (0x55)   Nearly warm
;    80°C → 0.00 (0x00)   Hot engine, NO cold offset
;
; PROBLEM: At operating temp (80°C), Cold Spark Offset has NO effect!
;          You must tune BOTH Main Spark AND Cold Spark tables.
;
;==============================================================================
; PATCH STRATEGY
;==============================================================================
;
; Set Cold Spark Multiplier to 1.00 (0xFF) at ALL temperatures:
;
;   -40°C → 1.00 (0xFF)   No change
;   -16°C → 1.00 (0xFF)   No change
;     8°C → 1.00 (0xFF)   No change (already 0xFF in stock!)
;    32°C → 1.00 (0xFF)   ← Changed from 0xAB
;    56°C → 1.00 (0xFF)   ← Changed from 0x55
;    80°C → 1.00 (0xFF)   ← Changed from 0x00 (KEY CHANGE!)
;
; RESULT: Cold Spark Offset ALWAYS applies, even when engine is hot.
;         Tune Cold Spark Offset Table as your primary timing adjustment.
;         this could be wrong and is a assumption more research is needed before testing.
;==============================================================================
; BINARY PATCHES (Apply with hex editor)
;==============================================================================

;------------------------------------------------------------------------------
; COLD SPARK MULTIPLIER TABLE - Force all values to 1.0
;------------------------------------------------------------------------------
; Address: 0x64CF (6 bytes)
; Stock:   FF FF FF AB 55 00  ← VERIFIED from Enhanced v1.0a bin and 92118883_STOCK.bin
; Patched: FF FF FF FF FF FF

COLD_SPARK_MULT_BASE    EQU $64CF   ; Start of Cold Spark Multiplier table
COLD_SPARK_MULT_SIZE    EQU 6       ; 6 temperature breakpoints

; Only 3 bytes need to change (first 3 already 0xFF):
; PATCH_ADDR_1            EQU $64D1   ; 8°C   - ALREADY 0xFF in stock!
PATCH_ADDR_1            EQU $64D2   ; 32°C  (0xAB → 0xFF)
PATCH_ADDR_2            EQU $64D3   ; 56°C  (0x55 → 0xFF)
PATCH_ADDR_3            EQU $64D4   ; 80°C  (0x00 → 0xFF) ← Most important!

;==============================================================================
; OPTIONAL: ASM ROUTINE TO FORCE COLD SPARK FLAG
;==============================================================================
; If the binary patch alone doesn't work, this routine ensures the cold
; spark enable flag is always set.
;
; Hook: Call at startup or in main loop
; Size: 10 bytes
; Free space: 0x14468+ (verified)
;------------------------------------------------------------------------------

            ORG $14468          ; Verified free space

;==============================================================================
; FORCE_COLD_SPARK - Ensure cold spark compensation is always enabled
;==============================================================================
; Entry: None (called at ECU startup)
; Exit:  Cold spark multiplier table forced to 1.0
; Stack: 2 bytes
; Size:  18 bytes
;==============================================================================

COLD_SPARK_ENABLE_FLAG  EQU $5F8A   ; Bit 7 = Add Cold Spark to Main

FORCE_COLD_SPARK:
    PSHA                            ; 36 - Save A
    PSHX                            ; 3C - Save X
    
    ; Step 1: Ensure "Add Cold Spark" flag is set (bit 7 of $5F8A)
    LDAA    COLD_SPARK_ENABLE_FLAG  ; B6 5F 8A
    ORAA    #$80                    ; 8A 80 - Set bit 7
    STAA    COLD_SPARK_ENABLE_FLAG  ; B7 5F 8A
    
    ; Step 2: Force Cold Spark Multiplier table to all 0xFF
    ; This ensures cold spark applies at ALL temperatures
    LDX     #COLD_SPARK_MULT_BASE   ; CE 64 CF
    LDAA    #$FF                    ; 86 FF
    
FORCE_COLD_LOOP:
    STAA    0,X                     ; A7 00 - Store 0xFF
    INX                             ; 08
    CPX     #COLD_SPARK_MULT_BASE+COLD_SPARK_MULT_SIZE  ; 8C 64 D5
    BNE     FORCE_COLD_LOOP         ; 26 F8
    
    PULX                            ; 38 - Restore X
    PULA                            ; 32 - Restore A
    RTS                             ; 39

;==============================================================================
; TABLES AFFECTED BY THIS PATCH
;==============================================================================
;
; PRIMARY TUNING TABLE (after patch):
;   "Cold Spark Offset Table" @ 0x646D
;   - 7 rows (RPM: 400-1600)
;   - 14 columns (MGC: 50-700 mg/cyl)
;   - Units: Degrees offset (-35 to +55°)
;   - Formula: X/256*90-35
;
; STILL USED (no change needed):
;   "Main Spark Table" - Base timing, cold offset adds to this
;   "Knock Retard" - Still active for knock protection
;   "Timing Retard Vs Airflow" - Still active for load compensation
;
; UNAFFECTED:
;   - Fuel calculations (still uses MAF, O2 feedback)
;   - Idle spark control
;   - Transmission shift timing
;   - Knock control
;
;==============================================================================
; VERIFICATION
;==============================================================================
;
; After applying patch, use TunerPro/datalog to verify:
;
; 1. Cold Spark Multiplier = 1.0 at ALL temperatures
;    - Watch "Cold Spark Multiplier" in datalog
;    - Should read 1.00 regardless of ECT
;
; 2. Cold Spark Offset is applied at 80°C
;    - Compare Final Spark to Main Spark
;    - Difference should equal Cold Spark Offset table value
;
; 3. ECT still reads correctly
;    - Engine temp gauge works normally
;    - Cooling fans operate at correct temp
;
;==============================================================================
; TUNING WORKFLOW
;==============================================================================
;
; 1. Apply binary patch (4 bytes at 0x64D1-0x64D4)
; 2. Flash modified bin to ECU
; 3. Open in TunerPro with v2.09a XDF
; 4. Tune "Cold Spark Offset Table" for your engine:
;    - Positive values = MORE advance (use cautiously)
;    - Negative values = LESS advance (safer)
;    - Zero = no offset from main spark
; 5. Leave Main Spark table as your base timing
; 6. Test at operating temp - verify Cold Offset applies
;
;==============================================================================
; REVERTING THE PATCH
;==============================================================================
;
; To restore stock behavior (VERIFIED from Enhanced v1.0a bin):
;
; Address  Patched  Stock   Temp   
; -------  -------  -----   ----
; 0x64D2   0xFF     0xAB    ; 32°C multiplier  
; 0x64D3   0xFF     0x55    ; 56°C multiplier
; 0x64D4   0xFF     0x00    ; 80°C multiplier
;
; NOTE: 0x64CF-0x64D1 are already 0xFF in stock (below 8°C)!
;
;==============================================================================
; END OF PATCH
;==============================================================================

            END

;------------------------------------------------------------------------------
; PATCH BYTES SUMMARY (for hex editor)
;------------------------------------------------------------------------------
;
; Cold Spark Multiplier - Force All 1.0:
; Address: 0x64D2 (3 bytes only - first 3 already 0xFF!)
; Stock:   AB 55 00
; Patched: FF FF FF
;
; Full table for reference (0x64CF, 6 bytes):
; Stock:   FF FF FF AB 55 00
; Patched: FF FF FF FF FF FF
;
; ASM Routine (optional):
; Address: 0x14468 (18 bytes)
; Bytes:   36 3C B6 5F 8A 8A 80 B7 5F 8A CE 64 CF 86 FF A7
;          00 08 8C 64 D5 26 F8 38 32 39
;
; VERIFIED from VX-VY_V6_$060A_Enhanced_v1.0a.bin on January 25, 2026
;
;------------------------------------------------------------------------------
