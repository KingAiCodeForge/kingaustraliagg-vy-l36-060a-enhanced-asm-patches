# Current `$060A` patch status — 2026-09-21

This file supersedes old README wording that called v38/v44/v45 a “verified spark cut”.

- v38/v44/v45: `REFERENCE_ONLY` / `SUPERSEDED` as spark-cut implementations. Their bank-placement and bounded code ideas are still useful, but `$017B` is not a proved final ignition-output primitive.
- The1/v1.1a `$31EF` port: `REJECTED` for clean-parent production use because the foreground path reaches an IRQ-tail/`RTI` return contract.
- R08 fuel-cut launch: `STATIC_CANDIDATE_DO_NOT_FLASH` moving toward `BENCH_CANDIDATE`; deterministic exact-target build and bounded execution pass, hardware validation still open.
- Ghost selector: `STATIC_CANDIDATE_DO_NOT_FLASH`; `$1916` phase source rejected, factory retarded-idle path retained for targeted testing.
- MAFless v3: `HOLD / redesign`; use source-backed factory default-airflow path and exact `$060A` relocation.
- XDF width/BLM/ADX/Table-8 work: review/diagnostic evidence only, not vehicle calibration approval.
- KingAI 68HC11 C compiler/assembler: not trusted for final PCM code until documented codegen/assembler defects are fixed.

See `asm_wip/REPAIR_MATRIX_2026-09-21.md` and `evidence/2026-09-21/`.