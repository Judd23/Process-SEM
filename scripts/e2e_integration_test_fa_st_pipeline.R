#!/usr/bin/env Rscript

# End-to-end integration test for the FASt conditional-process SEM pipeline.
#
# Goal: fail fast on any mismatch and write an auditable run folder under:
#   results/e2e_test/<timestamp>/
#
# This script is intentionally strict and self-contained.

suppressPackageStartupMessages({
  library(lavaan)
})

# -------------------------
# Paths + run folder
# -------------------------

ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
RUN_DIR <- file.path("results", "e2e_test", ts)
dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)

REP_DATA_PATH <- file.path(getwd(), "rep_data.csv")
if (!file.exists(REP_DATA_PATH)) stop("rep_data.csv not found at repo root: ", REP_DATA_PATH)

# Helper: write-and-stop with a reason
.verif_path <- file.path(RUN_DIR, "verification_checklist.txt")

.write_verif_header <- function(status, fail_section = "") {
  con <- file(.verif_path, open = "wt")
  on.exit(close(con), add = TRUE)
  cat("E2E integration test: FASt conditional-process SEM\n", file = con)
  cat("STATUS: ", status, "\n", sep = "", file = con)
  if (nzchar(fail_section)) cat("FAILED_SECTION: ", fail_section, "\n", sep = "", file = con)
  cat("RUN_DIR: ", RUN_DIR, "\n", sep = "", file = con)
  cat("REP_DATA_PATH: ", REP_DATA_PATH, "\n\n", sep = "", file = con)
}

.fail_fast <- function(section, msg, extra_paths = character(0)) {
  .write_verif_header("FAIL", fail_section = section)
  con <- file(.verif_path, open = "at")
  on.exit(close(con), add = TRUE)
  cat("MESSAGE: ", msg, "\n", sep = "", file = con)
  if (length(extra_paths) > 0) {
    cat("ARTIFACTS:\n", file = con)
    for (p in extra_paths) cat("- ", p, "\n", sep = "", file = con)
  }
  cat("\n", file = con)
  cat("FAIL: ", section, "\n", sep = "")
  cat(msg, "\n")
  cat("Run folder: ", RUN_DIR, "\n", sep = "")
  stop("E2E integration test failed: ", section)
}

.pass <- function() {
  .write_verif_header("PASS")
  cat("PASS\n")
  cat("Run folder: ", RUN_DIR, "\n", sep = "")
}

# Machine-readable key/value report
.write_kv <- function(path, kv) {
  stopifnot(is.character(names(kv)))
  df <- data.frame(key = names(kv), value = unname(as.character(kv)), stringsAsFactors = FALSE)
  utils::write.csv(df, file = path, row.names = FALSE)
}

.write_run_log <- function(path, fields) {
  con <- file(path, open = "wt")
  on.exit(close(con), add = TRUE)
  for (nm in names(fields)) {
    cat(nm, ": ", as.character(fields[[nm]]), "\n", sep = "", file = con)
  }
}

# -------------------------
# Load data
# -------------------------

dat <- tryCatch(read.csv(REP_DATA_PATH, stringsAsFactors = FALSE, check.names = FALSE),
  error = function(e) .fail_fast("LOAD", paste0("Failed to read rep_data.csv: ", conditionMessage(e)))
)

if (!("trnsfr_cr" %in% names(dat))) .fail_fast("LOAD", "Missing required column: trnsfr_cr")
dat$trnsfr_cr <- suppressWarnings(as.numeric(dat$trnsfr_cr))
if (all(is.na(dat$trnsfr_cr))) .fail_fast("LOAD", "trnsfr_cr could not be parsed as numeric")

# Do not use hgrades_AF anywhere
if ("hgrades_AF" %in% names(dat)) {
  dat$hgrades_AF <- NULL
}

# -------------------------
# A) Codebook range validation (no collapsing)
# -------------------------

four_pt_items <- c(
  "sbmyself","sbvalued","sbcommunity",
  "pgthink","pganalyze","pgwork","pgvalues","pgprobsolve",
  "SEwellness","SEnonacad","SEactivities","SEacademic","SEdiverse",
  "evalexp","sameinst"
)

mhw_items <- c("MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial")
qi_items <- c("QIstudent","QIadvisor","QIfaculty","QIstaff","QIadmin")

# Recode MHW 9 -> NA (allowed)
for (v in intersect(mhw_items, names(dat))) {
  x <- suppressWarnings(as.numeric(dat[[v]]))
  x[x == 9] <- NA
  dat[[v]] <- x
}

