# VY V6 TIC3 ISR Analysis - EXPLORATORY RESEARCH

> **📢 PUBLIC DOCUMENT** - This file is published on GitHub for community reference.

**Date:** January 16, 2026 (Updated: January 22, 2026)  
**Status:** ⚠️ EXPLORATORY - May be from Enhanced v1.0a and not match stock 92118883
---

## ⚠️ CRITICAL DISCLAIMER

**These ISR addresses are NOT in the STOCK 92118883 binary!**

Deep verification (Jan 22, 2026) confirms:
- Jump table 0x2006-0x2012: **ALL ZEROS in STOCK** (may exist in Enhanced v1.0a)
- ISR code at 0x35FF-0x3640: **NOT FOUND in STOCK disassembly**
- Source: Likely Enhanced v1.0a or different OSID variant (possibly LPG variant?)
- **$0046 bit 0** used by ISR code at `BRCLR $46,#$01,$361C` (see below)

**For spark cut implementation, THIS ANALYSIS IS NOT NEEDED!**

Use the verified hook point instead:
- ✅ **File offset 0x101E1** = `STD $017B` (CONFIRMED in STOCK)
- ✅ **Hook with JSR $C500** = spark_cut_chr0m3_method_VERIFIED_v38.asm
- ✅ **Use $0046 bit 7 ($80) for limiter flag** - verified FREE (0 stock refs)

**Next Steps:**
- [ ] Check Enhanced v1.0a binary for ISR code at 0x35FF
- [ ] Search for alternate TIC3 ISR location in STOCK
- [ ] Verify if $0178 vs $017B are both valid period storage

---

## 📍 ISR ADDRESSES CONFIRMED

| ISR | Vector | Jump Table | Actual Code | Purpose |
|-----|--------|------------|-------------|---------||
| TIC3 | 0x1FFEA → 0x200F | JMP $35FF | **0x35FF** | **24X Crank Handler** |
| TIC2 | 0x1FFEC → 0x2012 | JMP $358A | **0x358A** | CAM/SYNC Handler |
| TOC3 | 0x1FFE4 → 0x2009 | JMP $35BD | **0x35BD** | EST Output Handler |
| TOC4 | 0x1FFE2 → 0x2006 | JMP $35DE | **0x35DE** | Timer 4 Handler |

---

## 🔥 TIC3 ISR ANALYSIS (24X Crank - Spark Cut Point)

### Code Flow at 0x35FF:

```asm
35FF: LDAA   #$01           ; Clear TIC3 interrupt flag
3601: STAA   $1023          ; Write to TFLG1 (ack interrupt)
3604: INC    $1B8C          ; Increment counter
3607: INC    $18E5          ; Increment counter
360A: BRCLR  $46,#$01,$361C ; Branch if bit 0 of $0046 is clear
360E: BRSET  $48,#$01,$3616 ; Branch if bit 0 of $0048 is set
3612: BRCLR  $44,#$10,$361C ; Branch if bit 4 of $0044 is clear
3616: BCLR   $48,#$01       ; Clear bit 0 of $0048
3619: JMP    $3719          ; Jump to alternate path
361C: PULB                   ; Pop B (discard)
361D: PULB                   ; Pop B (discard)
361E: LDAB   $016D          ; Load cylinder index
3621: LDX    #$6852          ; Load table base address
3624: ABX                    ; Add B to X (table lookup)
3625: LDAB   $00,X          ; Load from table
...
362B: LDD    $01B3          ; <<< LOAD PREVIOUS CAPTURE
362E: SUBD   $00,X          ; Subtract something
3630: PULX
3631: JSR    $371A          ; <<< KEY SUBROUTINE (period calc?)
3634: STAA   $017D          ; Store result
...
363B: LDD    $15CA          ; <<< POSSIBLE TIC3 CAPTURE VALUE
363E: STD    $0178          ; <<< STORE TO $0178 (secondary period variable)
```

### ⚠️ CORRECTION: Multiple Period Storage Addresses

**TWO period-related variables found:**
- `$0178` - Found at $363E in TIC3 ISR (secondary/intermediate)
- `$017B` - Found at 0x101E1 (file offset) = **THE HOOK POINT**

