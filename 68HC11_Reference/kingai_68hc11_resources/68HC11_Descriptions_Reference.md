# 68HC11 Instruction Descriptions (from dis68hc11)

> **Source:** dis68hc11 disassembler - Description.cpp / Description.h
> **Purpose:** Human-readable descriptions for VY V6 ECU decompilation

---

## Description Function Signature

```cpp
#include <stdint.h>

const char* Description(uint8_t op);
```

Returns a human-readable description string for the given opcode.

---

## Complete Instruction Descriptions

### Accumulator Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x1B | ABA | Add Accumulator B to Accumulator A |
| 0x3A | ABX | Add B to X |
| 0x4F | CLRA | Clear Accumulator A |
| 0x5F | CLRB | Clear Accumulator B |
| 0x10 | SBA | Subtract B from A |
| 0x16 | TAB | Transfer A to B |

### Add with Carry (ADCB)

| Opcode | Mode | Description | Note |
|--------|------|-------------|------|
| 0xC9 | IMM | Add with carry to B, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| 0xD9 | DIR | Add with carry to B, direct | ⚠️ dis68hc11 said IMM - WRONG |
| 0xF9 | EXT | Add with carry to B, extended | |
| 0xE9 | IND,X | Add with carry to B, indexed | |

### AND Operations (ANDA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x84 | IMM | AND A with Memory, immediate |
| 0x94 | DIR | AND A with Memory, direct |
| 0xB4 | EXT | AND A with Memory, extended |
| 0xA4 | IND,X | AND A with Memory, indexed |

### AND Operations (ANDB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC4 | IMM | AND B with Memory, immediate |
| 0xD4 | DIR | AND B with Memory, direct |
| 0xF4 | EXT | AND B with Memory, extended |
| 0xE4 | IND,X | AND B with Memory, indexed |

### Shift Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x48 | ASLA | Arithmetic Shift Left A |
| 0x58 | ASLB | Arithmetic Shift Left B |

### Branch Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x25 | BCS | Branch if Carry Set |
| 0x27 | BEQ | Branch if Equal |
| 0x22 | BHI | Branch if Higher |
| 0x26 | BNE | Branch if Not Equal to Zero |

### CCR Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x0E | CLI | Clear Interrupt Mask |
| 0x0F | SEI | Set Interrupt Mask |

### Compare Operations (CMPA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x91 | DIR | Compare A, direct |

### Compare X (CPX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8C | IMM | Compare X to Memory 16-Bit, immediate |
| 0x9C | DIR | Compare X to Memory 16-Bit, direct |
| 0xBC | EXT | Compare X to Memory 16-Bit, extended |
| 0xAC | IND | Compare X to Memory 16-Bit, indexed |

### Index Register Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x09 | DEX | Decrement Index Register X |
| 0x08 | INX | Increment Index Register X |

### Exclusive OR (EORA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x88 | IMM | Exclusive OR, immediate |
| 0x98 | DIR | Exclusive OR, direct |
| 0xB8 | EXT | Exclusive OR, extended |
| 0xA8 | IND,X | Exclusive OR, indexed |

### Stack Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x31 | INS | Increment Stack Pointer |
| 0x38 | PULX | Pull Index Register X from Stack |

### Jump Operations

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xBD | JSR EXT | Jump to Subroutine, extended |
| 0xAD | JSR IND | Jump to Subroutine, indexed |

### Load A (LDAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x86 | IMM | Load Accumulator A, immediate |
| 0x96 | DIR | Load Accumulator A, direct |
| 0xB6 | EXT | Load Accumulator A, extended |

### Load Stack Pointer (LDS)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8E | IMM | Load Stack Pointer, immediate |
| 0x9E | DIR | Load Stack Pointer, direct |
| 0xBE | EXT | Load Stack Pointer, extended |

### Logical Shift Right (LSR)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x74 | EXT | Logical Shift Right, extended |
| 0x64 | IND,X | Logical Shift Right, indexed |
| 0x44 | LSRA | Logical Shift Right A |
| 0x54 | LSRB | Logical Shift Right B |
| 0x04 | LSRD | Logical Shift Right D |

