## How to Add Wideband (14.7 Kit / Innovate 4.9) to VS VT VX VY V6 ADX Files

**Last Updated:** January 25, 2026

---

## Introduction 

This guide walks through adding Wideband 14.7 Kit and Innovate 4.9 (LC-1, etc.) support to Holden Commodore ADX files. This enables real-time AFR logging alongside standard datastream parameters.

---

## Complete Wideband ADX File Inventory

### Standalone Wideband Controller Plugins

These are generic wideband plugins that can be used with any ECU ADX:

| File | Controller Type | Notes |
|------|-----------------|-------|
| `Innovate LC-1.adx` | Innovate LC-1 | Serial wideband controller |
| `LC1Plugin.adx` | Innovate LC-1 | Alternative LC-1 plugin |
| `TechEdge Wideband O2 Controllers.adx` | TechEdge | TechEdge serial controllers |

### ADX Files with Wideband Already Integrated

These are ECU datastream files that already have wideband channels added:

| File | Platform | Wideband Type | Scaling |
|------|----------|---------------|---------|
| `%2451 VS V6 Engine and Trans v1.10 WB 14.7kit.adx` | VS V6 ($51) | 14.7 Kit | 0-5V = 10-20 AFR |
| `%2451 VS V6 Engine and Trans v1.10 WB Innovate.adx` | VS V6 ($51) | Innovate | 0-5V = 7.35-22.39 AFR |
| `Vs V6 engine and trans 1.07-tp5-wideband.adx` | VS V6 | Generic WB | Unknown scaling |
| `VR_$11_v1.04-tp5-wideband.adx` | VR V6 ($11) | Generic WB | Unknown scaling |

### ADX Files WITHOUT Wideband (Targets for Addition)

#### VR Platform (1227424 ECU - $11/$12)
| File | Version | Notes |
|------|---------|-------|
| `VR_$11_v1.01.adx` | v1.01 | Base version |
| `VR_$11_v1.04-tp5.adx` | v1.04 | Has wideband variant available |
| `VR_$11_v1.05-tp5.adx` | v1.05 | Latest |
| `VR_$12_v1.03.adx` | v1.03 | 1227808 ECU |
| `VR_$12_v1.03 TP5.adx` | v1.03 | TP5 format |

#### VS Platform
| File | Version | Notes |
|------|---------|-------|
| `vs_V6_v1.02.adx` | v1.02 | Base VS V6 |
| `Vs V6 engine and trans 1.07-tp5.adx` | v1.07 | Has wideband variant available |
| `Vs V6 engine and trans 1.08-tp5 - Credit to Jayme.adx` | v1.08 | Latest stock |
| `VS S1 and S2 and VR_$11_v1.05-tp5.adx` | v1.05 | Series 1/2 combined |
| `VS S3 V8 A6 Engine and trans TP5 v104.adx` | v1.04 | VS V8 |
| `VS_V6_$51_Enhanced_v1.4d.adx` | v1.4d | Enhanced |
| `VS_V6_$51_Enhanced_v1.4e.adx` | v1.4e | Enhanced (latest) |
| `VS_V6_SC_$51_Enhanced_v1.0e.adx` | v1.0e | Supercharged Enhanced |
| `VS_V8_$A6F_Enhanced_v0.81b.adx` | v0.81b | VS V8 Enhanced |
| `VS_V8_$A6F_Enhanced_v0.90.adx` | v0.90 | VS V8 Enhanced (latest) |

