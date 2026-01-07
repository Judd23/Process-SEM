# Checklist: PSW Covariate Expansion (Time-Load + STEM Intent)

## Purpose
Success means `hacadpr13`, `tcare`, and `StemMaj` are integrated into the synthetic dataset and PSW pipeline with diagnostics and guards passing.

## Scope lock
- Allowed changes:
  - `1_Dataset/`
  - `2_Codebooks/`
  - `3_Analysis/`
  - `4_Model_Results/`
  - `results/`
- Disallowed changes:
  - Everything else
- Stop rule:
  - If a task requires touching a disallowed area, STOP and report why + the minimal alternative.

## Inputs
- Branch / commit: current working tree (no fixed commit)
- Data / seeds: `1_Dataset/generate_empirical_dataset.py` (seed = 42); `1_Dataset/rep_data.csv`
- Config flags: default generator settings (none specified)
- References:
  - `.claude/docs/dissertation_context.md`
  - `2_Codebooks/BCSSE_Codebook.xlsx`
  - `2_Codebooks/BCSSE2024_US First Year Student (Web only).docx`
  - `2_Codebooks/Variable_Table.csv`

## Evidence rules (how to check a box)
A box may be checked only if evidence is attached directly under it:
- Command output (paste)
- Link to CI run
- Table of metrics
- Screenshot
- Diff snippet (short)

Approval rule: I will request approval before starting each new phase (Treatment 1–5).

---

## Treatment 1: Build / Schema
- [x] ~~Add/verify variables: `hacadpr13`, `tcare`, `StemMaj`~~  
  **Evidence:**  
  ```
  columns contains: True
  ```
- [x] ~~Add centered versions / coding conventions (`hacadpr13_num`, `tcare_num`, `hacadpr13_num_c`, `tcare_num_c`, `StemMaj_c`)~~  
  **Evidence:**  
  ```
  hacadpr13_num_c mean: 0.000000
  tcare_num_c mean: 0.000000
  StemMaj_c mean: 0.000000
  ```
- [x] ~~Export artifacts contain new fields~~  
  **Evidence:**  
  ```
  columns contains: True
  ```

### Validation Gate 1 (must pass before Treatment 2)
- [x] ~~Frequency tables match targets within tolerance~~  
  **Evidence:**  
  ```
  Hacadpr13 % by category:
  1     0.98
  2    31.50
  3    29.18
  4    18.40
  5    10.08
  6     5.12
  7     1.86
  8     2.88
  ```
- [x] ~~No out-of-range values~~  
  **Evidence:**  
  ```
  hacadpr13 range: 1 8
  tcare range: 1 8
  hacadpr13_num range: 0.0 35.0
  tcare_num range: 0.0 35.0
  ```
- [x] ~~Centered vars have mean ~ 0 (report exact mean)~~  
  **Evidence:**  
  ```
  hacadpr13_num_c mean: 0.000000
  tcare_num_c mean: 0.000000
  StemMaj_c mean: 0.000000
  ```

---

## Treatment 2: Calibration / Conditioning
- [x] ~~Fit marginals to targets (report exact %)~~  
  **Evidence:**  
  ```
  Hacadpr13 % by category:
  1     0.98
  2    31.50
  3    29.18
  4    18.40
  5    10.08
  6     5.12
  7     1.86
  8     2.88

  Tcare % by category:
  1    68.94
  2    15.72
  3     7.28
  4     3.84
  5     2.20
  6     0.90
  7     0.62
  8     0.50

  StemMaj %:
  0    75.98
  1    24.02
  ```
- [x] ~~Archetype conditioning applied (report subgroup summaries)~~  
  **Evidence:**  
  ```
  Archetype 1 (Latina Commuter Caretaker):
    hacadpr13 mean: 8.54
    tcare mean: 3.30
    StemMaj %: 17.00

  Archetype 3 (Asian High-Pressure Achiever):
    hacadpr13 mean: 14.56
    tcare mean: 1.09
    StemMaj %: 40.00
  ```
- [x] ~~Correlation sign checks (report r values)~~  
  **Evidence:**  
  ```
  corr(hgrades, hacadpr13_num) = 0.141
  corr(tcare_num, hacadpr13_num) = -0.049
  corr(StemMaj, hgrades) = 0.224
  ```

### Validation Gate 2
- [x] ~~Marginals still within tolerance after conditioning~~  
  **Evidence:**  
  ```
  Hacadpr13 % by category:
  1     0.98
  2    31.50
  3    29.18
  4    18.40
  5    10.08
  6     5.12
  7     1.86
  8     2.88
  ```
- [x] ~~Subgroup distributions plausible (no extreme collapse)~~  
  **Evidence:**  
  ```
  Archetype 1 (Latina Commuter Caretaker):
    hacadpr13 mean: 8.54
    tcare mean: 3.30
    StemMaj %: 17.00

  Archetype 3 (Asian High-Pressure Achiever):
    hacadpr13 mean: 14.56
    tcare mean: 1.09
    StemMaj %: 40.00
  ```

---

## Treatment 3: Missingness
- [ ] MCAR missingness applied (report % by variable)  
  **Evidence:**  
- [ ] MAR missingness applied (report % by group)  
  **Evidence:**  
- [ ] PS model still fits with missingness strategy  
  **Evidence:**  

### Validation Gate 3
- [ ] Missingness summary table created (overall + by key groups)  
  **Evidence:**  
- [ ] No accidental 0% or runaway missingness  
  **Evidence:**  

---

## Treatment 4: PS Model + Weights
- [ ] Update PS formula (paste exact formula)  
  **Evidence:**  
- [ ] Compute propensity + overlap weights  
  **Evidence:**  
- [ ] Export weighted dataset with diagnostics  
  **Evidence:**  

### Validation Gate 4
- [ ] Coefficient directions sanity check (report ORs)  
  **Evidence:**  
- [ ] Overlap diagnostics (PS quantiles + weight quantiles)  
  **Evidence:**  
- [ ] ESS computed (report values)  
  **Evidence:**  

---

## Treatment 5: Balance + Unit Tests
- [ ] Balance table updated (SMD + variance ratios)  
  **Evidence:**  
- [ ] Distributional balance plots or eCDF/QQ checks added  
  **Evidence:**  
- [ ] Unit-test checks added (fail loudly)  
  **Evidence:**  
- [ ] Run report updated (what changed + why)  
  **Evidence:**  

### Final Acceptance Gate (Definition of Done)
- [ ] All validation gates passed  
  **Evidence:**  
- [ ] Reproducibility confirmed (seed + hashes if used)  
  **Evidence:**  
- [ ] No out-of-scope changes (confirm via git diff summary)  
  **Evidence:**  

---

## Debug log (append-only)
Each entry:
- Timestamp:
- What failed:
- Hypothesis:
- Experiment:
- Result:
- Next action:
