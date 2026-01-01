#!/usr/bin/env Rscript

# Standalone MG SEM: FASt vs non-FASt using CSU validated rep_data

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx)) return(default)
  if (idx == length(args)) return(default)
  args[[idx + 1]]
}

REP_DATA_CSV <- get_arg("--rep_data_csv", "results/repstudy_bootstrap/seed20251223_N3000_B2000_ciperc/rep_data.csv")
OUT_DIR <- get_arg("--out_dir", "results/repstudy_fast_vs_nonfast/seed20251223_N3000_B2000_ciperc")
ESTIMATOR <- get_arg("--estimator", "MLR")
MISSING <- get_arg("--missing", "fiml")
B <- as.integer(get_arg("--B", get_arg("--bootstrap", 0)))
BOOT_CI_TYPE <- get_arg("--boot_ci_type", "perc")
CI_LEVEL <- as.numeric(get_arg("--ci_level", 0.95))

if (!file.exists(REP_DATA_CSV)) {
  stop("rep_data_csv not found: ", REP_DATA_CSV)
}

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
  library(lavaan)
})

source("r/models/mg_fast_vs_nonfast_model.R")

dat <- utils::read.csv(REP_DATA_CSV, stringsAsFactors = FALSE)

required <- c(
  "x_FASt",
  "credit_dose_c",
  "cohort",
  "hgrades_c",
  "bparented_c",
  "pell",
  "hapcl",
  "hprecalc13",
  "hchallenge_c",
  "cSFcareer_c",
  "sbvalued","sbmyself","sbcommunity",
  "pganalyze","pgthink","pgwork","pgvalues","pgprobsolve",
  "SEacademic","SEwellness","SEnonacad","SEactivities","SEdiverse",
  "sameinst","evalexp",
  "MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial",
  "QIadmin","QIstudent","QIadvisor","QIfaculty","QIstaff",
  "SFcareer","SFotherwork","SFdiscuss","SFperform"
)
missing_cols <- setdiff(required, names(dat))
if (length(missing_cols) > 0) {
  stop("rep_data is missing required columns: ", paste(missing_cols, collapse = ", "))
}

# Fit call
fit_args <- list(
  model = model_mg_fast_vs_nonfast,
  data = dat,
  group = "x_FASt",
  estimator = ESTIMATOR,
  missing = MISSING,
  fixed.x = TRUE,
  check.lv.names = FALSE
)

if (is.finite(B) && B > 0) {
  # lavaan bootstrap is supported for ML (not MLR); if user didn't override,
  # switch to ML to honor the bootstrap request.
  if (identical(ESTIMATOR, "MLR")) {
    ESTIMATOR <- "ML"
    fit_args$estimator <- ESTIMATOR
  }
  fit_args$se <- "bootstrap"
  fit_args$bootstrap <- B
}

fit <- do.call(lavaan::sem, fit_args)

# Save outputs
pe <- lavaan::parameterEstimates(
  fit,
  ci = TRUE,
  level = CI_LEVEL,
  boot.ci.type = BOOT_CI_TYPE
)
fm <- lavaan::fitMeasures(fit)
conv <- lavaan::lavInspect(fit, "converged")

utils::write.csv(pe, file.path(OUT_DIR, "mg_fast_vs_nonfast_parameterEstimates.csv"), row.names = FALSE)
utils::write.csv(data.frame(measure = names(fm), value = as.numeric(fm)), file.path(OUT_DIR, "mg_fast_vs_nonfast_fitMeasures.csv"), row.names = FALSE)
utils::write.csv(data.frame(converged = as.logical(conv)), file.path(OUT_DIR, "mg_fast_vs_nonfast_convergence.csv"), row.names = FALSE)

sink(file.path(OUT_DIR, "mg_fast_vs_nonfast_fit.txt"))
cat("MG SEM: FASt vs non-FASt (x_FASt)\n")
cat("rep_data_csv: ", REP_DATA_CSV, "\n", sep = "")
cat("estimator: ", ESTIMATOR, "\n", sep = "")
cat("missing: ", MISSING, "\n", sep = "")
cat("bootstrap B: ", as.character(B), "\n", sep = "")
if (is.finite(B) && B > 0) {
  cat("boot_ci_type: ", BOOT_CI_TYPE, "\n", sep = "")
  cat("ci_level: ", as.character(CI_LEVEL), "\n", sep = "")
}
cat("converged: ", as.character(conv), "\n\n", sep = "")
print(summary(fit, fit.measures = TRUE, standardized = FALSE))
sink()

cat("Wrote outputs to: ", OUT_DIR, "\n", sep = "")