#### VT Platform
| File | Version | Notes |
|------|---------|-------|
| `16233396 VT V6 $A5.adx` | Stock | VT V6 |
| `A5 Engine and trans TP5 v102.adx` | v1.02 | VT base |
| `A5 Engine and trans TP5 v103.adx` | v1.03 | VT base |
| `A5 Engine and trans TP5 v105.adx` | v1.05 | VT base (latest) |
| `VT V6 And V8 - A5-A6 Engine and trans TP5 v104.adx` | v1.04 | Combined V6/V8 |
| `VT_$A6_v1.01.adx` | v1.01 | VT V8 |
| `VT_V6_$A5G_Enhanced_v1.0a.adx` | v1.0a | Enhanced |
| `VT_V6_$A5G_Enhanced_v1.0b.adx` | v1.0b | Enhanced (latest) |
| `VT_V6_SC_$A5G_Enhanced_v1.3d.adx` | v1.3d | Supercharged Enhanced |
| `VT_V8_$A6_v1.01.adx` | v1.01 | VT V8 |
| `VT_V8_$A6C_Enhanced_v0.80a.adx` | v0.80a | VT V8 Enhanced |
| `VT_V8_$A6E_Enhanced_v1.00.adx` | v1.00 | VT V8 Enhanced (latest) |

#### VX/VY/VU Platform
| File | Version | Notes |
|------|---------|-------|
| `VX Engine and trans TP5 V103.adx` | v1.03 | VX base |
| `VX Engine and trans TP5 V104.adx` | v1.04 | VX base (latest) |
| `VX Engine and trans TP5 V104 delcowizzid edition.adx` | v1.04 | Custom |
| `VX Engine and trans TP5 V104 yoda69 edition.adx` | v1.04 | Custom |
| `VX s-c Engine and trans TP5 v101.adx` | v1.01 | Supercharged |
| `VX_VY_VU Engine and trans TP5 V104.adx` | v1.04 | Combined |
| `VX_VY_VU Engine and trans TP5 V104 delcowizzid edition.adx` | v1.04 | Custom |
| `VX_VY_VU Engine and trans TP5 V104 yoda69 edition.adx` | v1.04 | Custom |
| `VX-VY_V6_$060A_Enhanced_v1.1.adx` | v1.1 | **TARGET - Enhanced (latest)** |
| `VX-VY_V6_SC_$07_Enhanced_v1.2E.adx` | v1.2E | Supercharged Enhanced |
| `VY_V6_$060A_Enhanced_v0.9c.adx` | v0.9c | Enhanced (older) |

---

## Wideband Scaling Reference

### 14.7 Kit (Generic 0-5V Wideband)
| Voltage | AFR |
|---------|-----|
| 0.0V | 10.0 |
| 2.5V | 14.7 (stoich) |
| 5.0V | 20.0 |

**Formula:** `AFR = (Voltage * 2) + 10`

### Innovate LC-1 / 4.9 (Simulated Narrowband Output)
| Voltage | AFR | Lambda |
|---------|-----|--------|
| 0.0V | 7.35 | 0.50 |
| 2.5V | 14.87 | 1.01 |
| 5.0V | 22.39 | 1.52 |

**Formula:** `AFR = (Voltage * 3.008) + 7.35`

### TechEdge Controllers
| Output Mode | Voltage Range | AFR Range |
|-------------|---------------|-----------|
| Linear 0-5V | 0-5V | 10-20 AFR |
| Lambda 0-5V | 0-5V | 0.5-1.5 Lambda |

---

## Standalone Wideband ADX Files - Detailed Reference

