# VY `$060A` `asm_wip` repair matrix — VX-source / new-XDF / exact-BIN pass

**Date:** 2026-09-21  
**Exact development target:** `VX-VY_V6_$060A_Enhanced_v1.0a.bin`  
**SHA-256:** `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`  
**Primary definition used for target-side relocation:** Antus `VX VY_V6_$060A_Enhanced_v2.09b.xdf`  
**Reference source:** private VX-era `vx_.asm`, SHA-256 `cbf97987663cbf648e0085c8cfbfbf9759b34a0117b6bc7cbe71dd0080461030`; reference only, not redistributed and not an address donor.

## Evidence labels

Use only: `REFERENCE_ONLY`, `STATIC_MATCH`, `BOUNDED_EXECUTION_PASS`, `STATIC_CANDIDATE_DO_NOT_FLASH`, `BENCH_CANDIDATE`, `BENCH_PROVED`, `VEHICLE_TESTED`, `REJECTED`, `SUPERSEDED`.

Do not use generic `VERIFIED`, `PROVEN`, `WORKING`, or `READY_TO_FLASH` unless the specific claim says what was verified and at what layer.

## Global corrections that apply across `asm_wip`

1. `$017B` / file `0x101E1` is inside the dwell/reference-history chain. It is **not** a proved final spark-output/cut primitive. Preserve the bank-placement work around this hook as reference, but retire claims that changing this word proves a reliable ignition cut.
2. Enhanced v1.1a's foreground `JSR $31EF` path reaches an IRQ-tail/`RTI` path. Do not port that mechanism into a clean-parent patch.
3. `$1916` is `M49CTR`, a cam/crank-fault counter. It is not a periodic ghost-cam oscillator.
4. Do not copy VX RAM addresses into VY. Port semantic/control-flow signatures and relocate independently in exact `$060A`.
5. Do not allocate scratch RAM because it looks unused. Build a target-specific RAM ownership manifest first. Existing examples such as `$003E/$003F/$0040/$0100` have real ownership.
6. Reuse factory state/control paths where possible: Performance/Power mode, factory limiter selection, `FUELCTOF`, retarded-idle strategy, default-airflow fallback, diagnostic serializers.
7. Any patch that crosses a bank must prove active overlay/context. The old `$81E1 -> $C500/$C468` direct JSR remains invalid; common-area trampoline or same-bank placement is required.
8. Do not compile final PCM code with the current KingAI 68HC11 compiler/assembler until its ISR return, integer-width, multiply/shift, Y-indexed bit-op and forward-reference relayout defects are closed. Use hand-audited ASM, a known assembler, exact expected bytes and an independent verifier.

## Folder/file repair plan

### `spark_cut/`

All existing spark-cut variants are **historical research / HOLD** until a genuine ignition/TIO output primitive is traced from request -> scheduler -> dwell/EST enable -> TIO command -> physical output.

