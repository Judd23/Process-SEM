#!/usr/bin/env python3
"""
Generate realistic representative dataset for Process-SEM dissertation.

Distributions calibrated to:
1. CSU student demographics (equity-focused population)
2. Dual enrollment/early college research findings:
   - Singh, Lee, & Lindquist (2021): 31% depression, 26% anxiety
   - Weissbourd et al. (2023): 42% not belonging, 28% academic stress
   - Raufman et al. (2021): heightened risks for first-gen and students of color
   - Moreno et al. (2023): accelerated students 2x counseling seeking

Key design choices:
- FASt students (>=12 credits) show HIGHER emotional distress than non-FASt
- First-gen and underrepresented students show elevated distress
- Belonging items reflect the 42% disconnection rate
- Treatment-mediator relationships align with theoretical model
"""

import argparse
import numpy as np
import pandas as pd
from pathlib import Path


def generate_realistic_data(n: int = 3000, seed: int = 20251229) -> pd.DataFrame:
    """Generate a realistic dataset reflecting CSU and equity research."""
    rng = np.random.default_rng(seed)
    
    # =========================================================================
    # DEMOGRAPHICS (CSU-aligned, equity-focused)
    # =========================================================================
    
    # Race/ethnicity: CSU system is ~45% Hispanic, 22% White, 15% Asian, 5% Black, 13% Other
    race_probs = [0.48, 0.23, 0.16, 0.05, 0.08]  # Hispanic, White, Asian, Black, Other
    race_labels = ['Hispanic/Latino', 'White', 'Asian', 'Black/African American', 'Other/Multiracial/Unknown']
    re_all = rng.choice(race_labels, size=n, p=race_probs)
    
    # First-generation: ~50% at CSU (higher than national average)
    firstgen = rng.binomial(1, 0.50, size=n)
    
    # Pell-eligible: ~55% at CSU
    pell = rng.binomial(1, 0.55, size=n)
    
    # Sex: CSU is ~57% women
    sex_probs = [0.57, 0.43]
    sex = rng.choice(['Woman', 'Man'], size=n, p=sex_probs)
    
    # Living situation (first-year): On-campus, Off-campus, With family
    living_probs = [0.25, 0.30, 0.45]  # Many CSU students commute
    living_labels = ['On-campus (residence hall)', 'Off-campus (rent/apartment)', 'With family (commuting)']
    living18 = rng.choice(living_labels, size=n, p=living_probs)
    
    # Cohort (year): 0=2022, 1=2023
    cohort = rng.binomial(1, 0.5, size=n)
    
    # =========================================================================
    # TRANSFER CREDITS (dual enrollment exposure)
    # Aligned to PPIC Figure 4 distribution, weighted for 4-year CSU enrollees
    # 
    # Source bins: 0, 1-5.9, 6-11.9, 12-24.9, 25-49.9, 50+
    # Among CA HS grads, 4-year attendance rates increase with DC credits
    # CSU sample over-represents higher credit students vs. general population
    # =========================================================================
    
    # Target distribution for CSU incoming students (4-year enrollees):
    # - 0 credits: ~35% (lower than general pop since DC→4yr selection)
    # - 1-5.9: ~18%
    # - 6-11.9: ~20%
    # - 12-24.9: ~15% (FASt tier 1)
    # - 25-49.9: ~9% (FASt tier 2)
    # - 50+: ~3% (FASt tier 3, rare high achievers)
    # Total FASt (12+): ~27%
    
    credit_bins = rng.choice([0, 1, 2, 3, 4, 5], size=n, 
                              p=[0.35, 0.18, 0.20, 0.15, 0.09, 0.03])
    trnsfr_cr = np.zeros(n, dtype=float)
    
    # 0 credits
    trnsfr_cr[credit_bins == 0] = 0
    
    # 1-5.9 credits: uniform within range
    n_bin1 = (credit_bins == 1).sum()
    trnsfr_cr[credit_bins == 1] = rng.uniform(1, 5.9, size=n_bin1)
    
    # 6-11.9 credits: uniform within range
    n_bin2 = (credit_bins == 2).sum()
    trnsfr_cr[credit_bins == 2] = rng.uniform(6, 11.9, size=n_bin2)
    
    # 12-24.9 credits (FASt tier 1): slightly right-skewed
    n_bin3 = (credit_bins == 3).sum()
    trnsfr_cr[credit_bins == 3] = np.clip(rng.normal(16, 4, size=n_bin3), 12, 24.9)
    
    # 25-49.9 credits (FASt tier 2): centered around 32
    n_bin4 = (credit_bins == 4).sum()
    trnsfr_cr[credit_bins == 4] = np.clip(rng.normal(32, 7, size=n_bin4), 25, 49.9)
    
    # 50+ credits (FASt tier 3): centered around 55
    n_bin5 = (credit_bins == 5).sum()
    trnsfr_cr[credit_bins == 5] = np.clip(rng.normal(55, 8, size=n_bin5), 50, 80)
    
    # Round to integers for cleaner display
    trnsfr_cr = np.round(trnsfr_cr).astype(int)
    
    # Derived treatment variables
    x_FASt = (trnsfr_cr >= 12).astype(int)
    credit_dose = np.maximum(0, trnsfr_cr - 12) / 10.0  # pmax(0, trnsfr_cr - 12)/10
    
    # =========================================================================
    # BACKGROUND/COVARIATE VARIABLES
    # =========================================================================
    
    # High school grades (1-9 scale, skewed toward higher)
    # FASt students tend to have higher HS grades
    hgrades = np.zeros(n, dtype=int)
    hgrades[x_FASt == 1] = np.clip(rng.normal(7.5, 1.0, size=x_FASt.sum()).astype(int), 3, 9)
    hgrades[x_FASt == 0] = np.clip(rng.normal(6.5, 1.2, size=(1-x_FASt).sum()).astype(int), 3, 9)
    hgrades_c = hgrades - hgrades.mean()  # Mean-centered
    hgrades_raw = hgrades.astype(float)   # Keep raw for Cgrades generation
    
    # Parent education (continuous, centered later)
    bparented = rng.normal(3.5, 1.2, size=n)  # ~bachelor's degree on average
    bparented[firstgen == 1] = rng.normal(2.2, 0.8, size=firstgen.sum())  # first-gen: lower
    
    # AP/CL taken in high school
    hapcl = rng.binomial(1, 0.35, size=n)
    hapcl[x_FASt == 1] = rng.binomial(1, 0.65, size=x_FASt.sum())  # FASt more likely
    
    # Precalculus exposure
    hprecalc13 = rng.binomial(1, 0.25, size=n)
    hprecalc13[x_FASt == 1] = rng.binomial(1, 0.45, size=x_FASt.sum())
    
    # Academic challenge (continuous)
    hchallenge = rng.normal(3.0, 0.8, size=n)
    
    # Career support seeking
    cSFcareer = rng.normal(3.2, 0.9, size=n)
    
    # -------------------------------------------------------------------------
    # STEM MAJOR (StemMaj) - Binary, NOT in CFA model
    # Creates cross-construct correlations that introduce model misfit
    # STEM students: ~25% of CSU population, higher in FASt (more units = STEM pathway)
    # Correlates with: pgprobsolve (+), grades (+), MHWdacad (+), MHWdlonely (+), SEacademic (-)
    # -------------------------------------------------------------------------
    stem_latent = (
        0.25 * x_FASt +                    # FASt students more likely STEM
        0.20 * hgrades_c +                 # Higher HS grades → STEM
        0.15 * hprecalc13 +                # Precalc → STEM pathway
        rng.normal(0, 1, n)
    )
    StemMaj = (stem_latent > np.percentile(stem_latent, 75)).astype(int)  # ~25% STEM
    
    # =========================================================================
    # LATENT FACTOR GENERATION (with discriminant validity)
    # =========================================================================
    # 
    # PROBLEM SOLVED: Previous version used single risk_base for all constructs,
    # creating r ~ -0.66 between EmoDiss and QualEngag (too high, causes Heywood cases).
    #
    # SOLUTION: Generate SEPARATE latent factors with controlled correlations:
    # - latent_EmoDiss: Emotional distress (FASt has MED-HIGH effect: d ~ 0.30)
    # - latent_QualEngag: Quality of engagement (FASt has SMALL effect: d ~ 0.12)
    # - latent_DevAdj: Developmental adjustment (outcome)
    # 
    # Target correlations (realistic per NSSE/CCSSE norms):
    # - EmoDiss <-> QualEngag: r ~ -0.35 (moderate negative, spillover)
    # - EmoDiss <-> DevAdj: r ~ -0.45 (distress impairs adjustment)
    # - QualEngag <-> DevAdj: r ~ +0.40 (engagement supports adjustment)
    # - x_FASt -> EmoDiss: d ~ 0.30 (medium-high protective effect)
    # - x_FASt -> QualEngag: d ~ 0.12 (small positive effect)
    # =========================================================================
    
    # Base random components for each construct (uncorrelated)
    z_emo = rng.normal(0, 1, size=n)       # EmoDiss unique
    z_qual = rng.normal(0, 1, size=n)      # QualEngag unique  
    z_adj = rng.normal(0, 1, size=n)       # DevAdj (second-order) unique
    z_belong = rng.normal(0, 1, size=n)    # Belong unique (first-order)
    z_gains = rng.normal(0, 1, size=n)     # Gains unique (first-order)
    z_support = rng.normal(0, 1, size=n)   # SupportEnv unique (first-order)
    z_shared = rng.normal(0, 1, size=n)    # Shared variance component
    
    # URM indicator for equity effects
    urm = np.isin(re_all, ['Hispanic/Latino', 'Black/African American', 'Other/Multiracial/Unknown'])
    
    # ---------------------------------------------------------
    # EMOTIONAL DISTRESS LATENT (higher = more distress)
    # ---------------------------------------------------------
    # FASt: INCREASES distress (acceleration stress, younger age, imposter syndrome)
    # Per Moreno et al. (2023): 2x counseling seeking rate
    # Per researcher: 17-year-old at university = MORE stress than peers
    #
    # RD-STYLE PARAMETERIZATION:
    # r = trnsfr_cr - 12 (running variable centered at FASt threshold)
    # r_minus = min(r, 0) / 10 (slope BELOW cutoff)
    # r_plus = max(r, 0) / 10 (slope ABOVE cutoff)
    #
    # Updated effect sizes (INCREASED for clearer signal):
    # - Pre-cutoff slope: more credits -> more distress (moderate)
    # - Post-cutoff slope: diminishing returns above threshold
    # ---------------------------------------------------------
    r = trnsfr_cr - 12  # Running variable centered at threshold
    r_minus = np.minimum(r, 0) / 10.0  # Pre-cutoff (negative values for <12 credits)
    r_plus = np.maximum(r, 0) / 10.0   # Post-cutoff (positive values for >=12 credits)
    
    latent_EmoDiss = (
        0.70 * z_emo +           # Unique variance (70%, reduced slightly)
        0.25 * z_shared +        # Shared variance (25%)
        +0.35 * r_minus +        # Pre-cutoff: more credits -> MORE distress (STRONG)
        +0.18 * r_plus +         # Post-cutoff: continued effect, diminishing (MODERATE)
        0.20 * firstgen +        # First-gen MORE distress
        0.15 * urm +             # URM MORE distress  
        0.12 * pell              # Pell MORE distress
    )
    
    # ---------------------------------------------------------
    # QUALITY OF ENGAGEMENT LATENT (higher = better engagement)
    # ---------------------------------------------------------
    # FASt: DECREASES engagement due to developmental/social challenges
    # - Accelerated students miss freshman socialization experiences
    # - Enter as sophomores/juniors at 17-18, developmentally younger than peers
    # - Less time for relationships due to heavy courseloads
    # - Lack college-going competencies for navigating university systems
    # Research: Weissbourd et al. (2023), Raufman et al. (2021)
    #
    # RD-STYLE PARAMETERIZATION:
    # - Pre-cutoff: slight negative effect (early credits = less socialization)
    # - Post-cutoff: stronger negative (FASt students miss key socialization)
    # ---------------------------------------------------------
    latent_QualEngag = (
        0.75 * z_qual +          # Unique variance (75%)
        -0.20 * z_shared +       # Shared variance (20%, NEGATIVE = spillover from distress)
        -0.08 * r_minus +        # Pre-cutoff: slight negative (early credits)
        -0.20 * r_plus +         # Post-cutoff: FASt DECREASES engagement (STRONGER)
        -0.10 * firstgen +       # First-gen struggles with navigation
        -0.08 * urm +            # URM navigation challenges
        -0.05 * pell             # Pell financial stress
    )
    
    # ---------------------------------------------------------
    # DEVELOPMENTAL ADJUSTMENT LATENT (higher = better adjustment)
    # ---------------------------------------------------------
    # Direct effects from mediators + RD-style direct effects
    # c'_pre: small direct effect of credits pre-cutoff
    # c'_post: small direct effect of credits post-cutoff
    # ---------------------------------------------------------
    latent_DevAdj = (
        0.50 * z_adj +           # Unique variance (50%)
        -0.35 * latent_EmoDiss + # Distress IMPAIRS adjustment (b1)
        0.30 * latent_QualEngag + # Engagement SUPPORTS adjustment (b2)
        0.02 * r_minus +         # Small direct pre-cutoff effect (c'_pre)
        0.03 * r_plus +          # Small direct post-cutoff effect (c'_post)
        -0.08 * firstgen +       # First-gen adjustment challenges
        -0.05 * urm              # URM adjustment challenges
    )
    
    # ---------------------------------------------------------
    # FIRST-ORDER FACTORS FOR DEVADJ (with unique variance)
    # Each first-order factor = second-order loading + unique variance
    # This creates discriminant validity (correlations ~0.5-0.7, not 1.0)
    # ---------------------------------------------------------
    latent_Belong = 0.65 * latent_DevAdj + 0.76 * z_belong      # sqrt(1 - 0.65^2) = 0.76
    latent_Gains = 0.60 * latent_DevAdj + 0.80 * z_gains        # sqrt(1 - 0.60^2) = 0.80
    latent_SupportEnv = 0.55 * latent_DevAdj + 0.84 * z_support # sqrt(1 - 0.55^2) = 0.84
    # Satisf first-order factor - high loading on DevAdj (satisfaction is core to adjustment)
    z_satisf = rng.normal(0, 1, n)
    latent_Satisf = 0.70 * latent_DevAdj + 0.71 * z_satisf      # sqrt(1 - 0.70^2) = 0.71
    
    # Standardize latent factors for cleaner generation
    latent_EmoDiss = (latent_EmoDiss - latent_EmoDiss.mean()) / latent_EmoDiss.std()
    latent_QualEngag = (latent_QualEngag - latent_QualEngag.mean()) / latent_QualEngag.std()
    latent_DevAdj = (latent_DevAdj - latent_DevAdj.mean()) / latent_DevAdj.std()
    latent_Belong = (latent_Belong - latent_Belong.mean()) / latent_Belong.std()
    latent_Gains = (latent_Gains - latent_Gains.mean()) / latent_Gains.std()
    latent_SupportEnv = (latent_SupportEnv - latent_SupportEnv.mean()) / latent_SupportEnv.std()
    latent_Satisf = (latent_Satisf - latent_Satisf.mean()) / latent_Satisf.std()
    
    # Verify correlations are in target range
    print(f"Generated latent correlations:")
    print(f"  EmoDiss <-> QualEngag: r = {np.corrcoef(latent_EmoDiss, latent_QualEngag)[0,1]:.3f} (target: -0.35)")
    print(f"  EmoDiss <-> DevAdj:    r = {np.corrcoef(latent_EmoDiss, latent_DevAdj)[0,1]:.3f} (target: -0.45)")
    print(f"  QualEngag <-> DevAdj:  r = {np.corrcoef(latent_QualEngag, latent_DevAdj)[0,1]:.3f} (target: +0.40)")
    print(f"  x_FASt -> EmoDiss:     r = {np.corrcoef(x_FASt, latent_EmoDiss)[0,1]:.3f} (target: -0.15 to -0.20)")
    print(f"  x_FASt -> QualEngag:   r = {np.corrcoef(x_FASt, latent_QualEngag)[0,1]:.3f} (target: +0.06 to +0.10)")
    print(f"First-order factor correlations (discriminant validity):")
    print(f"  Belong <-> Gains:      r = {np.corrcoef(latent_Belong, latent_Gains)[0,1]:.3f} (should be 0.3-0.6)")
    print(f"  Belong <-> SupportEnv: r = {np.corrcoef(latent_Belong, latent_SupportEnv)[0,1]:.3f} (should be 0.3-0.6)")
    print(f"  Gains <-> SupportEnv:  r = {np.corrcoef(latent_Gains, latent_SupportEnv)[0,1]:.3f} (should be 0.3-0.6)")
    print(f"  Satisf <-> Belong:     r = {np.corrcoef(latent_Satisf, latent_Belong)[0,1]:.3f} (should be 0.4-0.7)")
    print(f"  Satisf <-> DevAdj:     r = {np.corrcoef(latent_Satisf, latent_DevAdj)[0,1]:.3f} (should be 0.65-0.75)")
    
    # =========================================================================
    # EMOTIONAL DISTRESS (EmoDiss) - MHW "Difficulty" items
    # Generated from latent_EmoDiss (higher latent = MORE difficulty)
    # 
    # NSSE MHW Codebook: 6-POINT SCALE
    # 1 = Not at all difficult
    # 2, 3, 4, 5 = intermediate
    # 6 = Very difficult
    # 9 = Not applicable (treated as missing - excluded here)
    #
    # Equity-centered distributions:
    # - FASt students experience MORE difficulty (acceleration stress)
    # - First-gen/URM students experience MORE difficulty
    # - Per Singh, Lee & Lindquist (2021): 31% depression, 26% anxiety
    # - Per Moreno et al. (2023): accelerated students 2x counseling seeking
    # =========================================================================
    
    def generate_mhw_item(latent_factor, stem_maj, base_mean, loading, stem_effect, rng):
        """
        Generate 6-point MHW difficulty item from latent EmoDiss factor.
        
        Scale: 1 (Not at all difficult) to 6 (Very difficult)
        Higher latent = higher difficulty scores
        stem_effect: STEM majors report MORE academic/loneliness difficulty
        
        Distribution targets (equity-centered):
        - ~15% low difficulty (1-2)
        - ~50% moderate difficulty (3-4)
        - ~35% high difficulty (5-6)
        """
        item_latent = (base_mean + 
                       loading * latent_factor + 
                       stem_effect * stem_maj +  # STEM major effect
                       rng.normal(0, 0.8, size=len(latent_factor)))
        # Map continuous latent to 6-point ordinal with realistic thresholds
        # Equity-centered: right-skewed toward difficulty
        item = np.ones(len(latent_factor), dtype=int)
        item[item_latent > 1.8] = 2  # ~15% at 1
        item[item_latent > 2.4] = 3  # ~20% at 2
        item[item_latent > 3.0] = 4  # ~25% at 3
        item[item_latent > 3.6] = 5  # ~22% at 4
        item[item_latent > 4.2] = 6  # ~18% at 5-6
        return item
    
    # MHW difficulty items from latent_EmoDiss (loadings ~ 0.55-0.65)
    # StemMaj effects: STEM students report MORE difficulty on academic-pressure items
    # Direction: StemMaj=1 → HIGHER MHWd scores (more difficulty) → correlated residuals CFA can detect
    MHWdacad = generate_mhw_item(latent_EmoDiss, StemMaj, 3.2, 0.55, 0.30, rng)      # Academic difficulties (STEM +++)
    MHWdlonely = generate_mhw_item(latent_EmoDiss, StemMaj, 2.9, 0.50, 0.0, rng)     # Loneliness (no STEM effect)
    MHWdmental = generate_mhw_item(latent_EmoDiss, StemMaj, 3.1, 0.60, 0.0, rng)     # Mental/emotional health
    MHWdexhaust = generate_mhw_item(latent_EmoDiss, StemMaj, 3.4, 0.65, 0.25, rng)   # Exhaustion (STEM ++)
    MHWdsleep = generate_mhw_item(latent_EmoDiss, StemMaj, 3.3, 0.60, 0.20, rng)     # Sleep difficulties (STEM +)
    MHWdfinancial = generate_mhw_item(latent_EmoDiss, StemMaj, 3.0, 0.55, 0.0, rng)  # Financial stress (no STEM)
    
    # =========================================================================
    # BELONGING (SB items) - Part of DevAdj
    # Generated from latent_DevAdj (higher latent = HIGHER belonging)
    # Scale: 1-4 (1=Strongly disagree, 4=Strongly agree)
    # =========================================================================
    
    def generate_belonging_item(latent_factor, base_mean, loading, rng):
        """Generate belonging item from latent DevAdj factor."""
        item_latent = base_mean + loading * latent_factor + rng.normal(0, 0.5, size=len(latent_factor))
        probs = 1 / (1 + np.exp(-(item_latent - 2.5)))
        item = np.ones(len(latent_factor), dtype=int)
        item[probs > 0.25] = 2
        item[probs > 0.50] = 3
        item[probs > 0.75] = 4
        return item
    
    # SB items from latent_Belong (NOT DevAdj - proper first-order factor)
    sbmyself = generate_belonging_item(latent_Belong, 2.9, 0.55, rng)
    sbvalued = generate_belonging_item(latent_Belong, 2.85, 0.60, rng)
    sbcommunity = generate_belonging_item(latent_Belong, 2.5, 0.65, rng)
    
    # =========================================================================
    # QUALITY OF ENGAGEMENT (QI items)
    # Generated from latent_QualEngag (higher latent = HIGHER quality)
    # Scale: 1-7 (1=Poor, 7=Excellent)
    # NOTE: Belonging influences QI ratings (realistic self-report halo effect)
    # =========================================================================
    
    def generate_qi_item(latent_factor, latent_belong, stem_maj, base_mean, loading, belong_effect, stem_effect, rng):
        """Generate QI item from latent QualEngag factor with belonging halo and STEM buffering.
        
        NSSE QI items: 1-7 scale (1=Poor, 7=Excellent)
        Typical NSSE: Mean ~4.5-5.5, slight positive skew, SD ~1.3-1.5
        Students who feel they belong rate interactions higher (method effect).
        STEM majors reach out MORE → higher QI scores (buffering effect).
        """
        item_latent = (base_mean + 
                       loading * latent_factor + 
                       belong_effect * latent_belong +  # Belonging halo effect
                       stem_effect * stem_maj +         # STEM buffering: more interaction-seeking
                       rng.normal(0, 0.95, size=len(latent_factor)))
        item = np.clip(np.round(item_latent).astype(int), 1, 7)
        return item
    
    # QI items from latent_QualEngag with belonging halo + STEM buffering effects
    # NSSE benchmarks: QIstudent highest (~5.0), QIadmin lowest (~4.2)
    # STEM majors: HIGHER QI scores — seek out faculty/advisor help more (buffers distress)
    # Creates correlated residuals CFA can detect
    QIstudent = generate_qi_item(latent_QualEngag, latent_Belong, StemMaj, 5.0, 0.90, 0.15, 0.10, rng)   # STEM + (peers)
    QIadvisor = generate_qi_item(latent_QualEngag, latent_Belong, StemMaj, 4.6, 0.95, 0.12, 0.25, rng)   # STEM ++ (advising)
    QIfaculty = generate_qi_item(latent_QualEngag, latent_Belong, StemMaj, 4.8, 0.90, 0.18, 0.30, rng)   # STEM +++ (faculty office hrs)
    QIstaff = generate_qi_item(latent_QualEngag, latent_Belong, StemMaj, 4.5, 0.95, 0.10, 0.15, rng)     # STEM + (tutoring etc)
    QIadmin = generate_qi_item(latent_QualEngag, latent_Belong, StemMaj, 4.2, 1.00, 0.08, 0.05, rng)     # STEM ~ (admin less relevant)
    
    # =========================================================================
    # DEVELOPMENTAL ADJUSTMENT OUTCOMES (from latent_DevAdj)
    # =========================================================================
    
    # -------------------------------------------------------------------------
    # COLLEGE GRADES (Cgrades) - NSSE item, NOT in CFA model
    # Creates realistic model misfit by correlating with Gains items
    # NSSE scale: 1=C- or lower, 2=C, 3=C+, 4=B-, 5=B, 6=B+, 7=A-, 8=A
    # Typical distribution: right-skewed, mean ~5.5-6.0 (B to B+)
    # -------------------------------------------------------------------------
    # Cgrades shares variance with latent_Gains (r ~ 0.25-0.35) and hgrades
    # This creates correlated residuals in Gains items → imperfect CFA fit
    latent_grades = (
        0.30 * latent_Gains +           # Perceived gains correlate with grades
        0.25 * hgrades_raw +            # HS grades predict college grades
        0.15 * latent_DevAdj +          # General adjustment helps grades
        -0.10 * latent_EmoDiss +        # Distress hurts grades
        0.10 * StemMaj +                # STEM majors slightly higher grades
        0.65 * rng.normal(0, 1, n)      # Unique variance
    )
    latent_grades = (latent_grades - latent_grades.mean()) / latent_grades.std()
    
    # Convert to 1-8 scale with realistic distribution
    # ~5% C- or below, ~10% C/C+, ~25% B-/B, ~35% B+/A-, ~25% A
    Cgrades = np.ones(n, dtype=int)
    grade_probs = 1 / (1 + np.exp(-(latent_grades + 0.3) * 1.2))
    Cgrades[grade_probs > 0.05] = 2   # C
    Cgrades[grade_probs > 0.10] = 3   # C+
    Cgrades[grade_probs > 0.20] = 4   # B-
    Cgrades[grade_probs > 0.35] = 5   # B
    Cgrades[grade_probs > 0.55] = 6   # B+
    Cgrades[grade_probs > 0.75] = 7   # A-
    Cgrades[grade_probs > 0.90] = 8   # A
    
    # Gains (PG items): 1-4 scale from latent_Gains
    # NOW with Cgrades and StemMaj influence → creates correlated errors
    def generate_gains_item(latent_factor, cgrades, stem_maj, base_mean, loading, grade_effect, stem_effect, rng):
        """Generate gains item with grade and STEM-related correlated errors."""
        item_latent = (base_mean + 
                       loading * latent_factor + 
                       grade_effect * (cgrades - 5.5) / 2.0 +  # Grades influence perceived gains
                       stem_effect * stem_maj +                 # STEM major effect
                       rng.normal(0, 0.55, size=len(latent_factor)))
        probs = 1 / (1 + np.exp(-(item_latent - 2.3)))
        item = np.ones(len(latent_factor), dtype=int)
        item[probs > 0.22] = 2
        item[probs > 0.52] = 3
        item[probs > 0.82] = 4
        return item
    
    # PG items from latent_Gains with DIFFERENTIAL grade effects (creates detectable model misfit)
    # Cgrades: STRONG effect on pgprobsolve/pganalyze (analytical skills), WEAK on others
    # This creates correlated residuals that CFA can detect via modification indices
    # StemMaj: pgprobsolve HIGHER for STEM (+0.20, emphasis on problem-solving)
    pgthink = generate_gains_item(latent_Gains, Cgrades, StemMaj, 2.8, 0.40, 0.02, 0.0, rng)      # Weak grade effect
    pganalyze = generate_gains_item(latent_Gains, Cgrades, StemMaj, 2.8, 0.38, 0.35, 0.0, rng)   # STRONG grade effect
    pgwork = generate_gains_item(latent_Gains, Cgrades, StemMaj, 2.75, 0.42, 0.02, 0.0, rng)     # Weak grade effect
    pgvalues = generate_gains_item(latent_Gains, Cgrades, StemMaj, 2.7, 0.45, 0.02, 0.0, rng)    # Weak grade effect
    pgprobsolve = generate_gains_item(latent_Gains, Cgrades, StemMaj, 2.75, 0.40, 0.35, 0.20, rng)  # STRONG grade + STEM
    
    # Support Environment (SE items): 1-4 scale from latent_SupportEnv
    def generate_se_item(latent_factor, stem_maj, base_mean, loading, stem_effect, rng):
        """Generate SE item with optional StemMaj effect."""
        item_latent = (base_mean + 
                       loading * latent_factor + 
                       stem_effect * stem_maj +
                       rng.normal(0, 0.5, size=len(latent_factor)))
        probs = 1 / (1 + np.exp(-(item_latent - 2.4)))
        item = np.ones(len(latent_factor), dtype=int)
        item[probs > 0.22] = 2
        item[probs > 0.52] = 3
        item[probs > 0.82] = 4
        return item
    
    # SE items from latent_SupportEnv
    # StemMaj: NO direct effect on SupportEnv items (STEM effect goes through EmoDiss, not DevAdj)
    # This ensures StemMaj → DevAdj is NOT directly negative when grades are controlled
    SEwellness = generate_se_item(latent_SupportEnv, StemMaj, 2.65, 0.48, 0.0, rng)
    SEnonacad = generate_se_item(latent_SupportEnv, StemMaj, 2.55, 0.52, 0.0, rng)
    SEactivities = generate_se_item(latent_SupportEnv, StemMaj, 2.50, 0.55, 0.0, rng)
    SEacademic = generate_se_item(latent_SupportEnv, StemMaj, 2.85, 0.42, 0.0, rng)   # No STEM effect
    SEdiverse = generate_se_item(latent_SupportEnv, StemMaj, 2.70, 0.45, 0.0, rng)
    
    # Satisfaction items load on latent_Satisf (first-order factor)
    # NSSE Overall Satisfaction: 1-4 scale
    # 1=Poor, 2=Fair, 3=Good, 4=Excellent
    # Typical NSSE: ~70-75% Good/Excellent, Mean ~3.1-3.3, SD ~0.7-0.8
    # NOTE: Cgrades influences satisfaction (realistic self-report method effect)
    def generate_satisf_item(latent_factor, cgrades, base_mean, loading, grade_effect, rng):
        """Generate satisfaction item with NSSE-aligned distribution and grade effect."""
        item_latent = (base_mean + 
                       loading * latent_factor + 
                       grade_effect * (cgrades - 5.5) / 2.0 +  # Grades influence satisfaction
                       rng.normal(0, 0.55, size=len(latent_factor)))
        # Thresholds aligned to NSSE: ~5% Poor, ~20% Fair, ~50% Good, ~25% Excellent
        probs = 1 / (1 + np.exp(-(item_latent - 2.8) * 1.5))
        item = np.ones(len(latent_factor), dtype=int)
        item[probs > 0.05] = 2   # ~5% Poor
        item[probs > 0.25] = 3   # ~20% Fair
        item[probs > 0.75] = 4   # ~25% Excellent (top 25%)
        return item
    
    # Satisf items from latent_Satisf with grade effects (creates model misfit)
    evalexp = generate_satisf_item(latent_Satisf, Cgrades, 3.1, 0.75, 0.12, rng)
    sameinst = generate_satisf_item(latent_Satisf, Cgrades, 3.2, 0.70, 0.10, rng)
    
    # Additional SF items (from latent_DevAdj with smaller loadings, no StemMaj effect)
    SFcareer = generate_se_item(latent_DevAdj, StemMaj, 2.75, 0.38, 0.0, rng)
    SFotherwork = generate_se_item(latent_DevAdj, StemMaj, 2.65, 0.40, 0.0, rng)
    SFdiscuss = generate_se_item(latent_DevAdj, StemMaj, 2.70, 0.38, 0.0, rng)
    SFperform = generate_se_item(latent_DevAdj, StemMaj, 2.80, 0.35, 0.0, rng)
    
    # =========================================================================
    # CENTER CONTINUOUS VARIABLES
    # =========================================================================
    
    hgrades_c = hgrades - hgrades.mean()
    bparented_c = bparented - bparented.mean()
    hchallenge_c = hchallenge - hchallenge.mean()
    cSFcareer_c = cSFcareer - cSFcareer.mean()
    credit_dose_c = credit_dose - credit_dose.mean()
    XZ_c = x_FASt * credit_dose_c
    
    # =========================================================================
    # ASSEMBLE DATAFRAME
    # =========================================================================
    
    df = pd.DataFrame({
        # Demographics
        'cohort': cohort,
        'hgrades': hgrades,
        'hgrades_c': hgrades_c,
        'Cgrades': Cgrades,  # College grades (NSSE) - NOT in CFA model
        'bparented': bparented,
        'bparented_c': bparented_c,
        'pell': pell,
        'hapcl': hapcl,
        'hprecalc13': hprecalc13,
        'hchallenge': hchallenge,
        'hchallenge_c': hchallenge_c,
        'cSFcareer': cSFcareer,
        'cSFcareer_c': cSFcareer_c,
        'firstgen': firstgen,
        're_all': re_all,
        'living18': living18,
        'sex': sex,
        
        # Non-model variables (for realistic misfit)
        'Cgrades': Cgrades,
        'StemMaj': StemMaj,
        
        # Treatment
        'trnsfr_cr': trnsfr_cr,
        'x_FASt': x_FASt,
        'credit_dose': credit_dose,
        'credit_dose_c': credit_dose_c,
        'XZ_c': XZ_c,
        
        # RD running variables (piecewise linear parameterization)
        'r': r,               # Running variable: trnsfr_cr - 12
        'r_minus': r_minus,   # Pre-cutoff: min(r, 0) / 10
        'r_plus': r_plus,     # Post-cutoff: max(r, 0) / 10
        
        # NOTE: Latent factors (EmoDiss, QualEngag, DevAdj) are NOT included as columns
        # because they conflict with lavaan latent variable names. They are estimated from indicators.
        
        # Belonging items
        'sbmyself': sbmyself,
        'sbvalued': sbvalued,
        'sbcommunity': sbcommunity,
        
        # Gains items
        'pgthink': pgthink,
        'pganalyze': pganalyze,
        'pgwork': pgwork,
        'pgvalues': pgvalues,
        'pgprobsolve': pgprobsolve,
        
        # Support environment items
        'SEwellness': SEwellness,
        'SEnonacad': SEnonacad,
        'SEactivities': SEactivities,
        'SEacademic': SEacademic,
        'SEdiverse': SEdiverse,
        
        # Satisfaction items
        'evalexp': evalexp,
        'sameinst': sameinst,
        
        # Emotional distress items (MHW)
        'MHWdacad': MHWdacad,
        'MHWdlonely': MHWdlonely,
        'MHWdmental': MHWdmental,
        'MHWdexhaust': MHWdexhaust,
        'MHWdsleep': MHWdsleep,
        'MHWdfinancial': MHWdfinancial,
        
        # Quality of interaction items
        'QIstudent': QIstudent,
        'QIadvisor': QIadvisor,
        'QIfaculty': QIfaculty,
        'QIstaff': QIstaff,
        'QIadmin': QIadmin,
        
        # Additional SF items
        'SFcareer': SFcareer,
        'SFotherwork': SFotherwork,
        'SFdiscuss': SFdiscuss,
        'SFperform': SFperform,
    })
    
    return df


