# v38 retired: preserved, not a runnable patch

The old applier and import-time writer test were replaced only after their exact bytes were preserved and the archive copies SHA-256 checked. The two misleading v38 ASM variants remain unchanged at their original public tracked paths as rejected, non-build research history; they are not in the supported patch catalog. The dirty primary checkout was not edited. The preservation hashes below identify the original Windows checkout bytes, including their line endings; they are not Git-blob hashes.

The documented defect is a bank-2 hook at file 0x101E1 calling CPU $C500 while the intended payload was stored at bank-1 file 0x0C500. Reusing an apparent zero run or changing the CPU constant is not a proved repair.

The old test also created/modified a BIN during import, then printed an unsupported ready-to-flash claim. The compatibility applier now always refuses, and its replacement tests verify refusal without file output.

| Original path | Preserved SHA-256 |
| --- | --- |
| tools/apply_spark_cut_v38.py | d05d065b7c6f3087bbb1c6bdd533b29e6a810fa844b063a8c8b72e2c6b1fc800 |
| tools/test_apply_v38.py | 02075f5da4237842e9007f69bf68eb7c65605d46a7a51effa62e5475f78708a4 |
| asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm | e256a34a148a8acff2273482d01e3ea0247179feec03627a1bbb6dba19b9d401 |
| asm_wip/spark_cut/PATCH_BYTES_v38.asm | 9f9702e524540049666df1ac9dbc06559cad74b4514b4c98b3a18be9e8f37eb1 |

The two retained public sources also have these SHA-256 identities for their Git-stored LF bytes:

| Retained public path | Git-stored SHA-256 |
| --- | --- |
| asm_wip/spark_cut/spark_cut_chr0m3_method_VERIFIED_v38.asm | 8aac60ef1b2686a798f57d0769305886e96024f2dd4ae31d5d930b4ceb104627 |
| asm_wip/spark_cut/PATCH_BYTES_v38.asm | 0cd5f47d9899e81d4f9b58b9d1315a52d43d3e0901a87a2cf90b5b112dc6a67d |

The retained ASM is historical material already present in the public baseline, not new implementation advice or evidence of anyone's endorsement. This retirement record overrides its old READY, VERIFIED, free-space, flag-ownership and suggested-relocation claims. New documentation does not reproduce its quotations, and no new private correspondence is included. No replacement v38 BIN is supplied.
