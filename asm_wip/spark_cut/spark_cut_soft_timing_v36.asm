; ═══════════════════════════════════════════════════════════════════
; UPDATE HISTORY:
;   2026-01-28: RAM Address Fix - $01A0 → $0046 bit 7
;   2026-01-31: Crank Period Fix - $017B → $194C (TIC3 ISR verified)
;   2026-02-09: Enhanced v1.0a ground truth: hook=0x101E1 STD $017B, bank 1 free $C468-$FFBF
; ═══════════════════════════════════════════════════════════════════

;==============================================================================
; VY V6 IGNITION CUT v36 - SOFT TIMING RETARD (SPEEDUINO SOFT CUT STYLE)
;==============================================================================
;
; ⚠️ EXPERIMENTAL - Soft timing retard concept (not spark cut!)
; ⚠️ Uses $01A0 for LIMITER_FLAG - UNVERIFIED!
; ⚠️ Requires finding TIMING_ADVANCE RAM address (unknown)
;
; This is an alternative approach - retarding timing instead of cutting.
; More research needed on where timing is stored before TIO.
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 17, 2026
; Method: Ignition Timing Retard at Limiter (Reduces power without cutting)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; BASED ON SPEEDUINO SOFT LIMITER:
;   From Speeduino Wiki:
;   "The soft cut limiter will lock timing at an absolute value to slow 
;    further acceleration. If RPMs continue to climb and reach the hard 
;    cut limit, ignition events will cease until RPM drops."
;
;   From corrections.cpp:
;   ```cpp
;   if (currentStatus.RPMdiv100 >= configPage4.SoftRevLim) {
;       advance = calculateSoftRevLimitAdvance(advance); // Lock at retarded value
;   }
;   ```
;
; Status: 🔬 EXPERIMENTAL - Different approach than 3X Period
;
; WHAT IS SOFT CUT?
;   - Does NOT cut spark entirely
;   - Retards timing to reduce power gradually
;   - Engine still runs, but makes less power
;   - Creates "soft wall" feel instead of harsh bounce
;   - If RPM still climbs, transitions to hard cut
;
; IMPLEMENTATION CHALLENGE FOR VY V6:
;   - Need to find where final timing is stored before TIO
;   - Override that value with retarded timing
;   - More complex than crank period injection
;
; ADVANTAGES:
;   ✅ Smooth power reduction (no harsh cut)
;   ✅ No flames (spark still fires, just retarded)
;   ✅ Gentler on drivetrain
;   ✅ Can be used as "first stage" before hard cut
;
; DISADVANTAGES:
;   ⚠️  Retarded timing = more heat in exhaust (turbo concern)
;   ⚠️  Engine still makes some power at limit
;   ⚠️  More complex to implement (need timing RAM address)
;   ⚠️  May not fully prevent RPM climb
;
;==============================================================================

;------------------------------------------------------------------------------
; RAM ADDRESSES (VERIFIED + TIMING NEEDS DISCOVERY)
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: 8-bit RPM/25 ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: crank period storage ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

; IGNITION TIMING RAM - NEEDS DISCOVERY
; These are guesses based on typical Delco layout:
; Look for where spark advance is stored before TIO output
;
TIMING_ADVANCE  EQU $0190       ; ⚠️ UNVERIFIED: Spark advance (degrees)
TIMING_DWELL EQU $0199       ; ✅ VERIFIED: Dwell time ; Verified: DWELL_TIME_RAM (8 refs both) [Enhanced-fix]

;------------------------------------------------------------------------------
; SOFT LIMITER PARAMETERS
;------------------------------------------------------------------------------
; Soft cut thresholds (8-bit scaled RPM/25)
SOFT_LIMIT_RPM  EQU $EC         ; 236 × 25 = 5900 RPM (soft cut starts)
HARD_LIMIT_RPM  EQU $F0         ; 240 × 25 = 6000 RPM (hard cut kicks in)
RESUME_RPM      EQU $E9         ; 233 × 25 = 5825 RPM (full resume)

; Timing retard values
SOFT_TIMING     EQU $F0         ; -16 degrees (or 0xF0 = 240 if unsigned)
NORMAL_TIMING   EQU $00         ; Placeholder - actual timing varies

; Maximum soft limiter time before forcing hard cut
; Speeduino uses configPage4.SoftLimMax (in 0.1s units)
SOFT_MAX_TIME   EQU $05         ; 0.5 seconds max soft cut duration

