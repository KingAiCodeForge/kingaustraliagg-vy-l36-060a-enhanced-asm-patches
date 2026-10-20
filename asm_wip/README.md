# ASM WIP: exact targets, experiments and reviewed tools

Start with [current patch states](../PATCH_STATUS.md) and the [public WIP policy](../PUBLIC_WIP_POLICY.md).

The curated ghost_cam and est_shared_probe sources remain static DO_NOT_FLASH candidates, not a universal spark-cut release. All other retained ASM is explicitly unreviewed unless stronger exact-source evidence is supplied. The two retired v38 files were preserved before removal from this active layout.

Owner-approved patched BINs may be added with matching ASM after individual review, labelled WIP_BENCH_FLASH_ONLY, not vehicle-ready. SC01/SC02/SC03 are not exceptions to source identity, code correctness or provenance checks. More scripts will be promoted after portability and regression work.

Do not copy hook addresses, RAM allocations or calibration offsets across VS, VT, VX, VY, L36, L67 or different program revisions. Do not upload private VX source or conversations.
