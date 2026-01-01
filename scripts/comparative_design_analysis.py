#!/usr/bin/env python3
"""
Comparative Design Analysis: Original Moderated Mediation vs. RD Piecewise
============================================================================
Creates formal comparison tables and side-by-side visualizations for dissertation.

Author: Jay Johnson
Date: December 31, 2025
"""

import json
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path
from datetime import datetime

# Set up paths
RESULTS_DIR = Path("results/fast_treat_control/official_all_RQs")
OUTPUT_DIR = RESULTS_DIR / "comparative_design"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ============================================================================
# Data from Bootstrap Results
# ============================================================================

# Original Moderated Mediation (x_FASt/XZ_c parameterization)
ORIGINAL_PARALLEL = {
    "a1": {"est": 0.202, "se": 0.056, "ci_lo": 0.096, "ci_hi": 0.313, "sig": True},
    "a1z": {"est": 0.166, "se": 0.022, "ci_lo": 0.123, "ci_hi": 0.210, "sig": True},
    "a2": {"est": 0.021, "se": 0.070, "ci_lo": -0.115, "ci_hi": 0.161, "sig": False},
    "a2z": {"est": -0.260, "se": 0.029, "ci_lo": -0.315, "ci_hi": -0.204, "sig": True},
    "b1": {"est": -0.140, "se": 0.017, "ci_lo": -0.175, "ci_hi": -0.111, "sig": True},
    "b2": {"est": 0.108, "se": 0.013, "ci_lo": 0.084, "ci_hi": 0.134, "sig": True},
    "c": {"est": -0.021, "se": 0.021, "ci_lo": -0.063, "ci_hi": 0.021, "sig": False},
    "cz": {"est": 0.020, "se": 0.011, "ci_lo": 0.000, "ci_hi": 0.042, "sig": True},
    "ind_EmoDiss_z_mid": {"est": -0.028, "se": 0.008, "ci_lo": -0.046, "ci_hi": -0.013, "sig": True},
    "ind_EmoDiss_z_high": {"est": -0.058, "se": 0.009, "ci_lo": -0.077, "ci_hi": -0.042, "sig": True},
    "ind_QualEngag_z_mid": {"est": 0.002, "se": 0.008, "ci_lo": -0.012, "ci_hi": 0.017, "sig": False},
    "ind_QualEngag_z_high": {"est": -0.034, "se": 0.007, "ci_lo": -0.048, "ci_hi": -0.021, "sig": True},
    "total_z_mid": {"est": -0.047, "se": 0.023, "ci_lo": -0.094, "ci_hi": -0.003, "sig": True},
    "total_z_high": {"est": -0.086, "se": 0.017, "ci_lo": -0.121, "ci_hi": -0.054, "sig": True},
    "index_MM_EmoDiss": {"est": -0.023, "se": 0.004, "ci_lo": -0.032, "ci_hi": -0.016, "sig": True},
    "index_MM_QualEngag": {"est": -0.028, "se": 0.004, "ci_lo": -0.038, "ci_hi": -0.020, "sig": True},
}

ORIGINAL_SERIAL = {
    "d": {"est": -0.222, "se": 0.042, "ci_lo": -0.305, "ci_hi": -0.141, "sig": True},
    "ind_serial_z_mid": {"est": -0.005, "se": 0.002, "ci_lo": -0.008, "ci_hi": -0.002, "sig": True},
    "ind_serial_z_high": {"est": -0.010, "se": 0.002, "ci_lo": -0.014, "ci_hi": -0.006, "sig": True},
    "index_MM_serial": {"est": -0.004, "se": 0.001, "ci_lo": -0.006, "ci_hi": -0.002, "sig": True},
}

# RD Piecewise Parameterization
RD_PARALLEL = {
    "a1_pre": {"est": 0.421, "se": 0.055, "ci_lo": 0.316, "ci_hi": 0.530, "sig": True},
    "a1_post": {"est": 0.186, "se": 0.024, "ci_lo": 0.139, "ci_hi": 0.233, "sig": True},
    "a2_pre": {"est": -0.030, "se": 0.056, "ci_lo": -0.141, "ci_hi": 0.079, "sig": False},
    "a2_post": {"est": -0.264, "se": 0.025, "ci_lo": -0.315, "ci_hi": -0.215, "sig": True},
    "b1": {"est": -0.389, "se": 0.042, "ci_lo": -0.476, "ci_hi": -0.311, "sig": True},
    "b2": {"est": 0.450, "se": 0.038, "ci_lo": 0.376, "ci_hi": 0.523, "sig": True},
    "c_pre": {"est": -0.033, "se": 0.072, "ci_lo": -0.172, "ci_hi": 0.108, "sig": False},
    "c_post": {"est": 0.079, "se": 0.040, "ci_lo": -0.001, "ci_hi": 0.158, "sig": False},
    "delta_a1": {"est": -0.235, "se": 0.070, "ci_lo": -0.372, "ci_hi": -0.103, "sig": True},
    "delta_a2": {"est": -0.234, "se": 0.072, "ci_lo": -0.369, "ci_hi": -0.094, "sig": True},
    "delta_c": {"est": 0.112, "se": 0.096, "ci_lo": -0.077, "ci_hi": 0.295, "sig": False},
    "ind_emo_pre": {"est": -0.164, "se": 0.028, "ci_lo": -0.223, "ci_hi": -0.115, "sig": True},
    "ind_emo_post": {"est": -0.073, "se": 0.012, "ci_lo": -0.097, "ci_hi": -0.051, "sig": True},
    "ind_qual_pre": {"est": -0.014, "se": 0.025, "ci_lo": -0.064, "ci_hi": 0.036, "sig": False},
    "ind_qual_post": {"est": -0.119, "se": 0.015, "ci_lo": -0.150, "ci_hi": -0.091, "sig": True},
    "total_pre": {"est": -0.210, "se": 0.075, "ci_lo": -0.359, "ci_hi": -0.066, "sig": True},
    "total_post": {"est": -0.112, "se": 0.041, "ci_lo": -0.195, "ci_hi": -0.038, "sig": True},
}

