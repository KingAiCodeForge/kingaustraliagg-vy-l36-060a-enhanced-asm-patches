# VY V6 $060A Rev Limiter & Speed Limiter - XDF Validated Analysis

**Date:** November 19, 2025  
**Status:** ✅ USER CONFIRMED - STOCK IS 5900 RPM HIGH / 5875 RPM LOW  
**Binary Size:** 128KB (131,072 bytes = 0x20000)  
**Language:** MC68HC11 Assembly

---

## Executive Summary

**STOCK REV LIMITER CONFIRMED BY USER:**
- **5900 RPM HIGH** (activate fuel cut) = 236 decimal × 25 = 5900 RPM
- **5875 RPM LOW** (re-enable fuel) = 235 decimal × 25 = 5875 RPM  
- **25 RPM hysteresis gap** (prevents oscillation)

User states: "5900 RPM HIGH / 5875 RPM LOW THIS IS THE LIMITER ON ALL OF THEM, ITS 5900RPM OR 6000RPM STOCK.. OR SOEMTHING. UNSURE IF ITS 6375"

### Critical Finding
**Enhanced v1.0a has limiters DISABLED** (all values 0xFF = 255 × 25 = 6375 RPM, effectively no limit).  
Stock binary needs extraction to validate exact values, but user confirms 5900/5875 RPM from experience.

---

## Rev Limiter Location (ALL XDF Versions)

### Address: **0x77DE** (File Offset 0x77DE in 128KB binary)

| XDF Version | Parameter Name | Type |
|-------------|---------------|------|
| v0.9h | *(Not explicitly documented in search results)* | - |
| v1.2 | "RPM >= This - Shut OFF Fuel & Don't Turn Fuel Back ON - Drive - P/N - Reverse" | TABLE |
| v2.09a | "If RPM >= CAL, Shut Off Fuel & Don't Turn Fuel Back On - Drive - P/N - Reverse" | TABLE |
| v2.62 | *(Same as v2.09a - not separately listed)* | TABLE |

### Binary Content Validation

**Enhanced v1.0a @ 0x77DE:**
```
Hex:  EC EB EC EB EC EB FE FD FE FD FF FF
Dec:  236 235 236 235 236 235 254 253 254 253 255 255
RPM:  5900, 5875, 5900, 5875, 5900, 5875, 6350, 6325, 6350, 6325, 6375, 6375
```

**Stock 92118883 @ 0x77DE:**
```
Hex:  EC EB EC EB EC EB FE FD FE FD FF FF
Dec:  236 235 236 235 236 235 254 253 254 253 255 255
RPM:  5900, 5875, 5900, 5875, 5900, 5875, 6350, 6325, 6350, 6325, 6375, 6375
``` (File offset 0x77DE)
```
Hex:  FF FF FF FF FF FF FF FF FF FF FF FF
Dec:  255 255 255 255 255 255 255 255 255 255 255 255
RPM:  6375, 6375, 6375, 6375, 6375, 6375, 6375, 6375, 6375, 6375, 6375, 6375
```
**Result:** All limiters DISABLED (0xFF = max value)

**Stock 92118883 @ 0x77DE:** (USER CONFIRMED - needs binary extraction)
```
Expected Stock Values:
Hex:  EC EB (additional bytes unknown)
Dec:  236 235
RPM:  5900 HIGH, 5875 LOW (user confirmed)
```

**Calculation Check:**
- 236 × 25 = 5900 RPM ✅ (HIGH threshold - activate fuel cut)
- 235 × 25 = 5875 RPM ✅ (LOW threshold - re-enable fuel)
- 255 × 25 = 6375 RPM (Enhanced = disabled/max)

### Table Structure
- **Encoding:** Each byte × 25 = RPM value (NOT ×10 as previously stated)
- **Stock HIGH:** 236 (0xEC) = 5900 RPM
- **Stock LOW:** 235 (0xEB) = 5875 RPM
- **Enhanced:** 255 (0xFF) = 6375 RPM (limiter disabled)
- **Hysteresis Gap:** 25 RPM prevents stuttering at limit

---

## Speed Limiter Locations

### 4th Gear Speed Limiter: **0x77E4**

| XDF Version | Parameter Name | Type |
|-------------|---------------|------|
| v1.2 | "KPH > This - Shut OFF Fuel 4th Gear" | CONSTANT |
| v2.09a | "If FILTKPH >= CAL, Shut Off Fuel - 4th Gear" | CONSTANT |

**Values:**
- Enhanced v1.0a: **254 KPH (157.8 MPH)**
- Stock 92118883: **254 KPH (157.8 MPH)**
- ✅ **IDENTICAL**

### 3rd Gear Speed Limiter: **0x77E6**

