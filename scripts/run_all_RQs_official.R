#!/usr/bin/env Rscript

# scripts/run_all_RQs_official.R
# ONE run for all RQs:
#  - RQ1–RQ3 (+ RQ4c): overall treatment/control SEM with XZ moderation + bootstrap CIs
#  - RQ4 measurement: invariance by each W separately (incl. race)
#  - RQ4 structural (multi-group by W): estimate the same SEM across W groups and allow structural paths to differ by group
#  - RQ4 structural (race stratified): fit the same SEM within each race category (within-group run; exploratory)

suppressPackageStartupMessages({
  library(lavaan)
})

# -------------------------
# USER SETTINGS (edit these)
# -------------------------
MODEL_FILE   <- "r/models/mg_fast_vs_nonfast_model.R"
REP_DATA_CSV <- "results/repstudy_bootstrap/seed20251223_N3000_B2000_ciperc/rep_data.csv"
OUT_BASE     <- "results/fast_treat_control/official_all_RQs"
# Fix A: DE exposure treatment (0/1)
EXPOSURE_FLAG_COL <- "x_FASt"
TREATMENT_VAR <- "x_DE"


DO_PSW       <- TRUE

# -------------------------
# TABLE-CHECK MODE (super-fast verification)
# -------------------------
# When TRUE, uses tiny bootstraps + percentile CIs and disables bootstrap parallelism.
# Intended only to verify the pipeline runs and tables can be built.
TABLE_CHECK_MODE <- FALSE

# -------------------------
# BOOTSTRAP + CI SETTINGS
# -------------------------
# Main/primary vs exploratory bootstrap counts
B_BOOT_MAIN   <- 2000
B_BOOT_TOTAL  <- 500
B_BOOT_SERIAL <- 200
B_BOOT_MG     <- 200
B_BOOT_RACE   <- 200

# CI type by run (use "bca.simple" for final headline runs; "perc" or "none" for debug/smoke)
BOOT_CI_TYPE_MAIN   <- "bca.simple"
BOOT_CI_TYPE_TOTAL  <- "perc"
BOOT_CI_TYPE_SERIAL <- "perc"
BOOT_CI_TYPE_MG     <- "none"
BOOT_CI_TYPE_RACE   <- "none"

# Don’t bootstrap multi-group / race unless you truly need bootstrap CIs
BOOTSTRAP_MG   <- FALSE
BOOTSTRAP_RACE <- FALSE

# Bootstrap parallelization for lavaan (only used when bootstrap > 0)
BOOT_PARALLEL <- "multicore"
BOOT_NCPUS    <- 6

if (isTRUE(TABLE_CHECK_MODE)) {
  B_BOOT_MAIN <- 20
  BOOT_CI_TYPE_MAIN <- "perc"
  B_BOOT_TOTAL <- 10
  BOOT_CI_TYPE_TOTAL <- "perc"
  B_BOOT_SERIAL <- 10
  BOOT_CI_TYPE_SERIAL <- "perc"

  BOOTSTRAP_MG <- FALSE

  BOOT_PARALLEL <- "no"
  BOOT_NCPUS <- 1
}

# Smoke mode: run only A0/A/A1 with a small bootstrap and cheap CIs, skip RUN B/C2/C
SMOKE_ONLY_A <- FALSE
SMOKE_B_BOOT <- 50
SMOKE_BOOT_CI_TYPE <- "perc"

if (isTRUE(SMOKE_ONLY_A)) {
  B_BOOT_MAIN <- SMOKE_B_BOOT
  B_BOOT_TOTAL <- SMOKE_B_BOOT
  B_BOOT_SERIAL <- SMOKE_B_BOOT
  BOOT_CI_TYPE_MAIN <- SMOKE_BOOT_CI_TYPE
  BOOT_CI_TYPE_TOTAL <- SMOKE_BOOT_CI_TYPE
  BOOT_CI_TYPE_SERIAL <- SMOKE_BOOT_CI_TYPE
  BOOTSTRAP_MG <- FALSE
  BOOTSTRAP_RACE <- FALSE
}

 # RQ4 identity variables (each W separately for MEASUREMENT checks)
