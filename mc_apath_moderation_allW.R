# ============================================================
# One-file Monte Carlo: a-path moderation via multi-group SEM
# Simulate moderation for ONE W at a time, run ALL four W's in one run
# W variables: re_all, firstgen, living, sex
#
# Run (single command):
#   Rscript mc_apath_moderation_allW.R --N 1500 --R 200 --seed 12345 --p_fast 0.20
#
# Output:
#   mc_apath_W_re_all_N1500_R200_seed12345.rds
#   mc_apath_W_firstgen_N1500_R200_seed12345.rds
#   mc_apath_W_living_N1500_R200_seed12345.rds
#   mc_apath_W_sex_N1500_R200_seed12345.rds
# ============================================================

# ---------- minimal arg parser (no extra packages) ----------
get_arg <- function(flag, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  idx <- match(flag, args)
  if (!is.na(idx) && length(args) >= idx + 1) return(args[idx + 1])
  default
}

# ---------- safe package install to user library ----------
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    lib <- Sys.getenv("R_LIBS_USER")
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    install.packages(pkg, repos = "https://cloud.r-project.org", lib = lib)
  }
}

install_if_missing("lavaan")
library(lavaan)

seed   <- as.integer(get_arg("--seed", 12345))
N      <- as.integer(get_arg("--N", 1500))
Rreps  <- as.integer(get_arg("--R", 200))
p_fast <- as.numeric(get_arg("--p_fast", 0.20))

set.seed(seed)

# ---------- helper: continuous -> ordinal integer codes ----------
make_ord_int <- function(y, cuts) as.integer(cut(y, breaks = c(-Inf, cuts, Inf), labels = FALSE))

# ============================================================
# 1) ANALYSIS MODEL (same measurement + structure as your MC)
# ============================================================
analysis_model <- '
  # measurement
  Distress =~ MHWdacad + MHWdlonely + MHWdmental + MHWdpeers + MHWdexhaust
  Interact =~ QIstudent + QIfaculty + QIadvisor + QIstaff

  Belong  =~ SB1 + SB2 + SB3
  Gains   =~ PG1 + PG2 + PG3 + PG4 + PG5
  Support =~ SE1 + SE2 + SE3
  Adj =~ Belong + Gains + Support

  # structural (a-paths are the ones we test for moderation)
  Distress ~ FASt + Zplus10 + prep
  Interact ~ FASt + Zplus10 + prep
  Adj ~ FASt + Zplus10 + Distress + Interact + prep

  Distress ~~ Interact
'

ordered_vars <- c(
  "SB1","SB2","SB3","PG1","PG2","PG3","PG4","PG5","SE1","SE2","SE3",
  "MHWdacad","MHWdlonely","MHWdmental","MHWdpeers","MHWdexhaust",
  "QIstudent","QIfaculty","QIadvisor","QIstaff"
)

# ============================================================
# 2) GROUP DEFINITIONS (EDIT PROBS/LABELS TO MATCH YOUR DATA)
#    These W variables exist in every replication.
#    Only ONE W at a time will drive true a-path moderation.
# ============================================================
gen_W <- function(N) {
  re_all <- sample(
    x = c("White","Latine","Black","Asian","Other"),
    size = N, replace = TRUE,
    prob = c(0.35, 0.30, 0.10, 0.15, 0.10)
  )

  firstgen <- sample(x = c("0","1"), size = N, replace = TRUE, prob = c(0.55, 0.45))

  living <- sample(
    x = c("OnCampus","OffCampus","Family"),
    size = N, replace = TRUE,
    prob = c(0.20, 0.45, 0.35)
  )

  sex <- sample(
    x = c("Woman","Man","Nonbinary"),
    size = N, replace = TRUE,
    prob = c(0.55, 0.43, 0.02)
  )

  list(
    re_all = factor(re_all),
    firstgen = factor(firstgen),
    living = factor(living),
    sex = factor(sex)
  )
}

# ============================================================
# 3) A-PATH MODERATION MAPS (EDIT EFFECTS IF YOU WANT)
#    Baseline (no moderation): same a-paths for everyone.
#    When moderation is "on" for a W, we swap to group-specific a's.
# ============================================================
baseline_a <- c(a1 = 0.20, a1z = 0.10, a2 = 0.15, a2z = -0.10)

