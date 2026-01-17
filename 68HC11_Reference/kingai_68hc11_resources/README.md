# 68HC11 Reference Collection

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: 68HC11](https://img.shields.io/badge/Platform-68HC11-blue.svg)](https://en.wikipedia.org/wiki/Motorola_68HC11)
[![Target: VY V6 ECU](https://img.shields.io/badge/Target-Holden%20VY%20V6-green.svg)](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches)

> **Purpose:** Complete reference materials for reverse-engineering the Holden VY V6 Commodore ECU (Delco $060A, OSID 92118883)
> 
> **Author:** Jason King (kingaustraliagg) | **Last Updated:** January 18, 2026
>
> I assembled these resources to help identify opcodes, understand addressing modes, and properly disassemble/patch the 68HC11-based Delco ECU firmware.

> **📦 GitHub Push Status:** This folder (`kingai_68hc11_resources/`) is scheduled to be pushed to the main repository. See [DOCUMENT_CONSOLIDATION_PLAN.md](../../DOCUMENT_CONSOLIDATION_PLAN.md) for full details.

---

## 🎯 What This Collection Is For

This is a **curated toolkit** for anyone working on:
- Disassembling Holden VN-VY V6 ECU binaries
- Writing assembly patches for the 68HC11 processor
- Understanding Delco/Delphi ECU architecture
- Ghidra/IDA analysis of automotive firmware

**Target ECU:** Delco $060A (OSID 92118883) - Holden VY V6 L36 3.8L Ecotec (enhanced version off pcmhacking.net with lpg patched out)

---

## 📚 Quick Reference Links

| Document | Description | Use For |
|----------|-------------|---------|
| [68HC11_COMPLETE_INSTRUCTION_REFERENCE.md](./68HC11_COMPLETE_INSTRUCTION_REFERENCE.md) | Full instruction set with opcodes, cycles, addressing modes | Primary reference when writing patches |
| [68HC11_Opcodes_Reference.md](./68HC11_Opcodes_Reference.md) | Hex opcode lookup tables by category | Quick opcode → mnemonic lookup |
| [68HC11_Mnemonics_Reference.md](./68HC11_Mnemonics_Reference.md) | Mnemonic → opcode tables with all addressing modes | When you know the instruction, need the bytes |
| [68HC11_Descriptions_Reference.md](./68HC11_Descriptions_Reference.md) | Human-readable instruction descriptions | Understanding what each instruction does |
| [68HC11_Disassembler_Logic_Reference.md](./68HC11_Disassembler_Logic_Reference.md) | How dis68hc11 works + VY-specific addresses | Modifying disassemblers for ECU work |
| [68HC11 Instructions.doc](../68HC11%20Instructions.doc) | Original Motorola instruction reference | Official source document |
| [M68HC11RM_Reference_Manual.pdf](../M68HC11RM_Reference_Manual.pdf) | Official Motorola HC11 Reference Manual | Authoritative hardware/timer docs |

---

## 🛠️ Tools Directory

### Assemblers

| Tool | Directory | Description | Best For |
|------|-----------|-------------|----------|
| **A09** | `../A09_Assembler/` | Full macro assembler for 6809/6811. Open source with VS project. | Assembling patches to S19/binary |
| **BASIC11** | `../BASIC11/` | BASIC interpreter source. Contains `common.inc`, `macros.inc`, `mcu.inc` | Reference include files |

### Disassemblers

| Tool | Directory | Description | Best For |
|------|-----------|-------------|----------|
| **dasmfw** | `../dasmfw/` | Multi-architecture framework (68HC11, 6800, 6809, 68000, AVR). Key files: `Dasm68HC11.cpp/h` | Bulk disassembly with labels |
| **dis68hc11** | `../dis68hc11/` | Simple C++ disassembler specifically for 68HC11 | Quick single-file disassembly |
| **gendasm** | `../gendasm/` | Generic Code-Seeking Disassembler with Fuzzy-Function Analyzer. Uses DNA alignment algorithm. | Finding similar code across binaries |
| **dis12** | `../dis12_HC12_disasm/` | 68HC12 disassembler (HC11 evolution) | Reference for HC12 ECUs |

### Compilers & Development

| Tool | Directory | Description |
|------|-----------|-------------|
| **GCC HC11** | `../GCC_HC11/` | GNU cross-compiler for 68HC11 (C to assembly) |
| **HC11_Tools** | `../HC11_Tools/` | Miscellaneous development utilities |
| **Mini11** | `../Mini11/` | Minimal HC11 development kit |

### Simulators & Emulators

| Tool | Directory | Description |
|------|-----------|-------------|
| **EVBU Simulator** | `../EVBU_Simulator/` | Python-based 68HC11/Buffalo monitor simulator for testing code |
| **68HC11 Simulator** | `../68HC11-simulator/` | Additional HC11 simulation tools |

### Ghidra Integration

| File | Directory | Description |
|------|-----------|-------------|
| **HC11.slaspec** | `../ghidra_hc11/` | SLEIGH specification - defines all HC11 instructions |
| **HC11.ldefs** | `../ghidra_hc11/` | Language definitions for Ghidra |
| **HC11.pspec** | `../ghidra_hc11/` | Processor specification |
| **HC11.cspec** | `../ghidra_hc11/` | Compiler specification |
| **HC11.sla** | `../ghidra_hc11/` | Pre-compiled SLEIGH (ready to use) |

**Ghidra Setup:**
```bash
# Copy to your Ghidra installation
cp ../ghidra_hc11/* /path/to/Ghidra/Processors/68HC11/data/languages/
```

---

## 🔧 Key Files for VY V6 ECU Work

### Essential Reading Order
1. **68HC11_COMPLETE_INSTRUCTION_REFERENCE.md** - Start here for all opcodes
2. **68HC11_Opcodes_Reference.md** - Quick hex lookup when reading disassembly
3. **../dasmfw/Dasm68HC11.cpp** - How opcodes are decoded (learn the patterns)
4. **../gendasm/src/gendasm/cpu/m6811/** - Advanced techniques for code recovery

### Include Files (for writing patches)
```asm
; These are useful starting points for patch assembly
INCLUDE "../BASIC11/common.inc"   ; Common definitions
INCLUDE "../BASIC11/macros.inc"   ; Useful macros  
INCLUDE "../BASIC11/mcu.inc"      ; MCU register definitions ($1000-$103F)
```

---

## 📍 68HC11 Memory Map

### Standard HC11 Layout
| Address Range | Size | Description |
|---------------|------|-------------|
| `$0000-$00FF` | 256 | RAM (Direct Page - fast access) |
| `$0100-$01FF` | 256 | RAM (Stack default area) |
| `$1000-$103F` | 64 | **I/O Registers** (Timer, ADC, SCI, SPI) |
| `$B600-$B7FF` | 512 | Internal EEPROM |
| `$C000-$FFFF` | 16K | External ROM/EPROM |
| `$FFD6-$FFFF` | 42 | **Interrupt Vectors** |

### VY V6 ECU Specific (Delco $060A Enhanced v1.0a/v2.09a)
| Address Range | Size | Description |
|---------------|------|-------------|
| `$0000-$01FF` | 512 | RAM (Direct + Stack) |
| `$0200-$03FF` | 512 | RAM (Extended) |
| `$1000-$103F` | 64 | I/O Registers (Timer, ADC, SCI, SPI) |
| `$8000-$FFFF` | 32K | External EPROM window (128KB with bank switching) |

### ✅ VERIFIED FREE SPACE (File Offsets, NOT HC11 Addresses)
| File Offset Range | Size | Description |
|-------------------|------|-------------|
| `0x0C468-0x0FFBF` | 15,192 bytes | All zeros - safe for patch code |
| `0x57AF-0x5F73` | 1,988 bytes | Former LPG tables (zeroed by The1) |

### Bank Switching Note
The VY V6 uses **128KB EPROM** with bank switching. File offsets ≠ CPU addresses!
```
File Offset = CPU Address - $8000  (for bank 0)
Example: CPU $C500 = File offset $4500
```

---

## Interrupt Vector Table

| Vector | Address | Description |
|--------|---------|-------------|
| RESET | $FFFE-$FFFF | Reset vector (entry point) |
| CMF | $FFFC-$FFFD | Clock Monitor Fail |
| COP | $FFFA-$FFFB | COP Watchdog |
| ILLOP | $FFF8-$FFF9 | Illegal Opcode |
| SWI | $FFF6-$FFF7 | Software Interrupt |
| XIRQ | $FFF4-$FFF5 | Non-maskable Interrupt |
| IRQ | $FFF2-$FFF3 | External Interrupt |
| RTI | $FFF0-$FFF1 | Real-Time Interrupt |
| TIC1 | $FFEE-$FFEF | Timer Input Capture 1 |
| TIC2 | $FFEC-$FFED | Timer Input Capture 2 |
| TIC3 | $FFEA-$FFEB | Timer Input Capture 3 |
| TOC1 | $FFE8-$FFE9 | Timer Output Compare 1 |
| TOC2 | $FFE6-$FFE7 | Timer Output Compare 2 |
| TOC3 | $FFE4-$FFE5 | Timer Output Compare 3 |
| TOC4 | $FFE2-$FFE3 | Timer Output Compare 4 |
| TOC5/TIC4 | $FFE0-$FFE1 | Timer Output Compare 5/Input Capture 4 |
| TOF | $FFDE-$FFDF | Timer Overflow |
| PAOV | $FFDC-$FFDD | Pulse Accumulator Overflow |
| PAIE | $FFDA-$FFDB | Pulse Accumulator Input Edge |
| SPI | $FFD8-$FFD9 | Serial Peripheral Interface |
| SCI | $FFD6-$FFD7 | Serial Communications Interface |

---

## Quick Opcode Reference

### Common Branch Instructions
| Opcode | Mnemonic | Condition |
|--------|----------|-----------|
| $20 | BRA | Always |
| $26 | BNE | Not Equal (Z=0) |
| $27 | BEQ | Equal (Z=1) |
| $24 | BCC/BHS | Carry Clear |
| $25 | BCS/BLO | Carry Set |
| $2A | BPL | Plus (N=0) |
| $2B | BMI | Minus (N=1) |
| $2C | BGE | Greater or Equal |
| $2D | BLT | Less Than |

### Common Load/Store
| Opcode | Mode | Mnemonic |
|--------|------|----------|
| $86 | IMM | LDAA #$xx |
| $96 | DIR | LDAA $xx |
| $B6 | EXT | LDAA $xxxx |
| $A6 | IND,X | LDAA $xx,X |
| $B7 | EXT | STAA $xxxx |
| $CC | IMM | LDD #$xxxx |
| $BD | EXT | JSR $xxxx |
| $7E | EXT | JMP $xxxx |
| $39 | INH | RTS |

### Prebyte Codes
| Prebyte | Used For |
|---------|----------|
| $18 | Y-register indexed instructions |
| $1A | CPD, LDY/STY with X-index |
| $CD | LDX/STX with Y-index, CPX with Y-index |

---

## Building Tools

### dasmfw (Disassembler Framework)
```bash
cd dasmfw
make
./dasmfw -dasm68hc11 -bin yourfile.bin -org 0xC000 > output.asm
```

### A09 Assembler
```bash
cd A09_Assembler
make
./a09 -o output.s19 source.asm
```

### gendasm
```bash
cd gendasm
mkdir build && cd build
cmake ..
make
./gendasm -m6811 input.bin
```

---

## Additional Reference Links

- [NXP M68HC11 Reference Manual](https://www.nxp.com/docs/en/reference-manual/M68HC11RM.pdf)
- [THRSim11 Simulator](http://www.hc11.demon.nl/thrsim11/thrsim11.htm)
- [Buffalo Monitor Reference](https://www.mil.ufl.edu/projects/gup/docs/buffalo.pdf)
- [AS6811 Assembler](https://shop-pdp.net/ashtml/as6811.htm)

---

## VY V6 ECU Specific Notes

The VY Commodore V6 ECU uses a Delco/Delphi architecture based on the 68HC11 processor. Key characteristics:

| Parameter | Value | Source |
|-----------|-------|--------|
| **OSID** | 92118883 | BIN header |
| **Calibration ID** | $060A | Delco mask ID |
| **Processor** | MC68HC11 (8-bit) | Motorola |
| **Memory Layout** | 128KB with bank switching | VY Enhanced |
| **Clock Speed** | 2MHz E-clock (8MHz crystal ÷4) | HC11 spec |
| **Comms Protocol** | ALDL (OBD1.5) 8192 baud | Factory |

### ✅ VERIFIED Addresses (Jan 2026 - Binary Confirmed)

| RAM Address | Name | Size | Description |
|-------------|------|------|-------------|
| `$00A2` | ENGINE_RPM | 1 byte | Current RPM (×25 scaling) |
| `$017B` | 3X_PERIOD | 2 bytes | Time between 3X cam pulses (µs) |
| `$0199` | DWELL_TIME | 2 bytes | Current dwell time (µs) |

| File Offset | Name | Stock Value | Description |
|-------------|------|-------------|-------------|
| `0x171AA` | MIN_DWELL | $00A2 (162) | Minimum dwell count |
| `0x19813` | MIN_BURN | $24 (36) | Minimum burn time count |
| `0x77DD-0x77E3` | FUEL_CUTOFF | Various | Fuel cut RPM thresholds |

### ✅ VERIFIED ISR Handlers

| Vector | Address | Handler | Description |
|--------|---------|---------|-------------|
| TIC3 | $FFEA | → $35FF | 3X Cam Reference ISR |
| TOC1 | $FFE8 | → $35B5 | Main timing ISR |
| IRQ | $FFF2 | → $2006 | External interrupt |
| RESET | $FFFE | → $C060 | Power-on entry |

### Timer Hardware Registers (HC11 Standard)

| Address | Register | VY V6 Usage |
|---------|----------|-------------|
| `$1014` | TIC3 | 3X Cam pulse capture |
| `$1012` | TIC2 | 24X Crank timing |
| `$1018` | TOC2 | Dwell control |
| `$101A` | TOC3 | EST spark output |
| `$1020` | TCTL1 | Output compare edge control |

### Common ECU Code Patterns

- **Lookup Tables**: 2D/3D tables for fuel, timing, etc.
- **Timer ISRs**: Engine timing using TOC/TIC
- **ADC Polling**: Sensor reading loops via SPI slave
- **Serial Comms**: SCI for ALDL diagnostics
- **Dwell Calc**: Subroutine at $371A calculates coil dwell

---

## Related Projects

- **Assembly Patches**: [asm_wip/](../../asm_wip/) - Spark cut, turbo, shift control patches
- **XDF Definitions**: v2.09a Enhanced XDF for TunerPro
- **PCMHacking Forum**: Topic 2518 "VS-VY Enhanced Factory Bins"
- **The1's Enhanced ROM**: LPG tables zeroed, extended MAF/Spark tables

---

## Contribution Guidelines

If anything is wrong please fix it... so the patches can be applied with no second thoughts.
please some one just export the whole 128kb .asm or .c for me please with a hc11 processor to make my life easier. 

i was kind enough to share this to github, people calling this ai slop obviously dont understand what we are doing here and need to do there research before commenting on forums and facebook/discord posts/chats with crapgpt comments.

instead channel that rage into this project and be useful if you have a cup with more than mine and something to offer than stolen/fake tunes and using other peoples tools you didnt build yourself. 

now is your chance to redeem karma here and prove yourself worthy of being a real holden pcm hacker.

---

Assembled for VY V6 ECU decompilation project
