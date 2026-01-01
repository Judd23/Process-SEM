#!/usr/bin/env python3
"""
Generate descriptive statistics plots for Process-SEM dissertation.
Outputs publication-quality figures for Chapter 4 (Results).

Usage:
    python scripts/plot_descriptives.py [--data rep_data.csv] [--outdir results/descriptive_plots]
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
import argparse

def main(data_path='rep_data.csv', outdir='results/descriptive_plots'):
    os.makedirs(outdir, exist_ok=True)
    
    df = pd.read_csv(data_path)
    plt.style.use('seaborn-v0_8-whitegrid')
    
    # Color palette for equity focus
    colors = {
        'primary': '#1f77b4', 
        'secondary': '#ff7f0e', 
        'accent': '#2ca02c', 
        'highlight': '#d62728', 
        'neutral': '#7f7f7f'
    }
    
    # =========================================================================
    # FIGURE 1: Demographics Overview
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # 1a. Race/Ethnicity
    ax = axes[0, 0]
    race_order = ['Hispanic/Latino', 'White', 'Asian', 'Black/African American', 'Other/Multiracial/Unknown']
    race_counts = df['re_all'].value_counts().reindex(race_order)
    bars = ax.barh(race_order, race_counts.values, color=['#e74c3c', '#3498db', '#9b59b6', '#2ecc71', '#95a5a6'])
    ax.set_xlabel('Count', fontsize=11)
    ax.set_title('Race/Ethnicity Distribution', fontsize=12, fontweight='bold')
    for i, (v, pct) in enumerate(zip(race_counts.values, race_counts.values/len(df)*100)):
        ax.text(v + 20, i, f'{pct:.1f}%', va='center', fontsize=10)
    ax.set_xlim(0, max(race_counts.values) * 1.15)
    
    # 1b. First-gen and Pell status
    ax = axes[0, 1]
    categories = ['First-Gen', 'Pell-Eligible', 'Women', 'FASt Status']
    yes_pct = [df['firstgen'].mean()*100, df['pell'].mean()*100, 
               (df['sex']=='Woman').mean()*100, df['x_FASt'].mean()*100]
    no_pct = [100-p for p in yes_pct]
    x = np.arange(len(categories))
    width = 0.6
    bars1 = ax.bar(x, yes_pct, width, label='Yes', color=colors['primary'])
    bars2 = ax.bar(x, no_pct, width, bottom=yes_pct, label='No', color=colors['neutral'], alpha=0.5)
    ax.set_ylabel('Percentage', fontsize=11)
    ax.set_title('Key Demographic Indicators', fontsize=12, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(categories, fontsize=10)
    ax.legend(loc='upper right')
    for i, pct in enumerate(yes_pct):
        ax.text(i, pct/2, f'{pct:.1f}%', ha='center', va='center', color='white', fontweight='bold')
    
    # 1c. Credit dose distribution (use raw trnsfr_cr if available)
    ax = axes[1, 0]
    credit_col = 'trnsfr_cr' if 'trnsfr_cr' in df.columns else 'credit_dose'
    ax.hist(df[credit_col], bins=20, color=colors['primary'], edgecolor='white', alpha=0.8)
    ax.axvline(12, color=colors['highlight'], linestyle='--', linewidth=2, label='FASt threshold (12)')
    ax.axvline(df[credit_col].mean(), color=colors['secondary'], linestyle='-', linewidth=2, 
               label=f'Mean ({df[credit_col].mean():.1f})')
    ax.set_xlabel('Transfer Credits', fontsize=11)
    ax.set_ylabel('Frequency', fontsize=11)
    ax.set_title('Distribution of Transfer Credits', fontsize=12, fontweight='bold')
    ax.legend()
    
    # 1d. Cohort distribution
    ax = axes[1, 1]
    cohort_counts = df['cohort'].value_counts().sort_index()
    ax.bar(cohort_counts.index.astype(str), cohort_counts.values, color=colors['primary'], edgecolor='white')
    ax.set_xlabel('Cohort Year', fontsize=11)
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title('Cohort Distribution', fontsize=12, fontweight='bold')
    for i, v in enumerate(cohort_counts.values):
        ax.text(i, v + 20, f'{v}', ha='center', fontsize=10)
    
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig1_demographics.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 1: Demographics saved')
    
    # =========================================================================
    # FIGURE 2: Emotional Distress (EmoDiss) Distributions
    # =========================================================================
    fig, axes = plt.subplots(2, 3, figsize=(14, 9))
    mhw_cols = ['MHWdacad', 'MHWdlonely', 'MHWdmental', 'MHWdexhaust', 'MHWdsleep', 'MHWdfinancial']
    mhw_labels = ['Academic Difficulties', 'Loneliness', 'Mental Health', 'Exhaustion', 'Sleep Problems', 'Financial Stress']
    
    for idx, (col, label) in enumerate(zip(mhw_cols, mhw_labels)):
        ax = axes[idx // 3, idx % 3]
        counts = df[col].value_counts().sort_index()
        bars = ax.bar(counts.index, counts.values, color=colors['primary'], edgecolor='white')
        for bar, val in zip(bars, counts.index):
            if val >= 3:
                bar.set_color(colors['highlight'])
        ax.set_xlabel('Response (1=Not at all, 4=Very much)', fontsize=9)
        ax.set_ylabel('Count', fontsize=9)
        elevated_pct = (df[col] >= 3).mean() * 100
        ax.set_title(f'{label}\n({elevated_pct:.1f}% elevated)', fontsize=11, fontweight='bold')
        ax.set_xticks([1, 2, 3, 4])
    
    plt.suptitle('Emotional Distress Indicators (EmoDiss)', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig2_emotional_distress.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 2: Emotional Distress saved')
    
    # =========================================================================
    # FIGURE 3: Quality of Engagement (QualEngag) Distributions
    # =========================================================================
    fig, axes = plt.subplots(2, 3, figsize=(14, 9))
    qi_cols = ['QIstudent', 'QIadvisor', 'QIfaculty', 'QIstaff', 'QIadmin']
    qi_labels = ['Other Students', 'Academic Advisors', 'Faculty', 'Staff', 'Administrators']
    
    for idx, (col, label) in enumerate(zip(qi_cols, qi_labels)):
        ax = axes[idx // 3, idx % 3]
        counts = df[col].value_counts().sort_index()
        ax.bar(counts.index, counts.values, color=colors['primary'], edgecolor='white')
        ax.set_xlabel('Response (1=Poor, 7=Excellent)', fontsize=9)
        ax.set_ylabel('Count', fontsize=9)
        ax.set_title(f'Quality of Interactions: {label}\n(M={df[col].mean():.2f}, SD={df[col].std():.2f})', 
                     fontsize=11, fontweight='bold')
        ax.set_xticks(range(1, 8))
    
    axes[1, 2].axis('off')
    
    plt.suptitle('Quality of Engagement Indicators (QualEngag)', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig3_quality_engagement.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 3: Quality of Engagement saved')
    
    # =========================================================================
    # FIGURE 4: Developmental Adjustment (DevAdj) - Belonging & Gains
    # =========================================================================
    fig, axes = plt.subplots(2, 4, figsize=(16, 9))
    
    # Belonging items
    sb_cols = ['sbvalued', 'sbmyself', 'sbcommunity']
    sb_labels = ['Feel Valued', 'Can Be Myself', 'Part of Community']
    for idx, (col, label) in enumerate(zip(sb_cols, sb_labels)):
        ax = axes[0, idx]
        counts = df[col].value_counts().sort_index()
        bars = ax.bar(counts.index, counts.values, color=colors['accent'], edgecolor='white')
        for bar, val in zip(bars, counts.index):
            if val <= 2:
                bar.set_color(colors['highlight'])
        ax.set_xlabel('Response (1-4)', fontsize=9)
        ax.set_ylabel('Count', fontsize=9)
        low_pct = (df[col] <= 2).mean() * 100
        ax.set_title(f'{label}\n({low_pct:.1f}% low)', fontsize=10, fontweight='bold')
        ax.set_xticks([1, 2, 3, 4])
    
    # Summary belonging
    ax = axes[0, 3]
    low_belong = [(df[c] <= 2).mean() * 100 for c in sb_cols]
    ax.barh(sb_labels, low_belong, color=colors['highlight'])
    ax.set_xlabel('% Low Belonging (≤2)', fontsize=10)
    ax.set_title('Summary: Low Belonging', fontsize=10, fontweight='bold')
    ax.set_xlim(0, 80)
    for i, v in enumerate(low_belong):
        ax.text(v + 1, i, f'{v:.1f}%', va='center', fontsize=10)
    
    # Gains items
    pg_cols = ['pgthink', 'pganalyze', 'pgwork', 'pgvalues', 'pgprobsolve']
    pg_labels = ['Think Critically', 'Analyze', 'Work w/ Others', 'Values', 'Problem Solve']
    means = [df[c].mean() for c in pg_cols]
    sds = [df[c].std() for c in pg_cols]
    
    ax = axes[1, 0]
    ax.barh(pg_labels, means, xerr=sds, color=colors['primary'], capsize=3)
    ax.set_xlabel('Mean (±SD)', fontsize=10)
    ax.set_title('Perceived Gains', fontsize=10, fontweight='bold')
    ax.set_xlim(1, 4)
    
    # SE items
    se_cols = ['SEwellness', 'SEnonacad', 'SEactivities', 'SEacademic', 'SEdiverse']
    se_labels = ['Wellness', 'Non-Academic', 'Activities', 'Academic', 'Diverse']
    means = [df[c].mean() for c in se_cols]
    sds = [df[c].std() for c in se_cols]
    
    ax = axes[1, 1]
    ax.barh(se_labels, means, xerr=sds, color=colors['secondary'], capsize=3)
    ax.set_xlabel('Mean (±SD)', fontsize=10)
    ax.set_title('Support Environment', fontsize=10, fontweight='bold')
    ax.set_xlim(1, 4)
    
    # Satisfaction
    ax = axes[1, 2]
    sat_cols = ['evalexp', 'sameinst']
    sat_labels = ['Overall Experience', 'Same Institution']
    means = [df[c].mean() for c in sat_cols]
    sds = [df[c].std() for c in sat_cols]
    ax.barh(sat_labels, means, xerr=sds, color=colors['accent'], capsize=3)
    ax.set_xlabel('Mean (±SD)', fontsize=10)
    ax.set_title('Satisfaction', fontsize=10, fontweight='bold')
    ax.set_xlim(1, 4)
    
    axes[1, 3].axis('off')
    
    plt.suptitle('Developmental Adjustment Indicators (DevAdj)', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig4_developmental_adjustment.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 4: Developmental Adjustment saved')
    
    # =========================================================================
    # FIGURE 5: Equity Gaps Visualization
    # =========================================================================
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # 5a. FASt vs Non-FASt - Emotional Distress
    ax = axes[0, 0]
    fast = df[df['x_FASt'] == 1]
    nonfast = df[df['x_FASt'] == 0]
    mhw_short = ['Academic', 'Lonely', 'Mental', 'Exhaust', 'Sleep', 'Financial']
    fast_means = [fast[c].mean() for c in mhw_cols]
    nonfast_means = [nonfast[c].mean() for c in mhw_cols]
    x = np.arange(len(mhw_short))
    width = 0.35
    ax.bar(x - width/2, nonfast_means, width, label='Non-FASt', color=colors['primary'])
    ax.bar(x + width/2, fast_means, width, label='FASt', color=colors['highlight'])
    ax.set_ylabel('Mean Distress (1-4)', fontsize=11)
    ax.set_title('Emotional Distress by FASt Status', fontsize=12, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(mhw_short, fontsize=9)
    ax.legend()
    ax.set_ylim(1, 4)
    
    # 5b. FASt vs Non-FASt - Quality of Engagement
    ax = axes[0, 1]
    qi_short = ['Students', 'Advisors', 'Faculty', 'Staff', 'Admin']
    fast_means = [fast[c].mean() for c in qi_cols]
    nonfast_means = [nonfast[c].mean() for c in qi_cols]
    x = np.arange(len(qi_short))
    ax.bar(x - width/2, nonfast_means, width, label='Non-FASt', color=colors['primary'])
    ax.bar(x + width/2, fast_means, width, label='FASt', color=colors['highlight'])
    ax.set_ylabel('Mean Quality (1-7)', fontsize=11)
    ax.set_title('Quality of Engagement by FASt Status', fontsize=12, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(qi_short, fontsize=9)
    ax.legend()
    ax.set_ylim(1, 7)
    
    # 5c. First-gen gaps
    ax = axes[1, 0]
    firstgen = df[df['firstgen'] == 1]
    contgen = df[df['firstgen'] == 0]
    key_vars = ['MHWdacad', 'MHWdlonely', 'sbcommunity', 'QIfaculty', 'evalexp']
    key_labels = ['Academic\nDistress', 'Loneliness', 'Community\nBelong', 'Faculty\nQuality', 'Overall\nExperience']
    fg_means = [firstgen[c].mean() for c in key_vars]
    cg_means = [contgen[c].mean() for c in key_vars]
    x = np.arange(len(key_labels))
    ax.bar(x - width/2, cg_means, width, label='Continuing-gen', color=colors['primary'])
    ax.bar(x + width/2, fg_means, width, label='First-gen', color=colors['secondary'])
    ax.set_ylabel('Mean Score', fontsize=11)
    ax.set_title('Key Outcomes by First-Generation Status', fontsize=12, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(key_labels, fontsize=9)
    ax.legend()
    
    # 5d. Gap summary (effect sizes)
    ax = axes[1, 1]
    gap_vars = ['MHWdacad', 'MHWdmental', 'sbcommunity', 'QIfaculty', 'evalexp']
    gap_labels = ['Academic Distress', 'Mental Health', 'Community Belonging', 'Faculty Quality', 'Overall Experience']
    
    # Calculate Cohen's d for FASt effect
    def cohens_d(g1, g2):
        n1, n2 = len(g1), len(g2)
        var1, var2 = g1.var(), g2.var()
        pooled_std = np.sqrt(((n1-1)*var1 + (n2-1)*var2) / (n1+n2-2))
        return (g1.mean() - g2.mean()) / pooled_std
    
    fast_d = [cohens_d(fast[c], nonfast[c]) for c in gap_vars]
    
    colors_d = [colors['highlight'] if d > 0 else colors['accent'] for d in fast_d]
    ax.barh(gap_labels, fast_d, color=colors_d)
    ax.axvline(0, color='black', linewidth=0.8)
    ax.axvline(0.2, color='gray', linestyle='--', linewidth=0.8, alpha=0.5)
    ax.axvline(-0.2, color='gray', linestyle='--', linewidth=0.8, alpha=0.5)
    ax.set_xlabel("Cohen's d (FASt vs Non-FASt)", fontsize=11)
    ax.set_title('FASt Effect Sizes\n(+) = FASt higher, (−) = FASt lower', fontsize=12, fontweight='bold')
    ax.set_xlim(-0.5, 0.5)
    
    plt.suptitle('Equity Gaps Analysis', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig5_equity_gaps.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 5: Equity Gaps saved')
    
    # =========================================================================
    # FIGURE 6: Correlation Heatmap - Key Variables
    # =========================================================================
    fig, ax = plt.subplots(figsize=(12, 10))
    
    key_vars = ['x_FASt', 'credit_dose', 'firstgen', 'pell',
                'MHWdacad', 'MHWdlonely', 'MHWdmental',
                'QIstudent', 'QIfaculty', 'QIadvisor',
                'sbcommunity', 'sbvalued', 
                'pgthink', 'evalexp']
    
    var_labels = ['FASt Status', 'Credit Dose', 'First-Gen', 'Pell',
                  'Acad Distress', 'Loneliness', 'Mental Health',
                  'QI: Students', 'QI: Faculty', 'QI: Advisors',
                  'Belong: Community', 'Belong: Valued',
                  'Gains: Think', 'Satisfaction']
    
    corr_matrix = df[key_vars].corr()
    
    im = ax.imshow(corr_matrix, cmap='RdBu_r', vmin=-1, vmax=1)
    ax.set_xticks(range(len(var_labels)))
    ax.set_yticks(range(len(var_labels)))
    ax.set_xticklabels(var_labels, rotation=45, ha='right', fontsize=9)
    ax.set_yticklabels(var_labels, fontsize=9)
    
    # Add correlation values
    for i in range(len(var_labels)):
        for j in range(len(var_labels)):
            val = corr_matrix.iloc[i, j]
            color = 'white' if abs(val) > 0.4 else 'black'
            ax.text(j, i, f'{val:.2f}', ha='center', va='center', color=color, fontsize=8)
    
    plt.colorbar(im, ax=ax, label='Pearson r')
    ax.set_title('Correlation Matrix: Key Study Variables', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(f'{outdir}/fig6_correlation_heatmap.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Figure 6: Correlation Heatmap saved')
    
    print(f'\n✓ All figures saved to {outdir}/')
    return outdir


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate descriptive plots')
    parser.add_argument('--data', default='rep_data.csv', help='Path to data file')
    parser.add_argument('--outdir', default='results/descriptive_plots', help='Output directory')
    args = parser.parse_args()
    
    main(args.data, args.outdir)