**Location:** `A:\repos\Wideband Oxygen Sensor Controllers\`

These are standalone serial wideband controller plugins that can be used alongside any ECU ADX file for simultaneous logging.

---

### Innovate LC-1 ADX (`Innovate LC-1.adx`)

**Author:** Roman Savchuk  
**Version:** 0.1b  
**Baud Rate:** 19200  

#### Serial Protocol
| Parameter | Value |
|-----------|-------|
| Header Bytes | `0xB2 0x82` |
| Packet Size | 4 bytes |
| Packet Timeout | 1000ms |

#### Available Channels
| Channel | ID | Range | Formula |
|---------|-----|-------|---------|
| **AFR** | `afr` | 7.35 - 22.50 | `((HI*128 + LO)*0.001 + 0.5) * 14.7` |
| **Lambda** | `lambda` | 0.50 - 8.50 | `(HI*128 + LO)*0.001 + 0.5` |
| **Mode 000** | `mode000` | Bitmask | "Normal Mode" vs "Ignore DA!" |
| **Mode 001** | `mode001` | Bitmask | "Lambda in free air" |

#### LC-1 Mode 000 Warning
> **CRITICAL:** Make sure Mode 000 says "Normal Mode" - otherwise values displayed are NOT actual AFR and Lambda values!

The Mode 000 status indicator shows:
- **Green "Normal Mode"** = Valid readings
- **Red "Ignore DA!"** = Invalid readings (sensor warming up, error, etc.)

#### Dashboards Included
- **LC-1 AFR** - Gauge + status indicators
- **LC-1 Lambda** - Gauge + status indicators

---

### TechEdge Wideband O2 Controllers ADX (`TechEdge Wideband O2 Controllers.adx`)

**Author:** Don Starr  
**Version:** 1.0.7  
**Baud Rate:** 19200  

#### Serial Protocol (2.0 Data Frame Format)
| Parameter | Value |
|-----------|-------|
| Header Bytes | `0x5A 0xA5` |
| Packet Size | 26 bytes |
| Packet Timeout | 200ms |

#### 2.0 Data Frame Structure
```
Byte  1: Frame Header byte 1 (0x5A)
Byte  2: Frame Header byte 2 (0xA5)
Byte  3: Frame Sequence counter
Byte  4-5: Tick [high/low] (1 tick = 1/100 Second)
Byte  6-7: L-16 or Ipx(0) [high/low] - Lambda 16-bit
Byte  8-9: Ipx(1) [high/low] (8192=F/A, 4096=Ipx[0])
Byte 10-11: User 1 ADC [high/low] (V1 input)
Byte 12-13: User 2 ADC [high/low] (V2 input)
Byte 14-15: User 3 ADC [high/low] (V3 input)
Byte 16-17: Thermocouple1 ADC [high/low] (T1 Input)
Byte 18-19: Thermocouple2 ADC [high/low] (T2 Input)
Byte 20-21: Thermocouple3 ADC [high/low] (T3 Input)
Byte 22+: Thermistor data...
```

#### Ipx(1) to Lambda Lookup Table (from TechEdge emulator)
| Ipx(1) Raw | Lambda |
|------------|--------|
| 0 | 0.637 |
| 1000 | 0.697 |
| 2000 | 0.770 |
| 3000 | 0.862 |
| 4000 | 0.990 |
| 4100 | 1.009 |
| 4200 | 1.033 |
| 4500 | 1.128 |
| 5000 | 1.333 |
| 6000 | 2.013 |
| 7000 | 3.831 |
| 8000 | 24.68 |

**Note:** The Ipx(1) to Lambda relationship is non-linear around stoichiometric (Lambda ~1.0 at Ipx ~4100).

#### Lambda 16-bit Lookup Table
| L-16 Raw | Lambda |
|----------|--------|
| 0 | 0.500 |
| 36864 | 5.000 |
| 65535 | ~229 (sensor max) |

#### Available Channels
| Channel | Description |
|---------|-------------|
| **Lambda 16** | 16-bit Lambda value |
| **Ipx(0)** | Pump current channel 0 |
| **Ipx(1)** | Pump current channel 1 |
| **User 1-3 ADC** | Auxiliary voltage inputs (V1, V2, V3) |
| **Thermocouple 1-3** | EGT inputs (T1, T2, T3) |
| **Heater PID Status** | Controller status flags |
| **Vs/Ip PID Status** | Sensor status flags |

#### View Lists Included
- **Main** - All channels with status
- **Raw Data** - Raw byte values for debugging

#### TechEdge Status Codes

**Heater Status (byte 26):**
| Value | Status |
|-------|--------|
| 0 | Heater Off |
| 1 | Sensing Heater |
| 2 | Cold Heater |
| 3 | **OK operational** ✅ |
| 4 | Cal Mode |

**Controller Status (byte 27):**
| Value | Status |
|-------|--------|
| 0 | Normal |
| 1 | VBatt High |
| 2 | VBatt Low |
| 3 | Short circuit heater |
| 4 | Open circuit heater |
| 5 | FET failure |

**PID Status:**
| Value | Status |
|-------|--------|
| 0 | Normal |
| 32 | Low accum limit |
| 64 | High accum limit |
| 96 | Low Out limit |
| 128 | High Out limit |

#### TechEdge User Inputs (V1, V2, V3)

The TechEdge has 3 auxiliary 0-5V inputs for additional sensors:

| Input | Packet Offset | Formula | Example Use |
|-------|---------------|---------|-------------|
| User 1 | 0x07 | `x * 5 / 8184` (Volts) | MAP sensor (0-200 kPa) |
| User 2 | 0x09 | `x * 5 / 8184` (Volts) | Fuel pressure |
| User 3 | 0x0B | `x * 5 / 8184` (Volts) | Oil pressure |

**MAP Sensor Formula:** `x * 200 / 8184` (gives kPa directly for GM 2-bar sensor)

#### TechEdge Thermocouple Inputs (T1, T2, T3)

Type K thermocouple inputs for EGT monitoring:

| Input | Packet Offset | Range | Cold Junction Compensated |
|-------|---------------|-------|---------------------------|
| TC 1 | 0x0D | -50°C to 1217°C | Yes |
| TC 2 | 0x0F | -50°C to 1217°C | Yes |
| TC 3 | 0x11 | -50°C to 1217°C | Yes |

**EGT Formula:** `(((x/1024)*5.00)/101*1000) + CJC_mV` → lookup Type K table

The TechEdge includes full cold junction compensation using an onboard thermistor. EGT readings are accurate without external compensation.

---

## Innovate LC-1 Serial Protocol Deep Dive

### Packet Structure
```
Byte 0: Header High (0xB2)
Byte 1: Header Low (0x82)
Byte 2: AFR High Byte
Byte 3: AFR Low Byte
```

### Lambda/AFR Calculation

The LC-1 transmits Lambda as a 13-bit value split across two bytes:

```
Lambda = (HI_byte * 128 + LO_byte) * 0.001 + 0.5
AFR = Lambda * 14.7
```

**Decoding Example:**
- If HI = 0x03, LO = 0xE8 (1000 decimal combined)
- Lambda = (3 * 128 + 232) * 0.001 + 0.5 = 616 * 0.001 + 0.5 = 1.116
- AFR = 1.116 * 14.7 = 16.4 AFR (lean)

### LC-1 Mode Bits (Byte 0, bits 2-4)

| Bits 4:2 | Mode | Meaning |
|----------|------|---------|
| 000 | Normal Mode | ✅ Valid AFR readings |
| 001 | Lambda in free air | Sensor calibrating |
| 010 | Warmup | Heater warming sensor |
| 011 | Error | Sensor fault |

**CRITICAL:** Only trust AFR readings when Mode 000 shows "Normal Mode"!

---

## TechEdge Lambda-16 Calculation

The TechEdge uses a dual-slope Lambda-16 encoding:

```c
if (L16 < 36864) {
    Lambda = (L16 / 8192) + 0.5;    // Rich to stoich range
} else {
    Lambda = 5.0 + ((L16 - 36864) / 128);  // Lean range
}

