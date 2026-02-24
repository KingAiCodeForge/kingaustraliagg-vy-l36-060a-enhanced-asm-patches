#!/usr/bin/env python3
"""Verify stock VY_V6_Enhanced.bin at all key addresses from the ASM"""

import sys

bin_path = r"A:\repos\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin"
d = open(bin_path, "rb").read()
print(f"File size: {len(d)} bytes ({len(d)//1024}KB)")
print()

# === HOOK POINTS ===
print("=" * 70)
print("HOOK POINT 1: File 0x13618 (v38 hook - claimed STD $194C)")
print("=" * 70)
h1 = d[0x13618:0x1361B]
print(f"  Bytes: {h1[0]:02X} {h1[1]:02X} {h1[2]:02X}")
if h1 == b"\xFD\x19\x4C":
    print("  -> FD 19 4C = STD $194C  (CONFIRMED in stock)")
else:
    print(f"  -> NOT STD $194C! Got: {h1.hex()}")

print("  Context (0x13610-0x13625):")
ctx = d[0x13610:0x13625]
print("  ", " ".join(f"{b:02X}" for b in ctx))

print()
print("=" * 70)
print("HOOK POINT 2: File 0x101E1 (v39+ hook - claimed STD $017B)")
print("=" * 70)
h2 = d[0x101E1:0x101E4]
print(f"  Bytes: {h2[0]:02X} {h2[1]:02X} {h2[2]:02X}")
if h2 == b"\xFD\x01\x7B":
    print("  -> FD 01 7B = STD $017B  (CONFIRMED in stock)")
else:
    print(f"  -> NOT STD $017B! Got: {h2.hex()}")

print("  Context (0x101D8-0x101ED):")
ctx2 = d[0x101D8:0x101ED]
print("  ", " ".join(f"{b:02X}" for b in ctx2))

# === FREE SPACE ===
print()
print("=" * 70)
print("FREE SPACE: File 0x0C500 (patch destination)")
print("=" * 70)
fs = d[0x0C500:0x0C530]
all_zero = all(b == 0 for b in fs)
if all_zero:
    print(f"  0xC500-0xC52F ({len(fs)} bytes): ALL ZEROS (confirmed free)")
else:
    print(f"  0xC500-0xC52F: NOT ALL ZEROS!")
    print("  ", " ".join(f"{b:02X}" for b in fs))

# Check a wider range
fs_wide = d[0x0C468:0x0C600]
zero_count = sum(1 for b in fs_wide if b == 0)
print(f"  0xC468-0xC5FF ({len(fs_wide)} bytes): {zero_count}/{len(fs_wide)} zeros ({100*zero_count//len(fs_wide)}%)")

# === $194C REFERENCES ===
print()
print("=" * 70)
print("ALL REFERENCES TO $194C (19 4C pattern)")
print("=" * 70)
ops = {0xFD: "STD", 0xFC: "LDD", 0xFE: "LDX", 0xBD: "JSR", 0xB6: "LDAA",
       0xF6: "LDAB", 0xBE: "LDS", 0xFF: "STX", 0xB7: "STAA", 0xF7: "STAB",
       0xB3: "SUBD", 0xBB: "ADDA", 0xFB: "ADDB", 0xB1: "CMPA", 0xF1: "CMPB",
       0xBC: "CPX"}
count = 0
for i in range(len(d) - 2):
    if d[i + 1] == 0x19 and d[i + 2] == 0x4C:
        op = d[i]
        name = ops.get(op, f"?{op:02X}")
        # CPU addr = file offset - 0x10000 + 0x8000 for banked, or file offset for lower
        print(f"  File 0x{i:05X}: {op:02X} 19 4C = {name} $194C")
        count += 1
print(f"  Total: {count} references")

# === $017B REFERENCES ===
print()
print("=" * 70)
print("ALL REFERENCES TO $017B (01 7B pattern)")
print("=" * 70)
count = 0
for i in range(len(d) - 2):
    if d[i + 1] == 0x01 and d[i + 2] == 0x7B:
        op = d[i]
        name = ops.get(op, f"?{op:02X}")
        print(f"  File 0x{i:05X}: {op:02X} 01 7B = {name} $017B")
        count += 1
print(f"  Total: {count} references")

# === $00A2 (RPM) REFERENCES ===
print()
print("=" * 70)
print("LDAA $A2 (96 A2) - RPM/25 reads")
print("=" * 70)
count = 0
for i in range(len(d) - 1):
    if d[i] == 0x96 and d[i + 1] == 0xA2:
        count += 1
print(f"  Total: {count} instances of LDAA $A2")

# === $0046 BIT OPERATIONS ===
print()
print("=" * 70)
print("BIT OPERATIONS ON $0046 (flag byte) - checking bit 7 is free")
print("=" * 70)
bit_names = {0x12: "BRSET", 0x13: "BRCLR", 0x14: "BSET", 0x15: "BCLR"}
bit7_used = False
for i in range(len(d) - 3):
    if d[i + 1] == 0x46 and d[i] in bit_names:
        op = d[i]
        mask = d[i + 2]
        name = bit_names[op]
        bits_str = f"{mask:08b}"
        bit7 = "BIT7!" if mask & 0x80 else ""
        if mask & 0x80:
            bit7_used = True
        print(f"  File 0x{i:05X}: {op:02X} 46 {mask:02X} = {name} $46,#${mask:02X} (bits: {bits_str}) {bit7}")
if not bit7_used:
    print("  -> Bit 7 ($80) is NOT used in any BRSET/BRCLR/BSET/BCLR on $46 = FREE!")
else:
    print("  -> WARNING: Bit 7 IS used somewhere!")

# === PATCHED BIN COMPARISON ===
print()
print("=" * 70)
print("COMPARING PATCHED BINS - what's at their hook points?")
print("=" * 70)

import os
patch_dir = r"A:\repos\VY_V6_Assembly_Modding\bin_patch_test"
for fname in sorted(os.listdir(patch_dir)):
    if fname.endswith(".bin") and "v38.3" in fname and "temp" not in fname:
        fpath = os.path.join(patch_dir, fname)
        pd = open(fpath, "rb").read()
        h_old = pd[0x13618:0x1361B]
        h_new = pd[0x101E1:0x101E4]
        patch = pd[0xC500:0xC502]
        
        old_hooked = h_old != b"\xFD\x19\x4C"
        new_hooked = h_new != b"\xFD\x01\x7B"
        
        print(f"\n  {fname}:")
        print(f"    0x13618: {h_old[0]:02X} {h_old[1]:02X} {h_old[2]:02X} {'(PATCHED - JSR $C500)' if h_old == bytes([0xBD,0xC5,0x00]) else '(stock STD $194C)' if h_old == bytes([0xFD,0x19,0x4C]) else '(??)'}")
        print(f"    0x101E1: {h_new[0]:02X} {h_new[1]:02X} {h_new[2]:02X} {'(PATCHED - JSR $C500)' if h_new == bytes([0xBD,0xC5,0x00]) else '(stock STD $017B)' if h_new == bytes([0xFD,0x01,0x7B]) else '(??)'}")
        print(f"    0xC500:  {patch[0]:02X} {patch[1]:02X} {'(has patch code)' if patch[0] != 0 else '(empty)'}")
        
        # Check what STD target the patch uses internally
        p = pd[0xC500:0xC52A]
        for j in range(len(p) - 2):
            if p[j] == 0xFD:  # STD extended
                target = (p[j+1] << 8) | p[j+2]
                print(f"    Patch STD at C500+{j:02X}: STD ${target:04X}")

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)
