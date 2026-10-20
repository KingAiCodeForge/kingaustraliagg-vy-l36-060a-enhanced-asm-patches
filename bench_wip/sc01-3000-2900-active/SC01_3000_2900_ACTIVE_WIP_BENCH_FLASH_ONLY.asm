; KingAI authored patch source: SC01_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
    ORG $5D05
    JSR $5D0C
    JSR $FD84
    RTS
    PSHA
    PSHB
    PSHX
    TPA
    PSHA
    SEI
    LDAA $5EF4
    CMPA #$A5
    BNE $5D77
    BRSET $29,#$80,$5D77
    BRCLR $51,#$80,$5D77
    BRCLR $51,#$40,$5D77
    BRCLR $46,#$01,$5D77
    LDAA $19
    BITA #$60
    BNE $5D77
    LDAA $48
    BITA #$91
    BNE $5D77
    LDD $5EF0
    CPD #$05DC
    BLO $5D77
    CPD #$16A8
    BHI $5D77
    LDD $5EF2
    CPD #$03E8
    BLO $5D77
    CPD $5EF0
    BHS $5D77
    LDAA $16FA
    NOP
    LDD $16FA
    BITB #$04
    BEQ $5D77
    BRSET $66,#$40,$5D6F
    LDD $9D
    CPD $5EF0
    BLO $5D7A
    BSET $66,#$40
    BRA $5D7A
    LDD $9D
    CPD $5EF2
    BHI $5D7A
    BCLR $66,#$40
    PULA
    TAP
    PULX
    PULB
    PULA
    RTS
    BRCLR $66,#$40,$5DD9
    BRSET $66,#$80,$5DD9
    PSHA
    PSHB
    PSHX
    TPA
    PSHA
    SEI
    LDAA $14D6
    NOP
    LDD $14D6
    BITA #$40
    BNE $5DD3
    BITB #$10
    BNE $5DD3
    LDAA $149E
    NOP
    LDD $149E
    BITB #$01
    BEQ $5DD3
    ANDB #$FE
    STD $149E
    LDX #$0010
    DEX
    BNE $5DB0
    LDAA $14D6
    NOP
    LDD $14D6
    BITA #$40
    BNE $5DC7
    BITB #$10
    BNE $5DC7
    BSET $66,#$80
    BRA $5DD3
    LDAA $149E
    NOP
    LDD $149E
    ORAB #$01
    STD $149E
    PULA
    TAP
    PULX
    PULB
    PULA
    RTS
    RTS
    LDAA $1B8C
    CMPA #$04
    BHS $5DE4
    BCLR $66,#$40
    BRSET $66,#$40,$5DF4
    BRCLR $66,#$80,$5E04
    BCLR $66,#$80
    BCLR $44,#$10
    BRA $5E04
    JSR $5D80
    BRCLR $66,#$80,$5E04
    LDAA $1B8C
    CLR $1B8C
    JMP $3328
    LDAA $1B8C
    CLR $1B8C
    JMP $31E8
    JSR $5D80
    BRCLR $66,#$80,$5E17
    JMP $3719
    BRCLR $46,#$01,$5E1E
    JMP $360E
    JMP $361C
    BRCLR $66,#$80,$5E4F
    PSHA
    PSHB
    PSHX
    TPA
    PSHA
    SEI
    LDAA $19
    BITA #$60
    BNE $5E4A
    LDAA $48
    BITA #$90
    BNE $5E4A
    CLR $1912
    LDAA $14C8
    NOP
    LDD $14C8
    STD $01B5
    PULA
    TAP
    PULX
    PULB
    PULA
    RTS
    PULA
    TAP
    PULX
    PULB
    PULA
    JMP $FE32
        ORG $5EF0
        FCB $0B,$B8,$0B,$54,$A5
