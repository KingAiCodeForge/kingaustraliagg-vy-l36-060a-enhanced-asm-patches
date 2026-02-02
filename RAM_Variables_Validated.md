# VY V6 $060A RAM Variables - Validated Reference

> **📢 PUBLIC DOCUMENT** - This file is published on GitHub for community reference.
made by me and a computer robot.
**Document Created:** December 6, 2025  
**Last Updated:** January 26, 2026  
**Source:** map_ram_variables.py analysis, XDF validation, PCMhacking research, binary search  
**Status:** Validated for Enhanced v1.0a (92118883)  
**Processor:** MC68HC11 (8-bit, $060A mask)

---

## 🔴 MASTER TODO - Analysis Gaps (Updated 2026-01-26)

### ✅ COMPLETED
- [x] XDF ROM flag correlation ($4D5B, $5795, $5796 - TCC/Option flags)
- [x] HC11 interrupt vector analysis (RESET→$202A, IRQ→$30BA, etc.)
- [x] Pseudo-vector JMP tracing (8 wrappers at $2000-$202A)
- [x] RAM mode flag mapping (212 bytes, 593 patterns, FREE bits identified)
- [x] 8-bit RPM at $00A2 (82 reads, 2 writes, ×25 scale)
- [x] VE_TABLE base at $4600 (XDF confirmed)
- [x] SPARK_TABLE area at $5200+ (XDF confirmed)
- [x] TPS_RAM at $00F3 (XDF confirmed)

### 🔴 CRITICAL - Still Unknown
| Item | Status | Action Required |
|------|--------|-----------------|
| 16-bit RPM source | ✅ **VERIFIED: $194C** | 24X crank period at STD $3618 in TIC3 ISR |
| 24X Crank Period | ✅ **VERIFIED: $194C** | STD @ $3618 in TIC3 ISR (2026-01-31) |
| DWELL_INTERMEDIATE | ✅ **VERIFIED: $017B** | STD @ 0x101E1 - NOT crank period! (2026-01-31) |
| DWELL_RAM | ✅ **VERIFIED: $0199** | Already in README, confirmed @ 0x1008B, 0x101CE, 0x101DC |
| ECT_RAM (coolant temp) | NOT on PE2/AN2! | Trace SPI ADC |
| MAP_RAM | May be $007E but unverified | Trace SPI ADC |
| INJECTOR_PW_RAM | 🔬 **FOUND: $0153** | STD @ 0x169AD, 0x16A77 - UNTESTED, theory only |
| INJ_PW_BANK1 | ✅ **VERIFIED: $013F** | STD @ 0x17243, LDX @ 0x181AF - Bank 1 pulse width |
| INJ_PW_BANK2 | ✅ **VERIFIED: $0141** | STD @ 0x1727C, LDX @ 0x1825D - Bank 2 pulse width |
| INJ_TIMING_B1 | ✅ **VERIFIED: $0143** | 16-bit injection timing bank 1 |
| INJ_TIMING_B2 | ✅ **VERIFIED: $0145** | 16-bit injection timing bank 2 |
| FUEL_RAM_2 | 🔬 **FOUND: $016B** | STD @ 0x11C29, 0x181DA, 0x1823C, 0x18306 - UNTESTED |
| Mystery RAM $149E | v1.1a only | Disassemble $1FD84 |
| Mystery RAM $16FA | v1.1a only | Disassemble $1FD84 |
| 47 undocumented tables | Purpose unknown | Cross-ref with OSE 11P/12P |

### ✅ HC11 INTERRUPT VECTORS & PSEUDO-VECTORS (January 31, 2026)

**HC11 Hardware Vector Table** (file offset 0x1FFF0-0x1FFFF):
| Vector | File Offset | CPU Address | Target |
|--------|-------------|-------------|---------|
| IRQ | 0x1FFF2 | $FFF2 | $C015 (DTC recovery) |
| XIRQ | 0x1FFF4 | $FFF4 | $2021 → JMP $2BA6 |
| SWI | 0x1FFF6 | $FFF6 | $201E → JMP $2BA0 |
| Illegal Opcode | 0x1FFF8 | $FFF8 | $201B → JMP $2BAC (TIC3!) |
| COP Failure | 0x1FFFA | $FFFA | $2018 → JMP $30BA |
| COP Clock Monitor | 0x1FFFC | $FFFC | *Not analyzed* |
| **RESET** | 0x1FFFE | $FFFE | **$2000** |