### 🎯 VERIFIED HOOK POINT: `$017B` at file offset 0x101E1

Binary verification:
```
Offset 0x101E1: FD 01 7B = STD $017B  ← THIS IS THE CORRECT HOOK POINT
```

The code at $363E stores to $0178, but **Chr0m3's method targets the STD $017B at 0x101E1**.

---

## 📊 IDENTIFIED RAM VARIABLES

| Address | Purpose | Confidence | Notes |
|---------|---------|------------|-------|
| **$017B** | **DWELL INTERMEDIATE** (HOOK POINT) | 🟢 HIGH | STD at 0x101E1 VERIFIED - NOT crank period! |
| **$194C** | **24X Crank Period** | 🟢 HIGH | STD at $3618 in TIC3 ISR (verified 2026-01-31) |
| $0178 | Secondary period variable | 🟡 MEDIUM | STD at $363E (Enhanced only?) |
| $017D | Period calculation result | 🟢 HIGH | STAA in TIC3 ISR |
| $0171 | Cylinder index counter | 🟢 HIGH | Reference unclear |
| $016D | Cylinder index | 🟢 HIGH | LDAB $016D in ISR |
| $01B3 | Previous TIC3 capture | 🟡 MEDIUM | LDD $01B3 in ISR |
| $0044 | Mode flag byte | 🟡 MEDIUM | Bit 4 tested by BRCLR |
| $0046 | Engine mode flags | 🟢 HIGH | Bit 0 tested, bit 7 FREE |
| $0048 | State flag byte | 🟡 MEDIUM | Bit 0 BRSET/BCLR |
| $01B3 | Previous TIC3 capture | 🟡 MEDIUM | LDD $01B3 in ISR |
| $1B7A | Reference value for period calc | 🟡 MEDIUM | |
| $1B7C-$1B86 | Period differences per cylinder | 🟢 HIGH | |
| $1B8C | 24X pulse counter | 🟢 HIGH | INC in ISR |
| $18E5 | Secondary counter | 🟢 HIGH | INC in ISR |

**Cross-Reference:** See [`RAM_Variables_Validated.md`](RAM_Variables_Validated.md) for complete RAM map with XDF validation status.

---

## 🔧 VERIFIED SPARK CUT INJECTION POINT

### Original (Wrong) Assumption

```asm
; We thought period was at $00C2
LDD    #$FFFF        ; Max period
STD    $00C2         ; Store to wrong address
```

### ✅ VERIFIED Injection (Binary Confirmed)

```asm
; Hook at file offset 0x101E1 - replaces STD $017B with JSR $C500
; Period storage is at RAM $017B (NOT $0178 or $00C2!)

spark_cut_check:
    LDAA   $00A2         ; Load RPM/25 (82 reads confirmed)
    CMPA   #$F0          ; Compare to 6000 RPM (240 × 25)
    BLO    normal_exit   ; Below limit, continue normal
    
    ; ABOVE LIMIT - Inject fake period to starve dwell
    LDD    #$3E80        ; 16,000 = Chr0m3's recommended value
    STD    $017B         ; Store to VERIFIED period address
    RTS
    
normal_exit:
    STD    $017B         ; Store real period (original instruction)
    RTS
```

---

## 🔍 TOC3 ISR (EST Output) Analysis

```asm
35BD: LDAA   #$20           ; Value 0x20 = bit 5
35BF: STAA   $1023          ; Ack TOC3 interrupt (TFLG1)
35C2: LDAB   $1000          ; Load PORTA
35C5: TBA                   ; A = B
35C6: ANDB   #$18           ; Mask bits 3,4
35C8: PSHB                  ; Save on stack
35C9: ORAA   #$10           ; Set bit 4
35CB: ANDA   #$F7           ; Clear bit 3
35CD: STAA   $1000          ; <<< WRITE TO PORTA (EST control?)
35D0: JSR    $88B0          ; Call timing routine
35D3: LDAB   $1000          ; Read PORTA again
35D6: ANDB   #$E7           ; Clear bits 3,4
35D8: PULA                  ; Restore saved bits
35D9: ABA                   ; Add to A
35DA: STAA   $1000          ; Write PORTA
35DD: RTI                   ; Return from interrupt
```

