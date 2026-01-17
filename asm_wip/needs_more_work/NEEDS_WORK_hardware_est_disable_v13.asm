;==============================================================================
; VY V6 IGNITION CUT v13 - HARDWARE EST DISABLE (BennVenn-Inspired)
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 13, 2026
; Inspiration: BennVenn's OSE12P Hardware Spark Cut (topic_7922)
; Target: Holden VY V6 (OSID 92118883)
; Binary: VX-VY_V6_$060A_Enhanced_v1.0a.bin
; Processor: Motorola MC68HC11
;
; Description:
;   Attempts to implement hardware-level EST disable similar to BennVenn's
;   OSE12P discovery where bit 1 at $3FFC controls EST output.
;
;   On 808 (OSE12P): Setting bit 1 at $3FFC disables EST pulse
;   On HC11 (VY V6): Need to find equivalent register/bit
;
; Based On: BennVenn's OSE12P research (July 2022)
; Status: 🔬 EXPERIMENTAL - Hardware registers unknown
;
; BennVenn's Discovery (OSE12P):
;   > "Bit 1 at $3FFC is the master timer enable disable bit. Setting the
;   > bit high will not output an EST pulse."
;
; HC11 Equivalent Research:
;   - Output Compare 3 (OC3) likely controls EST on PA5
;   - TCTL1 register ($1020) controls OC3 output action
;   - Possible approach: Force OC3 output LOW or disconnect
;
; ⚠️ WARNING: This is THEORETICAL - HC11 may not have same hardware feature
; ⚠️ DO NOT FLASH without oscilloscope validation by Chr0m3 or expert
; some one learn how to update these or push other .asm version 
  please that would work better please to the github..... 6000rpm is better for now. 8bit probably better to for under 6375rpm.
;==============================================================================

;------------------------------------------------------------------------------
; MEMORY MAP
;------------------------------------------------------------------------------
RPM_ADDR            EQU $00A2       ; RPM address

; HC11 TIMER REGISTERS (Hardware - confirmed addresses)
TCTL1               EQU $1020       ; Timer Control Register 1 (OC2-OC5)
TCTL2               EQU $1021       ; Timer Control Register 2 (OC1, OC3)
TMSK1               EQU $1022       ; Timer Mask Register 1
TFLG1               EQU $1023       ; Timer Flag Register 1
OC3_DATA            EQU $1031       ; Output Compare 3 data register
PORTA               EQU $1000       ; Port A data register (PA5 = OC3/EST)

; RPM THRESHOLDS (SAFE DEFAULT - 6000 RPM)
RPM_HIGH            EQU $1770       ; 6000 RPM activation
RPM_LOW             EQU $175C       ; 5980 RPM deactivation

;------------------------------------------------------------------------------
; TCTL1 REGISTER BIT DEFINITIONS
;------------------------------------------------------------------------------
; TCTL1 controls OC2, OC3, OC4, OC5 output actions
; Bits 5-4: OC3M (Output Compare 3 Mode)
;   00 = OC3 disconnected from PA5
;   01 = Toggle PA5 on successful compare
;   10 = Clear PA5 to 0 on successful compare
;   11 = Set PA5 to 1 on successful compare

OC3M_DISCONNECT     EQU %00000000   ; Bits 5-4 = 00 (disconnect)
OC3M_TOGGLE         EQU %00010000   ; Bits 5-4 = 01 (toggle)
OC3M_CLEAR          EQU %00100000   ; Bits 5-4 = 10 (force LOW)
OC3M_SET            EQU %00110000   ; Bits 5-4 = 11 (force HIGH)
OC3M_MASK           EQU %11001111   ; Mask for OC3M bits

;==============================================================================
; HARDWARE EST DISABLE METHOD (BennVenn-Inspired)
;==============================================================================
; ⚠️ ADDRESS CORRECTED 2026-01-15: $18156 was WRONG (contains active code)
; ✅ VERIFIED FREE SPACE: File 0x0C468-0x0FFBF = 15,192 bytes of 0x00
            ORG $14468          ; Free space VERIFIED (was $18156 WRONG!)

EST_DISABLE_HANDLER:
    PSHA
    PSHB
    
    ; Check RPM
    LDD     RPM_ADDR
    CPD     #RPM_HIGH
    BHS     DISABLE_EST         ; RPM >= 6000, disable EST
    
    CPD     #RPM_LOW
    BLO     ENABLE_EST          ; RPM < 5980, enable EST
    
    ; In hysteresis zone - maintain current state
    BRA     EXIT_HANDLER

DISABLE_EST:
    ; Method 1: Force OC3 output LOW (no EST pulses)
    LDAA    TCTL1
    ANDA    #OC3M_MASK          ; Clear OC3M bits
    ORAA    #OC3M_CLEAR         ; Set OC3M = 10 (force LOW)
    STAA    TCTL1
    
    ; Optional: Also force PA5 LOW directly
    LDAA    PORTA
    ANDA    #%11011111          ; Clear bit 5 (PA5/EST)
    STAA    PORTA
    
    BRA     EXIT_HANDLER

ENABLE_EST:
    ; Restore normal OC3 operation (toggle mode for EST pulses)
    LDAA    TCTL1
    ANDA    #OC3M_MASK          ; Clear OC3M bits
    ORAA    #OC3M_TOGGLE        ; Set OC3M = 01 (toggle)
    STAA    TCTL1
    
    ; Fall through to exit

EXIT_HANDLER:
    PULB
    PULA
    RTS

