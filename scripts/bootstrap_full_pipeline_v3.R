#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap-Then-Weight v3: CORRECTED Model (No credit_dose_c main effect)
# =============================================================================
# Fixes the perfect collinearity issue where credit_dose_c and XZ_c are
# perfectly correlated within the FASt group.
# 
# Rationale: credit_dose only varies for FASt students (non-FASt = 0 by definition).
# Therefore, including credit_dose_c as a separate predictor alongside XZ_c
# creates perfect collinearity. The XZ_c term alone captures the dose-response
# relationship for FASt students.
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(parallel)
})

# Configuration
args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
  return(default)
}

B <- as.integer(parse_arg(args, "--B", "500"))
NCPUS <- as.integer(parse_arg(args, "--cores", "6"))
SEED <- as.integer(parse_arg(args, "--seed", "20251230"))
OUT_DIR <- parse_arg(args, "--out", "results/fast_treat_control/official_all_RQs/bootstrap_v3")

cat("=============================================================\n")
cat("Bootstrap-Then-Weight v3 (Corrected Model)\n")
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

# Measurement syntax (shared)
MEASUREMENT_SYNTAX <- '
Belong =~ sbvalued + sbmyself + sbcommunity
Gains  =~ pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
SupportEnv =~ SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
Satisf =~ sameinst + evalexp
DevAdj =~ 1*Belong + Gains + SupportEnv + Satisf
EmoDiss =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
QualEngag =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff
'

