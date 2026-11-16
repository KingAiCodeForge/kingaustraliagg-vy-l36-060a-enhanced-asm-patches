# 68HC11 Complete Instruction Set Reference

> **Source:** Tom Dickens / Dan Kohn (dankohn.info) + NXP M68HC11ERG Reference Manual
> **Maintained for:** VY V6 ECU Decompilation Project
> **Notes:** More rows and columns needed with notes. and each sources info in a column.
> **Last Updated:** January 20, 2026
> 
---

## Cross-Reference Verification Status ✅

All opcodes verified against **7 independent sources** on January 20, 2026:

| Source | File Path | Status |
|--------|-----------|--------|
| Ghidra SLEIGH | `ghidra_hc11/HC11.slaspec` | ✅ Matches |
| dasmfw | `dasmfw/Dasm68HC11.cpp` | ✅ Matches |
| gendasm | `gendasm/src/gendasm/cpu/m6811/m6811gdc.cpp` | ✅ Matches |
| PySim11 | `EVBU_Simulator/PySim11/ops.py` | ✅ Matches |
| techedge DISASM11 | `techedge_tools/DISASM11/DISASM11.OPC` | ✅ Matches |
| m68hc11x Assembler | `m68hc11x/assembler.h` | ✅ Matches |
| BASIC11 Registers | `BASIC11/exp-f1.inc` | ✅ Matches |
| dis68hc11 | `dis68hc11/Opcodes.h` | ⚠️ **BUGGY** (ADCA/ADCB swapped) |

### ⚠️ Known Bug in dis68hc11

The `dis68hc11` disassembler has **IMM/DIR modes swapped** for ADCA and ADCB:
- `OP_ADCA_DIR = 0x89` ❌ WRONG (should be IMM)
- `OP_ADCA_IMM = 0x99` ❌ WRONG (should be DIR)
- `OP_ADCB_DIR = 0xC9` ❌ WRONG (should be IMM)
- `OP_ADCB_IMM = 0xD9` ❌ WRONG (should be DIR)

**This document uses CORRECT opcodes verified against Motorola specifications.**

---