AFR = Lambda * AFRstoich;  // AFRstoich = 14.7 for gasoline
```

**Key L16 Values:**
| L16 Raw | Lambda | AFR | Condition |
|---------|--------|-----|-----------|
| 0 | 0.50 | 7.35 | Very Rich |
| 4096 | 1.00 | 14.7 | Stoichiometric |
| 8192 | 1.50 | 22.05 | Lean |
| 36864 | 5.00 | 73.5 | Very Lean |

### Ipx (Normalized Pump Current)

| Ipx Value | Meaning |
|-----------|---------|
| 0 | Richest (AFR < 10) |
| 4096 | Zero pump current (near stoich) |
| 8192 | Free air (sensor calibration) |

---

## Using Standalone Wideband ADX with ECU ADX

TunerPro RT supports **multiple ADX files simultaneously**. To log ECU data + Wideband:

1. Open your ECU ADX (e.g., `VX-VY_V6_$060A_Enhanced_v1.1.adx`)
2. Connect to ECU via ALDL cable
3. Open the wideband ADX (e.g., `Innovate LC-1.adx`) 
4. Connect to wideband controller via USB-Serial adapter
5. Both datastreams log simultaneously with synchronized timestamps

**Requirements:**
- Two serial ports (one for ECU, one for wideband)
- USB-Serial adapter for wideband (most use FTDI chipset)
- Wideband controller in "Normal Mode" (LC-1) or active state (TechEdge)

---

## Files to Create

Based on the existing wideband examples, we need to create:

### VX/VY V6 Enhanced Wideband Variants
| New File | Base File | Wideband Type |
|----------|-----------|---------------|
| `VX-VY_V6_$060A_Enhanced_v1.1_wideband.adx` | `VX-VY_V6_$060A_Enhanced_v1.1.adx` | Generic |
| `VX-VY_V6_$060A_Enhanced_v1.1_14.7kit.adx` | `VX-VY_V6_$060A_Enhanced_v1.1.adx` | 14.7 Kit |
| `VX-VY_V6_$060A_Enhanced_v1.1_innovate.adx` | `VX-VY_V6_$060A_Enhanced_v1.1.adx` | Innovate LC-1 |

---

## PCMHacking Forum Wideband Topics Reference

These are key forum topics from PCMHacking.net related to wideband setup:

### Core Wideband Setup Topics

| Topic | Title | Key Info |
|-------|-------|----------|
| **t=3583** | Setting up Wideband Datalogging Input Video | The1's video tutorial for ADX wideband setup |
| **t=5884** | Wideband Setup VT L67 | Spartan 2 with Enhanced code, uses pin A5 or B10 |
| **t=698** | Wideband input pin on 808 ecu? | Pin D8 for 808 ECU with OSE 12P/NVRAM |
| **t=4251** | Wideband pin input | VT V8 uses B12 (inj volt), A5 has better resolution (255 steps vs 55) |
| **t=7083** | VY flash pcm wideband install | VY flash PCM uses injector monitor pin or EGR input |

### Wideband Controller Topics

| Topic | Title | Controller |
|-------|-------|------------|
| **t=1418** | LC1 Wideband | Innovate LC-1 setup |
| **t=3585** | innovate lc-2 integrated to 808 12p? | LC-2 integration |
| **t=2864** | Innovate LM2 Wideband Info | LM2 setup |
| **t=4962** | Wideband Controller from www.14point7.com | 14point7 controllers |
| **t=3289** | 14Point7 Spartan Wide Band Kit | Spartan wideband |
| **t=8736** | Spartan 3 lite v2 install | Spartan 3 installation |

### Wideband Calibration & Formulas

| Topic | Title | Key Info |
|-------|-------|----------|
| **t=4656** | Wideband calibration for 12P and 11P | 0V and 5V scalers, pull-up resistor |
| **t=4240** | Calculate Analog Offsets for a Wideband | Calculating ADC offsets |
| **t=4288** | Wideband calculation | Formula calculations |
| **t=5046** | Wideband Converter Spreadsheet | Conversion spreadsheet |
| **t=3646** | Getting wideband logged data calc right | Correcting logged data |

### VX/VY Specific Wideband Topics

| Topic | Title | Notes |
|-------|-------|-------|
| **t=2752** | Vy v6 wideband log doesn't look right | Troubleshooting VY WB |
| **t=2280** | VX-VY ADX with fuel trims | VX/VY ADX modifications |
| **t=4142** | 30HZ logging for VX_VY flash PCMs | High-speed logging |
| **t=2483** | REALTIME VX-VY n_a PCM | VX/VY realtime tuning |

### Wideband Placement & Wiring

| Topic | Title | Key Info |
|-------|-------|----------|
| **t=744** | Wideband O2 sensor placement | Optimal exhaust location |
| **t=4624** | Wideband Placement | Mounting position |
| **t=2907** | Wiring temporary Wideband O2 sensor | Temporary installation |
| **t=2955** | wiring in wideband and setting it up | Complete wiring guide |
| **t=4854** | wiring in the mtx-l to nvram 808 | MTX-L to 808 ECU |

### Wideband Input Pin Summary (from forum)

| ECU Type | Primary WB Pin | Alternate Pins | Resolution |
|----------|----------------|----------------|------------|
| **808 ECU (VR/VN)** | D8 | - | 256 steps (8-bit) |
| **VT V6/V8 PCM** | B12 (Inj Volt) | A5, B10 | B12=55 steps, A5=255 steps |
| **VX/VY Flash PCM** | Injector Monitor | EGR input | Limited resolution |
| **Enhanced Memcal** | A5 | B10 | 256 steps (8-bit) |

### Key Wideband Formulas from Forum

**14point7 Spartan (0V=10 AFR, 5V=20 AFR):**
```
AFR = ((20.00-10.00)/255*x)+10.00
```
Where `x` = A/D reading from pin (0-255)

**OSE 11P/12P Wideband Scalers:**
- Set "0V AFR" and "5V AFR" scalars in bin to match wideband output range
- Formula handled internally: `AFR = x/10`

---

## Exact ADX XML Differences for Wideband

Based on comparing the actual ADX files, here are the exact XML blocks needed to add wideband support:

### ADXVALUE Block for Wideband Channel

The core change is adding a new `ADXVALUE` element for the wideband channel.

#### Innovate LC-1/4.9 Wideband (7.35-22.39 AFR range):

```xml
<ADXVALUE id="16" idhash="0xDE6A8D70" title="Wideband o2">
    <flags>0x0000000C</flags>
    <parentcmdidhash>0xB8CF04CA</parentcmdidhash>
    <units>Wideband B12 (inj feedback line)</units>
    <packetoffset>0x14</packetoffset>
    <range low="10.000000" high="17.930000" />
    <alarms low="10.000000" high="17.930000" />
    <digcount>2</digcount>
    <outputtype>3</outputtype>
    <datatype>61</datatype>
    <unittype>32</unittype>
    <MATH equation="(((22.39-7.35)/51)*x)+7.35">
      <VAR varID="x" type="native" />
    </MATH>