**Pseudo-Vector Jump Table** (file offset 0x2000-0x2030, CPU $A000-$A030):
| Offset | File Addr | CPU Addr | Instruction | Target | Purpose |
|--------|-----------|----------|-------------|--------|---------|
| +0 | 0x2000 | $A000 | JMP $2BAF | $2BAF | RESET entry |
| +3 | 0x2003 | $A003 | JMP $29D3 | $29D3 | Unknown ISR 1 |
| +6 | 0x2006 | $A006 | JMP $35DE | $35DE | Unknown ISR 2 |
| +9 | 0x2009 | $A009 | JMP $35BD | $35BD | Unknown ISR 3 |
| +12 | 0x200C | $A00C | JMP $37A6 | $37A6 | Unknown ISR 4 |
| +15 | 0x200F | $A00F | **JMP $35FF** | **$35FF** | **TIC3 ISR (crank/spark!)** |
| +18 | 0x2012 | $A012 | JMP $358A | $358A | Unknown ISR 6 |
| +21 | 0x2015 | $A015 | JMP $301F | $301F | Unknown ISR 7 |
| +24 | 0x2018 | $A018 | JMP $30BA | $30BA | COP handler |
| +27 | 0x201B | $A01B | JMP $2BAC | $2BAC | Illegal opcode |
| +30 | 0x201E | $A01E | JMP $2BA0 | $2BA0 | SWI handler |
| +33 | 0x2021 | $A021 | JMP $2BA6 | $2BA6 | XIRQ handler |
| +36 | 0x2024 | $A024 | JMP $2024 | $2024 | Infinite loop (unused) |
| +39 | 0x2027 | $A027 | JMP $2027 | $2027 | Infinite loop (unused) |
| +42 | 0x202A | $A02A | JMP $202A | $202A | Infinite loop (unused) |
| +45 | 0x202D | $A02D | JMP $2BB0 | $2BB0 | Unknown ISR 15 |

**CRITICAL FINDING:** TIC3 ISR is at **$35FF** (file offset 0x155FF), NOT $2BAC!  
The vector at $200F is the proper entry point for Input Capture 3 (crank/spark timing).

**Action Required:** Disassemble $35FF to find 16-bit RPM and PERIOD_3X storage.

### TIC3 ISR Analysis (File 0x135FF, CPU $35FF)

**Critical RAM Addresses Found:**
- `$194C` - 16-bit crank period storage (STD at $3618)
- `$194E` - Cleared before period store (CLR at $3611)  
- `$194F` - Cleared before period store (CLR at $360E)
- `$194A` - Flag checked before period calculation (LDAA at $3609)
- `$1948` - Result storage (STAA at $3633)
- `$1492` - 16-bit result storage (STD at $363B)

**Disassembly Snippet:**
```assembly
$35FF:  MUL              ; Multiply A×B
$3600:  SUBA #$1B        ; Subtract $1B
$3602:  LDAA $1ADE       ; Load from mode flags
$3605:  BITA #$08        ; Test bit 3
$3607:  BEQ $361D        ; Branch if clear
$3609:  LDAA $194A       ; Load period flag
$360C:  BNE $3633        ; Branch if non-zero
$360E:  CLR $194F        ; Clear high byte
$3611:  CLR $194E        ; Clear low byte  
$3614:  BCLR $50,#$01    ; Clear bit 0 of $50
$3618:  STD $194C        ; ** STORE CRANK PERIOD **
$361B:  BRA $3633        ; Branch ahead
```

**Candidate Addresses:**
- **PERIOD_3X_16BIT:** `$194C` (16-bit crank period)
- **RPM_CALC_TEMP:** `$1492` (16-bit intermediate)
- **PERIOD_FLAGS:** `$194A` (calculation control flags)

### 🟡 MEDIUM - Feature Gaps
- [ ] Lumpy idle implementation (Rhysk94 method = timing retard at idle cells, causes flames)
- [ ] Spark cut v1.1a decompilation at $1FD84
- [ ] Shift scheduler decision tree
- [ ] Alpha-N/MAFless enable flag
- [ ] EGR control addresses

**NOTE (Jan 28 2026):** "Ghost cam" on VY is Rhysk94's LUMPY IDLE (timing retard, causes flames).
Our SPARK CUT is different (dwell starvation, no flames). Don't confuse them!

### 🟢 LOW - Nice To Have
- [ ] XDF axis linking (EMBEDDEDDATA instead of LABEL)
- [ ] Alpina zero tables equivalent
- [ ] E85/ethanol compensation tables

---

## 🔍 Axis Breakpoints Discovery (NOT IN XDF)

### Q: Can axis breakpoints be edited in the binary?
**A: YES** - We found at least one axis array that IS in the binary but NOT exposed in the XDF.

### RPM Axis Found at 0x75FA

| Address | Index | Raw Value | RPM (×25) |
|---------|-------|-----------|-----------|
| 0x75FA | 0 | 16 | 400 |
| 0x75FB | 1 | 24 | 600 |
| 0x75FC | 2 | 32 | 800 |
| 0x75FD | 3 | 40 | 1000 |
| 0x75FE | 4 | 48 | 1200 |
| 0x75FF | 5 | 56 | 1400 |
| 0x7600 | 6 | 64 | 1600 |
| 0x7601 | 7 | 72 | 1800 |
| 0x7602 | 8 | 80 | 2000 |
| 0x7603 | 9 | 88 | 2200 |
| 0x7604 | 10 | 96 | 2400 |

**In XDF v2.09a?** ❌ NO - Address 0x75FA not defined  
**Encoding:** `RPM = byte × 25`  
**Size:** 11 cells (0x75FA to 0x7604)

### Q: Why does the XDF use LABEL tags instead of binary addresses?
**A:** The XDF author either:
1. Didn't find the axis arrays in binary, OR
2. Assumed axes were hardcoded in code (not calibration data)

**Current XDF approach:**
```xml
<XDFAXIS id="x">
  <LABEL value="400"/><LABEL value="600"/>...  <!-- Hardcoded text -->
</XDFAXIS>
```

