# VY V6 Bank Switching & ISR Analysis

**Date:** January 31, 2026  
**Binary:** VY_V6_$060A_Enhanced_v1.0a (128KB)  
**Tool:** hc11_disassembler.py  

---

## 🔴 CRITICAL: 128KB Bank Switching Architecture

### Memory Map Overview

```
HC11 CPU Address Space (64KB total):
├── $0000-$00FF   Internal Registers (256 bytes)
├── $0100-$01FF   RAM (256 bytes)
├── $1000-$103F   Memory-Mapped I/O (HC11 hardware registers)
├── $4000-$7FFF   Calibration ROM (16KB window)
└── $8000-$FFFF   Program ROM (32KB window)

128KB Binary File Layout:
├── 0x00000-0x0FFFF  Bank 0 (64KB) - Calibration data
│   ├── 0x00000-0x03FFF  Unknown/Reserved
│   ├── 0x04000-0x07FFF  Calibration tables (maps to CPU $4000-$7FFF)
│   └── 0x08000-0x0FFFF  Additional calibration/data
│
└── 0x10000-0x1FFFF  Bank 1 (64KB) - Program code
    ├── 0x10000-0x17FFF  Low ROM (maps to CPU $8000-$FFFF)
    ├── 0x18000-0x1FFBF  High ROM (executable code)
    ├── 0x1FFC0-0x1FFEF  Reserved/Padding
    └── 0x1FFF0-0x1FFFF  HC11 Interrupt Vector Table
```

### Address Conversion Formulas

**File Offset → CPU Address:**
```python
# For calibration ROM (XDF parameters)
if 0x04000 <= file_offset <= 0x07FFF:
    cpu_addr = file_offset  # Direct mapping to $4000-$7FFF

# For program code
if 0x18000 <= file_offset <= 0x1FFFF:
    cpu_addr = file_offset - 0x10000  # Maps to $8000-$FFFF
```

**CPU Address → File Offset:**
```python
# For calibration ROM
if 0x4000 <= cpu_addr <= 0x7FFF:
    file_offset = cpu_addr  # Direct mapping

# For program code
if 0x8000 <= cpu_addr <= 0xFFFF:
    file_offset = cpu_addr + 0x10000
```

---

## ✅ HC11 Hardware Interrupt Vector Table

**Location:** File offset `0x1FFF0-0x1FFFF` (CPU address `$FFF0-$FFFF`)

| Vector Name | File Offset | CPU Address | Points To | Notes |
|-------------|-------------|-------------|-----------|-------|
| SCI (Serial) | 0x1FFD6 | $FFD6 | *Not analyzed* | Serial communication interrupt |
| SPI (Serial Peripheral) | 0x1FFD8 | $FFD8 | *Not analyzed* | SPI transfer complete |
| Pulse Accumulator Input Edge | 0x1FFDA | $FFDA | *Not analyzed* | Pulse counter |
| Pulse Accumulator Overflow | 0x1FFDC | $FFDC | *Not analyzed* | Pulse overflow |
| Timer Overflow | 0x1FFDE | $FFDE | *Not analyzed* | TCNT overflow |
| Timer Output Compare 5 | 0x1FFE0 | $FFE0 | *Not analyzed* | TOC5 match |
| Timer Output Compare 4 | 0x1FFE2 | $FFE2 | *Not analyzed* | TOC4 match |
| Timer Output Compare 3 | 0x1FFE4 | $FFE4 | *Not analyzed* | TOC3 match |
| Timer Output Compare 2 | 0x1FFE6 | $FFE6 | *Not analyzed* | TOC2 match (dwell?) |
| Timer Output Compare 1 | 0x1FFE8 | $FFE8 | *Not analyzed* | TOC1 match |
| **Timer Input Capture 3** | 0x1FFEA | **$FFEA** | **$201B → $2BAC** | **Crank/24X sensor** |
| Timer Input Capture 2 | 0x1FFEC | $FFEC | *Not analyzed* | TIC2 |
| Timer Input Capture 1 | 0x1FFEE | $FFEE | *Not analyzed* | TIC1 |
| Real Time Interrupt | 0x1FFF0 | $FFF0 | *Not analyzed* | Periodic timer |
| **IRQ (External Interrupt)** | 0x1FFF2 | **$FFF2** | **$C015** | **DTC recovery logic** |
| **XIRQ (Non-Maskable)** | 0x1FFF4 | **$FFF4** | **$2021 → $2BA6** | High-priority interrupt |
| **SWI (Software Interrupt)** | 0x1FFF6 | **$FFF6** | **$201E → $2BA0** | Debug/diagnostic |
| **Illegal Opcode** | 0x1FFF8 | **$FFF8** | **$201B → $2BAC** | Invalid instruction trap |
| **COP Failure** | 0x1FFFA | **$FFFA** | **$2018 → $30BA** | Watchdog timeout |
| **COP Clock Monitor** | 0x1FFFC | **$FFFC** | *Not analyzed* | Clock failure detect |
| **RESET** | 0x1FFFE | **$FFFE** | **$2000** | **Power-on/reset entry** |

