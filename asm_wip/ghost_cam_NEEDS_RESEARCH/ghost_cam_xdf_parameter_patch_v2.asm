;==============================================================================
; VY V6 GHOST CAM v2 - XDF PARAMETER MULTIPLIER APPROACH
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Status: 🔬 NEEDS RESEARCH - ROM addresses need verification
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: EXPERIMENTAL
;
;==============================================================================
; APPROACH: MODIFY XDF PARAMETERS IN ROM
;==============================================================================
;
; Instead of complex ASM hook, directly modify the idle spark parameters
; in ROM to create ghost cam behavior. This is simpler but less flexible.
;
; From Enhanced XDF v2.09a and ghost_lumpy_idle_cam_asm.md research:
;
; Stock values create smooth idle (2-5° swing)
; Ghost cam values create lopey idle (30-45° swing)
;
;==============================================================================
; TARGET PARAMETERS AND GHOST CAM VALUES
;==============================================================================
;
; | Address | Parameter                           | Stock   | Ghost Cam |
; |---------|-------------------------------------|---------|-----------|
; | 0x6524  | IAC Spark Correction Lower ECT      | 40°C    | 100°C+    |
; | 0x6525  | KSARPMHI (High RPM Spark Mult)      | 0.04    | 0.20-0.25 |
; | 0x6527  | KSARPMLO (Low RPM Spark Mult)       | 0.04    | 0.20-0.25 |
; | 0x6529  | RPM Error Limit for Spark Correction| 512 RPM | 200 RPM   |
; | 0x652B  | KSCORLIM (Spark Correction Limit)   | 15°     | 30-35°    |
; | 0x6536  | Idle Spark Advance Table            | 18°     | 8-10°     |
; | 0x6541  | Retarded Idle Spark Table           | 10°     | 2-5°      |
;
;==============================================================================
; BINARY PATCHES (Direct ROM modification)
;==============================================================================

;------------------------------------------------------------------------------
; PATCH 1: KSARPMHI - High RPM Spark Correction Multiplier
;------------------------------------------------------------------------------
; Address: 0x6525 (file offset may differ - verify!)
; Stock: 0x04 (0.04 × 100 = 4 DEG%/RPM)
; Ghost: 0x14 (0.20 × 100 = 20 DEG%/RPM) - 5× more aggressive
;
; Explanation: When RPM is ABOVE target by X, retard spark by X × 0.20°
; Example: 100 RPM overspeed × 0.20 = 20° retard
;
KSARPMHI_ADDR       EQU $6525
KSARPMHI_STOCK      EQU $04
KSARPMHI_GHOST      EQU $14         ; 0x14 = 20 = 0.20 DEG%/RPM

;------------------------------------------------------------------------------
; PATCH 2: KSARPMLO - Low RPM Spark Correction Multiplier
;------------------------------------------------------------------------------
; Address: 0x6527
; Stock: 0x04
; Ghost: 0x14 - match KSARPMHI for symmetric response
;
KSARPMLO_ADDR       EQU $6527
KSARPMLO_STOCK      EQU $04
KSARPMLO_GHOST      EQU $14

;------------------------------------------------------------------------------
; PATCH 3: RPM Error Limit for Spark Correction
;------------------------------------------------------------------------------
; Address: 0x6529
; Stock: 0x0200 (512 RPM) - wide deadband
; Ghost: 0x00C8 (200 RPM) - narrow deadband, engages faster
;
RPM_ERROR_LIMIT_ADDR    EQU $6529
RPM_ERROR_LIMIT_STOCK   EQU $0200   ; 512 RPM
RPM_ERROR_LIMIT_GHOST   EQU $00C8   ; 200 RPM

;------------------------------------------------------------------------------
; PATCH 4: KSCORLIM - Idle Spark Correction Limit
;------------------------------------------------------------------------------
; Address: 0x652B
; Stock: 0x0F (15°) - maximum spark swing allowed
; Ghost: 0x20 (32°) - allow bigger swings for lope effect
;
KSCORLIM_ADDR       EQU $652B
KSCORLIM_STOCK      EQU $0F         ; 15°
KSCORLIM_GHOST      EQU $20         ; 32°

