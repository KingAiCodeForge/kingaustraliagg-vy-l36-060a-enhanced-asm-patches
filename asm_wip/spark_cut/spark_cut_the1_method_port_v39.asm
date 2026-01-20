;==============================================================================
; THE1'S SPARK CUT METHOD - PORTED TO $060A
;==============================================================================
; Source: The1's Enhanced v1.1a binary (addresses 0x1FD84-0x1FD9F)
; Target: VY V6 $060A (92118883) stock binary
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
;   - Use Chr0m3's 3X period injection
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

    ORG $14468          ; Candidate free space (verify!)

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

    ORG $C500           ; Verified free space

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
    STD     $017B       ; Store real period
    RTS
    
INJECT_FAKE:
    LDD     #$3E80      ; Fake period (16000)
    STD     $017B
    RTS

;------------------------------------------------------------------------------
; OPTION 3: SIMPLIFIED CPD METHOD (Verified Addresses Only)
;------------------------------------------------------------------------------
; Safest option - uses only confirmed addresses

    ORG $C500           ; Verified free space

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
    LDD     #$3E80      ; 16000 = very long period = no spark
    STD     $017B       ; Store to period (verified)
    PULA                ; Clean stack
    RTS
    
NORMAL_OPERATION:
    PULA                ; Restore A
    LDAB    #$00        ; Clear B
    STD     $017B       ; Store period (from original code)
    RTS

;==============================================================================
; HOOK INSTALLATION (Same as v38)
;==============================================================================
; Replace STD $017B at 0x101E1 with JSR $C500

; OFFSET: 0x101E1
; ORIGINAL: FD 01 7B        (STD $017B)
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