**Correct approach (if axis is in binary):**
```xml
<XDFAXIS id="x">
  <embeddeddata mmedaddress="0x75FA" />  <!-- Points to binary data -->
  <math equation="X*25"/>
</XDFAXIS>
```

### TODO: Find More Axis Arrays
- [ ] Search for load axis (mg/stroke patterns)
- [ ] Search for temperature axis patterns
- [ ] Match discovered axes to tables that use them
- [ ] Update XDF with EMBEDDEDDATA instead of LABEL
does our current xdf give us any data on this?
---

## Critical RAM Addresses (Confirmed)

### ⚠️ Version Note

This document covers **Enhanced v1.0a** (v2.09a XDF package). Enhanced v1.1a (v2.04c package) adds spark cut functionality with additional RAM variables that are currently under investigation:

| Address | Name | v1.0a | v1.1a | Notes |
|---------|------|-------|-------|-------|
| `$149E` | UNKNOWN | N/A | Used | The1's spark cut code references this |
| `$16FA` | UNKNOWN | N/A | Used | The1's spark cut code references this |
| `$9D1A` | RPM_16BIT? | N/A | Used | 16-bit RPM source for v2.04c |
| `$78B2` | SPARK_RPM_CUT | N/A | XDF | XDF-tunable spark cut threshold |

*Full v1.1a analysis pending - need to disassemble and verify opcodes before publishing.*

---

### Engine Speed / RPM

| Address | Name | Size | Access | Description |
|---------|------|------|--------|-------------|
| **0x00A2** | ENGINE_RPM | 1 byte | 82R/2W | Current engine RPM (8-bit, scaled ×25) |

**Notes:**
- Direct page addressing for fast access (2-cycle reads)
- Maximum value: 0xFF = 6,375 RPM
- Used in spark timing, fuel calculations, rev limiter checks
- Access ratio 97.6% read-only (near-constant updates from 3X sensor)

**Example Assembly:**
```assembly
LDAA $A2            ; Load current RPM (direct page)
CMPA #$EC           ; Compare with 5,900 RPM (236 × 25)
BHI LIMIT_ACTIVE    ; Branch if RPM > 5,900
```

### Sensor Inputs (From ASM Files - Verification Required)

| Address | Name | Size | XDF Status | Source | Confidence |
|---------|------|------|------------|--------|------------|
| **$00C6** | TPS_RAM | 1 byte | ❓ TBD | mafless_alpha_n_v1-v3.asm | 🟡 MEDIUM |
| **$00B4** | ECT_SENSOR | 1 byte | ❓ TBD | cold_maps_tuning_alpina_method_v1.asm | 🟡 MEDIUM |
| **$00B2** | IAT_SENSOR | 1 byte | ❓ TBD | speed_density_ve_table.asm | 🔴 LOW |
| **$00B0** | MAP_SENSOR | 1 byte | ❌ Not stock | speed_density_ve_table.asm | ⚠️ **DOES NOT EXIST** |

**⚠️ CRITICAL:** $00B0 MAP_SENSOR does NOT exist in stock VY V6 (MAF-based). Would require hardware mod + custom code.

### Engine Mode Flags ($0046) - VERIFIED January 22, 2026

| Address | Name | Size | Access | Description |
|---------|------|------|--------|-------------|
| **0x0046** | ENGINE_MODE_FLAGS | 1 byte | 20 refs | Mode/state flags byte |

**Bit Usage Analysis (verified by binary opcode search):**

| Bit | Mask | Status | Refs | Opcode Types Found |
|-----|------|--------|------|-------------------|
| 0 | `$01` | ❌ USED | 5 | BSET, BCLR, BRCLR |
| 1 | `$02` | ❌ USED | 6 | BSET, BCLR, BRCLR |
| 2 | `$04` | ❌ USED | 4 | BRSET, BSET, BCLR |
| 3 | `$08` | ✅ **FREE** | 0 | None |
| 4 | `$10` | ❌ USED | 4 | BRSET, BSET, BCLR |
| 5 | `$20` | ❌ USED | 1 | BRSET (mask 0x25) |
| 6 | `$40` | ✅ **FREE** | 0 | None |
| 7 | `$80` | ✅ **FREE** | 0 | **← BEST FOR LIMITER FLAG** |

**Recommended for Spark Cut Limiter: Bit 7 ($80)**

**Example Assembly (using bit 7 for limiter flag):**
```assembly
BRSET $46,#$80,LIMIT_ON  ; If bit 7 set, limiter is active
BSET  $46,#$80           ; Set bit 7 (activate limiter)
BCLR  $46,#$80           ; Clear bit 7 (deactivate limiter)
```

### Other Key Mode Flag Bytes (Discovered January 26, 2026)

Binary analysis using BRSET/BRCLR/BSET/BCLR opcode scanning revealed the most heavily-tested flag bytes:

