; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !! CROSS-BANK BUG (2026-02-13): This file places code at ORG $C468+ !!
; !! (bank 1 free space). The hook at file 0x101E1 (STD $017B) is in  !!
; !! bank 2 (0x10000-0x17FFF). JSR $C500 from bank 2 hits file        !!
; !! 0x1C500 (LIVE TRANS CODE), NOT 0x0C500 (our patch).               !!
; !! FIX: Relocate to common area $5D05 (always visible, 504 bytes    !!
; !! free) or bank 2 free space at file 0x17EA2 (286 bytes).           !!
; !! See custom_ose_$060_445_plan.md section 3.1a/3.1b for details.   !!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

; ═══════════════════════════════════════════════════════════════════
; AUTO-UPDATED: January 28, 2026 - RAM Address Fix
; ═══════════════════════════════════════════════════════════════════
; CHANGED: $01A0 (UNVERIFIED) → $0046 bit 7 (VERIFIED FREE)
; REFERENCE: spark_cut_chr0m3_method_VERIFIED_v38.asm
; STATUS: ⚠️  MANUAL REVIEW REQUIRED - Check LDAA/STAA replacements
; ═══════════════════════════════════════════════════════════════════

;==============================================================================
; VY V6 IGNITION CUT LIMITER v5 - RAPID CYCLE "AK47" PATTERN
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: November 26, 2025
; Updated: November 27, 2025 - CONVERTED TO RAPID CYCLE (AK47 PATTERN)
; Method: Rapid ON/OFF spark cycling for machine gun exhaust sound
; Video Reference: "300 HP 3.8L N/A Ecotec Burnout Car Project: Week 5" (mxoHSRijWds)
; Target: Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin
; Processor: Motorola MC68HC11
;
; ⚠️ WARNING: EXPERIMENTAL - Requires bench testing before vehicle use
;
; *** ORIGINAL APPROACH ABANDONED (CYLINDER SELECTIVE CUT) ***
;   The VY V6 uses a DFI (Distributorless Firing Ignition) module.
;   ECU sends SINGLE EST signal to DFI → DFI distributes to 3 coilpacks.
;   ECU has NO DIRECT CONTROL over individual coilpacks.
;   Selective cylinder cut is IMPOSSIBLE on this architecture.
;
; *** NEW APPROACH: RAPID CYCLE "AK47" PATTERN ***
;   Instead of smooth progressive reduction, this creates:
;   - Rapid on/off/on/off spark cycling at limiter threshold
;   - Creates staccato "BRRRT" machine gun / AK47 exhaust sound
;   - Pattern: Cut 2 firing events, fire 1 event, repeat
;   - Used by drift/motorsport for aggressive limiter sound
;
; How It Works:
;   1. Monitor RPM against threshold (default: 3000 for testing)
;   2. When RPM > threshold, enter rapid cycle mode
;   3. Increment CYCLE_COUNT on each main loop pass
;   4. If (CYCLE_COUNT % 3) == 2 → FIRE spark (one cycle)
;   5. Otherwise → CUT spark via 24X_PERIOD manipulation
;   6. Result: Cut-Cut-Fire-Cut-Cut-Fire-Cut-Cut-Fire = BRRRT!
;
; Why This Works on VY V6:
;   ✅ Uses 24X_PERIOD register (proven Method A technique)
;   ✅ Single EST signal means all cylinders cut/fire together
;   ✅ Works WITH DFI module, not against it
;   ✅ Rapid cycling creates the "AK47" effect
;
; XDF-Editable Parameters (add to your XDF file):
;   - RPM_THRESHOLD: Activation RPM (default: $0BB8 = 3000 RPM)
;   - CUT_PATTERN: Aggression level ($02=AK47, $01=mild, $03=extreme)
;
; Implementation Status: 🔬 EXPERIMENTAL - Needs Chr0m3 validation
;
; VALIDATION STATUS:
;   ✅ Uses proven crank period injection (Method A base)
;   ✅ Should work in theory (builds on working method)
;   ⚠️ NOT tested by Chr0m3 yet
;   ⚠️ Rapid cycling may stress TIO hardware
;
; BEFORE TESTING:
;   1. Validate Method A (basic 3X cut) works first
;   2. Bench test with oscilloscope
;   3. Monitor for TIO timing errors
;   4. Check for unexpected DTCs
;   5. Get Chr0m3 feedback if possible
;
; SOUND CHARACTERISTICS:
;   - Cut-Cut-Fire pattern = "BRRRT" machine gun sound
;   - Similar to motorsport/drift limiters
;   - Exhaust backfires from rapid on/off
;   - Different from smooth limiter bounce
;
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; 8-BIT RPM/25 (value × 25 = actual RPM) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
                                ; NOTE: $00A3 = Engine State, NOT RPM!

