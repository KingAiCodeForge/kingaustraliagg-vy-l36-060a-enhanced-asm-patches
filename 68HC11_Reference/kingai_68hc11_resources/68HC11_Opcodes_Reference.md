# 68HC11 Opcodes Reference (from dis68hc11)

> **Source:** dis68hc11 disassembler - Opcodes.h
> **Purpose:** Complete opcode hex values for VY V6 ECU decompilation
> **⚠️ Note:** dis68hc11 source has bugs - ADCA/ADCB IMM/DIR modes were swapped. This doc is CORRECTED.

---

## Page 0 Opcodes (Single-byte prefix)

### Arithmetic Instructions

| Mnemonic | Hex | Mode | Description | Note |
|----------|-----|------|-------------|------|
| ABA | 0x1B | INH | Add B to A | |
| ABX | 0x3A | INH | Add B to X | |
| ADCA | 0x89 | IMM | Add with Carry to A, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| ADCA | 0x99 | DIR | Add with Carry to A, direct | ⚠️ dis68hc11 said IMM - WRONG |
| ADCA | 0xB9 | EXT | Add with Carry to A, extended | |
| ADCA | 0xA9 | IND,X | Add with Carry to A, indexed X | |
| ADCB | 0xC9 | IMM | Add with Carry to B, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| ADCB | 0xD9 | DIR | Add with Carry to B, direct | ⚠️ dis68hc11 said IMM - WRONG |
| ADCB | 0xF9 | EXT | Add with Carry to B, extended | |
| ADCB | 0xE9 | IND,X | Add with Carry to B, indexed X | |
| ADDA | 0x8B | IMM | Add to A, immediate | |
| ADDA | 0x9B | DIR | Add to A, direct | |
| ADDA | 0xBB | EXT | Add to A, extended | |
| ADDA | 0xAB | IND,X | Add to A, indexed X | |
| ADDB | 0xCB | IMM | Add to B, immediate | |
| ADDB | 0xDB | DIR | Add to B, direct | |
| ADDB | 0xFB | EXT | Add to B, extended | |
| ADDB | 0xEB | IND,X | Add to B, indexed X | |
| ADDD | 0xC3 | IMM | Add to D, immediate | |
| ADDD | 0xD3 | DIR | Add to D, direct | |
| ADDD | 0xF3 | EXT | Add to D, extended | |
| ADDD | 0xE3 | IND,X | Add to D, indexed X | |

### Logic Instructions

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| ANDA | 0x84 | IMM | AND A, immediate |
| ANDA | 0x94 | DIR | AND A, direct |
| ANDA | 0xB4 | EXT | AND A, extended |
| ANDA | 0xA4 | IND,X | AND A, indexed X |
| ANDB | 0xC4 | IMM | AND B, immediate |
| ANDB | 0xD4 | DIR | AND B, direct |
| ANDB | 0xF4 | EXT | AND B, extended |
| ANDB | 0xE4 | IND,X | AND B, indexed X |
| EORA | 0x88 | IMM | XOR A, immediate |
| EORA | 0x98 | DIR | XOR A, direct |
| EORA | 0xB8 | EXT | XOR A, extended |
| EORA | 0xA8 | IND,X | XOR A, indexed X |
| EORB | 0xC8 | IMM | XOR B, immediate |
| EORB | 0xD8 | DIR | XOR B, direct |
| EORB | 0xF8 | EXT | XOR B, extended |
| EORB | 0xE8 | IND,X | XOR B, indexed X |
| ORAA | 0x8A | IMM | OR A, immediate |
| ORAA | 0x9A | DIR | OR A, direct |
| ORAA | 0xBA | EXT | OR A, extended |
| ORAA | 0xAA | IND,X | OR A, indexed X |
| ORAB | 0xCA | IMM | OR B, immediate |
| ORAB | 0xDA | DIR | OR B, direct |
| ORAB | 0xFA | EXT | OR B, extended |
| ORAB | 0xEA | IND,X | OR B, indexed X |

