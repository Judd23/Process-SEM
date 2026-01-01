#!/usr/bin/env python3
"""Build a collapse + recode report for rep_data.csv.

Writes:
- results/recode_reports/rep_data_collapse_recodes_report.csv
- results/recode_reports/rep_data_collapse_recodes_report.md

The report combines:
- Observed values in rep_data.csv
- Documented transformations from scripts/make_variable_table.R
- Raw response categories from:
  - Codebooks /BCSSE24_US_Codebook.xlsx
  - Codebooks /nsse-2024 codebook-core-us.docx
  - Codebooks /nsse-2024-mhw-codebook.docx
"""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd
from docx import Document


@dataclass
class CodebookEntry:
    label: str = ""
    values: Dict[str, str] = None  # code -> label
    response_options: str = ""  # from NSSE docx

    def __post_init__(self) -> None:
        if self.values is None:
            self.values = {}


def load_bcsse_xlsx(xlsx_path: Path) -> Dict[str, CodebookEntry]:
    out: Dict[str, CodebookEntry] = {}
    if not xlsx_path.exists():
        return out

    xl = pd.ExcelFile(xlsx_path)

    # Variable labels / metadata
    if "Variable Information" in xl.sheet_names:
        info = xl.parse("Variable Information")
        info = info.rename(columns={c: str(c).strip() for c in info.columns})

        # The sheet is often formatted with a nonstandard header. If expected columns
        # aren't present, re-read with a different header offset.
        if "Variable" not in info.columns or "Label" not in info.columns:
            info = pd.read_excel(xlsx_path, sheet_name="Variable Information", header=2)
            # Observed layout: Variable, Position, Label, Measurement Level, Column Width, Write Format
            if len(info.columns) >= 6:
                info = info.iloc[:, :6].copy()
                info.columns = [
                    "Variable",
                    "Position",
                    "Label",
                    "Measurement Level",
                    "Column Width",
                    "Write Format",
                ]

        if "Variable" in info.columns and "Label" in info.columns:
            for _, row in info.iterrows():
                var = str(row.get("Variable", "")).strip()
                lab = str(row.get("Label", "")).strip()
                if not var or var.lower() == "nan":
                    continue
                out.setdefault(var, CodebookEntry())
                if lab and lab.lower() != "nan":
                    out[var].label = lab

    # Value labels
    if "Variable labels" in xl.sheet_names:
        df = xl.parse("Variable labels")
        df = df.rename(columns={c: str(c).strip() for c in df.columns})
        # This sheet is block-structured:
        # - first column contains variable name on first row of block
        # - subsequent rows in block have blank var cell but have Value + Label
        var_col = df.columns[0]
        val_col = df.columns[1]
        lab_col = df.columns[2]

        current_var: Optional[str] = None
        for _, row in df.iterrows():
            vcell = row.get(var_col)
            if isinstance(vcell, str) and vcell.strip() and vcell.strip() != "Value":
                current_var = vcell.strip()
                out.setdefault(current_var, CodebookEntry())
                continue

            if current_var is None:
                continue

            code = row.get(val_col)
            label = row.get(lab_col)
            if pd.isna(code) or pd.isna(label):
                continue
            code_s = str(code).strip()
            label_s = str(label).strip()
            if not code_s or not label_s:
                continue
            out.setdefault(current_var, CodebookEntry())
            out[current_var].values[code_s] = label_s

    return out


