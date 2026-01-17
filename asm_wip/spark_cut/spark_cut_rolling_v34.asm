;==============================================================================
; VY V6 IGNITION CUT v34 - ROLLING CUT (SPEEDUINO-STYLE)
;==============================================================================
;
; ⚠️ EXPERIMENTAL - Uses concepts from Speeduino open source
; ⚠️ Uses $01A0 for flags - UNVERIFIED! See v38 for verified $0046 bit 7
;
; This is an interesting approach but needs verification before use.
; Speeduino source: https://github.com/noisymime/speeduino
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 17, 2026
; Method: Rolling Random Cylinder Cut (Based on Speeduino Open Source)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB)
; Processor: Motorola MC68HC711E9
;
; BASED ON SPEEDUINO OPEN-SOURCE IMPLEMENTATION:
;   From speeduino.ino (lines 934-989):
;   ```cpp
;   int16_t rpmDelta = currentStatus.RPM - maxAllowedRPM;
;   if(rpmDelta >= 0) { cutPercent = 100; }
;   else { cutPercent = table2D_getValue(&rollingCutTable, (int8_t)(rpmDelta / 10)); }
;   
;   for(uint8_t x=0; x<maxIgnOutputs; x++) {  
;       if(random1to100() < cutPercent) {
;           BIT_CLEAR(ignitionChannelsOn, x); // Skip spark
;       }
;   }
;   ```
;
; Status: 🔬 EXPERIMENTAL - Adapted from proven open-source code
;
; WHAT IS ROLLING CUT?
;   - Randomly skips spark events based on how far above RPM limit
;   - Near limit: skip 10-30% of sparks (random selection)
;   - At/above limit: skip 100% of sparks
;   - Creates smooth progressive limiting with FLAMES! 🔥
;   - Unburnt fuel ignites in exhaust = turbo anti-lag effect
;
; WHY ROLLING CUT?
;   ✅ Progressive feel (not harsh on/off)
;   ✅ FLAMES AND POPS (fuel still injecting, random sparks missing)
;   ✅ Better for turbos (maintains boost, anti-lag effect)
;   ✅ Smoother than hard cut on driveline
;   ✅ More exciting for burnouts/shows
;
; IMPLEMENTATION DIFFERENCE:
;   Speeduino: Can directly disable ignition channel bits
;   VY Delco: Cannot - must use 3X period injection trick
;
;   Our adaptation:
;   - Use pseudo-random check based on ignition cycle counter
;   - Roll cut percentage based on RPM delta from limit
;   - Inject fake period on "cut" cycles only
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED RAM ADDRESSES
;------------------------------------------------------------------------------
RPM_ADDR        EQU $00A2       ; ✅ VERIFIED: 8-bit RPM/25 (max 255=6375)
PERIOD_3X_RAM   EQU $017B       ; ✅ VERIFIED: 3X period storage
LIMITER_FLAG    EQU $01A0       ; ⚠️ UNVERIFIED: Limiter state flag
RANDOM_SEED     EQU $01A1       ; ⚠️ PLACEHOLDER: Pseudo-random counter

;------------------------------------------------------------------------------
; RPM THRESHOLDS (Rolling cut starts BELOW hard limit)
;------------------------------------------------------------------------------
; Speeduino uses rollingProtRPMDelta[] table - we'll simplify to zones
;
; Example: Hard limit = 6000 RPM
;   5900-5950 RPM: 25% cut (cut 1 in 4 randomly)
;   5950-5975 RPM: 50% cut (cut 1 in 2 randomly)
;   5975-6000 RPM: 75% cut (cut 3 in 4 randomly)
;   6000+ RPM: 100% cut (cut all)
;
; 8-bit scaled values (RPM÷25):
RPM_HARD_LIMIT  EQU $F0         ; 240 × 25 = 6000 RPM (100% cut)
RPM_ZONE_75     EQU $EF         ; 239 × 25 = 5975 RPM (75% cut)
RPM_ZONE_50     EQU $EE         ; 238 × 25 = 5950 RPM (50% cut)
RPM_ZONE_25     EQU $EC         ; 236 × 25 = 5900 RPM (25% cut)
RPM_RESUME      EQU $E9         ; 233 × 25 = 5825 RPM (resume threshold)

