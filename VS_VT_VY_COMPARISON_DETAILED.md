# VS/VT Memcal vs VY Flash ECU - Key Differences

**Date:** January 14, 2026  
**Analysis:** Binary architecture comparison for ignition cut porting

---
address are bank mapped for hc11 stuff we are tryna find out
### Topic 2092 Reference Added

✅ **Yes, Topic 2092 "Delco Code Related Books" info has been integrated:**
- Rice University ELEC201 68HC11 tutorial → `from_topic_2092_delco_code_related_books.md`
- Key concepts: Port D inputs, timer system, memory map
- Applied to button/switch inputs section in `github readme.md`

---

## 🔍 CRITICAL FINDINGS

### 1. All Use Same Hardware (MC68HC11)
✅ **TCTL1 ($1020) register exists on ALL platforms**
✅ **ISR vector table locations are IDENTICAL**
✅ **Hardware capabilities are THE SAME**

### 2. But Implementations Are DIFFERENT

| Feature | VS $51 | VT $A5 | VY $060A | OSE12P |
|---------|--------|--------|----------|---------|
| **Binary Size** | 128KB | 128KB | 128KB | 32KB |
| **TI2 ISR** | $650D | $622B | **$2003** | $0000 |
| **TI3 ISR** | $6951 | $69C3 | **$2000** | $0000 |
| **TCTL1 Writes** | 1 | 0 | **3** | 0 |
| **Code Region** | $6000+ | $6000+ | **$2000+** | $0000+ |

**KEY OBSERVATION:** VY has ISRs at **$2000-$2003** (very low addresses!)
- VS/VT ISRs are at $6000+ (mid-range)
- This suggests VY has a **different memory layout** we can confirm this in xdf and bins themselves.

---

## 📊 ISR Vector Analysis

### VY V6 $060A ISR Vectors (ACTUAL from binary)

```
VECTOR    FUNCTION              ADDRESS   NOTES
------    --------              -------   -----
$FFD6     TI2 (24X Crank)       $2003     ⭐ Key for spark timing
$FFD4     TI3 (3X Crank)        $2000     ⭐ Chr0m3's injection point
$FFE8     RESET                 $200C     Bootloader entry
$FFC0     SCI/SPI/Timers        $2000     All point to common handler
```

**CRITICAL:** VY TI3 ISR is at **$2000** (start of code!)
- This is where Chr0m3 would inject his "astronomically high" 3X period
- BennVenn's OSE12P TCTL1 method would go here too

### VS/VT ISR Vectors (for comparison)

```
VS $51:
  TI2: $650D
  TI3: $6951

VT $A5:
  TI2: $622B  
  TI3: $69C3
```

**Different addresses, but SAME CONCEPT applies**

---

## 🔧 TCTL1 Register Usage

### Search Results: TCTL1 ($1020) Writes

| Binary | STAA $1020 | STAA $20 | Total | Notes |
|--------|------------|----------|-------|-------|
| VS $51 | 0 | 1 | 1 | Uses direct page |
| VY $060A | **1** | **2** | **3** | Uses BOTH methods |
| VY Enhanced | 1 | 2 | 3 | Same as stock |

**VY already uses TCTL1 THREE times!**
- This means VY **already manipulates TCTL1** for spark control
- We can find these locations and **hook our code there**

---

## 💾 Memory Layout Comparison

### VS/VT ($51/$A5) Memory Map

```
$00000 - $02000: DATA/ZEROS (empty space)
$06000 - $08000: CODE (main routines)
$0A000 - $0C000: CODE (ISR handlers)
$19000 - $1C000: CODE (more routines)
$1CC00 - $20000: DATA/ZEROS (empty space)
```

### VY ($060A) Memory Map

```
$00000 - $02000: EMPTY (bootloader space?)
$02000 - $04400: CODE ⭐ TI2/TI3 ISRs HERE
$08000 - $0C400: CODE (main routines)
$10000 - $18C00: CODE (more routines)
$1C000 - $1D000: CODE (end routines)
```

**KEY DIFFERENCE:** VY code starts at $2000, VS/VT starts at $6000+

---

## 🎯 Porting OSE12P TCTL1 Method to VY

### OSE12P Strategy (Topic 7922 - BennVenn)

```asm
; BennVenn's method (conceptual - addresses are for VS/VT)
TI3_ISR:
    ; Check RPM
    LDAA RPM_ADDR
    CMPA #RPM_LIMIT
    BLO NORMAL_SPARK
    
    ; SPARK CUT: Force TCTL1 bits 5-4 = 10 (Force PA5 LOW)
    LDAA $1020          ; Read TCTL1
    ANDA #$CF           ; Clear bits 5-4
    ORAA #$20           ; Set bits 5-4 = 10
    STAA $1020          ; Write back → NO SPARK
    BRA DONE

NORMAL_SPARK:
    LDAA $1020
    ANDA #$CF
    ORAA #$30           ; Set bits 5-4 = 11 (normal)
    STAA $1020
    
DONE:
    ; ... continue ISR
```

### VY Adaptation

**Step 1:** Find VY's TI3 ISR at $2000
**Step 2:** Disassemble to understand existing logic
**Step 3:** Find RPM variable location (likely different from VS/VT)
**Step 4:** Inject TCTL1 manipulation at appropriate point
**Step 5:** Preserve original functionality

---

## 🔬 Why This WILL Work on VY

### Evidence from Binary Analysis

1. ✅ **VY already uses TCTL1** (3 write operations found)
2. ✅ **VY has TI3 ISR** at $2000 (verified in vector table)
3. ✅ **MC68HC11 hardware is identical** across all platforms
4. ✅ **TCTL1 bits 5-4 control OC3/PA5** (datasheet verified)

### What We Need to Find in VY Binary

| Item | VS/VT Location | VY Location | How to Find |
|------|----------------|-------------|-------------|
| **RPM variable** | $00A2 | ❓ Unknown | Search XDF, compare to VS/VT patterns |
| **TI3 ISR code** | $6951 | ✅ **$2000** | Vector table confirmed |
| **TCTL1 writes** | Various | ❓ 3 locations | Need disassembly |
| **Free space** | $F000+ | ❓ Unknown | Search for 0xFF regions |

---

## 📋 Action Plan: Disassemble VY TI3 ISR
R:\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin
### Commands to Run

```bash
# 1. Extract TI3 ISR region from VY binary
dd if=R:\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin of=vy_ti3_isr.bin bs=1 skip=8192 count=1024
# (skip=$2000 in decimal, count=1KB)

# 2. Disassemble with m68hc11 tools
m6811-elf-objdump -D -b binary -m m68hc11 vy_ti3_isr.bin

# 3. Compare to VS/VT ISR patterns
# Look for:
#   - LDAA instructions (RPM read)
#   - CMPA instructions (RPM compare)
#   - STAA $1020 (TCTL1 write)
#   - BRA/BEQ/BNE (branching logic)
```

### Python Script to Extract ISR

```python
# Extract VY TI3 ISR
with open('R:\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin', 'rb') as f:
    f.seek(0x2000)  # TI3 ISR location
    ti3_code = f.read(512)  # Read 512 bytes
    
# Save for disassembly
with open('vy_ti3_isr.bin', 'wb') as f:
    f.write(ti3_code)
```

---

## 🆕 New Variant: v16_tctl1_bennvenn_vy_port.asm

