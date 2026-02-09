# dis68hc11 Disassembler - Main Logic Reference

> **Source:** dis68hc11 disassembler - main.cpp
> **Purpose:** Understanding disassembly logic for VY V6 ECU binary analysis

---

## Program Structure

```
main.cpp (367 lines, 7.4 KB)
├── AddressString()     - Register/address name lookup
├── Page1()             - Handle 0x18 prefix (Y-register) opcodes  
├── Page0()             - Main opcode disassembly
├── Disassemble()       - Main disassembly loop (2 overloads)
└── main()              - CLI entry point
```

---

## Register Address Lookup

The disassembler recognizes HC11 register addresses and outputs symbolic names:

```cpp
std::string AddressString(uint16_t addr)
{
    switch(addr)
    {
    // Port Registers
    // NOTE: This is the dis68hc11 source (HC11E layout). The actual VY V6
    // ECU uses HC11F-family (68HC11FC0) which has a DIFFERENT register map:
    //   $1001 = DDRA (not reserved)
    //   $1002 = PORTG (not PIOC) — bank switching via bit 6
    //   $1003 = DDRG (not PORTC)
    //   $1005 = PORTF (not PORTCL)
    //   $1006 = PORTC (shifted from $1003)
    // See DARC disassembly (IDA Pro) for correct HC11F layout.
    case 0x1000: return "PORTA";   // Port A Data
    case 0x1002: return "PIOC";    // ⚠️ WRONG for VY V6 — actual chip is PORTG (HC11F)
    case 0x1003: return "PORTC";   // ⚠️ WRONG for VY V6 — actual chip is DDRG (HC11F)
    case 0x1004: return "PORTB";   // Port B Data
    case 0x1005: return "PORTCL";  // ⚠️ WRONG for VY V6 — actual chip is PORTF (HC11F)
    case 0x1006: return "DDRC";    // Data Direction C
    case 0x1008: return "PORTD";   // Port D Data
    case 0x1009: return "DDRD";    // Data Direction D
    case 0x100a: return "PORTE";   // Port E Data (A/D inputs)
    
    // Timer Registers  
    case 0x100b: return "CFORC";   // Compare Force
    case 0x100c: return "OC1M";    // OC1 Action Mask
    case 0x100d: return "OC1D";    // OC1 Action Data
    case 0x1020: return "TCTL1";   // Timer Control 1 (OC1-OC4)
    case 0x1026: return "PACTL";   // Pulse Accumulator Control
    
    // SPI/SCI Registers
    case 0x1028: return "SPCR";    // SPI Control
    case 0x1029: return "SPSR";    // SPI Status
    case 0x102b: return "BAUD";    // SCI Baud Rate
    case 0x102c: return "SCCR1";   // SCI Control 1
    case 0x102d: return "SCCR2";   // SCI Control 2
    
    // A/D Converter
    case 0x1030: return "ADCTL";   // A/D Control
    case 0x1031: return "ADR1";    // A/D Result 1
    case 0x1032: return "ADR2";    // A/D Result 2
    case 0x1033: return "ADR3";    // A/D Result 3
    case 0x1034: return "ADR4";    // A/D Result 4
    
    // System Control
    case 0x1039: return "OPTION";  // System Config Options
    case 0x103a: return "COPRST";  // COP Reset
    case 0x103b: return "PPROG";   // EEPROM Programming
    case 0x103c: return "HPRIO";   // Highest Priority Interrupt
    case 0x103d: return "INIT";    // RAM/Register Mapping
    case 0x103e: return "TEST1";   // Factory Test
    case 0x103f: return "CONFIG";  // System Configuration
    }
    
    // Default: return hex address
    std::ostringstream oss;
    oss << "$" << std::hex << std::setw(4) << std::setfill('0') << addr;
    return oss.str();
}
```

---

## VY V6 ECU - Additional Addresses to Add

For VY V6 $060A OS, add these timer registers:

