#!/usr/bin/env python3
"""Disassemble stock binary around both hook points to understand D register flow"""

d = open(r"A:\repos\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin", "rb").read()

def disasm_range(data, start, end, title):
    """Simple HC11 disassembler for the key opcodes we care about"""
    print("=" * 70)
    print(title)
    print("=" * 70)
    i = start
    while i < end:
        b = data[i]
        addr = i  # file offset
        
        def b1(): return data[i+1]
        def b2(): return data[i+2]
        def w1(): return (data[i+1] << 8) | data[i+2]
        def rel(off, sz): 
            o = off if off < 128 else off - 256
            return i + sz + o
        
        try:
            if b == 0x96:   s = f"LDAA ${b1():02X}"; n = 2
            elif b == 0x97: s = f"STAA ${b1():02X}"; n = 2
            elif b == 0xD6: s = f"LDAB ${b1():02X}"; n = 2
            elif b == 0xD7: s = f"STAB ${b1():02X}"; n = 2
            elif b == 0xDC: s = f"LDD  ${b1():02X}"; n = 2
            elif b == 0xDD: s = f"STD  ${b1():02X}"; n = 2
            elif b == 0xDE: s = f"LDX  ${b1():02X}"; n = 2
            elif b == 0xDF: s = f"STX  ${b1():02X}"; n = 2
            elif b == 0xB6: s = f"LDAA ${w1():04X}"; n = 3
            elif b == 0xB7: s = f"STAA ${w1():04X}"; n = 3
            elif b == 0xF6: s = f"LDAB ${w1():04X}"; n = 3
            elif b == 0xF7: s = f"STAB ${w1():04X}"; n = 3
            elif b == 0xFC: s = f"LDD  ${w1():04X}"; n = 3
            elif b == 0xFD: s = f"STD  ${w1():04X}  <<<" if w1() in (0x194C, 0x017B) else f"STD  ${w1():04X}"; n = 3
            elif b == 0xFE: s = f"LDX  ${w1():04X}"; n = 3
            elif b == 0xFF: s = f"STX  ${w1():04X}"; n = 3
            elif b == 0xCC: s = f"LDD  #${w1():04X}"; n = 3
            elif b == 0xCE: s = f"LDX  #${w1():04X}"; n = 3
            elif b == 0x86: s = f"LDAA #${b1():02X}"; n = 2
            elif b == 0xC6: s = f"LDAB #${b1():02X}"; n = 2
            elif b == 0x81: s = f"CMPA #${b1():02X}"; n = 2
            elif b == 0xC1: s = f"CMPB #${b1():02X}"; n = 2
            elif b == 0x8C: s = f"CPX  #${w1():04X}"; n = 3
            elif b == 0xBC: s = f"CPX  ${w1():04X}"; n = 3
            elif b == 0x83: s = f"SUBD #${w1():04X}"; n = 3
            elif b == 0xC3: s = f"ADDD #${w1():04X}"; n = 3
            elif b == 0xB3: s = f"SUBD ${w1():04X}"; n = 3
            elif b == 0xF3: s = f"ADDD ${w1():04X}"; n = 3
            elif b == 0xBD: s = f"JSR  ${w1():04X}"; n = 3
            elif b == 0xAD: s = f"JSR  {b1()},X"; n = 2
            elif b == 0x8D: s = f"BSR  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x20: s = f"BRA  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x24: s = f"BCC  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x25: s = f"BCS  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x26: s = f"BNE  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x27: s = f"BEQ  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x22: s = f"BHI  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x23: s = f"BLS  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2A: s = f"BPL  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2B: s = f"BMI  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2C: s = f"BGE  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2D: s = f"BLT  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2E: s = f"BGT  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x2F: s = f"BLE  ${rel(b1(),2):05X}"; n = 2
            elif b == 0x39: s = "RTS"; n = 1
            elif b == 0x3B: s = "RTI"; n = 1
            elif b == 0x04: s = "LSRD"; n = 1
            elif b == 0x05: s = "ASLD"; n = 1
            elif b == 0x36: s = "PSHA"; n = 1
            elif b == 0x37: s = "PSHB"; n = 1
            elif b == 0x32: s = "PULA"; n = 1
            elif b == 0x33: s = "PULB"; n = 1
            elif b == 0x4F: s = "CLRA"; n = 1
            elif b == 0x5F: s = "CLRB"; n = 1
            elif b == 0x01: s = "NOP"; n = 1
            elif b == 0x12: s = f"BRSET ${b1():02X},#${b2():02X},rel"; n = 4
            elif b == 0x13: s = f"BRCLR ${b1():02X},#${b2():02X},rel"; n = 4
            elif b == 0x14: s = f"BSET  ${b1():02X},#${b2():02X}"; n = 3
            elif b == 0x15: s = f"BCLR  ${b1():02X},#${b2():02X}"; n = 3
            elif b == 0x1C: s = f"BSET  {b1()},X,#${b2():02X}"; n = 3
            elif b == 0xA6: s = f"LDAA  {b1()},X"; n = 2
            elif b == 0xA7: s = f"STAA  {b1()},X"; n = 2
            elif b == 0xE6: s = f"LDAB  {b1()},X"; n = 2
            elif b == 0xE7: s = f"STAB  {b1()},X"; n = 2
            elif b == 0xEC: s = f"LDD   {b1()},X"; n = 2
            elif b == 0xED: s = f"STD   {b1()},X"; n = 2
            elif b == 0xEE: s = f"LDX   {b1()},X"; n = 2
            elif b == 0x6F: s = f"CLR   {b1()},X"; n = 2
            elif b == 0x7F: s = f"CLR   ${w1():04X}"; n = 3
            elif b == 0x4A: s = "DECA"; n = 1
            elif b == 0x5A: s = "DECB"; n = 1
            elif b == 0x4C: s = "INCA"; n = 1
            elif b == 0x5C: s = "INCB"; n = 1
            elif b == 0x48: s = "ASLA"; n = 1
            elif b == 0x58: s = "ASLB"; n = 1
            elif b == 0x44: s = "LSRA"; n = 1
            elif b == 0x54: s = "LSRB"; n = 1
            elif b == 0x9B: s = f"ADDA ${b1():02X}"; n = 2
            elif b == 0xDB: s = f"ADDB ${b1():02X}"; n = 2
            elif b == 0x90: s = f"SUBA ${b1():02X}"; n = 2
            elif b == 0xD0: s = f"SUBB ${b1():02X}"; n = 2
            elif b == 0xBB: s = f"ADDA ${w1():04X}"; n = 3
            elif b == 0xFB: s = f"ADDB ${w1():04X}"; n = 3
            elif b == 0xB0: s = f"SUBA ${w1():04X}"; n = 3
            elif b == 0xF0: s = f"SUBB ${w1():04X}"; n = 3
            elif b == 0x91: s = f"CMPA ${b1():02X}"; n = 2
            elif b == 0xD1: s = f"CMPB ${b1():02X}"; n = 2
            elif b == 0xB1: s = f"CMPA ${w1():04X}"; n = 3
            elif b == 0xF1: s = f"CMPB ${w1():04X}"; n = 3
            elif b == 0x93: s = f"SUBD ${b1():02X}"; n = 2
            elif b == 0xD3: s = f"ADDD ${b1():02X}"; n = 2
            elif b == 0x10: s = f"SBA"; n = 1  # actually prefix in some cases
            elif b == 0x11: s = f"CBA"; n = 1
            elif b == 0x08: s = f"INX"; n = 1
            elif b == 0x09: s = f"DEX"; n = 1
            elif b == 0x3C: s = f"PSHX"; n = 1
            elif b == 0x38: s = f"PULX"; n = 1
            elif b == 0x7E: s = f"JMP  ${w1():04X}"; n = 3
            elif b == 0x6E: s = f"JMP  {b1()},X"; n = 2
            else: s = f".db  ${b:02X}"; n = 1
            
            hexbytes = " ".join(f"{data[i+j]:02X}" for j in range(n))
            marker = " <<<--- HOOK" if i == 0x101E1 or i == 0x13618 else ""
            print(f"  {addr:05X}: {hexbytes:<12s}  {s}{marker}")
            i += n
        except IndexError:
            print(f"  {addr:05X}: {b:02X}            (end of range)")
            i += 1
    print()