; ⚠️ CORRECTED 2026-02-02: $017B is DWELL INTERMEDIATE, NOT crank period!
; 24X Crank Period Register (controls ignition timing reference)
; Setting to $FFFF blocks spark output = ignition cut
; PERIOD_24X_HI    EQU $017A       ; ❌ OLD WRONG - NOT crank period!
; PERIOD_24X_LO    EQU $017B       ; ❌ OLD WRONG - NOT crank period!
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: 24X crank period (TIC3 ISR @ $3618) ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]

; Rapid Cycle State Variables (in RAM)
CYCLE_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags byte ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
CYCLE_BIT       EQU $80         ; ✅ VERIFIED: Bit 7 is FREE
LIMITER_ACTIVE  EQU $01A1       ; Flag: 0=normal, 1=limiting

; RPM THRESHOLD (XDF-editable) - 8-bit scaled
; Default: 3000 RPM for safe testing = 3000/25 = 120 = $78
RPM_THRESHOLD   EQU $78         ; 120 × 25 = 3000 RPM

; PRODUCTION THRESHOLDS (uncomment for real use)
; RPM_THRESHOLD   EQU $FC         ; 252 × 25 = 6300 RPM 
; RPM_THRESHOLD   EQU $F0         ; 240 × 25 = 6000 RPM
; RPM_THRESHOLD   EQU $8C         ; 140 × 25 = 3500 RPM (launch control)

; CUT PATTERN CONTROL
; Controls aggression: How many cycles to cut vs fire
; Pattern = (CUT_CYCLES) cuts, then 1 fire, repeat
CUT_CYCLES      EQU $02         ; Cut 2, fire 1 = BRRRT! (AK47 sound)
                                ; $01 = Cut 1, fire 1 = mild stutter
                                ; $03 = Cut 3, fire 1 = extreme choppy
                                ; $04 = Cut 4, fire 1 = very aggressive

;------------------------------------------------------------------------------
; CODE SECTION - RAPID CYCLE "AK47" IGNITION CUT
;------------------------------------------------------------------------------
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $C468          ; Free space VERIFIED (was $18156 WRONG!) ; FIXED: $14468 is a FILE OFFSET, not CPU addr. CPU=$C468 bank 2 (file 0x14468) [Enhanced-fix]

ignition_cut_handler:
    ;--------------------------------------------------------------------------
    ; Step 1: Read current RPM (8-bit) and compare to threshold
    ;--------------------------------------------------------------------------
    LDAA RPM_ADDR               ; Load RPM/25 (8-bit from $00A2)
    CMPA #RPM_THRESHOLD         ; Compare with threshold
    BLO  limiter_off            ; Below threshold → normal operation
    
    ;--------------------------------------------------------------------------
    ; Step 2: Above threshold - enter rapid cycle mode
    ;--------------------------------------------------------------------------
    LDAA LIMITER_ACTIVE         ; Check if already limiting
    CMPA #$01                   ; Is limiter active?
    BEQ  rapid_cycle            ; Yes → continue cycling
    
    ; First time entering limiter - initialize
    LDAA #$01
    STAA LIMITER_ACTIVE         ; Set limiter active flag
    CLR  CYCLE_COUNT            ; Reset cycle counter
    
