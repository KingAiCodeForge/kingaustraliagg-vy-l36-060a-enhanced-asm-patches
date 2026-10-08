# Current asm_wip direction — 2026-09-22

Read this before using historical ASM files.

The current project direction is no longer "keep incrementing the $017B fake-period spark-cut line". New VX-source + exact-$060A evidence shows:

- $017B is useful dwell/reference-history evidence, but not a proved final ignition-output primitive.
- the The1/v1.1a foreground $31EF route is rejected because it reaches an IRQ-tail/RTI return contract.
- R08 factory limiter selection -> factory FUELCTOF is the current preferred launch-control research lane.
- $1916 is diagnostic-associated M49CTR, not a periodic ghost-cam clock.
- MAFless work should be rebuilt around exact-$060A factory default-airflow semantics.
- MAP speed density remains a separate project.
- NLS/rolling/ALS should become state machines calling shared, proved output services.

Current implementation order:

1. exact target identity + tool/RAM ownership;
2. bench R08;
3. prove factory PWR state and build R09;
4. test factory retarded idle;
5. prove one RAM-shadow/RTT object;
6. trace a genuine ignition/TIO primitive;
7. rebuild higher-level features around shared services.

Evidence labels:
REFERENCE_ONLY -> STATIC_MATCH -> BOUNDED_EXECUTION_PASS -> STATIC_CANDIDATE_DO_NOT_FLASH -> BENCH_CANDIDATE -> BENCH_PROVED -> VEHICLE_TESTED.

See REPAIR_MATRIX_2026-09-21.md and ASM_WIP_VERSION_LINEAGE_AND_REBUILD_PLAN_2026-09-22.md.