def load_nsse_docx(docx_path: Path) -> Dict[str, CodebookEntry]:
    """Parse NSSE docx paragraphs.

    Pattern observed:
    - A battery/question stem paragraph
    - A paragraph starting with "Response options:" giving the coding
    - One or more item lines containing "[...]" variable tags

    We attach the most recent response-options line to each subsequent variable-tagged item.
    """
    out: Dict[str, CodebookEntry] = {}
    if not docx_path.exists():
        return out

    doc = Document(str(docx_path))
    paras = [(p.text or "").strip() for p in doc.paragraphs]
    current_response: str = ""

    for i, text in enumerate(paras):
        if not text:
            continue

        lower = text.lower()
        if lower.startswith("response options:"):
            current_response = text
            continue

        next_text = paras[i + 1].strip() if i + 1 < len(paras) else ""
        next_lower = next_text.lower() if next_text else ""

        # Prefer response-options tied to THIS question (usually appears in the *next* paragraph).
        resp_for_this = ""
        if "response options:" in lower:
            # sometimes options are embedded in the same paragraph
            j = lower.find("response options:")
            resp_for_this = text[j:].strip()
        elif next_lower.startswith("response options:"):
            resp_for_this = next_text
        else:
            # battery items: response-options paragraph precedes many item lines
            resp_for_this = current_response

        # capture all [var] tags in this paragraph
        for m in re.finditer(r"\[([A-Za-z0-9_]+)\]", text):
            var = m.group(1)
            out.setdefault(var, CodebookEntry())
            # store a short label = the visible question text with the tag removed
            label = re.sub(r"\s*\[[A-Za-z0-9_]+\]\s*", "", text).strip()
            if label:
                out[var].label = label
            if resp_for_this:
                out[var].response_options = resp_for_this

    return out


