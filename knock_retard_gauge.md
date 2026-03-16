# Knock Retard Indicator Light — VY V6 L36 $060A Enhanced v1.0a
will make a .asm in the buttons folder or another? will keep local for now till i say push.
## Status: WIP / UNTESTED — Concept only, no binary patch written yet

## Concept
Patch the ECU to drive a visible indicator when knock retard is active:
- **Flicker** on light knock (>1.05° retard)
- **Solid ON** when heavy knock retard (>5.98° retard)
- Useful for tuning — tells you the ECU is pulling timing before detonation damages the engine

---

## Stock Knock System — XDF Addresses (Bank 1, Enhanced v1.0a)

All addresses from `Enhanced_v1.0a_bank{1,2}_labeled_v2.asm` via XDF labels.

### Knock Control Enable/Disable

| Address | XDF Name | Stock Value | Notes |
|---------|----------|-------------|-------|
| `$6957` | Knock Sensor Control Logic Enable | FLAG mask=0x?? | Bit flag — 1 = ESC enabled |
| `$6ADC` | If RPM lower than this value disable knock control | 500 RPM | Below this = no knock processing |
| `$69C9` | Attack Rate = Zero If Runtime < CAL | 5.0 SEC | No knock retard until engine running >5s |
| `$69CB` | Attack Rate = Zero If Coolant < CAL | 20.0 °C | No knock retard when cold |

### Knock Retard Thresholds (these are the trigger points)

| Address | XDF Name | Stock Value | How the ECU uses it |
|---------|----------|-------------|---------------------|
| `$696C` | Spark Knock Must Be > This — Light Knock Retard Rate | 1.05 DEG | If knock signal > 1.05° → light knock path |
| `$696D` | Spark Knock Must Be > This — Heavy Knock Retard Rate | 5.98 DEG | If knock signal > 5.98° → heavy knock path |
| `$6877` | Knock Maximum Retard | 11.95 DEG | Absolute max the ECU will pull timing | can this go higher?

### Knock Retard Rate Timing

| Address | XDF Name | Stock Value |
|---------|----------|-------------|
| `$696F` | Time Between Retard Updates For Light Knock | 1.11 SEC |
| `$6970` | Time Between Retard Updates For Heavy Knock | 1.05 SEC |
| `$6971` | Rate At Which Multiplier Moves Toward Retard Table | 0.14 |
| `$6972` | Time Between Retard Updates Of Multiplier If Cell Has Recovered | ?? |

### Knock Retard Limits

| Address | XDF Name | Stock Value |
|---------|----------|-------------|
| `$695F` | Knock Retard Limit Not in PE Mode | 15.002 DEG |
| `$6961` | Knock Retard Limit When in PE Mode | 15.002 DEG |
| `$696E` | Adaptive Spark Hi/Lo Difference Must Be > This | ?? |

### Burst Knock Scalars

| Address | XDF Name | Stock Value |
|---------|----------|-------------|
| `$651A` | Burst Knock Min Coolant Temp | 151.25 °C |
| `$651B` | Burst Knock Max RPM | 6375 RPM |
| `$651C` | Burst Knock Delta TPS | 4.69 TPS% |
| `$651D` | Burst Knock Stage1 Duration | 1.0 REFPLS |
| `$651E` | Burst Knock Stage2 Duration | 5.0 REFPLS |
| `$651F` | Burst Knock Retard | 12.13 DEG |
| `$6520` | Burst Knock Stage 1 Decay Delta | 1.05 DEG |
| `$6521` | Burst Knock Stage 2 Decay Delta | 0.35 DEG |
| `$6522` | Burst Knock TPS Offset % | 2.3 TPS% |

### ESC (Electronic Spark Control) Tables

| Address | XDF Name | Type |
|---------|----------|------|
| `$69CC` | ESC Attack Rate Vs RPM | TABLE 1x17 |
| `$69DD` | ESC Attack Rate 0-2 Multiplier Vs ADSPKRT | TABLE 1x18 |
| `$69F1` | ESC Delay Cal 12.5ms Loops Per Recovery Update | Scalar |
| `$6B92` | If Average < This — Gain = Gain + ESCGADJ | 0.8 V |
| `$6B93` | If Average > This — Gain = Gain − ESCGADJ | 1.46 V |
| `$6B94` | ESC Gain Adjustment To BPF | FLAG 2 DB |
| `$6B95` | DSNEF ESC Minimum Gain | 0.0 DB |
| `$6B96` | DSNEF ESC Maximum Gain | 26.0 DB |

### ESC Modifier

| Address | XDF Name | Stock Value |
|---------|----------|-------------|
| `$4467` | ESC Modifier For Pressure | 0.0 PSI |

### DTC Related

| Address | XDF Name | Notes |
|---------|----------|-------|
| `$56DB` | Process DTC 93 — RH ESC Failure (Knock Circuit) | FLAG mask |
| `$56E5` | Engine MIL DTC 93 — RH ESC Failure (Knock Circuit) | FLAG mask |

---

## Knock Processing Code Location (Bank 2)

