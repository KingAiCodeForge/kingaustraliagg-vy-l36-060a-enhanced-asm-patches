# KingAI VY `$060A`: TIO linear-disassembly correction and checksum admission HOLD

**Engineering checkpoint:** 25 October 2026 (Australia/Adelaide).  
**Owner:** KingAI Pty Ltd.  
**Status:** READ-ONLY STATIC EVIDENCE; NO NEW FIRMWARE, NO PCM/VEHICLE FLASH APPROVAL.  
**Provenance:** **ChatGPTz idea 💡** — AI-generated code/data fencing and checksum admission observations, inspired by the user's SC01B reverse-engineering request, exact VX `TIOUCODE`/table source match, `bank_split_output`, private full-image static IR PR #292 and the public `vy_flash_checksum.py` tool. Muncie's Stage20 and The1 V3 lineages are separate.

## 1. Newly established issue: TIO configuration masquerades as HC11 code

The public `bank_split_output/Enhanced_v1.0a_bank3.asm` was produced with a linear disassembler. A **byte-identical VX source region** has now been verified across three exact VY images (see below). The region at **physical file `[0x1C3AF,0x1CC37)`**, which maps to **bank3 CPU `[$C3AF,$CC37)`**, is source-defined table/initialization/microcode **data**, not HC11 program instructions. The correct executable TIO startup routine begins at bank3 CPU `$CC37`.

A fresh independent analysis of the exact GitHub `bank_split_output/Enhanced_v1.0a_bank3.asm` blob `c32fd674db8f3ef289baab9f33e3c007ac7ae155` counted:

| Physically identified data | Physical file start | Size | Misleading decoded rows |
| --- | ---: | ---: | ---: |
| TIO translation (`TIOTTRAM`) | `0x1C3AF` | 80 | 51 |
| TIO index (`TIOITRAM`) | `0x1C3FF` | 32 | 32 |
| TIO request flags (`TIOREQFL`) | `0x1C41F` | 6 | 2 |
| TIO register init (`TIOINRAM`) | `0x1C425` | 18 | 10 |
| TIO 64-bit instruction records (`TIOUCODE`) | `0x1C437` | 2,048 | 1,508 |
| **Total source-defined data** | `0x1C3AF` | **2,184** | **1,603** |

Within those 1,603 misleading rows are **86 synthetic HC11 control-flow-looking mnemonics**: branches, JSR/JMP, BSR and apparent RTS/RTI. These arise from decoding embedded data. They **must not** become firmware call edges, executable code-cave exclusions, stack deltas, RAM refs or indirect branch targets without independent evidence of actual CPU execution in that region.

The counts are **specific to that GitHub listing revision**. Other disassembler versions may produce different row counts from the same bytes. If a subsequent listing is supplied to `tools/vy060a_tio_data_fence.py`, re-evaluate its results rather than copying 1,603 into a new receipt.

This **does not** prove every other byte is valid executable code. Other mixed code/data and zero-filled areas remain unresolved. Some of the historical **78,259** total decoded rows reported in private PR #292 therefore are an instruction *inventory*, not valid executable coverage. PR #292's IR consumer must apply a bank-aware data fence **before building edges, RAM xrefs, stack metrics or instruction counts**, and regenerate all dependent metrics. The historical PR count is not silently corrected by simple subtraction.

## 2. Exact VY variant and VX source evidence

| Exact image | SHA-256 | Full TIO `[0x1C3AF,0x1CC37)` | TIO startup entry at `0x1CC37` |
| --- | --- | --- | --- |
| `92118883_STOCK.bin` | `750750d9a1250904b134af10e0d86d84daaa2a146f2946914f72ab8f0dcd2232` | identical | identical |
| `VX-VY_V6_$060A_Enhanced_v1.0a.bin` | `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd` | identical | identical |
| `VX-VY_V6_$060A_Enhanced_v1.1a.bin` | `d36a3e5e17d233b9f4b72f6b58c9f604f7ac6e1bfa57f7b408dcdf0998dc787d` | identical | identical |

**TIO 2,184-byte SHA-256:** `a179b1b980023e0c07a03df2db3075c925653a003ddc5a68445ffd63f763457a`.  
**TIO 2,048-byte microcode SHA-256:** `27a891e000f7f8aa782375b3f8df856e3c3aa6f0bf78a8bc75d0e83477d5cf13`.  
**VX symbolic source SHA-256:** `cbf97987663cbf648e0085c8cfbfbf9759b34a0117b6bc7cbe71dd0080461030`.

All three BINs were directly extracted and hashed from the user's Library archive: `kingai_20260922_VY_060A_CODEX_CLAUDE_HANDOFF_cutblock_sparkcut_XDF.zip`, exact `exact_inputs/` members. Their full-image hashes must not be inferred from similar filename strings. `vx_.asm` is an older **semantic** source: numeric addresses outside the exactly matched TIO region are not portable by assumption.

The 44 all-zero microcode records are not proven unused instructions. The proposed record-bits-35–42 next-address decode remains an **unverified hypothesis**, not a TIO CFG. CPU-side loader execution or microstore readback does not demonstrate actual coil output or a physical ROM/RAM microstore selection.

## 3. Separate file-checksum discrepancy requiring owner reconciliation