rapid_cycle:
    ;--------------------------------------------------------------------------
    ; Step 3: Rapid cycle logic - Cut 2 cycles, fire 1, repeat
    ;--------------------------------------------------------------------------
    ; The "AK47" effect comes from rapidly toggling spark on/off
    ; Pattern: CUT-CUT-FIRE-CUT-CUT-FIRE-CUT-CUT-FIRE = BRRRT!
    
    INC  CYCLE_COUNT            ; Increment cycle counter
    LDAA CYCLE_COUNT            ; Load current count
    
    ; Check if we should FIRE this cycle
    ; Fire when (CYCLE_COUNT mod (CUT_CYCLES+1)) == 0
    ; For CUT_CYCLES=2: Fire on counts 3, 6, 9, 12... (every 3rd cycle)
    
    LDAB #CUT_CYCLES            ; Load cut cycles value
    INCB                        ; B = CUT_CYCLES + 1 (pattern length)
    
    ; Simple modulo: Keep subtracting B until A < B
mod_loop:
    CBA                         ; Compare A with B
    BLO  check_fire             ; A < B → done with modulo
    SBA                         ; A = A - B
    BRA  mod_loop               ; Keep going
    
check_fire:
    ; If A == 0, it's FIRE time
    CMPA #$00
    BEQ  spark_fire             ; Zero → let spark fire
    BRA  spark_cut              ; Non-zero → cut spark

spark_cut:
    ;--------------------------------------------------------------------------
    ; CUT SPARK: Set 24X crank period to $FFFF (blocks EST output)
    ;--------------------------------------------------------------------------
    ; This is the "Chr0m3 Method" - proven to work on VY V6
    ; ⚠️ CORRECTED 2026-02-02: Now uses PERIOD_24X_RAM ($194C) instead of $017B
    LDD  #$FFFF
    STD  PERIOD_24X_RAM         ; Store $FFFF to 24X crank period
    BRA  handler_done

spark_fire:
    ;--------------------------------------------------------------------------
    ; FIRE SPARK: Allow normal spark timing
    ;--------------------------------------------------------------------------
    ; Don't modify period - let stock code calculate timing
    ; The next main loop iteration will set proper timing
    
    ; Reset cycle count to prevent overflow
    CLR  CYCLE_COUNT
    BRA  handler_done

limiter_off:
    ;--------------------------------------------------------------------------
    ; BELOW THRESHOLD: Normal operation, clear limiter state
    ;--------------------------------------------------------------------------
    CLR  LIMITER_ACTIVE         ; Clear limiter flag
    CLR  CYCLE_COUNT            ; Reset counter
    ; Fall through to handler_done

handler_done:
    RTS

