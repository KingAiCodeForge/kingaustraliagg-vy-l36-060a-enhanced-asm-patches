;==============================================================================
; VY $060A ENHANCED GHOST-CAM RETARDED-IDLE SELECTOR v1
;==============================================================================
;
; Status: STATIC CANDIDATE. The hook, displaced instruction, RAM producers, and
; code placement match the exact source image. Runtime cadence and engine
; behavior remain untested. Do not flash it.
;
; Exact source image
;   VX/VY V6 $060A Enhanced v1.0a
;   Size:    0x20000 bytes
;   SHA-256: 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
;
; Stock path
;   $1A44 receives the coolant-indexed normal idle spark value at bank2 $F42E.
;   $1A45 receives the coolant-indexed retarded idle spark value at $F438.
;   At $F90B, stock tests runtime flag $57.0. When set, $F90F loads $1A45.
;
; Hook contract
;   File 0x1790F / bank2 CPU $F90F
;   Stock: B6 1A 45       LDAA $1A45
;   Patch: BD FE A2       JSR $FEA2
;
; Routine placement
;   File 0x17EA2 / bank2 CPU $FEA2
;   The exact source contains zeros from file 0x17EA2 through 0x17FBF.
;
; Behavior
;   The stock branch remains the enable gate. If stock does not select retarded
;   idle spark, this hook is skipped. When reached, the handler alternates
;   between the already-computed normal and retarded idle spark values using a
;   read-only bit of $1916. Stock increments $1916 at common CPU $3037.
;
; No patch RAM is allocated and no final-spark address is invented. Tune the two
; idle spark tables and the existing retarded-idle enable in the Antus XDF.
;
; Still unproved
;   The exact increment cadence and audible result of PHASE_MASK need logging
;   and bench testing. Start with conservative table separation. This is not a
;   camshaft change and must not be represented as one.
;   In the exact parent both normal and retarded idle tables are eleven 0xAF
;   bytes. This ASM alone therefore has no distinct table values to alternate.
;   A separate, mild table-response research variant is documented under
;   bin_patch_test/ghost_lumpy_wip_20260924/; no audible effect is proved.
;
;==============================================================================

ENGINE_EVENT_COUNTER  EQU $1916
IDLE_SPARK_NORMAL     EQU $1A44
IDLE_SPARK_RETARDED   EQU $1A45

PHASE_MASK            EQU $08

                      ORG $FEA2

GHOST_CAM_SELECT_V1:
                      LDAA ENGINE_EVENT_COUNTER
                      BITA #PHASE_MASK
                      BEQ  GC1_NORMAL

                      LDAA IDLE_SPARK_RETARDED
                      RTS

GC1_NORMAL:
                      LDAA IDLE_SPARK_NORMAL
                      RTS

                      FCB  $4A,$4B,$47,$01  ; "JKG", source revision 1