</ADXVALUE>
```

**Formula Breakdown:**
- `(22.39 - 7.35) / 51 = 0.2949` (AFR per A/D step)
- 51 steps = 0-5V range for B12 injector voltage input (limited resolution)
- 7.35 = offset (0V = 7.35 AFR)
- Result: 0V = 7.35 AFR, 5V = 22.39 AFR

#### 14.7 Kit Wideband (10-20 AFR range):

```xml
<ADXVALUE id="16" idhash="0xDE6A8D70" title="Wideband o2">
    <flags>0x0000000C</flags>
    <parentcmdidhash>0xB8CF04CA</parentcmdidhash>
    <units>Wideband B12 (inj feedback line)</units>
    <packetoffset>0x14</packetoffset>
    <range low="10.000000" high="20.000000" />
    <alarms low="10.000000" high="20.000000" />
    <digcount>2</digcount>
    <outputtype>3</outputtype>
    <datatype>61</datatype>
    <unittype>32</unittype>
    <MATH equation="((20.12-10.06)/48*x)+10.06">
      <VAR varID="x" type="native" />
    </MATH>
</ADXVALUE>
```

**Formula Breakdown:**
- `(20.12 - 10.06) / 48 = 0.2096` (AFR per A/D step)
- 48 steps = usable range for B12 input
- 10.06 = offset (0V = 10.06 AFR)
- Result: 0V = 10 AFR, 5V = 20 AFR

#### Generic Wideband (for pin A5 with 255 steps):

```xml
<ADXVALUE id="16" idhash="0xDE6A8D70" title="Wideband">
    <flags>0x0000000C</flags>
    <parentcmdidhash>0xB8CF04CA</parentcmdidhash>
    <units>WB AFR</units>
    <packetoffset>0x14</packetoffset>
    <range low="11.500000" high="17.500000" />
    <alarms low="10.000000" high="15.000000" />
    <digcount>1</digcount>
    <outputtype>3</outputtype>
    <datatype>30</datatype>
    <unittype>21</unittype>
    <MATH equation="(((22.39-7.35)/51)*x)+7.35">
        <VAR varID="x" type="native" />
    </MATH>
