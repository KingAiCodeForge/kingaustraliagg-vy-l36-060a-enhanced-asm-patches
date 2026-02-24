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
; [ADDRESS FIX 2026-02-09] Enhanced v1.0a binary ground truth corrections
; Ground truth: VY_V6_Enhanced.bin + bank disassemblies (Enhanced_bank1/2/3.asm)
; Bank layout: 0=data+common, 1=free($C468-$FFBF), 2=engine, 3=trans+diag
; Bank 1 is IDENTICAL between stock and Enhanced (0 bytes differ)
;==============================================================================
;==============================================================================
; THE1'S SPARK CUT METHOD - PORTED TO $060A
;==============================================================================
; Source: The1's Enhanced v1.1a binary (addresses 0x1FD84-0x1FD9F)
; Target: VY V6 $060A Enhanced v1.0a binary
; Method: Direct threshold comparison with EST flag manipulation
;
; The1's Implementation Analysis:
; - Uses CPD (Compare D, non-destructive) instead of SUBD
; - Reads 16-bit RPM from $9D (not $A2!)
; - Compares against TABLE at $78B2 (not immediate value)
; - Manipulates EST control flags at $149E and $16FA
; - Calls EST subroutine at $31EF
;
; Adaptation Strategy:
; 1. Find equivalent hook point in $060A
; 2. Map $060A's EST control addresses
; 3. Port The1's logic structure
; 4. Maintain CPD comparison pattern
;
; Author: Jason King (kingaustraliagg)
; Date: January 20, 2026
; Status: RESEARCH - Needs address mapping
;==============================================================================

;------------------------------------------------------------------------------
; THE1'S ORIGINAL CODE (Enhanced v1.1a @ 0x1FD84)
;------------------------------------------------------------------------------
; 1FD84  DC 9D          LDD      $9D             ; Load 16-bit RPM
; 1FD86  1A B3 78 B2    CPD      $78B2           ; Compare with threshold table
; 1FD8A  23 13          BLS      $1FD9F          ; Branch if RPM ≤ threshold
; 1FD8C  FC 14 9E       LDD      $149E           ; RPM > threshold: Load EST flags
; 1FD8F  C4 FE          ANDB     #$FE            ; Clear bit 0 in B
; 1FD91  FD 14 9E       STD      $149E           ; Store modified flags
; 1FD94  FC 16 FA       LDD      $16FA           ; Load another EST control word
; 1FD97  CA FF          ORAB     #$FF            ; Set all bits (activate cut)
; 1FD99  FD 16 FA       STD      $16FA           ; Store modified control
; 1FD9C  BD 31 EF       JSR      $31EF           ; Call EST control subroutine
; 1FD9F  0F             SEI                      ; Continue: Disable interrupts

;------------------------------------------------------------------------------
; $060A ADDRESS MAPPING (TO BE VERIFIED)
;------------------------------------------------------------------------------
; The1's Binary    | $060A Equivalent | Description
; -----------------|------------------|----------------------------------
; $9D              | ???              | 16-bit RPM storage (FIND THIS!)
; $78B2            | ???              | Threshold table pointer
; $149E            | ???              | EST control flags 1
; $16FA            | ???              | EST control flags 2
; $31EF            | ???              | EST control subroutine
; Hook point       | 0x101E1?         | Where to inject (verify!)

;------------------------------------------------------------------------------
; ADAPTATION STRATEGY
;------------------------------------------------------------------------------
; Option 1: DIRECT PORT (if addresses match)
;   - Find $060A's 16-bit RPM location
;   - Find EST control flag addresses
;   - Copy The1's logic exactly
;
; Option 2: HYBRID (combine with Chr0m3 method)
;   - Use The1's CPD comparison
;   - Use Chr0m3's crank period injection
;   - Best of both worlds
;
; Option 3: SIMPLIFIED (verified addresses only)
;   - Use CPD with known RPM address
;   - Skip EST flag manipulation (unverified)
;   - Inject fake period like Chr0m3

;==============================================================================
; IMPLEMENTATION OPTIONS
;==============================================================================

;------------------------------------------------------------------------------
; OPTION 1: PURE THE1 METHOD (UNVERIFIED - NEEDS ADDRESS MAPPING)
;------------------------------------------------------------------------------
; This would require finding ALL equivalent addresses in $060A

    ORG $C468          ; Bank 1 free space (file 0x0C468, 15192 bytes free $C468-$FFBF)
                       ; ⚠️ The1's addresses ($149E, $16FA, $31EF) are from v1.1a — NOT mapped to $060A!

THE1_METHOD_ENTRY:
    ; Load 16-bit RPM (NEED TO FIND THIS ADDRESS!)
    LDD     $????       ; 16-bit RPM in $060A (NOT $00A2!)
    
    ; Compare with threshold (NEED TO VERIFY TABLE LOCATION!)
    CPD     $????       ; Threshold table address
    BLS     SKIP_CUT    ; Branch if RPM ≤ threshold
    
    ; Activate spark cut (NEED EST FLAG ADDRESSES!)
    LDD     $????       ; EST control flags 1
    ANDB    #$FE        ; Clear bit 0
    STD     $????       ; Store back
    
    LDD     $????       ; EST control flags 2
    ORAB    #$FF        ; Set all bits
    STD     $????       ; Store back
    
    ; Call EST control (NEED SUBROUTINE ADDRESS!)
    JSR     $????       ; EST control routine
    
