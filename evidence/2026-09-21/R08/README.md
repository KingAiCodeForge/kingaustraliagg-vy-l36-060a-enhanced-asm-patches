# R08 exact-target launch/fuel-cut evidence

Status: **STATIC_CANDIDATE_DO_NOT_FLASH** with **BOUNDED_EXECUTION_PASS**.

## Intake correction - 20 October 2026

The original PR revision accepted a synthetic parent with the wrong SHA-256
when its local preimages matched, and its verifier printed PASS for two empty
inputs under `python -O` because assertions were removed. The builder now
checks the complete documented parent hash, and verifier requirements remain
active with optimized Python. Focused regressions are in `test_r08_preflight.py`.
The older `validation.json` is a historical receipt, not a rerun of this repair.

This fixes those two software defects only. Installed-image on/off validation,
exclusive multi-output publication/rollback, exact bank/caller contracts and
independent native/bench/recovery evidence still require review. Keep this PR
draft and do not promote its builder or firmware to public master/release merely
because these focused checks pass. The existing checksum-bypass byte is retained,
not established as a generally valid checksum policy.

Target:
- `VX-VY_V6_$060A_Enhanced_v1.0a.bin`
- SHA-256 `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`

This public folder intentionally excludes the patched review BIN and full generated XDF. Use `build_launch_patch.py` against a lawful exact target image to reproduce a candidate and its generated target-specific XDF/manifest.

Architecture:
- file `0x12582` / CPU `$A582`: `LDX #$77DE` -> `JSR $FEC0`
- `$FEC0` selector reads raw RAM `$98`
- raw speed <=2 selects a shadow limiter block at `$FF00`
- above the gate it selects the unchanged factory limiter block at `$77DE`
- downstream factory logic owns the actual RPM compare and `FUELCTOF` action

Important limits:
- raw `$98` scaling is not asserted as km/h
- all ranges are currently eligible; no P/N/R, TPS, brake or clutch qualification
- no hardware, IRQ/full-system, TunerPro GUI or exact-v1.0a vehicle validation in this package
- source package records user feedback for preceding R07b, not comprehensive validation of this R08 v1.0a port
- use full-BIN handling only; the implementation is not a cal-only patch

The next intended revision is PWR-gated R09 after the exact VY Performance-mode state is independently proved, followed by range/TPS/brake/clutch gates where required.