a_map_re_all <- list(
  White  = c(a1=0.20, a1z=0.10, a2=0.15, a2z=-0.10),
  Latine = c(a1=0.28, a1z=0.12, a2=0.10, a2z=-0.06),
  Black  = c(a1=0.35, a1z=0.15, a2=0.06, a2z=-0.02),
  Asian  = c(a1=0.18, a1z=0.08, a2=0.18, a2z=-0.12),
  Other  = c(a1=0.24, a1z=0.10, a2=0.12, a2z=-0.08)
)

a_map_firstgen <- list(
  `0` = c(a1=0.18, a1z=0.08, a2=0.17, a2z=-0.10),
  `1` = c(a1=0.30, a1z=0.14, a2=0.09, a2z=-0.06)
)

a_map_living <- list(
  OnCampus  = c(a1=0.16, a1z=0.08, a2=0.20, a2z=-0.12),
  OffCampus = c(a1=0.24, a1z=0.11, a2=0.13, a2z=-0.08),
  Family    = c(a1=0.32, a1z=0.15, a2=0.07, a2z=-0.04)
)

a_map_sex <- list(
  Woman     = c(a1=0.22, a1z=0.11, a2=0.14, a2z=-0.10),
  Man       = c(a1=0.18, a1z=0.08, a2=0.17, a2z=-0.10),
  Nonbinary = c(a1=0.30, a1z=0.14, a2=0.10, a2z=-0.06)
)

get_a_map <- function(W) {
  switch(
    W,
    re_all   = a_map_re_all,
    firstgen = a_map_firstgen,
    living   = a_map_living,
    sex      = a_map_sex,
    stop("Unknown W: ", W)
  )
}