W_VARS_MEAS  <- c("re_all", "firstgen", "pell", "sex", "living18")   # edit to match your columns

# RQ4 structural multi-group (each W separately)
# W ordering defines W1..W5 for reporting in outputs:
#   W1 (race): re_all
#   W2 (first-gen): firstgen
#   W3 (Pell): pell
#   W4 (sex): sex
#   W5 (living arrangement): living18
W_VARS_STRUCT <- c("re_all", "firstgen", "pell", "sex", "living18")  # default mirrors W_VARS_MEAS
MIN_W_N_STRUCT <- 200
HANDLE_SMALL_W_STRUCT <- "drop"   # "warn" | "drop" | "combine"
OTHER_LABEL_W_STRUCT <- "Other"

# Reference (baseline) group for each W in multi-group structural runs (g1)
# Values must match labels in the data AFTER any recoding/cleaning.
W_REF_LEVEL <- list(
  re_all   = "White",
  firstgen = "Continuing-gen",
  pell     = "Non-Pell",
  sex      = "Female",
  living18 = "Off campus"
)

# If TRUE, recompute overlap weights within each W-group before multi-group SEM.
# Default FALSE keeps one common overlap-weighted estimand (ATO) across all groups.
PSW_WITHIN_GROUP_FOR_MG <- FALSE

# RQ4 structural stratified-by-race (exploratory; NOT multi-group)
RACE_VAR     <- "re_all"        # edit if your race column name differs
MIN_RACE_N   <- 200             # skip race cells smaller than this for structural run

# Handling small W categories for measurement invariance
MIN_W_N_MEAS     <- 200
HANDLE_SMALL_W   <- "drop"      # "warn" | "drop" | "combine"
OTHER_LABEL_W    <- "Other"

# PSW overlap-weight covariates (edit only if your covariate table changes)
PSW_COVARS <- c("hgrades_c","bparented_c","hapcl","hprecalc13","hchallenge_c","cSFcareer_c","cohort")

# -------------------------
# BASIC CHECKS
# -------------------------
stopifnot(file.exists(MODEL_FILE))
stopifnot(file.exists(REP_DATA_CSV))

dir.create(OUT_BASE, recursive = TRUE, showWarnings = FALSE)
source(MODEL_FILE)

dat <- read.csv(REP_DATA_CSV, stringsAsFactors = FALSE)

# Standardize sex labels for reporting/grouping
if ("sex" %in% names(dat)) {
  dat$sex <- as.character(dat$sex)
  dat$sex[trimws(dat$sex) == "Women"] <- "Female"
  dat$sex[trimws(dat$sex) == "Men"] <- "Male"
}


# -------------------------
# Fix A: build DE exposure indicator (X) from de_participation
# -------------------------
if (!(EXPOSURE_FLAG_COL %in% names(dat))) {
  stop("Fix A requires exposure column not found in rep_data: ", EXPOSURE_FLAG_COL)
}

dat[[TREATMENT_VAR]] <- as.integer(dat[[EXPOSURE_FLAG_COL]] == 1)
if (!all(na.omit(dat[[TREATMENT_VAR]]) %in% c(0, 1))) {
  stop("x_DE must be coded 0/1 derived from ", EXPOSURE_FLAG_COL)
}

# observed interaction term for moderation (overwrite any existing XZ so it matches Fix A)
if (!("credit_dose_c" %in% names(dat))) {
  stop("credit_dose_c not found in rep_data; cannot compute XZ")
}
dat$XZ <- dat[[TREATMENT_VAR]] * dat$credit_dose_c


