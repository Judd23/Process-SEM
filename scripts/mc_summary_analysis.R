# ============================================================
# MC SUMMARY ANALYSIS - Test Run
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

run_dir <- "results/runs/seed12345_N3000_R4_psw1_mg1"
# Pattern: rep001_pooled_mi_pe.csv
pooled_files <- list.files(run_dir, pattern = "rep[0-9]+_pooled_mi_pe[.]csv", full.names = TRUE)
cat("\n=== POOLED PARAMETER FILES ===\n")
cat("Found", length(pooled_files), "replication files\n")

if (length(pooled_files) > 0) {
  all_pe <- do.call(rbind, lapply(pooled_files, function(f) {
    d <- read.csv(f, stringsAsFactors = FALSE)
    d$rep <- as.integer(gsub(".*rep([0-9]+).*", "\\1", basename(f)))
    d
  }))
  
  dgp_truth <- data.frame(
    param = c("a1", "a2", "b1", "b2", "c", "a1_z", "a2_z", "c_z"),
    true_val = c(0.25, 0.20, -0.35, 0.30, 0.05, 0.05, 0.02, 0.01)
  )
  
  cat("\n======================================================================\n")
  cat("TABLE 1: POOLED SEM PARAMETER ESTIMATES (R=", max(all_pe$rep), ")\n")
  cat("======================================================================\n\n")
  
  param_summary <- all_pe %>%
    filter(lhs != "" & op %in% c("~", ":=")) %>%
    mutate(param = ifelse(label != "", label, paste0(lhs, op, rhs))) %>%
    mutate(z_val = ifelse(se > 0, est / se, NA),
           pvalue = 2 * pnorm(-abs(z_val))) %>%
    group_by(param) %>%
    summarise(mean_est = mean(est, na.rm = TRUE), sd_est = sd(est, na.rm = TRUE),
              mean_se = mean(se, na.rm = TRUE), pct_sig = mean(pvalue < 0.05, na.rm = TRUE) * 100,
              n_reps = n(), .groups = "drop") %>%
    left_join(dgp_truth, by = "param") %>%
    mutate(bias = ifelse(!is.na(true_val), mean_est - true_val, NA))
  
  cat("STRUCTURAL PATHS:\n")
  cat(sprintf("%-25s %10s %10s %10s %10s %10s\n", "Parameter", "Mean Est", "SD Est", "DGP Truth", "Bias", "% Sig"))
  cat(paste(rep("-", 85), collapse=""), "\n")
  for (p in c("a1", "a2", "b1", "b2", "c")) {
    row <- param_summary %>% filter(param == p)
    if (nrow(row) > 0) cat(sprintf("%-25s %10.4f %10.4f %10.4f %10.4f %10.1f%%\n", p, row$mean_est, row$sd_est, 
                                   ifelse(is.na(row$true_val), NA, row$true_val), ifelse(is.na(row$bias), NA, row$bias), row$pct_sig))
  }
  
  cat("\nMODERATION EFFECTS (x credit_dose_c):\n")
  for (p in c("a1_z", "a2_z", "c_z")) {
    row <- param_summary %>% filter(param == p)
    if (nrow(row) > 0) cat(sprintf("%-25s %10.4f %10.4f %10.4f %10.4f %10.1f%%\n", p, row$mean_est, row$sd_est, 
                                   ifelse(is.na(row$true_val), NA, row$true_val), ifelse(is.na(row$bias), NA, row$bias), row$pct_sig))
  }
  
  cat("\nINDIRECT EFFECTS (at Z=0):\n")
  for (p in c("ind_EmoDiss_z_mid", "ind_QualEngag_z_mid", "total_z_mid")) {
    row <- param_summary %>% filter(param == p)
    if (nrow(row) > 0) cat(sprintf("%-25s %10.4f %10.4f %10s %10s %10.1f%%\n", p, row$mean_est, row$sd_est, "---", "---", row$pct_sig))
  }
  
  cat("\nINDEX OF MODERATED MEDIATION:\n")
  for (p in c("index_MM_EmoDiss", "index_MM_QualEngag")) {
    row <- param_summary %>% filter(param == p)
    if (nrow(row) > 0) cat(sprintf("%-25s %10.4f %10.4f %10s %10s %10.1f%%\n", p, row$mean_est, row$sd_est, "---", "---", row$pct_sig))
  }
}

# ============================================================
# FIT INDICES
# ============================================================
fit_files <- list.files(run_dir, pattern = "rep[0-9]+_pooled_mi_fitMeasures[.]csv", full.names = TRUE)
if (length(fit_files) > 0) {
  all_fit <- do.call(rbind, lapply(fit_files, function(f) {
    d <- read.csv(f, stringsAsFactors = FALSE)
    d$rep <- as.integer(gsub(".*rep([0-9]+).*", "\\1", basename(f)))
    d
  }))
  
  cat("\n======================================================================\n")
  cat("TABLE 2: MODEL FIT INDICES\n")
  cat("======================================================================\n\n")
  
  # Pivot to wide format
  fit_wide <- all_fit %>%
    tidyr::pivot_wider(names_from = measure, values_from = value)
  
  cat(sprintf("%-15s %10s %10s\n", "Index", "Mean", "SD"))
  cat(paste(rep("-", 35), collapse=""), "\n")
  for (idx in c("cfi", "tli", "rmsea", "srmr")) {
    if (idx %in% names(fit_wide)) {
      cat(sprintf("%-15s %10.4f %10.4f\n", toupper(idx), 
                  mean(fit_wide[[idx]], na.rm = TRUE), 
                  sd(fit_wide[[idx]], na.rm = TRUE)))
    }
  }
}