RD_SERIAL = {
    "d": {"est": -0.172, "se": 0.031, "ci_lo": -0.232, "ci_hi": -0.108, "sig": True},
    "serial_pre": {"est": -0.031, "se": 0.008, "ci_lo": -0.048, "ci_hi": -0.018, "sig": True},
    "serial_post": {"est": -0.014, "se": 0.003, "ci_lo": -0.021, "ci_hi": -0.008, "sig": True},
}

# ============================================================================
# Collinearity Comparison
# ============================================================================

COLLINEARITY = {
    "original": {
        "cor_dose_xz": 0.957,
        "vif_dose": 15.2,
        "vif_xz": 15.8,
    },
    "rd": {
        "cor_r_minus_r_plus": 0.498,
        "vif_r_minus": 1.33,
        "vif_r_plus": 1.33,
    }
}

# ============================================================================
# Helper Functions
# ============================================================================

def format_estimate(d, decimals=3):
    """Format estimate with CI and significance star."""
    est = d["est"]
    ci_lo = d["ci_lo"]
    ci_hi = d["ci_hi"]
    sig = d.get("sig", False)
    star = "***" if sig else ""
    return f"{est:.{decimals}f}{star} [{ci_lo:.{decimals}f}, {ci_hi:.{decimals}f}]"

def format_short(d, decimals=2):
    """Format estimate with just significance star."""
    est = d["est"]
    sig = d.get("sig", False)
    star = "***" if sig else ""
    return f"{est:.{decimals}f}{star}"


# ============================================================================
# Create Formal Comparison Table (Markdown + LaTeX)
# ============================================================================

