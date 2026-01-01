#!/usr/bin/env Rscript
# =============================================================================
# Bootstrap-Then-Weight: Full Causal Pipeline Bootstrap
# =============================================================================
# Bootstraps the ENTIRE causal inference pipeline:
#   1. Resample units (with replacement)
#   2. Re-estimate propensity score model
#   3. Recompute overlap weights
#   4. Refit SEM with new weights
#   5. Store target parameters
#
# NEW: Multi-group invariance mode (--mode mg_invariance)
#   - 3-group model by credit dose: no_credits, de_1_11, fast_12plus
#   - Measurement invariance sequence (configural → metric → scalar)
#   - Structural invariance tests
#   - Latent mean comparisons (if scalar/partial scalar holds)
#
# References:
#   - Abadie & Imbens (2008, 2016): Bootstrap with estimated propensity scores
#   - Austin & Stuart (2015): PSW variance estimation
#   - Efron & Hastie (2016): Bootstrap and modern inference
#   - Imai, King, & Stuart (2008): Matching and weighting estimators
#   - Cheung & Rensvold (2002): Evaluating MI criteria
#   - Chen (2007): Sensitivity of fit indices
# =============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(parallel)
  library(boot)
})

# Source model definitions
source("r/models/mg_fast_vs_nonfast_model.R")

# =============================================================================
# CONFIGURATION
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)

# Parse command line arguments
parse_arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) > 0 && idx < length(args)) {
    return(args[idx + 1])
  }
  return(default)
}

B <- as.integer(parse_arg(args, "--B", "500"))
NCPUS <- as.integer(parse_arg(args, "--cores", "6"))
SEED <- as.integer(parse_arg(args, "--seed", "20251230"))
DATA_FILE <- parse_arg(args, "--data", "rep_data.csv")
OUT_DIR <- parse_arg(args, "--out", "results/fast_treat_control/official_all_RQs/bootstrap_pipeline")
CI_TYPE <- parse_arg(args, "--ci", "bca")  # bca, perc, or norm
MODE <- parse_arg(args, "--mode", "bootstrap_psw")  # bootstrap_psw or mg_invariance
ESTIMATOR <- parse_arg(args, "--estimator", "MLR")  # Estimator for mg_invariance mode

# Validate mode
if (!MODE %in% c("bootstrap_psw", "mg_invariance")) {
  stop("Invalid --mode. Must be 'bootstrap_psw' or 'mg_invariance'")
}

cat("=============================================================\n")
if (MODE == "mg_invariance") {
  cat("Multi-Group Invariance Analysis Pipeline\n")
} else {
  cat("Bootstrap-Then-Weight: Full Causal Pipeline\n")
}
cat("=============================================================\n")
cat("Mode:", MODE, "\n")
if (MODE == "bootstrap_psw") {
  cat("B =", B, "| cores =", NCPUS, "| seed =", SEED, "\n")
  cat("CI type:", CI_TYPE, "\n")
} else {
  cat("Estimator:", ESTIMATOR, "\n")
  cat("Seed:", SEED, "\n")
}
cat("Data:", DATA_FILE, "\n")
cat("Output:", OUT_DIR, "\n")
cat("=============================================================\n\n")

set.seed(SEED)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# LOAD DATA
# =============================================================================
dat_raw <- read.csv(DATA_FILE, stringsAsFactors = FALSE)

# Get all variables used in analysis
all_vars <- c("x_FASt", "credit_dose", "trnsfr_cr", "cohort", "hgrades", "bparented", "pell",
              "hapcl", "hprecalc13", "hchallenge", "cSFcareer",
              "sbvalued", "sbmyself", "sbcommunity",
              "pganalyze", "pgthink", "pgwork", "pgvalues", "pgprobsolve",
              "SEacademic", "SEwellness", "SEnonacad", "SEactivities", "SEdiverse",
              "sameinst", "evalexp",
              "MHWdacad", "MHWdlonely", "MHWdmental", "MHWdexhaust", "MHWdsleep", "MHWdfinancial",
              "QIadmin", "QIstudent", "QIadvisor", "QIfaculty", "QIstaff")

# Check which variables exist in data
missing_vars <- setdiff(all_vars, names(dat_raw))
if (length(missing_vars) > 0) {
  # Allow trnsfr_cr to be missing for bootstrap_psw mode
  if (MODE == "mg_invariance" && "trnsfr_cr" %in% missing_vars) {
    stop("ERROR: trnsfr_cr required for mg_invariance mode but not found in data.")
  }
  # Remove missing optional variables
  all_vars <- intersect(all_vars, names(dat_raw))
  cat("Note: Some variables not found, using:", length(all_vars), "variables\n")
}

# Use complete cases only for bootstrap stability
dat <- dat_raw[complete.cases(dat_raw[, all_vars]), ]
n <- nrow(dat)
cat("Using", n, "complete cases (from", nrow(dat_raw), "total)\n")

# =============================================================================
# BUG FIX A: Create centered covariates BEFORE any PS model or XZ_c
# =============================================================================
# Center continuous variables on the full analytic sample
dat$credit_dose_c <- dat$credit_dose - mean(dat$credit_dose, na.rm = TRUE)
dat$hgrades_c <- dat$hgrades - mean(dat$hgrades, na.rm = TRUE)
dat$bparented_c <- dat$bparented - mean(dat$bparented, na.rm = TRUE)
dat$hchallenge_c <- dat$hchallenge - mean(dat$hchallenge, na.rm = TRUE)
dat$cSFcareer_c <- dat$cSFcareer - mean(dat$cSFcareer, na.rm = TRUE)