| Address | Name | Description |
|---------|------|-------------|
| 0x100E | TCNT_H | Timer Counter High |
| 0x100F | TCNT_L | Timer Counter Low |
| 0x1010 | TIC1_H | Input Capture 1 High |
| 0x1011 | TIC1_L | Input Capture 1 Low |
| 0x1012 | TIC2_H | Input Capture 2 High |
| 0x1013 | TIC2_L | Input Capture 2 Low |
| 0x1014 | TIC3_H | Input Capture 3 High (3X Period!) |
| 0x1015 | TIC3_L | Input Capture 3 Low |
| 0x1016 | TOC1_H | Output Compare 1 High |
| 0x1017 | TOC1_L | Output Compare 1 Low |
| 0x1018 | TOC2_H | Output Compare 2 High |
| 0x1019 | TOC2_L | Output Compare 2 Low |
| 0x101A | TOC3_H | Output Compare 3 High (EST!) |
| 0x101B | TOC3_L | Output Compare 3 Low |
| 0x1022 | TMSK1 | Timer Interrupt Mask 1 |
| 0x1023 | TFLG1 | Timer Interrupt Flag 1 |
| 0x1024 | TMSK2 | Timer Interrupt Mask 2 |
| 0x1025 | TFLG2 | Timer Interrupt Flag 2 |

---

## Page 0 Opcode Handling

Main disassembly logic for single-byte opcodes:

### Inherent (No Operand)
```cpp
case OP_ABA:
case OP_ABX:
case OP_ASLA:
// ... many more
case OP_XGDX:
    std::cout << Mnenomic(op) << '\t';
    break;
```

### Immediate (1 byte operand)
```cpp
case OP_ADDA_IMM:
case OP_LDAA_IMM:
// ...
    std::cout << Mnenomic(op) << "\t#" << std::dec << (int)data[++pc];
    break;
```

### Direct (1 byte address, $00-$FF)
```cpp
case OP_ADDA_DIR:
case OP_LDAA_DIR:
// ...
    std::cout << Mnenomic(op) << '\t' << std::dec << (int)data[++pc];
    break;
```

### Relative (Branch, signed offset)
```cpp
case OP_BCC:
case OP_BCS:
case OP_BEQ:
// ...
{
    int offset = int8_t(data[++pc]);  // Signed!
    std::cout << Mnenomic(op) << "\t$" << std::hex << pc + offset + 1 + epromStart;
}
    break;
```

### Immediate 16-bit (2 byte operand)
```cpp
case OP_CPX_IMM:
case OP_LDD_IMM:
case OP_LDX_IMM:
case OP_LDS_IMM:
{
    uint8_t p0 = data[++pc];
    uint8_t p1 = data[++pc];
    uint16_t value = (uint16_t(p0) << 8) | p1;
    std::cout << Mnenomic(op) << "\t#$" << std::hex << value;
}
    break;
```

### Extended (2 byte address)
```cpp
case OP_CLR_EXT:
case OP_JMP_EXT:
case OP_JSR_EXT:
case OP_LDAA_EXT:
// ...
{
    uint8_t p0 = data[++pc];
    uint8_t p1 = data[++pc];
    uint16_t addr = (uint16_t(p0) << 8) | p1;
    std::cout << Mnenomic(op) << "\t" << AddressString(addr);
}
    break;
```

### Indexed (offset from X)
```cpp
case OP_ADCB_IND_X:
case OP_LDAA_IND_X:
// ...
{
    std::cout << Mnenomic(op);
    uint8_t p = data[++pc];
    if(p != 0)
        std::cout << '\t' << std::dec << int(p) << ",X";
    else
        std::cout << "\tX";
}
    break;
```

### Page 1 Prefix (0x18)
```cpp
case 0x18:
    pc++;
    Page1(data, pc);
    break;
```

---

## Page 1 (Y-Register) Handling

When 0x18 prefix is encountered:

```cpp
void Page1(const uint8_t* data, unsigned int& pc)
{
    uint8_t op = data[pc];
    switch(op)
    {
    // Inherent:
    case OP_DEY:
    case OP_INY:
        std::cout << MnenomicPage1(op);
        break;

    // Immediate 16-bit:
    case OP_LDY_IMM:
    case OP_CPY_IMM:
    {
        uint8_t p0 = data[++pc];
        uint8_t p1 = data[++pc];
        uint16_t value = (uint16_t(p0) << 8) | p1;
        std::cout << MnenomicPage1(op) << "\t#$" << std::hex << value;
    }
        break;

    // Indexed Y:
    case OP_STAA_IND_Y:
    case OP_LDAA_IND_Y:
    {
        std::cout << MnenomicPage1(op);
        uint8_t p = data[++pc];
        if(p != 0)
            std::cout << '\t' << std::dec << p << ",Y";
        else
            std::cout << "\tY";
    }
        break;
    }
}
```