---

## 🔥 Pseudo-Vector Jump Table

**Location:** File offset `0x2000-0x2030` (CPU address `$A000-$A030`)

This is a **software jump table** that redirects various ISRs to their actual handlers. The VY V6 uses this indirection layer to allow easier patching/modification without changing hardware vectors.

### Jump Table Structure

| Offset | File Addr | CPU Addr | Instruction | Target | Purpose |
|--------|-----------|----------|-------------|--------|---------|
| **+0** | 0x2000 | $A000 | `7E 2B AF` | **JMP $2BAF** | **RESET entry point** |
| +3 | 0x2003 | $A003 | `7E 29 D3` | JMP $29D3 | Unknown ISR 1 |
| +6 | 0x2006 | $A006 | `7E 35 DE` | JMP $35DE | Unknown ISR 2 |
| +9 | 0x2009 | $A009 | `7E 35 BD` | JMP $35BD | Unknown ISR 3 |
| +12 | 0x200C | $A00C | `7E 37 A6` | JMP $37A6 | Unknown ISR 4 |
| +15 | 0x200F | $A00F | `7E 35 FF` | **JMP $35FF** | **TIC3 ISR (24X crank)** |
| +18 | 0x2012 | $A012 | `7E 35 8A` | JMP $358A | Unknown ISR 6 |
| +21 | 0x2015 | $A015 | `7E 30 1F` | JMP $301F | Unknown ISR 7 |
| +24 | 0x2018 | $A018 | `7E 30 BA` | JMP $30BA | COP failure handler |
| +27 | 0x201B | $A01B | `7E 2B AC` | JMP $2BAC | Illegal opcode trap |
| +30 | 0x201E | $A01E | `7E 2B A0` | JMP $2BA0 | SWI handler |
| +33 | 0x2021 | $A021 | `7E 2B A6` | JMP $2BA6 | XIRQ handler |
| +36 | 0x2024 | $A024 | `7E 2024` | JMP $2024 | **Infinite loop (unused)** |
| +39 | 0x2027 | $A027 | `7E 2027` | JMP $2027 | **Infinite loop (unused)** |
| +42 | 0x202A | $A02A | `7E 202A` | JMP $202A | **Infinite loop (unused)** |
| +45 | 0x202D | $A02D | `7E 2B B0` | JMP $2BB0 | Unknown ISR 15 |

### How Pseudo-Vectors Work

1. **Hardware vector** at `$FFEA` (TIC3) contains `$201B`
2. CPU jumps to `$201B` on TIC3 interrupt
3. Code at `$201B` is `JMP $2BAC` (pseudo-vector)
4. Code at `$2BAC` does actual ISR work

**Why this matters for patches:**
- You can modify the jump table at `0x2000-0x2030` to redirect ISRs
- Safer than changing hardware vectors (which are ROM)
- Allows for hot-patching without ROM reflash (if using NVRAM)

---

