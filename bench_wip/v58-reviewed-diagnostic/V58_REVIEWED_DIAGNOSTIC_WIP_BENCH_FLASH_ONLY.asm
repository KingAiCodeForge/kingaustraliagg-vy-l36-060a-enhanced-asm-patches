; KingAI authored patch source: V58_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
                     OPT H11
                     ORG $5D14
FUEL_BLOCK_STOCK_REPLAY_V58:
                     BSET $5F,#$40
                     LDX  #$0000
                     STX  $0143
                     STX  $0145
                     STX  $013F
                     STX  $0141
                     JMP  $A647
                     OPT H11
                     ORG $A5C0
FUEL_BLOCK_DETOUR_V58:
                     JMP $5D14
