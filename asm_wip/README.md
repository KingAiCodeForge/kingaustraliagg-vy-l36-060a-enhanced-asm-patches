# ASM WIP: exact targets, experiments and reviewed tools

Start with [current patch states](../PATCH_STATUS.md) and the [public WIP policy](../PUBLIC_WIP_POLICY.md).

The curated ghost_cam and est_shared_probe sources remain static DO_NOT_FLASH candidates, not a universal spark-cut release. Other retained ASM is unreviewed unless stronger exact-source evidence is supplied. The two retired v38 files remain unchanged at their original paths as rejected, non-build research history; their old comments and filenames are not approval. See [their retirement record](../archive/rejected/v38/README.md).

Reviewed patched images and matching per-profile ASM are organized in [bench_wip/](../bench_wip/README.md), labelled WIP_BENCH_FLASH_ONLY. They retain exact parent/output identities, hook and checksum recipes, independently assembled source and explicit limits. The legacy source collection here is retained for comparison; its names do not promote it to the reviewed image set. SC02/SC03 remain analysis-only until an actual matching implementation is recovered.

The retired v38 applier and two misleading analysis entry points now refuse without firmware I/O. Their useful signed-branch and bank arithmetic has been replaced by the [bounded read-only analyzer](../tools/hc11_static_review.py), with explicit unsupported-opcode failures and synthetic negative controls. The [bundle verifier](../tools/verify_bench_bundle.py) is a separate tool for checking complete reviewed images and reversal to the exact parent.

Do not copy hook addresses, RAM allocations or calibration offsets across VS, VT, VX, VY, L36, L67 or different program revisions. Do not upload private VX source or conversations.
