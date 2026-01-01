#!/usr/bin/env Rscript
# Serial Mediation (Exploratory Analysis)
# Compares parallel vs serial mediation models
# Serial adds: EmoDiss -> QualEngag path (d coefficient)

suppressPackageStartupMessages({
  library(lavaan)
  library(semTools)
})

cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("SERIAL MEDIATION: Exploratory Analysis\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

# Load data
dat <- read.csv("rep_data.csv", stringsAsFactors = FALSE)
cat("N =", nrow(dat), "\n")
cat("FASt =", sum(dat$x_FASt == 1), "(", round(100*mean(dat$x_FASt), 1), "%)\n\n")

# Ensure centered variables exist (E2E pipeline does this)
if (!"hgrades_c" %in% names(dat)) {
  dat$hgrades_c <- scale(dat$hgrades, center = TRUE, scale = FALSE)[,1]
}
if (!"credit_dose_c" %in% names(dat)) {
  dat$credit_dose_c <- scale(dat$credit_dose, center = TRUE, scale = FALSE)[,1]
}
if (!"bparented_c" %in% names(dat)) {
  dat$bparented_c <- scale(dat$bparented, center = TRUE, scale = FALSE)[,1]
}
if (!"hchallenge_c" %in% names(dat)) {
  dat$hchallenge_c <- scale(dat$hchallenge, center = TRUE, scale = FALSE)[,1]
}
if (!"cSFcareer_c" %in% names(dat)) {
  dat$cSFcareer_c <- scale(dat$cSFcareer, center = TRUE, scale = FALSE)[,1]
}
# Interaction term
dat$XZ_c <- dat$x_FASt * dat$credit_dose_c

# Remove latent variable collisions (factor scores sometimes left in data)
dat <- dat[, !names(dat) %in% c("DevAdj", "EmoDiss", "QualEngag")]

# Source model definitions
source("r/models/mg_fast_vs_nonfast_model.R")

# Build both models
model_parallel <- build_model_fast_treat_control(dat)
model_serial   <- build_model_fast_treat_control_serial(dat)

# Create output directory
outdir <- "results/serial_mediation_exploratory"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("Fitting PARALLEL mediation model...\n")
fit_parallel <- sem(model_parallel, data = dat, estimator = "ML", missing = "fiml")

cat("Fitting SERIAL mediation model...\n")
fit_serial <- sem(model_serial, data = dat, estimator = "ML", missing = "fiml")

# Compare fit indices
cat("\n", paste(rep("-", 70), collapse=""), "\n")
cat("MODEL FIT COMPARISON\n")
cat(paste(rep("-", 70), collapse=""), "\n\n")

fit_idx <- c("chisq", "df", "pvalue", "cfi", "tli", "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "srmr", "aic", "bic")
fm_par <- fitMeasures(fit_parallel, fit_idx)
fm_ser <- fitMeasures(fit_serial, fit_idx)

comparison <- data.frame(
  Index = fit_idx,
  Parallel = round(fm_par, 4),
  Serial = round(fm_ser, 4),
  Diff = round(fm_ser - fm_par, 4)
)
print(comparison, row.names = FALSE)

# Chi-square difference test (serial is nested in parallel with d=0)
cat("\n", paste(rep("-", 70), collapse=""), "\n")
cat("CHI-SQUARE DIFFERENCE TEST (Serial vs Parallel)\n")
cat(paste(rep("-", 70), collapse=""), "\n")
cat("H0: d = 0 (EmoDiss does NOT predict QualEngag)\n\n")

chi_diff <- fm_par["chisq"] - fm_ser["chisq"]
df_diff <- fm_par["df"] - fm_ser["df"]
p_diff <- pchisq(chi_diff, df = abs(df_diff), lower.tail = FALSE)

cat(sprintf("Δχ² = %.3f, Δdf = %d, p = %.4f\n", chi_diff, abs(df_diff), p_diff))
if (p_diff < 0.05) {
  cat(">>> Serial model fits SIGNIFICANTLY better (d ≠ 0)\n")
} else {
  cat(">>> No significant improvement; parallel model is adequate\n")
}

# Extract serial path coefficient
cat("\n", paste(rep("-", 70), collapse=""), "\n")
cat("SERIAL PATH: EmoDiss -> QualEngag (d coefficient)\n")
cat(paste(rep("-", 70), collapse=""), "\n\n")

pe_serial <- parameterEstimates(fit_serial, ci = TRUE, standardized = TRUE)
d_path <- pe_serial[pe_serial$label == "d", ]
if (nrow(d_path) > 0) {
  cat(sprintf("d = %.4f (SE = %.4f), z = %.3f, p = %.4f\n", 
              d_path$est, d_path$se, d_path$z, d_path$pvalue))
  cat(sprintf("95%% CI [%.4f, %.4f]\n", d_path$ci.lower, d_path$ci.upper))
  cat(sprintf("Standardized (std.all) = %.4f\n", d_path$std.all))
}

# Compare indirect effects
cat("\n", paste(rep("-", 70), collapse=""), "\n")
cat("INDIRECT EFFECTS COMPARISON (at Z = mean)\n")
cat(paste(rep("-", 70), collapse=""), "\n\n")

pe_par <- parameterEstimates(fit_parallel, ci = TRUE)
pe_ser <- parameterEstimates(fit_serial, ci = TRUE)

# Parallel model indirects
ind_emo_par <- pe_par[pe_par$label == "ind_EmoDiss_z_mid", c("est", "se", "pvalue", "ci.lower", "ci.upper")]
ind_qual_par <- pe_par[pe_par$label == "ind_QualEngag_z_mid", c("est", "se", "pvalue", "ci.lower", "ci.upper")]

# Serial model indirects
ind_emo_ser <- pe_ser[pe_ser$label == "ind_EmoDiss_z_mid", c("est", "se", "pvalue", "ci.lower", "ci.upper")]
ind_qual_ser <- pe_ser[pe_ser$label == "ind_QualEngag_z_mid", c("est", "se", "pvalue", "ci.lower", "ci.upper")]
ind_serial <- pe_ser[pe_ser$label == "ind_serial_z_mid", c("est", "se", "pvalue", "ci.lower", "ci.upper")]

cat("PARALLEL MODEL:\n")
cat(sprintf("  via EmoDiss:   %.4f (p=%.4f) [%.4f, %.4f]\n", 
            ind_emo_par$est, ind_emo_par$pvalue, ind_emo_par$ci.lower, ind_emo_par$ci.upper))
cat(sprintf("  via QualEngag: %.4f (p=%.4f) [%.4f, %.4f]\n", 
            ind_qual_par$est, ind_qual_par$pvalue, ind_qual_par$ci.lower, ind_qual_par$ci.upper))
cat(sprintf("  TOTAL indirect: %.4f\n\n", ind_emo_par$est + ind_qual_par$est))

cat("SERIAL MODEL:\n")
cat(sprintf("  via EmoDiss:   %.4f (p=%.4f) [%.4f, %.4f]\n", 
            ind_emo_ser$est, ind_emo_ser$pvalue, ind_emo_ser$ci.lower, ind_emo_ser$ci.upper))
cat(sprintf("  via QualEngag: %.4f (p=%.4f) [%.4f, %.4f]\n", 
            ind_qual_ser$est, ind_qual_ser$pvalue, ind_qual_ser$ci.lower, ind_qual_ser$ci.upper))
cat(sprintf("  via SERIAL:    %.4f (p=%.4f) [%.4f, %.4f]\n", 
            ind_serial$est, ind_serial$pvalue, ind_serial$ci.lower, ind_serial$ci.upper))
cat(sprintf("  TOTAL indirect: %.4f\n", ind_emo_ser$est + ind_qual_ser$est + ind_serial$est))

# Index of moderated mediation for serial
cat("\n", paste(rep("-", 70), collapse=""), "\n")
cat("INDEX OF MODERATED MEDIATION\n")
cat(paste(rep("-", 70), collapse=""), "\n\n")

imm_emo <- pe_ser[pe_ser$label == "index_MM_EmoDiss", ]
imm_qual <- pe_ser[pe_ser$label == "index_MM_QualEngag", ]
imm_serial <- pe_ser[pe_ser$label == "index_MM_serial", ]

cat(sprintf("via EmoDiss:   %.4f (p=%.4f)\n", imm_emo$est, imm_emo$pvalue))
cat(sprintf("via QualEngag: %.4f (p=%.4f)\n", imm_qual$est, imm_qual$pvalue))
cat(sprintf("via SERIAL:    %.4f (p=%.4f)\n", imm_serial$est, imm_serial$pvalue))

# Save outputs
write.csv(comparison, file.path(outdir, "fit_comparison.csv"), row.names = FALSE)
write.csv(pe_serial, file.path(outdir, "serial_parameterEstimates.csv"), row.names = FALSE)

# Save model syntax
writeLines(model_serial, file.path(outdir, "serial_model_syntax.lav"))

# Summary
sink(file.path(outdir, "serial_model_summary.txt"))
summary(fit_serial, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE)
sink()

cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("Outputs saved to:", outdir, "\n")
cat(paste(rep("=", 70), collapse=""), "\n")

# Final interpretation
cat("\n*** INTERPRETATION ***\n")
if (p_diff < 0.05 && d_path$pvalue < 0.05) {
  if (d_path$est < 0) {
    cat("Emotional distress REDUCES quality of engagement (d < 0).\n")
    cat("This supports a 'spillover' hypothesis: distress impairs engagement.\n")
  } else {
    cat("Emotional distress INCREASES quality of engagement (d > 0).\n")
    cat("This could indicate compensatory help-seeking behavior.\n")
  }
  cat("The serial indirect effect represents an additional pathway.\n")
} else {
  cat("The serial path is not significant; parallel mediation is sufficient.\n")
  cat("EmoDiss and QualEngag operate as independent mediators.\n")
}
