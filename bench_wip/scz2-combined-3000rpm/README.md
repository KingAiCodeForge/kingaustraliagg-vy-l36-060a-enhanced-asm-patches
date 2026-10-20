# SCZ2 combined-3000rpm - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Zero-dwell/event-path experiment with disabled, ignition-only and combined variants.

BIN SHA-256: `ba722670406269e8d669d02d5de121e6a6d7801bbd8ebefc318443ee74af81a2`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/scz2-combined-3000rpm/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- The disabled installed profile still refreshes MINDWELL to 0x00A4 on pass-through dwell calls; it is not an exact side-effect OEM control.
- The combined profile additionally requests factory fuel cut; it can conceal a failed ignition mechanism and is a later comparison.
- Shared-state/IRQ/timing ownership, zero-command electrical behavior and first event after release remain unproved.

Independent host review: 21 unit tests and 196608 model cases passed; per-profile exact rebuild and A09 addressed-byte parity. No physical hardware test was performed by this intake.