SKIP_CUT:
    ; Continue normal execution
    RTS

;------------------------------------------------------------------------------
; OPTION 2: HYBRID METHOD (The1's CPD + Chr0m3's Period Injection)
;------------------------------------------------------------------------------
; Uses verified addresses from v38, The1's comparison pattern

    ORG $C530           ; Bank 1 free space (file 0x0C530) — offset from Option 1 to avoid overlap
                       ; ⚠️ This hooks 0x101E1 (STD $017B) but stores to $194C — INCONSISTENT

HYBRID_ENTRY:
    ; Check if already cutting
    BRSET   $46,$80,CHECK_RESUME
    
    ; Load RPM for comparison
    LDAA    $A2         ; 8-bit RPM/25
    LDAB    #$00        ; Clear B
    XGDX                ; Save in X
    
    ; Convert to 16-bit for CPD
    LDAA    $A2
    LDAB    #$19        ; Multiply by 25
    MUL                 ; D = RPM in real units
    
    ; Compare using CPD (The1's method)
    CPD     #$1770      ; 6000 RPM threshold
    BLS     STORE_NORMAL
    
    ; Activate cut
    BSET    $46,$80     ; Set flag
    BRA     INJECT_FAKE
    
CHECK_RESUME:
    LDAA    $A2
    LDAB    #$00
    LDAA    $A2
    LDAB    #$19
    MUL
    CPD     #$1716      ; 5900 RPM resume
    BCC     INJECT_FAKE
    
    BCLR    $46,$80     ; Clear flag
    
STORE_NORMAL:
    STD     $017B       ; Store to dwell intermediate (matches hook at 0x101E1)
    RTS
    
INJECT_FAKE:
    LDD     #$3E80      ; Fake dwell value (16000 = ~100µs dwell = no spark)
    STD     $017B       ; Store fake value to dwell intermediate
    RTS

;------------------------------------------------------------------------------
; OPTION 3: SIMPLIFIED CPD METHOD (Verified Addresses Only)
;------------------------------------------------------------------------------
; Safest option - uses only confirmed addresses

    ORG $C560           ; Bank 1 free space (file 0x0C560) — offset to avoid Option 1+2 overlap

SIMPLE_CPD_ENTRY:
    ; Load 8-bit RPM, convert to 16-bit
    LDAA    $A2         ; RPM/25 (verified)
    LDAB    #$00        ; Clear B for 16-bit
    
    ; Multiply to get real RPM
    PSHA                ; Save A
    LDAB    #$19        ; 25 in hex
    MUL                 ; D = A * 25 = RPM
    
    ; Compare with threshold using CPD
    CPD     #$1770      ; 6000 RPM = 0x1770
    BLS     NORMAL_OPERATION
    
    ; RPM above threshold - inject fake period
    LDD     #$3E80      ; 16000 = fake dwell value = ~100µs = no spark
    STD     $017B       ; Store to dwell intermediate ($017B)
    PULA                ; Clean stack
    RTS
    
NORMAL_OPERATION:
    PULA                ; Restore A
    LDAB    #$00        ; Clear B
    STD     $017B       ; Store to dwell intermediate ($017B)
    RTS

;==============================================================================
; HOOK INSTALLATION
;==============================================================================
; File offset 0x101E1 (bank 2, CPU $81E1)
; Original: FD 01 7B  (STD $017B — dwell intermediate, runs every cycle)
; Patched:  BD C5 00  (JSR $C500 — or $C530/$C560 for options 2/3)
;
; ❌ DO NOT USE 0x13618 (STD $194C = cold-start init path only)
; OFFSET: 0x101E1
; ORIGINAL: FD 01 7B        (STD $017B — dwell intermediate)
; PATCHED:  BD C5 00        (JSR $C500)

;==============================================================================
; NOTES FOR ADDRESS DISCOVERY
;==============================================================================
; To complete The1's method port, find these in $060A disassembly:
;
; 1. 16-bit RPM Location:
;    - Search for: LDD of RPM value
;    - Look for: Addresses read frequently in main loop
;    - Check: SPI/ADC result storage locations
;
; 2. EST Control Flags:
;    - Search for: Ignition timing calculations
;    - Look for: Dwell control code
;    - Check: Timer output compare register usage
;
; 3. EST Control Subroutine:
;    - Search for: JSR to EST routines
;    - Look for: TCTL1/TCTL2 register manipulation
;    - Check: PA5 (EST output) control code
;
; 4. Threshold Table:
;    - Search for: CPD instructions in limiter code
;    - Look for: Data tables near known calibration areas
;    - Check: XDF v2.09a for limiter threshold locations
;
;==============================================================================
; STATUS: RESEARCH ONLY
; DO NOT USE WITHOUT COMPLETING ADDRESS MAPPING!
;==============================================================================
