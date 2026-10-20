# V54 reviewed-diagnostic - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Factory fuel-cut-state software command comparison: raw 0x0208.

BIN SHA-256: `b4cabc198a8bdb3f023901e9544320d8bb111470a824b63813e7093dc035a9dd`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/v54-reviewed-diagnostic/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Both command-store hooks call common 0x5D05. Later normal writers can overwrite the software command; physical output authority is unproved.
- Factory injector fuel cut is retained. Raw command zero/0x0208 is not a calibrated dwell value or a demonstrated spark-off mechanism.
- Selected synchronous caller paths were checked; this does not establish IRQ observation, whole-program timing, stack margin or peripheral effects.
- When active, D and N/Z differ on return. Fresh checks of both main successors and fallback show overwrite before use; that result is bounded, not a universal preserved-register contract.
- This separately named reviewed diagnostic copy does not alter legacy source/catalog DO_NOT_FLASH status or qualify other builds from those sources.

Independent host review: 138240 instruction-subset cases passed for this profile; exact independent A09 reconstruction and bounded actual-byte caller review. No physical hardware test was performed by this intake.
