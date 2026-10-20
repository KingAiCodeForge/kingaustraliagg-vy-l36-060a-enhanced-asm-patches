; KingAI authored patch source: V54_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
                     OPT H11
FUEL_CUT_FLAGS       EQU $005F
FUEL_CUT_MASK        EQU $40
EST_SHARED_COMMAND   EQU $1444
SUBSTITUTE_COMMAND   EQU $0208
                     ORG $5D05
EST_FUELCUT_RAW_V54:
                     BRCLR FUEL_CUT_FLAGS,FUEL_CUT_MASK,V54_STORE
                     LDD   #SUBSTITUTE_COMMAND
V54_STORE:
                     STD   EST_SHARED_COMMAND
                     RTS
                     FCB   $4A,$4B,$54,$01
