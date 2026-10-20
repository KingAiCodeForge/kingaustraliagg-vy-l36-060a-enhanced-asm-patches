; KingAI authored patch source: CP1_6000_OSE_VALUE_0019_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
        OPT H11
        ORG $5D05
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        TSX
        LDAA   $00A2
        CMPA   $5D30
        BCS    normal
        LDD    1,X
        CPD    $5D32
        BLS    store
        LDD    $5D32
        BRA    store
normal:
        LDD    1,X
store:
        STD    $1444
        PULA
        TAP
        TSX
        LDD    0,X
        INS
        INS
        PULX
        RTS
        ORG $5D30
        FCB $F0
        ORG $5D32
        FDB $0019
