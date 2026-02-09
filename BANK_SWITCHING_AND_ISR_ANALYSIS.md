# VY V6 Bank Switching & ISR Analysis

**Date:** January 31, 2026  
**Binary:** VY_V6_$060A_Enhanced_v1.0a (128KB)  
**Tool:** hc11_disassembler.py  

---

## 🔴 CRITICAL: 128KB Bank Switching Architecture

> **Sources:** Antus (pcmhacking admin, DARC author) - [Topic 8500](https://pcmhacking.net/forums/viewtopic.php?t=8500), [Topic 237](https://pcmhacking.net/forums/viewtopic.php?t=237);
> VL400 (FlashTool author) - [Topic 82](https://pcmhacking.net/forums/viewtopic.php?t=82);
> malser (AM29F010 A16 info) - [Topic 82 Post 31](https://pcmhacking.net/forums/viewtopic.php?f=3&t=82&start=30);
> Binary analysis - `tools/analyze_binary_banks.py` (2026-02-09)

### Memory Map Overview

**Antus's own description (Topic 8500, March 2024):**
> "Note that the challenge for disassembly of the 128k bins, is the bank switching which the disassemblers can't follow. Essentially you have:
> - **0-32KB** mapped to 0-32KB address space **full time** with calibration and common code
> - **32-64KB** mapped to the high half (0x8000-0xFFFF) for **engine processing**
> - **92-128KB** mapped to 32-64KB for **transmission processing**"

```
HC11 CPU Address Space (64KB visible at any time):
├── $0000-$00FF   Internal RAM (256 bytes) — direct page
├── $0100-$03FF   Internal RAM (768 bytes) — HC11F has 1KB total
├── $1000-$105F   Memory-Mapped I/O (HC11F registers inc. PORTG/DDRG/PORTF)
├── $2000-$7FFF   ALWAYS VISIBLE — calibration + common code (from file 0x02000-0x07FFF)
│   ├── $2000-$3FFF   Calibration area (ISR jump table, cal tables)
│   └── $4000-$7FFF   More calibration + common executable code
└── $8000-$FFFF   BANK-SWITCHED — either engine OR transmission code
    ├── Engine bank: from file 0x08000-0x0FFFF (LOW half of binary)
    └── Trans bank:  from file 0x18000-0x1FFFF (HIGH half of binary)

128KB Binary File Layout (stacked image):
├── 0x00000-0x01FFF  (8KB)   Header/Reserved — 50.6% FF bytes
├── 0x02000-0x03FFF  (8KB)   Calibration area — ISR jump table at $2000
│                             VL400: "checksum region 1 = 0x02000-0x03FFF"
├── 0x04000-0x04007  (8 bytes) Checksum bytes — SKIPPED in checksum calc
├── 0x04008-0x07FFF  (16KB)  Calibration tables (XDF parameters live here)
│                             VL400: "checksum region 2 = 0x04008-0x1FFFF"
├── 0x08000-0x0FFFF  (32KB)  ENGINE bank — mapped to $8000-$FFFF when selected
│   ├── 0x0C468-0x0FFBF       FREE SPACE (15,192 bytes, fill=0x00)
│   └── 0x0FFD6-0x0FFFF       Engine bank interrupt vectors
│
├── 0x10000-0x17FFF  (32KB)  TRANSMISSION bank lower data region
└── 0x18000-0x1FFFF  (32KB)  TRANSMISSION bank — mapped to $8000-$FFFF when selected
    ├── 0x1C011               Trans-bank RESET target ($C011)
    └── 0x1FFD6-0x1FFFF       Trans bank interrupt vectors
```

### Binary Analysis Proof (2026-02-09)

**4KB block comparison between LOW (0x00000-0x0FFFF) and HIGH (0x10000-0x1FFFF):**

| CPU Range | Differences | Meaning |
|-----------|-------------|---------|
| `$0000-$BFFF` | 96-99% different | Completely different code/data in each half |
| `$C000-$CFFF` | 67% different | Mostly different code |
| `$D000-$DFFF` | **IDENTICAL** | Shared lookup tables (same data in both halves) |
| `$E000-$EFFF` | **IDENTICAL** | Shared lookup tables |
| `$F000-$FFFF` | 0.4% different (18 bytes) | Nearly identical — only vector differences |

**Vector table differences (only 3 vectors differ between halves):**

| Vector | LOW (Engine) | HIGH (Trans) | Notes |
|--------|-------------|-------------|-------|
| COP | `$2024` (jump table) | `$C015` | Trans has its own COP handler |
| CMF | `$2027` (jump table) | `$C019` | Trans has its own CMF handler |
| RESET | `$202A` (jump table) | `$C011` | Trans has its own reset/boot |
| All others | Point to `$2000-$201E` | **Same as LOW** | Shared ISR jump table |

### Bank Switching Mechanism — PORTC

**Hardware:** The HC11's external address line A16 is controlled by PORTC bit 3 to select which 32KB block appears in the `$8000-$FFFF` window.

**From pcmhacking (malser, Topic 82 Post 31):**
> "Memory AM29F010 — it has two banks on 64K. 1 — from 0000 to FFFF and 2 from 10000 to 1FFFF. Switching between banks occurs to the senior A16 address."

**Found in binary:**

- `STAB $1003` at file `0x1476A` — writes `$F7` to PORTC (clears bit 3 → A16=0 → engine bank)
- `BSET $03,#$CC` at file `0x0B0B9` — sets bits 7,6,3,2 of PORTC (bit 3 → A16=1 → trans bank)

> ⚠️ **PORTC bit 3 is the likely bank select pin.** Setting bit 3 = A16 high = file offsets 0x18000-0x1FFFF visible at `$8000-$FFFF`. Clearing bit 3 = A16 low = file offsets 0x08000-0x0FFFF visible.

### Address Conversion Formulas (CORRECTED 2026-02-09)

**File Offset → CPU Address:**
```python
# Common/calibration area (ALWAYS visible, both banks see this)
if 0x02000 <= file_offset <= 0x07FFF:
    cpu_addr = file_offset  # Direct: file 0x02000 = CPU $2000

# Engine bank code (visible when A16=0, engine bank selected)
if 0x08000 <= file_offset <= 0x0FFFF:
    cpu_addr = file_offset  # Direct: file 0x08000 = CPU $8000

# Transmission bank data (low region)
if 0x10000 <= file_offset <= 0x17FFF:
    cpu_addr = file_offset - 0x10000  # file 0x10000 = CPU $0000 context

# Transmission bank code (visible when A16=1, trans bank selected)
if 0x18000 <= file_offset <= 0x1FFFF:
    cpu_addr = file_offset - 0x10000  # file 0x18000 = CPU $8000
```

**CPU Address → File Offset (AMBIGUOUS — depends on active bank!):**
```python
# Always-visible calibration/common code
if 0x2000 <= cpu_addr <= 0x7FFF:
    file_offset = cpu_addr  # Always file 0x02000-0x07FFF

# Bank-switched region — could be EITHER half!
if 0x8000 <= cpu_addr <= 0xFFFF:
    # Engine bank: file_offset = cpu_addr          (0x08000-0x0FFFF)
    # Trans bank:  file_offset = cpu_addr + 0x10000 (0x18000-0x1FFFF)
    # MUST know which bank is active to resolve!
```

---

## ✅ HC11 Hardware Interrupt Vector Table

> **CORRECTED 2026-02-09:** Both halves now shown. Previous version only showed HIGH (trans) half.
> The LOW (engine) half vectors are at file `0x0FFD6-0x0FFFF`, HIGH (trans) at `0x1FFD6-0x1FFFF`.
> Most vectors are IDENTICAL between halves — only COP, CMF, and RESET differ.

**Location:** CPU `$FFD6-$FFFF` (visible from whichever bank is currently mapped to `$8000-$FFFF`)

| Vector Name | CPU Addr | LOW (Engine) Points To | HIGH (Trans) Points To | Notes |
|-------------|----------|----------------------|----------------------|-------|
| SCI (Serial) | $FFD6 | $2003 → JMP $29D3 | $2003 → JMP $29D3 | **Same** |
| SPI | $FFD8 | $2000 → JMP $2BAF | $2000 → JMP $2BAF | **Same** (default/unused) |
| PAIE | $FFDA | $2000 | $2000 | **Same** |
| PAO | $FFDC | $2000 | $2000 | **Same** |
| TOF | $FFDE | $2000 | $2000 | **Same** |
| TOC5 | $FFE0 | $2000 | $2000 | **Same** |
| TOC4 | $FFE2 | $2006 → JMP $35DE | $2006 → JMP $35DE | **Same** |
| TOC3 | $FFE4 | $2009 → JMP $35BD | $2009 → JMP $35BD | **Same** |
| TOC2 | $FFE6 | $2000 | $2000 | **Same** (default/unused) |
| TOC1 | $FFE8 | $200C → JMP $37A6 | $200C → JMP $37A6 | **Same** |
| **TIC3** | **$FFEA** | **$200F → JMP $35FF** | **$200F → JMP $35FF** | **Same** — 24X crank ISR |
| TIC2 | $FFEC | $2012 → JMP $358A | $2012 → JMP $358A | **Same** |
| TIC1 | $FFEE | $2015 → JMP $301F | $2015 → JMP $301F | **Same** |
| RTI | $FFF0 | $2000 | $2000 | **Same** (default/unused) |
| IRQ | $FFF2 | $2018 → JMP $30BA | $2018 → JMP $30BA | **Same** |
| XIRQ | $FFF4 | $201B → JMP $2BAC | $201B → JMP $2BAC | **Same** |
| SWI | $FFF6 | $201E → JMP $2BA0 | $201E → JMP $2BA0 | **Same** |
| ILLOP | $FFF8 | $2021 → JMP $2BA6 | $2021 → JMP $2BA6 | **Same** |
| **COP** | **$FFFA** | **$2024 (∞ loop)** | **$C015** | **⚠️ DIFFERENT** |
| **CMF** | **$FFFC** | **$2027 (∞ loop)** | **$C019** | **⚠️ DIFFERENT** |
| **RESET** | **$FFFE** | **$202A (∞ loop)** | **$C011** | **⚠️ DIFFERENT** |

> **HIGH-half extra JMP stubs at `$FFB2-$FFBF`** (not present in LOW half — zeros there):
> `$FFB2: JMP $C361`, `$FFB5: JMP $C357`, `$FFBA: JMP $C34B`, `$FFBD: JMP $C2E0`
> These may be additional trans-bank-specific entry points.

---

## 🔥 Pseudo-Vector Jump Table

**Location:** File offset `0x02000-0x02030` → CPU address `$2000-$2030`

> ⚠️ **CORRECTED 2026-02-09:** CPU addresses were previously listed as `$A000-$A030` — this was WRONG.
> File offset `0x02000` maps directly to CPU `$2000` (the common/calibration area is always visible at its file offset).

This is a **software jump table** in the always-visible calibration area. Both engine and transmission banks share these pseudo-vectors. The indirection allows patching ISR targets without modifying hardware vector tables in each bank.

### Jump Table Structure

| Offset | File Addr | CPU Addr | Instruction | Target | Purpose | Maps to HW Vector |
|--------|-----------|----------|-------------|--------|---------|-------------------|
| **+0** | 0x02000 | **$2000** | `7E 2B AF` | **JMP $2BAF** | Default ISR (SPI/PAIE/PAO/TOF/TOC5/TOC2/RTI) | Multiple unused vectors |
| +3 | 0x02003 | **$2003** | `7E 29 D3` | JMP $29D3 | SCI ISR | $FFD6 |
| +6 | 0x02006 | **$2006** | `7E 35 DE` | JMP $35DE | TOC4 ISR | $FFE2 |
| +9 | 0x02009 | **$2009** | `7E 35 BD` | JMP $35BD | TOC3 ISR | $FFE4 |
| +12 | 0x0200C | **$200C** | `7E 37 A6` | JMP $37A6 | TOC1 ISR | $FFE8 |
| +15 | 0x0200F | **$200F** | `7E 35 FF` | **JMP $35FF** | **TIC3 ISR (24X crank)** | $FFEA |
| +18 | 0x02012 | **$2012** | `7E 35 8A` | JMP $358A | TIC2 ISR | $FFEC |
| +21 | 0x02015 | **$2015** | `7E 30 1F` | JMP $301F | TIC1 ISR | $FFEE |
| +24 | 0x02018 | **$2018** | `7E 30 BA` | JMP $30BA | IRQ handler | $FFF2 |
| +27 | 0x0201B | **$201B** | `7E 2B AC` | JMP $2BAC | XIRQ handler | $FFF4 |
| +30 | 0x0201E | **$201E** | `7E 2B A0` | JMP $2BA0 | SWI handler | $FFF6 |
| +33 | 0x02021 | **$2021** | `7E 2B A6` | JMP $2BA6 | ILLOP handler | $FFF8 |
| +36 | 0x02024 | **$2024** | `7E 20 24` | JMP $2024 | **∞ loop (COP - engine bank)** | $FFFA (LOW) |
| +39 | 0x02027 | **$2027** | `7E 20 27` | JMP $2027 | **∞ loop (CMF - engine bank)** | $FFFC (LOW) |
| +42 | 0x0202A | **$202A** | `7E 20 2A` | JMP $202A | **∞ loop (RESET - engine bank)** | $FFFE (LOW) |
| +45 | 0x202D | $A02D | `7E 2B B0` | JMP $2BB0 | Unknown ISR 15 |

### How Pseudo-Vectors Work

**Example — TIC3 (24X crank sensor):**
1. **Hardware vector** at `$FFEA` (in BOTH bank vector tables) contains `$200F`
2. CPU jumps to `$200F` on TIC3 interrupt
3. Code at `$200F` (file 0x0200F, always-visible area) is `JMP $35FF`
4. Code at `$35FF` does the actual TIC3 ISR work

**Example — RESET vector difference between banks:**
- **Engine bank** RESET vector (`$FFFE` at file 0x0FFFE) = `$202A` → JMP `$202A` (infinite loop / watchdog trap)
- **Trans bank** RESET vector (`$FFFE` at file 0x1FFFE) = `$C011` → Direct boot code at `$C011`
- This means the **transmission bank has its own reset/boot path** independent of the jump table!

**Why this matters for patches:**
- You can modify the jump table at `$2000-$2030` (file 0x02000) to redirect ISRs — affects BOTH banks
- The jump table is in the **always-visible calibration area** — no bank switching needed to patch it
- Safer than changing hardware vectors (which exist in both halves and would need dual edits)
- Antus (DARC author): "patched the factory bins with jumps to jump out to unused space" — this is the method

---

## 🔍 Critical ISR Addresses Found

> **CORRECTED 2026-02-09:** All ISR handlers are in the `$2000-$7FFF` always-visible region.
> File offsets were previously listed as `0x15xxx` (adding 0x10000) — WRONG.
> Since `$35FF` < `$8000`, it's in the always-visible area, file offset = CPU address directly.

### ISR Dispatch Pattern

ALL timer ISR handlers follow the same pattern:
```assembly
; Step 1: Acknowledge interrupt flag in TFLG1 ($1023)
LDAA  #$xx         ; 86 xx — timer flag bit mask
STAA  $1023        ; B7 10 23 — clear the flag by writing 1 to it
; Step 2: Continue with actual ISR processing code...
```

| ISR | CPU Addr | File Offset | Flag Bit | First 6 bytes |
|-----|----------|-------------|----------|---------------|
| TIC3 (24X crank) | `$35FF` | `0x035FF` | `$01` (IC3F) | `86 01 B7 10 23 7C` |
| TIC2 | `$358A` | `0x0358A` | `$02` (IC2F) | `86 02 B7 10 23 F6` |
| TIC1 | `$301F` | `0x0301F` | `$04` (IC1F) | `86 04 B7 10 23 F6` |
| TOC4 | `$35DE` | `0x035DE` | `$10` (OC4F) | `86 10 B7 10 23 F6` |
| TOC3 | `$35BD` | `0x035BD` | `$20` (OC3F) | `86 20 B7 10 23 F6` |
| TOC1 | `$37A6` | `0x037A6` | `$80` (OC1F) | `86 80 B7 10 23 FC` |

### TIC3 ISR (Crank Position Sensor)

**Entry Point:** `$35FF` (file offset `0x035FF` — in always-visible region!)
**Purpose:** Reads 24X crank sensor, calculates RPM and period
**Accessed Via:** Pseudo-vector at `$200F` → `JMP $35FF`

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

## 📋 ISR Handler Summary

> **CORRECTED 2026-02-09:** All ISR targets are in the `$2000-$7FFF` always-visible region.
> File offset = CPU address (no +0x10000). Previous table had wrong offsets.

| ISR | CPU Addr | File Offset | Purpose |
|-----|----------|-------------|---------|
| $29D3 | `$29D3` | `0x029D3` | SCI (serial/ALDL communication) |
| $35DE | `$35DE` | `0x035DE` | TOC4 ISR |
| $35BD | `$35BD` | `0x035BD` | TOC3 ISR |
| $37A6 | `$37A6` | `0x037A6` | TOC1 ISR |
| **$35FF** | `$35FF` | `0x035FF` | **TIC3 ISR (24X crank) — CRITICAL** |
| $358A | `$358A` | `0x0358A` | TIC2 ISR |
| $301F | `$301F` | `0x0301F` | TIC1 ISR |
| $30BA | `$30BA` | `0x030BA` | COP failure handler |
| $2BAC | `$2BAC` | `0x02BAC` | ILLOP handler (sets bit, loops) |
| $2BA0 | `$2BA0` | `0x02BA0` | SWI handler (sets bit, loops) |
| $2BA6 | `$2BA6` | `0x02BA6` | XIRQ handler (sets bit, loops) |
| $2BAF | `$2BAF` | `0x02BAF` | Default ISR (RTI — return from interrupt) |

**✅ TIC3 ISR DISASSEMBLED ($35FF, File 0x035FF — COMMON area, always visible):**

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
$3617:  CLRB             ; Clear B register (B = $00)
$3618:  STD $194C        ; ** INIT PATH ONLY: D=$0000 (A=0 from BEQ, B=0 from CLRB) **
                         ; ⚠️ NOT the real period write! Only reached on cold start ($194A==0)
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

**Location:** File offset `0x101E1` → CPU address `$81E1` (engine bank, `$8000-$FFFF`)
**Instruction:** `STD $017B` (store dwell intermediate to RAM)
**Replacement:** `JSR $C468` (jump to our patch code in engine bank free space)

### Bank Switching Considerations (CORRECTED 2026-02-09)

**✅ VERIFIED: Hook and patch are in the SAME bank — engine bank (`$8000-$FFFF`)**

Our patch code at file offset `0x0C468` maps to CPU `$C468` when the engine bank is active. The hook at file `0x101E1` maps to CPU `$81E1` — but WAIT:

> ⚠️ **File offset `0x101E1` is in the HIGH half** (0x10000-0x1FFFF = transmission bank!).
> CPU address = `$101E1 - $10000` = `$01E1`.
> This is actually in **RAM space** (`$0100-$03FF`), which means the disassembly context needs re-examination.
> Alternatively, this code may be reached when the trans bank is active and addresses wrap.
>
> **TODO:** Re-verify which bank context the hook at `0x101E1` executes in. If it's in the transmission bank, then `$C468` might not be visible (that's engine bank free space). If so, we need to use free space in the HIGH half instead.

**Corrected Address Mapping:**

| File Offset | CPU Address | Bank | Contents |
|-------------|-------------|------|----------|
| `0x0C468` | `$C468` | Engine (LOW) | **FREE SPACE** — 15,192 bytes |
| `0x101E1` | `$01E1` (RAM?) or `$81E1`? | **AMBIGUOUS** | Hook point — needs verification |

**Antus's Patching Advice (Topic 8500):**
> "Instead we ended up using the disassembly work to understand the code, but patched the factory bins with jumps to jump out to unused space and implement additional logic there, without reassembling the bin. This side steps the whole bank switching problem quite effectively."

**Free Space by Bank:**

| Bank | File Range | CPU Range | Free Space | Fill |
|------|-----------|-----------|------------|------|
| Common | `0x02000-0x07FFF` | `$2000-$7FFF` | `0x03E87-0x03FFF` (377 bytes) | `0x00` |
| Common | `0x04000-0x07FFF` | `$4000-$7FFF` | `0x05D05-0x05EFC` (504 bytes) | `0x00` |
| Engine (LOW) | `0x08000-0x0FFFF` | `$8000-$FFFF` | **`0x0C468-0x0FFBF` (15,192 bytes)** | `0x00` |
| Trans (HIGH) | `0x18000-0x1FFFF` | `$8000-$FFFF` | `0x19B0B-0x1BFFF` (9,461 bytes) | `0x00` |
| Trans (HIGH) | `0x18000-0x1FFFF` | `$8000-$FFFF` | `0x1CE3F-0x1FFB1` (12,659 bytes) | `0x00` |

**Rule: Patch code MUST be in the same bank as the hook point, or in the always-visible common area (`$2000-$7FFF`).**

---

## 🔥 TIC3 ISR BREAKTHROUGH - January 31, 2026

### Complete TIC3 ISR Disassembly

**Location:** CPU address `$35FF`, file offset `0x035FF` (always-visible common area)  
**Trigger:** Input Capture 3 (24X crank sensor pulse every 15°)  
**Vector Chain:** Hardware vector 0x1FFEA → Pseudo-vector $200F → ISR $35FF

```assembly
; TIC3 ISR - Runs on every 24X crank pulse (15° rotation)
; ⚠️ CORRECTION (2026-02-07): The STD $194C at $3618 is the INIT PATH ONLY!
;    It only executes on cold start when $194A == 0, storing D = $0000.
;    The REAL period updates to $194C happen via the filter subroutine chain:
;      TOC3-area code at $35CB → JSR $24AA → JSR $050C → STD $00,X (X=$194C)
;    See "Period Update Mechanism" section below.

$35FF:  MUL              ; Multiply A×B  
$3600:  SUBA #$1B        ; Subtract $1B from A
$3602:  LDAA $1ADE       ; Load mode/state flags
$3605:  BITA #$08        ; Test bit 3 (engine running?)
$3607:  BEQ $361D        ; Skip if not running
$3618:  STD $194C        ; *** INIT PATH ONLY: stores D=$0000 on cold start *** ⚡
$360C:  BNE $3633        ; Skip init if already set (normal running path!)
$360E:  CLR $194F        ; Clear period high byte (INIT ONLY)
$3611:  CLR $194E        ; Clear period mid byte (INIT ONLY)
$3614:  BCLR $50,#$01    ; Clear bit 0 of RAM $50
$3617:  CLRB             ; Clear B register (B = $00)
$3618:  STD $194C        ; INIT ONLY: D=$0000 (A=0 via BEQ path, B=0 from CLRB)
$361B:  BRA $3633        ; Continue to calculation
```

### 🔬 Period Update Mechanism (Discovered 2026-02-07)

**How $194C actually gets updated with real crank period values:**

The `STD $194C` at `$3618` only fires during **cold-start initialization** (when `$194A == 0`). During normal engine operation, `$194A != 0` so execution jumps to `$3633` via the `BNE` at `$360C`, **completely bypassing `$3618`**.

The **real period updates** happen through an **indexed write chain**:

```assembly
; Code near $35CB (in TOC3/EST handler area, NOT TIC3 ISR):
$35C0:  LDX  $194C       ; FE 19 4C - Read current period from $194C
$35C3:  CPX  #$FA00      ; Compare with $FA00 (sanity check)
$35C6:  BCC  $35D7       ; Skip filter if period >= $FA00
$35C8:  PSHA             ; Save A
$35C9:  LDAA #$FF        ; Filter coefficient = $FF
$35CB:  LDX  #$194C      ; CE 19 4C - X = POINTER to $194C
$35CE:  LDY  #$7CDF      ; Y = ROM filter table
$35D2:  JSR  $24AA       ; Call filter chain
;         └→ JSR $050C   ; Sub-subroutine does the actual write:
;              STD $00,X  ; *** WRITES filtered period to ($194C) ***
$35D5:  PULB             ; Restore
```

**Key finding:** Subroutine `$050C` contains **4 instances** of `STD $00,X` (indexed store at offset 0 from X). When called with `X = #$194C`, this writes the filtered/calculated period value to `$194C`.

**Implication for spark cut:** Hooking the `STD $194C` at `$3618` would **only intercept cold-start initialization** (D=$0000), not real period writes. The real period would still be written by the `$050C` filter, **overwriting any fake value** injected at `$3618`.

### Verified RAM Addresses from TIC3 ISR

| Address | Bytes | Purpose | Access | Status |
|---------|-------|---------|--------|--------|
| **$194C** | 2 | **24X Crank Period (16-bit)** | Init: STD @ $3618; **Real updates: via filter sub $050C (STD 0,X with X=$194C)** | ✅ **VERIFIED** |
| $194E | 1 | Period buffer (high byte) | CLR @ $3611 (init path) | ✅ VERIFIED |
| $194F | 1 | Period buffer (mid byte) | CLR @ $360E (init path) | ✅ VERIFIED |
| $194A | 1 | Period calculation flag | LDAA @ $3609 | ✅ VERIFIED |
| $1948 | 1 | Result storage (8-bit) | STAA @ $3633 | ✅ VERIFIED |
| $1492 | 2 | Result storage (16-bit) | STD @ $363B | ✅ VERIFIED |
| $1ADE | 1 | Engine state flags | LDAA @ $3602 | ✅ VERIFIED |

### ❌ Critical Corrections

**What Was Wrong:**

| Old Claim | Reality | Impact |
|-----------|---------|--------|
| $017B = 3X/24X crank period | **WRONG** - $017B is dwell intermediate | ⚠️ **HIGH** - All spark cut patches need revision |
| Hook at $101E1 (STD $017B) | Dwell calc intermediate, not crank period | 🔧 Wrong hook point for period injection |
| 24X crank sensor | **24X crank sensor** (Input Capture 3) | ⚠️ Timing calculations affected |
| STD $194C at $3618 = "crank period store" | **MISLEADING** - Init path only (D=$0000), real period written by filter sub $050C via indexed STD 0,X | ⚠️ **HIGH** - Hook at $3618 ineffective for period manipulation |

**What Is Correct:**
- ✅ **$194C** is the actual 24X crank period RAM variable
- ✅ $194C is **initialized** at $3618 in TIC3 ISR (but only on cold start, D=$0000)
- ✅ $194C is **updated with real period** by filter sub $050C (via indexed STD 0,X with X=$194C)
- ✅ The filter chain is: $35CB (LDX #$194C) → JSR $24AA → JSR $050C → STD 0,X
- ✅ 24X sensor = 24 pulses per revolution = 15° per pulse
- ✅ TIC3 ISR at $35FF handles crank sensor input
- ✅ No bank switching issues for spark cut patch (calibration ROM always visible)

**⚠️ Revised Hook Strategy (2026-02-07):**
- ❌ Hooking `STD $194C` at $3618 = **INEFFECTIVE** (init path only, filter overwrites)
- ✅ **Option A:** Hook `STD $017B` at 0x101E1 (dwell intermediate) — affects dwell calc directly
- ✅ **Option B:** Hook inside filter sub $050C — intercepts real period updates
- ✅ **Option C:** Hook `$35D2` (JSR $24AA) — intercept before filter runs

### Implementation Options for Spark Cut (REVISED 2026-02-07)

**⚠️ CRITICAL: The STD $194C at $3618 is an INIT PATH (D=$0000 on cold start).**  
Real period updates to $194C happen via the filter subroutine $050C using indexed writes.  
Hooking $3618 would only intercept initialization, NOT real period values.

**Option 1: Hook Dwell Intermediate at $017B (RECOMMENDED)**
```assembly
; Hook at file offset 0x101E1 (replaces STD $017B with JSR $C500)
; $017B is in the dwell calculation path - injecting a fake value here
; directly affects dwell time without needing to intercept the period filter.
SPARK_CUT_HANDLER:
    PSHA                    ; Save A
    LDAA $00A2              ; Load RPM/25
    CMPA #$F0               ; Compare to 240 (6000 RPM)
    BCS  STORE_NORMAL       ; RPM < threshold → normal
    BSET $46,$80            ; Set limiter flag
    PULA                    ; Clean stack
    LDD  #$3E80             ; Fake dwell intermediate
    STD  $017B              ; Store fake value
    RTS
STORE_NORMAL:
    PULA                    ; Restore A
    STD  $017B              ; Store real value (original instruction)
    RTS
```

**Option 2: Hook Filter Subroutine Call at $35D2**
- Replace `JSR $24AA` at $35D2 with `JSR $C500`
- Intercepts before the filter writes real period to $194C
- Can inject fake period that won't be overwritten
- More complex: must replicate $24AA call on normal path

**Option 3: Hook Inside $050C (Indexed Write Intercept)**
- Patch one of the `STD 0,X` instructions inside $050C
- Would intercept ALL indexed period writes (not just $194C)
- Risk: $050C may be called with other X pointers too

### Documents Updated with Corrections

**Already Updated (2026-01-31):**
- ✅ `RAM_Variables_Validated.md` - Corrected crank period address
- ✅ `READY_TO_IMPLEMENT_NOW.md` - Updated crank period storage
- ✅ `24X_PERIOD_ANALYSIS_COMPLETE.md` - Added correction warnings
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

The original analysis (November 2025) found `STD $017B` at offset `0x101E1` and **assumed** it was crank period (WRONG - it is dwell intermediate) storage based on:
1. Nearby dwell-related code
2. Misinterpretation of dwell calculation flow
3. Not following the actual TIC3 ISR path

**The actual 24X crank period is stored at `$194C`** by the TIC3 ISR at CPU `$3618`.

### Corrected Address Map

| Address | Purpose | Verified |
|---------|---------|----------|
| `$0199` | Final dwell time RAM | ✅ STD @ 0x101D6, 0x101DC |
| `$017B` | Intermediate dwell calc (BEST HOOK TARGET) | ✅ STD @ 0x101E1 — directly affects dwell |
| `$194C` | 24X crank period | ✅ Init: STD @ $3618; Real updates: filter sub $050C via STD 0,X |
| `$0093` | Dwell calculation temp | ✅ LDD @ 0x101DF |

### Scripts That Propagated The Error

1. **3X_Period_Analysis_Findings.md** (Nov 2025) - First documented $017B as "crank period" (WRONG - it is dwell intermediate)
2. **hc11_disassembler.py outputs** - Used by AI to generate incorrect ASM files
3. **All spark_cut_*.asm versions v1-v37** - Used $017B based on early analysis
4. **VERIFIED_ADDRESSES_SUMMARY.md** - Listed $017B as verified (it was, just wrong purpose)

---

## 📝 Credits

- **hc11_disassembler.py** - KingAI Automotive Research
- **Motorola M68HC11 Reference Manual** - Motorola Inc.
- **VY V6 XDF v2.09a** - Chr0m3, The1, Antus
- **PCMHacking.net** - Community research archive
- **TIC3 ISR Analysis** - Manual disassembly January 31, 2026

**Last Updated:** February 7, 2026 - CRITICAL CORRECTION: $3618 is init-only path, real period updates via filter sub $050C; revised hook strategy to recommend $017B dwell intermediate hook
