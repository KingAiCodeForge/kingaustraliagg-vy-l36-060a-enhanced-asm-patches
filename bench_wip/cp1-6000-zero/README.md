# CP1 6000-zero - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Contract-preserving command-clamp experiment: nominal gate 6000 RPM, raw unsigned ceiling 0x0000.

BIN SHA-256: `a6f0674c6a4e1c2a57657aefa21a3a44a271bc6475a8a0c0ebe7ab0cd1a3ddc7`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/cp1-6000-zero/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Clamps the unsigned software command only; raw ceiling units and physical ignition suppression are unproved.
- The control profile passes through the incoming command but adds call/stack/timing overhead.
- The fallback writer and factory fuel cut remain unchanged; the 6000 RPM profile retains the lower factory fuel-cut thresholds.

Independent host review: 15 source-package unit tests passed; per-profile exact rebuild and A09 parity. No physical hardware test was performed by this intake.
