# SC01B exact-parent ROM allocation and hook review — 24 October 2026

**Status:** Source/ROM byte audit and proposal only. **No executable-free site certified. No SC01B patched BIN, XDF, DFI validation, flash or vehicle approval.**

**Provenance:** User requested a safe SC01B design preserving factory fuel cut and optional Power gating. **ChatGPTz idea 💡** — the allocation-admission and explicit relocation/state-machine proposal is AI-generated, inspired by the prior SC01 native collision reports, R08/R09 comparison, original Enhanced v1.0a image, source-correlated historical VX assembly and the Freescale M68HC11 instruction reference.

Public WIP BINs, where present, are not cleared for use by this document.

## Exact parent, not arbitrary VY files

The sole evidence parent is the automatic Enhanced v1.0a 131072-byte file already identified in ../README.md by SHA-256 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd.

The new dependency-free read-only checker at ../tools/sc01b_zero_space_gate.py accepts only that exact locally possessed image, checks limiter bytes and bank mappings and emits **no writable patch allocation**. Its tests at ../tools/test_sc01b_zero_space_gate.py reject false free-space assumptions.

## Confirmed zero regions: raw emptiness is NOT proof of freedom

| File half-open range | Bytes | CPU context | Finding |
|---|---:|---|---|
| 0x03E87..0x03FE2 | 347 | Common $3E87..$3FE1 | All zero. Direct/computed users and boot metadata unresolved; no allocation admitted. |
| 0x0C468..0x0FFC0 | 15,192 | Bank1 $C468..$FFBF | All zero. Bank2 and bank3 have different physical contents at the same CPU address. No cross-bank execution proof. |
| 0x05D05..0x05E52 | 333 | Common data/CAL | All zero in parent, but known F61AG/LPG native data consumers overlap. REJECT existing SC01 handler location. |
| 0x05EF0..0x05EF5 | 5 | Common data/CAL | All zero in parent, but known native VSR curves overlap. REJECT existing SC01 parameters. |

A full read-only scan found **14 maximal contiguous zero runs of at least 64 bytes** in the exact parent. The checker separately reports **15 curated region rows**: the single 504-byte run `[0x05D05,0x05EFD)` contains both the handler and five-byte parameter subregions shown above; the other thirteen runs each have one curated row. Curated rows are not fifteen independently discovered zero runs. Other relevant intervals include bank3 0x19B0B..0x1C000 (9,461 bytes), bank3 0x1CE3F..0x1FFB2 (12,659 bytes), bank2 0x17E87..0x17FC0 (313 bytes), common CAL 0x6559..0x66D8 (383 bytes), common CAL 0x5117..0x5249 (306 bytes), bank3 0x1CA57..0x1CBB7 (352 bytes inside protected TIO image), and several smaller CAL/common intervals. **None has been globally approved as live-code-free.**

**New decisive negative checks:**
- The 383-byte 0x6559..0x66D8 candidate is referenced by exact native bank2 instructions: $F323 LDX #$655A, $F326 LDY #$6613, $F34C LDX #$6605, $F34F LDY #$66BE, $FAFF LDX #$66CD, $FB05 LDAB $66CC and $FB48 LDAB $6559. Their exact source-byte preimages are now asserted by the checker. This proves data operands exist, not that every mode executes them.
- The zero 306-byte 0x5117..0x5249 region contains **14 distinct named XDF table starts** for transmission torque-reduction/shift behaviour. Zero-filled data with defined lookup roles is not unused firmware space.
- The 0x1CA57..0x1CBB7 zero span lies within the separate 2 KiB TIO image and must not be repurposed as ROM executable storage.
- A blank 313-byte bank2 tail and large bank3 gaps are capacity observations, not proof of unreferenced bytes, correct IRQ bank selection or useful runtime instruction space.

At CPU $C500, file 0x0C500 (bank1) has zeros, whereas file 0x14500 (bank2) and file 0x1C500 (bank3) have nonzero content. CPU $C500 cannot be called file $1C500 without first specifying a bank; the HC11 CPU has a 16-bit program counter.

A legacy local-only free-space helper incorrectly described the $0C468 region as an unconditionally verified injection cave and printed 17-bit CPU addresses. That is not a trustworthy allocator.

Vector/boot tails in all three banks and the protected TIO source image are not ordinary zero-code caves. A zero-run report never discharges indirect, computed, bank and asynchronous reader obligations.

## Two separate native SC01 collisions

- **Parameters:** the SC01 cut/release/enable bytes at $5EF0..$5EF4 overlap FVSRPBPW ($5EE7..$5EF2) and FVSRML ($5EF3..$5EFC). At bank3 $834D, a conditional gate on RAM $0056 bit5 permits lookup at $8364 LDX #$5EF3 / $8367 JSR $2491. The native two-byte word $0000 becomes $54A5 with SC01 active and $5400 in the disabled-control image.
- **Handler:** program at $5D05..$5E51 overlaps native F61AG/LPG and associated conditional table consumers. Relocating the five parameter bytes alone leaves this other conflict unresolved.

An independently retained bounded lookup audit enumerated 65,536 coordinates under a selected VSR-enabled CPU fixture. The interpolation word-read footprint extends from $5EF3 through $5EFD inclusive. This is a real **conditional code read**, not proof of operating-state reachability in the user's petrol car.

The historical VX donor assembler supplies useful symbolic names for IRQ3X, IRQ18X, MALF42 and LPG paths, but is **not byte-identical Enhanced v1.0a source**. Do not transfer VX address deltas without verifying instruction preimages, bank context and current code.

## Does SC01B require a trampoline?