The current public checksum utility at `tools/vy_flash_checksum.py` implements a specific VX/VY full-flash-file checksum: 16-bit sum of bytes `0x02000–0x1FFFF` excluding `0x04000–0x04007`, stored big-endian at `0x04006–0x04007`. The three retained original files **all store `0x8E6F`** but calculate differently under *that tool's algorithm*:

| Image | Stored | Recalculated using public tool's specified window | Match |
| --- | ---: | ---: | --- |
| `92118883_STOCK` | `0x8E6F` | `0x8D36` | No |
| Enhanced v1.0a | `0x8E6F` | `0x9E9F` | No |
| Enhanced v1.1a | `0x8E6F` | `0xB0F1` | No |

This is a **file/policy mismatch**, not proof any of the three original files is corrupt or that the checksum algorithm is wrong for its intended write mode. Do not automatically rewrite the source files or declare flash readiness because a checksum tool can produce a matching value. Determine whether these are upstream uncorrected images, whether the flash process adjusts the word, and whether boot/PCM validation has other checks. All SC01B builder decisions require a specific parent-selection and checksum/write-mode policy with before/after receipts.

## 4. Bank-select annotation conflict

The public `tools/split_and_disassemble.py` labels HC11F `$1002` as `PORTG` and describes bit 6 as a *candidate* flash A16 signal. Older project documentation also proposes PORTG bit 3, while Muncie's Stage16 traces Port A writes through reset/checksum paths. The `MC68HC11F1` peripheral register name alone does **not** prove physical A16/chip-select wiring. Correct register identity and **external board signal ownership** are independent issues. Until wiring/latch traces exist, do not generate automated bank-switch trampolines from either guess.

## 5. Ordered tasks and acceptance gates (both lines)

1. **Static IR:** fence the exact 2,184-byte TIO data block *before* parsing calls, references and stack in PR #292; rerun the inventory and compare with the historical source. Then address further mixed data/code and indirect-reader ambiguities.
2. **TIO semantics:** independently obtain field evidence for the full 64-bit microinstruction format, compare channel/index behavior against the source table plus hardware timing only when an appropriately protected setup is available. Do not infer semantics from field-size appearance alone.
3. **SC01B ROM/RAM:** complete common, B2, B3 and transient RAM owners, including indexed/bulk/boot readers, with explicit bank-latch, IRQ/CCR, stack and native-diagnostic contracts; source-known data remains protected.
4. **Muncie Stage20:** request the actual Stage19/Stage20 scripts and receipt inputs before considering reported 53/53 and 49,152 test counts independently reproduced. Resolve `$360A/$360E` predecessor paths, native checksum/RAM lifetime, and real EST feedback.
5. **Checksum policy:** verify accepted transfer/programmer mode; demonstrate parent equivalence, intended diffs only, no unintended writes, and complete reversibility. Preserve stock fuel-protection and VSR data.
6. **Physical feedback:** independently validate real 3X/18X, EST, bypass/DFI, dwell, coil and M41/M42 with a protected spare-PCM fixture. No qualified SC01B or Stage20 flash image currently exists.

## 6. Where to find sources / reproduction

- **Exact images archive (Library):** `/kingai_20260922_VY_060A_CODEX_CLAUDE_HANDOFF_cutblock_sparkcut_XDF.zip` (original internal `exact_inputs/`). Review here without uploading/disclosing firmware on public GitHub.
- **VX symbolic donor:** `A:\repos\vx_.asm` (historically reported; remote PC unavailable this pass), alternately Library `vx_(1).asm`, matching hash above.
- **Public GitHub source:** `KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches`, `bank_split_output/Enhanced_v1.0a_bank3.asm` on `master`, Git blob `c32fd674db8f3ef289baab9f33e3c007ac7ae155`.
- **New offline checker:** `tools/vy060a_tio_data_fence.py` (the input files are passed by path; no shell/network access or writers to firmware).
- **New regression tests:** `tools/test_vy060a_tio_data_fence.py` (real firmware inputs optional; portable synthetic cases always run).
- **Checksum utility:** `tools/vy_flash_checksum.py`, `tools/safe_outputs.py` and `tools/test_vy_flash_checksum.py` on the public VY repo.
- **Related private PRs:** [#292 full-image IR](https://github.com/KingAiCodeForge/private-cloud-claude-work/pull/292), [#294 exact-parent ABI gate](https://github.com/KingAiCodeForge/private-cloud-claude-work/pull/294), [#295 ALDL Table 8 research](https://github.com/KingAiCodeForge/private-cloud-claude-work/pull/295), [#293 Stage20 comparison](https://github.com/KingAiCodeForge/private-cloud-claude-work/pull/293).

Reproduce offline on an authorized local clone, with originals never changed:

```bash
python -B tools/vy060a_tio_data_fence.py --image ORIGINAL_Enhanced_v1.0a.bin --image ORIGINAL_v1.1a.bin --image ORIGINAL_stock.bin --bank3-listing bank_split_output/Enhanced_v1.0a_bank3.asm --json new_evidence.json
python -B -m unittest discover -s tools -p 'test_vy060a_tio_data_fence.py' -v
```

The optional `--json` path must not exist and cannot equal an input path. A successful TIO identity check is a *static-data classification result*, not code-placement or hardware certification.