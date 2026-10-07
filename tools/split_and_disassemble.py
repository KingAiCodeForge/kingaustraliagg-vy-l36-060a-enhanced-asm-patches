#!/usr/bin/env python3
"""Split, heuristically disassemble, and compare 128 KiB VY Delco images.

The three file-bank ranges are derived from the OSE FlashTool read/write
layout. Capstone's M680X decoder is used for instruction decoding. Code/data
classification is heuristic: recursive descent is seeded in the mixed common
region, while the remaining program windows use a linear sweep. Generated
output is evidence for review, not a complete decompilation or ownership map.

Examples:
  python split_and_disassemble.py image.bin
  python split_and_disassemble.py image.bin --split-only
  python split_and_disassemble.py enhanced.bin --diff-against stock.bin
"""

import argparse
import re
from pathlib import Path

# --- Configuration ---
SOURCE_SIZE = 0x20000

# Bank definitions: (name, bin_start, bin_end, cpu_base_address)
BANKS = [
    ("bank1", 0x00000, 0x10000, 0x0000),  # 64KB, CPU $0000-$FFFF
    ("bank2", 0x10000, 0x18000, 0x8000),  # 32KB, CPU $8000-$FFFF (paged)
    ("bank3", 0x18000, 0x20000, 0x8000),  # 32KB, CPU $8000-$FFFF (paged)
]

# HC11 vector table at $FFF0-$FFFF (in bank 1 only)
VECTORS = {
    0xFFD6: "SCI",
    0xFFD8: "SPI",
    0xFFDA: "PAI_Edge",
    0xFFDC: "PA_Overflow",
    0xFFDE: "Timer_Overflow",
    0xFFE0: "OC5",
    0xFFE2: "OC4",
    0xFFE4: "OC3",
    0xFFE6: "OC2",
    0xFFE8: "OC1",
    0xFFEA: "IC3",
    0xFFEC: "IC2",
    0xFFEE: "IC1",
    0xFFF0: "RTI",
    0xFFF2: "IRQ",
    0xFFF4: "XIRQ",
    0xFFF6: "SWI",
    0xFFF8: "Illegal_Opcode",
    0xFFFA: "COP_Watchdog",
    0xFFFC: "Clock_Monitor",
    0xFFFE: "RESET",
}

# Known address labels from XDF/disassembly work
KNOWN_LABELS = {
    # EEPROM/NVRAM
    0x0E00: "EEPROM_VIN",
    0x0F00: "EEPROM_End",
    # Calibration region
    0x2000: "CalStart",
    0x4000: "FlashCalStart",
    0x4006: "Checksum_HI",
    0x4007: "Checksum_LO",
    0x5FFF: "CalEnd",
    # Program region
    0x7FF0: "CalID",
    0x8000: "ProgROM_Start",
    0xFF80: "ProgID",
    # HC11 I/O registers - $1000-$100D are variant-dependent.
    # See HC11_VARIANT_REGISTERS below for all possibilities.
    # Only the label used in KNOWN_LABELS is the "safe" common name.
    0x1000: "PORTA",    # All variants
    0x1004: "PORTB",    # All variants
    0x1008: "PORTD",    # All variants
    0x1009: "DDRD",
    # $100E+: timer subsystem shared by the reviewed variants.
    0x100E: "TCNT_H",
    0x100F: "TCNT_L",
    0x1020: "TCTL1",    # Timer Control 1 (EST output mode)
    0x1021: "TCTL2",
    0x1022: "TMSK1",
    0x1023: "TFLG1",
    0x1024: "TMSK2",
    0x1025: "TFLG2",
    0x1026: "PACTL",
    0x1027: "PACNT",
    # SPI - same across the reviewed variants.
    0x1028: "SPCR",
    0x1029: "SPSR",
    0x102A: "SPDR",
    # SCI - same across the reviewed variants.
    0x102B: "BAUD",
    0x102C: "SCCR1",
    0x102D: "SCCR2",
    0x102E: "SCSR",
    0x102F: "SCDR",
    # ADC - HC11E and HC11F both place it at $1030.
    0x1030: "ADCTL",
    # System registers - same across the reviewed variants.
    0x1039: "OPTION",
    0x103A: "COPRST",
    0x103D: "INIT",
    0x103F: "CONFIG",
    # ISR handlers in common area
    0x29D3: "ISR_SCI",
    0x2BAF: "ISR_Default_RTI",
    0x2BAC: "ISR_XIRQ",
    0x2BA0: "ISR_SWI",
    0x2BA6: "ISR_ILLOP",
    0x301F: "ISR_TIC1",
    0x30BA: "ISR_IRQ",
    0x358A: "ISR_TIC2",
    0x35BD: "ISR_TOC3_EST",
    0x35DE: "ISR_TOC4",
    0x35FF: "ISR_TIC3_24X_Crank",
    0x3719: "ISR_TIC3_RTS",
    0x371A: "Dwell_Calc",
    0x37A6: "ISR_TOC1",
}