### Shift/Rotate Instructions

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| ASL | 0x78 | EXT | Arithmetic Shift Left, extended |
| ASL | 0x68 | IND,X | Arithmetic Shift Left, indexed X |
| ASLA | 0x48 | INH | Arithmetic Shift Left A |
| ASLB | 0x58 | INH | Arithmetic Shift Left B |
| ASLD | 0x05 | INH | Arithmetic Shift Left D |
| ASR | 0x77 | EXT | Arithmetic Shift Right, extended |
| ASR | 0x67 | IND,X | Arithmetic Shift Right, indexed X |
| ASRA | 0x47 | INH | Arithmetic Shift Right A |
| ASRB | 0x57 | INH | Arithmetic Shift Right B |
| LSR | 0x74 | EXT | Logical Shift Right, extended |
| LSR | 0x64 | IND,X | Logical Shift Right, indexed X |
| LSRA | 0x44 | INH | Logical Shift Right A |
| LSRB | 0x54 | INH | Logical Shift Right B |
| LSRD | 0x04 | INH | Logical Shift Right D |
| ROL | 0x79 | EXT | Rotate Left, extended |
| ROL | 0x69 | IND | Rotate Left, indexed |
| ROLA | 0x49 | INH | Rotate Left A |
| ROLB | 0x59 | INH | Rotate Left B |
| ROR | 0x76 | EXT | Rotate Right, extended |
| ROR | 0x66 | IND | Rotate Right, indexed |
| RORA | 0x46 | INH | Rotate Right A |
| RORB | 0x56 | INH | Rotate Right B |

### Branch Instructions

| Mnemonic | Hex | Condition | Description |
|----------|-----|-----------|-------------|
| BCC | 0x24 | C=0 | Branch if Carry Clear |
| BCS | 0x25 | C=1 | Branch if Carry Set |
| BEQ | 0x27 | Z=1 | Branch if Equal (Zero) |
| BGE | 0x2C | N⊕V=0 | Branch if Greater or Equal (signed) |
| BGT | 0x2E | Z+(N⊕V)=0 | Branch if Greater Than (signed) |
| BHI | 0x22 | C+Z=0 | Branch if Higher (unsigned) |
| BHS | 0x24 | C=0 | Branch if Higher or Same (=BCC) |
| BLE | 0x2F | Z+(N⊕V)=1 | Branch if Less or Equal (signed) |
| BLO | 0x25 | C=1 | Branch if Lower (=BCS) |
| BLS | 0x23 | C+Z=1 | Branch if Lower or Same (unsigned) |
| BLT | 0x2D | N⊕V=1 | Branch if Less Than (signed) |
| BMI | 0x2B | N=1 | Branch if Minus |
| BNE | 0x26 | Z=0 | Branch if Not Equal |
| BPL | 0x2A | N=0 | Branch if Plus |
| BRA | 0x20 | Always | Branch Always |
| BRN | 0x21 | Never | Branch Never |
| BSR | 0x8D | Always | Branch to Subroutine |
| BVC | 0x28 | V=0 | Branch if Overflow Clear |
| BVS | 0x29 | V=1 | Branch if Overflow Set |
| BRSET | 0x12 | DIR | Branch if Bit(s) Set, direct |
| BRSET | 0x1E | IND,X | Branch if Bit(s) Set, indexed |

### Compare Instructions

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| CMPA | 0x81 | IMM | Compare A, immediate |
| CMPA | 0x91 | DIR | Compare A, direct |
| CMPA | 0xB1 | EXT | Compare A, extended |
| CMPA | 0xA1 | IND,X | Compare A, indexed X |
| CMPB | 0xC1 | IMM | Compare B, immediate |
| CMPB | 0xD1 | DIR | Compare B, direct |
| CMPB | 0xF1 | EXT | Compare B, extended |
| CMPB | 0xE1 | IND,X | Compare B, indexed X |
| CPX | 0x8C | IMM | Compare X, immediate |
| CPX | 0x9C | DIR | Compare X, direct |
| CPX | 0xBC | EXT | Compare X, extended |
| CPX | 0xAC | IND | Compare X, indexed |

### Load/Store Instructions

