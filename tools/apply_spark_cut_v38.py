#!/usr/bin/env python3
"""
VY V6 Spark Cut Patch Applier v38
=================================
Applies the Chr0m3-method spark cut patch to VY V6 Enhanced binary.

Author: Jason King (kingaustraliagg)
Date: January 18, 2026

Usage:
    python apply_spark_cut_v38.py input.bin output.bin [--rpm 6000|3000]
    python apply_spark_cut_v38.py input.bin output.bin --undo

"""

import sys
import os
import struct
from datetime import datetime

# Constants
HOOK_OFFSET = 0x101E1       # Where we patch the hook
CODE_OFFSET = 0x0C500       # Where we place our code
EXPECTED_ORIGINAL = bytes([0xFD, 0x01, 0x7B])  # STD $017B

# 6000 RPM Production patch (verified branch offsets)
CODE_6000RPM = bytes([
    0x12, 0x46, 0x80, 0x0B,  # BRSET $46,$80,$C50F
    0x96, 0xA2,              # LDAA $A2
    0x81, 0xF0,              # CMPA #$F0 (6000 RPM)
    0x25, 0x0E,              # BCS STORE_NORMAL
    0x14, 0x46, 0x80,        # BSET $46,$80
    0x20, 0x0D,              # BRA INJECT_FAKE
    0x96, 0xA2,              # LDAA $A2 (CHECK_RESUME)
    0x81, 0xEC,              # CMPA #$EC (5900 RPM)
    0x24, 0x07,              # BCC INJECT_FAKE
    0x15, 0x46, 0x80,        # BCLR $46,$80
    0xFD, 0x01, 0x7B,        # STD $017B (STORE_NORMAL)
    0x39,                    # RTS
    0xCC, 0x3E, 0x80,        # LDD #$3E80 (INJECT_FAKE)
    0xFD, 0x01, 0x7B,        # STD $017B
    0x39                     # RTS
])

# 3000 RPM Test patch (same structure, different thresholds)
CODE_3000RPM = bytes([
    0x12, 0x46, 0x80, 0x0B,  # BRSET $46,$80,$C50F
    0x96, 0xA2,              # LDAA $A2
    0x81, 0x78,              # CMPA #$78 (3000 RPM) ← DIFFERENT
    0x25, 0x0E,              # BCS STORE_NORMAL
    0x14, 0x46, 0x80,        # BSET $46,$80
    0x20, 0x0D,              # BRA INJECT_FAKE
    0x96, 0xA2,              # LDAA $A2 (CHECK_RESUME)
    0x81, 0x74,              # CMPA #$74 (2900 RPM) ← DIFFERENT
    0x24, 0x07,              # BCC INJECT_FAKE
    0x15, 0x46, 0x80,        # BCLR $46,$80
    0xFD, 0x01, 0x7B,        # STD $017B (STORE_NORMAL)
    0x39,                    # RTS
    0xCC, 0x3E, 0x80,        # LDD #$3E80 (INJECT_FAKE)
    0xFD, 0x01, 0x7B,        # STD $017B
    0x39                     # RTS
])

# Hook patch
HOOK_PATCHED = bytes([0xBD, 0xC5, 0x00])  # JSR $C500


def print_banner():
    print("=" * 60)
    print("  VY V6 SPARK CUT PATCH APPLIER v38")
    print("  Chr0m3 3X Period Injection Method")
    print("=" * 60)
    print()


def verify_binary(data):
    """Verify this is the correct VY V6 Enhanced binary."""
    # Check for pcmhacking.net string
    if b'pcmhacking.net' not in data:
        print("⚠️  Warning: pcmhacking.net string not found")
        print("   This may not be the VY V6 Enhanced binary")
        return False
    
    # Check file size
    if len(data) != 0x20000:  # 128KB
        print(f"⚠️  Warning: File size is {len(data)} bytes, expected 131072 (128KB)")
        return False
    
    # Check hook point has expected bytes
    hook_bytes = data[HOOK_OFFSET:HOOK_OFFSET+3]
    if hook_bytes == EXPECTED_ORIGINAL:
        print("✅ Hook point verified: STD $017B found at 0x101E1")
        return True
    elif hook_bytes == HOOK_PATCHED:
        print("⚠️  Binary already patched (JSR $C500 at hook point)")
        return "already_patched"
    else:
        print(f"❌ Unexpected bytes at hook point: {hook_bytes.hex().upper()}")
        print(f"   Expected: {EXPECTED_ORIGINAL.hex().upper()} (stock)")
        print(f"         or: {HOOK_PATCHED.hex().upper()} (patched)")
        return False