</ADXVALUE>
```

### Optional: ADXHISTOGRAM Blocks for VE Tuning

These histogram blocks allow logging AFR vs RPM/Load for VE table corrections:

```xml
<ADXHISTOGRAM id="WBlog" idhash="0x1A678FB4" title="Wideband Logs">
    <parentcmdidhash>0xB8CF04CA</parentcmdidhash>
    <rows>31</rows>
    <cols>19</cols>
    <xmin>0.000000</xmin>
    <xmax>0.000000</xmax>
    <ymin>0.000000</ymin>
    <ymax>0.000000</ymax>
    <!-- RPM row values (400, 600, 800... 6400) -->
    <rowval index="0" val="400.000000" />
    <!-- ... more rows ... -->
    <rowval index="30" val="6400.000000" />
    <!-- Load column values (kPa or g/s) -->
    <colval index="0" val="62.500000" />
    <!-- ... more columns ... -->
    <colval index="18" val="625.000000" />
    <historysize>10</historysize>
    <xidhash>0xDE69CE70</xidhash>  <!-- Reference to Load/MAP channel -->
    <yidhash>0x86F3549B</yidhash>  <!-- Reference to RPM channel -->
    <zidhash>0xDE6A8D70</zidhash>  <!-- Reference to Wideband channel -->
