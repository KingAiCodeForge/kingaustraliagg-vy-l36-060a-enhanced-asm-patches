;==============================================================================
; VY V6 GHOST CAM — ROTATING IDLE CONCEPTS & THEORY
;==============================================================================
; Author:   Jason King (kingaustraliagg / KingAI)
; Date:     January 2026 (refactored February 25, 2026)
; Target:   Holden VY V6 Enhanced v1.0a (OSID 92118883)
; Binary:   VX-VY_V6_$060A_Enhanced_v1.0a.bin (128KB, 3-bank HC11)
; Status:   THEORY / CONCEPTS — none of this runs yet
; 

! WARNING NONE OF THIS IS TESTED AND IS STILL BEING WORKED OUT IF IT SAYS VALIDATED THAT JUST MEANS A XDF ADDRESS IS CONFIRMED THERE DOESNT MEAN THIS WILL WORK. 
BRAINSTORMING AND PEOPLES INPUTS WELCOME FOR NEW IDEAS. THERE IS NO GHOST CAM/LUMPY IDLE TUNE ON THE NET AND THE ONE THAT WAS AROUND ISNT FOR SALE AND WE DONT KNOW HOW IT WORKS.
THESE METHODS COULD OR MAY NOT WORK. 

; PURPOSE:
;   Explore every possible approach to making the VY V6 idle with a
;   rhythmic "lope" (ghost cam / choppy idle) through ECU manipulation.
;   This file is the IDEA BANK. Actual implementation goes into
;   ghost_cam_rpm_delta_spark_v1.asm and future version-specific files.
;
; COMPANION FILES:
;   ghost_cam_rpm_delta_spark_v1.asm  — RPM-delta spark table patch (BMW method)
;   (future) ghost_cam_iac_lock_v1.asm — IAC bypass / lock approach
;   (future) ghost_cam_target_osc_v1.asm — Oscillating idle target patch
;==============================================================================


;==============================================================================
; SECTION 1: WHAT IS GHOST CAM / LOPING IDLE
;==============================================================================
;
; Goal: Force RPM to oscillate ±50-200 RPM around target idle at 1-4 Hz.
;
; The "lope" sound comes from the engine surging and falling rhythmically.
; Real cams do this because of valve overlap — intake valve still open when
; exhaust opens, causing cylinder-to-cylinder breathing interference.
; We're faking it electronically by making the idle controller unstable.
;
; Key insight: The ECU's idle control is a PID loop. A stable idle means
; the PID is working correctly. Ghost cam = making the PID fail on purpose,
; either by fighting it, confusing it, or rewriting its setpoint.
;
; The question is HOW to add a parameter in xdf that controls the speed,
; e.g. if idle is 900rpm it oscillates 950→850→950→850.
; Under 500ms per full cycle (high-to-low-to-high) is the target.
;
; Requirements:
;   - Open-loop (O/L) idle MUST be on — closed-loop fuel fights you
;   - Things that smooth/slow RPM need to be disabled or reduced
;   - Not just timing or fuel — the actual idle logic itself
;


;==============================================================================
; SECTION 2: ECU ARCHITECTURE — WHY THIS IS HARD
;==============================================================================
;
; The HC11 runs interrupt-driven loops at fixed rates:
;
;   ┌─────────────────────────────────────────────────────────┐
;   │  RESET ($FFFE) → Init → Background loop (forever)      │
;   │                                                         │
;   │  INTERRUPTS (preempt background):                       │
;   │    OC1 → 6.25ms   Spark calc, injector timing, IAC     │
;   │    RTI → ~4ms     Timers, counters, watchdog            │
;   │    IC  → per-fire  RPM calculation from crank signal    │
;   │                                                         │
;   │  MEMORY:                                                │
;   │    $0000-$01FF  RAM (live variables)                     │
;   │    $1000-$103F  I/O (HC11 registers)                    │
;   │    $2000-$3FFF  COMMON (shared calibration)             │
;   │    $4000-$7FFF  CAL (bank1 calibration constants)       │
;   │    $8000-$FFFF  CODE (executable, bank-switched)        │
;   └─────────────────────────────────────────────────────────┘
;
; You can't "script" behavior. You hook into existing loops with
; JSR/JMP redirects to free ROM space. Register context (A, B, X, Y, CCR)
; must be preserved. The Delco code expects specific RAM locations to
; hold specific values at specific times.
;
; Pseudocode won't work because:
;   1. No OS, no scheduler — your code runs inside ISRs
;   2. Timing budget is hard — 6.25ms ISR must finish before next tick
;   3. Signed vs unsigned math matters — spark is signed, RPM is unsigned
;   4. RAM variables are interdependent (RPM error → PID → IAC → spark)
;


