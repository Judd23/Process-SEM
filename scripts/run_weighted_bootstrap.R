#!/usr/bin/env Rscript
# =============================================================================
# Weighted Bootstrap for PSW-SEM with BCa Confidence Intervals
# =============================================================================
# Purpose: Run bootstrap inference for the conditional-process SEM with
#          propensity score (overlap) weights. Uses the boot package for
#          proper BCa intervals.
#
# Usage:
#   Rscript scripts/run_weighted_bootstrap.R --B 2000 --ncpus 6 --ci bca
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(boot)
  library(parallel)
})

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  idx <- which(args == flag)
  if (length(idx) == 0) return(default)
  if (idx + 1 > length(args)) return(default)
  args[idx + 1]
}

B_BOOT       <- as.integer(get_arg("--B", 2000))
NCPUS        <- as.integer(get_arg("--ncpus", parallel::detectCores() - 1))
CI_TYPE      <- get_arg("--ci", "bca")  # bca, perc, norm
CI_LEVEL     <- as.numeric(get_arg("--level", 0.95))
OUT_DIR      <- get_arg("--out", "results/fast_treat_control/official_all_RQs/bootstrap_weighted")
DATA_FILE    <- get_arg("--data", "results/fast_treat_control/official_all_RQs/RQ1_RQ3_main/rep_data_with_psw.csv")
SEED         <- as.integer(get_arg("--seed", 12345))

cat("=== Weighted Bootstrap for PSW-SEM ===\n")
cat("B:", B_BOOT, "\n")
cat("CI type:", CI_TYPE, "\n")
cat("CI level:", CI_LEVEL, "\n")
cat("CPUs:", NCPUS, "\n")
cat("Seed:", SEED, "\n")
cat("Data:", DATA_FILE, "\n")
cat("Output:", OUT_DIR, "\n\n")

# Create output directory
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Source model definitions
source("r/models/mg_fast_vs_nonfast_model.R")

# Load data
dat <- read.csv(DATA_FILE, stringsAsFactors = FALSE)
cat("Data loaded:", nrow(dat), "rows,", ncol(dat), "cols\n")

# Build interaction if needed
if (!("XZ_c" %in% names(dat))) {
  dat$XZ_c <- dat$x_FASt * dat$credit_dose_c
}

# Build model syntax (uses z_vals from data)
model_syntax <- build_model_fast_treat_control(dat)

# Parameter labels we want CIs for
PARAMS_OF_INTEREST <- c(
  # Direct effects (conditional on Z)
  "dir_z_low", "dir_z_mid", "dir_z_high",
  # Indirect via EmoDiss
  "ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
  # Indirect via QualEngag
  "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high",
  # Total effects
  "total_z_low", "total_z_mid", "total_z_high",
  # Index of moderated mediation
  "index_MM_EmoDiss", "index_MM_QualEngag"
)

# -----------------------------------------------------------------------------
# Bootstrap statistic function
# -----------------------------------------------------------------------------
# This function is called by boot() for each bootstrap replicate.
# It resamples WITH replacement and uses the PSW weights in the resampled data.
boot_statistic <- function(data, indices) {
  d <- data[indices, ]
  
  # Fit with PSW weights (from resampled data)
  fit <- tryCatch({
    lavaan::sem(
      model = model_syntax,
      data = d,
      estimator = "ML",
      missing = "fiml",
      sampling.weights = "psw",
      fixed.x = TRUE,
      meanstructure = TRUE,
      check.gradient = FALSE,
      check.lv.names = FALSE,
      se = "none",  # Don't compute SEs within bootstrap
      control = list(iter.max = 5000)
    )
  }, error = function(e) NULL)
  
  if (is.null(fit) || !lavInspect(fit, "converged")) {
    return(rep(NA_real_, length(PARAMS_OF_INTEREST)))
  }
  
  # Extract defined parameters
  pe <- parameterEstimates(fit, standardized = FALSE)
  pe_def <- pe[pe$op == ":=", ]
  
  # Match to params of interest
  est_vec <- sapply(PARAMS_OF_INTEREST, function(p) {
    idx <- which(pe_def$label == p)
    if (length(idx) == 1) pe_def$est[idx] else NA_real_
  })
  
  est_vec
}

# -----------------------------------------------------------------------------
# Original fit (point estimates)
# -----------------------------------------------------------------------------
cat("\nFitting original model for point estimates...\n")
fit_orig <- lavaan::sem(
  model = model_syntax,
  data = dat,
  estimator = "ML",
  missing = "fiml",
  sampling.weights = "psw",
  fixed.x = TRUE,
  meanstructure = TRUE,
  check.gradient = FALSE,
  check.lv.names = FALSE,
  control = list(iter.max = 10000)
)

if (!lavInspect(fit_orig, "converged")) {
  stop("Original model did not converge!")
}
cat("Original model converged.\n")

# Extract original estimates
pe_orig <- parameterEstimates(fit_orig, standardized = FALSE)
pe_def_orig <- pe_orig[pe_orig$op == ":=", ]

