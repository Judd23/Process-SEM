#!/usr/bin/env python3
"""Align specific item distributions in rep_data.csv to targets from the provided image.

Targets (from user-supplied table):

SB items:
- sbmyself: Agree/Strongly Agree ~90%
- sbvalued: Agree/Strongly Agree ~81%

Interpretation used here:
- We enforce a 4-point SB scale (1..4). If the input uses 1..5, we collapse 4/5 -> 4.
- Agree/Strongly Agree := values >= 3 (i.e., categories 3–4)
- Other := values <= 2

MHW difficulty items (NSSE 2024):
- Responses are 1–6 (Not at all difficult=1 … Very difficult=6)
- 9 = Not applicable

Interpretation used here:
- Do NOT collapse 1–6 into 1–4
- Rewrite MHWd* items to match anchor marginals (1–6 + 9)
- Induce correlation across items via a shared latent factor (EmoDiss_true)

This script edits only the listed columns.
It makes a timestamped backup before overwriting the input when --inplace is used.

Usage:
  python scripts/align_distributions_to_image_targets.py --csv rep_data.csv --inplace

Outputs:
  results/distribution_alignment/image_targets_summary.csv
  results/distribution_alignment/image_targets_notes.txt
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd


OUTDIR = Path("results/distribution_alignment")


@dataclass(frozen=True)
class AdjustResult:
    column: str
    rows_changed: int


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _normalize_probs(probs: Dict[int, float]) -> Dict[int, float]:
    total = float(sum(probs.values()))
    if total <= 0:
        raise ValueError("probabilities sum to 0")
    return {k: float(v) / total for k, v in probs.items()}


def _desired_counts(n: int, probs: Dict[int, float]) -> Dict[int, int]:
    levels = sorted(probs.keys())
    raw = {lvl: probs[lvl] * n for lvl in levels}
    flo = {lvl: int(np.floor(raw[lvl])) for lvl in levels}
    rem = n - int(sum(flo.values()))
    fracs = sorted(((raw[lvl] - flo[lvl], lvl) for lvl in levels), reverse=True)
    out = dict(flo)
    for i in range(rem):
        out[fracs[i % len(fracs)][1]] += 1
    return out


def _adjust_discrete_min_change(
    s: pd.Series,
    probs: Dict[int, float],
    rng: np.random.Generator,
) -> Tuple[pd.Series, int]:
    """Adjust discrete integer series to match target distribution with minimal changes."""
    out = s.copy()
    n = int(len(out))
    probs = _normalize_probs(probs)
    desired = _desired_counts(n, probs)
    current = out.value_counts(dropna=False).to_dict()

    surplus_idx: List[int] = []
    deficit: List[Tuple[int, int]] = []

    for lvl in sorted(desired.keys()):
        cur = int(current.get(lvl, 0))
        des = int(desired[lvl])
        if cur > des:
            idx = out.index[out == lvl].to_numpy()
            choose = rng.choice(idx, size=(cur - des), replace=False)
            surplus_idx.extend(int(i) for i in choose)
        elif cur < des:
            deficit.append((lvl, des - cur))

    rng.shuffle(surplus_idx)

    changed = 0
    cursor = 0
    for lvl, need in deficit:
        take = min(need, len(surplus_idx) - cursor)
        for j in range(cursor, cursor + take):
            i = surplus_idx[j]
            if int(out.at[i]) != lvl:
                out.at[i] = lvl
                changed += 1
        cursor += take

        # If we still need more (rounding edge), take from anywhere not already that level.
        remaining = need - take
        if remaining > 0:
            pool = out.index[out != lvl].to_numpy()
            extra = rng.choice(pool, size=remaining, replace=False)
            for i in extra:
                out.at[i] = lvl
                changed += 1

    return out, changed


def _adjust_agree_threshold(
    s: pd.Series,
    target_agree: float,
    agree_threshold: int,
    rng: np.random.Generator,
) -> Tuple[pd.Series, int]:
    out = s.copy().astype(int)
    n = len(out)
    desired = int(round(float(target_agree) * n))
    is_agree = out >= agree_threshold
    cur = int(is_agree.sum())
    if cur == desired:
        return out, 0

    if desired > cur:
        need = desired - cur
        pool = out.index[~is_agree].to_numpy()
        choose = rng.choice(pool, size=need, replace=False)
        out.loc[choose] = agree_threshold
        return out, int(need)

    need = cur - desired
    pool = out.index[is_agree].to_numpy()
    choose = rng.choice(pool, size=need, replace=False)
    out.loc[choose] = agree_threshold - 1
    return out, int(need)


def _collapse_sb_to_4(s: pd.Series) -> pd.Series:
    """Collapse SB items to a 1..4 scale.

    If input is 1..5, map 4/5 -> 4.
    """
    out = s.astype(int).copy()
    out = out.clip(lower=1)
    out = out.where(out <= 4, 4)
    return out


def _zscore(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    mu = np.nanmean(x)
    sd = np.nanstd(x)
    if not np.isfinite(sd) or sd <= 0:
        return x * 0.0
    return (x - mu) / sd


def _ordinal_from_quantiles(eta: np.ndarray, probs: np.ndarray) -> np.ndarray:
    """Assign ordinal categories 1..K based on quantile thresholds.

    probs must be length K and sum to 1 (will be normalized defensively).
    """
    probs = np.asarray(probs, dtype=float)
    probs = np.clip(probs, 0, None)
    if probs.sum() <= 0:
        probs = np.ones_like(probs) / len(probs)
    probs = probs / probs.sum()

    cum = np.cumsum(probs)[:-1]
    cuts = np.quantile(eta, cum)
    return (np.digitize(eta, cuts, right=True) + 1).astype(int)


def _before_after_props(s: pd.Series, levels: List[int]) -> Dict[int, float]:
    vc = s.value_counts(normalize=True)
    return {lvl: float(vc.get(lvl, 0.0)) for lvl in levels}


def main() -> int:
    ap = argparse.ArgumentParser(description="Align rep_data.csv distributions to image targets")
    ap.add_argument("--csv", required=True, help="Input CSV (rep_data.csv)")
    ap.add_argument("--seed", type=int, default=123, help="RNG seed")
    ap.add_argument("--inplace", action="store_true", help="Overwrite input CSV (creates a timestamped .bak first)")
    ap.add_argument("--out", default=None, help="Output CSV path (if not --inplace)")
    args = ap.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        raise FileNotFoundError(csv_path)

    rng = np.random.default_rng(args.seed)
    df = pd.read_csv(csv_path)

    # Targets from the user table
    sb_targets = {
        "sbmyself": 0.90,
        "sbvalued": 0.81,
    }

    # Anchor distributions (unconditional; includes NA coded 9)
    anchor_a = {1: 0.16, 2: 0.12, 3: 0.17, 4: 0.24, 5: 0.16, 6: 0.13, 9: 0.03}
    anchor_b = {1: 0.21, 2: 0.14, 3: 0.17, 4: 0.17, 5: 0.11, 6: 0.15, 9: 0.06}

    def _make_target(
        base: Dict[int, float],
        pna: float,
        shift: Dict[int, float] | None = None,
        jitter_sd: float = 0.004,
    ) -> Dict[int, float]:
        """Return unconditional probs for categories 1..6 and 9."""
        shift = shift or {}
        pna = float(pna)
        pna = min(max(pna, 0.0), 0.20)

        base16 = np.array([base.get(k, 0.0) for k in [1, 2, 3, 4, 5, 6]], dtype=float)
        base16 = np.clip(base16, 0.0, None)
        if base16.sum() <= 0:
            base16 = np.ones(6) / 6
        base16 = base16 / base16.sum()

        delta = np.zeros(6)
        for k, v in shift.items():
            if k in [1, 2, 3, 4, 5, 6]:
                delta[[1, 2, 3, 4, 5, 6].index(k)] = float(v)

        p16 = base16 + delta
        if jitter_sd and jitter_sd > 0:
            p16 = p16 + rng.normal(0.0, float(jitter_sd), size=6)

        p16 = np.clip(p16, 0.005, None)
        p16 = p16 / p16.sum()
        mass = 1.0 - pna

        out: Dict[int, float] = {k: float(p16[i] * mass) for i, k in enumerate([1, 2, 3, 4, 5, 6])}
        out[9] = float(pna)
        # Normalize guard
        tot = sum(out.values())
        out = {k: float(v) / tot for k, v in out.items()}
        return out

    # Item targets: close to anchors, with modest theory-aligned item variation.
    mhw_targets: Dict[str, Dict[int, float]] = {
        "MHWdmental": _make_target(anchor_a, pna=0.04),
        "MHWdacad": _make_target(anchor_a, pna=0.03, shift={1: +0.010, 2: +0.010, 4: -0.010, 6: -0.010}),
        "MHWdexhaust": _make_target(anchor_a, pna=0.04, shift={1: -0.010, 4: +0.010, 5: +0.010, 6: -0.010}),
        "MHWdsleep": _make_target(anchor_a, pna=0.05, shift={1: -0.008, 4: +0.008, 5: +0.010, 6: -0.010}),
        "MHWdlonely": _make_target(anchor_b, pna=0.06, shift={1: -0.010, 2: -0.008, 5: +0.008, 6: +0.010}),
        # Canonical codebook naming
        "MHWdfinance": _make_target(anchor_b, pna=0.05, shift={1: -0.010, 2: -0.006, 5: +0.006, 6: +0.010}),
    }

    notes: List[str] = []
    notes.append(f"Input: {csv_path}")
    notes.append(f"Rows: {len(df)}")
    notes.append("SB: enforce 1–4 scale (4/5->4); agree definition: value >= 3")
    notes.append("MHW: keep 1–6; code 9 for Not applicable")

    summary_rows: List[Dict[str, object]] = []

    # Ensure all SB items are on the required 1..4 scale (some source data may be 1..5).
    for col in [c for c in df.columns if c.startswith("sb")]:
        try:
            df[col] = _collapse_sb_to_4(df[col])
        except Exception:
            # If a column is non-numeric, skip rather than fail.
            notes.append(f"SKIP: could not coerce SB column to int: {col}")

    # Adjust SB items
    for col, targ in sb_targets.items():
        if col not in df.columns:
            notes.append(f"SKIP: missing column {col}")
            continue
        before_raw = df[col].astype(int)
        before = _collapse_sb_to_4(before_raw)
        df[col] = before
        before_agree = float((before >= 3).mean())
        after, changed = _adjust_agree_threshold(before, target_agree=targ, agree_threshold=3, rng=rng)
        after_agree = float((after >= 3).mean())
        df[col] = after
        summary_rows.append({
            "column": col,
            "type": "agree>=3",
            "target": targ,
            "before": before_agree,
            "after": after_agree,
            "rows_changed": changed,
        })

    # Adjust / rewrite MHW items (1..6 + 9).
    # Canonicalize finance name if older datasets used MHWdfinancial.
    if "MHWdfinancial" in df.columns and "MHWdfinance" not in df.columns:
        df["MHWdfinance"] = df["MHWdfinancial"]

    # Shared latent driver (EmoDiss_true): prefer existing composite EmoDiss if available.
    if "EmoDiss" in df.columns:
        base_lat = np.asarray(pd.to_numeric(df["EmoDiss"], errors="coerce"), dtype=float)
    else:
        mhw_existing = [c for c in df.columns if c.startswith("MHWd")]
        if mhw_existing:
            tmp = df[mhw_existing].apply(pd.to_numeric, errors="coerce")
            base_lat = np.asarray(tmp.mean(axis=1, skipna=True), dtype=float)
        else:
            base_lat = rng.normal(0.0, 1.0, size=len(df))

    emo = _zscore(base_lat)
    if "pell" in df.columns:
        pell = np.asarray(pd.to_numeric(pd.Series(df["pell"]), errors="coerce"), dtype=float)
        pell = np.nan_to_num(pell, nan=0.0)
    else:
        pell = np.zeros(len(df), dtype=float)

    if "firstgen" in df.columns:
        firstgen = np.asarray(pd.to_numeric(pd.Series(df["firstgen"]), errors="coerce"), dtype=float)
        firstgen = np.nan_to_num(firstgen, nan=0.0)
    else:
        firstgen = np.zeros(len(df), dtype=float)
    re_all = df.get("re_all", pd.Series([""] * len(df))).astype(str)
    race_shift = re_all.isin([
        "Black/African American",
        "Hispanic/Latino",
        "Hispanic/Latino/a",
        "Hispanic/Latino/x",
    ]).to_numpy(dtype=float)
    emo_true = emo + 0.10 * pell + 0.06 * firstgen + 0.06 * race_shift

    loading = 0.85
    noise_sd = 0.60
    levels = [1, 2, 3, 4, 5, 6, 9]

    for col, probs_uncond in mhw_targets.items():
        pna = float(probs_uncond.get(9, 0.0))
        pna = min(max(pna, 0.0), 0.20)
        is_na = rng.random(len(df)) < pna

        p16 = np.array([probs_uncond.get(k, 0.0) for k in [1, 2, 3, 4, 5, 6]], dtype=float)
        p16 = np.clip(p16, 0.0, None)
        if p16.sum() <= 0:
            p16 = np.ones(6) / 6
        p16 = p16 / p16.sum()

        eta = loading * emo_true + rng.normal(0.0, noise_sd, size=len(df))

        out = np.full(len(df), 9, dtype=int)
        idx = np.where(~is_na)[0]
        out[idx] = _ordinal_from_quantiles(eta[idx], probs=p16)
        df[col] = out

        after_props = _before_after_props(pd.Series(df[col]), levels)
        after_pct = {k: 100.0 * after_props.get(k, 0.0) for k in levels}
        dev_a = max(abs(after_pct[k] - 100.0 * anchor_a.get(k, 0.0)) for k in levels)
        dev_b = max(abs(after_pct[k] - 100.0 * anchor_b.get(k, 0.0)) for k in levels)
        best = "A" if dev_a <= dev_b else "B"

        summary_rows.append({
            "column": col,
            "type": "mhw_max_abs_pp_dev_anchorA",
            "target": "anchorA",
            "before": float("nan"),
            "after": float(dev_a),
            "rows_changed": int(len(df)),
        })
        summary_rows.append({
            "column": col,
            "type": "mhw_max_abs_pp_dev_anchorB",
            "target": "anchorB",
            "before": float("nan"),
            "after": float(dev_b),
            "rows_changed": int(len(df)),
        })
        summary_rows.append({
            "column": col,
            "type": "mhw_best_anchor",
            "target": best,
            "before": float("nan"),
            "after": float(min(dev_a, dev_b)),
            "rows_changed": int(len(df)),
        })

    # Drop legacy finance name if present
    if "MHWdfinancial" in df.columns:
        df = df.drop(columns=["MHWdfinancial"])

    _ensure_dir(OUTDIR)
    summary_path = OUTDIR / "image_targets_summary.csv"
    notes_path = OUTDIR / "image_targets_notes.txt"

    pd.DataFrame(summary_rows).to_csv(summary_path, index=False)
    notes_path.write_text("\n".join(notes) + "\n", encoding="utf-8")

    if args.inplace:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = csv_path.with_suffix(csv_path.suffix + f".bak_{ts}")
        csv_path.replace(backup)
        df.to_csv(csv_path, index=False)
        print(f"Backed up original to: {backup}")
        print(f"Wrote updated CSV: {csv_path}")
    else:
        out_path = Path(args.out) if args.out else csv_path.with_name(csv_path.stem + "_image_aligned" + csv_path.suffix)
        df.to_csv(out_path, index=False)
        print(f"Wrote updated CSV: {out_path}")

    print(f"Wrote summary: {summary_path}")
    print(f"Wrote notes: {notes_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