;------------------------------------------------------------------------------
; PATCH 5: Lower Base Idle Spark (Table modification)
;------------------------------------------------------------------------------
; Address: 0x6536 (start of Idle Spark Advance Vs Coolant table)
; Stock: ~18° across temperature range
; Ghost: ~10° - lower base so retard cycles create weak combustion
;
; Table structure: 8 bytes, one per temp breakpoint
;
IDLE_SPARK_TABLE_ADDR   EQU $6536
IDLE_SPARK_STOCK        EQU $24     ; 18° in Delco 0.5° per bit encoding
IDLE_SPARK_GHOST        EQU $14     ; 10°

;------------------------------------------------------------------------------
; PATCH 6: Enable Retarded Idle Spark Mode
;------------------------------------------------------------------------------
; There's a flag "1 = Enable Retarded Idle Spark" in the XDF
; Address needs verification - may enable alternate timing path
;
; From XDF: "1 = Enable Retarded Idle Spark" - ❌ Not Set (stock)
; For ghost cam: Set to 1 to use retarded idle spark table
;
RETARDED_IDLE_ENABLE    EQU $????   ; TODO: Find this address

;==============================================================================
; FUEL COMPENSATION - CRITICAL FOR NO BACKFIRES
;==============================================================================
;
; Without fuel compensation, ghost cam = backfires/afterburner/flame throw each lope!
;
; Options:
;
; 1. Increase injector offset at idle (adds ~5-10% fuel all the time)
;    - Pro: Simple XDF change
;    - Con: Runs rich all the time at idle
;
; 2. Richen Open Loop Idle AFR table
;    - Address: Line 3088 in XDF
;    - Stock: 14.7 AFR warm, 12.0 AFR cold
;    - Ghost: 13.5 AFR warm, 11.5 AFR cold
;
; 3. Reduce idle VE cells by 5-10%
;    - Forces ECU to calculate more fuel
;    - Works in closed-loop
;
; 4. ASM patch to add fuel on misfire detection (most complex)
;
;==============================================================================
; IDLE TARGET ADJUSTMENT (BMW METHOD)
;==============================================================================
;
; From BMW MS42 research - flat 850 RPM warm idle helps ghost cam stability
;
; DESIRED IDLE SPEED (PARK) VS COOLANT TEMP table:
; Address: XDF Line 2565
;
; Stock:
;   -40°C  -20°C   0°C   20°C   40°C   60°C   80°C  100°C
;    1300   1150   950    800    750    700    650    650
;
; Ghost Cam (BMW style - flat warm):
;   -40°C  -20°C   0°C   20°C   40°C   60°C   80°C  100°C
;    1300   1150  1000    900    900    900    900    900
;
; Higher stable target = more headroom for oscillation
;
;==============================================================================
; HEX PATCH SUMMARY
;==============================================================================
;
; Apply these byte changes to VX-VY_V6_$060A_Enhanced_v1.0a.bin:
;
; | Offset | Stock | Ghost | Parameter                    |
; |--------|-------|-------|------------------------------|
; | 0x6525 | 0x04  | 0x14  | KSARPMHI                     |
; | 0x6527 | 0x04  | 0x14  | KSARPMLO                     |
; | 0x6529 | 0x02  | 0x00  | RPM Error Limit (high byte)  |
; | 0x652A | 0x00  | 0xC8  | RPM Error Limit (low byte)   |
; | 0x652B | 0x0F  | 0x20  | KSCORLIM                     |
;
; Plus table modifications for idle spark and idle RPM targets
;
;==============================================================================
; WARNING: ALL ADDRESSES NEED VERIFICATION
;==============================================================================
;
; The addresses above are from XDF analysis but may be:
; - XDF line numbers, not actual ROM addresses
; - Relative to calibration start, not file start
; - Subject to Enhanced v1.0a binary structure
;
; Before applying:
; 1. Open binary in TunerPro with v2.09a XDF
; 2. Find each parameter
; 3. Note actual file offset
; 4. Verify stock value matches expected
; 5. Apply patch and test on bench FIRST
;
;==============================================================================
; END OF FILE
;==============================================================================
