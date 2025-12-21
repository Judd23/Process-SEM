# ============================================================
# MC: PSW -> pooled SEM (RQ1–RQ3) + MG SEM a1 test (RQ4; W1–W4 one-at-a-time)
# Design: X = 1(trnsfr_cr >= 12), credit_dose = max(0, trnsfr_cr - 12)/10
# Estimator: WLSMV (ordered indicators)
# Weights: overlap weights from PS model (PSW computed for diagnostics; NOT used as SEM case weights)
# ============================================================

suppressPackageStartupMessages({
  # Needed for non-interactive Rscript runs (prevents 'trying to use CRAN without setting a mirror')
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop(
      "Package 'lavaan' is required but not installed.\n",
      "Install it once, then rerun:\n",
      "  install.packages('lavaan')\n",
      call. = FALSE
    )
  }
  library(lavaan)
})

# 'parallel' ships with base R; no install step needed.

get_arg <- function(flag, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  idx <- match(flag, args)
  if (!is.na(idx) && length(args) >= idx + 1) return(args[idx + 1])
  default
}

# --------------------------------------------------
# PSW handling (environment-safe)
# --------------------------------------------------

USE_PSW <- as.integer(get_arg("--psw", 1))

# PSW is computed for diagnostics only (not passed into SEM)

# Multi-group (RQ4) can be noisy/fragile; keep it behind a switch.
RUN_MG <- as.integer(get_arg("--mg", 1))

# Parallelization (replications over cores)
NCORES <- max(1L, parallel::detectCores() - 1L)

# Save full lavaan output to disk (text files)
SAVE_FITS <- as.integer(get_arg("--save_fits", 1))

# -------------------------
# DEBUG/DIAGNOSTICS
# -------------------------
DIAG_N <- as.integer(get_arg("--diag", 0))

# Representative study mode: generate one dataset and save full outputs for pooled + MG.
DO_REP_STUDY <- as.integer(get_arg("--repStudy", 0))

# Optional: pooled multiple imputation (MI) for representative study only.
# Uses mice + semTools::runMI; derived terms credit_dose_c and XZ_c are recomputed post-imputation.
MI_POOLED <- as.integer(get_arg("--mi_pooled", 0))
MI_M <- as.integer(get_arg("--mi_m", 30))
MI_MAXIT <- as.integer(get_arg("--mi_maxit", 20))

SEED <- as.integer(get_arg("--seed", 20251219))
set.seed(SEED)

# Optional: calibrate item response marginals to match an empirical NSSE dataset
# --item_probs: path to an .rds file containing a named list of probability vectors per item
# --calib_from: path to a CSV file with the NSSE items as columns; if provided, we estimate probs and save an .rds
ITEM_PROBS_FILE <- as.character(get_arg("--item_probs", NA_character_))
CALIB_FROM_FILE <- as.character(get_arg("--calib_from", NA_character_))
ITEM_PROBS <- NULL

# -------------------------
# SETTINGS YOU EDIT FIRST
# -------------------------
R_REPS <- 100
N      <- 3000

# Optional CLI overrides:
#   Rscript mc_allRQs_PSW_pooled_MG_a1.R --N 500 --R 5 --seed 1
R_REPS <- as.integer(get_arg("--R", R_REPS))
N      <- as.integer(get_arg("--N", N))
USE_PSW <- as.integer(get_arg("--psw", USE_PSW))
RUN_MG <- as.integer(get_arg("--mg", RUN_MG))
NCORES <- as.integer(get_arg("--cores", NCORES))
NCORES <- max(1L, NCORES)
SAVE_FITS <- as.integer(get_arg("--save_fits", SAVE_FITS))

# W variables (you run one at a time; rename to match your file)
W_LIST <- c("re_all", "firstgen", "pell", "living18", "sex")

# If provided, run MG (RQ4) for this single W only (recommended for speed).
# Support both --Wvar and the shorter alias --W.
WVAR_SINGLE <- as.character(get_arg("--Wvar", NA_character_))
if (!isTRUE(nzchar(WVAR_SINGLE)) || isTRUE(is.na(WVAR_SINGLE))) {
  WVAR_SINGLE <- as.character(get_arg("--W", NA_character_))
}
if (isTRUE(nzchar(WVAR_SINGLE)) && isTRUE(!is.na(WVAR_SINGLE))) {
  if (!WVAR_SINGLE %in% W_LIST) {
    stop("--Wvar must be one of: ", paste(W_LIST, collapse = ", "))
  }
}

# -------------------------
# OUTPUT HELPERS
# -------------------------
safe_filename <- function(x) {
  x <- gsub("[^A-Za-z0-9_.-]+", "_", as.character(x))
  x <- gsub("_+", "_", x)
  x
}

mk_run_id <- function() {
  # Include enough metadata that files are self-describing
  parts <- c(
    paste0("seed", SEED),
    paste0("N", N),
    paste0("R", R_REPS),
    paste0("psw", USE_PSW),
    paste0("mg", RUN_MG)
  )
  if (isTRUE(nzchar(WVAR_SINGLE)) && isTRUE(!is.na(WVAR_SINGLE))) {
    parts <- c(parts, paste0("W", WVAR_SINGLE))
  }
  safe_filename(paste(parts, collapse = "_"))
}

write_lavaan_output <- function(fit, file_path, title = NULL) {
  if (is.null(fit)) return(invisible(FALSE))
  dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)

  con <- file(file_path, open = "wt")
  on.exit(close(con), add = TRUE)

  w <- function(...) writeLines(paste0(...), con = con)
  w("# ", ifelse(is.null(title), "lavaan output", title))
  w("# Generated: ", as.character(Sys.time()))
  w("#")

  conv <- try(lavInspect(fit, "converged"), silent = TRUE)
  w("Converged: ", if (!inherits(conv, "try-error")) as.character(conv) else "NA")

  w("\n## Summary\n")
  s <- capture.output(summary(fit, standardized = TRUE, fit.measures = TRUE, rsquare = TRUE))
  writeLines(s, con)

  w("\n## Fit measures\n")
  fm <- try(fitMeasures(fit), silent = TRUE)
  if (!inherits(fm, "try-error")) {
    writeLines(capture.output(print(fm)), con)
  } else {
    w("fitMeasures() failed: ", as.character(fm))
  }

  w("\n## Parameter estimates\n")
  pe <- try(parameterEstimates(fit, standardized = TRUE), silent = TRUE)
  if (!inherits(pe, "try-error")) {
    writeLines(capture.output(print(pe)), con)
  } else {
    w("parameterEstimates() failed: ", as.character(pe))
  }

  w("\n## Modification indices (top 50)\n")
  mi <- try(modindices(fit), silent = TRUE)
  if (!inherits(mi, "try-error") && is.data.frame(mi) && nrow(mi) > 0) {
    mi <- mi[order(mi$mi, decreasing = TRUE), , drop = FALSE]
    writeLines(capture.output(print(utils::head(mi, 50))), con)
  } else {
    w("No modindices available (or failed).")
  }

  w("\n## Warnings\n")
  warn <- try(lavInspect(fit, "warnings"), silent = TRUE)
  if (!inherits(warn, "try-error") && length(warn) > 0) {
    writeLines(capture.output(print(warn)), con)
  } else {
    w("(none)")
  }

  invisible(TRUE)
}

