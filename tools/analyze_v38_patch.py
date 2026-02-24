#!/usr/bin/env python3
"""Disassemble the v38 spark cut patch"""

# Patch bytes at 0xC500 (CPU address $C500)
patch = bytes([
    0x12, 0x46, 0x80,  # 0: BRSET $46 #$80 ???
    0x0A,              # 3: target offset (+10 = addr 13)
    0x96, 0xA2,        # 4: LDAA $A2 (load RPM/25)
    0x81, 0xF0,        # 6: CMPA #$F0 (compare to 240 = 6000 RPM)
    0x25, 0x0D,        # 8: BCS +13 (if RPM < 6000, skip to normal)
    0x14, 0x46, 0x80,  # 10: BSET $46 #$80 (set limiter flag)
    0x20, 0x0A,        # 13: BRA +10 (branch to fake period inject)
    0x96, 0xA2,        # 15: LDAA $A2 (load RPM/25 again)
    0x81, 0xEC,        # 17: CMPA #$EC (compare to 236 = 5900 RPM)
    0x24, 0x04,        # 19: BHS +4 (if RPM >= 5900, keep flag set, normal)
    0x15, 0x46, 0x80,  # 21: BCLR $46 #$80 (clear limiter flag - resume)
    0xFD, 0x19, 0x4C,  # 24: STD $194C (store normal crank period)
    0x39,              # 27: RTS
    0xCC, 0x3E, 0x80,  # 28: LDD #$3E80 (load fake period = 16000)
    0xFD, 0x19, 0x4C,  # 31: STD $194C (inject fake period)
    0x39,              # 34: RTS
    0x4A, 0x4B,        # 35: signature "JK"
    0x26, 0x02         # 37: version 38, variant 02
])

print("=== V38 Spark Cut Patch Disassembly ===")
print("Hook: JSR $C500 at file offset 0x13618 (replaces STD $194C)")
print()

asm = """
; Spark Cut Patch v38 - 6000 RPM version
; Located at file 0xC500, CPU $C500
; Called from TIC3 ISR instead of original STD $194C

$C500:  BRSET  $46,#$80,$C50D   ; If limiter flag set, check resume threshold
$C504:  LDAA   $A2              ; Load RPM ÷ 25 from RAM
$C506:  CMPA   #$F0             ; Compare to 240 (6000 RPM)
$C508:  BCS    $C517            ; If RPM < 6000, skip to normal (store real period)
$C50A:  BSET   $46,#$80         ; Set limiter active flag
$C50D:  BRA    $C519            ; Branch to fake period injection

; Resume check (when flag already set)
$C50F:  LDAA   $A2              ; Load RPM ÷ 25
$C511:  CMPA   #$EC             ; Compare to 236 (5900 RPM)  
$C513:  BHS    $C519            ; If RPM >= 5900, keep cutting (inject fake)
$C515:  BCLR   $46,#$80         ; Clear limiter flag - resume normal spark

; Normal operation - store real crank period
$C517:  STD    $194C            ; Store D register (real period) to crank period RAM
$C51A:  RTS                     ; Return

; Spark cut active - inject fake period
$C51B:  LDD    #$3E80           ; Load fake period (16000 = ~250 RPM equivalent)
$C51E:  STD    $194C            ; Store fake period - kills dwell calculation
$C521:  RTS                     ; Return

; Signature
$C522:  .db    $4A,$4B,$26,$02  ; "JK" v38.2
"""

print(asm)

print("\n=== ACTIVATION CONDITIONS ===")
print("""
For spark cut to ACTIVATE:
1. RPM must be >= 6000 RPM ($A2 >= $F0 = 240)
2. Hook at 0x13618 must be installed (BD C5 00 = JSR $C500)
3. TIC3 ISR must be running (engine cranking/running)

For spark cut to RESUME (deactivate):
1. RPM must drop below 5900 RPM ($A2 < $EC = 236)
2. This provides 100 RPM hysteresis

CRITICAL CHECK - $00A2 must contain valid RPM data!
""")

print("\n=== POTENTIAL FAILURE MODES ===")
failure_modes = """
1. **RPM Variable Wrong** - $00A2 might not be RPM/25 in your binary
   - v1.0a Enhanced may use different RAM layout than assumed
   - Check what value is actually at $00A2 during running

2. **Hook Not Installed** - File offset 0x13618 must have BD C5 00
   - If it still has original STD $194C (FD 19 4C), patch isn't active

3. **Patch Code Not Present** - File offset 0xC500 must have the 39 bytes
   - This area is normally zeros in v1.0a, needs to contain patch

4. **TIC3 ISR Not Reaching Hook Point** - Engine must be running/cranking
   - Hook is in Timer Input Capture 3 ISR (crank sensor input)

5. **$0046 Bit 7 Already Used** - Conflict with existing ECU flag
   - If bit 7 of $46 is used for something else, logic will be wrong

6. **Fake Period Not Long Enough** - 16000 might not kill dwell
   - Dwell calculation: if period too short, coil still charges
   - Try increasing fake period value

7. **Branch Target Errors** - Offsets calculated incorrectly
   - BRSET branch at +10 should go to $C50D but that's the BRA, not LDAA
   - Need to verify branch destinations
"""
print(failure_modes)
