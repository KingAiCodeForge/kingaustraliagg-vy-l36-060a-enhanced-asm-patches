;==============================================================================
; VY V6 IGNITION CUT v9 - PROGRESSIVE SOFT LIMITER
;==============================================================================
;
; ⚠️ EXPERIMENTAL - Multi-zone progressive spark cut concept
; ⚠️ Uses $01A0 for CYCLE_COUNTER - UNVERIFIED! 
; ✅ See v38 for verified flag at $0046 bit 7
;
; This is an interesting approach - progressive limiting instead of hard cut.
; Concept is valid but needs RAM verification and testing.
;
; 🔴 CRITICAL BUG IDENTIFIED (Jan 18, 2026):
;    The original code saved D to stack, then clobbered it, then in NO_CUT
;    path it returned WITHOUT storing anything to $017B. This breaks the
;    timing state machine!
;
;    FIX: Must restore original D from stack and STD $017B in NO_CUT path.
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Method: Gradual power reduction instead of hard cut
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   Progressive "soft" limiter that gradually reduces power instead of
;   harsh on/off cut. Creates smoother limiter feel, less drivetrain shock.
;   Uses proportional spark cut based on RPM above threshold.
;  need to have expert knowledge of ose 11p 12p or hc11 to implement.
; vy v6 is different to them but hc11 code is hc11 code only thing stopping is hardcoded unknown limits.
; Based On: Chr0m3-approved 3X Period Injection (Method A)
; Status: 🔬 EXPERIMENTAL - Variation of proven method
;
; How It Works:
;   1. 6200-6250 RPM: 100% power (no cut)
;   2. 6250-6275 RPM: 75% power (25% spark cut - cut 1 in 4 cylinders)
;   3. 6275-6300 RPM: 50% power (50% spark cut - cut 1 in 2 cylinders)  
;   4. 6300+ RPM: 25% power (75% spark cut - cut 3 in 4 cylinders)
;
; Implementation:
;   - Cycle counter: tracks ignition events (0-3)
;   - RPM zone determines cut ratio
;   - Higher RPM = more frequent cuts
;   - Creates "soft wall" instead of "brick wall"
;
; Advantages:
;   ✅ Smooth power reduction (no harsh bounce)
;   ✅ Less drivetrain shock (transmission friendly)
;   ✅ Better for dyno testing (controlled power limit)
;   ✅ Easier to hold at limiter (drift/burnout)
;
; Disadvantages:
;   ⚠️  More complex than hard cut
;   ⚠️  Still produces some power at limiter (not true limit)
;   ⚠️  Not tested by Chr0m3 yet
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM/25 (8-bit!) - NOT 16-bit raw RPM
PERIOD_3X_RAM       EQU $017B       ; 3X period storage

; CYCLE COUNTER - ⚠️ UNVERIFIED LOCATION!
; We need a 2-bit counter (0-3) to track ignition events.
; Options:
;   $01A0 = Original guess, unverified (no extended references found)
;   $0046 bits 5-6 = Might be free (bits 3,6,7 appear unused)
;   Better: Pack into $0046 bits 5-6 which we've verified unused
;
; For now using $01A0 but NEEDS RUNTIME VERIFICATION before production use!
CYCLE_COUNTER       EQU $01A0       ; ⚠️ UNVERIFIED: Ignition event counter (0-3)

; PROGRESSIVE THRESHOLDS (8-BIT - RPM÷25)
; ⚠️ FIXED: Changed from 16-bit raw RPM to 8-bit RPM/25
; Max 8-bit value = 255 = 6375 RPM
RPM_ZONE1           EQU $EE         ; 238 × 25 = 5950 RPM (no cut)
RPM_ZONE2           EQU $EF         ; 239 × 25 = 5975 RPM (25% cut starts)
RPM_ZONE3           EQU $F0         ; 240 × 25 = 6000 RPM (50% cut starts)
RPM_ZONE4           EQU $F1         ; 241 × 25 = 6025 RPM (75% cut starts)

FAKE_PERIOD         EQU $3E80       ; Fake 3X period (spark cut)

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $0C500          ; ✅ FIXED: Use $C500 not $14468!