The main knock control routine lives in **Bank 2** around `$8239–$83F9` and `$F5D6–$F726`.

### Key code flow (from `Enhanced_v1.0a_bank2_labeled_v2.asm`):

```
$F5D6: Check runtime > 5s        (compare $22 vs $69C9)
$F5DF: Check coolant > 20°C      (compare $A4 vs $69CB)
$F5E4: Check RPM > 500           (compare $A2 vs $6ADC)
$F5EB: If any fail → JMP $F726   (skip knock processing entirely)

$F5FF: Load knock signal, compare vs $696C (light threshold = 1.05°)
$F608: Compare vs $696D (heavy threshold = 5.98°)

Light path:
  $F62A: Compare timer vs $696F (light knock update interval = 1.11s)
  → If timer expired: update retard multiplier

Heavy path:
  $F618: Compare timer vs $6970 (heavy knock update interval = 1.05s)
  → If timer expired: update retard multiplier (faster attack)

$F631: Add $6971 (retard step) to current retard multiplier
$F636: Clamp to 0xFF max
```

### What we need to read for the indicator:
- The **current knock retard amount** lives in the ESC working RAM area
- RAM address range `$1820–$1826` appears to be the per-cylinder ESC retard storage (6 cells at offset from `$1820`, accessed via X-index at `$F5FA`)
- The comparison at `$F5FF` uses `6, x` offset from `$1826` base — this is the **current accumulated retard value** per cylinder

---

## Output Method — MIL Lamp (PB2 / Pin C15)

### Confirmed from pinout CSV:
- **Port:** PB2 (HC11 Port B, bit 2)
- **Register:** `$1004` (PORTB)
- **Pin:** C15 on 32-pin C/D connector
- **Wire:** GREY
- **Type:** Ground-switched output to instrument cluster
- **Function:** Malfunction Indicator Lamp (Check Engine / SES)

### How to toggle it from a patch:

```asm
; Turn MIL ON (ground-switch active = lamp lit)
LDAA  $1004       ; read PORTB
ORAA  #$04        ; set bit 2
STAA  $1004       ; write PORTB → MIL ON

; Turn MIL OFF
LDAA  $1004       ; read PORTB
ANDA  #$FB        ; clear bit 2 (mask = ~$04)
STAA  $1004       ; write PORTB → MIL OFF
```

### WARNING
The stock DTC processing code **also drives PB2/MIL** — if a DTC is set, the MIL will be on regardless of your knock patch. Any patch must work **alongside** the existing MIL logic, not fight it. Options:
1. **Multiplex:** Only flicker when MIL is not already on for a DTC
2. **Use a different output:** Wire an external LED to QDM4 (pin F7) or an unused QDM channel instead
3. **ALDL method:** Send knock retard status via ALDL datastream and use a gauge/tablet to display it (no hardware changes needed)

---

## Knock Sensor Hardware

| Pin | Connector | Wire | Function |
|-----|-----------|------|----------|
| C10 | C/D 32-pin | Blue | LH Knock Sensor |
| C11 | C/D 32-pin | Light Blue | RH Knock Sensor |

Both are AC piezo-electric sensors mounted on the engine block. The ESC module filters the signal through a bandpass filter (BPF) with gain range 0–26 dB (`$6B95`–`$6B96`).

---

## Patch Strategy (NOT IMPLEMENTED)

### Option A: Hook into the existing knock processing (Bank 2)
Patch after the `$F5FF`/`$F608` comparison to toggle PB2 based on which threshold was exceeded:

```asm
; CONCEPT ONLY — addresses need verification
; Insert after $F608 heavy knock compare

; If we got here, knock > light threshold (1.05°)
; Check if heavy (>5.98°)
BHI   .heavy_knock

.light_knock:
  ; Flicker MIL — toggle bit 2
  LDAA  $1004
  EORA  #$04        ; XOR toggles the bit each pass
  STAA  $1004
  BRA   .done

.heavy_knock:
  ; Solid ON
  LDAA  $1004
  ORAA  #$04
  STAA  $1004

.done:
  ; Continue stock code...
```

### Option B: Separate routine in free space (C500)
Write a standalone routine that:
1. Reads the current knock retard from RAM (`$1820`+ area)
2. Compares against thresholds
3. Drives output accordingly
4. Gets called from the main loop via a hook

### Option C: ALDL datastream (no ECU patch needed)
The knock retard value is already in the ALDL Mode 1 datastream.
Read it with MrModule, ELM327, or custom Arduino and drive an external gauge.
**This is the safest option — zero risk of bricking the ECU.**

---

## TODO Before Implementation
- [ ] Confirm exact RAM address that holds current total knock retard (likely in `$1820`–`$182C` range)
- [ ] Verify the MIL bit doesn't get overwritten by the DTC routine every loop cycle
- [ ] Decide output method: hijack MIL vs external LED vs ALDL gauge
- [ ] Test with labeled bank 2 disassembly to trace the exact retard accumulator storage
- [ ] Write actual patch bytes and test on bench with JimStim knock simulation
- [ ] Check if QDM4 (F7) is available as an alternative output that doesn't conflict with DTCs