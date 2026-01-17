;==============================================================================
; VY V6 SPARK CUT - BINARY PATCH FILE - v38
;==============================================================================
; Author: Jason King (kingaustraliagg)
; Date: January 18, 2026
; Status: ✅ READY TO APPLY
;
; This file contains the exact hex bytes to patch into your binary.
; Two patches required:
;   1. Hook patch at 0x101E1 (3 bytes)
;   2. Code patch at 0x0C500 (35 bytes)
;
;==============================================================================

;------------------------------------------------------------------------------
; PATCH 1: HOOK POINT (3 bytes)
;------------------------------------------------------------------------------
; File Offset: 0x101E1
; Original:    FD 01 7B  (STD $017B - store period to RAM)
; Patched:     BD C5 00  (JSR $C500 - call our handler)
;
; Hex editor: Go to offset 0x101E1, replace:
;   FD 01 7B  →  BD C5 00
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; PATCH 2: SPARK CUT HANDLER CODE (35 bytes)  
;------------------------------------------------------------------------------
; File Offset: 0x0C500
; Original:    00 00 00 00 00 ... (all zeros - free space)
; Patched:     (see hex below)
;
; Write these bytes starting at file offset 0x0C500:
;------------------------------------------------------------------------------

; 6000 RPM PRODUCTION VERSION:
; ============================
; Offset  | Hex                              | Instruction
; --------|----------------------------------|---------------------------
; 0C500   | 12 46 80 0B                      | BRSET $46,$80,$C50F (CHECK_RESUME)
; 0C504   | 96 A2                            | LDAA $A2 (load RPM/25)
; 0C506   | 81 F0                            | CMPA #$F0 (6000 RPM)
; 0C508   | 25 0E                            | BCS $C518 (STORE_NORMAL)
; 0C50A   | 14 46 80                         | BSET $46,$80 (set limiter flag)
; 0C50D   | 20 0D                            | BRA $C51C (INJECT_FAKE)
; 0C50F   | 96 A2                            | LDAA $A2 (CHECK_RESUME)
; 0C511   | 81 EC                            | CMPA #$EC (5900 RPM)
; 0C513   | 24 07                            | BCC $C51C (INJECT_FAKE)
; 0C515   | 15 46 80                         | BCLR $46,$80 (clear limiter flag)
; 0C518   | FD 01 7B                         | STD $017B (STORE_NORMAL)
; 0C51B   | 39                               | RTS
; 0C51C   | CC 3E 80                         | LDD #$3E80 (INJECT_FAKE)
; 0C51F   | FD 01 7B                         | STD $017B
; 0C522   | 39                               | RTS

; Complete hex string for 6000 RPM (copy/paste to hex editor):
; 12 46 80 0B 96 A2 81 F0 25 0E 14 46 80 20 0D 96 A2 81 EC 24 07 15 46 80 FD 01 7B 39 CC 3E 80 FD 01 7B 39

;------------------------------------------------------------------------------
; 3000 RPM TEST VERSION:
; ======================
; Same structure, just different thresholds:
; 0C506   | 81 78                            | CMPA #$78 (3000 RPM)
; 0C511   | 81 74                            | CMPA #$74 (2900 RPM)
;
; Complete hex string for 3000 RPM TEST:
; 12 46 80 0B 96 A2 81 78 25 0E 14 46 80 20 0D 96 A2 81 74 24 07 15 46 80 FD 01 7B 39 CC 3E 80 FD 01 7B 39

;------------------------------------------------------------------------------
; VERIFICATION AFTER PATCHING
;------------------------------------------------------------------------------
;
; 1. Read back offset 0x101E1, should show: BD C5 00
; 2. Read back offset 0x0C500, should show code bytes above
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
; 1. Offset 0x101E1: Replace BD C5 00 → FD 01 7B
; 2. Offset 0x0C500: Optional - can leave code (never called)
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
;     # Patch 1: Hook at 0x101E1
;     f.seek(0x101E1)
;     f.write(bytes([0xBD, 0xC5, 0x00]))  # JSR $C500
;     
;     # Patch 2: Code at 0x0C500 (6000 RPM version)
;     f.seek(0x0C500)
;     code = bytes([
;         0x12, 0x46, 0x80, 0x0B,  # BRSET $46,$80,$C50F
;         0x96, 0xA2,              # LDAA $A2
;         0x81, 0xF0,              # CMPA #$F0 (6000 RPM)
;         0x25, 0x0E,              # BCS STORE_NORMAL
;         0x14, 0x46, 0x80,        # BSET $46,$80
;         0x20, 0x0D,              # BRA INJECT_FAKE
;         0x96, 0xA2,              # LDAA $A2 (CHECK_RESUME)
;         0x81, 0xEC,              # CMPA #$EC (5900 RPM)
;         0x24, 0x07,              # BCC INJECT_FAKE
;         0x15, 0x46, 0x80,        # BCLR $46,$80
;         0xFD, 0x01, 0x7B,        # STD $017B (STORE_NORMAL)
;         0x39,                    # RTS
;         0xCC, 0x3E, 0x80,        # LDD #$3E80 (INJECT_FAKE)
;         0xFD, 0x01, 0x7B,        # STD $017B
;         0x39                     # RTS
;     ])
;     f.write(code)
;     
; print("Patch applied successfully!")
;
;------------------------------------------------------------------------------

            END
