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
| 0xDF | DIR | Store Index Register X, direct |
| 0xFF | EXT | Store Index Register X, extended |
| 0xEF | IND | Store Index Register X, indexed |

### Add with Carry (ADCA)

| Opcode | Mode | Description | Note |
|--------|------|-------------|------|
| 0x89 | IMM | Add with carry to A, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| 0x99 | DIR | Add with carry to A, direct | ⚠️ dis68hc11 said IMM - WRONG |
| 0xB9 | EXT | Add with carry to A, extended | |
| 0xA9 | IND,X | Add with carry to A, indexed | |

### Add to A (ADDA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8B | IMM | Add to A, immediate |
| 0x9B | DIR | Add to A, direct |
| 0xBB | EXT | Add to A, extended |
| 0xAB | IND,X | Add to A, indexed |

### Add to B (ADDB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCB | IMM | Add to B, immediate |
| 0xDB | DIR | Add to B, direct |
| 0xFB | EXT | Add to B, extended |
| 0xEB | IND,X | Add to B, indexed |

### Add to D (ADDD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC3 | IMM | Add to D (16-bit), immediate |
| 0xD3 | DIR | Add to D (16-bit), direct |
| 0xF3 | EXT | Add to D (16-bit), extended |
| 0xE3 | IND,X | Add to D (16-bit), indexed |

### Subtract from A (SUBA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x80 | IMM | Subtract from A, immediate |
| 0x90 | DIR | Subtract from A, direct |
| 0xB0 | EXT | Subtract from A, extended |
| 0xA0 | IND,X | Subtract from A, indexed |

### Subtract from B (SUBB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC0 | IMM | Subtract from B, immediate |
| 0xD0 | DIR | Subtract from B, direct |
| 0xF0 | EXT | Subtract from B, extended |
| 0xE0 | IND,X | Subtract from B, indexed |

### Subtract D (SUBD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x83 | IMM | Subtract D (16-bit), immediate |
| 0x93 | DIR | Subtract D (16-bit), direct |
| 0xB3 | EXT | Subtract D (16-bit), extended |
| 0xA3 | IND,X | Subtract D (16-bit), indexed |

### Subtract with Carry from A (SBCA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x82 | IMM | Subtract with carry from A, immediate |
| 0x92 | DIR | Subtract with carry from A, direct |
| 0xB2 | EXT | Subtract with carry from A, extended |
| 0xA2 | IND,X | Subtract with carry from A, indexed |

### Subtract with Carry from B (SBCB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC2 | IMM | Subtract with carry from B, immediate |
| 0xD2 | DIR | Subtract with carry from B, direct |
| 0xF2 | EXT | Subtract with carry from B, extended |
| 0xE2 | IND,X | Subtract with carry from B, indexed |

### Bit Test A (BITA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x85 | IMM | Bit Test A (AND flags only), immediate |
| 0x95 | DIR | Bit Test A (AND flags only), direct |
| 0xB5 | EXT | Bit Test A (AND flags only), extended |
| 0xA5 | IND,X | Bit Test A (AND flags only), indexed |

### Bit Test B (BITB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC5 | IMM | Bit Test B (AND flags only), immediate |
| 0xD5 | DIR | Bit Test B (AND flags only), direct |
| 0xF5 | EXT | Bit Test B (AND flags only), extended |
| 0xE5 | IND,X | Bit Test B (AND flags only), indexed |

### Compare A (CMPA) - All Modes

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x81 | IMM | Compare A, immediate |
| 0x91 | DIR | Compare A, direct |
| 0xB1 | EXT | Compare A, extended |
| 0xA1 | IND,X | Compare A, indexed |

### Compare B (CMPB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC1 | IMM | Compare B, immediate |
| 0xD1 | DIR | Compare B, direct |
| 0xF1 | EXT | Compare B, extended |
| 0xE1 | IND,X | Compare B, indexed |

### Load B (LDAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC6 | IMM | Load Accumulator B, immediate |
| 0xD6 | DIR | Load Accumulator B, direct |
| 0xF6 | EXT | Load Accumulator B, extended |
| 0xE6 | IND,X | Load Accumulator B, indexed |

### Load D (LDD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCC | IMM | Load D (16-bit), immediate |
| 0xDC | DIR | Load D (16-bit), direct |
| 0xFC | EXT | Load D (16-bit), extended |
| 0xEC | IND,X | Load D (16-bit), indexed |

### Load X (LDX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCE | IMM | Load Index Register X, immediate |
| 0xDE | DIR | Load Index Register X, direct |
| 0xFE | EXT | Load Index Register X, extended |
| 0xEE | IND,X | Load Index Register X, indexed |

### Store D (STD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xDD | DIR | Store D (16-bit), direct |
| 0xFD | EXT | Store D (16-bit), extended |
| 0xED | IND,X | Store D (16-bit), indexed |

### Store Stack Pointer (STS)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x9F | DIR | Store Stack Pointer, direct |
| 0xBF | EXT | Store Stack Pointer, extended |
| 0xAF | IND,X | Store Stack Pointer, indexed |