;------------------------------------------------------------------------------
; XDF ENTRIES FOR TUNERPRO (Add to your .xdf file)
;------------------------------------------------------------------------------
; 
; <!-- RPM Threshold (where limiter activates) -->
; <XDFTABLE uniqueid="0x1000" flags="0x0">
;   <title>Ignition Cut - RPM Threshold</title>
;   <description>RPM at which AK47 ignition cut limiter activates</description>
;   <XDFAXIS id="x">
;     <units>RPM</units>
;     <EMBEDDEDDATA mmedaddress="0x18XX" mmedelementsizebits="16" 
;       mmedmajorstridebits="-32" mmedminortbits="-32" />
;     <math equation="X*1">
;       <VAR id="X" />
;     </math>
;   </XDFAXIS>
; </XDFTABLE>
;
; <!-- Cut Pattern (aggression level) -->
; <XDFTABLE uniqueid="0x1001" flags="0x0">
;   <title>Ignition Cut - Pattern Aggression</title>
;   <description>Cut cycles before fire: 1=mild, 2=AK47, 3=extreme, 4=brutal</description>
;   <XDFAXIS id="x">
;     <units>Cycles</units>
;     <EMBEDDEDDATA mmedaddress="0x18XX" mmedelementsizebits="8" />
;   </XDFAXIS>
; </XDFTABLE>
;
;------------------------------------------------------------------------------
; INSTALLATION NOTES
;------------------------------------------------------------------------------
; 1. Assemble this code using HC11 assembler (A09, AS11, or similar)
;
; 2. Convert assembled bytes to hex and apply to binary at offset $18156
;    File offset = $18156 - $8000 = $10156 (65878 decimal)
;
; 3. Hook into main loop by patching $101E1:
;    Original: STD $017B        ; Store timing
;    Patched:  JSR $18156       ; Call our handler first
;
; 4. XDF entries let you adjust RPM_THRESHOLD and CUT_CYCLES via TunerPro
;
; 5. TEST PROTOCOL (CRITICAL):
;    a) Bench test first - verify EST signal cuts on oscilloscope
;    b) Start with RPM_THRESHOLD = 3000 for safe testing
;    c) Increase to 6000-6500 after verifying correct operation
;    d) Listen for "BRRRT" machine gun exhaust sound
;
;------------------------------------------------------------------------------
; SOUND PATTERNS (adjust CUT_CYCLES for different effects)
;------------------------------------------------------------------------------
;
; CUT_CYCLES = 1:  Cut-Fire-Cut-Fire-Cut-Fire
;                  Sound: Mild stutter, like Ford Mustang burble
;                  Power: 50% average during limiting
;
; CUT_CYCLES = 2:  Cut-Cut-Fire-Cut-Cut-Fire  (DEFAULT - AK47)
;                  Sound: Machine gun "BRRRT" like WRC rally car
;                  Power: 33% average during limiting
;
; CUT_CYCLES = 3:  Cut-Cut-Cut-Fire-Cut-Cut-Cut-Fire
;                  Sound: Aggressive choppy, like Subaru anti-lag
;                  Power: 25% average during limiting
;
; CUT_CYCLES = 4:  Cut-Cut-Cut-Cut-Fire...
;                  Sound: Very harsh, near-stalling chop
;                  Power: 20% average during limiting
;                  ⚠️ May cause excessive backfire, catalyst damage
;
;------------------------------------------------------------------------------
; WHY THIS WORKS ON VY V6 (DFI EXPLANATION)
;------------------------------------------------------------------------------
;
; The VY V6 uses a DFI (Distributorless Firing Ignition) module:
;   - ECU sends SINGLE EST signal to DFI module
;   - DFI module has internal logic to distribute to 3 coilpacks
;   - ECU CANNOT control individual coilpacks directly
;
; This is why cylinder-selective cut is IMPOSSIBLE:
;   - No ECU address to disable individual coils
;   - DFI module handles coil selection internally
;   - ECU only controls TIMING, not which coil fires
;
; But rapid cycling WORKS because:
;   - We block the EST signal entirely (via 24X_PERIOD = $FFFF)
;   - DFI module receives no EST → no coils fire
;   - Rapidly toggling EST on/off = rapid cut/fire = AK47 sound
;
; Technical Details:
;   - EST signal: Pin B3 (WHITE wire) → DFI module input
;   - EST bypass: Pin B4 (TAN/BLACK) → allows bypass during cranking
;   - 24X_PERIOD register: Controls timing reference period
;   - Setting 24X_PERIOD = $FFFF = no spark events scheduled
;
;------------------------------------------------------------------------------
; COMPARISON: Method A (Full Cut) vs Method V5 (AK47 Rapid Cycle)
;------------------------------------------------------------------------------
;
; Method A (ignition_cut_patch.asm):
;   - Simple on/off cut at threshold
;   - Engine holds at RPM limit smoothly
;   - Sound: Single pop on hit, quiet during limit
;   - Good for: Street driving, consistent rev limit
;
; Method V5 (this file - AK47 Pattern):
;   - Rapid on/off cycling at threshold  
;   - Engine bounces at limit with staccato sound
;   - Sound: Machine gun "BRRRT" exhaust pops
;   - Good for: Motorsport, drift, show car, burnouts
;
; BOTH METHODS use same underlying technique (24X_PERIOD blocking)
; Only difference is PATTERN of cutting
;
;------------------------------------------------------------------------------
; STATUS: 🔬 EXPERIMENTAL - BENCH TEST BEFORE VEHICLE USE
;------------------------------------------------------------------------------
; ⚠️ This code is UNTESTED on real hardware
; ⚠️ May affect engine longevity with aggressive patterns
; ⚠️ Excessive backfire may damage exhaust/catalyst
; ⚠️ Recommended: Start with CUT_CYCLES=1, increase gradually
;
;==============================================================================