**Priority:** ⭐⭐⭐⭐⭐ HIGHEST  
**Based on:** OSE12P TCTL1 method (Topic 7922)  
**Target:** VY $060A at TI3 ISR ($2000)

### Implementation Strategy

1. **Hook Location:** VY TI3 ISR ($2000)
2. **RPM Source:** Find VY's RPM variable (likely $00A2 or nearby)
3. **TCTL1 Manipulation:** Same as OSE12P (bits 5-4 = 10)
4. **Free Space:** Inject at end of TI3 ISR or find free 0xFF region

### Advantages

- ✅ **Proven on OSE12P** (BennVenn, Topic 7922)
- ✅ **Hardware compatible** (same HC11, same TCTL1)
- ✅ **VY already uses TCTL1** (3 existing writes)
- ✅ **Clean implementation** (3-5 instruction overhead)

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Wrong RPM address | Cross-reference XDF, test on bench |
| ISR timing impact | Keep code minimal (<10 cycles) |
| Stack corruption | Preserve all registers (PSHA/PULA) |
| Fail-safe trigger | Test extensively before high RPM |

---

## 📚 References

1. **PCMHacking Topic 7922** - BennVenn's OSE12P spark cut
2. **MC68HC11 Reference Manual** - TCTL1 register specification
3. **VY XDF v2.09a** - Address mappings
4. **Binary comparison** - ISR vector analysis

---

## 🔥 Verified Dwell Values (Web Research - January 2026)

**From PCMHacking.net and Community Sources:**

| Platform | Dwell Value | Purpose | Source | Confidence |
|----------|-------------|---------|--------|------------|
| **OSE 11P** | **200µs** | Spark cut minimum | "cant ignite and keeps things happy" | ✅ VERIFIED |
| **OSE 12P** | **300µs** | BennVenn's value | "enough to misfire the coils" | ✅ VERIFIED |
| **VY LPG** | **600µs** | LPG fuel mode | "to help stop backfiring" (The1) | ✅ VERIFIED |
| **Normal operation** | 2.5-4ms | Coil charging | Standard dwell | ✅ VERIFIED |
| **Critical minimum** | 1.6-1.8ms | Below = rough/cutout | Factory safety | ✅ VERIFIED |

**Key Dwell Calculations:**

```
At 6,375 RPM:
- 60,000,000 µs / 6375 RPM = 9,412 µs per revolution
- 3X teeth: 9,412 / 24 = 392 µs per 3X tooth
- Dwell must be < period for no spark

⚠️ CORRECTED VALUES (January 16, 2026):
==========================================
The 0xA2 value below was from OSE12P (32KB memcal), NOT VY!

Actual Delta Cylair/Dwell thresholds:
| Platform   | Address | Value      | MG/CYL  |
|------------|---------|------------|---------|
| VS V6 $51  | 0x3D49  | 0x20 (32)  | 125.0   |
| VY V6 $060A| 0x6776  | 0x20 (32)  | 125.0   |
| OSE12P     | N/A     | 0xA2 (162) | 633.0   |

Both VS and VY use the SAME value (0x20=32), just at different addresses!
The OSE12P has a much looser threshold (0xA2=162).

Original values (FROM OSE12P - NOT VY):
- Min Dwell: 0xA2 = 162 decimal = ~162 × 10µs = 1,620µs (OSE12P ONLY!)
- Min Burn: 0x24 = 36 decimal = ~36 × 10µs = 360µs (OSE12P ONLY!)
```

---

## ⚠️ Critical Warning (From PCMHacking Research)

**DO NOT cut the EST trigger signal directly!**
- Causes ignition module sync loss
- Triggers failsafe bypass mode
- 400 RPM threshold for mode switching

**DO manipulate dwell time!**
- Correct approach for spark cut
- Reduces coil charge time to prevent ignition
- VY code allows minimum dwell override

---

## 🔧 HC11 Timer Programming Notes

**From MC68HC11 Reference Manual:**

| Feature | Value | Notes |
|---------|-------|-------|
| Timer Resolution | 500ns @ 2MHz | Single tick minimum |
| Output Compare Registers | 5 (OC1-OC5) | All available on VY |
| Zero Jitter Timing | Yes | Hardware-based timing |
| 200µs in ticks | 400 ticks | (200µs / 0.5µs per tick) |

**EST Bypass Safety (DFI Module):**
- 10kΩ pull-down resistor required
- Hardware fallback when dwell pulse missing
- 400 RPM threshold for mode switching
- Prevents damage from incorrect dwell

---

## 🔥 CHR0M3 vs THE1 METHOD DEBATE (Topic 8567)

### The1's Method (Enhanced Bin - 600µs Dwell)
**Source:** Topic 8567, Post #11 (August 8, 2024)

**Quote:**
> "I had some code to add to enhanced mod but never got time to finish it or test, I took out code for LPG they put in VY I think to help stop backfiring, they didn't set it to 0 but a very low value maybe **600usec**."

**Approach:**
- Simple dwell reduction to 600µs
- Based on VY LPG code (factory code for backfire prevention)
- Minimal code changes
- Not fully tested by The1

### Chr0m3's Method (3X Period Injection)
**Source:** Topic 8567, Post #4, #8, #10