def create_comparison_table():
    """Create formal comparison tables for dissertation."""
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Markdown Table
    md_content = f"""# Comparative Design Analysis
## Original Moderated Mediation vs. RD Piecewise Parameterization

*Generated: {timestamp}*

---

## Table 1: Model Specification Comparison

| Aspect | Original Moderated Mediation | RD Piecewise |
|--------|------------------------------|--------------|
| **Treatment Variable** | x_FASt (0/1 indicator) | —— |
| **Running Variable** | credit_dose_c (centered) | r = trnsfr_cr − 12 |
| **Pre-Cutoff Slope** | —— | r_minus = min(r, 0) / 10 |
| **Post-Cutoff Slope** | —— | r_plus = max(r, 0) / 10 |
| **Interaction** | XZ_c = x_FASt × credit_dose_c | —— |
| **Discontinuity Test** | Not explicit | δ parameters (delta_a1, delta_a2) |

---

## Table 2: Collinearity Diagnostics

| Metric | Original | RD Piecewise | Improvement |
|--------|----------|--------------|-------------|
| **Key Correlation** | cor(dose_c, XZ_c) = **{COLLINEARITY['original']['cor_dose_xz']:.3f}** | cor(r_minus, r_plus) = **{COLLINEARITY['rd']['cor_r_minus_r_plus']:.3f}** | **{(1 - COLLINEARITY['rd']['cor_r_minus_r_plus']/COLLINEARITY['original']['cor_dose_xz'])*100:.0f}% reduction** |
| **VIF (Dose/Pre)** | {COLLINEARITY['original']['vif_dose']:.1f} | {COLLINEARITY['rd']['vif_r_minus']:.2f} | **{COLLINEARITY['original']['vif_dose']/COLLINEARITY['rd']['vif_r_minus']:.1f}× reduction** |
| **VIF (XZ/Post)** | {COLLINEARITY['original']['vif_xz']:.1f} | {COLLINEARITY['rd']['vif_r_plus']:.2f} | **{COLLINEARITY['original']['vif_xz']/COLLINEARITY['rd']['vif_r_plus']:.1f}× reduction** |
| **Collinearity Concern** | ⚠️ **Severe** (VIF > 10) | ✅ None (VIF < 5) | **Resolved** |

---

## Table 3: Parallel Mediation — Path Coefficients

### 3a. Paths to Emotional Distress (EmoDiss)

| Path | Original Estimate | RD Estimate | Interpretation |
|------|-------------------|-------------|----------------|
| **Main FASt → EmoDiss (a1)** | {format_estimate(ORIGINAL_PARALLEL['a1'])} | —— | Positive: FASt ↑ distress |
| **Moderation (a1z)** | {format_estimate(ORIGINAL_PARALLEL['a1z'])} | —— | More credits → stronger effect |
| **Pre-cutoff slope** | —— | {format_estimate(RD_PARALLEL['a1_pre'])} | Credits ↑ distress below threshold |
| **Post-cutoff slope** | —— | {format_estimate(RD_PARALLEL['a1_post'])} | Credits ↑ distress above threshold |
| **Discontinuity (δ_a1)** | —— | {format_estimate(RD_PARALLEL['delta_a1'])} | **Attenuated** at threshold |

### 3b. Paths to Quality of Engagement (QualEngag)

| Path | Original Estimate | RD Estimate | Interpretation |
|------|-------------------|-------------|----------------|
| **Main FASt → QualEngag (a2)** | {format_estimate(ORIGINAL_PARALLEL['a2'])} | —— | Non-significant main effect |
| **Moderation (a2z)** | {format_estimate(ORIGINAL_PARALLEL['a2z'])} | —— | More credits → ↓ engagement |
| **Pre-cutoff slope** | —— | {format_estimate(RD_PARALLEL['a2_pre'])} | Non-significant below threshold |
| **Post-cutoff slope** | —— | {format_estimate(RD_PARALLEL['a2_post'])} | Credits ↓ engagement above threshold |
| **Discontinuity (δ_a2)** | —— | {format_estimate(RD_PARALLEL['delta_a2'])} | **Sharp drop** at threshold |

### 3c. Paths to Developmental Adjustment (DevAdj)

| Path | Original Estimate | RD Estimate | Interpretation |
|------|-------------------|-------------|----------------|
| **EmoDiss → DevAdj (b1)** | {format_estimate(ORIGINAL_PARALLEL['b1'])} | {format_estimate(RD_PARALLEL['b1'])} | Distress ↓ adjustment |
| **QualEngag → DevAdj (b2)** | {format_estimate(ORIGINAL_PARALLEL['b2'])} | {format_estimate(RD_PARALLEL['b2'])} | Engagement ↑ adjustment |
| **Direct Effect (c')** | {format_estimate(ORIGINAL_PARALLEL['c'])} | Pre: {format_short(RD_PARALLEL['c_pre'])} / Post: {format_short(RD_PARALLEL['c_post'])} | Non-significant |

---

## Table 4: Indirect and Total Effects

### 4a. Original Model (Conditional at Z levels)

| Effect | At Mean Dose (Z=0) | At High Dose (Z=+1SD) |
|--------|--------------------|-----------------------|
| **Indirect via EmoDiss** | {format_estimate(ORIGINAL_PARALLEL['ind_EmoDiss_z_mid'])} | {format_estimate(ORIGINAL_PARALLEL['ind_EmoDiss_z_high'])} |
| **Indirect via QualEngag** | {format_estimate(ORIGINAL_PARALLEL['ind_QualEngag_z_mid'])} | {format_estimate(ORIGINAL_PARALLEL['ind_QualEngag_z_high'])} |
| **Total Effect** | {format_estimate(ORIGINAL_PARALLEL['total_z_mid'])} | {format_estimate(ORIGINAL_PARALLEL['total_z_high'])} |

**Moderated Mediation Indices:**
- Index MM (EmoDiss): {format_estimate(ORIGINAL_PARALLEL['index_MM_EmoDiss'])}
- Index MM (QualEngag): {format_estimate(ORIGINAL_PARALLEL['index_MM_QualEngag'])}

### 4b. RD Model (Pre vs. Post Cutoff)

| Effect | Pre-Cutoff (per 10 credits) | Post-Cutoff (per 10 credits) |
|--------|-----------------------------|-----------------------------|
| **Indirect via EmoDiss** | {format_estimate(RD_PARALLEL['ind_emo_pre'])} | {format_estimate(RD_PARALLEL['ind_emo_post'])} |
| **Indirect via QualEngag** | {format_estimate(RD_PARALLEL['ind_qual_pre'])} | {format_estimate(RD_PARALLEL['ind_qual_post'])} |
| **Total Effect** | {format_estimate(RD_PARALLEL['total_pre'])} | {format_estimate(RD_PARALLEL['total_post'])} |

---

## Table 5: Serial Mediation (EmoDiss → QualEngag → DevAdj)

| Parameter | Original | RD Piecewise |
|-----------|----------|--------------|
| **d (EmoDiss → QualEngag)** | {format_estimate(ORIGINAL_SERIAL['d'])} | {format_estimate(RD_SERIAL['d'])} |
| **Serial Indirect** | Mid: {format_short(ORIGINAL_SERIAL['ind_serial_z_mid'])} / High: {format_short(ORIGINAL_SERIAL['ind_serial_z_high'])} | Pre: {format_short(RD_SERIAL['serial_pre'])} / Post: {format_short(RD_SERIAL['serial_post'])} |
| **Index MM Serial** | {format_estimate(ORIGINAL_SERIAL['index_MM_serial'])} | —— |

---

## Table 6: Convergent Evidence Summary

| Hypothesis | Original Support | RD Support | Verdict |
|------------|------------------|------------|---------|
| **H1: FASt → EmoDiss mediation** | ✅ Significant at mid/high dose | ✅ Significant pre & post | **Confirmed** |
| **H2: FASt → QualEngag mediation** | ✅ Significant at high dose | ✅ Significant post-cutoff | **Confirmed** |
| **H3: Moderation by credit dose** | ✅ Significant index MM | ✅ Significant discontinuity | **Confirmed** |
| **H4: Serial mediation** | ✅ d = -0.22*** | ✅ d = -0.17*** | **Confirmed** |
| **H5: Negative effects at high dose** | ✅ Total @ high = -0.086*** | ✅ Total post = -0.112*** | **Confirmed** |

---

## Methodological Recommendation

**Primary Analysis**: RD Piecewise Parameterization

**Rationale**:
1. **Eliminates collinearity** — VIF reduced from >15 to <1.5
2. **Respects data-generating process** — FASt status is defined by the 12-credit threshold
3. **Stronger causal claim** — Quasi-experimental RD design
4. **Clearer decomposition** — Separates pre/post effects and discontinuity

**Supplementary Analysis**: Original moderated mediation (robustness check)

---

*Note: *** indicates 95% CI excludes zero. All estimates from B=2000 bootstrap with BCa intervals.*
"""
    
    # Save markdown
    md_path = OUTPUT_DIR / "comparative_design_table.md"
    md_path.write_text(md_content)
    print(f"✅ Saved: {md_path}")
    
    # Create LaTeX version for dissertation
    latex_content = r"""\documentclass{article}
\usepackage{booktabs}
\usepackage{multirow}
\usepackage{array}
\usepackage{xcolor}
\usepackage{colortbl}

\begin{document}

\begin{table}[htbp]
\centering
\caption{Comparative Collinearity Diagnostics}
\label{tab:collinearity}
\begin{tabular}{lccc}
\toprule
\textbf{Metric} & \textbf{Original} & \textbf{RD Piecewise} & \textbf{Improvement} \\
\midrule
Key Correlation & """ + f"{COLLINEARITY['original']['cor_dose_xz']:.3f}" + r""" & """ + f"{COLLINEARITY['rd']['cor_r_minus_r_plus']:.3f}" + r""" & """ + f"{(1 - COLLINEARITY['rd']['cor_r_minus_r_plus']/COLLINEARITY['original']['cor_dose_xz'])*100:.0f}" + r"""\% reduction \\
VIF (Dose/Pre) & """ + f"{COLLINEARITY['original']['vif_dose']:.1f}" + r""" & """ + f"{COLLINEARITY['rd']['vif_r_minus']:.2f}" + r""" & """ + f"{COLLINEARITY['original']['vif_dose']/COLLINEARITY['rd']['vif_r_minus']:.1f}" + r"""$\times$ reduction \\
VIF (XZ/Post) & """ + f"{COLLINEARITY['original']['vif_xz']:.1f}" + r""" & """ + f"{COLLINEARITY['rd']['vif_r_plus']:.2f}" + r""" & """ + f"{COLLINEARITY['original']['vif_xz']/COLLINEARITY['rd']['vif_r_plus']:.1f}" + r"""$\times$ reduction \\
\bottomrule
\end{tabular}
\end{table}

\begin{table}[htbp]
\centering
\caption{Path Coefficients: Original vs. RD Piecewise Parameterization}
\label{tab:path_coefficients}
\small
\begin{tabular}{p{4cm}cc}
\toprule
\textbf{Path} & \textbf{Original} & \textbf{RD Piecewise} \\
\midrule
\multicolumn{3}{l}{\textit{Paths to Emotional Distress}} \\
\quad Main FASt $\to$ EmoDiss & """ + f"{format_short(ORIGINAL_PARALLEL['a1'])}" + r""" & --- \\
\quad Moderation (a1z) & """ + f"{format_short(ORIGINAL_PARALLEL['a1z'])}" + r""" & --- \\
\quad Pre-cutoff slope & --- & """ + f"{format_short(RD_PARALLEL['a1_pre'])}" + r""" \\
\quad Post-cutoff slope & --- & """ + f"{format_short(RD_PARALLEL['a1_post'])}" + r""" \\
\quad Discontinuity ($\delta_{a1}$) & --- & """ + f"{format_short(RD_PARALLEL['delta_a1'])}" + r""" \\
\midrule
\multicolumn{3}{l}{\textit{Paths to Quality Engagement}} \\
\quad Main FASt $\to$ QualEngag & """ + f"{format_short(ORIGINAL_PARALLEL['a2'])}" + r""" & --- \\
\quad Moderation (a2z) & """ + f"{format_short(ORIGINAL_PARALLEL['a2z'])}" + r""" & --- \\
\quad Pre-cutoff slope & --- & """ + f"{format_short(RD_PARALLEL['a2_pre'])}" + r""" \\
\quad Post-cutoff slope & --- & """ + f"{format_short(RD_PARALLEL['a2_post'])}" + r""" \\
\quad Discontinuity ($\delta_{a2}$) & --- & """ + f"{format_short(RD_PARALLEL['delta_a2'])}" + r""" \\
\midrule
\multicolumn{3}{l}{\textit{Mediation Paths}} \\
\quad EmoDiss $\to$ DevAdj (b1) & """ + f"{format_short(ORIGINAL_PARALLEL['b1'])}" + r""" & """ + f"{format_short(RD_PARALLEL['b1'])}" + r""" \\
\quad QualEngag $\to$ DevAdj (b2) & """ + f"{format_short(ORIGINAL_PARALLEL['b2'])}" + r""" & """ + f"{format_short(RD_PARALLEL['b2'])}" + r""" \\
\quad EmoDiss $\to$ QualEngag (d) & """ + f"{format_short(ORIGINAL_SERIAL['d'])}" + r""" & """ + f"{format_short(RD_SERIAL['d'])}" + r""" \\
\bottomrule
\end{tabular}
\begin{tablenotes}
\small
\item \textit{Note.} *** $p < .05$ (95\% CI excludes zero). B = 2,000 bootstrap replicates with BCa intervals.
\end{tablenotes}
\end{table}

\end{document}
"""
    
    latex_path = OUTPUT_DIR / "comparative_design_table.tex"
    latex_path.write_text(latex_content)
    print(f"✅ Saved: {latex_path}")
    
    return md_content


