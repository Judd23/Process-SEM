#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(lavaan)
})

args <- commandArgs(trailingOnly = TRUE)
BASE_DIR <- if (length(args) >= 1 && nzchar(args[[1]])) args[[1]] else "results/fast_treat_control/official_all_RQs"

MODEL_FILE <- "r/models/mg_fast_vs_nonfast_model.R"
REP_DATA   <- file.path(BASE_DIR, "RQ1_RQ3_main", "rep_data_with_psw.csv")
OUT_DIR    <- file.path(BASE_DIR, "sensitivity_unweighted_parallel", "structural")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(MODEL_FILE)) stop("Model file not found: ", MODEL_FILE)
if (!file.exists(REP_DATA)) stop("Input data not found: ", REP_DATA)

source(MODEL_FILE)

dat <- read.csv(REP_DATA, stringsAsFactors = FALSE)

# Fit the SAME primary (parallel) model, but with NO weights and NO bootstrap.
fit <- fit_mg_fast_vs_nonfast_with_outputs(
  dat = dat,
  out_dir = OUT_DIR,
  model_type = "parallel",
  estimator = "MLR",
  missing = "fiml",
  fixed.x = TRUE,
  weight_var = NULL,
  bootstrap = 0,
  boot_ci_type = "none",
  parallel = "no",
  ncpus = 1
)

cat("Wrote unweighted sensitivity outputs to:", OUT_DIR, "\n")