;==============================================================================
; SECTION 3: WHAT CLAMPS / PREVENTS THE LOPE
;==============================================================================
;
; These are the enemies. Each one tries to keep idle smooth.
; A successful ghost cam must defeat or bypass most of them.
;
; ┌──────────────────────────────┬────────────────────────────────────┬─────────────────────────────────────┐
; │ Limiter                      │ Why It Fights You                  │ Workaround                          │
; ├──────────────────────────────┼────────────────────────────────────┼─────────────────────────────────────┤
; │ Idle spark PID               │ Adds/removes timing to stabilize  │ Zero integral gain, reduce P gain   │
; │ IAC integrator               │ Slowly adjusts airflow            │ Reduce I gain or lock IAC position  │
; │ RPM filter time constant     │ Smooths RPM signal                │ Minimize filter → ECU sees changes  │
; │ Block learn / fuel trims     │ Adapts fuel to compensate         │ Force O/L at idle                   │
; │ Closed-loop fuel (O2)        │ O2 sensor correction smooths AFR  │ Must be O/L idle                    │
; │ Knock retard                 │ Heavy advance triggers KR         │ Reduce knock sensitivity at idle    │
; │ Min/max spark clamps         │ Won't let timing exceed limits    │ Widen clamp range in calibration    │
; │ Stall saver                  │ Forces IAC open if RPM too low    │ Useful — prevents stall on retard   │
; │ TCC lockup logic             │ Torque converter fights RPM swing │ Already unlocked at idle (no issue) │
; │ A/C compressor load          │ Sudden A/C clutch on/off         │ Disable A/C idle compensation       │
; └──────────────────────────────┴────────────────────────────────────┴─────────────────────────────────────┘
;


;==============================================================================
; SECTION 4: METHOD 1 — SPARK RETARD/ADVANCE OSCILLATION
;==============================================================================
; Difficulty: MEDIUM     Risk: MEDIUM     Lope: STRONG
; Requires: Code patch (JSR hook into spark calc)
;
; Concept: Alternate between heavy spark retard and advance on a timer.
;
;   Retard to -10° BTDC → engine nearly stalls, RPM drops fast
;   Snap to +25° BTDC  → torque spike, RPM jumps
;   The IAC is too slow to compensate if you oscillate fast enough
;
; Why it works:
;   Spark changes take effect on the NEXT combustion event (≈20ms at
;   800 RPM for a V6). Nearly instant. The crankshaft inertia creates
;   the visible RPM oscillation.
;
; What prevents speed:
;   - PID integral accumulates error → commands IAC to compensate
;   - Closed-loop idle spark correction tries to stabilize
;   - RPM filter smooths the reading — ECU might not "see" oscillation
;
; Implementation: See ghost_cam_rpm_delta_spark_v1.asm
;


;==============================================================================
; SECTION 5: METHOD 2 — IAC DUTY CYCLE OSCILLATION
;==============================================================================
; Difficulty: MEDIUM     Risk: LOW      Lope: MODERATE (slow response)
; Requires: Code patch or calibration abuse
;
; Concept: Rapidly open/close the Idle Air Control stepper/solenoid.
;   More air → RPM rises.  Less air → RPM falls.
;
; Why this is slower:
;   IAC is a stepper motor with mechanical response time.
;   HC11 updates IAC every 6.25-12.5ms loop, but the motor takes
;   50-200ms to physically move. The intake manifold acts as an air
;   buffer — pressure change takes time to reach cylinders.
;
; Best used as: COMPLEMENT to spark oscillation.
;   Lock IAC slightly open to prevent stalling on the retard phase.
;
; Key question: Does IAC affect idle speed enough on its own?
;   YES — IAC directly controls airflow past the throttle blade.
;   It IS the primary idle speed control actuator.
;   But its mechanical speed limits oscillation frequency.
;   It could control the AMPLITUDE of the lope (how far RPM swings)
;   while spark controls the FREQUENCY (how fast it oscillates).
;
; IAC-only ghost cam concept:
;   - Lock IAC at a fixed high position (more air than needed)
;   - Then use spark to create the oscillation
;   - The extra air makes the advance phase more aggressive (more torque)
;   - The retard phase still drops RPM because even with air, no spark = no power
;