;==============================================================================
; PROGRESSIVE SOFT LIMITER HANDLER
;==============================================================================
; ENTRY: D contains original 3X period (what stock was about to store)
; EXIT:  $017B contains either original period (no cut) or fake period (cut)
;
; 🔴 CRITICAL: We MUST store something to $017B before returning!
;    The hook replaced "STD $017B" so we've taken responsibility for that write.
;==============================================================================

SOFT_LIMITER_HANDLER:
    PSHB                        ; Save original D (period) to stack
    PSHA                        ; Stack: [A][B] (A at SP+0, B at SP+1)
    PSHX                        ; Save X
    
    ; Increment cycle counter (0-3 wrap-around)
    LDAA    CYCLE_COUNTER
    INCA
    ANDA    #$03                ; Mask to 0-3
    STAA    CYCLE_COUNTER
    
    ; Check RPM zone (8-bit comparison - FIXED Jan 17, 2026)
    LDAA    RPM_ADDR            ; Load 8-bit RPM/25 from $00A2
    
    ; Zone 1: < 5975 RPM → No cut
    CMPA    #RPM_ZONE2          ; Compare 8-bit to 239
    BLO     STORE_ORIGINAL      ; ✅ FIXED: Was "NO_CUT" which didn't store!
    
    ; Zone 2: 5975-6000 RPM → 25% cut (cut every 4th event)
    CMPA    #RPM_ZONE3          ; Compare 8-bit to 240
    BLO     CUT_25_PERCENT
    
    ; Zone 3: 6000-6025 RPM → 50% cut (cut every 2nd event)
    CMPA    #RPM_ZONE4          ; Compare 8-bit to 241
    BLO     CUT_50_PERCENT
    
    ; Zone 4: 6025+ RPM → 75% cut (cut 3 out of 4 events)
    BRA     CUT_75_PERCENT

;------------------------------------------------------------------------------
; STORE ORIGINAL PERIOD (No spark cut - normal operation)
;------------------------------------------------------------------------------
; ✅ FIXED: Must recover original D from stack and store to $017B!
;------------------------------------------------------------------------------
STORE_ORIGINAL:
    PULX                        ; Restore X first
    PULA                        ; Restore A (high byte of original D)
    PULB                        ; Restore B (low byte of original D)
    STD     PERIOD_3X_RAM       ; ✅ Store ORIGINAL period to $017B
    RTS

CUT_25_PERCENT:
    ; Cut spark on cycle 0 only (1 out of 4)
    LDAA    CYCLE_COUNTER
    CMPA    #$00
    BEQ     INJECT_FAKE_PERIOD
    BRA     STORE_ORIGINAL      ; ✅ FIXED: Store original, not just exit!

CUT_50_PERCENT:
    ; Cut spark on cycles 0 and 2 (2 out of 4)
    LDAA    CYCLE_COUNTER
    ANDA    #$01                ; Check if even (0 or 2)
    BEQ     INJECT_FAKE_PERIOD
    BRA     STORE_ORIGINAL      ; ✅ FIXED: Store original, not just exit!

CUT_75_PERCENT:
    ; Cut spark on cycles 0, 1, 2 (3 out of 4)
    LDAA    CYCLE_COUNTER
    CMPA    #$03
    BEQ     STORE_ORIGINAL      ; Only fire on cycle 3 - store original
    ; Fall through to inject fake period

INJECT_FAKE_PERIOD:
    LDD     #FAKE_PERIOD
    STD     PERIOD_3X_RAM       ; Inject fake period (cuts spark)
    ; Fall through to exit (need to clean up stack)

EXIT_AFTER_FAKE:
    PULX                        ; Clean up stack (we pushed X)
    PULA                        ; Discard saved A (we already wrote fake period)
    PULB                        ; Discard saved B
    RTS

