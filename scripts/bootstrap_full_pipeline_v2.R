#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap-Then-Weight: Full Causal Pipeline Bootstrap
# =============================================================================
# - Parallel mediation (primary analysis)
# - Serial mediation (secondary analysis)
# - Multi-group by sex (parallel model only)
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(parallel)
  library(jsonlite)
})

source("r/models/mg_fast_vs_nonfast_model.R")

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
OUT_DIR <- parse_arg(args, "--out", "results/fast_treat_control/official_all_RQs/bootstrap_pipeline")
PROGRESS_EVERY <- as.integer(parse_arg(args, "--progress", "100"))
RUN_SERIAL <- as.integer(parse_arg(args, "--serial", "1"))  # 1 = run serial mediation
RUN_MG_SEX <- as.integer(parse_arg(args, "--mg_sex", "1"))  # 1 = run MG by sex

cat("=============================================================\n")
cat("Bootstrap-Then-Weight Pipeline\n")
cat("B =", B, "| cores =", NCPUS, "| seed =", SEED, "\n")
cat("Progress report every:", PROGRESS_EVERY, "replicates\n")
cat("Serial mediation:", ifelse(RUN_SERIAL == 1, "YES", "NO"), "\n")
cat("MG by sex:", ifelse(RUN_MG_SEX == 1, "YES", "NO"), "\n")
cat("=============================================================\n\n")

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Load data
dat <- read.csv("rep_data.csv", stringsAsFactors = FALSE)

# Recalculate credit_dose from trnsfr_cr (matches official run_all_RQs_official.R)
# This allows negative values for control students, reducing XZ_c collinearity
dat$credit_dose <- (dat$trnsfr_cr - 12) / 10
dat$credit_dose_c <- as.numeric(scale(dat$credit_dose, scale = FALSE))
dat$XZ_c <- dat$x_FASt * dat$credit_dose_c

n <- nrow(dat)
idx_treat <- which(dat$x_FASt == 1)
idx_ctrl <- which(dat$x_FASt == 0)
cat("N =", n, "| Treated =", length(idx_treat), "| Control =", length(idx_ctrl), "\n\n")

# PS formula
PS_FORMULA <- x_FASt ~ cohort + hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c

# Target parameters - PARALLEL mediation
PARAM_NAMES <- c("a1", "a1z", "a2", "a2z", "b1", "b2", "c", "cz",
                 "a1_z_low", "a1_z_mid", "a1_z_high",
                 "a2_z_low", "a2_z_mid", "a2_z_high",
                 "dir_z_low", "dir_z_mid", "dir_z_high",
                 "ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
                 "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high",
                 "total_z_low", "total_z_mid", "total_z_high",
                 "index_MM_EmoDiss", "index_MM_QualEngag")

# Target parameters - SERIAL mediation (additional)
PARAM_NAMES_SERIAL <- c("a1", "a1z", "a2", "a2z", "b1", "b2", "c", "cz", "d",
                        "a1_z_low", "a1_z_mid", "a1_z_high",
                        "a2_z_low", "a2_z_mid", "a2_z_high",
                        "dir_z_low", "dir_z_mid", "dir_z_high",
                        "ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
                        "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high",
                        "ind_serial_z_low", "ind_serial_z_mid", "ind_serial_z_high",
                        "total_z_low", "total_z_mid", "total_z_high",
                        "index_MM_EmoDiss", "index_MM_QualEngag", "index_MM_serial")

