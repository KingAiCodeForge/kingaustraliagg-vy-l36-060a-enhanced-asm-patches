# VY patch status - 20 October 2026

Owner-approved BIN publication is permitted under PUBLIC_WIP_POLICY.md. Permission is not qualification. This update publishes no new executable BIN and changes no firmware behavior.

| Family | Current evidence/state | Next required job |
| --- | --- | --- |
| v38 applier and two historical ASM files | RETIRED: cross-bank defect; old test wrote during import; exact public variants retained at original paths | Non-build research history only; do not repair by guessing another address |
| v60 raw0208/rawzero | HOLD / diagnostic history: D may be reloaded from $019B rather than preserved | Re-derive caller-visible register/CCR and asynchronous-writer contract before a separately versioned replacement |
| ghost-cam | Public hash-bound STATIC_CANDIDATE_DO_NOT_FLASH; A09 byte parity passed | Cadence, consumer/output and bench/recovery evidence |
| est-shared-probe / v52 | Public hash-bound STATIC_WIP_PROBE_DO_NOT_FLASH | Qualify shared-command ownership, caller contracts, timing and measured response |
| SC01 / FDC1 | Private peer-pack notes report complete images; independent bank/control-flow review is still required | Reconcile exact recipes, matching ASM and current offline receipts before public binary intake |
| SC02 / SC03 | No executable implementation qualified by this public intake | Recover actual implementation evidence or retain analysis-only status; do not manufacture a binary from a family label |
| R61 / SC61 / SC62 / SCZ2 | Separate private peer-pack controls/experiments, not promoted by export counts | Exact-image/rebuild review, intended test-order and independent physical evidence |
| Other patched BINs | Eligible for review under owner permission, not automatically approved | Inventory, deduplicate by hash and assess source/ASM/control-flow/integrity individually |

The October 5 peer-pack correction distinguishes 57 matching XDF/BIN export/rebuild checks from code/hardware proof and moves v60 to diagnostic history. Private messages are not reproduced or used as endorsements. The v60 code suffix includes FD 14 44 FC 01 9B 39: writing $1444 followed by loading D from $019B requires a caller/asynchronous-state proof, not a checksum-only test.

## Exact v60 HOLD identities

- VY_060A_Enhanced_v1.0a_MainESTStore_RPM3000_Raw0208_BENCH_SCOPE_ONLY_v60.bin: 4df9165b39f4e2aaf4a28106a5d4f42be3ab312ba32653f0e8503af2280354e5
- VY_060A_Enhanced_v1.0a_MainESTStore_RPM3000_RawZero_BENCH_SCOPE_ONLY_v60.bin: e0d1234553debd0318c910e26346a0154b67a17523adddb974e670a3a9a37481

## Offline verification - 20 October 2026

- `python -m unittest discover -s tools -p "test_*.py" -v`: **31 passed, zero skipped**, with `VY_V1_0A_BIN` set to the exact private reference and `A09_ASSEMBLER` set to the local assembler. Without these optional fixtures, the corresponding checks may skip; a skipped check is not a pass.
- Both curated patch sources assembled with A09 to their manifest bytes. Exact-source candidate build/verify, conflicting-patch rejection and output-path protections passed. These are static checks, not ECU execution or measured ignition behavior.
- The supported 131,072-byte Enhanced v1.0a reference SHA-256 is `5cb8bd1c61da37a3846b6c28600cdc21db3ceef0c764232d0cd7ec8d6e836abd`. Its stored file checksum is `0x8E6F`, while this repository's calculation is `0x9E9F`; retain that observed discrepancy rather than calling the parent checksum validated.
- The bounded local `bin_patch_test` inventory observed **73 BIN paths**: 55 full-size paths hashed to **34 distinct payloads**, including 21 duplicate paths; 18 wrong-size files were not read or padded. Of the full-size paths, 49 have matching file checksums but still require code/ASM/native review, three have checksum holds, one is the exact reference, and two are the known v60 holds.
- Inventory coverage completed within its declared limits (512 BIN paths, 30,000 directory entries, depth 6), with no reported traversal/read errors. This covers the named local candidate directory only, not every disk, branch or archive. **Zero new executable uploads approved.** Full machine output stays local.
- New regression tests cover the retired writer's refusal, known-bad hash recognition after renaming, duplicates, wrong source/size, unchanged input and partial-inventory reporting. Public/private ignore rules were checked using path arguments without creating sample firmware.