# Additional code entry points in $2000-$5FFF that recursive descent
# can't reach (computed jump table targets, subroutines called via
# indexed addressing, etc.)
EXTRA_CODE_SEEDS = [
    # TIC3 ISR computed jump table targets (6 cylinder sync cases)
    0x361C,  # cylinder sync case (fall-through from brclr)
    0x365C,  # cyl case 0
    0x3667,  # cyl case 1
    0x367D,  # cyl case 2
    0x368F,  # cyl case 3
    0x36A0,  # cyl case 4
    0x36AB,  # cyl case 5
    0x36E6,  # period calculation
    0x371A,  # Dwell_Calc subroutine
    0x37B8,  # TOC1 ISR continuation
]

# ============================================================================
# HC11 VARIANT-DEPENDENT REGISTER MAP ($1000-$100D)
# ============================================================================
# The exact HC11 derivative in the VY V6 Delco P04 is UNCONFIRMED.
# A local DARC VT V6 SC disassembly, from a different ECU, names HC11FC0.
# We can't assume that applies to the VY V6.
#
# This table shows what each address means under each variant so the
# disassembly output can present ALL possibilities. By looking at HOW
# the code accesses these addresses (read-only? direction-register writes?
# bit-test patterns?) we can narrow down the actual chip.
#
# Registers at $100E-$103F are IDENTICAL across all HC11 variants.
# ============================================================================
HC11_VARIANT_REGISTERS = {
    # addr: { variant: (name, description) }
    0x1000: {
        "HC11E": ("PORTA",  "Port A data (PA7-PA0)"),
        "HC11F": ("PORTA",  "Port A data (PA7-PA0)"),
        "HC11G": ("PORTA",  "Port A data (PA7-PA0)"),
        "HC11K": ("PORTA",  "Port A data (PA7-PA0)"),
    },
    0x1001: {
        "HC11E": ("---",    "Reserved (no DDRA on E-series)"),
        "HC11F": ("DDRA",   "Port A Data Direction Register"),
        "HC11G": ("DDRA",   "Port A Data Direction Register"),
        "HC11K": ("DDRA",   "Port A Data Direction Register"),
    },
    0x1002: {
        "HC11E": ("PIOC",   "Parallel I/O Control (STAF,STAI,CWOM,HNDS,OIN,PLS,EGA,INVB)"),
        "HC11F": ("PORTG",  "Port G data (candidate bank select: bit 6 = A16)"),
        "HC11G": ("PIOC",   "Parallel I/O Control"),
        "HC11K": ("PORTG",  "Port G data"),
    },
    0x1003: {
        "HC11E": ("PORTC",  "Port C data (directly readable)"),
        "HC11F": ("DDRG",   "Port G Data Direction Register"),
        "HC11G": ("PORTC",  "Port C data"),
        "HC11K": ("DDRG",   "Port G Data Direction Register"),
    },
    0x1004: {
        "HC11E": ("PORTB",  "Port B data (output-only on E)"),
        "HC11F": ("PORTB",  "Port B data"),
        "HC11G": ("PORTB",  "Port B data"),
        "HC11K": ("PORTB",  "Port B data"),
    },
    0x1005: {
        "HC11E": ("PORTCL", "Port C Latched data"),
        "HC11F": ("PORTF",  "Port F data (extra port on F-series)"),
        "HC11G": ("PORTCL", "Port C Latched data"),
        "HC11K": ("PORTF",  "Port F data"),
    },
    0x1006: {
        "HC11E": ("---",    "Reserved"),
        "HC11F": ("PORTC",  "Port C data (shifted from $1003)"),
        "HC11G": ("---",    "Reserved"),
        "HC11K": ("PORTC",  "Port C data"),
    },
    0x1007: {
        "HC11E": ("DDRC",   "Port C Data Direction Register"),
        "HC11F": ("DDRC",   "Port C Data Direction Register"),
        "HC11G": ("DDRC",   "Port C Data Direction Register"),
        "HC11K": ("DDRC",   "Port C Data Direction Register"),
    },
    0x1008: {
        "HC11E": ("PORTD",  "Port D data (PD5-PD0, bits 7:6 unused)"),
        "HC11F": ("PORTD",  "Port D data"),
        "HC11G": ("PORTD",  "Port D data"),
        "HC11K": ("PORTD",  "Port D data"),
    },
    0x1009: {
        "HC11E": ("DDRD",   "Port D Data Direction Register"),
        "HC11F": ("DDRD",   "Port D Data Direction Register"),
        "HC11G": ("DDRD",   "Port D Data Direction Register"),
        "HC11K": ("DDRD",   "Port D Data Direction Register"),
    },
    0x100A: {
        "HC11E": ("PORTE",  "Port E data (ADC inputs, read-only)"),
        "HC11F": ("PORTE",  "Port E data (ADC inputs)"),
        "HC11G": ("PORTE",  "Port E data (ADC inputs)"),
        "HC11K": ("PORTE",  "Port E data (ADC inputs)"),
    },
    0x100B: {
        "HC11E": ("CFORC",  "Timer Compare Force Register"),
        "HC11F": ("CFORC",  "Timer Compare Force Register"),
        "HC11G": ("CFORC",  "Timer Compare Force Register"),
        "HC11K": ("CFORC",  "Timer Compare Force Register"),
    },
    0x100C: {
        "HC11E": ("OC1M",   "OC1 Action Mask Register"),
        "HC11F": ("OC1M",   "OC1 Action Mask Register"),
        "HC11G": ("OC1M",   "OC1 Action Mask Register"),
        "HC11K": ("OC1M",   "OC1 Action Mask Register"),
    },
    0x100D: {
        "HC11E": ("OC1D",   "OC1 Action Data Register"),
        "HC11F": ("OC1D",   "OC1 Action Data Register"),
        "HC11G": ("OC1D",   "OC1 Action Data Register"),
        "HC11K": ("OC1D",   "OC1 Action Data Register"),
    },
}