# Now create interaction term (after credit_dose_c exists)
dat$XZ_c <- dat$x_FASt * dat$credit_dose_c

cat("Centered variables created: credit_dose_c, hgrades_c, bparented_c, hchallenge_c, cSFcareer_c\n")
cat("Interaction XZ_c created\n\n")

# =============================================================================
# MULTI-GROUP INVARIANCE MODE (NEW)
# =============================================================================
if (MODE == "mg_invariance") {
  cat("=============================================================\n")
  cat("MULTI-GROUP INVARIANCE ANALYSIS\n")
  cat("=============================================================\n\n")
  
  # -------------------------------------------------------------------------
  # C1: Create 3-group variable DE_group based on trnsfr_cr
  # -------------------------------------------------------------------------
  # Check if trnsfr_cr exists; if not, try to derive from available variables
  if (!("trnsfr_cr" %in% names(dat))) {
    cat("WARNING: trnsfr_cr not found. Attempting to derive from credit_dose and x_FASt...\n")
    # If credit_dose is scaled differently, we need to reconstruct
    # Based on x_FASt definition: x_FASt = 1 if trnsfr_cr >= 12
    stop("ERROR: trnsfr_cr column not found in data. Cannot create DE_group.")
  }
  
  dat$DE_group <- NA_integer_
  dat$DE_group[dat$trnsfr_cr == 0] <- 0L
  dat$DE_group[dat$trnsfr_cr >= 1 & dat$trnsfr_cr <= 11] <- 1L
  dat$DE_group[dat$trnsfr_cr >= 12] <- 2L
  
  # Check for NAs
  if (any(is.na(dat$DE_group))) {
    cat("ERROR: NA values found in DE_group.\n")
    cat("trnsfr_cr summary:\n")
    print(summary(dat$trnsfr_cr))
    cat("trnsfr_cr values with NA DE_group:\n")
    print(head(dat$trnsfr_cr[is.na(dat$DE_group)], 20))
    stop("ERROR: NA values found in DE_group. Check trnsfr_cr variable.")
  }
  
  # Convert to factor with labels
  dat$DE_group <- factor(dat$DE_group, 
                         levels = c(0, 1, 2),
                         labels = c("no_credits", "de_1_11", "fast_12plus"))
  
  # Write group sizes
  group_sizes <- table(dat$DE_group)
  cat("Group sizes:\n")
  print(group_sizes)
  cat("\n")
  
  writeLines(
    c("Multi-Group Analysis: Group Sizes",
      paste(rep("=", 50), collapse = ""),
      "",
      capture.output(print(group_sizes)),
      "",
      paste("Total N:", nrow(dat))),
    file.path(OUT_DIR, "group_sizes.txt")
  )
  
  # -------------------------------------------------------------------------
  # C2: Measurement model syntax (exact project specification)
  # -------------------------------------------------------------------------
  # Using exact factors and indicators from MEASUREMENT_SYNTAX
  MEAS_MODEL <- '
    # First-order factors for DevAdj hierarchy
    Belong =~ sbvalued + sbmyself + sbcommunity
    Gains  =~ pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
    SupportEnv =~ SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
    Satisf =~ sameinst + evalexp
    
    # Second-order factor (Belong as marker)
    DevAdj =~ 1*Belong + Gains + SupportEnv + Satisf
    
    # Mediator factors (marker variable identification)
    EmoDiss =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
    QualEngag =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff
  '
  
  # -------------------------------------------------------------------------
  # Helper function: Extract fit indices
  # -------------------------------------------------------------------------
  get_fit_indices <- function(fit, model_name) {
    fm <- fitMeasures(fit, c("chisq", "df", "pvalue", "cfi", "tli", 
                              "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr"))
    data.frame(
      model = model_name,
      chisq = fm["chisq"],
      df = fm["df"],
      pvalue = fm["pvalue"],
      CFI = fm["cfi"],
      TLI = fm["tli"],
      RMSEA = fm["rmsea"],
      RMSEA_CI_lower = fm["rmsea.ci.lower"],
      RMSEA_CI_upper = fm["rmsea.ci.upper"],
      SRMR = fm["srmr"],
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  }
  
  # -------------------------------------------------------------------------
  # Helper function: Diagnostics for convergence issues
  # -------------------------------------------------------------------------
  write_diagnostics <- function(dat, group_var = "DE_group") {
    diag_file <- file.path(OUT_DIR, "convergence_diagnostics.txt")
    sink(diag_file)
    cat("Convergence Diagnostics\n")
    cat(paste(rep("=", 60), collapse = ""), "\n\n")
    
    cat("1. Group Sizes:\n")
    print(table(dat[[group_var]]))
    cat("\n")
    
    # Check for near-zero variance indicators within group
    cat("2. Near-Zero Variance Check (SD < 0.1 within group):\n")
    indicators <- c("sbvalued", "sbmyself", "sbcommunity",
                    "pganalyze", "pgthink", "pgwork", "pgvalues", "pgprobsolve",
                    "SEacademic", "SEwellness", "SEnonacad", "SEactivities", "SEdiverse",
                    "sameinst", "evalexp",
                    "MHWdacad", "MHWdlonely", "MHWdmental", "MHWdexhaust", "MHWdsleep", "MHWdfinancial",
                    "QIadmin", "QIstudent", "QIadvisor", "QIfaculty", "QIstaff")
    
    for (g in levels(dat[[group_var]])) {
      g_dat <- dat[dat[[group_var]] == g, indicators]
      sds <- sapply(g_dat, sd, na.rm = TRUE)
      low_var <- names(sds)[sds < 0.1]
      if (length(low_var) > 0) {
        cat(sprintf("  Group '%s': %s\n", g, paste(low_var, collapse = ", ")))
      }
    }
    cat("\n")
    
    cat("3. Missingness by Group:\n")
    for (g in levels(dat[[group_var]])) {
      g_dat <- dat[dat[[group_var]] == g, indicators]
      miss_pct <- 100 * sum(is.na(g_dat)) / (nrow(g_dat) * ncol(g_dat))
      cat(sprintf("  Group '%s': %.2f%% missing\n", g, miss_pct))
    }
    cat("\n")
    
    sink()
    cat("Diagnostics written to:", diag_file, "\n")
  }
  
  # -------------------------------------------------------------------------
  # C3: Measurement Invariance Sequence
  # -------------------------------------------------------------------------
  cat("Fitting measurement invariance sequence...\n\n")
  
  fit_results <- list()
  fit_indices <- data.frame()
  
  # Step A: Configural invariance
  cat("Step A: Configural invariance (no equality constraints)...\n")
  fit_config <- tryCatch({
    lavaan::cfa(
      model = MEAS_MODEL,
      data = dat,
      group = "DE_group",
      estimator = ESTIMATOR,
      meanstructure = TRUE,
      fixed.x = TRUE,
      std.lv = TRUE,
      control = list(iter.max = 5000)
    )
  }, error = function(e) {
    cat("ERROR in configural model:", conditionMessage(e), "\n")
    write_diagnostics(dat)
    NULL
  }, warning = function(w) {
    cat("WARNING in configural model:", conditionMessage(w), "\n")
    write_diagnostics(dat)
    invokeRestart("muffleWarning")
  })
  
  if (is.null(fit_config) || !lavInspect(fit_config, "converged")) {
    cat("ERROR: Configural model did not converge. Check diagnostics.\n")
    write_diagnostics(dat)
    quit(save = "no", status = 1)
  }
  
  fit_results$configural <- fit_config
  fit_indices <- rbind(fit_indices, get_fit_indices(fit_config, "A_Configural"))
  cat("  CFI =", round(fitMeasures(fit_config, "cfi"), 3), 
      "| RMSEA =", round(fitMeasures(fit_config, "rmsea"), 3), "\n\n")
  
  # Step B: Metric invariance
  cat("Step B: Metric invariance (loadings equal)...\n")
  fit_metric <- tryCatch({
    lavaan::cfa(
      model = MEAS_MODEL,
      data = dat,
      group = "DE_group",
      group.equal = "loadings",
      estimator = ESTIMATOR,
      meanstructure = TRUE,
      fixed.x = TRUE,
      std.lv = TRUE,
      control = list(iter.max = 5000)
    )
  }, error = function(e) {
    cat("ERROR in metric model:", conditionMessage(e), "\n")
    write_diagnostics(dat)
    NULL
  })
  
  if (is.null(fit_metric) || !lavInspect(fit_metric, "converged")) {
    cat("ERROR: Metric model did not converge.\n")
    write_diagnostics(dat)
    quit(save = "no", status = 1)
  }
  
  fit_results$metric <- fit_metric
  fit_indices <- rbind(fit_indices, get_fit_indices(fit_metric, "B_Metric"))
  cat("  CFI =", round(fitMeasures(fit_metric, "cfi"), 3), 
      "| RMSEA =", round(fitMeasures(fit_metric, "rmsea"), 3), "\n")
  
  # Compute delta CFI and delta RMSEA
  delta_cfi_AB <- fitMeasures(fit_config, "cfi") - fitMeasures(fit_metric, "cfi")
  delta_rmsea_AB <- fitMeasures(fit_metric, "rmsea") - fitMeasures(fit_config, "rmsea")
  cat("  ΔCFI =", round(delta_cfi_AB, 4), "| ΔRMSEA =", round(delta_rmsea_AB, 4), "\n\n")
  
  # Step C: Scalar invariance
  cat("Step C: Scalar invariance (loadings + intercepts equal)...\n")
  fit_scalar <- tryCatch({
    lavaan::cfa(
      model = MEAS_MODEL,
      data = dat,
      group = "DE_group",
      group.equal = c("loadings", "intercepts"),
      estimator = ESTIMATOR,
      meanstructure = TRUE,
      fixed.x = TRUE,
      std.lv = TRUE,
      control = list(iter.max = 5000)
    )
  }, error = function(e) {
    cat("ERROR in scalar model:", conditionMessage(e), "\n")
    write_diagnostics(dat)
    NULL
  })
  
  if (is.null(fit_scalar) || !lavInspect(fit_scalar, "converged")) {
    cat("ERROR: Scalar model did not converge.\n")
    write_diagnostics(dat)
    quit(save = "no", status = 1)
  }
  
  fit_results$scalar <- fit_scalar
  fit_indices <- rbind(fit_indices, get_fit_indices(fit_scalar, "C_Scalar"))
  cat("  CFI =", round(fitMeasures(fit_scalar, "cfi"), 3), 
      "| RMSEA =", round(fitMeasures(fit_scalar, "rmsea"), 3), "\n")
  
  delta_cfi_BC <- fitMeasures(fit_metric, "cfi") - fitMeasures(fit_scalar, "cfi")
  delta_rmsea_BC <- fitMeasures(fit_scalar, "rmsea") - fitMeasures(fit_metric, "rmsea")
  cat("  ΔCFI =", round(delta_cfi_BC, 4), "| ΔRMSEA =", round(delta_rmsea_BC, 4), "\n\n")
  
  # Add delta columns to fit_indices
  fit_indices$delta_CFI <- c(NA, delta_cfi_AB, delta_cfi_BC)
  fit_indices$delta_RMSEA <- c(NA, delta_rmsea_AB, delta_rmsea_BC)
  
  # Write initial invariance results
  write.csv(fit_indices, file.path(OUT_DIR, "invariance_fit_indices.csv"), row.names = FALSE)
  
  # -------------------------------------------------------------------------
  # Partial scalar if needed (ΔCFI > 0.01 or ΔRMSEA > 0.015)
  # -------------------------------------------------------------------------
  scalar_acceptable <- (delta_cfi_BC <= 0.01) && (delta_rmsea_BC <= 0.015)
  partial_scalar_success <- FALSE
  freed_intercepts <- character(0)
  
  if (!scalar_acceptable) {
    cat("Scalar invariance not acceptable. Attempting partial scalar...\n")
    
    current_fit <- fit_scalar
    current_partial <- character(0)
    max_freed <- 6
    
    for (iter in 1:max_freed) {
      # Get modification indices for intercepts only
      mi <- modindices(current_fit, sort = TRUE)
      mi_intercepts <- mi[mi$op == "~1" & mi$group == 1, ]  # Only observed intercepts
      
      # Filter to only indicator variables
      indicators <- c("sbvalued", "sbmyself", "sbcommunity",
                      "pganalyze", "pgthink", "pgwork", "pgvalues", "pgprobsolve",
                      "SEacademic", "SEwellness", "SEnonacad", "SEactivities", "SEdiverse",
                      "sameinst", "evalexp",
                      "MHWdacad", "MHWdlonely", "MHWdmental", "MHWdexhaust", "MHWdsleep", "MHWdfinancial",
                      "QIadmin", "QIstudent", "QIadvisor", "QIfaculty", "QIstaff")
      mi_intercepts <- mi_intercepts[mi_intercepts$lhs %in% indicators, ]
      
      if (nrow(mi_intercepts) == 0) {
        cat("  No more intercepts to free.\n")
        break
      }
      
      # Free the intercept with highest MI
      top_mi <- mi_intercepts[1, ]
      freed_item <- paste0(top_mi$lhs, "~1")
      cat(sprintf("  Iteration %d: Freeing %s (MI = %.2f)\n", iter, freed_item, top_mi$mi))
      
      current_partial <- c(current_partial, freed_item)
      
      # Refit with partial constraints
      fit_partial <- tryCatch({
        lavaan::cfa(
          model = MEAS_MODEL,
          data = dat,
          group = "DE_group",
          group.equal = c("loadings", "intercepts"),
          group.partial = current_partial,
          estimator = ESTIMATOR,
          meanstructure = TRUE,
          fixed.x = TRUE,
          std.lv = TRUE,
          control = list(iter.max = 5000)
        )
      }, error = function(e) NULL)
      
      if (is.null(fit_partial) || !lavInspect(fit_partial, "converged")) {
        cat("  Partial scalar did not converge.\n")
        break
      }
      
      current_fit <- fit_partial
      
      # Check if acceptable now
      new_delta_cfi <- fitMeasures(fit_metric, "cfi") - fitMeasures(fit_partial, "cfi")
      new_delta_rmsea <- fitMeasures(fit_partial, "rmsea") - fitMeasures(fit_metric, "rmsea")
      
      cat(sprintf("    ΔCFI = %.4f | ΔRMSEA = %.4f\n", new_delta_cfi, new_delta_rmsea))
      
      if (new_delta_cfi <= 0.01 && new_delta_rmsea <= 0.015) {
        cat("  Partial scalar acceptable!\n")
        partial_scalar_success <- TRUE
        freed_intercepts <- current_partial
        fit_results$partial_scalar <- fit_partial
        
        # Add to fit indices
        fit_indices_final <- fit_indices
        fit_indices_final <- rbind(fit_indices_final, 
                                    get_fit_indices(fit_partial, paste0("C_Partial_Scalar_", iter, "_freed")))
        fit_indices_final$delta_CFI[nrow(fit_indices_final)] <- new_delta_cfi
        fit_indices_final$delta_RMSEA[nrow(fit_indices_final)] <- new_delta_rmsea
        
        write.csv(fit_indices_final, file.path(OUT_DIR, "invariance_fit_indices_final.csv"), row.names = FALSE)
        break
      }
    }
    
    if (length(freed_intercepts) > 0) {
      writeLines(freed_intercepts, file.path(OUT_DIR, "partial_scalar_freed_intercepts.txt"))
    }
  } else {
    cat("Full scalar invariance is acceptable.\n")
    partial_scalar_success <- TRUE  # Full scalar counts as success
  }
  
  cat("\n")
  
  # -------------------------------------------------------------------------
  # C4: Structural Model Invariance Tests
  # -------------------------------------------------------------------------
  cat("=============================================================\n")
  cat("STRUCTURAL INVARIANCE TESTS\n")
  cat("=============================================================\n\n")
  
  # Determine which measurement constraints to use
  if (scalar_acceptable) {
    struct_group_equal <- c("loadings", "intercepts")
    struct_group_partial <- NULL
    cat("Using full scalar constraints for structural models.\n\n")
  } else if (partial_scalar_success && length(freed_intercepts) > 0) {
    struct_group_equal <- c("loadings", "intercepts")
    struct_group_partial <- freed_intercepts
    cat("Using partial scalar constraints for structural models.\n")
    cat("Freed intercepts:", paste(freed_intercepts, collapse = ", "), "\n\n")
  } else {
    struct_group_equal <- "loadings"
    struct_group_partial <- NULL
    cat("WARNING: Using metric constraints only. Latent mean comparisons not valid.\n\n")
  }
  
  # Structural model syntax
  STRUCT_MODEL_FREE <- paste0(MEAS_MODEL, '
    # Structural paths (free across groups)
    DevAdj ~ c(b1_g0, b1_g1, b1_g2)*EmoDiss + c(b2_g0, b2_g1, b2_g2)*QualEngag
    
    # Allow mediator covariance
    EmoDiss ~~ QualEngag
  ')
  
  STRUCT_MODEL_B1_EQUAL <- paste0(MEAS_MODEL, '
    # b1 constrained equal, b2 free
    DevAdj ~ c(b1, b1, b1)*EmoDiss + c(b2_g0, b2_g1, b2_g2)*QualEngag
    EmoDiss ~~ QualEngag
  ')
  
  STRUCT_MODEL_B2_EQUAL <- paste0(MEAS_MODEL, '
    # b1 free, b2 constrained equal
    DevAdj ~ c(b1_g0, b1_g1, b1_g2)*EmoDiss + c(b2, b2, b2)*QualEngag
    EmoDiss ~~ QualEngag
  ')
  
  STRUCT_MODEL_BOTH_EQUAL <- paste0(MEAS_MODEL, '
    # Both b1 and b2 constrained equal
    DevAdj ~ c(b1, b1, b1)*EmoDiss + c(b2, b2, b2)*QualEngag
    EmoDiss ~~ QualEngag
  ')
  
  # Fit structural models
  cat("Fitting structural model with free paths...\n")
  fit_struct_free <- lavaan::sem(
    model = STRUCT_MODEL_FREE,
    data = dat,
    group = "DE_group",
    group.equal = struct_group_equal,
    group.partial = struct_group_partial,
    estimator = ESTIMATOR,
    meanstructure = TRUE,
    fixed.x = TRUE,
    std.lv = TRUE,
    control = list(iter.max = 5000)
  )
  
  cat("Fitting structural model with b1 constrained equal...\n")
  fit_struct_b1eq <- lavaan::sem(
    model = STRUCT_MODEL_B1_EQUAL,
    data = dat,
    group = "DE_group",
    group.equal = struct_group_equal,
    group.partial = struct_group_partial,
    estimator = ESTIMATOR,
    meanstructure = TRUE,
    fixed.x = TRUE,
    std.lv = TRUE,
    control = list(iter.max = 5000)
  )
  
  cat("Fitting structural model with b2 constrained equal...\n")
  fit_struct_b2eq <- lavaan::sem(
    model = STRUCT_MODEL_B2_EQUAL,
    data = dat,
    group = "DE_group",
    group.equal = struct_group_equal,
    group.partial = struct_group_partial,
    estimator = ESTIMATOR,
    meanstructure = TRUE,
    fixed.x = TRUE,
    std.lv = TRUE,
    control = list(iter.max = 5000)
  )
  
  cat("Fitting structural model with both constrained equal...\n")
  fit_struct_both <- lavaan::sem(
    model = STRUCT_MODEL_BOTH_EQUAL,
    data = dat,
    group = "DE_group",
    group.equal = struct_group_equal,
    group.partial = struct_group_partial,
    estimator = ESTIMATOR,
    meanstructure = TRUE,
    fixed.x = TRUE,
    std.lv = TRUE,
    control = list(iter.max = 5000)
  )
  
  # LRT comparisons
  cat("\nLikelihood Ratio Tests:\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  
  lrt_results <- list()
  
  # Test b1 equality
  lrt_b1 <- lavTestLRT(fit_struct_free, fit_struct_b1eq)
  lrt_results$b1_test <- lrt_b1
  cat("\nb1 (EmoDiss -> DevAdj) equality test:\n")
  print(lrt_b1)
  
  # Test b2 equality
  lrt_b2 <- lavTestLRT(fit_struct_free, fit_struct_b2eq)
  lrt_results$b2_test <- lrt_b2
  cat("\nb2 (QualEngag -> DevAdj) equality test:\n")
  print(lrt_b2)
  
  # Test both equality
  lrt_both <- lavTestLRT(fit_struct_free, fit_struct_both)
  lrt_results$both_test <- lrt_both
  cat("\nBoth paths equality test:\n")
  print(lrt_both)
  
  # Write LRT results
  sink(file.path(OUT_DIR, "structural_invariance_LRT.txt"))
  cat("Structural Invariance: Likelihood Ratio Tests\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")
  cat("Reference model: Free structural paths across groups\n")
  cat("Measurement constraints:", paste(struct_group_equal, collapse = " + "), "\n")
  if (!is.null(struct_group_partial)) {
    cat("Freed intercepts:", paste(struct_group_partial, collapse = ", "), "\n")
  }
  cat("\n")
  
  cat("Test 1: b1 (EmoDiss -> DevAdj) equal across groups\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  print(lrt_b1)
  cat("\n")
  
  cat("Test 2: b2 (QualEngag -> DevAdj) equal across groups\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  print(lrt_b2)
  cat("\n")
  
  cat("Test 3: Both b1 and b2 equal across groups\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  print(lrt_both)
  sink()
  
  # -------------------------------------------------------------------------
  # C5: Latent Mean Differences (if scalar/partial scalar holds)
  # -------------------------------------------------------------------------
  cat("\n=============================================================\n")
  cat("LATENT MEAN ESTIMATES\n")
  cat("=============================================================\n\n")
  
  if (scalar_acceptable || partial_scalar_success) {
    # Extract latent means from the free structural model
    pe <- parameterEstimates(fit_struct_free, standardized = FALSE)
    
    # Latent means are in rows where op == "~1" and lhs is a latent variable
    latent_means <- pe[pe$op == "~1" & pe$lhs %in% c("DevAdj", "EmoDiss", "QualEngag"), 
                       c("lhs", "est", "se", "pvalue", "group")]
    
    # Add group labels
    latent_means$group_label <- factor(latent_means$group, 
                                        levels = 1:3, 
                                        labels = c("no_credits", "de_1_11", "fast_12plus"))
    
    cat("Latent means (reference group = no_credits):\n")
    print(latent_means[order(latent_means$lhs, latent_means$group), ])
    
    write.csv(latent_means, 
              file.path(OUT_DIR, "latent_means_DevAdj_EmoDiss_QualEngag.csv"), 
              row.names = FALSE)
    cat("\nLatent means saved to: latent_means_DevAdj_EmoDiss_QualEngag.csv\n")
  } else {
    writeLines("Latent mean comparisons skipped: Scalar/partial scalar invariance not achieved.",
               file.path(OUT_DIR, "latent_means_skipped.txt"))
    cat("Latent means skipped (scalar invariance not achieved).\n")
  }
  
  # -------------------------------------------------------------------------
  # C6: Final Outputs
  # -------------------------------------------------------------------------
  cat("\n=============================================================\n")
  cat("FINAL OUTPUTS\n")
  cat("=============================================================\n\n")
  
  # Standardized parameters by group
  pe_std <- parameterEstimates(fit_struct_free, standardized = TRUE)
  write.csv(pe_std, file.path(OUT_DIR, "final_parameters_by_group_std.csv"), row.names = FALSE)
  cat("Standardized parameters saved: final_parameters_by_group_std.csv\n")
  
  # Final structural fit indices
  final_fit_indices <- get_fit_indices(fit_struct_free, "Structural_Free")
  write.csv(final_fit_indices, file.path(OUT_DIR, "final_structural_fit_indices.csv"), row.names = FALSE)
  cat("Structural fit indices saved: final_structural_fit_indices.csv\n")
  
  cat("\n=============================================================\n")
  cat("Multi-group invariance analysis complete!\n")
  cat("All results saved to:", OUT_DIR, "\n")
  cat("=============================================================\n")
  
  quit(save = "no", status = 0)
}

# =============================================================================
# BOOTSTRAP_PSW MODE (Default - existing pipeline continues below)
# =============================================================================

# =============================================================================
# DEFINE PROPENSITY SCORE MODEL
# =============================================================================
# Covariates for PS model (pre-treatment variables)
PS_FORMULA <- x_FASt ~ cohort + hgrades_c + bparented_c + pell + 
                       hapcl + hprecalc13 + hchallenge_c

# =============================================================================
# FUNCTION: Estimate overlap weights
# =============================================================================
compute_overlap_weights <- function(data) {
  # Fit propensity score model
  ps_fit <- glm(PS_FORMULA, data = data, family = binomial(link = "logit"))
  ps <- predict(ps_fit, type = "response")
  
  # Clip extreme propensity scores
  ps <- pmax(pmin(ps, 0.99), 0.01)
  
  # Overlap weights: w = 1 - |2*ps - 1| = min(ps, 1-ps) * 2
  # For treated (x_FASt=1): w = 1 - ps
  # For control (x_FASt=0): w = ps
  psw <- ifelse(data$x_FASt == 1, 1 - ps, ps)
  
  # Normalize to sum to n
  psw <- psw * n / sum(psw)
  
  return(psw)
}

# =============================================================================
# FUNCTION: Fit SEM and extract parameters
# =============================================================================
fit_and_extract <- function(data, indices = NULL) {
  # If indices provided, resample (stratified by treatment)
  if (!is.null(indices)) {
    boot_dat <- data[indices, , drop = FALSE]
  } else {
    boot_dat <- data
  }
  
  # Step 2-3: Re-estimate PS and recompute weights
  boot_dat$psw <- tryCatch({
    ps_fit <- glm(PS_FORMULA, data = boot_dat, family = binomial(link = "logit"))
    ps <- predict(ps_fit, type = "response")
    ps <- pmax(pmin(ps, 0.99), 0.01)
    psw <- ifelse(boot_dat$x_FASt == 1, 1 - ps, ps)
    psw * nrow(boot_dat) / sum(psw)
  }, error = function(e) rep(1, nrow(boot_dat)))
  
  # Recenter variables for this bootstrap sample
  boot_dat$credit_dose_c <- boot_dat$credit_dose - mean(boot_dat$credit_dose, na.rm = TRUE)
  boot_dat$hgrades_c <- boot_dat$hgrades - mean(boot_dat$hgrades, na.rm = TRUE)
  boot_dat$bparented_c <- boot_dat$bparented - mean(boot_dat$bparented, na.rm = TRUE)
  boot_dat$hchallenge_c <- boot_dat$hchallenge - mean(boot_dat$hchallenge, na.rm = TRUE)
  boot_dat$cSFcareer_c <- boot_dat$cSFcareer - mean(boot_dat$cSFcareer, na.rm = TRUE)
  boot_dat$XZ_c <- boot_dat$x_FASt * boot_dat$credit_dose_c
  
  # Get SD of credit_dose_c for conditional effects
  sd_z <- sd(boot_dat$credit_dose_c, na.rm = TRUE)
  z_vals <- c(z_low = -sd_z, z_mid = 0, z_high = sd_z)
  
  # Step 4: Fit SEM with bootstrap weights
  # Build model directly
  model_tc <- build_model_fast_treat_control(boot_dat, z_vals = z_vals)
  
  fit <- tryCatch({
    suppressWarnings(
      lavaan::sem(
        model = model_tc,
        data = boot_dat,
        estimator = "MLR",  # Use robust ML which handles singularity better
        fixed.x = TRUE,
        sampling.weights = "psw",
        se = "robust.huber.white",
        check.lv.names = FALSE,
        meanstructure = TRUE,
        check.gradient = FALSE,
        control = list(iter.max = 5000)
      )
    )
  }, error = function(e) NULL)
  
  # Check fit validity
  if (is.null(fit)) {
    return(rep(NA_real_, 28))  # Return NAs if fit fails
  }
  
  converged <- tryCatch(lavInspect(fit, "converged"), error = function(e) FALSE)
  if (!converged) {
    return(rep(NA_real_, 28))
  }
  
  # Step 5: Extract target parameters
  pe <- parameterEstimates(fit, standardized = FALSE)
  
  # Helper to get estimate by label
  get_est <- function(label) {
    row <- pe[pe$label == label, ]
    if (nrow(row) == 1) row$est else NA_real_
  }
  
  # Extract all key parameters
  params <- c(
    # Structural paths
    a1 = get_est("a1"),
    a1z = get_est("a1z"),
    a2 = get_est("a2"),
    a2z = get_est("a2z"),
    b1 = get_est("b1"),
    b2 = get_est("b2"),
    c = get_est("c"),
    cz = get_est("cz"),
    
    # Conditional a-paths
    a1_z_low = get_est("a1_z_low"),
    a1_z_mid = get_est("a1_z_mid"),
    a1_z_high = get_est("a1_z_high"),
    a2_z_low = get_est("a2_z_low"),
    a2_z_mid = get_est("a2_z_mid"),
    a2_z_high = get_est("a2_z_high"),
    
    # Conditional direct effects
    dir_z_low = get_est("dir_z_low"),
    dir_z_mid = get_est("dir_z_mid"),
    dir_z_high = get_est("dir_z_high"),
    
    # Conditional indirect effects
    ind_EmoDiss_z_low = get_est("ind_EmoDiss_z_low"),
    ind_EmoDiss_z_mid = get_est("ind_EmoDiss_z_mid"),
    ind_EmoDiss_z_high = get_est("ind_EmoDiss_z_high"),
    ind_QualEngag_z_low = get_est("ind_QualEngag_z_low"),
    ind_QualEngag_z_mid = get_est("ind_QualEngag_z_mid"),
    ind_QualEngag_z_high = get_est("ind_QualEngag_z_high"),
    
    # Total effects
    total_z_low = get_est("total_z_low"),
    total_z_mid = get_est("total_z_mid"),
    total_z_high = get_est("total_z_high"),
    
    # Indices of moderated mediation
    index_MM_EmoDiss = get_est("index_MM_EmoDiss"),
    index_MM_QualEngag = get_est("index_MM_QualEngag")
  )
  
  return(params)
}

# =============================================================================
# ORIGINAL ESTIMATES (Point estimates from full sample)
# =============================================================================
cat("Computing original estimates...\n")
start_time <- Sys.time()

# Compute weights on full sample
dat$psw <- compute_overlap_weights(dat)
orig_params <- fit_and_extract(dat, indices = NULL)

cat("Original estimates computed in", 
    round(difftime(Sys.time(), start_time, units = "secs"), 1), "sec\n")
cat("Number of parameters:", length(orig_params), "\n\n")

# =============================================================================
# BOOTSTRAP
# =============================================================================
cat("Starting bootstrap with B =", B, "replicates...\n")
boot_start <- Sys.time()

# Wrapper for boot package
boot_fn <- function(data, indices) {
  fit_and_extract(data, indices)
}

# Run bootstrap
if (NCPUS > 1) {
  cat("Using parallel processing with", NCPUS, "cores\n")
  boot_out <- boot(
    data = dat,
    statistic = boot_fn,
    R = B,
    parallel = "multicore",
    ncpus = NCPUS
  )
} else {
  boot_out <- boot(
    data = dat,
    statistic = boot_fn,
    R = B
  )
}

boot_time <- difftime(Sys.time(), boot_start, units = "mins")
cat("\nBootstrap completed in", round(boot_time, 1), "minutes\n")

# Count successful replicates
n_success <- sum(complete.cases(boot_out$t))
cat("Successful replicates:", n_success, "/", B, 
    "(", round(100 * n_success / B, 1), "%)\n\n")

# =============================================================================
# COMPUTE CONFIDENCE INTERVALS
# =============================================================================
cat("Computing", toupper(CI_TYPE), "confidence intervals...\n")

param_names <- names(orig_params)
results <- data.frame(
  parameter = param_names,
  est = orig_params,
  se = NA_real_,
  ci_lower = NA_real_,
  ci_upper = NA_real_,
  stringsAsFactors = FALSE
)

for (i in seq_along(param_names)) {
  # Bootstrap SE
  results$se[i] <- sd(boot_out$t[, i], na.rm = TRUE)
  
  # Confidence intervals
  ci <- tryCatch({
    boot.ci(boot_out, type = CI_TYPE, index = i)
  }, error = function(e) NULL)
  
  if (!is.null(ci)) {
    if (CI_TYPE == "bca") {
      results$ci_lower[i] <- ci$bca[4]
      results$ci_upper[i] <- ci$bca[5]
    } else if (CI_TYPE == "perc") {
      results$ci_lower[i] <- ci$percent[4]
      results$ci_upper[i] <- ci$percent[5]
    } else if (CI_TYPE == "norm") {
      results$ci_lower[i] <- ci$normal[2]
      results$ci_upper[i] <- ci$normal[3]
    }
  }
}

# Add significance flag (CI excludes 0)
results$sig <- with(results, 
  !is.na(ci_lower) & !is.na(ci_upper) & 
  ((ci_lower > 0 & ci_upper > 0) | (ci_lower < 0 & ci_upper < 0)))

# =============================================================================
# SAVE RESULTS
# =============================================================================

# Save full results
write.csv(results, file.path(OUT_DIR, "bootstrap_results.csv"), row.names = FALSE)

# Save boot object for later analysis
saveRDS(boot_out, file.path(OUT_DIR, "boot_object.rds"))

# Save formatted table
sink(file.path(OUT_DIR, "bootstrap_results.txt"))
cat("=============================================================\n")
cat("Bootstrap-Then-Weight Results\n")
cat("=============================================================\n")
cat("B =", B, "| Successful =", n_success, "| CI type =", toupper(CI_TYPE), "\n")
cat("Time:", round(boot_time, 1), "minutes\n")
cat("=============================================================\n\n")

cat("STRUCTURAL PATHS\n")
cat(strrep("-", 70), "\n")
struct_params <- c("a1", "a1z", "a2", "a2z", "b1", "b2", "c", "cz")
print(results[results$parameter %in% struct_params, ], row.names = FALSE)

cat("\n\nCONDITIONAL INDIRECT EFFECTS (FASt -> Mediator -> DevAdj)\n")
cat(strrep("-", 70), "\n")
ind_params <- grep("^ind_", results$parameter, value = TRUE)
print(results[results$parameter %in% ind_params, ], row.names = FALSE)

cat("\n\nTOTAL EFFECTS\n")
cat(strrep("-", 70), "\n")
total_params <- grep("^total_", results$parameter, value = TRUE)
print(results[results$parameter %in% total_params, ], row.names = FALSE)

cat("\n\nINDICES OF MODERATED MEDIATION\n")
cat(strrep("-", 70), "\n")
mm_params <- grep("^index_MM", results$parameter, value = TRUE)
print(results[results$parameter %in% mm_params, ], row.names = FALSE)

sink()

# =============================================================================
# PRINT SUMMARY
# =============================================================================
cat("\n=============================================================\n")
cat("KEY RESULTS\n")
cat("=============================================================\n\n")

cat("Structural Paths:\n")
for (p in c("a1", "a2", "b1", "b2", "c", "a2z")) {
  r <- results[results$parameter == p, ]
  sig_star <- if (r$sig) "*" else ""
  cat(sprintf("  %s: %.3f [%.3f, %.3f]%s\n", 
              p, r$est, r$ci_lower, r$ci_upper, sig_star))
}

cat("\nConditional Indirect Effects (QualEngag pathway):\n")
for (p in c("ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high")) {
  r <- results[results$parameter == p, ]
  sig_star <- if (r$sig) "*" else ""
  cat(sprintf("  %s: %.4f [%.4f, %.4f]%s\n", 
              p, r$est, r$ci_lower, r$ci_upper, sig_star))
}

cat("\nIndex of Moderated Mediation:\n")
for (p in c("index_MM_EmoDiss", "index_MM_QualEngag")) {
  r <- results[results$parameter == p, ]
  sig_star <- if (r$sig) "*" else ""
  cat(sprintf("  %s: %.4f [%.4f, %.4f]%s\n", 
              p, r$est, r$ci_lower, r$ci_upper, sig_star))
}

cat("\n* = 95% CI excludes zero\n")
cat("\nResults saved to:", OUT_DIR, "\n")
cat("=============================================================\n")
