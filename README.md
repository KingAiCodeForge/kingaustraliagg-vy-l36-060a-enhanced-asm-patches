# VY L36 $060A Enhanced Binary - Assembly Patches (WIP)

[![Platform: 68HC11](https://img.shields.io/badge/Platform-68HC11-blue.svg)](https://en.wikipedia.org/wiki/Motorola_68HC11)
[![Target: VY V6 ECU](https://img.shields.io/badge/Target-Holden%20VY%20V6-green.svg)](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches)
[![Status: Research/WIP](https://img.shields.io/badge/Status-WIP-yellow.svg)](https://github.com/KingAiCodeForge/kingaustraliagg-vy-l36-060a-enhanced-asm-patches)

> **Holden VY V6 Ecotec L36 (3.8L) - Assembly Patches for Delco $060A 92118883 ECU**
>
> Research-based 68HC11 assembly patches based on Chr0m3 Motorsport and The1's Enhanced OS, made by me and a computer robot.

⚠️ **ALL CODE IS UNTESTED - RESEARCH ONLY** ⚠️

No patched binaries included. These are reference implementations requiring manual binary patching and oscilloscope verification before real-world use.

> **Reality Check:** Most patches will likely work if applied correctly. However, use at your own risk. If you don't understand what connects to what in the binary, how one routine calls another, how RAM variables are shared between ISRs, or how timing-critical code interacts — you can brick your ECU or damage your engine. The HC11 has no safety net.
need to map out every thing to the bone in the binary itself and correct any mistakes i make along the way. im only human after all.

---

## ⚠️ CRITICAL ADDRESS CORRECTION (2026-01-31/02-02)

**TIC3 ISR disassembly PROVED previous assumptions about `$017B` were WRONG:**

| Old Claim | Corrected Fact |
|-----------|----------------|
| `$017B` = 24X crank period | **`$017B` = Intermediate dwell calculation** (NOT crank!) |
| Unknown actual crank storage | **`$194C` = 24X crank period** (STD @ $3618 in TIC3 ISR) |

**Both hooks are VALID for spark cut:**
- **$017B hook** (@ 0x101E1) - In main code, easier to debug, manipulates dwell intermediate
- **$194C hook** (@ 0x13618) - In TIC3 ISR, manipulates actual crank period

**See:** `BANK_SWITCHING_AND_ISR_ANALYSIS.md` for full TIC3 ISR disassembly

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
│   └── spark_cut_original.asm              # Original crank period method
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
├── ghost_cam_ASM_PATCH/            # 👻 Ghost cam experiment (THEORETICAL)
│   │   # OUR OWN APPROACH: BMW/LS-style RPM-delta lookup table (UNTESTED)
│   │   # NOTE: Rhysk94 says timing is NOT used for ghost cam on Delcos
│   │   # His working method is unknown to us - this is independent research
│   └── ghost_cam_rpm_delta_spark_v1.asm    # RPM delta spark lookup table
│
├── lumpy_idle_XDF_ONLY/            # 🎚️ Lumpy idle (XDF parameters only)
│   │   # LUMPY IDLE: XDF changes only, no ASM - produces slow ~1Hz lope
│   │   # NOTE: Rhysk94 has working ghost cam but his method is unknown to us
│   └── lumpy_idle_xdf_parameters_v2.asm    # XDF parameters reference
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
├── VS_V6_$51_Enhanced_v1.4g.xdf          # VS V6 NA (257 tables, 681 constants, 68 DTCs)
├── VS_V6_SC_$51_Enhanced_v1.0d.xdf       # VS V6 Supercharged (254 tables, 68 DTCs)
├── VS_V8_$A6F_Enhanced_v0.90b.xdf        # VS V8 (82 tables, 68 DTCs)
├── VT_V6_$A5G_Enhanced_v1.0i.xdf         # VT V6 NA (118 tables, 68 DTCs)
├── VT_V6_SC_$A5G_Enhanced_v1.3i.xdf      # VT V6 Supercharged (129 tables, 68 DTCs)
├── VT_V8_$A6E_Enhanced_v1.04.xdf         # VT V8 (77 tables, 68 DTCs)
├── VX VY_V6_$060A_Enhanced_v2.09b.xdf    # ⭐ VX/VY V6 NA (334 tables, 1546 constants, 68 DTCs)
└── VX VY_V6_SC_$07_Enhanced_v2.6i.xdf    # VX/VY V6 Supercharged (175 tables, 68 DTCs)
```

> **XDF versions above are the LATEST** — all include 68 DTC enable/disable flags added by Antus's XDF DTC Tool. Previous versions (v2.09a, v1.4f, v1.0h etc.) did NOT have individual DTC flags.

---

## 🔧 ASM vs XDF Tuning Guide

**Not everything needs assembly patches!** The Enhanced v2.09b XDF exposes many parameters.

| Feature | Method | Notes |
|---------|--------|-------|
| **Spark Cut Limiter** | ⚙️ ASM Required | Not in XDF - needs code injection |
| **Lumpy Idle** | 📊 XDF Only | Our approach: KSARPMHI/KSARPMLO multipliers, slow ~1Hz lope |
| **Ghost Cam (fast lope)** | ❓ Unknown | Rhysk94 has working tune but method unknown to us |
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

> **Lumpy Idle vs Ghost Cam:** Lumpy idle (XDF) creates slow 1Hz lope using spark correction parameters. Ghost cam creates fast aggressive lope - Rhysk94 has a working VY V6 ghost cam tune but states his method does NOT use timing. We don't know his method. Our BMW/LS-inspired ASM approach is THEORETICAL and untested.

---

## 🎯 Primary Focus: Spark Cut Limiter

### Binary Versions

| Binary | XDF | Spark Cut? | Status |
|--------|-----|------------|--------|
| **Enhanced v1.0a** | v2.09b | ❌ NO | This repo's target (v2.09b adds 68 DTC flags via Antus DTC Tool) |
| **Enhanced v1.1a** | v2.04c | ✅ YES | The1's implementation (Topic 8852) |

> **Note:** Enhanced v1.1a (v2.04c package, Topic 8852) includes The1's spark cut implementation. We are currently reverse-engineering that code to understand exactly what changed from v1.0a → v1.1a before documenting it publicly. Our v38 ASM patches are independent work based on Chr0m3's dwell intermediate method.

Primary implementation based on **Dwell Intermediate Injection** (Chr0m3 validated method, originally called "crank period"):

| Step | Description |
|------|-------------|
| 1 | Hook at file offset `0x101E1` (replaces `STD $017B`) |
| 2 | `JSR $C500` calls our patch in free space |
| 3 | Check RPM against threshold (e.g., 6000 RPM = `$F0` for 8-bit or `$1770` for 16-bit) |
| 4 | If over limit: inject fake period `$3E80` (16000) → starves dwell |
| 5 | Result: Classic "pops and bangs" exhaust sound |

**Start here:** [`asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm`](asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm)

### Key Verified Addresses

| Address | Type | Purpose |
|---------|------|---------|
| `$00A2` | RAM | Engine RPM (×25 scaling, 8-bit) |
| `$017B` | RAM | ~~3X period~~ **DWELL INTERMEDIATE** (corrected 2026-01-31) |
| `$194C` | RAM | **24X Crank Period** (actual crank storage in TIC3 ISR) |
| `$0199` | RAM | Dwell time storage |
| `$101E1` | ROM | Hook point (STD $017B) - **dwell intermediate hook** |
| `$13618` | ROM | Hook point (STD $194C) - **crank period hook** |
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
| **Chr0m3** | [Topic 8567](https://pcmhacking.net/forums/viewtopic.php?t=8567) | crank period injection method, dwell starving |
| **The1** | [Topic 2518](https://pcmhacking.net/forums/viewtopic.php?t=2518) | Enhanced OS bins, CPD comparison method, XDF definitions |
| **BennVenn** | [Topic 7922](https://pcmhacking.net/forums/viewtopic.php?t=7922) | OSE12P timer bit `$3FFC` discovery |
| **charlay86** | [Topic 2544](https://pcmhacking.net/forums/viewtopic.php?t=2544) | 6,375 RPM max (255 � 25 = 6375) - July 2012 |

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
- **XDF:** `VX VY_V6_$060A_Enhanced_v2.09b.xdf` (68 DTCs, 334 tables, 1546 constants)
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

### Stock vs Enhanced Binary Differences (Verified January 29, 2026)

Direct binary comparison of `92118883_STOCK.bin` vs `VY_V6_Enhanced.bin`:

| Region | Stock Binary | Enhanced Binary | Interpretation |
|--------|--------------|-----------------|----------------|
| **>850mg High-Oct** (0x57AF) | ALL 0x00 | HAS DATA | Stock disabled, Enhanced uses |
| **>850mg Low-Oct** (0x58C2) | ALL 0x00 | HAS DATA | Stock disabled, Enhanced uses |
| **LPG Region** (0x58E9-0x5A20) | ALL 0x00 | HAS DATA | Stock zeroed, Enhanced repurposed |
| **Rev Limiter** (0x77DE-0x77DF) | 0xEC 0xEB = 5900/5875 | IDENTICAL | Same factory limit |
| **Free Space** (0x0C468-0x0FFBF) | ALL 0x00 | ALL 0x00 | 15,192 bytes available |

> **Key Finding:** The "LPG tables removed" description is misleading. Stock binary has LPG region **already zeroed** (factory disabled). The Enhanced OS **repurposed** this pre-existing empty space for extended spark tuning data.

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
- [ ] **Port to other Holden ECUs** - VS, VT, VX variants


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

### Latest Enhanced XDF Inventory (All Platforms)

All XDFs below are the **latest versions** with 68 DTC enable/disable flags added by **Antus's XDF DTC Tool**. Author field updated to `"The1, Antus XDF DTC Tool"` (or `"Others, Antus XDF DTC Tool"` for VT V8).

| XDF File | Platform | OSID | Author | Tables | Constants | Flags | DTCs | Key Categories |
|----------|----------|------|--------|--------|-----------|-------|------|----------------|
| `VS_V6_$51_Enhanced_v1.4g.xdf` | VS V6 NA | $51 | The1, Antus | 257 | 681 | 349 | 68 | Spark, ESC, MAF, IAC, Adaptive Shift/Spark, TCC |
| `VS_V6_SC_$51_Enhanced_v1.0d.xdf` | VS V6 S/C | $51 | The1, Antus | 254 | 679 | 369 | 68 | + EGR, Power Steering |
| `VS_V8_$A6F_Enhanced_v0.90b.xdf` | VS V8 | $A6F | The1, Antus | 82 | 120 | 202 | 68 | Spark, Knock, DFCO, Adaptive Spark |
| `VT_V6_$A5G_Enhanced_v1.0i.xdf` | VT V6 NA | $A5G | The1, Antus | 118 | 177 | 205 | 68 | Spark, Knock, Torque Mgmt, MALF DTCs |
| `VT_V6_SC_$A5G_Enhanced_v1.3i.xdf` | VT V6 S/C | $A5G | The1, Antus | 129 | 169 | 203 | 68 | + Supercharger Boost Valve |
| `VT_V8_$A6E_Enhanced_v1.04.xdf` | VT V8 | $A6E | Others, Antus | 77 | 81 | 203 | 68 | Spark, ESC, DTC MALF, Crank |
| **`VX VY_V6_$060A_Enhanced_v2.09b.xdf`** | **VX/VY V6 NA** | **$060A** | **THE1, Antus** | **334** | **1546** | **548** | **68** | **⭐ Primary — 64 categories incl. Chr0m3/Charlay86 Mods** |
| `VX VY_V6_SC_$07_Enhanced_v2.6i.xdf` | VX/VY V6 S/C | $07 | The1, Antus | 175 | 385 | 257 | 68 | + Supercharger Solenoid, Abuse Management |

> **v2.09b vs v2.09a:** The only difference is 68 DTC "Process DTC xx" flags added by Antus's tool. v2.09a had **0 individual DTC flags**. All calibration tables/constants are identical. This is what Antus used AI for — batch-generating DTC flag entries — and it works perfectly.

### 68 DTCs (All Platforms — Identical Set)

Every XDF above has the same 68 "Process DTC" enable/disable flags:

<details>
<summary>Click to expand full DTC list</summary>

| DTC | Description | DTC | Description |
|-----|-------------|-----|-------------|
| 13 | RH O2 Sensor Open | 55 | A/D Conversion Error |
| 14 | Coolant High Temp | 56 | Fuel Starvation Under Load (Lean) |
| 15 | Coolant Low Temp | 57 | Injector Monitor Failure |
| 16 | Coolant Sensor Unstable | 58 | Trans. Temp. High |
| 17 | Coolant Pull-up Failure | 59 | Trans. Temp. Low |
| 18 | Linear EGR Flow Check | 63 | LH O2 Sensor Open |
| 19 | TPS Sensor Stuck | 64 | LH O2 Sensor Lean |
| 21 | TPS Sensor High | 65 | LH O2 Sensor Rich |
| 22 | TPS Sensor Low | 66 | 3-2 DS QDM2/Solenoid Failure |
| 23 | IAT Sensor Low | 67 | TCC QDM2/Solenoid Failure |
| 24 | Vehicle Speed Sensor | 68 | Trans. Component Slipping |
| 25 | IAT Sensor High | 69 | TCC Stuck On |
| 26 | IAT Sensor Unstable | 72 | VSS Output Speed Loss (Auto) |
| 27 | PSM Open | 73 | Force Motor Current |
| 28 | PSM | 75 | Voltage Low |
| 29 | EGR Pintle Position | 76 | STFT Delta Integrator High |
| 31 | Theft Deterrent Missing | 78 | LTFT Delta BLM High |
| 32 | MAF Out of Range | 79 | Transmission Hot |
| 33 | BAP High | 81 | Solenoid B Failure (2-3) |
| 34 | BAP Low | 82 | Solenoid A Failure (1-2) |
| 35 | IAC Failure | 83 | TCC Solenoid Failure |
| 36 | Vacuum Leak | 84 | QDM2 Failure |
| 39 | TCC Off | 86 | Solenoid B Stuck On |
| 41 | EST Open / Shorted | 87 | Solenoid B Stuck Off |
| 42 | Bypass Open / Shorted | 91 | QDM Failure |
| 43 | LH ESC Failure | 92 | Low Speed Fan Comms |
| 44 | RH O2 Sensor Lean | 93 | RH ESC Failure (Knock Circuit) |
| 45 | RH O2 Sensor Rich | 94 | Loss of PWM from ASR (VSS Manual) |
| 46 | Crank Reference Pulses | 95 | Loss of Serial Data from ASR |
| 47 | No 18x Signal | 96 | A/C Pressure Transducer |
| 48 | Cam Signal Missing / Grounded | 97 | Purge Valve Continuity |
| 49 | Cam / Crank Signal Error | 98 | Purge Valve Function Test |
| 51 | Prom Checksum Error | | |
| 52 | Voltage High - Long Test | | |
| 53 | Voltage High | | |
| 54 | Voltage Unstable | | |

</details>

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
| **3X period at $017B** | ~~Chr0m3 method verified~~ **CORRECTED: $017B = dwell intermediate, $194C = crank period** | TIC3 ISR disassembly |
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

## ?? Key Technical Discoveries

1. **The 8-bit RPM limit is hardware** - 255 � 25 = 6375 RPM max. You need code changes to exceed this.
2. **Zeroing dwell triggers bypass mode** - The ignition module has failsafe. Chr0m3 figured out you inject a fake period instead.
3. **VY ISRs are at $2000, not $6000** - Every other platform has code at $6000+. VY is different.
4. **$0046 is a mode byte** - Bits 0,1,2,4,5 used by stock. **Bits 3,6,7 are FREE** for custom use.
5. **$01A0 doesn't exist** - Was a placeholder copied across 42 ASM files. Use $0046 bit 7 instead.
6. **VL Walkinshaw has BMW-style limiter** - Two-stage with hysteresis. Same pattern as MS43.
7. **Buick 3800 resources apply to Holden** - Same engine family. GearheadEFI's 8F Hack documentation is useful.

---

## ?? Bench Testing Setup

See [`BENCH_TESTING_SETUP.md`](BENCH_TESTING_SETUP.md) for hardware requirements and test procedures.

---

## ?? Why This Project Exists

**Timeline:** 6 weeks from idea to 40+ assembly files (Nov 2025 - Jan 2026).

### Why I'm Publishing This

- These engines are **20+ years old** - Holden doesn't even exist anymore
- **Knowledge shouldn't be gatekept** for discontinued platforms
- **I learned from people who shared** (Chr0m3's videos, The1's forum posts, PCMHacking archives)
- Time to pay it forward
- **Open source wins** - Speeduino, rusEFI, MegaSquirt all prove this

### On AI-Assisted Development

Yes, I use AI tools to accelerate research. Every address is verified against the actual binary - check `0x101E1` yourself: it's `FD 01 7B` (STD $017B). AI doesn't replace understanding of 68HC11 addressing modes, ISR timing, or which RAM is safe to use.

### Want To Actually Help?

If you can contribute research, testing, or validation - PRs are open.

If you've tested any Holden ECU assembly patches (on any platform) - let me know what works.

If you have oscilloscope traces of EST/dwell on VY V6 - that's the missing piece for hardware verification.

---

## 🔗 Credits

### Primary Contributors

| Person | Contribution | Why They Matter |
|--------|--------------|-----------------|
| **Chr0m3 Motorsport** | Spark cut method discovery, dwell research, video documentation | The crank period injection = his idea. I just am trying to implement it from what he told me. |
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
| **VYVZMods** | VY/VZ cluster RE work, Renesas MCU details and a lot of other info about tech 2 |


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
