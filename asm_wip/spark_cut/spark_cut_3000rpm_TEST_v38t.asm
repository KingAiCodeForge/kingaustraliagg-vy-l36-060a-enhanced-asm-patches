;==============================================================================
; VY V6 SPARK CUT - TEST MODE 3000 RPM - v38t
;==============================================================================
; Author: Jason King (kingaustraliagg)  
; Date: January 18, 2026
; Status: ✅ TEST VERSION - 3000 RPM threshold for safe validation
;
; THIS IS A TEST FILE! Uses 3000 RPM threshold so you can:
;   1. Verify the patch loads correctly
;   2. Confirm spark cut activates (rev bounces at 3000)
;   3. Monitor $0046 bit 7 via ALDL scanner
;   4. Verify no CEL codes or limp mode
;   5 could be used for launch control if proven as a second limiter setup in unused space.
;    or scraped space like chr0m3 said he tryed.
; After successful test, use spark_cut_chr0m3_method_VERIFIED_v38.asm
; with 6000 RPM production thresholds.
;
;==============================================================================

;------------------------------------------------------------------------------
; VERIFIED ADDRESSES (CORRECTED 2026-01-31)
;------------------------------------------------------------------------------
RPM_ADDR EQU $00A2       ; ✅ VERIFIED: 82 reads (8-bit RPM/25) ; Verified: RPM_DIV25 (94 refs Enhanced (96 stock). RPM = value * 25) [Enhanced-fix]
PERIOD_24X_RAM EQU $194C       ; ✅ VERIFIED: STD @ $3618 in TIC3 ISR ; Verified: CRANK_PERIOD_24X (5 refs bank 2 both. TIC3 ISR variable) [Enhanced-fix]
                                ; ❌ OLD WRONG: $017B (purpose unknown)
LIMITER_FLAGS EQU $0046       ; ✅ VERIFIED: Engine mode flags ; Verified: ENGINE_MODE_FLAGS (2 refs both bins, bits 3/6/7 free) [Enhanced-fix]
LIMITER_BIT     EQU $80         ; ✅ VERIFIED: Bit 7 is FREE

;------------------------------------------------------------------------------
; TEST THRESHOLDS - 3000 RPM
;------------------------------------------------------------------------------
RPM_HIGH        EQU $78         ; 120 × 25 = 3000 RPM - TEST THRESHOLD
RPM_LOW         EQU $74         ; 116 × 25 = 2900 RPM - 100 RPM hysteresis

;------------------------------------------------------------------------------
; FAKE PERIOD (Chr0m3 validated)
;------------------------------------------------------------------------------
FAKE_PERIOD     EQU $3E80       ; 16000 = ~100µs dwell = no spark

;------------------------------------------------------------------------------
; CODE SECTION
;------------------------------------------------------------------------------
            ORG $0C500 ; Bank 1 (file 0x0C500). Free banks: [1], used: [2, 3]. 15192 bytes free [Enhanced-fix]

SPARK_CUT_HANDLER:
    BRSET   LIMITER_FLAGS,LIMITER_BIT,CHECK_RESUME
    
    LDAA    RPM_ADDR            ; Load RPM/25
    CMPA    #RPM_HIGH           ; Compare with 3000 RPM (TEST)
    BCS     STORE_NORMAL        ; If below, normal operation
    
    BSET    LIMITER_FLAGS,LIMITER_BIT  ; Activate limiter
    BRA     INJECT_FAKE

CHECK_RESUME:
    LDAA    RPM_ADDR
    CMPA    #RPM_LOW            ; Compare with 2900 RPM
    BCC     INJECT_FAKE         ; Still above, keep cutting
    
    BCLR    LIMITER_FLAGS,LIMITER_BIT  ; Deactivate limiter

STORE_NORMAL:
    STD     PERIOD_24X_RAM      ; Store real period to $194C
    RTS

INJECT_FAKE:
    LDD     #FAKE_PERIOD        ; Load fake period
    STD     PERIOD_24X_RAM      ; Store fake period to $194C
    RTS

;==============================================================================
; TEST PROCEDURE
;==============================================================================
;
; 1. Flash this patch to ECU
; 2. Connect ALDL scanner (monitor $0046)
; 3. Start engine, let idle stabilize
; 4. Slowly increase RPM toward 3000
; 5. EXPECTED: At ~3000 RPM, engine should "bounce" (limiter active)
; 6. EXPECTED: $0046 bit 7 should toggle 0→1 at 3000, 1→0 at 2900
; 7. EXPECTED: No CEL, no limp mode, normal idle after test
;
; If test passes: Use v38 with 6000 RPM thresholds for production
; If test fails: Check hook point, verify bytes at 0x101E1 = BD C5 00
;
;==============================================================================

            END