;==============================================================================
; TUNING NOTES
;==============================================================================
;
; RPM ZONE ADJUSTMENT:
;   Narrow zones (20 RPM): Sharp soft limiter (quick transition)
;   Wide zones (100 RPM): Gentle soft limiter (smooth transition)
;
; CUT RATIOS:
;   25% cut: Still makes ~75% power (safe for dyno testing)
;   50% cut: Makes ~50% power (good for holding at limiter)
;   75% cut: Makes ~25% power (prevents RPM climb)
;
; CYCLE COUNTING:
;   VY V6 is wastespark (3 coils, 6 cylinders)
;   Each "ignition event" fires 2 cylinders
;   Cutting 1 in 4 events = cutting 2 in 8 cylinders = 25% cut
;
; COMPARISON TO HARD CUT:
;   Hard Cut (Method v3):
;     - 6299 RPM: 100% power
;     - 6300 RPM: 0% power (instant)
;     - Harsh bounce, transmission shock
;
;   Soft Cut (This Method):
;     - 6250 RPM: 100% power
;     - 6275 RPM: 50% power
;     - 6300 RPM: 25% power
;     - Smooth transition, easier to control
;
; WHEN TO USE:
;   - Dyno testing (controlled power limit)
;   - Burnouts (easier to hold at limiter)
;   - Drift events (smooth power control)
;   - Transmission protection (less shock)
;
; WHEN NOT TO USE:
;   - Drag racing (need instant hard cut)
;   - Competition (absolute limit preferred)
;   - If you want "brick wall" limiter feel
;
;==============================================================================

;==============================================================================
; ADVANCED TUNING: CUSTOM CUT PATTERNS
;==============================================================================
;
; Instead of linear 25-50-75% progression, you can customize:
;
; Pattern A: Aggressive (quick ramp)
;   6280 RPM: 100% power
;   6290 RPM: 50% power  
;   6300 RPM: 10% power
;
; Pattern B: Gentle (slow ramp)
;   6200 RPM: 100% power
;   6250 RPM: 75% power
;   6300 RPM: 50% power
;
; Pattern C: Two-stage (soft then hard)
;   6250-6290: Soft limiter (50% power)
;   6290+: Hard limiter (0% power)
;
; To implement custom patterns, modify RPM_ZONEx values
; and cut ratios in the comparison sections
;
;==============================================================================