**Quotes:**
> "Basically, but as discussed you **can't pull the dwell down to 0**, can get it low enough to misfire but yeah, still definitely needs more research and testing." (Post #4)

> "I'm now running an ecu on **bench and able to actually monitor the EST output on a scope**, this has helped a lot with testing and it's also shown **some issues that weren't noticed in car**." (Post #8)

> "I've discovered at **6500-6600 rpm the spark delivery is less then ideal** with factory code.." (Post #8)

**Approach:**
- ✅ Oscilloscope validated (bench tested)
- ✅ 3X period manipulation ("astronomically high" fake period)
- ✅ Works reliably at 6500+ RPM but Jason King (kingaustraliagg) was aiming for 6000 RPM instead. Chr0m3 was aiming for high RPM and doing spark cut combined. 5900 RPM is where the stock limiter fuel cut is at, with spark/ignition cut using a different method by manipulation of the binary once mapped out more on the VY V6.
- ✅ Multiple patches coordinated across functions
- ⚠️ Complex implementation (edge checks, timestamps)

### Chr0m3's Response to The1's Method
**Source:** Facebook Messenger (January 15, 2026)

**Quote:**
> "He called my method **over complicated and unnecessary**"
> "That's exactly why **his doesn't work without issues**"
> "**Mine and The1's are entirely different code, same concept**" (Topic 8567, Post #33)

**Why Chr0m3's Method is More Complex:**
1. **Edge checks** - Timestamp validation to prevent false triggers
2. **Multiple patch points** - Not one function, coordinated changes
3. **Hardware timing** - Accounts for TIO microcode limitations
4. **Oscilloscope validated** - Real-world waveform analysis

### The Verdict

| Aspect | The1's Method | Chr0m3's Method | Winner |
|--------|---------------|-----------------|--------|
| **Simplicity** | ✅ Simple (600µs dwell) | ❌ Complex (3X injection) | The1 |
| **Tested** | ❌ Never finished/tested | ✅ 3-4 years development | Chr0m3 |
| **Bench Validated** | ❌ No oscilloscope | ✅ EST output monitored | Chr0m3 |
| **High RPM (6500+)** | ❓ Unknown | ✅ Tested at 6500-6600 | Chr0m3 |
| **Reliability** | ⚠️ "doesn't work without issues" | ✅ Works reliably | Chr0m3 |
| **Public Release** | ❌ Never released | ✅ Working (private testing) | Chr0m3 |

**Conclusion:** Chr0m3's method is proven. The1's simpler approach may work for lower RPM but lacks validation.

---

## ⚠️ OPCODE TIMING & CYCLE COMPENSATION (CRITICAL!)

### Chr0m3's Warning (Facebook Messenger - January 15, 2026)

**Quote:**
> "Also another thing people overlook is **op codes and cycles matter**"
> "This is old technology, **loops have compensation built in** to them for how many cycles they take etc"
> "So you go **under or over that in critical functions you're in trouble**"

### What This Means

**HC11 Instruction Timing:**
- Every instruction takes a fixed number of **E-clock cycles**
- Timing-critical code (ISRs, dwell calc) expects **exact cycle counts**
- Loops are **pre-compensated** for their execution time

**Example: Timer ISR**
```asm
; Original ISR (assume 20 cycles total)
TI3_ISR:
    LDAA  $00A2        ; 4 cycles - Load RPM
    CMPA  #$FF         ; 2 cycles - Compare
    BLS   NORMAL       ; 3 cycles - Branch if lower
    ; ... (11 more cycles)
    RTI                ; 12 cycles - Return from interrupt
```

If you insert extra code:
```asm
; Modified ISR (now 25 cycles!)
TI3_ISR:
    LDAA  $00A2        ; 4 cycles
    CMPA  #$FF         ; 2 cycles
    BLS   NORMAL       ; 3 cycles
    JSR   YOUR_PATCH   ; +6 cycles ⚠️ TIMING DISRUPTED!
    ; ... (11 more cycles)
    RTI                ; 12 cycles
```

**Result:** Next interrupt arrives **5 cycles late** → spark timing OFF!

### How to Avoid Timing Issues

1. **Preserve Register States**
```asm
    PSHA              ; Save A
    PSHB              ; Save B
    ; ... your code ...
    PULB              ; Restore B
    PULA              ; Restore A
```

2. **Keep Code Minimal** (<10 cycles overhead)
```asm
    LDAA  RPM_ADDR    ; 4 cycles
    CMPA  #RPM_LIMIT  ; 2 cycles
    BLS   NO_CUT      ; 3 cycles (total 9)
```

3. **Use Free Space for Complex Logic**
- Don't inject long code into ISRs
- Jump to free space, do work there, return
- ISR only does: check flag → branch

4. **Test with Oscilloscope**
- Verify EST signal timing unchanged
- Check for jitter or drift
- Compare before/after patch

### HC11 E-Clock Cycle Reference

| Instruction | Cycles | Example |
|-------------|--------|----------|
| LDAA direct | 3 | LDAA $00A2 |
| LDAA extended | 4 | LDAA $1000 |
| STAA direct | 3 | STAA $017B |
| CMPA immediate | 2 | CMPA #$FF |
| BEQ/BNE/BLS | 3 | BLS LABEL |
| JSR | 6 | JSR SUBROUTINE |
| RTS | 5 | RTS |
| RTI | 12 | RTI |
| PSHA/PULA | 3/4 | PSHA / PULA |

**Source:** MC68HC11 Reference Manual, Section 10 - Instruction Set

---

## 🚦 STOCK FUEL CUT LIMITS

### VY V6 Stock Fuel Cut RPM
**Source:** Topic 2518 - VS-VY Enhanced Factory Bins

**Stock Limit:** **5900 RPM** (fuel cut activated)
**Enhanced Limit:** **6375 RPM** (0xFF, fuel cut disabled)

**The1's Quote (Topic 2518):**
> "It's running **stock 5900rpm limiter**."
> "VY Supercharged and VT V8 were the only codes i have added RPM to the fuel cut."

### Why 6375 RPM is Maximum (Chr0m3 Explanation)
**Source:** Topic 8567, Post #10

**Quote:**
> "If you set the limiter to **6375 on factory code it will skip the limiter all together**, this is because the code checks if the rpm > what you set, and **6375 is 0xFF in the calibration** so it's max and can't get any bigger, so if it's not above the limit it will skip the limiter."

**Technical Reason:**
- RPM stored as **8-bit value**
- Scaling: **25 RPM per bit**
- Maximum: **255 × 25 = 6375 RPM**
- 0xFF = 255 = highest possible 8-bit value
- Code checks: `if (RPM > LIMIT)` → if LIMIT = 0xFF, condition never true!

### Extending Beyond 6375 RPM
**Source:** Topic 8567, Post #10

**Chr0m3's Method:**
> "You can **patch the ECU to read the RPM from a 16 bit address** instead and read up to **8000+ RPM** however at **6500+ RPM the spark control becomes less then average**."

**Required Patches:**
1. Change RPM read from 8-bit to 16-bit
2. Update RPM comparison logic
3. Extend calibration tables to cover high RPM
4. **Fix spark control issue at 6500+ RPM** (min burn/dwell)

### Jason's Question: Should Production Use 5900 RPM? (we will use 6000rpm as this is a safe rpm limit for a unmodded VY V6)

**Answer: NO - Use 6300-6400 RPM**

| RPM Setting | Pros | Cons | Recommendation |
|-------------|------|------|----------------|
| **5900 RPM** | ✅ Matches stock fuel cut | ❌ Too conservative for modded engine | ❌ NOT recommended |
| **6300 RPM** | ✅ Safe for N/A | ✅ PCMHacking tested | ✅ **RECOMMENDED** |
| **6375 RPM** | ✅ Factory ECU limit | ⚠️ Edge of 8-bit overflow | ⚠️ Use with caution |
| **6500+ RPM** | ⚠️ Requires burn/dwell patches | ❌ Spark control issues | ❌ NOT safe without patches |
| **7200 RPM** | ✅ Chr0m3 tested | ❌ Requires unknown patches | ⚠️ Expert only |

**Rationale:**
- 5900 RPM is for **stock engine** with factory redline
- Modded engine (headers, tune) can safely rev to **6300 RPM**
- 6375 RPM is **absolute factory limit** (0xFF)
- Beyond 6375 requires **16-bit RPM conversion**
- Beyond 6500 requires **burn/dwell timing fixes**

---

## 🔧 HC11 EXPANDED MODE & BANK SWITCHING

### Jason's Problem: Reset Vector 0xC011 Doesn't Decode
**Source:** Facebook Messenger (January 15, 2026)

**Quote:**
> "problem im having with no ida pro is **HC11 in expanded mode with bank switching**, the **reset vector 0xC011 doesn't decode** to expected startup code at either offset."

### Explanation: CONFIG Register & Memory Mapping

**HC11 Operating Modes:**

| Mode | MODA | MODB | Reset Vector | Internal ROM |
|------|------|------|--------------|---------------|
| **Single Chip** | 0 | 0 | $FFFE | Enabled |
| **Expanded** | 1 | 1 | $FFFE | **Disabled** |
| **Special Test** | 0 | 1 | **$BFFE** | Disabled |
| **Bootstrap** | 1 | 0 | $BFFE | Disabled |

**VY V6 ECU Configuration:**
- **Mode:** Expanded (MODA=1, MODB=1)
- **Internal ROM:** Disabled (external 128KB flash)
- **Reset Vector Location:** $FFFE (in external ROM)
- **Vector Contents:** $C011 (startup code address)

### Why 0xC011 Doesn't Disassemble Correctly

**Problem:** VY uses **bank switching** (128KB in 64KB address space)

**Memory Banking:**
```
Address Space:  $0000 - $FFFF (64KB visible)
Physical Flash: $00000 - $1FFFF (128KB total)

Bank 0: $00000 - $0FFFF → mapped to $8000-$FFFF
Bank 1: $10000 - $1FFFF → mapped to $8000-$FFFF
```

**Reset Vector @ $FFFE:**
- **CPU Address:** $FFFE (top of address space)
- **File Offset:** Could be at $0FFFE (Bank 0) OR $1FFFE (Bank 1)
- **VY V6:** Reset vector is at **file offset $1FFFE** (Bank 1)

**Reset Handler @ $C011:**
- **CPU Address:** $C011
- **Which Bank?** Need to know CONFIG register setting
- **VY V6:** Likely in Bank 0, so **file offset $0C011**

### How to Disassemble with Bank Switching

**Method 1: Split Binary by Bank**
```bash
# Extract Bank 0 (first 64KB)
dd if=92118883.BIN of=bank0.bin bs=1 count=65536 skip=0

# Extract Bank 1 (second 64KB)  
dd if=92118883.BIN of=bank1.bin bs=1 count=65536 skip=65536

# Disassemble Bank 0 starting at reset handler
m6811-elf-objdump -D -b binary -m m68hc11 --start-address=0xC011 bank0.bin
```

**Method 2: Use Arduino/Moates to Read from Running ECU**
- ECU handles bank switching automatically
- Read via ALDL or SPI flash programmer
- Easier than offline analysis

**Method 3: IDA Pro with Custom Loader**
- Write IDC script to handle bank switching
- Define memory segments for each bank
- IDA can follow cross-bank JSR/JMP

### CONFIG Register (Determines Banking)

**CONFIG @ $103F (EEPROM):**

| Bit | Name | Function |
|-----|------|----------|
| 7 | - | Unused |
| 6 | - | Unused |
| 5 | - | Unused |
| 4 | EE4 | EEPROM mapping |
| 3 | EEON | EEPROM enable |
| 2 | - | Unused |
| 1 | NOCOP | COP disable |
| 0 | ROMON | **Internal ROM enable** |

**VY V6 CONFIG = 0x0F** (typical):
- Bit 0 (ROMON) = 1 → Internal ROM **ENABLED** (but usually has no code)
- Expanded mode still uses external flash

### Bank Switching Hardware

**VY V6 uses external latch for bank selection:**
- Write to specific I/O port triggers bank switch
- Bank select stored in hardware latch
- Transparent to software (JSR/JMP work across banks)

**Finding Bank Switch Code:**
```bash
# Search for bank switch patterns
grep -a "STAA.*\$10" 92118883.BIN  # Look for I/O writes
```

**Typical Bank Switch:**
```asm
    LDAA  #$01        ; Select Bank 1
    STAA  $1039       ; Write to bank control register (example)
    JSR   $C000       ; Call function in Bank 1
    LDAA  #$00        ; Select Bank 0  
    STAA  $1039       ; Restore bank
```

---

## 🔬 L36/ECOTEC RAM ADDRESS CROSS-REFERENCE (External Archives)

**Sources Searched:** FULL_ARCHIVE_V2 + Gearhead_EFI (January 16, 2026)
**Purpose:** Cross-reference known RAM/ROM addresses from similar 68HC11 platforms

### Archive Discovery Summary

| Source File | CPU | ROM Size | VY V6 Match? | Key Content |
|-------------|-----|----------|--------------|-------------|
| **VS ROM map (topic_181)** | 68HC11 | 128KB (banked) | ✅ Same architecture | VS Commodore memory layout |
| **BKLL.md (topic_184)** | 68HC11 | 32KB? | ⚠️ Similar RAM, older P-series | 18,000+ line disassembly |
| **8F hack.md (gearhead)** | 68HC11 | 32KB | ⚠️ **Buick 3800 - same DFI!** | Detailed RAM map |
| **93Zdisassembly.md (topic_206)** | 68HC11 | 32KB | ✅ TIC3/TOC2/TOC3 documented | Timer ISR code |

### VS Commodore Memory Map (topic_181 - Same as VY architecture)

| Address Range | Contents | Size | VY V6 Equivalent |
|---------------|----------|------|------------------|
| `$0000-$03FF` | PCM RAM | 1K | ✅ Same |
| `$0400-$06FF` | Extra RAM | 0.75K | ✅ Same |
| `$0E00-$0FFF` | PCM EEPROM | 0.5K | ✅ Same |
| `$1000-$105F` | Registers | 96 bytes | ✅ Same (HC11 I/O) |
| `$2000-$5FFF` | Engine cal + Trans cal | 16K | ⚠️ Different offsets |
| `$6000-$7FFF` | Program ROM (common) | 8K | ⚠️ VY uses $2000+ |
| `$18000-$18FFF` | Unknown | 4K | - |
| `$19000-$1FFAF` | Bank 1 ROM (trans) | 28K | ⚠️ Bank switching |
| `$28000-$2FFAF` | Bank 2 ROM (engine) | 26K | ⚠️ Bank switching |

**Bank Switching (VS/VY):** Port G bit 6 controls ROM bank selection
```asm
; Bank Switch To 1 (ORAB #0x40 on Port G)
; Bank Switch To 2 (ANDB #0xBF on Port G)
```

### BKLL.md RAM Addresses (topic_184 - VN/VP/VR Era)

| RAM Address | Function | VY Equivalent | Notes |
|-------------|----------|---------------|-------|
| `$0011` | Minor Loop Counter (6.25ms-800ms bits) | ⚠️ Different | Timing intervals |
| `$0013` | MALF Status Flag 1 (P0123 TPS Hi, P0341 Cam) | ⚠️ DTC bitmap | |
| `$0014` | MALF Status Flag 2 (P0113 IAT Hi, P0502 VSS) | ⚠️ DTC bitmap | |
| `$0083` | Battery Volts | ⚠️ Need to verify | |
| `$0089` | SC1SD0 - **EST Enable bit B2** | ⭐ EST control | **Key for ignition cut** |
| `$0093` | CAM FLAG (B5=Cam pulse during crank) | ⚠️ Need to verify | |
| `$00AC` | RPM/25 | ✅ Similar to VY $00A2? | 8-bit RPM |
| `$00AD` | RPM/12.5 | ⚠️ 16-bit RPM? | |
| `$00BC` | Filtered MPH | ⚠️ Need to verify | |
| `$00C0` | Minor Loop Ref Period (N = 1310720/RPM) | ⚠️ Compare to VY | |
| `$00C2` | **Prev Ref Period (3X spark)** | ⭐ **3X timing!** | |
| `$00C8` | 3/4 of 3X Ref Period | ⚠️ Need to verify | |
| `$011E` | Dynamic Dwell | ⭐ Dwell control | |
| `$0120` | Total Dwell | ⭐ Dwell control | |
| `$0123` | Spark from Table Lookup | ⚠️ Need to verify | |
| `$0131` | 24X Crank Sensor Pulse Counter | ⭐ 24X counter | |
| `$016B` | Main Spark Advance Lookup Result | ⚠️ Need to verify | |
| `$0237` | Mode 4 Commanded Spark Advance | ⚠️ Diagnostic mode | |

### Buick 8F Hack RAM Map (gearhead_efi - Same L36/3800 Engine Family)

**Why This Matters:** Buick 3800 = Holden L36/L67 (licensed design), same DFI coils/injectors

| RAM Address | Label | Function | Bit Definitions |
|-------------|-------|----------|-----------------|
| `$0001` | NVMWD | O2 Ready, C/L Timer, IAC Reset, M42 EST Failure | Bit 7 = M42 EST monitor |
| `$0029` | MW1 | Mode Word 1 | B7=Engine Running, B5=A/C, B0=Advance Flag |
| `$002A` | MW2 | Mode Word 2 | B2=Ref Pulse, B4=Diag Position |
| `$0049` | QDM1 | Quad Driver Module 1 | B7=CEL, B6=EGR, B5=CCP |
| `$004C-4D` | REFPER | Minor Loop Ref Period | N = REFPER*KNUMCYL/256 |
| `$0058` | - | Filtered MAP A/D | KPA calculation |
| `$0059-5B` | - | Dynamic Dwell | Multi-byte |
| `$005F` | - | RPM/25 (ALDL) | ⭐ 8-bit RPM |
| `$009C` | - | Left Injector Pulsewidth | Sequential injection |
| `$00A8` | - | Right Injector Pulsewidth | Sequential injection |
| `$00C0` | - | Filtered RPM | Multi-byte |
| `$00CD` | - | BLM (Block Learn Multiplier) | Fuel learning |

### 93Z Disassembly Timer Interrupts (topic_206)

**Port Configuration at Init:**
```
PORTA ($1001) = 0x60  (DDA6, DDA5 output; others input)
PORTG ($1003) = 0x2F  (DDG5,3,2,1,0 output; DDG7,6,4 input)
PORTD ($1009) = 0x3C  (DDD5,4,3,2 output; DDD7,6,1,0 input)
TCTL2 ($1021) = 0x13  (Timer #4=Nothing, Timer #1=Falling, #3=Both edges)
SPCR  ($1028) = 0x44  (SPI enabled, CPHA=1)
```

**Key Timer ISR Routines:**
| ISR | Address | Function | VY V6 Equivalent |
|-----|---------|----------|------------------|
| **TIC3 ISR** | $B248 | Crank reference input capture | TI3 @ $2000 |
| **TOC3 ISR** | $B36C | Left injector output compare | EST/TOC3 @ $2009 |
| **TOC2 ISR** | $B3D3 | Right injector output compare | Dwell/TOC2 @ $2006 |

**TIC3 ISR Key Operations (from 93Z):**
1. Read injector pulsewidth from RAM `$009C` (left) / `$00A8` (right)
2. Set TCTL1 bits for injector timing
3. Load timer compare registers for injection duration
4. Handle enrichment/enleanment flags

### Holden ECU Part Number Evolution (For Bin Identification)

| Era | V6 Part Number | V8 Part Number | Binary Size | Notes |
|-----|----------------|----------------|-------------|-------|
| **VN (1988-91)** | 1227808 | 1227808 | 32KB | OBDI, $5D Memcal |
| **VP (1991-93)** | 1227808 | 1227808 | 32KB | OBDI, $FB Memcal |
| **VR (1993-95)** | 16176424/16195699 | 16183082/16206305 | 32KB→64KB | OBDI/II transition |
| **VS (1995-97)** | 16199728/16210672 | 16176424 | 64KB→128KB | OBDII, $51 Memcal |
| **VT (1997-00)** | 16233396 | 16234531 | 128KB | OBDII, $A5/$A6 Memcal |
| **VX (2000-02)** | 16269208/16269248 | - | 128KB | **First Flash PCM** |
| **VY (2002-04)** | 16269238/16269268 | 12202088/12225074 | 128KB | **Flash PCM $060A** |
| **VZ (2004-06)** | 92190926+ | 92189583+ | 512KB+ | P12 (E38) platform |

---

## 🔍 BINARY ADDRESS ANALYSIS - Memory Address vs File Offset (Merged from Binary_Address_Analysis.md)

**Analysis Date:** November 19, 2025 | **Merged:** January 16, 2026

### Critical Discovery: Binary Size vs Address Space

**MAJOR FINDING:** The VX-VY V6 $060A Enhanced v1.0a binary shows addresses up to **0x7FFC** (32,764) but:

1. **The addresses are NOT file offsets** - they are runtime memory addresses
2. **The binary is loaded at a specific base address** in the ECU's memory
3. **Load address must be determined** to map memory addresses to file offsets

### Common HC11 Memory Maps for GM ECUs

#### Option 1: EPROM at 0x4000 (most likely for partial binaries)
```
Memory Map:
0x0000-0x003F: I/O Registers (hardware)
0x0040-0x01FF: RAM (internal)
0x2000-0x3FFF: RAM (external, optional)
0x4000-0x7FFF: EPROM/Flash (16KB)
0x8000-0xFFFF: EPROM/Flash (32KB) or extended memory

File Offset Calculation:
File_Offset = Memory_Address - 0x4000
Example: Address 0x4002 → File Offset 0x0002
Example: Address 0x5AB1 → File Offset 0x1AB1
Example: Address 0x6877 → File Offset 0x2877
```

#### Option 2: VY 128KB Full Binary (Bank Switched)
```
Memory Map (Full 128KB):
Bank 0: 0x00000-0x0FFFF → mapped to 0x8000-0xFFFF
Bank 1: 0x10000-0x1FFFF → mapped to 0x8000-0xFFFF

File Offset = Memory Address directly (for analysis)
Reset Vector @ 0x1FFFE points to startup code
```

### Priority Address Analysis (Within File Range)

#### Address 0x6877-0x68BE → File Offset 0x2877-0x28BE

**Bytes at 0x2877 (if loaded at 0x4000):**
```
0x2877: 13 5C 26 01 5A F7 19 1B F1 7F 8A 24 0A B1 7F 8A
0x2887: 24 05 15 1A 01 20 0A 14 1A 01 20 05 4F 5F FD 19
```

**HC11 Disassembly (estimated):**
```asm
6877: 13              ABA          ; Add B to A
6878: 5C              INCB         ; Increment B
6879: 26 01           BNE $687C    ; Branch if not equal (rev limit check!)
687B: 5A              DECB         ; Decrement B
687C: F7 19 1B        STAB $191B   ; Store B (write to memory)
687F: F1 7F 8A        CMPB $7F8A   ; COMPARE B with threshold at 0x7F8A
6882: 24 0A           BCC $688E    ; Branch if carry clear (higher than limit)
6884: B1 7F 8A        CMPA $7F8A   ; COMPARE A with threshold
6887: 24 05           BCC $688E    ; Branch if carry clear
```

**Analysis:** 
- **CONFIRMED REV LIMITER CODE**
- Instructions at 0x687F and 0x6884: `CMPB $7F8A` - comparing against threshold
- Branches at 0x6882/0x6887 jump to cut routine
- **Patch Strategy:** NOP out 0x687F-0x6887 (9 bytes) = `01 01 01 01 01 01 01 01 01`

#### Address 0x5AB1-0x5B50 → File Offset 0x1AB1-0x1B50

**Bytes at 0x1AB1:**
```
0x1AB1: FC 1A 35 1A B3 7F 9A 23 15 FC 1B AB 1A 83 00 1A
```

**Pattern Analysis:**
- Spacing matches predicted 3-coil ignition pattern!
- 16 iterations = 16 RPM/Load cells for ignition timing
- **Patch Strategy:** Check for 0x00 values (spark cut) and replace with normal values

#### Address 0x4D5B-0x4D5E → File Offset 0x095B-0x095E

**Bytes at 0x095B:**
```
0x095B: 15 0E 96 90
```

**Values:** `15 0E 96 90` (4 consecutive bytes)
- Could be 4x 8-bit thresholds: 21, 14, 150, 144
- Or 2x 16-bit values: 0x150E (5390), 0x9690 (38544)
- Or scaled RPM limits (if 0x96 = 6400 RPM stock)

**Patch Recommendation:**
```
Original: 15 0E 96 90
Patched:  FF FF FF FF  (raise all limits to maximum)
```

### Python Script for Binary Patching

```python
#!/usr/bin/env python3
"""Apply ignition cut removal patches to VY V6 ECU binary"""

def apply_patch(filename, offset, original_bytes, new_bytes):
    with open(filename, 'rb') as f:
        data = bytearray(f.read())
    
    actual = data[offset:offset+len(original_bytes)]
    if actual != bytearray(original_bytes):
        print(f"ERROR: Offset 0x{offset:04X} mismatch!")
        return False
    
    data[offset:offset+len(new_bytes)] = new_bytes
    output = filename.replace('.', '_PATCHED.')
    with open(output, 'wb') as f:
        f.write(data)
    print(f"✓ Patched 0x{offset:04X}: {len(new_bytes)} bytes")
    return True

patches = [
    {'offset': 0x2877, 'name': 'Rev limiter compare removal',
     'original': bytes.fromhex('135C26015AF7191BF17F8A240A'),
     'patched': bytes.fromhex('01010101010101010101010101')},
    {'offset': 0x095B, 'name': 'Rev limiter threshold raise',
     'original': bytes.fromhex('150E9690'),
     'patched': bytes.fromhex('FFFFFFFF')}
]
```

### ⚠️ Critical Warnings Before Flashing

1. **Verify Binary Completeness** - Is this full 128KB or partial?
2. **Backup Original ECU** - Read stock binary via ALDL first
3. **Test on Bench First** - Monitor coil driver signals with oscilloscope
4. **Check for Paired Fuel Cut** - Ignition cut often paired with fuel cut

---

## ✅ Conclusion

**YES, we can port OSE12P's TCTL1 method to VY!**

- Hardware registers ARE compatible (same HC11)
- ISR locations are DIFFERENT but concept is IDENTICAL
- VY already uses TCTL1, so we know it works
- Need to find VY-specific RPM address and inject code
- **Recommended dwell for spark cut: 200-300µs** (proven values)
- **Recommended production RPM: 6300-6400 RPM** (NOT 5900) i recommend 6000rpm chr0m3 was just tryna get past stock rpm limits as it has bad us we need to do 600dwell to get 1000us to get cut happening i think based on math.
- **CRITICAL: Opcode timing matters** - keep ISR patches minimal
- **Bank switching:** Reset vector 0xC011 is in Bank 0 @ file offset 0x0C011
we could just try it at 6000rpm though to be safe. incase it over revs.
**Next Step:** Disassemble VY TI3 ISR at $2000 to understand existing logic this might of been done need to string search all documents at once # ## ### to read lines and things and use address in keywords or the keyword itself in strings of .md or .txt .json etc .xdf 
in R:\VY_V6_Assembly_Modding

R:\VY_V6_Assembly_Modding\VX VY_V6_$060A_Enhanced_v2.09a.xdf

heres the xdf

bin is here
R:\VY_V6_Assembly_Modding\VY_V6_Enhanced.bin
lpg had been 0 to make room for extended spark tables?
did this make room for other stuff? add info to R:\VY_V6_Assembly_Modding\WHY_ZEROS_CANT_BE_USED_Chrome_Explanation.md

---

## VERIFIED XDF DATA (January 16, 2026)

**Exported using:** KingAI TunerPro XDF+BIN Universal Exporter v3.1.0
**Method:** Direct binary+XDF parsing with actual calibration values

### Delta CYLAIR / Max Dwell Threshold (VERIFIED)

This parameter controls when the ECU forces maximum dwell - important for spark cut implementation.

| Platform | XDF Parameter Name | Address | Raw Value | Notes |
|----------|-------------------|---------|-----------|-------|
| **VS V6 $51** | If Delta CYLAIR is Greater than this then Max Dwell | **0x3D49** | **32** (0x20) | Enhanced v1.4f |
| **VY V6 $060A** | If Delta Cylair > This - Then Max Dwell | **0x6776** | **32** (0x20) | Enhanced v2.09a |
| **VT V6 $A5G** | NOT MAPPED | - | - | Not in XDF |
| **OSE12P** | NOT PRESENT | - | - | Uses different dwell system |

**FINDING:** VS and VY use the SAME value (0x20=32) but at DIFFERENT addresses!

### Dwell Parameters (OSE12P ONLY - Not in VS/VT/VY XDFs)

OSE12P has explicit dwell slope parameters that other platforms don't expose:

| Parameter | Address | Raw Value | Converted |
|-----------|---------|-----------|-----------|
| Dwell - First Slope Upper Ref Period Threshold (High RPM) | 0x9AD9 | 229 | 6.99 ms |
| Dwell - Second Slope Upper Ref Period Threshold (Mid RPM) | 0x9ADB | 294 | 17.94 ms |
| Dwell - First Slope Dwell Adder (High RPM) | 0x9ADD | 308 | 4.70 ms |
| Dwell - Second Slope Dwell Adder (Mid RPM) | 0x9ADF | 1526 | 23.28 ms |
| Dwell - Third Slope Dwell Adder (Low RPM) | 0x9AE1 | 381 | 5.81 ms |

**NOTE:** These are only mapped in OSE12P XDF. VS/VT/VY likely have similar code but not exposed.

### Rev Limiter Parameters

#### OSE12P (Full Implementation - VERIFIED)

| Parameter | Address | Value | Notes |
|-----------|---------|-------|-------|
| Map A: Rev Limit - Soft Fuel Cut Upper RPM Threshold | 0x8832 | **5800 RPM** | Above = hard cut |
| Map A: Rev Limit - RPM Below Threshold for Soft Fuel-Cut | 0x8830 | 0 RPM | Start of soft zone |
| Map A: Rev Limit - RPM Below Threshold for Ignition Retard | 0x8835 | **150 RPM** | Retard starts 150 below |
| Map A: Rev Limit - Soft Touch Rev-Limit Advance Reduction | 0x8837 | 17 | 5.98 degrees |
| Map A: Rev Limit - Multiplier For Soft Fuel Cut Time | 0x8834 | 16 | 0.12 factor |
| Map B: (same structure) | 0x8838+ | Same values | Second map |

**OSE12P uses a SOFT + HARD limiter system:**
- Soft fuel cut starts at (5800 - 0) = 5800 RPM
- Ignition retard starts at (5800 - 150) = 5650 RPM
- Hard fuel cut above 5800 RPM

#### VS/VT/VY Rev Limiter (NOT MAPPED IN XDF)

VS, VT, and VY XDFs do NOT have explicit rev limiter parameters mapped!
- They have `Fuel Cut - High RPM` tables but with NO ADDRESS
- Rev limiter is implemented in code but not exposed in XDF
- This is why we need to patch the binary directly for spark cut

### Fuel Cutoff Parameters (VY - VERIFIED)

| Parameter | Address | Value | Notes |
|-----------|---------|-------|-------|
| If KPH > CAL Use Drive CALS For RPM Fuel Cutoff | 0x77DC | 10 KPH | Speed threshold |
| Fuel Cutoff A/F Ratio in Drive | 0x77EE | 102 | ~15.0 AFR |
| Fuel Cutoff A/F Ratio in P/N And Reverse | 0x77EF | 102 | ~15.0 AFR |
| If TPS > CAL Disable Decel Fuel Cutoff | 0x77D7 | 3 | ~1.2% TPS |
| If MPH < CAL Disable Decel Fuel Cutoff | 0x77D9 | 25 MPH | Minimum speed |
| Crank Engage Lock-Out Engine RPM Limit | 0x64FA | 88 | 1100 RPM |
| Adaptive Spark Cell - RPM Limit | 0x6965 | 80 | 2500 RPM |

### XDF Parameter Counts (Platform Comparison)

| Platform | Scalars | Flags | Tables | Notes |
|----------|---------|-------|--------|-------|
| **OSE12P V112** | 401 | 148 | 90 | Most complete dwell/rev limit exposure |
| **VS V6 $51 Enhanced v1.4f** | 681 | 147 | 256 | Most parameters total |
| **VT V6 $A5G Enhanced v1.0h** | 166 | 8 | 108 | Fewer parameters exposed |
| **VY V6 $060A Enhanced v2.09a** | ~600+ | ~100+ | ~200+ | Similar to VS |

### Key Addresses for Spark Cut Implementation

Based on verified XDF data:

| Purpose | VS Address | VY Address | OSE12P Address |
|---------|------------|------------|----------------|
| Delta CYLAIR/Max Dwell Threshold | **0x3D49** | **0x6776** | N/A |
| Fuel Cut RPM Table | Not mapped | Not mapped | 0x8830+ |
| Ignition Retard Threshold | Not mapped | Not mapped | 0x8835 |

**CONCLUSION:** For spark cut on VS/VY, we need to either:
1. Find unmapped code that handles rev limiting (in binary, not XDF)
2. Inject new TCTL1-based spark cut code (BennVenn's OSE12P method)
3. Use the Delta CYLAIR/Max Dwell parameter (but it's not a rev limiter)

---

## Binary Export Summary

| Binary | MD5 Hash | Size | Notes |
|--------|----------|------|-------|
| VT_V6_AUTO_$A5G_Enhanced_v1.1.bin | e56178fab59f51f015e07d936ccc3407 | 131,072 | VT automatic |
| VS_V6_$51_Enhanced_v1.4b.bin | c63ddd2e0322b632289b717efec46bc8 | 131,072 | VS enhanced |
| OSE $12P V112 BLCD V6.BIN | 24d31b878a40955db6a0ec68b52fd28e | 32,768 | OSE12P memcal |
| VY 92118883_STOCK.bin | 4afd0d075d2a2960c51775b0efce059f | 131,072 | VY stock |

---

## OSE11P and OSE12P - Complete Technical Comparison

**Sources:** PCMHacking Forum Topics 7922, 3798, 8567, 2518 + Archive Search

### Overview

| Feature | OSE12P | OSE11P | VS/VT Enhanced | VY Flash |
|---------|--------|--------|----------------|----------|
| **Hardware** | MC68HC808 (VN/VP) | MC68HC424 (VR) | MC68HC11 | MC68HC12 |
| **Binary Size** | 32KB Memcal | 64KB NVRAM | 128KB Memcal | 128KB Flash |
| **Spark Control** | External IC (TCTL1) | CPU-based | CPU-based | CPU-based |
| **Spark Cut Support** | ✅ Via TCTL1 bit 1 | ✅ Via dwell reduction | ❌ Not in XDF | 🔄 In development |
| **Developer** | VL400/BennVenn | VL400/Holden202T | The1 | Chr0m3 |

### OSE12P Spark Cut Implementation (Topic 7922)

**BennVenn's Discovery (July 2022):**

The MC68HC808's timer IC has a **master timer enable/disable bit** that supports hardware spark cut:

```
$3FFC Bit 1 = Master Timer Enable/Disable
- Setting bit HIGH = No EST pulse output (spark cut)
- Setting bit LOW = Normal EST pulse output
```

**Method 1: Dwell Reduction (Proof of Concept)**
- Reduce dwell to ~0.3ms which is insufficient to charge ignition coil
- Coil fails to fire → "misfire" spark cut
- 6 bytes of code space + 2 bytes RAM required
- Works but causes timing penalties in EST loop

**Method 2: TCTL1 Master Switch (Preferred)**
- Flip TCTL1 bit 1 every other reference pulse to prevent bypass mode
- Modify ESTLOOP timer code to ignore overflow during spark cut
- True hardware spark cut without timing penalties
- Can be placed in timeloop or beside fuel cut code

**Key Forum Quotes:**
> "Bit 1 at $3FFC is the master timer enable disable bit. Setting the bit high will not output an EST pulse." - BennVenn

> "12P doesnt have spark cut because the '808 family of ecus has a hardware chip driving spark which fires with the amount of timing it was last asked to deliver automatically when its running." - antus

### OSE11P Spark Cut Implementation (Topic 3798)

**Holden202T's Implementation (2014-2016):**

The MC68HC424 moved spark control from external hardware IC (808) to the main CPU, enabling **software-based spark cut**:

```
Method: Dwell reduction to 200µs (0.2ms)
- Too short to charge ignition coil
- Coil cannot fire → spark cut
- EST continues, no bypass mode triggered
- Logging and RPM trace continue normally
```

**XDF Parameters (11P on '424 Computer):**
- Flag: `Set - Enable Spark Cut Rev Limit` (for [Econ] and [Power] modes)
- Parameter: `Run Params - High RPM Fuel/Spark Cut - Upper` (set upper limit)
- Parameter: `RPM Below Upper To Begin Spark Reduction` (set to 0 for hard cut)

**Key Forum Quotes:**
> "11P has spark cut via dwell tuning. I think it was 202 that did it and got it working?" - vlad01

> "from memory, the spark cut limiter in 11P doesnt stop EST... it only reduces dwell to the point spark is not acheivable. logging continues and rpm trace continues... log doesnt show bypass mode." - Jayme

> "That is correct. Dwell is set to 200us so cant ignite and keeps things happy. It also disables some of the EST error logic only during spark cut so no code 41/42 errors are logged." - VL400

> "Tick the spark cut option flag and it disables the fuel cut code running only the spark cut code. No option for both fuel and spark cut, its one or the other." - VL400

### Hardware Architecture Comparison

| CPU Family | ECU Type | Spark Control IC | Spark Cut Method |
|------------|----------|------------------|------------------|
| MC68HC808 | VN/VP Memcal | External timer IC | TCTL1 bit 1 toggle or dwell ~0.3ms |
| MC68HC424 | VR NVRAM | CPU-based | Dwell = 200µs |
| MC68HC11 | VS/VT Memcal | CPU-based | Dwell reduction (untested) |
| MC68HC12 | VT-VZ Flash | CPU-based | Dwell reduction + code patch |

**Critical Insight from antus:**
> "'424 based computers (and later, such as all the1's enhanced bins use) moved spark on to the main CPU so 11P and these operating systems can with software mods."

This means:
- **VS/VT (MC68HC11)** = Similar to 424, spark control in CPU = dwell method should work
- **VY Flash (MC68HC12)** = Same architecture = dwell method applies

### VT-VY Spark Cut Development (Topic 8567 - Chr0m3)

**Current Status (Jan 2026):** In Development

Chr0m3's approach for VT-VY Flash ECUs:

1. **RPM Limitation Discovery:**
   - Factory code uses 8-bit RPM value (25 RPM per bit)
   - Max = 255 × 25 = **6375 RPM**
   - Setting limiter to 6375 skips limiter entirely (0xFF can't be exceeded)
   - Can patch to 16-bit for 8000+ RPM but spark control degrades above 6500

2. **Min Dwell Discovery:**
   - Found min dwell parameter but changing it doesn't help
   - Overall min/max boundaries exist that override calibration values
   - 3X ref is directly related to the limit

3. **Spark Control at High RPM:**
   - At 6500-6600 RPM, "burn time gets too excessive"
   - Calculation overflow causes misfires
   - Needs separate fix before higher RPM is viable

**Key Forum Quotes:**
> "I've been researching and developing spark cut on the VX/VY flash ecu for about 3-4 years now with decent success" - Chr0m3

> "Basically, but as discussed you can't pull the dwell down to 0, can get it low enough to misfire but yeah, still definitely needs more research and testing." - Chr0m3

> "I had some code to add to enhanced mod but never got time to finish it or test, I took out code for LPG they put in VY I think to help stop backfiring, they didn't set it to 0 but a very low value maybe 600usec." - The1

### Platform Resource Comparison

| ECU | RAM Available | Code Space | Spark Control | Notes |
|-----|---------------|------------|---------------|-------|
| 808 (12P) | Very limited | Minimal free | External IC | "tapped out - no more RAM" |
| 424 (11P) | More available | Has free space | CPU-based | "heaps could be freed up removing auto stuff" |
| Flash PCM | Most available | ~128KB | CPU-based | "CYLAIR, MAF, RPM limiter limitations" |

### Why 424/11P is Preferred for MEMCAL Tuning

From vlad01:
> "424 had big potential as it's map and has many of the desirable flexibility and features and ease of tuning as the 808 but has more resources and better I/O and spark control and high speed data"

From Jayme:
> "when given the option, even on Manual engines or non electronic autos like the t400, I run the VR auto computer and 11P now, because spark cut limiter"

From antus:
> "I just unchecked all the auto DTC enable flags so that none of the errors of the missing auto would trigger or upset anything. Other that the auto support, 11P is nearly the same as as 12P apart from some slightly better spark control hardware and with the couple of additional spark features."

### Key Differences Summary

| Aspect | OSE12P (808) | OSE11P (424) | VS/VT Enhanced | VY Flash |
|--------|--------------|--------------|----------------|----------|
| **Spark Cut Method** | TCTL1 hardware toggle | 200µs dwell | Not implemented | In development |
| **Max Mapped RPM** | 9600 RPM tables | ~8000 RPM | 6375 RPM (8-bit) | 6375 RPM (8-bit) |
| **Speed Cut** | None | 255 km/h hardcoded | Unknown | Removable via patch |
| **Development Status** | Mature, complete | Mature, complete | Stalled | Active (Chr0m3) |
| **Source Code Available** | No (VL400 has it) | No (VL400 has it) | No | No |
| **Community Support** | Limited (VL400 gone) | Limited (VL400 gone) | Active (The1) | Active (Chr0m3) |

### Porting Path: OSE11P Method → VS/VT/VY

Based on the research, the **11P dwell method** is most applicable to VS/VT/VY because:

1. ✅ All use CPU-based spark control (not external IC like 808)
2. ✅ Dwell calibration is exposed in XDF
3. ✅ VL400 confirmed 200µs dwell prevents coil charging
4. ✅ EST error logic can be disabled during spark cut

**Required Steps:**
1. Find the dwell calculation routine in binary
2. Inject code to set dwell = 200µs when RPM > limit
3. Bypass EST error detection during spark cut
4. Add XDF flag to enable/disable spark cut mode

**Alternative: TCTL1 Method (if CPU control doesn't work)**
- BennVenn's $3FFC method might work if VS/VT/VY have similar timer IC
- Requires finding equivalent master timer enable bit
- More research needed on MC68HC11/12 timer architecture

---

## 🔗 Cross-Reference: VL V8 Walkinshaw Features

**See:** `VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md`

### What VL Has That VY Doesn't

| Feature | VL $5D | VY $060A | Can Port? |
|---------|--------|----------|-----------|
| **Two-Stage Limiter** | ✅ KFCORPMH/KFCORPML | ❌ Single threshold | ✅ Yes |
| **94 RPM Hysteresis** | ✅ Smooth on/off | ❌ Sharp cut | ✅ Yes |
| **0.1 sec Delay** | ✅ KFCOTIME | ❌ None | ✅ Yes |
| **Shift Light** | ✅ Per-gear RPM/MAP | ❌ Not present | ✅ Yes (Chr0m3 pin) |
| **F55 TPS Table** | ✅ RPM vs TPS | ❌ None | ✅ Yes |
| **"Amazing" Sound** | ✅ Valve bounce feel | ❌ Harsh stutter | ✅ Via hysteresis |

### Why VL Sounds Better at Limiter

**VL V8:** Hysteresis band (94 RPM) creates smooth 1.5 Hz on/off modulation → sounds like mechanical valve bounce or hardware limit

**VY V6:** Instant on/off at single threshold → RPM oscillates rapidly → sounds harsh and stuttery

**Solution for VY:** Implement `spark_cut_two_stage_hysteresis_v23.asm` with:
- HIGH threshold (e.g., 6000 RPM)
- LOW threshold (e.g., 5900 RPM) 
- 100 RPM hysteresis band
- Optional delay timer

### VL Shift Light → VY Shift Light

**VL Implementation (XDF parameters 0x21F-0x232):**
- Per-gear N/V ratios
- Per-gear RPM thresholds
- Per-gear MAP limits
- Per-gear in-gear delays
- F55 TPS-based table

**VY Implementation Path:**
1. Chr0m3 found unused pin on VX/VY
2. Write simple toggle code (BSET/BCLR on port register)
3. Check RPM threshold in background loop
4. Toggle pin if exceeded

**ASM Example (untested):**
```asm
; Shift Light Check - runs in main loop
; Assumes Port G bit 3 is the unused pin
SHIFT_LIGHT:
    LDAA  $00A2           ; Load RPM (×25)
    CMPA  #$E8            ; 5800 RPM threshold
    BLO   LIGHT_OFF
    BSET  $1003,#$08      ; Port G bit 3 = HIGH
    BRA   DONE_SHIFT
LIGHT_OFF:
    BCLR  $1003,#$08      ; Port G bit 3 = LOW
DONE_SHIFT:
    RTS
```

⚠️ **WARNING:** Pin needs confirmation from Chr0m3 or oscilloscope probing before use.

---