# Registers at $100E+ that are IDENTICAL across ALL HC11 variants
HC11_COMMON_REGISTERS = {
    0x100E: ("TCNT_H",  "Free-running Timer Counter (high byte)"),
    0x100F: ("TCNT_L",  "Free-running Timer Counter (low byte)"),
    0x1010: ("TIC1_H",  "Input Capture 1 (high)"),
    0x1011: ("TIC1_L",  "Input Capture 1 (low)"),
    0x1012: ("TIC2_H",  "Input Capture 2 (high)"),
    0x1013: ("TIC2_L",  "Input Capture 2 (low)"),
    0x1014: ("TIC3_H",  "Input Capture 3 - candidate 24X crank input (high)"),
    0x1015: ("TIC3_L",  "Input Capture 3 - candidate 24X crank input (low)"),
    0x1016: ("TOC1_H",  "Output Compare 1 (high)"),
    0x1017: ("TOC1_L",  "Output Compare 1 (low)"),
    0x1018: ("TOC2_H",  "Output Compare 2 (high)"),
    0x1019: ("TOC2_L",  "Output Compare 2 (low)"),
    0x101A: ("TOC3_H",  "Output Compare 3 - candidate EST output (high)"),
    0x101B: ("TOC3_L",  "Output Compare 3 - candidate EST output (low)"),
    0x101C: ("TOC4_H",  "Output Compare 4 (high)"),
    0x101D: ("TOC4_L",  "Output Compare 4 (low)"),
    0x101E: ("TOC5_H",  "Output Compare 5 (high)"),
    0x101F: ("TOC5_L",  "Output Compare 5 (low)"),
    0x1020: ("TCTL1",   "Timer Control 1 (OC edge config / EST output mode)"),
    0x1021: ("TCTL2",   "Timer Control 2 (IC edge config)"),
    0x1022: ("TMSK1",   "Timer Interrupt Mask 1"),
    0x1023: ("TFLG1",   "Timer Interrupt Flag 1"),
    0x1024: ("TMSK2",   "Timer Interrupt Mask 2"),
    0x1025: ("TFLG2",   "Timer Interrupt Flag 2"),
    0x1026: ("PACTL",   "Pulse Accumulator Control"),
    0x1027: ("PACNT",   "Pulse Accumulator Count"),
    0x1028: ("SPCR",    "SPI Control Register"),
    0x1029: ("SPSR",    "SPI Status Register"),
    0x102A: ("SPDR",    "SPI Data Register"),
    0x102B: ("BAUD",    "SCI Baud Rate"),
    0x102C: ("SCCR1",   "SCI Control Register 1"),
    0x102D: ("SCCR2",   "SCI Control Register 2"),
    0x102E: ("SCSR",    "SCI Status Register"),
    0x102F: ("SCDR",    "SCI Data Register"),
    0x1030: ("ADCTL",   "ADC Control/Status"),
    0x1031: ("ADR1",    "ADC Result 1"),
    0x1032: ("ADR2",    "ADC Result 2"),
    0x1033: ("ADR3",    "ADC Result 3"),
    0x1034: ("ADR4",    "ADC Result 4"),
    0x1035: ("BPROT",   "Block Protect"),
    0x1039: ("OPTION",  "System Configuration Options"),
    0x103A: ("COPRST",  "COP Reset Register"),
    0x103B: ("PPROG",   "EEPROM Programming"),
    0x103C: ("HPRIO",   "Highest Priority I-Bit"),
    0x103D: ("INIT",    "RAM/IO Mapping Register"),
    0x103F: ("CONFIG",  "System Configuration Register"),
}