;------------------------------------------------------------------------------
; FAKE PERIOD FOR HARD CUT FALLBACK
;------------------------------------------------------------------------------
FAKE_PERIOD     EQU $3E80       ; Used if soft cut fails to limit RPM

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ Code below still uses TST/STAA/CLR $01A0 — needs rewrite to BRSET/BSET/BCLR $46,$80
; See spark_cut_chr0m3_method_VERIFIED_v38.asm for correct implementation
;

            ORG $0C500          ; ✅ VERIFIED: Free space ; Bank 1 (file 0x0C500). Free banks: [1], used: [2, 3]. 15192 bytes free [Enhanced-fix]

;==============================================================================
; SOFT LIMITER HANDLER - TWO-STAGE LIMITING
;==============================================================================
;
; Stage 1 (5900-6000 RPM): Retard timing to reduce power
; Stage 2 (6000+ RPM): Hard cut via crank period injection
;
; This provides:
;   - Smooth transition as approaching limit
;   - Definite stop if timing retard isn't enough
;
;==============================================================================

SOFT_LIMITER_HANDLER:
    PSHA                        ; 36       Save period high
    PSHB                        ; 37       Save period low
    
    ;--------------------------------------------------------------------------
    ; CHECK CURRENT RPM
    ;--------------------------------------------------------------------------
    LDAA    RPM_ADDR            ; 96 A2    Load RPM/25
    
    ; Check if above hard limit first
    CMPA    #HARD_LIMIT_RPM     ; 81 F0    >= 6000 RPM?
    BHS     DO_HARD_CUT         ; 24 xx    Yes → hard cut immediately
    
    ; Check if in soft limit zone
    CMPA    #SOFT_LIMIT_RPM     ; 81 EC    >= 5900 RPM?
    BHS     DO_SOFT_RETARD      ; 24 xx    Yes → apply timing retard
    
    ; Below soft limit - check resume threshold
    CMPA    #RESUME_RPM         ; 81 E9    < 5825 RPM?
    BCS     CLEAR_SOFT_FLAG     ; 25 xx    Yes → clear soft state
    
    ; In hysteresis band - maintain current state
    TST     LIMITER_FLAG        ; 7D 01 A0
    BNE     DO_SOFT_RETARD      ; 26 xx    If soft was active, keep retarding
    BRA     EXIT_NORMAL         ; 20 xx    Otherwise normal

DO_SOFT_RETARD:
    ;--------------------------------------------------------------------------
    ; STAGE 1: SOFT CUT - Apply timing retard
    ;--------------------------------------------------------------------------
    ; Set soft limiter flag
    LDAA    #$01                ; 86 01
    STAA    LIMITER_FLAG        ; 97 A0
    
    ; Apply timing retard
    ; ⚠️ THIS IS THE UNCERTAIN PART - need correct address
    ; Option A: Override timing advance register
    ;   LDAA    #SOFT_TIMING    ; Load retarded timing value
    ;   STAA    TIMING_ADVANCE  ; Store to timing RAM
    ;
    ; Option B: Modify timing before TIO calculation
    ;   (requires finding the right hook point)
    ;
    ; Option C: Use dwell manipulation to affect timing indirectly
    ;   (this we know works - see crank period method)
    ;
    ; For now, we'll use a hybrid: slightly inflate the period
    ; This effectively retards timing without full cut
    
    PULB                        ; 33       Get original period low
    PULA                        ; 32       Get original period high
    
    ; Add 10% to period (retards timing ~10%)
    ; D = D + (D >> 3) ≈ D × 1.125
    PSHD                        ; 3C       Save D          ; ❌ ERROR: HC11 has NO PSHD! $3C=PSHX. Need PSHB+PSHA to push D.
    LSRD                        ; 04       D >> 1
    LSRD                        ; 04       D >> 2
    LSRD                        ; 04       D >> 3 (D/8)
    PSHD                        ; 3C       Save D/8        ; ❌ ERROR: HC11 has NO PSHD! Stack math below is BROKEN — entire DO_SOFT_RETARD needs rewrite.
    TSX                         ; 30       X = SP
    LDD     2,X                 ; EC 02    Load original D
    ADDD    0,X                 ; E3 00    Add D/8
    PULX                        ; 38       Clean stack
    PULX                        ; 38       Clean stack
    
    ; Store modified period (slightly longer = retarded timing)
    STD     PERIOD_24X_RAM      ; FD 19 4C
    RTS                         ; 39

