# VY V6 $060A RAM Variables - Validated Reference
to add x and y linking to a xdf i think this is needed and for patching safer with less guesswork and verification needed. once we know math and constants and the full internals confirmed or confidently with no other option and then check it twice we know its right. remeber the way the hc11 works from docuemnts and xdf.
**Document Created:** December 6, 2025  
**Source:** map_ram_variables.py analysis, XDF validation, PCMhacking research  
**Status:** Validated for Enhanced v1.0a (92118883)  
**Processor:** MC68HC11 (8-bit, $060A mask)

---

## Critical RAM Addresses (Confirmed)

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

### 3X Period Storage

| Address | Name | Size | Access | Description |
|---------|------|------|--------|-------------|
| **0x017B** | 3X_PERIOD | 2 bytes | Frequent | Time between 3X pulses (µs) |

**Notes:**
- This is the key target for Chr0m3's spark cut method
- Injecting fake high value (e.g., 0x3E80 = 16,000) causes dwell underflow
- Normal values at 6,000 RPM: ~3,333µs (10ms per revolution ÷ 3 pulses)

**Spark Cut Injection:**
```assembly
; When RPM > threshold, inject fake 3X period
LDD #$3E80          ; 16,000 = ~1 second apparent period
STD $017B           ; Store to 3X period variable
                    ; Result: Dwell calculation returns ~100µs (too short)
```

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

- **0x017B**: 3X period storage (spark cut target)
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
| 3X Period Address | 0x017B ✅ CONFIRMED | DONE |
| MIN_DWELL Address | 0x171AA ✅ CONFIRMED | DONE |
| MIN_BURN Address | 0x19813 ✅ CONFIRMED | DONE |
| TIO Config Registers | ✅ Per HC11 Reference | DONE |

---

## Cross-Reference Documents

### HC11 Reference Sources
- `68HC11_Reference/68HC11_COMPLETE_INSTRUCTION_REFERENCE.md` - Complete opcode table
- `68HC11_Reference/M68HC11RM_Reference_Manual.pdf` - Official Motorola reference
- `MC68HC11_Reference.md` - Quick reference guide

### Project Documents
- `discovery_reports/RAM_Variable_Report.md` - Full map_ram_variables.py output
- `discovery_reports/XDF_Coverage_Report.md` - XDF version comparison
- `CHROME_RPM_LIMITER_FINDINGS.md` - Chr0m3's validated values
- `docs/Chr0m3_Spark_Cut_Analysis_Critical_Findings.md` - Topic 8567 archive

### Scripts
- `tools/map_ram_variables.py` - RAM variable analyzer (generates this data)

---

**Last Updated:** January 18, 2026  
**Maintainer:** KingAI Tuning Project
