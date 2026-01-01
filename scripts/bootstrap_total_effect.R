#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap-Then-Weight: Total Effect Model
# =============================================================================
# Bootstraps the total effect model (DevAdj ~ x_FASt only, no mediators)
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(parallel)
})

source("r/models/mg_fast_vs_nonfast_model.R")

# Configuration
args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
  return(default)
}

B <- as.integer(parse_arg(args, "--B", "200"))
NCPUS <- as.integer(parse_arg(args, "--cores", "6"))
SEED <- as.integer(parse_arg(args, "--seed", "20251230"))
OUT_DIR <- parse_arg(args, "--out", "results/fast_treat_control/official_all_RQs/bootstrap_total")

cat("=============================================================\n")
cat("Bootstrap-Then-Weight: Total Effect Model\n")
cat("B =", B, "| cores =", NCPUS, "| seed =", SEED, "\n")
cat("=============================================================\n\n")

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Load data
dat <- read.csv("rep_data.csv", stringsAsFactors = FALSE)
n <- nrow(dat)
idx_treat <- which(dat$x_FASt == 1)
idx_ctrl <- which(dat$x_FASt == 0)
cat("N =", n, "| Treated =", length(idx_treat), "| Control =", length(idx_ctrl), "\n\n")

# PS formula
PS_FORMULA <- x_FASt ~ cohort + hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c

# Target parameters for total effect
PARAM_NAMES <- c("c_total")

# Function to fit one bootstrap replicate
fit_one_boot <- function(b, dat, idx_treat, idx_ctrl, n) {
  # Stratified resampling
  boot_treat <- sample(idx_treat, length(idx_treat), replace = TRUE)
  boot_ctrl <- sample(idx_ctrl, length(idx_ctrl), replace = TRUE)
  boot_dat <- dat[c(boot_treat, boot_ctrl), ]
  
  # Re-estimate propensity scores
  ps_fit <- tryCatch(
    glm(PS_FORMULA, data = boot_dat, family = binomial(link = "logit")),
    error = function(e) NULL
  )
  if (is.null(ps_fit)) return(rep(NA_real_, length(PARAM_NAMES)))
  
  ps <- predict(ps_fit, type = "response")
  ps <- pmax(pmin(ps, 0.99), 0.01)
  boot_dat$psw <- ifelse(boot_dat$x_FASt == 1, 1 - ps, ps)
  boot_dat$psw <- boot_dat$psw * n / sum(boot_dat$psw)
  
  # Build and fit model
  model_total <- build_model_total_effect(boot_dat)
  
  fit <- tryCatch({
    suppressWarnings(
      lavaan::sem(
        model = model_total,
        data = boot_dat,
        estimator = "MLR",
        fixed.x = TRUE,
        sampling.weights = "psw",
        se = "none",
        check.lv.names = FALSE,
        meanstructure = TRUE,
        check.gradient = FALSE,
        std.lv = TRUE,
        control = list(iter.max = 3000)
      )
    )
  }, error = function(e) NULL)
  
  if (is.null(fit)) return(rep(NA_real_, length(PARAM_NAMES)))
  
  # Extract estimates
  pe <- tryCatch(parameterEstimates(fit, standardized = FALSE), error = function(e) NULL)
  if (is.null(pe)) return(rep(NA_real_, length(PARAM_NAMES)))
  
  get_est <- function(label) {
    row <- pe[pe$label == label, ]
    if (nrow(row) == 1) row$est else NA_real_
  }
  
  sapply(PARAM_NAMES, get_est)
}

# Original estimates
cat("Computing original estimates...\n")
ps_fit_orig <- glm(PS_FORMULA, data = dat, family = binomial(link = "logit"))
ps_orig <- predict(ps_fit_orig, type = "response")
ps_orig <- pmax(pmin(ps_orig, 0.99), 0.01)
dat$psw <- ifelse(dat$x_FASt == 1, 1 - ps_orig, ps_orig)
dat$psw <- dat$psw * n / sum(dat$psw)

