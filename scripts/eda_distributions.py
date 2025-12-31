#!/usr/bin/env python3
"""Generate descriptive distribution visualizations for a CSV dataset.

Produces 10+ plot types covering numeric/categorical distributions, missingness,
correlations, and bivariate frequency.

Default input: rep_data.csv at repo root.
Output: results/eda/ (PNG + HTML report).
"""

from __future__ import annotations

import argparse
import html
import math
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, cast

import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
from scipy import stats


DEFAULT_IN = Path("rep_data.csv")
DEFAULT_OUTDIR = Path("results/eda")
DEFAULT_VAR_TABLE = Path("results/tables/variable_table.csv")


@dataclass(frozen=True)
class PlotArtifact:
    title: str
    filename: str
    description: str


def _safe_filename(name: str) -> str:
    keep = []
    for ch in name:
        if ch.isalnum() or ch in ("-", "_", "."):
            keep.append(ch)
        else:
            keep.append("_")
    out = "".join(keep).strip("_")
    return out[:160] if out else "plot"


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def _save_fig(outpath: Path, dpi: int = 150) -> None:
    plt.tight_layout()
    plt.savefig(outpath, dpi=dpi, bbox_inches="tight")
    plt.close()


def _choose_columns(columns: list[str], max_n: int) -> list[str]:
    if len(columns) <= max_n:
        return columns
    return columns[:max_n]


def _infer_types(df: pd.DataFrame) -> tuple[list[str], list[str]]:
    numeric_cols = [c for c in df.columns if pd.api.types.is_numeric_dtype(df[c])]

    # Treat low-cardinality numerics as categorical if they look like codes
    categorical_cols: list[str] = [
        c
        for c in df.columns
        if (pd.api.types.is_object_dtype(df[c])
            or pd.api.types.is_bool_dtype(df[c])
            or isinstance(df[c].dtype, pd.CategoricalDtype))
    ]

    for c in list(numeric_cols):
        s = df[c].dropna()
        if s.empty:
            continue
        nunique = int(s.nunique())
        if nunique <= 12 and s.dtype.kind in {"i", "u"}:
            # Likely a coded categorical
            numeric_cols.remove(c)
            categorical_cols.append(c)

    categorical_cols = [c for c in categorical_cols if c not in numeric_cols]
    return numeric_cols, categorical_cols


def _load_variable_labels_map(var_table_path: Path) -> dict[str, str]:
    if not var_table_path.exists():
        return {}

    vt = pd.read_csv(var_table_path)
    labels: dict[str, str] = {}

    if "variable" in vt.columns and "label" in vt.columns:
        direct = vt.loc[vt["variable"].notna(), ["variable", "label"]].copy()
        direct["variable"] = direct["variable"].astype(str)
        direct["label"] = direct["label"].astype(str)
        labels.update(dict(zip(direct["variable"], direct["label"])))

    # Also map construct code names (often used as factor-score columns) to the latent label.
    # This covers columns like DevAdj/EmoDiss/QualEngag that may appear in data even when
    # the variable table represents them as latent rows (variable = NA).
    if "code_name" in vt.columns and "label" in vt.columns:
        cn = vt.loc[vt["code_name"].notna(), ["code_name", "label"]].copy()
        cn["code_name"] = cn["code_name"].astype(str)
        cn["label"] = cn["label"] .astype(str)
        # Only fill missing keys to avoid overriding direct variable labels.
        for k, v in dict(zip(cn["code_name"], cn["label"])).items():
            labels.setdefault(k, v)

    return labels


def _display_name(var: str, labels_map: dict[str, str]) -> str:
    lbl = labels_map.get(var)
    return f"{lbl} ({var})" if lbl and lbl != var else var


def _basic_clean(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    # Strip whitespace in object columns
    for c in out.columns:
        if pd.api.types.is_object_dtype(out[c]):
            out[c] = out[c].astype(str).str.strip().replace({"nan": np.nan})

    return out


def plot_missingness(df: pd.DataFrame, outdir: Path) -> PlotArtifact:
    miss = df.isna().mean().sort_values(ascending=False)
    miss = miss[miss > 0]

    plt.figure(figsize=(10, 4))
    if miss.empty:
        plt.text(0.5, 0.5, "No missing values detected.", ha="center", va="center")
        plt.axis("off")
        fname = "missingness_none.png"
        _save_fig(outdir / fname)
        return PlotArtifact(
            title="Missingness",
            filename=fname,
            description="No missing values detected.",
        )

    sns.barplot(x=miss.index, y=miss.values, color=sns.color_palette()[0])
    plt.xticks(rotation=90)
    plt.ylabel("Missing fraction")
    plt.title("Missingness rate by column")
    fname = "missingness_by_column.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Missingness",
        filename=fname,
        description="Missing fraction per column.",
    )


