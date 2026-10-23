# Reviewed VY $060A bench-WIP images

**Experimental research archives — not approved for ECU flashing, engine or vehicle use.**

**SC01-specific blocking finding (24 October 2026):** The existing SC01 active **and installed-disabled** images overwrite native F61AG/LPG data in the handler allocation and native VSR curves in the parameter allocation. The original SC01 also lacks independently proven missing-3X release and EST/DFI recovery. The historical `_WIP_BENCH_FLASH_ONLY` filename is not a statement of compatibility, readiness or safety. **Do not flash either SC01 image pending verified reallocation and full ignition-recovery review.** See [SC01B memory/owner investigation](../docs/SC01B_ROM_ALLOCATION_AND_HOOK_REVIEW_20261024.md).

This intake recovered nine sent v3.1 ZIP parts and verified all 384 member-manifest hashes. The public set contains **29 distinct images**, covering **32 of the 57 indexed rows** after shared-reference deduplication. The [intake ledger](intake_status.json) records each remaining HOLD or rejection. Original BIN bytes were preserved.

Each folder contains one BIN and matching ASM with the same `_WIP_BENCH_FLASH_ONLY` basename, plus `manifest.json` and `README.md`. Images are independent; do not stack them. Source compilation is addressed: never write assembler gap padding into a PCM.

The initial program installation requires a path that transfers the full program changes. A CAL-only transfer does not install these hooks. Helpers in calibration/common space must also survive later CAL overlays. These files are logical 128 KiB PCM images, not OneROM carrier wrappers.

