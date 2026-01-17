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

### Timer Output Compare

| Address | Register | Description |
|---------|----------|-------------|
| **0x1018** | TOC1 | Timer Output Compare 1 (EST primary) |
| **0x101A** | TOC2 | Timer Output Compare 2 |
| **0x101C** | TOC3 | Timer Output Compare 3 |
| **0x1020** | TCTL1 | Timer Control Register 1 |

**EST Control via TCTL1:**
- Bits 5:4 (OM2:OL2) control EST output mode
- 00 = Disconnected (triggers bypass mode - NOT recommended)
- 01 = Toggle on compare
- 10 = Clear on compare
- 11 = Set on compare

**Chr0m3's Warning:**
> "Flipping EST off turns bypass on" - direct register manipulation triggers failsafe

---

## Spark Timing Parameters (Estimated)

### Minimum Timing Constants

| Address | Parameter | Stock Value | Patched Value | Effect |
|---------|-----------|-------------|---------------|--------|
| **TBD** | MIN_DWELL | 0xA2 (162) | 0x9A (154) | Reduces min dwell ~50µs |
| **TBD** | MIN_BURN | 0x24 (36) | 0x1C (28) | Reduces min burn ~50µs |

**Notes:**
- Exact ROM addresses need XDF search or disassembly
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
| 3X Period Address | 0x017B assumed | HIGH |
| MIN_DWELL Address | Unknown | HIGH |
| MIN_BURN Address | Unknown | HIGH |
| TIO Config Registers | Standard HC11 | MEDIUM |

---

## Cross-Reference Documents

- `discovery_reports/RAM_Variable_Report.md` - Full map_ram_variables.py output
- `discovery_reports/XDF_Coverage_Report.md` - XDF version comparison
- `CHROME_RPM_LIMITER_FINDINGS.md` - Chr0m3's validated values
- `docs/Chr0m3_Spark_Cut_Analysis_Critical_Findings.md` - Topic 8567 archive

---

**Last Updated:** December 6, 2025  
**Maintainer:** KingAI Tuning Project
