;==============================================================================
; VY $060A Enhanced v1.0a — R08 factory fuel-cut launch selector
; STATUS: STATIC_CANDIDATE_DO_NOT_FLASH + BOUNDED_EXECUTION_PASS
; DATE: 2026-09-21
;
; Exact target SHA-256:
; 5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd
;
; This is the current preferred launch-control research lane because it reuses
; the factory limiter selection + downstream FUELCTOF path. It does NOT claim
; spark cut. Raw RAM $98 speed scaling and physical range/clutch behavior are
; still open. Use the evidence/2026-09-21/R08 builder/verifier, not hand-copying.
;==============================================================================

; File 0x12582 / CPU $A582:
;   original: CE 77 DE  -> LDX #$77DE
;   R08 ON:   BD FE C0  -> JSR $FEC0
;
; File 0x17EC0 / CPU $FEC0:
selector:
    PSHA                    ; preserve A
    LDAA  $98               ; unsigned raw speed byte; units not asserted
    CMPA  #$02              ; default tested R07b-compatible raw gate
    BHI   factory
    LDX   #$FF00            ; target-specific shadow limiter block
    BRA   done
factory:
    LDX   #$77DE            ; original limiter block
done:
    PULA
    RTS

; Shadow construction:
;   copy file 0x77DE..0x781D -> file 0x17F00..0x17F3F
;   replace shadow offsets +0..+5 with launch cut/restart values
;   default six bytes: 50 50 50 50 50 50 (2000 RPM at 25 RPM/count)
;
; Known limitations:
; - all ranges are currently eligible;
; - no brake, TPS or clutch qualification;
; - raw speed <=2 is not asserted as 2 km/h;
; - full-BIN patch/write path required;
; - bench + physical injector-command validation still required;
; - next intended revision: prove factory Performance/PWR state, then R09 gating.