| Byte | Most Used Bit | Tests | Inferred Function | FREE Bits |
|------|---------------|-------|-------------------|-----------|
| **$29** | bit 7 ($80) | **65** | Diagnostic Mode | $02, $04, $08, $10 |
| **$05** | bit 3 ($08) | **59** | Fuel/Shift Cut? | $20 only |
| **$3D** | bit 7 ($80) | 50 | Unknown | TBD |
| **$24** | bit 0 ($01) | **49** | MAF Enable | NONE (all used) |
| **$41** | bit 0 ($01) | 32 | Unknown | $02, $04, $10, $20, $40, $80 |
| **$46** | bits 0-4 | 20 total | Engine Mode | **$08, $20, $40, $80** |

**Best bytes for custom patches:**
- **$46** - 4 FREE bits, already used for engine modes
- **$41** - 6 FREE bits (only bits 0 and 3 are used)
- **$29** - 4 FREE bits (bit 7 is heavily used for diagnostics)

**Script:** `tools/mode_byte_flag_mapper.py` (needs path fix from R: to A:)

---

### ⚠️ CRITICAL CORRECTION (2026-01-31/02-02)

**TIC3 ISR disassembly PROVED that `$017B` is NOT crank period storage!**

### 24X Crank Period Storage (CORRECTED)

| Address | Name | Size | Access | Description |
|---------|------|------|--------|-------------|
| **0x194C** | 24X_CRANK_PERIOD | 2 bytes | TIC3 ISR | **ACTUAL** 24X crank period (STD @ $3618) |
| **0x017B** | DWELL_INTERMEDIATE | 2 bytes | Dwell calc | Intermediate dwell calculation (NOT crank!) |

**Notes:**
- **$194C** is the actual crank period storage (verified in TIC3 ISR at file 0x13618)
- **$017B** is intermediate dwell calculation, NOT crank period
- Both hooks are VALID for spark cut - choose based on preference:
  - $017B hook (0x101E1) - in main code, easier to debug
  - $194C hook (0x13618) - in TIC3 ISR, affects timing directly

**Spark Cut Injection (Option 1 - Dwell Hook at $017B):**
```assembly
; Hook at 0x101E1 - manipulate dwell intermediate
; When RPM > threshold, inject fake dwell value
LDD #$0000          ; Zero dwell = no spark
STD $017B           ; Store fake intermediate dwell
                    ; Result: Spark timing calculation uses wrong value
```

**Spark Cut Injection (Option 2 - Crank Period Hook at $194C):**
```assembly
; Hook at 0x13618 in TIC3 ISR - manipulate crank period
; When RPM > threshold, inject fake crank period
LDD #$3E80          ; 16,000 = fake long period
STD $194C           ; Store to ACTUAL crank period variable
                    ; Result: Dwell calculation produces wrong timing
```

---

### Dwell Calculation Routine (from comprehensive_dwell_analysis.json)

**Routine Address:** `$101D0` (file offset 0x101D0) - Dwell calc uses $017B as INTERMEDIATE storage

| Address | Bytes | Instruction | Purpose |
|---------|-------|-------------|---------|
| $101C2 | FC 01 7B | LDD $017B | Load **dwell intermediate** (NOT crank!) |
| $101D0 | 1A B3 01 99 | CPD $0199 | Compare D with DWELL_RAM |
| $101DC | FD 01 99 | STD $0199 | Store to DWELL_RAM (final dwell) |
| $101DF | DC 93 | LDD $93 | Load intermediate calc from $93 |
| $101E1 | FD 01 7B | STD $017B | **← HOOK POINT (dwell intermediate, NOT crank!)** |

**TIC3 ISR - Actual Crank Period Storage:**
| Address | Bytes | Instruction | Purpose |
|---------|-------|-------------|---------||
| $3618 | FD 19 4C | STD $194C | **← ACTUAL 24X crank period storage** |

**Dwell RAM:** `$0199` (16-bit, multiple reads/writes per cycle)

---

## MAFless / Alpha-N ROM Addresses (Binary Verified Jan 27, 2026)

### M32 MAF Failure DTC System

| Address | XDF Name | Function | Stock Value | Notes |
|---------|----------|----------|-------------|-------|
| **0x56D4** | KKMASK4 (M32 Mask) | DTC logging control | 0xCC (bit 6=1) | Enables DTC M32 logging |
| **0x56DE** | KKKMASK4 (M32 CEL) | CEL/SES light control | 0xC0 (bit 6=1) | Enables CEL for M32 |
| **0x56F3** | KKACT3 (M32 Action) | **Action enable** | **0x00 (bit 6=0)** | **KEY: Stock has NO fallback action!** |

**MAFless Enable Patch:** Set `0x56F3 = 0x40` (OR with 0x40 to set bit 6) to enable MAF failure fallback mode.

**Verification:** Stock ECU logs DTC and lights CEL but takes NO action. Setting bit 6 at 0x56F3 enables actual fallback to TPS-based load.

### Min Airflow Fallback

| Address | XDF Name | Stock Value | Decoded | Purpose |
|---------|----------|-------------|---------|---------|
| **0x7F1B** | Min Airflow For Default Air | 0x01C0 | 3.5 g/s | Fallback airflow when MAF fails |
| **0x7F2A** | Default Airflow Vs RPM & TPS | Table (17 cells) | Various | TPS-based fallback table |

---

## Cold Maps ROM Addresses (Binary Verified Jan 27, 2026)

### Cold Spark Multiplier Table

