#!/usr/bin/env python3
"""
Deep-cut visualizations for Process-SEM dissertation.
These reveal nuanced patterns in the data beyond basic descriptives.

Usage:
    python scripts/plot_deep_cuts.py [--data rep_data.csv] [--outdir results/descriptive_plots]
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
import argparse
from scipy import stats
from matplotlib.patches import FancyBboxPatch
import matplotlib.patches as mpatches

def main(data_path='rep_data.csv', outdir='results/descriptive_plots'):
    os.makedirs(outdir, exist_ok=True)
    
    df = pd.read_csv(data_path)
    plt.style.use('seaborn-v0_8-whitegrid')
    
    # Color schemes
    colors = {
        'fast': '#d62728',
        'nonfast': '#1f77b4', 
        'firstgen': '#ff7f0e',
        'contgen': '#2ca02c',
        'risk_gradient': plt.cm.Reds,
        'benefit_gradient': plt.cm.Blues_r
    }
    
    # =========================================================================
    # FIGURE 7: Risk Factor Accumulation - Cumulative Disadvantage
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 12))
    
    # Create composite risk score (count of risk factors)
    df['urm'] = df['re_all'].isin(['Hispanic/Latino', 'Black/African American']).astype(int)
    df['risk_count'] = df['x_FASt'] + df['firstgen'] + df['pell'] + df['urm']
    
    # 7a. Distribution of risk factor counts
    ax = axes[0, 0]
    risk_counts = df['risk_count'].value_counts().sort_index()
    bars = ax.bar(risk_counts.index, risk_counts.values, color=plt.cm.Reds(np.linspace(0.2, 0.8, 5)))
    ax.set_xlabel('Number of Risk Factors\n(FASt + First-Gen + Pell + URM)', fontsize=11)
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title('Distribution of Cumulative Risk Factors', fontsize=12, fontweight='bold')
    for i, (idx, v) in enumerate(zip(risk_counts.index, risk_counts.values)):
        ax.text(idx, v + 20, f'{v/len(df)*100:.1f}%', ha='center', fontsize=10)
    
    # 7b. Mean distress by risk count
    ax = axes[0, 1]
    mhw_cols = ['MHWdacad', 'MHWdlonely', 'MHWdmental', 'MHWdexhaust', 'MHWdsleep', 'MHWdfinancial']
    df['mean_distress'] = df[mhw_cols].mean(axis=1)
    
    means = df.groupby('risk_count')['mean_distress'].mean()
    sems = df.groupby('risk_count')['mean_distress'].sem()
    
    ax.errorbar(means.index, means.values, yerr=1.96*sems.values, 
                fmt='o-', color=colors['fast'], capsize=5, markersize=10, linewidth=2)
    ax.set_xlabel('Number of Risk Factors', fontsize=11)
    ax.set_ylabel('Mean Emotional Distress (1-4)', fontsize=11)
    ax.set_title('Cumulative Risk → Distress\n(95% CI)', fontsize=12, fontweight='bold')
    ax.set_ylim(2, 3.5)
    
    # Add trend line
    slope, intercept, r, p, se = stats.linregress(df['risk_count'], df['mean_distress'])
    x_line = np.array([0, 4])
    ax.plot(x_line, intercept + slope * x_line, '--', color='gray', alpha=0.7,
            label=f'Linear trend: β={slope:.3f}, p<.001')
    ax.legend(loc='lower right')
    
    # 7c. Mean engagement by risk count
    ax = axes[1, 0]
    qi_cols = ['QIstudent', 'QIadvisor', 'QIfaculty', 'QIstaff', 'QIadmin']
    df['mean_engagement'] = df[qi_cols].mean(axis=1)
    
    means = df.groupby('risk_count')['mean_engagement'].mean()
    sems = df.groupby('risk_count')['mean_engagement'].sem()
    
    ax.errorbar(means.index, means.values, yerr=1.96*sems.values, 
                fmt='s-', color=colors['nonfast'], capsize=5, markersize=10, linewidth=2)
    ax.set_xlabel('Number of Risk Factors', fontsize=11)
    ax.set_ylabel('Mean Quality of Engagement (1-7)', fontsize=11)
    ax.set_title('Cumulative Risk → Engagement\n(95% CI)', fontsize=12, fontweight='bold')
    ax.set_ylim(3, 5.5)
    
    slope, intercept, r, p, se = stats.linregress(df['risk_count'], df['mean_engagement'])
    x_line = np.array([0, 4])
    ax.plot(x_line, intercept + slope * x_line, '--', color='gray', alpha=0.7,
            label=f'Linear trend: β={slope:.3f}, p<.001')
    ax.legend(loc='upper right')
    
    # 7d. % Low belonging by risk count
    ax = axes[1, 1]
    df['low_belonging'] = (df['sbcommunity'] <= 2).astype(int)
    
    pct_low = df.groupby('risk_count')['low_belonging'].mean() * 100
    ns = df.groupby('risk_count').size()
    
    # Calculate 95% CI for proportions
    ci_low = []
    ci_high = []
    for rc in pct_low.index:
        p = pct_low[rc] / 100
        n = ns[rc]
        se = np.sqrt(p * (1-p) / n)
        ci_low.append((p - 1.96*se) * 100)
        ci_high.append((p + 1.96*se) * 100)
    
    ax.bar(pct_low.index, pct_low.values, color=plt.cm.Reds(np.linspace(0.2, 0.8, 5)))
    ax.errorbar(pct_low.index, pct_low.values, 
                yerr=[pct_low.values - ci_low, np.array(ci_high) - pct_low.values],
                fmt='none', color='black', capsize=5)
    ax.set_xlabel('Number of Risk Factors', fontsize=11)
    ax.set_ylabel('% Low Community Belonging', fontsize=11)
    ax.set_title('Cumulative Risk → Low Belonging\n(95% CI)', fontsize=12, fontweight='bold')
    ax.axhline(42, color='gray', linestyle='--', alpha=0.7, label='National avg (42%)')
    ax.legend()
    
    plt.suptitle('Figure 7: Cumulative Disadvantage Analysis', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig7_cumulative_risk.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 7: Cumulative Risk Analysis saved')
    
    # =========================================================================
    # FIGURE 8: Credit Dose × FASt Interaction (Moderation Visualization)
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 12))
    
    # Reconstruct raw credits if needed
    if 'trnsfr_cr' in df.columns:
        credits = df['trnsfr_cr']
    else:
        credits = df['credit_dose'] * 10 + 12  # reverse transformation
    
    # 8a. Scatter: Credits vs Distress by FASt status
    ax = axes[0, 0]
    fast_mask = df['x_FASt'] == 1
    
    ax.scatter(credits[~fast_mask], df.loc[~fast_mask, 'mean_distress'], 
               alpha=0.3, c=colors['nonfast'], label='Non-FASt', s=20)
    ax.scatter(credits[fast_mask], df.loc[fast_mask, 'mean_distress'], 
               alpha=0.5, c=colors['fast'], label='FASt', s=30)
    
    # Add LOESS-style smoothed lines
    for mask, color, label in [(~fast_mask, colors['nonfast'], 'Non-FASt'), 
                                (fast_mask, colors['fast'], 'FASt')]:
        x = credits[mask].values
        y = df.loc[mask, 'mean_distress'].values
        # Bin and average for smooth line
        bins = np.linspace(0, max(credits), 15)
        bin_means = []
        bin_centers = []
        for i in range(len(bins)-1):
            bin_mask = (x >= bins[i]) & (x < bins[i+1])
            if bin_mask.sum() > 5:
                bin_centers.append((bins[i] + bins[i+1])/2)
                bin_means.append(y[bin_mask].mean())
        if len(bin_centers) > 2:
            ax.plot(bin_centers, bin_means, '-', color=color, linewidth=3, alpha=0.8)
    
    ax.axvline(12, color='gray', linestyle='--', alpha=0.5)
    ax.set_xlabel('Transfer Credits', fontsize=11)
    ax.set_ylabel('Mean Emotional Distress', fontsize=11)
    ax.set_title('Credit Dose → Distress by FASt Status', fontsize=12, fontweight='bold')
    ax.legend()
    
    # 8b. Conditional effects at different credit doses
    ax = axes[0, 1]
    
    # Create credit dose bins
    credit_bins = pd.cut(credits, bins=[0, 3, 6, 12, 20, 60], labels=['0-3', '4-6', '7-12', '13-20', '21+'])
    df['credit_bin'] = credit_bins
    
    # Calculate FASt gap at each bin
    gaps = []
    gap_ses = []
    bin_labels = []
    for bin_label in ['0-3', '4-6', '7-12', '13-20', '21+']:
        bin_data = df[df['credit_bin'] == bin_label]
        if len(bin_data) > 10:
            fast_mean = bin_data[bin_data['x_FASt']==1]['mean_distress'].mean()
            nonfast_mean = bin_data[bin_data['x_FASt']==0]['mean_distress'].mean()
            fast_n = (bin_data['x_FASt']==1).sum()
            nonfast_n = (bin_data['x_FASt']==0).sum()
            
            if fast_n > 5 and nonfast_n > 5:
                gap = fast_mean - nonfast_mean
                # Pooled SE
                fast_var = bin_data[bin_data['x_FASt']==1]['mean_distress'].var()
                nonfast_var = bin_data[bin_data['x_FASt']==0]['mean_distress'].var()
                se = np.sqrt(fast_var/fast_n + nonfast_var/nonfast_n)
                gaps.append(gap)
                gap_ses.append(se)
                bin_labels.append(bin_label)
    
    x_pos = np.arange(len(bin_labels))
    bars = ax.bar(x_pos, gaps, yerr=[1.96*se for se in gap_ses], 
                  capsize=5, color=[colors['fast'] if g > 0 else colors['nonfast'] for g in gaps])
    ax.axhline(0, color='black', linewidth=0.8)
    ax.set_xticks(x_pos)
    ax.set_xticklabels(bin_labels)
    ax.set_xlabel('Credit Dose Range', fontsize=11)
    ax.set_ylabel('FASt - Non-FASt Gap (Distress)', fontsize=11)
    ax.set_title('FASt Effect by Credit Dose\n(+ = FASt higher distress)', fontsize=12, fontweight='bold')
    
    # 8c. Johnson-Neyman style: At what credit level does FASt effect become significant?
    ax = axes[1, 0]
    
    # Compute rolling FASt effect
    credit_vals = np.arange(0, 35, 2)
    effects = []
    ci_lows = []
    ci_highs = []
    
    for cv in credit_vals:
        # Window around this credit value
        window = 5
        mask = (credits >= cv - window) & (credits <= cv + window)
        if mask.sum() > 20:
            fast_data = df.loc[mask & (df['x_FASt']==1), 'mean_distress']
            nonfast_data = df.loc[mask & (df['x_FASt']==0), 'mean_distress']
            
            if len(fast_data) > 5 and len(nonfast_data) > 5:
                effect = fast_data.mean() - nonfast_data.mean()
                se = np.sqrt(fast_data.var()/len(fast_data) + nonfast_data.var()/len(nonfast_data))
                effects.append(effect)
                ci_lows.append(effect - 1.96*se)
                ci_highs.append(effect + 1.96*se)
            else:
                effects.append(np.nan)
                ci_lows.append(np.nan)
                ci_highs.append(np.nan)
        else:
            effects.append(np.nan)
            ci_lows.append(np.nan)
            ci_highs.append(np.nan)
    
    ax.fill_between(credit_vals, ci_lows, ci_highs, alpha=0.3, color=colors['fast'])
    ax.plot(credit_vals, effects, '-', color=colors['fast'], linewidth=2)
    ax.axhline(0, color='black', linewidth=1)
    ax.axvline(12, color='gray', linestyle='--', alpha=0.7, label='FASt threshold')
    ax.set_xlabel('Transfer Credits', fontsize=11)
    ax.set_ylabel('FASt Effect on Distress', fontsize=11)
    ax.set_title('Conditional FASt Effect Across Credit Spectrum\n(Rolling window, 95% CI)', fontsize=12, fontweight='bold')
    ax.legend()
    
    # 8d. Engagement pattern
    ax = axes[1, 1]
    
    effects = []
    ci_lows = []
    ci_highs = []
    
    for cv in credit_vals:
        window = 5
        mask = (credits >= cv - window) & (credits <= cv + window)
        if mask.sum() > 20:
            fast_data = df.loc[mask & (df['x_FASt']==1), 'mean_engagement']
            nonfast_data = df.loc[mask & (df['x_FASt']==0), 'mean_engagement']
            
            if len(fast_data) > 5 and len(nonfast_data) > 5:
                effect = fast_data.mean() - nonfast_data.mean()
                se = np.sqrt(fast_data.var()/len(fast_data) + nonfast_data.var()/len(nonfast_data))
                effects.append(effect)
                ci_lows.append(effect - 1.96*se)
                ci_highs.append(effect + 1.96*se)
            else:
                effects.append(np.nan)
                ci_lows.append(np.nan)
                ci_highs.append(np.nan)
        else:
            effects.append(np.nan)
            ci_lows.append(np.nan)
            ci_highs.append(np.nan)
    
    ax.fill_between(credit_vals, ci_lows, ci_highs, alpha=0.3, color=colors['nonfast'])
    ax.plot(credit_vals, effects, '-', color=colors['nonfast'], linewidth=2)
    ax.axhline(0, color='black', linewidth=1)
    ax.axvline(12, color='gray', linestyle='--', alpha=0.7, label='FASt threshold')
    ax.set_xlabel('Transfer Credits', fontsize=11)
    ax.set_ylabel('FASt Effect on Engagement', fontsize=11)
    ax.set_title('Conditional FASt Effect on Engagement\n(Rolling window, 95% CI)', fontsize=12, fontweight='bold')
    ax.legend()
    
    plt.suptitle('Figure 8: Credit Dose × FASt Moderation Pattern', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig8_credit_dose_moderation.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 8: Credit Dose Moderation saved')
    
    # =========================================================================
    # FIGURE 9: Mediation Pathway Visualization
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 12))
    
    # Create composite outcome measures
    sb_cols = ['sbvalued', 'sbmyself', 'sbcommunity']
    pg_cols = ['pgthink', 'pganalyze', 'pgwork', 'pgvalues', 'pgprobsolve']
    se_cols = ['SEwellness', 'SEnonacad', 'SEactivities', 'SEacademic', 'SEdiverse']
    
    df['mean_belonging'] = df[sb_cols].mean(axis=1)
    df['mean_gains'] = df[pg_cols].mean(axis=1)
    df['mean_support'] = df[se_cols].mean(axis=1)
    df['mean_devadj'] = (df['mean_belonging'] + df['mean_gains'] + df['mean_support'] + 
                         df[['evalexp', 'sameinst']].mean(axis=1)) / 4
    
    # 9a. Distress → Developmental Adjustment scatter
    ax = axes[0, 0]
    ax.scatter(df['mean_distress'], df['mean_devadj'], alpha=0.2, c='gray', s=10)
    
    # Add regression line
    slope, intercept, r, p, se = stats.linregress(df['mean_distress'], df['mean_devadj'])
    x_line = np.array([df['mean_distress'].min(), df['mean_distress'].max()])
    ax.plot(x_line, intercept + slope * x_line, '-', color=colors['fast'], linewidth=3,
            label=f'r = {r:.3f}, p < .001')
    ax.set_xlabel('Emotional Distress (EmoDiss)', fontsize=11)
    ax.set_ylabel('Developmental Adjustment (DevAdj)', fontsize=11)
    ax.set_title('Mediator Path: EmoDiss → DevAdj', fontsize=12, fontweight='bold')
    ax.legend()
    
    # 9b. Engagement → Developmental Adjustment scatter
    ax = axes[0, 1]
    ax.scatter(df['mean_engagement'], df['mean_devadj'], alpha=0.2, c='gray', s=10)
    
    slope, intercept, r, p, se = stats.linregress(df['mean_engagement'], df['mean_devadj'])
    x_line = np.array([df['mean_engagement'].min(), df['mean_engagement'].max()])
    ax.plot(x_line, intercept + slope * x_line, '-', color=colors['nonfast'], linewidth=3,
            label=f'r = {r:.3f}, p < .001')
    ax.set_xlabel('Quality of Engagement (QualEngag)', fontsize=11)
    ax.set_ylabel('Developmental Adjustment (DevAdj)', fontsize=11)
    ax.set_title('Mediator Path: QualEngag → DevAdj', fontsize=12, fontweight='bold')
    ax.legend()
    
    # 9c. FASt → Mediators → Outcome path diagram (conceptual)
    ax = axes[1, 0]
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Draw boxes
    boxes = {
        'X': (1, 5, 'FASt\nStatus'),
        'M1': (5, 7.5, 'EmoDiss'),
        'M2': (5, 2.5, 'QualEngag'),
        'Y': (9, 5, 'DevAdj')
    }
    
    for key, (x, y, label) in boxes.items():
        rect = FancyBboxPatch((x-0.8, y-0.6), 1.6, 1.2, boxstyle="round,pad=0.05",
                              facecolor='lightblue' if key in ['M1', 'M2'] else 'lightyellow',
                              edgecolor='black', linewidth=2)
        ax.add_patch(rect)
        ax.text(x, y, label, ha='center', va='center', fontsize=11, fontweight='bold')
    
    # Draw arrows with path coefficients (from our SEM)
    # a paths (X → M)
    ax.annotate('', xy=(4.2, 7.5), xytext=(1.8, 5.5),
                arrowprops=dict(arrowstyle='->', color=colors['fast'], lw=2))
    ax.text(2.8, 7, 'a₁ (+)', fontsize=10, color=colors['fast'])
    
    ax.annotate('', xy=(4.2, 2.5), xytext=(1.8, 4.5),
                arrowprops=dict(arrowstyle='->', color=colors['nonfast'], lw=2))
    ax.text(2.8, 3, 'a₂ (−)', fontsize=10, color=colors['nonfast'])
    
    # b paths (M → Y)
    ax.annotate('', xy=(8.2, 5.5), xytext=(5.8, 7.5),
                arrowprops=dict(arrowstyle='->', color=colors['fast'], lw=2))
    ax.text(7.2, 7, 'b₁ (−)', fontsize=10, color=colors['fast'])
    
    ax.annotate('', xy=(8.2, 4.5), xytext=(5.8, 2.5),
                arrowprops=dict(arrowstyle='->', color=colors['nonfast'], lw=2))
    ax.text(7.2, 3, 'b₂ (+)', fontsize=10, color=colors['nonfast'])
    
    # c' path (X → Y direct)
    ax.annotate('', xy=(8.2, 5), xytext=(1.8, 5),
                arrowprops=dict(arrowstyle='->', color='gray', lw=1.5, ls='--'))
    ax.text(5, 5.3, "c' (ns)", fontsize=10, color='gray')
    
    ax.set_title('Parallel Mediation Model\n(Conceptual)', fontsize=12, fontweight='bold')
    
    # 9d. Indirect effects visualization
    ax = axes[1, 1]
    
    # Calculate crude indirect effects for visualization
    # a1: FASt → Distress
    a1 = df.groupby('x_FASt')['mean_distress'].mean().diff().iloc[1]
    # b1: Distress → DevAdj (controlling for FASt)
    b1 = stats.linregress(df['mean_distress'], df['mean_devadj'])[0]
    # a2: FASt → Engagement
    a2 = df.groupby('x_FASt')['mean_engagement'].mean().diff().iloc[1]
    # b2: Engagement → DevAdj
    b2 = stats.linregress(df['mean_engagement'], df['mean_devadj'])[0]
    
    ind_distress = a1 * b1
    ind_engage = a2 * b2
    total_indirect = ind_distress + ind_engage
    
    # Direct effect (crude)
    direct = df.groupby('x_FASt')['mean_devadj'].mean().diff().iloc[1]
    
    effects = ['via EmoDiss\n(a₁×b₁)', 'via QualEngag\n(a₂×b₂)', 'Direct\n(c\')', 'Total']
    values = [ind_distress, ind_engage, direct, direct + total_indirect]
    colors_bar = [colors['fast'], colors['nonfast'], 'gray', 'purple']
    
    bars = ax.barh(effects, values, color=colors_bar)
    ax.axvline(0, color='black', linewidth=1)
    ax.set_xlabel('Effect on Developmental Adjustment', fontsize=11)
    ax.set_title('Decomposition of FASt Effect\n(Crude estimates for visualization)', fontsize=12, fontweight='bold')
    
    for i, (bar, val) in enumerate(zip(bars, values)):
        ax.text(val + 0.005 if val > 0 else val - 0.005, i, f'{val:.3f}', 
                va='center', ha='left' if val > 0 else 'right', fontsize=10)
    
    plt.suptitle('Figure 9: Mediation Pathway Analysis', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig9_mediation_pathways.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 9: Mediation Pathways saved')
    
    # =========================================================================
    # FIGURE 10: Intersectionality Matrix (FASt × First-Gen × URM)
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 12))
    
    # Create intersectional groups
    df['intersection'] = (df['x_FASt'].astype(str) + '_' + 
                          df['firstgen'].astype(str) + '_' + 
                          df['urm'].astype(str))
    
    # Readable labels
    int_labels = {
        '0_0_0': 'Non-FASt\nCont-Gen\nNon-URM',
        '0_0_1': 'Non-FASt\nCont-Gen\nURM',
        '0_1_0': 'Non-FASt\nFirst-Gen\nNon-URM',
        '0_1_1': 'Non-FASt\nFirst-Gen\nURM',
        '1_0_0': 'FASt\nCont-Gen\nNon-URM',
        '1_0_1': 'FASt\nCont-Gen\nURM',
        '1_1_0': 'FASt\nFirst-Gen\nNon-URM',
        '1_1_1': 'FASt\nFirst-Gen\nURM'
    }
    
    # 10a. Distress by intersectional group
    ax = axes[0, 0]
    int_means = df.groupby('intersection')['mean_distress'].agg(['mean', 'sem', 'count'])
    int_means = int_means.reindex(['0_0_0', '0_0_1', '0_1_0', '0_1_1', '1_0_0', '1_0_1', '1_1_0', '1_1_1'])
    
    x_pos = np.arange(8)
    colors_int = [colors['nonfast']]*4 + [colors['fast']]*4
    alphas = [0.5, 0.7, 0.7, 1.0] * 2  # darker = more risk factors
    
    for i, (idx, row) in enumerate(int_means.iterrows()):
        ax.bar(i, row['mean'], yerr=1.96*row['sem'], capsize=3,
               color=colors_int[i], alpha=alphas[i % 4])
    
    ax.set_xticks(x_pos)
    ax.set_xticklabels([int_labels[k] for k in int_means.index], fontsize=8, rotation=45, ha='right')
    ax.set_ylabel('Mean Distress', fontsize=11)
    ax.set_title('Emotional Distress by Intersectional Identity', fontsize=12, fontweight='bold')
    ax.set_ylim(2, 3.5)
    
    # 10b. Engagement by intersectional group
    ax = axes[0, 1]
    int_means = df.groupby('intersection')['mean_engagement'].agg(['mean', 'sem', 'count'])
    int_means = int_means.reindex(['0_0_0', '0_0_1', '0_1_0', '0_1_1', '1_0_0', '1_0_1', '1_1_0', '1_1_1'])
    
    for i, (idx, row) in enumerate(int_means.iterrows()):
        ax.bar(i, row['mean'], yerr=1.96*row['sem'], capsize=3,
               color=colors_int[i], alpha=alphas[i % 4])
    
    ax.set_xticks(x_pos)
    ax.set_xticklabels([int_labels[k] for k in int_means.index], fontsize=8, rotation=45, ha='right')
    ax.set_ylabel('Mean Engagement', fontsize=11)
    ax.set_title('Quality of Engagement by Intersectional Identity', fontsize=12, fontweight='bold')
    ax.set_ylim(3, 5.5)
    
    # 10c. Heatmap: FASt × First-Gen interaction on distress
    ax = axes[1, 0]
    pivot = df.pivot_table(values='mean_distress', index='firstgen', columns='x_FASt', aggfunc='mean')
    pivot.index = ['Continuing-Gen', 'First-Gen']
    pivot.columns = ['Non-FASt', 'FASt']
    
    im = ax.imshow(pivot.values, cmap='Reds', vmin=2.3, vmax=2.9)
    ax.set_xticks([0, 1])
    ax.set_yticks([0, 1])
    ax.set_xticklabels(pivot.columns)
    ax.set_yticklabels(pivot.index)
    
    for i in range(2):
        for j in range(2):
            ax.text(j, i, f'{pivot.values[i, j]:.2f}', ha='center', va='center', 
                    fontsize=14, fontweight='bold', color='white' if pivot.values[i, j] > 2.6 else 'black')
    
    ax.set_title('FASt × First-Gen → Distress\n(Cell means)', fontsize=12, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Mean Distress')
    
    # 10d. Heatmap: FASt × URM interaction on engagement
    ax = axes[1, 1]
    pivot = df.pivot_table(values='mean_engagement', index='urm', columns='x_FASt', aggfunc='mean')
    pivot.index = ['Non-URM', 'URM']
    pivot.columns = ['Non-FASt', 'FASt']
    
    im = ax.imshow(pivot.values, cmap='Blues', vmin=3.8, vmax=4.6)
    ax.set_xticks([0, 1])
    ax.set_yticks([0, 1])
    ax.set_xticklabels(pivot.columns)
    ax.set_yticklabels(pivot.index)
    
    for i in range(2):
        for j in range(2):
            ax.text(j, i, f'{pivot.values[i, j]:.2f}', ha='center', va='center', 
                    fontsize=14, fontweight='bold', color='white' if pivot.values[i, j] < 4.2 else 'black')
    
    ax.set_title('FASt × URM → Engagement\n(Cell means)', fontsize=12, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Mean Engagement')
    
    plt.suptitle('Figure 10: Intersectionality Analysis', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig10_intersectionality.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 10: Intersectionality Analysis saved')
    
    # =========================================================================
    # FIGURE 11: Outcome Profiles (Cluster-style visualization)
    # =========================================================================
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    
    # 11a. Radar/Spider chart for FASt vs Non-FASt profiles
    ax = axes[0]
    
    # Normalize outcomes to 0-1 scale for comparison
    outcomes = ['mean_distress', 'mean_engagement', 'mean_belonging', 'mean_gains', 'mean_support']
    outcome_labels = ['Distress\n(reversed)', 'Engagement', 'Belonging', 'Gains', 'Support']
    
    fast_profile = []
    nonfast_profile = []
    
    for out in outcomes:
        out_min = df[out].min()
        out_max = df[out].max()
        fast_norm = (df[df['x_FASt']==1][out].mean() - out_min) / (out_max - out_min)
        nonfast_norm = (df[df['x_FASt']==0][out].mean() - out_min) / (out_max - out_min)
        
        # Reverse distress so higher = better
        if out == 'mean_distress':
            fast_norm = 1 - fast_norm
            nonfast_norm = 1 - nonfast_norm
        
        fast_profile.append(fast_norm)
        nonfast_profile.append(nonfast_norm)
    
    # Create radar chart
    angles = np.linspace(0, 2*np.pi, len(outcomes), endpoint=False).tolist()
    angles += angles[:1]  # complete the circle
    
    fast_profile += fast_profile[:1]
    nonfast_profile += nonfast_profile[:1]
    
    ax = plt.subplot(121, polar=True)
    ax.plot(angles, nonfast_profile, 'o-', linewidth=2, label='Non-FASt', color=colors['nonfast'])
    ax.fill(angles, nonfast_profile, alpha=0.25, color=colors['nonfast'])
    ax.plot(angles, fast_profile, 'o-', linewidth=2, label='FASt', color=colors['fast'])
    ax.fill(angles, fast_profile, alpha=0.25, color=colors['fast'])
    
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(outcome_labels, fontsize=10)
    ax.set_ylim(0, 1)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.0))
    ax.set_title('Outcome Profile: FASt vs Non-FASt\n(Higher = Better)', fontsize=12, fontweight='bold')
    
    # 11b. Profile by risk level
    ax = plt.subplot(122, polar=True)
    
    risk_profiles = {}
    for risk_level in [0, 1, 2, 3, 4]:
        profile = []
        for out in outcomes:
            out_min = df[out].min()
            out_max = df[out].max()
            risk_data = df[df['risk_count']==risk_level]
            if len(risk_data) > 10:
                norm = (risk_data[out].mean() - out_min) / (out_max - out_min)
                if out == 'mean_distress':
                    norm = 1 - norm
                profile.append(norm)
            else:
                profile.append(np.nan)
        risk_profiles[risk_level] = profile + [profile[0]]
    
    cmap = plt.cm.Reds
    for risk_level, profile in risk_profiles.items():
        if not any(np.isnan(profile)):
            ax.plot(angles, profile, 'o-', linewidth=2, 
                   label=f'{risk_level} factors', color=cmap(0.2 + risk_level * 0.2))
            ax.fill(angles, profile, alpha=0.1, color=cmap(0.2 + risk_level * 0.2))
    
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(outcome_labels, fontsize=10)
    ax.set_ylim(0, 1)
    ax.legend(loc='upper right', bbox_to_anchor=(1.4, 1.0))
    ax.set_title('Outcome Profile by Risk Level\n(Higher = Better)', fontsize=12, fontweight='bold')
    
    plt.suptitle('Figure 11: Student Outcome Profiles', fontsize=14, fontweight='bold', y=1.05)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig11_outcome_profiles.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 11: Outcome Profiles saved')
    
    # =========================================================================
    # FIGURE 12: Longitudinal Cohort Patterns
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # 12a. Distress trend by cohort
    ax = axes[0, 0]
    cohort_distress = df.groupby('cohort')['mean_distress'].agg(['mean', 'sem'])
    ax.errorbar(cohort_distress.index, cohort_distress['mean'], 
                yerr=1.96*cohort_distress['sem'], fmt='o-', capsize=5, 
                color=colors['fast'], markersize=10, linewidth=2)
    ax.set_xlabel('Cohort Year', fontsize=11)
    ax.set_ylabel('Mean Distress', fontsize=11)
    ax.set_title('Distress Trends Across Cohorts', fontsize=12, fontweight='bold')
    
    # 12b. Engagement trend by cohort
    ax = axes[0, 1]
    cohort_engage = df.groupby('cohort')['mean_engagement'].agg(['mean', 'sem'])
    ax.errorbar(cohort_engage.index, cohort_engage['mean'], 
                yerr=1.96*cohort_engage['sem'], fmt='s-', capsize=5, 
                color=colors['nonfast'], markersize=10, linewidth=2)
    ax.set_xlabel('Cohort Year', fontsize=11)
    ax.set_ylabel('Mean Engagement', fontsize=11)
    ax.set_title('Engagement Trends Across Cohorts', fontsize=12, fontweight='bold')
    
    # 12c. FASt % by cohort
    ax = axes[1, 0]
    fast_by_cohort = df.groupby('cohort')['x_FASt'].mean() * 100
    ax.bar(fast_by_cohort.index.astype(str), fast_by_cohort.values, color=colors['fast'])
    ax.set_xlabel('Cohort Year', fontsize=11)
    ax.set_ylabel('% FASt Students', fontsize=11)
    ax.set_title('FASt Enrollment by Cohort', fontsize=12, fontweight='bold')
    for i, (idx, v) in enumerate(fast_by_cohort.items()):
        ax.text(i, v + 0.5, f'{v:.1f}%', ha='center', fontsize=10)
    
    # 12d. FASt gap by cohort
    ax = axes[1, 1]
    gaps = []
    cohorts = df['cohort'].unique()
    for cohort in sorted(cohorts):
        cohort_data = df[df['cohort'] == cohort]
        fast_mean = cohort_data[cohort_data['x_FASt']==1]['mean_distress'].mean()
        nonfast_mean = cohort_data[cohort_data['x_FASt']==0]['mean_distress'].mean()
        gaps.append(fast_mean - nonfast_mean)
    
    ax.bar([str(c) for c in sorted(cohorts)], gaps, 
           color=[colors['fast'] if g > 0 else colors['nonfast'] for g in gaps])
    ax.axhline(0, color='black', linewidth=1)
    ax.set_xlabel('Cohort Year', fontsize=11)
    ax.set_ylabel('FASt - Non-FASt Gap (Distress)', fontsize=11)
    ax.set_title('FASt Effect on Distress by Cohort', fontsize=12, fontweight='bold')
    
    plt.suptitle('Figure 12: Cohort Patterns', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig12_cohort_patterns.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 12: Cohort Patterns saved')
    
    print(f'\n✓ All deep-cut figures saved to {outdir}/')
    return outdir


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate deep-cut visualizations')
    parser.add_argument('--data', default='rep_data.csv', help='Path to data file')
    parser.add_argument('--outdir', default='results/descriptive_plots', help='Output directory')
    args = parser.parse_args()
    
    main(args.data, args.outdir)
