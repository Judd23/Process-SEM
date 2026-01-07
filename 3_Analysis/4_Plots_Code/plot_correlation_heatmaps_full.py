#!/usr/bin/env python3
"""Generate full correlation heatmaps (pre- and post-PSW weighting).

Outputs two publication-ready correlation heatmaps grouped by role in the SEM:
- Treatment/moderation
- Covariates
- Mediator indicators (EmoDiss, QualEngag)
- Outcome indicators (DevAdj components)

This script is designed to be exact and reproducible:
- Pre-PSW heatmap uses unweighted Pearson correlations.
- Post-PSW heatmap uses weighted Pearson correlations with the specified weight column.
- Pairwise complete cases are used for each correlation.

Usage:
  python3 3_Analysis/4_Plots_Code/plot_correlation_heatmaps_full.py \
    --pre 4_Model_Results/Outputs/FullRun_Prepped_20260103_2037/logs/analysis_dataset_cleaned.csv \
    --post 4_Model_Results/Outputs/FullRun_Prepped_20260103_2037/RQ1_RQ3_main/rep_data_with_psw.csv \
    --weight_col psw \
    --outdir 4_Model_Results/Figures
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize


def _weighted_corr(x: np.ndarray, y: np.ndarray, w: np.ndarray) -> float:
    mask = (~np.isnan(x)) & (~np.isnan(y)) & (~np.isnan(w))
    if mask.sum() < 3:
        return np.nan

    x = x[mask]
    y = y[mask]
    w = w[mask]

    w_sum = w.sum()
    if w_sum <= 0:
        return np.nan

    mx = np.sum(w * x) / w_sum
    my = np.sum(w * y) / w_sum

    cov = np.sum(w * (x - mx) * (y - my)) / w_sum
    vx = np.sum(w * (x - mx) ** 2) / w_sum
    vy = np.sum(w * (y - my) ** 2) / w_sum

    denom = np.sqrt(vx * vy)
    if denom == 0 or np.isnan(denom):
        return np.nan

    return float(cov / denom)


def weighted_corr_matrix(df: pd.DataFrame, cols: list[str], w: np.ndarray) -> pd.DataFrame:
    n = len(cols)
    out = np.full((n, n), np.nan, dtype=float)

    # Pre-extract arrays to avoid repeated indexing overhead
    arrays = {c: pd.to_numeric(df[c], errors="coerce").to_numpy(dtype=float) for c in cols}

    for i, ci in enumerate(cols):
        out[i, i] = 1.0
        xi = arrays[ci]
        for j in range(i + 1, n):
            cj = cols[j]
            r = _weighted_corr(xi, arrays[cj], w)
            out[i, j] = r
            out[j, i] = r

    return pd.DataFrame(out, index=cols, columns=cols)


def weighted_spearman_corr_matrix(df: pd.DataFrame, cols: list[str], w: np.ndarray) -> pd.DataFrame:
    """Weighted Spearman correlation (pairwise) via weighted Pearson on pairwise ranks.

    Notes on accuracy:
    - Spearman is Pearson correlation of ranks.
    - With missing data, "pairwise complete" Spearman should rank within the
      pairwise complete subset for each (x, y) pair.
    - This implementation does that for each cell.
    """

    n = len(cols)
    out = np.full((n, n), np.nan, dtype=float)
    arrays = {c: pd.to_numeric(df[c], errors="coerce").to_numpy(dtype=float) for c in cols}

    for i, ci in enumerate(cols):
        out[i, i] = 1.0
        xi = arrays[ci]
        for j in range(i + 1, n):
            cj = cols[j]
            yj = arrays[cj]
            mask = (~np.isnan(xi)) & (~np.isnan(yj)) & (~np.isnan(w))
            if mask.sum() < 3:
                r = np.nan
            else:
                xr = pd.Series(xi[mask]).rank(method="average").to_numpy(dtype=float)
                yr = pd.Series(yj[mask]).rank(method="average").to_numpy(dtype=float)
                r = _weighted_corr(xr, yr, w[mask])

            out[i, j] = r
            out[j, i] = r

    return pd.DataFrame(out, index=cols, columns=cols)


def spearman_corr_matrix(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    """Unweighted Spearman correlation with pairwise ranking for missingness accuracy."""
    n = len(cols)
    out = np.full((n, n), np.nan, dtype=float)
    arrays = {c: pd.to_numeric(df[c], errors="coerce").to_numpy(dtype=float) for c in cols}

    for i, ci in enumerate(cols):
        out[i, i] = 1.0
        xi = arrays[ci]
        for j in range(i + 1, n):
            cj = cols[j]
            yj = arrays[cj]
            mask = (~np.isnan(xi)) & (~np.isnan(yj))
            if mask.sum() < 3:
                r = np.nan
            else:
                xr = pd.Series(xi[mask]).rank(method="average").to_numpy(dtype=float)
                yr = pd.Series(yj[mask]).rank(method="average").to_numpy(dtype=float)
                # Pearson on ranks
                r = float(np.corrcoef(xr, yr)[0, 1])

            out[i, j] = r
            out[j, i] = r

    return pd.DataFrame(out, index=cols, columns=cols)


def build_role_grouped_variable_spec(df: pd.DataFrame) -> tuple[list[str], list[str], list[int]]:
    """Return (vars, labels, separators) for a role-grouped correlation heatmap."""

    # Role groups (in order)
    treatment = ["x_FASt", "credit_dose", "credit_dose_c", "XZ_c"]

    covariates = [
        "cohort",
        "hgrades_c",
        "bparented_c",
        "pell",
        "hapcl",
        "hprecalc13",
        "hchallenge_c",
        "cSFcareer_c",
    ]

    emo_diss = ["MHWdacad", "MHWdlonely", "MHWdmental", "MHWdexhaust", "MHWdsleep", "MHWdfinancial"]
    qual_engag = ["QIstudent", "QIadvisor", "QIfaculty", "QIstaff", "QIadmin"]

    # Outcome indicators for DevAdj
    belong = ["sbvalued", "sbmyself", "sbcommunity"]
    gains = ["pgthink", "pganalyze", "pgwork", "pgvalues", "pgprobsolve"]
    support = ["SEacademic", "SEwellness", "SEnonacad", "SEactivities", "SEdiverse"]
    satisf = ["evalexp", "sameinst"]

    grouped = [
        ("Treatment / dose", treatment),
        ("Covariates", covariates),
        ("EmoDiss indicators", emo_diss),
        ("QualEngag indicators", qual_engag),
        ("DevAdj: Belong", belong),
        ("DevAdj: Gains", gains),
        ("DevAdj: SupportEnv", support),
        ("DevAdj: Satisf", satisf),
    ]

    vars_out: list[str] = []
    labels_out: list[str] = []
    separators: list[int] = []

    pretty = {
        "x_FASt": "X: FASt",
        "credit_dose": "Credit dose",
        "credit_dose_c": "Credit dose (c)",
        "XZ_c": "XZ (FASt×dose)",
        "cohort": "Cohort",
        "hgrades_c": "HS grades (c)",
        "bparented_c": "Parent edu (c)",
        "pell": "Pell",
        "hapcl": "AP/CL",
        "hprecalc13": "Precalc by 13",
        "hchallenge_c": "HS challenge (c)",
        "cSFcareer_c": "SF career (c)",
        "MHWdacad": "ED: Academic",
        "MHWdlonely": "ED: Lonely",
        "MHWdmental": "ED: Mental",
        "MHWdexhaust": "ED: Exhaust",
        "MHWdsleep": "ED: Sleep",
        "MHWdfinancial": "ED: Financial",
        "QIstudent": "QE: Students",
        "QIadvisor": "QE: Advisors",
        "QIfaculty": "QE: Faculty",
        "QIstaff": "QE: Staff",
        "QIadmin": "QE: Admin",
        "sbvalued": "Bel: Valued",
        "sbmyself": "Bel: Myself",
        "sbcommunity": "Bel: Community",
        "pgthink": "Gain: Think",
        "pganalyze": "Gain: Analyze",
        "pgwork": "Gain: Work",
        "pgvalues": "Gain: Values",
        "pgprobsolve": "Gain: Problem",
        "SEacademic": "SE: Academic",
        "SEwellness": "SE: Wellness",
        "SEnonacad": "SE: Nonacad",
        "SEactivities": "SE: Activities",
        "SEdiverse": "SE: Diverse",
        "evalexp": "Sat: Experience",
        "sameinst": "Sat: Same inst",
    }

    for _, group_vars in grouped:
        for v in group_vars:
            if v in df.columns:
                vars_out.append(v)
                labels_out.append(pretty.get(v, v))
        separators.append(len(vars_out))

    # separators are boundaries; drop the last boundary (end)
    if separators:
        separators = separators[:-1]

    return vars_out, labels_out, separators


def plot_heatmap(
    corr: pd.DataFrame,
    labels: list[str],
    separators: list[int],
    title: str,
    out_path: Path,
    cbar_label: str,
    cmap_name: str,
    contrast_power: float,
) -> None:
    n = corr.shape[0]

    # Bigger figure for full matrix
    fig_w = max(14, min(32, 0.55 * n))
    fig_h = max(12, min(30, 0.55 * n))

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))

    class SignedPowerNorm(Normalize):
        """Nonlinear diverging normalization to increase contrast near 0.

        Maps values in [-1, 1] to [0, 1] via:
          f(x) = 0.5 + 0.5 * sign(x) * |x|**power

        power in (0, 1) increases contrast for small magnitudes.
        power = 1.0 is linear.
        """

        def __init__(self, vmin: float = -1.0, vmax: float = 1.0, power: float = 0.65, clip: bool = True):
            super().__init__(vmin=vmin, vmax=vmax, clip=clip)
            if power <= 0:
                raise ValueError("contrast_power must be > 0")
            self.power = float(power)

        def __call__(self, value, clip=None):
            v = np.asarray(value, dtype=float)
            if clip is None:
                clip = self.clip

            # Clamp to bounds to keep the scale honest.
            vv = np.clip(v, self.vmin, self.vmax)
            vv = vv / max(abs(self.vmin), abs(self.vmax))

            out = 0.5 + 0.5 * np.sign(vv) * (np.abs(vv) ** self.power)
            if clip:
                out = np.clip(out, 0.0, 1.0)
            return out

    norm = SignedPowerNorm(vmin=-1.0, vmax=1.0, power=contrast_power)
    im = ax.imshow(
        corr.to_numpy(),
        cmap=cmap_name,
        norm=norm,
        interpolation="nearest",
    )

    ax.set_xticks(range(n))
    ax.set_yticks(range(n))

    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=8)
    ax.set_yticklabels(labels, fontsize=8)

    # Cell labels (trim if too dense)
    show_values = n <= 40
    if show_values:
        for i in range(n):
            for j in range(n):
                val = corr.iat[i, j]
                if np.isnan(val):
                    continue
                color = "white" if abs(val) >= 0.4 else "black"
                ax.text(j, i, f"{val:.2f}", ha="center", va="center", color=color, fontsize=6)

    for sep in separators:
        if 0 < sep < n:
            ax.axhline(sep - 0.5, color="black", linewidth=1.5)
            ax.axvline(sep - 0.5, color="black", linewidth=1.5)

    cbar = plt.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label(cbar_label)
    cbar.set_ticks(np.linspace(-1, 1, 9))

    ax.set_title(title, fontsize=14, fontweight="bold")
    plt.tight_layout()
    fig.savefig(out_path.as_posix(), dpi=300, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate full correlation heatmaps pre/post PSW")
    ap.add_argument("--pre", required=True, help="Pre-PSW dataset CSV (cleaned analysis dataset)")
    ap.add_argument("--post", required=True, help="Post-PSW dataset CSV (must include weight column)")
    ap.add_argument("--weight_col", required=True, help="Weight column name in post dataset (e.g., psw)")
    ap.add_argument("--outdir", default="4_Model_Results/Figures", help="Output directory")
    ap.add_argument("--method", default="pearson", choices=["pearson", "spearman"], help="Correlation method")
    ap.add_argument(
        "--cmap",
        default="RdBu",
        help="Matplotlib colormap name (default: RdBu so negative=red, positive=blue)",
    )
    ap.add_argument(
        "--contrast_power",
        type=float,
        default=0.65,
        help="Contrast power for the diverging scale (0<p<=1; lower = more contrast near 0)",
    )
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    df_pre = pd.read_csv(args.pre)
    df_post = pd.read_csv(args.post)

    vars_pre, labels_pre, separators_pre = build_role_grouped_variable_spec(df_pre)
    vars_post, labels_post, separators_post = build_role_grouped_variable_spec(df_post)

    # Enforce same ordering for visual comparability: intersect in pre-order
    shared_vars = [v for v in vars_pre if v in set(vars_post)]
    labels = [labels_pre[vars_pre.index(v)] for v in shared_vars]

    # Recompute separators based on shared_vars
    # Build a group assignment by scanning original pre vars in order of grouped spec.
    # separators_pre is end-of-group boundaries; reconstruct using vars_pre and boundaries.
    group_boundaries = separators_pre + [len(vars_pre)]
    separators: list[int] = []
    start = 0
    for end in group_boundaries:
        group_vars = vars_pre[start:end]
        count_in_shared = sum(1 for v in group_vars if v in set(shared_vars))
        if count_in_shared > 0:
            new_end = (separators[-1] if separators else 0) + count_in_shared
            separators.append(new_end)
        start = end
    if separators:
        separators = separators[:-1]

    # Pre-PSW: unweighted
    if args.method == "pearson":
        corr_pre = df_pre[shared_vars].corr(method="pearson")
    else:
        corr_pre = spearman_corr_matrix(df_pre, shared_vars)

    # Post-PSW: weighted
    if args.weight_col not in df_post.columns:
        raise SystemExit(f"Weight column '{args.weight_col}' not found in post dataset")
    w = pd.to_numeric(df_post[args.weight_col], errors="coerce").to_numpy(dtype=float)
    if args.method == "pearson":
        corr_post = weighted_corr_matrix(df_post, shared_vars, w)
    else:
        corr_post = weighted_spearman_corr_matrix(df_post, shared_vars, w)

    method_label = "Pearson r" if args.method == "pearson" else "Spearman ρ"
    file_tag = "correlation" if args.method == "pearson" else "spearman"
    cbar_label = f"{method_label} (red=negative, blue=positive)"

    plot_heatmap(
        corr_pre,
        labels,
        separators,
        f"Figure 6\n{method_label} Correlation Matrix (Before PSW Weighting)\nGrouped by Role",
        outdir / f"fig6_{file_tag}_matrix_grouped.png",
        cbar_label,
        args.cmap,
        args.contrast_power,
    )

    plot_heatmap(
        corr_post,
        labels,
        separators,
        f"Figure 7\n{method_label} Correlation Matrix (After PSW Weighting)\nGrouped by Role",
        outdir / f"fig7_{file_tag}_matrix_post_psw.png",
        cbar_label,
        args.cmap,
        args.contrast_power,
    )


if __name__ == "__main__":
    main()