DO_HARD_CUT:
    ;--------------------------------------------------------------------------
    ; STAGE 2: HARD CUT - Full spark cut via crank period injection
    ;--------------------------------------------------------------------------
    LDAA    #$02                ; 86 02    Flag = 2 (hard cut mode)
    STAA    LIMITER_FLAG        ; 97 A0
    
    PULB                        ; 33       Discard original period
    PULA                        ; 32
    LDD     #FAKE_PERIOD        ; CC 3E 80 Load fake period
    STD     PERIOD_24X_RAM      ; FD 19 4C Store → no spark
    RTS                         ; 39

CLEAR_SOFT_FLAG:
    ;--------------------------------------------------------------------------
    ; RESUME NORMAL OPERATION
    ;--------------------------------------------------------------------------
    CLR     LIMITER_FLAG        ; 7F 01 A0 Clear limiter flag

EXIT_NORMAL:
    ;--------------------------------------------------------------------------
    ; NORMAL OPERATION - Use real period
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore original period
    PULA                        ; 32
    STD     PERIOD_24X_RAM      ; FD 19 4C Store real period
    RTS                         ; 39

;==============================================================================
; END OF SOFT LIMITER HANDLER
;==============================================================================
;
; BEHAVIOR SUMMARY:
;
; | RPM Range    | Action | Power Level | Feel |
; |--------------|--------|-------------|------|
; | < 5825       | Normal | 100%        | Normal |
; | 5825-5899    | Hysteresis | Depends on prev | Transitional |
; | 5900-5999    | Soft (timing retard) | ~85% | Power falls off |
; | 6000+        | Hard cut | 0% | Bounces on limit |
;
; SPEEDUINO COMPARISON:
;
; Speeduino settings:
;   - Soft rev limit: RPM at which timing retard starts
;   - Soft limit absolute timing: The locked timing value (e.g., 0°)
;   - Soft limit max time: Max seconds in soft mode before hard cut
;   - Hard rev limiter: RPM for complete spark cut
;
; Our implementation:
;   - SOFT_LIMIT_RPM: 5900 RPM (soft starts)
;   - HARD_LIMIT_RPM: 6000 RPM (hard cut)
;   - Timing retard: Via period inflation (~10% longer)
;   - No timeout (hard cut is RPM-based not time-based)
;
;==============================================================================

