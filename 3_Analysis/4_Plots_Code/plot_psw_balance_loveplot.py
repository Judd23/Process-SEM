#!/usr/bin/env python3
"""PSW balance diagnostics (SMD table + Love plot).

This script answers the causal/bias question directly: are covariates balanced
between x_FASt=1 vs x_FASt=0, before vs after PSW weighting?

Outputs:
- 4_Model_Results/Summary/psw_balance_smd_table.csv
- 4_Model_Results/Summary/psw_balance_report.md
- 4_Model_Results/Figures/psw_loveplot.png

Notes:
- Balance is assessed using absolute standardized mean differences (|SMD|).
- For categorical variables, SMD is computed for each level indicator and the
  max |SMD| across levels is reported as the variable-level balance statistic.
- "Before" uses unweighted pre-PSW dataset.
- "After" uses PSW weights (column `psw`) on the post-PSW dataset.

Usage:
  python3 3_Analysis/4_Plots_Code/plot_psw_balance_loveplot.py \
    --pre 4_Model_Results/Outputs/FullRun_Prepped_20260103_2037/logs/analysis_dataset_cleaned.csv \
    --post 4_Model_Results/Outputs/FullRun_Prepped_20260103_2037/RQ1_RQ3_main/rep_data_with_psw.csv \
    --treat x_FASt --w psw
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


COVARIATES_DEFAULT = [
    "cohort",
    "hgrades_c",
    "bparented_c",
    "pell",
    "hapcl",
    "hprecalc13",
    "hchallenge_c",
    "cSFcareer_c",
]


def _to_numeric(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def _weighted_mean(x: np.ndarray, w: np.ndarray) -> float:
    mask = np.isfinite(x) & np.isfinite(w)
    if mask.sum() == 0:
        return np.nan
    x = x[mask]
    w = w[mask]
    ws = w.sum()
    if ws <= 0:
        return np.nan
    return float(np.sum(w * x) / ws)


def _weighted_var(x: np.ndarray, w: np.ndarray) -> float:
    mask = np.isfinite(x) & np.isfinite(w)
    if mask.sum() < 2:
        return np.nan
    x = x[mask]
    w = w[mask]
    ws = w.sum()
    if ws <= 0:
        return np.nan
    mu = np.sum(w * x) / ws
    v = np.sum(w * (x - mu) ** 2) / ws
    return float(v)


def _smd_continuous(x: np.ndarray, t: np.ndarray, w: np.ndarray | None) -> float:
    """Standardized mean difference for a continuous variable.

    SMD = (mean1 - mean0) / sd_pooled, where sd_pooled = sqrt((v1+v0)/2)
    computed within groups, optionally weighted.
    """
    t = t.astype(int)

    if w is None:
        x0 = x[t == 0]
        x1 = x[t == 1]
        m0 = np.nanmean(x0)
        m1 = np.nanmean(x1)
        v0 = np.nanvar(x0)
        v1 = np.nanvar(x1)
    else:
        w0 = w[t == 0]
        w1 = w[t == 1]
        x0 = x[t == 0]
        x1 = x[t == 1]
        m0 = _weighted_mean(x0, w0)
        m1 = _weighted_mean(x1, w1)
        v0 = _weighted_var(x0, w0)
        v1 = _weighted_var(x1, w1)

    sd_pooled = np.sqrt((v0 + v1) / 2.0)
    if not np.isfinite(sd_pooled) or sd_pooled == 0:
        return np.nan
    return float((m1 - m0) / sd_pooled)


def _smd_binary(x: np.ndarray, t: np.ndarray, w: np.ndarray | None) -> float:
    """SMD for binary indicator using proportions."""
    t = t.astype(int)

    if w is None:
        p0 = np.nanmean(x[t == 0])
        p1 = np.nanmean(x[t == 1])
    else:
        p0 = _weighted_mean(x[t == 0], w[t == 0])
        p1 = _weighted_mean(x[t == 1], w[t == 1])

    pbar = (p0 + p1) / 2.0
    sd = np.sqrt(pbar * (1.0 - pbar))
    if not np.isfinite(sd) or sd == 0:
        return np.nan
    return float((p1 - p0) / sd)


@dataclass
class BalanceRow:
    variable: str
    level: str
    smd_unweighted: float
    smd_weighted: float


def _is_categorical(series: pd.Series, max_levels: int = 10) -> bool:
    s = series.dropna()
    if s.empty:
        return False

    if pd.api.types.is_object_dtype(s) or isinstance(s.dtype, pd.CategoricalDtype):
        return True

    # Treat low-cardinality integers as categorical.
    if pd.api.types.is_integer_dtype(s):
        return s.nunique(dropna=True) <= max_levels

    return False


def compute_balance_table(
    df_pre: pd.DataFrame,
    df_post: pd.DataFrame,
    treat_col: str,
    weight_col: str,
    covariates: list[str],
) -> pd.DataFrame:
    if treat_col not in df_pre.columns or treat_col not in df_post.columns:
        raise ValueError(f"Missing treatment column: {treat_col}")
    if weight_col not in df_post.columns:
        raise ValueError(f"Missing weight column in post data: {weight_col}")

    t_pre = _to_numeric(df_pre[treat_col]).to_numpy(dtype=float)
    t_post = _to_numeric(df_post[treat_col]).to_numpy(dtype=float)

    # use post treat for weighted computations (should match pre)
    if not np.all(np.isfinite(t_post)):
        raise ValueError("Treatment column contains non-numeric values after coercion")

    w = _to_numeric(df_post[weight_col]).to_numpy(dtype=float)

    rows: list[BalanceRow] = []

    for var in covariates:
        if var not in df_pre.columns or var not in df_post.columns:
            continue

        s_pre = df_pre[var]
        s_post = df_post[var]

        if _is_categorical(s_pre):
            # For categorical variables, compute level-indicator SMDs.
            levels = sorted(pd.Series(pd.concat([s_pre, s_post], ignore_index=True)).dropna().unique().tolist())
            for lvl in levels:
                x_pre = (s_pre == lvl).astype(float).to_numpy(dtype=float)
                x_post = (s_post == lvl).astype(float).to_numpy(dtype=float)

                smd_u = _smd_binary(x_pre, t_pre, None)
                smd_w = _smd_binary(x_post, t_post, w)

                rows.append(BalanceRow(variable=var, level=str(lvl), smd_unweighted=smd_u, smd_weighted=smd_w))
        else:
            x_pre = _to_numeric(s_pre).to_numpy(dtype=float)
            x_post = _to_numeric(s_post).to_numpy(dtype=float)

            # If looks binary (0/1), use binary formula; else continuous.
            unique_nonmissing = pd.Series(x_pre).dropna().unique()
            if len(unique_nonmissing) <= 2 and set(unique_nonmissing).issubset({0.0, 1.0}):
                smd_u = _smd_binary(x_pre, t_pre, None)
                smd_w = _smd_binary(x_post, t_post, w)
            else:
                smd_u = _smd_continuous(x_pre, t_pre, None)
                smd_w = _smd_continuous(x_post, t_post, w)

            rows.append(BalanceRow(variable=var, level="(overall)", smd_unweighted=smd_u, smd_weighted=smd_w))

    out = pd.DataFrame(
        [
            {
                "variable": r.variable,
                "level": r.level,
                "smd_unweighted": r.smd_unweighted,
                "smd_weighted": r.smd_weighted,
                "abs_smd_unweighted": np.abs(r.smd_unweighted) if np.isfinite(r.smd_unweighted) else np.nan,
                "abs_smd_weighted": np.abs(r.smd_weighted) if np.isfinite(r.smd_weighted) else np.nan,
            }
            for r in rows
        ]
    )

    # Variable-level summary: max abs SMD across levels.
    summary = (
        out.groupby("variable", as_index=False)
        .agg(
            max_abs_smd_unweighted=("abs_smd_unweighted", "max"),
            max_abs_smd_weighted=("abs_smd_weighted", "max"),
        )
        .sort_values("max_abs_smd_unweighted", ascending=False)
    )

    out = out.merge(summary, on="variable", how="left")
    return out


def effective_sample_size(w: np.ndarray) -> float:
    w = w[np.isfinite(w)]
    if w.size == 0:
        return float("nan")
    s1 = np.sum(w)
    s2 = np.sum(w**2)
    if s2 <= 0:
        return float("nan")
    return float((s1**2) / s2)


def write_report(
    out_md: Path,
    df_balance: pd.DataFrame,
    df_post: pd.DataFrame,
    treat_col: str,
    weight_col: str,
) -> None:
    w = _to_numeric(df_post[weight_col]).to_numpy(dtype=float)
    t = _to_numeric(df_post[treat_col]).to_numpy(dtype=float).astype(int)

    w_clean = w[np.isfinite(w)]
    ess_all = effective_sample_size(w)
    ess_t0 = effective_sample_size(w[t == 0])
    ess_t1 = effective_sample_size(w[t == 1])

    # Variable-level max abs SMD table
    var_tbl = (
        df_balance[["variable", "max_abs_smd_unweighted", "max_abs_smd_weighted"]]
        .drop_duplicates()
        .sort_values("max_abs_smd_unweighted", ascending=False)
    )

    def fmt(x: float) -> str:
        return "NA" if not np.isfinite(x) else f"{x:.4f}"

    lines: list[str] = []
    lines.append("# PSW Balance Diagnostics\n")
    lines.append("## Weight Diagnostics\n")
    lines.append(f"- Weight column: `{weight_col}`\n")
    if w_clean.size:
        lines.append(
            "- psw summary: "
            + f"min={w_clean.min():.3f}, p01={np.quantile(w_clean,0.01):.3f}, "
            + f"median={np.quantile(w_clean,0.50):.3f}, p99={np.quantile(w_clean,0.99):.3f}, max={w_clean.max():.3f}\n"
        )
    lines.append(f"- Effective sample size (ESS), overall: {fmt(ess_all)}\n")
    lines.append(f"- ESS in x_FASt=0: {fmt(ess_t0)}\n")
    lines.append(f"- ESS in x_FASt=1: {fmt(ess_t1)}\n")

    lines.append("\n## Covariate Balance (max |SMD| across levels)\n")
    lines.append("Rule of thumb: |SMD| < 0.10 is often considered good balance; < 0.20 is usually acceptable.\n\n")

    lines.append("| Covariate | max |SMD| (pre) | max |SMD| (post, PSW) |\n")
    lines.append("|---|---:|---:|\n")
    for _, r in var_tbl.iterrows():
        lines.append(f"| {r['variable']} | {fmt(r['max_abs_smd_unweighted'])} | {fmt(r['max_abs_smd_weighted'])} |\n")

    out_md.write_text("".join(lines), encoding="utf-8")


def plot_love(out_png: Path, df_balance: pd.DataFrame) -> None:
    var_tbl = (
        df_balance[["variable", "max_abs_smd_unweighted", "max_abs_smd_weighted"]]
        .drop_duplicates()
        .sort_values("max_abs_smd_unweighted", ascending=True)
    )

    y = np.arange(len(var_tbl))
    pre = var_tbl["max_abs_smd_unweighted"].to_numpy(dtype=float)
    post = var_tbl["max_abs_smd_weighted"].to_numpy(dtype=float)
    labels = var_tbl["variable"].tolist()

    fig_h = max(4.5, 0.55 * len(labels))
    fig, ax = plt.subplots(figsize=(9.5, fig_h))

    ax.scatter(pre, y, label="Pre (unweighted)", color="#333333", s=35, zorder=3)
    ax.scatter(post, y, label="Post (PSW weighted)", color="#1f77b4", s=35, zorder=3)

    # Reference lines
    ax.axvline(0.10, color="black", linewidth=1, linestyle="--")
    ax.axvline(0.20, color="black", linewidth=1, linestyle=":")

    ax.set_yticks(y)
    ax.set_yticklabels(labels)
    ax.set_xlabel("Absolute Standardized Mean Difference (|SMD|)")
    ax.set_title("PSW Balance (Love Plot)\nMax |SMD| across levels for categorical variables")

    ax.grid(axis="x", alpha=0.25)
    ax.set_xlim(left=0, right=max(0.35, np.nanmax(np.r_[pre, post]) * 1.10))

    ax.legend(loc="lower right")
    plt.tight_layout()
    fig.savefig(out_png.as_posix(), dpi=300, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser(description="PSW balance diagnostics (SMD + Love plot)")
    ap.add_argument("--pre", required=True, help="Pre-PSW dataset CSV")
    ap.add_argument("--post", required=True, help="Post-PSW dataset CSV (includes weights)")
    ap.add_argument("--treat", required=True, help="Treatment column (e.g., x_FASt)")
    ap.add_argument("--w", required=True, help="Weight column (e.g., psw)")
    ap.add_argument(
        "--covariates",
        default=",".join(COVARIATES_DEFAULT),
        help="Comma-separated covariate list",
    )
    ap.add_argument("--out_summary", default="4_Model_Results/Summary", help="Output summary directory")
    ap.add_argument("--out_figures", default="4_Model_Results/Figures", help="Output figures directory")
    args = ap.parse_args()

    covariates = [c.strip() for c in args.covariates.split(",") if c.strip()]

    df_pre = pd.read_csv(args.pre)
    df_post = pd.read_csv(args.post)

    df_balance = compute_balance_table(df_pre, df_post, args.treat, args.w, covariates)

    out_summary = Path(args.out_summary)
    out_figures = Path(args.out_figures)
    out_summary.mkdir(parents=True, exist_ok=True)
    out_figures.mkdir(parents=True, exist_ok=True)

    out_csv = out_summary / "psw_balance_smd_table.csv"
    out_md = out_summary / "psw_balance_report.md"
    out_png = out_figures / "psw_loveplot.png"

    df_balance.to_csv(out_csv, index=False)
    write_report(out_md, df_balance, df_post, args.treat, args.w)
    plot_love(out_png, df_balance)


if __name__ == "__main__":
    main()