def get_register_comment(addr):
    """Get register annotation for an address in the $1000-$105F range.
    
    For $1000-$100D (variant-dependent), returns ALL variant interpretations.
    For $100E+ (common), returns the single known register name.
    Returns empty string if address is not a register.
    """
    if addr in HC11_VARIANT_REGISTERS:
        variants = HC11_VARIANT_REGISTERS[addr]
        # Check if all variants agree (e.g. PORTA at $1000)
        names = set(v[0] for v in variants.values() if v[0] != "---")
        if len(names) == 1:
            name = names.pop()
            desc = next(v[1] for v in variants.values() if v[0] != "---")
            return f" ; [HW] {name} - {desc}"
        else:
            parts = []
            for var in ["HC11E", "HC11F", "HC11G", "HC11K"]:
                name, desc = variants[var]
                parts.append(f"{var}={name}")
            return f" ; [HW?] {' | '.join(parts)}"
    
    if addr in HC11_COMMON_REGISTERS:
        name, desc = HC11_COMMON_REGISTERS[addr]
        return f" ; [HW] {name} - {desc}"
    
    return ""


def read_bin(filepath):
    """Read an exact 128 KiB source image."""
    data = Path(filepath).read_bytes()
    if len(data) != SOURCE_SIZE:
        raise ValueError(
            f"{filepath} is 0x{len(data):X} bytes; expected exactly 0x{SOURCE_SIZE:X}"
        )
    return data


def artifact_name(path):
    """Return a stable filesystem-safe label derived from an input filename."""
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", Path(path).stem).strip("._")
    return name or "image"


def split_bin(data, name, output_dir):
    """Split a 128KB binary into 3 bank files."""
    bank_files = []
    for bank_name, start, end, cpu_base in BANKS:
        bank_data = data[start:end]
        out_path = output_dir / f"{name}_{bank_name}.bin"
        with open(out_path, "wb") as f:
            f.write(bank_data)
        bank_files.append((bank_name, out_path, bank_data, cpu_base))
        print(f"  {bank_name}: {out_path.name} ({len(bank_data)} bytes, CPU ${cpu_base:04X}-${cpu_base + len(bank_data) - 1:04X})")
    return bank_files


def extract_vectors(bank1_data):
    """Extract interrupt vector table from bank 1 data."""
    lines = []
    lines.append("\n; === HC11 Interrupt Vector Table ($FFD6-$FFFF) ===")
    for addr in sorted(VECTORS.keys()):
        offset = addr  # bank1 is loaded at CPU $0000, so offset = addr
        if offset + 1 < len(bank1_data):
            vec_hi = bank1_data[offset]
            vec_lo = bank1_data[offset + 1]
            vec_target = (vec_hi << 8) | vec_lo
            label = VECTORS[addr]
            lines.append(f"; ${addr:04X}: {label:20s} -> ${vec_target:04X}")
    return "\n".join(lines)


def format_vector_entry(bank_data, cpu_base, address):
    """Format one HC11 vector as a big-endian 16-bit handler address."""
    offset = address - cpu_base
    if offset < 0 or offset + 1 >= len(bank_data):
        raise ValueError(f"vector ${address:04X} is outside the supplied bank")
    hi = bank_data[offset]
    lo = bank_data[offset + 1]
    target = (hi << 8) | lo
    raw = f"{hi:02X} {lo:02X}"
    return (
        f"L{address:04X}:  {raw:15s}  .word    "
        f"${target:04X}            ; -> {VECTORS[address]} handler\n"
    )


def _extract_operand_addr(op_str):
    """Try to extract a 16-bit address from a Capstone operand string.
    Returns the integer address or None.
    Examples:  '$1020' -> 0x1020,  '$00, $1022' -> 0x1022,  '$04, x' -> None
    """
    import re
    # Find all $XXXX patterns (4-digit hex = extended addressing)
    for m in re.finditer(r'\$([0-9A-Fa-f]{4})\b', op_str):
        val = int(m.group(1), 16)
        if 0x1000 <= val <= 0x105F:
            return val
    return None