;------------------------------------------------------------------------------
; ALTERNATIVE: PURE TIMING OVERRIDE
;------------------------------------------------------------------------------
;
; If we can find the correct timing advance RAM location:
;
; DO_TIMING_OVERRIDE:
;     ; Save normal timing calculation result
;     LDAA    TIMING_ADVANCE      ; Load calculated timing
;     
;     ; Override with soft limit timing
;     LDAA    #$00                ; 0 degrees (TDC)
;     STAA    TIMING_ADVANCE      ; Store override
;     
;     ; Continue with normal crank period storage
;     PULB
;     PULA
;     STD     DWELL_INTERMEDIATE
;     RTS
;
; This would be cleaner but requires:
; 1. Correct RAM address for timing advance
; 2. Hook AFTER timing calculation but BEFORE TIO output
; 3. Verification via oscilloscope
;
;------------------------------------------------------------------------------
; FINDING TIMING ADVANCE ADDRESS:
;------------------------------------------------------------------------------
;
; Search hints:
; - Look for spark advance tables in XDF
; - Find where table lookup result is stored
; - Trace from spark table → RAM → TIO output
; - Cross-reference with dwell calculation (which we know)
;
; Key XDF tables:
; - "Spark Advance" at various addresses
; - "Timing at Limiter" if exists
; - "EST Angle" calculations
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
; File Offset | Bytes      | Verified      | Purpose
; ------------|------------|---------------|-------------------------------
; 0x101E1     | FD 01 7B   | ✅ STD $017B      | HOOK POINT — dwell intermediate store
; 0x0C500     | 00 00 00...| ✅ zeros      | FREE SPACE for code
; 0x0199      | (varies)   | ✅ RAM        | Dwell time storage
;
; TIMING RAM (UNVERIFIED - need disassembly):
; $0190       | ???        | ⚠️ guess     | Spark advance (degrees?)
;
;------------------------------------------------------------------------------
; 📐 TIMING RETARD MATH
;------------------------------------------------------------------------------
;
; Timing in degrees affects power output:
;   Optimal timing (e.g., 32° BTDC): 100% power
;   Retarded 10° (e.g., 22° BTDC): ~85% power
;   Retarded 20° (e.g., 12° BTDC): ~65% power
;   Retarded 30° (e.g., 2° BTDC): ~45% power
;   TDC (0°): ~30% power (engine barely runs)
;
; Our period inflation method:
;   +10% period = ~10% timing retard equivalent
;   Original: 3333 counts @ 6000 RPM
;   +10%: 3666 counts → effective ~5500 RPM timing lookup
;   Result: Uses lower-RPM timing value = retarded
;
; WHY PERIOD INFLATION WORKS:
;   ECU uses 3X period to calculate spark advance
;   Longer period = ECU thinks lower RPM
;   Lower RPM typically has less advance
;   Result: Timing is retarded without explicit override
;
;------------------------------------------------------------------------------
; 📐 PERIOD INFLATION CALCULATION
;------------------------------------------------------------------------------
;
; Goal: Inflate period by ~12.5% (1/8)
;
; Algorithm: D = D + (D >> 3)
;   D >> 3 = D / 8 = 12.5% of D
;   D + (D >> 3) = D × 1.125
;
; Example:
;   Original period: $0D05 (3333 counts) @ 6000 RPM
;   D >> 3: $01A0 (416 counts)
;   D + (D >> 3): $0EA5 (3749 counts)
;   New apparent RPM: 6000 × 3333 / 3749 = 5334 RPM
;
; Timing effect:
;   ECU looks up timing for 5334 RPM instead of 6000 RPM
;   Typical difference: 2-5 degrees less advance
;   Reduces power without cutting spark entirely
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. Spark advance RAM location
;    Need: Disassemble timing calculation routine
;    Look for: Table lookup followed by RAM store
;    XDF hint: Find "Spark Advance" table, trace where result goes
;
; 2. Timing format
;    Question: Is timing stored as degrees? Timer counts? Offset?
;    Typical: 1 byte = 0.5° resolution (0-127.5°)
;    Or: 1 byte = 1° resolution (0-255°)
;    Or: 16-bit timer offset value
;
; 3. Timing modification timing (!)
;    Question: When is timing applied to TIO?
;    Need: Hook AFTER calculation, BEFORE TIO output
;    Currently: We hook at 3X period (may be too early)
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: TABLE MODIFICATION
;------------------------------------------------------------------------------
;
; Instead of code, modify spark tables to reduce advance at high RPM:
;
; Method:
;   1. Find spark advance table in XDF
;   2. Reduce values in 5900-6000+ RPM columns
;   3. Normal operation until high RPM, then timing drops
;
; Pros:
;   - No code needed
;   - XDF-tunable
;   - Predictable behavior
;
; Cons:
;   - Permanent (always active above threshold)
;   - Requires good table understanding
;   - May affect WOT performance
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: SPEEDUINO-STYLE TIMING LOCK
;------------------------------------------------------------------------------
;
; Speeduino locks timing to absolute value at soft limit:
;   configPage4.SoftLimRetard = 0  ; Lock at TDC
;   OR
;   configPage4.SoftLimRetard = 5  ; Lock at 5° BTDC
;
; Implementation (if we find timing RAM):
;   LDAA    #$00        ; 0 degrees
;   STAA    TIMING_ADV  ; Override any calculated value
;
; Pros:
;   - Consistent, predictable
;   - No calculation needed
;
; Cons:
;   - Requires correct timing RAM address
;   - Abrupt transition (not progressive)
;
;------------------------------------------------------------------------------
; 💡 BEST USE CASES FOR SOFT TIMING CUT
;------------------------------------------------------------------------------
;
; USE SOFT TIMING CUT (v36) FOR:
;   - Dyno testing (smooth power reduction at limit)
;   - Automatic transmission cars (less driveline shock)
;   - Street cars (quieter, less dramatic)
;   - First stage before hard cut
;
; USE HARD CUT (v32) FOR:
;   - Racing (absolute, consistent limit)
;   - Burnouts (flames, drama)
;   - Manual transmission (driver expects hard cut)
;   - Turbo cars (anti-lag effect)
;
; COMBINE BOTH:
;   Stage 1 (5900-5999 RPM): Soft timing retard (this file)
;   Stage 2 (6000+ RPM): Hard spark cut (v32)
;   Best of both worlds!
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm - Hard cut version (combine with this)
; spark_cut_progressive_soft_v9.asm - Progressive spark cut (different approach)
; spark_cut_two_stage_hysteresis_v23.asm - VL V8 style state machine
;
;##############################################################################