;==============================================================================
; ALTERNATIVE METHOD: OC3 DISCONNECT
;==============================================================================
;
; Instead of forcing LOW, disconnect OC3 from PA5 entirely
;
; DISABLE_EST_ALT:
;     LDAA    TCTL1
;     ANDA    #OC3M_MASK          ; Clear OC3M bits
;     ORAA    #OC3M_DISCONNECT    ; Set OC3M = 00 (disconnect)
;     STAA    TCTL1
;     RTS
;
; Problem: PA5 may float or maintain last state
; Solution: Also force PA5 LOW via PORTA register
;
;==============================================================================

;==============================================================================
; COMPARISON: OSE12P vs HC11
;==============================================================================
;
; OSE12P (808 Processor):
;   - Single bit at $3FFC controls EST globally
;   - Set bit 1 = disable EST
;   - Clear bit 1 = enable EST
;   - Hardware-level control
;
; VY V6 (HC11 Processor):
;   - TCTL1 register controls Output Compare actions
;   - OC3M bits (5-4) control PA5/EST pin behavior
;   - 00 = disconnect, 01 = toggle, 10 = force LOW, 11 = force HIGH
;   - More granular control than 808
;
; Key Difference:
;   808: Single master enable/disable bit (simpler)
;   HC11: Per-channel output control (more flexible)
;
;==============================================================================

;==============================================================================
; VALIDATION REQUIREMENTS
;==============================================================================
;
; ⚠️ CRITICAL: This code is THEORETICAL and requires hardware validation
;
; Before bench testing:
;   1. Verify OC3 is actually used for EST signal
;   2. Confirm TCTL1 address is $1020 for VY V6 ECU
;   3. Check if forcing OC3 LOW triggers failsafe/bypass mode
;   4. Oscilloscope on EST pin (PCM Pin B3 WHITE wire)
;
; Validation Steps:
;   1. Monitor EST signal with oscilloscope
;   2. Rev engine to 5900 RPM (below limiter)
;   3. Check: EST pulses present, normal operation
;   4. Rev engine to 6000 RPM (at limiter)
;   5. Check: EST pulses stop, no spark
;   6. Check: No DTC codes, no bypass mode activation
;   7. Rev engine back to 5980 RPM (hysteresis)
;   8. Check: EST pulses resume normally
;
; If failsafe triggers:
;   - ECU may have ESTLOOP timer like OSE12P
;   - Need to find and bypass timer overflow check
;   - See Method v14 (ESTLOOP Timer Bypass)
;
;==============================================================================

;==============================================================================
; ADVANTAGES vs 3X PERIOD METHOD
;==============================================================================
;
; Hardware EST Disable (This Method):
;   ✅ Direct hardware control (no calculation tricks)
;   ✅ Cleaner implementation (single register write)
;   ✅ Faster response time (immediate)
;   ✅ No interference with dwell/timing calculations
;   ⚠️ May trigger failsafe if ESTLOOP timer exists
;
; 3X Period Injection (Method v1-v3):
;   ✅ Proven working (Chr0m3 validated)
;   ✅ No hardware manipulation (software trick)
;   ✅ No failsafe triggered (uses existing firmware logic)
;   ⚠️ More complex (manipulates dwell calculation)
;
; Recommendation:
;   - Stick with 3X Period method (proven)
;   - Test this method on bench ONLY
;   - Requires expert validation (Chr0m3 or VL400)
;
;==============================================================================

;==============================================================================
; BennVenn's ESTLOOP Timer Insight (OSE12P)
;==============================================================================
;
; BennVenn's Quote:
;   > "It looks like 12p code is checking the ESTLOOP timer and if it doesn't
;   > see the pulse it triggers EST bypass mode. The code below flips the bit
;   > every other reference pulse to keep 12P from forcing bypass mode."
;
; Workaround for OSE12P:
;   - Toggle EST enable every other crank reference pulse
;   - Keeps ESTLOOP timer from timing out
;   - 50% spark cut (fires every other cylinder)
;
; Better Solution (BennVenn suggests):
;   > "If we modify the ESTLOOP timer code to ignore an overflow while spark
;   > cut is enabled, the ECU shouldn't go into EST bypass and instead do a
;   > real spark cut for as long as we ask it."
;
; For VY V6:
;   - Need to find if HC11 has similar ESTLOOP timer
;   - If yes, implement bypass like BennVenn suggests
;   - If no, hardware EST disable should work directly
;
;==============================================================================

;==============================================================================
; THEORY: Why This Might Work on HC11
;==============================================================================
;
; HC11 Timer Subsystem:
;   - Output Compare channels generate timed outputs
;   - TCTL1/TCTL2 registers control output actions
;   - Can force output HIGH, LOW, toggle, or disconnect
;
; EST Signal Generation (Suspected):
;   1. Firmware calculates spark timing
;   2. Sets OC3 compare register for spark trigger time
;   3. OC3 toggles PA5 when timer matches compare value
;   4. DFI module sees toggle → fires coil
;
; By Forcing OC3 LOW:
;   - OC3 compare still occurs (firmware thinks it's working)
;   - But PA5 stays LOW (no toggle)
;   - DFI module sees flat signal → no spark trigger
;   - Result: Clean spark cut
;
; Potential Problem:
;   - Firmware may check for EST pulse feedback
;   - If no pulse detected → trigger bypass mode
;   - Solution: Find and bypass feedback check
;
;==============================================================================

;==============================================================================
; HOOK POINT SUGGESTIONS
;==============================================================================
;
; Option 1: Main loop timer routine (called every 12.5ms)
;   - Safe, non-critical timing
;   - Good for checking RPM and updating EST state
;
; Option 2: Reference pulse interrupt (called every crank reference)
;   - Faster response
;   - Risk: Tight timing constraints
;
; Option 3: RPM calculation routine (called after RPM update)
;   - Logical place (RPM just updated)
;   - Low overhead
;
; Recommendation: Option 1 or 3 for initial testing
;
;==============================================================================
