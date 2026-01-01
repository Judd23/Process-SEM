#!/usr/bin/env Rscript
# Debug: test if model fits with rep_data.csv (actual data)

suppressPackageStartupMessages({
  library(lavaan)
})

setwd("/Users/jjohnson3/Documents/GitHub/Process-SEM")

# Source the model file
source("r/models/mg_fast_vs_nonfast_model.R")

cat("=== Loading rep_data.csv ===\n")
dat <- read.csv("rep_data.csv", stringsAsFactors = FALSE)
cat("N =", nrow(dat), "\n")

# Create centered variables
if (!"hgrades_c" %in% names(dat) && "hgrades" %in% names(dat)) {
  dat$hgrades_c <- scale(dat$hgrades, scale = FALSE)[,1]
}
if (!"bparented_c" %in% names(dat) && "bparented" %in% names(dat)) {
  dat$bparented_c <- scale(dat$bparented, scale = FALSE)[,1]
}
if (!"hchallenge_c" %in% names(dat) && "hchallenge" %in% names(dat)) {
  dat$hchallenge_c <- scale(dat$hchallenge, scale = FALSE)[,1]
}
if (!"cSFcareer_c" %in% names(dat) && "cSFcareer" %in% names(dat)) {
  dat$cSFcareer_c <- scale(dat$cSFcareer, scale = FALSE)[,1]
}

# Check covariance matrix condition
cat("\n=== Checking covariance matrix ===\n")
indicators <- c(
  "sbvalued", "sbmyself", "sbcommunity",
  "pganalyze", "pgthink", "pgwork", "pgvalues", "pgprobsolve",
  "SEacademic", "SEwellness", "SEnonacad", "SEactivities", "SEdiverse",
  "sameinst", "evalexp",
  "MHWdacad", "MHWdlonely", "MHWdmental", "MHWdexhaust", "MHWdsleep", "MHWdfinancial",
  "QIstudent", "QIadvisor", "QIfaculty", "QIstaff", "QIadmin"
)

dat_ind <- dat[, indicators]
for (v in names(dat_ind)) {
  dat_ind[[v]] <- as.numeric(dat_ind[[v]])
}

dat_ind_complete <- na.omit(dat_ind)
cat("Complete cases:", nrow(dat_ind_complete), "\n")

S <- cov(dat_ind_complete)
eig <- eigen(S)$values
cat("Eigenvalue range:", min(eig), "to", max(eig), "\n")
cat("Condition number:", max(eig) / min(eig), "\n")

# Check correlations
cormat <- cor(dat_ind_complete)
cat("Max absolute correlation:", max(abs(cormat[lower.tri(cormat)])), "\n")

# Now try fitting
cat("\n=== Building and fitting model ===\n")
model_str <- build_model_fast_treat_control(dat)

fit <- tryCatch({
  lavaan::sem(
    model = model_str,
    data = dat,
    estimator = "ML",
    missing = "fiml",
    fixed.x = TRUE,
    meanstructure = TRUE,
    check.lv.names = FALSE,
    control = list(iter.max = 10000)
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(fit)) {
  cat("Converged:", lavInspect(fit, "converged"), "\n")
  cat("Iterations:", lavInspect(fit, "iterations"), "\n")
  
  if (lavInspect(fit, "converged")) {
    pe <- parameterEstimates(fit)
    key_params <- c("a1", "b1", "a2", "b2", "c")
    cat("\nKey parameters:\n")
    print(pe[pe$label %in% key_params, c("label", "est", "se", "pvalue")])
  }
}

cat("\nDone.\n")