| Mnemonic | Hex | Mode | Description | 
|----------|-----|------|-------------|
| LDAA | 0x86 | IMM | Load A, immediate |
| LDAA | 0x96 | DIR | Load A, direct |
| LDAA | 0xB6 | EXT | Load A, extended |
| LDAA | 0xA6 | IND,X | Load A, indexed X |
| LDAB | 0xC6 | IMM | Load B, immediate |
| LDAB | 0xD6 | DIR | Load B, direct |
| LDAB | 0xF6 | EXT | Load B, extended |
| LDAB | 0xE6 | IND,X | Load B, indexed X |
| LDD | 0xCC | IMM | Load D, immediate |
| LDD | 0xDC | DIR | Load D, direct |
| LDD | 0xFC | EXT | Load D, extended |
| LDD | 0xEC | IND,X | Load D, indexed X |
| LDS | 0x8E | IMM | Load SP, immediate |
| LDS | 0x9E | DIR | Load SP, direct |
| LDS | 0xBE | EXT | Load SP, extended |
| LDS | 0xAE | IND | Load SP, indexed |
| LDX | 0xCE | IMM | Load X, immediate |
| LDX | 0xDE | DIR | Load X, direct |
| LDX | 0xFE | EXT | Load X, extended |
| LDX | 0xEE | IND | Load X, indexed |
| STAA | 0x97 | DIR | Store A, direct |
| STAA | 0xB7 | EXT | Store A, extended |
| STAA | 0xA7 | IND,X | Store A, indexed X |
| STAB | 0xD7 | DIR | Store B, direct |
| STAB | 0xF7 | EXT | Store B, extended |
| STAB | 0xE7 | IND,X | Store B, indexed X |
| STD | 0xDD | DIR | Store D, direct |
| STD | 0xFD | EXT | Store D, extended |
| STD | 0xED | IND,X | Store D, indexed X |
| STS | 0x9F | DIR | Store SP, direct |
| STS | 0xBF | EXT | Store SP, extended |
| STS | 0xAF | IND,X | Store SP, indexed X |
| STX | 0xDF | DIR | Store X, direct |
| STX | 0xFF | EXT | Store X, extended |
| STX | 0xEF | IND | Store X, indexed |

### Subtract Instructions

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| SBA | 0x10 | INH | Subtract B from A |
| SBCA | 0x82 | IMM | Subtract with Carry A, immediate |
| SBCA | 0x92 | DIR | Subtract with Carry A, direct |
| SBCA | 0xB2 | EXT | Subtract with Carry A, extended |
| SBCA | 0xA2 | IND,X | Subtract with Carry A, indexed X |
| SBCB | 0xC2 | IMM | Subtract with Carry B, immediate |
| SBCB | 0xD2 | DIR | Subtract with Carry B, direct |
| SBCB | 0xF2 | EXT | Subtract with Carry B, extended |
| SBCB | 0xE2 | IND,X | Subtract with Carry B, indexed X |
| SUBA | 0x80 | IMM | Subtract A, immediate |
| SUBA | 0x90 | DIR | Subtract A, direct |
| SUBA | 0xB0 | EXT | Subtract A, extended |
| SUBA | 0xA0 | IND,X | Subtract A, indexed X |
| SUBB | 0xC0 | IMM | Subtract B, immediate |
| SUBB | 0xD0 | DIR | Subtract B, direct |
| SUBB | 0xF0 | EXT | Subtract B, extended |
| SUBB | 0xE0 | IND,X | Subtract B, indexed X |
| SUBD | 0x83 | IMM | Subtract D, immediate |
| SUBD | 0x93 | DIR | Subtract D, direct |
| SUBD | 0xB3 | EXT | Subtract D, extended |
| SUBD | 0xA3 | IND,X | Subtract D, indexed X |

### Increment/Decrement/Clear/Test

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| CLR | 0x7F | EXT | Clear, extended |
| CLR | 0x6F | IND | Clear, indexed |
| CLRA | 0x4F | INH | Clear A |
| CLRB | 0x5F | INH | Clear B |
| DECA | 0x4A | INH | Decrement A |
| DECB | 0x5A | INH | Decrement B |
| DES | 0x34 | INH | Decrement SP |
| DEX | 0x09 | INH | Decrement X |
| INC | 0x7C | EXT | Increment, extended |
| INC | 0x6C | IND,X | Increment, indexed X |
| INCA | 0x4C | INH | Increment A |
| INCB | 0x5C | INH | Increment B |
| INS | 0x31 | INH | Increment SP |
| INX | 0x08 | INH | Increment X |
| TST | 0x7D | EXT | Test, extended |
| TST | 0x6D | IND,X | Test, indexed X |
| TSTA | 0x4D | INH | Test A |
| TSTB | 0x5D | INH | Test B |

### Stack Operations

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| PSHA | 0x36 | INH | Push A |
| PSHB | 0x37 | INH | Push B |
| PSHX | 0x3C | INH | Push X |
| PULA | 0x32 | INH | Pull A |
| PULB | 0x33 | INH | Pull B |
| PULX | 0x38 | INH | Pull X |

