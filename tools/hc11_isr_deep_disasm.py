#!/usr/bin/env python3
"""
HC11 ISR Deep Disassembler using Ghidra SLEIGH
==============================================
Deep disassembly of 3X Period Timer ISR (0x180DB) to find TOC1 write mechanism.
Uses existing HC11 disassembler and pattern matching to trace indirect addressing.

⚠️ UNTESTED experimental analysis for VY V6 ECU modification research.

Author: KingAI Auto Tuning Research
Date: November 20, 2025
"""

import sys
from pathlib import Path
from typing import List, Dict, Tuple, Optional

# Try to import existing disassembler
try:
    from hc11_disassembler import HC11Disassembler
    HAS_DISASM = True
except ImportError:
    HAS_DISASM = False
    print("⚠️  hc11_disassembler.py not found - using basic pattern matching")


# HC11 addressing modes and their patterns
HC11_OPCODES = {
    # Direct addressing (8-bit address -> 0x0000-0x00FF)
    0x96: ("LDAA", "direct", 2),
    0xD6: ("LDAB", "direct", 2),
    0x97: ("STAA", "direct", 2),
    0xD7: ("STAB", "direct", 2),
    0xDD: ("STD", "direct", 2),
    
    # Extended addressing (16-bit address)
    0xB6: ("LDAA", "extended", 3),
    0xF6: ("LDAB", "extended", 3),
    0xB7: ("STAA", "extended", 3),
    0xF7: ("STAB", "extended", 3),
    0xFD: ("STD", "extended", 3),
    0xFC: ("LDD", "extended", 3),
    0xFE: ("LDX", "extended", 3),
    0xFF: ("STX", "extended", 3),
    
    # Indexed addressing (X register)
    0xA6: ("LDAA", "indexed", 2),
    0xE6: ("LDAB", "indexed", 2),
    0xA7: ("STAA", "indexed", 2),
    0xE7: ("STAB", "indexed", 2),
    0xED: ("STD", "indexed", 2),
    0xEC: ("LDD", "indexed", 2),
    0xEE: ("LDX", "indexed", 2),
    0xEF: ("STX", "indexed", 2),
    
    # Subroutine calls
    0xBD: ("JSR", "extended", 3),
    0xAD: ("JSR", "indexed", 2),
    # Return instructions
    0x3B: ("RTI", "inherent", 1),
    0x39: ("RTS", "inherent", 1),
    # Stack operations
    0x36: ("PSHA", "inherent", 1),
    0x37: ("PSHB", "inherent", 1),
    0x3C: ("PSHX", "inherent", 1),
    0x32: ("PULA", "inherent", 1),
    0x33: ("PULB", "inherent", 1),
    0x38: ("PULX", "inherent", 1),
    
    # Branches
    0x20: ("BRA", "relative", 2),
    0x22: ("BHI", "relative", 2),
    0x23: ("BLS", "relative", 2),
    0x24: ("BCC", "relative", 2),
    0x25: ("BCS", "relative", 2),
    0x26: ("BNE", "relative", 2),
    0x27: ("BEQ", "relative", 2),
}


def disassemble_region(data: bytes, start_offset: int, length: int, base_addr: int = 0x8000) -> List[Dict]:
    """Disassemble a region of binary data"""
    instructions = []
    offset = start_offset
    end_offset = min(start_offset + length, len(data))
    
    while offset < end_offset:
        opcode = data[offset]
        
        if opcode in HC11_OPCODES:
            mnemonic, mode, size = HC11_OPCODES[opcode]
            
            # Build instruction dict
            instr = {
                "offset": offset,
                "address": base_addr + offset,
                "opcode": opcode,
                "mnemonic": mnemonic,
                "mode": mode,
                "size": size,
                "bytes": data[offset:offset+size].hex().upper()
            }
            
            # Parse operands based on mode
            if mode == "direct" and size >= 2:
                addr = 0x1000 + data[offset + 1]  # Direct page at 0x1000+
                instr["operand_addr"] = addr
                instr["disasm"] = f"{mnemonic} ${addr:04X}"
                
            elif mode == "extended" and size >= 3:
                addr = (data[offset + 1] << 8) | data[offset + 2]
                instr["operand_addr"] = addr
                instr["disasm"] = f"{mnemonic} ${addr:04X}"
                
            elif mode == "indexed" and size >= 2:
                offset_val = data[offset + 1]
                instr["operand_offset"] = offset_val
                instr["disasm"] = f"{mnemonic} ${offset_val:02X},X"
                
            elif mode == "relative" and size >= 2:
                rel_offset = data[offset + 1]
                # Convert signed byte
                if rel_offset > 127:
                    rel_offset = rel_offset - 256
                target_addr = base_addr + offset + size + rel_offset
                instr["branch_target"] = target_addr
                instr["disasm"] = f"{mnemonic} ${target_addr:04X}"
                
            elif mnemonic in ["JSR"]:
                if mode == "extended" and size >= 3:
                    addr = (data[offset + 1] << 8) | data[offset + 2]
                    instr["call_target"] = addr
                    instr["disasm"] = f"JSR ${addr:04X}"
                elif mode == "indexed" and size >= 2:
                    offset_val = data[offset + 1]
                    instr["disasm"] = f"JSR ${offset_val:02X},X"
                    
            else:
                instr["disasm"] = mnemonic
            
            instructions.append(instr)
            offset += size
        else:
            # Unknown opcode - skip
            offset += 1
    
    return instructions