| Address | ECT | Stock Raw | Decoded Mult | Purpose |
|---------|-----|-----------|--------------|---------|
| **0x64CF** | -40°C | 0xFF | 1.00 | Cold spark multiplier |
| **0x64D0** | -16°C | 0xFF | 1.00 | Cold spark multiplier |
| **0x64D1** | 8°C | 0xFF | 1.00 | Cold spark multiplier |
| **0x64D2** | 32°C | 0xAB | 0.67 | Cold spark multiplier |
| **0x64D3** | 56°C | 0x55 | 0.33 | Cold spark multiplier |
| **0x64D4** | 80°C | 0x00 | 0.00 | Cold spark multiplier |

**Force Cold Maps Patch:** Change `0x64D2-0x64D4` from `AB 55 00` to `FF FF FF` (forces 1.0 multiplier at all temps).

**Formula:** `Multiplier = byte / 255`

---

## Fuel Trim ROM Addresses (Binary Verified Jan 27, 2026)

### STFT/LTFT Enable Temperatures

| Address | XDF Name | Stock Value | Decoded Temp | Purpose |
|---------|----------|-------------|--------------|---------|
| **0x752C** | STFT Enable Temp | 0xA0 | ~90°C | Short-term fuel trim enable threshold |
| **0x7635** | LTFT Enable Temp | 0x50 | ~20°C | Long-term fuel trim enable threshold |

**Notes:**
- STFT waits until engine is warm (90°C) before adapting
- LTFT learns much earlier (20°C)

---

## Fuel Cutoff ROM Addresses (XDF Validated)

### Stock Fuel Cut Thresholds

| Address | XDF Name | Stock Value | Enhanced Value | Description |
|---------|----------|-------------|----------------|-------------|
| **0x77DD** | FUEL_CUTOFF_BASE | 0xEC (236) | 0xFF (255) | Base threshold |
| **0x77DE** | FUEL_CUTOFF_DRIVE_HIGH | 0xEC (236) | 0xFF (255) | 5,900/6,375 RPM |
| **0x77DF** | FUEL_CUTOFF_DRIVE_LOW | 0xEB (235) | 0xFF (255) | 5,875/6,375 RPM |
| **0x77E0** | FUEL_CUTOFF_PN_HIGH | ? | 0xFF | Park/Neutral HIGH |
| **0x77E1** | FUEL_CUTOFF_PN_LOW | ? | 0xFF | Park/Neutral LOW |
| **0x77E2** | FUEL_CUTOFF_REV_HIGH | ? | 0xFF | Reverse HIGH |
| **0x77E3** | FUEL_CUTOFF_REV_LOW | ? | 0xFF | Reverse LOW |

**Scaling:** `RPM = Byte × 25`  
**Maximum:** 0xFF = 255 × 25 = 6,375 RPM (effective disable)

**XDF Validation Source:**
- Line 4103: 0x77DE scaling `equation="X*25"`
- Line 4116: 0x77DF scaling `equation="X*25"`
- File: `VY V6_$060A v2.62.xdf`

---

## Speed Limiters (XDF Validated)

### First Gear Speed Limit

| Address | XDF Name | Stock Value | Description |
|---------|----------|-------------|-------------|
| **0x77E4** | 1ST_GEAR_SPEED_LIMIT | ~62 KPH | First gear hold limit |
| **0x77E6** | 2ND_GEAR_SPEED_LIMIT | ~95 KPH | Second gear hold limit |

**Notes:**
- These are 4L60E transmission limiters
- First gear hold patch modifies 0x77E4 to higher value
- Allows burnouts/drag launches without forced upshift

---

## TIO Hardware Registers (MC68HC11)

### Timer I/O Registers (Per M68HC11RM Reference Manual)

| Address | Register | Size | Description |
|---------|----------|------|-------------|
| **0x100E** | TCNT | 2 bytes | Free-running Timer Counter (16-bit) |
| **0x1010** | TIC1 | 2 bytes | Input Capture 1 |
| **0x1012** | TIC2 | 2 bytes | Input Capture 2 (24X Crank Timing) |
| **0x1014** | TIC3 | 2 bytes | Input Capture 3 (3X Cam Reference) |
| **0x1016** | TOC1 | 2 bytes | Output Compare 1 |
| **0x1018** | TOC2 | 2 bytes | Output Compare 2 (Dwell Control) |
| **0x101A** | TOC3 | 2 bytes | Output Compare 3 (EST Output) |
| **0x101C** | TOC4 | 2 bytes | Output Compare 4 |
| **0x101E** | TIC4/TOC5 | 2 bytes | Input Capture 4/Output Compare 5 |
| **0x1020** | TCTL1 | 1 byte | Timer Control 1 (OC edge selection) |
| **0x1021** | TCTL2 | 1 byte | Timer Control 2 |
| **0x1022** | TMSK1 | 1 byte | Timer Interrupt Mask 1 |
| **0x1023** | TFLG1 | 1 byte | Timer Interrupt Flags 1 |

**EST Control via TCTL1 (at 0x1020):**
- Bits 7:6 (OM1:OL1) control OC1 output mode
- Bits 5:4 (OM2:OL2) control OC2 output mode (Dwell via TOC2)
- Bits 3:2 (OM3:OL3) control OC3 output mode (EST via TOC3)
- Bits 1:0 (OM4:OL4) control OC4 output mode