# ============================================================
# 4) DATA GENERATOR WITH "ONE W AT A TIME" a-PATH MODERATION
# ============================================================
gen_dat <- function(N, p_fast, moderate_W = c("re_all","firstgen","living","sex"),
                    # non-a structural parameters (constant across groups here)
                    b1 = -0.30, b2 = 0.40,
                    cprime = 0.10, cz = -0.05,
                    rho_m12 = -0.25) {

  moderate_W <- match.arg(moderate_W)

  # ---- treatment + credits ----
  FASt <- rbinom(N, 1, p_fast)

  trnsfr_cr <- numeric(N)
  for (i in 1:N) {
    if (FASt[i] == 0) {
      trnsfr_cr[i] <- if (runif(1) < 0.60) 0 else runif(1, 1, 11)
    } else {
      trnsfr_cr[i] <- 12 + rgamma(1, shape = 2.5, scale = 6)
      if (trnsfr_cr[i] > 60) trnsfr_cr[i] <- 60
    }
  }

  Zplus   <- pmax(0, trnsfr_cr - 12)
  Zplus10 <- Zplus / 10

  prep <- rnorm(N, 0, 1)

  # ---- W variables (all included every time) ----
  Wlist <- gen_W(N)
  re_all   <- Wlist$re_all
  firstgen <- Wlist$firstgen
  living   <- Wlist$living
  sex      <- Wlist$sex

  # ---- correlated mediator disturbances ----
  e1 <- rnorm(N, 0, 1)
  e2 <- rho_m12 * e1 + sqrt(1 - rho_m12^2) * rnorm(N, 0, 1)

  # ---- assign person-specific a-paths (ONLY for the moderated W) ----
  # Everyone starts at baseline, then we overwrite with group-specific a's for the chosen W.
  a1_i  <- rep(baseline_a["a1"],  N)
  a1z_i <- rep(baseline_a["a1z"], N)
  a2_i  <- rep(baseline_a["a2"],  N)
  a2z_i <- rep(baseline_a["a2z"], N)

  Wvec <- switch(moderate_W,
                 re_all = re_all,
                 firstgen = firstgen,
                 living = living,
                 sex = sex)

  amap <- get_a_map(moderate_W)
  gchr <- as.character(Wvec)

  a1_i  <- vapply(gchr, function(g) amap[[g]]["a1"],  numeric(1))
  a1z_i <- vapply(gchr, function(g) amap[[g]]["a1z"], numeric(1))
  a2_i  <- vapply(gchr, function(g) amap[[g]]["a2"],  numeric(1))
  a2z_i <- vapply(gchr, function(g) amap[[g]]["a2z"], numeric(1))

  # ---- mediators (a-paths vary by group for the chosen W) ----
  Distress <- a1_i*FASt + a1z_i*Zplus10 + 0.15*prep + e1
  Interact <- a2_i*FASt + a2z_i*Zplus10 + 0.10*prep + e2

  # ---- outcome ----
  eY <- rnorm(N, 0, 1)
  Adj <- cprime*FASt + cz*Zplus10 + b1*Distress + b2*Interact + 0.20*prep + eY

  # ---- second-order structure: first-order factors ----
  Belong  <- 0.85*Adj + rnorm(N, 0, sqrt(1 - 0.85^2))
  Gains   <- 0.80*Adj + rnorm(N, 0, sqrt(1 - 0.80^2))
  Support <- 0.75*Adj + rnorm(N, 0, sqrt(1 - 0.75^2))

  # ---- item loadings ----
  l_SB  <- c(0.80, 0.75, 0.78)
  l_PG  <- c(0.70, 0.72, 0.74, 0.68, 0.73)
  l_SE  <- c(0.75, 0.78, 0.72)
  l_MHW <- c(0.75, 0.75, 0.80, 0.70, 0.78)
  l_QI  <- c(0.70, 0.80, 0.75, 0.85)

  SB_star  <- sapply(1:3, function(j) l_SB[j]*Belong  + rnorm(N, 0, sqrt(1 - l_SB[j]^2)))
  PG_star  <- sapply(1:5, function(j) l_PG[j]*Gains   + rnorm(N, 0, sqrt(1 - l_PG[j]^2)))
  SE_star  <- sapply(1:3, function(j) l_SE[j]*Support + rnorm(N, 0, sqrt(1 - l_SE[j]^2)))
  MHW_star <- sapply(1:5, function(j) l_MHW[j]*Distress + rnorm(N, 0, sqrt(1 - l_MHW[j]^2)))
  QI_star  <- sapply(1:4, function(j) l_QI[j]*Interact  + rnorm(N, 0, sqrt(1 - l_QI[j]^2)))

  cuts4 <- c(-1.0, -0.2, 0.8)
  cuts6 <- c(-1.3, -0.7, -0.1, 0.5, 1.1)
  cuts7 <- c(-1.5, -0.9, -0.3, 0.3, 0.9, 1.5)

  SB  <- apply(SB_star,  2, make_ord_int, cuts = cuts4)
  PG  <- apply(PG_star,  2, make_ord_int, cuts = cuts4)
  SE  <- apply(SE_star,  2, make_ord_int, cuts = cuts4)
  MHW <- apply(MHW_star, 2, make_ord_int, cuts = cuts6)
  QI  <- apply(QI_star,  2, make_ord_int, cuts = cuts7)

  dat <- data.frame(
    FASt = FASt,
    trnsfr_cr = trnsfr_cr,
    Zplus = Zplus,
    Zplus10 = Zplus10,
    prep = prep,
    re_all = re_all,
    firstgen = firstgen,
    living = living,
    sex = sex,
    SB1 = SB[,1], SB2 = SB[,2], SB3 = SB[,3],
    PG1 = PG[,1], PG2 = PG[,2], PG3 = PG[,3], PG4 = PG[,4], PG5 = PG[,5],
    SE1 = SE[,1], SE2 = SE[,2], SE3 = SE[,3],
    MHWdacad    = MHW[,1],
    MHWdlonely  = MHW[,2],
    MHWdmental  = MHW[,3],
    MHWdpeers   = MHW[,4],
    MHWdexhaust = MHW[,5],
    QIstudent   = QI[,1],
    QIfaculty   = QI[,2],
    QIadvisor   = QI[,3],
    QIstaff     = QI[,4]
  )

  # ordinal cols as ordered factors
  dat[ordered_vars] <- lapply(dat[ordered_vars], function(x) ordered(x))
  dat
}