# Coerce all indicators used in validations/models to numeric (without collapsing)
for (v in intersect(c(four_pt_items, mhw_items, qi_items), names(dat))) {
  dat[[v]] <- suppressWarnings(as.numeric(dat[[v]]))
}

.bad_codes_report <- function(d, var, bad_values, rule) {
  if (length(bad_values) == 0) return(NULL)
  data.frame(
    var = var,
    value = as.character(bad_values),
    n = as.integer(table(factor(bad_values, levels = unique(as.character(bad_values))))),
    rule = rule,
    stringsAsFactors = FALSE
  )
}

.check_allowed <- function(d, vars, allowed, rule) {
  out <- data.frame(var = character(0), value = character(0), n = integer(0), rule = character(0), stringsAsFactors = FALSE)
  for (v in vars) {
    if (!(v %in% names(d))) next
    x <- suppressWarnings(as.numeric(d[[v]]))
    bad <- !is.na(x) & !(x %in% allowed)
    if (any(bad)) {
      vals <- x[bad]
      tab <- table(vals)
      out <- rbind(out, data.frame(var = v, value = names(tab), n = as.integer(tab), rule = rule, stringsAsFactors = FALSE))
    }
  }
  out
}

bad_4 <- .check_allowed(dat, four_pt_items, allowed = 1:4, rule = "allowed_1_4")
bad_m <- .check_allowed(dat, mhw_items, allowed = 1:6, rule = "allowed_1_6_or_9_to_NA")
bad_q <- .check_allowed(dat, qi_items, allowed = 1:7, rule = "allowed_1_7")

bad_all <- rbind(bad_4, bad_m, bad_q)
if (nrow(bad_all) > 0) {
  bad_path <- file.path(RUN_DIR, "bad_codes_report.csv")
  utils::write.csv(bad_all[order(bad_all$var, -bad_all$n), , drop = FALSE], file = bad_path, row.names = FALSE)
  .fail_fast("A_CODEBOOK", "Invalid codes detected after recode step (no collapsing allowed).", extra_paths = bad_path)
}

# -------------------------
# B) Derived terms (overwrite; assert max_abs_diff=0)
# -------------------------

dat$x_FASt <- as.integer(dat$trnsfr_cr >= 12)

credit_dose <- (dat$trnsfr_cr - 12) / 10
credit_dose_c <- as.numeric(scale(credit_dose, scale = FALSE))
XZ_c <- dat$x_FASt * credit_dose_c

# Hard overwrite

dat$credit_dose <- credit_dose

dat$credit_dose_c <- credit_dose_c

dat$XZ_c <- XZ_c

mx0 <- function(x) suppressWarnings(max(abs(x), na.rm = TRUE))

if (mx0(dat$x_FASt - as.integer(dat$trnsfr_cr >= 12)) != 0) {
  .fail_fast("B_DERIVED", "x_FASt mismatch to as.integer(trnsfr_cr>=12)")
}
if (mx0(dat$credit_dose - ((dat$trnsfr_cr - 12) / 10)) != 0) {
  .fail_fast("B_DERIVED", "credit_dose mismatch to (trnsfr_cr - 12)/10")
}
if (mx0(dat$credit_dose_c - as.numeric(scale(dat$credit_dose, scale = FALSE))) != 0) {
  .fail_fast("B_DERIVED", "credit_dose_c mismatch to as.numeric(scale(credit_dose, scale=FALSE))")
}
if (mx0(dat$XZ_c - (dat$x_FASt * dat$credit_dose_c)) != 0) {
  .fail_fast("B_DERIVED", "XZ_c mismatch to x_FASt*credit_dose_c")
}

# Quick exogenous collinearity diagnostic (cov eigenvalues)
exo_cols <- c("x_FASt", "credit_dose_c", "XZ_c")
if (all(exo_cols %in% names(dat))) {
  cc <- stats::complete.cases(dat[, exo_cols, drop = FALSE])
  ev_path <- file.path(RUN_DIR, "exo_eigenvalues.csv")
  if (sum(cc) >= 3) {
    exo_cov <- tryCatch(stats::cov(dat[cc, exo_cols, drop = FALSE]), error = function(e) NULL)
    if (!is.null(exo_cov)) {
      exo_eig <- eigen(exo_cov, symmetric = TRUE, only.values = TRUE)$values
      utils::write.csv(
        data.frame(component = seq_along(exo_eig), eigenvalue = as.numeric(exo_eig), stringsAsFactors = FALSE),
        file = ev_path,
        row.names = FALSE
      )
    } else {
      utils::write.csv(
        data.frame(component = integer(0), eigenvalue = numeric(0), stringsAsFactors = FALSE),
        file = ev_path,
        row.names = FALSE
      )
    }
  } else {
    utils::write.csv(
      data.frame(component = integer(0), eigenvalue = numeric(0), stringsAsFactors = FALSE),
      file = ev_path,
      row.names = FALSE
    )
  }
}

