; ============================================================================
; VY V6 E85 Dual-Map Toggle Patch (v24)
; ============================================================================
; Purpose: Manual E85/Petrol fuel map toggle via button input
; Inspired by: MS43X flex_fuel_sensor_diagnostics.asm + OSE 12P multi-fuel maps, needs the opcode and the address check carefully.
; Author: Adapted from BMW MS43X and OSE 12P concepts
; Date: 2026-01-15
; Status: UNTESTED - Proof of concept
; ============================================================================
;
; CONCEPT:
; - Uses power button or unused pin as E85/Petrol toggle
; - Switches between two complete fuel/timing map sets
; - No E85 sensor required (manual toggle)
; - Based on OSE 12P's 3-fuel map structure (Petrol/E85/Methanol)
;
; BUTTON INPUT OPTIONS:
; 1. Power button (if available on VY dash)
; 2. Chr0m3's unused pin discovery (check PCMHacking for pinout)
; 3. Repurpose A/C request input (if A/C deleted)
; 4. Add external momentary switch to clutch port
;
; MAP SWITCHING STRATEGY:
; - E85 requires ~30% more fuel (stoich 9.765:1 vs 14.7:1)
; - E85 can tolerate more timing advance (+3-5 degrees)
; - VE table, spark table, and fuel enrichment all need adjustment
;
; MEMORY REQUIREMENTS:
; - Need to store 2 complete map sets (double XDF size)
; - Option 1: Store in unused calibration space
; - Option 2: Bank switching between two bins
; - Option 3: Offset pointers to alternate tables
;
; RISKS:
; - Wrong map selection = severe lean/rich condition
; - Need visual indicator (shift light LED?)
; - Power loss could reset to default map
;
; ============================================================================

        ORG     $0C468          ; Verified free space region

; ============================================================================
; Constants and Addresses
; ============================================================================

; Button Input Configuration
BUTTON_PORT     EQU     $1008   ; Port D - clutch/button input
BUTTON_MASK     EQU     $10     ; Bit 4 of Port D (example)

; E85 Map Flag Storage
E85_FLAG_RAM    EQU     $0201   ; RAM flag: 0=Petrol, 1=E85

; Original Petrol Map Addresses (from XDF)
VE_TABLE_PETROL         EQU     $6D1D   ; Maximum Airflow Vs RPM (petrol)
SPARK_TABLE_PETROL      EQU     $19813  ; Base spark timing (petrol)
FUEL_ENRICH_PETROL      EQU     $7F1B   ; Fuel enrichment (petrol)

; E85 Map Addresses (need to allocate in free space or upper bank)
VE_TABLE_E85            EQU     $1A000  ; E85 VE table (to be defined)
SPARK_TABLE_E85         EQU     $1A100  ; E85 spark table
FUEL_ENRICH_E85         EQU     $1A200  ; E85 enrichment

; Fuel Stoichiometry Constants
PETROL_STOICH   EQU     147     ; 14.7:1 * 10
E85_STOICH      EQU     98      ; 9.765:1 * 10 (E85 stoich ratio)

; ============================================================================
; E85 Toggle Detection (Called from main loop or timer ISR)
; ============================================================================

e85_toggle_check:
        ; Read button input
        LDAA    BUTTON_PORT     ; Load Port D status
        ANDA    #BUTTON_MASK    ; Mask button bit
        BEQ     button_not_pressed
        
        ; Button pressed - toggle E85 flag
        LDAA    E85_FLAG_RAM
        EORA    #$01            ; Toggle bit 0
        STAA    E85_FLAG_RAM
        
        ; Debounce delay (wait for button release)
        JSR     debounce_delay
        
button_not_pressed:
        RTS

; ============================================================================
; Debounce Delay
; ============================================================================

debounce_delay:
        LDX     #$FFFF          ; Load max counter
debounce_loop:
        DEX                     ; Decrement
        BNE     debounce_loop   ; Loop until zero
        RTS

; ============================================================================
; Fuel Map Pointer Override (Hook into fuel calculation)
; ============================================================================
; This needs to intercept the fuel table lookup routine and redirect
; to E85 tables when E85_FLAG_RAM is set

fuel_map_selector:
        LDAA    E85_FLAG_RAM    ; Check E85 flag
        BEQ     use_petrol_map  ; 0 = Petrol
        
        ; Use E85 maps
        LDX     #VE_TABLE_E85
        STX     $017D           ; Store E85 VE table pointer (RAM location TBD)
        LDD     #SPARK_TABLE_E85
        STD     $017F           ; Store E85 spark table pointer
        BRA     map_selected
        
use_petrol_map:
        ; Use Petrol maps (stock)
        LDX     #VE_TABLE_PETROL
        STX     $017D
        LDD     #SPARK_TABLE_PETROL
        STD     $017F
        
map_selected:
        RTS

; ============================================================================
; E85 Fuel Correction Factor
; ============================================================================
; Multiply fuel pulse width by E85/Petrol stoich ratio

e85_fuel_correction:
        LDAA    E85_FLAG_RAM
        BEQ     no_correction   ; Petrol = no correction
        
        ; Calculate E85 correction: (14.7 / 9.765) = ~1.505
        ; Approximation: multiply by 3/2 (1.5x)
        
        LDD     $0199           ; Load current fuel pulse width (example RAM)
        LSLD                    ; Multiply by 2
        ADDD    $0199           ; Add original (now 3x)
        LSRD                    ; Divide by 2 (now 1.5x)
        STD     $0199           ; Store corrected pulse width
        
