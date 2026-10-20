; KingAI authored patch source: V52_REVIEWED_DIAGNOSTIC_WIP_BENCH_FLASH_ONLY
; WIP_BENCH_FLASH_ONLY. Hardware behavior and recovery are unqualified.
; Exact Enhanced v1.0a parent SHA256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
; Hook replacements, file/bank mappings and checksum are in manifest.json.
; This is addressed patch source, NOT a flat full-ROM image.
EST_SHARED_COMMAND EQU $1444
                   ORG $5D05
EST_DUAL_STORE_PROBE_V52:
                   STD EST_SHARED_COMMAND
                   RTS
