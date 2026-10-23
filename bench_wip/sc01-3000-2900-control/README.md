# SC01 3000-2900-control - historical DO NOT FLASH archive

**HOLD — do not flash this existing SC01 image to any PCM. Research/provenance only.**

**Reproduced native allocation collisions (24 October 2026):** SC01's 333-byte handler at `$5D05..$5E51` overlaps native F61AG/LPG data, and its five-byte cut/return/enable parameters at `$5EF0..$5EF4` replace portions of native VSR curves. In the active build the conditional native lookup at `$5EF3` changes from `$0000` to `$54A5`; in the disabled control it still changes to `$5400`. The latter therefore is **not** an unchanged factory-function control. Missing-3X HELD release and physical EST/DFI/M42 recovery remain unproved. This supersedes any implication of flash readiness in the historical filename. See [SC01B allocation/recovery review](../../docs/SC01B_ROM_ALLOCATION_AND_HOOK_REVIEW_20261024.md).

Phase-qualified event-hold experiment with real IRQ continuations; disabled and active are separate complete images.

BIN SHA-256: `7670fcc475f7273f8a2e924466a10eb369499209e2ac90c8b098ba2dd41241a3`.
Exact source SHA-256: `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Logical size: 131,072 bytes.

The BIN bytes are unchanged from the recovered v3.1 peer pack. The matching ASM is a comment-cleaned, per-profile source assembled independently with A09 V1.62. The manifest supplies hook replacements and checksum changes separately from addressed source sections. Never apply assembler gap padding as firmware.

The manifest preserves the original `WIP_BENCH_FLASH_ONLY` status for historical identity and adds the overriding `current_disposition: HISTORICAL_DO_NOT_FLASH`. The original basename and [historical bench prerelease](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches/releases/tag/bench-wip-2026.10.20) are not current recommendations.

The manifest records every changed byte and its original preimage. The read-only verifier checks hashes, checksum and reversal to the exact parent; it does not authorize a flash.

Run from the repository root:

`python tools/verify_bench_bundle.py bench_wip/sc01-3000-2900-control/manifest.json`

A static integrity PASS retains `release_ready: false`. Adding `--require-release-ready` to that command returns exit 1. This gate does not prevent manual flashing of downloaded bytes.

Limits:

- No measured ignition/EST/DFI/coil, bench readback, interrupted-write recovery or vehicle qualification is claimed.
- Historical full logical 128 KiB image identity only; no installation is recommended.
- Use the exact declared program parent. Do not stack with other cave/hook/RAM users or logger/RBCP/OneROM additions.
- ASM-to-BIN parity and instruction-subset models do not prove whole-ECU IRQ, timing, stack or shared-state ownership.
- This is a logical PCM image, not a transformed OneROM carrier file.
- Reserves shared 0x0066 bits6/7. Whole-program indirect, bulk and IRQ ownership is unproved.
- Requires unproved TIO DATAL channel 14/4 mapping and polarity; its 16-iteration settle window does not establish hardware completion.
- Pauses expected missing-edge observation while its hold state is acquired, and releases through the next native 3X path.
- Native scheduler and diagnostic calls retain caller bank assumptions. Live bank-latch, stack, IRQ and asynchronous behavior remain unproved.
- The authored builder exported the matching ASM; the export was independently assembled, not reconstructed from guessed opcodes.

Independent host review: 43 bounded source-package tests passed; exact queue rebuild and independent A09 parity. No physical hardware test was performed by this intake.