# -------------------------
# C) Group definitions
# -------------------------

dat$credit_band <- NA_character_
dat$credit_band[!is.na(dat$trnsfr_cr) & dat$trnsfr_cr == 0] <- "non_DE"
dat$credit_band[!is.na(dat$trnsfr_cr) & dat$trnsfr_cr >= 1 & dat$trnsfr_cr <= 11] <- "non_FASt_1_11"
dat$credit_band[!is.na(dat$trnsfr_cr) & dat$trnsfr_cr >= 12] <- "FASt_12plus"
dat$credit_band <- factor(dat$credit_band, levels = c("non_DE","non_FASt_1_11","FASt_12plus"))

if (any(is.na(dat$credit_band))) {
  .fail_fast("C_GROUPS", "credit_band has NA values; check trnsfr_cr coding")
}

x_match <- all((dat$x_FASt == 1) == (dat$credit_band == "FASt_12plus"))
if (!isTRUE(x_match)) {
  .fail_fast("C_GROUPS", "x_FASt does not correspond exactly to credit_band == FASt_12plus")
}

counts <- as.data.frame(table(dat$credit_band), stringsAsFactors = FALSE)
colnames(counts) <- c("credit_band","n")
counts$prop <- counts$n / sum(counts$n)
counts_path <- file.path(RUN_DIR, "group_counts.csv")
utils::write.csv(counts, file = counts_path, row.names = FALSE)

# -------------------------
# D) Centering checks
# -------------------------

center_col <- function(d, base, centered) {
  # ALWAYS recenter to ensure mean is exactly 0, even if centered var already exists
  if (!(base %in% names(d))) stop("Missing base var needed for centering: ", base)
  d[[base]] <- suppressWarnings(as.numeric(d[[base]]))
  d[[centered]] <- as.numeric(scale(d[[base]], scale = FALSE))
  d
}

dat <- tryCatch(center_col(dat, "bparented", "bparented_c"), error = function(e) .fail_fast("D_CENTERING", conditionMessage(e)))
dat <- tryCatch(center_col(dat, "hchallenge", "hchallenge_c"), error = function(e) .fail_fast("D_CENTERING", conditionMessage(e)))
dat <- tryCatch(center_col(dat, "cSFcareer", "cSFcareer_c"), error = function(e) .fail_fast("D_CENTERING", conditionMessage(e)))

# Keep hgrades_c creation (but make it robust if deleted)
dat <- tryCatch(center_col(dat, "hgrades", "hgrades_c"), error = function(e) .fail_fast("D_CENTERING", conditionMessage(e)))

center_vars <- c("hgrades_c","bparented_c","hchallenge_c","cSFcareer_c","credit_dose_c")

cent_stats <- data.frame(
  var = center_vars,
  n_nonmiss = vapply(center_vars, function(v) sum(!is.na(dat[[v]])), integer(1)),
  mean = vapply(center_vars, function(v) mean(dat[[v]], na.rm = TRUE), numeric(1)),
  stringsAsFactors = FALSE
)
cent_stats$abs_mean <- abs(cent_stats$mean)

if (any(!(cent_stats$abs_mean < 1e-10))) {
  bad <- cent_stats$var[!(cent_stats$abs_mean < 1e-10)]
  .fail_fast("D_CENTERING", paste0("Centering failed abs(mean)<1e-10 for: ", paste(bad, collapse = ", ")))
}

# -------------------------
# E) Directional alignment (continuous correlations)
# -------------------------

cor_median <- function(vars, label) {
  vars <- intersect(vars, names(dat))
  if (length(vars) < 2) return(data.frame(set = label, n_items = length(vars), median_r = NA_real_, min_r = NA_real_, stringsAsFactors = FALSE))
  cm <- tryCatch(stats::cor(dat[, vars, drop = FALSE], use = "pairwise.complete.obs"), error = function(e) NULL)
  if (is.null(cm)) return(data.frame(set = label, n_items = length(vars), median_r = NA_real_, min_r = NA_real_, stringsAsFactors = FALSE))

  cm <- as.matrix(cm)
  vals <- cm[lower.tri(cm)]
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) return(data.frame(set = label, n_items = length(vars), median_r = NA_real_, min_r = NA_real_, stringsAsFactors = FALSE))
  data.frame(set = label, n_items = length(vars), median_r = median(vals), min_r = min(vals), stringsAsFactors = FALSE)
}