def verify_free_space(data):
    """Verify code space is empty (all zeros)."""
    code_area = data[CODE_OFFSET:CODE_OFFSET+len(CODE_6000RPM)]
    if all(b == 0 for b in code_area):
        print(f"✅ Code space verified: {len(CODE_6000RPM)} bytes free at 0x{CODE_OFFSET:05X}")
        return True
    elif code_area == CODE_6000RPM or code_area == CODE_3000RPM:
        print("⚠️  Code already present at patch location")
        return "already_patched"
    else:
        print(f"❌ Code space not empty at 0x{CODE_OFFSET:05X}")
        print(f"   Found: {code_area[:16].hex().upper()}...")
        return False


def apply_patch(data, rpm_mode):
    """Apply the spark cut patch."""
    data = bytearray(data)
    
    # Select code based on RPM mode
    if rpm_mode == 3000:
        code = CODE_3000RPM
        print(f"📝 Applying 3000 RPM TEST patch...")
    else:
        code = CODE_6000RPM
        print(f"📝 Applying 6000 RPM PRODUCTION patch...")
    
    # Write hook
    data[HOOK_OFFSET:HOOK_OFFSET+3] = HOOK_PATCHED
    print(f"   Hook: 0x{HOOK_OFFSET:05X} = BD C5 00 (JSR $C500)")
    
    # Write code
    data[CODE_OFFSET:CODE_OFFSET+len(code)] = code
    print(f"   Code: 0x{CODE_OFFSET:05X} = {len(code)} bytes")
    
    return bytes(data)


def undo_patch(data):
    """Remove the spark cut patch (restore stock)."""
    data = bytearray(data)
    
    # Restore original hook
    data[HOOK_OFFSET:HOOK_OFFSET+3] = EXPECTED_ORIGINAL
    print(f"📝 Restored stock hook at 0x{HOOK_OFFSET:05X}")
    
    # Zero out code area (optional but clean)
    data[CODE_OFFSET:CODE_OFFSET+len(CODE_6000RPM)] = bytes(len(CODE_6000RPM))
    print(f"   Cleared code at 0x{CODE_OFFSET:05X}")
    
    return bytes(data)


def main():
    print_banner()
    
    # Parse arguments
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python apply_spark_cut_v38.py input.bin output.bin [--rpm 6000|3000]")
        print("  python apply_spark_cut_v38.py input.bin output.bin --undo")
        print()
        print("Options:")
        print("  --rpm 6000    Apply 6000 RPM production patch (default)")
        print("  --rpm 3000    Apply 3000 RPM test patch")
        print("  --undo        Remove patch, restore stock")
        return 1
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Parse options
    rpm_mode = 6000
    undo_mode = False
    
    for i, arg in enumerate(sys.argv[3:], 3):
        if arg == "--undo":
            undo_mode = True
        elif arg == "--rpm" and i+1 < len(sys.argv):
            rpm_mode = int(sys.argv[i+1])
    
    # Read input file
    if not os.path.exists(input_file):
        print(f"❌ Input file not found: {input_file}")
        return 1
    
    print(f"📂 Reading: {input_file}")
    with open(input_file, 'rb') as f:
        data = f.read()
    print(f"   Size: {len(data)} bytes ({len(data)//1024}KB)")
    print()
    
    # Verify binary
    verify_result = verify_binary(data)
    if verify_result is False:
        print()
        print("❌ Binary verification failed. Aborting.")
        return 1
    
    space_result = verify_free_space(data)
    if space_result is False:
        print()
        print("❌ Free space verification failed. Aborting.")
        return 1
    
    print()
    
    # Apply or undo patch
    if undo_mode:
        if verify_result != "already_patched":
            print("⚠️  Binary doesn't appear to be patched.")
            response = input("Continue anyway? (y/n): ")
            if response.lower() != 'y':
                return 1
        data = undo_patch(data)
    else:
        if verify_result == "already_patched":
            print("⚠️  Binary already patched.")
            response = input("Re-apply patch? (y/n): ")
            if response.lower() != 'y':
                return 1
        data = apply_patch(data, rpm_mode)
    
    # Write output file
    print()
    print(f"💾 Writing: {output_file}")
    with open(output_file, 'wb') as f:
        f.write(data)
    print(f"   Size: {len(data)} bytes")
    
    print()
    print("=" * 60)
    if undo_mode:
        print("  ✅ PATCH REMOVED - Stock behavior restored")
    else:
        print(f"  ✅ PATCH APPLIED - {rpm_mode} RPM spark cut active")
        print()
        print("  Next steps:")
        print("  1. Flash to ECU with your preferred tool")
        print("  2. Monitor $0046 bit 7 via ALDL scanner")
        print("  3. Verify limiter activates at target RPM")
    print("=" * 60)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
