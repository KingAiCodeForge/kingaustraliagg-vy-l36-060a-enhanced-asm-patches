; KingAI authored patch source: R61_3000_2900_ACTIVE_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
        ORG $FE87
POLICY:
    PSHB
    PSHA
    TPA
    PSHA
    JSR ELIGIBLE
    BCS ALLOW
    LDD <$9D
    CPD >$FFB2
    BCC INHIBIT
    CPD >$FFB4
    BLS ALLOW
    BRCLR $66,$08,INHIBIT
ALLOW:
    BSET $66,$08
    BRA POLICY_DONE
INHIBIT:
    BCLR $66,$08
POLICY_DONE:
    PULA
    TAP
    LDAA <$66
    ORAA #$08
    PULA
    PULB
    RTS
M42_WRAPPER:
    PSHX
    PSHB
    PSHA
    TPA
    PSHA
    LDAA >$FFB1
    CMPA #$01
    BNE M42_STOCK
    JSR ELIGIBLE
    BCS M42_STOCK
    BRSET $66,$08,M42_STOCK
    LDD <$9D
    CPD >$FFB4
    BLS M42_STOCK
    LDD >$019B
    BNE M42_STOCK
    SEI
    LDAA >$14C8
    NOP
    LDX >$14C8
    STX >$01B5
    CLR >$1912
    PULA
    TAP
    PULA
    PULB
    PULX
    RTS
M42_STOCK:
    PULA
    TAP
    PULA
    PULB
    PULX
    JMP $FE32
ELIGIBLE:
    LDAA >$FFB0
    CMPA #$01
    BNE INELIGIBLE
    LDD >$FFB4
    CPD #$03E8
    BCS INELIGIBLE
    CPD >$FFB2
    BCC INELIGIBLE
    LDD >$FFB2
    CPD #$16A8
    BHI INELIGIBLE
    BRSET $29,$80,INELIGIBLE
    BRCLR $51,$80,INELIGIBLE
    BRCLR $53,$08,INELIGIBLE
    BRCLR $46,$01,INELIGIBLE
    BRCLR $44,$10,INELIGIBLE
    BRSET $05,$08,INELIGIBLE
    BRSET $3D,$80,INELIGIBLE
    LDAA <$48
    BITA #$90
    BNE INELIGIBLE
    LDAA <$19
    BITA #$60
    BNE INELIGIBLE
    LDAA >$1BF9
    CMPA #$01
    BNE INELIGIBLE
    CLC
    RTS
INELIGIBLE:
    SEC
    RTS
        ORG $FFB0
        FCB $01,$01,$0B,$B8,$0B,$54,$4B,$41,$49,$2D,$52,$36,$31,$00,$00,$00
