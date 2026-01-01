# ==============================================================================
# CFA for All Constructs - Aligned with Process-SEM Design
# ==============================================================================
# Two-Stage Approach:
#   Stage 1: First-order CFA with std.lv=TRUE (item validation, no second-order)
#   Stage 2: Second-order CFA with MARKER VARIABLE scaling throughout
#            - DevAdj: marker on Belong (1*Belong), DevAdj variance free
#            - First-order factors: marker on first indicator (1*)
#            - EmoDiss, QualEngag: marker on first indicator (1*)
# ==============================================================================

suppressPackageStartupMessages({
  library(lavaan)
  library(semTools)
})

cat("\n", rep("=", 70), "\n", sep = "")
cat("CFA FOR ALL CONSTRUCTS - PROCESS-SEM MEASUREMENT MODEL\n")
cat(rep("=", 70), "\n\n", sep = "")

# Load data
dat <- read.csv("rep_data.csv")
cat("Data loaded: N =", nrow(dat), "observations\n\n")

# ##############################################################################
# STAGE 1: FIRST-ORDER CFA (Item Validation)
# - No second-order factor
# - std.lv = TRUE to free all loadings
# - Factors allowed to correlate
# ##############################################################################

cat("\n", rep("=", 70), "\n", sep = "")
cat("STAGE 1: FIRST-ORDER CFA (Item Validation)\n")
cat("Identification: std.lv = TRUE (factor variances = 1)\n")
cat(rep("=", 70), "\n\n", sep = "")

cfa_firstorder <- '
  # DevAdj sub-factors (will become first-order in Stage 2)
  Belong     =~ sbvalued + sbmyself + sbcommunity
  Gains      =~ pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
  SupportEnv =~ SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
  Satisf     =~ sameinst + evalexp
  
  # Mediator factors
  EmoDiss   =~ MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
  QualEngag =~ QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff
'

fit_fo <- cfa(cfa_firstorder, 
              data = dat, 
              estimator = "ML",
              missing = "fiml",
              std.lv = TRUE)  # Factor variances = 1, all loadings free

cat("--- STAGE 1 FIT INDICES ---\n")
fit_fo_indices <- fitMeasures(fit_fo, c("chisq", "df", "pvalue", 
                                         "cfi", "tli", "rmsea", "srmr"))
print(round(fit_fo_indices, 4))

cat("\n--- STAGE 1 FACTOR LOADINGS (Standardized) ---\n")
loadings_fo <- parameterEstimates(fit_fo, standardized = TRUE)
loadings_fo_only <- loadings_fo[loadings_fo$op == "=~", 
                                 c("lhs", "rhs", "est", "se", "z", "pvalue", "std.all")]
print(loadings_fo_only, digits = 3, row.names = FALSE)

cat("\n--- STAGE 1 FACTOR CORRELATIONS ---\n")
lv_cor_fo <- lavInspect(fit_fo, "cor.lv")
print(round(lv_cor_fo, 3))

cat("\n--- STAGE 1 RELIABILITY ---\n")
tryCatch({
  # Use compRelSEM for omega (replaces deprecated reliability())
  omega_fo <- compRelSEM(fit_fo)
  cat("Omega (composite reliability):\n")
  print(round(omega_fo, 3))
  
  # Use AVE() for average variance extracted
  ave_fo <- AVE(fit_fo)
  cat("\nAVE (average variance extracted):\n")
  print(round(ave_fo, 3))
}, error = function(e) cat("Could not compute reliability:", e$message, "\n"))

# ##############################################################################
# STAGE 2: SECOND-ORDER CFA (Hierarchical Structure)
# - Marker variable identification throughout (NO std.lv)
# - First-order factors: marker on first indicator
# - Second-order: marker on Belong, DevAdj variance freely estimated
# ##############################################################################

cat("\n\n", rep("=", 70), "\n", sep = "")
cat("STAGE 2: SECOND-ORDER CFA (Hierarchical DevAdj)\n")
cat("Identification: Marker variable throughout (first indicator = 1)\n")
cat(rep("=", 70), "\n\n", sep = "")

cfa_secondorder <- '
  # ============================================================================
  # FIRST-ORDER FACTORS - MARKER VARIABLE (1* on first indicator)
  # Remaining loadings and factor variances freely estimated
  # ============================================================================
  Belong     =~ 1*sbvalued + sbmyself + sbcommunity
  Gains      =~ 1*pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
  SupportEnv =~ 1*SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
  Satisf     =~ 1*sameinst + evalexp
  
  # ============================================================================
  # SECOND-ORDER FACTOR - MARKER on Belong
  # DevAdj variance is freely estimated
  # First-order disturbances (residual variances) are freely estimated
  # ============================================================================
  DevAdj =~ 1*Belong + Gains + SupportEnv + Satisf
  
  # ============================================================================
  # STANDALONE MEDIATOR FACTORS - MARKER VARIABLE (1* on first indicator)
  # ============================================================================
  EmoDiss   =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
  QualEngag =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff
