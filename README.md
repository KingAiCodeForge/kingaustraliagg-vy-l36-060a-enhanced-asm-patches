# Holden VX/VY L36 `$060A` — bank-aware ECU reverse-engineering

**Research repository: Motorola 68HC11/Delco Enhanced code, assembly experiments, disassembly evidence and static patch verification.**

**Documented branch:** public `master` (last code sync 7 October 2026). **README reviewed:** 16 October 2026.

> **STATUS: RESEARCH / STATIC REVIEW ONLY. NO PATCH IN THIS REPOSITORY IS APPROVED FOR FLASHING OR VEHICLE USE.**
>
> Some legacy ASM files are known to have incorrect bank calls or inactive hook points, even when their filenames contain `VERIFIED` or `PRODUCTION`. Passing a Python test, source hash check, deterministic byte build or file checksum is **not** proof of physical spark behaviour, ECU recovery or engine safety.

This README describes what the **currently published `master` branch** actually contains. Detailed historical notes remain accessible in the [previous README revision](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches/blob/e9d56d524e8b27506adf98ebcb64e71ca85e81ef/README.md), but it includes obsolete conclusions and **unsafe patch instructions**. Use the current evidence and source review instead.

## What is implemented and what remains unproved

| Area | Available on public `master` | Evidence boundary |
| --- | --- | --- |
| Bank splitting / disassembly | [`tools/split_and_disassemble.py`](tools/split_and_disassemble.py), [bank reports](bank_split_output/README.md) | Uses Capstone M680X/HC11 and heuristic code/data classification; **not** complete decompilation or exclusive memory ownership proof |
| Exact-source patch catalog | [`tools/party_patch_tool.py`](tools/party_patch_tool.py) and two source manifests | Bounded, hash-checked static candidates only |
| Additive checksum | [`tools/vy_flash_checksum.py`](tools/vy_flash_checksum.py) | Validates the known 128 KiB **file checksum** only; cannot authorise a flash |
| Historical ASM | `asm_wip/` experiments including spark-cut, EST, ghost-cam and MAFless concepts | Some programs are known-broken, incomplete or untested |
| XDF/vehicle results | Historical community comparison notes and private research exist separately | No target-wide native TunerPro, bench, physical EST, recovery or road qualification is established by this repository |

The 7 October 2026 selective tooling sync recorded **17 local tests passed, 2 skipped and 2 passing subtests**. Some exact source/assembly checks were skipped. This is a historical receipt, **not a fresh test run** or flash-readiness claim. Different versions of VY private research are not automatically included in this public repo.

## Exact source identification

The guarded builder currently recognises **one exact 128 KiB Enhanced v1.0a source image**. These are its compiled-in preconditions:

| Property | Value |
| --- | --- |
| Full image length | `131072` bytes / `0x20000` |
| Source SHA-256 | `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd` |
| Manifest schema | `kingai.vy-060a-static-patch.v1` |
| Target | VX/VY L36 `$060A` Enhanced v1.0a research file |

Read-only identity check against a legitimately obtained **full** image:

```python
from pathlib import Path
from hashlib import sha256

file = Path("VX-VY_V6_$060A_Enhanced_v1.0a.bin")  # replace with your real path
image = file.read_bytes()
expected = "5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd"
digest = sha256(image).hexdigest()

if len(image) != 131072 or digest != expected:
    raise SystemExit(f"REFUSED: size={len(image)} sha256={digest}")
print("PASS: exact source file identity only. NOT a flash/patch approval.")
```

**Why this matters:** the previous README called an image “verified” after checking its 128 KiB size, three hook bytes and an all-zero region. A different or fabricated image could pass those checks. It also used `assert`, which `python -O` removes. The new check fails closed on the **complete image hash** and uses explicit exceptions. Identity is a prerequisite, not a safety certificate. Bank extracts published under `bank_split_output/` are **not** substitutes for the original complete image.

## Bank context: file offsets are not CPU addresses

The published splitter treats the 128 KiB image as these ranges:

| File region (half-open) | CPU address context | Notes |
| --- | --- | --- |
| `0x00000–0x0FFFF` | Base/common 64 KiB view | Mixed memory and code; apparent zeros are not automatically free patch space |
| `0x10000–0x17FFF` | Paged `$8000–$FFFF` bank 2 | Contains the dwell-path hook at file `0x101E1` |
| `0x18000–0x1FFFF` | Alternative paged `$8000–$FFFF` bank 3 | Transmission and related code in this research image |