### OR Operations (ORAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8A | IMM | Inclusive OR accumulator A, immediate |
| 0x9A | DIR | Inclusive OR accumulator A, direct |
| 0xAA | IND,X | Inclusive OR accumulator A, indexed |

### Rotate Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x59 | ROLB | Rotate Left B |

### Return Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x39 | RTS | Return from Subroutine |

### Store A (STAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x97 | DIR | Store Accumulator A, direct |
| 0xB7 | EXT | Store Accumulator A, extended |
| 0xA7 | IND,X | Store Accumulator A, indexed |

### Store B (STAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xD7 | DIR | Store Accumulator B, direct |
| 0xF7 | EXT | Store Accumulator B, extended |
| 0xE7 | IND,X | Store Accumulator B, indexed |

### Store X (STX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xDF | DIR | Store Index Register X, immediate |
| 0xFF | EXT | Store Index Register X, extended |
| 0xEF | IND | Store Index Register X, indexed |

### Transfer Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x30 | TSX | Transfer Stack Pointer to X |
| 0x8F | XGDX | Exchange D with X |

---

## Description Implementation (C++)

```cpp
#include "Description.h"
#include "Opcodes.h"

const char* Description(uint8_t op)
{
    switch(op)
    {
    case OP_ABA:      return "Add Accumulator B to Accumulator A";
    case OP_ABX:      return "Add B to X";
    case OP_ADCB_DIR: return "Add with carry to B, direct";
    case OP_ADCB_EXT: return "Add with carry to B, extended";
    case OP_ADCB_IMM: return "Add with carry to B, immediate";
    case OP_ADCB_IND_X: return "Add with carry to B, indexed";
    case OP_ANDA_DIR: return "AND A with Memory, direct";
    case OP_ANDA_EXT: return "AND A with Memory, extended";
    case OP_ANDA_IMM: return "AND A with Memory, immediate";
    case OP_ANDA_IND_X: return "AND A with Memory, indexed";
    case OP_ANDB_DIR: return "AND B with Memory, direct";
    case OP_ANDB_EXT: return "AND B with Memory, extended";
    case OP_ANDB_IMM: return "AND B with Memory, immediate";
    case OP_ANDB_IND_X: return "AND B with Memory, indexed";
    case OP_ASLA:     return "Arithmetic Shift Left A";
    case OP_ASLB:     return "Arithmetic Shift Left B";
    case OP_BCS:      return "Branch if Carry Set";
    case OP_BEQ:      return "Branch if Equal";
    case OP_BHI:      return "Branch if Higher";
    case OP_BNE:      return "Branch if Not Equal to Zero";
    case OP_CLI:      return "Clear Interrupt Mask";
    case OP_CLRA:     return "Clear Accumulator A";
    case OP_CLRB:     return "Clear Accumulator B";
    case OP_CMPA_DIR: return "Compare A, direct";
    case OP_CPX_DIR:  return "Compare X to Memory 16-Bit, direct";
    case OP_CPX_EXT:  return "Compare X to Memory 16-Bit, extended";
    case OP_CPX_IMM:  return "Compare X to Memory 16-Bit, immediate";
    case OP_CPX_IND:  return "Compare X to Memory 16-Bit, indexed";
    case OP_DEX:      return "Decrement Index Register X";
    case OP_EORA_DIR: return "Exclusive OR, direct";
    case OP_EORA_EXT: return "Exclusive OR, extended";
    case OP_EORA_IMM: return "Exclusive OR, immediate";
    case OP_EORA_IND_X: return "Exclusive OR, indexed";
    case OP_INS:      return "Increment Stack Pointer";
    case OP_INX:      return "Increment Index Register X";
    case OP_JSR_EXT:  return "Jump to Subroutine, extended";
    case OP_JSR_IND:  return "Jump to Subroutine, indexed";
    case OP_LDAA_DIR: return "Load Accumulator A, direct";
    case OP_LDAA_IMM: return "Load Accumulator A, immediate";
    case OP_LDAA_EXT: return "Load Accumulator A, extended";
    case OP_LDS_DIR:  return "Load Stack Pointer, direct";
    case OP_LDS_EXT:  return "Load Stack Pointer, extended";
    case OP_LDS_IMM:  return "Load Stack Pointer, immediate";
    case OP_LSR_EXT:  return "Logical Shift Right, extended";
    case OP_LSR_IND_X: return "Logical Shift Right, indexed";
    case OP_LSRA:     return "Logical Shift Right A";
    case OP_LSRB:     return "Logical Shift Right B";
    case OP_LSRD:     return "Logical Shift Right D";
    case OP_ORAA_DIR: return "Inclusive OR accumulator A, direct";
    case OP_ORAA_IMM: return "Inclusive OR accumulator A, immediate";
    case OP_ORAA_IND_X: return "Inclusive OR accumulator A, indexed";
    case OP_PULX:     return "Pull Index Register X from Stack";
    case OP_ROLB:     return "Rotate Left B";
    case OP_RTS:      return "Return from Subroutine";
    case OP_SBA:      return "Subtract B from A";
    case OP_SEI:      return "Set Interrupt Mask";
    case OP_STAA_DIR: return "Store Accumulator A, direct";
    case OP_STAA_EXT: return "Store Accumulator A, extended";
    case OP_STAA_IND_X: return "Store Accumulator A, indexed";
    case OP_STAB_DIR: return "Store Accumulator B, direct";
    case OP_STAB_EXT: return "Store Accumulator B, extended";
    case OP_STAB_IND_X: return "Store Accumulator B, indexed";
    case OP_STX_DIR:  return "Store Index Register X, immediate";
    case OP_STX_EXT:  return "Store Index Register X, extended";
    case OP_STX_IND:  return "Store Index Register X, indexed";
    case OP_TAB:      return "Transfer A to B";
    case OP_TSX:      return "Transfer Stack Pointer to X";
    case OP_XGDX:     return "Exchange D with X";
    default:          return "";
    }
}
```

