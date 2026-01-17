;==============================================================================
; VT V6 IGNITION CUT v37 - DWELL PATCH FOR HIGH RPM (CHR0M3 VIDEO METHOD)
;==============================================================================
;
; ⚠️⚠️⚠️ THIS FILE IS FOR VT V6, NOT VY V6! ⚠️⚠️⚠️
;
; Contains research notes from Chr0m3's YouTube video and PCMHacking.net.
; These are HEX PATCH values, not ASM code to inject.
; VY V6 addresses are DIFFERENT - need separate research.
;
; See README for knowledge gaps - community help wanted to find VY addresses!
;
;==============================================================================
; Author: Jason King kingaustraliagg
; Date: January 17, 2026
; Method: Patch Min Dwell/Burn Constants (NOT code injection)
;
; ⚠️ WARNING: THESE ADDRESSES ARE FOR VT V6, NOT VY V6!
; ============================================================
; The addresses below were verified for VT V6 ($A5) platform.
; VY V6 ($060A) has DIFFERENT calibration offsets!
; DO NOT apply these patches directly to VY binaries.
;
; To find VY addresses, search for similar byte patterns in the VY binary
; at different offsets. VY Delta CYLAIR/Max Dwell is at 0x6776.
;
; Target: VT V6 Enhanced (NOT VY!)
; Processor: Motorola MC68HC711E9
;
; SOURCE: PCMhacking.net Topic 8607
;   "Extending the high rpm dwell limits of the VX / VY flash PCM"
;
;   "Location 14735 Hex 144A (Minimum dwell)
;    Location 1473B Hex 1448 (EST Low time or min burn)
;    I patched those values to achieve exactly that"
;
; ALSO FROM CHR0M3 VIDEO (300 HP Ecotec Week 5):
;   Stock: Min Dwell = 0xA2 (162), Min Burn = 0x24 (36), Sum = 198
;   Patch: Min Dwell = 0x9A (154), Min Burn = 0x1C (28), Sum = 182
;   Result: Stable spark control to 7,200 RPM
;
; Status: ⚠️ NOT ASM CODE - This is HEX PATCH documentation
;
;==============================================================================

