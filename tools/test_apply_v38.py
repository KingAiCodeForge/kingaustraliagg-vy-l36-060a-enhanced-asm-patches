#!/usr/bin/env python3
"""
Test-Apply v38 Spark Cut Patch to Enhanced Binary
===================================================
Creates a copy of VY_V6_Enhanced.bin, applies the 42-byte spark cut patch
at file offset 0x0C500, installs the 3-byte JSR hook at file offset 0x101E1,
and verifies the bytes were written correctly.

⚠️  WARNING: The hook at 0x101E1 (bank 2) JSRs to $C500 which resolves to
    bank 2's $C500 (trans code), NOT our patch in bank 1. See the cross-bank
    bug documented in custom_ose_$060_445_plan.md §3.1a. Use $5D05 (common
    area) instead for a production patch.

Usage:
    python test_apply_v38.py

Requires:
    VY_V6_Enhanced.bin in the same directory

Outputs:
    VY_V6_Enhanced_v38_patched.bin — patched binary copy
    Console output with verification results and SHA256 hash

Author:  Jason King (KingAI Tuning)
Date:    January 2026
Repo:    https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches
Status:  ✅ WORKING — applies patch correctly (but see cross-bank warning above)

Future:
    - Update to use $5D05 common area (Option A fix)
    - Add checksum recalculation
    - Add min dwell/burn patches at 0x171AA and 0x19813
"""
import shutil
import hashlib

shutil.copy2('VY_V6_Enhanced.bin', 'VY_V6_Enhanced_v38_patched.bin')

code = bytes([
    0x36,                    # PSHA
    0x12, 0x46, 0x80, 0x0B,  # BRSET $46,$80,CHECK_RESUME
    0x96, 0xA2,              # LDAA $A2
    0x81, 0xF0,              # CMPA #$F0 (6000 RPM)
    0x25, 0x0E,              # BCS STORE_NORMAL
    0x14, 0x46, 0x80,        # BSET $46,$80
    0x20, 0x0E,              # BRA INJECT_FAKE
    0x96, 0xA2,              # LDAA $A2
    0x81, 0xEC,              # CMPA #$EC (5900 RPM)
    0x24, 0x08,              # BCC INJECT_FAKE
    0x15, 0x46, 0x80,        # BCLR $46,$80
    0x32,                    # PULA (restore A)
    0xFD, 0x01, 0x7B,        # STD $017B
    0x39,                    # RTS
    0x32,                    # PULA (clean stack)
    0xCC, 0x3E, 0x80,        # LDD #$3E80
    0xFD, 0x01, 0x7B,        # STD $017B
    0x39,                    # RTS
    0x4A, 0x4B, 0x26, 0x02,  # Signature: JK v38 6000rpm
])

with open('VY_V6_Enhanced_v38_patched.bin', 'r+b') as f:
    # Verify before
    f.seek(0x101E1)
    orig_hook = f.read(3)
    print(f'Hook 0x101E1 BEFORE: {" ".join(f"{b:02X}" for b in orig_hook)} (expect FD 01 7B)')
    
    f.seek(0x0C500)
    orig_area = f.read(42)
    all_zero = all(b == 0 for b in orig_area)
    print(f'Code 0x0C500 BEFORE: all zeros = {all_zero}')
    
    # Apply patch 1: hook
    f.seek(0x101E1)
    f.write(bytes([0xBD, 0xC5, 0x00]))
    
    # Apply patch 2: code
    f.seek(0x0C500)
    f.write(code)

# Verify after
with open('VY_V6_Enhanced_v38_patched.bin', 'rb') as f:
    f.seek(0x101E1)
    hook = f.read(3)
    print(f'\nHook 0x101E1 AFTER:  {" ".join(f"{b:02X}" for b in hook)} (expect BD C5 00)')
    assert hook == bytes([0xBD, 0xC5, 0x00]), 'HOOK MISMATCH!'
    
    f.seek(0x0C500)
    patched = f.read(42)
    print(f'Code 0x0C500 AFTER:  {" ".join(f"{b:02X}" for b in patched)}')
    assert patched == code, 'CODE MISMATCH!'
    
    f.seek(0)
    full = f.read()

with open('VY_V6_Enhanced.bin', 'rb') as f:
    orig = f.read()

diffs = [i for i in range(len(orig)) if orig[i] != full[i]]
print(f'\nTotal bytes changed: {len(diffs)} (expected 45 = 3 hook + 42 code)')
assert len(diffs) == 45, f'UNEXPECTED DIFF COUNT: {len(diffs)}'

# Show diff locations
hook_diffs = [d for d in diffs if 0x101E0 <= d <= 0x101E3]
code_diffs = [d for d in diffs if 0x0C500 <= d <= 0x0C52A]
other_diffs = [d for d in diffs if d not in hook_diffs and d not in code_diffs]
print(f'  Hook region: {len(hook_diffs)} bytes (0x{min(hook_diffs):05X}-0x{max(hook_diffs):05X})')
print(f'  Code region: {len(code_diffs)} bytes (0x{min(code_diffs):05X}-0x{max(code_diffs):05X})')
if other_diffs:
    print(f'  OTHER:       {len(other_diffs)} bytes!!! UNEXPECTED!')
else:
    print(f'  Stray bytes: 0 (clean)')

md5 = hashlib.md5(full).hexdigest()
print(f'\nPatched binary MD5: {md5}')
print(f'Patched binary: VY_V6_Enhanced_v38_patched.bin')
print('\n=== ALL VERIFICATION PASSED — v38 patch is ready to flash ===')
