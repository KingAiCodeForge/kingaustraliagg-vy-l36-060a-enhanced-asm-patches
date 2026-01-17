# 68HC11 Mnemonics Reference (from dis68hc11)

> **Source:** dis68hc11 disassembler - Mnenomic.cpp / Mnenomic.h
> **Purpose:** Mnemonic lookup for VY V6 ECU decompilation
> **⚠️ Note:** dis68hc11 source has bugs - ADCA/ADCB IMM/DIR modes were swapped. This doc is CORRECTED.

---

## Mnemonic Function Signature

```cpp
#include <stdint.h>

const char* Mnenomic(uint8_t op);      // Page 0 (main) opcodes
const char* MnenomicPage1(uint8_t op); // Page 1 (0x18 prefix) opcodes
```

---

## Page 0 Mnemonics (Main Instruction Set)

### Inherent (No Operand)

| Opcode | Mnemonic | Category |
|--------|----------|----------|
| 0x1B | ABA | Arithmetic |
| 0x3A | ABX | Index Register |
| 0x48 | ASLA | Shift |
| 0x58 | ASLB | Shift |
| 0x05 | ASLD | Shift |
| 0x47 | ASRA | Shift |
| 0x57 | ASRB | Shift |
| 0x0E | CLI | CCR |
| 0x4F | CLRA | Clear |
| 0x5F | CLRB | Clear |
| 0x0A | CLV | CCR |
| 0x19 | DAA | Arithmetic |
| 0x4A | DECA | Decrement |
| 0x5A | DECB | Decrement |
| 0x34 | DES | Stack |
| 0x09 | DEX | Index Register |
| 0x03 | FDIV | Math |
| 0x02 | IDIV | Math |
| 0x4C | INCA | Increment |
| 0x5C | INCB | Increment |
| 0x31 | INS | Stack |
| 0x08 | INX | Index Register |
| 0x44 | LSRA | Shift |
| 0x54 | LSRB | Shift |
| 0x04 | LSRD | Shift |
| 0x3D | MUL | Math |
| 0x36 | PSHA | Stack |
| 0x37 | PSHB | Stack |
| 0x3C | PSHX | Stack |
| 0x32 | PULA | Stack |
| 0x33 | PULB | Stack |
| 0x38 | PULX | Stack |
| 0x49 | ROLA | Rotate |
| 0x59 | ROLB | Rotate |
| 0x46 | RORA | Rotate |
| 0x56 | RORB | Rotate |
| 0x39 | RTS | Control |
| 0x10 | SBA | Arithmetic |
| 0x0D | SEC | CCR |
| 0x0F | SEI | CCR |
| 0x0B | SEV | CCR |
| 0xCF | STOP | Control |
| 0x3F | SWI | Control |
| 0x16 | TAB | Transfer |
| 0x06 | TAP | Transfer |
| 0x17 | TBA | Transfer |
| 0x00 | TEST | Test |
| 0x07 | TPA | Transfer |
| 0x4D | TSTA | Test |
| 0x5D | TSTB | Test |
| 0x30 | TSX | Transfer |
| 0x35 | TXS | Transfer |
| 0x3E | WAI | Control |
| 0x8F | XGDX | Transfer |

### Multi-Mode Instructions

These instructions share the same mnemonic but different opcodes based on addressing mode:

#### ADCA - Add with Carry to A
| Mode | Opcode | Note |
|------|--------|------|
| IMM | 0x89 | ⚠️ dis68hc11 said DIR - WRONG |
| DIR | 0x99 | ⚠️ dis68hc11 said IMM - WRONG |
| EXT | 0xB9 | |
| IND,X | 0xA9 | |

#### ADCB - Add with Carry to B
| Mode | Opcode | Note |
|------|--------|------|
| IMM | 0xC9 | ⚠️ dis68hc11 said DIR - WRONG |
| DIR | 0xD9 | ⚠️ dis68hc11 said IMM - WRONG |
| EXT | 0xF9 | |
| IND,X | 0xE9 | |

#### ADDA - Add to A
| Mode | Opcode |
|------|--------|
| IMM | 0x8B |
| DIR | 0x9B |
| EXT | 0xBB |
| IND,X | 0xAB |