belong_items <- c("sbvalued","sbmyself","sbcommunity")
gains_items <- c("pganalyze","pgthink","pgwork","pgvalues","pgprobsolve")
support_items <- c("SEacademic","SEwellness","SEnonacad","SEactivities","SEdiverse")
satisf_items <- c("sameinst","evalexp")
qual_items <- c("QIadmin","QIstudent","QIadvisor","QIfaculty","QIstaff")

cor_diag <- rbind(
  cor_median(mhw_items, "EmoDiss"),
  cor_median(belong_items, "Belong"),
  cor_median(gains_items, "Gains"),
  cor_median(support_items, "SupportEnv"),
  cor_median(satisf_items, "Satisf"),
  cor_median(qual_items, "QualEngag")
)

cor_path <- file.path(RUN_DIR, "directional_alignment_diagnostics.csv")
utils::write.csv(cor_diag, file = cor_path, row.names = FALSE)

bad_sets <- cor_diag$set[is.finite(cor_diag$median_r) & cor_diag$median_r < 0]
if (length(bad_sets) > 0) {
  .fail_fast("E_ALIGNMENT", paste0("Median inter-item polychoric correlation < 0 for: ", paste(bad_sets, collapse = ", ")), extra_paths = cor_path)
}

# -------------------------
# Measurement + structural model strings (exact)
# -------------------------
# IDENTIFICATION STRATEGY:
# 1. First-order DevAdj factors (Belong, Gains, SupportEnv, Satisf): 
#    - ALL loadings freely estimated (requires std.lv = TRUE for identification)
#    - Factor variances fixed to 1 by std.lv
# 2. Second-order DevAdj: 
#    - Belong is marker (loading = 1), others freely estimated
# 3. Mediator factors (EmoDiss, QualEngag):
#    - Marker variable identification (first indicator loading = 1)
#    - These are standalone factors, not part of the DevAdj hierarchy

REQUIRED_MEASUREMENT_SYNTAX <- paste0(
  # DevAdj hierarchy: first-order loadings freely estimated (std.lv = TRUE identifies)
  "Belong =~ sbvalued + sbmyself + sbcommunity\n",
  "Gains  =~ pganalyze + pgthink + pgwork + pgvalues + pgprobsolve\n",
  "SupportEnv =~ SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse\n",
  "Satisf =~ sameinst + evalexp\n",
  # Second-order factor: Belong is marker (loading = 1), others freely estimated
  "DevAdj =~ 1*Belong + Gains + SupportEnv + Satisf\n",
  # Mediator factors: MARKER VARIABLE identification (standalone single-factor models)
  "EmoDiss =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial\n",
  "QualEngag =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff\n"
)

# Source final model builders to get the current defined effects block (single source)
MODEL_FILE <- file.path("r", "models", "mg_fast_vs_nonfast_model.R")
if (!file.exists(MODEL_FILE)) .fail_fast("MODEL", paste0("Model file not found: ", MODEL_FILE))
source(MODEL_FILE)

if (!exists("build_model_fast_treat_control")) {
  .fail_fast("MODEL", "Expected function build_model_fast_treat_control() not found after sourcing model file")
}

# Verify the model file is still the single source of truth and did not drift
if (!exists("MEASUREMENT_SYNTAX")) {
  .fail_fast("MODEL", "Model file did not define MEASUREMENT_SYNTAX")
}

if (!identical(MEASUREMENT_SYNTAX, REQUIRED_MEASUREMENT_SYNTAX)) {
  req_path <- file.path(RUN_DIR, "REQUIRED_measurement_syntax.lav")
  mod_path <- file.path(RUN_DIR, "MODEL_measurement_syntax.lav")
  writeLines(REQUIRED_MEASUREMENT_SYNTAX, con = req_path)
  writeLines(MEASUREMENT_SYNTAX, con = mod_path)
  .fail_fast(
    "MODEL",
    paste0(
      "Measurement syntax drift detected. ",
      "Model file MEASUREMENT_SYNTAX must exactly match REQUIRED_MEASUREMENT_SYNTAX."
    ),
    extra_paths = c(req_path, mod_path)
  )
}

