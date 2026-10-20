; KingAI authored patch source: SCZ2_IGNITION_ONLY_3000RPM_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
        ORG $5D05
write_dwell:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        SEI
        TSX
        JSR cut_requested
        BEQ dwell_normal
        LDD #$0000
        STD $144A
        NOP
        NOP
        STD $1444
        BRA store_done
dwell_normal:
        LDD #$00A4
        STD $144A
        LDD 1,X
        STD $1444
store_done:
        PULA
        TAP
        TSX
        LDD 0,X
        INS
        INS
        PULX
        RTS
        ORG $5D50
write_minimum:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        SEI
        TSX
        JSR cut_requested
        BEQ minimum_normal
        LDD #$0000
        STD $144A
        BRA minimum_done
minimum_normal:
        LDD 1,X
        STD $144A
minimum_done:
        PULA
        TAP
        TSX
        LDD 0,X
        INS
        INS
        PULX
        RTS
        ORG $5D90
write_manual_rise:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        SEI
        TSX
        JSR cut_requested
        BNE rise_done
        LDX 3,X
        STX $15EA
rise_done:
        PULA
        TAP
        PULA
        PULB
        PULX
        PSHX
        TSX
        LDX 0,X
        INS
        INS
        RTS
        ORG $5DC0
qualify_missing_edges:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        SEI
        JSR cut_requested
        BEQ timer_normal
        LDAA $1444
        NOP
        LDD $1444
        BNE timer_normal
        LDAA $144A
        NOP
        LDD $144A
        BNE timer_normal
        PULA
        TAP
        PULA
        PULB
        PULX
        LDAA #$00
        RTS
timer_normal:
        PULA
        TAP
        PULA
        PULB
        PULX
        LDAA $1912
        INCA
        RTS
        ORG $5E10
cut_requested:
        LDAA $5EA0
        CMPA #$A5
        BNE no_cut
        LDAA $5EA1
        CMPA #$5A
        BNE no_cut
        LDAA $5EA3
        CMPA #$02
        BNE no_cut
        LDAA $5EA4
        CMPA #$01
        BHI no_cut
        LDAA $5EA2
        CMPA #$28
        BCS no_cut
        CMPA #$E8
        BHI no_cut
        LDAA <$A2
        CMPA $5EA2
        BCS no_cut
        BRCLR $46,$01,no_cut
        BRCLR $44,$10,no_cut
        BRCLR $53,$08,no_cut
        LDAA <$48
        BITA #$91
        BNE no_cut
        LDAA <$19
        BITA #$60
        BNE no_cut
        LDAA $1BF9
        CMPA #$01
        BNE no_cut
        LDAA $1BFA
        BNE no_cut
        LDAA #$01
        RTS
no_cut:
        LDAA #$00
        RTS
        ORG $5EA0
        FCB $A5,$5A,$78,$02,$00
        ORG $5EB0
optional_fuel_action:
        PSHX
        PSHB
        PSHA
        TPA
        PSHA
        SEI
        JSR cut_requested
        BEQ fuel_normal
        LDAA $5EA4
        CMPA #$01
        BNE fuel_normal
        PULA
        TAP
        PULA
        PULB
        PULX
        JMP $A5C0
fuel_normal:
        PULA
        TAP
        PULA
        PULB
        PULX
        BCLR $5F,$40
        JMP $A5D8
