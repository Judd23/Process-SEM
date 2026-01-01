#!/usr/bin/env Rscript
# Quick test: does the model fit with simulated vs real data?

suppressPackageStartupMessages({
  library(lavaan)
})

# Source the model file
source("r/models/mg_fast_vs_nonfast_model.R")

cat("========================================\n")
cat("TEST 1: Fit with rep_data.csv (real data)\n")
cat("========================================\n")

dat <- read.csv("rep_data.csv", stringsAsFactors = FALSE)
cat("N =", nrow(dat), "\n")

# Check required columns
required <- c("x_FASt", "credit_dose_c", "XZ_c", "hgrades_c", "bparented_c", "pell", 
              "hapcl", "hprecalc13", "hchallenge_c", "cSFcareer_c", "cohort")
missing <- setdiff(required, names(dat))
cat("Missing columns:", if(length(missing)==0) "NONE" else paste(missing, collapse=", "), "\n")

# Build and fit
model_str <- build_model_fast_treat_control(dat)
fit <- tryCatch({
  lavaan::sem(
    model = model_str,
    data = dat,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    meanstructure = TRUE,
    check.gradient = FALSE,
    control = list(iter.max = 5000)
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(fit)) {
  cat("Converged:", lavInspect(fit, "converged"), "\n")
  if (lavInspect(fit, "converged")) {
    pe <- parameterEstimates(fit)
    key_params <- c("a1", "b1", "a2", "b2", "c")
    cat("\nKey parameters:\n")
    print(pe[pe$label %in% key_params, c("label", "est", "se")])
  }
}

cat("\n========================================\n")
cat("TEST 2: Fit with MC-generated data\n")
cat("========================================\n")

# Source MC script to get data generator
source("r/mc/02_mc_allRQs_pooled_mg_psw.R", local = TRUE, chdir = TRUE)

set.seed(12345)
sim_dat <- generate_one_dataset(500)
cat("N =", nrow(sim_dat), "\n")
cat("Columns (first 30):", paste(names(sim_dat)[1:30], collapse=", "), "\n")

# Check required columns
missing2 <- setdiff(required, names(sim_dat))
cat("Missing columns:", if(length(missing2)==0) "NONE" else paste(missing2, collapse=", "), "\n")

# Build and fit
model_str2 <- build_model_fast_treat_control(sim_dat)
fit2 <- tryCatch({
  lavaan::sem(
    model = model_str2,
    data = sim_dat,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    meanstructure = TRUE,
    check.gradient = FALSE,
    control = list(iter.max = 5000)
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(fit2)) {
  cat("Converged:", lavInspect(fit2, "converged"), "\n")
  if (lavInspect(fit2, "converged")) {
    pe2 <- parameterEstimates(fit2)
    key_params <- c("a1", "b1", "a2", "b2", "c")
    cat("\nKey parameters:\n")
    print(pe2[pe2$label %in% key_params, c("label", "est", "se")])
  }
}

cat("\nDone.\n")