;==============================================================================
; SECTION 6: METHOD 3 — FUEL CUT/ADD OSCILLATION
;==============================================================================
; Difficulty: EASY       Risk: HIGH (exhaust damage)   Lope: WEAK alone
; Requires: Calibration changes only (O/L fuel table)
;
; Concept: Alternate between lean and rich at idle.
;   Lean → less torque → RPM drops.  Rich → more torque → RPM rises.
;
; Why this is bad alone:
;   - Injector pulsewidth at idle is already tiny (≈2-4ms)
;   - Going lean spikes exhaust temps → O2 sensor goes haywire
;   - Going rich fouls plugs, smells, ruins catalytic converter
;   - Response is slower than spark (fuel atomize → mix → burn)
;
; Useful as: Combined with spark.
;   Enrich during advance phase, lean during retard phase amplifies effect.
;   But probably not worth the added complexity for minimal gain.
;
; Pre-ignition / startup note:
;   Wall wetting, prime pulse, and crank-fuel enrichment can be tuned
;   separately. The startup phase can actually sound great (lopey start)
;   by tuning the after-start fuel decay and prime pulse length.
;   Fuel trims during cranking can reach +10%, making for a rich choppy start.
;


;==============================================================================
; SECTION 7: METHOD 4 — OSCILLATING IDLE RPM TARGET (cleanest)
;==============================================================================
; Difficulty: MEDIUM     Risk: LOW      Lope: STRONG
; Requires: Code patch (JSR hook on idle target load)
;
; Concept: Instead of fighting the PID, make the TARGET itself oscillate.
;   Frame 1: target = 850 RPM
;   Frame 2: target = 950 RPM
;   The PID controller does ALL the work — spark + IAC chase the changing target.
;
; Why this is elegant: You work WITH the ECU, not against it.
;
; Why this is hard:
;   - Idle RPM target is a calibration CONSTANT in ROM, not a variable
;   - Must patch the code that reads it to call your oscillator routine
;   - Need free ROM space for the patch and free RAM for the counter
;   - 3-byte JSR replaces 3-byte LDAA extended — perfect fit
;
; Concept 1 — Simple timer-based toggle:
;
;   ; Hook: Replace LDAA KIDLERPD_ADDR with JSR GHOST_PATCH
;
;   GHOST_PATCH:
;       LDX  GHOST_COUNTER      ; 16-bit counter in free RAM
;       INX
;       STX  GHOST_COUNTER
;       CPX  #HALF_PERIOD        ; e.g. 10 = 10 loops × 25ms = 250ms
;       BLO  .use_low
;       CPX  #FULL_PERIOD        ; e.g. 20 = 500ms full cycle
;       BLO  .use_high
;       LDX  #$0000              ; reset counter
;       STX  GHOST_COUNTER
;   .use_low:
;       LDAA IDLE_RPM_LOW        ; 850 RPM encoded
;       RTS
;   .use_high:
;       LDAA IDLE_RPM_HIGH       ; 950 RPM encoded
;       RTS
;
; Concept 2 — Sine-wave approximation (smoother lope):
;
;   Instead of hard toggle between two values, use a small lookup table
;   that approximates a sine wave. This gives a smoother rise/fall that
;   sounds more like a real cam, less like a switch.
;
;   SINE_TABLE:  ; 8 entries = 8 × 25ms = 200ms full cycle (5 Hz)
;       .DB $6A, $70, $76, $70, $6A, $64, $5E, $64
;       ;   850  880  950  880  850  820  790  820 RPM (approx)
;
;   GHOST_PATCH_SINE:
;       LDAB GHOST_IDX           ; 0-7 index
;       LDX  #SINE_TABLE
;       ABX
;       LDAA 0,X                 ; load RPM from table
;       INCB
;       ANDB #$07                ; wrap 0-7
;       STAB GHOST_IDX
;       RTS
;
; Concept 3 — RPM-feedback driven (self-tuning lope):
;
;   Don't use a fixed timer. Instead, switch targets based on actual RPM.
;   When RPM exceeds target_high → switch to target_low.
;   When RPM drops below target_low → switch to target_high.
;   The lope frequency is determined by engine response, not a fixed timer.
;   This adapts to different conditions automatically.
;
;   GHOST_PATCH_ADAPTIVE:
;       LDAA RPM_ADDR            ; current RPM ÷25
;       LDAB GHOST_STATE         ; 0 = targeting low, 1 = targeting high
;       BNE  .check_high
;   .check_low:
;       CMPA #RPM_LOW_THRESH     ; e.g. 830 RPM encoded
;       BHI  .keep_low           ; hasn't dropped enough yet
;       LDAB #$01
;       STAB GHOST_STATE         ; switch to high target
;       LDAA #IDLE_RPM_HIGH
;       RTS
;   .keep_low:
;       LDAA #IDLE_RPM_LOW
;       RTS
;   .check_high:
;       CMPA #RPM_HI_THRESH      ; e.g. 920 RPM encoded
;       BLO  .keep_high           ; hasn't risen enough yet
;       CLR  GHOST_STATE          ; switch to low target
;       LDAA #IDLE_RPM_LOW
;       RTS
;   .keep_high:
;       LDAA #IDLE_RPM_HIGH
;       RTS
;
; Concept 4 — Exploit what's already in XDF:
;
;   The XDF has KSARPMHI / KSARPMLO (spark correction multipliers per RPM error).
;   Stock: 0.04 DEG%/RPM. If you increase these to 0.25+ DEG%/RPM and widen
;   the correction limit (KSCORLIM) from 15° to 35°, the idle loop's
;   OWN spark correction becomes oscillatory — the proportional gain is so
;   high that any RPM error causes an over-correction, which causes error
;   in the opposite direction, which causes another over-correction...
;   This is classic P-controller instability. No code patch needed.
;
;   Tune: KSARPMHI ($6525) = 0.20-0.30 DEG%/RPM
;         KSARPMLO ($6527) = 0.20-0.30 DEG%/RPM
;         KSCORLIM ($652B) = 30-35°
;         RPM error limit ($6529) = 200-300 RPM (tighter deadband)
;         RPM filter time constant → minimum
;         Idle spark integral gain → zero or near-zero
;
; Concept 5 — Combined approach (most likely to work):
;
;   Layer 1: XDF calibration changes (Concept 4) — make the idle inherently
;            unstable by cranking up the spark correction gains
;   Layer 2: If that's too slow, add the target oscillator (Concept 1 or 3)
;            to inject deliberate instability on top
;   Layer 3: Lock IAC at a fixed slightly-high position so the engine has
;            enough air to survive deep retard phases without stalling
;   Layer 4: Force O/L idle, zero fuel trims, disable knock at idle
;
;   This is the "belt AND suspenders" approach. If any single method is
;   insufficient alone, the combination of all four should produce the lope.
;


