# Statistical Models

This folder contains the lavaan model specifications for the structural equation models.

## Files

### Model Definitions
- **mg_fast_vs_nonfast_model.R** — Multi-group model definitions and measurement syntax
- **pooled_sem_model_builder.R** — Single-group pooled SEM model builder

### Supporting Files
- `mc/` — Monte Carlo simulation scripts
- `utils/` — Helper functions for model fitting

## Model Overview

The study uses **conditional-process SEM** (moderated mediation) with:

- **Parallel mediators**: Emotional Distress, Quality of Engagement
- **Second-order outcome**: Developmental Adjustment (Belonging, Gains, Support, Satisfaction)
- **Propensity score overlap weights** for causal inference

## Key Syntax

All models share identical measurement syntax to ensure comparability across analyses.