'

fit <- cfa(cfa_secondorder, 
           data = dat, 
           estimator = "ML",
           missing = "fiml",
           std.lv = FALSE)  # NO std.lv - using marker variable identification

# ==============================================================================
# STAGE 2 OUTPUT SECTION
# ==============================================================================

cat("\n", rep("=", 70), "\n", sep = "")
cat("STAGE 2 MODEL FIT SUMMARY\n")
cat(rep("=", 70), "\n\n", sep = "")
summary(fit, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE)

cat("\n", rep("=", 70), "\n", sep = "")
cat("FIT INDICES (DETAILED)\n")
cat(rep("=", 70), "\n\n", sep = "")
fit_indices <- fitMeasures(fit, c("chisq", "df", "pvalue", 
                                   "cfi", "tli", "rmsea", "rmsea.ci.lower", "rmsea.ci.upper",
                                   "srmr", "aic", "bic"))
print(round(fit_indices, 4))

cat("\n", rep("=", 70), "\n", sep = "")
cat("FACTOR LOADINGS (UNSTANDARDIZED)\n")
cat(rep("=", 70), "\n\n", sep = "")
loadings <- parameterEstimates(fit, standardized = TRUE)
loadings_only <- loadings[loadings$op == "=~", c("lhs", "rhs", "est", "se", "z", "pvalue", "std.all")]
print(loadings_only, digits = 3, row.names = FALSE)

cat("\n", rep("=", 70), "\n", sep = "")
cat("FACTOR VARIANCES AND COVARIANCES\n")
cat(rep("=", 70), "\n\n", sep = "")
variances <- loadings[loadings$op == "~~" & loadings$lhs %in% c("Belong", "Gains", "SupportEnv", "Satisf", "DevAdj", "EmoDiss", "QualEngag"), 
                      c("lhs", "op", "rhs", "est", "se", "z", "pvalue")]
print(variances, digits = 3, row.names = FALSE)

cat("\n", rep("=", 70), "\n", sep = "")
cat("RELIABILITY: OMEGA AND AVE\n")
cat(rep("=", 70), "\n\n", sep = "")

# Calculate reliability using compRelSEM (omega) and AVE
tryCatch({
  # Omega (composite reliability) - replaces deprecated reliability()
  omega <- compRelSEM(fit)
  cat("Omega (composite reliability):\n")
  print(round(omega, 3))
  
  # AVE (average variance extracted)
  ave <- AVE(fit)
  cat("\nAVE (average variance extracted):\n")
  print(round(ave, 3))
}, error = function(e) {
  cat("Could not compute reliability (may be due to second-order structure).\n")
  cat("Error:", e$message, "\n")
})

cat("\n", rep("=", 70), "\n", sep = "")
cat("MODIFICATION INDICES (top 15)\n")
cat(rep("=", 70), "\n\n", sep = "")
mi <- modificationIndices(fit, sort. = TRUE, minimum.value = 5)
if(nrow(mi) > 0) {
  print(head(mi[, c("lhs", "op", "rhs", "mi", "epc")], 15), digits = 3, row.names = FALSE)
} else {
  cat("No modification indices > 5\n")
}

cat("\n", rep("=", 70), "\n", sep = "")
cat("RESIDUAL CORRELATIONS (absolute > 0.1)\n")
cat(rep("=", 70), "\n\n", sep = "")
res_cor <- residuals(fit, type = "cor")$cov
res_cor[upper.tri(res_cor, diag = TRUE)] <- NA
large_resid <- which(abs(res_cor) > 0.1, arr.ind = TRUE)
if(nrow(large_resid) > 0) {
  resid_df <- data.frame(
    var1 = rownames(res_cor)[large_resid[,1]],
    var2 = colnames(res_cor)[large_resid[,2]],
    residual = res_cor[large_resid]
  )
  resid_df <- resid_df[order(abs(resid_df$residual), decreasing = TRUE), ]
  print(head(resid_df, 20), row.names = FALSE)
} else {
  cat("No residual correlations > |0.1|\n")
}

cat("\n", rep("=", 70), "\n", sep = "")
cat("DISCRIMINANT VALIDITY: FACTOR CORRELATION MATRIX\n")
cat(rep("=", 70), "\n\n", sep = "")
# Get latent variable correlations
lv_cor <- lavInspect(fit, "cor.lv")
print(round(lv_cor, 3))

cat("\n", rep("=", 70), "\n", sep = "")
cat("CFA COMPLETE\n")
cat(rep("=", 70), "\n\n", sep = "")
