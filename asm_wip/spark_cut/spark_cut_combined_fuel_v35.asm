; ═══════════════════════════════════════════════════════════════════
; UPDATE HISTORY:
;   2026-01-28: RAM Address Fix - $01A0 → $0046 bit 7
;   2026-01-31: Crank Period Fix - $017B → $194C (TIC3 ISR verified)
;   2026-02-09: Enhanced v1.0a ground truth: hook=0x101E1 STD $017B, bank 1 free $C468-$FFBF
; ═══════════════════════════════════════════════════════════════════

;==============================================================================
; VY V6 IGNITION CUT v35 - COMBINED FUEL+SPARK CUT (CLEAN CUT)
;==============================================================================
;
; ⚠️ EXPERIMENTAL - Combined fuel and spark cut concept
; ⚠️ Uses $01A0 for LIMITER_FLAG - UNVERIFIED!
; ✅ See v38 for verified production code using $0046 bit 7
;
; This is an advanced concept - cutting both fuel and spark simultaneously.
; Needs more research on injector pulse width RAM locations.
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 17, 2026
; Method: Simultaneous Fuel and Spark Cut (Speeduino PROTECT_CUT_BOTH style)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; BASED ON SPEEDUINO'S PROTECT_CUT_BOTH:
;   From speeduino.ino:
;   ```cpp
;   case PROTECT_CUT_BOTH:
;       ignitionChannelsOn = 0;
;       fuelChannelsOn = 0;
;       disableAllIgnSchedules();
;       disableAllFuelSchedules();
;       break;
;   ```
;
; Status: 🔬 EXPERIMENTAL - Hybrid of VY stock + Speeduino method
;
; WHY COMBINED CUT?
;   ✅ No unburnt fuel in exhaust (cleaner)
;   ✅ Lower cat/O2 sensor stress than spark-only cut
;   ✅ No flames (safer for race classes requiring it)
;   ✅ Smoother engine stop (no partial burns)
;   ⚠️  No pops and bangs (if you want those, use v32/v34)
;
; IMPLEMENTATION:
;   Stock VY = Fuel cut only (via calibration tables at 0x77DE/0x77DF)
;   This version = Coordinates BOTH fuel cut + spark cut
;
;   Method:
;   1. At RPM limit: Set flag for spark cut
;   2. Fuel cut: Lower fuel cut threshold in RAM to match (if possible)
;   3. OR: Hook injector pulse width calculation to zero it
;
; COMPLEXITY WARNING:
;   This is MORE COMPLEX than pure spark cut because we need to:
;   - Find injector pulse width RAM location
;   - Zero it at limiter (or hook the calculation)
;   - Coordinate timing with spark cut
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: 8-bit RPM/25 ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: crank period storage ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

; INJECTOR PULSE WIDTH - NEEDS VERIFICATION
; These are guesses based on typical Delco RAM layout:
INJ_PW_RAM EQU $0180       ; ⚠️ UNVERIFIED: Injector pulse width (µs) ; Verified: CALC_AIRFLOW_REF (1 ref both) [Enhanced-fix]
INJ_PW_FINAL    EQU $0182       ; ⚠️ UNVERIFIED: Final calculated PW

; FUEL CUT TABLE IN CALIBRATION (verified from XDF)
FUEL_CUT_HIGH   EQU $77DE       ; ✅ VERIFIED: Fuel cut RPM high (drive)
FUEL_CUT_LOW    EQU $77DF       ; ✅ VERIFIED: Fuel cut RPM low (drive)

;------------------------------------------------------------------------------
; RPM THRESHOLDS (8-bit scaled)
;------------------------------------------------------------------------------
RPM_HIGH        EQU $F0         ; 240 × 25 = 6000 RPM (cut activation)
RPM_LOW         EQU $EC         ; 236 × 25 = 5900 RPM (resume)

FAKE_PERIOD     EQU $3E80       ; Spark cut fake period

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ Code below still uses TST/STAA/CLR $01A0 — needs rewrite to BRSET/BSET/BCLR $46,$80
; See spark_cut_chr0m3_method_VERIFIED_v38.asm for correct implementation
;

            ORG $0C500          ; ✅ VERIFIED: Free space ; Bank 1 (file 0x0C500). Free banks: [1], used: [2, 3]. 15192 bytes free [Enhanced-fix]