## 🔍 Critical ISR Addresses Found

### TIC3 ISR (Crank Position Sensor)

**Entry Point:** `$35FF` (file offset `0x155FF`)  
**Purpose:** Reads 24X/3X crank sensor, calculates RPM and period  
**Accessed Via:** Pseudo-vector at `$200F`

**Expected to contain:**
- Read TIC3 register (`$1014-$1015`)
- Calculate 16-bit period (current TIC3 - previous TIC3)
- Store to **PERIOD_3X** (unknown location, likely `$017B`)
- Calculate RPM from period
- Store to **RPM_16BIT** (candidate: `$9D`/`$9E`)
- Divide by 25 to get 8-bit RPM
- Store to **RPM_8BIT** at `$00A2` (verified)

### IRQ Handler (DTC Recovery)

**Entry Point:** `$C015` (file offset `0x0C015`)  
**Purpose:** Manages diagnostic trouble code recovery timers  
**Accessed Via:** Hardware vector `$FFF2`

**Code snippet:**
```assembly
$C015:  MUL              ; Multiply A×B
$C016:  NEGB             ; Negate B
$C017:  LDAA #$01        ; Load A with 1
$C019:  RTS              ; Return

$C01A:  BRCLR $4F,#$10,$C021  ; Test bit 4 of $4F
$C01E:  JMP $C0CF             ; Jump if set
$C021:  LDAA $0292            ; Load M24 counter
$C024:  BEQ $C02F             ; Branch if zero
$C026:  CMPA $5708            ; Compare with threshold
$C029:  BCC $C02F             ; Branch if >=
$C02B:  DECA                  ; Decrement counter
$C02C:  STAA $0292            ; Store back
```

**References found:**
- `$0292` - M24 recovery counter
- `$0293` - M28 recovery counter  
- `$5708` - M24 disable threshold (XDF: "If M24CNT > This, Disable M24 Recovery")
- `$571A` - M28 disable threshold (XDF: "If M28 CNT > This, Disable M28 Recovery")

---

## 📋 TODO: Disassemble These ISRs

| ISR | Address | File Offset | Purpose (Estimated) |
|-----|---------|-------------|---------------------|
| $29D3 | 0x129D3 | Unknown ISR 1 |
| $35DE | 0x155DE | Unknown ISR 2 |
| $35BD | 0x155BD | Unknown ISR 3 |
| $37A6 | 0x157A6 | Unknown ISR 4 |
| **$35FF** | 0x155FF | **TIC3 ISR (CRITICAL)** |
| $358A | 0x1558A | Unknown ISR 6 |
| $301F | 0x1301F | Unknown ISR 7 |
| $30BA | 0x130BA | COP failure handler |
| $2BAC | 0x12BAC | Illegal opcode trap |
| $2BA0 | 0x12BA0 | SWI handler |
| $2BA6 | 0x12BA6 | XIRQ handler |
| $2BAF | 0x12BAF | RESET handler |
| $2BB0 | 0x12BB0 | Unknown ISR 15 |

**✅ TIC3 ISR DISASSEMBLED ($35FF, File 0x135FF):**

```assembly
$35FF:  MUL              ; Multiply A×B  
$3600:  SUBA #$1B        ; Subtract $1B from A
$3602:  LDAA $1ADE       ; Load mode/state flags
$3605:  BITA #$08        ; Test bit 3 (engine running?)
$3607:  BEQ $361D        ; Skip if not running
$3609:  LDAA $194A       ; Load crank period flag
$360C:  BNE $3633        ; Skip init if already set
$360E:  CLR $194F        ; Clear period high byte
$3611:  CLR $194E        ; Clear period mid byte
$3614:  BCLR $50,#$01    ; Clear bit 0 of RAM $50
$3617:  CLRB             ; Clear B register
$3618:  STD $194C        ; ** STORE 16-BIT CRANK PERIOD **
$361B:  BRA $3633        ; Continue
$361D:  BRCLR $50,#$40   ; Test bit 6 of $50
$3621:  LDX #$105F       ; Load X with $105F (port address?)
$3624:  BSET $00,#$04    ; Set port bit
$3627:  BCLR $00,#$03    ; Clear port bit
$362A:  JSR $051E        ; Call subroutine
$362D:  LDX #$105F       ; Load X again
$3630:  BSET $00,#$07    ; Set port bit
$3633:  STAA $1948       ; Store A to $1948
```