req <- c(
  "x_DE","credit_dose_c","cohort",
  "hgrades_c","bparented_c","pell","hapcl","hprecalc13","hchallenge_c","cSFcareer_c",
  "sbvalued","sbmyself","sbcommunity",
  "pganalyze","pgthink","pgwork","pgvalues","pgprobsolve",
  "SEacademic","SEwellness","SEnonacad","SEactivities","SEdiverse",
  "sameinst","evalexp",
  "MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial",
  "QIadmin","QIstudent","QIadvisor","QIfaculty","QIstaff"
)
miss <- setdiff(req, names(dat))
if (length(miss) > 0) stop("rep_data missing required columns: ", paste(miss, collapse = ", "))

xvals <- unique(na.omit(dat[[TREATMENT_VAR]]))
if (!all(xvals %in% c(0, 1))) stop("Treatment must be 0/1: ", TREATMENT_VAR)
# Make XZ if absent
if (!("XZ" %in% names(dat))) dat$XZ <- dat$x_DE * dat$credit_dose_c

# -------------------------
# WEIGHTING HELPERS (PSW overlap weights) + balance check
# -------------------------
w_mean <- function(x, w) sum(w * x, na.rm = TRUE) / sum(w[!is.na(x)], na.rm = TRUE)
w_var  <- function(x, w) {
  m <- w_mean(x, w)
  sum(w * (x - m)^2, na.rm = TRUE) / sum(w[!is.na(x)], na.rm = TRUE)
}
smd <- function(x, g, w = NULL) {
  if (is.null(w)) w <- rep(1, length(g))
  x0 <- x[g == 0]; w0 <- w[g == 0]
  x1 <- x[g == 1]; w1 <- w[g == 1]
  m0 <- w_mean(x0, w0); m1 <- w_mean(x1, w1)
  v0 <- w_var(x0, w0);  v1 <- w_var(x1, w1)
  (m1 - m0) / sqrt((v0 + v1) / 2)
}

compute_psw_overlap <- function(d, x = "x_DE", covars, out_txt = NULL) {
  dd <- d
  dd$psw <- NULL

  idx <- which(stats::complete.cases(dd[, c(x, covars)]))
  ps_df <- dd[idx, c(x, covars), drop = FALSE]

  ps_df[[x]] <- as.numeric(ps_df[[x]])
  if (!all(ps_df[[x]] %in% c(0, 1))) stop("x_DE must be 0/1 for PSW stage.")

  f <- stats::as.formula(paste0(x, " ~ ", paste(covars, collapse = " + ")))
  ps_mod <- stats::glm(f, data = ps_df, family = stats::binomial())

  ps <- stats::predict(ps_mod, type = "response")
  # overlap weights: treated get (1-ps); control get ps
  w_raw <- ps_df[[x]] * (1 - ps) + (1 - ps_df[[x]]) * ps
  w <- w_raw / mean(w_raw)

  dd$psw <- NA_real_
  dd$psw[idx] <- w

  if (!is.null(out_txt)) {
    cat("PSW overlap weights\n", file = out_txt)
    cat("PS model: ", deparse(f), "\n\n", file = out_txt, append = TRUE)
    ws <- dd$psw[!is.na(dd$psw)]
    cat("Weights summary (non-missing):\n", file = out_txt, append = TRUE)
    cat(paste(capture.output(summary(ws)), collapse = "\n"), "\n\n", file = out_txt, append = TRUE)
    cat("Weights normalized to mean 1\n", file = out_txt, append = TRUE)
  }

  dd
}

balance_table <- function(d, x = "x_DE", covars, wcol = "psw") {
  g <- as.numeric(d[[x]])
  out <- data.frame(covariate = covars, smd_unweighted = NA_real_, smd_weighted = NA_real_)
  for (i in seq_along(covars)) {
    v <- d[[covars[[i]]]]
    out$smd_unweighted[i] <- smd(v, g, w = rep(1, length(g)))
    w <- d[[wcol]]; w[is.na(w)] <- 0
    out$smd_weighted[i]   <- smd(v, g, w = w)
  }
  out
}