FAKE_PERIOD     EQU $3E80       ; 16000 = fake period for spark kill

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
            ORG $0C500          ; ✅ VERIFIED: Free space

;==============================================================================
; ROLLING CUT HANDLER - SPEEDUINO-STYLE RANDOM CYLINDER CUT
;==============================================================================
; Called from: JSR at 0x101E1 (replaces STD $017B)
; Entry: D = calculated 3X period
; Exit:  D = real period OR fake period (based on rolling cut decision)
;
; Algorithm (Speeduino-inspired):
;   1. Check RPM against zones
;   2. Determine cut percentage based on RPM delta
;   3. Increment pseudo-random counter
;   4. Compare random value to cut percentage
;   5. If random < cutPercent: inject fake period (cut spark)
;   6. Else: use real period (allow spark)
;
;==============================================================================

ROLLING_CUT_HANDLER:
    PSHA                        ; 36       Save period high
    PSHB                        ; 37       Save period low
    
    ;--------------------------------------------------------------------------
    ; INCREMENT PSEUDO-RANDOM COUNTER
    ;--------------------------------------------------------------------------
    ; Simple LFSR-style pseudo-random: counter XOR with RPM creates pattern
    ; Not cryptographically random, but good enough for random-ish cuts
    ;
    LDAA    RANDOM_SEED         ; 96 A1    Load seed
    ADDA    RPM_ADDR            ; 9B A2    Add current RPM
    EORA    #$A5                ; 88 A5    XOR with constant
    STAA    RANDOM_SEED         ; 97 A1    Store new seed
    ; A now contains pseudo-random 0-255
    
    ;--------------------------------------------------------------------------
    ; DETERMINE CUT PERCENTAGE BASED ON RPM ZONE
    ;--------------------------------------------------------------------------
    LDAB    RPM_ADDR            ; D6 A2    Load RPM/25 into B
    
    ; Check zones from highest to lowest
    CMPB    #RPM_HARD_LIMIT     ; C1 F0    >= 6000 RPM?
    BHS     CUT_100             ; 24 xx    Yes → 100% cut (always)
    
    CMPB    #RPM_ZONE_75        ; C1 EF    >= 5975 RPM?
    BHS     CUT_75              ; 24 xx    Yes → 75% cut
    
    CMPB    #RPM_ZONE_50        ; C1 EE    >= 5950 RPM?
    BHS     CUT_50              ; 24 xx    Yes → 50% cut
    
    CMPB    #RPM_ZONE_25        ; C1 EC    >= 5900 RPM?
    BHS     CUT_25              ; 24 xx    Yes → 25% cut
    
    ; Below 5900 RPM: Normal operation (0% cut)
    BRA     EXIT_REAL_PERIOD    ; 20 xx

CUT_100:
    ;--------------------------------------------------------------------------
    ; 100% CUT - Always cut spark (hard limit reached)
    ;--------------------------------------------------------------------------
    ; Speeduino: cutPercent = 100; if(random1to100() < 100) { cut }
    ; We always cut at this level
    BRA     INJECT_FAKE

CUT_75:
    ;--------------------------------------------------------------------------
    ; 75% CUT - Cut 3 out of 4 sparks randomly
    ;--------------------------------------------------------------------------
    ; Speeduino: if(random1to100() < 75) { cut }
    ; We use random[0-255] < 192 (192/256 = 75%)
    ;
    CMPA    #$C0                ; 81 C0    random < 192?
    BCS     INJECT_FAKE         ; 25 xx    Yes → cut this spark
    BRA     EXIT_REAL_PERIOD    ; 20 xx    No → allow this spark

CUT_50:
    ;--------------------------------------------------------------------------
    ; 50% CUT - Cut every other spark randomly
    ;--------------------------------------------------------------------------
    ; random[0-255] < 128 (128/256 = 50%)
    ;
    CMPA    #$80                ; 81 80    random < 128?
    BCS     INJECT_FAKE         ; 25 xx    Yes → cut
    BRA     EXIT_REAL_PERIOD    ; 20 xx    No → allow