- `spark_cut_chr0m3_method_VERIFIED_v38.asm` — **SUPERSEDED name/status.** Keep as dwell-chain experiment only. Remove “BEST/VERIFIED spark cut” claims. Its `$017B` hook is not final-output proof.
- `spark_cut_3x_period_VERIFIED.asm` — **SUPERSEDED name/status.** Reclassify as period/dwell perturbation experiment. Do not call it verified ignition cut.
- `PATCH_BYTES_v38.asm`, `spark_cut_3000rpm_TEST_v38t.asm`, `Spark_cut_3000rpm_test_11p_style_v43.asm`, `spark_cut_6000rpm_v32.asm`, `spark_cut_chrome_method_v33.asm` — **REFERENCE_ONLY.** They inherit the same unproved low-level cut primitive.
- `spark_cut_11p_style_v44_BANKFIX.asm` — **REFERENCE_ONLY / bank-placement analysis useful.** Keep the common-area/same-bank correction; remove the conclusion that fake-period injection itself is a proved spark cut.
- `spark_cut_11p_style_v45_engineBANK.asm` — **REFERENCE_ONLY / bank-layout analysis useful.** `$5D05` vs `$FEA2` placement analysis is useful. The underlying `$017B` cut mechanism remains HOLD.
- `spark_cut_the1_method_port_v39.asm` — **REJECTED for production port.** The `$31EF` foreground call enters an IRQ-only path ending in `RTI`; rebuild from clean v1.0a only after the true ignition output path is traced.
- `spark_cut_dwell_patch_v37.asm` — **REFERENCE_ONLY.** Treat MIN_DWELL/MIN_BURN work as timing-budget research, not proof that a hard spark cut is safe above the factory high-RPM boundary.
- `spark_cut_bmw_inspired_v40.asm`, `spark_cut_delco_optimized_v41.asm`, `spark_cut_progressive_soft_v9.asm`, `spark_cut_rolling_v34.asm`, `spark_cut_soft_timing_v36.asm`, `spark_cut_combined_fuel_v35.asm`, `spark_cut_two_stage_hysteresis_v23.asm`, `spark_cut_6375_safe_mode_v18.asm`, `spark_cut_original.asm` — **SUPERSEDED feature shells.** Retain any high-level state/hysteresis ideas, but replace their low-level cut/flag/RAM core with one future proved primitive.

**Replacement direction:** launch/limiter work should use the R08 factory limiter-pointer + factory `FUELCTOF` path first. Spark-cut work resumes only after true TIO/EST output tracing.

### `old_versions/` and `rejected/`

- Keep as history only. Add a folder README saying these must never be promoted by filename or copied as patch bases.
- `REJECTED_methodB_dwell_override.asm` remains rejected.
- Any `$01A0` / “free bit” auto-fix comments are historical. A current RAM ownership proof is required before any scratch byte/bit is reused.

### `shift_control/`

- `launch_control_two_step.asm`, `shift_launch_v1.asm` — replace embedded spark/dwell cut with R08/factory limiter-pointer selection for the first working launch lane. Add Performance-mode arm and speed/range/TPS/brake/clutch qualifications only after each exact target state is proved.
- `flat_shift_no_lift.asm`, `no_lift_shift.asm`, `shift_bang_manual.asm` — keep the detection/state-machine idea; remove independent cut primitives. Future design should emit a shared `CUT_REQUEST` to one proved ignition/fuel primitive. Do not reuse guessed scratch RAM.
- `shift_bang_auto.asm`, `shift_retard.asm`, `timing_retard_soft.asm` — audit against exact `$060A` transmission control. New source evidence shows the `0.4 s` minimum-shift-time item at `$4276/$4277` is an **adaptation qualifier**, not a direct hydraulic shift-duration command. Separate `COMMAND`, `TARGET`, `QUALIFIER`, `LIMIT`, `DIAGNOSTIC THRESHOLD` semantics before edits.

### `ghost_cam_ASM_PATCH/`

- `ghost_cam_rpm_delta_spark_v1.asm` — keep only as a control-concept experiment. The stronger first path is the factory retarded-idle strategy already traced in exact `$060A`.
- `ghost_cam_rpm_rotating_idle.asm` — **redesign phase source.** `$1916` is a cam/crank-fault counter and must not drive periodic oscillation. Use a proved scheduler/event counter after exact relocation. Preserve hook/normal-vs-retarded idle selector only where exact code evidence supports it.
- Before ASM oscillation, vehicle-test calibration-only factory retarded idle and log final spark/idle control response.

### `lumpy_idle_XDF_ONLY/`

- Keep calibration-only lane separate from “ghost cam”. Re-check every title/equation against v2.09b and the six word-width corrections. Do not infer causal meaning from an XDF title alone.

### `fuel_systems/`