def load_variable_table_equations(r_path: Path) -> Dict[str, Dict[str, str]]:
    """Return a mapping for variables from results/tables/variable_table.csv.

    We intentionally do NOT parse the R file with regex because loops/builders make that
    fragile. Instead, we run the R script (if needed) and read the generated CSV.
    """
    out: Dict[str, Dict[str, str]] = {}
    if not r_path.exists():
        return out

    variable_table_csv = Path("results/tables/variable_table.csv")
    if not variable_table_csv.exists():
        # Build it via the repo's R script
        subprocess.run(
            ["Rscript", str(r_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    if not variable_table_csv.exists():
        return out

    vt = pd.read_csv(variable_table_csv)
    # Keep only rows that map to actual dataset columns
    vt = vt.rename(columns={c: str(c).strip() for c in vt.columns})
    if "variable" not in vt.columns:
        return out

    for _, row in vt.iterrows():
        var = row.get("variable")
        if pd.isna(var):
            continue
        var = str(var).strip()
        if not var:
            continue
        out[var] = {
            "label": str(row.get("label", "") if not pd.isna(row.get("label", "")) else "").strip(),
            "stat_equation": str(row.get("stat_equation", "") if not pd.isna(row.get("stat_equation", "")) else "").strip(),
            "notes": str(row.get("notes", "") if not pd.isna(row.get("notes", "")) else "").strip(),
            "role": str(row.get("role", "") if not pd.isna(row.get("role", "")) else "").strip(),
            "measurement_type": str(
                row.get("measurement_type", "") if not pd.isna(row.get("measurement_type", "")) else ""
            ).strip(),
            "scale": str(row.get("scale", "") if not pd.isna(row.get("scale", "")) else "").strip(),
            "scale_points": str(row.get("scale_points", "") if not pd.isna(row.get("scale_points", "")) else "").strip(),
            "construct_code": str(row.get("construct_code", "") if not pd.isna(row.get("construct_code", "")) else "").strip(),
            "code_name": str(row.get("code_name", "") if not pd.isna(row.get("code_name", "")) else "").strip(),
        }

    return out


def summarize_observed(df: pd.DataFrame, col: str, max_levels: int = 30) -> Tuple[str, str]:
    """Return (observed_type, observed_summary)."""
    s = df[col]

    if pd.api.types.is_numeric_dtype(s):
        sn = pd.to_numeric(s, errors="coerce")
        uniq = sn.dropna().unique()
        if len(uniq) <= max_levels:
            vals = ", ".join(str(v) for v in sorted(uniq))
            return ("numeric", f"unique<= {max_levels}: {vals}")
        return (
            "numeric",
            f"n={sn.notna().sum():,}; mean={sn.mean():.4g}; sd={sn.std(ddof=1):.4g}; min={sn.min():.4g}; max={sn.max():.4g}",
        )

    # treat as categorical
    sc = s.astype(str)
    vc = sc.value_counts(dropna=False)
    levels = list(vc.index[:max_levels])
    shown = "; ".join([f"{lvl}={int(vc[lvl])}" for lvl in levels])
    more = "" if len(vc) <= max_levels else f"; +{len(vc)-max_levels} more levels"
    return ("categorical", shown + more)


def guess_recode_type(var: str, df_cols: List[str]) -> str:
    if var.endswith("_c") and var[:-2] in df_cols:
        return "centered (mean=0)"
    if var in {"x_FASt"}:
        return "binary recode"
    if var in {"credit_dose"}:
        return "derived continuous"
    if var in {"credit_dose_c", "XZ_c"}:
        return "derived/centered"
    if var in {"hgrades"}:
        return "derived (standardized)"
    if var in {"hgrades_AF"}:
        return "collapsed categorical"
    if var in {"re_all"}:
        return "collapsed categorical"
    return "(see formula/notes)"


def verify_known_transforms(df: pd.DataFrame) -> Dict[str, Dict[str, str]]:
    """Compute sanity checks for a few key derived/recode variables."""
    out: Dict[str, Dict[str, str]] = {}

    cols = set(df.columns)

    def put(var: str, status: str, detail: str) -> None:
        out[var] = {"verified_status": status, "verified_detail": detail}

    if {"trnsfr_cr", "x_FASt"}.issubset(cols):
        calc = (df["trnsfr_cr"] >= 12).astype(int)
        d = (df["x_FASt"] - calc).abs().max()
        put("x_FASt", "ok" if d == 0 else "mismatch", f"max_abs_diff_vs_1(trnsfr_cr>=12)={d}")

    if {"trnsfr_cr", "credit_dose"}.issubset(cols):
        calc_plain = (df["trnsfr_cr"] - 12) / 10
        calc_pmax = ((df["trnsfr_cr"] - 12).clip(lower=0)) / 10
        d_plain = (df["credit_dose"] - calc_plain).abs().max()
        d_pmax = (df["credit_dose"] - calc_pmax).abs().max()
        if d_plain == 0:
            put("credit_dose", "ok", "matches (trnsfr_cr - 12)/10 exactly")
        elif d_pmax == 0:
            put("credit_dose", "ok", "matches pmax(0, trnsfr_cr - 12)/10 exactly")
        else:
            put(
                "credit_dose",
                "mismatch",
                f"max_abs_diff_plain={(float(d_plain)):.6g}; max_abs_diff_pmax={(float(d_pmax)):.6g}",
            )

    if {"credit_dose", "credit_dose_c"}.issubset(cols):
        calc = df["credit_dose"] - df["credit_dose"].mean()
        d = (df["credit_dose_c"] - calc).abs().max()
        put("credit_dose_c", "ok" if d < 1e-12 else "mismatch", f"max_abs_diff_vs_centered={d}")

    if {"x_FASt", "credit_dose_c", "XZ_c"}.issubset(cols):
        calc = df["x_FASt"] * df["credit_dose_c"]
        d = (df["XZ_c"] - calc).abs().max()
        put("XZ_c", "ok" if d < 1e-12 else "mismatch", f"max_abs_diff_vs_x*credit_dose_c={d}")

    if {"hgrades_AF", "hgrades"}.issubset(cols):
        # empirically: A=5,B=4,C=3,D=2,F=1
        mapping = {"A": 5, "B": 4, "C": 3, "D": 2, "F": 1}
        x = df["hgrades_AF"].map(mapping)
        z = (x - x.mean()) / x.std(ddof=1)
        d = (df["hgrades"] - z).abs().max()
        put("hgrades", "ok" if d < 1e-12 else "mismatch", f"max_abs_diff_vs_z(mapped_AF)={d}")

    if {"hgrades", "hgrades_c"}.issubset(cols):
        calc = df["hgrades"] - df["hgrades"].mean()
        d = (df["hgrades_c"] - calc).abs().max()
        put("hgrades_c", "ok" if d < 1e-12 else "mismatch", f"max_abs_diff_vs_centered={d}")

    # generic _c checks
    for c in df.columns:
        if c.endswith("_c") and c[:-2] in cols and c not in out:
            base = c[:-2]
            if pd.api.types.is_numeric_dtype(df[c]) and pd.api.types.is_numeric_dtype(df[base]):
                calc = df[base] - df[base].mean()
                d = (df[c] - calc).abs().max()
                put(c, "ok" if d < 1e-12 else "mismatch", f"max_abs_diff_vs_centered({base})={d}")

    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Build collapse + recode report for rep_data.csv")
    ap.add_argument("--in", dest="in_csv", default="rep_data.csv", help="Input CSV")
    ap.add_argument("--outdir", default="results/recode_reports", help="Output directory")
    args = ap.parse_args()

    in_csv = Path(args.in_csv)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    if not in_csv.exists():
        raise FileNotFoundError(f"Input not found: {in_csv}")

    df = pd.read_csv(in_csv)
    df_cols = list(df.columns)

    # Load codebooks
    bcsse = load_bcsse_xlsx(Path("Codebooks /BCSSE24_US_Codebook.xlsx"))
    nsse_core = load_nsse_docx(Path("Codebooks /nsse-2024 codebook-core-us.docx"))
    nsse_mhw = load_nsse_docx(Path("Codebooks /nsse-2024-mhw-codebook.docx"))

    eqs = load_variable_table_equations(Path("scripts/make_variable_table.R"))
    ver = verify_known_transforms(df)

    # Candidate list: anything derived/centered/collapsed OR documented in variable table OR present in codebooks
    candidates: List[str] = []
    codebook_vars = set(bcsse.keys()) | set(nsse_core.keys()) | set(nsse_mhw.keys())
    for c in df_cols:
        if c.endswith("_c"):
            candidates.append(c)
        if c in {
            "hgrades_AF",
            "hgrades",
            "x_FASt",
            "trnsfr_cr",
            "credit_dose",
            "credit_dose_c",
            "XZ_c",
            "re_all",
            "living18",
            "sex",
            "cohort",
            "pell",
            "hapcl",
            "firstgen",
        }:
            candidates.append(c)
        if c in eqs:
            candidates.append(c)
        if c in codebook_vars:
            candidates.append(c)

    # de-dup but preserve order
    seen = set()
    candidates = [c for c in candidates if not (c in seen or seen.add(c))]

    rows: List[Dict[str, str]] = []
    for var in candidates:
        obs_type, obs = summarize_observed(df, var)

        # Merge codebook info (prefer BCSSE for baseline covariates, NSSE for engagement/well-being)
        cb = CodebookEntry()
        cb_source = "(not found)"
        cb_matched_var = ""

        # Some BCSSE vars in rep_data.csv drop a leading 't' (e.g., ttrnsfr_cr -> trnsfr_cr)
        # and hgrades is often stored as a derived column from hgrades23.
        bcsse_aliases = [var]
        if not var.startswith("t"):
            bcsse_aliases.append(f"t{var}")
        if var == "trnsfr_cr":
            bcsse_aliases.extend(["ttrnsfr_cr"])  # explicit
        if var == "hgrades_AF":
            bcsse_aliases.extend(["hgrades23"])  # explicit

        for a in bcsse_aliases:
            if a in bcsse:
                cb = bcsse[a]
                cb_source = "BCSSE24_US_Codebook.xlsx"
                cb_matched_var = a
                break

        # NSSE: allow manual aliases and case-insensitive matches
        nsse_alias_map = {
            # Belonging items appear with capitalized tags in the NSSE core codebook
            "sbmyself": "SBmyself",
            "sbvalued": "SBvalued",
            "sbcommunity": "SBcommunity",
            # Rep dataset uses MHWdfinancial; NSSE MHW codebook uses MHWdfinance
            "MHWdfinancial": "MHWdfinance",
        }

        def _nsse_lookup(d: Dict[str, CodebookEntry], key: str) -> str:
            if key in d:
                return key
            # manual alias
            if key in nsse_alias_map and nsse_alias_map[key] in d:
                return nsse_alias_map[key]
            # case-insensitive exact
            k_low = key.lower()
            for k in d.keys():
                if k.lower() == k_low:
                    return k
            return ""

        if cb_source == "(not found)":
            k = _nsse_lookup(nsse_core, var)
            if k:
                cb = nsse_core[k]
                cb_source = "nsse-2024 codebook-core-us.docx"
                cb_matched_var = k

        if cb_source == "(not found)":
            k = _nsse_lookup(nsse_mhw, var)
            if k:
                cb = nsse_mhw[k]
                cb_source = "nsse-2024-mhw-codebook.docx"
                cb_matched_var = k

        # Transform info
        eq = eqs.get(var, {})
        vcheck = ver.get(var, {})

        # Build raw category text
        raw_cats = ""
        if cb.values:
            # keep compact
            pairs = []
            for k, v in list(cb.values.items())[:60]:
                pairs.append(f"{k}={v}")
            raw_cats = "; ".join(pairs)
            if len(cb.values) > 60:
                raw_cats += f"; +{len(cb.values)-60} more"
        elif cb.response_options:
            raw_cats = cb.response_options

        # Quick codebook-vs-observed alignment check (helps spot accidental mismatches)
        alignment_flag = ""
        alignment_detail = ""
        recode_type = guess_recode_type(var, df_cols)
        if raw_cats and obs_type in {"numeric", "categorical"}:
            # Extract numeric codes from codebook text if possible
            codes: List[str] = []
            if cb.values:
                codes = list(cb.values.keys())
            else:
                # Response options: ...=4, ...=3, ...=2 ...
                codes = re.findall(r"=\s*([0-9]+)", raw_cats)

                # Handle ranges like "Poor=1 to Excellent=7"
                m_rng = re.search(r"=\s*([0-9]+)\s*to\s*[^=]*=\s*([0-9]+)", raw_cats)
                if m_rng:
                    lo = int(m_rng.group(1))
                    hi = int(m_rng.group(2))
                    if lo <= hi:
                        codes.extend([str(i) for i in range(lo, hi + 1)])

            codes_set = set(str(c).strip() for c in codes if str(c).strip())
            observed_set: Optional[set] = None
            try:
                uniq = pd.Series(df[var]).dropna().unique()
                if len(uniq) <= 30:
                    observed_set = set(str(u).strip() for u in uniq)
            except Exception:
                observed_set = None

            if codes_set and observed_set:
                if recode_type.startswith("collapsed") or recode_type.startswith("derived") or "recode" in recode_type:
                    alignment_flag = "expected_recode"
                    alignment_detail = "observed values differ from codebook; variable is labeled as derived/collapsed"
                else:
                    # Normalize common missing codes like 9/99
                    if observed_set.issubset(codes_set):
                        alignment_flag = "ok_or_subset"
                        if observed_set != codes_set:
                            alignment_detail = f"observed subset of codebook codes (obs={sorted(observed_set)}; codebook includes more)"
                    else:
                        alignment_flag = "mismatch"
                        alignment_detail = f"observed not subset of codebook codes (obs={sorted(observed_set)}; codes~={sorted(list(codes_set))[:12]}...)"

        rows.append(
            {
                "variable": var,
                "recode_type": recode_type,
                "documented_label": eq.get("label", "") or cb.label,
                "stat_equation": eq.get("stat_equation", ""),
                "notes": eq.get("notes", ""),
                "observed_type": obs_type,
                "observed_values": obs,
                "raw_item_categories_from_codebooks": raw_cats,
                "verified_status": vcheck.get("verified_status", ""),
                "verified_detail": vcheck.get("verified_detail", ""),
                "codebook_alignment_flag": alignment_flag,
                "codebook_alignment_detail": alignment_detail,
                "codebook_source": cb_source,
                "codebook_variable_matched": cb_matched_var,
            }
        )

    out_csv = outdir / "rep_data_collapse_recodes_report.csv"
    pd.DataFrame(rows).to_csv(out_csv, index=False)

    # Markdown summary
    md = []
    md.append(f"# rep_data.csv: Collapse + Recode Report\n")
    md.append(f"Input: `{in_csv}`\n")
    md.append("## Notes\n")
    md.append("- This report lists variables in `rep_data.csv` that are commonly derived, centered, or collapsed in this repo, plus any variables with documented equations in `scripts/make_variable_table.R`.\n")
    md.append("- `raw_item_categories_from_codebooks` is extracted from the provided codebooks when an exact variable-name match is found; otherwise it is left blank.\n")
    md.append("\n## Output\n")
    md.append(f"- CSV: `{out_csv}`\n")

    md_path = outdir / "rep_data_collapse_recodes_report.md"
    md_path.write_text("\n".join(md), encoding="utf-8")

    print(f"Wrote: {out_csv}")
    print(f"Wrote: {md_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