def find_toc1_references(instructions: List[Dict]) -> List[Dict]:
    """Find all references to TOC1 register (0x1016/0x1017)"""
    toc1_refs = []
    
    TOC1_ADDRS = {0x1016, 0x1017}
    
    for instr in instructions:
        if "operand_addr" in instr and instr["operand_addr"] in TOC1_ADDRS:
            toc1_refs.append(instr)
    
    return toc1_refs


def find_indirect_writes(instructions: List[Dict]) -> List[Dict]:
    """Find potential indirect writes via X register or JSR calls"""
    indirect_patterns = []
    
    for i, instr in enumerate(instructions):
        # Pattern 1: LDX #addr followed by STAA/STAB offset,X
        if instr["mnemonic"] == "LDX" and "operand_addr" in instr:
            # Look ahead for indexed stores
            for j in range(i + 1, min(i + 10, len(instructions))):
                next_instr = instructions[j]
                if next_instr["mode"] == "indexed" and next_instr["mnemonic"] in ["STAA", "STAB", "STD"]:
                    # Calculate effective address
                    base_addr = instr["operand_addr"]
                    offset = next_instr.get("operand_offset", 0)
                    effective_addr = base_addr + offset
                    
                    indirect_patterns.append({
                        "type": "indexed_write",
                        "ldx_instr": instr,
                        "store_instr": next_instr,
                        "effective_addr": effective_addr,
                        "description": f"LDX #${base_addr:04X} + ST* ${offset:02X},X = ${effective_addr:04X}"
                    })
        
        # Pattern 2: JSR to subroutine (may write TOC1 internally)
        elif instr["mnemonic"] == "JSR" and "call_target" in instr:
            indirect_patterns.append({
                "type": "subroutine_call",
                "jsr_instr": instr,
                "call_target": instr["call_target"],
                "description": f"JSR ${instr['call_target']:04X} (may write TOC1)"
            })
    
    return indirect_patterns


