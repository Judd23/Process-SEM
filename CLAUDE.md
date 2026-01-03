# Process-SEM

Ed.D. dissertation project: Conditional-Process Structural Equation Model analysis examining how accelerated dual credit participation (FASt status) affects first-year developmental adjustment among equity-impacted California State University students.

**Research Model:** FASt Status → Emotional Distress / Quality of Engagement → Developmental Adjustment, moderated by credit dose.

## Tech Stack

**R 4.5+** (primary - statistical modeling):
- lavaan (>=0.6-21) - SEM/CFA analysis
- semTools - Diagnostics and extensions
- mice - Multiple imputation
- parallel - Bootstrap parallelization

**Python 3.9+** (secondary - visualization/tables):
- pandas, numpy, scipy - Data processing
- matplotlib, seaborn - Visualization
- python-docx - APA 7 table generation
- pytest, pytest-cov - Testing

## Directory Structure

```
Process-SEM/
├── 1_Dataset/           # Analysis data (rep_data.csv, N=5,000)
├── 2_Codebooks/         # Variable dictionaries (Variable_Table.csv, survey codebooks)
├── 3_Analysis/          # Scripts organized by stage
│   ├── 1_Main_Pipeline_Code/   # Entry point orchestrator
│   ├── 2_Bootstrap_Code/       # Resampling inference
│   ├── 3_Tables_Code/          # Report generation (Python)
│   ├── 4_Plots_Code/           # Visualization (Python)
│   └── 5_Utilities_Code/       # Shared helpers
├── 4_Model_Results/     # Outputs (Tables/, Figures/, Summary/, Outputs/)
├── 5_Statistical_Models/# Model specifications (models/, themes/, utils/)
└── _Setup/              # Dependencies (requirements.txt)
```

## Essential Commands

### Full Analysis Pipeline
```bash
Rscript 3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R
```

### Python Environment Setup
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r _Setup/requirements.txt
```

### Quick Verification (fast smoke test)
```bash
TABLE_CHECK_MODE=1 Rscript 3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R
```

### Generate Tables
```bash
python 3_Analysis/3_Tables_Code/build_dissertation_tables.py --outdir 4_Model_Results/Tables
python 3_Analysis/3_Tables_Code/build_bootstrap_tables.py
```

### Generate Plots
```bash
python 3_Analysis/4_Plots_Code/plot_descriptives.py
python 3_Analysis/4_Plots_Code/plot_deep_cuts.py
```

### Run Tests
```bash
pytest
```

## Key Entry Points

| Purpose | File |
|---------|------|
| Main pipeline | `3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R` |
| Model specification | `5_Statistical_Models/models/mg_fast_vs_nonfast_model.R` |
| Dataset | `1_Dataset/rep_data.csv` |
| Variable dictionary | `2_Codebooks/Variable_Table.csv` |
| Python dependencies | `_Setup/requirements.txt` |

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `OUT_BASE` | Output directory | `4_Model_Results/Outputs` |
| `B_BOOT_MAIN` | Bootstrap replicates (main) | `2000` |
| `BOOT_CI_TYPE_MAIN` | CI method | `bca.simple` |
| `W_SELECT` | W moderators to test (e.g., `"1,3,4"`) | All (W1-W5) |
| `TABLE_CHECK_MODE` | Quick verification mode | `0` |
| `SMOKE_ONLY_A` | Run only RQ1-RQ3 | `0` |
| `BOOTSTRAP_MG` | Bootstrap multi-group | `0` |

See `run_all_RQs_official.R:51-172` for complete list.

## VS Code Tasks

Pre-configured tasks available (`.vscode/tasks.json`):
- **PSW Stage** - Compute overlap weights
- **SEM Stage** - Run weighted lavaan model
- **PSW + SEM** - Full sequential pipeline

## Additional Documentation

| Document | When to Reference |
|----------|-------------------|
| `.claude/docs/architectural_patterns.md` | Understanding design patterns, naming conventions, validation strategies |
| `0_Overview.md` | Conceptual model, research questions, variable definitions |
| `4_Model_Results/Summary/Key_Findings_Summary.md` | Interpreting results |
| `2_Codebooks/Variable_Table.csv` | Variable meanings and coding |