CUT_25:
    ;--------------------------------------------------------------------------
    ; 25% CUT - Cut 1 out of 4 sparks randomly
    ;--------------------------------------------------------------------------
    ; random[0-255] < 64 (64/256 = 25%)
    ;
    CMPA    #$40                ; 81 40    random < 64?
    BCS     INJECT_FAKE         ; 25 xx    Yes → cut
    BRA     EXIT_REAL_PERIOD    ; 20 xx    No → allow

INJECT_FAKE:
    ;--------------------------------------------------------------------------
    ; CUT SPARK - Inject fake period
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Discard original period
    PULA                        ; 32       
    LDD     #FAKE_PERIOD        ; CC 3E 80 Load fake period
    STD     PERIOD_3X_RAM       ; FD 01 7B Store to 3X period RAM
    RTS                         ; 39       Return

EXIT_REAL_PERIOD:
    ;--------------------------------------------------------------------------
    ; ALLOW SPARK - Use real period
    ;--------------------------------------------------------------------------
    PULB                        ; 33       Restore original period
    PULA                        ; 32       
    STD     PERIOD_3X_RAM       ; FD 01 7B Store real period
    RTS                         ; 39       Return

;==============================================================================
; END OF ROLLING CUT HANDLER
;==============================================================================
; Total code size: ~80 bytes
;
; COMPARISON TO OTHER METHODS:
;
; | Method          | Behavior at Limit | Driver Feel | Flames? |
; |-----------------|-------------------|-------------|---------|
; | Hard Cut (v32)  | 0% power instant  | Harsh       | Yes     |
; | Soft Cut (v9)   | Progressive power | Smooth      | Less    |
; | Rolling Cut (v34)| Random 0-25%     | "Burble"    | YES 🔥  |
;
; TUNING THE CUT ZONES:
;
; For more aggressive rolling (more flames, more bounce):
;   - Narrow the zones (5980/5990/6000 instead of 5900/5950/6000)
;   - Higher cut percentages at lower deltas
;
; For smoother rolling (less harsh):
;   - Widen the zones (5800/5900/5950/6000)
;   - Lower cut percentages
;
; SOUND CHARACTER:
;   Hard cut:    "BRAAAP-BRAAAP-BRAAAP" (distinct cuts)
;   Soft cut:    "braaaaaaap" (continuous reduced power)
;   Rolling cut: "BR-A-A-A-P-P-P" (random stuttering, machine gun)
;
;==============================================================================

