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

---

# Data Construct Checklist

Note: I will strike through each checklist item after it has been completed and validated.
Note: I will request approval before starting each new phase (Treatment 1–5).

Reference: .claude/docs/dissertation_context.md

AGENT PROMPT: Expand the PSW covariate set with time-load + STEM intent covariates and integrate into the current synthetic dataset + pipeline

- [ ] Add/verify `hacadpr13`, `tcare`, `StemMaj` in `rep_data` and pipeline exports
- [ ] Create modeling versions: `hacadpr13_num`, `tcare_num`, `hacadpr13_num_c`, `tcare_num_c`, `StemMaj` (and optional `StemMaj_c`)
- [ ] Ensure centering safeguards align with new `_c` variables
- [ ] Validate `hacadpr13` frequency targets within tolerance
- [ ] Document and validate `tcare` distribution (source or conservative assumption)
- [ ] Document and validate `StemMaj` distribution (source or benchmark)
- [ ] Print distributions overall + by archetype + by `x_FASt`
- [ ] Confirm midpoint recodes bounded and centered means near 0
- [ ] Add archetype conditioning rules and re-balance marginals if needed
- [ ] Check correlation signs: `hgrades` vs `hacadpr13_num` (+), `tcare_num` vs `hacadpr13_num` (-), `StemMaj` vs prep (+)
- [ ] Inject missingness (MCAR + MAR) with low missingness for new PS covariates
- [ ] Add missingness summaries overall + by race + by archetype (incl. new covariates, MHW, QI)
- [ ] Expand PS model to include `hacadpr13_num_c`, `tcare_num_c`, `StemMaj` (or `StemMaj_c`)
- [ ] Recompute PSW (ATO) and export weighted dataset
- [ ] Add PS coefficient direction checks for new covariates
- [ ] Report PS distribution, weight distribution, and ESS (overall + by group)
- [ ] Update balance diagnostics (SMD/VR + eCDF/QQ) for new covariates
- [ ] Add fail-loud guards for distribution drift, balance, variance ratio, and ESS thresholds
- [ ] Update documentation artifacts and variable inventory with new covariates
- [ ] Produce a short run report: distributions, missingness, PS directions, balance, ESS, issues