def plot_summary_table(df: pd.DataFrame, numeric_cols: list[str], outdir: Path) -> PlotArtifact:
    if not numeric_cols:
        fname = "summary_stats_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact(
            title="Numeric Summary",
            filename=fname,
            description="No numeric columns detected.",
        )

    desc = df[numeric_cols].describe(percentiles=[0.05, 0.25, 0.5, 0.75, 0.95]).T
    desc = desc[["count", "mean", "std", "min", "5%", "25%", "50%", "75%", "95%", "max"]]
    desc.to_csv(outdir / "summary_stats_numeric.csv")

    # Heatmap-style table
    plt.figure(figsize=(12, max(3, 0.35 * len(desc))))
    sns.heatmap(
        desc.drop(columns=["count"]),
        cmap="viridis",
        cbar=True,
        linewidths=0.2,
        linecolor="white",
    )
    plt.title("Numeric descriptive statistics (excluding count)")
    fname = "summary_stats_heatmap.png"
    _save_fig(outdir / fname)

    return PlotArtifact(
        title="Numeric Descriptives",
        filename=fname,
        description="Heatmap of numeric descriptives (mean, sd, quantiles, min/max). CSV also saved.",
    )


def plot_hist_grid(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 12) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    n = len(cols)
    if n == 0:
        fname = "histograms_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Histograms", fname, "No numeric columns detected.")

    ncols = 3
    nrows = int(math.ceil(n / ncols))
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(12, 3.2 * nrows))
    axes = np.asarray(axes).reshape(-1)

    for i, c in enumerate(cols):
        ax = axes[i]
        # Seaborn typing stubs prefer DataFrame + column name
        sns.histplot(data=df, x=c, bins=30, kde=False, ax=ax)

        x_num = cast(pd.Series, pd.to_numeric(df[c], errors="coerce")).dropna()
        if not x_num.empty:
            ax.axvline(float(x_num.mean()), color="red", linestyle="--", linewidth=1, label="mean")
            ax.axvline(float(x_num.median()), color="black", linestyle=":", linewidth=1, label="median")

        ax.set_title(c)
        ax.legend(loc="best")

    for j in range(n, len(axes)):
        axes[j].axis("off")

    fig.suptitle("Histograms (mean/median lines)", y=1.02)
    fname = "histograms_grid.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Histograms",
        filename=fname,
        description=f"Histograms for up to {max_cols} numeric variables.",
    )


def plot_kde_ridgeline(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 12) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    if not cols:
        fname = "ridgeline_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Ridgeline", fname, "No numeric columns detected.")

    long = df[cols].melt(var_name="variable", value_name="value").dropna()
    plt.figure(figsize=(10, max(4, 0.5 * len(cols))))

    # Ridgeline-ish: stacked KDEs by y
    y_positions = {v: i for i, v in enumerate(cols)}
    for v in cols:
        vals = long.loc[long["variable"] == v, "value"].values
        if len(vals) < 5:
            continue
        density = stats.gaussian_kde(vals)
        xs = np.linspace(np.nanmin(vals), np.nanmax(vals), 200)
        ys = density(xs)
        ys = ys / (ys.max() if ys.max() else 1.0)
        base = y_positions[v]
        plt.fill_between(xs, base, base + ys, alpha=0.8)

    plt.yticks(range(len(cols)), cols)
    plt.title("Ridgeline-style KDE (scaled per variable)")
    plt.xlabel("Value")
    plt.ylabel("Variable")
    fname = "ridgeline_kde.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Ridgeline KDE",
        filename=fname,
        description=f"Ridgeline-style KDE for up to {max_cols} numeric variables.",
    )


