# FDC1 3000-2900-control - experimental bench WIP

**WIP_BENCH_FLASH_ONLY. No vehicle or measured ignition qualification.**

Floor-aware main/fallback software-command experiment with independent disabled, short, zero and combined profiles.

BIN SHA-256: `37f8d6c602c437cbd699cd252d9f032d2b8cd4594e231456cb6b886acb491d46`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/fdc1-3000-2900-control/manifest.json`

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Full logical 128 KiB program image. An initial CAL-only write does not install program changes.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Uses sampled RPM byte 0x00A2 in nominal 25-RPM units, not an event-synchronous speed measurement.
- Reserves shared flag 0x0066 bit6; complete indirect/bulk/IRQ ownership is unproved.
- Normal and disabled paths also refresh minimum dwell to 0x00A4. These are installed comparisons, not exact OEM side-effect controls.
- Adds up to nine stack bytes without masking real interrupts; the bounded checks do not execute actual PCM interrupts.
- The short profile uses raw command 0x000A. The historical nominal time name is not a measured conversion.
- The combined profile separately changes native fuel-cut threshold bytes to 777477747774; disabling the spark flag does not undo those calibration edits.

Independent host review: 17920 independent actual-candidate-byte execution cases passed; exact queue rebuild and independent A09 parity. The historical FDC1 suite was unavailable and is not counted as rerun. No physical hardware test was performed by this intake.
