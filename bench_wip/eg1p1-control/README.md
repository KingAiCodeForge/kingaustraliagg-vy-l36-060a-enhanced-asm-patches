# EG1p1 control - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Three-hook ignition-event inhibition experiment; active and control are separate profiles.

BIN SHA-256: `ba91fbb9f49091571556c327eb7f0e7322812ac502b8cfedabace858ee5ccb77`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/eg1p1-control/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Intentionally changes shared native run-init state 0x44 bit4; no newly isolated private latch is allocated.
- Same-state diagnostic qualification may overlap unrelated states. The 18X guard does not establish whole-program asynchronous ownership.
- Physical event suppression, coil charging and safe re-arm remain unproved.

Independent host review: 53 unit tests and 196608 model cases passed; exact rebuild/reversal and independent A09 addressed-byte parity. No physical hardware test was performed by this intake.
