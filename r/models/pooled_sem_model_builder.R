# ============================================================
# ONE DROP-IN R SCRIPT (VS Code) — revised pooled-cohort SEM
# X and Z+ built from trnsfr_cr
# Pooled cohorts with cohort indicator as covariate
# WLSMV with ordered NSSE items (SB*, pg*, SE*, MHW*, QI*)
# ============================================================

suppressPackageStartupMessages({
  library(lavaan)
})

# ----------------------------
# 1) LOAD DATA
#    Usage:
#      Rscript model_one_pooled_sem.R path/to/your_file.csv
#    If omitted, defaults to "YOUR_ANALYTIC_FILE.csv".
# ----------------------------
args <- commandArgs(trailingOnly = TRUE)
DATA_PATH <- if (length(args) >= 1) args[1] else "YOUR_ANALYTIC_FILE.csv"

dat <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

# ----------------------------
# 2) COHORT INDICATOR (POOLED COHORTS)
#    Uses existing 'cohort' if present; otherwise tries common year fields.
#    Convention here:
#      cohort = 0 for 22/23 (NSSE 2023)
#      cohort = 1 for 23/24 (NSSE 2024)
# ----------------------------
if (!("cohort" %in% names(dat))) {
  yr_candidates <- c(
    "nsse_year", "NSSE_YEAR", "nsse_yr", "NSSE_YR",
    "nsseYear", "NSSEyear", "year", "YEAR"
  )
  yr_found <- yr_candidates[yr_candidates %in% names(dat)]
  if (length(yr_found) == 0) {
    stop("No cohort column found. Add 'cohort' (0=22/23, 1=23/24) or add an NSSE year column (e.g., nsse_year).")
  }
  yr <- suppressWarnings(as.integer(dat[[yr_found[1]]]))
  if (!all(yr %in% c(2023L, 2024L))) {
    stop(paste0("Year column '", yr_found[1], "' must contain 2023 and/or 2024 to build cohort automatically."))
  }
  dat$cohort <- ifelse(yr == 2024L, 1L, 0L)
}

# Ensure cohort is integer-ish
if ("cohort" %in% names(dat)) {
  dat$cohort <- suppressWarnings(as.integer(dat$cohort))
}

# ----------------------------
# 3) BUILD TREATMENT + DOSE FROM trnsfr_cr
#    X (FASt) = 1 if trnsfr_cr >= 12; else 0
#    Z+ = max(0, trnsfr_cr - 12); scaled to Zplus10 = Z+/10 (per 10 credits above 12)
# ----------------------------
if (!("trnsfr_cr" %in% names(dat))) stop("Missing required column: trnsfr_cr")

dat$trnsfr_cr <- suppressWarnings(as.numeric(dat$trnsfr_cr))
dat$FASt      <- ifelse(dat$trnsfr_cr >= 12, 1L, 0L)
dat$Zplus     <- pmax(0, dat$trnsfr_cr - 12)
dat$Zplus10   <- dat$Zplus / 10

# ----------------------------
# 4) REQUIRED VARIABLES CHECK (controls + key indicators)
# ----------------------------
controls <- c(
  "bchsgrade", "bcsmath", "bcscourses", "bchstudy", "bparented",
  "firstgen", "bdegexp", "bchwork", "bcnonacad"
)
missing_controls <- setdiff(controls, names(dat))
if (length(missing_controls) > 0) {
  stop(paste("Missing control variables:", paste(missing_controls, collapse = ", ")))
}

# NSSE core items for Developmental Adjustment domains (from NSSE core codebook)
SB_items <- c("SBmyself", "SBvalued", "SBcommunity")
PG_items <- c("pgwrite", "pgspeak", "pgthink", "pganalyze", "pgwork")
SE_items <- c(
  "SEacademic", "SElearnsup", "SEdiverse", "SEsocial", "SEwellness",
  "SEnonacad", "SEactivities", "SEevents"
)

# Mediators (from your model table)
MHW_items <- c("MHWdacad", "MHWdlonely", "MHWdmental", "MHWdpeers", "MHWdexhaust")
QI_items  <- c("QIstudent", "QIfaculty", "QIadvisor", "QIstaff")

need_vars <- c(SB_items, PG_items, SE_items, MHW_items, QI_items, "cohort", "FASt", "Zplus10", controls)
missing_need <- setdiff(need_vars, names(dat))
if (length(missing_need) > 0) {
  stop(paste("Missing required indicators/fields:", paste(missing_need, collapse = ", ")))
}

# ----------------------------
# 4b) Coerce ordered indicators (recommended for WLSMV)
#     This matches your intended scales:
#       SB/PG/SE: 1-4
#       MHW:      1-6
#       QI:       1-7
# ----------------------------
ordered_4 <- c(SB_items, PG_items, SE_items)
ordered_6 <- MHW_items
ordered_7 <- QI_items