def plot_box_violin(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 12) -> list[PlotArtifact]:
    cols = _choose_columns(cols, max_cols)
    if not cols:
        fname = "boxplot_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return [PlotArtifact("Box plot", fname, "No numeric columns detected.")]

    long = df[cols].melt(var_name="variable", value_name="value").dropna()

    plt.figure(figsize=(12, max(4, 0.45 * len(cols))))
    sns.boxplot(data=long, y="variable", x="value")
    plt.title("Box plots (median/IQR/outliers)")
    fname1 = "boxplots.png"
    _save_fig(outdir / fname1)

    plt.figure(figsize=(12, max(4, 0.45 * len(cols))))
    sns.violinplot(data=long, y="variable", x="value", inner="quartile", cut=0)
    plt.title("Violin plots (distribution shape + quartiles)")
    fname2 = "violinplots.png"
    _save_fig(outdir / fname2)

    return [
        PlotArtifact("Box plots", fname1, f"Box plots for up to {max_cols} numeric variables."),
        PlotArtifact("Violin plots", fname2, f"Violin plots for up to {max_cols} numeric variables."),
    ]


def plot_ecdf(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 6) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    if not cols:
        fname = "ecdf_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("ECDF", fname, "No numeric columns detected.")

    plt.figure(figsize=(10, 6))
    for c in cols:
        x_series = cast(pd.Series, pd.to_numeric(df[c], errors="coerce")).dropna()
        x = x_series.to_numpy(dtype=float)
        x = np.sort(x)
        if x.size == 0:
            continue
        y = np.arange(1, x.size + 1) / x.size
        plt.step(x, y, where="post", label=c)
    plt.title("ECDF (empirical cumulative distribution)")
    plt.xlabel("Value")
    plt.ylabel("ECDF")
    plt.legend(loc="best")
    fname = "ecdf_overlay.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="ECDF",
        filename=fname,
        description=f"Overlay ECDF for up to {max_cols} numeric variables.",
    )


def plot_qq(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 6) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    if not cols:
        fname = "qq_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No numeric columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Q-Q", fname, "No numeric columns detected.")

    n = len(cols)
    ncols = 3
    nrows = int(math.ceil(n / ncols))
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(12, 3.6 * nrows))
    axes = np.asarray(axes).reshape(-1)

    for i, c in enumerate(cols):
        ax = axes[i]
        x_series = cast(pd.Series, pd.to_numeric(df[c], errors="coerce")).dropna()
        x = x_series.to_numpy(dtype=float)
        if x.size < 5:
            ax.text(0.5, 0.5, "Too few values", ha="center", va="center")
            ax.axis("off")
            continue
        stats.probplot(x, dist="norm", plot=ax)
        ax.set_title(f"Q-Q: {c}")

    for j in range(n, len(axes)):
        axes[j].axis("off")

    fig.suptitle("Normal Q-Q plots (tail behavior)", y=1.02)
    fname = "qqplots.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Q-Q plots",
        filename=fname,
        description=f"Normal Q-Q plots for up to {max_cols} numeric variables.",
    )


def plot_corr_heatmap(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 30) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    if len(cols) < 2:
        fname = "correlation_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "Not enough numeric columns for correlation.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Correlation heatmap", fname, "Not enough numeric columns.")

    sub = cast(pd.DataFrame, df.loc[:, cols])
    corr = sub.corr(method="spearman")
    plt.figure(figsize=(10, 8))
    sns.heatmap(corr, cmap="vlag", center=0, square=True)
    plt.title("Spearman correlation heatmap")
    fname = "correlation_heatmap.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Correlation heatmap",
        filename=fname,
        description=f"Spearman correlations for up to {max_cols} numeric variables.",
    )


def plot_pairplot(df: pd.DataFrame, cols: list[str], outdir: Path, max_cols: int = 6) -> PlotArtifact:
    cols = _choose_columns(cols, max_cols)
    if len(cols) < 2:
        fname = "pairplot_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "Not enough numeric columns for pairplot.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Pairplot", fname, "Not enough numeric columns.")

    sub = cast(pd.DataFrame, df.loc[:, cols]).dropna()
    g = sns.pairplot(sub, corner=True, plot_kws={"s": 10, "alpha": 0.6})
    g.fig.suptitle("Scatterplot matrix (pairplot)", y=1.02)
    fname = "pairplot.png"
    g.savefig(outdir / fname, dpi=150, bbox_inches="tight")
    plt.close(g.fig)

    return PlotArtifact(
        title="Pairplot",
        filename=fname,
        description=f"Pairplot for up to {max_cols} numeric variables (rows with NA dropped for these columns).",
    )