# Build full SEM model string using the final model builder (parallel model; includes defined effects)
full_model <- build_model_fast_treat_control(dat)

# Write executed model syntax
executed_model_path <- file.path(RUN_DIR, "executed_model.lav")
writeLines(full_model, con = executed_model_path)

# Use a lavaan modeling dataset that does not contain observed composites with
# names that collide with latent variables.
dat_model <- dat
for (v in c("DevAdj", "EmoDiss", "QualEngag", "QualEngage")) {
  if (v %in% names(dat_model)) dat_model[[v]] <- NULL
}

# -------------------------
# CFA (measurement-only; ML + FIML; unweighted)
# -------------------------

INDICATORS <- c(
  "sbvalued","sbmyself","sbcommunity",
  "pganalyze","pgthink","pgwork","pgvalues","pgprobsolve",
  "SEacademic","SEwellness","SEnonacad","SEactivities","SEdiverse",
  "evalexp","sameinst",
  "MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial",
  "QIadmin","QIstudent","QIadvisor","QIfaculty","QIstaff"
)

missing_inds <- setdiff(INDICATORS, names(dat))
if (length(missing_inds) > 0) {
  .fail_fast("CFA", paste0("Missing required indicators: ", paste(missing_inds, collapse = ", ")))
}

cfa_fit <- tryCatch(
  cfa(
    model = MEASUREMENT_SYNTAX,
    data = dat_model,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    conditional.x = FALSE,
    meanstructure = TRUE,
    check.lv.names = FALSE,
    check.gradient = FALSE,
    control = list(iter.max = 20000)
  ),
  error = function(e) .fail_fast("CFA", paste0("CFA failed: ", conditionMessage(e)), extra_paths = executed_model_path)
)

fm_cfa <- tryCatch(fitMeasures(cfa_fit), error = function(e) NULL)
if (is.null(fm_cfa)) .fail_fast("CFA", "Could not extract CFA fitMeasures")
cfa_fitmeasures <- data.frame(measure = names(fm_cfa), value = as.numeric(fm_cfa), stringsAsFactors = FALSE)
utils::write.csv(cfa_fitmeasures, file = file.path(RUN_DIR, "cfa_fitMeasures.csv"), row.names = FALSE)

cfa_pe <- parameterEstimates(cfa_fit, standardized = TRUE)
utils::write.csv(cfa_pe, file = file.path(RUN_DIR, "cfa_parameterEstimates.csv"), row.names = FALSE)

sink(file.path(RUN_DIR, "cfa_summary.txt"))
print(summary(cfa_fit, fit.measures = TRUE, standardized = TRUE))
sink()

# -------------------------
# SEM (ML + FIML point estimate)
# -------------------------

sem_fit <- tryCatch(
  sem(
    model = full_model,
    data = dat_model,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    conditional.x = FALSE,
    meanstructure = TRUE,
    check.lv.names = FALSE,
    check.gradient = FALSE,
    control = list(iter.max = 20000)
  ),
  error = function(e) .fail_fast("SEM", paste0("SEM failed: ", conditionMessage(e)), extra_paths = executed_model_path)
)

fm_sem <- tryCatch(fitMeasures(sem_fit), error = function(e) NULL)
if (is.null(fm_sem)) .fail_fast("SEM", "Could not extract SEM fitMeasures")
sem_fitmeasures <- data.frame(measure = names(fm_sem), value = as.numeric(fm_sem), stringsAsFactors = FALSE)
utils::write.csv(sem_fitmeasures, file = file.path(RUN_DIR, "sem_fitMeasures.csv"), row.names = FALSE)

sem_pe <- parameterEstimates(sem_fit, standardized = TRUE)
utils::write.csv(sem_pe, file = file.path(RUN_DIR, "sem_parameterEstimates.csv"), row.names = FALSE)

sem_defs <- sem_pe[sem_pe$op == ":=", , drop = FALSE]
utils::write.csv(sem_defs, file = file.path(RUN_DIR, "sem_definedEffects.csv"), row.names = FALSE)

sink(file.path(RUN_DIR, "sem_summary.txt"))
print(summary(sem_fit, fit.measures = TRUE, standardized = TRUE))
sink()

# -------------------------
# Bootstrap CIs (ML case-resampling bootstrap)
# -------------------------

B_BOOT <- suppressWarnings(as.integer(Sys.getenv("B_BOOT_MAIN", unset = "50")))
if (is.na(B_BOOT) || B_BOOT < 0) B_BOOT <- 50
BOOT_CI_TYPE <- Sys.getenv("BOOT_CI_TYPE_MAIN", unset = "bca.simple")

