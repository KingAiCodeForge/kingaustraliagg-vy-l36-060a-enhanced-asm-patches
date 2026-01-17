# Priority Analysis Summary

**Analysis Date**: November 20, 2025
**Binary**: VX-VY_V6_$060A_Enhanced_v1.0a - Copy.bin

## 🎯 Critical Subroutines

| Address | Calls | JSR Targets | Table Refs | File |
|---------|-------|-------------|------------|------|
| $2491 | 172 | 0 | 0 | 01_subroutine_2491_172calls.asm |
| $2371 | 45 | 0 | 0 | 02_subroutine_2371_45calls.asm |
| $23E5 | 35 | 0 | 0 | 03_subroutine_23e5_35calls.asm |
| $2474 | 29 | 0 | 0 | 04_subroutine_2474_29calls.asm |
| $24AA | 21 | 2 | 0 | 05_subroutine_24aa_21calls.asm |

## 🔥 Code Hotspots

| Address | Tables | Unique Refs | File |
|---------|--------|-------------|------|
| $14300 | 15 | 3 | 06_hotspot_14300_15tables.asm |
| $14100 | 14 | 6 | 07_hotspot_14100_14tables.asm |
| $1CD00 | 11 | 0 | 08_hotspot_1cd00_11tables.asm |
| $1EC00 | 10 | 0 | 09_hotspot_1ec00_10tables.asm |
| $1F200 | 10 | 0 | 010_hotspot_1f200_10tables.asm |

## 📏 Undocumented Gaps

| Range | Size | Non-Zero | Data Type | File |
|-------|------|----------|-----------|------|
| $5B50-$5F78 | 1064 | 18% | LOW VALUES | 11_gap_5b50_1064bytes.txt |
| $5796-$5AB1 | 795 | 100% | MIXED DATA | 12_gap_5796_795bytes.txt |
| $6DB8-$705B | 675 | 83% | MIXED DATA | 13_gap_6db8_675bytes.txt |

## 🎯 Next Actions

1. **Review $02491** (172 calls) - Core algorithm identification
2. **Review $14300** (15 tables) - Feature cluster analysis
3. **Review $05B50-$05F78** (1,064 bytes) - Largest gap investigation
4. **Cross-reference JSR targets** with XDF documentation
5. **Identify table purposes** from code context