**Usually yes, as a function of interrupting native control flow; no, it does not justify jumping into an unselected bank.**

- At the existing 3X entry, two original 3-byte instructions are displaced by an extended 3-byte JMP and padding. Any relocated path must replay the original counter loads/clears as appropriate and preserve both native continuations.
- At 18X, the original 4-byte conditional branch is intercepted by a 3-byte JMP plus padding. Both native branch outcomes, interrupt flags and the eventual RTI tail must remain correct.
- A 3-byte foreground JSR can be redirected into a wrapper that calls the original scheduler subroutine and returns by RTS.
- A diagnostic JSR can call a separate M42 wrapper only if genuine fault accounting and caller frame/CCR are preserved. Do not substitute RTI for RTS.
- Extended JSR/JMP targets name only a 16-bit *CPU-visible* address. A bank1 ROM cave requires a separately proved bank-switch save/restore strategy before the call is valid from bank2/bank3.

NXP official guide on signed 8-bit relative branches, JSR/RTS/RTI stack distinction: https://www.nxp.com/docs/en/reference-manual/M68HC11ERG.pdf (printed page 21).

**Trampoline does not mean unsafe by definition. A trampoline into a wrong ROM bank, with displaced instructions ignored, is unsafe.**

## Candidate architectural routes

| Route | Possible gain | Remaining proof and decision |
|---|---|---|
| A. Prove a same-bank or common cave large enough | Minimal IRQ bank complexity | Preferred investigation, but none admitted at this checkpoint. |
| B. Put program in bank1 zero span and use a common dispatcher | 15 KB apparent storage | Requires verified bank-latch state, nested interrupts, saved bank/stack/cycles and native continuation; HOLD. |
| C. Linker-level repack/relocation of selected native subroutines | Retain original functions while freeing coherent code interval | Requires whole caller/jump/table/branch/boot proof, reversible builder; HOLD. |
| D. Retire original LPG/VSR functionality explicitly | Potential native data/code reclaim | Must prove all mode transitions and native consumers unreachable or functionally replaced; not justified by zero CAL values alone. |
| E. Delete factory fuel-cut logic/thresholds | Frees comparatively little; loses independent fallback | REJECT. Keep original $A582 pointer and the $77DE..$781D factory limiter region. |
| F. OEM-supported spark-off policy requiring no hooks | Simplest if equivalent output exists | No evidence of such a complete physical primitive in this exact target. |

The 347-byte common tail is not a practical unexamined drop-in: SC01 V1's handler already takes 333 bytes plus five parameter bytes, leaving only 9 raw bytes if combined. New Power admission and recovery need additional verified space and cannot be assumed to fit.

## Event recovery remains separate

Current SC01 sets request/HELD state at RAM $0066.6/.7. Canceling request does not release HELD without another 3X event. Selected tests leave HELD after 100 request+18X-only iterations. M42 reaching a real threshold after V3 recovery is consistent with missing feedback; resetting diagnostic counters alone cannot prove normal EST or coil operation.

SC01B must separately prove coherent 3X/18X phase identity, bounded missing-reference behavior, correct period/first-pass restoration, no unintended TIO rising events, physical EST/DFI output confirmation and genuine M41/M42 fault reporting.

The latched Power-mode bit $0360.6 is a **request source**, not a safety interlock and not a dedicated momentary button. R08 and R09 implement native fuel-cut shadow selection and must not be stacked with the SC01B design that retains factory fuel cut.

## Required ordered proof gates

1. Exact parent image size/hash, bank/context and native hook/preimage identity.
2. Full protected interval registry including direct and computed ROM consumers, pointer tables, TIO, vectors and all bank aliases. Unknown means NOT admitted.
3. Independent ROM and RAM allocations with original CAL/VSR/F61AG data restored in both active and disabled builds.
4. Source-driven assembler relocation for all branches, literal parameter operands, called wrappers, displaced instruction effects and a single image/checksum policy.
5. Parent-equivalent mode-off behavior and full native VSR, scheduler and diagnostic replays. Run real tests outside any CI that cannot execute.
6. Interrupt/phase, missing-3X/18X, mode changes and actual EST recovery negative tests.
7. Only after host proof, native editor and isolated spare-PCM readback/physical waveform qualification. No installed-car claim without independent evidence.

**Current verdict:** no globally certified executable free interval; no SC01B firmware approved for generation/flash; stock fuel cut must remain.

## Reproduction

    python -B tools/sc01b_zero_space_gate.py --image "<exact Enhanced v1.0a.bin>"
    python -B tools/test_sc01b_zero_space_gate.py

The scanner deliberately returns approved_patch_spans as an empty array even for byte-empty regions. It has no patch writer, forced approval switch, trampoline generator or native ECU access.

The v2 JSON separates `curated_region_count` from the independently scanned `zero_run_inventory`. Its CLI retains the exact full-image admission hash. Synthetic fixtures used through the Python test API report `known_native_pointers_preserved: null`, `checked: 0`, `skipped: 7` and `NOT_CHECKED_SYNTHETIC`; they cannot claim native-signature preservation. The exact admitted parent checks all seven selected native CAL signatures. These selected checks do not close the whole native owner graph.

Optional JSON output is fully written, flushed and closed in a sibling temporary file before exclusive publication. Windows uses non-replacing rename; POSIX uses an exclusive hard link, because POSIX rename can replace a destination ([Python OS documentation](https://docs.python.org/3.13/library/os.html#os.rename)). Regression tests exercise the CLI, completed JSON, existing-destination races and injected pre-publication failures. This does not establish crash/power-loss recovery of an ECU or filesystem.