;==============================================================================
; COMBINED CUT HANDLER - FUEL AND SPARK
;==============================================================================
; Entry: D = calculated 3X period
; Exit:  D = real or fake period, fuel PW may also be zeroed
;
; Strategy:
;   Option A: Use existing fuel cut + add spark cut (simplest)
;   Option B: Override both in single handler (this implementation)
;
;==============================================================================

COMBINED_CUT_HANDLER:
    PSHA                        ; 36       Save period high
    PSHB                        ; 37       Save period low
    
    ;--------------------------------------------------------------------------
    ; CHECK LIMITER STATE
    ;--------------------------------------------------------------------------
    LDAA    LIMITER_FLAG        ; 96 A0    Load limiter state
    CMPA    #$01                ; 81 01    Is limiter active?
    BEQ     CHECK_DEACTIVATE    ; 27 xx    Yes → check if should resume
    
    ;--------------------------------------------------------------------------
    ; LIMITER OFF - Check if should activate
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25
    CMPA    #RPM_HIGH           ; 81 F0    >= 6000 RPM?
    BCS     EXIT_NORMAL         ; 25 xx    No → normal operation
    
    ; ACTIVATE BOTH CUTS
    LDAA    #$01                ; 86 01    
    STAA    LIMITER_FLAG        ; 97 A0    Set limiter flag
    BRA     DO_COMBINED_CUT     ; 20 xx

CHECK_DEACTIVATE:
    ;--------------------------------------------------------------------------
    ; LIMITER ON - Check if should deactivate
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25
    CMPA    #RPM_LOW            ; 81 EC    < 5900 RPM?
    BCC     DO_COMBINED_CUT     ; 24 xx    No (>= 5900) → keep cutting
    
    ; DEACTIVATE CUTS
    CLR     LIMITER_FLAG        ; 7F 01 A0 Clear flag
    BRA     EXIT_NORMAL         ; 20 xx

DO_COMBINED_CUT:
    ;--------------------------------------------------------------------------
    ; CUT BOTH FUEL AND SPARK
    ;--------------------------------------------------------------------------
    
    ; 1. CUT SPARK: Inject fake period
    PULB                        ; 33       Discard original period
    PULA                        ; 32       
    LDD     #FAKE_PERIOD        ; CC 3E 80 Load fake period
    STD     PERIOD_24X_RAM      ; FD 19 4C Store → kills spark
    
    ; 2. CUT FUEL: Zero the injector pulse width
    ; ⚠️ THIS SECTION REQUIRES VERIFICATION OF INJ_PW_RAM ADDRESS
    ; Option A: Zero pulse width directly
    ;   LDD     #$0000          ; CC 00 00 Zero pulse width
    ;   STD     INJ_PW_RAM      ; FD 01 80 Store zero PW
    ;
    ; Option B: Set fuel cut flag if one exists in RAM
    ;   LDAA    #$01            
    ;   STAA    FUEL_CUT_FLAG   
    ;
    ; Option C: Rely on stock fuel cut (set threshold to match spark)
    ;   This is the SAFEST - just ensure calibration fuel cut = 6000 RPM
    ;
    ; For now, we rely on Option C (stock fuel cut coordination)
    ; User must set fuel cut tables to same RPM as spark cut:
    ;   0x77DE = $F0 (6000/25 = 240)
    ;   0x77DF = $EC (5900/25 = 236)
    
    RTS                         ; 39       Return

EXIT_NORMAL:
    ;--------------------------------------------------------------------------
    ; NORMAL OPERATION
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore original period
    PULA                        ; 32       
    STD     PERIOD_24X_RAM      ; FD 19 4C Store real period
    RTS                         ; 39       Return