def print_distribution_report(df: pd.DataFrame) -> None:
    """Print summary statistics to verify alignment with literature."""
    print("=" * 70)
    print("DISTRIBUTION REPORT - Calibrated to Equity Research")
    print("=" * 70)
    
    print("\n=== DEMOGRAPHICS ===")
    print(f"N = {len(df)}")
    print(f"\nRace/Ethnicity:")
    print(df['re_all'].value_counts(normalize=True).round(3))
    print(f"\nFirst-gen: {df['firstgen'].mean()*100:.1f}%")
    print(f"Pell-eligible: {df['pell'].mean()*100:.1f}%")
    print(f"Women: {(df['sex']=='Woman').mean()*100:.1f}%")
    
    print("\n=== TREATMENT (FASt STATUS) ===")
    print(f"FASt (>=12 credits): {df['x_FASt'].mean()*100:.1f}%")
    print(f"Transfer credits: mean={df['trnsfr_cr'].mean():.1f}, median={df['trnsfr_cr'].median():.0f}")
    
    print("\n=== EMOTIONAL DISTRESS (Target: ~31% high, Singh et al. 2021) ===")
    mhw_cols = ['MHWdacad', 'MHWdlonely', 'MHWdmental', 'MHWdexhaust', 'MHWdsleep', 'MHWdfinancial']
    for col in mhw_cols:
        pct_high = (df[col] >= 3).mean() * 100  # 3 or 4 on 1-4 scale = elevated
        print(f"  {col}: mean={df[col].mean():.2f}, % elevated (>=3)={pct_high:.1f}%")
    
    print("\n=== BELONGING (Target: ~42% low, Weissbourd et al. 2023) ===")
    sb_cols = ['sbmyself', 'sbvalued', 'sbcommunity']
    for col in sb_cols:
        pct_low = (df[col] <= 2).mean() * 100  # 1 or 2 on 1-4 scale = low belonging
        print(f"  {col}: mean={df[col].mean():.2f}, % low (<=2)={pct_low:.1f}%")
    
    print("\n=== EQUITY GAPS (Raufman et al. 2021) ===")
    
    # FASt vs non-FASt
    fast = df[df['x_FASt'] == 1]
    nonfast = df[df['x_FASt'] == 0]
    print(f"\nFASt vs Non-FASt (accelerated students at higher risk):")
    print(f"  MHWdacad: FASt={fast['MHWdacad'].mean():.2f} vs Non-FASt={nonfast['MHWdacad'].mean():.2f}")
    print(f"  MHWdmental: FASt={fast['MHWdmental'].mean():.2f} vs Non-FASt={nonfast['MHWdmental'].mean():.2f}")
    print(f"  sbcommunity: FASt={fast['sbcommunity'].mean():.2f} vs Non-FASt={nonfast['sbcommunity'].mean():.2f}")
    
    # First-gen vs continuing-gen
    fg = df[df['firstgen'] == 1]
    cg = df[df['firstgen'] == 0]
    print(f"\nFirst-gen vs Continuing-gen:")
    print(f"  MHWdacad: First-gen={fg['MHWdacad'].mean():.2f} vs Cont-gen={cg['MHWdacad'].mean():.2f}")
    print(f"  MHWdlonely: First-gen={fg['MHWdlonely'].mean():.2f} vs Cont-gen={cg['MHWdlonely'].mean():.2f}")
    print(f"  sbcommunity: First-gen={fg['sbcommunity'].mean():.2f} vs Cont-gen={cg['sbcommunity'].mean():.2f}")
    
    # URM vs non-URM
    urm_mask = df['re_all'].isin(['Hispanic/Latino', 'Black/African American', 'Other/Multiracial/Unknown'])
    urm = df[urm_mask]
    non_urm = df[~urm_mask]
    print(f"\nURM vs Non-URM students:")
    print(f"  MHWdacad: URM={urm['MHWdacad'].mean():.2f} vs Non-URM={non_urm['MHWdacad'].mean():.2f}")
    print(f"  sbcommunity: URM={urm['sbcommunity'].mean():.2f} vs Non-URM={non_urm['sbcommunity'].mean():.2f}")
    
    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Generate realistic representative dataset for Process-SEM"
    )
    parser.add_argument("--n", type=int, default=3000, help="Number of observations")
    parser.add_argument("--seed", type=int, default=20251229, help="Random seed")
    parser.add_argument("--out", type=Path, default=Path("1_Dataset/rep_data.csv"), help="Output path")
    parser.add_argument("--report", action="store_true", help="Print distribution report")
    
    args = parser.parse_args()
    
    df = generate_realistic_data(n=args.n, seed=args.seed)
    
    if args.report:
        print_distribution_report(df)
    
    # Backup existing file
    if args.out.exists():
        backup_path = args.out.with_suffix(f".csv.bak_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}")
        args.out.rename(backup_path)
        print(f"Backed up existing file to: {backup_path}")
    
    df.to_csv(args.out, index=False)
    print(f"Wrote {len(df)} rows to: {args.out}")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