# ============================================================
# 5) NESTED TEST ISOLATING "a-PATH MODERATION"
#    H0: a paths equal across groups
#    H1: a paths differ across groups
#    Implementation: constrain all regressions, then PARTIAL free non-a regressions
# ============================================================
fit_a_path_moderation <- function(dat, Wvar) {
  dat[[Wvar]] <- droplevels(dat[[Wvar]])
  if (nlevels(dat[[Wvar]]) < 2) return(NULL)

  # constrain regressions across groups BUT free non-a regressions,
  # leaving ONLY the a paths constrained.
  fit_conA <- lavaan::sem(
    analysis_model,
    data = dat,
    group = Wvar,
    ordered = ordered_vars,
    estimator = "WLSMV",
    parameterization = "theta",
    std.lv = TRUE,
    group.equal = c("regressions"),
    group.partial = c(
      # non-a regressions freed across groups:
      "Adj ~ Distress",
      "Adj ~ Interact",
      "Adj ~ FASt",
      "Adj ~ Zplus10"
    )
  )

  # fully free model (a paths free too)
  fit_freeA <- lavaan::sem(
    analysis_model,
    data = dat,
    group = Wvar,
    ordered = ordered_vars,
    estimator = "WLSMV",
    parameterization = "theta",
    std.lv = TRUE
  )

  if (!isTRUE(lavInspect(fit_conA, "converged"))) return(NULL)
  if (!isTRUE(lavInspect(fit_freeA, "converged"))) return(NULL)

  lrt <- lavaan::lavTestLRT(fit_conA, fit_freeA)
  lrt_df <- as.data.frame(lrt)

  # return just what we need
  list(
    lrt = lrt_df,
    p = lrt_df$`Pr(>Chisq)`[2]
  )
}

# ============================================================
# 6) MONTE CARLO RUNNER: run one W at a time
# ============================================================
run_mc_oneW <- function(Wvar, N, R, p_fast) {
  pvals <- rep(NA_real_, R)
  conv  <- rep(FALSE, R)

  for (r in seq_len(R)) {
    dat <- gen_dat(N, p_fast = p_fast, moderate_W = Wvar)
    res <- try(fit_a_path_moderation(dat, Wvar), silent = TRUE)
    if (inherits(res, "try-error") || is.null(res)) next
    conv[r] <- TRUE
    pvals[r] <- res$p
  }

  used <- which(conv & !is.na(pvals))
  power <- if (length(used) > 0) mean(pvals[used] < 0.05) else NA_real_

  list(
    W = Wvar,
    N = N, R = R, p_fast = p_fast,
    reps_used = length(used),
    convergence_rate = mean(conv),
    power_a_path_moderation = power,
    pvals = pvals
  )
}

# ============================================================
# 7) RUN ALL FOUR W'S (single run, single file)
# ============================================================
Wvars <- c("re_all","firstgen","living","sex")
results <- vector("list", length(Wvars))
names(results) <- Wvars

cat("\n--- MC a-path moderation: starting ---\n")
cat("N =", N, "| R =", Rreps, "| p_fast =", p_fast, "| seed =", seed, "\n\n")

for (W in Wvars) {
  cat("Running W =", W, "...\n")
  res <- run_mc_oneW(W, N, Rreps, p_fast)
  results[[W]] <- res

  cat("  reps_used:", res$reps_used,
      "| conv_rate:", sprintf("%.3f", res$convergence_rate),
      "| power:", sprintf("%.3f", res$power_a_path_moderation), "\n\n")

  out <- sprintf("mc_apath_W_%s_N%d_R%d_seed%d.rds", W, N, Rreps, seed)
  saveRDS(res, out)
  cat("  Saved:", out, "\n\n")
}

saveRDS(results, sprintf("mc_apath_ALLW_N%d_R%d_seed%d.rds", N, Rreps, seed))
cat("Saved combined:", sprintf("mc_apath_ALLW_N%d_R%d_seed%d.rds", N, Rreps, seed), "\n")
cat("--- done ---\n")