- `fuel_cut_enhanced.asm` — highest-value salvage candidate. Rebase around exact factory limiter/FUELCTOF semantics shown by R08. Add exact-target manifests and downstream diagnostic proof.
- `mafless_alpha_n_v1.asm`, `mafless_alpha_n_v2.asm`, `mafless_alpha_n_v3.asm`, `alpha_n_tps_fallback.asm`, `mafless_tpi_method.asm` — **HOLD / redesign.** The old v3 has undefined flags, confuses DTC/action masks with runtime fail state, risks sibling-bit destruction, has contradictory airflow units/layouts and imports foreign ECU assumptions. Use the VX-source default-airflow producer as the semantic oracle, then relocate the exact VY producer/consumer.
- VY default-airflow engineering conversion recovered in this pass: `airflow_g/s = raw_word / 128`; `$01C0 = 3.5 g/s`, `$00C8 = 1.5625 g/s`. Retire notes treating `$00C8` as 200 g/s.
- `speed_density_fallback_v1.asm`, `speed_density_ve_table.asm` — **separate MAP/load-model project.** Factory default-airflow fallback is not proof of real MAP-based speed density. Require MAP hardware/input path, ADC/conversion, load consumer, plausibility/fault handling and full fueling arbitration.
- `e85_dual_map_toggle.asm` — migrate selector to the factory Performance/Power state after exact VY state/bit proof. Keep fuel-property changes as separate calibrated data, not a switch-only feature.

### `cold_maps_only_for_tuning_patch/`

- Existing files explicitly contain the old cross-bank `$81E1 -> $C468` pattern. **Do not fix only the jump target.** First decide whether the feature actually needs an ASM hook after exact XDF semantics are reviewed.
- `cold_maps_force_cold_spark_v1.asm` — prefer XDF-only strategy if the desired factory multiplier/selector can be calibrated directly. If code selection is still needed, relocate the actual temperature/selector path rather than hooking dwell history.
- `alpina_mafless_fallback_v1.asm` — fold into the redesigned factory default-airflow/Alpha-N lane; remove BMW table-name assumptions that are not exact `$060A` semantics.
- `cold_maps_tuning_alpina_method_v1.asm` — documentation/reference only; split BMW inspiration from Holden-proved facts.

### `turbo_boost/`

- `boost_controller_pid.asm` — separate project. Require an exact output driver/PWM channel, input sensor path, failsafe state, actuator range and bench output proof before enabling.
- `overboost_protection.asm` — first implement as a bounded request into a proved factory fuel-cut/limiter primitive, not a guessed spark intervention.
- `antilag_turbo.asm`, `antilag_rolling.asm`, `antilag_cruise_button.asm`, `hybrid_fuel_spark_limiter.asm`, `turbo_limiter_v1.asm` — **future/high-risk.** Keep state-machine ideas only; rebuild around proved ignition/fuel primitives with EGT/lambda/knock/temperature safeguards and explicit arming.

### `needs_validation/` and `needs_more_work/`

Keep these quarantined. The new TIO microcode/startup audit improves the map of the hardware-output layer but does not make the old direct-timer guesses valid automatically. For every method, prove exact register ownership, scheduler/ISR context, masking, fallback and actual pin waveform before promotion.

## New primary implementation sequence

1. Exact v1.0a hash + v2.09b definition identity gate.
2. Integrate corrected HC11 decoder and regenerate affected traces.
3. Maintain target-specific RAM/symbol ownership manifest.
4. Bench R08 with RPM/speed stimulus, Table-8 `FUELCTOF`, serial continuity, injector command scope and supply/reset monitoring.
5. Prove the VY Performance-mode RAM/bit by producer + consumers + read-only observation; then add PWR gating to an R09 selector.
6. Test factory retarded-idle calibration path physically before custom periodic modulation.
7. Prove one RAM-shadow lookup object and transport path without affecting engine control.
8. Trace genuine ignition output/TIO path and create one shared low-level `CUT_REQUEST` primitive.
9. Rebuild NLS/rolling/ALS/other features as state machines calling shared primitives, rather than independent blobs.

## Public evidence uploaded with this repair branch

The branch includes public-safe extracts under `evidence/2026-09-21/`. Private `vx_.asm`, full BINs, full XDF/ADX definitions and the R08 patched review BIN/XDF are deliberately excluded.