def disassemble_bank(bank_data, cpu_base, bank_name, name, output_dir):
    """Disassemble a bank using Capstone HC11 with recursive descent.

    For bank1, $2000-$5FFF contains BOTH code and data intermixed.
    Uses recursive descent from ISR entry points + JSR/JMP targets
    found in $6000+ code to separate code from calibration data.
    """
    from capstone import Cs, CS_ARCH_M680X, CS_MODE_M680X_6811

    md = Cs(CS_ARCH_M680X, CS_MODE_M680X_6811)
    md.detail = True

    out_path = output_dir / f"{name}_{bank_name}.asm"
    bank_size = len(bank_data)

    # Track register accesses for variant analysis summary
    # reg_hits[addr] = [(cpu_addr, mnemonic, op_str), ...]
    reg_hits = {}

    # Phase 1: Recursive descent for bank1 mixed region
    insn_map = {}       # addr -> (mnemonic, op_str, raw_hex, size)
    if bank_name == "bank1":
        seed_addrs = set()

        # Parse JMP table at $2000-$202F (16 x 3-byte JMP $XXXX)
        for i in range(0x2000, 0x2030, 3):
            off = i - cpu_base
            if off + 2 < bank_size and bank_data[off] == 0x7E:
                tgt = (bank_data[off + 1] << 8) | bank_data[off + 2]
                seed_addrs.add(i)
                if 0x2000 <= tgt < 0x6000:
                    seed_addrs.add(tgt)

        # Scan $6000+ code for JSR/JMP into $2000-$5FFF
        md_scan = Cs(CS_ARCH_M680X, CS_MODE_M680X_6811)
        md_scan.detail = False
        for insn in md_scan.disasm(bank_data[0x6000:], cpu_base + 0x6000):
            mn = insn.mnemonic.lower()
            if mn in ('jsr', 'jmp'):
                op = insn.op_str.strip()
                if op.startswith('$'):
                    try:
                        t = int(op[1:], 16)
                        if 0x2000 <= t < 0x6000:
                            seed_addrs.add(t)
                    except ValueError:
                        pass

        # Also scan bank2 and bank3 for JSR/JMP into $2000-$5FFF
        # (they share this region via bank switching)
        for bname, bstart, bend, bbase in BANKS[1:]:
            bpath = output_dir / f"{name}_{bname}.bin"
            if bpath.exists():
                bdata = bpath.read_bytes()
                for insn in md_scan.disasm(bdata, bbase):
                    mn = insn.mnemonic.lower()
                    if mn in ('jsr', 'jmp'):
                        op = insn.op_str.strip()
                        if op.startswith('$'):
                            try:
                                t = int(op[1:], 16)
                                if 0x2000 <= t < 0x6000:
                                    seed_addrs.add(t)
                            except ValueError:
                                pass

        branch_ops = {
            'bra', 'brn', 'bhi', 'bls', 'bcc', 'bcs', 'bne', 'beq',
            'bvc', 'bvs', 'bpl', 'bmi', 'bge', 'blt', 'bgt', 'ble',
            'jmp', 'jsr', 'bsr', 'brclr', 'brset',
        }
        terminators = {'rts', 'rti', 'jmp', 'bra', 'swi', 'wai', 'stop'}

        # Add manually identified code entry points
        seed_addrs.update(EXTRA_CODE_SEEDS)

        # Also scan for JMP $XXXX tables in $2000-$5FFF data
        # Pattern: consecutive 16-bit addresses pointing to $2000-$5FFF
        for i in range(0x2000, 0x5FFE, 2):
            off = i - cpu_base
            hi = bank_data[off]
            lo = bank_data[off + 1]
            tgt = (hi << 8) | lo
            if 0x2030 <= tgt < 0x5FFF:
                # Check if surrounding words also look like valid addresses
                # (heuristic: at least 2 consecutive valid-looking pointers)
                if off + 3 < bank_size:
                    hi2 = bank_data[off + 2]
                    lo2 = bank_data[off + 3]
                    tgt2 = (hi2 << 8) | lo2
                    if 0x2030 <= tgt2 < 0x5FFF:
                        seed_addrs.add(tgt)
                        seed_addrs.add(tgt2)

        work = list(seed_addrs)
        visited = set()

        while work:
            addr = work.pop()
            if addr in visited:
                continue
            if not (0x2000 <= addr < 0x6000):
                continue
            visited.add(addr)

            off = addr - cpu_base
            if off < 0 or off >= bank_size:
                continue

            for insn in md.disasm(bank_data[off:], addr):
                if insn.address in insn_map:
                    break
                if insn.address >= 0x6000:
                    break

                raw = " ".join(f"{b:02X}" for b in insn.bytes)
                insn_map[insn.address] = (
                    insn.mnemonic, insn.op_str, raw, insn.size
                )
                mn = insn.mnemonic.lower()
                if mn in branch_ops:
                    op = insn.op_str.strip()
                    tgt = None
                    if op.startswith('$'):
                        try:
                            tgt = int(op[1:], 16)
                        except ValueError:
                            pass
                    elif ', ' in op:
                        parts = op.split(',')
                        last = parts[-1].strip()
                        if last.startswith('$'):
                            try:
                                tgt = int(last[1:], 16)
                            except ValueError:
                                pass
                    if tgt and 0x2000 <= tgt < 0x6000:
                        if tgt not in visited:
                            work.append(tgt)

                if mn in terminators:
                    break

        print(f"      Recursive descent: {len(insn_map)} instructions in $2000-$5FFF from {len(seed_addrs)} seeds")

    # Phase 2: Write output
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(f"; {name} {bank_name} Disassembly\n")
        f.write("; Generated by split_and_disassemble.py\n")
        bid = ['bank1', 'bank2', 'bank3'].index(bank_name)
        f.write(f"; CPU Base: ${cpu_base:04X}  Size: {bank_size} bytes ({bank_size // 1024}KB)\n")
        f.write(f"; Bin offset: ${BANKS[bid][1]:05X}\n")
        f.write(";\n")

        if bank_name == "bank1":
            f.write(extract_vectors(bank_data))
            f.write("\n;\n")

        f.write(f"\n        .org    ${cpu_base:04X}\n\n")

        insn_count = 0
        data_bytes = 0
        vector_count = 0

        def emit_data_line(f, addr, chunk):
            hs = ", ".join(f"${b:02X}" for b in chunk)
            asc = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
            lbl = f"  ; << {KNOWN_LABELS[addr]}" if addr in KNOWN_LABELS else ""
            f.write(f"L{addr:04X}:  .byte   {hs:48s} ; |{asc}|{lbl}\n")
            return len(chunk)

        if bank_name == "bank1":
            # $0000-$1FFF: pure data (RAM/header)
            f.write("; --- Data region $0000-$1FFF (8192 bytes) ---\n")
            for i in range(0x0000, 0x2000, 16):
                data_bytes += emit_data_line(f, cpu_base + i, bank_data[i:i+16])

            # $2000-$5FFF: mixed code/data
            f.write("\n\n; === Mixed Code/Data region $2000-$5FFF ===\n")
            f.write(f"; {len(insn_map)} code instructions found via recursive descent\n\n")

            addr = 0x2000
            pend = bytearray()
            pend_start = None

            while addr < 0x6000:
                if addr in insn_map:
                    # Flush pending data bytes
                    if pend:
                        for j in range(0, len(pend), 16):
                            data_bytes += emit_data_line(f, pend_start + j, pend[j:j+16])
                        pend = bytearray()
                        pend_start = None
                        f.write("\n")

                    mn, op, raw, sz = insn_map[addr]
                    if addr in KNOWN_LABELS:
                        f.write(f"\n; --- {KNOWN_LABELS[addr]} ---\n")
                    reg_addr = _extract_operand_addr(op)
                    reg_comment = get_register_comment(reg_addr) if reg_addr else ""
                    if reg_addr and reg_addr in HC11_VARIANT_REGISTERS:
                        reg_hits.setdefault(reg_addr, []).append((addr, mn, op))
                    f.write(f"L{addr:04X}:  {raw:15s}  {mn:8s} {op}{reg_comment}\n")
                    insn_count += 1
                    addr += sz
                else:
                    if pend_start is None:
                        pend_start = addr
                    pend.append(bank_data[addr - cpu_base])
                    addr += 1

            if pend:
                for j in range(0, len(pend), 16):
                    data_bytes += emit_data_line(f, pend_start + j, pend[j:j+16])

            code_start = 0x6000
        else:
            code_start = 0

        # Linear sweep for remaining code. Stop at $FFD6 so vector words are
        # never decoded as ordinary instructions.
        vector_start = 0xFFD6  # First vector address
        code_end_offset = vector_start - cpu_base
        code_data = bank_data[code_start:code_end_offset]
        code_base = cpu_base + code_start

        f.write(f"\n\n; === Code region ${code_base:04X}-${cpu_base + bank_size - 1:04X} ===\n\n")

        for insn in md.disasm(code_data, code_base):
            if insn.address in KNOWN_LABELS:
                f.write(f"\n; --- {KNOWN_LABELS[insn.address]} ---\n")
            if insn.address in VECTORS:
                f.write(f"\n; --- Vector: {VECTORS[insn.address]} ---\n")

            raw_bytes = " ".join(f"{b:02X}" for b in insn.bytes)
            reg_addr = _extract_operand_addr(insn.op_str)
            reg_comment = get_register_comment(reg_addr) if reg_addr else ""
            if reg_addr and reg_addr in HC11_VARIANT_REGISTERS:
                reg_hits.setdefault(reg_addr, []).append(
                    (insn.address, insn.mnemonic, insn.op_str))
            f.write(f"L{insn.address:04X}:  {raw_bytes:15s}  {insn.mnemonic:8s} {insn.op_str}{reg_comment}\n")
            insn_count += 1

        f.write(f"\n; === Interrupt Vector Table ${vector_start:04X}-$FFFF ===\n")
        f.write("; These are 16-bit handler addresses, not instructions.\n\n")
        for vec_addr in sorted(VECTORS.keys()):
            if vec_addr < vector_start:
                continue
            offset = vec_addr - cpu_base
            if offset + 1 < bank_size:
                vec_name = VECTORS[vec_addr]
                f.write(f"\n; --- Vector: {vec_name} ---\n")
                f.write(format_vector_entry(bank_data, cpu_base, vec_addr))
                vector_count += 1

        # === Register Variant Analysis Summary ===
        f.write(f"\n; {'=' * 72}\n")
        f.write("; HC11 VARIANT-DEPENDENT REGISTER ACCESS SUMMARY\n")
        f.write(f"; {'=' * 72}\n")
        f.write("; Addresses $1000-$100D differ between HC11E/F/G/K variants.\n")
        f.write("; Below are ALL accesses to variant-dependent registers found\n")
        f.write("; in this bank. Use the access patterns (read/write, bit-test\n")
        f.write("; masks, direction-register writes) to determine the actual chip.\n")
        f.write(";\n")
        if not reg_hits:
            f.write("; (no variant-dependent register accesses found in this bank)\n")
        else:
            for reg_addr in sorted(reg_hits.keys()):
                variants = HC11_VARIANT_REGISTERS[reg_addr]
                f.write(";\n")
                f.write(f"; --- ${reg_addr:04X} ---\n")
                for var in ["HC11E", "HC11F", "HC11G", "HC11K"]:
                    vname, vdesc = variants[var]
                    f.write(f";   {var}: {vname:8s} - {vdesc}\n")
                f.write(f";   Accesses ({len(reg_hits[reg_addr])}):\n")
                for cpu_addr, mn, op in reg_hits[reg_addr][:20]:
                    f.write(f";     ${cpu_addr:04X}: {mn:8s} {op}\n")
                if len(reg_hits[reg_addr]) > 20:
                    f.write(f";     ... and {len(reg_hits[reg_addr]) - 20} more\n")
        f.write(f"; {'=' * 72}\n")

        f.write("\n; === Summary ===\n")
        f.write(f"; Instructions disassembled: {insn_count}\n")
        f.write(f"; Vectors emitted: {vector_count}\n")
        f.write(f"; Data bytes emitted: {data_bytes}\n")
        if bank_name == "bank1":
            f.write(f"; Code instructions in $2000-$5FFF: {len(insn_map)}\n")
        f.write(f"; Bank size: {bank_size} bytes\n")

    print(f"    -> {out_path.name}: {insn_count} instructions, {data_bytes} data bytes")
    return out_path