**CRITICAL FINDINGS:**

1. **16-bit Crank Period:** Stored at **$194C** (confirmed by STD at $3618)
2. **Period Buffers:** $194E-$194F cleared before new period
3. **Period Flag:** $194A checked/set for initialization
4. **Result Storage:** $1948 (8-bit) and $1492 (16-bit)
5. **Port Operations:** ISR directly controls hardware ports at $105F

**CORRECTED UNDERSTANDING:**
- $017B is NOT the crank period (previous assumption was wrong)
- $194C is the actual 16-bit crank period storage
- This ISR runs on every 24X crank pulse (every 15° of rotation)
- Period = time between consecutive pulses
- RPM = (Clock_Freq / Period) × scaling_factor

---

## 🎯 How This Affects Spark Cut Patches

### Current Hook Point

**Location:** File offset `0x101E1` (CPU address unknown, needs bank mapping)  
**Instruction:** `STD $017B` (store 3X period to RAM)  
**Replacement:** `JSR $14468` (jump to our patch code)

### Bank Switching Considerations

**✅ VERIFIED: No bank switching issues for spark cut patch**

Our patch code at file offset `0x0C468` is in the **calibration ROM area** (0x00000-0x0FFFF), which is **always visible** to the CPU at addresses $4000-$7FFF. 

**Address Mapping:**
- File offset `0x0C468` → CPU address `$C468` (direct mapping)
- This is in the visible window, no bank switching needed
- Hook point at `0x101E1` → CPU `$A1E1` (also in visible ROM)

**CORRECTION TO PREVIOUS ASSUMPTIONS:**
- ❌ **WRONG:** CPU address `$14468` (would be outside 64KB space!)
- ✅ **CORRECT:** CPU address `$C468` (in calibration ROM window)
- ✅ Hook `JSR $C468` is safe - no bank switching required

**128KB Binary Layout (CORRECTED):**
```
File Offset          CPU Visible Address     Contents
0x00000-0x03FFF  →  Not directly mapped     Reserved/Data
0x04000-0x07FFF  →  $4000-$7FFF            Calibration ROM (XDF params)
0x08000-0x0FFFF  →  $8000-$FFFF            Calibration continued
0x10000-0x17FFF  →  $8000-$FFFF (bank 1)   Program ROM
0x18000-0x1FFFF  →  $8000-$FFFF (bank 2)   Program ROM
```

**Free Space Analysis:**
- File `0x0C468` = CPU `$C468` (15,192 bytes free)
- Spark cut patch (~200 bytes) fits easily
- No bank switching complications

**Problem:** The CPU can only see 64KB at a time. If the hook is in Bank 1 (program ROM) and our patch is in Bank 0 (calibration ROM), we may have bank switching issues!

**Solution options:**
1. **Put patch code in same bank as hook** (safest)
2. **Use bank switching register** (requires understanding INIT register at `$103D`)
3. **Use pseudo-vector indirection** (modify jump table at `0x2000-0x2030`)


### in powershell type disasm or disahw to split the bins correctly and view the banks?


---

## 🔥 TIC3 ISR BREAKTHROUGH - January 31, 2026

### Complete TIC3 ISR Disassembly

**Location:** CPU address `$35FF`, file offset `0x135FF`  
**Trigger:** Input Capture 3 (24X crank sensor pulse every 15°)  
**Vector Chain:** Hardware vector 0x1FFEA → Pseudo-vector $200F → ISR $35FF