# Function to fit one bootstrap replicate
fit_one_boot <- function(b, dat, idx_treat, idx_ctrl, n, model_type = "parallel", param_names = PARAM_NAMES) {
  # Stratified resampling
  boot_treat <- sample(idx_treat, length(idx_treat), replace = TRUE)
  boot_ctrl <- sample(idx_ctrl, length(idx_ctrl), replace = TRUE)
  boot_dat <- dat[c(boot_treat, boot_ctrl), ]
  
  # Re-estimate propensity scores
  ps_fit <- tryCatch(
    glm(PS_FORMULA, data = boot_dat, family = binomial(link = "logit")),
    error = function(e) NULL
  )
  if (is.null(ps_fit)) return(rep(NA_real_, length(param_names)))
  
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
  
  # Build and fit model based on type
  model_tc <- if (model_type == "serial") {
    build_model_fast_treat_control_serial(boot_dat, z_vals = z_vals)
  } else {
    build_model_fast_treat_control(boot_dat, z_vals = z_vals)
  }
  
  fit <- tryCatch({
    suppressWarnings(
      lavaan::sem(
        model = model_tc,
        data = boot_dat,
        estimator = "ML",
        missing = "fiml",
        fixed.x = TRUE,
        sampling.weights = "psw",
        se = "none",  # We don't need SEs within bootstrap
        check.lv.names = FALSE,
        meanstructure = TRUE,
        check.gradient = FALSE,
        control = list(iter.max = 5000)
      )
    )
  }, error = function(e) NULL)
  
  if (is.null(fit)) return(rep(NA_real_, length(param_names)))
  
  # Extract estimates
  pe <- tryCatch(parameterEstimates(fit, standardized = FALSE), error = function(e) NULL)
  if (is.null(pe)) return(rep(NA_real_, length(param_names)))
  
  get_est <- function(label) {
    row <- pe[pe$label == label, ]
    if (nrow(row) == 1) row$est else NA_real_
  }
  
  sapply(param_names, get_est)
}

# Original estimates
cat("Computing original estimates...\n")
# For original: use full sample, compute PSW, fit model
ps_fit_orig <- glm(PS_FORMULA, data = dat, family = binomial(link = "logit"))
ps_orig <- predict(ps_fit_orig, type = "response")
ps_orig <- pmax(pmin(ps_orig, 0.99), 0.01)
dat$psw <- ifelse(dat$x_FASt == 1, 1 - ps_orig, ps_orig)
dat$psw <- dat$psw * n / sum(dat$psw)

dat$XZ_c <- dat$x_FASt * dat$credit_dose_c
sd_z_orig <- sd(dat$credit_dose_c, na.rm = TRUE)
z_vals_orig <- c(z_low = -sd_z_orig, z_mid = 0, z_high = sd_z_orig)

