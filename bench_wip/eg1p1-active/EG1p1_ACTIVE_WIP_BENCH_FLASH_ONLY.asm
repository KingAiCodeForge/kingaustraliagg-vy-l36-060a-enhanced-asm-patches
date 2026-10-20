; KingAI authored patch source: EG1p1_ACTIVE_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
        OPT H11
        ORG $5D05
EG1_EVENT:
        PSHA
        PSHB
        TPA
        PSHA
        SEI
        LDAA   $5EF0
        CMPA   #$0001
        BNE    EG1_EVENT_native
        LDAA   $0019
        BITA   #$0060
        BNE    EG1_EVENT_native
        BRCLR  $46,#$01,EG1_EVENT_native
        LDD    $009D
        CPD    $5EF2
        BCS    EG1_EVENT_native
        LDAA   $1B8C
        CMPA   #$0004
        BCS    EG1_EVENT_native
        LDAA   $16FA
        NOP
        LDD    $16FA
        ANDB   #$0005
        CMPB   #$0005
        BNE    EG1_EVENT_native
        LDAA   $149E
        NOP
        LDD    $149E
        BITB   #$0002
        BNE    EG1_EVENT_native
        ANDB   #$00FE
        STD    $149E
        CLR    $1B8C
        BCLR   $44,#$10
        PULA
        TAP
        PULB
        PULA
        JMP    $3328
EG1_EVENT_native:
        PULA
        TAP
        PULB
        PULA
        LDAA   $1B8C
        JMP    $31E5
        ORG $5DA0
EG1_DIAG:
        PSHA
        PSHB
        TPA
        PSHA
        SEI
        LDAA   $5EF0
        CMPA   #$0001
        BNE    EG1_DIAG_stock
        LDAA   $0019
        BITA   #$0060
        BNE    EG1_DIAG_stock
        BRCLR  $46,#$01,EG1_DIAG_stock
        LDD    $009D
        CPD    $5EF2
        BCS    EG1_DIAG_stock
        BRSET  $44,#$10,EG1_DIAG_stock
        LDAA   $16FA
        NOP
        LDD    $16FA
        ANDB   #$0005
        CMPB   #$0005
        BNE    EG1_DIAG_stock
        LDAA   $149E
        NOP
        LDD    $149E
        ANDB   #$0003
        BNE    EG1_DIAG_stock
        CLR    $1912
        LDAA   $14C8
        NOP
        LDD    $14C8
        STD    $01B5
        PULA
        TAP
        PULB
        PULA
        RTS
EG1_DIAG_stock:
        PULA
        TAP
        PULB
        PULA
        JMP    $FE32
        ORG $5E10
EG1_REF18:
        PSHA
        PSHB
        TPA
        PSHA
        SEI
        BRSET  $44,#$10,EG1_REF18_native_exit
        LDAA   $5EF0
        CMPA   #$0001
        BNE    EG1_REF18_native_crank
        LDAA   $0019
        BITA   #$0060
        BNE    EG1_REF18_native_crank
        BRCLR  $46,#$01,EG1_REF18_native_crank
        LDD    $009D
        CPD    $5EF2
        BCS    EG1_REF18_native_crank
        LDAA   $16FA
        NOP
        LDD    $16FA
        ANDB   #$0005
        CMPB   #$0005
        BNE    EG1_REF18_native_crank
        LDAA   $149E
        NOP
        LDD    $149E
        ANDB   #$0003
        BNE    EG1_REF18_native_crank
EG1_REF18_native_exit:
        PULA
        TAP
        PULB
        PULA
        JMP    $3616
EG1_REF18_native_crank:
        PULA
        TAP
        PULB
        PULA
        JMP    $361C
        ORG $5EF0
        FCB $01
        ORG $5EF2
        FDB $0BB8
        ORG $31E2
        JMP EG1_EVENT
        ORG $3612
        JMP EG1_REF18
        NOP
        ORG $FD93
        JSR EG1_DIAG