;==============================================================================
; SECTION 8: METHOD 5 — EXPLOIT EXISTING SPARK MAPS (no code patch)
;==============================================================================
; Difficulty: EASY       Risk: LOW      Lope: MILD to MODERATE
; Requires: Calibration changes only (TunerPro XDF editing)
;
; Concept: The XDF has idle spark tables with RPM breakpoints.
;   Set extreme values at adjacent breakpoints:
;     800 RPM: -20° (heavy retard)
;     850 RPM: +30° (heavy advance)
;     900 RPM: -20° (heavy retard)
;
; The engine oscillates because:
;   1. At 800, retard kills power → RPM tries to drop, IAC saves it
;   2. IAC pushes RPM to 850, advance kicks in → RPM shoots up
;   3. At 900, retard slams it back down → cycle repeats
;
; What limits it:
;   - RPM breakpoints may be too coarse (600/800/1200, not 800/850/900)
;   - Interpolation between breakpoints softens the transition
;   - PID integral gain slowly adapts and smooths it out
;
; Main vs idle spark maps:
;   Main spark maps typically span 0-4800 and 4800-6400 RPM because
;   those are the operating ranges under load. There IS an idle-specific
;   spark map (Idle Spark Advance Vs Coolant) with finer resolution,
;   but its X-axis is coolant temp, not RPM. The RPM-dependent idle
;   spark correction uses KSARPMHI/KSARPMLO multipliers, not a
;   separate RPM table.
;