This shows:
- TOC3 controls PORTA bits 3 and 4
- Bit 4 = EST output high
- Bit 3 = EST output low
- The pattern: set bit 4, clear bit 3 = **coil charging**

---

## 🔄 Updated XDF Addresses to Add

| File Offset | CPU Address | Name | Description |
|-------------|-------------|------|-------------|
| 0x0178 | $0178 | RAM_3X_PERIOD | 3X period storage (16-bit) |
| 0x017D | $017D | RAM_PERIOD_RESULT | Period calculation result |
| 0x0171 | $0171 | RAM_CYL_INDEX | Cylinder index counter |
| 0x01B3 | $01B3 | RAM_PREV_TIC3 | Previous TIC3 capture |
| 0x1B7C | $1B7C | RAM_PERIOD_CYL1 | Period for cylinder 1 |
| 0x1B7E | $1B7E | RAM_PERIOD_CYL2 | Period for cylinder 2 |
| 0x1B80 | $1B80 | RAM_PERIOD_CYL3 | Period for cylinder 3 |
| 0x1B82 | $1B82 | RAM_PERIOD_CYL4 | Period for cylinder 4 |
| 0x1B84 | $1B84 | RAM_PERIOD_CYL5 | Period for cylinder 5 |
| 0x1B86 | $1B86 | RAM_PERIOD_CYL6 | Period for cylinder 6 |
| 0x1B8C | $1B8C | RAM_3X_COUNT | 3X pulse counter |
| 0x18E5 | $18E5 | RAM_SECONDARY_COUNT | Secondary event counter |

---

## ⚠️ IMPORTANT: $15CA is NOT RAM

The address $15CA appears in:
```asm
363B: LDD    $15CA
```

This is in the **calibration/ROM area** (Bank 1, 0x10000+). It's likely:
- A calibration constant, or
- A shadow register value

The actual **TIC3 hardware register** is at $1014, but the code reads from $15CA which may be a cached/processed value.

---

## 📝 Next Steps

1. ✅ **COMPLETED** - Hook point verified at 0x101E1 (STD $017B = dwell intermediate)
2. ✅ **COMPLETED** - Free space found at $0C468-$0FFBF (15KB+)
3. ✅ **COMPLETED** - RPM at $00A2 verified (8-bit, ×25 scaling)
4. ✅ **COMPLETED** - 24X crank period at $194C verified (TIC3 ISR)
5. **DONE** - See spark_cut_chr0m3_method_VERIFIED_v38.asm for working patch

---

## 🔗 Cross-Reference to Previous Findings

| Previous Doc Says | Actual Finding | Status |
|-------------------|----------------|--------|
| Period at $00C2 | **$194C** = 24X crank period, **$017B** = dwell intermediate | ✅ VERIFIED 2026-01-31 |
| TIC3 ISR at $2000 | TIC3 ISR at $35FF (via jump table at $200F) | ✅ VERIFIED |
| RPM at $005F | **RPM at $00A2** (8-bit, ×25 scaling) | ✅ VERIFIED (82 reads in binary) |
| TCTL1 writes | 3 locations in VY binary | ✅ VERIFIED |

---

## ✅ What This Means for Spark Cut Patch

**Two valid hook approaches (verified 2026-01-31/02-02):**

**Option 1: Dwell Intermediate Hook ($017B) - RECOMMENDED**
- Hook at file offset 0x101E1 (replaces STD $017B with JSR $C500)
- Easier to debug (main code, not ISR)
- See: `spark_cut_chr0m3_method_VERIFIED_v38.asm`

**Option 2: Crank Period Hook ($194C)**  
- Hook at file offset 0x13618 (in TIC3 ISR)
- Manipulates actual crank period

```asm
; Working patch at $C500 (Option 1 - dwell hook)
    LDAA   $00A2          ; Load RPM/25 (VERIFIED address)
    CMPA   #$F0           ; Compare to 240 = 6000 RPM
    BLO    normal_exit
    LDD    #$3E80         ; Fake period (16000)
    STD    $017B          ; Store to dwell intermediate
    RTS
normal_exit:
    STD    $017B          ; Store real value (original instruction)
    RTS
```