**Output Mode Settings (per HC11 Reference):**
- 00 = Timer disconnected from output pin
- 01 = Toggle OCx output on compare
- 10 = Clear OCx output to 0 on compare
- 11 = Set OCx output to 1 on compare

**Chr0m3's Warning:**
> "Flipping EST off turns bypass on" - Setting OC3 bits to 00 disconnects the EST signal, triggering bypass mode failsafe

---

## Spark Timing Parameters (Estimated)

### Minimum Timing Constants ✅ CONFIRMED JAN 17 2026

| Address | Parameter | Stock Value | Patched Value | Effect |
|---------|-----------|-------------|---------------|--------|
| **0x171AA** | MIN_DWELL | 0x00A2 (162) | 0x009A (154) | Reduces min dwell ~32µs |
| **0x19813** | MIN_BURN | 0x24 (36) | 0x1C (28) | Reduces min burn ~32µs |

**CONFIRMED ADDRESSES (Jan 17 2026 Binary Analysis):**
- MIN_DWELL at file offset 0x171A9-0x171AB: CC 00 A2 = LDD #$00A2 (value at 0x171AA-0x171AB)
- MIN_BURN at file offset 0x19812-0x19813: 86 24 = LDAA #$24 (value at 0x19813)
- Both values IDENTICAL in stock (92118883_STOCK.bin) and Enhanced bins

**Notes:**
- Values from Chr0m3's testing (PCMhacking Topic 8567)
- Required for 7,200+ RPM operation
- Without patches, timer overflow at ~6,500 RPM

**The1's Overflow Math:**
```
At 6,500 RPM:
Min Dwell (0xA2) = 600µs
Min Burn (0x24) = 280µs
Combined = 880µs

3X Period @ 6,500 RPM = 3,080µs
Problem: 8-bit timer overflow in timing calculation
Result: dwell + burn = 0 → no spark
```

---

## ALDL Communication Variables

### Diagnostic RAM Locations

| Address | Name | Description |
|---------|------|-------------|
| **0x000C** | ALDL_MODE | Current diagnostic mode (1-4) |
| **0x000D** | ALDL_STATUS | Communication status flags |
| **0x000E** | ALDL_ERROR | Error counter |

**Notes:**
- Mode 1: Normal data streaming
- Mode 4: Bidirectional control
- 8192 baud, 8N1, half-duplex

---

## RAM Map Summary

### Direct Page ($0000-$00FF) - Fast Access

- **0x00A2**: Engine RPM (critical for spark cut)
- **0x00xx**: Other frequently-accessed engine variables
- 2-cycle access for load/store operations

### Extended RAM ($0100-$03FF)

- **0x017B**: ~~3X period storage~~ **DWELL INTERMEDIATE** (NOT crank period! - CORRECTED 2026-01-31)
- **0x194C**: **24X Crank Period** (ACTUAL crank period storage - verified in TIC3 ISR)
- **0x01xx-0x02xx**: Timer/calculation scratch space
- **0x03xx**: Stack area

### Calibration ROM ($4000-$7FFF)

- **0x77DD-0x77EF**: Fuel cutoff parameters
- **0x77E4-0x77E6**: Speed limiters
- **0x7xxx**: Other calibration tables

### Operating System ROM ($8000-$FFFF)

- **0x8000-0xFFFD**: OS code and ISRs
- **0xFFFE-0xFFFF**: Reset vector

---

## Variable Discovery Status

### Fully Validated (Binary + XDF + Usage Confirmed)

| Count | Category | Example |
|-------|----------|---------|
| 1 | Engine Speed | 0x00A2 RPM |
| 4 | Injector RAM | $013F, $0141, $0143, $0145 (Jan 28 2026) |
| 3 | Period/Dwell | $194C (24X crank period), $017B (dwell intermediate), $0199 (final dwell) |
| 7 | Fuel Cutoff | 0x77DD-0x77E3 |
| 2 | Speed Limits | 0x77E4, 0x77E6 |

### Partially Validated (XDF or Binary Only)

| Count | Category | Status |
|-------|----------|--------|
| 48 | Undocumented RAM | Heavily used, need XDF mapping |
| 47 | Undocumented Calibration | Unknown features |
| 2 | Timing Minimums | Values known, addresses TBD |

### Research Required

| Item | Status | Priority |
|------|--------|----------|
| 24X Crank Period | **0x194C** ✅ CONFIRMED (was 0x017B - WRONG!) | DONE |
| MIN_DWELL Address | 0x171AA ✅ CONFIRMED | DONE |
| MIN_BURN Address | 0x19813 ✅ CONFIRMED | DONE |
| TIO Config Registers | ✅ Per HC11 Reference | DONE |

---

## 🆕 NEWLY DISCOVERED RAM ADDRESSES (January 27, 2026)

**Method:** Binary pattern search for STD (Store D) instructions writing to undocumented RAM addresses

**Note:** $0199 was already documented in README.md but file offsets confirmed here for first time.

### Injector Pulse Width RAM - $0153 🔬 THEORETICAL

**Discovery:** Multiple STD $0153 writes in fuel calculation code - **NEEDS TESTING!**