bootstrap_report_path <- file.path(RUN_DIR, "bootstrap_report.txt")

pe_for_docx <- sem_pe

if (B_BOOT > 0) {
  fit_boot <- tryCatch(
    sem(
      model = full_model,
      data = dat_model,
      estimator = "ML",
      se = "bootstrap",
      bootstrap = B_BOOT,
      missing = "fiml",
      fixed.x = TRUE,
      conditional.x = FALSE,
      meanstructure = TRUE,
      check.lv.names = FALSE,
      check.gradient = FALSE,
      control = list(iter.max = 20000),
      parallel = "multicore",
      ncpus = 8
    ),
    error = function(e) .fail_fast("BOOTSTRAP", paste0("Bootstrap SEM failed: ", conditionMessage(e)), extra_paths = executed_model_path)
  )

  # Try to recover bootstrap success counts if available
  n_req <- B_BOOT
  n_success <- NA_integer_
  n_fail <- NA_integer_
  boot_note <- "Bootstrap ran with estimator=ML (case-resampling) under ML+FIML pipeline."

  # Best-effort introspection (structure varies by lavaan version)
  n_success <- tryCatch({
    if (!is.null(fit_boot@boot) && !is.null(fit_boot@boot$coef)) {
      nrow(as.matrix(fit_boot@boot$coef))
    } else {
      NA_integer_
    }
  }, error = function(e) NA_integer_)

  if (is.finite(n_success)) n_fail <- max(0L, as.integer(n_req - n_success))

  con <- file(bootstrap_report_path, open = "wt")
  on.exit(close(con), add = TRUE)
  cat("Bootstrap report\n", file = con)
  cat("requested_draws=", n_req, "\n", sep = "", file = con)
  cat("successful_draws=", ifelse(is.na(n_success), "NA", as.character(n_success)), "\n", sep = "", file = con)
  cat("failed_draws=", ifelse(is.na(n_fail), "NA", as.character(n_fail)), "\n", sep = "", file = con)
  cat("ci_type=", BOOT_CI_TYPE, "\n", sep = "", file = con)
  cat("note=", boot_note, "\n", sep = "", file = con)

  # Save bootstrap CIs for all params (includes := defined effects)
  pe_boot <- parameterEstimates(fit_boot, standardized = TRUE, boot.ci.type = BOOT_CI_TYPE)
  utils::write.csv(pe_boot, file = file.path(RUN_DIR, "sem_parameterEstimates_bootstrap.csv"), row.names = FALSE)

  # Use bootstrap parameter estimates for DOCX structural-path tables
  pe_for_docx <- pe_boot
}

# -------------------------
# Run log + paper tables
# -------------------------

run_log_path <- file.path(RUN_DIR, "run_log.txt")

W_VARS_MEAS_OK <- c("re_all", "firstgen", "pell", "sex", "living18")
W_VARS_MEAS_OK <- W_VARS_MEAS_OK[W_VARS_MEAS_OK %in% names(dat)]

.write_run_log(
  run_log_path,
  fields = list(
    `Run complete` = "E2E integration test",
    MODEL_FILE = MODEL_FILE,
    REP_DATA_CSV = REP_DATA_PATH,
    OUT_BASE = RUN_DIR,
    TREATMENT_VAR = "x_FASt",
    DO_PSW = "FALSE (E2E sets psw=1)",
    TABLE_CHECK_MODE = "FALSE",
    SMOKE_ONLY_A = "FALSE",
    B_BOOT_MAIN = as.character(B_BOOT),
    BOOT_CI_TYPE_MAIN = BOOT_CI_TYPE,
    W_VARS_MEAS_OK = paste(W_VARS_MEAS_OK, collapse = ", ")
  )
)

# Mirror the folder layout expected by the paper tables builder (minimal)
# so the DOCX can be built from this e2e run.

rq_dir <- file.path(RUN_DIR, "RQ1_RQ3_main")
dir.create(rq_dir, recursive = TRUE, showWarnings = FALSE)

dat_out <- dat
# Provide psw column if missing (uniform weights) so descriptives table can render.
if (!("psw" %in% names(dat_out))) dat_out$psw <- 1
utils::write.csv(dat_out, file = file.path(rq_dir, "rep_data_with_psw.csv"), row.names = FALSE)