Read-only inventory usage:

```powershell
python tools/audit_patch_inventory.py --source EXACT_REFERENCE.bin --candidates LOCAL_CANDIDATE_DIRECTORY --out-dir NEW_REPORT_DIRECTORY
```

The output directory must be new and outside the candidate directories. The tool does not rewrite firmware or approve publication.

## Per-file public ASM inventory

Hashes below identify the source bytes stored in Git, not a Windows CRLF checkout. Normalize checkout line endings to the Git form before comparing; the two curated manifests also pin normalized source identity.

The table below covers 61 non-retired WIP sources, not a claim that each file has been fully reviewed. The two additional v38 historical sources remain unchanged at their original paths and are separately identified in [the retirement record](archive/rejected/v38/README.md). MANIFEST_BOUND_STATIC_HOLD refers only to the two public curated source manifests. All other retained implementations require individual review; a VERIFIED or PRODUCTION filename cannot override this status.

| Public ASM path | SHA-256 of Git-stored bytes | State |
| --- | --- | --- |
| asm_wip/turbo_boost/antilag_cruise_button.asm | 6e933781add4e3bf7c212c98fc57334722c3568df7447681461135ed10aa220f | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/antilag_rolling.asm | a2caac27257579d4d6097631c13dc3e1f4b16596b61e22f4d64b12ffc1101728 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/antilag_turbo.asm | 67da5e510b0c3dbc7611fb8593ca0c92e0cff03ff39477b031cdb4ef75c0bc55 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/boost_controller_pid.asm | c41752327532027d6390b77cfc6a01a4385ad438569c1925fdccd6f9e9db9a75 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/hybrid_fuel_spark_limiter.asm | 97196f042d593344d6a814049ac6c1bf24cfa15bc5c1c21643eabe805b207eab | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/overboost_protection.asm | e60ed1b400048759a21c798b12b9298eee30ca1e739748f87c57182ac7442c93 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/turbo_limiter_v1.asm | 5a24683eaea308abfb6315f0ec53a441ccc7e023f52456bc58bd0d837b5385b7 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_11p_style_v44_BANKFIX.asm | 5865d136c8fecd39a927d17baa80faaa7ce478540def78de29f8cad5f432fde5 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_11p_style_v45_engineBANK.asm | fe6e7fdfba252738bdc9cdd37e7efa4423c3fb9b751a2fe6047375edb15a5377 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/Spark_cut_3000rpm_test_11p_style_v43.asm | b5b02165f58dd685be310c3be1fa667168c242f1c41159bab1fcbe826142eaef | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_3000rpm_TEST_v38t.asm | 8523a7ae0beafd23229108a62ef94c7399641c604c141026947fdfcab8d9eb48 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_3x_period_VERIFIED.asm | 781b452c6e0fea7a5e12c5ed835b08e51789ab35b60abd76e5a0ccb5fda806ef | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_6000rpm_v32.asm | 694fbb9c10442844ecb9a7d7a628e4c74038b18efb6c56d3429b9364617638c7 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_6375_safe_mode_v18.asm | 9e5a702c8a35eeb6a21f991a0c030e0feaf1686a5ec5cc0e7402739480c394de | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_bmw_inspired_v40.asm | 6b7f6280584270d4a580855b961893c12a1dd1626363f145632948ca66fef869 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_chrome_method_v33.asm | 8d89bd8d6802d45878bb9b11ac51a038664c0d5ac05cb1ad647356951dcb6f8b | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_combined_fuel_v35.asm | ca77f32de690725be680f5aa9608ea2c31e06dfdea3d47b698bb0d06976832a5 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_delco_optimized_v41.asm | d8339591c5a0026140bea0c221fd1bda394d66cf07f50dd0e07ea7e0d6e9f372 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_dwell_patch_v37.asm | 863c3bc9c03be7f8849a36ac869c58d3777b1b5b751267abd53f8f078009c3aa | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_original.asm | e8d45c20174716531ceda4caffe02e8e53f97da9f1b0a0cf9c4673f8f09fe539 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_progressive_soft_v9.asm | 4daf1dc3c001e80b1216711d0b617ae12ab7173698b5bcf1e7db076cfd7f52d2 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_rolling_v34.asm | 436236f2e32f4e0133212ea74bb489099d887d800b31f85d0f871ccfed8343ae | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_soft_timing_v36.asm | f367233fd16c65425e6750e2fea563657d762183fe34478cef340ae9bfe43394 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_the1_method_port_v39.asm | ffe863259f887c9a4d7c637674e9ad6ed3dd2e7c998bce8cde8d9fd07b06eb04 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_two_stage_hysteresis_v23.asm | 23f00003b47c972a05bf2422b486a3b6bed5a5dc009a06d3eecdf00a898e98ec | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/flat_shift_no_lift.asm | f3a1cb688e0d2ea2fa6b0437c030c2dd0bb0eb8a6515f3a91518daaf5826dee7 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/launch_control_two_step.asm | 31f7eb7547791b7509dd33cc6d610e9c88d77bec4753e47b06bb78ccec2eea7b | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/no_lift_shift.asm | 70d7c3770c7c5da50161e1705420312d95bab37746951d45453aed284d9d5f0e | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_bang_auto.asm | a523b2d0d5bd4ee3b357609cdc24ebebcf0b3ad49775f8fc80df6c09b4bf6d2c | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_bang_manual.asm | 3ebb5b4d0b512d7eac00289ba0063e85f473f8c9e26efbcdaa3aab6fad1c7114 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_launch_v1.asm | 947e8748d45e39be33030c8eb66cfbef07d0ece50eb45272f22d44cd4298f881 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_retard.asm | aa8d76653ede8f62a3b8c9fc965353e9ba1f38c3243c78333b9e240e377305fc | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/timing_retard_soft.asm | 53c70ffa2d535dc97562d0212ce78b7359e48691c9dca195c38cf6a18090d6a0 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/rejected/REJECTED_methodB_dwell_override.asm | 05fb8b0bf4d3ce1ffbebab7cea00d9aad84829c9c077a937a0fcf537adb58445 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv2.asm | 99114351512273014ebcb70874786a1725ad7cb97de13fbaa3736400d7f11361 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv3.asm | 5df1d8c9174af505255d1c91f454fdf043f9e90332511fe74b5fca9927ade2b4 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv4.asm | 55af37a7f95b1ead0e2e9cf68e4b33b359ff812dc79b8e6be4dc35edf447478f | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_original.asm | 15695338b654c70134edf04915fec44aa6c209a7d7d197b50b240e29170122a4 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_methodC_output_compare.asm | 212b26121561fb3498dc00d6f800b03988cc855f40b54deae752535923fb2acc | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v14_hardware_timer_control.asm | 917afc3c45675309851e4f59553a0157f015349d576725488887b5ce449d07e6 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm | 9cb4d3b75baa66f9ad191770e1306829f73a84e175a0f5f9516c7be9d4adbf83 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v17_oc1d_forced_output.asm | b4b9e3f8128930da1410590cd92bd7b70a060213c24bac95f419a866af8b00e4 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v19_pulse_accumulator_isr.asm | efb4ab56426f67146f8c4b094112b21b969164f9fd947fe7c460cba441860859 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_more_work/NEEDS_WORK_hardware_est_disable_v13.asm | ae4e0a7eb294ad7b98d38cab654f33d48916109285d5eacd7179212d463402ad | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/lumpy_idle_XDF_ONLY/lumpy_idle_xdf_parameters_v2.asm | 58249ac138a504cffa5dc5f70c7222917074ab70fe401b748744ab14272c486d | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam_ASM_PATCH/ghost_cam_rpm_delta_spark_v1.asm | fcff833060db32976fbbb14774714f0d29fc1a08baf7b196534ce7e99ad9c630 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam_ASM_PATCH/ghost_cam_rpm_rotating_idle.asm | 9bf12b3ce477fd85deee9a85562f31ad5e8ee1c07553efee1362bdadcc327e16 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam/ghost_cam_retarded_idle_selector_v1.asm | 9531a4a7ef40f21b05bbb13ba573c491223059722af9575c4ce8054dc09f3de5 | MANIFEST_BOUND_STATIC_HOLD |
| asm_wip/fuel_systems/alpha_n_tps_fallback.asm | a35a2b4e5a5d9e9071ee5dd886ca5390854d314406ac183cd293b7ae13d1c460 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/e85_dual_map_toggle.asm | c77431863844f09354c1841b3cd0d503b1b5a2cdb2b52726e3fca31fdf42085a | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/fuel_cut_enhanced.asm | 8261e70a20861cf628b00b8649c5b2f1c17bad02980aafc076b54129d68278c6 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v1.asm | 08fc4e9d7e9da6dccd072d8bf0675ddfe08e80ee2611e8ef2cbd98d4a332e2aa | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v2.asm | b13ad8b829ca076b8486101bca89d59027cf54c3d945ef2bb495e701b6ae69dd | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v3.asm | 3409cd6c97960f87f04a0b64902e6a23b8cb62c51c7e94a3399dae731be05c8c | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_tpi_method.asm | 001a5421649f6a2b2c80e446d71869c54171b9ff228dbb60b0821e0f58baa3af | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/speed_density_fallback_v1.asm | e1d5b5e559159fe794b7cf52ec8681a45f928ce2985cf3927b8619f12e15cc5e | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/speed_density_ve_table.asm | 35ce7ab78680fb7c49791d83ffe31d7b78f915b5d2cee81c16a332d83099e669 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/est_shared_probe/est_shared_dual_store_probe_v52.asm | 1ae5ac048259656e20e0b099d717ca54206320ca291ec3231b8df1998fd64b12 | MANIFEST_BOUND_STATIC_HOLD |
| asm_wip/cold_maps_only_for_tuning_patch/alpina_mafless_fallback_v1.asm | 45e76539f360d67b6ccb506b2b612493bf2cb69cc535098ebe01280e4f00a50d | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/cold_maps_only_for_tuning_patch/cold_maps_force_cold_spark_v1.asm | 5fa7a3add104202641bbbdd3d18aab6a01b8db7592d5cedfc5a79df4c795be31 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/cold_maps_only_for_tuning_patch/cold_maps_tuning_alpina_method_v1.asm | ecc9c261a4cfb9c3df9e783c110aa7c005ebb5bacb76b5533dfaa0d4f091ce30 | LEGACY_UNREVIEWED_DO_NOT_FLASH |

## Archive V2 sources reviewed

These public topics provide context, not validation of KingAI binaries. Only concise paraphrases are used; private correspondence and full archived posts stay out of the repository.

- [Topic 8567: VT/VY spark-cut development](https://pcmhacking.net/forums/viewtopic.php?t=8567): platform-specific development and testing claims; not portable patch bytes or approval of this repository.
- [Topic 8607: high-RPM dwell limits](https://pcmhacking.net/forums/viewtopic.php?t=8607): measured bench timing concerns and minimum dwell/burn discussions; not proof that zeroing a software value safely suppresses ignition.
- [Topic 8500: 060A disassembly](https://pcmhacking.net/forums/viewtopic.php?t=8500): separate bank views and caller context are necessary; file offsets alone do not establish executable CPU addresses.
- [Topic 2518: Enhanced factory BINs](https://pcmhacking.net/forums/viewtopic.php?t=2518): source-package and definition-revision provenance; do not confuse a v2.09b XDF label with a v1.0a program revision.
- [Topic 1396: FAQ](https://pcmhacking.net/forums/viewtopic.php?t=1396): verify platform-specific hardware, NVRAM/programming and logging requirements rather than generalizing from a different PCM.