#### ADDB - Add to B
| Mode | Opcode |
|------|--------|
| IMM | 0xCB |
| DIR | 0xDB |
| EXT | 0xFB |
| IND,X | 0xEB |

#### ADDD - Add to D (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0xC3 |
| DIR | 0xD3 |
| EXT | 0xF3 |
| IND,X | 0xE3 |

#### ANDA - AND with A
| Mode | Opcode |
|------|--------|
| IMM | 0x84 |
| DIR | 0x94 |
| EXT | 0xB4 |
| IND,X | 0xA4 |

#### ANDB - AND with B
| Mode | Opcode |
|------|--------|
| IMM | 0xC4 |
| DIR | 0xD4 |
| EXT | 0xF4 |
| IND,X | 0xE4 |

#### ASL - Arithmetic Shift Left
| Mode | Opcode |
|------|--------|
| EXT | 0x78 |
| IND,X | 0x68 |

#### ASR - Arithmetic Shift Right
| Mode | Opcode |
|------|--------|
| EXT | 0x77 |
| IND,X | 0x67 |

#### CLR - Clear Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7F |
| IND | 0x6F |

#### CMPA - Compare A
| Mode | Opcode |
|------|--------|
| IMM | 0x81 |
| DIR | 0x91 |
| EXT | 0xB1 |
| IND,X | 0xA1 |

#### CMPB - Compare B
| Mode | Opcode |
|------|--------|
| IMM | 0xC1 |
| DIR | 0xD1 |
| EXT | 0xF1 |
| IND,X | 0xE1 |

#### CPX - Compare X (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0x8C |
| DIR | 0x9C |
| IND | 0xAC |

#### EORA - Exclusive OR with A
| Mode | Opcode |
|------|--------|
| IMM | 0x88 |
| DIR | 0x98 |
| EXT | 0xB8 |
| IND,X | 0xA8 |

#### EORB - Exclusive OR with B
| Mode | Opcode |
|------|--------|
| IMM | 0xC8 |
| DIR | 0xD8 |
| EXT | 0xF8 |
| IND,X | 0xE8 |

#### INC - Increment Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7C |
| IND,X | 0x6C |

#### JMP - Jump
| Mode | Opcode |
|------|--------|
| EXT | 0x7E |
| IND,X | 0x6E |

#### JSR - Jump to Subroutine
| Mode | Opcode |
|------|--------|
| DIR | 0x9D |
| EXT | 0xBD |
| IND | 0xAD |

#### LDAA - Load A
| Mode | Opcode |
|------|--------|
| IMM | 0x86 |
| DIR | 0x96 |
| EXT | 0xB6 |
| IND,X | 0xA6 |

#### LDAB - Load B
| Mode | Opcode |
|------|--------|
| IMM | 0xC6 |
| DIR | 0xD6 |
| EXT | 0xF6 |
| IND,X | 0xE6 |

#### LDD - Load D (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0xCC |
| DIR | 0xDC |
| EXT | 0xFC |
| IND,X | 0xEC |

#### LDS - Load Stack Pointer
| Mode | Opcode |
|------|--------|
| IMM | 0x8E |
| DIR | 0x9E |
| EXT | 0xBE |
| IND | 0xAE |

#### LDX - Load X
| Mode | Opcode |
|------|--------|
| IMM | 0xCE |
| DIR | 0xDE |
| EXT | 0xFE |
| IND | 0xEE |

#### LSR - Logical Shift Right
| Mode | Opcode |
|------|--------|
| EXT | 0x74 |
| IND,X | 0x64 |

#### ORAA - OR with A
| Mode | Opcode |
|------|--------|
| IMM | 0x8A |
| DIR | 0x9A |
| EXT | 0xBA |
| IND,X | 0xAA |

#### ORAB - OR with B
| Mode | Opcode |
|------|--------|
| IMM | 0xCA |
| DIR | 0xDA |
| EXT | 0xFA |
| IND,X | 0xEA |

#### ROL - Rotate Left
| Mode | Opcode |
|------|--------|
| EXT | 0x79 |
| IND | 0x69 |

#### ROR - Rotate Right
| Mode | Opcode |
|------|--------|
| EXT | 0x76 |
| IND | 0x66 |

#### SBCA - Subtract with Carry from A
| Mode | Opcode |
|------|--------|
| IMM | 0x82 |
| DIR | 0x92 |
| EXT | 0xB2 |
| IND,X | 0xA2 |