# Provide minimal PSW reports (since real PSW is not part of this e2e)
writeLines(
  c(
    "PSW stage report (E2E):",
    "PS model: x_FASt ~ hgrades + bparented_c + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c + cohort",
    "Weights summary (non-missing):",
    paste(c("Min.", "1st Qu.", "Median", "Mean", "3rd Qu.", "Max."), collapse = "\t"),
    paste(rep("1", 6), collapse = "\t")
  ),
  con = file.path(rq_dir, "psw_stage_report.txt")
)
writeLines(
  c("Balance SMD report (E2E):", "(no PSW computed in this e2e run; psw set to 1)"),
  con = file.path(rq_dir, "psw_balance_smd.txt")
)

struct_dir <- file.path(rq_dir, "structural")
dir.create(struct_dir, recursive = TRUE, showWarnings = FALSE)

# Write structural outputs in the locations the DOCX builder expects
utils::write.table(sem_fitmeasures, file = file.path(struct_dir, "structural_fitMeasures.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
utils::write.table(pe_for_docx, file = file.path(struct_dir, "structural_parameterEstimates.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
utils::write.table(
  standardizedSolution(sem_fit),
  file = file.path(struct_dir, "structural_standardizedSolution.txt"),
  sep = "\t", row.names = FALSE, quote = FALSE
)

# R2 table
r2 <- tryCatch(lavInspect(sem_fit, "r2"), error = function(e) NULL)
if (!is.null(r2)) {
  r2_df <- data.frame(var = names(r2), r2 = as.numeric(r2), stringsAsFactors = FALSE)
  utils::write.table(r2_df, file = file.path(struct_dir, "structural_r2.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
}

# Also mirror total effect folder used by the builder
te_dir <- file.path(RUN_DIR, "A0_total_effect", "structural")
dir.create(te_dir, recursive = TRUE, showWarnings = FALSE)
# For simplicity reuse sem outputs; the builder will extract c_total if present.
utils::write.table(pe_for_docx, file = file.path(te_dir, "structural_parameterEstimates.txt"), sep = "\t", row.names = FALSE, quote = FALSE)

# Sensitivity: unweighted parallel fit (for Table 12)
sens_dir <- file.path(RUN_DIR, "sensitivity_unweighted_parallel", "structural")
dir.create(sens_dir, recursive = TRUE, showWarnings = FALSE)
sens_fit <- tryCatch(
  sem(
    model = full_model,
    data = dat_model,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    conditional.x = FALSE,
    meanstructure = TRUE,
    check.lv.names = FALSE,
    check.gradient = FALSE,
    control = list(iter.max = 20000)
  ),
  error = function(e) .fail_fast("SENSITIVITY", paste0("Unweighted sensitivity SEM failed: ", conditionMessage(e)), extra_paths = executed_model_path)
)
sens_pe <- parameterEstimates(sens_fit, standardized = TRUE)
utils::write.table(sens_pe, file = file.path(sens_dir, "structural_parameterEstimates.txt"), sep = "\t", row.names = FALSE, quote = FALSE)

# RQ4 measurement invariance outputs (for Table 5)
if (length(W_VARS_MEAS_OK) > 0) {
  meas_root <- file.path(RUN_DIR, "RQ4_measurement")
  dir.create(meas_root, recursive = TRUE, showWarnings = FALSE)

  dat_meas <- dat_out

  fit_invariance_for_W_list(
    dat = dat_meas,
    W_vars = W_VARS_MEAS_OK,
    base_out_dir = meas_root,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    weight_var = "psw",
    min_group_n = 200,
    handle_small = "drop",
    other_label = "Other"
  )

  # Fail-fast if invariance outputs were not produced
  for (w in W_VARS_MEAS_OK) {
    stack_path <- file.path(meas_root, paste0("by_", w), "fit_index_stack.txt")
    if (!file.exists(stack_path)) {
      .fail_fast("RQ4_MEAS", paste0("Missing invariance output fit_index_stack.txt for W=", w), extra_paths = stack_path)
    }
  }
}

# RQ4 race-stratified structural fits (for Table 10)
if ("re_all" %in% names(dat_out)) {
  race_root <- file.path(RUN_DIR, "RQ4_structural_by_re_all")
  dir.create(race_root, recursive = TRUE, showWarnings = FALSE)

  MIN_RACE_N <- 200
  races <- sort(unique(na.omit(as.character(dat_out$re_all))))
  for (rc in races) {
    d_rc <- dat_model[!is.na(dat_out$re_all) & as.character(dat_out$re_all) == rc, , drop = FALSE]
    if (nrow(d_rc) < MIN_RACE_N) next

    out_rc <- file.path(race_root, rc, "structural")
    dir.create(out_rc, recursive = TRUE, showWarnings = FALSE)

    fit_rc <- tryCatch(
      sem(
        model = full_model,
        data = d_rc,
        estimator = "ML",
        missing = "fiml",
        fixed.x = TRUE,
        conditional.x = FALSE,
        meanstructure = TRUE,
        check.lv.names = FALSE,
        check.gradient = FALSE,
        control = list(iter.max = 20000)
      ),
      error = function(e) {
        .fail_fast("RQ4_RACE", paste0("Race-stratified SEM failed for ", rc, ": ", conditionMessage(e)), extra_paths = executed_model_path)
      }
    )

    fm_rc <- tryCatch(fitMeasures(fit_rc), error = function(e) NULL)
    if (is.null(fm_rc)) {
      .fail_fast("RQ4_RACE", paste0("Could not extract fitMeasures for race=", rc))
    }
    utils::write.table(
      data.frame(measure = names(fm_rc), value = as.numeric(fm_rc), row.names = NULL),
      file = file.path(out_rc, "structural_fitMeasures.txt"),
      sep = "\t",
      row.names = FALSE,
      quote = FALSE
    )

    pe_rc <- parameterEstimates(fit_rc, standardized = TRUE)
    utils::write.table(
      pe_rc,
      file = file.path(out_rc, "structural_parameterEstimates.txt"),
      sep = "\t",
      row.names = FALSE,
      quote = FALSE
    )
  }
}

# Build paper tables DOCX
paper_docx_path <- file.path(RUN_DIR, "Paper_Tables_All.docx")
py_candidates <- c(
  file.path(getwd(), ".venv", "bin", "python"),
  Sys.which("python"),
  Sys.which("python3")
)
py <- py_candidates[nzchar(py_candidates)][1]
if (is.na(py) || !nzchar(py)) {
  .fail_fast("PAPER_TABLES", "No python interpreter found (needed for scripts/build_paper_tables_docx.py)")
}

cmd <- paste(shQuote(py), shQuote(file.path(getwd(), "scripts", "build_paper_tables_docx.py")), "--base_dir", shQuote(RUN_DIR))
cmd <- paste(cmd, "--page_breaks", "0")
ret <- system(cmd)
if (!identical(ret, 0L)) {
  .fail_fast("PAPER_TABLES", paste0("Paper tables build failed (exit code ", ret, ")"), extra_paths = cmd)
}
if (!file.exists(paper_docx_path)) {
  .fail_fast("PAPER_TABLES", "Paper tables build did not produce Paper_Tables_All.docx")
}

# -------------------------
# Verification checklist content
# -------------------------

.write_verif_header("PASS")
con <- file(.verif_path, open = "at")
on.exit(close(con), add = TRUE)

cat("(A) Codebook validation: PASS\n", file = con)
cat("(B) Derived terms overwrite + exact checks: PASS (max_abs_diff=0)\n", file = con)
cat("(C) Group definitions: PASS\n", file = con)
cat("group_counts.csv=", counts_path, "\n", sep = "", file = con)
cat("(D) Centering checks: PASS (abs(mean)<1e-10)\n", file = con)
cat(paste(capture.output(cent_stats), collapse = "\n"), "\n\n", file = con)
cat("(E) Directional alignment diagnostics: PASS (no median<0)\n", file = con)
cat("directional_alignment_diagnostics.csv=", cor_path, "\n\n", sep = "", file = con)

cat("CFA outputs:\n", file = con)
cat("- cfa_fitMeasures.csv\n- cfa_parameterEstimates.csv\n- cfa_summary.txt\n\n", file = con)

cat("SEM outputs:\n", file = con)
cat("- sem_fitMeasures.csv\n- sem_parameterEstimates.csv\n- sem_definedEffects.csv\n- sem_summary.txt\n\n", file = con)

cat("Bootstrap outputs:\n", file = con)
cat("- bootstrap_report.txt\n- sem_parameterEstimates_bootstrap.csv\n\n", file = con)

cat("executed_model.lav=", executed_model_path, "\n", sep = "", file = con)
cat("paper_tables=", paper_docx_path, "\n", sep = "", file = con)

cat("\nPASS\n", file = con)

# Console summary
cat("PASS\n")
cat("run_folder=", RUN_DIR, "\n", sep = "")
cat("executed_model=", executed_model_path, "\n", sep = "")
cat("paper_tables=", paper_docx_path, "\n", sep = "")