# -------------------------
# RUN A: RQ1–RQ3 (+ RQ4c) overall model
# -------------------------
out_main <- file.path(OUT_BASE, "RQ1_RQ3_main")
dir.create(out_main, recursive = TRUE, showWarnings = FALSE)

dat_main <- dat

if (DO_PSW) {
  dat_main <- compute_psw_overlap(dat_main, covars = PSW_COVARS, out_txt = file.path(out_main, "psw_stage_report.txt"))
  bal <- balance_table(dat_main, covars = PSW_COVARS)
  write.table(bal, file.path(out_main, "psw_balance_smd.txt"), sep = "\t", row.names = FALSE, quote = FALSE)
  write.csv(dat_main, file.path(out_main, "rep_data_with_psw.csv"), row.names = FALSE)
}

# -------------------------
# RUN A0: Total effect (Eq. 1): DevAdj ~ X only (no mediators, no moderator)
#   Uses the same analysis sample + weights as RUN A for comparability.
# -------------------------
out_total <- file.path(OUT_BASE, "A0_total_effect")
dir.create(out_total, recursive = TRUE, showWarnings = FALSE)
fit_total <- fit_mg_fast_vs_nonfast_with_outputs(
  dat = dat_main,
  out_dir = file.path(out_total, "structural"),
  model_type = "total",
  estimator = "MLR",
  missing = "fiml",
  fixed.x = FALSE,
  weight_var = if (DO_PSW) "psw" else NULL,
  bootstrap = B_BOOT_TOTAL,
  boot_ci_type = BOOT_CI_TYPE_TOTAL,
  parallel = if (B_BOOT_TOTAL > 0) BOOT_PARALLEL else "no",
  ncpus = if (B_BOOT_TOTAL > 0) BOOT_NCPUS else 1
)

fit_main <- fit_mg_fast_vs_nonfast_with_outputs(
  dat = dat_main,
  out_dir = file.path(out_main, "structural"),
  model_type = "parallel",
  estimator = "MLR",
  missing = "fiml",
  fixed.x = FALSE,
  weight_var = if (DO_PSW) "psw" else NULL,
  bootstrap = B_BOOT_MAIN,
  boot_ci_type = BOOT_CI_TYPE_MAIN,
  parallel = if (B_BOOT_MAIN > 0) BOOT_PARALLEL else "no",
  ncpus = if (B_BOOT_MAIN > 0) BOOT_NCPUS else 1
)

# -------------------------
# RUN A1: Serial mediation (exploratory add-on)
#   Runs the serial variant (adds EmoDiss -> QualEngag) after the parallel primary model.
# -------------------------
out_serial <- file.path(OUT_BASE, "A1_serial_exploratory")
dir.create(out_serial, recursive = TRUE, showWarnings = FALSE)
fit_serial <- fit_mg_fast_vs_nonfast_with_outputs(
  dat = dat_main,
  out_dir = file.path(out_serial, "structural"),
  model_type = "serial",
  estimator = "MLR",
  missing = "fiml",
  fixed.x = FALSE,
  weight_var = if (DO_PSW) "psw" else NULL,
  bootstrap = B_BOOT_SERIAL,
  boot_ci_type = BOOT_CI_TYPE_SERIAL,
  parallel = if (B_BOOT_SERIAL > 0) BOOT_PARALLEL else "no",
  ncpus = if (B_BOOT_SERIAL > 0) BOOT_NCPUS else 1
)