#### SBCB - Subtract with Carry from B
| Mode | Opcode |
|------|--------|
| IMM | 0xC2 |
| DIR | 0xD2 |
| EXT | 0xF2 |
| IND,X | 0xE2 |

#### STAA - Store A
| Mode | Opcode |
|------|--------|
| DIR | 0x97 |
| EXT | 0xB7 |
| IND,X | 0xA7 |

#### STAB - Store B
| Mode | Opcode |
|------|--------|
| DIR | 0xD7 |
| EXT | 0xF7 |
| IND,X | 0xE7 |

#### STD - Store D (16-bit)
| Mode | Opcode |
|------|--------|
| DIR | 0xDD |
| EXT | 0xFD |
| IND,X | 0xED |

#### STS - Store Stack Pointer
| Mode | Opcode |
|------|--------|
| DIR | 0x9F |
| IND,X | 0xAF |

#### STX - Store X
| Mode | Opcode |
|------|--------|
| DIR | 0xDF |
| EXT | 0xFF |
| IND | 0xEF |

#### SUBA - Subtract from A
| Mode | Opcode |
|------|--------|
| IMM | 0x80 |
| DIR | 0x90 |
| EXT | 0xB0 |
| IND,X | 0xA0 |

#### SUBB - Subtract from B
| Mode | Opcode |
|------|--------|
| IMM | 0xC0 |
| DIR | 0xD0 |
| EXT | 0xF0 |
| IND,X | 0xE0 |

#### TST - Test Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7D |
| IND,X | 0x6D |

---

## Branch Mnemonics

| Opcode | Mnemonic | Condition |
|--------|----------|-----------|
| 0x24 | BCC/BHS | Carry Clear |
| 0x25 | BCS/BLO | Carry Set |
| 0x27 | BEQ | Equal (Z=1) |
| 0x2C | BGE | Greater/Equal (signed) |
| 0x2E | BGT | Greater Than (signed) |
| 0x22 | BHI | Higher (unsigned) |
| 0x2F | BLE | Less/Equal (signed) |
| 0x23 | BLS | Lower/Same (unsigned) |
| 0x2D | BLT | Less Than (signed) |
| 0x2B | BMI | Minus (N=1) |
| 0x26 | BNE | Not Equal (Z=0) |
| 0x2A | BPL | Plus (N=0) |
| 0x20 | BRA | Always |
| 0x28 | BVC | Overflow Clear |
| 0x29 | BVS | Overflow Set |

---

## Page 1 Mnemonics (0x18 Prefix)

```cpp
const char* MnenomicPage1(uint8_t op)
{
    switch(op)
    {
    case 0x3A: return "ABY";    // Add B to Y
    case 0x8C: return "CPY";    // Compare Y
    case 0x09: return "DEY";    // Decrement Y
    case 0x08: return "INY";    // Increment Y
    case 0x30: return "TSY";    // Transfer SP to Y
    case 0xCE: return "LDY";    // Load Y immediate
    case 0xDF: 
    case 0xFF:
    case 0xEF: return "STY";    // Store Y
    case 0xA7: return "STAA";   // Store A indexed Y
    case 0xA6: return "LDAA";   // Load A indexed Y
    default:   return "Unknown";
    }
}
```

---

## Addressing Mode Patterns

The opcode structure follows a pattern for many instructions:

| High Nibble | Meaning |
|-------------|---------|
| 0x8x | Immediate |
| 0x9x | Direct |
| 0xAx | Indexed X |
| 0xBx | Extended |
| 0xCx | Immediate (B/D) |
| 0xDx | Direct (B/D) |
| 0xEx | Indexed X (B/D) |
| 0xFx | Extended (B/D) |

---

## VY V6 Common Mnemonic Sequences

**Load-Compare-Branch (RPM Check):**
```
LDAA → CMPA → BCS/BCC
```

**Load-Modify-Store (Bit Manipulation):**
```
LDAA → ORAA/ANDA → STAA
```

**16-bit Operations:**
```
LDD → ADDD/SUBD → STD
```

**Subroutine Call Pattern:**
```
JSR → ... → RTS
```

---

*Generated from dis68hc11 source - January 2026*
