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

---

## 📁 Repository Structure

```text
asm_wip/
├── spark_cut/                      # 🔥 Ignition cut limiters (Chr0m3 method)
│   ├── spark_cut_3x_period_VERIFIED.asm    # ⭐ VERIFIED - 16-bit test template
│   ├── spark_cut_6000rpm_v32.asm           # Hard cut at 6000 RPM
│   ├── spark_cut_chrome_method_v33.asm     # Chr0m3 method (fuel cut scrapped)
│   ├── spark_cut_progressive_soft_v9.asm   # Gradual soft limiter
│   ├── spark_cut_rolling_v34.asm           # Speeduino-style rolling cut
│   ├── spark_cut_soft_timing_v36.asm       # Soft timing retard style
│   ├── spark_cut_combined_fuel_v35.asm     # Fuel+Spark clean cut
│   ├── spark_cut_dwell_patch_v37.asm       # Dwell patch for high RPM
│   ├── spark_cut_two_stage_hysteresis_v23.asm  # Two-stage with hysteresis
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
| **Ghost Cam / Lopey Idle** | 📊 XDF Preferred | KSARPMHI, KSARPMLO, Idle Spark tables |
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
| `$00A2` | RAM | Engine RPM (×25 scaling) |
| `$017B` | RAM | 3X period storage |
| `$0199` | RAM | Dwell time storage |
| `$101E1` | ROM | Hook point (STD $017B) |
| `$0C468-$0FFBF` | ROM | 15,192 bytes free space |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [`docs/FULL_TECHNICAL_REFERENCE.md`](docs/FULL_TECHNICAL_REFERENCE.md) | Complete technical reference (addresses, sources, analysis) |
| [`RAM_Variables_Validated.md`](RAM_Variables_Validated.md) | Verified RAM variable mapping |
| [`THE1_ENHANCED_ROM_METHODOLOGY.md`](THE1_ENHANCED_ROM_METHODOLOGY.md) | How The1's Enhanced bins work |
| [`DOCUMENT_CONSOLIDATION_PLAN.md`](DOCUMENT_CONSOLIDATION_PLAN.md) | Project status & session notes |
| [`68HC11_Reference/kingai_68hc11_resources/`](68HC11_Reference/kingai_68hc11_resources/) | HC11 instruction set reference |

---

## 🔬 Verified Sources

All claims verified against PCMHacking.net archive:

| Source | Topic | Key Finding |
|--------|-------|-------------|
| **Chr0m3** | [Topic 8567](https://pcmhacking.net/forums/viewtopic.php?t=8567) | 3X period injection method, dwell starving |
| **The1** | [Topic 2518](https://pcmhacking.net/forums/viewtopic.php?t=2518) | Enhanced OS bins, LPG zeroing, XDF definitions |
| **BennVenn** | [Topic 7922](https://pcmhacking.net/forums/viewtopic.php?t=7922) | OSE12P timer bit `$3FFC` discovery |
| **Rhysk94** | [Topic 8756](https://pcmhacking.net/forums/viewtopic.php?t=8756) | 6,375 RPM max (255 × 25 = 6375) |

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

## 🔗 Credits

### Primary Contributors

- **Chr0m3 Motorsport** - Spark cut method discovery, dwell research, video documentation, direct collaboration
- **The1** - Enhanced OS creation, XDF definitions, LPG zeroing technique, ongoing development
- **antus** - PCMHacking admin, technical guidance, hardware/software architecture insights

### Community Contributors

- **PCMHacking.net** - Community knowledge base and archive
- **BennVenn** - OSE12P timer research foundation ($3FFC discovery)
- **charlay86** - Enhanced code testing and dwell limiting validation
- **vlad01** - 11P spark cut research and historical context
- **Muncie** - Real-world testing ("Have had this in my car with partial success")
- **Rhysk94** - RPM limit confirmation (Topic 8756)

### External Inspiration

- **BMW MS4X Community** - The MS42/MS43 community patchlists and IVVT assembly code provided theoretical foundations and patterns that influenced several patch designs here. Their open approach to ECU modification documentation is appreciated.

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
- **Facebook:** Jason King (Holden tuning groups)
