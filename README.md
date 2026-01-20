# VY L36 $060A Enhanced Binary - Assembly Patches (WIP)

[![Platform: 68HC11](https://img.shields.io/badge/Platform-68HC11-blue.svg)](https://en.wikipedia.org/wiki/Motorola_68HC11)
[![Target: VY V6 ECU](https://img.shields.io/badge/Target-Holden%20VY%20V6-green.svg)](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches)
[![Status: Research/WIP](https://img.shields.io/badge/Status-WIP-yellow.svg)](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches)

> **Holden VY V6 Ecotec L36 (3.8L) - Assembly Patches for Delco $060A 92118883 ECU**
>
> Research-based 68HC11 assembly patches based on Chr0m3 Motorsport and The1's Enhanced OS.

⚠️ **ALL CODE IS UNTESTED - RESEARCH ONLY** ⚠️

No patched binaries included. These are reference implementations requiring manual binary patching and oscilloscope verification before real-world use.

> **Reality Check:** Most patches will likely work if applied correctly. However, use at your own risk. If you don't understand what connects to what in the binary, how one routine calls another, how RAM variables are shared between ISRs, or how timing-critical code interacts — you can brick your ECU or damage your engine. The HC11 has no safety net.
need to map out every thing to the bone in the binary itself and correct any mistakes i make along the way. im only human after all.
---

## 🚨 CRITICAL PLATFORM CLARIFICATION

**This section addresses common misunderstandings about OSE 11P/12P and VY V6 architecture.**

### OSE 11P / 12P — What They Are and Aren't

| Aspect | OSE 11P / 12P | VY V6 ($060A) |
|--------|---------------|---------------|
| **Target Hardware** | VN/VP/VR/VS MEMCAL ECUs (Delco 808/424) | VT-VZ Flash PCMs |
| **Fuel System** | **Speed-Density ONLY** (MAP-based, no MAF) | **MAF-based** (Mass Airflow) |
| **Binary Size** | 32KB (12P) / 64KB (11P) | 128KB |
| **EPROM Chip** | 28-pin (VN-VR) or 32-pin (VS) EPROM/EEPROM | Internal Flash |
| **Real-time Tuning** | Moates Ostrich 2.0, AutoProm, or NVRAM board | TunerPro RT (OSE Flash Tool / Moates plugin) |

### ✅ VY/VX/VT CAN Run OSE 12P — With ECU Swap

**VY V6 (and VX, VT, VS) CAN run OSE 12P** — but NOT by patching the stock VY ECU. You must:

1. **Swap to a Delco 808 ECU** (VR/VS Manual or Buick 808)
2. **Rewire the harness** to match 808 pinout (see PCMHacking Topic 102, 356)
3. **Install OSE 12P firmware** on the 808 ECU
4. **Add MAP sensor** (MAF-based cars don't have one stock)

> **Key Point:** MAF-based ECUs (VT-VZ) **cannot run OSE 12P directly** — the code doesn't exist in those ECUs. You need a complete ECU swap to older MEMCAL hardware. The MAF-based ECUs can't go backwards.

### Hardware Details

**For complete MEMCAL hardware reference (chips, adapters, NVRAM, ALDL speeds), see:**

📄 [`VS_VT_VY_COMPARISON_DETAILED.md`](VS_VT_VY_COMPARISON_DETAILED.md#-memcal-hardware--chip-reference)

**Quick Reference:**
- **28-pin MEMCAL** (VN/VP/VR/VS V8): Use **G2 Adapter** + SST27SF512 or AT29C256
- **32-pin MEMCAL** (VS S3/VT): Use **G6 Adapter** + W27E010, W27E040, or AM29F040B
- **Real-time tuning (MEMCAL):** Moates Ostrich 2.0, AutoProm, or NVRAM board (PCMHacking DIY)
- **Real-time tuning (Flash PCM):** TunerPro RT with Moates plugin or OSE Flash Tool plugin
- **Bin stacking:** 512KB chips hold 4× 128KB tunes (done in TunerPro)

### How This Repo Uses 11P/12P Research

We study OSE 11P/12P **concepts** (spark cut via dwell, timer control) and **port the techniques** to VY V6:

- **11P dwell spark cut method** → Ported to `spark_cut_chr0m3_method_VERIFIED_v38.asm`
- **12P TCTL1 timer control** → Research in `NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm`
- **VE table structure** → Inspiration for `speed_density_ve_table.asm`

**The MAFless research document covers the PCM swap option** (swapping VY to a VR/VS 808 ECU + OSE 12P) as a complete conversion path with wiring diagrams.

---

## 📁 Repository Structure

```text
asm_wip/
├── spark_cut/                      # 🔥 Ignition cut limiters (Chr0m3 method)
│   ├── spark_cut_chr0m3_method_VERIFIED_v38.asm  # ⭐⭐ BEST - Chr0m3 verified method
│   ├── spark_cut_3x_period_VERIFIED.asm    # ⭐ VERIFIED - 16-bit test template
│   ├── PATCH_BYTES_v38.asm                 # Raw hex bytes for v38 patch
│   ├── spark_cut_3000rpm_TEST_v38t.asm     # Low RPM test version
│   ├── spark_cut_the1_method_port_v39.asm  # 🔬 The1's CPD comparison port (research)
│   ├── spark_cut_bmw_inspired_v40.asm      # 🔬 BMW MS42/MS43 table-driven (concept)
│   ├── spark_cut_delco_optimized_v41.asm   # 🔬 Multi-method systematic test (experimental)
│   ├── spark_cut_6000rpm_v32.asm           # Hard cut at 6000 RPM
│   ├── spark_cut_chrome_method_v33.asm     # Chr0m3 method (fuel cut scrapped)
│   ├── spark_cut_progressive_soft_v9.asm   # Gradual soft limiter
│   ├── spark_cut_rolling_v34.asm           # Speeduino-style rolling cut
│   ├── spark_cut_soft_timing_v36.asm       # Soft timing retard style
│   ├── spark_cut_combined_fuel_v35.asm     # Fuel+Spark clean cut
│   ├── spark_cut_dwell_patch_v37.asm       # Dwell patch for high RPM
│   ├── spark_cut_two_stage_hysteresis_v23.asm  # Two-stage with hysteresis (VL style)
│   ├── spark_cut_6375_safe_mode_v18.asm    # 6375 RPM max enforcer
│   └── spark_cut_original.asm              # Original 3X period method
│
├── fuel_systems/                   # ⛽ MAFless, Speed Density, E85
│   ├── mafless_alpha_n_v1.asm              # Force MAF failure mode v1
│   ├── mafless_alpha_n_v2.asm              # Force MAF failure mode v2
│   ├── mafless_alpha_n_v3.asm              # Minimal ROM footprint v3
│   ├── mafless_tpi_method.asm              # Gearhead_EFI TPI method port
│   ├── alpha_n_tps_fallback.asm            # TPS fallback mode
│   ├── speed_density_fallback_v1.asm       # SD fallback conversion
│   ├── speed_density_ve_table.asm          # Full VE table implementation
│   ├── e85_dual_map_toggle.asm             # Manual E85/Petrol toggle
│   └── fuel_cut_enhanced.asm               # Stock fuel cut enhanced
│
├── turbo_boost/                    # 🚀 Boost control & forced induction
│   ├── boost_controller_pid.asm            # PID closed-loop wastegate
│   ├── overboost_protection.asm            # Safety fuel cut on overboost
│   ├── antilag_turbo.asm                   # Anti-lag (turbo only)
│   ├── antilag_rolling.asm                 # Rolling anti-lag partial cut
│   ├── antilag_cruise_button.asm           # Anti-lag via cruise button
│   ├── hybrid_fuel_spark_limiter.asm       # Fuel + spark combined cut
│   └── turbo_limiter_v1.asm                # Cylinder selective wastespark
│
├── shift_control/                  # 🏁 Launch control & shift features
│   ├── launch_control_two_step.asm         # Two-step launch limiter
│   ├── flat_shift_no_lift.asm              # Flat shift / no-lift
│   ├── no_lift_shift.asm                   # MS43X dynamic RPM cap port
│   ├── shift_bang_auto.asm                 # Firm shift (auto trans)
│   ├── shift_bang_manual.asm               # Flat foot shift (manual)
│   ├── shift_retard.asm                    # Spark retard on shift
│   ├── shift_launch_v1.asm                 # "AK47" rapid cycle pattern
│   └── timing_retard_soft.asm              # Soft timing retard limiter
│
├── ghost_cam_NEEDS_RESEARCH/       # 👻 Lopey idle effect
│   │   # NOTE: XDF TUNING PREFERRED - See ASM vs XDF table below
│   │   # VY V6 has no VVT - uses spark modulation not valve overlap
│   ├── ghost_cam_rpm_delta_spark_v1.asm    # RPM delta spark concept
│   └── ghost_cam_xdf_parameter_patch_v2.asm # XDF parameters reference
│
├── cold_maps_only_for_tuning_patch/# ❄️ Alpina/OEM tuning method
│   │   # NOTE: XDF TUNING PREFERRED - Disables STFT/LTFT for OL tuning
│   └── cold_maps_tuning_alpina_method_v1.asm # Cold maps only strategy
│
├── needs_validation/               # 🔬 Untested hardware timer methods
│   ├── NEEDS_VALIDATION_methodC_output_compare.asm  # OC direct manipulation
│   ├── NEEDS_VALIDATION_v14_hardware_timer_control.asm
│   ├── NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm
│   ├── NEEDS_VALIDATION_v17_oc1d_forced_output.asm
│   └── NEEDS_VALIDATION_v19_pulse_accumulator_isr.asm
│
├── needs_more_work/                # 🚧 Incomplete patches
│   └── NEEDS_WORK_hardware_est_disable_v13.asm  # BennVenn EST disable
│
├── old_versions/                   # 📜 Superseded (history only)
│   ├── spark_cut_methodv2.asm              # OC force-low method
│   ├── spark_cut_methodv3.asm              # v3 iteration
│   ├── spark_cut_methodv4.asm              # Coil saturation prevention
│   └── spark_cut_original.asm              # Original concept
│
└── rejected/                       # ❌ Methods proven not to work
    └── REJECTED_methodB_dwell_override.asm  # Dwell override (failed)

68HC11_Reference/
├── kingai_68hc11_resources/  # Complete HC11 instruction reference
│   ├── 68HC11_COMPLETE_INSTRUCTION_REFERENCE.md
│   ├── 68HC11_Opcodes_Reference.md
│   ├── 68HC11_Mnemonics_Reference.md
│   └── README.md             # Reference collection index
├── A09_Assembler/            # HC11 assembler
├── dis68hc11/                # Disassembler
├── ghidra_hc11/              # Ghidra SLEIGH files
└── M68HC11RM_Reference_Manual.pdf

docs/
├── FULL_TECHNICAL_REFERENCE.md   # Complete technical deep-dive (9000+ lines)
└── ...

xdfs_and_adx_and_bins_related_to_project/
└── VX VY_V6_$060A_Enhanced_v2.09a.xdf   # Current XDF definition
```

---

## 🔧 ASM vs XDF Tuning Guide

**Not everything needs assembly patches!** The Enhanced v2.09a XDF exposes many parameters.

| Feature | Method | Notes |
|---------|--------|-------|
| **Spark Cut Limiter** | ⚙️ ASM Required | Not in XDF - needs code injection |
| **Ghost Cam / Lopey Idle** | 📊 XDF Preferred | Idle Spark Correction tables, RPM Error Limit (get a real cam they say) |
| **Cold Maps Tuning** | 📊 XDF Preferred | Cold Spark Multiplier, STFT/LTFT temps |
| **MAFless / Alpha-N** | ⚙️ ASM Required | Force TPS-based load calculation |
| **Speed Density** | ⚙️ ASM Required | VE table + MAP-based fueling |
| **Launch Control** | ⚙️ ASM Required | Two-step limiter with input trigger |
| **Antilag** | ⚙️ ASM Required | Retard + fuel enrichment timing |
| **Flat Shift** | ⚙️ ASM Required | Clutch/gear input handling |
| **Boost Control** | ⚙️ ASM Required | PID controller for wastegate |
| **Rev Limiter (Fuel)** | 📊 XDF Available | Standard fuel cut tables exist |
| **Idle RPM Target** | 📊 XDF Available | P/N and Drive idle tables |
| **Timing Maps** | 📊 XDF Available | Main spark tables |

> **VY V6 has no VVT/VANOS** - Ghost cam is achieved via aggressive idle spark correction, not valve overlap like BMW MS42/MS43.

---

## 🎯 Primary Focus: Spark Cut Limiter

### Binary Versions

| Binary | XDF | Spark Cut? | Status |
|--------|-----|------------|--------|
| **Enhanced v1.0a** | v2.09a | ❌ NO | This repo's target |
| **Enhanced v1.1a** | v2.04c | ✅ YES | The1's implementation (Topic 8852) |

> **Note:** Enhanced v1.1a (v2.04c package, Topic 8852) includes The1's spark cut implementation. We are currently reverse-engineering that code to understand exactly what changed from v1.0a → v1.1a before documenting it publicly. Our v38 ASM patches are independent work based on Chr0m3's 3X period method.

Primary implementation based on **3X Period Injection** (Chr0m3 validated method):

| Step | Description |
|------|-------------|
| 1 | Hook at file offset `0x101E1` (replaces `STD $017B`) |
| 2 | `JSR $C500` calls our patch in free space |
| 3 | Check RPM against threshold (e.g., 6000 RPM = `$1770`) |
| 4 | If over limit: inject fake period `$3E80` (16000) → starves dwell |
| 5 | Result: Classic "pops and bangs" exhaust sound |

**Start here:** [`asm_wip/spark_cut/spark_cut_3x_period_VERIFIED.asm`](asm_wip/spark_cut/spark_cut_3x_period_VERIFIED.asm)

### Key Verified Addresses

| Address | Type | Purpose |
|---------|------|---------|
| `$00A2` | RAM | Engine RPM (×25 scaling, 8-bit) |
| `$017B` | RAM | 3X period storage |
| `$0199` | RAM | Dwell time storage |
| `$101E1` | ROM | Hook point (STD $017B) - **v38 method** |
| `$0C468-$0FFBF` | ROM | 15,192 bytes free space |

**v1.1a (v2.04c) Additional Addresses** *(under investigation)*:

| Address | Type | Purpose | Status |
|---------|------|---------|--------|
| `$78B2` | ROM | Spark RPM Cut threshold (XDF tunable) | 🔬 Researching |
| `$1FD84` | ROM | The1's spark cut code location | 🔬 Researching |
| `$056F4` | ROM | The1's hook point | 🔬 Researching |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [`RAM_Variables_Validated.md`](RAM_Variables_Validated.md) | Verified RAM variable mapping with cross-references |
| [`TIC3_ISR_ANALYSIS.md`](TIC3_ISR_ANALYSIS.md) | TIC3 ISR disassembly - spark cut injection point |
| [`MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md`](MAFLESS_SPEED_DENSITY_COMPLETE_RESEARCH.md) | MAFless and Speed Density implementation research |
| [`VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md`](VL_V8_WALKINSHAW_TWO_STAGE_LIMITER_ANALYSIS.md) | VL V8 two-stage hysteresis limiter analysis |
| [`VS_VT_VY_COMPARISON_DETAILED.md`](VS_VT_VY_COMPARISON_DETAILED.md) | VS/VT/VY platform differences and porting guide |
| [`68HC11_Reference/kingai_68hc11_resources/`](68HC11_Reference/kingai_68hc11_resources/) | Complete HC11 instruction set reference collection |

---

## 🔬 Verified Sources

All claims verified against PCMHacking.net archive:

| Source | Topic | Key Finding |
|--------|-------|-------------|
| **Chr0m3** | [Topic 8567](https://pcmhacking.net/forums/viewtopic.php?t=8567) | 3X period injection method, dwell starving |
| **The1** | [Topic 2518](https://pcmhacking.net/forums/viewtopic.php?t=2518) | Enhanced OS bins, CPD comparison method, XDF definitions |
| **BennVenn** | [Topic 7922](https://pcmhacking.net/forums/viewtopic.php?t=7922) | OSE12P timer bit `$3FFC` discovery |
| **Rhysk94** | [Topic 8756](https://pcmhacking.net/forums/viewtopic.php?t=8756) | 6,375 RPM max (255 × 25 = 6375) |

### The1's Spark Cut Method (Enhanced v1.1a)

**Discovered:** January 19, 2026 via disassembly  
**Location:** File offset 0x1FD84-0x1FD9F  
**Method:** CPD (Compare D) with EST flag manipulation

Key differences from Chr0m3's method:
- Uses **CPD** (non-destructive compare) vs SUBD
- Reads **16-bit RPM** from $9D (not 8-bit $A2)
- Compares against **table** at $78B2 (not immediate value)
- Manipulates **EST control flags** at $149E and $16FA
- Calls EST subroutine at $31EF

**Status:** Addresses need mapping to $060A STOCK 99218883, 1,0 then 1,1a to fully understand.
**Please** edit if you know and push corrections please.
**See:** `spark_cut_the1_method_port_v39.asm` for research notes

### Hardware Limits

| Limit | Value | Source |
|-------|-------|--------|
| Max RPM (8-bit) | 6,375 RPM | Chr0m3 Topic 8567 |
| Spark loss point | ~6,500 RPM | Chr0m3 dwell research |
| Safe patched limit | 6,000-6,350 RPM | Community testing |

---

## 🛠️ Requirements

- **Binary:** `VX-VY_V6_$060A_Enhanced_v1.0a.bin` (128KB)
- **XDF:** `VX VY_V6_$060A_Enhanced_v2.09a.xdf`
- **Assembler:** A09 or similar HC11 assembler
- **Hex Editor:** HxD, 010 Editor, or similar
- **Verification:** Oscilloscope recommended for EST/dwell testing

---

## ✅ Binary Verification

**How do you know you have the right binary?**

### Quick Verification Checklist

| Check | Expected Value | How to Verify |
|-------|----------------|---------------|
| **File Size** | 131,072 bytes (128KB exactly) | File properties |
| **OSID** | `92118883` | Bytes at offset `$1FFC0-$1FFC7` |
| **Broadcast Code** | `$060A` | TunerPro or hex editor |
| **Hook Point** | `FD 01 7B` at `$101E1` | Hex editor search |
| **Free Space** | All `$00` from `$0C468-$0FFBF` | Hex editor verify |

### Hex Verification Commands

```python
# Quick Python verification script
from pathlib import Path
import hashlib

binary = Path('VX-VY_V6_$060A_Enhanced_v1.0a.bin').read_bytes()

# Size check
assert len(binary) == 131072, f"Wrong size: {len(binary)}"

# Hook point check (STD $017B at file offset 0x101E1)
assert binary[0x101E1:0x101E4] == bytes([0xFD, 0x01, 0x7B]), "Hook point mismatch!"

# Free space check (should be zeros)
free_space = binary[0x0C468:0x0FFBF]
assert all(b == 0 for b in free_space), "Free space not empty!"

print("✅ Binary verified - correct Enhanced v1.0a")
```

### Known Binary Hashes

| Version | MD5 | SHA256 (first 16 chars) |
|---------|-----|-------------------------|
| Enhanced v1.0a | *Calculate yours* | *Calculate yours* |
| Stock 92118883 | *Different* | *Different* |

> **Note:** If your hook point at `$101E1` doesn't show `FD 01 7B`, you have a different binary version and all patch offsets will be wrong.

### Common Binary Confusion

| Binary | Size | Notes |
|--------|------|-------|
| **Enhanced v1.0a** | 128KB | ✅ What this repo targets |
| **Stock 92118883** | 128KB | ❌ Different internal layout |
| **Enhanced v2.x** | 128KB | ⚠️ May have different offsets |
| **Other OSID** | Varies | ❌ Completely different ECU |

---

## ❓ FAQ

### General Questions

**Q: Will this work on my VY Commodore?**
> Only if you have the **$060A OSID 92118883** ECU with Enhanced v1.0a binary loaded. Check your OSID with a scan tool first.

**Q: Can I just flash the patched binary directly?**
> No patched binaries are provided. You need to apply patches manually using a hex editor. This is intentional - you need to understand what you're changing.

**Q: Why 68HC11 assembly? Why not just tune in TunerPro?**
> Some features (spark cut limiter, MAFless, launch control) are not exposed in XDF tables. They require modifying the actual ECU code.

**Q: Is this legal?**
> For off-road/race use only. Modifying emissions controls may violate laws in your jurisdiction. Check local regulations.

### Technical Questions

**Q: Why can't I just set fuel cut to 9999 RPM?**
> The stock fuel cut uses 8-bit RPM storage: `255 × 25 = 6375 RPM max`. You physically cannot exceed this without code modification.
> You will lose the limiter at any value above 6374 RPM.
**Q: What's the difference between fuel cut and spark cut?**
> - **Fuel cut:** Stops injectors → engine dies smoothly, no sound
> - **Spark cut:** Stops ignition → unburnt fuel ignites in exhaust → pops and bangs

**Q: Why does Chr0m3 say to inject a fake period instead of zeroing dwell?**
> Zeroing dwell directly triggers the ECU's "bypass mode" which hands ignition timing to the distributor module. The period injection method tricks the dwell calculation into returning insufficient time without triggering bypass.

**Q: What's $0046 and why do you keep mentioning it?**
> `$0046` is a RAM flag byte used throughout the ECU code. Static binary analysis found 20 BSET/BCLR/BRSET/BRCLR operations referencing it. Bits 0, 1, 2, 4, 5 are actively used by stock code. **Bits 3, 6, 7 appear free** and safe for custom patch flags (e.g., limiter state tracking). See [RAM Validation Methodology](#-ram-validation-methodology) below.

**Q: Can AI really decompile ECU binaries?**
> AI can disassemble known opcodes and identify patterns, but it cannot:
> - Name functions semantically without context
> - Verify correctness without hardware testing
> - Handle unknown processor variants
> 
> I use AI to accelerate research, then verify everything against the actual binary. i use it when im lazy and push to github and it replys i deleted your files what would you like me to do now.

### Hardware Questions

**Q: What hardware do I need to flash this?**
> - **Moates Ostrich 2.0** - Real-time emulator for MEMCAL ECUs (28/32-pin)
> - **Moates AutoProm** - Alternative real-time emulator
> - **NVRAM board** - DIY option from PCMHacking (Dallas DS1245Y)
> - **TunerPro RT** - With OSE Flash Tool plugin or Moates plugin for flash PCMs
> - **Moates FlashnBurn** - Direct flash programming software
> - **DIY ALDL cable** - For reading/communication
> - **Oscilloscope** - For verifying EST/dwell timing

**Q: Can I brick my ECU?**
> Yes. If you corrupt the reset vector or critical ISR code, the ECU won't boot. Always keep a known-good backup and test on bench first.

**Q: Why do you recommend oscilloscope testing?**
> Spark timing is safety-critical. A coding error could cause:
> - Coil saturation (burn out ignition module)
> - Pre-ignition/detonation (destroy pistons)
> - No spark at all (no start)
> 
> An oscilloscope on the EST line confirms your patch is behaving correctly before you run the engine.

---

## 🔬 RAM Validation Methodology

### How Free RAM Bits Were Identified

**Target Binary:** `VX-VY_V6_$060A_Enhanced_v1.0a.bin`  
**Size:** 131,072 bytes (128KB)  
**MD5:** `b5fe9212095f52b9e5e84301803f4f95`  
**SHA256:** `5cb8bd1c61da37a3846b6c28600cdc21...`

### $0046 Bit Usage Analysis

**Methodology:** Static binary scan for all HC11 bit manipulation opcodes targeting direct page address $46:

| Opcode | Instruction | Purpose |
|--------|-------------|---------|
| `$12` | BRSET | Branch if bits set |
| `$13` | BRCLR | Branch if bits clear |
| `$14` | BSET | Set bits |
| `$15` | BCLR | Clear bits |

**Scan Results (20 operations found):**

| Offset | Instruction | Mask | Bits Affected |
|--------|-------------|------|---------------|
| `$031FE` | BCLR $46,$01 | 00000001 | Bit 0 |
| `$03206` | BSET $46,$01 | 00000001 | Bit 0 |
| `$03213` | BRCLR $46,$01 | 00000001 | Bit 0 |
| `$0360A` | BRCLR $46,$01 | 00000001 | Bit 0 |
| `$100AD` | BSET $46,$01 | 00000001 | Bit 0 |
| `$10100` | BSET $46,$02 | 00000010 | Bit 1 |
| `$10107` | BCLR $46,$02 | 00000010 | Bit 1 |
| `$107A2` | BRSET $46,$25 | 00100101 | Bits 0, 2, 5 |
| `$12023` | BRCLR $46,$02 | 00000010 | Bit 1 |
| `$12041` | BRCLR $46,$02 | 00000010 | Bit 1 |
| `$1589B` | BRSET $46,$04 | 00000100 | Bit 2 |
| `$158EE` | BRSET $46,$04 | 00000100 | Bit 2 |
| `$15C75` | BRSET $46,$10 | 00010000 | Bit 4 |
| `$15CBE` | BRSET $46,$10 | 00010000 | Bit 4 |
| `$169A3` | BSET $46,$04 | 00000100 | Bit 2 |
| `$16A7D` | BCLR $46,$04 | 00000100 | Bit 2 |
| `$16D14` | BSET $46,$10 | 00010000 | Bit 4 |
| `$16D87` | BCLR $46,$10 | 00010000 | Bit 4 |
| `$1728F` | BRCLR $46,$02 | 00000010 | Bit 1 |
| `$172B0` | BRCLR $46,$02 | 00000010 | Bit 1 |

**Conclusion:**
- **Bits USED by stock code:** 0, 1, 2, 4, 5
- **Bits FREE for custom use:** 3, 6, 7
- **Bit 7 (mask $80):** Used as limiter state flag in v38 patches

### $01A0 Scratch Byte Analysis

**Methodology:** Static scan for all extended addressing opcodes targeting $01A0:

| Opcode Category | Instructions Scanned |
|-----------------|---------------------|
| Load | LDAA, LDAB, LDD, LDX |
| Store | STAA, STAB, STD, STX |
| Modify | INC, DEC, CLR, COM, NEG, LSR, ASL, ASR, ROL, ROR |

**Result:** **0 references found** to $01A0 in the entire binary.

**Current Value at Offset $01A0:** `$FF` (part of empty $FF region)

**Status:** Likely free, but treated as "scratch candidate" until runtime validation confirms stock code doesn't touch it via indexed/indirect addressing.

### Limitations of Static Analysis

⚠️ **What this scan CAN detect:**
- Absolute/direct addressing to $0046 or $01A0
- Bit operations (BRSET/BRCLR/BSET/BCLR) to direct page

⚠️ **What this scan CANNOT detect:**
- Indexed addressing (`LDAA 0,X` where X=$01A0)
- Indirect addressing (pointer dereference)
- Self-modifying code (very unlikely on HC11)
- Runtime register value changes

### Recommended Runtime Validation

For 100% certainty, log $0046 and $01A0 under stock driving conditions:

```text
1. Connect ALDL logger
2. Add $0046 and $01A0 to data stream (may need custom definition)
3. Drive vehicle through all conditions:
   - Cold start → warm-up
   - Idle (P/N and Drive)
   - Light cruise → heavy throttle
   - Gear changes (if auto)
   - Engine braking / decel
4. Verify:
   - $0046 bits 3,6,7 stay 0 (or stable value)
   - $01A0 doesn't change unless you modify it

If stable → safe to use. If any unexpected changes → investigate before using.
```

### Defensive Coding Practice

Even with "likely free" addresses, patches should be written defensively:

```asm
; Example: Only use $01A0 when our flag is set
    BRCLR $0046,$80,NOT_IN_LIMITER_MODE  ; If bit 7 clear, skip
    LDAA $01A0                           ; Only access when we "own" it
    INCA
    STAA $01A0
NOT_IN_LIMITER_MODE:
```

This ensures if stock code ever touches $01A0 unexpectedly, our code isn't corrupting its use.

---

## 🗺️ Roadmap / TODO

### ✅ Completed (January 2026)

- [x] Identify Enhanced v1.0a binary structure
- [x] Map 15KB+ free ROM space ($0C468-$0FFBF)
- [x] Verify hook point at $101E1 (STD $017B)
- [x] Document 68HC11 instruction set with corrections
- [x] Create 40+ assembly patch templates
- [x] Validate RAM variables ($00A2, $017B, $0199)
- [x] Analyze $0046 bit usage (bits 3,6,7 free)
- [x] Cross-reference with Chr0m3/The1 research

### 🔄 In Progress

- [ ] **Hardware verification** - Need oscilloscope traces of patched EST output
- [ ] **Spark cut v38 testing** - Binary created, needs bench test
- [ ] **Python assembler integration** - Auto-patch binary from .asm source
- [ ] **XDF enhancement** - Add patch control flags to XDF

### 📋 Planned

- [ ] **MAFless/Alpha-N implementation** - Force TPS-based load
- [ ] **Launch control with clutch input** - Two-step limiter
- [ ] **Flat shift / no-lift shift** - RPM-based spark cut during shifts
- [ ] **Antilag system** - Retard + enrichment for turbo applications
- [ ] **Ghost cam via ASM** - Aggressive idle spark modulation
- [ ] **VE table implementation** - Full speed density conversion

### 🔮 Future / Dream Features

- [ ] **Ghidra processor module improvements** - Better HC11 decompilation
- [ ] **Real-time tuning via ALDL** - Live parameter adjustment
- [ ] **Web-based patch builder** - Select features, generate patched binary
- [ ] **Port to other Holden ECUs** - VS, VT, VX variants
- [ ] **CAN bus integration** - For later model Commodores

### 🤝 Help Wanted

| Task | Skills Needed | Priority |
|------|---------------|----------|
| Oscilloscope EST verification | Hardware, automotive electrical | 🔴 HIGH |
| Test spark cut on running engine | Access to VY V6, brave soul | 🔴 HIGH |
| Review assembly for correctness | 68HC11 experience | 🟡 MEDIUM |
| Port to VS/VT platforms | Binary analysis, XDF creation | 🟢 LOW |
| Documentation improvements | Technical writing | 🟢 LOW |

---

## 🔗 Related Projects & Resources

### Essential Resources

| Resource | Link | Description |
|----------|------|-------------|
| **PCMHacking.net** | [pcmhacking.net](https://pcmhacking.net) | Community forum, XDF/bin archive |
| **Chr0m3 Motorsport YouTube** | [YouTube Channel](https://www.youtube.com/@Chr0m3Motorsport) | Video tutorials, spark cut research |
| **GearheadEFI** | [gearheadefi.com](https://gearheadefi.com) | Injector data, wiring diagrams, ALDL info |
| **Moates** | [moates.net](https://moates.net) | Ostrich, Quarterhorse hardware |
| **TunerPro RT** | [tunerpro.net](https://tunerpro.net) | Free tuning software (donate to Mark!) |

### PCMHacking Forum Topics

| Topic | Link | Content |
|-------|------|---------|
| Spark Cut Research | [Topic 8567](https://pcmhacking.net/forums/viewtopic.php?t=8567) | Chr0m3's original dwell/spark cut work |
| Enhanced OS Thread | [Topic 2518](https://pcmhacking.net/forums/viewtopic.php?t=2518) | The1's Enhanced bin development |
| OSE12P Timer Research | [Topic 7922](https://pcmhacking.net/forums/viewtopic.php?t=7922) | BennVenn's timer bit discovery |
| RPM Limit Discussion | [Topic 8756](https://pcmhacking.net/forums/viewtopic.php?t=8756) | 8-bit RPM limitation (255×25=6375) |

### Open Source ECU Projects

| Project | Description | Relevance |
|---------|-------------|-----------|
| **Speeduino** | Arduino-based standalone ECU | Rolling limiter implementation reference |
| **rusEFI** | STM32-based standalone ECU | Modern open source ECU design |
| **MegaSquirt** | DIY standalone ECU | Community-driven ECU development |
| **OpenPCM** | GM PCM research | Similar reverse engineering approach |

---

## 🔄 Platform Compatibility Matrix

### Will This Work on Other Holden ECUs?

**Short answer:** The concepts apply, but offsets will be different.

| Platform | Engine | ECU | Binary | Compatibility | Notes |
|----------|--------|-----|--------|---------------|-------|
| **VY L36** | 3.8L V6 NA | Delco $060A | 128KB | ✅ **Primary Target** | This repo |
| **VX L36** | 3.8L V6 NA | Delco $060A | 128KB | ✅ **Very High** | Same ECU, different BCM comms |
| **VY L67** | 3.8L V6 S/C | Delco $07 | 128KB | ⚠️ **Medium** | Different calibration, boost tables |
| **VT L36** | 3.8L V6 NA | Delco $A5 | 128KB | ⚠️ **Medium** | ISRs at $6000+ vs $2000+ |
| **VS L36** | 3.8L V6 NA | Delco $51 | 128KB | ⚠️ **Medium** | MEMCAL-based, different offsets |
| **OSE 12P** | VN-VS V6/V8 | Delco 808 MEMCAL | 32KB | 🔬 **Concept Only** | Speed-density, no MAF - techniques ported |
| **OSE 11P** | VR-VS V6/V8 | Delco 424 MEMCAL | 64KB | 🔬 **Concept Only** | Dwell spark cut method studied |
| **VL Walkinshaw** | 5.0L V8 | Delco 808 | 32KB | 🔬 **Research** | Two-stage limiter (BMW MS43 pattern) |
| **Buick 3800** | 3.8L L36/L67 | Delco 808 | 32KB | 🔬 **Related** | Same engine family, GearheadEFI resources |

> **⚠️ IMPORTANT:** OSE 11P/12P are **speed-density (MAP-only)** platforms that **cannot run on MAF-based VY V6 ECUs**. We study their spark cut and dwell techniques, then port those concepts to VY V6 code. Running 11P/12P requires a complete PCM swap to VR/VS MEMCAL hardware + NVRAM conversion.

### What's The Same Across All Platforms?

| Component | Universal? | Notes |
|-----------|------------|-------|
| **MC68HC11 CPU** | ✅ Yes | All use same instruction set |
| **TCTL1 register ($1020)** | ✅ Yes | Timer control identical |
| **TIC/TOC timer registers** | ✅ Yes | Hardware identical |
| **Vector table ($FFD6-$FFFE)** | ✅ Yes | Same structure |
| **ISR addresses** | ❌ No | Different per OSID |
| **RAM variable locations** | ❌ No | Different per OSID |
| **Free ROM space** | ❌ No | Varies significantly |
| **Hook points** | ❌ No | Must re-identify per binary |

### Porting Effort Estimates

| From VY $060A To | Effort | What Needs Changing |
|------------------|--------|---------------------|
| **VX $060A** | 🟢 Low | Just BCM comms, core identical |
| **VT $A5** | 🟡 Medium | Re-map ISRs, RAM addresses, hook points |
| **VS $51** | 🟡 Medium | Re-map all addresses, test free space |
| **OSE 12P** | 🔴 High | Different architecture, 32KB vs 128KB |
| **VL $5D** | 🔴 High | Very different layout, 16-32KB |

### L67 Supercharged Notes

> *"VY Supercharged and VT V8 were the only codes I have added RPM to the fuel cut."* — The1

The L67 (supercharged) uses OSID **$07** instead of $060A. Key differences:

- Boost control tables present
- Overboost fuel cut logic
- Different injector scaling (more fuel flow)
- Knock sensor tuning more aggressive

**Same patches could work**, but calibration addresses will differ.

### Buick 3800 Connection

The Holden L36/L67 **IS** the Buick 3800 (licensed from GM). Resources from GearheadEFI for Buick apply:

- Same DFI ignition module
- Same injector pinouts (mostly)
- RAM variable patterns similar
- 8F Hack documentation useful

---

## 📊 Project Statistics

| Metric | Count | Notes |
|--------|-------|-------|
| **Python Tools** | 199 | Analysis, extraction, validation scripts |
| **Assembly Files** | 52 | Spark cut, MAFless, launch control, etc. |
| **Documentation Files** | 172+ | Markdown research notes |
| **Total Project Size** | 1.5 GB | Including binaries, XDFs, datasheets |
| **Research Duration** | 6 weeks | Nov 2025 - Jan 2026 |
| **Forum Topics Analyzed** | 50+ | PCMHacking, GearheadEFI archives |
| **XDF Definitions Examined** | 20+ | Cross-platform comparison |

### Key Discoveries Made

| Discovery | Significance | How Found |
|-----------|--------------|-----------|
| **Hook point at $101E1** | Entry point for patches | Binary pattern analysis |
| **15KB+ free ROM space** | Room for complex patches | Zero-byte scanning |
| **$0046 bit 7 is FREE** | Custom flag storage | BSET/BCLR pattern analysis |
| **3X period at $017B** | Chr0m3 method verified | ISR tracing + XDF cross-ref |
| **RPM at $00A2 (×25 scaling)** | 8-bit RPM variable | 82 references in binary |
| **VL uses BMW MS43-style limiter** | Two-stage hysteresis | XDF parameter extraction |
| **dis68hc11 has opcode bugs** | ADCA/ADCB modes swapped | Manual Motorola datasheet verification |

### Tools Created

| Tool | Purpose | Lines of Code |
|------|---------|---------------|
| `apply_spark_cut_v38.py` | Apply patches to binary | ~200 |
| `hc11_disassembler_enhanced.py` | Better than dis68hc11 | ~800 |
| `xdf_complete_extractor.py` | Full XDF parameter dump | ~400 |
| `analyze_all_isrs.py` | Trace interrupt handlers | ~300 |
| `find_free_space.py` | Locate empty ROM regions | ~150 |
| `validate_readme_claims.py` | Fact-check documentation | ~250 |

---

## 💡 What The Gatekeepers Don't Want You To Know

### Things I Learned That Aren't Documented Anywhere Else

1. **The 8-bit RPM limit is hardware** - 255 × 25 = 6375 RPM max. You can't "tune around" this. You need code changes.

2. **Zeroing dwell triggers bypass mode** - The ignition module has failsafe. Chr0m3 figured out you inject a fake period instead.

3. **VY ISRs are at $2000, not $6000** - Every other platform has code at $6000+. VY is different. This matters for hooks.

4. **The Enhanced bin was never documented** - The1 released it, but never explained the assembly changes. I had to reverse engineer it.

5. **Buick 3800 resources apply to Holden** - Same engine family. GearheadEFI's 8F Hack documentation is gold.

6. **VL Walkinshaw has BMW-style limiter** - Two-stage with hysteresis. Sounds amazing. Same pattern as MS43.

7. **$0046 is a mode byte** - Bits are used as flags throughout the code. Some bits are free for custom use.

8. **dis68hc11 has bugs** - The open source disassembler has ADCA/ADCB addressing modes swapped. I documented the corrections.

### Why They Won't Tell You

- **Business protection** - Some sell tuning services and don't want competition
- **Ego protection** - Admitting they don't know everything hurts
- **Guild mentality** - "I had to figure it out the hard way, so should you"
- **Fear of liability** - If someone damages an engine, they get blamed

### My Philosophy

- **Share everything** - Knowledge wants to be free
- **Document mistakes** - Future researchers benefit from knowing what doesn't work
- **Credit sources** - Chr0m3, The1, BennVenn, Antus, Mark Mansur - legends
- **Test before bragging** - This code is marked UNTESTED until I verify on hardware

### Why Markdown?

Markdown is the only format that is **diff-native** and **reviewable at speed**. People can comment line-by-line, submit PRs, and every change is attributable and reversible. PDFs, Word docs, and spreadsheets are fine for final releases but they are hostile to rapid iteration and community correction. PDF and spreadsheet outputs can be auto-generated later from the same source. For now, the repo stays in a format that supports **fast review, fast fixes, and clear history**.

---

## 🔧 Bench Testing Setup (What I'm Building)

### Required Hardware

| Item | Purpose | Status |
|------|---------|--------|
| **Spare VY ECU** | Test subject | ✅ Have |
| **Moates Ostrich 2.0** | Real-time emulation | ✅ Have |
| **12V bench power supply** | ECU power | ✅ Have |
| **Oscilloscope** | EST signal verification | 🔴 Need |
| **Crank sensor simulator** | Generate 3X/24X signals | 🔴 Need to build |
| **Breakout harness** | Access ECU pins | 🔄 Building |

### Test Procedure (Planned)

1. Load stock binary via Ostrich
2. Verify normal EST output on scope
3. Load patched binary
4. Simulate high RPM via crank signals
5. Verify EST cuts at threshold
6. Check for bypass mode triggering
7. Test hysteresis behavior
8. Document all waveforms

### What Success Looks Like

- **EST signal goes LOW** when RPM exceeds threshold
- **No bypass mode trigger** (ignition module stays in ECU control)
- **Clean recovery** when RPM drops below threshold
- **Consistent behavior** across multiple test cycles

---

## My Other Repositories

| Repository | Description |
|------------|-------------|
| [TunerPro-XDF-BIN-Universal-Exporter](https://github.com/KingAiCodeForge/TunerPro-XDF-BIN-Universal-Exporter) | Export XDF/BIN data to various formats |


### 68HC11 Development Resources

| Resource | Description |
|----------|-------------|
| **M68HC11 Reference Manual** | Official Motorola/Freescale documentation |
| **A09 Assembler** | Free HC11/HC12 assembler |
| **dis68hc11** | Simple disassembler (has bugs - see my docs) |
| **dasmfw** | More accurate disassembler framework |
| **Ghidra** | NSA reverse engineering tool with HC11 support |

### YouTube Channels Worth Following

| Channel | Content |
|---------|---------|
| **Chr0m3 Motorsport** | Holden ECU tuning, spark cut development |
| **TheBoostController** | Boost/turbo tuning content |
| **HP Tuners** | (Competitors but good general info) |

### Books & Documentation

| Title | Author | Notes |
|-------|--------|-------|
| *M68HC11 Reference Manual* | Motorola/Freescale | Essential HC11 documentation |
| *Embedded Systems: Introduction to Arm Cortex-M Microcontrollers* | Jonathan Valvano | General embedded concepts |
| *Engine Management: Advanced Tuning* | Greg Banish | Tuning fundamentals |

---

## 💭 Why This Project Exists

### Timeline: 6 Weeks from Idea to 40+ Assembly Files

- **Late November 2025** - Thought: *"I want ignition cut on my Commodore like I did on my BMW"*
- **Late 2025** - Finally got PCMHacking account after **2 years of trying** (couldn't get admin support without account, couldn't get account without admin support)
- **December 2025** - Started pulling apart Enhanced $060A binaries
- **January 2026** - This repository: 40+ assembly patches, 15KB+ free ROM mapped, verified hook points, Python tooling

**6 weeks.** From zero Holden ECU assembly knowledge to the most documented VY V6 ASM repository publicly available.

### The Gatekeeping Problem

After **1+ year** trying to learn ECU tuning through "official" Discord channels, Facebook pages, and forums, here's what happened:

| Platform | My Contribution | Their Response |
|----------|-----------------|----------------|
| **BMW Tuning Discord** | Cracked password-protected RAR with Stage 1/2/3 tunes, shared the password to help community access locked files, uploaded some tunes that werent on public repos. tried to share a patch for the community patch. waste of effort with that lot | classed as spam **BANNED** |
| **Facebook Groups** | GitHub repos, offered help and advice | Posts deleted → **BLOCKED** |
| **Various "Experts"** | Questions about specific opcodes | Left on read, or *"that looks like GPT crap"* |

The pattern is always the same:
1. Share free work (XDFs, tools, file collections)
2. Nobody acknowledges it
3. Ask one question
4. Get insulted, then banned for "spamming"

#### What They Called "Spam":
- 5 private messages to 5 different people asking if anyone could help
- That's it. That's "spamming links" apparently.

#### What They Said When I Asked Why:
> *"You kept spamming links as private messages. And didn't explain what's the deal with that."*

The "links" were GitHub repositories. The explanation was in the repositories. They just didn't click them.

### Meanwhile, People Who Actually Looked At My Work...

| Person | What Happened |
|--------|---------------|
| **Mark Mansur (TunerPro developer)** | I reported a zero-export bug. **Fixed it in 24 hours.** Also added missing data units. Professional, helpful, legend. |
| **Antus (PCMHacking admin)** | Activated my account, explained rules, answered emails. Said *"I just do software as a hobby"* - honest about scope. **Turns out he lives near me in SA.** |
| **Chr0m3 Motorsport** | His videos and forum posts are the foundation of this work. The 3X period injection method = his discovery. |
| **The1** | His Enhanced OS bins are what we're patching. Years of work, shared publicly. |
| **Nakai** | Random person on Discord who actually validated my BMW claims instead of dismissing them |

**The gatekeepers are not the experts. The helpful people are.**

### On AI-Assisted Development

Yes, I use **Claude Opus 4.5 in VS Code Copilot** to accelerate my work.

Someone in a Discord called my code *"GPT crap that won't even run"* and *"GPT likes to hallucinate"*.

Here's my response:

1. **Every address verified against the actual binary** - check yourself. Check `0x101E1`. It's `FD 01 7B` (STD $017B). That's not a hallucination.

2. **AI doesn't replace understanding** - You still need to know:
   - What bank the code executes in
   - How 68HC11 addressing modes work
   - Which RAM is safe to use (I ran bit-analysis on $0046 - bits 0,1,2,4,5 used, bit 7 free)
   - How ISRs interact with main loop timing

3. **The alternative is asking gatekeepers who don't answer** - I asked dozens of people. Hundreds of messages. Left on read, blocked, or banned. AI actually helps.

4. **Results speak** - This repo has more documented Holden ECU assembly than anywhere else public. If that's "slop", show me the alternative.

From a chat with another tuner who gets it:
> *"Use what ya know and get AI to help. Should be purpose-built AI. Gemini and ChatGPT love to hallucinate."*


### The 10/90 Rule

The tuning community is:
- **10% legends** who share knowledge freely (Chr0m3, The1, Antus, Mark Mansur, BennVenn)
- **90% gatekeepers** who hoard it, sell it, or just insult newcomers to feel powerful, dont now how to RE or make hardware or code are the one who click the ban/delete post button.

**Find the 10%. Ignore the 90%.**

### Why I'm Publishing This

- These engines are **20+ years old** - Holden doesn't even exist anymore
- **Knowledge shouldn't be gatekept** for discontinued platforms in 2026
- **I learned from people who shared** (Chr0m3's videos, The1's forum posts, PCMHacking archives)
- Time to pay it forward
- **Open source wins** - Speeduino, rusEFI, MegaSquirt all prove this

### To The Haters

To the people leaving jealous, spiteful comments without reviewing the actual code:

- You called it "AI slop" without reading it
- You called it "spam" because I asked for help
- You called me "mental" because I contributed without permission
- You banned me from servers where I shared free tools

**Stay jealous.** Your doubt pushes me harder than you'll ever go.

This repo exists because you told me I couldn't. Keep watching. you will be using this code in a few months time to make off custom tuning mail order so called dyno validated tunes off ebay.

### Want To Actually Help?

If you can contribute research, testing, or validation - PRs are open.

If you've tested any Holden ECU assembly patches (on any platform) - let me know what works.

If you have oscilloscope traces of EST/dwell on VY V6 - that's the missing piece for hardware verification.

---

## 🔗 Credits

### Primary Contributors

| Person | Contribution | Why They Matter |
|--------|--------------|-----------------|
| **Chr0m3 Motorsport** | Spark cut method discovery, dwell research, video documentation | The 3X period injection = his idea. I just am trying to implement it from what he told me. |
| **The1** | Enhanced OS creation, XDF definitions, LPG zeroing technique | Years of bin editing work, shared publicly on PCMHacking |
| **Antus** | PCMHacking admin, technical guidance | Helped me get started, lives in my state, actually answers emails (even when he's been at a work party 🍺) |
| **Mark Mansur** | TunerPro developer | Fixed bugs I reported in 24 hours. Please donate to TunerPro - it's free and he deserves it |

### Community Contributors

| Person | Contribution |
|--------|--------------|
| **BennVenn** | OSE12P timer research foundation ($3FFC discovery) |
| **charlay86** | Enhanced code testing and dwell limiting validation |
| **vlad01** | 11P spark cut research and historical context |
| **Muncie** | Real-world testing (*"Have had this in my car with partial success"*) |
| **Rhysk94** | RPM limit confirmation (Topic 8756) also a mega tooner by the way... |
| **VYVZMods** | VY/VZ cluster RE work, Renesas MCU details and alot of other info about tech 2 |
| **Nakai** | Validated my BMW claims when others dismissed them, answered questions helps with pcm tuning discussions. renowned tooner in asia |

### Knowledge Sources

- **PCMHacking.net** - Community knowledge base and archive (4000+ XDFs, 10000+ bins) 8+gb of files
- **GearheadEFI.com** - Injector data, VE tools, Moates documentation
- **BMW MS4X Community** - MS42/MS43 patchlists influenced patch design patterns

### The Real MVPs

The people who **share knowledge freely** instead of gatekeeping it:
- Chr0m3's YouTube videos teaching the concepts
- The1's forum posts explaining Enhanced OS methodology
- Mark Mansur making TunerPro free and maintaining it for decades
- Josh Stewart (Speeduino), Andrey (rusEFI), and the open source ECU movement
- Wadim from cobra rtp - giving me the hw flash online pdf with the live tuning info near identical to moates.
- Craig Moates from moates - helping me setup my ostrich 2.0 and g6 the right way round...
**You are the 10%. Thank you.** - the rest need to pull ya heads out ya bums and stop using buzzwords and insults and the bullying shit. i could legit say something right and its wrong to the 90 percent of these people. you know who you are...

---

## ⚠️ Disclaimer

This is **research code for educational purposes only**.

- No warranty expressed or implied
- Test on bench with oscilloscope before vehicle use
- Author not responsible for engine damage
- All code marked UNTESTED until hardware verified

---

## 📜 License

MIT with Attribution

Copyright (c) 2026 Jason King (kingaustraliagg / KingAiCodeForge)

---

## 📫 Contact

- **GitHub:** [@KingAiCodeForge](https://github.com/KingAiCodeForge)
- **PCMHacking:** kingaustraliagg
- **Email:** jasonking282@gmail.com
- **Location:** South Australia 🇦🇺

### Other Projects

| Repository | Description |
|------------|-------------|
| [TunerPro-XDF-BIN-Universal-Exporter](https://github.com/KingAiCodeForge/TunerPro-XDF-BIN-Universal-Exporter) | XDF/BIN export tool (Mark Mansur acknowledged this one) |


---

*This README was written by a human who uses AI tools to work faster. If that bothers you, go make something better.*