---

## VY V6 ECU - Common Description Patterns

### Timing-Critical Operations
- **"Set Interrupt Mask"** (SEI 0x0F) - Disables interrupts during critical sections
- **"Clear Interrupt Mask"** (CLI 0x0E) - Re-enables interrupts

### EST/Spark Control
- **"Store Accumulator A"** to $1020 (TCTL1) - Controls EST output compare
- **"Inclusive OR accumulator A"** - Sets specific bits (e.g., OC3 for EST)

### Loop Operations
- **"Decrement Index Register X"** (DEX) - Common loop counter
- **"Branch if Not Equal to Zero"** (BNE) - Loop continuation

### Subroutine Patterns
- **"Jump to Subroutine"** (JSR) - Function call
- **"Return from Subroutine"** (RTS) - Function return

---

## Missing Descriptions (TODO)

The original Description.cpp is incomplete. These common instructions need descriptions:

| Opcode | Mnemonic | Suggested Description |
|--------|----------|----------------------|
| 0x3D | MUL | Multiply A by B, result in D |
| 0x02 | IDIV | Integer Divide D by X |
| 0x03 | FDIV | Fractional Divide D by X |
| 0xCC | LDD IMM | Load D with immediate 16-bit value |
| 0xDC | LDD DIR | Load D from direct address |
| 0xFC | LDD EXT | Load D from extended address |
| 0xDD | STD DIR | Store D to direct address |
| 0xFD | STD EXT | Store D to extended address |
| 0x3B | RTI | Return from Interrupt |
| 0x3F | SWI | Software Interrupt |

---

## ⚠️ Bug Fix Applied

**Original dis68hc11 source had swapped IMM/DIR modes for ADCA and ADCB.**
This file has been corrected to match the official Motorola M68HC11 Reference Manual.

See `68HC11_Opcodes_Reference.md` for full details of the bug.

---

*Generated from dis68hc11 source - January 2026*
*Corrected: ADCB IMM/DIR modes fixed January 17, 2026*