;==============================================================================
; SECTION 9: METHOD 6 — INJECTOR SKIP-FIRE PATTERN (new concept)
;==============================================================================
; Difficulty: HARD       Risk: MEDIUM (exhaust temps)   Lope: VERY STRONG
; Requires: Code patch (hook into injector sequencing)
;
; Concept: Instead of modifying spark timing, skip fuel injection on
; alternating combustion events. Fire cylinders in a pattern:
;   1-SKIP-3-SKIP-5-SKIP  then  SKIP-2-SKIP-4-SKIP-6
;
; Why this would work:
;   - Running on 3 of 6 cylinders produces half power → RPM drops
;   - Switch to the other 3 → power returns → RPM rises
;   - The uneven firing creates a V-twin-like exhaust pulse
;   - This is actually what cylinder deactivation does (DOD/AFM on GM V8s)
;
; Why this is different from Method 3:
;   - Method 3 leans ALL cylinders. This KILLS specific cylinders entirely.
;   - A dead cylinder produces zero torque. A lean cylinder still fires.
;   - The asymmetric firing order creates an uneven exhaust note
;
; Challenges:
;   - Must find the injector sequencer in the code
;   - HC11 fires injectors via output compare pins — need to find the
;     routine that schedules OC events for each injector
;   - Skipped cylinders pump raw air into exhaust → catalytic converter risk
;   - Must compensate: enrich the firing cylinders to maintain overall AFR
;
; HC11 injector control:
;   On the VY V6, injectors fire in bank pairs or sequential depending
;   on the calibration. The OC (Output Compare) hardware pins trigger
;   injector driver circuits at precise crank angles.
;   Skipping one = simply don't set up the OC event for that cylinder.
;


;==============================================================================
; SECTION 10: METHOD 7 — WASTE SPARK OFFSET (new concept)
;==============================================================================
; Difficulty: EXTREME    Risk: HIGH     Lope: UNKNOWN (experimental)
; Requires: Deep code patch into ignition scheduling
;
; Concept: On a waste-spark V6, each coil fires two cylinders (1-4, 2-5, 3-6).
; The "waste" spark fires on the exhaust stroke (does nothing normally).
; What if you DELAY the waste spark so it fires during overlap?
;
; Theory:
;   - During valve overlap, both valves are slightly open
;   - A spark during overlap ignites residual mixture in the cylinder
;   - This creates a pressure pulse that fights the normal combustion
;   - The result is uneven torque pulses → lopey sound
;
; Why this probably won't work:
;   - The HC11 controls waste-spark via coil dwell, not individual spark events
;   - The "waste" spark is a hardware consequence, not software-scheduled
;   - There may not be enough mixture during overlap to ignite
;   - Risk of backfire through the intake manifold
;
; Included for completeness. This is the "nuclear option" — interesting theory,
; almost certainly impractical on this platform.
;


;==============================================================================
; SECTION 11: METHOD 8 — ALTERNATOR LOAD MODULATION (new concept)
;==============================================================================
; Difficulty: EASY       Risk: NONE     Lope: SUBTLE
; Requires: Calibration or code patch on alternator field control
;
; Concept: The ECU controls alternator field duty cycle. More field = more
; electrical load = more mechanical drag on engine = RPM drops.
; Less field = less load = RPM rises.
;
; On the VY V6, the alternator field is PWM-controlled by the ECU.
; If you oscillate the field duty between 0% and 100%:
;   - 100% field: alternator fully loaded → engine bogs → RPM drops 30-80
;   - 0% field: alternator unloaded → engine speeds up → RPM rises 30-80
;
; Why this might work as a SUPPLEMENT:
;   - Fast electrical response (milliseconds)
;   - No spark or fuel changes = no exhaust issues
;   - 30-80 RPM swing alone isn't enough for ghost cam, but stacked on
;     top of spark/IAC manipulation it adds to the effect
;
; Why this isn't enough alone:
;   - RPM swing from alternator load is only ≈50-80 RPM max
;   - Need ±150-200 RPM for an audible lope
;   - The voltage regulator will fight you (maintains 14V target)
;


