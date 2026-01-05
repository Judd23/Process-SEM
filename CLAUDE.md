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

**Webapp** (React 19 + TypeScript + Vite):
- Interactive research visualization platform
- D3.js for SEM pathway diagrams
- CSS-only scroll animations (Intersection Observer)
- React Router v6 with HashRouter (GitHub Pages compatibility)
- CSS Modules for component-scoped styling
- Node 18+ / npm 9+
- Build output: `webapp/dist`
- Deployed to GitHub Pages

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
├── webapp/              # Interactive research visualization platform
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

### Webapp Development
```bash
cd webapp
npm install
npm run dev      # Start dev server
npm run build    # Production build
npm run deploy   # Deploy to GitHub Pages
```

## Key Entry Points

| Purpose | File |
|---------|------|
| Main pipeline | `3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R` |
| Model specification | `5_Statistical_Models/models/mg_fast_vs_nonfast_model.R` |
| Dataset | `1_Dataset/rep_data.csv` |
| Variable dictionary | `2_Codebooks/Variable_Table.csv` |
| Python dependencies | `_Setup/requirements.txt` |
| Webapp entry | `webapp/src/App.tsx` |
| Webapp data (from R pipeline) | `webapp/src/data/*.json` |

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

## Webapp Architecture

**Live URL:** https://judd23.github.io/Dissertation-Model-Simulation

### Structure
```
webapp/src/
├── components/
│   ├── charts/       # PathwayDiagram (D3), DoseResponseCurve, GroupComparison
│   ├── layout/       # Header (with scroll progress bar), Footer, Layout
│   └── ui/           # StatCard, Slider, Toggle, ThemeToggle
├── context/          # ThemeContext, ResearchContext, ModelDataContext
├── data/             # JSON from R pipeline (modelResults, doseEffects, etc.)
├── hooks/            # useScrollReveal (Intersection Observer animations)
├── pages/            # 7 pages: Landing, Home, Dose, Demographics, Pathway, Methods, Researcher
└── styles/           # variables.css (design tokens), global.css (animation system)
```

### Design System
- **Colors**: Semantic construct colors (distress=red, engagement=blue, FASt=orange)
- **Typography**: Source Serif Pro (headings), Source Sans Pro (body)
- **Animations**: CSS-only with `useScrollReveal` hook, respects `prefers-reduced-motion`
- **Themes**: Light/dark mode with system preference detection

### Key Patterns
- **Data Flow**: R pipeline → JSON exports → React context → components (no hardcoded values)
- **Editorial/storytelling layout**: Scroll-triggered reveals with `useScrollReveal` hook
- **Sticky controls**: PathwayPage controls with glassmorphism backdrop-filter
- **Header scroll progress**: Gradient bar (accent → engagement) tracks page position
- **Responsive breakpoints**: 480px (mobile), 768px (tablet), 1024px (desktop)
- **Theme switching**: Light/dark mode with CSS custom properties + system preference detection

## Development Workflow

### Typical Development Sequence
1. **Modify statistical models** in R (e.g., `5_Statistical_Models/models/`)
2. **Run pipeline** to generate updated JSON: `Rscript 3_Analysis/1_Main_Pipeline_Code/run_all_RQs_official.R`
3. **Copy JSON outputs** to `webapp/src/data/` (if not automated)
4. **Test webapp locally**: `cd webapp && npm run dev`
5. **Build and deploy**: `npm run build && npm run deploy`

### Data Update Flow
```
R lavaan model → run_all_RQs_official.R → JSON exports → webapp/src/data/
                                                              ↓
                                              ModelDataContext.tsx reads JSON
                                                              ↓
                                              Components consume via useModelData()
```

## Performance Notes

- **Bootstrap replicates**: Default `B_BOOT_MAIN=2000` takes ~15-20 min. Reduce to 500 for testing.
- **Webapp bundle size**: ~450KB gzipped (D3.js is largest dependency)
- **Large datasets**: rep_data.csv (N=5,000) loads in <1s with lavaan caching

## Troubleshooting

### R Pipeline Issues
- **lavaan won't install**: Ensure R >= 4.5, try `install.packages("lavaan", dependencies=TRUE)`
- **Missing packages**: Run `install.packages(c("semTools", "mice", "parallel"))`
- **Bootstrap timeout**: Reduce `B_BOOT_MAIN` or increase `parallel::detectCores()` usage

### Python Issues
- **Module not found**: Activate venv first (`source .venv/bin/activate`)
- **pandas/numpy conflicts**: Use fresh venv, install from `requirements.txt`

### Webapp Issues
- **Build fails**: Check Node version (`node -v` should be 18+), run `npm install` again
- **GitHub Pages 404**: Ensure `vite.config.ts` has `base: '/Dissertation-Model-Simulation/'`
- **Dark mode broken**: Clear browser cache, check CSS custom properties in DevTools
- **Animations janky**: Verify `prefers-reduced-motion` isn't enabled, check browser support for Intersection Observer

## UX Recommendations & Roadmap

For detailed webapp improvement recommendations, see:
- 23 UX/responsiveness/learning recommendations from January 2026 audit
- Priority quick wins: Touch targets (44px min), sticky control feedback, responsive PathwayDiagram
- Future roadmap: Guided tour, glossary tooltips, keyboard navigation for D3 diagram

## Additional Documentation

| Document | When to Reference |
|----------|-------------------|
| `.claude/docs/architectural_patterns.md` | Understanding design patterns, naming conventions, validation strategies |
| `0_Overview.md` | Conceptual model, research questions, variable definitions |
| `4_Model_Results/Summary/Key_Findings_Summary.md` | Interpreting results |
| `2_Codebooks/Variable_Table.csv` | Variable meanings and coding |