| File Offset | Instruction | Context |
|-------------|-------------|---------|
| 0x169AD | `FD 01 53` STD $0153 | Primary PW calc |
| 0x16A77 | `FD 01 53` STD $0153 | PW validation |

**Suspected Usage:** May store injector pulse width calculations. **UNVERIFIED - requires bench/dyno testing.**

**Antilag Theory:** If correct, this would be the address for `antilag_turbo.asm` fuel enrichment. Replace placeholder:
```asm
INJECTOR_PW_RAM     EQU $0150       ; ❌ UNVALIDATED
```
With:
```asm
INJECTOR_PW_RAM     EQU $0153       ; 🔬 THEORETICAL Jan 27 2026 - UNTESTED!
```

**WARNING:** Do NOT use in real patches until validated on bench with oscilloscope/injector monitoring!

### Secondary Fuel RAM - $016B 🔬 THEORETICAL

**Discovery:** Multiple STD $016B writes - suspected bank 2 injectors or fuel trim (UNVERIFIED)

| File Offset | Instruction | Context |
|-------------|-------------|---------|
| 0x11C29 | `FD 01 6B` STD $016B | Bank calc |
| 0x181DA | `FD 01 6B` STD $016B | Fuel correction |
| 0x1823C | `FD 01 6B` STD $016B | Final output |
| 0x18306 | `FD 01 6B` STD $016B | Validation |

**Suspected Usage:** Unknown - possibly bank 2 injectors (VY V6 is sequential), or short-term fuel trim storage. **REQUIRES TESTING.**

### Other Discovered Addresses (Binary Found, Purpose Unknown)

| Address | Writes | Suspected Purpose |
|---------|--------|-------------------|
| $019B | 2 | Unknown spark/timing related |
| $019D | 1 | Unknown calculation |
| $0155 | 2 | Fuel related (near $0153) |
| $015F | 1 | Fuel related |
| $0169 | 1 | Fuel related (near $016B) |

**Next Steps - CRITICAL BEFORE USE:**
1. ⚠️ **Bench test with oscilloscope** - Monitor actual RAM values during engine operation
2. **Disassemble context** around each write to determine exact purpose
3. **Cross-reference** with LS1 P01/P59 RAM maps for similar patterns
4. **Injector monitoring** - Verify $0153 correlates with pulse width changes
5. **Never use in production** without hardware validation

**Reality Check:** These are pattern-matched guesses. Could be temporary calculations, could be unrelated to injectors entirely. Binary patterns ≠ confirmed functionality.

### TIC3 ISR RAM Variables (From TIC3_ISR_ANALYSIS.md) ⚠️ ENHANCED ONLY

**Source:** ISR code at 0x35FF (Enhanced v1.0a - **NOT CONFIRMED in stock 92118883**)

| Address | Purpose | Evidence | XDF Status |
|---------|---------|----------|------------|
| $0178 | Secondary 3X period storage | STD at $363E in TIC3 ISR | ❌ Not in XDF |
| $017D | Period calculation result | STAA $017D in TIC3 ISR | ❌ Not in XDF |
| $016D | Cylinder index counter | LDAB $016D in TIC3 ISR | ❌ Not in XDF |
| $01B3 | Previous TIC3 capture value | LDD $01B3 in TIC3 ISR | ❌ Not in XDF |

**⚠️ VERIFICATION STATUS:** These addresses extracted from Enhanced v1.0a ISR disassembly. The ISR code at 0x35FF is **NOT FOUND** in stock 92118883 binary. May be Enhanced-specific modifications. Requires stock binary verification.

### Mode Flag Bytes (TIC3 ISR References)

| Address | Bit Used | Instruction Example | Suspected Purpose |
|---------|----------|---------------------|-------------------|
| $0044 | Bit 4 ($10) | `BRCLR $44,#$10,$361C` | Unknown mode gate |
| $0048 | Bit 0 ($01) | `BRSET $48,#$01,$3616` | Unknown state toggle |

**Status:** Found in Enhanced TIC3 ISR, purpose unknown. Not analyzed in stock binary.

---

## ROM Addresses - MAFless/Alpha-N System (From MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md)

### MAF Failure DTC Control

| Address | XDF Name | Function | Stock Value | Code Refs | Notes |
|---------|----------|----------|-------------|-----------|-------|
| **0x56D4** | KKMASK4 | DTC M32 logging enable | 0xCC (bit 6=1) | 6+ | Enables M32 MAF failure logging |
| **0x56DE** | KKKMASK4 | DTC M32 CEL control | 0xC0 (bit 6=1) | Multiple | Enables CEL for M32 |
| **0x56F3** | KKACT3 | **MAF failure action** | **0x00 (bit 6=0)** | Unknown | **KEY: Stock logs DTC but takes NO action!** |

**Critical Finding (Jan 22, 2026):** Stock ECU logs M32 DTC and lights CEL but **does not enable fallback mode**. Setting bit 6 at 0x56F3 = 0x40 enables actual Alpha-N fallback.

### $56D4 Bit Map (Disassembly Verified)

