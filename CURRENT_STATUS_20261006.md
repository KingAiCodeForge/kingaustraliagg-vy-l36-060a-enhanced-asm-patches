# VY $060A public ASM corpus — current status 2026-10-06

This repository is a public historical/WIP research corpus. It is useful for concept provenance, old experiments, bank-split evidence and reproducible counterexamples. It is not the current KingAI integration authority and its version-numbered ASM files are not a release ladder.

## Exact target used by current private work

Enhanced v1.0a logical image:
- 131072 bytes
- SHA-256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd

## Superseded/rejected public patch families

Do not treat these as current preferred hardware-test candidates:
- v23/v32/v34/v38/v42/v44/v45;
- V56/V57/V59;
- the foreground JSR-to-IRQ-tail $31EF architecture;
- $017B fake-period / final-spark assumptions;
- antilag_rolling.asm;
- the VY address/RAM implementation in antilag_cruise_button.asm.

Historical filenames containing VERIFIED indicate old research/software status, not physical no-spark proof.

## Current static conclusions that override older README prose

### Ignition/event ownership

- $017B is upstream/history state, not the final physical ignition owner.
- native dwell/command path includes $019B -> $1444 and minimum/floor state around $144A.
- $149E.0 is better modeled as an event-admission/re-arm handshake than a permanent master spark switch.
- current source/target work binds a native six-slot event counter at $016D and physical-cylinder lookup at $3584.
- native EST diagnostic feedback observes $14C8.
- software ownership is still not electrical DFI/coil proof.

### Rolling anti-lag

Current VY RAL research ports the behavior of actual MS43X source, not the old placeholder VY addresses in this repository.

Target model:
- factory PWR/Performance state $0360.6 arms the feature;
- moving/TPS/RPM conditions qualify activation;
- current RPM is captured at activation and a bounded offset forms a dynamic RPM ceiling;
- RAL requests late ignition retard and a richer-only fuel target;
- the automatic transmission remains in Drive;
- no Neutral command belongs to the RAL design;
- TCC remains factory-owned in the first implementation.

No RAL BIN in this public corpus should be treated as current or hardware-ready.

### Airflow / Alpha-N

Later exact VY static work separates:
- DISPFLOI $0122 — primary cylinder-filling/load authority;
- DEFARFLO $0128 — factory default-air producer;
- RAWMAFRD $0130 — transient AIRFILT path;
- CHARGAIR $0136;
- CYL_AIR $007B;
- CYLAIR50 $007E;
- Enhanced extended-load state $19C2.

Therefore an Alpha-N implementation that only writes one downstream airflow state is incomplete.

### Free ROM

Do not use zero-run scans as allocation proof.

| Physical range | Size | Current status |
|---|---:|---|
| common $3E87-$3FE1 | 347 | high-confidence candidate, modern indirect/pointer closure still required |
| common $5C31-$5CB8 | 136 | high-confidence candidate |
| common $5D05-$5EFC | 504 | OEM-unused candidate but KingAI-reserved/conflicted; allocator only |
| common $6559-$66D7 | 383 | high-confidence candidate |
| Bank-1 file 0x0C468-0x0FFBF | 15192 | major bank-dependent candidate; bank-state XREF closure required |
| Bank-2 $FE87-$FFB1 | 299 | strong candidate; current XREF/bank proof required |
| Bank-3 $9B0B-$BFFF | 9461 | HOLD, older free claim contradicted by bank-XREF evidence |
| Bank-3 $CE3F-$FFB1 | 12659 | HOLD pending bank-state closure |
| $5117-$5248 | 306 | REJECT: live torque calibration |
| Bank-2 $C41E-$C681 | 612 | REJECT: live NOP/timing corridor |

The large Bank-1 zero arena and the Bank-2 live NOP corridor are different physical regions and must not be conflated.

## How to use this repository now

Use it for historical source examples, exact-bank disassembly/reference snippets, regression tests and old failure cases, and ideas to re-derive against current exact-target ownership.

Do not use it as an automatic patch installer, a source of free RAM/free ROM without a modern ownership audit, proof that a higher version number is safer, or proof that an old BMW/OSE port retained correct VY addresses or semantics.

Current private integration uses separate exact-target ownership, source-correlation, XDF/ADX, KCOS and hardware-validation lanes. Restricted/private source is intentionally not copied here.