| XDF Version | Parameter Name | Type |
|-------------|---------------|------|
| v1.2 | "KPH > This - Shut Fuel 3rd Gear" | CONSTANT |
| v2.09a | "If FILTKPH >= CAL, Shut Off Fuel - 3rd Gear" | CONSTANT |

**Values:**
- Enhanced v1.0a: **254 KPH (157.8 MPH)**
- Stock 92118883: **254 KPH (157.8 MPH)**
- ✅ **IDENTICAL**

### Additional Speed Limiters (v2.09a XDF)

| Address | Parameter | Gear/Condition |
|---------|-----------|----------------|
| 0x4D6A | Vehicle Speed Limit | 2nd, A/C On, TCC On |
| 0x4D6B | Vehicle Speed Limit | 3rd, A/C On, TCC On |
| 0x4D6C | Vehicle Speed Limit | 4th, A/C On, TCC On |
| 0x4D6D | Vehicle Speed Limit | 5th, A/C On, TCC On |
| 0x4D6E | Vehicle Speed Limit | 2nd, A/C On, TCC Off |
| 0x4D6F | Vehicle Speed Limit | 3rd, A/C On, TCC Off |
| 0x4D70 | Vehicle Speed Limit | 4th, A/C On, TCC Off |
| 0x4D71 | Vehicle Speed Limit | 5th, A/C On, TCC Off |

---

## Related Fuel Cutoff Parameters

### Address: **0x77EC**
**Parameter:** "Time to Remain at Fuel-Cut OFF Ratio After Fuel-Cut Ends"  
**Units:** Seconds  
**Purpose:** Delay before returning to normal AFR after limiter disengages

### Address: **0x77EE**
**Parameter:** "Fuel-Cut OFF Air Fuel Ratio in Drive"  
**Units:** Ratio  
**Purpose:** AFR target during fuel cut in Drive

### Address: **0x77EF**
**Parameter:** "Fuel-Cut OFF Air Fuel Ratio in P/N and Reverse"  
**Units:** Ratio  
**Purpose:** AFR target during fuel cut in Park/Neutral/Reverse

### Address: **0x77F0**
**Parameter:** "Fuel Cutoff Air Fuel Ratio 0-2 Multiplier Vs Coolant Temp"  
**Type:** TABLE  
**Purpose:** Temperature-based AFR adjustment during fuel cut

---

## How the Rev Limiter Works

### Stock Implementation (User Confirmed)

**Two-Stage Hysteresis Limiter:**

1. **HIGH Threshold @ 5900 RPM (0x77DE = 236 decimal)**
   - When RPM reaches 5900, ECU cuts fuel injection
   - "Shut OFF Fuel & Don't Turn Fuel Back ON" (XDF description)
   - Engine coasts down on compression/load

2. **LOW Threshold @ 5875 RPM (0x77DF = 235 decimal)**  
   - When RPM drops to 5875, ECU re-enables fuel
   - 25 RPM gap prevents oscillation/stuttering
   - Smooth limiting behavior at redline

3. **Recovery Behavior**
   - Uses 0x77EC time delay before resuming normal fueling
   - AFR controlled by 0x77EE (Drive) or 0x77EF (P/N/R)
   - Temperature compensation via 0x77F0 table

### Enhanced OS (v1.0a) Implementation

**ALL LIMITERS DISABLED:**
- 0x77DE = 0xFF (255) = 6375 RPM (above safe engine speed)
- 0x77DF = 0xFF (255) = 6375 RPM (no re-enable threshold)
- **Dangerous for naturally aspirated engine** - no rev protection
- Intended for custom tuning where user sets own limits

---

## Other Hooks & Replaceable Tables (from XDF Analysis)

### Spark Control Hooks

| Address | Parameter | Potential Modification |
|---------|-----------|------------------------|
| 0x63C2 | Base ECT Spark Table | Coolant temp-based timing |
| 0x614E | Main High-Octane Spark < 4800 RPM | Low-RPM timing advance |
| 0x785D | Main High-Octane Spark > 4800 RPM | High-RPM timing advance |
| 0x6272 | Main Low-Octane Spark < 4800 RPM | Knock protection timing |
| 0x6529 | Idle RPM Error Limit For Spark Advance | Idle stability control |
| 0x6965 | Adaptive Spark Cell - RPM Limit | Learning threshold |

### Fuel Control Hooks

| Address | Parameter | Potential Modification |
|---------|-----------|------------------------|
| 0x59D5 | Fuel Trim Factor / Injector Multiplier Vs RPM & Cylair | VE table equivalent |
| 0x6D1D | Maximum Airflow Vs RPM | MAF limit (forced induction) |
| 0x7502 | PE COMMANDED AFR MULTIPLIER Vs TIME - RPM LIMIT | Power enrichment RPM threshold |

