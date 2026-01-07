# PSW Balance Diagnostics
## Weight Diagnostics
- Weight column: `psw`
- psw summary: min=0.223, p01=0.259, median=0.922, p99=2.094, max=2.252
- Effective sample size (ESS), overall: 4028.1344
- ESS in x_FASt=0: 2314.6255
- ESS in x_FASt=1: 1782.5942

## Covariate Balance (max |SMD| across levels)
Rule of thumb: |SMD| < 0.10 is often considered good balance; < 0.20 is usually acceptable.

| Covariate | max |SMD| (pre) | max |SMD| (post, PSW) |
|---|---:|---:|
| bparented_c | 0.8121 | 0.0000 |
| hgrades_c | 0.6624 | 0.0000 |
| pell | 0.6576 | 0.0934 |
| hapcl | 0.3611 | 0.0000 |
| hprecalc13 | 0.2148 | 0.0000 |
| cSFcareer_c | 0.0120 | 0.0000 |
| hchallenge_c | 0.0047 | 0.0000 |
| cohort | 0.0024 | 0.0000 |
