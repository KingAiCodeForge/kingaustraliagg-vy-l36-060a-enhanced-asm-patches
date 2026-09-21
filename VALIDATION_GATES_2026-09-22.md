# VY $060A patch validation gates

Gate 0 — provenance/identity:
exact full-image hash, layout, strategy applicability, known parent, definition identity, no unexplained program changes.

Gate 1 — static proof:
original bytes, instruction boundary, bank mapping, caller/callee contract, data width/endian/signedness, axes/shape and changed-byte allow-list.

Gate 2 — deterministic build/reverse:
never overwrite input, deterministic output/hash, deterministic OFF/reverse, exact diff/reparse and explicit checksum state.

Gate 3 — bounded execution:
branch/threshold behavior, relevant register/stack preservation, factory-equivalence path, OFF equivalence and invalid-input rejection. This is not whole-ECU emulation.

Gate 4 — recovery/write:
known-good bench write/readback, interruption/recovery, checksum handling and supply monitoring.

Gate 5 — internal-state bench:
Table-8 FUELCTOF, RPM/speed, relevant flags, requested/final values, ALDL continuity and reset state.

Gate 6 — physical output:
injector output for fuel cut, TIO/EST/coil output for ignition, PWM for boost, transmission command/output where applicable.

Gate 7 — controlled vehicle A/B:
log lambda/wideband, RPM/load, spark request/final spark, knock/retard, temperatures, fuel pressure if relevant, injector PW, DTC/readiness and actuator target/actual.

Gate 8 — boundary/fault:
threshold edges, cold/warm, enable/disable, sensor fault, communication loss, power cycle, timeout, stuck input and recovery.

Gate 9 — release:
supported hashes, builder/verifier hashes, manifest, reverse path, limitations, tested hardware/revision, evidence logs and recovery procedure.

A later gate never retroactively proves an earlier one.