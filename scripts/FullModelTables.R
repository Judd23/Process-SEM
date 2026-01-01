#!/usr/bin/env Rscript

# Build paper tables (DOCX) for the current FASt conditional-process SEM model.
#
# This script exists because "printing tables" in this repo means producing
# Paper_Tables_All.docx (via scripts/build_paper_tables_docx.py).
#
# Usage:
#   Rscript scripts/FullModelTables.R --base_dir results/fast_treat_control/official_all_RQs
#
# On success, writes:
#   <base_dir>/Paper_Tables_All.docx

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- match(flag, args)
  if (is.na(idx)) return(default)
  if (idx == length(args)) return(default)
  args[[idx + 1]]
}

BASE_DIR <- get_arg("--base_dir", "results/fast_treat_control/official_all_RQs")
BASE_DIR <- path.expand(BASE_DIR)

.exists_file <- function(p) file.exists(p) && !dir.exists(p)

# ---- Validate required inputs for the DOCX builder
required_paths <- c(
  file.path(BASE_DIR, "run_log.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "rep_data_with_psw.csv"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "psw_stage_report.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "psw_balance_smd.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "structural", "structural_fitMeasures.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "structural", "structural_parameterEstimates.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "structural", "structural_standardizedSolution.txt"),
  file.path(BASE_DIR, "RQ1_RQ3_main", "structural", "structural_r2.txt"),
  file.path(BASE_DIR, "sensitivity_unweighted_parallel", "structural", "structural_parameterEstimates.txt")
)

missing <- required_paths[!vapply(required_paths, .exists_file, logical(1))]
if (length(missing) > 0) {
  cat("FAIL: missing required inputs for paper tables\n")
  cat("base_dir=", BASE_DIR, "\n", sep = "")
  cat("Missing:\n")
  for (p in missing) cat("- ", p, "\n", sep = "")
  quit(status = 2)
}

# ---- Find a python interpreter
py_candidates <- c(
  file.path(getwd(), ".venv", "bin", "python"),
  Sys.which("python"),
  Sys.which("python3")
)
py <- py_candidates[nzchar(py_candidates)][1]
if (is.na(py) || !nzchar(py)) {
  cat("FAIL: no python interpreter found (needed for scripts/build_paper_tables_docx.py)\n")
  quit(status = 2)
}

builder <- file.path(getwd(), "scripts", "build_paper_tables_docx.py")
if (!file.exists(builder)) {
  cat("FAIL: missing DOCX builder script: ", builder, "\n", sep = "")
  quit(status = 2)
}

cmd <- paste(shQuote(py), shQuote(builder), "--base_dir", shQuote(BASE_DIR), "--page_breaks", "0")
cat("Running: ", cmd, "\n", sep = "")
ret <- system(cmd)
if (!identical(ret, 0L)) {
  cat("FAIL: DOCX builder failed with exit code ", ret, "\n", sep = "")
  quit(status = 2)
}

out_docx <- file.path(BASE_DIR, "Paper_Tables_All.docx")
if (!file.exists(out_docx)) {
  cat("FAIL: DOCX builder did not produce: ", out_docx, "\n", sep = "")
  quit(status = 2)
}

cat("PASS\n")
cat("paper_tables=", out_docx, "\n", sep = "")
