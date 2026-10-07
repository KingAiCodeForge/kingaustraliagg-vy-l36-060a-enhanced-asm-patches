; VY $060A Enhanced v1.0a EST shared-command dual-store probe, v52.
;
; STATUS: WIP STATIC PROBE. This does not cut spark or alter the commanded
; value. Its purpose is to establish a reusable hook at the two direct HC11
; stores to shared word $1444 found in the reviewed static xrefs. Physical
; B3/B4 ownership and indirect or external writers remain unproved.
;
; Exact 128 KiB source SHA-256:
; 5CB8BD1C61DA37A3846B6C28600CDC21DB3CEEF0C764232D0CD7EC8D6E836ABD
;
; Two hook sites in bank 2:
;   file 0x10232 / CPU $8232: FD 14 44 -> BD 5D 05
;   file 0x106EE / CPU $86EE: FD 14 44 -> BD 5D 05
; Both execute JSR $5D05 in common ROM instead of STD $1444 in place.
;
; Common handler placement:
;   file 0x05D05 / CPU $5D05, original four bytes 00 00 00 00.
;
; STD $1444 sets N/Z/V the same way at either call site; JSR/RTS preserve
; the input D and restore SP. Each executed hook adds 11 E-clock cycles and
; temporarily uses two stack bytes. Timing and stack headroom still require
; physical bench measurement. No direct code xref proves the external EST
; device's response to $1444.
;
; The WIP spark-cut path after this probe is: confirm write/readback and
; B3/B4 signals, identify a reversible command value and DTC interaction,
; then implement RPM gate, hysteresis, explicit release, and a backup fuel
; cut in a new version. Do not reuse the v1.1a IRQ-tail call.

EST_SHARED_COMMAND EQU $1444

                   ORG $5D05

EST_DUAL_STORE_PROBE_V52:
                   STD EST_SHARED_COMMAND
                   RTS
