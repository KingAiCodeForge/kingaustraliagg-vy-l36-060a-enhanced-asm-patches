# VY V6 Assembly Party Patches

Work-in-progress Motorola 68HC11 assembly patches for the Holden VX/VY V6
`$060A` Enhanced PCM.

**Nothing here is bench-proved, vehicle-proved, or ready to flash.**

The repository is deliberately small. It publishes useful patch source and the
tools that reproduce its byte contracts. Raw research, generated disassembly,
third-party definitions, source binaries, old variants, and test outputs remain
local and ignored.

## Exact Target

| Property | Value |
|---|---|
| Calibration | VX/VY V6 `$060A` Enhanced v1.0a |
| File size | 131,072 bytes |
| SHA-256 | `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd` |
| Processor | Motorola 68HC11 family |
| Definition used for labels | Antus Enhanced v2.09b XDF |

The BIN and XDF are not distributed. A different revision is a different
target, even when an address appears similar.

## Patch Catalog

| Patch | What it does | Current proof |
|---|---|---|
| [Ghost cam selector v1](asm_wip/ghost_cam/ghost_cam_retarded_idle_selector_v1.asm) | Alternates the stock normal and retarded idle-spark values when the stock retarded-idle path is active | Assembles; real idle-spark hook and RAM producers match |
| [EST shared-command no-op probe v52](asm_wip/est_shared_probe/est_shared_dual_store_probe_v52.asm) | Routes both direct `$1444` stores through one routine without changing D | Assembles; both original store sites and the full zero placement run match |

These are static candidates, not claims about vehicle behavior. The EST entry
is instrumentation groundwork only: it does not implement a spark cut. Runtime
cadence, timing margin, stack headroom and physical EST behavior remain unproved.

## Withdrawn Cut Prototypes

The former RPM and rolling cut candidates are no longer public build options.
An exact-target Ghidra rerun proved that bank2 `$81E1` stores current `$0093`
into the previous-period history word `$017B`. The same live D value then
continues through piecewise arithmetic, combines with the independently bounded
`$0199` term, is clamped as `$019B`, and is copied to shared EST address `$1444`.

Replacing `STD $017B` and loading the unproved `$3E80` value did not override
that full chain. Correct hook bytes, free-space placement, assembly, and file
checksum were only static integrity checks; they did not make the behavior a
spark cut. The rejected sources remain in the ignored local research archive.

## Enhanced v1.1a Beta Finding

An exact-bank Ghidra control-flow rerun also rejects the v1.1a `$FD84` beta as
a source for a public patch. `$FD84` is called from the timer-paced foreground
loop at `$3884`, approximately once per 6.25 ms. Above its RPM threshold it
changes shared words `$149E/$16FA`, then executes `JSR $31EF`.

`$31EF` is an internal entry in the IRQ handler rooted at `$30BA`. All 274
statically reachable instructions from that entry converge on `$34BF RTI`;
there is no reachable `RTS`. The IRQ prologue that supplies the interrupt frame
and saved bank byte is bypassed by the foreground call. On HC11, a two-byte
`JSR` return frame cannot be consumed as an interrupt frame. Treat that exact
beta as unfinished and unsafe to execute above its threshold.

The same rerun disproved the old names `spark enable` for `$149E.0` and `force
spark cut` for `$16FA`. They are shared-interface words with partially traced
bit ownership; physical EST behavior still needs a spare-PCM B3 scope test.
The detailed local evidence remains ignored under
`reports/local_re/vy_v1_1a_patch_semantics_20260910/`.

## Build And Verify

The patch tool refuses unknown source hashes, checks original hook bytes and
zero-filled placement, applies only compatible patches, repairs the recovered
VXY file checksum, proves every changed byte is inside a reviewed patch or
checksum region, and records every changed offset. Each public patch owns a
machine-readable manifest beside its assembly source. Outputs are created
exclusively and never replace an input or existing file.

```powershell
cd tools
python party_patch_tool.py list

python party_patch_tool.py build `
  ..\your_exact_v1.0a.bin `
  ..\bin_patch_test\ghost_cam.bin `
  --patch ghost-cam `
  --manifest ..\bin_patch_test\ghost_cam.json `
  --acknowledge-static-candidate

python party_patch_tool.py verify `
  ..\your_exact_v1.0a.bin `
  ..\bin_patch_test\ghost_cam.bin `
  --patch ghost-cam

python party_patch_tool.py verify-asm `
  --assembler PATH_TO_A09 `
  --patch ghost-cam
```

Replace `ghost-cam` with `est-shared-probe` to build or verify the no-op probe.
The two entries intentionally conflict so each behavior is evaluated alone.

Passing verification means only that the output is the deterministic static
build and its file checksum matches.

## What Is Intentionally Ignored

- source and patched BINs;
- XDF and ADX files;
- Ghidra projects, bank splits, listings, labels, traces, and generated reports;
- forum, chat, video, PDF, and datasheet research;
- speculative launch, flat-shift, button, boost-control, fuel, and spark drafts;
- superseded patch versions;
- Antus injector and bug-fix patches already represented by the XDF.

An XDF byte patch does not need a second hand-maintained `.asm` copy. Assembly
belongs here when executable HC11 behavior is the patch.

## What Still Blocks Use

1. Prove full-write recovery on a spare PCM.
2. Write and read back the exact candidate, then compare every byte.
3. Confirm the actual flashing workflow accepts the repaired checksum.
4. Log the ghost-cam hook cadence and prove which engine events select each
   idle-spark source.
5. Scope commanded and physical spark before describing the audible result.
6. Bench the no-op EST probe first, then finish the external EST contract for
   `$019B`, `$1444`, `$149E`, and `$16FA`; do not reuse the invalid v1.1a
   `JSR $31EF` path.
7. Add a proven driver input, timeout, load gating, and temperature protection
   before calling any future rolling-cut design anti-lag.
8. Test without boost first and keep a known-good recovery image.

The [assembly catalog](asm_wip/README.md) records each retained hook and the
specific reason unfinished ideas are not public ASM yet.

## Credits

The work is constrained by public material from The1, Antus, VL400, Chr0m3,
BennVenn, charlay86, vlad01, Muncie, and the PCMHacking community. Credit does
not imply that any contributor reviewed or endorsed these patches.

Original repository material is available under the [MIT License](LICENSE).
Third-party material retains its own ownership and license.
