# VY V6 ECU Memory Map & Mnemonic Reference

> **📢 PUBLIC DOCUMENT** - This file is published on GitHub for community reference.

> **Created:** January 20, 2026  
> **Purpose:** Document bank switching, memory layout, and non-standard mnemonics  
> **Target:** Holden Commodore VY V6 Ecotec (Delco P04, OSID: 92118883)

---

## Table of Contents
1. [Non-Standard Mnemonics (DHC11 vs Motorola)](#non-standard-mnemonics)
2. [VY V6 128KB Memory Map](#vy-v6-memory-map)
3. [Bank Switching Explained](#bank-switching)
4. [Interrupt Vector Table](#interrupt-vector-table)
5. [RAM Layout ($0000-$01FF)](#ram-layout)
6. [Hardware Registers ($1000-$103F)](#hardware-registers)
7. [Address Calculation Formulas](#address-calculation)

---

## Non-Standard Mnemonics

### DHC11 (TechEdge) vs Motorola Standard

The DHC11 disassembler from TechEdge uses different mnemonics from Motorola's official documentation:

| DHC11 Mnemonic | Motorola | Opcode(s) | Description |
|----------------|----------|-----------|-------------|
| `CALL` | `JSR` | $BD (ext), $9D (dir) | Call subroutine (16-bit address) |
| `CALLR` | `BSR` | $8D | Call relative (8-bit offset) |
| `CMPD` | `CPD` | $1A 83/93/A3/B3 | Compare D register (16-bit) |
| `CMPX` | `CPX` | $8C/9C/AC/BC | Compare X register |
| `CMPY` | `CPY` | $18 8C/9C/AC/BC | Compare Y register |
| `DECX` | `DEX` | $09 | Decrement X |
| `DECY` | `DEY` | $18 09 | Decrement Y |
| `DECS` | `DES` | $34 | Decrement Stack Pointer |
| `DI` | `SEI` | $0F | Disable interrupts (Set I flag) |
| `EI` | `CLI` | $0E | Enable interrupts (Clear I flag) |
| `INCX` | `INX` | $08 | Increment X |
| `INCY` | `INY` | $18 08 | Increment Y |
| `INCS` | `INS` | $31 | Increment Stack Pointer |
| `JR` | `BRA` | $20 | Jump relative (always) |
| `PUSH` / `PUSHA` | `PSHA` | $36 | Push A onto stack |
| `PUSHB` | `PSHB` | $37 | Push B onto stack |
| `PUSHX` | `PSHX` | $3C | Push X onto stack |
| `PUSHY` | `PSHY` | $18 3C | Push Y onto stack |
| `POPA` | `PULA` | $32 | Pop A from stack |
| `POPB` | `PULB` | $33 | Pop B from stack |
| `POPX` | `PULX` | $38 | Pop X from stack |
| `POPY` | `PULY` | $18 38 | Pop Y from stack |
| `RET` | `RTS` | $39 | Return from subroutine |
| `RETI` | `RTI` | $3B | Return from interrupt |
| `XORA` | `EORA` | $88/98/A8/B8 | Exclusive OR with A |
| `XORB` | `EORB` | $C8/D8/E8/F8 | Exclusive OR with B |

### Other Disassembler Variations

| Tool | Notes |
|------|-------|
| **dis68hc11** (kingai fork) | Uses Motorola standard, had ADCA/ADCB bugs (fixed) |
| **DISASM11** (TechEdge) | Uses Motorola standard mnemonics |
| **Ghidra HC11** | Uses Motorola standard |
| **IDA Pro HC11** | Uses Motorola standard |
| **dasmfw** | Uses Motorola standard |

### Recommendation
**Always use Motorola standard mnemonics** in your source code for portability. If working with DHC11 output, mentally translate to Motorola equivalents.

---

## VY V6 Memory Map

### 128KB Binary Layout (OSID: 92118883)

The VY V6 Ecotec ECU uses a **128KB (0x20000 byte)** EEPROM/Flash organized as follows:
where is the trans tables located is it in a higher or lower in the calibration area
```
FILE OFFSET         SIZE      PURPOSE                    CPU ADDRESS
─────────────────────────────────────────────────────────────────────
0x00000 - 0x0FFFF   64KB      Calibration Bank 0         (Not mapped)
                              - Spark tables
                              - Fuel tables  
                              - VE tables
                              - Timing tables
                              - Parameters
                              
0x10000 - 0x17FFF   32KB      CPU Lower Space            0x0000 - 0x7FFF
                              - RAM mirror
                              - Calibration overlay
                              - Table data
                              
0x18000 - 0x1FFFF   32KB      CPU ROM Space              0x8000 - 0xFFFF
                              - Executable code
                              - ISR handlers
                              - Main loop
                              - Vector table (0x1FFD6-0x1FFFF)
```

### File Offset → CPU Address Formula

```python
# For 128KB VY V6 Enhanced binary:
CODE_START_OFFSET = 0x10000  # Second 64KB bank

def file_to_cpu(file_offset):
    """Convert file offset to HC11 CPU address"""
    if file_offset >= 0x10000:
        return file_offset - 0x10000  # Direct mapping for bank 1
    else:
        return None  # Bank 0 = calibration data (not directly addressable)
```

### Examples

| File Offset | CPU Address | Region |
|-------------|-------------|--------|
| 0x00000 | N/A | Bank 0 calibration |
| 0x10000 | 0x0000 | RAM/IO area |
| 0x17D84 | 0x7D84 | Lower memory (The1's spark cut) |
| 0x18000 | 0x8000 | ROM start |
| 0x1C011 | 0xC011 | Reset handler entry |
| 0x1FFFE | 0xFFFE | Reset vector |

---

## Bank Switching

### How the VY V6 ECU Handles 128KB

The MC68HC11 has a **16-bit address bus** (64KB max). To access 128KB, the ECU uses **bank switching**:

1. **External Address Latch** - Hardware (PAL/GAL) decodes upper address bits
2. **Bank Select Register** - Port pin(s) control which bank is mapped
3. **Permanent Mapping** - Some addresses always map to the same physical memory

### Typical Delco P04 Bank Scheme

```
HC11 CPU Address     Bank 0 Selected      Bank 1 Selected
────────────────────────────────────────────────────────────
0x0000 - 0x01FF      Internal RAM         Internal RAM (fixed)
0x1000 - 0x103F      I/O Registers        I/O Registers (fixed)
0x8000 - 0xBFFF      Cal Tables Bank 0    Cal Tables Bank 1
0xC000 - 0xFFFF      Executable Code      Executable Code (fixed)
```

### Bank Switch Detection

Look for these patterns in disassembly:
```assembly
; Bank switch to Bank 0
LDAA    #$00
STAA    $7FFF        ; Or similar address
                     ; Or PORTA/PORTG bit manipulation

; Bank switch to Bank 1  
LDAA    #$01
STAA    $7FFF
```

### ✅ VY V6 Bank Switch - VERIFIED (Jan 22, 2026)
this is how it works on vs? 
**Source:** PCMhacking Archive `downloads_md\BMW\topic_181\bank switch.md`

```assembly
; -- Bank Switch To Bank 1 (Code/Upper 64KB) --
tpa             ; Save The Conditions Register On The Stack
psha            ; 
sei             ; Turn Off Interrupts
ldab  $1002     ; Port G
orab  #$40      ; Set Bit 6 [b01000000]
stab  $1002     ; Save It
pula            ; 
tap             ; Restore The Condition Registers

; -- Bank Switch To Bank 0 (Calibration/Lower 64KB) --
tpa             ; Save The Conditions Register On The Stack  
psha            ;
sei             ; Turn Off Interrupts
ldab  $1002     ; Port G
andb  #$BF      ; Clear Bit 6 [b10111111]
stab  $1002     ; Save It
pula            ;
tap             ; Restore The Condition Registers
```

**Summary:**
| Register | Address | Bit | Bank 0 (Cal) | Bank 1 (Code) |
|----------|---------|-----|--------------|---------------|
| **PORTG** | **$1002** | **Bit 6** | CLEAR (ANDB #$BF) | SET (ORAB #$40) |

---

## Interrupt Vector Table

### Location: File 0x1FFD6 - 0x1FFFF (CPU 0xFFD6 - 0xFFFF)

| Vector | File Offset | CPU Address | Handler (Stock) | Purpose |
|--------|-------------|-------------|-----------------|---------|
| SCI | 0x1FFD6 | 0xFFD6 | $2003 | Serial Comm Interface |
| SPI | 0x1FFD8 | 0xFFD8 | $2000 | SPI Interrupt |
| PAIE | 0x1FFDA | 0xFFDA | $2000 | Pulse Accumulator Input Edge |
| PAO | 0x1FFDC | 0xFFDC | $2000 | Pulse Accumulator Overflow |
| TOF | 0x1FFDE | 0xFFDE | $2000 | Timer Overflow |
| TOC5 | 0x1FFE0 | 0xFFE0 | $2000 | Timer Output Compare 5 |
| TOC4 | 0x1FFE2 | 0xFFE2 | $2006 | Timer Output Compare 4 |
| TOC3 | 0x1FFE4 | 0xFFE4 | $2009 | Timer Output Compare 3 |
| TOC2 | 0x1FFE6 | 0xFFE6 | $2000 | Timer Output Compare 2 |
| TOC1 | 0x1FFE8 | 0xFFE8 | **$200C** | Timer Output Compare 1 |
| TIC3 | 0x1FFEA | 0xFFEA | **$200F** | Timer Input Capture 3 (**3X Crank!**) |
| TIC2 | 0x1FFEC | 0xFFEC | **$2012** | Timer Input Capture 2 |
| TIC1 | 0x1FFEE | 0xFFEE | **$2015** | Timer Input Capture 1 |
| RTI | 0x1FFF0 | 0xFFF0 | $2000 | Real Time Interrupt |
| IRQ | 0x1FFF2 | 0xFFF2 | **$2018** | External IRQ |
| XIRQ | 0x1FFF4 | 0xFFF4 | **$201B** | External XIRQ |
| SWI | 0x1FFF6 | 0xFFF6 | **$201E** | Software Interrupt |
| Illegal Op | 0x1FFF8 | 0xFFF8 | $2021 | Illegal Opcode Trap |
| COP Fail | 0x1FFFA | 0xFFFA | **$C015** | Watchdog Failure |
| CMF | 0x1FFFC | 0xFFFC | $C019 | Clock Monitor Failure |
| **RESET** | **0x1FFFE** | **0xFFFE** | **$C011** | **Power-on Reset** |

> **Note:** Most vectors point to a jump table at $2000-$2021 (pseudo-vectors).
> Only RESET and COP go directly to ROM code at $C0xx.

### Vector Format

Each vector is a **16-bit address** (big-endian):
```
0xFFFE: C0     ; High byte
0xFFFF: 11     ; Low byte
         → Handler at $C011
```

---

## RAM Layout

### HC11E9 Internal RAM ($0000-$01FF, 512 bytes)

| Address | Size | Verified | Description |
|---------|------|----------|-------------|
| $0000-$003F | 64B | ✅ | Scratch/temp variables |
| $0040-$0045 | 6B | ✅ | System flags |
| **$0046** | 1B | ✅ | **Safe flag byte (bit 7 = spark cut flag)** |
| $0047-$005D | 23B | ⚠️ | Various engine variables |
| **$005E-$005F** | 2B | ✅ | **16-bit RPM value** (or RPM/25 at $005F) |
| $0060-$009F | 64B | ⚠️ | Timer/counter variables |
| **$00A2** | 2B | ✅ | **RPM working register** |
| $00A4-$00FF | 92B | ⚠️ | Calculated values |
| $0100-$0140 | 65B | ⚠️ | DTC/diagnostic data |
| $0141-$017F | 63B | ⚠️ | Sensor readings |
| **$017B** | 2B | ✅ | **3X period storage** (spark cut target) |
| $0180-$01FF | 128B | ⚠️ | Stack area |

### ⚠️ Warning: $01A0

**DO NOT USE $01A0** without verification! Many draft scripts used this address as a placeholder, but it may be used by the bootloader or diagnostic routines. **Use $0046 bit 7** for flag storage instead.

---

## Hardware Registers

### HC11 Internal Registers ($1000-$103F)

| Address | Name | Purpose |
|---------|------|---------|
| $1000 | PORTA | Port A data |
| $1002 | PIOC | Parallel I/O Control |
| $1003 | PORTC | Port C data |
| $1004 | PORTB | Port B data |
| $1005 | PORTCL | Port C Latch |
| $1007 | DDRC | Port C Data Direction |
| $1008 | PORTD | Port D data |
| $1009 | DDRD | Port D Data Direction |
| $100A | PORTE | Port E data (ADC inputs) |
| $100B | CFORC | Timer Compare Force |
| $100C | OC1M | OC1 Action Mask |
| $100D | OC1D | OC1 Action Data |
| $100E-$100F | TCNT | Timer Counter (16-bit) |
| $1010-$1011 | TIC1 | Input Capture 1 |
| $1012-$1013 | TIC2 | Input Capture 2 |
| **$1014-$1015** | **TIC3** | **Input Capture 3 (3X Crank!)** |
| $1016-$1017 | TOC1 | Output Compare 1 |
| $1018-$1019 | TOC2 | Output Compare 2 |
| $101A-$101B | TOC3 | Output Compare 3 |
| $101C-$101D | TOC4 | Output Compare 4 |
| $101E-$101F | TOC5 | Output Compare 5 |
| **$1020** | **TCTL1** | **Timer Control 1 (EST output mode!)** |
| $1021 | TCTL2 | Timer Control 2 |
| $1022 | TMSK1 | Timer Interrupt Mask 1 |
| $1023 | TFLG1 | Timer Interrupt Flags 1 |
| $1024 | TMSK2 | Timer Interrupt Mask 2 |
| $1025 | TFLG2 | Timer Interrupt Flags 2 |
| $1026 | PACTL | Pulse Accumulator Control |
| $1027 | PACNT | Pulse Accumulator Count |
| $1028 | SPCR | SPI Control |
| $1029 | SPSR | SPI Status |
| $102A | SPDR | SPI Data |
| $102B | BAUD | SCI Baud Rate |
| $102C | SCCR1 | SCI Control 1 |
| $102D | SCCR2 | SCI Control 2 |
| $102E | SCSR | SCI Status |
| $102F | SCDR | SCI Data |
| $1030 | ADCTL | ADC Control |
| $1031-$1034 | ADRx | ADC Results |
| $1035 | BPROT | Block Protect |
| $1036 | EPROG | EEPROM Programming |
| $1039 | OPTION | System Configuration |
| $103A | COPRST | COP Reset |
| $103B | PPROG | EEPROM Programming |
| $103C | HPRIO | Highest Priority I Bit |
| $103D | INIT | RAM/IO Mapping |
| $103F | CONFIG | System Configuration |

---

## Address Calculation

### Quick Reference Formulas

```python
# File offset → CPU address (VY V6 128KB binary)
def file_to_cpu(offset):
    if offset >= 0x10000:
        return offset - 0x10000
    return None  # Bank 0 calibration

# CPU address → File offset
def cpu_to_file(cpu_addr):
    return cpu_addr + 0x10000  # For bank 1

# XDF address → File offset (if XDF uses 0x8000 base)
def xdf_to_file(xdf_addr):
    if xdf_addr >= 0x8000:
        return xdf_addr + 0x10000  # 0x18000 for ROM area
    return None

# Check if address is in ROM (executable code)
def is_rom(cpu_addr):
    return 0x8000 <= cpu_addr <= 0xFFFF
```

### Common Conversions

| Description | File Offset | CPU Address |
|-------------|-------------|-------------|
| Reset vector | 0x1FFFE | 0xFFFE |
| Reset handler | 0x1C011 | 0xC011 |
| TIC3 ISR entry | 0x12000 | 0x2000 (approx) |
| The1's spark cut | 0x17D84 | 0x7D84 |
| Hook point | 0x101E1 | 0x01E1 |
| Free RAM flag | - | 0x0046 |
| 3X period | - | 0x017B |

---

## References

- **M68HC11 Reference Manual** (Motorola/NXP)
- **PCMHacking.net** - Delco ECU reverse engineering
- **TechEdge.com.au** - DHC11 disassembler documentation
- **kingai_68hc11_resources** - Opcode/mnemonic references
- **VY V6 $060A Enhanced XDF** - Verified RAM/table addresses

---

## Version History

| Date | Changes |
|------|---------|
| 2026-01-20 | Initial document - DHC11 mnemonics, memory map, bank switching |
| 2026-01-21 | **VERIFIED** vector table against v1.1a binary (TIC3=$200F, RST=$C011) | we are meant to be working on 92118883 and enhanced 1.0