**Known cross-bank error:** file offset `0x101E1` maps to **CPU `$81E1`** in bank 2, *not* `$A1E1`. A historic v38 ASM declares `HOOK_DWELL_CPU EQU $A1E1`, and later emits `HOOK_PATCHED EQU $BDC500` (`JSR $C500`). The proposed payload is placed at **bank 1** file `0x0C500`. Calling CPU `$C500` from the bank-2 hook context does **not** establish a call to that bank-1 payload; it may dispatch into the wrong overlay. This is a known design defect, not a qualified limiter.

A proposed trampoline via the `$5D05` common region remains **research**: the bank selection, instruction displacement, interrupt state, return sequence, stack/cycle margin, area ownership and actual signal effect must all be independently validated. A zero-filled ROM region is not automatically safe to execute from or rewrite.

Read [bank and ISR research](BANK_SWITCHING_AND_ISR_ANALYSIS.md), [TIC3 analysis](TIC3_ISR_ANALYSIS.md) and [bank source information](bank_split_output/README.md) before discussing any patch location.

## Important: do not follow the legacy v38 instructions

- [`asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm`](asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm) has **a misleading filename**: the file explicitly documents both a bad historical initialization-path hook and the cross-bank `JSR $C500` problem. It must **not** be used as a preferred starting point for a working patch.
- [`tools/apply_spark_cut_v38.py`](tools/apply_spark_cut_v38.py) still writes `BD C5 00` at file `0x101E1` and stores payload code at `0x0C500`. **Do not run it to produce a BIN intended for an ECU.**
- Other files named `VERIFIED`, `BANKFIX` or `PRODUCTION` are historical snapshots; none is promoted by this README.

The known v38 error does not prove that all dwell-intervention techniques are impossible. It means *this implementation* cannot be treated as correct until independently repaired and tested against exact source, bank, caller and hardware evidence.

## Curated exact-source STATIC candidates

The guarded catalog [`tools/party_patch_tool.py`](tools/party_patch_tool.py) currently exposes:

| Catalog name | Description | Unproven |
| --- | --- | --- |
| `ghost-cam` | [Idle selector, source and manifest](asm_wip/ghost_cam/README.md) | Runtime cadence, idle stability, EST/spark effect, thermal consequences |
| `est-shared-probe` | [Shared-command no-op probe and manifest](asm_wip/est_shared_probe/README.md) | All $1444 writers, timing, stack margin, B3/B4 physical response and interrupted-write recovery |

The two candidates must not be blindly combined: the manifests include conflicting-role and `unproved` constraints. Their review codes explicitly say **DO NOT FLASH**. The guarded tool checks input hash, exact hook bytes, zero-run placement, deterministic diffs and output-path collisions, not the engine's response.

To inspect the catalog or run read-only/local tests:

```console
python tools/party_patch_tool.py list
python tools/vy_flash_checksum.py exact-source.bin
python -m unittest discover -s tools -p "test_*.py" -v
```

These are **examples to run locally with appropriate dependencies**; the complete test suite was not executed in this documentation review. The builder has `build`, `verify` and `verify-asm` operations documented by each candidate's README, with an explicit `--acknowledge-static-candidate` required for output. That acknowledgement **does not approve ECU use**.

## File checksum is a separate layer

The reviewed VXY checksum algorithm in [`tools/vy_flash_checksum.py`](tools/vy_flash_checksum.py) sums image bytes `0x02000–0x1FFFF` modulo `65536`, **excludes `[0x04000,0x04008)`**, and stores the big-endian result at `0x04006–0x04007`.

- Passing `input_bin` alone checks the checksum and produces a report.
- Passing `--fix NEW.bin` produces a **new file**, not an in-place edit; existing output paths are refused.
- A correct file checksum is **not** an OSID/program identity test, evidence of safe code execution, flash scope verification, recovery validation or physical engine acceptance.

Do not attempt to make an unverified code patch “safe” just by repairing the checksum.

## RAM, limiter and table findings: research, not verified free resources