The exact parent is Enhanced v1.0a, SHA-256 `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. The checksum-only control changes the downloaded parent word from `8E6F` to `9E9F`. No factory-reference, customer calibration, private full-source dump, correspondence or donor-source excerpt was added by this intake. Existing historical bank extracts remain elsewhere in the repository.

## Bundle index

| Family | Profile | Files and exact limits |
| --- | --- | --- |
| CP1 | 3000-control | [Bundle](cp1-3000-control/README.md) / [manifest](cp1-3000-control/manifest.json) / [BIN](cp1-3000-control/CP1_3000_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-3000-control/CP1_3000_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 3000-ose_value_0019 | [Bundle](cp1-3000-ose-value-0019/README.md) / [manifest](cp1-3000-ose-value-0019/manifest.json) / [BIN](cp1-3000-ose-value-0019/CP1_3000_OSE_VALUE_0019_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-3000-ose-value-0019/CP1_3000_OSE_VALUE_0019_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 3000-raw_0208 | [Bundle](cp1-3000-raw-0208/README.md) / [manifest](cp1-3000-raw-0208/manifest.json) / [BIN](cp1-3000-raw-0208/CP1_3000_RAW_0208_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-3000-raw-0208/CP1_3000_RAW_0208_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 3000-zero | [Bundle](cp1-3000-zero/README.md) / [manifest](cp1-3000-zero/manifest.json) / [BIN](cp1-3000-zero/CP1_3000_ZERO_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-3000-zero/CP1_3000_ZERO_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 6000-control | [Bundle](cp1-6000-control/README.md) / [manifest](cp1-6000-control/manifest.json) / [BIN](cp1-6000-control/CP1_6000_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-6000-control/CP1_6000_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 6000-ose_value_0019 | [Bundle](cp1-6000-ose-value-0019/README.md) / [manifest](cp1-6000-ose-value-0019/manifest.json) / [BIN](cp1-6000-ose-value-0019/CP1_6000_OSE_VALUE_0019_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-6000-ose-value-0019/CP1_6000_OSE_VALUE_0019_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 6000-raw_0208 | [Bundle](cp1-6000-raw-0208/README.md) / [manifest](cp1-6000-raw-0208/manifest.json) / [BIN](cp1-6000-raw-0208/CP1_6000_RAW_0208_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-6000-raw-0208/CP1_6000_RAW_0208_WIP_BENCH_FLASH_ONLY.asm) |
| CP1 | 6000-zero | [Bundle](cp1-6000-zero/README.md) / [manifest](cp1-6000-zero/manifest.json) / [BIN](cp1-6000-zero/CP1_6000_ZERO_WIP_BENCH_FLASH_ONLY.bin) / [ASM](cp1-6000-zero/CP1_6000_ZERO_WIP_BENCH_FLASH_ONLY.asm) |
| EG1p1 | active | [Bundle](eg1p1-active/README.md) / [manifest](eg1p1-active/manifest.json) / [BIN](eg1p1-active/EG1p1_ACTIVE_WIP_BENCH_FLASH_ONLY.bin) / [ASM](eg1p1-active/EG1p1_ACTIVE_WIP_BENCH_FLASH_ONLY.asm) |
| EG1p1 | control | [Bundle](eg1p1-control/README.md) / [manifest](eg1p1-control/manifest.json) / [BIN](eg1p1-control/EG1p1_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](eg1p1-control/EG1p1_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| FDC1 | 3000-2900-combined-raw000a | [Bundle](fdc1-3000-2900-combined-raw000a/README.md) / [manifest](fdc1-3000-2900-combined-raw000a/manifest.json) / [BIN](fdc1-3000-2900-combined-raw000a/FDC1_3000_2900_COMBINED_RAW000A_WIP_BENCH_FLASH_ONLY.bin) / [ASM](fdc1-3000-2900-combined-raw000a/FDC1_3000_2900_COMBINED_RAW000A_WIP_BENCH_FLASH_ONLY.asm) |
| FDC1 | 3000-2900-control | [Bundle](fdc1-3000-2900-control/README.md) / [manifest](fdc1-3000-2900-control/manifest.json) / [BIN](fdc1-3000-2900-control/FDC1_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](fdc1-3000-2900-control/FDC1_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| FDC1 | 3000-2900-short-raw000a | [Bundle](fdc1-3000-2900-short-raw000a/README.md) / [manifest](fdc1-3000-2900-short-raw000a/manifest.json) / [BIN](fdc1-3000-2900-short-raw000a/FDC1_3000_2900_SHORT_RAW000A_WIP_BENCH_FLASH_ONLY.bin) / [ASM](fdc1-3000-2900-short-raw000a/FDC1_3000_2900_SHORT_RAW000A_WIP_BENCH_FLASH_ONLY.asm) |
| FDC1 | 3000-2900-zero | [Bundle](fdc1-3000-2900-zero/README.md) / [manifest](fdc1-3000-2900-zero/manifest.json) / [BIN](fdc1-3000-2900-zero/FDC1_3000_2900_ZERO_WIP_BENCH_FLASH_ONLY.bin) / [ASM](fdc1-3000-2900-zero/FDC1_3000_2900_ZERO_WIP_BENCH_FLASH_ONLY.asm) |
| R61 | 3000-2900-active | [Bundle](r61-3000-2900-active/README.md) / [manifest](r61-3000-2900-active/manifest.json) / [BIN](r61-3000-2900-active/R61_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY.bin) / [ASM](r61-3000-2900-active/R61_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY.asm) |
| R61 | 3000-2900-control | [Bundle](r61-3000-2900-control/README.md) / [manifest](r61-3000-2900-control/manifest.json) / [BIN](r61-3000-2900-control/R61_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](r61-3000-2900-control/R61_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| REFERENCE | checksum-control | [Bundle](reference-checksum-control/README.md) / [manifest](reference-checksum-control/manifest.json) / [BIN](reference-checksum-control/REFERENCE_CHECKSUM_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](reference-checksum-control/REFERENCE_CHECKSUM_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| SC01 | 3000-2900-active | [Bundle](sc01-3000-2900-active/README.md) / [manifest](sc01-3000-2900-active/manifest.json) / [BIN](sc01-3000-2900-active/SC01_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY.bin) / [ASM](sc01-3000-2900-active/SC01_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY.asm) |
| SC01 | 3000-2900-control | [Bundle](sc01-3000-2900-control/README.md) / [manifest](sc01-3000-2900-control/manifest.json) / [BIN](sc01-3000-2900-control/SC01_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](sc01-3000-2900-control/SC01_3000_2900_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| SC61_SC62 | 3000-2800-control | [Bundle](sc61-sc62-3000-2800-control/README.md) / [manifest](sc61-sc62-3000-2800-control/manifest.json) / [BIN](sc61-sc62-3000-2800-control/SC61_SC62_3000_2800_CONTROL_WIP_BENCH_FLASH_ONLY.bin) / [ASM](sc61-sc62-3000-2800-control/SC61_SC62_3000_2800_CONTROL_WIP_BENCH_FLASH_ONLY.asm) |
| SC61_SC62 | 3000-2800-short6 | [Bundle](sc61-sc62-3000-2800-short6/README.md) / [manifest](sc61-sc62-3000-2800-short6/manifest.json) / [BIN](sc61-sc62-3000-2800-short6/SC61_SC62_3000_2800_SHORT6_WIP_BENCH_FLASH_ONLY.bin) / [ASM](sc61-sc62-3000-2800-short6/SC61_SC62_3000_2800_SHORT6_WIP_BENCH_FLASH_ONLY.asm) |
| SC61_SC62 | 3000-2800-zero | [Bundle](sc61-sc62-3000-2800-zero/README.md) / [manifest](sc61-sc62-3000-2800-zero/manifest.json) / [BIN](sc61-sc62-3000-2800-zero/SC61_SC62_3000_2800_ZERO_WIP_BENCH_FLASH_ONLY.bin) / [ASM](sc61-sc62-3000-2800-zero/SC61_SC62_3000_2800_ZERO_WIP_BENCH_FLASH_ONLY.asm) |
| SCZ2 | combined-3000rpm | [Bundle](scz2-combined-3000rpm/README.md) / [manifest](scz2-combined-3000rpm/manifest.json) / [BIN](scz2-combined-3000rpm/SCZ2_COMBINED_3000RPM_WIP_BENCH_FLASH_ONLY.bin) / [ASM](scz2-combined-3000rpm/SCZ2_COMBINED_3000RPM_WIP_BENCH_FLASH_ONLY.asm) |
| SCZ2 | disabled-installed | [Bundle](scz2-disabled-installed/README.md) / [manifest](scz2-disabled-installed/manifest.json) / [BIN](scz2-disabled-installed/SCZ2_DISABLED_INSTALLED_WIP_BENCH_FLASH_ONLY.bin) / [ASM](scz2-disabled-installed/SCZ2_DISABLED_INSTALLED_WIP_BENCH_FLASH_ONLY.asm) |
| SCZ2 | ignition-only-3000rpm | [Bundle](scz2-ignition-only-3000rpm/README.md) / [manifest](scz2-ignition-only-3000rpm/manifest.json) / [BIN](scz2-ignition-only-3000rpm/SCZ2_IGNITION_ONLY_3000RPM_WIP_BENCH_FLASH_ONLY.bin) / [ASM](scz2-ignition-only-3000rpm/SCZ2_IGNITION_ONLY_3000RPM_WIP_BENCH_FLASH_ONLY.asm) |
| V52 | reviewed-diagnostic | [Bundle](v52-reviewed-diagnostic/README.md) / [manifest](v52-reviewed-diagnostic/manifest.json) / [BIN](v52-reviewed-diagnostic/V52_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.bin) / [ASM](v52-reviewed-diagnostic/V52_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.asm) |
| V53 | reviewed-diagnostic | [Bundle](v53-reviewed-diagnostic/README.md) / [manifest](v53-reviewed-diagnostic/manifest.json) / [BIN](v53-reviewed-diagnostic/V53_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.bin) / [ASM](v53-reviewed-diagnostic/V53_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.asm) |
| V54 | reviewed-diagnostic | [Bundle](v54-reviewed-diagnostic/README.md) / [manifest](v54-reviewed-diagnostic/manifest.json) / [BIN](v54-reviewed-diagnostic/V54_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.bin) / [ASM](v54-reviewed-diagnostic/V54_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.asm) |
| V58 | reviewed-diagnostic | [Bundle](v58-reviewed-diagnostic/README.md) / [manifest](v58-reviewed-diagnostic/manifest.json) / [BIN](v58-reviewed-diagnostic/V58_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.bin) / [ASM](v58-reviewed-diagnostic/V58_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY.asm) |

## Verification

The portable read-only verifier checks candidate/ASM hashes, all change preimages, exact parent reconstruction, checksum, bank-qualified hooks and declared assembly regions. It writes no firmware. It checks the recorded assembly evidence; it does not rerun A09 or prove physical behavior.

`python tools/verify_bench_bundle.py bench_wip/cp1-3000-control/manifest.json`

Run the repository regression suite with `python -m unittest discover -s tools -p "test_*.py" -v`. Published-bundle checks need no private reference. Separate curated-catalog integration and assembler tests use optional local fixtures and may skip when absent.

Independent source-package checks passed for CP1 (15 tests), R61 (40), SC61/62 (63), SCZ2 (21), EG1p1 (53) and SC01 (43). FDC1 has 17,920 independently executed actual-byte cases; its unavailable historical suite is not counted as rerun. SCZ2 and EG1p1 also each passed 196,608 bounded model cases. V52/V53/V54 each additionally passed 138,240 bounded instruction-subset cases; V58 passed 37 tests and 196,608 fixed-bank entry-equivalence cases. Every published per-profile ASM was independently assembled with A09 V1.62 and matched against its image. These are separate bounded checks, not whole-ECU qualification.

## Material differences between controls

- CP1 control retains the incoming command but adds call/stack/timing overhead. Its 6000 RPM profiles retain the lower factory fuel-cut thresholds.

- FDC1, SC61/62 and SCZ2 installed disabled controls refresh minimum dwell in paths where the unpatched caller did not. They are not exact OEM side-effect controls.

- FDC1 and SC01 use shared flag bits whose whole-program asynchronous ownership is unproved. SC01 depends on unmeasured TIO channel/polarity and hold/re-arm behavior.

- R61 and EG1p1 intentionally qualify diagnostic behavior during their requested state; latched faults/masks and unrelated shared states still need hardware review.

- Combined fuel+ignition profiles are later comparisons: fuel cut can conceal failure of the ignition mechanism.

The corrected queue begins with reference/control comparisons, CP1, R61, SC61/62, EG1p1 and SCZ2. FDC1/SC01 now have an additional independent bank/control-flow review, recorded with each bundle. v60 remains HOLD and v38 remains retired. All controls require the same recovery and load-isolation preparation as their active partner.