def plot_hexbin(df: pd.DataFrame, cols: list[str], outdir: Path) -> PlotArtifact:
    if len(cols) < 2:
        fname = "hexbin_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "Not enough numeric columns for hexbin.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Hexbin", fname, "Not enough numeric columns.")

    xcol, ycol = cols[0], cols[1]
    data = df[[xcol, ycol]].dropna()

    plt.figure(figsize=(7, 6))
    plt.hexbin(data[xcol], data[ycol], gridsize=35, cmap="viridis", mincnt=1)
    plt.colorbar(label="Count")
    plt.xlabel(xcol)
    plt.ylabel(ycol)
    plt.title("2D frequency (hexbin)")
    fname = f"hexbin_{_safe_filename(xcol)}_{_safe_filename(ycol)}.png"
    _save_fig(outdir / fname)

    return PlotArtifact(
        title="2D frequency (hexbin)",
        filename=fname,
        description=f"Hexbin count plot for {xcol} vs {ycol}.",
    )


def plot_categorical_bars(df: pd.DataFrame, cat_cols: list[str], outdir: Path, max_cols: int = 12) -> PlotArtifact:
    cat_cols = _choose_columns(cat_cols, max_cols)
    if not cat_cols:
        fname = "categorical_none.png"
        plt.figure(figsize=(8, 2))
        plt.text(0.5, 0.5, "No categorical columns detected.", ha="center", va="center")
        plt.axis("off")
        _save_fig(outdir / fname)
        return PlotArtifact("Categorical frequencies", fname, "No categorical columns detected.")

    n = len(cat_cols)
    ncols = 2
    nrows = int(math.ceil(n / ncols))
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(12, 3.8 * nrows))
    axes = np.asarray(axes).reshape(-1)

    for i, c in enumerate(cat_cols):
        ax = axes[i]
        vc = df[c].astype("object").value_counts(dropna=False).head(20)
        sns.barplot(x=vc.values, y=vc.index.astype(str), ax=ax)
        ax.set_title(f"{c} (top 20)")
        ax.set_xlabel("Count")
        ax.set_ylabel("Level")

    for j in range(n, len(axes)):
        axes[j].axis("off")

    fig.suptitle("Categorical frequencies (top levels)", y=1.02)
    fname = "categorical_frequencies.png"
    _save_fig(outdir / fname)
    return PlotArtifact(
        title="Categorical frequencies",
        filename=fname,
        description=f"Bar charts for up to {max_cols} categorical variables (top 20 levels each).",
    )


