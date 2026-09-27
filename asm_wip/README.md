# Assembly Patch Catalog

This directory is for executable party-patch source, not general reverse-
engineering notes and not byte patches already supplied by an XDF.

## Retained Patches

| Source | Hook | Handler | Status |
|---|---|---|---|
| `ghost_cam/ghost_cam_retarded_idle_selector_v1.asm` | File `0x1790F`, bank2 `$F90F` | File `0x17EA2`, bank2 `$FEA2` | Static candidate |
| `est_shared_probe/est_shared_dual_store_probe_v52.asm` | Files `0x10232` and `0x106EE`, bank2 `$8232/$86EE` | File `0x05D05`, common `$5D05` | Static WIP no-op probe |

The retained source assembles with A09 v1.62 in HC11 mode. Its adjacent
`manifest.json` binds the normalized source hash, assembled bytes, hooks and
exact target. `tools/party_patch_tool.py` validates that manifest before an
output can be created and can independently rerun A09 byte-parity verification.

## Inclusion Rules

A public `.asm` file needs:

1. one exact source hash;
2. original bytes at every hook;
3. correct file, CPU, and bank mapping;
4. a bounded handler placement;
5. buildable HC11 source;
6. displaced-instruction and register-state handling;
7. a deterministic apply and verification path;
8. explicit statements about what remains unproved.

Bench and vehicle proof are later evidence levels. Until then, the source must
carry a `DO_NOT_FLASH` status and must not use words such as safe, working, or
verified for physical behavior.

## Excluded Drafts

Old files remain in the local workspace and Git history, but are ignored from
the public tree when they rely on:

- direct `$C468` or `$C500` calls from the bank2 `$81E1` hook;
- guessed scratch RAM or invented final-spark variables;
- `$194C` as a blind spark-output hook;
- packet offsets treated as RAM addresses;
- placeholder clutch, cruise, TPS, gear, or button inputs;
- an all-zero run described as proven executable space;
- code that does not assemble;
- XDF patch bytes copied into an `.asm` file;
- the withdrawn `$017B/$3E80` cut design: `$017B` is a history word and the
  handler did not replace the complete `$0199 -> $019B -> $1444` command path.

## Next Patch Lanes

The retained `est_shared_probe` lane is an exact-source dual-hook **no-op** at
the two direct `$1444` stores. It establishes a reproducible candidate place to
observe the final shared command; it does not implement a spark cut. It remains
a `STATIC_WIP_PROBE_DO_NOT_FLASH` entry pending external EST and bench evidence.

Launch control, two-step, no-lift shift, and button-controlled rolling anti-lag
are worth keeping as goals. They do not get public ASM implementations until a
real clutch/button runtime bit and its polarity are traced in this exact OS.

Spark-cut work also needs a proved external-EST contract. Static alternatives
at `$019B`, `$1444`, `$149E`, or `$16FA` are not accepted merely because those
addresses participate in the path.

The Enhanced v1.1a beta is not a reusable implementation. Its foreground
`JSR $31EF` enters the middle of an IRQ handler whose only reachable exit is
`RTI`; the required interrupt frame and IRQ bank-save prologue are absent.
Direct-xref tracing also shows `$149E.0` is an IRQ handshake bit and that the
beta has no proved recovery for `$16FA` bits 0, 1, or 3-7. A replacement must
use a normal `RTS`, explicit release state, and measured B3 output behavior.

Full rolling anti-lag also needs timeout, throttle/load gating, fuel and spark
arbitration, and exhaust-temperature protection. There is no retained public
rolling-cut source yet.

Pop-and-bang or shift-bang work needs a proven final spark/fuel integration
point and overrun/shift state. A long concept file with guessed addresses is not
a patch.