no_correction:
        RTS

; ============================================================================
; Visual Indicator (Flash shift light to show E85 mode)
; ============================================================================

e85_indicator:
        LDAA    E85_FLAG_RAM
        BEQ     indicator_off
        
        ; Flash shift light LED
        LDAA    PORTA
        ORAA    #$20            ; Set bit 5 (example shift light pin)
        STAA    PORTA
        BRA     indicator_done
        
indicator_off:
        LDAA    PORTA
        ANDA    #$DF            ; Clear bit 5
        STAA    PORTA
        
indicator_done:
        RTS

; ============================================================================
; E85 Map Data (Placeholder - needs calibration on dyno)
; ============================================================================
; These would be complete 2D/3D tables copied from XDF and adjusted for E85
; 
; E85 VE Table Example (17 cells RPM-based):
;   - Increase fuel flow ~30% across all cells
;   - Compensate for lower energy density of ethanol
;
; E85 Spark Table Example:
;   - Add 3-5 degrees advance (E85 has higher octane)
;   - Monitor knock, adjust per cylinder if needed
;
; E85 Enrichment:
;   - Cold start: E85 needs MORE enrichment (harder to vaporize)
;   - WOT: E85 can run richer safely (cooling effect)

        ORG     $1A000          ; E85 map storage (example address)

ve_table_e85:
        ; Placeholder - copy from petrol VE and multiply by 1.3
        FCB     $00, $00, $00, $00, $00, $00, $00, $00
        FCB     $00, $00, $00, $00, $00, $00, $00, $00
        ; ... (17 cells total)

spark_table_e85:
        ; Placeholder - copy from petrol spark and add 3-5 degrees
        FCB     $00, $00, $00, $00, $00, $00, $00, $00
        ; ... (full spark table)

; ============================================================================
; Integration Points (Where to hook this code)
; ============================================================================
;
; 1. MAIN LOOP: Call e85_toggle_check every loop iteration
;    - Find main loop in disassembly (continuous execution)
;    - Insert JSR $0C468 (this patch address)
;
; 2. FUEL CALC: Hook fuel_map_selector into fuel calculation
;    - Find fuel pulse width calculation routine
;    - Redirect table lookups through our selector
;
; 3. SPARK CALC: Hook into spark timing lookup
;    - Find spark advance calculation
;    - Use E85 spark table when flag set
;
; 4. STARTUP: Initialize E85_FLAG_RAM to 0 (Petrol default)
;    - Hook into ECU initialization routine
;    - Set $0201 = 0x00
;
; ============================================================================
; XDF Entries Needed
; ============================================================================
;
; 1. E85 VE Table @ $1A000 (or allocate in free space)
;    - Title: "E85 Maximum Airflow Vs RPM"
;    - Copy structure from $6D1D, scale by 1.3x
;
; 2. E85 Spark Table @ $1A100
;    - Title: "E85 Base Spark Timing"
;    - Copy from $19813, add 3-5 degrees
;
; 3. E85 Fuel Enrichment @ $1A200
;    - Title: "E85 Cold Start / WOT Enrichment"
;    - Increase cold start by 50%, WOT by 20%
;
; 4. E85 Toggle Button Config @ $0C468
;    - Title: "E85 Map Toggle - Button Port/Mask"
;    - Configurable port address and bit mask
;
; 5. E85 Flag Status @ $0201 (RAM)
;    - Title: "Current Fuel Map (0=Petrol, 1=E85)"
;    - Display-only, shows active map
;
; ============================================================================
; Testing Procedure
; ============================================================================
;
; 1. BENCH TEST: Verify button toggles flag
;    - Monitor RAM $0201 with datalogger
;    - Confirm toggle on each button press
;
; 2. IDLE TEST: Start on petrol map, verify stable idle
;    - Switch to E85 map, should run slightly rich (safe)
;    - Monitor AFR, should be ~12-13:1 on petrol fuel
;
; 3. DYNO CALIBRATION: Tune E85 maps on actual E85 fuel
;    - Start with 1.3x fuel multiplier
;    - Adjust VE table cells to achieve target AFR
;    - Add timing until knock detected, back off 2 degrees
;
; 4. ROAD TEST: Verify no lean conditions during transitions
;    - DO NOT switch maps while driving (only at idle/stopped)
;    - Confirm indicator light works
;
; ============================================================================
; Safety Warnings
; ============================================================================
;
; ⚠️ CRITICAL: Switching maps with wrong fuel in tank = ENGINE DAMAGE
;    - Petrol map on E85 = LEAN (melted pistons)
;    - E85 map on petrol = RICH (fouled plugs, wash down cylinders)
;
; ⚠️ NO AUTOMATIC DETECTION without E85 sensor
;    - Driver MUST remember which fuel is in tank
;    - Consider labeling fuel door with current map
;
; ⚠️ COLD START on E85 requires MORE fuel, not less
;    - E85 has lower vapor pressure than petrol
;    - Cold start enrichment must be increased significantly
;
; ============================================================================
; END OF E85 DUAL-MAP TOGGLE PATCH
; ============================================================================