run_representative_study <- function(N, use_psw = TRUE) {
  # One full simulated dataset + pooled + MG outputs.
  # Uses the same fitting functions as the MC, but always saves outputs.
  W_TARGETS <- W_LIST
  if (isTRUE(nzchar(WVAR_SINGLE)) && isTRUE(!is.na(WVAR_SINGLE))) W_TARGETS <- WVAR_SINGLE

  rep_dir <- file.path(
    "results",
    "repstudy",
    safe_filename(paste0("seed", SEED, "_N", N, "_psw", as.integer(use_psw), ifelse(isTRUE(nzchar(WVAR_SINGLE)) && !is.na(WVAR_SINGLE), paste0("_W", WVAR_SINGLE), "")))
  )
  dir.create(rep_dir, showWarnings = FALSE, recursive = TRUE)

  # 1) simulate one dataset
  dat <- gen_dat(N)

  # 2) PSW first (diagnostics only)
  if (isTRUE(use_psw)) {
    dat <- make_overlap_weights(dat)
  }

  # 3) pooled SEM
  fitP <- fit_pooled(dat)
  if (is.null(fitP)) stop("Representative pooled SEM failed to converge.")
  write_lavaan_output(fitP, file.path(rep_dir, "pooled.txt"), title = "Representative Study — Pooled SEM (RQ1–RQ3)")
  peP <- parameterEstimates(fitP, standardized = TRUE)
  utils::write.csv(peP, file.path(rep_dir, "pooled_parameterEstimates.csv"), row.names = FALSE)
  fm <- fitMeasures(fitP)
  utils::write.csv(data.frame(measure = names(fm), value = as.numeric(fm)), file.path(rep_dir, "pooled_fitMeasures.csv"), row.names = FALSE)

  # 3b) OPTIONAL: pooled MI (representative study only)
  if (isTRUE(MI_POOLED == 1)) {
    mi_out <- file.path(rep_dir, "mi_summary.txt")
    message("MI pooled enabled: writing ", mi_out)

    if (!requireNamespace("mice", quietly = TRUE)) {
      writeLines(
        c(
          "MI requested via --mi_pooled 1 but package 'mice' is not installed.",
          "Install once then rerun:",
          "  install.packages('mice')"
        ),
        con = mi_out
      )
    } else if (!requireNamespace("semTools", quietly = TRUE)) {
      writeLines(
        c(
          "MI requested via --mi_pooled 1 but package 'semTools' is not installed.",
          "Install once then rerun:",
          "  install.packages('semTools')"
        ),
        con = mi_out
      )
    } else {
      suppressPackageStartupMessages({
        library(mice)
        library(semTools)
      })

      vars_for_mi <- unique(c(
        ORDERED_VARS,
        "X", "credit_dose",
        "hgrades", "bparented", "pell", "hapcl", "hprecalc13", "hchallenge", "cSFcareer", "cohort",
        "re_all", "firstgen", "living18", "sex"
      ))

      dat_mi <- dat[, vars_for_mi, drop = FALSE]
      # Enforce ordered-factor class for ordinal indicators
      for (v in ORDERED_VARS) dat_mi[[v]] <- as.ordered(dat_mi[[v]])

  meth <- mice::make.method(dat_mi)
  meth[ORDERED_VARS] <- "polr"
  meth[c("hgrades", "bparented", "hchallenge", "cSFcareer", "credit_dose")] <- "pmm"
      meth[c("X", "pell", "hapcl", "hprecalc13", "firstgen", "cohort")] <- "logreg"
      meth[c("re_all", "living18", "sex")] <- "polyreg"

      pred <- mice::make.predictorMatrix(dat_mi)
      diag(pred) <- 0

      imp <- try(
        mice::mice(
          dat_mi,
          m = MI_M,
          method = meth,
          predictorMatrix = pred,
          maxit = MI_MAXIT,
          printFlag = isTRUE(DIAG_N > 0),
          seed = SEED
        ),
        silent = TRUE
      )

      if (inherits(imp, "try-error")) {
        writeLines(
          c(
            "MI failed during mice() call.",
            "Error:",
            as.character(imp)
          ),
          con = mi_out
        )
      } else {
        fit_fun <- function(data) {
          # recompute derived terms post-imputation for internal consistency
          zbar <- mean(data$credit_dose, na.rm = TRUE)
          data$credit_dose_c <- as.numeric(scale(data$credit_dose, center = TRUE, scale = FALSE))
          data$XZ_c <- data$X * data$credit_dose_c

          lavaan::sem(
            model = build_model_pooled(zbar = zbar),
            data = data,
            ordered = ORDERED_VARS,
            estimator = "WLSMV",
            parameterization = "theta",
            std.lv = FALSE,
            auto.fix.first = FALSE,
            missing = "pairwise"
          )
        }

        fit_mi <- try(semTools::runMI(data = imp, fun = fit_fun), silent = TRUE)
        if (inherits(fit_mi, "try-error")) {
          writeLines(
            c(
              "MI failed during semTools::runMI() call.",
              "Error:",
              as.character(fit_mi)
            ),
            con = mi_out
          )
        } else {
          con <- file(mi_out, open = "wt")
          on.exit(close(con), add = TRUE)
          writeLines("Representative Study — Pooled MI (mice + semTools::runMI)", con = con)
          writeLines(paste0("m=", MI_M, ", maxit=", MI_MAXIT, ", seed=", SEED), con = con)
          writeLines("", con = con)
          out_txt <- utils::capture.output(summary(fit_mi, standardized = TRUE, fit.measures = TRUE))
          writeLines(out_txt, con = con)
        }
      }
    }
  }

  # 4) descriptives: credit bands + W sizes
  dat$credit_band <- cut(dat$trnsfr_cr, breaks = c(-Inf, 0, 11, Inf), labels = c("0", "1–11", "12+"), right = TRUE)
  tab_credit <- as.data.frame(table(dat$credit_band))
  utils::write.csv(tab_credit, file.path(rep_dir, "credit_bands.csv"), row.names = FALSE)

  # Baseline covariate descriptives (helps sanity-check simulated placeholders)
  covars <- c("hgrades","bparented","pell","hapcl","hprecalc13","hchallenge","cSFcareer","cohort","firstgen")
  covars <- covars[covars %in% names(dat)]
  if (length(covars) > 0) {
    cov_desc <- do.call(
      rbind,
      lapply(covars, function(v) {
        x <- dat[[v]]
        if (is.factor(x) || is.character(x)) x <- as.numeric(factor(x))
        data.frame(
          var = v,
          n = sum(!is.na(x)),
          mean = mean(x, na.rm = TRUE),
          sd = stats::sd(x, na.rm = TRUE),
          min = suppressWarnings(min(x, na.rm = TRUE)),
          p25 = stats::quantile(x, 0.25, na.rm = TRUE, names = FALSE, type = 7),
          median = stats::median(x, na.rm = TRUE),
          p75 = stats::quantile(x, 0.75, na.rm = TRUE, names = FALSE, type = 7),
          max = suppressWarnings(max(x, na.rm = TRUE))
        )
      })
    )
    utils::write.csv(cov_desc, file.path(rep_dir, "baseline_covariates_descriptives.csv"), row.names = FALSE)
  }

  for (Wvar in W_TARGETS) {
    if (Wvar %in% names(dat)) {
      tab_W <- as.data.frame(table(dat[[Wvar]]))
      names(tab_W) <- c(Wvar, "n")
      utils::write.csv(tab_W, file.path(rep_dir, sprintf("W_sizes_%s.csv", safe_filename(Wvar))), row.names = FALSE)
    }
  }

  # 5) MG SEM for each W (no SEM weights)
  for (Wvar in W_TARGETS) {
    datW <- dat
    if (Wvar == "sex") datW$sex <- collapse_sex_2grp(datW$sex)
    if (Wvar %in% c("re_all", "living18")) datW[[Wvar]] <- collapse_small_to_other(datW[[Wvar]])

    outW <- fit_mg_a1_test(datW, Wvar)
    if (is.null(outW$fit)) {
      # save a minimal text note so the folder is still complete
      note_path <- file.path(rep_dir, sprintf("mg_%s_ERROR.txt", safe_filename(Wvar)))
      writeLines(
        c(
          paste0("Representative MG failed for W=", Wvar),
          paste0("reason=", outW$reason)
        ),
        con = note_path
      )
      next
    }

    write_lavaan_output(outW$fit, file.path(rep_dir, sprintf("mg_%s.txt", safe_filename(Wvar))), title = paste0("Representative Study — MG SEM (RQ4, W=", Wvar, ")"))
    peMG <- parameterEstimates(outW$fit, standardized = TRUE)
    utils::write.csv(peMG, file.path(rep_dir, sprintf("mg_parameterEstimates_%s.csv", safe_filename(Wvar))), row.names = FALSE)

    # Wald test
    G <- nlevels(factor(datW[[Wvar]]))
    cnstr <- make_a1_equal_constraints(G)
    wald <- try(lavTestWald(outW$fit, constraints = cnstr), silent = TRUE)
    if (!inherits(wald, "try-error")) {
      utils::write.csv(
        data.frame(stat = wald[["stat"]], df = wald[["df"]], p.value = wald[["p.value"]]),
        file.path(rep_dir, sprintf("mg_wald_%s.csv", safe_filename(Wvar))),
        row.names = FALSE
      )
    }
  }

  message("Representative study saved to: ", rep_dir)
  invisible(list(dat = dat, fitP = fitP))
}

