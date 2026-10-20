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

## Retired reports and the reusable static checks

`tools/analyze_v38_patch.py` and `tools/verify_v38_offsets.py` now also refuse with exit status 2 and remain silent when imported. Their original public versions are preserved in Git history at commit `ac269647b1e6042284cc6315f613c98f866fac0b`; the rejected payload is not copied into the new tool.

The old analyzer printed hand-written assembly that disagreed with its 39-byte array. Its encoded branch targets landed inside instruction operands. The verifier embedded a different 42-byte routine, calculated branches from repeated constants instead of its encoded operands, and did not include branch/store failures in its final result or process exit status. Changing an embedded displacement could therefore leave its unconditional success claim intact. Neither report established bank context or runtime behaviour.

The portable replacement, [`tools/hc11_static_review.py`](../../../tools/hc11_static_review.py), is read-only. It decodes an explicit, limited unprefixed HC11 instruction subset, rejects unknown/prebyte/truncated instructions, computes targets from actual signed operands and checks whether targets fall on decoded instruction boundaries. An explicit executable prefix prevents signatures and data tails from being decoded as instructions. Targets outside that prefix remain unreviewed findings. JSON reports go to stdout; there is no BIN output or patch operation.

Every address calculation requires an assumed active bank. Low common-region code retains its caller's bank context. For example, a bank-2 `JSR $C500` resolves to file offset `0x14500`, not bank-1 file offset `0x0C500`. The tool rejects a file region not visible under the supplied bank or one that crosses a discontinuity in that mapping. It does not prove the supplied bank state, code/data classification, reachable execution, register preservation, timing or physical signal effects.

Synthetic examples, containing no firmware payload:

```console
python tools/hc11_static_review.py --hex "20 00 39" --file-offset 0x10000 --bank bank2
python tools/hc11_static_review.py --hex "BD C5 00" --file-offset 0x101E1 --bank bank2
python -B -m unittest discover -s tools -p "test_hc11_static_review.py" -v
```

The first example checks a branch to the following synthetic `RTS`. The second reports the resolved call target as outside the reviewed code and exits 1. Exit 0 means the bounded static checks found no issue, exit 1 means static findings remain, and exit 2 means invalid or unsupported input was refused. None is a runtime approval. `--input` may read a full 128 KiB image with an explicit `--length`; it reports the input hash and never modifies that image.
