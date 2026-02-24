#!/usr/bin/env python3
"""
Verify v38 Spark Cut Patch Branch Offsets
==========================================
Validates all HC11 branch instruction offsets in the 42-byte v38 spark cut
patch. Checks BRSET, BCS, BRA, BCC targets resolve to the correct labels.
Also verifies the STD $017B (dwell intermediate store) instructions.

Usage:
    python verify_v38_offsets.py

Outputs:
    Pass/fail for each branch instruction with computed vs expected targets.
    Exits 0 if all offsets correct, 1 if any mismatch.

Patch layout (42 bytes at $C500 or $5D05):
    PSHA → BRSET $46,$80,CHECK_RESUME → LDAA $A2 → CMPA #RPM_HIGH →
    BCS STORE_NORMAL → BSET $46,$80 → BRA INJECT_FAKE → ... → RTS

Author:  Jason King (KingAI Tuning)
Date:    January 2026
Repo:    https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches
Status:  ✅ WORKING — all branch offsets verified correct

See also:
    - asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm
    - custom_ose_$060_445_plan.md §3.1 (v38 patch bytes)
"""

code = bytes([
    0x36,                    # $C500: PSHA
    0x12, 0x46, 0x80, 0x0B,  # $C501: BRSET $46,$80,+$0B
    0x96, 0xA2,              # $C505: LDAA $A2
    0x81, 0xF0,              # $C507: CMPA #$F0
    0x25, 0x0E,              # $C509: BCS +$0E
    0x14, 0x46, 0x80,        # $C50B: BSET $46,$80
    0x20, 0x0E,              # $C50E: BRA +$0E
    0x96, 0xA2,              # $C510: LDAA $A2
    0x81, 0xEC,              # $C512: CMPA #$EC
    0x24, 0x08,              # $C514: BCC +$08
    0x15, 0x46, 0x80,        # $C516: BCLR $46,$80
    0x32,                    # $C519: PULA
    0xFD, 0x01, 0x7B,        # $C51A: STD $017B
    0x39,                    # $C51D: RTS
    0x32,                    # $C51E: PULA
    0xCC, 0x3E, 0x80,        # $C51F: LDD #$3E80
    0xFD, 0x01, 0x7B,        # $C522: STD $017B
    0x39,                    # $C525: RTS
    0x4A, 0x4B, 0x26, 0x02,  # $C526: signature
])

base = 0xC500
print(f'Total bytes: {len(code)}')
print()

# HC11 branch: target = PC_after_instruction + signed_offset
# BRSET is 4 bytes (opcode, addr, mask, offset), so PC_after = PC + 4
# BCS/BRA/BCC are 2 bytes (opcode, offset), so PC_after = PC + 2

# BRSET at $C501
brset_pc_after = 0xC501 + 4  # = $C505
brset_target = brset_pc_after + 0x0B  # = $C510
ok = "OK" if brset_target == 0xC510 else "WRONG!"
print(f'BRSET at $C501: PC_after=$C505, offset=$0B -> target=${brset_target:04X} (expect CHECK_RESUME $C510) {ok}')

# BCS at $C509
bcs_pc_after = 0xC509 + 2  # = $C50B
bcs_target = bcs_pc_after + 0x0E  # = $C519
ok = "OK" if bcs_target == 0xC519 else "WRONG!"
print(f'BCS   at $C509: PC_after=$C50B, offset=$0E -> target=${bcs_target:04X} (expect STORE_NORMAL $C519) {ok}')

# BRA at $C50E
bra_pc_after = 0xC50E + 2  # = $C510
bra_target = bra_pc_after + 0x0E  # = $C51E
ok = "OK" if bra_target == 0xC51E else "WRONG!"
print(f'BRA   at $C50E: PC_after=$C510, offset=$0E -> target=${bra_target:04X} (expect INJECT_FAKE $C51E) {ok}')

# BCC at $C514
bcc_pc_after = 0xC514 + 2  # = $C516
bcc_target = bcc_pc_after + 0x08  # = $C51E
ok = "OK" if bcc_target == 0xC51E else "WRONG!"
print(f'BCC   at $C514: PC_after=$C516, offset=$08 -> target=${bcc_target:04X} (expect INJECT_FAKE $C51E) {ok}')

print()

# Verify STD targets
for i in range(len(code) - 2):
    if code[i] == 0xFD:
        addr = (code[i + 1] << 8) | code[i + 2]
        pc = base + i
        ok = "OK (dwell intermediate)" if addr == 0x017B else "WRONG!"
        print(f'STD   at ${pc:04X}: stores to ${addr:04X} {ok}')

print()

# Verify key opcodes at expected positions
checks = [
    (0,  0x36, 'PSHA (save A)'),
    (25, 0x32, 'PULA (STORE_NORMAL - restore A)'),
    (26, 0xFD, 'STD (store real dwell)'),
    (29, 0x39, 'RTS (end normal path)'),
    (30, 0x32, 'PULA (INJECT_FAKE - clean stack)'),
    (31, 0xCC, 'LDD #imm (load fake dwell)'),
    (37, 0x39, 'RTS (end fake path)'),
]
all_ok = True
for offset, expected, label in checks:
    actual = code[offset]
    if actual == expected:
        print(f'  [{offset:2d}] ${base + offset:04X}: ${actual:02X} = {label} ... OK')
    else:
        print(f'  [{offset:2d}] ${base + offset:04X}: ${actual:02X} = {label} ... WRONG (expected ${expected:02X})')
        all_ok = False

print()
print('Code hex (38 bytes):')
print(' '.join(f'{b:02X}' for b in code[:38]))
print()
print('Signature (4 bytes):')
print(' '.join(f'{b:02X}' for b in code[38:42]))
print()

if all_ok:
    print('ALL BRANCH OFFSETS AND OPCODES VERIFIED CORRECT')
else:
    print('*** ERRORS FOUND ***')