;==============================================================================
; SECTION 12: FASTEST OSCILLATION PATH (RECOMMENDED ORDER)
;==============================================================================
;
; START HERE — try each step, test, move to next if not aggressive enough:
;
; Step 1: Force O/L idle — prevents closed-loop fuel from fighting
; Step 2: Calibration-only changes (Method 5 / Concept 4):
;         - Crank KSARPMHI/LO to 0.25 DEG%/RPM
;         - Widen KSCORLIM to 35°
;         - Minimize RPM filter time constant
;         - Zero idle spark integral gain
;         - Widen spark min/max clamps
; Step 3: If Step 2 isn't aggressive enough, add IAC lock (Method 2)
;         Lock IAC at a slightly-open fixed position
; Step 4: If Step 3 isn't enough, add target oscillator (Method 4 Concept 1 or 3)
;         Code patch to oscillate the idle RPM target itself
; Step 5: If Step 4 isn't enough, add direct spark override (Method 1)
;         Code patch to inject ±25° spark delta on a timer
; Step 6: For maximum effect, add skip-fire (Method 6)
;         But this is much harder to implement
;
;
; Note on Rhysk94's method:
;   He states his ghost cam tune does NOT touch timing.
;   This suggests he may be using IAC manipulation, fuel manipulation,
;   or a target-oscillation approach. Or something we haven't thought of.
;   We don't know his method — the above is our own research.
;


;==============================================================================
; SECTION 13: VERIFIED ADDRESSES FROM v3 LABELED ASM (Feb 25, 2026)
;==============================================================================
;
; These were confirmed present in Enhanced_v1.0a_bank1_labeled_v3.asm
; and bank2_labeled_v3.asm by running _check_ghost_cam_addrs.py and
; cross-referencing the v3 audit output.
;
; ── IDLE SPARK CALIBRATION (BANK1 $6500-$6560 region) ──────────────────────
;
; $6523: High Resolution Idle RPM Filter Coefficient = 2560.0 COEFF
;        eq=X*256 | raw=$0A
;        *** THIS IS THE RPM FILTER. Reducing this = faster RPM response
;        *** = ECU sees oscillation faster = MORE LOPE. Critical for ghost cam.
;        Stock $0A → try $02-$04 for faster response.
;
; $6524: IAC Spark Correction Lower Coolant Threshold = -40.0 DEG/C
;        eq=X/256*192-40 | raw=$00
;        Below this temp, no spark correction. Stock=-40°C (always active).
;
; $6525: KSARPMHI — High RPM Spark Correction Multiplier = 0.04 DEG%/RPM
;        eq=X/256/256*90 | raw=$0020 (2-byte)
;        How aggressively spark correction responds to OVER-speed.
;        Stock: 0.04. Ghost cam: 0.15-0.25 → raw $0075-$00C4.
;
; $6527: KSARPMLO — Low RPM Spark Correction Multiplier = 0.04 DEG%/RPM
;        eq=X/256/256*90 | raw=$0020 (2-byte)
;        How aggressively spark correction responds to UNDER-speed.
;        Stock: 0.04. Ghost cam: 0.15-0.25 → raw $0075-$00C4.
;
; $6529: RPM Error Limit For Spark Advance Correction = 512.0 RPM
;        raw=$0200 (2-byte, no equation — straight RPM)
;        Beyond this RPM error, spark correction saturates.
;        Stock: 512 RPM. Ghost cam: 200-300 RPM → tighter response.
;
; $652A: *** UNLABELED *** raw=$00
;        Between RPM Error Limit and KSCORLIM. Unknown purpose.
;        Could be padding, could be an undiscovered parameter.
;
; $652B: KSCORLIM — Idle Spark Correction Limit = 5.27 DEG
;        eq=X/256*90 | raw=$0F
;        Maximum spark correction the idle loop can apply.
;        Stock: 5.27°. Ghost cam: 25-35° → raw $47-$63.
;        *** THIS IS THE MAIN LIMITER. Stock 5° means the idle loop
;        *** can only swing ±5°. Bump to 35° for ±35° swings.
;
; $6536-$6540: Idle Spark Advance Vs Coolant (11x1 table)
;        eq=X/256*90-35 | stock warm cells: $AF $AF... = 26.5°
;        Base idle spark per coolant temp.
;
; $6541-$654B: Retarded Idle Spark Advance Vs Coolant (11x1 table)
;        eq=X/256*90-35 | stock warm cells: $AF $AF... = 26.5°
;        Alternative idle spark when "retarded idle" flag is set.
;
; $654C-$6555: Idle Spark Multiplier Vs CYLAIR50 (1x11 table)
;        eq=X/128 | stock: $80 = 1.0 (unity multiplier)
;        Scales idle spark based on air charge. All 1.0 stock.
;
; ── IDLE SPARK CODE (BANK2 $F835-$F8FC) ───────────────────────────────────
;
; The actual idle spark calculation routine is in BANK2, confirmed at:
;
;   $F835: CMPB $652C  ; check Load vs Closed Throttle threshold
;   $F85D: CMPB $652C  ; second load check
;   $F8D2: CMPA $6524  ; check coolant vs IAC spark lower threshold
;   $F8D7: LDD  $6525  ; load KSARPMHI (2-byte)
;   $F8E0: CPX  $6529  ; compare RPM error vs limit
;   $F8E5: LDD  $6527  ; load KSARPMLO (2-byte)
;   $F8F7: CMPA $652B  ; compare spark correction vs KSCORLIM
;   $F8FC: LDAA $652B  ; load KSCORLIM (to clamp)
;
; This is the hook region for Method 1 / ghost_cam_rpm_delta_spark_v1.asm.
; The JSR hook should go at or near $F8D7 (where KSARPMHI is loaded)
; or at $F8F7 (where the correction is clamped to KSCORLIM).
;
; ── GHOST CAM RECOMMENDED RAW VALUES ──────────────────────────────────────
;
;   Parameter               Stock Raw    Ghost Raw    Ghost Value
;   ────────────────────────────────────────────────────────────────
;   KSARPMHI  ($6525)       $0020        $0075        0.16 DEG%/RPM
;   KSARPMHI  ($6525)       $0020        $00C4        0.27 DEG%/RPM
;   KSARPMLO  ($6527)       $0020        $0075        0.16 DEG%/RPM
;   KSCORLIM  ($652B)       $0F          $47          24.96 DEG
;   KSCORLIM  ($652B)       $0F          $63          34.81 DEG
;   RPM err   ($6529)       $0200        $00FA        250 RPM
;   RPM filter ($6523)      $0A          $02          512 COEFF (faster)
;
;   All equations verified with _verify_equations.py (Feb 25, 2026).
;