# Disassemble around hook point 2 (v38.4 target) - wider context
disasm_range(d, 0x10190, 0x10210, 
    "DWELL CALCULATION AREA (file 0x10190-0x10210)\n"
    "Hook target: 0x101E1 = STD $017B")

# Also show what reads $017B after it's written
disasm_range(d, 0x101C0, 0x101F5,
    "ZOOMED: Instructions around STD $017B (0x101E1)")

# Disassemble around old hook for comparison
disasm_range(d, 0x13600, 0x13640,
    "OLD HOOK AREA (file 0x13600-0x13640)\n"
    "Old hook: 0x13618 = STD $194C (init path)")

# Now the critical question: what READS $017B after STD writes it?
print("=" * 70)
print("WHO READS $017B? (LDD/LDAA/LDAB $017B)")
print("=" * 70)
for i in range(len(d) - 2):
    if d[i+1] == 0x01 and d[i+2] == 0x7B:
        op = d[i]
        # Show context: 10 bytes before and after
        ctx_start = max(0, i - 6)
        ctx_end = min(len(d), i + 10)
        ctx_hex = " ".join(f"{d[j]:02X}" for j in range(ctx_start, ctx_end))
        ops = {0xFC: "LDD", 0xFD: "STD", 0xB6: "LDAA", 0xF6: "LDAB", 
               0xB7: "STAA", 0xF7: "STAB", 0xFE: "LDX", 0xFF: "STX"}
        name = ops.get(op, f"?{op:02X}")
        print(f"  File 0x{i:05X}: {name} $017B")
        print(f"    Context: ...{ctx_hex}...")
print()

# Also check: what uses $0199 (dwell RAM) - is it downstream?
print("=" * 70)
print("WHO USES $0199 (dwell time RAM)?")
print("=" * 70)
for i in range(len(d) - 2):
    if d[i+1] == 0x01 and d[i+2] == 0x99:
        op = d[i]
        ops = {0xFC: "LDD", 0xFD: "STD", 0xB6: "LDAA", 0xF6: "LDAB",
               0xB7: "STAA", 0xF7: "STAB", 0xFE: "LDX", 0xFF: "STX"}
        name = ops.get(op, f"?{op:02X}")
        print(f"  File 0x{i:05X}: {name} $0199")
print()

# Check $0093 (what gets loaded into D before STD $017B)
print("=" * 70)
print("WHAT IS $0093? (loaded into D right before STD $017B)")
print("=" * 70)
for i in range(len(d) - 1):
    if d[i+1] == 0x93 and d[i] in (0xDC, 0xDD, 0x96, 0x97, 0xD6, 0xD7):
        ops = {0xDC: "LDD", 0xDD: "STD", 0x96: "LDAA", 0x97: "STAA", 
               0xD6: "LDAB", 0xD7: "STAB"}
        name = ops.get(d[i], f"?{d[i]:02X}")
        print(f"  File 0x{i:05X}: {name} $93 (direct page = $0093)")
print()
print("Total references to direct-page $93 shown above")
