; KingAI authored patch source: FDC1_3000_2900_SHORT_RAW000A_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
        ORG $5D05
DWELL_WRITE:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        TSX
        JSR UPDATE_STATE
        BRCLR $66,#$40,NORMAL_DWELL
        LDD 1,X
        CPD $5EE4
        BLS CLAMP_READY
        LDD $5EE4
CLAMP_READY:
        STD $144A
        NOP
        STD $1444
        BRA RESTORE
NORMAL_DWELL:
        LDD #$00A4
        STD $144A
        NOP
        LDD 1,X
        STD $1444
RESTORE:
        PULA
        TAP
        TSX
        LDD 0,X
        INS
        INS
        PULX
        RTS
FLOOR_REFRESH:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        TSX
        LDAA $5EE0
        CMPA #$01
        BNE REFRESH_DISABLE
        BRCLR $51,#$80,REFRESH_DISABLE
        BRSET $29,#$80,REFRESH_DISABLE
        BRSET $66,#$40,RESTORE
        BRA REFRESH_NATIVE
REFRESH_DISABLE:
        BCLR $66,#$40
REFRESH_NATIVE:
        LDD 1,X
        STD $144A
        BRA RESTORE
FLOOR_INIT:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        TSX
        BCLR $66,#$40
        LDD 1,X
        STD $144A
        BRA RESTORE
UPDATE_STATE:
        LDAA $5EE0
        CMPA #$01
        BNE STATE_OFF
        BRCLR $51,#$80,STATE_OFF
        BRSET $29,#$80,STATE_OFF
        LDD $5EE8
        CPD #$FDC1
        BNE STATE_OFF
        LDD $5EE4
        CPD #$0027
        BHI STATE_OFF
        LDAA $5EE1
        CMPA #$28
        BCS STATE_OFF
        CMPA #$E8
        BHI STATE_OFF
        LDAB $5EE2
        CMPB #$14
        BCS STATE_OFF
        CBA
        BLS STATE_OFF
        LDAA $00A2
        BRCLR $66,#$40,CHECK_ENTRY
        CMPA $5EE2
        BLS STATE_OFF
        BRA STATE_ON
CHECK_ENTRY:
        CMPA $5EE1
        BCS STATE_OFF
STATE_ON:
        BSET $66,#$40
        RTS
STATE_OFF:
        BCLR $66,#$40
        RTS
        ORG $5EE0
        FCB $01,$78,$74,$01,$00,$0A,$00,$00,$FD,$C1