;==============================================================================
; SECTION 14: OPEN QUESTIONS
;==============================================================================
;
; Q: Does the IAC valve directly control idle speed?
; A: YES. The IAC is the PRIMARY idle speed actuator. It controls airflow
;    past the closed throttle blade. More air = higher RPM. Less air = lower.
;    It IS the key to controlling the amplitude of the lope.
;    Spark controls frequency. IAC controls the "swing size."
;
; Q: Could this work on memcal-based Ecotecs (VZ/VE)?
; A: Different CPU, different addresses, different XDF. But the concept
;    is identical. The idle PID loop is fundamentally the same.
;    On memcal boards with MOATES, you could put ghost cam on tune bank 2
;    and stock on bank 1 for a switchable setup.
;
; Q: Why is main spark map 0-4800 / 4800-6400 RPM?
; A: These ranges cover the engine's operating envelope under load.
;    0-4800 handles normal driving, 4800-6400 handles WOT/high-RPM.
;    Idle (600-1000 RPM) is a tiny slice of the 0-4800 map, which is why
;    the idle spark correction system exists separately — it provides
;    finer control in that narrow RPM band.
;
; Q: Is there an idle spark map with finer RPM resolution than main spark?
; A: Not exactly. The idle spark tables are indexed by COOLANT TEMP, not RPM.
;    The RPM-dependent idle correction uses linear multipliers (KSARPMHI/LO),
;    not a table. This means there's no RPM breakpoint resolution issue —
;    the correction is continuous and proportional to RPM error.
;
;==============================================================================
; END OF FILE
;==============================================================================