### OR B (ORAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCA | IMM | Inclusive OR accumulator B, immediate |
| 0xDA | DIR | Inclusive OR accumulator B, direct |
| 0xFA | EXT | Inclusive OR accumulator B, extended |
| 0xEA | IND,X | Inclusive OR accumulator B, indexed |

### OR A (ORAA) - Extended Mode (Missing from original)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xBA | EXT | Inclusive OR accumulator A, extended |

### Exclusive OR B (EORB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC8 | IMM | Exclusive OR B, immediate |
| 0xD8 | DIR | Exclusive OR B, direct |
| 0xF8 | EXT | Exclusive OR B, extended |
| 0xE8 | IND,X | Exclusive OR B, indexed |

### Transfer Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x06 | TAP | Transfer A to Condition Codes Register |
| 0x07 | TPA | Transfer Condition Codes Register to A |
| 0x16 | TAB | Transfer A to B |
| 0x17 | TBA | Transfer B to A |
| 0x30 | TSX | Transfer Stack Pointer to X |
| 0x35 | TXS | Transfer X to Stack Pointer |
| 0x8F | XGDX | Exchange D with X |

### Multiply/Divide

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x3D | MUL | Multiply A by B, unsigned result in D |
| 0x02 | IDIV | Integer Divide D by X, quotient in X, remainder in D |
| 0x03 | FDIV | Fractional Divide D by X, quotient in X, remainder in D |
| 0x19 | DAA | Decimal Adjust A (BCD correction after ADD) |

### Control Flow

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x3B | RTI | Return from Interrupt (restore all registers + CCR) |
| 0x3F | SWI | Software Interrupt (push all registers, vector to $FFF6) |
| 0x3E | WAI | Wait for Interrupt (push all, halt until IRQ/NMI) |
| 0xCF | STOP | Stop all clocks (lowest power, requires S bit clear) |
| 0x00 | TEST | Test mode (factory only, causes address bus sweep) |
| 0x01 | NOP | No Operation (does nothing for 2 cycles) |

### Stack Operations (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x36 | PSHA | Push A onto Stack |
| 0x37 | PSHB | Push B onto Stack |
| 0x3C | PSHX | Push X onto Stack |
| 0x32 | PULA | Pull A from Stack |
| 0x33 | PULB | Pull B from Stack |
| 0x38 | PULX | Pull X from Stack |
| 0x31 | INS | Increment Stack Pointer |
| 0x34 | DES | Decrement Stack Pointer |

### Increment/Decrement (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x4C | INCA | Increment Accumulator A |
| 0x5C | INCB | Increment Accumulator B |
| 0x4A | DECA | Decrement Accumulator A |
| 0x5A | DECB | Decrement Accumulator B |
| 0x08 | INX | Increment Index Register X |
| 0x09 | DEX | Decrement Index Register X |
| 0x7C | INC EXT | Increment Memory, extended |
| 0x6C | INC IND,X | Increment Memory, indexed |
| 0x7A | DEC EXT | Decrement Memory, extended |
| 0x6A | DEC IND,X | Decrement Memory, indexed |

