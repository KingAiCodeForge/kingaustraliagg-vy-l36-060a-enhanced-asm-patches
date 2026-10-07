# Retarded-Idle Selector v1

This folder contains one exact-target, static assembly candidate for the
128 KiB VX/VY V6 `$060A` Enhanced v1.0a image identified in `manifest.json`.
It is not approved for flashing or vehicle use.

## Files

- `ghost_cam_retarded_idle_selector_v1.asm` is the A09 HC11 source.
- `manifest.json` binds the source, assembled bytes, hook bytes, placement and
  target SHA-256.
- `../../tools/party_patch_tool.py` performs the guarded build and verification.

No source BIN is distributed. Supply a legally obtained exact matching image.

## Build

From the repository root:

```powershell
python tools/party_patch_tool.py build SOURCE.bin OUTPUT.bin `
  --patch ghost-cam --manifest OUTPUT.manifest.json `
  --acknowledge-static-candidate
```

The command refuses an incorrect source hash, non-zero placement bytes,
existing outputs, and any output path that aliases an input.

## Verify

```powershell
python tools/party_patch_tool.py verify SOURCE.bin OUTPUT.bin `
  --patch ghost-cam --json OUTPUT.verify.json
```

If A09 v1.62 is available, independently confirm that the checked-in machine
bytes still match the assembly source:

```powershell
python tools/party_patch_tool.py verify-asm `
  --assembler PATH_TO_A09 --patch ghost-cam
```

Passing these checks proves deterministic static construction only. Runtime
cadence, idle stability, physical spark behavior, exhaust temperature and
catalyst safety remain unproved.