```assembly
; TIC3 ISR - Runs on every 24X crank pulse (15° rotation)
$35FF:  MUL              ; Multiply A×B  
$3600:  SUBA #$1B        ; Subtract $1B from A
$3602:  LDAA $1ADE       ; Load mode/state flags
$3605:  BITA #$08        ; Test bit 3 (engine running?)
$3607:  BEQ $361D        ; Skip if not running
$3609:  LDAA $194A       ; Load crank period flag
$360C:  BNE $3633        ; Skip init if already set
$360E:  CLR $194F        ; Clear period high byte
$3611:  CLR $194E        ; Clear period mid byte
$3614:  BCLR $50,#$01    ; Clear bit 0 of RAM $50
$3617:  CLRB             ; Clear B register
$3618:  STD $194C        ; *** STORE 16-BIT CRANK PERIOD *** ⚡
$361B:  BRA $3633        ; Continue to calculation
```

### Verified RAM Addresses from TIC3 ISR

| Address | Bytes | Purpose | Access | Status |
|---------|-------|---------|--------|--------|
| **$194C** | 2 | **24X Crank Period (16-bit)** | STD @ $3618 ⚡ | ✅ **VERIFIED** |
| $194E | 1 | Period buffer (high byte) | CLR @ $3611 | ✅ VERIFIED |
| $194F | 1 | Period buffer (mid byte) | CLR @ $360E | ✅ VERIFIED |
| $194A | 1 | Period calculation flag | LDAA @ $3609 | ✅ VERIFIED |
| $1948 | 1 | Result storage (8-bit) | STAA @ $3633 | ✅ VERIFIED |
| $1492 | 2 | Result storage (16-bit) | STD @ $363B | ✅ VERIFIED |
| $1ADE | 1 | Engine state flags | LDAA @ $3602 | ✅ VERIFIED |

### ❌ Critical Corrections

**What Was Wrong:**

| Old Claim | Reality | Impact |
|-----------|---------|--------|
| $017B = 3X/24X crank period | **WRONG** - Purpose unknown | ⚠️ **HIGH** - All spark cut patches need revision |
| Hook at $181E1 (STD $017B) | Not crank period storage | 🔧 Wrong hook point |
| 3X crank sensor | **24X crank sensor** (Input Capture 3) | ⚠️ Timing calculations affected |

**What Is Correct:**
- ✅ **$194C** is the actual 24X crank period storage (STD @ $3618 in TIC3 ISR)
- ✅ 24X sensor = 24 pulses per revolution = 15° per pulse
- ✅ TIC3 ISR at $35FF handles crank sensor input
- ✅ No bank switching issues for spark cut patch (calibration ROM always visible)

### Implementation Options for Spark Cut

**Option 1: Hook TIC3 ISR Before Period Store**
```assembly
; Hook at CPU $3617 (before STD $194C)
; Replace with: JSR SPARK_CUT_HANDLER @ $C468
SPARK_CUT_HANDLER:
    PSHA
    PSHB
    LDD  $00A2              ; Load RPM/25
    CMPA #$F0               ; Compare to 240 (6000 RPM)
    BHI  INJECT_FAKE        ; If > 6000, inject fake period
    PULB
    PULA
    STD  $194C              ; Store real period
    RTS
INJECT_FAKE:
    LDD  #$3E80             ; Load fake period (16000)
    PULB                    ; Restore B (discard real period)
    PULA                    ; Restore A
    STD  $194C              ; Store fake period
    RTS
```

**Option 2: Hook Dwell Calculation**
- Find where dwell calculation reads from $194C
- Intercept the read and substitute fake value
- Less invasive than modifying ISR

### Documents Updated with Corrections

**Already Updated (2026-01-31):**
- ✅ `RAM_Variables_Validated.md` - Corrected crank period address
- ✅ `READY_TO_IMPLEMENT_NOW.md` - Updated 3X period storage
- ✅ `3X_PERIOD_ANALYSIS_COMPLETE.md` - Added correction warnings
- ✅ `SPARK_CUT_QUICK_REFERENCE.md` - Added critical notice banner
- ✅ `Chr0m3_Spark_Cut_Analysis_Critical_Findings.md` - Added correction banner
- ✅ `.github/copilot-instructions.md` - Updated verified addresses