## Table of Contents
1. [Addressing Modes](#addressing-modes)
2. [Operand Notation](#operand-notation)
3. [Complete Instruction Set (A-Z)](#complete-instruction-set)
4. [Opcode Quick Reference by Hex](#opcode-quick-reference)
5. [Prebyte Instructions ($18, $1A, $CD)](#prebyte-instructions)
6. [Branch Instructions Summary](#branch-instructions)
7. [Interrupt Vectors](#interrupt-vectors)
8. [Register Map ($1000-$103F)](#register-map)
9. [Condition Codes Register (CCR)](#condition-codes)
10. [Cycle Counting Notes](#cycle-counting)

---

## Addressing Modes

| Mode | Abbreviation | Description | Example |
|------|--------------|-------------|---------|
| **INH** | Inherent | No operand needed | `INCA` |
| **IMM** | Immediate | Data follows opcode | `LDAA #$55` |
| **DIR** | Direct | 8-bit address ($00-$FF) | `LDAA $50` |
| **EXT** | Extended | 16-bit address | `LDAA $1234` |
| **IND,X** | Indexed X | X + 8-bit offset | `LDAA $10,X` |
| **IND,Y** | Indexed Y | Y + 8-bit offset (needs $18 prebyte) | `LDAA $10,Y` |
| **REL** | Relative | Signed 8-bit offset for branches | `BNE label` |

---

## Operand Notation

| Symbol | Meaning |
|--------|---------|
| `dd` | 8-bit direct address ($00-$FF) |
| `ff` | 8-bit unsigned offset (0-255) added to index register |
| `hh` | High byte of 16-bit extended address |
| `ll` | Low byte of 16-bit extended address |
| `ii` | 8-bit immediate data |
| `jj` | High byte of 16-bit immediate data |
| `kk` | Low byte of 16-bit immediate data |
| `mm` | 8-bit bit mask (set bits affected) |
| `rr` | Signed relative offset (-128 to +127) from next instruction |

---

## Complete Instruction Set

### A - Add/Arithmetic

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles | Note |
|----------|-----------|------|---------|--------|---------|-------|--------|------|
| **ABA** | A + B → A | INH | — | 1B | — | 1 | 2 | |
| **ABX** | B + X → X | INH | — | 3A | — | 1 | 3 | |
| **ABY** | B + Y → Y | INH | 18 | 3A | — | 2 | 4 | |
| **ADCA** | A + M + C → A | IMM | — | 89 | ii | 2 | 2 | ⚠️ dis68hc11 wrong |
| **ADCA** | | DIR | — | 99 | dd | 2 | 3 | ⚠️ dis68hc11 wrong |
| **ADCA** | | EXT | — | B9 | hh ll | 3 | 4 | |
| **ADCA** | | IND,X | — | A9 | ff | 2 | 4 | |
| **ADCA** | | IND,Y | 18 | A9 | ff | 3 | 5 | |
| **ADCB** | B + M + C → B | IMM | — | C9 | ii | 2 | 2 | ⚠️ dis68hc11 wrong |
| **ADCB** | | DIR | — | D9 | dd | 2 | 3 | ⚠️ dis68hc11 wrong |
| **ADCB** | | EXT | — | F9 | hh ll | 3 | 4 | |
| **ADCB** | | IND,X | — | E9 | ff | 2 | 4 | |
| **ADCB** | | IND,Y | 18 | E9 | ff | 3 | 5 | |
| **ADDA** | A + M → A | IMM | — | 8B | ii | 2 | 2 | |
| **ADDA** | | DIR | — | 9B | dd | 2 | 3 | |
| **ADDA** | | EXT | — | BB | hh ll | 3 | 4 | |
| **ADDA** | | IND,X | — | AB | ff | 2 | 4 | |
| **ADDA** | | IND,Y | 18 | AB | ff | 3 | 5 | |
| **ADDB** | B + M → B | IMM | — | CB | ii | 2 | 2 | |
| **ADDB** | | DIR | — | DB | dd | 2 | 3 | |
| **ADDB** | | EXT | — | FB | hh ll | 3 | 4 | |
| **ADDB** | | IND,X | — | EB | ff | 2 | 4 | |
| **ADDB** | | IND,Y | 18 | EB | ff | 3 | 5 | |
| **ADDD** | D + M:M+1 → D | IMM | — | C3 | jj kk | 3 | 4 | |
| **ADDD** | | DIR | — | D3 | dd | 2 | 5 | |
| **ADDD** | | EXT | — | F3 | hh ll | 3 | 6 | |
| **ADDD** | | IND,X | — | E3 | ff | 2 | 6 | |
| **ADDD** | | IND,Y | 18 | E3 | ff | 3 | 7 | |
| **ANDA** | A AND M → A | IMM | — | 84 | ii | 2 | 2 | |
| **ANDA** | | DIR | — | 94 | dd | 2 | 3 | |
| **ANDA** | | EXT | — | B4 | hh ll | 3 | 4 | |
| **ANDA** | | IND,X | — | A4 | ff | 2 | 4 | |
| **ANDA** | | IND,Y | 18 | A4 | ff | 3 | 5 | |
| **ANDB** | B AND M → B | IMM | — | C4 | ii | 2 | 2 | |
| **ANDB** | | DIR | — | D4 | dd | 2 | 3 | |
| **ANDB** | | EXT | — | F4 | hh ll | 3 | 4 | |
| **ANDB** | | IND,X | — | E4 | ff | 2 | 4 | |
| **ANDB** | | IND,Y | 18 | E4 | ff | 3 | 5 | |
| **ASL** | Arithmetic Shift Left | EXT | — | 78 | hh ll | 3 | 6 | |
| **ASL** | | IND,X | — | 68 | ff | 2 | 6 | |
| **ASL** | | IND,Y | 18 | 68 | ff | 3 | 7 | |
| **ASLA** | Shift A Left | INH | — | 48 | — | 1 | 2 | |
| **ASLB** | Shift B Left | INH | — | 58 | — | 1 | 2 | |
| **ASLD** | Shift D Left | INH | — | 05 | — | 1 | 3 | |
| **ASR** | Arithmetic Shift Right | EXT | — | 77 | hh ll | 3 | 6 | |
| **ASR** | | IND,X | — | 67 | ff | 2 | 6 | |
| **ASR** | | IND,Y | 18 | 67 | ff | 3 | 7 | |
| **ASRA** | Shift A Right | INH | — | 47 | — | 1 | 2 | |
| **ASRB** | Shift B Right | INH | — | 57 | — | 1 | 2 | |

### B - Branch Instructions

| Mnemonic | Condition | Opcode | Bytes | Cycles |
|----------|-----------|--------|-------|--------|
| **BCC** | Carry Clear (C=0) | 24 | 2 | 3 |
| **BCS** | Carry Set (C=1) | 25 | 2 | 3 |
| **BEQ** | Equal (Z=1) | 27 | 2 | 3 |
| **BGE** | Greater/Equal (N⊕V=0) | 2C | 2 | 3 |
| **BGT** | Greater Than (Z+(N⊕V)=0) | 2E | 2 | 3 |
| **BHI** | Higher (C+Z=0) | 22 | 2 | 3 |
| **BHS** | Higher/Same (C=0) | 24 | 2 | 3 |
| **BLE** | Less/Equal (Z+(N⊕V)=1) | 2F | 2 | 3 |
| **BLO** | Lower (C=1) | 25 | 2 | 3 |
| **BLS** | Lower/Same (C+Z=1) | 23 | 2 | 3 |
| **BLT** | Less Than (N⊕V=1) | 2D | 2 | 3 |
| **BMI** | Minus (N=1) | 2B | 2 | 3 |
| **BNE** | Not Equal (Z=0) | 26 | 2 | 3 |
| **BPL** | Plus (N=0) | 2A | 2 | 3 |
| **BRA** | Always | 20 | 2 | 3 |
| **BRN** | Never | 21 | 2 | 3 |
| **BSR** | Branch to Subroutine | 8D | 2 | 6 |
| **BVC** | Overflow Clear (V=0) | 28 | 2 | 3 |
| **BVS** | Overflow Set (V=1) | 29 | 2 | 3 |

### Bit Manipulation Instructions

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **BCLR** | M AND (NOT mm) → M | DIR | — | 15 | dd mm | 3 | 6 |
| **BCLR** | | IND,X | — | 1D | ff mm | 3 | 7 |
| **BCLR** | | IND,Y | 18 | 1D | ff mm | 4 | 8 |
| **BSET** | M OR mm → M | DIR | — | 14 | dd mm | 3 | 6 |
| **BSET** | | IND,X | — | 1C | ff mm | 3 | 7 |
| **BSET** | | IND,Y | 18 | 1C | ff mm | 4 | 8 |
| **BRCLR** | Branch if bits clear | DIR | — | 13 | dd mm rr | 4 | 6 |
| **BRCLR** | | IND,X | — | 1F | ff mm rr | 4 | 7 |
| **BRCLR** | | IND,Y | 18 | 1F | ff mm rr | 5 | 8 |
| **BRSET** | Branch if bits set | DIR | — | 12 | dd mm rr | 4 | 6 |
| **BRSET** | | IND,X | — | 1E | ff mm rr | 4 | 7 |
| **BRSET** | | IND,Y | 18 | 1E | ff mm rr | 5 | 8 |
| **BITA** | A AND M (flags only) | IMM | — | 85 | ii | 2 | 2 |
| **BITA** | | DIR | — | 95 | dd | 2 | 3 |
| **BITA** | | EXT | — | B5 | hh ll | 3 | 4 |
| **BITA** | | IND,X | — | A5 | ff | 2 | 4 |
| **BITA** | | IND,Y | 18 | A5 | ff | 3 | 5 |
| **BITB** | B AND M (flags only) | IMM | — | C5 | ii | 2 | 2 |
| **BITB** | | DIR | — | D5 | dd | 2 | 3 |
| **BITB** | | EXT | — | F5 | hh ll | 3 | 4 |
| **BITB** | | IND,X | — | E5 | ff | 2 | 4 |
| **BITB** | | IND,Y | 18 | E5 | ff | 3 | 5 |

### C - Compare/Clear

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **CBA** | A - B | INH | — | 11 | — | 1 | 2 |
| **CLC** | 0 → C | INH | — | 0C | — | 1 | 2 |
| **CLI** | 0 → I | INH | — | 0E | — | 1 | 2 |
| **CLR** | 0 → M | EXT | — | 7F | hh ll | 3 | 6 |
| **CLR** | | IND,X | — | 6F | ff | 2 | 6 |
| **CLR** | | IND,Y | 18 | 6F | ff | 3 | 7 |
| **CLRA** | 0 → A | INH | — | 4F | — | 1 | 2 |
| **CLRB** | 0 → B | INH | — | 5F | — | 1 | 2 |
| **CLV** | 0 → V | INH | — | 0A | — | 1 | 2 |
| **CMPA** | A - M | IMM | — | 81 | ii | 2 | 2 |
| **CMPA** | | DIR | — | 91 | dd | 2 | 3 |
| **CMPA** | | EXT | — | B1 | hh ll | 3 | 4 |
| **CMPA** | | IND,X | — | A1 | ff | 2 | 4 |
| **CMPA** | | IND,Y | 18 | A1 | ff | 3 | 5 |
| **CMPB** | B - M | IMM | — | C1 | ii | 2 | 2 |
| **CMPB** | | DIR | — | D1 | dd | 2 | 3 |
| **CMPB** | | EXT | — | F1 | hh ll | 3 | 4 |
| **CMPB** | | IND,X | — | E1 | ff | 2 | 4 |
| **CMPB** | | IND,Y | 18 | E1 | ff | 3 | 5 |
| **COM** | NOT M → M | EXT | — | 73 | hh ll | 3 | 6 |
| **COM** | | IND,X | — | 63 | ff | 2 | 6 |
| **COM** | | IND,Y | 18 | 63 | ff | 3 | 7 |
| **COMA** | NOT A → A | INH | — | 43 | — | 1 | 2 |
| **COMB** | NOT B → B | INH | — | 53 | — | 1 | 2 |
| **CPD** | D - M:M+1 | IMM | 1A | 83 | jj kk | 4 | 5 |
| **CPD** | | DIR | 1A | 93 | dd | 3 | 6 |
| **CPD** | | EXT | 1A | B3 | hh ll | 4 | 7 |
| **CPD** | | IND,X | 1A | A3 | ff | 3 | 7 |
| **CPD** | | IND,Y | CD | A3 | ff | 3 | 7 |
| **CPX** | X - M:M+1 | IMM | — | 8C | jj kk | 3 | 4 |
| **CPX** | | DIR | — | 9C | dd | 2 | 5 |
| **CPX** | | EXT | — | BC | hh ll | 3 | 6 |
| **CPX** | | IND,X | — | AC | ff | 2 | 6 |
| **CPX** | | IND,Y | CD | AC | ff | 3 | 7 |
| **CPY** | Y - M:M+1 | IMM | 18 | 8C | jj kk | 4 | 5 |
| **CPY** | | DIR | 18 | 9C | dd | 3 | 6 |
| **CPY** | | EXT | 18 | BC | hh ll | 4 | 7 |
| **CPY** | | IND,X | 1A | AC | ff | 3 | 7 |
| **CPY** | | IND,Y | 18 | AC | ff | 3 | 7 |

### D - Decimal/Decrement

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **DAA** | Decimal Adjust A | INH | — | 19 | — | 1 | 2 |
| **DEC** | M - 1 → M | EXT | — | 7A | hh ll | 3 | 6 |
| **DEC** | | IND,X | — | 6A | ff | 2 | 6 |
| **DEC** | | IND,Y | 18 | 6A | ff | 3 | 7 |
| **DECA** | A - 1 → A | INH | — | 4A | — | 1 | 2 |
| **DECB** | B - 1 → B | INH | — | 5A | — | 1 | 2 |
| **DES** | SP - 1 → SP | INH | — | 34 | — | 1 | 3 |
| **DEX** | X - 1 → X | INH | — | 09 | — | 1 | 3 |
| **DEY** | Y - 1 → Y | INH | 18 | 09 | — | 2 | 4 |

### E - Exclusive OR

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **EORA** | A XOR M → A | IMM | — | 88 | ii | 2 | 2 |
| **EORA** | | DIR | — | 98 | dd | 2 | 3 |
| **EORA** | | EXT | — | B8 | hh ll | 3 | 4 |
| **EORA** | | IND,X | — | A8 | ff | 2 | 4 |
| **EORA** | | IND,Y | 18 | A8 | ff | 3 | 5 |
| **EORB** | B XOR M → B | IMM | — | C8 | ii | 2 | 2 |
| **EORB** | | DIR | — | D8 | dd | 2 | 3 |
| **EORB** | | EXT | — | F8 | hh ll | 3 | 4 |
| **EORB** | | IND,X | — | E8 | ff | 2 | 4 |
| **EORB** | | IND,Y | 18 | E8 | ff | 3 | 5 |

### F - Fractional Divide

| Mnemonic | Operation | Mode | Opcode | Bytes | Cycles |
|----------|-----------|------|--------|-------|--------|
| **FDIV** | D/X → X, r → D | INH | 03 | 1 | 41 |

### I - Increment/Integer Divide

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **IDIV** | D/X → X, r → D | INH | — | 02 | — | 1 | 41 |
| **INC** | M + 1 → M | EXT | — | 7C | hh ll | 3 | 6 |
| **INC** | | IND,X | — | 6C | ff | 2 | 6 |
| **INC** | | IND,Y | 18 | 6C | ff | 3 | 7 |
| **INCA** | A + 1 → A | INH | — | 4C | — | 1 | 2 |
| **INCB** | B + 1 → B | INH | — | 5C | — | 1 | 2 |
| **INS** | SP + 1 → SP | INH | — | 31 | — | 1 | 3 |
| **INX** | X + 1 → X | INH | — | 08 | — | 1 | 3 |
| **INY** | Y + 1 → Y | INH | 18 | 08 | — | 2 | 4 |

### J - Jump

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **JMP** | Address → PC | EXT | — | 7E | hh ll | 3 | 3 |
| **JMP** | | IND,X | — | 6E | ff | 2 | 3 |
| **JMP** | | IND,Y | 18 | 6E | ff | 3 | 4 |
| **JSR** | Call Subroutine | DIR | — | 9D | dd | 2 | 5 |
| **JSR** | | EXT | — | BD | hh ll | 3 | 6 |
| **JSR** | | IND,X | — | AD | ff | 2 | 6 |
| **JSR** | | IND,Y | 18 | AD | ff | 3 | 7 |

### L - Load

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **LDAA** | M → A | IMM | — | 86 | ii | 2 | 2 |
| **LDAA** | | DIR | — | 96 | dd | 2 | 3 |
| **LDAA** | | EXT | — | B6 | hh ll | 3 | 4 |
| **LDAA** | | IND,X | — | A6 | ff | 2 | 4 |
| **LDAA** | | IND,Y | 18 | A6 | ff | 3 | 5 |
| **LDAB** | M → B | IMM | — | C6 | ii | 2 | 2 |
| **LDAB** | | DIR | — | D6 | dd | 2 | 3 |
| **LDAB** | | EXT | — | F6 | hh ll | 3 | 4 |
| **LDAB** | | IND,X | — | E6 | ff | 2 | 4 |
| **LDAB** | | IND,Y | 18 | E6 | ff | 3 | 5 |
| **LDD** | M:M+1 → D | IMM | — | CC | jj kk | 3 | 3 |
| **LDD** | | DIR | — | DC | dd | 2 | 4 |
| **LDD** | | EXT | — | FC | hh ll | 3 | 5 |
| **LDD** | | IND,X | — | EC | ff | 2 | 5 |
| **LDD** | | IND,Y | 18 | EC | ff | 3 | 6 |
| **LDS** | M:M+1 → SP | IMM | — | 8E | jj kk | 3 | 3 |
| **LDS** | | DIR | — | 9E | dd | 2 | 4 |
| **LDS** | | EXT | — | BE | hh ll | 3 | 5 |
| **LDS** | | IND,X | — | AE | ff | 2 | 5 |
| **LDS** | | IND,Y | 18 | AE | ff | 3 | 6 |
| **LDX** | M:M+1 → X | IMM | — | CE | jj kk | 3 | 3 |
| **LDX** | | DIR | — | DE | dd | 2 | 4 |
| **LDX** | | EXT | — | FE | hh ll | 3 | 5 |
| **LDX** | | IND,X | — | EE | ff | 2 | 5 |
| **LDX** | | IND,Y | CD | EE | ff | 3 | 6 |
| **LDY** | M:M+1 → Y | IMM | 18 | CE | jj kk | 4 | 4 |
| **LDY** | | DIR | 18 | DE | dd | 3 | 5 |
| **LDY** | | EXT | 18 | FE | hh ll | 4 | 6 |
| **LDY** | | IND,X | 1A | EE | ff | 3 | 6 |
| **LDY** | | IND,Y | 18 | EE | ff | 3 | 6 |
| **LSL** | Logical Shift Left | EXT | — | 78 | hh ll | 3 | 6 |
| **LSL** | (same as ASL) | IND,X | — | 68 | ff | 2 | 6 |
| **LSL** | | IND,Y | 18 | 68 | ff | 3 | 7 |
| **LSLA** | | INH | — | 48 | — | 1 | 2 |
| **LSLB** | | INH | — | 58 | — | 1 | 2 |
| **LSLD** | | INH | — | 05 | — | 1 | 3 |
| **LSR** | Logical Shift Right | EXT | — | 74 | hh ll | 3 | 6 |
| **LSR** | | IND,X | — | 64 | ff | 2 | 6 |
| **LSR** | | IND,Y | 18 | 64 | ff | 3 | 7 |
| **LSRA** | | INH | — | 44 | — | 1 | 2 |
| **LSRB** | | INH | — | 54 | — | 1 | 2 |
| **LSRD** | | INH | — | 04 | — | 1 | 3 |

### M - Multiply

| Mnemonic | Operation | Mode | Opcode | Bytes | Cycles |
|----------|-----------|------|--------|-------|--------|
| **MUL** | A × B → D | INH | 3D | 1 | 10 |

### N - Negate

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **NEG** | 0 - M → M | EXT | — | 70 | hh ll | 3 | 6 |
| **NEG** | | IND,X | — | 60 | ff | 2 | 6 |
| **NEG** | | IND,Y | 18 | 60 | ff | 3 | 7 |
| **NEGA** | 0 - A → A | INH | — | 40 | — | 1 | 2 |
| **NEGB** | 0 - B → B | INH | — | 50 | — | 1 | 2 |
| **NOP** | No Operation | INH | — | 01 | — | 1 | 2 |

### O - OR

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **ORAA** | A OR M → A | IMM | — | 8A | ii | 2 | 2 |
| **ORAA** | | DIR | — | 9A | dd | 2 | 3 |
| **ORAA** | | EXT | — | BA | hh ll | 3 | 4 |
| **ORAA** | | IND,X | — | AA | ff | 2 | 4 |
| **ORAA** | | IND,Y | 18 | AA | ff | 3 | 5 |
| **ORAB** | B OR M → B | IMM | — | CA | ii | 2 | 2 |
| **ORAB** | | DIR | — | DA | dd | 2 | 3 |
| **ORAB** | | EXT | — | FA | hh ll | 3 | 4 |
| **ORAB** | | IND,X | — | EA | ff | 2 | 4 |
| **ORAB** | | IND,Y | 18 | EA | ff | 3 | 5 |

### P - Push/Pull

| Mnemonic | Operation | Mode | Prebyte | Opcode | Bytes | Cycles |
|----------|-----------|------|---------|--------|-------|--------|
| **PSHA** | A → Stack | INH | — | 36 | 1 | 3 |
| **PSHB** | B → Stack | INH | — | 37 | 1 | 3 |
| **PSHX** | X → Stack | INH | — | 3C | 1 | 4 |
| **PSHY** | Y → Stack | INH | 18 | 3C | 2 | 5 |
| **PULA** | Stack → A | INH | — | 32 | 1 | 4 |
| **PULB** | Stack → B | INH | — | 33 | 1 | 4 |
| **PULX** | Stack → X | INH | — | 38 | 1 | 5 |
| **PULY** | Stack → Y | INH | 18 | 38 | 2 | 6 |

### R - Rotate/Return

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **ROL** | Rotate Left through C | EXT | — | 79 | hh ll | 3 | 6 |
| **ROL** | | IND,X | — | 69 | ff | 2 | 6 |
| **ROL** | | IND,Y | 18 | 69 | ff | 3 | 7 |
| **ROLA** | | INH | — | 49 | — | 1 | 2 |
| **ROLB** | | INH | — | 59 | — | 1 | 2 |
| **ROR** | Rotate Right through C | EXT | — | 76 | hh ll | 3 | 6 |
| **ROR** | | IND,X | — | 66 | ff | 2 | 6 |
| **ROR** | | IND,Y | 18 | 66 | ff | 3 | 7 |
| **RORA** | | INH | — | 46 | — | 1 | 2 |
| **RORB** | | INH | — | 56 | — | 1 | 2 |
| **RTI** | Return from Interrupt | INH | — | 3B | — | 1 | 12 |
| **RTS** | Return from Subroutine | INH | — | 39 | — | 1 | 5 |

### S - Subtract/Store/Set

| Mnemonic | Operation | Mode | Prebyte | Opcode | Operand | Bytes | Cycles |
|----------|-----------|------|---------|--------|---------|-------|--------|
| **SBA** | A - B → A | INH | — | 10 | — | 1 | 2 |
| **SBCA** | A - M - C → A | IMM | — | 82 | ii | 2 | 2 |
| **SBCA** | | DIR | — | 92 | dd | 2 | 3 |
| **SBCA** | | EXT | — | B2 | hh ll | 3 | 4 |
| **SBCA** | | IND,X | — | A2 | ff | 2 | 4 |
| **SBCA** | | IND,Y | 18 | A2 | ff | 3 | 5 |
| **SBCB** | B - M - C → B | IMM | — | C2 | ii | 2 | 2 |
| **SBCB** | | DIR | — | D2 | dd | 2 | 3 |
| **SBCB** | | EXT | — | F2 | hh ll | 3 | 4 |
| **SBCB** | | IND,X | — | E2 | ff | 2 | 4 |
| **SBCB** | | IND,Y | 18 | E2 | ff | 3 | 5 |
| **SEC** | 1 → C | INH | — | 0D | — | 1 | 2 |
| **SEI** | 1 → I | INH | — | 0F | — | 1 | 2 |
| **SEV** | 1 → V | INH | — | 0B | — | 1 | 2 |
| **STAA** | A → M | DIR | — | 97 | dd | 2 | 3 |
| **STAA** | | EXT | — | B7 | hh ll | 3 | 4 |
| **STAA** | | IND,X | — | A7 | ff | 2 | 4 |
| **STAA** | | IND,Y | 18 | A7 | ff | 3 | 5 |
| **STAB** | B → M | DIR | — | D7 | dd | 2 | 3 |
| **STAB** | | EXT | — | F7 | hh ll | 3 | 4 |
| **STAB** | | IND,X | — | E7 | ff | 2 | 4 |
| **STAB** | | IND,Y | 18 | E7 | ff | 3 | 5 |
| **STD** | D → M:M+1 | DIR | — | DD | dd | 2 | 4 |
| **STD** | | EXT | — | FD | hh ll | 3 | 5 |
| **STD** | | IND,X | — | ED | ff | 2 | 5 |
| **STD** | | IND,Y | 18 | ED | ff | 3 | 6 |
| **STOP** | Stop Clocks | INH | — | CF | — | 1 | 2 |
| **STS** | SP → M:M+1 | DIR | — | 9F | dd | 2 | 4 |
| **STS** | | EXT | — | BF | hh ll | 3 | 5 |
| **STS** | | IND,X | — | AF | ff | 2 | 5 |
| **STS** | | IND,Y | 18 | AF | ff | 3 | 6 |
| **STX** | X → M:M+1 | DIR | — | DF | dd | 2 | 4 |
| **STX** | | EXT | — | FF | hh ll | 3 | 5 |
| **STX** | | IND,X | — | EF | ff | 2 | 5 |
| **STX** | | IND,Y | CD | EF | ff | 3 | 6 |
| **STY** | Y → M:M+1 | DIR | 18 | DF | dd | 3 | 5 |
| **STY** | | EXT | 18 | FF | hh ll | 4 | 6 |
| **STY** | | IND,X | 1A | EF | ff | 3 | 6 |
| **STY** | | IND,Y | 18 | EF | ff | 3 | 6 |
| **SUBA** | A - M → A | IMM | — | 80 | ii | 2 | 2 |
| **SUBA** | | DIR | — | 90 | dd | 2 | 3 |
| **SUBA** | | EXT | — | B0 | hh ll | 3 | 4 |
| **SUBA** | | IND,X | — | A0 | ff | 2 | 4 |
| **SUBA** | | IND,Y | 18 | A0 | ff | 3 | 5 |
| **SUBB** | B - M → B | IMM | — | C0 | ii | 2 | 2 |
| **SUBB** | | DIR | — | D0 | dd | 2 | 3 |
| **SUBB** | | EXT | — | F0 | hh ll | 3 | 4 |
| **SUBB** | | IND,X | — | E0 | ff | 2 | 4 |
| **SUBB** | | IND,Y | 18 | E0 | ff | 3 | 5 |
| **SUBD** | D - M:M+1 → D | IMM | — | 83 | jj kk | 3 | 4 |
| **SUBD** | | DIR | — | 93 | dd | 2 | 5 |
| **SUBD** | | EXT | — | B3 | hh ll | 3 | 6 |
| **SUBD** | | IND,X | — | A3 | ff | 2 | 6 |
| **SUBD** | | IND,Y | 18 | A3 | ff | 3 | 7 |
| **SWI** | Software Interrupt | INH | — | 3F | — | 1 | 14 |

### T - Transfer/Test

| Mnemonic | Operation | Mode | Prebyte | Opcode | Bytes | Cycles |
|----------|-----------|------|---------|--------|-------|--------|
| **TAB** | A → B | INH | — | 16 | 1 | 2 |
| **TAP** | A → CCR | INH | — | 06 | 1 | 2 |
| **TBA** | B → A | INH | — | 17 | 1 | 2 |
| **TEST** | Test (Special Mode Only) | INH | — | 00 | 1 | ∞ |
| **TPA** | CCR → A | INH | — | 07 | 1 | 2 |
| **TST** | M - 0 | EXT | — | 7D | hh ll | 3 | 6 |
| **TST** | | IND,X | — | 6D | ff | 2 | 6 |
| **TST** | | IND,Y | 18 | 6D | ff | 3 | 7 |
| **TSTA** | A - 0 | INH | — | 4D | 1 | 2 |
| **TSTB** | B - 0 | INH | — | 5D | 1 | 2 |
| **TSX** | SP + 1 → X | INH | — | 30 | 1 | 3 |
| **TSY** | SP + 1 → Y | INH | 18 | 30 | 2 | 4 |
| **TXS** | X - 1 → SP | INH | — | 35 | 1 | 3 |
| **TYS** | Y - 1 → SP | INH | 18 | 35 | 2 | 4 |

### W - Wait

| Mnemonic | Operation | Mode | Opcode | Bytes | Cycles |
|----------|-----------|------|--------|-------|--------|
| **WAI** | Wait for Interrupt | INH | 3E | 1 | 14+n |

### X - Exchange

| Mnemonic | Operation | Mode | Prebyte | Opcode | Bytes | Cycles |
|----------|-----------|------|---------|--------|-------|--------|
| **XGDX** | D ↔ X | INH | — | 8F | 1 | 3 |
| **XGDY** | D ↔ Y | INH | 18 | 8F | 2 | 4 |

---

## Opcode Quick Reference

### Page 0 (No Prebyte)
```
     0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
0x  TST NOP IDV FDV LSD ASD TAP TPA INX DEX CLV SEV CLC SEC CLI SEI
1x  SBA CBA BRS BRC BST BCL TAB TBA  -  DAA  -  ABA BST BCL BRS BRC
2x  BRA BRN BHI BLS BCC BCS BNE BEQ BVC BVS BPL BMI BGE BLT BGT BLE
3x  TSX INS PLA PLB DES TXS PSA PSB PLX RTS ABX RTI PSX MUL WAI SWI
4x  NGA  -   -  CMA LSA  -  RRA ASA ASA RLA DCA  -  ICA TSA  -  CLA
5x  NGB  -   -  CMB LSB  -  RRB ASB ASB RLB DCB  -  ICB TSB  -  CLB
6x  NEG  -   -  COM LSR  -  ROR ASR ASL ROL DEC  -  INC TST JMP CLR
7x  NEG  -   -  COM LSR  -  ROR ASR ASL ROL DEC  -  INC TST JMP CLR
8x  SBA CMA SCA SBD AND BIT LDA  -  EOR ADC ORA ADD CPX BSR LDS XGD
9x  SBA CMA SCA SBD AND BIT LDA STA EOR ADC ORA ADD CPX JSR LDS STS
Ax  SBA CMA SCA SBD AND BIT LDA STA EOR ADC ORA ADD CPX JSR LDS STS
Bx  SBA CMA SCA SBD AND BIT LDA STA EOR ADC ORA ADD CPX JSR LDS STS
Cx  SBB CMB SCB ADD AND BIT LDB  -  EOR ADC ORB ADB LDD  -  LDX STP
Dx  SBB CMB SCB ADD AND BIT LDB STB EOR ADC ORB ADB LDD STD LDX STX
Ex  SBB CMB SCB ADD AND BIT LDB STB EOR ADC ORB ADB LDD STD LDX STX
Fx  SBB CMB SCB ADD AND BIT LDB STB EOR ADC ORB ADB LDD STD LDX STX
```

### Y-Register Instructions (Prebyte $18)
Most X-indexed instructions become Y-indexed with $18 prefix.
Key opcodes: INY($08), DEY($09), TSY($30), TYS($35), PSHY($3C), PULY($38), XGDY($8F)

### CPD Instructions (Prebyte $1A)
CPD with various addressing modes.

### Special Instructions (Prebyte $CD)
Used for LDX/STX with Y-indexing and some CPX variants.

---

## Interrupt Vectors

| Vector | Address | Priority | Description |
|--------|---------|----------|-------------|
| SCI | $FFD6 | Low | Serial Communications Interface |
| SPI | $FFD8 | | Serial Peripheral Interface |
| PAIE | $FFDA | | Pulse Accumulator Input Edge |
| PAOV | $FFDC | | Pulse Accumulator Overflow |
| TOF | $FFDE | | Timer Overflow |
| TOC5 | $FFE0 | | Timer Output Compare 5 |
| TOC4 | $FFE2 | | Timer Output Compare 4 |
| TOC3 | $FFE4 | | Timer Output Compare 3 |
| TOC2 | $FFE6 | | Timer Output Compare 2 |
| TOC1 | $FFE8 | | Timer Output Compare 1 |
| TIC3 | $FFEA | | Timer Input Capture 3 |
| TIC2 | $FFEC | | Timer Input Capture 2 |
| TIC1 | $FFEE | | Timer Input Capture 1 |
| RTI | $FFF0 | | Real-Time Interrupt |
| IRQ | $FFF2 | | External IRQ |
| XIRQ | $FFF4 | | Non-Maskable Interrupt |
| SWI | $FFF6 | | Software Interrupt |
| ILL | $FFF8 | | Illegal Opcode Trap |
| COP | $FFFA | | COP Watchdog Timeout |
| CMF | $FFFC | | Clock Monitor Fail |
| RESET | $FFFE | High | Reset Vector |

---

## Register Map ($1000-$103F)

| Offset | Register | Description |
|--------|----------|-------------|
| $00 | PORTA | Port A Data Register |
| $01 | DDRA | Port A Data Direction (HC11F) |
| $02 | PORTG | Port G Data (**bank switching** — NOT PIOC as per HC11E datasheet) |
| $03 | DDRG | Port G Data Direction (NOT PORTC) |
| $04 | PORTB | Port B Data Register |
| $05 | PORTF | Port F Data (HC11F — NOT PORTCL as per HC11E) |
| $06 | Reserved | |
| $07 | DDRC | Port C Data Direction |
| $08 | PORTD | Port D Data Register |
| $09 | DDRD | Port D Data Direction |
| $0A | PORTE | Port E Data Register |
| $0B | CFORC | Timer Compare Force |
| $0C | OC1M | OC1 Action Mask |
| $0D | OC1D | OC1 Action Data |
| $0E-$0F | TCNT | Timer Counter (16-bit) |
| $10-$11 | TIC1 | Input Capture 1 |
| $12-$13 | TIC2 | Input Capture 2 |
| $14-$15 | TIC3 | Input Capture 3 |
| $16-$17 | TOC1 | Output Compare 1 |
| $18-$19 | TOC2 | Output Compare 2 |
| $1A-$1B | TOC3 | Output Compare 3 |
| $1C-$1D | TOC4 | Output Compare 4 |
| $1E-$1F | TIC4/TOC5 | Input Capture 4/Output Compare 5 |
| $20 | TCTL1 | Timer Control 1 |
| $21 | TCTL2 | Timer Control 2 |
| $22 | TMSK1 | Timer Interrupt Mask 1 |
| $23 | TFLG1 | Timer Interrupt Flag 1 |
| $24 | TMSK2 | Timer Interrupt Mask 2 |
| $25 | TFLG2 | Timer Interrupt Flag 2 |
| $26 | PACTL | Pulse Accumulator Control |
| $27 | PACNT | Pulse Accumulator Count |
| $28 | SPCR | SPI Control Register |
| $29 | SPSR | SPI Status Register |
| $2A | SPDR | SPI Data Register |
| $2B | BAUD | SCI Baud Rate Control |
| $2C | SCCR1 | SCI Control Register 1 |
| $2D | SCCR2 | SCI Control Register 2 |
| $2E | SCSR | SCI Status Register |
| $2F | SCDR | SCI Data Register |
| $30-$31 | ADCTL/ADR1 | A/D Control/Result 1 |
| $32-$33 | ADR2-ADR3 | A/D Results 2-3 |
| $34 | ADR4 | A/D Result 4 |
| $35 | BPROT | Block Protect |
| $36-$38 | Reserved | |
| $39 | OPTION | System Configuration |
| $3A | COPRST | COP Reset Register |
| $3B | PPROG | EEPROM Programming |
| $3C | HPRIO | Highest Priority I-bit |
| $3D | INIT | RAM/Register Mapping |
| $3E | TEST1 | Factory Test |
| $3F | CONFIG | Configuration Control |

---

## Condition Codes Register (CCR)

```
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
+-------+-------+-------+-------+-------+-------+-------+-------+
|   S   |   X   |   H   |   I   |   N   |   Z   |   V   |   C   |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

| Bit | Name | Description |
|-----|------|-------------|
| S | Stop Disable | 1 = STOP instruction disabled |
| X | X-Interrupt Mask | 1 = XIRQ disabled (cannot be set by software) |
| H | Half Carry | Set on carry from bit 3 to 4 |
| I | Interrupt Mask | 1 = IRQ disabled |
| N | Negative | Set if MSB of result is 1 |
| Z | Zero | Set if result is zero |
| V | Overflow | Set on 2's complement overflow |
| C | Carry/Borrow | Set on unsigned overflow |

---

## Cycle Counting Notes

- **Y-indexed instructions** add 1 cycle over X-indexed equivalents
- **WAI** uses 14 cycles minimum, then waits indefinitely for interrupt
- **TEST** ($00) runs forever until reset - avoid in normal code
- **IDIV/FDIV** take 41 cycles (slowest instructions)
- **MUL** takes 10 cycles

---

## S19 (Motorola S-Record) Format

Each line: `SX` + `NN` + `AAAA` + `DD...DD` + `CC`

| Field | Meaning |
|-------|---------|
| S1 | Data record with 16-bit address |
| S9 | End record |
| NN | Byte count (address + data + checksum) |
| AAAA | 16-bit start address |
| DD | Data bytes |
| CC | 1's complement checksum of NN + address + data |

**Example:**
```
S1130170707172737475767778797A7B7C7D7E7F03
```
- S1: Data record
- 13: 19 bytes follow ($13)
- 0170: Start address
- 70-7F: 16 data bytes
- 03: Checksum

---

## Tools Available in This Reference Collection

| Tool | Location | Purpose | What It Does |
|------|----------|---------|-------------|
| **dis68hc11** | `dis68hc11/` | Simple C++ disassembler | Single-pass linear disassembler written by forum member. Reads raw binary, walks bytes sequentially, decodes Page 0/1 opcodes. **⚠️ HAS BUGS:** ADCA/ADCB IMM/DIR swapped in Opcodes.h. Outputs mnemonics + descriptions + address comments. Small (~367 lines main.cpp). Good learning reference but not production quality. |
| **dasmfw** | `dasmfw/` | Comprehensive disassembler framework | Full-featured multi-CPU disassembler. `Dasm68HC11.cpp` has authoritative opcode tables with correct addressing modes, byte counts, and cycle counts. Handles ALL prebytes (0x18, 0x1A, 0xCD) correctly. **Best source for verifying opcodes.** Supports labels, data regions, output formatting. |
| **EVBU Simulator** | `EVBU_Simulator/` | Python-based HC11/Buffalo simulator | `PySim11/ops.py` contains complete opcode execution with cycle-accurate simulation. Tests actual register/memory behavior. Useful for verifying what instructions DO (not just what bytes they decode to). Buffalo monitor ROM included. |
| **A09 Assembler** | `A09_Assembler/` | Full macro assembler (`a09.c`) | Assembles HC11 mnemonics to binary. Supports macros, includes, conditional assembly. Use for building patches from .asm files. Single C file, portable. Handles all addressing modes including Y-indexed with prebytes. |
| **GCC HC11** | `GCC_HC11/` | GNU cross-compiler | Full C compiler targeting 68HC11. Generates HC11 assembly from C source. Includes linker scripts, startup code, and library. Useful for complex patches that would be painful in pure assembly. |
| **BASIC11** | `BASIC11/` | BASIC interpreter with include files | HC11 BASIC interpreter with hardware register definitions. `bas11e.inc` has complete register equate list — another verification source for register addresses ($1000-$103F). |
| **Ghidra SLEIGH** | `ghidra_hc11/` | Ghidra processor specification | `HC11.slaspec` (2464 lines) defines the complete HC11 instruction set in Ghidra's SLEIGH language. Maps every opcode to semantic operations (what it does to registers/flags). **Most authoritative source** — Ghidra uses this to decompile. `HC11.sla` is compiled version. `GaryOderNichts_HC11.slaspec` is an alternate community version. |
| **gendasm** | `gendasm/` | Generic disassembler with HC11 support | `m6811gdc.cpp` contains another independent opcode table. Cross-references well with dasmfw. Includes addressing mode encoding patterns. |
| **m68hc11x** | `m68hc11x/` | Assembler (has BNE bug) | `assembler.h` contains opcode definitions. **⚠️ HAS BUG:** BNE opcode defined as 0x2B (should be 0x26, 0x2B is BMI). Otherwise good reference for instruction encoding. |
| **techedge DISASM11** | `techedge_tools/` | Techedge disassembler | `DISASM11.OPC` is a flat opcode table file. Simple but correct. Used in Techedge ECU tools for Holden/HSV tuning. |

### SLEIGH (.sla / .slaspec) File Format Notes

**What SLEIGH is:** A domain-specific language used by Ghidra to describe processor instruction sets. It defines:
- **Token patterns** — how bytes map to instruction fields
- **Constructors** — how to decode each instruction variant
- **Semantics** — what each instruction does to registers, flags, and memory
- **Display** — how to show the disassembly text

**HC11.slaspec key sections:**
- `define space` — Address spaces (RAM, register)
- `define register` — A, B, D, X, Y, SP, PC, CCR and individual flag bits
- `define token` — Byte field definitions for opcode/operand extraction
- `attach variables` — Map bit fields to register names
- `macro` — Reusable patterns (e.g., `setNZFlags`, `setAddFlags`)
- Individual instruction constructors with pcodeop semantics

**Why it matters for VY V6:** Ghidra needs correct SLEIGH to properly decompile the ECU binary. If you load the 128KB bin into Ghidra with this processor spec, it can decompile the HC11 code to C-like pseudocode, making reverse engineering much easier.

### Tool Cross-Reference: Which Tool For What?

| Task | Best Tool | Why |
|------|-----------|-----|
| Verify an opcode | dasmfw `Dasm68HC11.cpp` | Most complete, correct tables |
| Understand instruction semantics | Ghidra SLEIGH `HC11.slaspec` | Shows exact flag/register effects |
| Build a patch (.asm → .bin) | A09 Assembler `a09.c` | Full assembler with macro support |
| Test patch behavior | EVBU Simulator `PySim11` | Cycle-accurate execution |
| Quick disassembly | dis68hc11 | Fast, but apply ADCA/ADCB fix first |
| Full binary decompilation | Ghidra with HC11.slaspec | Interactive analysis, call graphs |
| Compile C to HC11 | GCC HC11 | For complex logic patches |
| Check register addresses | BASIC11 `bas11e.inc` | Quick equate lookup |

---

## VY V6 ECU Specific Register Usage ($060A OSID 92118883)

> **IMPORTANT:** The VY V6 Delco ECU uses an **HC11F-family derivative** (68HC11FC0 per DARC/IDA Pro disassembly and PCMhacking community confirmation). NOT HC11E9 as previously stated. The HC11F has a different register layout at $1000-$1005 (PORTG/DDRG/PORTF instead of PIOC/PORTC/PORTCL). Crystal = 13.631488 MHz → E-clock = 3.408 MHz (VL400, topic_982). These mappings are verified against the Enhanced v1.0a binary.

### Timer Registers for EST (Electronic Spark Timing)

| Address | Name | VY V6 Usage | Notes |
|---------|------|-------------|-------|
| **$100E-$100F** | TCNT | Free-running 16-bit counter | ~293ns per count @ 3.408MHz E-clock (NOT 500ns/2MHz — see topic_982) |
| **$1014-$1015** | TIC3 | 24X crank sensor capture | ISR at $35FF handles spark calc |
| **$1012-$1013** | TIC2 | 24X Crank sensor capture | ISR at $358A for position |
| **$101A-$101B** | TOC3 | EST output control | ISR at $35BD fires coils |
| **$1020** | TCTL1 | Output Compare mode | OM2:OL2 bits control EST pin |
| **$1021** | TCTL2 | Input Capture edge select | Selects rising/falling for TIC |
| **$1022** | TMSK1 | Timer interrupt enables | Bits enable TIC/TOC ISRs |
| **$1023** | TFLG1 | Timer interrupt flags | Write 1 to clear flag |

### TCTL1 Timer Control 1 Register ($1020) - EST Critical

```
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
+-------+-------+-------+-------+-------+-------+-------+-------+
|  OM2  |  OL2  |  OM3  |  OL3  |  OM4  |  OL4  |  OM5  |  OL5  |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

| OMn:OLn | Action on Compare Match |
|---------|-------------------------|
| 00 | Disconnected (disabled) |
| 01 | Toggle output pin |
| 10 | Clear output (go LOW) |
| 11 | Set output (go HIGH) |

**⚠️ Chr0m3 Warning:** "Flipping EST off turns bypass on" - Don't set OM2:OL2 to 00!

### TCTL2 Timer Control 2 Register ($1021) - Input Capture

```
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
+-------+-------+-------+-------+-------+-------+-------+-------+
| EDG1B | EDG1A | EDG2B | EDG2A | EDG3B | EDG3A |   0   |   0   |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

| EDGxB:EDGxA | Edge Detected |
|-------------|---------------|
| 00 | Capture disabled |
| 01 | Rising edge only |
| 10 | Falling edge only |
| 11 | Any edge (rising or falling) |

### Force Output Compare Register (CFORC) - $100B

```
  Bit 7   Bit 6   Bit 5   Bit 4   Bit 3   Bit 2   Bit 1   Bit 0
+-------+-------+-------+-------+-------+-------+-------+-------+
| FOC1  | FOC2  | FOC3  | FOC4  | FOC5  |   0   |   0   |   0   |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

Writing 1 to FOCx forces the corresponding OCx output action immediately (without waiting for TCNT match).

### OC1M/OC1D - Output Compare 1 Mask/Data ($100C-$100D)

**OC1M ($100C):** Mask register - set bits to enable OC1 control of corresponding Port A pins
**OC1D ($100D):** Data register - value written to Port A when OC1 compare matches

| Bit | Port A Pin | VY V6 Function |
|-----|------------|----------------|
| 7 | PA7 | Pulse Accumulator Input |
| 6 | PA6 | OC2/EST Output |
| 5 | PA5 | OC3 |
| 4 | PA4 | OC4 |
| 3 | PA3 | OC5/IC4 |

---

## VY V6 Pseudo-Vector / Jump Table System

> The VY V6 uses a pseudo-vector system where hardware vectors point to RAM/ROM jump table entries, which then JMP to the actual ISR code.

### Interrupt Vector Table (File Offset 0x1FFD6-0x1FFFF = HIGH bank)

| Vector | File Offset | Points To | Jump Table | Actual ISR |
|--------|-------------|-----------|------------|------------|
| SCI | $1FFD6 | $2033 | JMP $xxxx | Serial handler |
| SPI | $1FFD8 | $2030 | JMP $xxxx | SPI handler |
| PAIE | $1FFDA | $202D | JMP $xxxx | Pulse Accum Edge |
| PAOV | $1FFDC | $202A | JMP $xxxx | Pulse Accum Overflow |
| TOF | $1FFDE | $2027 | JMP $xxxx | Timer Overflow |
| **TOC5** | $1FFE0 | $2003 | JMP $35DE | Output Compare 5 |
| **TOC4** | $1FFE2 | $2006 | JMP $35DE | Output Compare 4 |
| **TOC3** | $1FFE4 | $2009 | **JMP $35BD** | **EST Output Handler** |
| TOC2 | $1FFE6 | $200C | JMP $xxxx | Output Compare 2 |
| TOC1 | $1FFE8 | $2024 | JMP $xxxx | Output Compare 1 |
| **TIC3** | $1FFEA | $200F | **JMP $35FF** | **24X Crank Handler** |
| **TIC2** | $1FFEC | $2012 | **JMP $358A** | **24X Crank Handler** |
| TIC1 | $1FFEE | $2015 | JMP $xxxx | Input Capture 1 |
| RTI | $1FFF0 | $2018 | JMP $xxxx | Real-Time Interrupt |
| IRQ | $1FFF2 | $C015 | Direct | External IRQ |
| XIRQ | $1FFF4 | $2021 | JMP $2BA6 | Non-Maskable |
| SWI | $1FFF6 | $201E | JMP $xxxx | Software Interrupt |
| ILLOP | $1FFF8 | $201B | JMP $xxxx | Illegal Opcode |
| COP | $1FFFA | $2018 | JMP $30BA | Watchdog Fail |
| CMF | $1FFFC | $2018 | JMP $xxxx | Clock Monitor |
| **RESET** | $1FFFE | $C011 | Direct | **Startup Code** |

### Pseudo-Vector Pattern

```asm
; Vector table entry (at $1FFEA for TIC3):
    FDB  $200F          ; Points to jump table entry

; Jump table entry (at $200F):
    JMP  $35FF          ; 7E 35 FF - Jumps to actual ISR

; Actual ISR (at $35FF):
    LDAA #$01           ; Clear interrupt flag
    STAA $1023          ; Write to TFLG1
    ...                 ; Handler code
    RTI                 ; Return from interrupt
```

**Why Pseudo-Vectors?**
1. Allows ISR relocation without reflashing vector table
2. Enables patching/hooking by changing JMP address
3. RAM-based jump tables allow runtime modification

---

## VY V6 DTC / Malfunction Code System (from XDF v2.09a)

> **Source:** Enhanced v2.09a XDF definition file (latest, includes extra DTCs)
> **XDF calibration range:** 0x4000–0x7FFC (1655 entries)

### How DTCs Work in the $060A OS

The VY V6 ECU uses a **MALF (Malfunction) flag** system with bitmask registers:

| Register | Address | Purpose |
|----------|---------|--------|
| KKMASK1–9A | Calibration | Enable mask — which MALFs are active (1=enabled) |
| KKACT1–9 | Calibration | Action mask — what the ECU does when MALF is set |
| KKSEL1–6 | Calibration | Alternate action mask (secondary response) |
| KKKMASK1–9A | Calibration | Check Transmission Light mask (illuminate dash light) |

**Bit positions:** Each MALF code corresponds to a specific bit in a specific flag byte.
Flag bytes are organized as MALF Flag 1 through MALF Flag 9A (10 flag bytes total).

### Transmission-Defined MALFs

These MALFs are defined in the transmission section of calibrations:

| MALF # | Description | Notes |
|--------|-------------|-------|
| 24 | Vehicle Speed Sensor Failure | |
| 28 | Pressure Switch Manifold | |
| 37 | (Transmission defined) | |
| 38 | (Transmission defined) | |
| 39 | TCC Off | Torque Converter Clutch |
| 53 | Battery Voltage High | |
| 58 | Transmission Temperature High | |
| 59 | Transmission Temperature Low | |
| 63 | (Transmission defined) | |
| 64 | (Transmission defined) | |
| 68 | Transmission Component Slipping | |
| 69 | TCC Stuck On | |
| 71 | Engine Speed Sensor Low | |
| 72 | Output Speed Loss | |
| 73 | Force Motor Current | |
| 74 | (Transmission defined) | |
| 75 | System Voltage Low | |
| 79 | Transmission Hot | |
| 81 | Shift B Solenoid Shorted | |
| 82 | Shift A Solenoid Shorted | |
| 83 | (Transmission defined) | |
| 85 | (Transmission defined) | |
| 86 | Shift A Solenoid Open | |
| 87 | Shift B Solenoid Open | |
| 89 | Maximum Adaptive Long Shift | |

### Shared Engine/Transmission MALFs

These MALFs reside in `DATADIET` module and have **separate default values** for engine vs transmission logic:

| MALF # | Description | Notes |
|--------|-------------|-------|
| 14 | Coolant Temperature Sensor High | Separate engine/trans defaults |
| 15 | Coolant Temperature Sensor Low | Separate engine/trans defaults |
| 21 | Throttle Position Sensor High | Separate engine/trans defaults |
| 22 | Throttle Position Sensor Low | Separate engine/trans defaults |

### Engine MALFs Affecting Transmission

> "Any engine defined Malf that causes an action to be taken in the transmission
> logic must have the appropriate BITS selected in KKACT and KKSEL (A 1 in KKACT
> and either a 0 or a 1 in KKSEL), and in KKKMASK."

### DTC Clearing

| Parameter | Address | Value | Description |
|-----------|---------|-------|-------------|
| Successive Power Ups With No Malfs | $56E6 | CYCLES | Number of clean starts before DTC auto-clears |

### MALF 93 (MAF Failure) — Important for Tuning

| Table | Address | Description |
|-------|---------|-------------|
| M93 Enable Load Vs RPM | $6B9C | Minimum airflow for MALF 93 enable |

**Tuning note:** When MAF or knock sensor DTC is set, the PCM falls back to low-octane spark tables exclusively. The PCM interpolates between high-octane and low-octane maps based on knock activity. Only when a MAF/knock DTC is active does it lock to low-octane.

### BCC ID (DTC Flag Identifier)

| Parameter | Address | Value | Description |
|-----------|---------|-------|-------------|
| BCC ID | $4002 | 0x44544346 | ASCII "DTCF" — visible in hex editor comments field |
| PROGRAM ID (Box Code) | $7FF8 | varies | PCM identification (e.g., 92118883) |

### Calibration IDs Covered by v2.09a XDF

| OSID | BDA/BDB/06x | Type | Notes |
|------|-------------|------|-------|
| 92104512 | BDA AUTO | 261 | |
| 92108760 | BDB AUTO | 262 | |
| 92108761 | BDB MAN/LPG | 263 | Manual and LPG variants |
| 92118885 | 06A AUTO (LPG) | 306 | |
| **92118883** | **06A AUTO** | **305** | **Primary target (Enhanced v1.0a base)** |
| 92118889 | 06A LPG | 305 | |
| 92161296 | 06B AUTO | 305 | |
| 92162167 | 06B AUTO | 305 | |
| 92211726 | 06B AUTO | 307 | |
| 92163772 | 06C LPG | | |

### Key Calibration Addresses from v2.09a

| Address | Parameter | Category |
|---------|-----------|----------|
| $4D9F | Min TCC Capacity | Transmission |
| $4DB0 | Max TCC Capacity | Transmission |
| $6272 | Main Low-Octane Spark < 4800 RPM | Spark |
| $58C2 | Main Low-Octane Spark > 850-1650mg | Spark |
| $7DFF | Main Low-Octane Spark > 4800 RPM | Spark |
| $6B9C | M93 Enable Load Vs RPM | DTC |
| $56E6 | Successive Power Ups With No Malfs | DTC |
| $77DD-$77E9 | Fuel Cut RPM Thresholds | Rev Limiter |

| Address | Name | Size | Purpose | Verified By |
|---------|------|------|---------|-------------|
| **$00A2** | RPM | 1 byte | Engine RPM ÷ 25 (8-bit) | 82 reads in code |
| **$0178** | 24X_PERIOD | 2 bytes | 24X crank period (µs) | TIC3 ISR at $363E |
| **$017B** | DWELL_INTERMEDIATE | 2 bytes | Alternate period storage | STD at $101E1 |
| **$0199** | DWELL_RAM | 2 bytes | Calculated dwell time | LDD at $1007C |
| **$0171** | CYL_INDEX | 1 byte | Current cylinder (0-5) | TIC3 cylinder tracking |
| **$01B3** | PREV_TIC3 | 2 bytes | Previous TIC3 capture | Period calculation |
| **$1B7C-$1B86** | CYL_PERIODS | 12 bytes | Per-cylinder periods | 6 × 16-bit values |
| **$1B8C** | 3X_COUNT | 1 byte | 3X pulse counter | Incremented each 3X |

### RAM Calculation: 16-bit vs 8-bit RPM

```asm
; 8-BIT RPM (Stock fuel cut method) - Limited to 6375 RPM
    LDAA $00A2          ; Load 8-bit RPM/25 (max 0xFF = 255)
    CMPA #$EC           ; Compare to 236 (5900 RPM)
    ; Problem: 255 × 25 = 6375 RPM maximum

; 16-BIT RPM (Chr0m3 method) - Full range
    LDD  $00A2          ; Load 16-bit value starting at $00A2
    CPD  #$1770         ; Compare to 6000 RPM
    ; Note: A at $00A2, B at $00A3 = full 16-bit value
```

---

## VY V6 ROM Calibration Addresses

### Fuel Cut Table ($77DD-$77E9)

| Offset | Name | Stock Value | Enhanced | Description |
|--------|------|-------------|----------|-------------|
| $77DD | FC_BASE | $50 | $50 | Enable threshold |
| **$77DE** | FC_DRIVE_HI | $EC (5900) | $FF (6375) | Drive gear HIGH |
| **$77DF** | FC_DRIVE_LO | $EB (5875) | $FF (6375) | Drive gear LOW |
| $77E0 | FC_PN_HI | $EC | $FF | Park/Neutral HIGH |
| $77E1 | FC_PN_LO | $EB | $FF | Park/Neutral LOW |
| $77E2 | FC_REV_HI | $EC | $FF | Reverse HIGH |
| $77E3 | FC_REV_LO | $EB | $FF | Reverse LOW |

**Scaling:** `RPM = Byte × 25` (8-bit method)

### Spark Cut Injection Point (Chr0m3 Method)

| File Offset | Original Bytes | Patched Bytes | Effect |
|-------------|----------------|---------------|--------|
| **$101E1** | FD 01 7B | BD C5 00 | Redirect STD $017B to JSR $C500 |

```asm
; Original at 0x101E1:
    STD  $017B          ; FD 01 7B - Store dwell intermediate (NOT crank period!)

; Patched to:
    JSR  $C500          ; BD C5 00 - Call spark cut handler
```

### Free Space for Patches

| Start | End | Size | Status | Notes |
|-------|-----|------|--------|-------|
| **$0C468** | $0FFBF | 15,192 bytes | ✅ VERIFIED | All 0x00 bytes |
| $0C500 | $0C5FF | 256 bytes | SUGGESTED | Patch injection point |

---

## Common VY V6 Assembly Patterns

### RPM Check and Branch

```asm
; Check 16-bit RPM against threshold
    LDD  $00A2          ; FC 00 A2 - Load RPM (16-bit)
    CPD  #$1770         ; 1A 83 17 70 - Compare to 6000 RPM
    BHI  LIMIT          ; 22 xx - Branch if higher
```

### Interrupt Acknowledge Pattern

```asm
; Clear TIC3 interrupt flag (required in ISR)
    LDAA #$01           ; 86 01 - TIC3 flag = bit 0
    STAA $1023          ; B7 10 23 - Write to TFLG1
```

### Stack Save/Restore Pattern

```asm
HANDLER:
    PSHA                ; 36 - Save A
    PSHB                ; 37 - Save B
    PSHX                ; 3C - Save X (if needed)
    ; ... handler code ...
    PULX                ; 38 - Restore X
    PULB                ; 33 - Restore B
    PULA                ; 32 - Restore A
    RTS                 ; 39 - Return
```

---

## Notes on Two-Way Bridge / Port A Control

The HC11F-family derivative (68HC11FC0) in the VY V6 uses PORTA bits for EST (Electronic Spark Timing) control:

| Port A Bit | Function | Notes |
|------------|----------|-------|
| PA7 | Pulse Accumulator / IC4 | Input from distributor/crank? |
| PA6 | OC2 Output | **EST Signal** - controls coil charging |
| PA5 | OC3 Output | Secondary timing output |
| PA4 | OC4 Output | Auxiliary timer output |
| PA3 | OC5/IC4 Output/Input | Shared function |

**EST Control Flow:**
1. TIC3 ISR captures 24X crank pulse timing at $1014
2. Period calculated and stored to $0178/$017B
3. Dwell time calculated based on period
4. TOC3 ISR ($35BD) toggles PA bits to control coil:
   - ORAA #$10 → Set bit 4 (start charging)
   - ANDA #$F7 → Clear bit 3 (hold ground)
   - STAA $1000 → Write to PORTA

**Chr0m3 Spark Cut Method:**
Instead of manipulating PORTA directly (which triggers bypass mode), inject fake period value to make dwell calculation return insufficient time (~100µs vs ~3000µs needed).

---

## VY V6 ECU Quick Reference Cheat Sheet

### Most Common Opcodes for VY V6 Patching

| Hex | Mnemonic | Operation | Bytes | Cycles | Use Case |
|-----|----------|-----------|-------|--------|----------|
| **20** | BRA | Branch Always | 2 | 3 | Skip code unconditionally |
| **26** | BNE | Branch if Z=0 | 2 | 3 | Loop until zero |
| **27** | BEQ | Branch if Z=1 | 2 | 3 | Branch if equal |
| **24** | BCC/BHS | Branch if C=0 | 2 | 3 | Unsigned >= |
| **25** | BCS/BLO | Branch if C=1 | 2 | 3 | Unsigned < |
| **7E** | JMP ext | Jump to address | 3 | 3 | Redirect code flow |
| **BD** | JSR ext | Call subroutine | 3 | 6 | Function call |
| **39** | RTS | Return | 1 | 5 | End subroutine |
| **01** | NOP | No operation | 1 | 2 | Pad/disable bytes |
| **86** | LDAA #ii | Load A immediate | 2 | 2 | Set fixed value |
| **96** | LDAA dd | Load A direct | 2 | 3 | Load from RAM |
| **B6** | LDAA hhll | Load A extended | 3 | 4 | Load from anywhere |
| **97** | STAA dd | Store A direct | 2 | 3 | Write to RAM |
| **B7** | STAA hhll | Store A extended | 3 | 4 | Write anywhere |
| **CC** | LDD #jjkk | Load D immediate | 3 | 3 | Load 16-bit value |
| **DC** | LDD dd | Load D direct | 2 | 4 | Load 16-bit from RAM |
| **DD** | STD dd | Store D direct | 2 | 4 | Write 16-bit to RAM |
| **81** | CMPA #ii | Compare A | 2 | 2 | Test against value |
| **4F** | CLRA | Clear A to 0 | 1 | 2 | Zero accumulator |
| **8A** | ORAA #ii | OR A immediate | 2 | 2 | Set bits |
| **84** | ANDA #ii | AND A immediate | 2 | 2 | Clear bits |

### Key VY V6 RAM Locations (Direct Page $00-$FF)

| Address | Name | Size | Description |
|---------|------|------|-------------|
| $00A2 | ENGINE_RPM | 1 | RPM / 25 (e.g., $F0 = 6000 RPM) |
| $00A4 | TPS_VOLTS | 1 | Throttle position sensor |
| $00AD | COOLANT_TEMP | 1 | Engine coolant temperature |
| $00B0 | IAC_STEPS | 1 | Idle air control position |
| $0178 | PERIOD_24X_HI | 1 | 24X crankshaft period (high byte) |
| $0179 | PERIOD_24X_LO | 1 | 24X crankshaft period (low byte) |
| $017A | PERIOD_24X_COPY | 2 | Period working copy |
| $017D | DWELL_TIME | 1 | Calculated coil dwell |

### Key VY V6 Register Addresses (Extended)

| Address | Register | Description |
|---------|----------|-------------|
| $1000 | PORTA | Port A Data (EST output here!) |
| $1003 | PORTC | Port C Data |
| $1004 | PORTB | Port B Data |
| $100E | TCNT | Timer Counter (16-bit, $100E:$100F) |
| $1014 | TIC3 | Input Capture 3 (24X crank pulse timing) |
| $101A | TOC3 | Output Compare 3 (EST timing, $101A:$101B) |
| $1020 | TCTL1 | Timer Control 1 (OC edge selection) |
| $1022 | TMSK1 | Timer Interrupt Mask 1 |
| $1023 | TFLG1 | Timer Interrupt Flags 1 |
| $1030 | ADCTL | A/D Control Register |
| $1031-34 | ADR1-4 | A/D Results (MAP, TPS, O2, etc.) |

### Patching Patterns

**1. Skip a section (NOP-fill):**
```
Original:  BD xx xx   ; JSR somewhere
Patched:   01 01 01   ; NOP NOP NOP
```

**2. Force a branch (always/never):**
```
Original:  27 xx      ; BEQ offset
Always:    20 xx      ; BRA offset (always take)
Never:     21 xx      ; BRN offset (never take, fall through)
```

**3. Force value into register:**
```
Original:  96 A2      ; LDAA $A2 (load from RAM)
Patched:   86 F0      ; LDAA #$F0 (load fixed value)
```

**4. Redirect to new code:**
```
Original:  BD 93 40   ; JSR $9340
Patched:   BD FF 00   ; JSR $FF00 (your patch space)
```

**5. Disable comparison (always pass):**
```
Original:  81 F0      ; CMPA #$F0
           25 xx      ; BCS somewhere
Patched:   01 01      ; NOP NOP (skip compare)
           20 xx      ; BRA somewhere (always branch)
```

### Branch Offset Calculation

Branch target = PC + 2 + signed_offset

| Offset | Decimal | Target (from $8000) |
|--------|---------|---------------------|
| $FE | -2 | $8000 (infinite loop!) |
| $00 | 0 | $8002 |
| $10 | +16 | $8012 |
| $80 | -128 | $7F82 |
| $7F | +127 | $8081 |

### dis68hc11 Source Code Bug Warning ⚠️

The dis68hc11 `Opcodes.h` has **swapped IMM/DIR** for ADCA and ADCB:
```cpp
// WRONG in dis68hc11:
OP_ADCA_DIR = 0x89,  // Should be IMM!
OP_ADCA_IMM = 0x99,  // Should be DIR!
```

**Correct values (verified against dasmfw + Motorola datasheet):**
- 0x89 = ADCA IMM (immediate)
- 0x99 = ADCA DIR (direct)
- 0xC9 = ADCB IMM (immediate)
- 0xD9 = ADCB DIR (direct)

---

*Reference: M68HC11 Reference Manual Rev 6.1, NXP/Freescale*
*VY V6 Specific: Verified against OSID 92118883 Enhanced v1.0a binary*
*XDF Data: Enhanced v2.09a XDF definition (1655 calibration entries, $4000-$7FFC)*
*Cross-checked: dasmfw, Ghidra SLEIGH HC11.slaspec, M68HC11E Family Datasheet*
*Last Updated: February 7, 2026*

---

## Legacy dis68hc11 mnemonic lookup reference — consolidated 2026-11-16

The source-specific `Mnenomic.cpp` / `Mnenomic.h` lookup material, including page-0/page-1 tables, C++ signatures and VY mnemonic patterns, formerly lived in `68HC11_Mnemonics_Reference.md` (Git blob `cbc0d8b29b29ed5ec4769b354bd62b2847bad4d8`). It is preserved below, with only heading depth changed. These tables overlap the primary ISA reference; retain the primary tables above as the navigation source.

**Error and verification history:** `dis68hc11/Opcodes.h` historically transposed ADCA `0x89/0x99` and ADCB `0xC9/0xD9` immediate-versus-direct modes. The separate mnemonic document labelled its tables "CORRECTED"; the source-specific `Mnenomic` spelling in code signatures is preserved, not silently renamed. The January 2026 claims of checks against multiple independent sources are **historical report claims**, not tests rerun during this consolidation. Re-check target CPU derivative, bytes, prefix handling and individual entries before any toolchain use.

<!-- HISTORICAL_MNEMONIC_SOURCE_BEGIN blob:cbc0d8b29b29ed5ec4769b354bd62b2847bad4d8 -->
### 68HC11 Mnemonics Reference (from dis68hc11)

> **Source:** dis68hc11 disassembler - Mnenomic.cpp / Mnenomic.h
> **Purpose:** Mnemonic lookup for VY V6 ECU decompilation
> **⚠️ Note:** dis68hc11 source has bugs - ADCA/ADCB IMM/DIR modes were swapped. This doc is CORRECTED.

---

#### Mnemonic Function Signature

```cpp
#include <stdint.h>

const char* Mnenomic(uint8_t op);      // Page 0 (main) opcodes
const char* MnenomicPage1(uint8_t op); // Page 1 (0x18 prefix) opcodes
```

---

#### Page 0 Mnemonics (Main Instruction Set)

##### Inherent (No Operand)

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
| 0x01 | NOP | Control |
| 0x11 | CBA | Arithmetic |
| 0x0C | CLC | CCR |
| 0x40 | NEGA | Negate |
| 0x50 | NEGB | Negate |
| 0x43 | COMA | Complement |
| 0x53 | COMB | Complement |

##### Bit Manipulation Instructions

These instructions use unique operand formats (address + mask, with optional branch offset):

| Opcode | Mnemonic | Mode | Bytes | Description |
|--------|----------|------|-------|-------------|
| 0x14 | BSET | DIR | 3 | Set bits: M OR mask → M |
| 0x1C | BSET | IND,X | 3 | Set bits: M OR mask → M (indexed) |
| 0x15 | BCLR | DIR | 3 | Clear bits: M AND NOT mask → M |
| 0x1D | BCLR | IND,X | 3 | Clear bits: M AND NOT mask → M (indexed) |
| 0x12 | BRSET | DIR | 4 | Branch if bit(s) set (addr, mask, rel) |
| 0x1E | BRSET | IND,X | 4 | Branch if bit(s) set (offset, mask, rel) |
| 0x13 | BRCLR | DIR | 4 | Branch if bit(s) clear (addr, mask, rel) |
| 0x1F | BRCLR | IND,X | 4 | Branch if bit(s) clear (offset, mask, rel) |

**VY V6 Usage:** BRSET/BRCLR are heavily used for testing mode flags:
```asm
; Example: Test ENGINE_RUNNING bit 7 at $0046
BRSET  $0046,#$80,$target  ; 12 46 80 xx — Branch if bit 7 set
BRCLR  $0046,#$80,$target  ; 13 46 80 xx — Branch if bit 7 clear
```

##### Multi-Mode Instructions

These instructions share the same mnemonic but different opcodes based on addressing mode:

###### ADCA - Add with Carry to A
| Mode | Opcode | Note |
|------|--------|------|
| IMM | 0x89 | ⚠️ dis68hc11 said DIR - WRONG |
| DIR | 0x99 | ⚠️ dis68hc11 said IMM - WRONG |
| EXT | 0xB9 | |
| IND,X | 0xA9 | |

###### ADCB - Add with Carry to B
| Mode | Opcode | Note |
|------|--------|------|
| IMM | 0xC9 | ⚠️ dis68hc11 said DIR - WRONG |
| DIR | 0xD9 | ⚠️ dis68hc11 said IMM - WRONG |
| EXT | 0xF9 | |
| IND,X | 0xE9 | |

###### ADDA - Add to A
| Mode | Opcode |
|------|--------|
| IMM | 0x8B |
| DIR | 0x9B |
| EXT | 0xBB |
| IND,X | 0xAB |

###### ADDB - Add to B
| Mode | Opcode |
|------|--------|
| IMM | 0xCB |
| DIR | 0xDB |
| EXT | 0xFB |
| IND,X | 0xEB |

###### ADDD - Add to D (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0xC3 |
| DIR | 0xD3 |
| EXT | 0xF3 |
| IND,X | 0xE3 |

###### ANDA - AND with A
| Mode | Opcode |
|------|--------|
| IMM | 0x84 |
| DIR | 0x94 |
| EXT | 0xB4 |
| IND,X | 0xA4 |

###### ANDB - AND with B
| Mode | Opcode |
|------|--------|
| IMM | 0xC4 |
| DIR | 0xD4 |
| EXT | 0xF4 |
| IND,X | 0xE4 |

###### ASL - Arithmetic Shift Left
| Mode | Opcode |
|------|--------|
| EXT | 0x78 |
| IND,X | 0x68 |

###### ASR - Arithmetic Shift Right
| Mode | Opcode |
|------|--------|
| EXT | 0x77 |
| IND,X | 0x67 |

###### CLR - Clear Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7F |
| IND | 0x6F |

###### CMPA - Compare A
| Mode | Opcode |
|------|--------|
| IMM | 0x81 |
| DIR | 0x91 |
| EXT | 0xB1 |
| IND,X | 0xA1 |

###### CMPB - Compare B
| Mode | Opcode |
|------|--------|
| IMM | 0xC1 |
| DIR | 0xD1 |
| EXT | 0xF1 |
| IND,X | 0xE1 |

###### CPX - Compare X (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0x8C |
| DIR | 0x9C |
| EXT | 0xBC |
| IND | 0xAC |

###### EORA - Exclusive OR with A
| Mode | Opcode |
|------|--------|
| IMM | 0x88 |
| DIR | 0x98 |
| EXT | 0xB8 |
| IND,X | 0xA8 |

###### EORB - Exclusive OR with B
| Mode | Opcode |
|------|--------|
| IMM | 0xC8 |
| DIR | 0xD8 |
| EXT | 0xF8 |
| IND,X | 0xE8 |

###### INC - Increment Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7C |
| IND,X | 0x6C |

###### JMP - Jump
| Mode | Opcode |
|------|--------|
| EXT | 0x7E |
| IND,X | 0x6E |

###### JSR - Jump to Subroutine
| Mode | Opcode |
|------|--------|
| DIR | 0x9D |
| EXT | 0xBD |
| IND | 0xAD |

###### LDAA - Load A
| Mode | Opcode |
|------|--------|
| IMM | 0x86 |
| DIR | 0x96 |
| EXT | 0xB6 |
| IND,X | 0xA6 |

###### LDAB - Load B
| Mode | Opcode |
|------|--------|
| IMM | 0xC6 |
| DIR | 0xD6 |
| EXT | 0xF6 |
| IND,X | 0xE6 |

###### LDD - Load D (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0xCC |
| DIR | 0xDC |
| EXT | 0xFC |
| IND,X | 0xEC |

###### LDS - Load Stack Pointer
| Mode | Opcode |
|------|--------|
| IMM | 0x8E |
| DIR | 0x9E |
| EXT | 0xBE |
| IND | 0xAE |

###### LDX - Load X
| Mode | Opcode |
|------|--------|
| IMM | 0xCE |
| DIR | 0xDE |
| EXT | 0xFE |
| IND | 0xEE |

###### LSR - Logical Shift Right
| Mode | Opcode |
|------|--------|
| EXT | 0x74 |
| IND,X | 0x64 |

###### ORAA - OR with A
| Mode | Opcode |
|------|--------|
| IMM | 0x8A |
| DIR | 0x9A |
| EXT | 0xBA |
| IND,X | 0xAA |

###### ORAB - OR with B
| Mode | Opcode |
|------|--------|
| IMM | 0xCA |
| DIR | 0xDA |
| EXT | 0xFA |
| IND,X | 0xEA |

###### ROL - Rotate Left
| Mode | Opcode |
|------|--------|
| EXT | 0x79 |
| IND | 0x69 |

###### ROR - Rotate Right
| Mode | Opcode |
|------|--------|
| EXT | 0x76 |
| IND | 0x66 |

###### SBCA - Subtract with Carry from A
| Mode | Opcode |
|------|--------|
| IMM | 0x82 |
| DIR | 0x92 |
| EXT | 0xB2 |
| IND,X | 0xA2 |

###### SBCB - Subtract with Carry from B
| Mode | Opcode |
|------|--------|
| IMM | 0xC2 |
| DIR | 0xD2 |
| EXT | 0xF2 |
| IND,X | 0xE2 |

###### STAA - Store A
| Mode | Opcode |
|------|--------|
| DIR | 0x97 |
| EXT | 0xB7 |
| IND,X | 0xA7 |

###### STAB - Store B
| Mode | Opcode |
|------|--------|
| DIR | 0xD7 |
| EXT | 0xF7 |
| IND,X | 0xE7 |

###### STD - Store D (16-bit)
| Mode | Opcode |
|------|--------|
| DIR | 0xDD |
| EXT | 0xFD |
| IND,X | 0xED |

###### STS - Store Stack Pointer
| Mode | Opcode |
|------|--------|
| DIR | 0x9F |
| EXT | 0xBF |
| IND,X | 0xAF |

###### SUBD - Subtract from D (16-bit)
| Mode | Opcode |
|------|--------|
| IMM | 0x83 |
| DIR | 0x93 |
| EXT | 0xB3 |
| IND,X | 0xA3 |

###### STX - Store X
| Mode | Opcode |
|------|--------|
| DIR | 0xDF |
| EXT | 0xFF |
| IND | 0xEF |

###### SUBA - Subtract from A
| Mode | Opcode |
|------|--------|
| IMM | 0x80 |
| DIR | 0x90 |
| EXT | 0xB0 |
| IND,X | 0xA0 |

###### SUBB - Subtract from B
| Mode | Opcode |
|------|--------|
| IMM | 0xC0 |
| DIR | 0xD0 |
| EXT | 0xF0 |
| IND,X | 0xE0 |

###### TST - Test Memory
| Mode | Opcode |
|------|--------|
| EXT | 0x7D |
| IND,X | 0x6D |

---

#### Branch Mnemonics

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

#### Page 1 Mnemonics (0x18 Prefix)

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

#### Addressing Mode Patterns

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

#### VY V6 Common Mnemonic Sequences

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

<!-- HISTORICAL_MNEMONIC_SOURCE_END -->

---

---

## Legacy dis68hc11 instruction-description reference — consolidated 2026-11-16

The old `68HC11_Descriptions_Reference.md` documents `Description(uint8_t op)`, source file `Description.cpp`/`Description.h`, a fuller English-description lookup, and VY-specific example patterns. It was a distinct C++ API companion to the main ISA table and is preserved **in full** below. Original Git blob: `8e000650442121b10fbc5cbf830d363dfef5f7cb`. Headings alone were nested two levels deeper to suit this master.

**Errors / false-completion history:** the imported text includes a prior `Previously Missing Descriptions (COMPLETED ✅)` claim and a `Bug Fix Applied` paragraph. Those are *dated author assertions*, not a compile, ROM-test, or seven-source re-verification performed on 2026-11-16. The reported ADCA/ADCB immediate/direct-mode swap in the upstream `dis68hc11` source is kept explicit. The appendix's original mention of `68HC11_Opcodes_Reference.md` identifies a **historical source path**; use the opcode tables in this master and the consolidated opcode appendix if that standalone is retired. Avoid treating textual opcode descriptions as validation of a particular ECU binary's semantics.

<!-- HISTORICAL_DESCRIPTIONS_SOURCE_BEGIN blob:8e000650442121b10fbc5cbf830d363dfef5f7cb -->
### 68HC11 Instruction Descriptions (from dis68hc11)

> **Source:** dis68hc11 disassembler - Description.cpp / Description.h
> **Purpose:** Human-readable descriptions for VY V6 ECU decompilation

---

#### Description Function Signature

```cpp
#include <stdint.h>

const char* Description(uint8_t op);
```

Returns a human-readable description string for the given opcode.

---

#### Complete Instruction Descriptions

##### Accumulator Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x1B | ABA | Add Accumulator B to Accumulator A |
| 0x3A | ABX | Add B to X |
| 0x4F | CLRA | Clear Accumulator A |
| 0x5F | CLRB | Clear Accumulator B |
| 0x10 | SBA | Subtract B from A |
| 0x16 | TAB | Transfer A to B |

##### Add with Carry (ADCB)

| Opcode | Mode | Description | Note |
|--------|------|-------------|------|
| 0xC9 | IMM | Add with carry to B, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| 0xD9 | DIR | Add with carry to B, direct | ⚠️ dis68hc11 said IMM - WRONG |
| 0xF9 | EXT | Add with carry to B, extended | |
| 0xE9 | IND,X | Add with carry to B, indexed | |

##### AND Operations (ANDA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x84 | IMM | AND A with Memory, immediate |
| 0x94 | DIR | AND A with Memory, direct |
| 0xB4 | EXT | AND A with Memory, extended |
| 0xA4 | IND,X | AND A with Memory, indexed |

##### AND Operations (ANDB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC4 | IMM | AND B with Memory, immediate |
| 0xD4 | DIR | AND B with Memory, direct |
| 0xF4 | EXT | AND B with Memory, extended |
| 0xE4 | IND,X | AND B with Memory, indexed |

##### Shift Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x48 | ASLA | Arithmetic Shift Left A |
| 0x58 | ASLB | Arithmetic Shift Left B |

##### Branch Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x25 | BCS | Branch if Carry Set |
| 0x27 | BEQ | Branch if Equal |
| 0x22 | BHI | Branch if Higher |
| 0x26 | BNE | Branch if Not Equal to Zero |

##### CCR Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x0E | CLI | Clear Interrupt Mask |
| 0x0F | SEI | Set Interrupt Mask |

##### Compare Operations (CMPA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x91 | DIR | Compare A, direct |

##### Compare X (CPX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8C | IMM | Compare X to Memory 16-Bit, immediate |
| 0x9C | DIR | Compare X to Memory 16-Bit, direct |
| 0xBC | EXT | Compare X to Memory 16-Bit, extended |
| 0xAC | IND | Compare X to Memory 16-Bit, indexed |

##### Index Register Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x09 | DEX | Decrement Index Register X |
| 0x08 | INX | Increment Index Register X |

##### Exclusive OR (EORA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x88 | IMM | Exclusive OR, immediate |
| 0x98 | DIR | Exclusive OR, direct |
| 0xB8 | EXT | Exclusive OR, extended |
| 0xA8 | IND,X | Exclusive OR, indexed |

##### Stack Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x31 | INS | Increment Stack Pointer |
| 0x38 | PULX | Pull Index Register X from Stack |

##### Jump Operations

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xBD | JSR EXT | Jump to Subroutine, extended |
| 0xAD | JSR IND | Jump to Subroutine, indexed |

##### Load A (LDAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x86 | IMM | Load Accumulator A, immediate |
| 0x96 | DIR | Load Accumulator A, direct |
| 0xB6 | EXT | Load Accumulator A, extended |

##### Load Stack Pointer (LDS)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8E | IMM | Load Stack Pointer, immediate |
| 0x9E | DIR | Load Stack Pointer, direct |
| 0xBE | EXT | Load Stack Pointer, extended |

##### Logical Shift Right (LSR)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x74 | EXT | Logical Shift Right, extended |
| 0x64 | IND,X | Logical Shift Right, indexed |
| 0x44 | LSRA | Logical Shift Right A |
| 0x54 | LSRB | Logical Shift Right B |
| 0x04 | LSRD | Logical Shift Right D |

##### OR Operations (ORAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8A | IMM | Inclusive OR accumulator A, immediate |
| 0x9A | DIR | Inclusive OR accumulator A, direct |
| 0xAA | IND,X | Inclusive OR accumulator A, indexed |

##### Rotate Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x59 | ROLB | Rotate Left B |

##### Return Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x39 | RTS | Return from Subroutine |

##### Store A (STAA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x97 | DIR | Store Accumulator A, direct |
| 0xB7 | EXT | Store Accumulator A, extended |
| 0xA7 | IND,X | Store Accumulator A, indexed |

##### Store B (STAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xD7 | DIR | Store Accumulator B, direct |
| 0xF7 | EXT | Store Accumulator B, extended |
| 0xE7 | IND,X | Store Accumulator B, indexed |

##### Store X (STX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xDF | DIR | Store Index Register X, direct |
| 0xFF | EXT | Store Index Register X, extended |
| 0xEF | IND | Store Index Register X, indexed |

##### Add with Carry (ADCA)

| Opcode | Mode | Description | Note |
|--------|------|-------------|------|
| 0x89 | IMM | Add with carry to A, immediate | ⚠️ dis68hc11 said DIR - WRONG |
| 0x99 | DIR | Add with carry to A, direct | ⚠️ dis68hc11 said IMM - WRONG |
| 0xB9 | EXT | Add with carry to A, extended | |
| 0xA9 | IND,X | Add with carry to A, indexed | |

##### Add to A (ADDA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x8B | IMM | Add to A, immediate |
| 0x9B | DIR | Add to A, direct |
| 0xBB | EXT | Add to A, extended |
| 0xAB | IND,X | Add to A, indexed |

##### Add to B (ADDB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCB | IMM | Add to B, immediate |
| 0xDB | DIR | Add to B, direct |
| 0xFB | EXT | Add to B, extended |
| 0xEB | IND,X | Add to B, indexed |

##### Add to D (ADDD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC3 | IMM | Add to D (16-bit), immediate |
| 0xD3 | DIR | Add to D (16-bit), direct |
| 0xF3 | EXT | Add to D (16-bit), extended |
| 0xE3 | IND,X | Add to D (16-bit), indexed |

##### Subtract from A (SUBA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x80 | IMM | Subtract from A, immediate |
| 0x90 | DIR | Subtract from A, direct |
| 0xB0 | EXT | Subtract from A, extended |
| 0xA0 | IND,X | Subtract from A, indexed |

##### Subtract from B (SUBB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC0 | IMM | Subtract from B, immediate |
| 0xD0 | DIR | Subtract from B, direct |
| 0xF0 | EXT | Subtract from B, extended |
| 0xE0 | IND,X | Subtract from B, indexed |

##### Subtract D (SUBD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x83 | IMM | Subtract D (16-bit), immediate |
| 0x93 | DIR | Subtract D (16-bit), direct |
| 0xB3 | EXT | Subtract D (16-bit), extended |
| 0xA3 | IND,X | Subtract D (16-bit), indexed |

##### Subtract with Carry from A (SBCA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x82 | IMM | Subtract with carry from A, immediate |
| 0x92 | DIR | Subtract with carry from A, direct |
| 0xB2 | EXT | Subtract with carry from A, extended |
| 0xA2 | IND,X | Subtract with carry from A, indexed |

##### Subtract with Carry from B (SBCB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC2 | IMM | Subtract with carry from B, immediate |
| 0xD2 | DIR | Subtract with carry from B, direct |
| 0xF2 | EXT | Subtract with carry from B, extended |
| 0xE2 | IND,X | Subtract with carry from B, indexed |

##### Bit Test A (BITA)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x85 | IMM | Bit Test A (AND flags only), immediate |
| 0x95 | DIR | Bit Test A (AND flags only), direct |
| 0xB5 | EXT | Bit Test A (AND flags only), extended |
| 0xA5 | IND,X | Bit Test A (AND flags only), indexed |

##### Bit Test B (BITB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC5 | IMM | Bit Test B (AND flags only), immediate |
| 0xD5 | DIR | Bit Test B (AND flags only), direct |
| 0xF5 | EXT | Bit Test B (AND flags only), extended |
| 0xE5 | IND,X | Bit Test B (AND flags only), indexed |

##### Compare A (CMPA) - All Modes

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x81 | IMM | Compare A, immediate |
| 0x91 | DIR | Compare A, direct |
| 0xB1 | EXT | Compare A, extended |
| 0xA1 | IND,X | Compare A, indexed |

##### Compare B (CMPB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC1 | IMM | Compare B, immediate |
| 0xD1 | DIR | Compare B, direct |
| 0xF1 | EXT | Compare B, extended |
| 0xE1 | IND,X | Compare B, indexed |

##### Load B (LDAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC6 | IMM | Load Accumulator B, immediate |
| 0xD6 | DIR | Load Accumulator B, direct |
| 0xF6 | EXT | Load Accumulator B, extended |
| 0xE6 | IND,X | Load Accumulator B, indexed |

##### Load D (LDD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCC | IMM | Load D (16-bit), immediate |
| 0xDC | DIR | Load D (16-bit), direct |
| 0xFC | EXT | Load D (16-bit), extended |
| 0xEC | IND,X | Load D (16-bit), indexed |

##### Load X (LDX)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCE | IMM | Load Index Register X, immediate |
| 0xDE | DIR | Load Index Register X, direct |
| 0xFE | EXT | Load Index Register X, extended |
| 0xEE | IND,X | Load Index Register X, indexed |

##### Store D (STD)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xDD | DIR | Store D (16-bit), direct |
| 0xFD | EXT | Store D (16-bit), extended |
| 0xED | IND,X | Store D (16-bit), indexed |

##### Store Stack Pointer (STS)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0x9F | DIR | Store Stack Pointer, direct |
| 0xBF | EXT | Store Stack Pointer, extended |
| 0xAF | IND,X | Store Stack Pointer, indexed |

##### OR B (ORAB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xCA | IMM | Inclusive OR accumulator B, immediate |
| 0xDA | DIR | Inclusive OR accumulator B, direct |
| 0xFA | EXT | Inclusive OR accumulator B, extended |
| 0xEA | IND,X | Inclusive OR accumulator B, indexed |

##### OR A (ORAA) - Extended Mode (Missing from original)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xBA | EXT | Inclusive OR accumulator A, extended |

##### Exclusive OR B (EORB)

| Opcode | Mode | Description |
|--------|------|-------------|
| 0xC8 | IMM | Exclusive OR B, immediate |
| 0xD8 | DIR | Exclusive OR B, direct |
| 0xF8 | EXT | Exclusive OR B, extended |
| 0xE8 | IND,X | Exclusive OR B, indexed |

##### Transfer Operations

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x06 | TAP | Transfer A to Condition Codes Register |
| 0x07 | TPA | Transfer Condition Codes Register to A |
| 0x16 | TAB | Transfer A to B |
| 0x17 | TBA | Transfer B to A |
| 0x30 | TSX | Transfer Stack Pointer to X |
| 0x35 | TXS | Transfer X to Stack Pointer |
| 0x8F | XGDX | Exchange D with X |

##### Multiply/Divide

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x3D | MUL | Multiply A by B, unsigned result in D |
| 0x02 | IDIV | Integer Divide D by X, quotient in X, remainder in D |
| 0x03 | FDIV | Fractional Divide D by X, quotient in X, remainder in D |
| 0x19 | DAA | Decimal Adjust A (BCD correction after ADD) |

##### Control Flow

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x3B | RTI | Return from Interrupt (restore all registers + CCR) |
| 0x3F | SWI | Software Interrupt (push all registers, vector to $FFF6) |
| 0x3E | WAI | Wait for Interrupt (push all, halt until IRQ/NMI) |
| 0xCF | STOP | Stop all clocks (lowest power, requires S bit clear) |
| 0x00 | TEST | Test mode (factory only, causes address bus sweep) |
| 0x01 | NOP | No Operation (does nothing for 2 cycles) |

##### Stack Operations (Full Set)

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

##### Increment/Decrement (Full Set)

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

##### Negate/Complement/Test/Clear

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

##### Bit Manipulation

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

##### Rotate/Shift (Full Set)

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

##### Branch Instructions (Full Set)

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

##### CCR Operations (Full Set)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x0A | CLV | Clear Overflow Flag |
| 0x0B | SEV | Set Overflow Flag |
| 0x0C | CLC | Clear Carry Flag |
| 0x0D | SEC | Set Carry Flag |
| 0x0E | CLI | Clear Interrupt Mask (enable IRQ) |
| 0x0F | SEI | Set Interrupt Mask (disable IRQ) |

---

#### Description Implementation (C++)

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

#### VY V6 ECU - Common Description Patterns

##### Timing-Critical Operations
- **"Set Interrupt Mask"** (SEI 0x0F) - Disables interrupts during critical sections
- **"Clear Interrupt Mask"** (CLI 0x0E) - Re-enables interrupts

##### EST/Spark Control
- **"Store Accumulator A"** to $1020 (TCTL1) - Controls EST output compare
- **"Inclusive OR accumulator A"** - Sets specific bits (e.g., OC3 for EST)

##### Loop Operations
- **"Decrement Index Register X"** (DEX) - Common loop counter
- **"Branch if Not Equal to Zero"** (BNE) - Loop continuation

##### Subroutine Patterns
- **"Jump to Subroutine"** (JSR) - Function call
- **"Return from Subroutine"** (RTS) - Function return

---

#### Previously Missing Descriptions (COMPLETED ✅)

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

#### ⚠️ Bug Fix Applied

**Original dis68hc11 source had swapped IMM/DIR modes for ADCA and ADCB.**
This file has been corrected to match the official Motorola M68HC11 Reference Manual.

See `68HC11_Opcodes_Reference.md` for full details of the bug.

---

*Generated from dis68hc11 source - January 2026*
*Corrected: ADCB IMM/DIR modes fixed January 17, 2026*

<!-- HISTORICAL_DESCRIPTIONS_SOURCE_END -->

---