# =============================================================================
# Helper function to run bootstrap for a given model type
# =============================================================================
run_bootstrap <- function(model_type, param_names, label) {
  cat("\n", paste(rep("=", 60), collapse=""), "\n", sep="")
  cat(" ", label, " (B = ", B, ")\n", sep="")
  cat(paste(rep("=", 60), collapse=""), "\n\n", sep="")
  
  # Fit original
  if (model_type == "serial") {
    model_orig <- build_model_fast_treat_control_serial(dat, z_vals = z_vals_orig)
  } else {
    model_orig <- build_model_fast_treat_control(dat, z_vals = z_vals_orig)
  }
  
  fit_orig <- lavaan::sem(
    model = model_orig,
    data = dat,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    sampling.weights = "psw",
    se = "robust.huber.white",
    check.lv.names = FALSE,
    meanstructure = TRUE,
    check.gradient = FALSE,
    control = list(iter.max = 5000)
  )
  
  pe_orig <- parameterEstimates(fit_orig, standardized = FALSE)
  get_est_orig <- function(lbl) {
    row <- pe_orig[pe_orig$label == lbl, ]
    if (nrow(row) == 1) row$est else NA_real_
  }
  orig_est <- sapply(param_names, get_est_orig)
  cat("Original estimates computed.\n")
  
  # Bootstrap
  cat("Starting bootstrap...\n")
  start_time <- Sys.time()
  
  # Store in parent scope for cluster export
  .model_type <- model_type
  .param_names <- param_names
  
  if (NCPUS > 1) {
    cat("Using", NCPUS, "cores with progress every", PROGRESS_EVERY, "replicates\n")
    
    boot_results <- vector("list", B)
    chunks <- split(1:B, ceiling(seq_along(1:B) / PROGRESS_EVERY))
    completed <- 0
    
    for (chunk_idx in seq_along(chunks)) {
      chunk_ids <- chunks[[chunk_idx]]
      
      cl <- makeCluster(NCPUS)
      clusterExport(cl, c("dat", "idx_treat", "idx_ctrl", "n", "PS_FORMULA", 
                          ".param_names", "fit_one_boot", "build_model_fast_treat_control",
                          "build_model_fast_treat_control_serial", "SEED", ".model_type",
                          "MEASUREMENT_SYNTAX"), envir = environment())
      clusterEvalQ(cl, {
        suppressPackageStartupMessages(library(lavaan))
        source("r/models/mg_fast_vs_nonfast_model.R")
      })
      
      chunk_results <- parLapply(cl, chunk_ids, function(b) {
        set.seed(SEED + b)
        fit_one_boot(b, dat, idx_treat, idx_ctrl, n, model_type = .model_type, param_names = .param_names)
      })
      stopCluster(cl)
      
      for (i in seq_along(chunk_ids)) {
        boot_results[[chunk_ids[i]]] <- chunk_results[[i]]
      }
      
      completed <- completed + length(chunk_ids)
      elapsed <- difftime(Sys.time(), start_time, units = "mins")
      rate <- completed / as.numeric(elapsed)
      remaining <- (B - completed) / rate
      cat(sprintf("  [%s] Completed %d / %d (%.1f%%) | Elapsed: %.1f min | ETA: %.1f min\n",
                  format(Sys.time(), "%H:%M:%S"), completed, B, 100*completed/B, 
                  as.numeric(elapsed), remaining))
    }
  } else {
    boot_results <- lapply(1:B, function(b) {
      if (b %% PROGRESS_EVERY == 0) {
        elapsed <- difftime(Sys.time(), start_time, units = "mins")
        cat(sprintf("  [%s] Completed %d / %d (%.1f%%)\n", 
                    format(Sys.time(), "%H:%M:%S"), b, B, 100*b/B))
      }
      set.seed(SEED + b)
      fit_one_boot(b, dat, idx_treat, idx_ctrl, n, model_type = model_type, param_names = param_names)
    })
  }
  
  boot_mat <- do.call(rbind, boot_results)
  boot_time <- difftime(Sys.time(), start_time, units = "mins")
  cat("\nBootstrap completed in", round(boot_time, 1), "minutes\n")
  
  n_success <- sum(complete.cases(boot_mat))
  cat("Successful replicates:", n_success, "/", B, "(", round(100*n_success/B, 1), "%)\n")
  
  # Compute CIs
  results <- data.frame(
    parameter = param_names,
    est = orig_est,
    boot_se = apply(boot_mat, 2, sd, na.rm = TRUE),
    ci_lower = apply(boot_mat, 2, quantile, probs = 0.025, na.rm = TRUE),
    ci_upper = apply(boot_mat, 2, quantile, probs = 0.975, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  results$sig <- with(results, (ci_lower > 0 & ci_upper > 0) | (ci_lower < 0 & ci_upper < 0))
  
  list(results = results, boot_mat = boot_mat, orig_est = orig_est, 
       n_success = n_success, boot_time = boot_time)
}

# =============================================================================
# 1. PARALLEL MEDIATION (Primary Analysis)
# =============================================================================
parallel_out <- run_bootstrap("parallel", PARAM_NAMES, "PARALLEL MEDIATION (Primary)")

# Save parallel results
write.csv(parallel_out$results, file.path(OUT_DIR, "bootstrap_results_parallel.csv"), row.names = FALSE)
saveRDS(parallel_out, file.path(OUT_DIR, "boot_object_parallel.rds"))

sink(file.path(OUT_DIR, "bootstrap_results_parallel.txt"))
cat("=============================================================\n")
cat("Bootstrap-Then-Weight: PARALLEL Mediation\n")
cat("B =", B, "| Successful =", parallel_out$n_success, "| Time =", round(parallel_out$boot_time, 1), "min\n")
cat("=============================================================\n\n")
print(parallel_out$results, row.names = FALSE)
sink()

cat("\n=== KEY RESULTS (Parallel) ===\n")
key_params <- c("a2", "a2z", "b2", "ind_QualEngag_z_mid", "ind_QualEngag_z_high", "index_MM_QualEngag")
print(parallel_out$results[parallel_out$results$parameter %in% key_params, ], row.names = FALSE)

# =============================================================================
# 2. SERIAL MEDIATION (Secondary Analysis)
# =============================================================================
if (RUN_SERIAL == 1) {
  serial_out <- run_bootstrap("serial", PARAM_NAMES_SERIAL, "SERIAL MEDIATION (Secondary)")
  
  # Save serial results
  write.csv(serial_out$results, file.path(OUT_DIR, "bootstrap_results_serial.csv"), row.names = FALSE)
  saveRDS(serial_out, file.path(OUT_DIR, "boot_object_serial.rds"))
  
  sink(file.path(OUT_DIR, "bootstrap_results_serial.txt"))
  cat("=============================================================\n")
  cat("Bootstrap-Then-Weight: SERIAL Mediation\n")
  cat("B =", B, "| Successful =", serial_out$n_success, "| Time =", round(serial_out$boot_time, 1), "min\n")
  cat("=============================================================\n\n")
  print(serial_out$results, row.names = FALSE)
  sink()
  
  cat("\n=== KEY RESULTS (Serial) ===\n")
  key_params_serial <- c("d", "ind_serial_z_mid", "ind_serial_z_high", "index_MM_serial")
  print(serial_out$results[serial_out$results$parameter %in% key_params_serial, ], row.names = FALSE)
}

# =============================================================================
# 3. MULTI-GROUP BY SEX (Parallel model only)
# =============================================================================
if (RUN_MG_SEX == 1) {
  cat("\n", paste(rep("=", 60), collapse=""), "\n", sep="")
  cat(" MULTI-GROUP BY SEX (Parallel Mediation)\n")
  cat(paste(rep("=", 60), collapse=""), "\n\n", sep="")
  
  # Standardize sex labels
  dat$sex <- as.character(dat$sex)
  sx_low <- tolower(trimws(dat$sex))
  dat$sex[sx_low %in% c("woman", "women", "female")] <- "Female"
  dat$sex[sx_low %in% c("man", "men", "male")] <- "Male"
  
  sex_levels <- unique(dat$sex[!is.na(dat$sex)])
  cat("Sex groups:", paste(sex_levels, collapse=", "), "\n")
  for (s in sex_levels) cat("  ", s, ":", sum(dat$sex == s, na.rm=TRUE), "\n")
  
  # Run bootstrap for each sex group
  mg_results <- list()
  for (sex_grp in sex_levels) {
    cat("\n--- Processing:", sex_grp, "---\n")
    
    # Subset data
    dat_grp <- dat[dat$sex == sex_grp & !is.na(dat$sex), ]
    n_grp <- nrow(dat_grp)
    idx_treat_grp <- which(dat_grp$x_FASt == 1)
    idx_ctrl_grp <- which(dat_grp$x_FASt == 0)
    cat("N =", n_grp, "| Treated =", length(idx_treat_grp), "| Control =", length(idx_ctrl_grp), "\n")
    
    # Recompute PSW for this group
    ps_fit_grp <- glm(PS_FORMULA, data = dat_grp, family = binomial(link = "logit"))
    ps_grp <- predict(ps_fit_grp, type = "response")
    ps_grp <- pmax(pmin(ps_grp, 0.99), 0.01)
    dat_grp$psw <- ifelse(dat_grp$x_FASt == 1, 1 - ps_grp, ps_grp)
    dat_grp$psw <- dat_grp$psw * n_grp / sum(dat_grp$psw)
    
    sd_z_grp <- sd(dat_grp$credit_dose_c, na.rm = TRUE)
    z_vals_grp <- c(z_low = -sd_z_grp, z_mid = 0, z_high = sd_z_grp)
    
    # Fit original for this group
    model_grp <- build_model_fast_treat_control(dat_grp, z_vals = z_vals_grp)
    fit_grp <- tryCatch({
      lavaan::sem(
        model = model_grp,
        data = dat_grp,
        estimator = "ML",
        missing = "fiml",
        fixed.x = TRUE,
        sampling.weights = "psw",
        se = "robust.huber.white",
        check.lv.names = FALSE,
        meanstructure = TRUE,
        check.gradient = FALSE,
        control = list(iter.max = 5000)
      )
    }, error = function(e) {
      cat("  Original fit failed:", e$message, "\n")
      NULL
    })
    
    if (is.null(fit_grp)) {
      cat("  Skipping", sex_grp, "due to convergence failure\n")
      next
    }
    
    pe_grp <- parameterEstimates(fit_grp, standardized = FALSE)
    orig_est_grp <- sapply(PARAM_NAMES, function(lbl) {
      row <- pe_grp[pe_grp$label == lbl, ]
      if (nrow(row) == 1) row$est else NA_real_
    })
    
    # Bootstrap for this group
    cat("  Starting bootstrap (B =", B, ")...\n")
    start_time_grp <- Sys.time()
    
    boot_results_grp <- vector("list", B)
    chunks <- split(1:B, ceiling(seq_along(1:B) / PROGRESS_EVERY))
    completed <- 0
    
    for (chunk_idx in seq_along(chunks)) {
      chunk_ids <- chunks[[chunk_idx]]
      
      cl <- makeCluster(NCPUS)
      clusterExport(cl, c("dat_grp", "idx_treat_grp", "idx_ctrl_grp", "n_grp", "PS_FORMULA", 
                          "PARAM_NAMES", "fit_one_boot", "build_model_fast_treat_control",
                          "build_model_fast_treat_control_serial", "SEED",
                          "MEASUREMENT_SYNTAX"), envir = environment())
      clusterEvalQ(cl, {
        suppressPackageStartupMessages(library(lavaan))
        source("r/models/mg_fast_vs_nonfast_model.R")
      })
      
      chunk_results <- parLapply(cl, chunk_ids, function(b) {
        set.seed(SEED + b + 10000)  # Different seed offset for MG
        fit_one_boot(b, dat_grp, idx_treat_grp, idx_ctrl_grp, n_grp, 
                     model_type = "parallel", param_names = PARAM_NAMES)
      })
      stopCluster(cl)
      
      for (i in seq_along(chunk_ids)) {
        boot_results_grp[[chunk_ids[i]]] <- chunk_results[[i]]
      }
      
      completed <- completed + length(chunk_ids)
      elapsed <- difftime(Sys.time(), start_time_grp, units = "mins")
      rate <- completed / as.numeric(elapsed)
      remaining <- (B - completed) / rate
      cat(sprintf("    [%s] %s: %d / %d (%.1f%%) | ETA: %.1f min\n",
                  format(Sys.time(), "%H:%M:%S"), sex_grp, completed, B, 
                  100*completed/B, remaining))
    }
    
    boot_mat_grp <- do.call(rbind, boot_results_grp)
    boot_time_grp <- difftime(Sys.time(), start_time_grp, units = "mins")
    n_success_grp <- sum(complete.cases(boot_mat_grp))
    cat("  Completed in", round(boot_time_grp, 1), "min | Success:", n_success_grp, "/", B, "\n")
    
    # Compute CIs
    results_grp <- data.frame(
      parameter = PARAM_NAMES,
      est = orig_est_grp,
      boot_se = apply(boot_mat_grp, 2, sd, na.rm = TRUE),
      ci_lower = apply(boot_mat_grp, 2, quantile, probs = 0.025, na.rm = TRUE),
      ci_upper = apply(boot_mat_grp, 2, quantile, probs = 0.975, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
    results_grp$sig <- with(results_grp, (ci_lower > 0 & ci_upper > 0) | (ci_lower < 0 & ci_upper < 0))
    results_grp$group <- sex_grp
    
    mg_results[[sex_grp]] <- list(results = results_grp, n_success = n_success_grp, 
                                   boot_time = boot_time_grp)
    
    # Save group results
    write.csv(results_grp, file.path(OUT_DIR, paste0("bootstrap_results_sex_", sex_grp, ".csv")), 
              row.names = FALSE)
  }
  
  # Combine MG results
  if (length(mg_results) > 0) {
    all_mg <- do.call(rbind, lapply(mg_results, function(x) x$results))
    write.csv(all_mg, file.path(OUT_DIR, "bootstrap_results_mg_sex.csv"), row.names = FALSE)
    saveRDS(mg_results, file.path(OUT_DIR, "boot_object_mg_sex.rds"))
    
    cat("\n=== KEY RESULTS BY SEX ===\n")
    key_params_mg <- c("ind_QualEngag_z_mid", "index_MM_QualEngag")
    for (sex_grp in names(mg_results)) {
      cat("\n", sex_grp, ":\n")
      print(mg_results[[sex_grp]]$results[mg_results[[sex_grp]]$results$parameter %in% key_params_mg, 
                                           c("parameter", "est", "ci_lower", "ci_upper", "sig")], 
            row.names = FALSE)
    }
  }
}

cat("\n* sig = 95% CI excludes zero\n")
cat("\nAll results saved to:", OUT_DIR, "\n")

# =============================================================================
# Generate Standards Compliance Visualizations
# =============================================================================
cat("\n=== Generating Standards Compliance Visualizations ===\n")

# Create JSON data file for visualization script
viz_data <- list(
  n = n,
  bootstrap_b = B,
  bootstrap_converged = parallel_out$n_success,
  bootstrap_pct = 100 * parallel_out$n_success / B
)
viz_data_file <- file.path(OUT_DIR, "viz_data.json")
writeLines(jsonlite::toJSON(viz_data, auto_unbox = TRUE), viz_data_file)

viz_cmd <- sprintf(
  "python3 scripts/plot_standards_comparison.py --out '%s' --data '%s'",
  OUT_DIR, viz_data_file
)
viz_result <- system(viz_cmd, intern = FALSE)
if (viz_result == 0) {
  cat("Standards visualizations saved to:", OUT_DIR, "\n")
} else {
  warning("Standards visualization script failed (exit code ", viz_result, ")")
}

# =============================================================================
# Build Bootstrap Tables (DOCX)
# =============================================================================
cat("\n=== Building Bootstrap Tables ===\n")

# The build_bootstrap_tables.py script expects results in bootstrap_pipeline or bootstrap_v3 subfolder
# Since OUT_DIR already points to bootstrap_pipeline, we pass the parent directory
parent_dir <- dirname(OUT_DIR)
tables_cmd <- sprintf(
  "python3 scripts/build_bootstrap_tables.py --results_dir '%s'",
  parent_dir
)
tables_result <- system(tables_cmd, intern = FALSE)
if (tables_result == 0) {
  # Move the generated docx into OUT_DIR for consistency
  docx_path <- file.path(parent_dir, "Bootstrap_Tables_v3.docx")
  if (file.exists(docx_path)) {
    file.copy(docx_path, file.path(OUT_DIR, "Bootstrap_Tables.docx"), overwrite = TRUE)
    file.remove(docx_path)
    cat("Bootstrap tables saved to:", file.path(OUT_DIR, "Bootstrap_Tables.docx"), "\n")
  }
} else {
  warning("Bootstrap tables script failed (exit code ", tables_result, ")")
}

cat("\n✅ Bootstrap pipeline complete!\n")