| Location | Historical finding | Current limitation |
| --- | --- | --- |
| `$00A2` | 8-bit speed-related value, earlier `×25` RPM representation | `255×25=6375` limits that *representation*, **not every RPM control path or engine mechanically** |
| `$017B` | Dwell-path intermediate with a store near file `0x101E1` | Not a validated safe hook, cut request or spark output |
| `$194C` | Crank-period-related storage; old `0x13618` hook occurs on initialization path | Not a repeating runtime limiter hook |
| `$0046` bits 3, 6 and 7 | Not seen in a limited set of direct bit-operation scans | **Not proved free or exclusively owned**; other writers, IRQs, indexed paths and initialization remain possible |
| `$01A0`, `$00FB`, `$00FC` | Scratch-address hypotheses based on old static scans | **Not proved unused**, even if a short data log looks constant |

The previous README mentioned an `0xFF` byte at **BIN file offset `0x01A0`** while discussing **live CPU RAM `$01A0`**. These are different address spaces; that ROM observation does not establish that a RAM byte is free. Nor can an apparent “unused” bit be trusted without auditing *all* producers and consumers, reset paths, concurrent access and relevant peripheral activity.

The older “all Enhanced XDFs contain the same 68 DTC flags,” “VX is just BCM comms,” and generic 11P/12P portability statements were **not revalidated** in this public branch. Treat them as historical leads only. Do not port patch bytes or whole calibrations across ECU, XDF or OSID variants without independent identity, geometry, offsets and call-path evidence.

## Repository guide

| Resource | Intended use |
| --- | --- |
| [`bank_split_output/`](bank_split_output/README.md) | Historical bank BIN/ASM extracts, disassembler comparison, limitations |
| [`tools/split_and_disassemble.py`](tools/split_and_disassemble.py) | Bank splitting and heuristic M680X disassembly, not native execution |
| [`tools/party_patch_tool.py`](tools/party_patch_tool.py) | Static candidate catalog/build/verify with an exact source SHA |
| [`tools/vy_flash_checksum.py`](tools/vy_flash_checksum.py) | 128 KiB file-checksum checking/new-copy repair |
| [`tools/test_party_patch_tool.py`](tools/test_party_patch_tool.py) | Guarded-builder regression tests |
| [`tools/test_split_and_disassemble.py`](tools/test_split_and_disassemble.py) | Splitter regression tests |
| [`tools/test_vy_flash_checksum.py`](tools/test_vy_flash_checksum.py) | Checksum regression tests |
| [RAM variable evidence](RAM_Variables_Validated.md), [MAFless/SD](MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md), [platform comparison](VS_VT_VY_COMPARISON_DETAILED.md), [pinout mapping](VY_V6_PINOUT_MASTER_MAPPING.csv) | Research references; check dates and target variants |
| [VL V8 limiter research](VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md) | Related concept, not a VY implementation |

These resources do **not** include a public, validated universal `$060A` spark-cut release. Third-party XDFs and newer private VY definitions are not implied to be present. Historic code counts and “latest all-platform XDF” tables are not maintained as a current inventory.

## Before proposing any actual patch

1. Fix the known bank/CPU offset and v38 hook/placement defects in a **separate source review branch**; keep the rejected lineage intact.
2. Prove the **exact** source image, all overwritten bytes, code-bank transitions, displaced instructions, callers, interrupt/scheduler timing, stack and shared RAM ownership.
3. Rebuild and independently compare A09 bytes where appropriate; verify every resulting BIN difference and declared checksum region without touching originals.
4. Obtain spare-PCM read/write/recovery evidence plus oscilloscope or logic captures of actual relevant signals under controlled conditions. Record negative controls and failure behaviour.
5. Advance an experimental candidate only after source, code, measurement and recovery evidence close. Otherwise retain a clear **HOLD**. No AI-only or synthetic test may waive those gates.

Contributions should include exact hashes, firmware variant, file/CPU address bases, observed bytes and a reproducible counterexample. Do not commit customer BINs, security credentials or proprietary XDFs without appropriate rights.

## Credits and licensing

Research draws on **Chr0m3 Motorsport**, **The1**, **Antus**, **charlay86**, PCMHacking contributors and the Delco/68HC11 community. **TunerPro** is maintained by **Mark Mansur**. Attribution does not imply a contributor has reviewed or endorsed a particular patch.

**Licence status requires resolution.** The previous README described “MIT with Attribution” but the checked public `master` tree contains **no root `LICENSE` file**. This documentation-only change does not grant or change any software rights; the owner should add explicit terms before third parties rely on redistribution permissions. Upstream materials may have separate licences.

All content remains research material. No warranty of ECU function, engine behaviour or safety is made.
