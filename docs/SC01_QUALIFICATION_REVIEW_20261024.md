# Legacy SC01 quarantine and checker qualification - 24 October 2026

This isolated review builds on draft [PR #11](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches/pull/11), pinned at `e71544fcb8c51250521ede301f3b18c00ae56f77`, compared with public master `6a123e19cfab1b06284ef9452965faf918cba595`. Both live tips were checked before work. This is review-branch work for later integration; it does not establish that these corrections are already on master or in an existing download.

**Legacy SC01 active and installed-disabled remain DO NOT FLASH.** Native-data collisions affect the handler at `$5D05` and parameters at `$5EF0`. No executable allocation is approved. No firmware was built, patched or flashed, and SC01b/V3 development remains a separate workflow. Existing research worktrees and their branches were not edited.

## Public routes inspected

- Root README previously included SC01 in the bench-flash publication paragraph. PATCH_STATUS grouped it with reviewed bench-WIP. The two per-image READMEs warned of collisions, while manifests and intake rows still presented historical `WIP_BENCH_FLASH_ONLY` / published decisions without a machine-readable current quarantine.
- The [bench-wip-2026.10.20 prerelease](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches/releases/tag/bench-wip-2026.10.20) still describes 29 reviewed experimental images including SC01. Its downloaded `vy060a_reviewed_bench_wip_2026.10.20.zip` has 189 members, including both SC01 BIN/ASM/manifests/notes and a top-level bench-WIP README. SHA-256 reproduced: `f3e07c12e61021303b29a81108a4c2cd94a21e5efe9baa5e93f7320759d0c716`.
- The [offline-tools-2026.10.20 prerelease](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches/releases/tag/offline-tools-2026.10.20) describes a source/tool-only package without firmware. Its release metadata was read; its ZIP was not downloaded in this review.
- Repository source archives, old tags, direct BIN URLs and already-downloaded ZIPs remain possible historical access paths. This change adds current warnings and a tool gate; it cannot prevent manual flashing or update an old downloaded copy.

No historical release name, tag, asset, checksum, BIN, ASM or source history was replaced or removed. Existing remote release descriptions were not edited. The current index now separates 27 unqualified bench-WIP images from two quarantined historical SC01 images. No image is marked release-ready.

The verifier retains static integrity checks and the historical manifest status as `declared_status`. Its current classification follows the actual SC01 SHA-256 even with renamed files, stripped disposition or false family metadata. Forged current qualification is refused. `--require-release-ready` provides a distinct nonzero-exit gate; it does not turn integrity failure into a pass or approve another bundle.

## Independently reproduced defects and repairs

PR #11's synthetic test API returned `known_native_pointers_preserved: true` while skipping all seven native CAL-reader signatures. A synthetic fixture with zero matching signatures reproduced that result. Schema v2 now emits `null`, zero checked/seven skipped and an explicit synthetic status. Exact-source CLI admission remains the pinned complete SHA-256; its seven selected signatures still must match. All rows retain `executably_free: false` and `approved_patch_spans: []`.

The old atomic-creation test called Python `open("x")` directly. It did not exercise the CLI or verify completed publication. The replacement tests execute the actual parser/main and real subprocess CLI, inspect completed JSON before publication, preserve a concurrently created destination and input aliases, and inject a failed sync before publication. A sibling temporary file is completely written, flushed and closed before exclusive publication. Windows uses non-replacing rename; POSIX uses an exclusive hard link. Filesystem/ECU power-loss recovery is not established.

The report now separately scans maximal zero runs and counts curated rows: **14 maximal runs of at least 64 bytes; 15 curated rows**. One 504-byte run `[0x05D05,0x05EFD)` contains both handler and parameter rows. The other thirteen runs each correspond to one row. Counts describe storage contents, not unowned executable space.

## Exact local inputs and byte comparison

| Input | Size | SHA-256 |
| --- | ---: | --- |
| Exact Enhanced automatic v1.0a parent | 131072 | `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd` |
| Related private VX donor ASM, read locally only | 4470398 | `cbf97987663cbf648e0085c8cfbfbf9759b34a0117b6bc7cbe71dd0080461030` |
| Historical SC01 active | 131072 | `6e63865810f452c310b83a368a0f2ee9ab942f6a53d3e38af8d2215c302a662a` |
| Historical SC01 installed-disabled | 131072 | `7670fcc475f7273f8a2e924466a10eb369499209e2ac90c8b098ba2dd41241a3` |

All four before/after hashes match. The related VX source supplied symbolic/routine crosschecks; it is not byte-identical source for the Enhanced image, and no uniform address delta was assumed. No restricted source excerpts or raw donor files are included here.

Thirteen selected exact-parent native signatures also remain present in both SC01 images. The bank3 lookup at file `0x18364` still loads `$5EF3` and calls the native lookup helper, while the word at `$5EF3` changes from parent `0000` to active `54A5` or disabled `5400`. The F61AG lookup points into the handler allocation; each SC01 changes 332 bytes within its 333-byte handler span. The five-byte parameter span changes five bytes active and four disabled. These static comparisons support the existing collision HOLD; they do not establish physical operating-state reachability or ignition behavior.

## Executed qualification

Final checks ran after the isolated writers stopped editing. Python 3.13.5 and Capstone 5.0.6 were used on JasonsPC. Repeated and focused counts overlap and must not be added as unique coverage.

- Combined repository suite, normal and `-O -B`: **109 tests run, 106 passed, zero failures/errors, three optional skips; exit 0** in each mode. The three skips and deliberately excluded firmware-building fixtures are explained below. Normal log SHA-256: `1e451063b46fafd1b77708e42d061e49245efb4f520e53cec8f50cafb3e024fa`; optimized log: `a7e750d951daff7777fef34793d37fd940c6a025d8accda22b14a23a3567418e`.
- Focused checker: 22/22 pass with no skips, normal and `-O -B`, using the available exact parent read-only. Actual JSON has seven checked/zero skipped signatures, fifteen curated rows, fourteen zero runs and no approved allocation; synthetic JSON has zero checked/seven skipped and null preservation.
- All 29 bundle manifests: actual normal and optimized CLI integrity runs return exit 0, with 29 integrity PASS results and `release_ready: false`. The same runs with `--require-release-ready` return exit 1 for all 29, retaining the integrity reports; two are classified historical SC01.
- Every tracked BIN/ASM remains unchanged relative to the pinned source commit. Per-image bytes and original manifest identity fields are preserved; current quarantine metadata is additive.

The inspected exact-source JSON file SHA-256 is `d2219acfbbf12a3008c36e987d35269209efd49164bb8dac0c4d462193146684`. Its parsed contents match CLI stdout; Windows stdout uses CRLF whereas the portable JSON file uses LF. The 34 focused verifier/quarantine tests also pass in both modes without skips, and overlap the combined suite.

The combined suite deliberately receives neither `VY_V1_0A_BIN` nor `A09_ASSEMBLER`: its optional candidate-builder and assembler tests are outside this task's no-firmware-construction scope. This is a scope exclusion, not missing-source evidence. The optional exact-source checker test is run separately with the real available input, as described above. No tests were weakened or converted to skips.

Reproduction commands from the repository root:

```console
python -B -m unittest discover -s tools -p "test_*.py" -v
python -O -B -m unittest discover -s tools -p "test_*.py" -v
python -B tools/test_sc01b_zero_space_gate.py
python -O -B tools/test_sc01b_zero_space_gate.py
python -B tools/sc01b_zero_space_gate.py --image "<exact locally owned parent>" --json-out "<new report.json>"
python -B tools/verify_bench_bundle.py bench_wip/sc01-3000-2900-active/manifest.json
python -O -B tools/verify_bench_bundle.py --require-release-ready bench_wip/sc01-3000-2900-control/manifest.json
```

Set `VY_V1_0A_BIN` only for the focused read-only checker tests to reproduce their optional exact-input case. Do not supply it to the complete suite within a no-build review.

## Remaining limits and next owner action

This branch is not merged, and the old release ZIP/descriptions remain historical. The integration owner must review the exact candidate and PR #11 dependency before later main promotion. Any future package must use current warnings and eligibility checks rather than treating historical integrity PASS as release approval.

Handler/parameter ownership, global computed readers, RAM ownership, bank/IRQ behavior, missing-reference release and physical EST/DFI recovery remain unresolved in the separate research lane. Static checks are not physical ignition validation. No main merge, force push, release publication, firmware construction or hardware operation belongs to this review.