# Minimum per-group size for MG (polychoric/threshold estimation needs space)
# Lowered to reduce 'small_cell' dropouts in MG runs when W has rare categories.
MIN_N_PER_GROUP <- 60

# -------------------------
# VARIABLE NAMES (KEEP CONSISTENT WITH YOUR R FILES)
# -------------------------
ORDERED_VARS <- c(
  "sbmyself","sbvalued","sbcommunity",
  "pgthink","pganalyze","pgwork","pgvalues","pgprobsolve",
  "SEwellness","SEnonacad","SEactivities","SEacademic","SEdiverse",
  "evalexp","sameinst",
  "MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial",
  "QIstudent","QIadvisor","QIfaculty","QIstaff","QIadmin",
  "SFcareer","SFotherwork","SFdiscuss","SFperform"
)

# -------------------------
# HELPERS
# -------------------------
make_ordinal <- function(x, K, probs = NULL) {
  # Converts continuous x to ordered factor with K levels.
  # probs optional; if NULL uses equal-quantile cuts.
  if (is.null(probs)) {
    probs <- rep(1/K, K)
  }
  probs <- probs / sum(probs)
  cuts <- quantile(x, probs = cumsum(probs)[-length(probs)], na.rm = TRUE, type = 7)
  ordered(cut(x, breaks = c(-Inf, cuts, Inf), labels = FALSE, right = TRUE))
}

# --- Calibration helpers ---
# Goal: feed category probabilities into make_ordinal() so simulated items reproduce empirical marginals.

infer_K_for_item <- function(var) {
  if (var %in% c("sbmyself","sbvalued","sbcommunity")) return(5L)
  if (var %in% c(
    "pgthink","pganalyze","pgwork","pgvalues","pgprobsolve",
    "SEwellness","SEnonacad","SEactivities","SEacademic","SEdiverse",
    "evalexp","sameinst",
    "SFcareer","SFotherwork","SFdiscuss","SFperform"
  )) return(4L)
  if (var %in% c("MHWdacad","MHWdlonely","MHWdmental","MHWdexhaust","MHWdsleep","MHWdfinancial")) return(6L)
  if (var %in% c("QIstudent","QIadvisor","QIfaculty","QIstaff","QIadmin")) return(7L)
  NA_integer_
}

normalize_to_1K <- function(x, K) {
  # Accepts ordered factors, factors, character, numeric.
  # Returns integer codes 1..K with NAs preserved.
  if (is.ordered(x) || is.factor(x)) {
    x <- suppressWarnings(as.integer(as.character(x)))
    if (all(is.na(x))) x <- as.integer(x)
  }
  if (is.character(x)) x <- suppressWarnings(as.integer(x))
  if (!is.numeric(x)) x <- suppressWarnings(as.numeric(x))

  # Common NSSE pattern is 1..K; some extracts may be 0..(K-1)
  if (is.finite(suppressWarnings(min(x, na.rm = TRUE))) && is.finite(suppressWarnings(max(x, na.rm = TRUE)))) {
    mn <- suppressWarnings(min(x, na.rm = TRUE))
    mx <- suppressWarnings(max(x, na.rm = TRUE))
    if (mn == 0 && mx == (K - 1)) x <- x + 1
  }

  x <- as.integer(round(x))
  x[!(x %in% seq_len(K))] <- NA_integer_
  x
}

empirical_probs_1K <- function(x, K, eps = 1e-6) {
  x <- normalize_to_1K(x, K)
  tab <- table(factor(x, levels = seq_len(K)), useNA = "no")
  p <- as.numeric(tab)
  s <- sum(p)
  if (!is.finite(s) || s <= 0) return(rep(1 / K, K))
  p <- p / s
  # guard against zero-mass categories (quantile cuts become unstable)
  p <- pmax(p, eps)
  p / sum(p)
}

estimate_item_probs_from_csv <- function(csv_path, vars) {
  df <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  out <- list()
  for (v in vars) {
    if (!v %in% names(df)) next
    K <- infer_K_for_item(v)
    if (is.na(K)) next
    out[[v]] <- empirical_probs_1K(df[[v]], K = K)
  }
  out
}

load_item_probs <- function() {
  # Priority: calib_from (estimate + save) then item_probs (load)
  if (isTRUE(nzchar(CALIB_FROM_FILE)) && isTRUE(!is.na(CALIB_FROM_FILE)) && file.exists(CALIB_FROM_FILE)) {
    probs <- estimate_item_probs_from_csv(CALIB_FROM_FILE, ORDERED_VARS)
    dir.create(file.path("results", "calibration"), showWarnings = FALSE, recursive = TRUE)
    out_path <- file.path("results", "calibration", safe_filename(paste0("item_probs_", basename(CALIB_FROM_FILE), "_", mk_run_id(), ".rds")))
    saveRDS(probs, out_path)
    message("Saved item probability calibration to: ", out_path)
    return(probs)
  }

  if (isTRUE(nzchar(ITEM_PROBS_FILE)) && isTRUE(!is.na(ITEM_PROBS_FILE)) && file.exists(ITEM_PROBS_FILE)) {
    probs <- readRDS(ITEM_PROBS_FILE)
    if (is.list(probs)) return(probs)
  }

  NULL
}

