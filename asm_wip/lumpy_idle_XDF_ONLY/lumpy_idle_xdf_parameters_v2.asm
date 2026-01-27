;==============================================================================
; VY V6 LUMPY IDLE v2 - XDF PARAMETER APPROACH (NO ASM REQUIRED)
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Status: 🔬 PARTIALLY VERIFIED - Addresses from VY V6 XDF v2.09a
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; TERMINOLOGY:
;   "Lumpy Idle" = THIS FILE - XDF parameter changes only, slow ~1Hz lope
;   "Ghost Cam"  = Fast aggressive lopey sound (method TBD - see ghost_cam_ASM_PATCH/)
;
; ⚠️ CORRECTION (Jan 27, 2026): Rhysk94 (RKGarage / Rhys Kirkham) states that
; ghost cam on these PCMs is NOT done with timing - timing does not get touched.
; Topic 8605 (VY L67 Enhanced Idle Timing) is about idle spark XDFs, NOT ghost cam.
; The actual ghost cam method needs clarification from Rhysk94.
;
; NO ASM PATCHING REQUIRED - just modify values in TunerPro!
; ⚠️ WARNING: EXPERIMENTAL - NOT TESTED ON HARDWARE
;
;==============================================================================
; APPROACH: MODIFY XDF PARAMETERS IN ROM (VIA TUNERPRO)
;==============================================================================
;
; Directly modify the idle spark parameters in ROM to create lumpy idle.
; VY V6 XDF v2.09a verified addresses used below.
; ALL THESE PARAMETERS ARE ALREADY EXPOSED IN v2.09a XDF!
;
; VERIFIED PARAMETERS FROM VY V6 XDF:
; - Idle Spark Advance vs Coolant Temp: 0x6536 (11 cells)
; - Retarded Idle Spark vs Coolant Temp: 0x6541 (11 cells)
; - Enable Retarded Idle Spark flag: 0x652C bit 2
;
; IDLE SPARK CORRECTION PARAMETERS (from XDF v2.09a):
; - 0x6524: IAC Spark Correction Lower Coolant Threshold (~40°C stock)
; - 0x6525: High RPM Spark Correction Multiplier (KSARPMHI) - 0.04 DEG%/RPM
; - 0x6527: Low RPM Spark Correction Multiplier (KSARPMLO) - 0.04 DEG%/RPM
; - 0x6529: RPM Error Limit For Spark Advance Correction - 512 RPM stock
; - 0x652B: Idle Spark Correction Limit (KSCORLIM) - ~15° stock
;
; Encoding: x/256*90-35 (degrees)
;   0x3C = -13.4 deg, 0x60 = 0 deg, 0x84 = 14.3 deg, 0xA0 = 26.4 deg
;
;==============================================================================
; VERIFIED VY V6 IDLE SPARK TABLE (0x6536-0x6540)
;==============================================================================
;
; Stock Values (from binary):
;   0x6536: 0xA0 = 26.4 deg  (-40C)
;   0x6537: 0xA0 = 26.4 deg  (-20C)
;   0x6538: 0xA0 = 26.4 deg  (0C)
;   0x6539: 0xA0 = 26.4 deg  (20C)
;   0x653A: 0x9D = 25.4 deg  (40C)
;   0x653B: 0x94 = 22.2 deg  (50C)
;   0x653C: 0x8A = 18.6 deg  (60C)
;   0x653D: 0x80 = 15.0 deg  (70C)
;   0x653E: 0x79 = 12.5 deg  (80C)
;   0x653F: 0x79 = 12.5 deg  (90C)
;   0x6540: 0x79 = 12.5 deg  (100C)
;
IDLE_SPARK_TABLE_ADDR   EQU $6536   ; VERIFIED - 11 cells
IDLE_SPARK_TABLE_SIZE   EQU 11

