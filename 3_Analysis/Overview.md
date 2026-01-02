# Analysis

This folder contains all R and Python scripts for running the analysis.

## Subfolders

### 1_Main_Pipeline_Code/
The main entry point for running the complete analysis:
- **run_all_RQs_official.R** — Runs RQ1–RQ4 with bootstrap CIs

### 2_Bootstrap_Code/
Bootstrap inference scripts:
- `bootstrap_full_pipeline.R` — Full causal pipeline bootstrap
- `bootstrap_serial_mediation.R` — Serial mediation model
- `bootstrap_total_effect.R` — Total effect estimation

### 3_Tables_Code/
Table generation (Python):
- `build_dissertation_tables.py` — APA 7 tables (Word format)
- `build_bootstrap_tables.py` — Bootstrap results tables

### 4_Plots_Code/
Figure generation (Python):
- `plot_descriptives.py` — Basic descriptive figures
- `plot_deep_cuts.py` — Advanced visualizations
- `plot_standards_comparison.py` — Methodology standards

### 5_Utilities_Code/
Supporting utilities:
- `cfa_all_constructs.R` — CFA validation
- `generate_realistic_rep_data.py` — Data generation
- `apa7_theme.R` — ggplot theme
- `make_*.R` — Diagram/table utilities

## How to Run

```bash
# From repo root:
Rscript 3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R
```

## Requirements

- R 4.5+ with lavaan (≥0.6-21), semTools, mice
- Python 3.10+ with pandas, python-docx, matplotlib
- See `_Setup/requirements.txt` for full dependency list