collapse_small_to_other <- function(x, min_n = MIN_N_PER_GROUP, other_label = "Other") {
  x <- as.character(x)
  tab <- table(x)
  small <- names(tab)[tab < min_n]
  if (length(small) > 0) x[x %in% small] <- other_label
  factor(x)
}

collapse_sex_2grp <- function(sex) {
  s <- trimws(tolower(as.character(sex)))
  out <- ifelse(s %in% c("man","male","m"), "Man",
                ifelse(s %in% c("woman","female","f"), "Woman", "Woman"))
  factor(out, levels = c("Woman","Man"))
}

group_sizes_ok <- function(dat, Wvar, min_n = MIN_N_PER_GROUP) {
  g <- dat[[Wvar]]
  if (is.null(g)) return(FALSE)
  tab <- table(g)
  if (length(tab) < 2) return(FALSE)
  all(tab >= min_n)
}

covars_for_mg <- function(Wvar) {
  # Baseline covariates used in SEM equations (selection-bias adjustment proxies)
  # NOTE: firstgen is treated as a demographic/W variable, not a baseline covariate in the SEM.
  # Use centered versions for continuous covariates for stability.
  base <- c("hgrades_c","bparented_c","pell","hapcl","hprecalc13","hchallenge_c","cSFcareer_c","cohort")

  # Drop the grouping variable if it is in the covariate list
  setdiff(base, Wvar)
}

# PSW (overlap weights) computed for diagnostics only (not carried into SEM)
make_overlap_weights <- function(dat) {
  ps_mod <- try(glm(
    X ~ hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c + cohort,
    data = dat, family = binomial()
  ), silent = TRUE)

  ps <- rep(0.5, nrow(dat))
  if (!inherits(ps_mod, "try-error")) {
    ps_hat <- try(predict(ps_mod, newdata = dat, type = "response"), silent = TRUE)
    if (!inherits(ps_hat, "try-error") && length(ps_hat) == nrow(dat)) {
      ps <- as.numeric(ps_hat)
    }
  }

  ps <- pmin(pmax(ps, 1e-3), 1 - 1e-3)
  ow <- ifelse(dat$X == 1, 1 - ps, ps)
  ow <- ow / mean(ow)
  dat$psw <- ow
  dat
}

# -------------------------
# POPULATION PARAMETERS (EDIT IF YOU WANT DIFFERENT "TRUE" EFFECTS)
# -------------------------
PAR <- list(
  # RQ1: direct (X->Y) at threshold + dose slope above threshold
  c  =  0.20,
  cz = -0.10,
  cxz = -0.08,  # X×Z moderation on direct path (RQ1)

  # RQ2: distress mediator
  a1  =  0.35,   # X -> M1 (at threshold)
  a1z =  0.20,   # credit_dose (centered) -> M1 (dose above threshold)
  a1xz =  0.16, # X×Z moderation on X->M1 (RQ2/Model 7 logic)
  b1  = -0.30,   # M1 -> Y

  # RQ3: interaction-quality mediator
  a2  =  0.30,   # X -> M2 (at threshold)
  a2z = -0.08,   # credit_dose (centered) -> M2 (dose above threshold)
  a2xz = -0.08, # X×Z moderation on X->M2 (RQ3/Model 7 logic)
  b2  =  0.35,   # M2 -> Y

  # Optional serial link (set d = 0 if you do NOT want the serial path)
  d   = -0.30,

  # Cohort shifts (pooled indicator)
  g1 = 0.05,
  g2 = 0.00,
  g3 = 0.05
)

BETA_M1 <- c(hgrades = -0.10, bparented = -0.04, pell = 0.09, hapcl = 0.06, hprecalc13 = 0.05, hchallenge = 0.06, cSFcareer = 0.03)
BETA_M2 <- c(hgrades =  0.08, bparented =  0.04, pell = -0.04, hapcl = 0.04, hprecalc13 = 0.06, hchallenge = -0.05, cSFcareer = 0.04)
BETA_Y  <- c(hgrades =  0.10, bparented =  0.05, pell = -0.06, hapcl = 0.05, hprecalc13 = 0.06, hchallenge = -0.06, cSFcareer = 0.04)

LAM <- 0.80  # loading strength for indicators

