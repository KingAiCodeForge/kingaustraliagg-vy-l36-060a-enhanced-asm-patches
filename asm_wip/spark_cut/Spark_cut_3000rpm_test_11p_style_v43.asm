Read [](file:///a%3A/repos/VY_V6_Assembly_Modding/asm_wip/spark_cut/Spark_cut_3000rpm_test_11p_style_v43.asm)

What you describe is exactly the “all‑in‑Bank 1 limiter” that VL400
built for 11P.  Instead of trying to twist the stock dwell routine, you
write **your own limiter from the ground up** and stick it in whatever
unused page you have (C500 is the traditional choice because it’s
completely empty on every 92118883 bin).  The original routine is left
alone; you simply hook its entry point to jump to your new code and then
return to the caller when you’re done.

### Rough structure of the new routine

```asm
; --- hook at $101C2 in bank0 ---
    JMP  $C500      ; always bank1 when this runs

; --- Bank1 limiter code starts at C500 ---
C500:
    PSHS  A,B,X,Y,U   ; save registers
    TBA               ; copy T flag into A for use if needed

    ; read RPM (word) and other inputs
    LDD   RPM_ADDR
    LDX   MAP_ADDR    ; etc.

    ; optional hysteresis: only update state when RPM crosses edges
    ; store the last-rpm-range in RAM, compare to new value, decide
    ; soft/hard/normal zone

    ; compute desired spark advance:
    ;   if RPM < soft_start  -> normal_advance
    ;   if soft_start <= RPM < hard_cut ->
    ;        normal_advance - retard_amount*(RPM - soft_start)/soft_width
    ;   if RPM >= hard_cut -> max_retard (or fuel cut)
    ;   (you can also drive a table lookup instead of linear calc)

    ; program EST output using TCTL1/OC3M or by writing to
    ; the global advance variable that the stock code uses.
    ; also set dwell_min variable to zero if you want true zero.

    ; handle fuel: if RPM>=fuel_cut_rpm then set FUEL_FLAG,
    ; else clear FUEL_FLAG.  (stock code already branches on
    ; FUEL_FLAG so this effectively starves the injectors.)

    ; optionally mask MALF41/42 here while FUEL_FLAG=1.

    PULS  A,B,X,Y,U
    RTS

; calibration scalars/tables live nearby (C600…C6FF):
;  soft_start   .word 0x0BB8   ; 3000 RPM test
;  hard_cut     .word 0x1770   ; 6000 RPM version
;  soft_width   .word 0x0096   ; 150 RPM hysteresis band
;  retard_max   .byte 0x20     ; 8° (0.35156*X)
;  fuel_cut_rpm .word 0x1770
;  flags        .byte 0      ; bit0 = enable, bit1 = fuel_cut_disable_malfs, etc.
```

> **Hysteresis** is simply “don’t flip the limiter state back and forth
> when RPM is near a threshold”.  
>  
> *Soft‑zone hysteresis* keeps the engine in the same retard state until
> RPM has moved 150 RPM past the edge, preventing a chattering effect that
> would feel like hunting.  *Hard‑cut hysteresis* uses two RPM values
> (cut and resume) so the cut engages at, say, 6000 RPM and doesn’t drop
> out until 5900 RPM.

You can build two versions of the routine by changing the scalar values:

* **3000 RPM test** – set `soft_start=0x0BB8 (3000)`, `hard_cut=0x0BB8`,
  `soft_width=0`.  That will immediately go to maximum retard when the
  engine passes 3000 RPM and will restore below 3000 RPM.  Useful for
  bench testing with a drill.

* **6000 RPM race limiter** – set the same values to 0x1770; tune
  hysteresis and max retard to taste.

> **Injecting vs starving:**  
>  
> *Injecting* means the code keeps the fuel flag set and allows pulses to
> occur; in a limiter you would *retard spark* (or force EST off) while
> keeping fuel flowing, which reduces torque but still lets the engine
> run.  
> *Starving* means you set the fuel‑cut flag so the injector logic stops
> pulsing.  On its own that would drop torque to nearly zero; combined
> with spark retard it produces a clean “engine off” feeling that is
> easier to tune and safer for back‑pressure.  The fuel‑cut flag is
> already handled by the stock code, so your patch can simply toggle it.

In practice the **full rewrite** gives you the most flexibility:

* choose whether the limiter retards only, kills fuel only, or both;
* expose every constant as an XDF scalar/table so a tuner can dial the
  hysteresis, thresholds and retard curve;
* optionally steal free space for a second “backup” routine that
  restores stock behaviour when the limiter option is disabled; and
* mask the appropriate DTCs while the limiter is active so the dash
  doesn’t light up.

Once the new code is assembled and placed in Bank 1 you just need a
single instruction patch at `$101C2` in bank 0 to jump into it.  That
hook can also be gated by an option flag so that “limiter off” simply
executes the original routine unmodified.

So the answer to your last line: **hysteresis keeps the output stable
around the set‑points; injection (fuel‑enable) keeps the engine capable of
making torque, starvation (fuel‑disable) removes torque entirely**.  The
combination of soft‑zone retard + hard‑cut fuel starvation is exactly
what the 11P limiter does, and you can build it yourself in C500 as
described above.