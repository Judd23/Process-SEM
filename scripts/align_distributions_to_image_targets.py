#!/usr/bin/env python3
"""Align specific item distributions in rep_data.csv to targets from the provided image.

Targets (from user-supplied table):

SB items (Likert 1-5 in this dataset):
- sbmyself: Agree/Strongly Agree ~90%
- sbvalued: Agree/Strongly Agree ~81%

Interpretation used here:
- Agree/Strongly Agree := values >= 4
- Other := values <= 3

MHW difficulty items (coded 1-6 in this dataset):
Target table is 4 categories:
  1 Not at all difficult
  2 Slightly difficult
  3 Moderately difficult
  4 Very/Extremely difficult

Interpretation used here:
- Collapse original 1-6 responses to 1-4 by mapping 1->1, 2->2, 3->3, 4/5/6->4
- Then adjust marginal counts to match target percentages.

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


def _collapse_mhw_to_4(s: pd.Series) -> pd.Series:
    s2 = s.astype(int).copy()
    # Map 1->1, 2->2, 3->3, 4/5/6->4
    s2 = s2.clip(lower=1)
    s2 = s2.where(s2 <= 4, 4)
    return s2


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

    mhw_targets: Dict[str, Dict[int, float]] = {
        "MHWdacad": {1: 0.18, 2: 0.34, 3: 0.28, 4: 0.20},
        "MHWdlonely": {1: 0.30, 2: 0.33, 3: 0.22, 4: 0.15},
        "MHWdmental": {1: 0.22, 2: 0.32, 3: 0.26, 4: 0.20},
        "MHWdexhaust": {1: 0.12, 2: 0.28, 3: 0.33, 4: 0.27},
        "MHWdsleep": {1: 0.10, 2: 0.26, 3: 0.34, 4: 0.30},
        "MHWdfinancial": {1: 0.20, 2: 0.30, 3: 0.28, 4: 0.22},
    }

    notes: List[str] = []
    notes.append(f"Input: {csv_path}")
    notes.append(f"Rows: {len(df)}")
    notes.append("SB agree definition: value >= 4")
    notes.append("MHW collapse: 1->1, 2->2, 3->3, 4/5/6->4")

    summary_rows: List[Dict[str, object]] = []

    # Adjust SB items
    for col, targ in sb_targets.items():
        if col not in df.columns:
            notes.append(f"SKIP: missing column {col}")
            continue
        before = df[col].astype(int)
        before_agree = float((before >= 4).mean())
        after, changed = _adjust_agree_threshold(before, target_agree=targ, agree_threshold=4, rng=rng)
        after_agree = float((after >= 4).mean())
        df[col] = after
        summary_rows.append({
            "column": col,
            "type": "agree>=4",
            "target": targ,
            "before": before_agree,
            "after": after_agree,
            "rows_changed": changed,
        })

    # Adjust MHW items
    for col, probs in mhw_targets.items():
        if col not in df.columns:
            notes.append(f"SKIP: missing column {col}")
            continue
        before_raw = df[col].astype(int)
        before = _collapse_mhw_to_4(before_raw)
        # Apply collapse first so we can hit 4-category targets
        df[col] = before

        levels = [1, 2, 3, 4]
        before_props = _before_after_props(before, levels)
        after, changed = _adjust_discrete_min_change(before, probs, rng=rng)
        after_props = _before_after_props(after, levels)
        df[col] = after

        for lvl in levels:
            summary_rows.append({
                "column": col,
                "type": f"prop[{lvl}]",
                "target": probs[lvl],
                "before": before_props[lvl],
                "after": after_props[lvl],
                "rows_changed": changed,
            })

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
