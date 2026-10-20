# R61 3000-2900-control - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

OEM EST-request hysteresis experiment. Disabled and active controls are separate complete images.

BIN SHA-256: `deecab3523e205081a28bfae46e65cb8eb2fedb3e0cb07784032523ff0a8dd8a`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/r61-3000-2900-control/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Uses existing OEM EST-request state and a bounded M42 qualification path; latched faults and masks remain inherited.
- The active supplied profile enables M42 qualification intentionally; a default-off builder invocation is a different image.
- Asynchronous timer/feedback behavior, safe event re-arm and whole-program state ownership remain unproved.

Independent host review: 40 R61 unit tests passed; source rebuild and independent handler/parameter A09 parity. No physical hardware test was performed by this intake.