# Build corrected model (NO credit_dose_c main effect)
build_model_corrected <- function(z_vals) {
  z_low  <- z_vals[1]
  z_mid  <- z_vals[2]
  z_high <- z_vals[3]
  
  paste0(MEASUREMENT_SYNTAX, '
# CORRECTED structural: NO credit_dose_c main effect (causes perfect collinearity)
# XZ_c captures the dose effect for FASt students only
EmoDiss ~ a1*x_FASt + a1z*XZ_c + g1*cohort +
     hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

QualEngag ~ a2*x_FASt + a2z*XZ_c + g2*cohort +
     hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

DevAdj ~ c*x_FASt + cz*XZ_c + b1*EmoDiss + b2*QualEngag + g3*cohort +
         hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

# conditional a-paths at Z values
a1_z_low  := a1 + a1z*', z_low, '
a1_z_mid  := a1 + a1z*', z_mid, '
a1_z_high := a1 + a1z*', z_high, '
a2_z_low  := a2 + a2z*', z_low, '
a2_z_mid  := a2 + a2z*', z_mid, '
a2_z_high := a2 + a2z*', z_high, '

# conditional direct effects
dir_z_low  := c + cz*', z_low, '
dir_z_mid  := c + cz*', z_mid, '
dir_z_high := c + cz*', z_high, '

# conditional indirect effects
ind_EmoDiss_z_low  := a1_z_low*b1
ind_EmoDiss_z_mid  := a1_z_mid*b1
ind_EmoDiss_z_high := a1_z_high*b1
ind_QualEngag_z_low  := a2_z_low*b2
ind_QualEngag_z_mid  := a2_z_mid*b2
ind_QualEngag_z_high := a2_z_high*b2

# total effects
total_z_low  := dir_z_low + ind_EmoDiss_z_low + ind_QualEngag_z_low
total_z_mid  := dir_z_mid + ind_EmoDiss_z_mid + ind_QualEngag_z_mid
total_z_high := dir_z_high + ind_EmoDiss_z_high + ind_QualEngag_z_high

# indices of moderated mediation
index_MM_EmoDiss   := a1z*b1
index_MM_QualEngag := a2z*b2
')
}

# Target parameters
PARAM_NAMES <- c("a1", "a1z", "a2", "a2z", "b1", "b2", "c", "cz",
                 "a1_z_low", "a1_z_mid", "a1_z_high",
                 "a2_z_low", "a2_z_mid", "a2_z_high",
                 "dir_z_low", "dir_z_mid", "dir_z_high",
                 "ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
                 "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high",
                 "total_z_low", "total_z_mid", "total_z_high",
                 "index_MM_EmoDiss", "index_MM_QualEngag")

# Function to fit one bootstrap replicate
fit_one_boot <- function(b, dat, idx_treat, idx_ctrl, n, SEED) {
  set.seed(SEED + b)
  
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
  z_vals <- c(-sd_z, 0, sd_z)
  
  # Build and fit model
  model <- build_model_corrected(z_vals)
  
  fit <- tryCatch({
    suppressWarnings(
      lavaan::sem(
        model = model,
        data = boot_dat,
        estimator = "MLR",
        fixed.x = TRUE,
        sampling.weights = "psw",
        se = "none",
        std.lv = TRUE,
        check.gradient = FALSE,
        control = list(iter.max = 500)
      )
    )
  }, error = function(e) NULL)
  
  if (is.null(fit)) return(rep(NA_real_, length(PARAM_NAMES)))
  if (!lavInspect(fit, "converged")) return(rep(NA_real_, length(PARAM_NAMES)))
  
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
z_vals_orig <- c(-sd_z_orig, 0, sd_z_orig)

model_orig <- build_model_corrected(z_vals_orig)
fit_orig <- lavaan::sem(
  model = model_orig,
  data = dat,
  estimator = "MLR",
  fixed.x = TRUE,
  sampling.weights = "psw",
  se = "robust.huber.white",
  std.lv = TRUE,
  check.gradient = FALSE,
  control = list(iter.max = 1000)
)

cat("Original model converged:", lavInspect(fit_orig, "converged"), "\n")
fm <- fitMeasures(fit_orig, c("cfi", "rmsea", "srmr"))
cat("Fit: CFI =", round(fm["cfi"], 3), "| RMSEA =", round(fm["rmsea"], 3), 
    "| SRMR =", round(fm["srmr"], 3), "\n\n")

pe_orig <- parameterEstimates(fit_orig, standardized = FALSE)
get_est_orig <- function(label) {
  row <- pe_orig[pe_orig$label == label, ]
  if (nrow(row) == 1) row$est else NA_real_
}
orig_est <- sapply(PARAM_NAMES, get_est_orig)

# Bootstrap
cat("Starting bootstrap with B =", B, "replicates...\n")
start_time <- Sys.time()

if (NCPUS > 1) {
  cat("Using", NCPUS, "cores\n")
  cl <- makeCluster(NCPUS)
  clusterExport(cl, c("dat", "idx_treat", "idx_ctrl", "n", "PS_FORMULA", 
                      "PARAM_NAMES", "fit_one_boot", "build_model_corrected",
                      "MEASUREMENT_SYNTAX", "SEED"))
  clusterEvalQ(cl, {
    suppressPackageStartupMessages(library(lavaan))
  })
  
  boot_results <- parLapply(cl, 1:B, function(b) {
    fit_one_boot(b, dat, idx_treat, idx_ctrl, n, SEED)
  })
  stopCluster(cl)
} else {
  boot_results <- lapply(1:B, function(b) {
    if (b %% 50 == 0) cat("  Completed", b, "/", B, "\n")
    fit_one_boot(b, dat, idx_treat, idx_ctrl, n, SEED)
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
write.csv(results, file.path(OUT_DIR, "bootstrap_results.csv"), row.names = FALSE)
saveRDS(list(boot_mat = boot_mat, orig_est = orig_est, B = B, n_success = n_success,
             fit_orig = fit_orig),
        file.path(OUT_DIR, "boot_object.rds"))

# Print results
sink(file.path(OUT_DIR, "bootstrap_results.txt"))
cat("=============================================================\n")
cat("Bootstrap-Then-Weight v3 Results (Corrected Model)\n")
cat("B =", B, "| Successful =", n_success, "| Time =", round(boot_time, 1), "min\n")
cat("Model: NO credit_dose_c main effect (fixes perfect collinearity)\n")
cat("=============================================================\n\n")
print(results, row.names = FALSE)
sink()

cat("\n=== KEY RESULTS ===\n")
key_params <- c("a2", "a2z", "b2", "ind_QualEngag_z_mid", "ind_QualEngag_z_high", "index_MM_QualEngag")
print(results[results$parameter %in% key_params, ], row.names = FALSE)
cat("\n* sig = 95% CI excludes zero\n")
cat("\nResults saved to:", OUT_DIR, "\n")
