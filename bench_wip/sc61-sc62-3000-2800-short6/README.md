# SC61_SC62 3000-2800-short6 - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Shared EST-permission hysteresis plus final command/floor experiments. Keep control, short6 and zero separate.

BIN SHA-256: `a462ade7f0e3461febb8d41bac436325dcbb8df105da230f74c1ebfe867eb4ed`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/sc61-sc62-3000-2800-short6/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Normal dwell writes additionally refresh MINDWELL to 0x00A4, including the disabled installed control; this is not an exact side-effect OEM control.
- Short6 and zero are raw command experiments; scope evidence is required for their physical effect.
- Uses an existing shared permission bit. The instruction-subset model does not establish whole-program state ownership.

Independent host review: 63 SC61/62 unit tests passed; source rebuild and independent handler/parameter A09 parity. No physical hardware test was performed by this intake.