| Bit | Mask | DTC Code | File Offset | Instruction |
|-----|------|----------|-------------|-------------|
| 7 | $80 | M38? | 0x15678 | LDAB $56D4 / BITB #$80 |
| **6** | **$40** | **M32 MAF** | 0x156A3 | LDAB $56D4 / BITB #$40 |
| 5 | $20 | M35? | 0x156CE | LDAA $56D4 / BITA #$20 |
| 4 | $10 | M34 MAP Low | 0x15713 | LDAA $56D4 / BITA #$10 |
| 3 | $08 | M33 MAP High | 0x15758 | LDAA $56D4 / BITA #$08 |
| 2 | $04 | M31? | 0x15812 | LDAA $56D4 / BITA #$04 |

### Default Airflow Tables

| Address | XDF Name | Stock Value | Code Refs | Purpose |
|---------|----------|-------------|-----------|---------|
| **0x7F1B** | Min Airflow For Default Air | 0x01C0 (3.5 g/s) | **19** | Single fallback value when MAF fails |
| **0x7F2A** | Default Airflow Vs RPM & TPS | 7×5 table | **0** | ⚠️ **Defined in XDF but UNUSED by stock code!** |

**Major Discovery:** The $7F2A TPS-based fallback table exists in XDF but has **zero code references** in stock binary. Custom ASM required to use it.

---

## ROM Addresses - Idle/Spark Control (From ASM Files)

### Lumpy Idle / Ghost Cam Tables

| Address | XDF Name | Size | Source | Purpose |
|---------|----------|------|--------|---------|
| **0x6536** | IDLE_SPARK_TABLE | 11 cells | lumpy_idle_xdf_parameters_v2.asm | Idle spark advance table |
| **0x6541** | RETARD_SPARK_TABLE | 11 cells | lumpy_idle_xdf_parameters_v2.asm | Retarded spark table |
| **0x652C** | RETARD_IDLE_FLAG | 1 byte | lumpy_idle_xdf_parameters_v2.asm | Enable retard at idle |

**Status:** VERIFIED addresses per ASM comments. Used for XDF-only lumpy idle tuning (slow 1Hz lope).

### Fuel Cut System Extensions

| Address | XDF Name | Stock Value | Purpose |
|---------|----------|-------------|---------|
| **0x77DC** | FUEL_CUT_ENABLE | ? | "If KPH > CAL Use Drive CALS" |
| **0x77D5** | FUEL_CUT_TPS | ? | "If TPS > CAL Disable Decel Fuel Cutoff" |
| **0x77EE** | FUEL_CUT_AFR_D | ? | "Fuel Cutoff A/F Ratio in Drive" |
| **0x77EF** | FUEL_CUT_AFR_PN | ? | "Fuel Cutoff A/F Ratio in P/N And Reverse" |

**Source:** fuel_cut_enhanced.asm - Extends stock fuel cut at 0x77DD-0x77E3 with additional parameters.

### Tables Repurposed for Speed Density

| Address | Stock XDF Name | Repurposed As | Notes |
|---------|----------------|---------------|-------|
| **0x6D1D** | Maximum Airflow Vs RPM | VE Table Base | 17 cells, multiple ASM files use this |
| **0x7800** | *(Free space?)* | VE Enable Flag | speed_density_ve_table.asm |
| **0x7810** | *(Free space?)* | IAT Comp Table | 16 bytes |
| **0x7820** | *(Free space?)* | ECT Comp Table | 16 bytes |
| **0x7830** | *(Free space?)* | Baro Comp Table | 16 bytes |

**⚠️ WARNING:** Addresses 0x7800-0x7830 are HYPOTHETICAL free space allocations. **Must verify these are unused before patching!**

---

## IAT and BARO Sensor Addresses (Validated Nov 24, 2025)

### IAT (Intake Air Temperature) Sensor

**Validation Status**: VALIDATED | **Confidence**: 100%

**ALDL Datastream Packets:**
- **0x06**: Intake Air Temp Sensor Voltage - Formula: `X * 0.019608 Volts`
- **0x07**: Intake Air Temp - Formula: `X * 0.750000 + -40.000000 Deg C`

**XDF Calibration Tables:**
- **0x66DB**: Spark IAT Table
- **0x674B**: Spark IAT Multiplier

### BARO (Barometric Pressure) Sensor

**Validation Status**: VALIDATED | **Confidence**: 100%

**ALDL Datastream Packets:**
- **0x0A**: Barometric Pressure - Formula: `X * 0.312500 + 20.000000 KPA` (Range: 20-105 kPa)

**XDF Calibration Tables:**
- **0x4D49**: Barometric Pressure Vs AD Counts Lookup Table
- **0x4D5A**: Barometric Pressure Filter Coefficient
- **0x571B**: Barometric Sensor High Reading Limit
- **0x571F**: Barometric Sensor Low Reading Limit

### External SPI ADC Architecture

**Critical Finding (Nov 21, 2025):**
- 28 SPI register accesses found, 12 SPI transaction sequences
- ZERO PE0-PE7 internal ADC channel selections found
- **IAT and BARO use external SPI ADC chip via PD2-PD5 SPI bus**

---

### Scripts
- `tools/map_ram_variables.py` - RAM variable analyzer (generates this data)

---

**Last Updated:** January 26, 2026  
**Maintainer:** KingAI Tuning Project
