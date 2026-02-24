; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !! CROSS-BANK BUG (2026-02-13): This file places code at ORG $C468+ !!
; !! (bank 1 free space). The hook at file 0x101E1 (STD $017B) is in  !!
; !! bank 2 (0x10000-0x17FFF). JSR $C500 from bank 2 hits file        !!
; !! 0x1C500 (LIVE TRANS CODE), NOT 0x0C500 (our patch).               !!
; !! FIX: Relocate to common area $5D05 (always visible, 504 bytes    !!
; !! free) or bank 2 free space at file 0x17EA2 (286 bytes).           !!
; !! See custom_ose_$060_445_plan.md section 3.1a/3.1b for details.   !!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;;==============================================================================
; VY V6 SPARK CUT - BINARY PATCH FILE - v38
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Updated: February 9, 2026 (Enhanced v1.0a ground truth fix)
; Status: ✅ READY TO APPLY
;
; Binary Target: VX-VY_V6_$060A_Enhanced_v1.0a (128KB, bank-switched)
;   Bank 0: file 0x00000-0x07FFF (CPU $0000-$7FFF) - data + common code
;   Bank 1: file 0x08000-0x0FFFF (CPU $8000-$FFFF) - FREE SPACE at $C468-$FFBF
;   Bank 2: file 0x10000-0x17FFF (CPU $8000-$FFFF) - main engine code
;   Bank 3: file 0x18000-0x1FFFF (CPU $8000-$FFFF) - transmission + diagnostics
;   Bank 1 is IDENTICAL between stock and Enhanced (0 bytes differ)
;
; Two patches required:
;   1. Hook patch at file 0x101E1 in bank 2 (3 bytes)
;   2. Code patch at file 0x0C500 in bank 1 (42 bytes, includes PSHA/PULA fix)
;
;==============================================================================

;------------------------------------------------------------------------------
; PATCH 1: HOOK POINT (3 bytes)
;------------------------------------------------------------------------------
; ✅ CORRECT HOOK (verified against Enhanced v1.0a bank disassembly):
;   File Offset: 0x101E1 (bank 2, CPU $81E1)
;   Original:    FD 01 7B  (STD $017B - store dwell intermediate)
;   Patched:     BD C5 00  (JSR $C500 - call our handler in bank 1)
;   Context: Dwell calculation path, executes every ignition cycle
;
; Hex editor: Go to offset 0x101E1, replace:
;   FD 01 7B  →  BD C5 00
;
; ❌ DO NOT USE 0x13618 (STD $194C) — that is the cold-start init path only!
;   At runtime $194A != 0 so BNE at $360C skips past $3618 entirely.
;   Any value written there gets overwritten by filter sub $050C.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; PATCH 2: SPARK CUT HANDLER CODE (42 bytes = 38 code + 4 signature)
;------------------------------------------------------------------------------
; File Offset: 0x0C500
; Original:    00 00 00 00 00 ... (all zeros - free space)
; Patched:     (see hex below)
;
; Write these bytes starting at file offset 0x0C500:
;
; ⚠️  CRITICAL: PSHA/PULA required to preserve register A!
;     Without it, LDAA $A2 corrupts the high byte of D.
;     On the normal (below-RPM) path, STD would store (RPM:B) instead of
;     the real dwell intermediate value. This was the v38 A-register bug.
;------------------------------------------------------------------------------

; 6000 RPM PRODUCTION VERSION (Fixed 2026-02-09 — with PSHA/PULA fix):
; ====================================================
; This hooks STD $017B at file 0x101E1 (bank 2, CPU $81E1).
; Our handler preserves A, checks RPM, stores to $017B then returns.
;
; Offset  | Hex                              | Instruction
; --------|----------------------------------|---------------------------
; 0C500   | 36                               | PSHA (save A — contains real dwell high byte!)
; 0C501   | 12 46 80 0B                      | BRSET $46,$80,$C510 (CHECK_RESUME)
; 0C505   | 96 A2                            | LDAA $A2 (load RPM/25)
; 0C507   | 81 F0                            | CMPA #$F0 (6000 RPM)
; 0C509   | 25 0E                            | BCS $C519 (STORE_NORMAL)
; 0C50B   | 14 46 80                         | BSET $46,$80 (set limiter flag)
; 0C50E   | 20 0E                            | BRA $C51E (INJECT_FAKE)
; 0C510   | 96 A2                            | LDAA $A2 (CHECK_RESUME)
; 0C512   | 81 EC                            | CMPA #$EC (5900 RPM)
; 0C514   | 24 08                            | BCC $C51E (INJECT_FAKE)
; 0C516   | 15 46 80                         | BCLR $46,$80 (clear limiter flag)
; 0C519   | 32                               | PULA (STORE_NORMAL — restore real A!)
; 0C51A   | FD 01 7B                         | STD $017B (store REAL dwell intermediate)
; 0C51D   | 39                               | RTS
; 0C51E   | 32                               | PULA (INJECT_FAKE — clean stack)
; 0C51F   | CC 3E 80                         | LDD #$3E80 (fake dwell = 16000 = ~100µs)
; 0C522   | FD 01 7B                         | STD $017B (store fake dwell value)
; 0C525   | 39                               | RTS
; 0C526   | 4A 4B 26 02                      | Signature: "JK" v38 6000rpm
;
; Total: 42 bytes (38 code + 4 signature)