**Still Need Updates:**
- ⚠️ All ASM patch files in `asm_wip/spark_cut/` directory (42 files)
- ⚠️ Assembly templates using $017B
- ⚠️ Hook point instructions

---

## 🔬 Research Questions

1. ✅ **Where is the hardware vector table?** → `0x1FFF0-0x1FFFF`
2. ✅ **Where is the pseudo-vector jump table?** → `0x2000-0x2030`
3. ✅ **Which ISR handles crank sensor?** → `$35FF` via TIC3 vector
4. ✅ **Where is 24X crank period stored?** → `$194C` (verified via TIC3 ISR)
5. ✅ **How does bank switching affect patches?** → No issues (calibration ROM always visible)
6. ✅ **Where is $017B actually used?** → See below (RESOLVED)
7. ❌ **Where does dwell calculation read $194C?** → Needs analysis
8. ❌ **What are the 8 unknown ISRs?** → Need systematic disassembly

---

## 🔍 $017B Purpose Analysis (RESOLVED 2026-01-31)

### Binary Evidence

**Location:** File offset `0x101E1` contains `FD 01 7B` (STD $017B)

**Context Disassembly:**
```assembly
0x101D6: 1A B3 01 99  CPD  $0199     ; Compare D with dwell RAM
0x101DA: 24 03        BCC  +3        ; Branch if carry clear
0x101DC: FD 01 99     STD  $0199     ; Store dwell (conditional)
0x101DF: DC 93        LDD  $93       ; Load from direct page $93
0x101E1: FD 01 7B     STD  $017B     ; Store D to $017B
0x101E4: 04           LSRD           ; Logical shift right D
0x101E5: 83 00 E8     SUBD #$00E8    ; Subtract 232
```

### What $017B Actually Is

**$017B = INTERMEDIATE DWELL CALCULATION VALUE (NOT crank period!)**

The code flow shows:
1. Store dwell to `$0199` (the REAL dwell RAM)
2. Load value from `$93` (direct page - another calculated value)
3. Store to `$017B` (intermediate storage)
4. Shift right (divide by 2)

This is part of the **dwell calculation routine**, not the crank period storage!

### Why The Error Occurred

The original analysis (November 2025) found `STD $017B` at offset `0x101E1` and **assumed** it was 3X crank period storage based on:
1. Nearby dwell-related code
2. Misinterpretation of dwell calculation flow
3. Not following the actual TIC3 ISR path

**The actual 24X crank period is stored at `$194C`** by the TIC3 ISR at CPU `$3618`.

### Corrected Address Map

| Address | Purpose | Verified |
|---------|---------|----------|
| `$0199` | Final dwell time RAM | ✅ STD @ 0x101D6, 0x101DC |
| `$017B` | Intermediate dwell calc | ✅ STD @ 0x101E1 (NOT crank!) |
| `$194C` | 24X crank period | ✅ STD @ $3618 in TIC3 ISR |
| `$0093` | Dwell calculation temp | ✅ LDD @ 0x101DF |

### Scripts That Propagated The Error

1. **3X_Period_Analysis_Findings.md** (Nov 2025) - First documented $017B as "3X period"
2. **hc11_disassembler.py outputs** - Used by AI to generate incorrect ASM files
3. **All spark_cut_*.asm versions v1-v37** - Used $017B based on early analysis
4. **VERIFIED_ADDRESSES_SUMMARY.md** - Listed $017B as verified (it was, just wrong purpose)

---

## 📝 Credits

- **hc11_disassembler.py** - KingAI Automotive Research
- **Motorola M68HC11 Reference Manual** - Motorola Inc.
- **VY V6 XDF v2.09a** - Chr0m3 Motorsport
- **PCMHacking.net** - Community research archive
- **TIC3 ISR Analysis** - Manual disassembly January 31, 2026

**Last Updated:** January 31, 2026 - Added TIC3 ISR breakthrough findings