# Coerce to ordered factors if not already.
# (If your data are already ordered factors, this will preserve their ordering.)
for (v in ordered_4) dat[[v]] <- ordered(as.integer(dat[[v]]), levels = 1:4)
for (v in ordered_6) dat[[v]] <- ordered(as.integer(dat[[v]]), levels = 1:6)
for (v in ordered_7) dat[[v]] <- ordered(as.integer(dat[[v]]), levels = 1:7)

# Coerce controls to numeric (lavaan handles factors too, but this keeps intent clear)
for (v in controls) {
  if (v != "firstgen") dat[[v]] <- suppressWarnings(as.numeric(dat[[v]]))
}
# Ensure firstgen is numeric 0/1
if ("firstgen" %in% names(dat)) dat$firstgen <- suppressWarnings(as.numeric(dat$firstgen))

# ----------------------------
# 5) LAVAAN MODEL (POOLED COHORTS + COHORT COVARIATE)
#    Revised design:
#      - X = FASt (threshold at 12 credits)
#      - Zplus10 = credits beyond 12 (per 10 credits)
#      - Sequential + parallel mediation (Distress -> QInteract included)
#      - Y = second-order DevAdj (Belong + Gains + Support)
# ----------------------------
model_one <- "
  # -----------------------
  # Measurement
  # -----------------------
  Distress  =~ MHWdacad + MHWdlonely + MHWdmental + MHWdpeers + MHWdexhaust
  QInteract =~ QIstudent + QIfaculty + QIadvisor + QIstaff

  Belong  =~ SBmyself + SBvalued + SBcommunity
  Gains   =~ pgwrite + pgspeak + pgthink + pganalyze + pgwork
  Support =~ SEacademic + SElearnsup + SEdiverse + SEsocial + SEwellness + SEnonacad + SEactivities + SEevents

  DevAdj =~ Belong + Gains + Support

  # -----------------------
  # Structural (pooled cohorts; cohort indicator included)
  # Treatment: FASt (>=12 credits vs 0-11)
  # Dose beyond threshold: Zplus10 (per +10 credits above 12)
  # -----------------------
  Distress ~ a1*FASt + a1z*Zplus10 + cohort
           + bchsgrade + bcsmath + bcscourses + bchstudy + bparented
           + firstgen + bdegexp + bchwork + bcnonacad

  QInteract ~ a2*FASt + a2z*Zplus10 + d21*Distress + cohort
            + bchsgrade + bcsmath + bcscourses + bchstudy + bparented
            + firstgen + bdegexp + bchwork + bcnonacad

  DevAdj ~ cprime*FASt + cz*Zplus10 + b1*Distress + b2*QInteract + cohort
         + bchsgrade + bcsmath + bcscourses + bchstudy + bparented
         + firstgen + bdegexp + bchwork + bcnonacad

  # Residual covariance between mediators
  Distress ~~ QInteract

  # -----------------------
  # Conditional indirect effects evaluated at Zplus10 = 0, 1, 2
  # (0, +10, +20 credits above 12)
  # -----------------------
  ind_D_z0   := (a1 + a1z*0)*b1
  ind_D_z1   := (a1 + a1z*1)*b1
  ind_D_z2   := (a1 + a1z*2)*b1

  ind_Q_z0   := (a2 + a2z*0)*b2
  ind_Q_z1   := (a2 + a2z*1)*b2
  ind_Q_z2   := (a2 + a2z*2)*b2

  ind_seq_z0 := (a1 + a1z*0)*d21*b2
  ind_seq_z1 := (a1 + a1z*1)*d21*b2
  ind_seq_z2 := (a1 + a1z*2)*d21*b2

  ind_total_z0 := ind_D_z0 + ind_Q_z0 + ind_seq_z0
  ind_total_z1 := ind_D_z1 + ind_Q_z1 + ind_seq_z1
  ind_total_z2 := ind_D_z2 + ind_Q_z2 + ind_seq_z2

  total_z0 := cprime + cz*0 + ind_total_z0
  total_z1 := cprime + cz*1 + ind_total_z1
  total_z2 := cprime + cz*2 + ind_total_z2

  # Dose contribution to each indirect component (per +10 credits above 12)
  dose_ind_D   := a1z*b1
  dose_ind_Q   := a2z*b2
  dose_ind_seq := a1z*d21*b2
"

# ----------------------------
# 6) FIT MODEL (WLSMV; treat indicators as ordered)
# ----------------------------
ordered_vars <- c(ordered_4, ordered_6, ordered_7)

fit <- sem(
  model_one,
  data = dat,
  estimator = "WLSMV",
  ordered = ordered_vars,
  parameterization = "theta",
  std.lv = TRUE,
  missing = "pairwise"
)

print(summary(fit, fit.measures = TRUE, standardized = TRUE))
print(parameterEstimates(fit, standardized = TRUE))