;==============================================================================
; CALIBRATION REQUIREMENTS FOR COMBINED CUT
;==============================================================================
;
; To properly coordinate fuel cut with spark cut, modify these XDF values:
;
; 1. FUEL CUT RPM HIGH (0x77DE):
;    Set to same as spark cut threshold
;    6000 RPM = $F0 (240 × 25)
;
; 2. FUEL CUT RPM LOW (0x77DF):  
;    Set to same as spark resume threshold
;    5900 RPM = $EC (236 × 25)
;
; This ensures both fuel and spark cut at exactly the same RPM.
;
; WHY COORDINATE THEM?
;
; | Scenario | Fuel | Spark | Result |
; |----------|------|-------|--------|
; | Spark only cut | ✅ | ❌ | Unburnt fuel → FLAMES (want this? use v32) |
; | Fuel only cut | ❌ | ✅ | Spark fires on no fuel → lean burn → HOT |
; | Both cut | ❌ | ❌ | Clean cut, no flames, no lean burn ✅ |
; | Neither | ✅ | ✅ | Normal operation ✅ |
;
; "Fuel only cut" (stock VY behavior) is actually slightly bad because:
;   - Spark still fires
;   - No fuel to burn
;   - Creates lean condition in cylinder
;   - Could stress piston/exhaust valve
;   - (In reality the ECU manages this but combined is cleaner)
;
;==============================================================================

;------------------------------------------------------------------------------
; SPEEDUINO COMPARISON: PROTECT_CUT_BOTH
;------------------------------------------------------------------------------
;
; Speeduino has an elegant system:
;   ```cpp
;   uint8_t ignitionChannelsOn;  // Bit flags for each coil
;   uint8_t fuelChannelsOn;       // Bit flags for each injector
;   
;   case PROTECT_CUT_BOTH:
;       ignitionChannelsOn = 0;   // Turn off all coils
;       fuelChannelsOn = 0;        // Turn off all injectors
;       disableAllIgnSchedules(); // Cancel pending
;       disableAllFuelSchedules();
;       break;
;   ```
;
; Delco VY cannot do this directly because:
;   - Ignition is hardware-controlled via TIO
;   - Cannot just "clear a bit" to disable coils
;   - Must use period injection trick instead
;
; For fuel, the VY CAN directly control pulse width:
;   - Injector scheduling is software-controlled
;   - Could zero the pulse width in RAM
;   - BUT need to verify the RAM address first
;
;==============================================================================

;------------------------------------------------------------------------------
; FUTURE ENHANCEMENT: FIND INJECTOR PW RAM
;------------------------------------------------------------------------------
;
; To implement true combined cut (not relying on calibration):
;
; 1. Disassemble around injector control
; 2. Find where final PW is stored before output
; 3. Hook that location to zero PW when limiter active
;
; Search hints:
;   - Look for OUTPUT COMPARE routines (OC3-OC5 used for injectors)
;   - Find STD/STX instructions near timer registers
;   - Cross-reference with VE table lookup code
;
; For now, the calibration method (Option C) works reliably.
;
;==============================================================================

;##############################################################################
;#                                                                            #
;#                    ═══ CONFIRMED ADDRESSES & FINDINGS ═══                  #
;#                                                                            #
;##############################################################################

