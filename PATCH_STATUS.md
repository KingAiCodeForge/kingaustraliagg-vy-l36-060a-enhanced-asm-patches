# VY patch status - 20 October 2026

Owner-approved BIN publication is permitted under PUBLIC_WIP_POLICY.md. Permission is not qualification. This update publishes no new executable BIN and changes no firmware behavior.

| Family | Current evidence/state | Next required job |
| --- | --- | --- |
| v38 applier and two retired ASM files | RETIRED: cross-bank defect; old test wrote during import | Preserve history; do not repair by guessing another address |
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

The table below is a source inventory, not a claim that each file has been fully reviewed. MANIFEST_BOUND_STATIC_HOLD refers only to the two public curated source manifests. All other retained implementations require individual review; a VERIFIED or PRODUCTION filename cannot override this status.

| Public ASM path | SHA-256 | State |
| --- | --- | --- |
| asm_wip/turbo_boost/antilag_cruise_button.asm | 84a994f1a8e4d73036655869bb1a966ec34bda67072955a25cb0ee1130c412e2 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/antilag_rolling.asm | b6c6ea7ca339e8e686b486fe1dda0e7aeae1722784c4f846e74c4a7026eaa6ab | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/antilag_turbo.asm | 98d2ffc4fa209019b970c936e7a07893c9a70d2cea580de032f8ee72890c68e9 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/boost_controller_pid.asm | 48e17e6b5f11de8fb09754eb4e063a12e20203d167a5138dae5fa5e804eccb6f | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/hybrid_fuel_spark_limiter.asm | df93164103605b749e8d56011e2de08a827931ab0e263fca353a11f514fc2f12 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/overboost_protection.asm | 0de352eef03470a096d9538fef6e051ddf680508e09a7ce146e721280a18535d | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/turbo_boost/turbo_limiter_v1.asm | 30298bd1fa1e42f730414272a945a69771ad061b218aa1ab5c8e562c87d2c05b | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_11p_style_v44_BANKFIX.asm | 6326f8ee9c6076b42e9be1c48043b3113ee7363bc4e8277feb05ed50816ee542 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_11p_style_v45_engineBANK.asm | 240012a3b09d28ee4c67adbc7428d6faf60daa204a74241cb41a9399136ee8d5 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/Spark_cut_3000rpm_test_11p_style_v43.asm | db302a14214145e46e5fa3ebb4989f931e3c1b851489265c7353a6add56f61f4 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_3000rpm_TEST_v38t.asm | 126109bc780fc3e539b468c42cafda5d0857cd39348fdfe4a98c0c36288ef216 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_3x_period_VERIFIED.asm | 8704870aef6a0a049a53b27610170630e269d31c81c68c2415f1fcce74d3d47b | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_6000rpm_v32.asm | 7599ea31f545a56d8c97b0c2cd855c0134473c5c120888008613530d1b283698 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_6375_safe_mode_v18.asm | af1781443c4178a6349e44b999819a27db08eeeb8c83dc43c8a4fc6a2fa4f967 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_bmw_inspired_v40.asm | b7a0605b5bc0860b5943a42a9b8ab0f7fcccb2d1520c67f253ab114deb07028e | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_chrome_method_v33.asm | c7345f91dcf17f03823a955f1217f73caad979fac284da0848e47efb44da29a0 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_combined_fuel_v35.asm | ca93ec3b63936e2dcc6aa2d40d323ee3aa66ea5bd8b90f0bfe50c06b41083f03 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_delco_optimized_v41.asm | 4df1e448caa7194fe68160cf719019bc72f1a2d1b6e740a01a6b1e57d892f76c | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_dwell_patch_v37.asm | 1ff61e9a9d9a57ca8fc278621a4641a8c012174ac4545756a49820e6c52b347c | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_original.asm | 64a790d3d8a5fbc41e74ea57085a9ed412bc1dbc9290e9173c0b4f76fef6c172 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_progressive_soft_v9.asm | 15e41c4fcfaad6fdc7c1326f0928caef9232428e00b402c40d13cd11df7afa51 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_rolling_v34.asm | 958cdb274aaa9b71db8f39790edd2b1e6af2440d5ff8996471a4672f07b27549 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_soft_timing_v36.asm | 52e01814c005ea4f590980e3df2e25b364c94009a081c8a9bbc4b26adc6522b9 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_the1_method_port_v39.asm | 29a0e42f785f9300ce276d92d1fb2d9d92a4dfaca62fe3dead040bdf3cd33acc | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/spark_cut/spark_cut_two_stage_hysteresis_v23.asm | 7e93ba0d7b22fd937c0da932b832a767c85214a0b183ec3487878c0e013323c4 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/flat_shift_no_lift.asm | dc4cbf8fc26fdffca27675bb6f18e0ad465ab26ddbb59d5b65edc597f7a1b3ce | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/launch_control_two_step.asm | c3dcee2de89b51f2066c4ccc20b6a25ca42b00d4dd7fdcd6b880b28eed92de08 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/no_lift_shift.asm | 81da3b490f1890cca3d40943373f14749684d39dbb971fe77e9a29d952d20fee | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_bang_auto.asm | af222bb4ed9e64612349eb97a23224069bac42a50410ef48e6014e72bbf18cdc | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_bang_manual.asm | a6b21e47a0759fef197531f290495aed796e04d5114efdf5869944754374cc60 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_launch_v1.asm | 89843b3035fc31c3bc5c609c495e16cf23e43e7d2dca4a3955c705a57fc9df29 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/shift_retard.asm | 8babb52fb81d0601b882efad9e6183b855ae102e4e7036dd43052d8c7ee2a5fd | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/shift_control/timing_retard_soft.asm | 00914744944b72e500cdf63f755ac52a90f46da7a1d5ab50bd295cc37d5383f6 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/rejected/REJECTED_methodB_dwell_override.asm | 8757a1fd911ac0b8d51b4ae548ea381ae602f8d2220f17d18a7c896067d34fd5 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv2.asm | e617f51b23f41bdf9acd56ae74456090bf30be75c8f8516d0c2cc0d9002d0aa1 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv3.asm | d26847647c5f3109083d75b947de61877cbcb453fa5868df6600a991612d6494 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_methodv4.asm | 7e8a2013248dfac2019980539566df0ec91ace84044aa8aac854082fac098d7a | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/old_versions/spark_cut_original.asm | 787c570e6c9f151c863482b37e0c2fa55ee10e2f7f2a19e6dc5c38db0c856dd9 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_methodC_output_compare.asm | 43fc22fe7c88fc81882b43d8a8940626f1de6e9d76c7bbdcf67e93fadbfc46cb | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v14_hardware_timer_control.asm | d5be73566412aa65344f20cc17d870f5fa2a1628eb77170a5176da9868b0ba9c | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v16_tctl1_bennvenn_ose12p_port.asm | 78912e979aff91fa2c8b48dc0f255c7d336921169c3c38ab4650c8626b895392 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v17_oc1d_forced_output.asm | 4fa55d1773b56b2e9101712afcfe3b07ac289ea6e3db2c508ef213e57fafa6cb | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_validation/NEEDS_VALIDATION_v19_pulse_accumulator_isr.asm | 33f779ac79959221cd68d80cc78e137e5e57d32d5e721acf564f8671e307a55a | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/needs_more_work/NEEDS_WORK_hardware_est_disable_v13.asm | 74f46c07727de09ddada6d550863fb14dcd64b0afc918b5e4de8d3f012561256 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/lumpy_idle_XDF_ONLY/lumpy_idle_xdf_parameters_v2.asm | 872c07ba6d7406223ce67fd2bed6de18443921f6f183f541e9c54d0f218c08ef | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam_ASM_PATCH/ghost_cam_rpm_delta_spark_v1.asm | 7aef4439ef37c84cdd9ab040a350bd62f592f4ec6c2e657b26bcdec8e2338879 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam_ASM_PATCH/ghost_cam_rpm_rotating_idle.asm | 96c2ab36896fc02de40a9fbb859d96efdab3e5351412ba9a0dd04ea8c84c11bd | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/ghost_cam/ghost_cam_retarded_idle_selector_v1.asm | be4a7b2d44dcddfe2d1c8320bab5c9bdc1214f15f8a24ba745299c0bf0ac8faf | MANIFEST_BOUND_STATIC_HOLD |
| asm_wip/fuel_systems/alpha_n_tps_fallback.asm | 10006a647f1da51456adee70da9cac7d8045b4a852286838482889c39cac3f73 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/e85_dual_map_toggle.asm | 7c8f9fdf064428de0cfec7ede3bb4512768d3fa1062cdc8d9371482219086282 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/fuel_cut_enhanced.asm | 85eb77c5c3c7129bf271e551ac07b0b9ecfe9217e6e30f9cdd63f7b90d4557ec | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v1.asm | 6ad3ec5a4d373aeb7ae6a95fab841d4beeb753f72898850884fe2bf341b6c27b | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v2.asm | a033c59d09fb9eeae5660413db799cb471c8fe7df3f842ee9687f9834b686185 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_alpha_n_v3.asm | fdf5e2cd9793955e05967414e350c31c8ece7c7d70ca794b305f41c7565f3ed8 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/mafless_tpi_method.asm | dd1aa4564e8bfdc6df89aee9a3bac19bbe565980f2c8afd48241887136519231 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/speed_density_fallback_v1.asm | 9e736e083cc2cfa1f7016069dcc0b77afe3bbc41a66a3b97761ee00d04a89e74 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/fuel_systems/speed_density_ve_table.asm | db51a0cfe1c60f7f22210b7ca3aa67bf42e3476c1d3053040de5893960f1e55a | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/est_shared_probe/est_shared_dual_store_probe_v52.asm | 15e398d20688b717a5a9993dda718ae6ad5c3421819d14d3f27d989fb65fdfe4 | MANIFEST_BOUND_STATIC_HOLD |
| asm_wip/cold_maps_only_for_tuning_patch/alpina_mafless_fallback_v1.asm | ec2c5453d0e6046ef6e6abe31da87243e13993ee5d3e6d553dd95bd46ed93399 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/cold_maps_only_for_tuning_patch/cold_maps_force_cold_spark_v1.asm | fdc1c56672290e83d4e1f72f99f7798b344f8e483a249c48482c174529b9fcd5 | LEGACY_UNREVIEWED_DO_NOT_FLASH |
| asm_wip/cold_maps_only_for_tuning_patch/cold_maps_tuning_alpina_method_v1.asm | f84bf193f96593bfc0ef0517ee80863b2d17976e89400e5e8826a02c47c8c1a0 | LEGACY_UNREVIEWED_DO_NOT_FLASH |

## Archive V2 sources reviewed

These public topics provide context, not validation of KingAI binaries. Only concise paraphrases are used; private correspondence and full archived posts stay out of the repository.

- [Topic 8567: VT/VY spark-cut development](https://pcmhacking.net/forums/viewtopic.php?t=8567): platform-specific development and testing claims; not portable patch bytes or approval of this repository.
- [Topic 8607: high-RPM dwell limits](https://pcmhacking.net/forums/viewtopic.php?t=8607): measured bench timing concerns and minimum dwell/burn discussions; not proof that zeroing a software value safely suppresses ignition.
- [Topic 8500: 060A disassembly](https://pcmhacking.net/forums/viewtopic.php?t=8500): separate bank views and caller context are necessary; file offsets alone do not establish executable CPU addresses.
- [Topic 2518: Enhanced factory BINs](https://pcmhacking.net/forums/viewtopic.php?t=2518): source-package and definition-revision provenance; do not confuse a v2.09b XDF label with a v1.0a program revision.
- [Topic 1396: FAQ](https://pcmhacking.net/forums/viewtopic.php?t=1396): verify platform-specific hardware, NVRAM/programming and logging requirements rather than generalizing from a different PCM.