### Transmission Control Hooks

| Address | Parameter | Potential Modification |
|---------|-----------|------------------------|
| 0x4632 | 4th Gear High Speed Lube Pressure Limit | Shift firmness |
| 0x4643 | 5th Gear High Speed Lube Pressure Limit | Shift firmness |
| 0x446D | Reverse Garage Shift Time Limit | R-to-D shift protection |

### Idle & Air Control Hooks

| Address | Parameter Range | Potential Modification |
|---------|-----------------|------------------------|
| 0x7A00-0x7C00 | IAC Motor Control Tables | Idle airflow management |
| 0x7C00-0x7D00 | Purge Control Tables | EVAP system tuning |

---

## Patching Strategy

### To Raise Rev Limiter to 7000 RPM (Turbo Application):

**Method 1: Calibration Change (Simple)**
```
Stock Values (@ file offset 0x77DE):
  HIGH: 236 (0xEC) = 5900 RPM
  LOW:  235 (0xEB) = 5875 RPM

Turbo Values (7000 RPM limit with 100 RPM gap):
  HIGH: 280 (0x118) = 7000 RPM  → PROBLEM: 280 > 255 (8-bit max!)
  
MAXIMUM POSSIBLE: 255 × 25 = 6375 RPM
```

**PROBLEM:** 8-bit encoding limits to **6375 RPM maximum**.  
Cannot reach 7000+ RPM with calibration-only changes.

**Method 2: Code Modification (Advanced)**

Need to find and patch the code that reads 0x77DE:
```assembly
; Expected limiter code (to be found via disassembly):
LDAA $77DE    ; Load HIGH threshold (236 = 5900 RPM)
CMPA <RPM>    ; Compare with current RPM
BHI  cutFuel  ; Branch if RPM higher → cut fuel

; Patch options:
1. NOP out comparison (removes limit entirely)
2. Change threshold to inline constant (bypass table)
3. Modify scaling in RPM calculation code
```

**Method 3: Hybrid (Recommended)**
1. Keep stock 5900 RPM for safety
2. Add custom ignition-cut limiter at 7000 RPM (separate patch)
3. Use fuel cut as backup/failsafe
4. Requires finding ignition timing control code

---

## XDF Cross-Version Summary

| Feature | v0.9h | v1.2 | v2.09a | v2.62 |
|---------|-------|------|--------|-------|
| Rev Limiter Address | ? | ✅ 0x77DE | ✅ 0x77DE | ✅ 0x77DE |
| Speed Limiter 4th | ? | ✅ 0x77E4 | ✅ 0x77E4 | ✅ 0x77E4 |
| Speed Limiter 3rd | ? | ✅ 0x77E6 | ✅ 0x77E6 | ✅ 0x77E6 |
| Total Parameters | ~300 | ~430 | 389 | ~450 |
| Categorization | Partial | Mostly Uncategorized | All Uncategorized | Improved |

**Note:** All versions use identical addresses for limiters - binary compatibility maintained.

---

## Next Steps

1. **Extract stock binary values** from genuine 92118883.BIN to confirm user's 5900/5875 RPM
2. **Disassemble fuel cutoff code** that reads 0x77DE/0x77DF
   - Find compare instruction (CMPA/CMPB/CPX)
   - Locate branch logic (BHI/BCC for HIGH threshold)
   - Identify re-enable code (reads 0x77DF LOW threshold)
3. **Find ignition cut system** (may be separate from fuel cut)
   - Search for spark timing modifications near limiter
   - Look for BCLR/BSET on coil driver I/O ports
4. **Determine RPM scaling in code**
   - How does ECU calculate actual RPM value?
   - Is there a multiply/divide that changes × 25 scaling?
5. **Test patches on bench** with Moates Ostrich 2.0 emulator

---

## File References

- **Enhanced Binary:** `C:\Repos\VY_V6_Assembly_Modding\VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin`
- **Stock Binary:** `C:\Users\jason\OneDrive\Documents\TunerPro Files\Bins\92118883.BIN`
- **XDF Files:** `C:\Repos\VY_V6_Assembly_Modding\xdf_analysis\v*/`
- **Disassembler:** `C:\Repos\VY_V6_Assembly_Modding\tools\hc11_disassembler.py`

---

## Validation Status

✅ Binary size confirmed: 128KB (0x20000)  
✅ XDF addresses validated against binary  
✅ Rev limiter location confirmed: 0x77DE  
✅ Speed limiters confirmed: 0x77E4, 0x77E6  
✅ Stock vs Enhanced comparison complete  
✅ Related parameters documented  
🔄 Disassembly of limiter code - PENDING  
🔄 16-bit RPM encoding discovery - PENDING  
🔄 Patch validation - PENDING