</ADXHISTOGRAM>
```

### Key ADX Parameters Explained

| Parameter | Purpose | Common Values |
|-----------|---------|---------------|
| `id` | Unique identifier for the channel | "16", "WB", "AFR" |
| `idhash` | Hash for referencing (must be unique) | 0xDE6A8D70 |
| `parentcmdidhash` | Links to monitor command | 0xB8CF04CA (Mode 1) |
| `packetoffset` | Byte position in datastream | 0x14 (offset 20) |
| `flags` | Display/logging options | 0x0000000C |
| `datatype` | Internal data classification | 30, 61 |
| `unittype` | Units classification | 21, 32 (AFR types) |

### Input Pin to Packet Offset Mapping

| ECU Type | Pin | Packet Offset | Resolution |
|----------|-----|---------------|------------|
| VS $51 | B12 (Inj Volt) | 0x14 | 51 steps |
| VT $A5 | B12 (Inj Volt) | 0x14 | 51 steps |
| VT $A5 | A5 | Varies | 255 steps |
| VX/VY Flash | Inj Monitor | Varies | 55 steps |
| VX/VY Flash | EGR Input | Varies | Limited |
| Enhanced | A5 | Custom | 255 steps |

---

## Next Steps

1. ~~Compare `Vs V6 engine and trans 1.07-tp5.adx` vs `Vs V6 engine and trans 1.07-tp5-wideband.adx` to extract the XML blocks added for wideband~~ ✅ **DONE**
2. ~~Identify which analog input pin is used (typically unused A/D channel)~~ ✅ **DONE** - Pin B12 (Injector Voltage) at offset 0x14
3. Create the three wideband variants for Enhanced v1.1
4. Test with TunerPro to verify channels appear correctly