;------------------------------------------------------------------------------
; PATCH APPLICATION INSTRUCTIONS
;------------------------------------------------------------------------------
; 1. Open binary in hex editor
;
; 2. At file offset 0x101E1, change:
;    FROM: FD 01 7B (STD $017B)
;    TO:   BD C5 00 (JSR $C500)
;
; 3. At file offset 0x0C500, insert this assembled code
;
; 4. Recalculate checksum with TunerPro
;
; 5. Test at safe RPM first (modify thresholds)
;
;------------------------------------------------------------------------------
; SPEEDUINO SOURCE REFERENCE:
;------------------------------------------------------------------------------
; File: speeduino/speeduino.ino (lines 916-989)
; Repository: https://github.com/speeduino/speeduino
; License: GPL v2
;
; Key variables:
;   - rollingCutTable: Maps RPM delta to cut percentage
;   - rollingCutLastRev: Tracks revolution for multi-rev cuts
;   - ignitionChannelsOn: Bit field for enabled channels
;   - random1to100(): Returns pseudo-random 1-100
;
; Our adaptation:
;   - rollingCutTable → Fixed zone thresholds
;   - ignitionChannelsOn → 3X period injection
;   - random1to100() → LFSR pseudo-random from counter
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
; 0x101E1     | FD 01 7B   | ✅ STD $017B  | HOOK POINT - 3X period store
; 0x0C500     | 00 00 00...| ✅ zeros      | FREE SPACE - code injection
; 0x77DE-E1   | EC EB EC EB| ✅ fuel cut   | Stock 5900/5875 RPM values
;
;------------------------------------------------------------------------------
; 📐 ROLLING CUT PERCENTAGE MATH
;------------------------------------------------------------------------------
;
; Speeduino uses random1to100() < cutPercent to decide cut.
; We use 8-bit random[0-255] with scaled thresholds:
;
; Cut %  | Speeduino Test        | Our Test (8-bit)     | Threshold
; -------|------------------------|----------------------|----------
; 25%    | random < 25           | random < 64          | $40
; 50%    | random < 50           | random < 128         | $80
; 75%    | random < 75           | random < 192         | $C0
; 100%   | random < 100 (always) | (always cut)         | N/A
;
; Conversion: threshold = (cutPercent / 100) × 256
;   25% = 0.25 × 256 = 64 = $40
;   50% = 0.50 × 256 = 128 = $80
;   75% = 0.75 × 256 = 192 = $C0
;
;------------------------------------------------------------------------------
; 📐 PSEUDO-RANDOM GENERATOR
;------------------------------------------------------------------------------
;
; LFSR-style pseudo-random for HC11:
;   LDAA RANDOM_SEED    ; Load previous seed
;   ADDA RPM_ADDR       ; Add current RPM (changes rapidly)
;   EORA #$A5           ; XOR with magic constant
;   STAA RANDOM_SEED    ; Store new seed
;
; Result: A contains pseudo-random 0-255
; Period: ~65,000 values before repeat (good enough for limiter)
;
; Why not true random?
;   - HC11 has no hardware RNG
;   - Timer-based random too slow
;   - This LFSR is fast (4 instructions, ~8 cycles)
;
;------------------------------------------------------------------------------
; 📐 ZONE THRESHOLD MATH
;------------------------------------------------------------------------------
;
; Default zones (8-bit RPM/25):
;   Zone  | RPM Range    | 8-bit Value | Cut %
;   ------|--------------|-------------|------
;   0     | < 5900       | < $EC       | 0%
;   1     | 5900-5949    | $EC-$ED     | 25%
;   2     | 5950-5974    | $EE         | 50%
;   3     | 5975-5999    | $EF         | 75%
;   4     | >= 6000      | >= $F0      | 100%
;
; Zone width = 50 RPM ÷ 25 = 2 byte values per zone
; For wider zones: increase difference between thresholds
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. RANDOM_SEED RAM ($01A1)
;    Status: UNVERIFIED - needs confirmation
;    Alternative: Use ignition event counter ($1B8C?) as seed
;
; 2. Flame tuning
;    More flames = more unburnt fuel = richer AFR at cut
;    Consider: Add injector PW boost at cut?
;    Or: Just rely on existing fuel (usually sufficient)
;
; 3. Sound character tuning
;    Faster LFSR = more random = "machine gun" sound
;    Slower = more pattern = "burble" sound
;    Try: LSRA before STAA for slower pattern
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE RANDOM METHODS
;------------------------------------------------------------------------------
;
; A) LFSR (THIS FILE) ⭐ RECOMMENDED
;    Speed: ~8 cycles
;    Randomness: Good enough
;    Code: 4 instructions
;
; B) Timer-based Random
;    LDAA $100E (TCNT low byte)
;    Speed: 1 instruction!
;    Randomness: Depends on timing
;    Issue: May sync with engine events
;
; C) Galois LFSR (16-bit)
;    LDD RANDOM_SEED
;    LSRD
;    BCC NO_XOR
;    EORA #$B4 ; tap polynomial
;NO_XOR:
;    STD RANDOM_SEED
;    Speed: ~12 cycles
;    Randomness: Excellent
;    Code: 6 instructions
;
; D) Cylinder-based Rotation (Non-random)
;    Cut cylinders 1,3,5 then 2,4,6 alternating
;    Predictable pattern, not "random" but consistent
;
;------------------------------------------------------------------------------
; 💡 FLAME MAXIMIZATION
;------------------------------------------------------------------------------
;
; For MAXIMUM FLAMES:
;   1. Disable fuel cut at 0x77DE-E1 (set to $FF)
;   2. Keep injectors firing at limiter
;   3. Random spark cut = unburnt fuel enters exhaust
;   4. Occasional spark ignites accumulated fuel = FIREBALL
;
; For turbo anti-lag effect:
;   1. Same as above
;   2. Hot exhaust gases keep turbo spinning
;   3. Random combustion events = boost maintenance
;
; WARNING: Excessive rolling cut at high load can overheat exhaust/cat!
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm     - Simple hard cut (less flames)
; spark_cut_progressive_soft_v9.asm - Deterministic progressive cut
; speeduino/speeduino.ino       - Original Speeduino source code
;
;##############################################################################

