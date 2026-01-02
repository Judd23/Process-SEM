#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap-Then-Weight: Serial Mediation Model
# =============================================================================
# Bootstraps the serial mediation model (EmoDiss -> QualEngag -> DevAdj)
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(parallel)
})

source("5_Statistical_Models/models/mg_fast_vs_nonfast_model.R")

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
OUT_DIR <- parse_arg(args, "--out", "4_Model_Results/Outputs/bootstrap_serial")

cat("=============================================================\n")
cat("Bootstrap-Then-Weight: Serial Mediation Model\n")
cat("B =", B, "| cores =", NCPUS, "| seed =", SEED, "\n")
cat("=============================================================\n\n")

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Load data
dat <- read.csv("1_Dataset/rep_data.csv", stringsAsFactors = FALSE)
n <- nrow(dat)
idx_treat <- which(dat$x_FASt == 1)
idx_ctrl <- which(dat$x_FASt == 0)
cat("N =", n, "| Treated =", length(idx_treat), "| Control =", length(idx_ctrl), "\n\n")

# PS formula
PS_FORMULA <- x_FASt ~ cohort + hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c

# Target parameters for serial model (includes d path and serial indirects)
PARAM_NAMES <- c("a1", "a1z", "a2", "a2z", "d", "b1", "b2", "c", "cz",
                 "a1_z_low", "a1_z_mid", "a1_z_high",
                 "a2_z_low", "a2_z_mid", "a2_z_high",
                 "dir_z_low", "dir_z_mid", "dir_z_high",
                 "ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
                 "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high",
                 "ind_serial_z_low", "ind_serial_z_mid", "ind_serial_z_high",
                 "total_z_low", "total_z_mid", "total_z_high",
                 "index_MM_EmoDiss", "index_MM_QualEngag", "index_MM_serial")

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
  
  # Recenter for this sample
  boot_dat$credit_dose_c <- boot_dat$credit_dose - mean(boot_dat$credit_dose, na.rm = TRUE)
  boot_dat$hgrades_c <- boot_dat$hgrades - mean(boot_dat$hgrades, na.rm = TRUE)
  boot_dat$bparented_c <- boot_dat$bparented - mean(boot_dat$bparented, na.rm = TRUE)
  boot_dat$hchallenge_c <- boot_dat$hchallenge - mean(boot_dat$hchallenge, na.rm = TRUE)
  boot_dat$cSFcareer_c <- boot_dat$cSFcareer - mean(boot_dat$cSFcareer, na.rm = TRUE)
  boot_dat$XZ_c <- boot_dat$x_FASt * boot_dat$credit_dose_c
  
  sd_z <- sd(boot_dat$credit_dose_c, na.rm = TRUE)
  z_vals <- c(z_low = -sd_z, z_mid = 0, z_high = sd_z)
  
  # Build and fit serial model
  model_serial <- build_model_fast_treat_control_serial(boot_dat, z_vals = z_vals)
  
  fit <- tryCatch({
    suppressWarnings(
      lavaan::sem(
        model = model_serial,
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

dat$XZ_c <- dat$x_FASt * dat$credit_dose_c
sd_z_orig <- sd(dat$credit_dose_c, na.rm = TRUE)
z_vals_orig <- c(z_low = -sd_z_orig, z_mid = 0, z_high = sd_z_orig)

model_orig <- build_model_fast_treat_control_serial(dat, z_vals = z_vals_orig)
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
cat("Original estimates computed.\n\n")

# Bootstrap
cat("Starting bootstrap with B =", B, "replicates...\n")
start_time <- Sys.time()

if (NCPUS > 1) {
  cat("Using", NCPUS, "cores\n")
  cl <- makeCluster(NCPUS)
  clusterExport(cl, c("dat", "idx_treat", "idx_ctrl", "n", "PS_FORMULA", 
                      "PARAM_NAMES", "fit_one_boot", "build_model_fast_treat_control_serial",
                      "MEASUREMENT_SYNTAX", "SEED"))
  clusterEvalQ(cl, {
    suppressPackageStartupMessages(library(lavaan))
    source("5_Statistical_Models/models/mg_fast_vs_nonfast_model.R")
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

boot_mat <- do.call(rbind, boot_results)
boot_time <- difftime(Sys.time(), start_time, units = "mins")
cat("\nBootstrap completed in", round(boot_time, 1), "minutes\n")

# Count successes
n_success <- sum(complete.cases(boot_mat))
cat("Successful replicates:", n_success, "/", B, "(", round(100*n_success/B, 1), "%)\n\n")

# Compute CIs
cat("Computing percentile 95% CIs...\n")
results <- data.frame(
  parameter = PARAM_NAMES,
  est = orig_est,
  boot_se = apply(boot_mat, 2, sd, na.rm = TRUE),
  ci_lower = apply(boot_mat, 2, quantile, probs = 0.025, na.rm = TRUE),
  ci_upper = apply(boot_mat, 2, quantile, probs = 0.975, na.rm = TRUE),
  stringsAsFactors = FALSE
)
results$sig <- with(results, (ci_lower > 0 & ci_upper > 0) | (ci_lower < 0 & ci_upper < 0))

# Save
write.csv(results, file.path(OUT_DIR, "bootstrap_serial.csv"), row.names = FALSE)
saveRDS(list(boot_mat = boot_mat, orig_est = orig_est, B = B, n_success = n_success),
        file.path(OUT_DIR, "boot_serial_object.rds"))

# Print results
sink(file.path(OUT_DIR, "bootstrap_serial.txt"))
cat("=============================================================\n")
cat("Bootstrap-Then-Weight: Serial Mediation Results\n")
cat("B =", B, "| Successful =", n_success, "| Time =", round(boot_time, 1), "min\n")
cat("=============================================================\n\n")
print(results, row.names = FALSE)
sink()

cat("\n=== KEY SERIAL MEDIATION RESULTS ===\n")
key_params <- c("d", "ind_serial_z_mid", "ind_serial_z_high", "index_MM_serial")
print(results[results$parameter %in% key_params, ], row.names = FALSE)
cat("\n* sig = 95% CI excludes zero\n")
cat("\nResults saved to:", OUT_DIR, "\n")