if (isTRUE(SMOKE_ONLY_A)) {
  message("[SMOKE] SMOKE_ONLY_A=TRUE: completed A0/A/A1 only; skipping RUN B/C2/C.")
  W_VARS_MEAS_OK <- character(0)
  W_VARS_STRUCT_OK <- character(0)
} else {

# -------------------------
# RUN B: RQ4 measurement invariance for each W individually
# -------------------------
out_meas <- file.path(OUT_BASE, "RQ4_measurement")
dir.create(out_meas, recursive = TRUE, showWarnings = FALSE)

# Use the weighted dataset (if created) so measurement checks match the analysis sample
dat_meas <- if (DO_PSW) dat_main else dat

W_VARS_MEAS_OK <- W_VARS_MEAS[W_VARS_MEAS %in% names(dat_meas)]
if (length(W_VARS_MEAS_OK) > 0) {
  fit_invariance_for_W_list(
    dat = dat_meas,
    W_vars = W_VARS_MEAS_OK,
    base_out_dir = out_meas,
    estimator = "MLR",
    missing = "fiml",
    fixed.x = FALSE,
    weight_var = if (DO_PSW) "psw" else NULL,
    min_group_n = MIN_W_N_MEAS,
    handle_small = HANDLE_SMALL_W,
    other_label = OTHER_LABEL_W
  )
}

# Default for logging if structural MG block is skipped
W_VARS_STRUCT_OK <- character(0)

# -------------------------
# RUN C2: RQ4 structural multi-group (each W separately)
#   Same SEM across W groups; structural paths allowed to differ by group.
#   Fast by default: no bootstrap unless BOOTSTRAP_MG == TRUE.
# -------------------------
out_mg <- file.path(OUT_BASE, "RQ4_structural_MG")
dir.create(out_mg, recursive = TRUE, showWarnings = FALSE)

# Use the same weighted data as main model
dat_mg_base <- if (DO_PSW) dat_main else dat

W_VARS_STRUCT_OK <- W_VARS_STRUCT[W_VARS_STRUCT %in% names(dat_mg_base)]

# Decide bootstrap settings for MG runs
MG_BOOT <- if (isTRUE(BOOTSTRAP_MG)) B_BOOT_MG else 0
MG_CI   <- if (MG_BOOT > 0) BOOT_CI_TYPE_MG else "none"

for (i in seq_along(W_VARS_STRUCT_OK)) {
  wvar <- W_VARS_STRUCT_OK[[i]]
  out_w <- file.path(out_mg, paste0("W", i, "_", wvar))
  dir.create(out_w, recursive = TRUE, showWarnings = FALSE)

  dW <- dat_mg_base

  # Coerce to factor for stable grouping
  dW[[wvar]] <- as.character(dW[[wvar]])
  dW[[wvar]] <- trimws(dW[[wvar]])
  dW[[wvar]][dW[[wvar]] == ""] <- NA

  # Handle small categories
  tab <- table(dW[[wvar]], useNA = "no")
  small_levels <- names(tab)[tab < MIN_W_N_STRUCT]

  if (length(small_levels) > 0) {
    if (HANDLE_SMALL_W_STRUCT == "drop") {
      dW[[wvar]][dW[[wvar]] %in% small_levels] <- NA
    } else if (HANDLE_SMALL_W_STRUCT == "combine") {
      dW[[wvar]][dW[[wvar]] %in% small_levels] <- OTHER_LABEL_W_STRUCT
    } else {
      # warn: keep as-is
      writeLines(
        paste0("Warning: small levels kept for ", wvar, ": ", paste(small_levels, collapse = ", ")),
        con = file.path(out_w, "small_levels_warning.txt")
      )
    }
  }

  # Drop rows with missing group (after handling)
  keep_idx <- !is.na(dW[[wvar]])
  dW <- dW[keep_idx, , drop = FALSE]

  # Recompute counts and decide whether to run
  tab2 <- table(dW[[wvar]], useNA = "no")
  ok_levels <- names(tab2)[tab2 >= MIN_W_N_STRUCT]

  if (length(ok_levels) < 2) {
    writeLines(
      c(
        paste0("Skipped MG for W=", wvar, ": fewer than 2 groups with n>=", MIN_W_N_STRUCT),
        "Counts:",
        paste0(names(tab2), " = ", as.integer(tab2))
      ),
      con = file.path(out_w, "skipped_reason.txt")
    )
    next
  }

  # Keep only ok levels (drop any remaining small ones)
  dW <- dW[dW[[wvar]] %in% ok_levels, , drop = FALSE]
  dW[[wvar]] <- factor(dW[[wvar]])

  # Set preferred reference group (g1) when present
  canon <- function(x) {
    x <- as.character(x)
    x <- trimws(x)
    x <- tolower(x)
    x <- gsub("[^a-z0-9]+", "", x)
    x
  }

  ref_pref <- W_REF_LEVEL[[wvar]]
  ref_level <- levels(dW[[wvar]])[1]
  if (!is.null(ref_pref)) {
    levs <- levels(dW[[wvar]])
    m <- which(canon(levs) == canon(ref_pref))
    if (length(m) == 1) {
      ref_level <- levs[[m]]
      dW[[wvar]] <- stats::relevel(dW[[wvar]], ref = ref_level)
    } else {
      message(
        "[RQ4 structural MG] ", wvar,
        ": reference level '", ref_pref,
        "' not found uniquely after cleaning; keeping default reference='", ref_level,
        "'. Levels: ", paste(levs, collapse = ", ")
      )
    }
  }

  # Record reference and levels used
  writeLines(
    c(
      paste0("W_index = ", i),
      paste0("W = ", wvar),
      paste0("reference = ", ref_level),
      "levels:",
      paste0("- ", levels(dW[[wvar]]))
    ),
    con = file.path(out_w, "reference_group.txt")
  )

  # Fit MG structural model
  fit_mg_fast_vs_nonfast_with_outputs(
    dat = dW,
    group = wvar,
    w_label = paste0("W", i),
    out_dir = file.path(out_w, "structural"),
    estimator = "MLR",
    missing = "fiml",
    fixed.x = FALSE,
    weight_var = if (DO_PSW) "psw" else NULL,
    bootstrap = MG_BOOT,
    boot_ci_type = MG_CI,
    parallel = if (MG_BOOT > 0) BOOT_PARALLEL else "no",
    ncpus = if (MG_BOOT > 0) BOOT_NCPUS else 1
  )
}

# -------------------------
# RUN C: RQ4 structural stratified-by-race (exploratory)
#   Fit the same SEM within each race category (within-group run; NOT multi-group).
#   Fast by default: no bootstrap unless BOOTSTRAP_RACE == TRUE.
# -------------------------
out_race <- file.path(OUT_BASE, paste0("RQ4_structural_by_", RACE_VAR))
dir.create(out_race, recursive = TRUE, showWarnings = FALSE)

dat_race_base <- if (DO_PSW) dat_main else dat

RACE_BOOT <- if (isTRUE(BOOTSTRAP_RACE)) B_BOOT_RACE else 0
RACE_CI   <- if (RACE_BOOT > 0) BOOT_CI_TYPE_RACE else "none"

if (!(RACE_VAR %in% names(dat_race_base))) {
  writeLines(
    c(
      paste0("Skipped race-stratified RUN C: RACE_VAR not found: ", RACE_VAR),
      paste0("Available columns: ", paste(names(dat_race_base), collapse = ", "))
    ),
    con = file.path(out_race, "skipped_reason.txt")
  )
} else {
  dR <- dat_race_base
  dR[[RACE_VAR]] <- as.character(dR[[RACE_VAR]])
  dR[[RACE_VAR]] <- trimws(dR[[RACE_VAR]])
  dR[[RACE_VAR]][dR[[RACE_VAR]] == ""] <- NA

  tabR <- table(dR[[RACE_VAR]], useNA = "no")
  race_levels <- names(tabR)[as.integer(tabR) >= MIN_RACE_N]

  if (length(race_levels) == 0) {
    writeLines(
      c(
        paste0("Skipped race-stratified RUN C: no race level has n>=", MIN_RACE_N),
        "Counts:",
        paste0(names(tabR), " = ", as.integer(tabR))
      ),
      con = file.path(out_race, "skipped_reason.txt")
    )
  } else {
    for (race_level in race_levels) {
      dsub <- dR[dR[[RACE_VAR]] == race_level, , drop = FALSE]
      out_level <- file.path(out_race, gsub("[^A-Za-z0-9]+", "_", race_level))
      dir.create(out_level, recursive = TRUE, showWarnings = FALSE)

      writeLines(paste0("RACE_VAR = ", RACE_VAR), con = file.path(out_level, "race_var.txt"))
      writeLines(paste0("race_level = ", race_level), con = file.path(out_level, "race_level.txt"))
      writeLines(paste0("n = ", nrow(dsub)), con = file.path(out_level, "n.txt"))

      fit_mg_fast_vs_nonfast_with_outputs(
        dat = dsub,
        out_dir = file.path(out_level, "structural"),
        model_type = "parallel",
        estimator = "MLR",
        missing = "fiml",
        fixed.x = FALSE,
        weight_var = if (DO_PSW) "psw" else NULL,
        bootstrap = RACE_BOOT,
        boot_ci_type = RACE_CI,
        parallel = if (RACE_BOOT > 0) BOOT_PARALLEL else "no",
        ncpus = if (RACE_BOOT > 0) BOOT_NCPUS else 1
      )
    }
  }
}

}