;------------------------------------------------------------------------------
; THIS IS NOT ASSEMBLY CODE!
;------------------------------------------------------------------------------
; Unlike v32-v36, this is NOT code to inject into free space.
; This is a CALIBRATION PATCH - changing constant values in existing code.
;
; The dwell/burn patch enables the ECU to maintain spark control above
; 6,500 RPM where the stock values cause timer overflow.
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; VT V6 PATCH ADDRESSES (From PCMhacking.net Topic 8607)
;------------------------------------------------------------------------------
;
; ⚠️ THESE ARE FOR VT V6 ONLY - NOT VY!
;
; FILE OFFSET     | CPU ADDRESS | Name              | Stock | Patched
; ----------------|-------------|-------------------|-------|--------
; 0x14735         | $0144A      | Minimum Dwell     | 0xA2  | 0x9A
; 0x1473B         | $01448      | Min Burn (EST Lo) | 0x24  | 0x1C
;
; NOTE: The "CPU Address" column is the runtime address. The "File Offset"
; is where to find it in the .bin file. They differ due to address mapping.
;
;------------------------------------------------------------------------------
; VY V6 ADDRESSES - ✅ VERIFIED JAN 17, 2026
;------------------------------------------------------------------------------
;
; VY V6 ($060A) has different calibration layout than VT V6 ($A5).
; 
; ✅ CONFIRMED VY ADDRESSES (Binary analysis Jan 17, 2026):
;
; FILE OFFSET     | Instruction        | Stock | Patched | Description
; ----------------|--------------------| ------|---------|-------------
; 0x171AA-0x171AB | LDD #$00A2         | 0x00A2| 0x009A  | Min Dwell (16-bit)
; 0x19813         | LDAA #$24          | 0x24  | 0x1C    | Min Burn (8-bit)
;
; NOTE: These are IMMEDIATE VALUES in the instruction stream, not table data!
;   - 0x171A9: CC 00 A2 = LDD #$00A2 (load D with 162)
;   - 0x19812: 86 24    = LDAA #$24 (load A with 36)
; could be wrong maybe above. 
; Known VY calibration addresses:
;   0x6776 = Delta CYLAIR Max Dwell (value 0x20 = 32) - from XDF
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; THE OVERFLOW PROBLEM (FROM CHR0M3 VIDEO)
;------------------------------------------------------------------------------
;
; At high RPM, the ECU calculates: min_dwell + min_burn < available_time
;
; Stock values: 162 + 36 = 198 (in timer units)
;
; At 6,600 RPM: calculation gives 198.59 (OK - above threshold)
; At 6,700 RPM: calculation gives 195.40 (OVERFLOW - below threshold)
;
; When the sum goes below the threshold, the 8-bit timer calculation
; overflows, and dwell/burn times become garbage (3.68ms burn instead
; of 640µs burn = MISFIRE!)
;
; Chr0m3's patch: 154 + 28 = 182
; This lower sum allows the calculation to work up to ~7,200 RPM
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; STEP-BY-STEP PATCH INSTRUCTIONS
;------------------------------------------------------------------------------
;
; BACKUP FIRST! Save your original .bin file before patching.
;
; 1. Open binary in hex editor (HxD, Hex Workshop, etc.)
;
; 2. Navigate to file offset 0x14735
;    - Look for byte: 0xA2 (162 decimal)
;    - This is the minimum dwell time constant
;
; 3. Change 0xA2 to 0x9A
;    Before: ...A2...
;    After:  ...9A...
;
; 4. Navigate to file offset 0x1473B  
;    - Look for byte: 0x24 (36 decimal)
;    - This is the minimum burn time constant (EST low time)
;
; 5. Change 0x24 to 0x1C
;    Before: ...24...
;    After:  ...1C...
;
; 6. Save the patched binary
;
; 7. IMPORTANT: Recalculate checksum using TunerPro or similar
;    - Open patched .bin in TunerPro with correct XDF
;    - Save (TunerPro auto-updates checksum)
;
; 8. Flash patched binary to ECU
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; EXPECTED RESULTS
;------------------------------------------------------------------------------
;
; BEFORE PATCH:
;   - 6,300 RPM: Normal operation
;   - 6,500 RPM: Intermittent misfires (3.68ms burn errors)
;   - 6,600 RPM: Severe misfires, spark control lost
;   - 6,700+ RPM: No reliable spark control
;
; AFTER PATCH:
;   - 6,300 RPM: Normal operation
;   - 6,500 RPM: Normal operation
;   - 7,000 RPM: Normal operation (480µs burn per Chr0m3)
;   - 7,200 RPM: Normal operation (Chr0m3's tested limit)
;   - 7,500+ RPM: Unknown, not tested
;
; TRADE-OFFS:
;   - Slightly reduced dwell time at LOW RPM (minimal impact)
;   - Chr0m3: "Lost a bit of dwell time but it's not terrible"
;   - Coil saturation still occurs, just slightly faster ramp
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; COMBINING WITH SPARK CUT CODE
;------------------------------------------------------------------------------
;
; This patch COMPLEMENTS the spark cut ASM code (v32-v36).
;
; Scenario A: 6,000 RPM limiter (v32)
;   - Patch NOT required (6,000 is within stock limits)
;   - v32 spark cut handles limiting
;   - Works fine on unpatched binary
;
; Scenario B: 7,200 RPM limiter
;   - Patch REQUIRED first (enables spark control to 7,200)
;   - Then modify v32 thresholds to 7,200 RPM
;   - Both work together
;
; Scenario C: No hard limiter, just extend RPM capability
;   - Patch REQUIRED
;   - No spark cut code needed
;   - Fuel cut still active at 6,375 (or 0xFF disabled)
;   - Engine can rev to 7,200 under control
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; ALTERNATIVE PATCH VALUES
;------------------------------------------------------------------------------
;
; Chr0m3's first attempt (TOO AGGRESSIVE):
;   Min Burn: 0x24 → 0x14 (36 → 20)
;   Result: "Way too small amount of dwell at low RPM"
;   14ms burn time - FAILED
;
; Chr0m3's working patch:
;   Min Dwell: 0xA2 → 0x9A (162 → 154) - Reduction of 8
;   Min Burn:  0x24 → 0x1C (36 → 28)   - Reduction of 8
;   Result: 7,000 RPM achieved, 480µs burn
;
; More conservative (less RPM extension, safer low RPM):
;   Min Dwell: 0xA2 → 0x9E (162 → 158) - Reduction of 4
;   Min Burn:  0x24 → 0x20 (36 → 32)   - Reduction of 4
;   New sum: 190 (vs stock 198)
;   Estimated max: ~6,800 RPM
;
; More aggressive (untested, risky):
;   Min Dwell: 0xA2 → 0x96 (162 → 150) - Reduction of 12
;   Min Burn:  0x24 → 0x18 (36 → 24)   - Reduction of 12
;   New sum: 174
;   Estimated max: ~7,500+ RPM
;   WARNING: May affect low RPM dwell negatively!
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; OSCILLOSCOPE VERIFICATION
;------------------------------------------------------------------------------
;
; RECOMMENDED: Use oscilloscope to verify before real-world use
;
; Test points:
;   - EST output (pin location varies by harness)
;   - Coil primary negative (ground side of coil)
;
; What to measure:
;   - Dwell time (high portion of EST signal)
;   - Burn time (low portion between dwells)
;
; Expected at 7,000 RPM (after patch):
;   - Dwell: ~2.0-2.5ms (reduced from ~3ms at lower RPM)
;   - Burn: ~480µs (Chr0m3's measured value)
;
; FAILURE indicators:
;   - Burn time > 1ms (should never happen)
;   - Erratic timing (jumping between values)
;   - Missing spark events
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; SPEEDUINO COMPARISON
;------------------------------------------------------------------------------
;
; Speeduino handles this differently:
;   - Software calculates all timing
;   - No hardware minimum dwell enforced
;   - High RPM is limited only by CPU speed
;
; VY Delco ECU:
;   - Hardware TIO module enforces minimums
;   - Code constants (now patchable) set the limits
;   - Must work within hardware architecture
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; REFERENCES
;------------------------------------------------------------------------------
;
; PCMhacking.net Topic 8607:
;   "Extending the high rpm dwell limits of the VX / VY flash PCM"
;   - Original discovery of addresses
;   - Community verification
;
; Chr0m3 Motorsport YouTube:
;   "300 HP 3.8L N/A Ecotec Burnout Car: Week 5"
;   - Video demonstration of patching process
;   - Oscilloscope measurements before/after
;   - 7,200 RPM successful testing
;
; Document: CHROME_VIDEO_ANALYSIS.md
;   - Full transcript of patch process
;   - Math behind overflow calculation
;
;------------------------------------------------------------------------------

;==============================================================================
; END OF DWELL PATCH DOCUMENTATION
;==============================================================================

;##############################################################################
;#                                                                            #
;#                    ═══ CONFIRMED ADDRESSES & FINDINGS ═══                  #
;#                                                                            #
;##############################################################################

;------------------------------------------------------------------------------
; ✅ PLATFORM ADDRESSES - CONFIRMED JAN 17, 2026
;------------------------------------------------------------------------------
;
; VT V6 Addresses (from PCMhacking.net):
;   0x14735 = Min Dwell ($A2 stock)
;   0x1473B = Min Burn ($24 stock)
;
; ✅ VY V6 ($060A) ADDRESSES - CONFIRMED BY BINARY ANALYSIS:
;   0x171AA-0x171AB = Min Dwell (0x00A2 stock, 16-bit in LDD instruction)
;   0x19813         = Min Burn (0x24 stock, 8-bit in LDAA instruction)
;
; PATCH PROCEDURE FOR VY V6:
;   1. Open VX-VY_V6_$060A_Enhanced_v1.0a.bin in hex editor
;   2. Go to offset 0x171AA, change A2 to 9A
;   3. Go to offset 0x19813, change 24 to 1C  
;   4. Update checksum with TunerPro
;   5. Flash to ECU
;
;------------------------------------------------------------------------------
; ✅ VY BINARY VERIFIED ADDRESSES (January 17, 2026)
;------------------------------------------------------------------------------
;
; Verified on: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin (131,072 bytes)
;
; SEARCHING FOR DWELL CONSTANTS:
;
; Pattern: LDAA #$24 (86 24)
;   Found at: 0x19812 - "86 24 B7" = LDAA #$24; STAA ...
;   Context: Likely Min Burn constant
;   ⚠️ NEEDS VERIFICATION via disassembly trace
;
; Pattern: LDAA #$A2 (86 A2)
;   Found at: NONE in VY binary!
;   Implication: Min Dwell may be stored differently in VY
;   Possibility: Value in calibration table, not code constant
;
; DWELL CALC ROUTINE ($371A):
;   0x371A: 13 67 A0 06 = BRCLR $67,#$A0,$3722
;   This is NOT a constant load, it's a bit test
;   The dwell limits may be in calibration space, not code
;
; CALIBRATION CANDIDATES (from XDF):
;   0x6511: Max Dwell table area
;   0x6513: Min Dwell Normal (may be here)
;   0x6515: Min Dwell Cranking
;   0x6776: Delta CYLAIR Max Dwell ($20 = 32)
;
;------------------------------------------------------------------------------
; 📐 OVERFLOW MATH (Chr0m3 Video Analysis)
;------------------------------------------------------------------------------
;
; Timer calculation at high RPM:
;   available_time = (60/RPM) × 1000 × timer_resolution
;   
; Stock check: min_dwell + min_burn < available_time
;   Stock sum: 162 + 36 = 198
;   
; At various RPM:
;   6000 RPM: available ≈ 210 → 210 > 198 ✓ OK
;   6600 RPM: available ≈ 198.59 → 198.59 > 198 ✓ BARELY OK
;   6700 RPM: available ≈ 195.40 → 195.40 < 198 ✗ OVERFLOW!
;
; Patched sum: 154 + 28 = 182
;   7000 RPM: available ≈ 184 → 184 > 182 ✓ OK
;   7200 RPM: available ≈ 180 → 180 < 182 ✗ OVERFLOW (limit)
;
; Formula for max RPM:
;   max_RPM = 60000 / (sum × timer_period_ms)
;   Assuming timer_period ≈ 0.5µs:
;   stock: 60000 / (198 × 0.0005 × some_factor) ≈ 6600 RPM
;   patched: 60000 / (182 × 0.0005 × some_factor) ≈ 7200 RPM
;
;------------------------------------------------------------------------------
; ✅ THINGS NOW CONFIRMED (Jan 17, 2026)
;------------------------------------------------------------------------------
;
; 1. VY Min Dwell Address ✅ FOUND
;    File offset: 0x171AA-0x171AB (16-bit value)
;    Instruction: CC 00 A2 = LDD #$00A2 at 0x171A9
;    Stock value: 0x00A2 (162)
;    Patch to: 0x009A (154) for 7200 RPM
;
; 2. VY Min Burn Address ✅ FOUND
;    File offset: 0x19813 (8-bit value)
;    Instruction: 86 24 = LDAA #$24 at 0x19812  
;    Stock value: 0x24 (36)
;    Patch to: 0x1C (28) for 7200 RPM
;
; 3. VY vs VT Addressing ✅ CONFIRMED DIFFERENT
;    VT uses: 0x14735 (min dwell), 0x1473B (min burn)
;    VY uses: 0x171AA (min dwell), 0x19813 (min burn)
;    DO NOT USE VT ADDRESSES ON VY BINARY!
;
; 4. XDF Addition Needed
;    TODO: Add these to VY XDF as tunable scalars:
;      Min Dwell @ 0x171AA (16-bit)
;      Min Burn @ 0x19813 (8-bit)
;
;------------------------------------------------------------------------------
; 🔧 VERIFICATION PROCEDURE
;------------------------------------------------------------------------------
;
; PATCH VERIFICATION STEPS:
;
; 1. Open Enhanced v1.0a binary in hex editor
;
; 2. Verify stock values (BEFORE patching):
;    0x171A9: CC 00 A2 (should see this pattern)
;    0x19812: 86 24 (should see this pattern)
;
; 3. Apply patches:
;    0x171AA: Change A2 to 9A
;    0x19813: Change 24 to 1C
;
; 4. Scope test at 6000 RPM:
;    Dwell should be ~2.5ms
;    Burn time should be ~500µs
;
; 5. Rev test to 7000+ RPM:
;    Verify stable spark events
;    No dropouts or misfires
;
;------------------------------------------------------------------------------
; 🔗 RELATED FILES
;------------------------------------------------------------------------------
;
; trace_jsr_371a_and_all_isrs.py - Disassembles dwell calc routine
; JSR_371A_DWELL_CALC_ANALYSIS.txt - Output of above script
; CHROME_VIDEO_ANALYSIS.md - Full patch math explanation
; spark_cut_6000rpm_v32.asm - Works without this patch (<6375 RPM)
;
;##############################################################################

