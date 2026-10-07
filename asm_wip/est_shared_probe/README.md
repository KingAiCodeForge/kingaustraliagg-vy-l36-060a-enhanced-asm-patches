# EST Shared-Command No-Op Probe v52

This folder contains an exact-target static instrumentation candidate for the
128 KiB VX/VY V6 `$060A` Enhanced v1.0a image identified in `manifest.json`.
It is not a spark cut, does not alter the value stored at `$1444`, and is not
approved for flashing or vehicle use.

The two original `STD $1444` instructions become calls to one common routine.
That routine performs the displaced `STD $1444` and returns. Each executed hook
adds 11 E-clock cycles and temporarily consumes two stack bytes. Static parity
does not prove that either overhead is acceptable at runtime.

## Files

- `est_shared_dual_store_probe_v52.asm` is the A09 HC11 source.
- `manifest.json` binds both hooks, the routine, source hash and exact target.
- `../../tools/party_patch_tool.py` performs guarded build and verification.

No source BIN is distributed. Supply a legally obtained exact matching image.

## Build And Verify

Run these commands from the repository root:

```text
python tools/party_patch_tool.py build SOURCE.bin OUTPUT.bin --patch est-shared-probe --manifest OUTPUT.manifest.json --acknowledge-static-candidate
python tools/party_patch_tool.py verify SOURCE.bin OUTPUT.bin --patch est-shared-probe --json OUTPUT.verify.json
python tools/party_patch_tool.py verify-asm --assembler PATH_TO_A09 --patch est-shared-probe
```

The tool refuses an incorrect source hash, changed hook bytes, any non-zero byte
in the reviewed placement run, overlapping write regions, existing outputs and
output paths that alias inputs.

## Evidence Boundary

Passing all checks proves only deterministic construction, A09 byte parity and
the recovered file checksum. A spare-PCM bench test still needs to establish
write/readback/recovery, hook timing and stack margin, the B3/B4 electrical
behavior, and whether all writers of the shared command have been found.