sink(file.path(OUT_BASE, "run_log.txt"))
cat("Run complete\n")
cat("MODEL_FILE: ", MODEL_FILE, "\n", sep = "")
cat("REP_DATA_CSV: ", REP_DATA_CSV, "\n", sep = "")
cat("OUT_BASE: ", OUT_BASE, "\n", sep = "")
cat("EXPOSURE_FLAG_COL: ", EXPOSURE_FLAG_COL, "\n", sep = "")
cat("TREATMENT_VAR: ", TREATMENT_VAR, "\n", sep = "")
cat("DO_PSW: ", DO_PSW, "\n", sep = "")
cat("TABLE_CHECK_MODE: ", TABLE_CHECK_MODE, "\n", sep = "")
cat("SMOKE_ONLY_A: ", SMOKE_ONLY_A, "\n", sep = "")
cat("B_BOOT_MAIN: ", B_BOOT_MAIN, "\n", sep = "")
cat("BOOT_CI_TYPE_MAIN: ", BOOT_CI_TYPE_MAIN, "\n", sep = "")
cat("B_BOOT_TOTAL: ", B_BOOT_TOTAL, "\n", sep = "")
cat("BOOT_CI_TYPE_TOTAL: ", BOOT_CI_TYPE_TOTAL, "\n", sep = "")
cat("W_VARS_MEAS_OK: ", paste(W_VARS_MEAS_OK, collapse = ", "), "\n", sep = "")
cat("W_VARS_STRUCT_OK: ", paste(W_VARS_STRUCT_OK, collapse = ", "), "\n", sep = "")
cat("BOOTSTRAP_MG: ", BOOTSTRAP_MG, "\n", sep = "")
cat("B_BOOT_MG: ", B_BOOT_MG, "\n", sep = "")
cat("BOOT_CI_TYPE_MG: ", BOOT_CI_TYPE_MG, "\n", sep = "")
cat("BOOTSTRAP_RACE: ", BOOTSTRAP_RACE, "\n", sep = "")
cat("B_BOOT_RACE: ", B_BOOT_RACE, "\n", sep = "")
cat("BOOT_CI_TYPE_RACE: ", BOOT_CI_TYPE_RACE, "\n", sep = "")
cat("B_BOOT_SERIAL: ", B_BOOT_SERIAL, "\n", sep = "")
cat("BOOT_CI_TYPE_SERIAL: ", BOOT_CI_TYPE_SERIAL, "\n", sep = "")
cat("PSW_WITHIN_GROUP_FOR_MG: ", PSW_WITHIN_GROUP_FOR_MG, "\n", sep = "")
cat("RACE_VAR: ", RACE_VAR, "\n", sep = "")
cat("MIN_RACE_N: ", MIN_RACE_N, "\n\n", sep = "")
cat("sessionInfo():\n")
print(sessionInfo())
sink()

message("ALL RQs run complete. Outputs under: ", OUT_BASE)
