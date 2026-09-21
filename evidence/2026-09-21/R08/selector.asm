; R08 = user-tested R07b selector, unchanged.
; 060A Enhanced target layout verified against supplied v1.0a and R34 BINs.
; File 0x12582 / CPU $A582: JSR $FEC0 replaces LDX #$77DE.
; File 0x17EC0 / CPU $FEC0:
selector:
    PSHA                    ; 36
    LDAA  $98               ; 96 98 -- unsigned speed byte; units unverified
    CMPA  #$02              ; 81 02 -- file 0x17EC4 editable raw gate
    BHI   factory           ; 22 05
    LDX   #$FF00            ; CE FF 00 -- target-specific shadow
    BRA   done              ; 20 03
factory:
    LDX   #$77DE            ; CE 77 DE -- original limiter block
 done:
    PULA                    ; 32
    RTS                     ; 39
; ON:  BD FE C0 at file 0x12582
; OFF: CE 77 DE at file 0x12582
; Shadow: copy target file 0x77DE..0x781D to 0x17F00..0x17F3F,
; then set offsets +0..+5 to 50 50 50 50 50 50.
; No physical range, brake, TPS or clutch qualification.