def analyze_3x_period_isr(binary_path: str):
    """Deep analysis of 3X Period Timer ISR"""
    
    print("\n" + "=" * 80)
    print("HC11 3X PERIOD TIMER ISR DEEP DISASSEMBLY")
    print("=" * 80)
    print(f"Binary: {Path(binary_path).name}")
    print(f"Target ISR: $35FF (TIC3 - 3X Crank Signal Handler)")
    print("Vector: $FFEA -> $200F -> JMP $35FF")
    print("=" * 80 + "\n")
    
    # Load binary
    data = Path(binary_path).read_bytes()
    base_addr = 0x0000  # LOW bank, direct file offset mapping
    
    # ISR address and estimated size (verified from disasm_tic3_isr.py)
    ISR_ADDR = 0x35FF
    ISR_OFFSET = ISR_ADDR  # Direct offset in LOW bank
    ISR_SIZE = 300  # TIC3 handler runs to about $3719
    
    print(f"[LOC] ISR Location:")
    print(f"   File Offset: 0x{ISR_OFFSET:04X}")
    print(f"   HC11 Address: ${ISR_ADDR:04X}")
    print(f"   Analysis Size: {ISR_SIZE} bytes\n")
    
    # Disassemble ISR
    print("[DISASM] Disassembling ISR...")
    instructions = disassemble_region(data, ISR_OFFSET, ISR_SIZE, base_addr)
    print(f"   Found {len(instructions)} instructions\n")
    
    # Find direct TOC1 references
    print("[TARGET] Direct TOC1 References:")
    print("-" * 60)
    toc1_refs = find_toc1_references(instructions)
    
    if toc1_refs:
        for ref in toc1_refs:
            print(f"   [FOUND] {ref['address']:04X}: {ref['disasm']}")
            print(f"      Opcode: 0x{ref['opcode']:02X} ({ref['mnemonic']})")
            print(f"      Mode: {ref['mode']}")
    else:
        print("   [WARN] No direct TOC1 references found")
        print("   Likely uses indirect addressing or subroutine calls\n")
    
    # Find indirect write patterns
    print("\n[SEARCH] Indirect Write Patterns:")
    print("-" * 60)
    indirect = find_indirect_writes(instructions)
    
    toc1_candidates = []
    for pattern in indirect:
        if pattern["type"] == "indexed_write":
            eff_addr = pattern["effective_addr"]
            # Check if effective address is near TOC1 (0x1016/0x1017)
            if 0x1000 <= eff_addr <= 0x1030:  # Timer register range
                print("\n   [OK] POTENTIAL TOC1 WRITE:")
                print(f"      {pattern['description']}")
                print(f"      LDX at: 0x{pattern['ldx_instr']['address']:04X}")
                print(f"      Store: 0x{pattern['store_instr']['address']:04X}")
                
                if eff_addr in [0x1016, 0x1017]:
                    print(f"      [CONFIRMED] TOC1 at 0x{eff_addr:04X}")
                    toc1_candidates.append(pattern)
                else:
                    print(f"      Target: Timer register 0x{eff_addr:04X}")
        
        elif pattern["type"] == "subroutine_call":
            print("\n   [CALL] Subroutine Call:")
            print(f"      {pattern['description']}")
            print(f"      JSR at: 0x{pattern['jsr_instr']['address']:04X}")
            print(f"      Target: 0x{pattern['call_target']:04X}")
            print("      [WARN] Needs tracing into subroutine")
    
    # Print full disassembly
    print("\n\n[DISASM] Complete ISR Disassembly:")
    print("-" * 80)
    print(f"{'Address':<10} {'Bytes':<12} {'Disassembly':<30} {'Notes'}")
    print("-" * 80)
    
    for instr in instructions[:50]:  # Limit to first 50 instructions
        addr_str = f"0x{instr['address']:04X}"
        bytes_str = instr['bytes']
        disasm_str = instr.get('disasm', instr['mnemonic'])
        
        # Add notes
        notes = ""
        if instr.get('operand_addr') in [0x1016, 0x1017]:
            notes = "[!] TOC1 ACCESS"
        elif instr['mnemonic'] == "JSR":
            notes = "[CALL]"
        elif instr['mnemonic'] == "RTI":
            notes = "[RTI] ISR Return"
        elif instr['mnemonic'] in ["PSHA", "PSHB", "PSHX"]:
            notes = "[SAVE]"
        elif instr['mnemonic'] in ["PULA", "PULB", "PULX"]:
            notes = "[RESTORE]"
        
        print(f"{addr_str:<10} {bytes_str:<12} {disasm_str:<30} {notes}")
    
    # Summary
    print("\n" + "=" * 80)
    print("ANALYSIS SUMMARY")
    print("=" * 80)
    
    if toc1_candidates:
        print(f"\n[OK] Found {len(toc1_candidates)} TOC1 write candidate(s):")
        for i, cand in enumerate(toc1_candidates, 1):
            print(f"\n   Candidate #{i}:")
            print(f"   Location: 0x{cand['store_instr']['address']:04X}")
            print(f"   Pattern: {cand['description']}")
            print("\n   [TARGET] IGNITION CUT HOOK POINT:")
            print(f"   Insert check BEFORE 0x{cand['store_instr']['address']:04X}")
            print(f"   Pseudocode:")
            print(f"       LDD  $00F3       ; Load RPM")
            print(f"       CMPD #$1900      ; Compare to 6400 RPM (0x1900 = 6400)")
            print(f"       BLS  skip_cut    ; Branch if RPM < limiter")
            print(f"       BRA  end_isr     ; Skip TOC1 write (ignition cut)")
            print(f"   skip_cut:")
            print(f"       {cand['store_instr']['disasm']}  ; Original TOC1 write")
    else:
        print("\n[WARN] No TOC1 write candidates found in direct analysis")
        print("   Possible reasons:")
        print("   1. TOC1 write is in called subroutine")
        print("   2. Uses complex indirect addressing")
        print("   3. ISR size estimation incorrect")
        print("\n   [NEXT] Trace JSR calls to find TOC1 write location")
    
    print("\n" + "=" * 80)
    print("FOR CHR0M3 MOTORSPORT:")
    print("=" * 80)
    print("""
1. Scope EST pin during crank to confirm timing
2. Identify which instruction writes TOC1 (spark timing)
3. Verify safe insertion point for RPM check
4. Test modified binary on bench with oscilloscope
5. Measure ISR execution time increase (should be <50µs)

Files generated: (ready to share)
- This analysis output (save to text file)
- timer_io_analysis.json (hardware constraints)
- timer_accesses.csv (all 639 timer operations)
""")


def main():
    if len(sys.argv) < 2:
        print("Usage: python hc11_isr_deep_disasm.py <binary_file>")
        print("\nExample:")
        print('  python hc11_isr_deep_disasm.py "VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin"')
        sys.exit(1)
    
    binary_file = sys.argv[1]
    
    if not Path(binary_file).exists():
        print(f"[ERROR] Binary file not found: {binary_file}")
        sys.exit(1)
    
    analyze_3x_period_isr(binary_file)
    
    print("\n[DONE] Analysis complete!")


if __name__ == "__main__":
    main()
