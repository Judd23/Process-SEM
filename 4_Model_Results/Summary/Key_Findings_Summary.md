# Key Findings Summary
## Psychosocial Effects of Accelerated Dual Credit on First-Year Developmental Adjustment

**Analysis Date**: January 1, 2026  
**Sample Size**: N = 5,000 students  
**Statistical Method**: Structural Equation Modeling with Propensity Score Weighting

---

## Overview

This study examined whether students who enter college with significant dual credit experience ("FASt" students—those with 12 or more transferable credits at matriculation) differ in their first-year developmental adjustment compared to their peers. The analysis tested whether any effects operate through two psychological mechanisms: emotional distress and quality of engagement with the campus community.

---

## Research Question 1: Does FASt Status Affect Developmental Adjustment?

**Finding: Yes, but the effect depends on how many credits students bring.**

At the average level of credit accumulation, FASt students show significantly lower developmental adjustment compared to non-FASt peers. The total effect is -0.045 (p = .012), meaning FASt students score about 4.5% of a standard deviation lower on developmental adjustment. 

However, this effect varies considerably based on credit dose (the number of credits students accumulated):
- **Students with fewer credits** (1 SD below average): No significant difference from non-FASt peers
- **Students with average credits**: Significant negative effect on adjustment
- **Students with more credits** (1 SD above average): Larger negative effect (-0.084, p < .001)

**Interpretation**: The more dual credits students accumulate, the more challenging their first-year adjustment appears to be. Students who just barely qualify as FASt (around 12 credits) show minimal differences, while those with substantially more credits experience greater adjustment difficulties.

---

## Research Question 2: How Does FASt Status Affect Emotional Distress?

**Finding: FASt students experience more emotional distress, and this intensifies with more credits.**

FASt status significantly increases emotional distress (a₁ = 0.21, p < .001). This means FASt students report higher levels of academic stress, loneliness, mental health difficulties, exhaustion, sleep problems, and financial concerns.

The moderation effect is also significant (a₁z = 0.17, p < .001):
- **Low credit dose**: No significant effect on distress
- **Average credit dose**: Moderate increase in distress
- **High credit dose**: Strong increase in distress (0.43, p < .001)

**Interpretation**: Students who enter with more dual credits experience substantially more emotional distress during their first year. This may reflect the challenges of missing developmental experiences that typically occur during the senior year of high school, or feeling out of sync with same-age peers who are experiencing college milestones together.

---

## Research Question 3: How Does FASt Status Affect Quality of Engagement?

**Finding: The relationship reverses depending on credit dose.**

FASt status alone does not significantly affect quality of engagement (a₂ = 0.04, p = .477). However, there is a strong moderation effect (a₂z = -0.26, p < .001):

- **Low credit dose**: FASt students show *higher* engagement (0.38, p < .001)
- **Average credit dose**: No significant difference
- **High credit dose**: FASt students show *lower* engagement (-0.31, p < .001)

**Interpretation**: This is a striking crossover interaction. Students who enter with modest dual credit experience (around 12-15 credits) actually engage more with faculty, staff, advisors, and peers—perhaps because they feel confident and prepared. However, students with extensive dual credit experience (20+ credits) engage less with the campus community, possibly because they feel disconnected from typical first-year experiences or may be further along in their academic trajectory.

---

## Mediation Analysis: How Do the Effects Work?

**Finding: Both emotional distress and quality of engagement mediate the effect, but in opposite directions.**

### Emotional Distress Pathway
- Distress significantly harms developmental adjustment (b₁ = -0.15, p < .001)
- The indirect effect through distress is significant at average and high credit levels
- **Index of moderated mediation**: -0.025 (p < .001), confirming that the mediation effect strengthens with more credits

### Quality of Engagement Pathway  
- Engagement significantly helps developmental adjustment (b₂ = 0.11, p < .001)
- The indirect effect through engagement varies by credit dose:
  - Low dose: Positive indirect effect (engagement helps)
  - High dose: Negative indirect effect (reduced engagement hurts)
- **Index of moderated mediation**: -0.028 (p < .001)

### Direct Effect
- The direct effect of FASt on adjustment (controlling for mediators) is not significant (c = -0.02, p = .29)
- This indicates **full mediation**: the effect of FASt status operates entirely through emotional distress and quality of engagement

---

## Model Fit

The structural equation model demonstrated excellent fit to the data:

| Fit Index | Value | Interpretation |
|-----------|-------|----------------|
| CFI | 0.956 | Excellent (>0.95) |
| TLI | 0.951 | Excellent (>0.95) |
| RMSEA | 0.023 | Excellent (<0.05) |
| SRMR | 0.024 | Excellent (<0.05) |

---

## Summary of Key Takeaways

1. **Credit dose matters more than FASt status alone.** The effects of accelerated dual credit are not uniform—students with more credits experience greater challenges.

2. **Two competing mechanisms.** FASt status increases emotional distress (harmful) and can either increase or decrease engagement depending on credit dose.

3. **Full mediation.** The effects of FASt status on developmental adjustment operate entirely through these psychological mechanisms, not through direct effects.

4. **A crossover pattern for engagement.** Modest dual credit experience appears beneficial for engagement, while extensive experience appears detrimental.

5. **Implications for practice.** Interventions should target students with high credit loads, focusing on reducing emotional distress and promoting meaningful campus engagement despite their advanced academic standing.

---

## Technical Notes

- **Estimator**: Maximum Likelihood with Full Information Maximum Likelihood (FIML) for missing data
- **Weighting**: Propensity Score Overlap Weights to balance treatment and control groups
- **Bootstrap**: 2,000 replicates for confidence intervals
- **Software**: R 4.5.2 with lavaan 0.6-21