;==============================================================================
; IGNITION EVENT TRACKING
;==============================================================================
;
; IMPORTANT: This code assumes it's called EVERY ignition event
;
; Hook point options:
;   1. Main 3X period write (@ 0x181E1) - called every ignition
;   2. Spark advance calculation routine - called every ignition
;   3. Timer ISR - may be called more/less frequently
;
; If hooked at wrong location, cycle counting will be incorrect
; and cut ratios won't match expected percentages
;
; VALIDATION:
;   - Use oscilloscope on EST pin
;   - Count spark events vs cut events
;   - Verify ratios match code (25%, 50%, 75%)
;   - Adjust CYCLE_COUNTER logic if needed
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
;
; NOTE: File uses $14468 as ORG, which is within verified free space
; (0x0C468-0x0FFBF = 15,192 bytes of zeros)
;
;------------------------------------------------------------------------------
; 📐 PROGRESSIVE CUT MATH
;------------------------------------------------------------------------------
;
; Wastespark V6 cylinder firing:
;   Cylinders: 1-6, 2-5, 3-4 (paired by wastespark)
;   6 ignition events per 2 revolutions
;   3 ignition events per revolution
;
; Cycle counting (0-3):
;   Counter wraps: 0 → 1 → 2 → 3 → 0 → 1 → ...
;   Pattern over 4 events matches 1 complete V6 revolution
;
; Cut percentage accuracy:
;   25% cut = cut on cycle 0 = 1 of 4 events
;   50% cut = cut on cycles 0,2 = 2 of 4 events  
;   75% cut = cut on cycles 0,1,2 = 3 of 4 events
;   100% = cut all = 4 of 4 events (not used, goes to hard cut)
;
; Power output at each zone:
;   Zone 1 (0% cut):   100% power (normal)
;   Zone 2 (25% cut):  ~75% power
;   Zone 3 (50% cut):  ~50% power
;   Zone 4 (75% cut):  ~25% power
;
;------------------------------------------------------------------------------
; 📐 ZONE THRESHOLD MATH (8-bit RPM/25)
;------------------------------------------------------------------------------
;
; Default zones:
;   Zone      | 8-bit Value | Actual RPM  | Cut %   | Power
;   ----------|-------------|-------------|---------|-------
;   Zone 1    | < $EE       | < 5950      | 0%      | 100%
;   Zone 2    | $EE-$EF     | 5950-5975   | 25%     | 75%
;   Zone 3    | $EF-$F0     | 5975-6000   | 50%     | 50%
;   Zone 4    | >= $F0      | >= 6000     | 75%     | 25%
;
; Zone width = 25 RPM ÷ 25 = 1 byte per zone (very narrow!)
; For wider zones: spread thresholds further apart
;
; Example - wider 50 RPM zones:
;   RPM_ZONE1 = $EA  (5850 RPM - start of soft cut)
;   RPM_ZONE2 = $EC  (5900 RPM - 25% cut)
;   RPM_ZONE3 = $EE  (5950 RPM - 50% cut)
;   RPM_ZONE4 = $F0  (6000 RPM - 75% cut / hard limit)
;
;------------------------------------------------------------------------------
; ⚠️ THINGS STILL TO FIND OUT
;------------------------------------------------------------------------------
;
; 1. CYCLE_COUNTER RAM ($01A0)
;    Status: UNVERIFIED - assumed free
;    Alternative: Use ignition counter at $1B8C (if it exists)
;
; 2. Ignition event frequency
;    Assumption: Hook is called once per 3X event
;    Reality: Need to verify with oscilloscope
;    If called twice per event, cut percentages will be wrong!
;
; 3. Phase alignment
;    Currently cuts cylinder pairs randomly
;    Could enhance: Always cut same cylinders for consistency
;    Example: Only cut 1-6 pair, never 3-4 pair
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: TIMING RETARD SOFT CUT
;------------------------------------------------------------------------------
;
; Instead of spark CUT, use spark RETARD for soft limiting:
;
; Zone 1: Normal timing (e.g., 32° BTDC)
; Zone 2: Retard 10° (e.g., 22° BTDC) = -15% power
; Zone 3: Retard 20° (e.g., 12° BTDC) = -35% power  
; Zone 4: Retard 30° (e.g., 2° BTDC) = -50% power
;
; Pros:
;   - Smoother than spark cut
;   - All cylinders still fire (no misfire codes)
;   - Progressive feel
;
; Cons:
;   - Still makes power (not true limit)
;   - No exhaust pops/flames
;   - Increased exhaust gas temperature
;
; Implementation:
;   Hook timing calculation
;   Subtract retard value based on RPM zone
;   Clamp minimum timing to 0° (avoid pinging)
;
;------------------------------------------------------------------------------
; 🔄 ALTERNATIVE: FUEL CUT SOFT LIMITER
;------------------------------------------------------------------------------
;
; Stock ECU has fuel cut table - could use similar progressive:
;
; Zone 1: 100% injector PW
; Zone 2: 75% injector PW
; Zone 3: 50% injector PW
; Zone 4: 25% injector PW (lean cut)
;
; Pros:
;   - Uses existing fuel cut hardware
;   - Smooth power reduction
;
; Cons:
;   - Running lean at limit = hot exhaust
;   - Potential knock issues
;   - Less dramatic than spark cut
;   - 8-bit RPM limit still applies
;
;------------------------------------------------------------------------------
; 💡 DYNO TUNING APPLICATION
;------------------------------------------------------------------------------
;
; This soft limiter is IDEAL for dyno use:
;
; 1. Set RPM limit 500 below desired max (e.g., 5500 for 6000 limit)
; 2. Run dyno pull
; 3. Progressive cut prevents hard bounce at limit
; 4. Dyno operator sees smooth power reduction
; 5. Safe for repeated pulls without shocking engine/dyno
;
; Recommended dyno settings:
;   Zone start: 500 RPM below max
;   Zone width: 100-150 RPM per zone
;   Final zone: 75% cut (25% power) - prevents further RPM rise
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; spark_cut_6000rpm_v32.asm    - Hard cut (simpler, harsher)
; spark_cut_rolling_v34.asm    - Random cut (flames, less predictable)
; spark_cut_two_stage_hysteresis_v23.asm - VL V8 style (state machine)
;
;##############################################################################