;------------------------------------------------------------------------------
; ✅ BINARY VERIFIED ADDRESSES (January 17, 2026)
;------------------------------------------------------------------------------
;
; Verified on: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (131,072 bytes)
;
; SPARK CUT ADDRESSES (proven):
; File Offset | Bytes      | Verified      | Purpose
; ------------|------------|---------------|-------------------------------
; 0x101E1     | FD 01 7B   | ✅ STD $017B      | HOOK POINT — dwell intermediate store
; 0x0C500     | 00 00 00...| ✅ zeros      | FREE SPACE for code
;
; FUEL CUT CALIBRATION (verified from XDF):
; File Offset | Bytes | Value                   | Purpose
; ------------|-------|-------------------------|--------------------
; 0x77DE      | EC    | 236 × 25 = 5900 RPM     | Fuel cut HIGH (Drive)
; 0x77DF      | EB    | 235 × 25 = 5875 RPM     | Fuel cut LOW (Drive)
; 0x77E0      | EC    | 236 × 25 = 5900 RPM     | Fuel cut HIGH (P/N)
; 0x77E1      | EB    | 235 × 25 = 5875 RPM     | Fuel cut LOW (P/N)
; 0x77E2-E3   | EC EB | 5900/5875               | A/C On values
;
; NOTE: Enhanced binary has STOCK fuel cut values!
;
;------------------------------------------------------------------------------
; 📐 COMBINED CUT COORDINATION
;------------------------------------------------------------------------------
;
; TO COORDINATE FUEL + SPARK AT 6000 RPM:
;
; Step 1: Set fuel cut tables to match spark cut
;   File Offset | Change From | Change To | New Value
;   ------------|-------------|-----------|----------
;   0x77DE      | EC          | F0        | 6000 RPM
;   0x77DF      | EB          | EC        | 5900 RPM (hysteresis)
;   0x77E0      | EC          | F0        | 6000 RPM
;   0x77E1      | EB          | EC        | 5900 RPM
;
; Step 2: Apply spark cut hook at 0x101E1
;   Change: FD 01 7B → BD C5 00 (JSR $C500)
;
; Step 3: Install combined cut handler at $C500
;
; Result: Both fuel AND spark cut at 6000 RPM = clean cut
;
;------------------------------------------------------------------------------
; 📐 SPEEDUINO PROTECT_CUT_BOTH COMPARISON
;------------------------------------------------------------------------------
;
; SPEEDUINO can directly disable channels:
;   ignitionChannelsOn = 0;  // Clear all bits = all coils off
;   fuelChannelsOn = 0;       // Clear all bits = all injectors off
;
; VY DELCO CANNOT do this because:
;   - Ignition is controlled by hardware TIO module
;   - Cannot "clear a bit" to disable coils
;   - Must trick the system (period injection)
;
; VY DELCO CAN do this for fuel:
;   - Injectors are software-scheduled
;   - Could zero pulse width if we knew the address
;   - OR use stock fuel cut calibration (easier)
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. Injector pulse width RAM location
;    Candidate: $0180-$0182 area (typical Delco layout)
;    Method: Disassemble injector scheduling code
;    Benefit: Direct PW control = true combined cut
;
; 2. Individual injector control
;    Question: Can we cut specific cylinders (e.g., 1-3-5)?
;    Benefit: Rolling fuel cut for different effect
;    Challenge: Need injector firing order mapping
;
; 3. Injector driver timing
;    Question: What's the relationship between PW RAM and output?
;    HC11 uses OC3-OC5 for injector scheduling
;    Need to find where schedule is set up
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: PURE CALIBRATION METHOD
;------------------------------------------------------------------------------
;
; Instead of code injection, just align calibration tables:
;
; Set all fuel cut = spark cut threshold:
;   0x77DE-E3: All = $F0 (6000 RPM)
;   0x77DF, E1, E3: All = $EC (5900 RPM hysteresis)
;
; Then DON'T use any ASM code - just rely on stock behavior!
;
; Pros:
;   - No code to debug
;   - Uses proven stock logic
;   - XDF-tunable
;
; Cons:
;   - Still fuel cut only (no spark cut)
;   - Won't produce flames
;   - Limited to 6375 RPM max
;
; This file (v35) adds spark cut ON TOP of calibrated fuel cut.
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: INJECTOR DRIVER DISABLE
;------------------------------------------------------------------------------
;
; Another option: Disable injector output compare interrupts
;
; HC11 Injector Control:
;   OC3, OC4, OC5 = Output Compare channels for injectors
;   TMSK1 ($1022) bit 5,4,3 = OC3,4,5 interrupt enables
;
; To disable all injectors:
;   LDAA #$00
;   STAA $1022      ; Disable all OC interrupts
;
; Pros:
;   - Immediate fuel cut
;   - Simple
;
; Cons:
;   - Also disables spark timing interrupts!
;   - Would need selective disable
;   - Risky - may affect other functions
;
; NOT RECOMMENDED without extensive testing.
;
;------------------------------------------------------------------------------
; 💡 BEST PRACTICE FOR COMBINED CUT
;------------------------------------------------------------------------------
;
; RECOMMENDED APPROACH:
;   1. Set fuel cut calibration to 6000/5900 RPM (0x77DE-E3)
;   2. Install spark cut at 6000/5900 RPM (v32)
;   3. Both systems work together via calibration coordination
;   4. No need for complex combined cut code
;
; This gives:
;   - Clean cut (no unburnt fuel)
;   - Both systems work independently but in sync
;   - XDF-tunable thresholds
;   - Proven code (v32)
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm - Simple spark cut (use with calibration)
; spark_cut_rolling_v34.asm - For flames (disable fuel cut instead)
; DOCUMENT_CONSOLIDATION_PLAN.md - Project status
;
;##############################################################################