def diff_banks(stock_data, enhanced_data, bank_name, cpu_base, output_dir, stock_name, enh_name):
    """Diff two bank binaries and report changes."""
    if len(stock_data) != len(enhanced_data):
        print(f"  WARNING: Size mismatch in {bank_name}: {len(stock_data)} vs {len(enhanced_data)}")
        return

    diffs = []
    run_start = None
    run_stock = bytearray()
    run_enh = bytearray()

    for i in range(len(stock_data)):
        if stock_data[i] != enhanced_data[i]:
            if run_start is None:
                run_start = i
                run_stock = bytearray()
                run_enh = bytearray()
            run_stock.append(stock_data[i])
            run_enh.append(enhanced_data[i])
        else:
            if run_start is not None:
                diffs.append((run_start, bytes(run_stock), bytes(run_enh)))
                run_start = None

    if run_start is not None:
        diffs.append((run_start, bytes(run_stock), bytes(run_enh)))

    out_path = output_dir / f"diff_{stock_name}_vs_{enh_name}_{bank_name}.txt"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(f"Binary Diff: {stock_name} vs {enh_name} - {bank_name}\n")
        f.write(f"{'=' * 70}\n")
        f.write(f"Bank CPU base: ${cpu_base:04X}\n")
        f.write(f"Total differences: {len(diffs)} regions, {sum(len(s) for _, s, _ in diffs)} bytes changed\n\n")

        # Classify changes by region
        cal_changes = 0
        code_changes = 0
        eeprom_changes = 0

        for offset, stock_bytes, enh_bytes in diffs:
            addr = cpu_base + offset
            region = "CODE"
            if bank_name == "bank1":
                if 0x0E00 <= addr <= 0x0FFF:
                    region = "EEPROM"
                    eeprom_changes += len(stock_bytes)
                elif 0x2000 <= addr <= 0x5FFF:
                    region = "CAL"
                    cal_changes += len(stock_bytes)
                elif addr < 0x2000:
                    region = "LOW"
                else:
                    code_changes += len(stock_bytes)
            else:
                code_changes += len(stock_bytes)

            label = KNOWN_LABELS.get(addr, "")
            label_str = f"  ({label})" if label else ""

            f.write(f"[{region}] ${addr:04X}-${addr + len(stock_bytes) - 1:04X} ({len(stock_bytes)} bytes){label_str}\n")

            # Show bytes (up to 32 per diff region)
            show_count = min(len(stock_bytes), 32)
            stock_hex = " ".join(f"{b:02X}" for b in stock_bytes[:show_count])
            enh_hex = " ".join(f"{b:02X}" for b in enh_bytes[:show_count])
            if len(stock_bytes) > 32:
                stock_hex += f" ... (+{len(stock_bytes) - 32} more)"
                enh_hex += f" ... (+{len(enh_bytes) - 32} more)"
            f.write(f"  STOCK:    {stock_hex}\n")
            f.write(f"  ENHANCED: {enh_hex}\n\n")

        f.write(f"\n{'=' * 70}\n")
        f.write(f"Summary for {bank_name}:\n")
        if bank_name == "bank1":
            f.write(f"  CAL region changes:    {cal_changes} bytes\n")
            f.write(f"  EEPROM changes:        {eeprom_changes} bytes\n")
            f.write(f"  Code region changes:   {code_changes} bytes\n")
        else:
            f.write(f"  Code/table changes:    {code_changes} bytes\n")
        f.write(f"  Total changed regions: {len(diffs)}\n")
        f.write(f"  Total changed bytes:   {sum(len(s) for _, s, _ in diffs)}\n")

    print(
        f"    -> {out_path.name}: {len(diffs)} regions, "
        f"{sum(len(s) for _, s, _ in diffs)} bytes changed"
    )
    if bank_name == "bank1":
        print(f"       CAL: {cal_changes}B, EEPROM: {eeprom_changes}B, CODE: {code_changes}B")
    return out_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "bins",
        nargs="+",
        type=Path,
        help="one or more exact 128 KiB VY images",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("bank_split_output"),
        help="generated-output directory (default: bank_split_output)",
    )
    parser.add_argument(
        "--split-only",
        action="store_true",
        help="split banks without running the heuristic disassembler",
    )
    parser.add_argument(
        "--diff-against",
        type=Path,
        metavar="BASE.bin",
        help="compare every input image with this exact 128 KiB base image",
    )
    args = parser.parse_args()

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    labels = [artifact_name(path) for path in args.bins]
    if len(labels) != len(set(labels)):
        parser.error("input filenames collapse to duplicate output labels")

    try:
        inputs = [
            (label, path, read_bin(path))
            for label, path in zip(labels, args.bins)
        ]
        base = read_bin(args.diff_against) if args.diff_against else None
    except (OSError, ValueError) as exc:
        parser.error(str(exc))

    generated = []

    # Phase 1: Split
    print("=" * 60)
    print("PHASE 1: Split 128KB binaries into banks")
    print("=" * 60)

    all_banks = {}
    for name, path, data in inputs:
        print(f"\n  {name}: {path}")
        bank_files = split_bin(data, name, output_dir)
        all_banks[name] = bank_files
        generated.extend(item[1] for item in bank_files)

    # Phase 2: Disassemble
    if not args.split_only:
        print(f"\n{'=' * 60}")
        print("PHASE 2: Heuristically disassemble each bank (Capstone HC11)")
        print("=" * 60)

        for name, bank_files in all_banks.items():
            print(f"\n  {name}:")
            for bank_name, _path, bank_data, cpu_base in bank_files:
                generated.append(
                    disassemble_bank(
                        bank_data,
                        cpu_base,
                        bank_name,
                        name,
                        output_dir,
                    )
                )

    # Phase 3: Diff
    if base is not None:
        print(f"\n{'=' * 60}")
        print(f"PHASE 3: Diff {args.diff_against} vs input images")
        print("=" * 60)

        base_name = artifact_name(args.diff_against)
        base_banks = {
            bank_name: base[start:end]
            for bank_name, start, end, _cpu_base in BANKS
        }
        for name, bank_files in all_banks.items():
            print(f"\n  {base_name} vs {name}:")
            for bank_name, _path, image_data, cpu_base in bank_files:
                generated.append(
                    diff_banks(
                        base_banks[bank_name],
                        image_data,
                        bank_name,
                        cpu_base,
                        output_dir,
                        base_name,
                        name,
                    )
                )

    # Summary
    print(f"\n{'=' * 60}")
    print(f"Output directory: {output_dir.resolve()}")
    print(f"Files generated: {len(generated)}")
    for path in sorted(generated):
        size_kb = path.stat().st_size / 1024
        print(f"  {path.name} ({size_kb:.1f} KB)")
    print("=" * 60)


if __name__ == "__main__":
    main()