;==============================================================================
; VERIFIED VY V6 RETARDED IDLE SPARK TABLE (0x6541-0x654B)
;==============================================================================
;
; Stock Values (from binary):
;   0x6541: 0x64 = 1.4 deg   (-40C)
;   0x6542: 0x64 = 1.4 deg   (-20C)
;   0x6543: 0x64 = 1.4 deg   (0C)
;   0x6544: 0x64 = 1.4 deg   (20C)
;   0x6545: 0x64 = 1.4 deg   (40C)
;   0x6546: 0x64 = 1.4 deg   (50C)
;   0x6547: 0x64 = 1.4 deg   (60C)
;   0x6548: 0x64 = 1.4 deg   (70C)
;   0x6549: 0x64 = 1.4 deg   (80C)
;   0x654A: 0x64 = 1.4 deg   (90C)
;   0x654B: 0x64 = 1.4 deg   (100C)
;
RETARD_SPARK_TABLE_ADDR EQU $6541   ; VERIFIED - 11 cells
RETARD_SPARK_TABLE_SIZE EQU 11

;==============================================================================
; VERIFIED VY V6 RETARDED IDLE ENABLE FLAG (0x652C bit 2)
;==============================================================================
;
; XDF Name: "1 = Enable Retarded Idle Spark"
; Address: 0x652C, Bit 2 (mask 0x04)
; Stock: 0 (disabled)
; Ghost Cam: 1 (enabled) - ECU will use retarded idle spark table
;
RETARD_IDLE_FLAG_ADDR   EQU $652C   ; VERIFIED
RETARD_IDLE_FLAG_BIT    EQU $04     ; Bit 2 mask

;==============================================================================
; GHOST CAM STRATEGY - SIMPLE XDF PARAMETER MODIFICATION
;==============================================================================
;
; The simplest ghost cam approach for VY V6:
;
; 1. ENABLE Retarded Idle Spark (0x652C bit 2 = 1)
;    - This activates the alternate retarded idle spark table
;
; 2. LOWER the Idle Spark Advance table (0x6536)
;    - Stock warm idle: 12.5 deg → Ghost: 5-8 deg
;    - Lower base timing = weak combustion = RPM drop
;
; 3. RAISE the gap between normal and retarded tables
;    - Stock: 26 deg normal, 1.4 deg retarded = 25 deg swing
;    - Ghost: keep swing but lower both bases
;
; The ECU oscillates between tables based on RPM error, creating lope.
;
;==============================================================================
; HEX PATCH SUMMARY - VERIFIED ADDRESSES
;==============================================================================
;
; Apply these byte changes to VX-VY_V6_$060A_Enhanced_v1.0a.bin:
;
; PATCH 1: Enable Retarded Idle Spark
; | Offset | Stock | Ghost | Description                      |
; |--------|-------|-------|----------------------------------|
; | 0x652C | 0x??  | |=0x04 | Set bit 2 to enable retarded idle|
;
; PATCH 2: Lower Warm Idle Spark (last 3 cells: 80C, 90C, 100C)
; | Offset | Stock | Ghost | Description                      |
; |--------|-------|-------|----------------------------------|
; | 0x653E | 0x79  | 0x60  | 12.5 deg → 0 deg (80C)           |
; | 0x653F | 0x79  | 0x60  | 12.5 deg → 0 deg (90C)           |
; | 0x6540 | 0x79  | 0x60  | 12.5 deg → 0 deg (100C)          |
;
; PATCH 3: Lower Retarded Spark (make it more negative for bigger swing)
; | Offset | Stock | Ghost | Description                      |
; |--------|-------|-------|----------------------------------|
; | 0x6549 | 0x64  | 0x54  | 1.4 deg → -5 deg (80C)           |
; | 0x654A | 0x64  | 0x54  | 1.4 deg → -5 deg (90C)           |
; | 0x654B | 0x64  | 0x54  | 1.4 deg → -5 deg (100C)          |
;
; Encoding formula: value = (degrees + 35) * 256 / 90
;   0 deg = 0x63, -5 deg = 0x54, -10 deg = 0x47, 12.5 deg = 0x79
;
;==============================================================================
; WARNING: FUEL ENRICHMENT MAY BE NEEDED
;==============================================================================
;
; Without fuel compensation, ghost cam can cause backfires.
; 
; Options in TunerPro:
; 1. Increase "Injector Offset" at idle by 0.1-0.2ms
; 2. Richen "Open Loop AFR" table at idle cells
; 3. Lower VE table idle cells by 5-10% (forces ECU to add fuel)
;
;==============================================================================
; END OF FILE
;==============================================================================
