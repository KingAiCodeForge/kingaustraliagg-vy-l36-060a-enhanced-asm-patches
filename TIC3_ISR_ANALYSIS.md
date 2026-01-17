# VY V6 TIC3 ISR Analysis - SPARK CUT INJECTION POINT FOUND

**Date:** January 16, 2026  
**Status:** 🎯 CRITICAL FINDINGS - Ready for patch implementation

---

## 📍 ISR ADDRESSES CONFIRMED

| ISR | Vector | Jump Table | Actual Code | Purpose |
|-----|--------|------------|-------------|---------|
| TIC3 | 0x1FFEA → 0x200F | JMP $35FF | **0x35FF** | 3X Crank Handler |
| TIC2 | 0x1FFEC → 0x2012 | JMP $358A | **0x358A** | 24X Crank Handler |
| TOC3 | 0x1FFE4 → 0x2009 | JMP $35BD | **0x35BD** | EST Output Handler |
| TOC4 | 0x1FFE2 → 0x2006 | JMP $35DE | **0x35DE** | Timer 4 Handler |

---

## 🔥 TIC3 ISR ANALYSIS (3X Crank - Spark Cut Point)

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

| Address | Purpose | Confidence |
|---------|---------|------------|
| **$017B** | 3X Period Storage (HOOK POINT) | 🟢 HIGH - STD at 0x101E1 VERIFIED |
| $0178 | Secondary period variable | 🟡 MEDIUM - STD at $363E |
| $017D | Period calculation result | 🟢 HIGH |
| $0171 | Cylinder index counter | 🟢 HIGH |
| $01B3 | Previous TIC3 capture | 🟡 MEDIUM |
| $1B7A | Reference value for period calc | 🟡 MEDIUM |
| $1B7C-$1B86 | Period differences per cylinder | 🟢 HIGH |
| $1B8C | 3X pulse counter | 🟢 HIGH |
| $18E5 | Secondary counter | 🟢 HIGH |
| $0046 | Engine mode flags | 🟢 HIGH |
| $0048 | Engine state flags | 🟢 HIGH |
| $0044 | Control flags | 🟢 HIGH |

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

1. **Update ignition_cut_patch.asm** - Change target from $00C2 to $0178
2. **Find free space** - Need to locate actual 0xFF regions for patch code
3. **Verify subroutine $371A** - This does the period math
4. **Test RPM address** - Confirm $005F is really RPM/25
5. **Update XDF** - Add new RAM variable definitions

---

## 🔗 Cross-Reference to Previous Findings

| Previous Doc Says | Actual Finding | Status |
|-------------------|----------------|--------|
| Period at $00C2 | Period at $0178 | ❌ WRONG - Corrected |
| TIC3 ISR at $2000 | TIC3 ISR at $35FF (via jump table) | ❌ WRONG - Corrected |
| RPM at $005F | Needs verification | 🟡 Unconfirmed |
| TCTL1 writes | Not in this ISR | 🔍 Check other code |

---

## ✅ What This Means for Spark Cut Patch

The patch injection needs to happen **AFTER** address $363E (where period is stored) but **BEFORE** the timing calculation uses it.

**Best injection point:** Immediately after `STD $0178`

```asm
; At $3641, insert our check
    LDAA   $005F          ; Load RPM
    CMPA   #$FA           ; 6250 RPM limit
    BLO    skip_cut
    LDD    #$FFFF
    STD    $0178          ; Override period with max value
skip_cut:
    ; Continue with original code at $3641
    F6 01 71              ; LDAB $0171 (original instruction)
```