model_orig <- build_model_total_effect(dat)
fit_orig <- lavaan::sem(
  model = model_orig,
  data = dat,
  estimator = "MLR",
  fixed.x = TRUE,
  sampling.weights = "psw",
  se = "robust.huber.white",
  check.lv.names = FALSE,
  meanstructure = TRUE,
  check.gradient = FALSE,
  std.lv = TRUE,
  control = list(iter.max = 5000)
)

pe_orig <- parameterEstimates(fit_orig, standardized = FALSE)
get_est_orig <- function(label) {
  row <- pe_orig[pe_orig$label == label, ]
  if (nrow(row) == 1) row$est else NA_real_
}
orig_est <- sapply(PARAM_NAMES, get_est_orig)

# Get robust SE from original fit
orig_se <- pe_orig[pe_orig$label == "c_total", "se"]
cat("Original estimates:\n")
cat("  c_total =", orig_est, "(robust SE =", orig_se, ")\n\n")

# Bootstrap
cat("Starting bootstrap with B =", B, "replicates...\n")
start_time <- Sys.time()

if (NCPUS > 1) {
  cat("Using", NCPUS, "cores\n")
  cl <- makeCluster(NCPUS)
  clusterExport(cl, c("dat", "idx_treat", "idx_ctrl", "n", "PS_FORMULA", 
                      "PARAM_NAMES", "fit_one_boot", "build_model_total_effect",
                      "MEASUREMENT_SYNTAX", "SEED"))
  clusterEvalQ(cl, {
    suppressPackageStartupMessages(library(lavaan))
    source("r/models/mg_fast_vs_nonfast_model.R")
  })
  
  boot_results <- parLapply(cl, 1:B, function(b) {
    set.seed(SEED + b)
    fit_one_boot(b, dat, idx_treat, idx_ctrl, n)
  })
  stopCluster(cl)
} else {
  boot_results <- lapply(1:B, function(b) {
    if (b %% 50 == 0) cat("  Completed", b, "/", B, "\n")
    set.seed(SEED + b)
    fit_one_boot(b, dat, idx_treat, idx_ctrl, n)
  })
}

boot_vec <- unlist(boot_results)
boot_time <- difftime(Sys.time(), start_time, units = "mins")
cat("\nBootstrap completed in", round(boot_time, 1), "minutes\n")

# Count successes
n_success <- sum(!is.na(boot_vec))
cat("Successful replicates:", n_success, "/", B, "(", round(100*n_success/B, 1), "%)\n\n")

# Compute CIs
cat("Computing percentile 95% CIs...\n")
results <- data.frame(
  parameter = PARAM_NAMES,
  est = orig_est,
  robust_se = orig_se,
  boot_se = sd(boot_vec, na.rm = TRUE),
  ci_lower = quantile(boot_vec, probs = 0.025, na.rm = TRUE),
  ci_upper = quantile(boot_vec, probs = 0.975, na.rm = TRUE),
  stringsAsFactors = FALSE
)
results$sig <- with(results, (ci_lower > 0 & ci_upper > 0) | (ci_lower < 0 & ci_upper < 0))

# Save
write.csv(results, file.path(OUT_DIR, "bootstrap_total_effect.csv"), row.names = FALSE)
saveRDS(list(boot_vec = boot_vec, orig_est = orig_est, B = B, n_success = n_success),
        file.path(OUT_DIR, "boot_total_object.rds"))

# Print results
sink(file.path(OUT_DIR, "bootstrap_total_effect.txt"))
cat("=============================================================\n")
cat("Bootstrap-Then-Weight: Total Effect Model Results\n")
cat("B =", B, "| Successful =", n_success, "| Time =", round(boot_time, 1), "min\n")
cat("=============================================================\n\n")
print(results, row.names = FALSE)
sink()

cat("\n=== TOTAL EFFECT RESULTS ===\n")
print(results, row.names = FALSE)
cat("\n* sig = 95% CI excludes zero\n")
cat("\nResults saved to:", OUT_DIR, "\n")