# ============================================================
# PSW BALANCE CHECK
# ============================================================
cat("\n======================================================================\n")
cat("PSW OVERLAP WEIGHTS BALANCE\n")
cat("======================================================================\n\n")

dat <- read.csv("rep_data.csv")

# Compute PSW
ps_mod <- glm(x_FASt ~ hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c + cohort,
              data = dat, family = binomial())
ps <- predict(ps_mod, type = "response")
ps <- pmin(pmax(ps, 1e-3), 1 - 1e-3)
dat$psw <- ifelse(dat$x_FASt == 1, 1 - ps, ps)
dat$psw <- dat$psw / mean(dat$psw)

# SMD before and after weighting
covars <- c("hgrades_c", "bparented_c", "pell", "hapcl", "hprecalc13", "hchallenge_c", "cSFcareer_c")

cat("STANDARDIZED MEAN DIFFERENCES (SMD):\n")
cat(sprintf("%-15s %12s %12s %12s\n", "Covariate", "Unweighted", "Weighted", "Balance?"))
cat(paste(rep("-", 55), collapse=""), "\n")

for (v in covars) {
  if (v %in% names(dat)) {
    m1_uw <- mean(dat[[v]][dat$x_FASt == 1], na.rm = TRUE)
    m0_uw <- mean(dat[[v]][dat$x_FASt == 0], na.rm = TRUE)
    s_pool <- sqrt((var(dat[[v]][dat$x_FASt == 1], na.rm = TRUE) + 
                    var(dat[[v]][dat$x_FASt == 0], na.rm = TRUE)) / 2)
    smd_uw <- (m1_uw - m0_uw) / s_pool
    
    # Weighted
    m1_w <- weighted.mean(dat[[v]][dat$x_FASt == 1], dat$psw[dat$x_FASt == 1], na.rm = TRUE)
    m0_w <- weighted.mean(dat[[v]][dat$x_FASt == 0], dat$psw[dat$x_FASt == 0], na.rm = TRUE)
    smd_w <- (m1_w - m0_w) / s_pool
    
    balanced <- ifelse(abs(smd_w) < 0.10, "OK", "!")
    cat(sprintf("%-15s %12.3f %12.3f %12s\n", v, smd_uw, smd_w, balanced))
  }
}

cat("\n")
cat("Note: PSW balances covariates BEFORE SEM estimation.\n")
cat("Weights are computed once on full data, then carried through bootstrap.\n")

# ============================================================
# VISUALIZATION
# ============================================================
if (length(pooled_files) > 0) {
  plot_params <- c("a1", "a2", "b1", "b2", "c")
  plot_data <- all_pe %>%
    filter(label %in% plot_params) %>%
    select(rep, label, est, se)
  
  if (nrow(plot_data) > 0) {
    p1 <- ggplot(plot_data, aes(x = est, fill = label)) +
      geom_histogram(bins = 8, alpha = 0.7) +
      facet_wrap(~label, scales = "free_x") +
      geom_vline(data = dgp_truth %>% filter(param %in% plot_params),
                 aes(xintercept = true_val), linetype = "dashed", color = "red", linewidth = 1) +
      theme_minimal() +
      labs(title = "MC Parameter Distributions (R=4 Test)",
           subtitle = "Red dashed = DGP truth",
           x = "Estimate", y = "Count") +
      theme(legend.position = "none")
    
    ggsave(file.path(run_dir, "mc_param_distributions.png"), 
           p1, width = 10, height = 6, dpi = 150)
    cat("\nSaved:", file.path(run_dir, "mc_param_distributions.png"), "\n")
  }
  
  # Indirect effects plot
  indirect_params <- c("ind_EmoDiss_z_low", "ind_EmoDiss_z_mid", "ind_EmoDiss_z_high",
                       "ind_QualEngag_z_low", "ind_QualEngag_z_mid", "ind_QualEngag_z_high")
  indirect_data <- all_pe %>%
    filter(label %in% indirect_params) %>%
    mutate(
      mediator = ifelse(grepl("EmoDiss", label), "EmoDiss", "QualEngag"),
      z_level = case_when(
        grepl("z_low", label) ~ "-1 SD",
        grepl("z_mid", label) ~ "0",
        grepl("z_high", label) ~ "+1 SD"
      ),
      z_level = factor(z_level, levels = c("-1 SD", "0", "+1 SD"))
    )
  
  if (nrow(indirect_data) > 0) {
    p2 <- ggplot(indirect_data, aes(x = z_level, y = est, fill = mediator)) +
      geom_boxplot(alpha = 0.7) +
      geom_hline(yintercept = 0, linetype = "dashed") +
      facet_wrap(~mediator) +
      theme_minimal() +
      labs(title = "Conditional Indirect Effects by Credit Dose (Z)",
           x = "Credit Dose (Centered)", y = "Indirect Effect") +
      theme(legend.position = "none")
    
    ggsave(file.path(run_dir, "mc_indirect_effects.png"), 
           p2, width = 8, height = 5, dpi = 150)
    cat("Saved:", file.path(run_dir, "mc_indirect_effects.png"), "\n")
  }
}

cat("\n======================================================================\n")
cat("MC TEST RUN COMPLETE\n")
cat("======================================================================\n")