; Complete hex string for 6000 RPM (copy/paste to hex editor):
; 36 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0E 96 A2 81 EC 24 08 15 46 80 32 FD 01 7B 39 32 CC 3E 80 FD 01 7B 39 4A 4B 26 02

;------------------------------------------------------------------------------
; 3000 RPM TEST VERSION:
; ======================
; Same structure, just different thresholds:
; 0C507   | 81 78                            | CMPA #$78 (3000 RPM)
; 0C512   | 81 74                            | CMPA #$74 (2900 RPM)
;
; Complete hex string for 3000 RPM TEST:
; 36 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0E 96 A2 81 74 24 08 15 46 80 32 FD 01 7B 39 32 CC 3E 80 FD 01 7B 39 4A 4B 26 01

;------------------------------------------------------------------------------
; VERIFICATION AFTER PATCHING
;------------------------------------------------------------------------------
;
; 1. Read back offset 0x101E1 (bank 2, CPU $81E1): should show BD C5 00
; 2. Read back offset 0x0C500 (bank 1, CPU $C500): should show code bytes above
; 3. Recalculate checksum if your flash tool requires it
;
; ALDL MONITORING:
;   Address $0046 bit 7:
;     0 = Limiter OFF (normal operation)
;     1 = Limiter ON (spark cut active)
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; ROLLBACK (UNDO PATCH)
;------------------------------------------------------------------------------
;
; To restore stock behavior:
; 1. Offset 0x101E1 (bank 2): Replace BD C5 00 → FD 01 7B (restores STD $017B)
; 2. Offset 0x0C500 (bank 1): Optional - can leave code (never called if hook reverted)
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; PYTHON SCRIPT TO APPLY PATCH
;------------------------------------------------------------------------------
;
; import struct
; 
; # Open binary
; with open('VY_V6_Enhanced.bin', 'r+b') as f:
;     
;     # Patch 1: Hook at 0x101E1 (bank 2, CPU $81E1)
;     # Replaces STD $017B with JSR $C500 (call handler in bank 1)
;     f.seek(0x101E1)
;     f.write(bytes([0xBD, 0xC5, 0x00]))  # JSR $C500
;     
;     # Patch 2: Code at 0x0C500 (bank 1, CPU $C500, free space $C468-$FFBF)
;     # 42 bytes: 38 code + 4 signature (with PSHA/PULA A-register fix)
;     f.seek(0x0C500)
;     code = bytes([
;         0x36,                    # PSHA (save A — real dwell high byte!)
;         0x12, 0x46, 0x80, 0x0B,  # BRSET $46,$80,CHECK_RESUME ($C510)
;         0x96, 0xA2,              # LDAA $A2 (RPM/25, 94 refs Enhanced)
;         0x81, 0xF0,              # CMPA #$F0 (6000 RPM)
;         0x25, 0x0E,              # BCS STORE_NORMAL ($C519)
;         0x14, 0x46, 0x80,        # BSET $46,$80 (set limiter flag)
;         0x20, 0x0E,              # BRA INJECT_FAKE ($C51E)
;         0x96, 0xA2,              # LDAA $A2 (CHECK_RESUME)
;         0x81, 0xEC,              # CMPA #$EC (5900 RPM)
;         0x24, 0x08,              # BCC INJECT_FAKE ($C51E)
;         0x15, 0x46, 0x80,        # BCLR $46,$80 (clear limiter flag)
;         0x32,                    # PULA (restore A — real dwell high byte!)
;         0xFD, 0x01, 0x7B,        # STD $017B (store REAL dwell intermediate)
;         0x39,                    # RTS
;         0x32,                    # PULA (clean stack)
;         0xCC, 0x3E, 0x80,        # LDD #$3E80 (fake dwell = 16000)
;         0xFD, 0x01, 0x7B,        # STD $017B (store fake dwell value)
;         0x39,                    # RTS
;         0x4A, 0x4B, 0x26, 0x02,  # Signature: "JK" v38 6000rpm
;     ])
;     f.write(code)
;     
; print("Patch applied successfully!")
;
;------------------------------------------------------------------------------

            END
