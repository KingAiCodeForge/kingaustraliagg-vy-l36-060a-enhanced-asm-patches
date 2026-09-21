# VY $060A diagnostic/XDF review lane

Status: offline/source-correlated review evidence.

Key outputs used by the ASM repair work:
- BLM learning upper-limit definitions recovered at 0x7636 and 0x7637 for exact VY $060A
- ADX packet-offset corrections were derived across the Ecotec definition set
- VY Knock Retard buffer location was corrected in the larger audit
- Mode-1 Table 8 field/packed-state mapping was source-correlated and bounded-tested
- Table 8 includes an observable FUELCTOF state useful for R08 bench instrumentation
- diagnostic memory-read serializer has a protected start-address interval; requests beginning in $1000..$1810 can be substituted to RAM zero, so a changing read does not prove the requested RAM address was actually sampled

The public folder includes only a review diff and offline decoder. Full definitions, private source and firmware are excluded.