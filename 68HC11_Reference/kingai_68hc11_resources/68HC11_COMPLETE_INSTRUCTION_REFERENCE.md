# 68HC11 Complete Instruction Set Reference

> **Source:** Tom Dickens / Dan Kohn (dankohn.info) + NXP M68HC11ERG Reference Manual
> **Maintained for:** VY V6 ECU Decompilation Project
> **Notes:** More rows and columns needed with notes. and each sources info in a column.
> **Last Updated:** January 17, 2026
> 
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
| $01 | Reserved | |
| $02 | PIOC | Parallel I/O Control |
| $03 | PORTC | Port C Data Register |
| $04 | PORTB | Port B Data Register |
| $05 | PORTCL | Port C Latched Data |
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

| Tool | Location | Purpose |
|------|----------|---------|
| dis68hc11 | `dis68hc11/` | Simple C++ disassembler |
| dasmfw | `dasmfw/` | Comprehensive disassembler framework |
| EVBU Simulator | `EVBU_Simulator/` | Python-based HC11/Buffalo simulator |
| A09 Assembler | `A09_Assembler/` | Full macro assembler |
| GCC HC11 | `GCC_HC11/` | GNU cross-compiler |
| BASIC11 | `BASIC11/` | BASIC interpreter with include files |
| Ghidra Files | `ghidra_hc11/` | Ghidra processor specification |

---

## VY V6 ECU Specific Register Usage ($060A OSID 92118883)

> **IMPORTANT:** The VY V6 Delco ECU uses the MC68HC711E9 variant. These mappings are verified against the Enhanced v1.0a binary.

### Timer Registers for EST (Electronic Spark Timing)

| Address | Name | VY V6 Usage | Notes |
|---------|------|-------------|-------|
| **$100E-$100F** | TCNT | Free-running 16-bit counter | 500ns per count @ 2MHz E-clock |
| **$1014-$1015** | TIC3 | 3X Crank sensor capture | ISR at $35FF handles spark calc |
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
| **TIC3** | $1FFEA | $200F | **JMP $35FF** | **3X Crank Handler** |
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

## VY V6 Critical RAM Variables (Verified)

| Address | Name | Size | Purpose | Verified By |
|---------|------|------|---------|-------------|
| **$00A2** | RPM | 1 byte | Engine RPM ÷ 25 (8-bit) | 82 reads in code |
| **$0178** | 3X_PERIOD | 2 bytes | 3X crank period (µs) | TIC3 ISR at $363E |
| **$017B** | 3X_PERIOD_ALT | 2 bytes | Alternate period storage | STD at $101E1 |
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
    STD  $017B          ; FD 01 7B - Store 3X period

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

The 68HC711E9 in the VY V6 uses PORTA bits for EST (Electronic Spark Timing) control:

| Port A Bit | Function | Notes |
|------------|----------|-------|
| PA7 | Pulse Accumulator / IC4 | Input from distributor/crank? |
| PA6 | OC2 Output | **EST Signal** - controls coil charging |
| PA5 | OC3 Output | Secondary timing output |
| PA4 | OC4 Output | Auxiliary timer output |
| PA3 | OC5/IC4 Output/Input | Shared function |

**EST Control Flow:**
1. TIC3 ISR captures 3X crank pulse timing at $1014
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
| $0178 | PERIOD_3X_HI | 1 | 3X crankshaft period (high byte) |
| $0179 | PERIOD_3X_LO | 1 | 3X crankshaft period (low byte) |
| $017A | PERIOD_3X_COPY | 2 | Period working copy |
| $017D | DWELL_TIME | 1 | Calculated coil dwell |

### Key VY V6 Register Addresses (Extended)

| Address | Register | Description |
|---------|----------|-------------|
| $1000 | PORTA | Port A Data (EST output here!) |
| $1003 | PORTC | Port C Data |
| $1004 | PORTB | Port B Data |
| $100E | TCNT | Timer Counter (16-bit, $100E:$100F) |
| $1014 | TIC3 | Input Capture 3 (3X crank pulse timing) |
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
*Cross-checked: dasmfw, Ghidra SLEIGH HC11.slaspec, M68HC11E Family Datasheet*
*Last Updated: January 17, 2026*
