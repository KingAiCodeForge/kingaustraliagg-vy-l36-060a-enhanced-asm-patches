# HC11 decoder + shared 3D lookup audit

Status: decoder fix identified; lookup algorithm BOUNDED_EXECUTION_PASS, not live-PCM proof.

This lane supports the VY repair work in two ways:

1. The same 114-byte 3D lookup implementation was matched across ten inspected Ecotec images and was executed with relocated table objects through another X pointer. This establishes the table-format/interpolation contract needed for RAM-shadow/RTT experiments; it does not establish a safe live RAM region or transport.
2. The local HC11 decoder had page-0x18 register-operation exceptions overwritten by the general indexed-opcode comprehension. The review patch restores CPY/LDY/STY indexed decoding after the comprehension.

Porting rule: use the VX source as a semantic/function oracle, then fingerprint and relocate each function in the exact target. Never apply a cross-OS address delta.