### Jump/Return/Control

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| JMP | 0x7E | EXT | Jump, extended |
| JMP | 0x6E | IND,X | Jump, indexed X |
| JSR | 0x9D | DIR | Jump to Subroutine, direct |
| JSR | 0xBD | EXT | Jump to Subroutine, extended |
| JSR | 0xAD | IND | Jump to Subroutine, indexed |
| RTI | 0x3B | INH | Return from Interrupt |
| RTS | 0x39 | INH | Return from Subroutine |
| SWI | 0x3F | INH | Software Interrupt |
| WAI | 0x3E | INH | Wait for Interrupt |

### CCR/Transfer Instructions

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| CLI | 0x0E | INH | Clear Interrupt Mask |
| CLV | 0x0A | INH | Clear Overflow Flag |
| SEC | 0x0D | INH | Set Carry |
| SEI | 0x0F | INH | Set Interrupt Mask |
| SEV | 0x0B | INH | Set Overflow |
| TAB | 0x16 | INH | Transfer A to B |
| TAP | 0x06 | INH | Transfer A to CCR |
| TBA | 0x17 | INH | Transfer B to A |
| TPA | 0x07 | INH | Transfer CCR to A |
| TSX | 0x30 | INH | Transfer SP to X |
| TXS | 0x35 | INH | Transfer X to SP |
| XGDX | 0x8F | INH | Exchange D with X |

### Multiply/Divide

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| DAA | 0x19 | INH | Decimal Adjust A |
| FDIV | 0x03 | INH | Fractional Divide |
| IDIV | 0x02 | INH | Integer Divide |
| MUL | 0x3D | INH | Multiply (A × B → D) |

### Special

| Mnemonic | Hex | Mode | Description |
|----------|-----|------|-------------|
| STOP | 0xCF | INH | Stop Clocks |
| TEST | 0x00 | INH | Test (factory use only) |

---

## Page 1 Opcodes (Prefix 0x18)

These require the 0x18 prefix byte for Y-register operations:

| Mnemonic | Hex (after 0x18) | Mode | Description |
|----------|------------------|------|-------------|
| ABY | 0x3A | INH | Add B to Y |
| CPY | 0x8C | IMM | Compare Y, immediate |
| DEY | 0x09 | INH | Decrement Y |
| INY | 0x08 | INH | Increment Y |
| LDAA | 0xA6 | IND,Y | Load A, indexed Y |
| LDY | 0xCE | IMM | Load Y, immediate |
| LDY | 0xDE | DIR | Load Y, direct |
| LDY | 0xFE | EXT | Load Y, extended |
| LDY | 0xEE | IND,Y | Load Y, indexed Y |
| STAA | 0xA7 | IND,Y | Store A, indexed Y |
| STY | 0xDF | DIR | Store Y, direct |
| STY | 0xFF | EXT | Store Y, extended |
| STY | 0xEF | IND,Y | Store Y, indexed Y |
| TSY | 0x30 | INH | Transfer SP to Y |

---

## Quick Hex Lookup Table (Page 0)

| 0x | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A | B | C | D | E | F |
|----|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0x | TEST | - | IDIV | FDIV | LSRD | ASLD | TAP | TPA | INX | DEX | CLV | SEV | CLC | SEC | CLI | SEI |
| 1x | SBA | - | BRSET | - | - | - | TAB | TBA | (18) | DAA | (1A) | ABA | - | - | BRSET | - |
| 2x | BRA | BRN | BHI | BLS | BCC | BCS | BNE | BEQ | BVC | BVS | BPL | BMI | BGE | BLT | BGT | BLE |
| 3x | TSX | INS | PULA | PULB | DES | TXS | PSHA | PSHB | PULX | RTS | ABX | RTI | PSHX | MUL | WAI | SWI |
| 4x | NEGA | - | - | COMA | LSRA | - | RORA | ASRA | ASLA | ROLA | DECA | - | INCA | TSTA | - | CLRA |
| 5x | NEGB | - | - | COMB | LSRB | - | RORB | ASRB | ASLB | ROLB | DECB | - | INCB | TSTB | - | CLRB |
| 6x | NEG | - | - | COM | LSR | - | ROR | ASR | ASL | ROL | DEC | - | INC | TST | JMP | CLR |
| 7x | NEG | - | - | COM | LSR | - | ROR | ASR | ASL | ROL | DEC | - | INC | TST | JMP | CLR |
| 8x | SUBA | CMPA | SBCA | SUBD | ANDA | BITA | LDAA | - | EORA | ADCA | ORAA | ADDA | CPX | BSR | LDS | XGDX |
| 9x | SUBA | CMPA | SBCA | SUBD | ANDA | BITA | LDAA | STAA | EORA | ADCA | ORAA | ADDA | CPX | JSR | LDS | STS |
| Ax | SUBA | CMPA | SBCA | SUBD | ANDA | BITA | LDAA | STAA | EORA | ADCA | ORAA | ADDA | CPX | JSR | LDS | STS |
| Bx | SUBA | CMPA | SBCA | SUBD | ANDA | BITA | LDAA | STAA | EORA | ADCA | ORAA | ADDA | CPX | JSR | LDS | STS |
| Cx | SUBB | CMPB | SBCB | ADDD | ANDB | BITB | LDAB | - | EORB | ADCB | ORAB | ADDB | LDD | - | LDX | STOP |
| Dx | SUBB | CMPB | SBCB | ADDD | ANDB | BITB | LDAB | STAB | EORB | ADCB | ORAB | ADDB | LDD | STD | LDX | STX |
| Ex | SUBB | CMPB | SBCB | ADDD | ANDB | BITB | LDAB | STAB | EORB | ADCB | ORAB | ADDB | LDD | STD | LDX | STX |
| Fx | SUBB | CMPB | SBCB | ADDD | ANDB | BITB | LDAB | STAB | EORB | ADCB | ORAB | ADDB | LDD | STD | LDX | STX |