orig_est <- sapply(PARAMS_OF_INTEREST, function(p) {
  idx <- which(pe_def_orig$label == p)
  if (length(idx) == 1) pe_def_orig$est[idx] else NA_real_
})
orig_se <- sapply(PARAMS_OF_INTEREST, function(p) {
  idx <- which(pe_def_orig$label == p)
  if (length(idx) == 1) pe_def_orig$se[idx] else NA_real_
})

cat("\nOriginal point estimates:\n")
print(data.frame(param = PARAMS_OF_INTEREST, est = round(orig_est, 4), se = round(orig_se, 4)))

# -----------------------------------------------------------------------------
# Run bootstrap
# -----------------------------------------------------------------------------
cat("\n=== Starting Bootstrap (B =", B_BOOT, ") ===\n")
cat("This may take several hours...\n")
set.seed(SEED)

start_time <- Sys.time()

boot_out <- boot::boot(
  data = dat,
  statistic = boot_statistic,
  R = B_BOOT,
  parallel = if (NCPUS > 1) "multicore" else "no",
  ncpus = NCPUS
)

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")
cat("\nBootstrap completed in", round(as.numeric(elapsed), 1), "minutes.\n")

# Check for failed replicates
n_failed <- sum(apply(boot_out$t, 1, function(x) any(is.na(x))))
cat("Failed replicates:", n_failed, "of", B_BOOT, "(", round(100*n_failed/B_BOOT, 1), "%)\n")

# -----------------------------------------------------------------------------
# Compute confidence intervals
# -----------------------------------------------------------------------------
cat("\nComputing", toupper(CI_TYPE), "confidence intervals...\n")

ci_results <- lapply(seq_along(PARAMS_OF_INTEREST), function(i) {
  tryCatch({
    ci <- boot::boot.ci(boot_out, index = i, conf = CI_LEVEL, type = CI_TYPE)
    
    # Extract CI bounds based on type
    if (CI_TYPE == "bca") {
      bounds <- ci$bca[, 4:5]
    } else if (CI_TYPE == "perc") {
      bounds <- ci$percent[, 4:5]
    } else if (CI_TYPE == "norm") {
      bounds <- ci$normal[, 2:3]
    } else {
      bounds <- c(NA, NA)
    }
    
    data.frame(
      param = PARAMS_OF_INTEREST[i],
      est = boot_out$t0[i],
      se_boot = sd(boot_out$t[, i], na.rm = TRUE),
      ci_lower = bounds[1],
      ci_upper = bounds[2],
      ci_type = CI_TYPE,
      ci_level = CI_LEVEL,
      n_boot = B_BOOT,
      n_failed = sum(is.na(boot_out$t[, i]))
    )
  }, error = function(e) {
    data.frame(
      param = PARAMS_OF_INTEREST[i],
      est = boot_out$t0[i],
      se_boot = sd(boot_out$t[, i], na.rm = TRUE),
      ci_lower = NA,
      ci_upper = NA,
      ci_type = CI_TYPE,
      ci_level = CI_LEVEL,
      n_boot = B_BOOT,
      n_failed = sum(is.na(boot_out$t[, i]))
    )
  })
})

ci_df <- do.call(rbind, ci_results)

cat("\n=== Bootstrap Results ===\n")
print(ci_df)

# -----------------------------------------------------------------------------
# Save outputs
# -----------------------------------------------------------------------------
# Save CI results
write.csv(ci_df, file.path(OUT_DIR, "bootstrap_ci_results.csv"), row.names = FALSE)

# Save full boot object
saveRDS(boot_out, file.path(OUT_DIR, "boot_object.rds"))

# Save run log
sink(file.path(OUT_DIR, "bootstrap_run_log.txt"))
cat("Weighted Bootstrap Run Log\n")
cat("==========================\n\n")
cat("Timestamp:", as.character(Sys.time()), "\n")
cat("B:", B_BOOT, "\n")
cat("CI type:", CI_TYPE, "\n")
cat("CI level:", CI_LEVEL, "\n")
cat("CPUs:", NCPUS, "\n")
cat("Seed:", SEED, "\n")
cat("Data file:", DATA_FILE, "\n")
cat("Elapsed time:", round(as.numeric(elapsed), 1), "minutes\n")
cat("Failed replicates:", n_failed, "of", B_BOOT, "\n\n")
cat("Results:\n")
print(ci_df)
sink()

# Save original lavaan fit summary
sink(file.path(OUT_DIR, "original_fit_summary.txt"))
summary(fit_orig, fit.measures = TRUE, standardized = TRUE)
sink()

# Save full parameter estimates with asymptotic SEs for comparison
write.csv(
  pe_orig[pe_orig$op %in% c("~", "=~", ":="), c("lhs", "op", "rhs", "label", "est", "se", "z", "pvalue", "ci.lower", "ci.upper")],
  file.path(OUT_DIR, "parameterEstimates_asymptotic.csv"),
  row.names = FALSE
)

cat("\n=== Outputs saved to", OUT_DIR, "===\n")
cat("- bootstrap_ci_results.csv: Bootstrap CIs for key parameters\n")
cat("- boot_object.rds: Full boot object for further analysis\n")
cat("- bootstrap_run_log.txt: Run details\n")
cat("- original_fit_summary.txt: Full lavaan summary\n")
cat("- parameterEstimates_asymptotic.csv: All parameter estimates\n")

cat("\nDone!\n")