---

## Page 1A (CPD Instructions) Handling

When the 0x1A prefix byte is encountered, the next byte selects a CPD (Compare D) variant:

```cpp
void Page1A(const uint8_t* data, unsigned int& pc)
{
    uint8_t op = data[pc];
    switch(op)
    {
    case 0x83:  // CPD IMM
    {
        uint8_t p0 = data[++pc];
        uint8_t p1 = data[++pc];
        uint16_t value = (uint16_t(p0) << 8) | p1;
        std::cout << "CPD\t#$" << std::hex << value;
    }
        break;
    case 0x93:  // CPD DIR
        std::cout << "CPD\t" << std::dec << (int)data[++pc];
        break;
    case 0xA3:  // CPD IND,X
    {
        uint8_t p = data[++pc];
        std::cout << "CPD\t" << std::dec << int(p) << ",X";
    }
        break;
    case 0xB3:  // CPD EXT
    {
        uint8_t p0 = data[++pc];
        uint8_t p1 = data[++pc];
        uint16_t addr = (uint16_t(p0) << 8) | p1;
        std::cout << "CPD\t" << AddressString(addr);
    }
        break;
    }
}
```

**VY V6 ECU Usage:** CPD is the 16-bit compare of D register. Used heavily for:
- 16-bit RPM comparisons: `LDD $00A2; CPD #$1770` (compare to 6000 RPM)
- Period threshold checks: `LDD $017B; CPD #$00C8`
- Table lookup bounds checking

---

## Page CD (Cross-Page LDX/STX/CPX with Y-indexing) Handling

The 0xCD prefix byte selects LDX/STX indexed by Y and some CPX variants:

```cpp
void PageCD(const uint8_t* data, unsigned int& pc)
{
    uint8_t op = data[pc];
    switch(op)
    {
    case 0xEE:  // LDX IND,Y
    {
        uint8_t p = data[++pc];
        std::cout << "LDX\t" << std::dec << int(p) << ",Y";
    }
        break;
    case 0xEF:  // STX IND,Y
    {
        uint8_t p = data[++pc];
        std::cout << "STX\t" << std::dec << int(p) << ",Y";
    }
        break;
    case 0xAC:  // CPX IND,Y
    {
        uint8_t p = data[++pc];
        std::cout << "CPX\t" << std::dec << int(p) << ",Y";
    }
        break;
    case 0xA3:  // CPD IND,Y
    {
        uint8_t p = data[++pc];
        std::cout << "CPD\t" << std::dec << int(p) << ",Y";
    }
        break;
    }
}
```

### Prebyte Summary

| Prebyte | Purpose | Example |
|---------|---------|--------|
| None | Page 0 - standard instructions | `LDAA #$FF` |
| 0x18 | Y-register variants (LDY, STY, CPY, indexed Y) | `18 CE 0100` = `LDY #$0100` |
| 0x1A | CPD instructions + CPY IND,X + LDY IND,X | `1A 83 1770` = `CPD #$1770` |
| 0xCD | LDX/STX indexed Y + CPX IND,Y + CPD IND,Y | `CD EE 05` = `LDX 5,Y` |

---

## Bit Manipulation Opcode Handling

The 68HC11 has 4 bit manipulation instructions with unique operand formats:

```cpp
// BSET/BCLR: 3 or 4 bytes depending on mode
case 0x14:  // BSET DIR: addr, mask
{
    uint8_t addr = data[++pc];
    uint8_t mask = data[++pc];
    std::cout << "BSET\t$" << std::hex << int(addr) << ",#$" << int(mask);
}
    break;

case 0x1C:  // BSET IND,X: offset, mask
{
    uint8_t offset = data[++pc];
    uint8_t mask = data[++pc];
    std::cout << "BSET\t" << std::dec << int(offset) << ",X,#$" << std::hex << int(mask);
}
    break;

// BRSET/BRCLR: 4 or 5 bytes (includes branch offset)
case 0x12:  // BRSET DIR: addr, mask, rel
{
    uint8_t addr = data[++pc];
    uint8_t mask = data[++pc];
    int8_t  rel  = int8_t(data[++pc]);
    uint16_t target = pc + rel + 1 + epromStart;
    std::cout << "BRSET\t$" << std::hex << int(addr) 
              << ",#$" << int(mask) << ",$" << target;
}
    break;
```