# -------------------------
# DATA GENERATOR (FULL MODEL)
# -------------------------
gen_dat <- function(N) {

  # Cohort indicator (pooled)
  cohort <- rbinom(N, 1, 0.50)

  # -------------------------
  # Baseline covariates (selection-bias proxies; use only these in the generator)
  # -------------------------
  # Create mild correlation structure via a shared academic-prep factor.
  prep <- rnorm(N, 0, 1)
  bparented <- 0.40*prep + rnorm(N, 0, sqrt(1 - 0.40^2))

  # HS grades: generate a continuous propensity, then collapse to A/B/C/D/F (no +/-)
  hgrades_cont <- 0.60*prep + rnorm(N, 0, sqrt(1 - 0.60^2))

  # Target grade shares (calibration choices): A=0.35, B=0.35, C=0.20, D=0.07, F=0.03
  qF <- stats::quantile(hgrades_cont, probs = 0.03, na.rm = TRUE, type = 7)
  qD <- stats::quantile(hgrades_cont, probs = 0.10, na.rm = TRUE, type = 7)
  qC <- stats::quantile(hgrades_cont, probs = 0.30, na.rm = TRUE, type = 7)
  qB <- stats::quantile(hgrades_cont, probs = 0.65, na.rm = TRUE, type = 7)

  hgrades_AF <- cut(
    hgrades_cont,
    breaks = c(-Inf, qF, qD, qC, qB, Inf),
    labels = c("F","D","C","B","A"),
    right = TRUE,
    ordered_result = TRUE
  )

  # Numeric version for modeling (A=4 ... F=0), then standardize to mean 0 / SD 1
  hgrades_num <- as.numeric(hgrades_AF) - 1
  hgrades     <- as.numeric(scale(hgrades_num, center = TRUE, scale = TRUE))

  # Demographic/W variables
  # First-generation (CSU systemwide undergraduates): "more than one-third" (calibration choice)
  firstgen  <- rbinom(N, 1, 0.35)

  # Pell Grant recipient: "nearly half" (calibration choice)
  pell      <- rbinom(N, 1, 0.50)

  # hapcl: completed >2 AP courses in HS (binary; higher probability with stronger grades)
  hapcl <- rbinom(N, 1, plogis(-0.20 + 0.55*hgrades))

  # hprecalc13: HS attendance type recoded to binary Public(0) vs Private-bucket(1)
  # Private-bucket includes: Private religiously-affiliated, Private not religiously-affiliated, Home school, Other
  hprecalc13_raw_levels <- c(
    "Public",
    "Private religiously-affiliated",
    "Private not religiously-affiliated",
    "Home school",
    "Other"
  )
  # Target: ~87% California public HS, ~13% private-bucket
  hprecalc13_raw_probs  <- c(0.87, 0.05, 0.04, 0.02, 0.02)
  hprecalc13_raw <- sample(hprecalc13_raw_levels, N, replace = TRUE, prob = hprecalc13_raw_probs)
  hprecalc13 <- as.integer(hprecalc13_raw != "Public")

  # hchallenge: HS academic challenge (continuous; related to grades and parental education)
  hchallenge <- 0.35*hgrades + 0.15*bparented + rnorm(N, 0, 1)

  # cSFcareer: baseline career orientation/goals (continuous)
  cSFcareer  <- 0.25*hgrades + rnorm(N, 0, 1)

  # Center selected continuous covariates for SEM stability.
  # Keep the original variables too (useful for descriptives / backwards compatibility),
  # but prefer *_c in SEM covariate tails.
  hgrades_c    <- as.numeric(scale(hgrades,    center = TRUE, scale = FALSE))
  bparented_c  <- as.numeric(scale(bparented,  center = TRUE, scale = FALSE))
  hchallenge_c <- as.numeric(scale(hchallenge, center = TRUE, scale = FALSE))
  cSFcareer_c  <- as.numeric(scale(cSFcareer,  center = TRUE, scale = FALSE))

  # -------------------------
  # W variables (simulation draws; CSU-realistic marginal distributions)
  # -------------------------
  re_all_levels <- c(
    "Hispanic/Latino",
    "White",
    "Asian",
    "Black/African American",
    "Other/Multiracial/Unknown"
  )
  # Target (CSU systemwide, Fall 2024; collapsed): Hispanic 0.489, White 0.201, Asian 0.155, Black 0.041, Other/Multiracial/Unknown 0.114
  re_all_probs <- c(0.489, 0.201, 0.155, 0.041, 0.114)
  re_all <- factor(sample(re_all_levels, N, replace = TRUE, prob = re_all_probs), levels = re_all_levels)

  living18_levels <- c(
    "With family (commuting)",
    "Off-campus (rent/apartment)",
    "On-campus (residence hall)"
  )
  living18_probs <- c(0.40, 0.35, 0.25)
  living18 <- factor(sample(living18_levels, N, replace = TRUE, prob = living18_probs), levels = living18_levels)

  # Sex/Gender: CSU systemwide (federal reporting) is 56% female, 44% male
  sex_levels <- c("Woman","Man")
  sex_probs  <- c(0.56, 0.44)
  sex <- collapse_sex_2grp(sample(sex_levels, N, replace = TRUE, prob = sex_probs))

  # -------------------------
  # Transfer credits (trnsfr_cr)
  # Make credit accumulation depend on the new baseline covariates to encode selection bias.
  # -------------------------
  credit_lat <- 0.50*hgrades + 0.12*bparented + 0.18*hapcl + 0.15*hchallenge + 0.10*cSFcareer -
    0.12*pell - 0.10*hprecalc13 + rnorm(N, 0, 1)
  trnsfr_cr  <- pmax(0, pmin(60, round(10 + 14*credit_lat + rnorm(N, 0, 8))))

  # Treatment + dose from trnsfr_cr (your confirmed rule)
  X <- as.integer(trnsfr_cr >= 12)
  credit_dose <- pmax(0, trnsfr_cr - 12) / 10

  # Center Z to improve numerical stability of XZ interactions in WLSMV.
  # Note: when using XZ interaction, we must use a centered Z term consistently
  # to avoid rank deficiency in the exogenous covariate matrix.
  credit_dose_c <- as.numeric(scale(credit_dose, center = TRUE, scale = FALSE))
  XZ_c <- X * credit_dose_c

  # Keep named categories intact here; collapsing (if needed) is handled at MG-fit time.
  # sex already 2-group

  # additive deltas (kept mild)
  delta_re   <- setNames(seq(-0.08, 0.08, length.out = nlevels(re_all)), levels(re_all))
  delta_live <- setNames(seq(-0.06, 0.06, length.out = nlevels(living18)), levels(living18))
  delta_fg   <- c("0" = -0.03, "1" = 0.03)
  delta_pell <- c("0" = -0.03, "1" = 0.03)
  delta_sex  <- c("Woman" = -0.03, "Man" = 0.03)

  a1_i <- PAR$a1 +
    delta_re[as.character(re_all)] +
    delta_live[as.character(living18)] +
    delta_fg[as.character(firstgen)] +
    delta_pell[as.character(pell)] +
    delta_sex[as.character(sex)]

  # Latent M1 (Distress)
  M1_lat <- (a1_i*X) + (PAR$a1xz*XZ_c) + (PAR$a1z*credit_dose_c) + (PAR$g1*cohort) +
    BETA_M1["hgrades"]*hgrades + BETA_M1["bparented"]*bparented +
    BETA_M1["pell"]*pell + BETA_M1["hapcl"]*hapcl + BETA_M1["hprecalc13"]*hprecalc13 +
    BETA_M1["hchallenge"]*hchallenge + BETA_M1["cSFcareer"]*cSFcareer +
    rnorm(N, 0, 0.70)

  # Latent M2 (Quality of Interactions)
  M2_lat <- (PAR$a2*X) + (PAR$a2xz*XZ_c) + (PAR$a2z*credit_dose_c) + (PAR$d*M1_lat) + (PAR$g2*cohort) +
    BETA_M2["hgrades"]*hgrades + BETA_M2["bparented"]*bparented +
    BETA_M2["pell"]*pell + BETA_M2["hapcl"]*hapcl + BETA_M2["hprecalc13"]*hprecalc13 +
    BETA_M2["hchallenge"]*hchallenge + BETA_M2["cSFcareer"]*cSFcareer +
    rnorm(N, 0, 0.70)

  # Latent DevAdj (second-order)
  Y_lat <- (PAR$c*X) + (PAR$cxz*XZ_c) + (PAR$cz*credit_dose_c) + (PAR$b1*M1_lat) + (PAR$b2*M2_lat) + (PAR$g3*cohort) +
    BETA_Y["hgrades"]*hgrades + BETA_Y["bparented"]*bparented +
    BETA_Y["pell"]*pell + BETA_Y["hapcl"]*hapcl + BETA_Y["hprecalc13"]*hprecalc13 +
    BETA_Y["hchallenge"]*hchallenge + BETA_Y["cSFcareer"]*cSFcareer +
    rnorm(N, 0, 1)

  Belong_lat  <- 0.85*Y_lat + rnorm(N, 0, sqrt(1 - 0.85^2))
  Gains_lat   <- 0.85*Y_lat + rnorm(N, 0, sqrt(1 - 0.85^2))
  SuppEnv_lat <- 0.85*Y_lat + rnorm(N, 0, sqrt(1 - 0.85^2))
  Satisf_lat  <- 0.85*Y_lat + rnorm(N, 0, sqrt(1 - 0.85^2))

  # Generate continuous item tendencies, then make ordinal
  make_item <- function(var, eta, K) {
    p <- NULL
    if (!is.null(ITEM_PROBS) && !is.null(ITEM_PROBS[[var]])) p <- ITEM_PROBS[[var]]
    make_ordinal(eta, K = K, probs = p)
  }

  # SB, PG, SE set to 5-category for SB (Belong) indicators
  sbmyself    <- make_item("sbmyself",    LAM*Belong_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 5)
  sbvalued    <- make_item("sbvalued",    LAM*Belong_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 5)
  sbcommunity <- make_item("sbcommunity", LAM*Belong_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 5)

  pgthink     <- make_item("pgthink",     LAM*Gains_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  pganalyze   <- make_item("pganalyze",   LAM*Gains_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  pgwork      <- make_item("pgwork",      LAM*Gains_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  pgvalues    <- make_item("pgvalues",    LAM*Gains_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  pgprobsolve <- make_item("pgprobsolve", LAM*Gains_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)

  SEwellness   <- make_item("SEwellness",   LAM*SuppEnv_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SEnonacad    <- make_item("SEnonacad",    LAM*SuppEnv_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SEactivities <- make_item("SEactivities", LAM*SuppEnv_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SEacademic   <- make_item("SEacademic",   LAM*SuppEnv_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SEdiverse    <- make_item("SEdiverse",    LAM*SuppEnv_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)

  evalexp  <- make_item("evalexp",  LAM*Satisf_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  sameinst <- make_item("sameinst", LAM*Satisf_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)

  # MHW difficulty set to 6-category
  MHWdacad      <- make_item("MHWdacad",      LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)
  MHWdlonely    <- make_item("MHWdlonely",    LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)
  MHWdmental    <- make_item("MHWdmental",    LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)
  MHWdexhaust   <- make_item("MHWdexhaust",   LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)
  MHWdsleep     <- make_item("MHWdsleep",     LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)
  MHWdfinancial <- make_item("MHWdfinancial", LAM*M1_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 6)

  # Quality of Interactions (NSSE): 7-category frequency/quality items
  QIstudent <- make_item("QIstudent", LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 7)
  QIadvisor <- make_item("QIadvisor", LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 7)
  QIfaculty <- make_item("QIfaculty", LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 7)
  QIstaff   <- make_item("QIstaff",   LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 7)
  QIadmin   <- make_item("QIadmin",   LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 7)

  # Student–Faculty Interaction (NSSE): 4-category frequency items
  SFcareer    <- make_item("SFcareer",    LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SFotherwork <- make_item("SFotherwork", LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SFdiscuss   <- make_item("SFdiscuss",   LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)
  SFperform   <- make_item("SFperform",   LAM*M2_lat + rnorm(N, 0, sqrt(1 - LAM^2)), K = 4)

  dat <- data.frame(
    cohort,
    hgrades, hgrades_c, hgrades_AF, bparented, bparented_c, pell, hapcl, hprecalc13, hchallenge, hchallenge_c, cSFcareer, cSFcareer_c,
    firstgen,
    re_all, living18, sex,
    trnsfr_cr,
  X, credit_dose, credit_dose_c, XZ_c,
    sbmyself, sbvalued, sbcommunity,
    pgthink, pganalyze, pgwork, pgvalues, pgprobsolve,
    SEwellness, SEnonacad, SEactivities, SEacademic, SEdiverse,
    evalexp, sameinst,
    MHWdacad, MHWdlonely, MHWdmental, MHWdexhaust, MHWdsleep, MHWdfinancial,
    QIstudent, QIadvisor, QIfaculty, QIstaff, QIadmin,
    SFcareer, SFotherwork, SFdiscuss, SFperform
  )

  dat
}

# -------------------------
# POOLED SEM SYNTAX (RQ1–RQ3)
# -------------------------
build_model_pooled <- function(zbar) {
  # Probe dose at meaningful entry-credit totals:
  # credit_dose = (entry_credits - 12) / 10
  # Entry credits: 12, 24, 36, 48, 60  ->  credit_dose: 0.0, 1.2, 2.4, 3.6, 4.8
  zc0 <- 0.0 - zbar  # 12 credits at entry
  zc1 <- 1.2 - zbar  # 24 credits at entry
  zc2 <- 2.4 - zbar  # 36 credits at entry
  zc3 <- 3.6 - zbar  # 48 credits at entry
  zc4 <- 4.8 - zbar  # 60 credits at entry

  paste0('
  # measurement (marker-variable identification)
  Belong =~ 1*sbvalued + sbmyself + sbcommunity
  Gains  =~ 1*pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
  SuppEnv =~ 1*SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
  Satisf =~ 1*sameinst + evalexp
  DevAdj =~ 1*Belong + Gains + SuppEnv + Satisf

  M1 =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
  M2 =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff + SFcareer + SFotherwork + SFdiscuss + SFperform

  # structural (pooled)
  M1 ~ a1*X + a1xz*XZ_c + a1z*credit_dose_c + g1*cohort +
    hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

  M2 ~ a2*X + a2xz*XZ_c + a2z*credit_dose_c + d*M1 + g2*cohort +
    hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

  DevAdj ~ c*X + cxz*XZ_c + cz*credit_dose_c + b1*M1 + b2*M2 + g3*cohort +
    hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

  # conditional effects along entry credits = 12,24,36,48,60 (raw credit_dose = 0.0,1.2,2.4,3.6,4.8)

  # X->M paths conditional on Z (a-paths)
  a1_z0 := a1 + a1xz*', sprintf('%.8f', zc0), '
  a1_z1 := a1 + a1xz*', sprintf('%.8f', zc1), '
  a1_z2 := a1 + a1xz*', sprintf('%.8f', zc2), '
  a1_z3 := a1 + a1xz*', sprintf('%.8f', zc3), '
  a1_z4 := a1 + a1xz*', sprintf('%.8f', zc4), '

  a2_z0 := a2 + a2xz*', sprintf('%.8f', zc0), '
  a2_z1 := a2 + a2xz*', sprintf('%.8f', zc1), '
  a2_z2 := a2 + a2xz*', sprintf('%.8f', zc2), '
  a2_z3 := a2 + a2xz*', sprintf('%.8f', zc3), '
  a2_z4 := a2 + a2xz*', sprintf('%.8f', zc4), '

  # indirects (parallel)
  ind_M1_z0 := a1_z0*b1
  ind_M1_z1 := a1_z1*b1
  ind_M1_z2 := a1_z2*b1
  ind_M1_z3 := a1_z3*b1
  ind_M1_z4 := a1_z4*b1

  ind_M2_z0 := a2_z0*b2
  ind_M2_z1 := a2_z1*b2
  ind_M2_z2 := a2_z2*b2
  ind_M2_z3 := a2_z3*b2
  ind_M2_z4 := a2_z4*b2

  # serial
  ind_serial_z0 := a1_z0*d*b2
  ind_serial_z1 := a1_z1*d*b2
  ind_serial_z2 := a1_z2*d*b2
  ind_serial_z3 := a1_z3*d*b2
  ind_serial_z4 := a1_z4*d*b2

  # direct (X->Y) conditional on Z
  direct_z0 := c + cxz*', sprintf('%.8f', zc0), '
  direct_z1 := c + cxz*', sprintf('%.8f', zc1), '
  direct_z2 := c + cxz*', sprintf('%.8f', zc2), '
  direct_z3 := c + cxz*', sprintf('%.8f', zc3), '
  direct_z4 := c + cxz*', sprintf('%.8f', zc4), '

  total_z0 := direct_z0 + ind_M1_z0 + ind_M2_z0 + ind_serial_z0
  total_z1 := direct_z1 + ind_M1_z1 + ind_M2_z1 + ind_serial_z1
  total_z2 := direct_z2 + ind_M1_z2 + ind_M2_z2 + ind_serial_z2
  total_z3 := direct_z3 + ind_M1_z3 + ind_M2_z3 + ind_serial_z3
  total_z4 := direct_z4 + ind_M1_z4 + ind_M2_z4 + ind_serial_z4
')
}

# -------------------------
# MG SEM FOR RQ4 (ONLY a1 VARIES BY GROUP)
# -------------------------
make_model_mg_a1 <- function(G, cov_string) {
  a1_vec  <- paste0("a1_", seq_len(G))
  a1xz_vec <- paste0("a1xz_", seq_len(G))
  a1_free  <- paste0("c(", paste(a1_vec, collapse = ","), ")*X")
  a1xz_free <- paste0("c(", paste(a1xz_vec, collapse = ","), ")*XZ_c")

  paste0('
    # measurement (marker-variable identification)
    Belong =~ 1*sbvalued + sbmyself + sbcommunity
    Gains  =~ 1*pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
    SuppEnv =~ 1*SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
    Satisf =~ 1*sameinst + evalexp
    DevAdj =~ 1*Belong + Gains + SuppEnv + Satisf

    M1 =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
    M2 =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff + SFcareer + SFotherwork + SFdiscuss + SFperform

    # structural (a1 and a1xz vary by group; other paths equal)
  M1 ~ ', a1_free, ' + ', a1xz_free, ' + a1z*credit_dose_c + g1*cohort + ', cov_string, '

  M2 ~ a2*X + a2xz*XZ_c + a2z*credit_dose_c + d*M1 + g2*cohort + ', cov_string, '

  DevAdj ~ c*X + cxz*XZ_c + cz*credit_dose_c + b1*M1 + b2*M2 + g3*cohort + ', cov_string, '
  ')
}

make_a1_equal_constraints <- function(G) {
  # a1_1 == a1_2 == ... == a1_G  AND  a1xz_1 == a1xz_2 == ... == a1xz_G
  if (G <= 1) return("")
  c1 <- paste(sapply(2:G, function(g) sprintf("a1_1 == a1_%d", g)), collapse = ";\n")
  c2 <- paste(sapply(2:G, function(g) sprintf("a1xz_1 == a1xz_%d", g)), collapse = ";\n")
  paste(c(c1, c2), collapse = ";\n")
}

fit_pooled <- function(dat) {
  args <- list(
    model = build_model_pooled(zbar = mean(dat$credit_dose, na.rm = TRUE)),
    data = dat,
    ordered = ORDERED_VARS,
    estimator = "WLSMV",
    parameterization = "theta",
    std.lv = FALSE,
    auto.fix.first = FALSE,
    missing = "pairwise",
    control = list(iter.max = 2000)  # hard stop instead of endless churn
  )

  # IMPORTANT:
  # lavaan + ordered indicators + WLSMV + sampling.weights is currently unstable here
  # (internal "subscript out of bounds" during W-matrix construction).
  # We therefore compute PSW but do NOT pass it into SEM estimation.

  fit <- tryCatch(
    do.call(lavaan::sem, args),
    error = function(e) {
      message("[pooled fit_error] ", e$message)
      return(NULL)
    }
  )
  if (is.null(fit)) return(NULL)
  if (!isTRUE(lavInspect(fit, "converged"))) {
    if (isTRUE(DIAG_N > 0)) {
      message("fit_pooled(): model did not converge")
      warn <- try(lavInspect(fit, "warnings"), silent = TRUE)
      if (!inherits(warn, "try-error") && length(warn) > 0) {
        message("Warnings (first 5):")
        message(paste0("- ", head(warn, 5), collapse = "\n"))
      }
    }
    return(NULL)
  }

  fit
}

fit_mg_a1_test <- function(dat, Wvar) {
  dat[[Wvar]] <- factor(dat[[Wvar]])
  G <- nlevels(dat[[Wvar]])
  if (G < 2) return(list(ok = FALSE, p = NA_real_, reason = "one_group", fit = NULL))

  if (!group_sizes_ok(dat, Wvar)) return(list(ok = FALSE, p = NA_real_, reason = "small_cell", fit = NULL))

  covs <- covars_for_mg(Wvar)
  cov_string <- paste(covs[covs != "cohort"], collapse = " + ")
  # cohort is already included explicitly as g*cohort terms, so don't double-add it
  model_mg <- make_model_mg_a1(G, cov_string)

  args <- list(
    model = model_mg,
    data = dat,
    group = Wvar,
    ordered = ORDERED_VARS,
    estimator = "WLSMV",
    parameterization = "theta",
    std.lv = FALSE,
    auto.fix.first = FALSE,
    missing = "pairwise",
    # make measurement comparable for MG test in the simulation
    group.equal = c("loadings","thresholds")
  )

  fit0 <- try(do.call(lavaan::sem, args), silent = TRUE)
  if (inherits(fit0, "try-error")) {
    if (isTRUE(DIAG_N > 0)) {
      msg <- as.character(fit0)
      message("[MG fit_error] Wvar=", Wvar, " | ", msg)
    }
    return(list(ok = FALSE, p = NA_real_, reason = "fit_error", fit = NULL))
  }
  if (!isTRUE(lavInspect(fit0, "converged"))) return(list(ok = FALSE, p = NA_real_, reason = "no_converge", fit = fit0))

  fit <- fit0
  cnstr <- make_a1_equal_constraints(G)
  wald <- try(lavTestWald(fit, constraints = cnstr), silent = TRUE)
  if (inherits(wald, "try-error")) return(list(ok = FALSE, p = NA_real_, reason = "wald_error", fit = fit))

  p <- as.numeric(wald[["p.value"]])
  if (!is.finite(p)) return(list(ok = FALSE, p = NA_real_, reason = "bad_p", fit = fit))

  list(ok = TRUE, p = p, reason = "ok", fit = fit)
}

run_mc <- function() {
  # -------------------------
  # MONTE CARLO RUN
  # -------------------------
  # storage
  W_TARGETS <- W_LIST
  if (isTRUE(nzchar(WVAR_SINGLE)) && isTRUE(!is.na(WVAR_SINGLE))) W_TARGETS <- WVAR_SINGLE

  pooled_targets <- c("a1","a1xz","a1z","a2","a2xz","a2z","d","c","cxz","cz","b1","b2",
                      "a1_z0","a1_z1","a1_z2","a1_z3","a1_z4",
                      "a2_z0","a2_z1","a2_z2","a2_z3","a2_z4",
                      "direct_z0","direct_z1","direct_z2","direct_z3","direct_z4",
                      "ind_M1_z0","ind_M1_z1","ind_M1_z2","ind_M1_z3","ind_M1_z4",
                      "ind_M2_z0","ind_M2_z1","ind_M2_z2","ind_M2_z3","ind_M2_z4",
                      "ind_serial_z0","ind_serial_z1","ind_serial_z2","ind_serial_z3","ind_serial_z4",
                      "total_z0","total_z1","total_z2","total_z3","total_z4")

  pooled_est <- as.data.frame(matrix(NA_real_, nrow = R_REPS, ncol = length(pooled_targets)))
  names(pooled_est) <- pooled_targets
  pooled_converged <- rep(0L, R_REPS)

  rq4_pvals <- setNames(as.data.frame(matrix(NA_real_, nrow = R_REPS, ncol = length(W_TARGETS))), W_TARGETS)
  rq4_ok    <- setNames(as.data.frame(matrix(0L, nrow = R_REPS, ncol = length(W_TARGETS))), W_TARGETS)
  rq4_reason <- lapply(W_TARGETS, function(x) rep(NA_character_, R_REPS))
  names(rq4_reason) <- W_TARGETS

  # --- One replication as a pure function (makes parallelization easy) ---
  one_rep <- function(r) {
    dat <- gen_dat(N)

    # PSW first (weights computed prior to SEM estimation)
    if (isTRUE(USE_PSW == 1)) {
      dat <- make_overlap_weights(dat)
    }

    # pooled SEM (tests RQ1–RQ3)
    pooled_ok <- 0L
    pooled_row <- setNames(as.list(rep(NA_real_, length(pooled_targets))), pooled_targets)
    fitP <- fit_pooled(dat)
    pooled_path <- NA_character_
    if (!is.null(fitP)) {
      pooled_ok <- 1L
      pe <- parameterEstimates(fitP)
      pe2 <- pe[pe$label %in% pooled_targets & pe$op %in% c("~",":="), c("label","est")]
      if (nrow(pe2) > 0) {
        for (i in seq_len(nrow(pe2))) pooled_row[[pe2$label[i]]] <- pe2$est[i]
      }

      if (isTRUE(SAVE_FITS == 1)) {
        run_dir <- file.path("results", "lavaan", mk_run_id())
        pooled_path <- file.path(run_dir, sprintf("rep%03d_pooled.txt", r))
        write_lavaan_output(fitP, pooled_path, title = paste0("Pooled SEM (rep ", r, ")"))
      }
    }

    # RQ4: MG tests, one W at a time (a1 differs by group)
    mg <- list()
    mg_paths <- list()
    if (isTRUE(RUN_MG == 1)) {
      for (Wvar in W_TARGETS) {
        # light category handling for MC stability
        if (Wvar == "sex") dat$sex <- collapse_sex_2grp(dat$sex)
        if (Wvar %in% c("re_all","living18")) dat[[Wvar]] <- collapse_small_to_other(dat[[Wvar]])

        outW <- fit_mg_a1_test(dat, Wvar)
        mg[[Wvar]] <- outW

        if (isTRUE(SAVE_FITS == 1) && !is.null(outW[["fit"]])) {
          run_dir <- file.path("results", "lavaan", mk_run_id())
          mg_path <- file.path(run_dir, sprintf("rep%03d_mg_%s.txt", r, safe_filename(Wvar)))
          mg_paths[[Wvar]] <- mg_path
          write_lavaan_output(outW$fit, mg_path, title = paste0("MG SEM (W=", Wvar, ", rep ", r, ")"))
        }
      }
    }

    list(
      pooled_ok = pooled_ok,
      pooled_row = pooled_row,
      pooled_path = pooled_path,
      mg = mg,
      mg_paths = mg_paths
    )
  }

  # --- Run replications ---
  reps <- seq_len(R_REPS)
  if (isTRUE(DIAG_N > 0)) {
    message("run_mc(): reps=", R_REPS, ", N=", N, ", mg=", RUN_MG, ", psw=", USE_PSW, ", cores=", NCORES)
  }

  # Reproducible parallel RNG: each fork inherits stream; we then set per-rep seed.
  # NOTE: forking (mclapply) works on macOS/Linux. On Windows, run sequential.
  results <- NULL
  if (.Platform$OS.type != "windows" && NCORES > 1L) {
    results <- parallel::mclapply(
      reps,
      function(r) {
        set.seed(SEED + r)
        one_rep(r)
      },
      mc.cores = NCORES
    )
  } else {
    results <- lapply(
      reps,
      function(r) {
        set.seed(SEED + r)
        one_rep(r)
      }
    )
  }

  # --- Collect results back into the pre-allocated containers ---
  for (r in reps) {
    out <- results[[r]]
    pooled_converged[r] <- out$pooled_ok
    pooled_est[r, names(out$pooled_row)] <- as.numeric(out$pooled_row)

    if (isTRUE(RUN_MG == 1) && length(out$mg) > 0) {
      for (Wvar in names(out$mg)) {
        outW <- out$mg[[Wvar]]
        rq4_reason[[Wvar]][r] <- outW$reason
        if (isTRUE(outW$ok)) {
          rq4_ok[r, Wvar] <- 1L
          rq4_pvals[r, Wvar] <- outW$p
        }
      }
    }
  }

  # -------------------------
  # SUMMARIES
  # -------------------------
  cat("\n=============================\n")
  cat("POOLED SEM (RQ1–RQ3)\n")
  cat("Convergence rate:", mean(pooled_converged), "\n")

  # quick bias/SD table for core paths
  core <- c("c","cxz","cz","a1","a1xz","a1z","a2","a2xz","a2z","b1","b2","d")
  truth <- c(c = PAR$c, cxz = PAR$cxz, cz = PAR$cz,
             a1 = PAR$a1, a1xz = PAR$a1xz, a1z = PAR$a1z,
             a2 = PAR$a2, a2xz = PAR$a2xz, a2z = PAR$a2z,
             b1 = PAR$b1, b2 = PAR$b2, d = PAR$d)

  summ <- data.frame(
    param = core,
    true  = as.numeric(truth[core]),
    mean_est = sapply(core, function(p) mean(pooled_est[[p]], na.rm = TRUE)),
    sd_est   = sapply(core, function(p) sd(pooled_est[[p]], na.rm = TRUE)),
    bias     = sapply(core, function(p) mean(pooled_est[[p]], na.rm = TRUE) - truth[p])
  )
  print(summ, row.names = FALSE)

  if (isTRUE(RUN_MG == 1)) {
    cat("\n=============================\n")
    if (isTRUE(nzchar(WVAR_SINGLE)) && isTRUE(!is.na(WVAR_SINGLE))) {
      cat("RQ4 MG a1 tests (W = ", WVAR_SINGLE, ")\n", sep = "")
    } else {
      cat("RQ4 MG a1 tests (one W at a time)\n")
    }
    for (Wvar in names(rq4_pvals)) {
      used <- which(rq4_ok[[Wvar]] == 1 & is.finite(rq4_pvals[[Wvar]]))
      power <- if (length(used) > 0) mean(rq4_pvals[[Wvar]][used] < 0.05) else NA_real_
      cat("\nW:", Wvar, "\n")
      cat("Used reps:", length(used), " / ", R_REPS, "\n", sep = "")
      cat("Power (reject equal a1 across groups):", power, "\n")
      cat("Fail reasons:\n")
      print(sort(table(rq4_reason[[Wvar]], useNA = "ifany"), decreasing = TRUE))
    }
  }

  invisible(list(
    pooled_est = pooled_est,
    pooled_converged = pooled_converged,
    rq4_pvals = rq4_pvals,
    rq4_ok = rq4_ok,
    rq4_reason = rq4_reason
  ))
}

# Only run the Monte Carlo when executed via Rscript, not when sourced()
if (sys.nframe() == 0) {
  # Load calibrated item marginals once so gen_dat() can reuse them
  ITEM_PROBS <<- load_item_probs()
  if (!is.null(ITEM_PROBS)) {
    message("Item marginals: using calibrated probabilities for ", length(ITEM_PROBS), " items")
  } else {
    message("Item marginals: using default equal-quantile cuts (no calibration loaded)")
  }
  if (isTRUE(DO_REP_STUDY == 1)) {
    run_representative_study(N = N, use_psw = isTRUE(USE_PSW == 1))
  } else {
    run_mc()
  }
}