def write_html_report(
    outdir: Path,
    artifacts: list[PlotArtifact],
    input_path: Path,
    df: pd.DataFrame,
    numeric_cols: list[str],
    cat_cols: list[str],
) -> None:
    parts: list[str] = []
    parts.append("<!doctype html>")
    parts.append("<html><head><meta charset='utf-8'>")
    parts.append("<meta name='viewport' content='width=device-width, initial-scale=1'>")
    parts.append("<title>EDA Distributions Report</title>")
    parts.append(
        "<style>body{font-family:system-ui, -apple-system, Segoe UI, Roboto, Arial; margin:24px;} "
        ".grid{display:grid; grid-template-columns:repeat(auto-fit,minmax(320px,1fr)); gap:18px;} "
        ".card{border:1px solid #ddd; border-radius:10px; padding:12px;} "
        "img{max-width:100%; height:auto; border-radius:6px;} "
        "code{background:#f6f8fa; padding:2px 6px; border-radius:6px;}" 
        "</style>"
    )
    parts.append("</head><body>")

    parts.append("<h1>EDA Distributions Report</h1>")
    parts.append("<p>")
    parts.append(f"Generated: <code>{html.escape(datetime.now().isoformat(timespec='seconds'))}</code><br>")
    parts.append(f"Input: <code>{html.escape(str(input_path))}</code><br>")
    parts.append(f"Rows: <code>{len(df)}</code>, Columns: <code>{df.shape[1]}</code><br>")
    parts.append(f"Numeric cols: <code>{len(numeric_cols)}</code>, Categorical cols: <code>{len(cat_cols)}</code>")
    parts.append("</p>")

    parts.append("<h2>Artifacts</h2>")
    parts.append("<div class='grid'>")
    for a in artifacts:
        parts.append("<div class='card'>")
        parts.append(f"<h3>{html.escape(a.title)}</h3>")
        parts.append(f"<p>{html.escape(a.description)}</p>")
        parts.append(f"<a href='{html.escape(a.filename)}'><img src='{html.escape(a.filename)}' alt='{html.escape(a.title)}'></a>")
        parts.append("</div>")
    parts.append("</div>")

    parts.append("<h2>Notes</h2>")
    parts.append(
        "<ul>"
        "<li>Correlation uses Spearman (rank-based) by default.</li>"
        "<li>Pairplot drops rows with missing values for the selected columns.</li>"
        "<li>Categorical frequency plots show the top 20 levels for each variable.</li>"
        "</ul>"
    )

    parts.append("</body></html>")
    _write_text(outdir / "index.html", "\n".join(parts))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate dataset distribution visualizations + HTML report")
    parser.add_argument("--in", dest="in_path", default=str(DEFAULT_IN), help="Input CSV path")
    parser.add_argument("--outdir", default=str(DEFAULT_OUTDIR), help="Output directory")
    parser.add_argument(
        "--var_table",
        default=str(DEFAULT_VAR_TABLE),
        help="Optional variable table CSV (results/tables/variable_table.csv) used for labels",
    )
    parser.add_argument("--max_numeric", type=int, default=12, help="Max numeric columns for multi-plot figures")
    parser.add_argument("--max_cat", type=int, default=12, help="Max categorical columns for frequency plots")
    args = parser.parse_args()

    in_path = Path(args.in_path)
    outdir = Path(args.outdir)
    _ensure_dir(outdir)

    if not in_path.exists():
        raise FileNotFoundError(f"Input file not found: {in_path}")

    sns.set_theme(style="whitegrid")

    df = pd.read_csv(in_path)
    df = _basic_clean(df)

    labels_map = _load_variable_labels_map(Path(args.var_table))

    # For plotting, use label (code) where available.
    df_plot = df.copy()
    df_plot.columns = [_display_name(c, labels_map) for c in df_plot.columns]

    numeric_cols, cat_cols = _infer_types(df_plot)

    # Save a simple data dictionary-ish overview
    overview = pd.DataFrame(
        {
            "column": df_plot.columns,
            "dtype": [str(df_plot[c].dtype) for c in df_plot.columns],
            "non_null": [int(df_plot[c].notna().sum()) for c in df_plot.columns],
            "missing": [int(df_plot[c].isna().sum()) for c in df_plot.columns],
            "nunique": [int(df_plot[c].nunique(dropna=True)) for c in df_plot.columns],
        }
    )
    overview.to_csv(outdir / "column_overview.csv", index=False)

    artifacts: list[PlotArtifact] = []

    artifacts.append(plot_missingness(df_plot, outdir))
    artifacts.append(plot_summary_table(df_plot, numeric_cols, outdir))
    artifacts.append(plot_hist_grid(df_plot, numeric_cols, outdir, max_cols=args.max_numeric))
    artifacts.append(plot_kde_ridgeline(df_plot, numeric_cols, outdir, max_cols=args.max_numeric))
    artifacts.extend(plot_box_violin(df_plot, numeric_cols, outdir, max_cols=args.max_numeric))
    artifacts.append(plot_ecdf(df_plot, numeric_cols, outdir, max_cols=max(2, min(6, len(numeric_cols)))))
    artifacts.append(plot_qq(df_plot, numeric_cols, outdir, max_cols=max(2, min(6, len(numeric_cols)))))
    artifacts.append(plot_corr_heatmap(df_plot, numeric_cols, outdir, max_cols=30))
    artifacts.append(plot_pairplot(df_plot, numeric_cols, outdir, max_cols=max(3, min(6, len(numeric_cols)))))
    artifacts.append(plot_hexbin(df_plot, numeric_cols, outdir))
    artifacts.append(plot_categorical_bars(df_plot, cat_cols, outdir, max_cols=args.max_cat))

    write_html_report(
        outdir=outdir,
        artifacts=artifacts,
        input_path=in_path,
        df=df,
        numeric_cols=numeric_cols,
        cat_cols=cat_cols,
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