# ============================================================================
# Create Side-by-Side Visualization
# ============================================================================

def create_visualization():
    """Create professional side-by-side comparison visualization."""
    
    # Set up the figure with APA-style formatting
    plt.rcParams.update({
        'font.family': 'sans-serif',
        'font.sans-serif': ['Arial', 'Helvetica', 'DejaVu Sans'],
        'font.size': 10,
        'axes.titlesize': 12,
        'axes.labelsize': 10,
        'xtick.labelsize': 9,
        'ytick.labelsize': 9,
        'legend.fontsize': 9,
        'figure.titlesize': 14,
        'axes.spines.top': False,
        'axes.spines.right': False,
    })
    
    fig = plt.figure(figsize=(16, 14))
    
    # Color scheme
    ORIGINAL_COLOR = '#2E86AB'  # Blue
    RD_COLOR = '#A23B72'        # Magenta
    SIG_COLOR = '#28A745'       # Green for significant
    NS_COLOR = '#6C757D'        # Gray for non-significant
    
    # =========================================================================
    # Panel A: Collinearity Comparison
    # =========================================================================
    ax1 = fig.add_subplot(3, 2, 1)
    
    categories = ['Correlation\n(key variables)', 'VIF\n(Dose/Pre)', 'VIF\n(XZ/Post)']
    original_vals = [COLLINEARITY['original']['cor_dose_xz'], 
                     COLLINEARITY['original']['vif_dose'], 
                     COLLINEARITY['original']['vif_xz']]
    rd_vals = [COLLINEARITY['rd']['cor_r_minus_r_plus'], 
               COLLINEARITY['rd']['vif_r_minus'], 
               COLLINEARITY['rd']['vif_r_plus']]
    
    x = np.arange(len(categories))
    width = 0.35
    
    bars1 = ax1.bar(x - width/2, original_vals, width, label='Original', color=ORIGINAL_COLOR, alpha=0.8)
    bars2 = ax1.bar(x + width/2, rd_vals, width, label='RD Piecewise', color=RD_COLOR, alpha=0.8)
    
    # Add value labels
    for bar, val in zip(bars1, original_vals):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3, f'{val:.2f}', 
                 ha='center', va='bottom', fontsize=9, fontweight='bold')
    for bar, val in zip(bars2, rd_vals):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3, f'{val:.2f}', 
                 ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    # Add danger line for VIF
    ax1.axhline(y=10, color='red', linestyle='--', alpha=0.5, label='VIF Threshold (10)')
    
    ax1.set_ylabel('Value')
    ax1.set_title('A. Collinearity Diagnostics', fontweight='bold', loc='left')
    ax1.set_xticks(x)
    ax1.set_xticklabels(categories)
    ax1.legend(loc='upper right')
    ax1.set_ylim(0, 18)
    
    # =========================================================================
    # Panel B: Path Coefficients Comparison (Horizontal)
    # =========================================================================
    ax2 = fig.add_subplot(3, 2, 2)
    
    # Prepare data for horizontal bar chart
    paths = ['b2 (QualEngag→DevAdj)', 'b1 (EmoDiss→DevAdj)', 
             'd (EmoDiss→QualEngag)', 'a2z / a2_post', 'a1z / a1_post']
    original_ests = [ORIGINAL_PARALLEL['b2']['est'], ORIGINAL_PARALLEL['b1']['est'],
                     ORIGINAL_SERIAL['d']['est'], ORIGINAL_PARALLEL['a2z']['est'], 
                     ORIGINAL_PARALLEL['a1z']['est']]
    rd_ests = [RD_PARALLEL['b2']['est'], RD_PARALLEL['b1']['est'],
               RD_SERIAL['d']['est'], RD_PARALLEL['a2_post']['est'], 
               RD_PARALLEL['a1_post']['est']]
    
    y = np.arange(len(paths))
    height = 0.35
    
    bars1 = ax2.barh(y - height/2, original_ests, height, label='Original', color=ORIGINAL_COLOR, alpha=0.8)
    bars2 = ax2.barh(y + height/2, rd_ests, height, label='RD Piecewise', color=RD_COLOR, alpha=0.8)
    
    ax2.axvline(x=0, color='black', linestyle='-', linewidth=0.5)
    ax2.set_xlabel('Standardized Estimate')
    ax2.set_title('B. Key Path Coefficients', fontweight='bold', loc='left')
    ax2.set_yticks(y)
    ax2.set_yticklabels(paths)
    ax2.legend(loc='lower right')
    
    # =========================================================================
    # Panel C: Indirect Effects - Original Model
    # =========================================================================
    ax3 = fig.add_subplot(3, 2, 3)
    
    # Forest plot for original model
    params = ['ind_EmoDiss\n(mid)', 'ind_EmoDiss\n(high)', 'ind_QualEngag\n(mid)', 
              'ind_QualEngag\n(high)', 'serial\n(mid)', 'serial\n(high)']
    ests = [ORIGINAL_PARALLEL['ind_EmoDiss_z_mid']['est'], ORIGINAL_PARALLEL['ind_EmoDiss_z_high']['est'],
            ORIGINAL_PARALLEL['ind_QualEngag_z_mid']['est'], ORIGINAL_PARALLEL['ind_QualEngag_z_high']['est'],
            ORIGINAL_SERIAL['ind_serial_z_mid']['est'], ORIGINAL_SERIAL['ind_serial_z_high']['est']]
    ci_los = [ORIGINAL_PARALLEL['ind_EmoDiss_z_mid']['ci_lo'], ORIGINAL_PARALLEL['ind_EmoDiss_z_high']['ci_lo'],
              ORIGINAL_PARALLEL['ind_QualEngag_z_mid']['ci_lo'], ORIGINAL_PARALLEL['ind_QualEngag_z_high']['ci_lo'],
              ORIGINAL_SERIAL['ind_serial_z_mid']['ci_lo'], ORIGINAL_SERIAL['ind_serial_z_high']['ci_lo']]
    ci_his = [ORIGINAL_PARALLEL['ind_EmoDiss_z_mid']['ci_hi'], ORIGINAL_PARALLEL['ind_EmoDiss_z_high']['ci_hi'],
              ORIGINAL_PARALLEL['ind_QualEngag_z_mid']['ci_hi'], ORIGINAL_PARALLEL['ind_QualEngag_z_high']['ci_hi'],
              ORIGINAL_SERIAL['ind_serial_z_mid']['ci_hi'], ORIGINAL_SERIAL['ind_serial_z_high']['ci_hi']]
    sigs = [ORIGINAL_PARALLEL['ind_EmoDiss_z_mid']['sig'], ORIGINAL_PARALLEL['ind_EmoDiss_z_high']['sig'],
            ORIGINAL_PARALLEL['ind_QualEngag_z_mid']['sig'], ORIGINAL_PARALLEL['ind_QualEngag_z_high']['sig'],
            ORIGINAL_SERIAL['ind_serial_z_mid']['sig'], ORIGINAL_SERIAL['ind_serial_z_high']['sig']]
    
    y = np.arange(len(params))
    colors = [SIG_COLOR if s else NS_COLOR for s in sigs]
    
    ax3.scatter(ests, y, c=colors, s=100, zorder=3)
    for i, (est, lo, hi, sig) in enumerate(zip(ests, ci_los, ci_his, sigs)):
        ax3.plot([lo, hi], [i, i], color=colors[i], linewidth=2)
    
    ax3.axvline(x=0, color='black', linestyle='--', linewidth=0.5)
    ax3.set_xlabel('Indirect Effect')
    ax3.set_title('C. Original: Conditional Indirect Effects', fontweight='bold', loc='left')
    ax3.set_yticks(y)
    ax3.set_yticklabels(params)
    
    # Legend
    sig_patch = mpatches.Patch(color=SIG_COLOR, label='Significant (CI excludes 0)')
    ns_patch = mpatches.Patch(color=NS_COLOR, label='Non-significant')
    ax3.legend(handles=[sig_patch, ns_patch], loc='lower left')
    
    # =========================================================================
    # Panel D: Indirect Effects - RD Model
    # =========================================================================
    ax4 = fig.add_subplot(3, 2, 4)
    
    params = ['ind_emo\n(pre)', 'ind_emo\n(post)', 'ind_qual\n(pre)', 
              'ind_qual\n(post)', 'serial\n(pre)', 'serial\n(post)']
    ests = [RD_PARALLEL['ind_emo_pre']['est'], RD_PARALLEL['ind_emo_post']['est'],
            RD_PARALLEL['ind_qual_pre']['est'], RD_PARALLEL['ind_qual_post']['est'],
            RD_SERIAL['serial_pre']['est'], RD_SERIAL['serial_post']['est']]
    ci_los = [RD_PARALLEL['ind_emo_pre']['ci_lo'], RD_PARALLEL['ind_emo_post']['ci_lo'],
              RD_PARALLEL['ind_qual_pre']['ci_lo'], RD_PARALLEL['ind_qual_post']['ci_lo'],
              RD_SERIAL['serial_pre']['ci_lo'], RD_SERIAL['serial_post']['ci_lo']]
    ci_his = [RD_PARALLEL['ind_emo_pre']['ci_hi'], RD_PARALLEL['ind_emo_post']['ci_hi'],
              RD_PARALLEL['ind_qual_pre']['ci_hi'], RD_PARALLEL['ind_qual_post']['ci_hi'],
              RD_SERIAL['serial_pre']['ci_hi'], RD_SERIAL['serial_post']['ci_hi']]
    sigs = [RD_PARALLEL['ind_emo_pre']['sig'], RD_PARALLEL['ind_emo_post']['sig'],
            RD_PARALLEL['ind_qual_pre']['sig'], RD_PARALLEL['ind_qual_post']['sig'],
            RD_SERIAL['serial_pre']['sig'], RD_SERIAL['serial_post']['sig']]
    
    y = np.arange(len(params))
    colors = [SIG_COLOR if s else NS_COLOR for s in sigs]
    
    ax4.scatter(ests, y, c=colors, s=100, zorder=3)
    for i, (est, lo, hi, sig) in enumerate(zip(ests, ci_los, ci_his, sigs)):
        ax4.plot([lo, hi], [i, i], color=colors[i], linewidth=2)
    
    ax4.axvline(x=0, color='black', linestyle='--', linewidth=0.5)
    ax4.set_xlabel('Indirect Effect (per 10 credits)')
    ax4.set_title('D. RD Piecewise: Pre/Post Indirect Effects', fontweight='bold', loc='left')
    ax4.set_yticks(y)
    ax4.set_yticklabels(params)
    ax4.legend(handles=[sig_patch, ns_patch], loc='lower left')
    
    # =========================================================================
    # Panel E: Total Effects Comparison
    # =========================================================================
    ax5 = fig.add_subplot(3, 2, 5)
    
    # Bar chart comparing total effects
    categories = ['Original\n(mid dose)', 'Original\n(high dose)', 'RD\n(pre-cutoff)', 'RD\n(post-cutoff)']
    totals = [ORIGINAL_PARALLEL['total_z_mid']['est'], ORIGINAL_PARALLEL['total_z_high']['est'],
              RD_PARALLEL['total_pre']['est'], RD_PARALLEL['total_post']['est']]
    errors = [(ORIGINAL_PARALLEL['total_z_mid']['est'] - ORIGINAL_PARALLEL['total_z_mid']['ci_lo'],
               ORIGINAL_PARALLEL['total_z_mid']['ci_hi'] - ORIGINAL_PARALLEL['total_z_mid']['est']),
              (ORIGINAL_PARALLEL['total_z_high']['est'] - ORIGINAL_PARALLEL['total_z_high']['ci_lo'],
               ORIGINAL_PARALLEL['total_z_high']['ci_hi'] - ORIGINAL_PARALLEL['total_z_high']['est']),
              (RD_PARALLEL['total_pre']['est'] - RD_PARALLEL['total_pre']['ci_lo'],
               RD_PARALLEL['total_pre']['ci_hi'] - RD_PARALLEL['total_pre']['est']),
              (RD_PARALLEL['total_post']['est'] - RD_PARALLEL['total_post']['ci_lo'],
               RD_PARALLEL['total_post']['ci_hi'] - RD_PARALLEL['total_post']['est'])]
    
    sigs = [ORIGINAL_PARALLEL['total_z_mid']['sig'], ORIGINAL_PARALLEL['total_z_high']['sig'],
            RD_PARALLEL['total_pre']['sig'], RD_PARALLEL['total_post']['sig']]
    colors = [ORIGINAL_COLOR, ORIGINAL_COLOR, RD_COLOR, RD_COLOR]
    alphas = [0.8 if s else 0.4 for s in sigs]
    
    x = np.arange(len(categories))
    bars = ax5.bar(x, totals, color=colors, alpha=0.8, edgecolor='black', linewidth=1)
    ax5.errorbar(x, totals, yerr=np.array(errors).T, fmt='none', color='black', capsize=5)
    
    # Add stars for significant effects
    for i, (bar, sig) in enumerate(zip(bars, sigs)):
        if sig:
            ax5.text(bar.get_x() + bar.get_width()/2, bar.get_height() - 0.02, '***', 
                     ha='center', va='top', fontsize=12, fontweight='bold', color='white')
    
    ax5.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax5.set_ylabel('Total Effect on DevAdj')
    ax5.set_title('E. Total Effects Comparison', fontweight='bold', loc='left')
    ax5.set_xticks(x)
    ax5.set_xticklabels(categories)
    
    # =========================================================================
    # Panel F: Convergent Validity Summary
    # =========================================================================
    ax6 = fig.add_subplot(3, 2, 6)
    ax6.axis('off')
    
    summary_text = """
    CONVERGENT VALIDITY SUMMARY
    ════════════════════════════════════════════════════════════════════════
    
    Both parameterizations yield consistent substantive conclusions:
    
    ✓  Significant mediation through Emotional Distress (EmoDiss)
    ✓  Significant moderation by credit accumulation
    ✓  Significant serial mediation (EmoDiss → QualEngag → DevAdj)
    ✓  Negative effects at higher doses / post-threshold
    
    KEY DIFFERENCES:
    ────────────────────────────────────────────────────────────────────────
    Original:  Tests "does FASt status moderate the dose-response?"
    RD:        Tests "is there a discontinuity at the 12-credit threshold?"
    
    RECOMMENDATION:
    ────────────────────────────────────────────────────────────────────────
    ★  Primary analysis: RD Piecewise (eliminates collinearity, cleaner causal claim)
    ★  Supplementary: Original moderated mediation (robustness check)
    
    Bootstrap: B = 2,000  |  100% convergence for both models
    """
    
    ax6.text(0.05, 0.95, summary_text, transform=ax6.transAxes, fontsize=10,
             verticalalignment='top', fontfamily='monospace',
             bbox=dict(boxstyle='round', facecolor='#f8f9fa', edgecolor='#dee2e6'))
    ax6.set_title('F. Summary & Recommendation', fontweight='bold', loc='left')
    
    # =========================================================================
    # Finalize
    # =========================================================================
    fig.suptitle('Comparative Design Analysis:\nOriginal Moderated Mediation vs. RD Piecewise Parameterization', 
                 fontsize=14, fontweight='bold', y=0.98)
    
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    
    # Save figures
    png_path = OUTPUT_DIR / "comparative_design_visualization.png"
    pdf_path = OUTPUT_DIR / "comparative_design_visualization.pdf"
    
    fig.savefig(png_path, dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig(pdf_path, bbox_inches='tight', facecolor='white')
    
    print(f"✅ Saved: {png_path}")
    print(f"✅ Saved: {pdf_path}")
    
    plt.close(fig)
    
    return str(png_path)


# ============================================================================
# Create Conceptual Model Diagrams
# ============================================================================

def create_conceptual_diagrams():
    """Create side-by-side conceptual model diagrams."""
    
    fig, axes = plt.subplots(1, 2, figsize=(16, 8))
    
    # =========================================================================
    # Left: Original Moderated Mediation
    # =========================================================================
    ax1 = axes[0]
    ax1.set_xlim(0, 10)
    ax1.set_ylim(0, 10)
    ax1.axis('off')
    ax1.set_title('A. Original: Moderated Mediation\n(x_FASt × credit_dose_c)', fontweight='bold', fontsize=12)
    
    # Boxes
    boxes = {
        'X': (1, 5, 'x_FASt\n(0/1)'),
        'Z': (1, 2, 'credit_dose_c\n(Z)'),
        'XZ': (1, 8, 'XZ_c\n(interaction)'),
        'M1': (5, 7, 'EmoDiss'),
        'M2': (5, 3, 'QualEngag'),
        'Y': (9, 5, 'DevAdj'),
    }
    
    for key, (x, y, label) in boxes.items():
        box = mpatches.FancyBboxPatch((x-0.7, y-0.5), 1.4, 1, boxstyle="round,pad=0.1",
                                       facecolor='#E8F4FD', edgecolor='#2E86AB', linewidth=2)
        ax1.add_patch(box)
        ax1.text(x, y, label, ha='center', va='center', fontsize=9, fontweight='bold')
    
    # Arrows with labels
    arrows = [
        ((1.7, 5), (4.3, 7), 'a1', '#2E86AB'),
        ((1.7, 5), (4.3, 3), 'a2', '#2E86AB'),
        ((1.7, 8), (4.3, 7.2), 'a1z', '#A23B72'),
        ((1.7, 8), (4.3, 3.2), 'a2z', '#A23B72'),
        ((5.7, 7), (8.3, 5.3), 'b1', '#28A745'),
        ((5.7, 3), (8.3, 4.7), 'b2', '#28A745'),
        ((1.7, 5), (8.3, 5), "c'", '#6C757D'),
    ]
    
    for (x1, y1), (x2, y2), label, color in arrows:
        ax1.annotate('', xy=(x2, y2), xytext=(x1, y1),
                     arrowprops=dict(arrowstyle='->', color=color, lw=2))
        mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
        ax1.text(mid_x, mid_y + 0.3, label, ha='center', va='bottom', fontsize=9, 
                 color=color, fontweight='bold')
    
    # Legend
    ax1.text(5, 0.5, '* Collinearity issue: cor(dose_c, XZ_c) = 0.96', 
             ha='center', fontsize=9, color='red', style='italic')
    
    # =========================================================================
    # Right: RD Piecewise
    # =========================================================================
    ax2 = axes[1]
    ax2.set_xlim(0, 10)
    ax2.set_ylim(0, 10)
    ax2.axis('off')
    ax2.set_title('B. RD Piecewise: Pre/Post Cutoff\n(r_minus, r_plus)', fontweight='bold', fontsize=12)
    
    # Boxes
    boxes = {
        'R-': (1, 7, 'r_minus\n(pre-12)'),
        'R+': (1, 3, 'r_plus\n(post-12)'),
        'M1': (5, 7, 'EmoDiss'),
        'M2': (5, 3, 'QualEngag'),
        'Y': (9, 5, 'DevAdj'),
    }
    
    for key, (x, y, label) in boxes.items():
        color = '#FDE8F0' if 'r_' in label else '#E8F4FD'
        edge = '#A23B72' if 'r_' in label else '#2E86AB'
        box = mpatches.FancyBboxPatch((x-0.7, y-0.5), 1.4, 1, boxstyle="round,pad=0.1",
                                       facecolor=color, edgecolor=edge, linewidth=2)
        ax2.add_patch(box)
        ax2.text(x, y, label, ha='center', va='center', fontsize=9, fontweight='bold')
    
    # Arrows
    arrows = [
        ((1.7, 7), (4.3, 7), 'a1_pre', '#A23B72'),
        ((1.7, 3), (4.3, 6.5), 'a1_post', '#A23B72'),
        ((1.7, 7), (4.3, 3.5), 'a2_pre', '#A23B72'),
        ((1.7, 3), (4.3, 3), 'a2_post', '#A23B72'),
        ((5.7, 7), (8.3, 5.3), 'b1', '#28A745'),
        ((5.7, 3), (8.3, 4.7), 'b2', '#28A745'),
        ((1.7, 7), (8.3, 5.2), "c_pre", '#6C757D'),
        ((1.7, 3), (8.3, 4.8), "c_post", '#6C757D'),
    ]
    
    for (x1, y1), (x2, y2), label, color in arrows:
        ax2.annotate('', xy=(x2, y2), xytext=(x1, y1),
                     arrowprops=dict(arrowstyle='->', color=color, lw=2, 
                                     connectionstyle="arc3,rad=0.1"))
        mid_x, mid_y = (x1 + x2) / 2 + 0.3, (y1 + y2) / 2
        ax2.text(mid_x, mid_y + 0.2, label, ha='center', va='bottom', fontsize=8, 
                 color=color, fontweight='bold')
    
    # Legend
    ax2.text(5, 0.5, '✓ No collinearity: cor(r_minus, r_plus) = 0.50', 
             ha='center', fontsize=9, color='green', style='italic')
    
    plt.tight_layout()
    
    # Save
    png_path = OUTPUT_DIR / "conceptual_model_comparison.png"
    pdf_path = OUTPUT_DIR / "conceptual_model_comparison.pdf"
    
    fig.savefig(png_path, dpi=300, bbox_inches='tight', facecolor='white')
    fig.savefig(pdf_path, bbox_inches='tight', facecolor='white')
    
    print(f"✅ Saved: {png_path}")
    print(f"✅ Saved: {pdf_path}")
    
    plt.close(fig)


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("COMPARATIVE DESIGN ANALYSIS")
    print("Original Moderated Mediation vs. RD Piecewise Parameterization")
    print("=" * 70)
    print()
    
    print("Creating formal comparison table...")
    create_comparison_table()
    print()
    
    print("Creating side-by-side visualization...")
    create_visualization()
    print()
    
    print("Creating conceptual model diagrams...")
    create_conceptual_diagrams()
    print()
    
    print("=" * 70)
    print(f"✅ All outputs saved to: {OUTPUT_DIR}")
    print("=" * 70)
