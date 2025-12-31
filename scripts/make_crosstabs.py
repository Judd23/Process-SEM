#!/usr/bin/env python3
"""Create crosstabulation tables from an input CSV.

Default behavior (most common need in this repo):
- Crosstab each categorical variable by the treatment/exposure indicator (default: x_FASt)
- Emit a single long-form CSV that includes counts + row/column percentages
- Also emit an HTML preview for quick viewing

Usage:
  python scripts/make_crosstabs.py \
    --in results/distribution_alignment/rep_data_aligned.csv \
    --by x_FASt \
    --outdir results/tables

Optional:
  --vars re_all,sex,pell   # only these variables (comma-separated)
  --max_levels 20          # skip vars with too many categories
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable, List

import numpy as np
import pandas as pd


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _infer_categorical_columns(df: pd.DataFrame, by: str, max_levels: int) -> List[str]:
    cols: List[str] = []
    for c in df.columns:
        if c == by:
            continue
        s = df[c]
        # objects are categorical
        if pd.api.types.is_object_dtype(s) or isinstance(s.dtype, pd.CategoricalDtype) or pd.api.types.is_bool_dtype(s):
            nunique = int(s.nunique(dropna=False))
            if nunique <= max_levels:
                cols.append(c)
            continue

        # low-cardinality integer-coded columns
        if pd.api.types.is_integer_dtype(s):
            nunique = int(s.nunique(dropna=False))
            if 2 <= nunique <= min(12, max_levels):
                cols.append(c)

    # stable order
    return cols


def _crosstab_long(df: pd.DataFrame, var: str, by: str) -> pd.DataFrame:
    a = df[var].astype("string")
    b = df[by].astype("string")

    ct = pd.crosstab(a, b, dropna=False)

    # counts
    out = ct.reset_index().melt(id_vars=[var], var_name=by, value_name="count")

    # totals
    row_tot = ct.sum(axis=1)
    col_tot = ct.sum(axis=0)

    # row % (within var level)
    row_pct = (ct.div(row_tot.replace(0, np.nan), axis=0) * 100.0).reset_index().melt(
        id_vars=[var], var_name=by, value_name="row_pct"
    )

    # col % (within by level)
    col_pct = (ct.div(col_tot.replace(0, np.nan), axis=1) * 100.0).reset_index().melt(
        id_vars=[var], var_name=by, value_name="col_pct"
    )

    merged = out.merge(row_pct, on=[var, by], how="left").merge(col_pct, on=[var, by], how="left")
    merged.insert(0, "variable", var)
    merged = merged.rename(columns={var: "level"})

    # add overall pct for context
    grand_total = float(ct.to_numpy().sum())
    if grand_total > 0:
        merged["overall_pct"] = merged["count"] / grand_total * 100.0
    else:
        merged["overall_pct"] = np.nan

    # helpful ordering
    merged["by_level"] = merged[by]
    merged = merged.drop(columns=[by])
    return merged


def _to_simple_html(df: pd.DataFrame, title: str) -> str:
    style = (
        "<style>"
        "body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:20px;}"
        "table{border-collapse:collapse;width:100%;}"
        "th,td{border:1px solid #ddd;padding:6px 8px;font-size:12px;}"
        "th{background:#f5f5f5;text-align:left;}"
        "tr:nth-child(even){background:#fafafa;}"
        "</style>"
    )
    return (
        "<html><head><meta charset='utf-8'><title>"
        + title
        + "</title>"
        + style
        + "</head><body><h1>"
        + title
        + "</h1>"
        + df.to_html(index=False, escape=True)
        + "</body></html>"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Create crosstabulation tables")
    ap.add_argument("--in", dest="in_csv", required=True, help="Input CSV")
    ap.add_argument("--by", default="x_FASt", help="Column to crosstab against (default: x_FASt)")
    ap.add_argument("--vars", default=None, help="Comma-separated variables to crosstab (defaults to inferred categoricals)")
    ap.add_argument("--max_levels", type=int, default=20, help="Skip vars with > max_levels unique values")
    ap.add_argument("--outdir", default="results/tables", help="Output directory")
    args = ap.parse_args()

    in_csv = Path(args.in_csv)
    outdir = Path(args.outdir)
    _ensure_dir(outdir)

    df = pd.read_csv(in_csv)
    by = args.by
    if by not in df.columns:
        raise ValueError(f"--by column not found: {by}")

    if args.vars:
        vars_ = [v.strip() for v in args.vars.split(",") if v.strip()]
    else:
        vars_ = _infer_categorical_columns(df, by=by, max_levels=int(args.max_levels))

    # filter out columns with too many levels (even if user provided them)
    kept: List[str] = []
    skipped: List[str] = []
    for v in vars_:
        if v not in df.columns:
            skipped.append(f"{v} (missing)")
            continue
        nunique = int(df[v].nunique(dropna=False))
        if nunique > int(args.max_levels):
            skipped.append(f"{v} ({nunique} levels)")
            continue
        kept.append(v)

    frames: List[pd.DataFrame] = []
    for v in kept:
        frames.append(_crosstab_long(df, var=v, by=by))

    out = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()

    csv_path = outdir / f"crosstabs_by_{by}.csv"
    html_path = outdir / f"crosstabs_by_{by}.html"
    meta_path = outdir / f"crosstabs_by_{by}_notes.txt"

    out.to_csv(csv_path, index=False)

    # Write a readable HTML preview (first ~500 rows if huge)
    preview = out.head(500).copy()
    html = _to_simple_html(preview, title=f"Crosstabs by {by} (preview)")
    html_path.write_text(html, encoding="utf-8")

    meta = [
        f"Input: {in_csv}",
        f"By: {by}",
        f"Variables included: {len(kept)}",
        f"Variables skipped: {len(skipped)}",
    ]
    if skipped:
        meta.append("Skipped details:")
        meta.extend([f"- {s}" for s in skipped])
    meta_path.write_text("\n".join(meta) + "\n", encoding="utf-8")

    print(f"Wrote: {csv_path}")
    print(f"Wrote: {html_path}")
    print(f"Wrote: {meta_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
