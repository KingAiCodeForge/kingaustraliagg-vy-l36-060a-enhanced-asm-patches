# Public WIP scripts and patched-BIN policy

Updated 20 October 2026 by owner request.

## What may be published

Jason authorizes publication of his reviewed patched BINs, including SC01, SC02, SC03 and other families, with matching patch ASM. This is not limited to three names and is not permission to upload an unreviewed directory. Publication permission is not evidence of correct code or safe ECU behavior.

Improved scripts will be added to the public repositories after review, portability fixes and relevant regression tests. Keep exact-target patches, experimental probes and reusable tooling separate. Preserve variants before retiring an active implementation; never overwrite a different payload merely because its name matches.

## Candidate bundle contract

Use bench_wip/<family-revision>/ for a deliberately reviewed bundle. BIN and matching patch ASM must share a basename ending _WIP_BENCH_FLASH_ONLY; include README.md and manifest.json. Do not substitute a full private OEM/VX disassembly for the matching patch source.

Each bundle must record exact source/output/ASM SHA-256, source size and firmware identity; hook preimages; CPU/file/bank mapping; assembler version and independently rebuilt bytes; complete allowed byte changes; checksum mode and any bypass behavior; known issues and negative controls. A matching XDF export or checksum alone does not qualify a patch.

Known code defects block the executable upload. Unknown or missing assembly/control-flow evidence stays HOLD. Bench-readback, interrupted-write recovery, signal behavior and vehicle qualification are separate evidence fields; do not fabricate them or require completed road testing just to document an appropriately qualified bench-only WIP. The label limits intended use; it is not a guarantee that flashing is safe. Existing DO_NOT_FLASH manifest statuses remain in force until their own evidence justifies a change.

Never blindly stack SC01, SC02, SC03, SCZ2, ghost-cam or other families. Check hook, ROM, RAM, IRQ, timer and state ownership and qualify a separately rebuilt combined image.

## Private material

Do not upload vx_.asm or other private full VX source, raw Messenger/email exports, credentials, personal/customer data, unreviewed logs or third-party material without redistribution permission. Public credit is not consent to reproduce private quotations or a claim of endorsement. Retain applicable upstream terms; this policy does not invent a software license.

## Review and contributions

Send reproducible corrections, sanitized logs, exact input/output hashes, firmware identity, bank-qualified locations, assembler output, bench setup and negative-control results to jasonking282@gmail.com or jason.king@kingai.com.au. Please describe whether a result is static, synthetic, native execution, bench readback, measured signals or vehicle testing. Do not post VINs, customer details or private source in public issues.

The public inventory tool is read-only and never automatically approves an upload. The owner-approved publication scope is broader than the currently qualified artifact set. See PATCH_STATUS.md for what is actually available or held.