---

## VY V6 ECU Common Patterns

**RPM Comparison (8-bit):**
```asm
LDAA  $00A2          ; Load ENGINE_RPM (96=LDAA dir)
CMPA  #$F0           ; Compare to 240 (6000 RPM) (81=CMPA imm)
BCS   skip           ; Branch if below (25=BCS)
```

**16-bit Period Load:**
```asm
LDD   $017B          ; Load PERIOD_3X_RAM (DC=LDD dir)
CPD   #$00C8         ; Compare to threshold (1A 83=CPD imm, Page 1A)
```

**EST Output Control:**
```asm
LDAA  $1020          ; Load TCTL1 (B6=LDAA ext)
ORAA  #$20           ; Set OC3 bit (8A=ORAA imm)
STAA  $1020          ; Store back (B7=STAA ext)
```

---

## ⚠️ dis68hc11 Source Code Bug Warning

The original dis68hc11 `Opcodes.h` file contains **swapped IMM/DIR mode** definitions for ADCA and ADCB.

**BUG in dis68hc11 Opcodes.h:**
```cpp
// WRONG - these are reversed!
OP_ADCA_DIR = 0x89,  // Actually IMM!
OP_ADCA_IMM = 0x99,  // Actually DIR!
OP_ADCB_DIR = 0xc9,  // Actually IMM!
OP_ADCB_IMM = 0xd9,  // Actually DIR!
```

**Correct Values (verified against Motorola M68HC11 Reference Manual + dasmfw):**

| Opcode | Correct Mode | Instruction |
|--------|--------------|-------------|
| 0x89 | **IMM** | ADCA #ii |
| 0x99 | **DIR** | ADCA dd |
| 0xA9 | IND,X | ADCA ff,X |
| 0xB9 | EXT | ADCA hhll |
| 0xC9 | **IMM** | ADCB #ii |
| 0xD9 | **DIR** | ADCB dd |
| 0xE9 | IND,X | ADCB ff,X |
| 0xF9 | EXT | ADCB hhll |

**This document contains CORRECTED values** - do not rely on raw dis68hc11 source!

---

## Reference Sources (Verified)

1. **M68HC11E Family Datasheet** - `A:\repos\VY_V6_Assembly_Modding\datasheets\M68HC11E_Family_Datasheet.pdf` (3.5MB, official Freescale)
2. **dasmfw Dasm68HC11.cpp** - `68HC11_Reference\dasmfw\Dasm68HC11.cpp` (authoritative opcode tables)
3. **Ghidra SLEIGH HC11.slaspec** - `68HC11_Reference\ghidra_hc11\HC11.slaspec` (2465 lines, verified)
4. **AN1060 Bootstrap Mode** - `A:\repos\VY_V6_Assembly_Modding\datasheets\AN1060.pdf` (M68HC11 bootstrap)
5. **EB729 Engineering Bulletin** - `A:\repos\VY_V6_Assembly_Modding\datasheets\EB729.pdf` (technical details)

---

*Generated from dis68hc11 source - January 2026*
*Fact-checked and corrected against dasmfw + Motorola datasheets*
*Last Updated: January 17, 2026*