### Negate/Complement/Test/Clear

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x40 | NEGA | Negate A (two's complement) |
| 0x50 | NEGB | Negate B (two's complement) |
| 0x70 | NEG EXT | Negate Memory, extended |
| 0x60 | NEG IND,X | Negate Memory, indexed |
| 0x43 | COMA | Complement A (one's complement) |
| 0x53 | COMB | Complement B (one's complement) |
| 0x73 | COM EXT | Complement Memory, extended |
| 0x63 | COM IND,X | Complement Memory, indexed |
| 0x4D | TSTA | Test A (set N,Z flags only) |
| 0x5D | TSTB | Test B (set N,Z flags only) |
| 0x7D | TST EXT | Test Memory, extended |
| 0x6D | TST IND,X | Test Memory, indexed |
| 0x7F | CLR EXT | Clear Memory, extended |
| 0x6F | CLR IND,X | Clear Memory, indexed |

### Bit Manipulation

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x14 | BSET DIR | Set Bits in Memory (M OR mask), direct |
| 0x1C | BSET IND,X | Set Bits in Memory, indexed |
| 0x15 | BCLR DIR | Clear Bits in Memory (M AND NOT mask), direct |
| 0x1D | BCLR IND,X | Clear Bits in Memory, indexed |
| 0x12 | BRSET DIR | Branch if Bits Set in Memory, direct |
| 0x1E | BRSET IND,X | Branch if Bits Set, indexed |
| 0x13 | BRCLR DIR | Branch if Bits Clear in Memory, direct |
| 0x1F | BRCLR IND,X | Branch if Bits Clear, indexed |

### Rotate/Shift (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x49 | ROLA | Rotate Left A through Carry |
| 0x59 | ROLB | Rotate Left B through Carry |
| 0x79 | ROL EXT | Rotate Left Memory, extended |
| 0x69 | ROL IND,X | Rotate Left Memory, indexed |
| 0x46 | RORA | Rotate Right A through Carry |
| 0x56 | RORB | Rotate Right B through Carry |
| 0x76 | ROR EXT | Rotate Right Memory, extended |
| 0x66 | ROR IND,X | Rotate Right Memory, indexed |
| 0x48 | ASLA | Arithmetic Shift Left A |
| 0x58 | ASLB | Arithmetic Shift Left B |
| 0x05 | ASLD | Arithmetic Shift Left D |
| 0x78 | ASL EXT | Arithmetic Shift Left Memory, extended |
| 0x68 | ASL IND,X | Arithmetic Shift Left Memory, indexed |
| 0x47 | ASRA | Arithmetic Shift Right A |
| 0x57 | ASRB | Arithmetic Shift Right B |
| 0x77 | ASR EXT | Arithmetic Shift Right Memory, extended |
| 0x67 | ASR IND,X | Arithmetic Shift Right Memory, indexed |
| 0x44 | LSRA | Logical Shift Right A |
| 0x54 | LSRB | Logical Shift Right B |
| 0x04 | LSRD | Logical Shift Right D |
| 0x74 | LSR EXT | Logical Shift Right Memory, extended |
| 0x64 | LSR IND,X | Logical Shift Right Memory, indexed |

### Branch Instructions (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x20 | BRA | Branch Always |
| 0x21 | BRN | Branch Never (2-cycle NOP) |
| 0x22 | BHI | Branch if Higher (unsigned C+Z=0) |
| 0x23 | BLS | Branch if Lower or Same (unsigned C+Z=1) |
| 0x24 | BCC/BHS | Branch if Carry Clear / Higher or Same |
| 0x25 | BCS/BLO | Branch if Carry Set / Lower |
| 0x26 | BNE | Branch if Not Equal (Z=0) |
| 0x27 | BEQ | Branch if Equal (Z=1) |
| 0x28 | BVC | Branch if Overflow Clear (V=0) |
| 0x29 | BVS | Branch if Overflow Set (V=1) |
| 0x2A | BPL | Branch if Plus (N=0) |
| 0x2B | BMI | Branch if Minus (N=1) |
| 0x2C | BGE | Branch if Greater or Equal signed (N⊕V=0) |
| 0x2D | BLT | Branch if Less Than signed (N⊕V=1) |
| 0x2E | BGT | Branch if Greater Than signed (Z+(N⊕V)=0) |
| 0x2F | BLE | Branch if Less or Equal signed (Z+(N⊕V)=1) |
| 0x8D | BSR | Branch to Subroutine (push PC, branch) |

### CCR Operations (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x0A | CLV | Clear Overflow Flag |
| 0x0B | SEV | Set Overflow Flag |
| 0x0C | CLC | Clear Carry Flag |
| 0x0D | SEC | Set Carry Flag |
| 0x0E | CLI | Clear Interrupt Mask (enable IRQ) |
| 0x0F | SEI | Set Interrupt Mask (disable IRQ) |

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

## Previously Missing Descriptions (COMPLETED ✅)

The original Description.cpp was incomplete. All descriptions below have been added to the sections above:

| Opcode | Mnemonic | Description | Status |
|--------|----------|-------------|--------|
| 0x3D | MUL | Multiply A by B, unsigned result in D | ✅ Added |
| 0x02 | IDIV | Integer Divide D by X, quotient→X, remainder→D | ✅ Added |
| 0x03 | FDIV | Fractional Divide D by X, quotient→X, remainder→D | ✅ Added |
| 0xCC | LDD IMM | Load D with immediate 16-bit value | ✅ Added |
| 0xDC | LDD DIR | Load D from direct address | ✅ Added |
| 0xFC | LDD EXT | Load D from extended address | ✅ Added |
| 0xDD | STD DIR | Store D to direct address | ✅ Added |
| 0xFD | STD EXT | Store D to extended address | ✅ Added |
| 0x3B | RTI | Return from Interrupt | ✅ Added |
| 0x3F | SWI | Software Interrupt | ✅ Added |
| 0x80-0xA0 | SUBA | Subtract from A (all modes) | ✅ Added |
| 0xC0-0xE0 | SUBB | Subtract from B (all modes) | ✅ Added |
| 0x82-0xA2 | SBCA | Subtract with Carry from A (all modes) | ✅ Added |
| 0xC2-0xE2 | SBCB | Subtract with Carry from B (all modes) | ✅ Added |
| 0x85-0xA5 | BITA | Bit Test A (all modes) | ✅ Added |
| 0xC5-0xE5 | BITB | Bit Test B (all modes) | ✅ Added |
| 0x14-0x1F | BSET/BCLR/BRSET/BRCLR | Bit manipulation instructions | ✅ Added |

---

## ⚠️ Bug Fix Applied

**Original dis68hc11 source had swapped IMM/DIR modes for ADCA and ADCB.**
This file has been corrected to match the official Motorola M68HC11 Reference Manual.

See `68HC11_Opcodes_Reference.md` for full details of the bug.

---

*Generated from dis68hc11 source - January 2026*
*Corrected: ADCB IMM/DIR modes fixed January 17, 2026*