**VY V6 ECU Usage:** BRSET/BRCLR are used extensively for checking mode flags:
```asm
; Check if engine is running (bit test on mode byte)
BRSET  $0046,#$80,$xxxx  ; Branch if ENGINE_RUNNING flag set
BRCLR  $0046,#$80,$xxxx  ; Branch if ENGINE_RUNNING flag clear
```

---

## Main Loop - Prebyte Dispatch

The complete prefix handling in Page0:

```cpp
case 0x18:  // Y-register page
    pc++;
    Page1(data, pc);
    break;

case 0x1A:  // CPD page (+ some CPY/LDY with X indexing)
    pc++;
    Page1A(data, pc);
    break;

case 0xCD:  // Cross-page (LDX/STX/CPX with Y indexing)
    pc++;
    PageCD(data, pc);
    break;
```

```cpp
void Disassemble(const uint8_t data[], unsigned int length, uint16_t startAddress)
{
    unsigned int epromStart = 0xFFFF - length + 1;
    unsigned int pc = startAddress - epromStart;
    
    while(pc < length)
    {
        // Print address
        std::cout << "$" << std::hex << std::setw(4) << std::setfill('0') 
                  << pc + epromStart << ":\t";

        uint8_t op = data[pc];
        Page0(data, pc, epromStart);
        
        // Print description comment
        std::cout << "\t; " << Description(op) << std::endl;
        pc++;
    }
}

// Auto-detect start address from reset vector
void Disassemble(const uint8_t data[], unsigned int length)
{
    uint8_t fffe = data[length - 2];
    uint8_t ffff = data[length - 1];
    uint16_t startAddress = ((uint16_t(fffe) << 8) | ffff);
    Disassemble(data, length, startAddress);
}
```

---

## Command Line Usage

```bash
# Auto-detect start from reset vector ($FFFE-$FFFF):
dis68hc11 binary.bin

# Specify start address:
dis68hc11 -s 8000 binary.bin
```

---

## Output Format

Example disassembly output:
```
$8000:  LDAA    $A2         ; Load Accumulator A, direct
$8002:  CMPA    #240        ; Compare A, immediate
$8004:  BCS     $800A       ; Branch if Carry Set
$8006:  JSR     $9234       ; Jump to Subroutine, extended
$8009:  RTS                 ; Return from Subroutine
$800A:  LDAA    TCTL1       ; Load Accumulator A, extended
```

---

## VY V6 ECU Usage

For VY V6 $060A binary:

```bash
# Full 128KB binary (banked):
dis68hc11 -s 8000 VY_V6_060A.bin

# Specific bank:
dis68hc11 -s C000 bank_high.bin
```

---

## VY V6 ECU Specific Addresses (for patching AddressString)

Add these to the disassembler for VY V6 ECU work:

```cpp
// VY V6 ECU RAM locations (Direct Page $00-$FF)
case 0x00A2: return "ENGINE_RPM";      // RPM / 25
case 0x00A4: return "TPS_VOLTS";       // Throttle Position
case 0x00AD: return "COOLANT_TEMP";    // Coolant Temp
case 0x00B0: return "IAC_STEPS";       // Idle Air Control
case 0x0178: return "PERIOD_24X_HI";    // 3X Period High
case 0x0179: return "PERIOD_24X_LO";    // 3X Period Low
case 0x017A: return "PERIOD_24X_COPY";  // Working Copy
case 0x017D: return "DWELL_TIME";      // Coil Dwell

// VY V6 Timer registers for EST
case 0x100E: return "TCNT_HI";         // Timer Counter High
case 0x100F: return "TCNT_LO";         // Timer Counter Low
case 0x1014: return "TIC3_HI";         // Input Capture 3 (24X Crank!)
case 0x1015: return "TIC3_LO";
case 0x101A: return "TOC3_HI";         // Output Compare 3 (EST!)
case 0x101B: return "TOC3_LO";
case 0x1022: return "TMSK1";           // Timer Interrupt Mask 1
case 0x1023: return "TFLG1";           // Timer Interrupt Flag 1
```

---

## ⚠️ Note on dis68hc11 Bugs

The dis68hc11 `Opcodes.h` contains **swapped IMM/DIR modes** for ADCA and ADCB.
See `68HC11_Opcodes_Reference.md` for corrected values.

---

*Generated from dis68hc11 source - January 2026*
*Enhanced with VY V6 ECU specific addresses - January 17, 2026*
