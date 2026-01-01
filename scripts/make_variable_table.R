#!/usr/bin/env Rscript

# Create a variable table (data dictionary) for the Process-SEM pipeline.
# Output: results/tables/variable_table.csv

out_path <- file.path("results", "tables", "variable_table.csv")
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

rows <- list()
add_row <- function(variable,
                    label,
                    role,
                    measurement_type,
                    scale = NA,
                    scale_points = NA,
                    construct_code = NA,
                    code_name = NA,
                    stat_equation = NA,
                    levels = NA,
                    notes = NA) {
  rows[[length(rows) + 1L]] <<- data.frame(
    variable = variable,
    label = label,
    role = role,
    measurement_type = measurement_type,
    scale = scale,
    scale_points = scale_points,
    construct_code = construct_code,
    code_name = code_name,
    stat_equation = stat_equation,
    levels = levels,
    notes = notes,
    stringsAsFactors = FALSE
  )
}

scale_nominal <- "Nominal -> categories only"
scale_ordinal <- "Ordinal -> ordered categories"
scale_interval <- "Interval -> equal distances, no true zero"
scale_ratio <- "Ratio -> equal distances, true zero"

# ----------------------------
# Latent constructs
# ----------------------------
add_row(
  NA,
  "Belonging (latent)",
  "Dependent",
  "latent",
  construct_code = "Belong",
  code_name = "Belong",
  stat_equation = "Belong =~ sbvalued + sbmyself + sbcommunity"
)
add_row(
  NA,
  "Perceived Gains (latent)",
  "Dependent",
  "latent",
  construct_code = "Gains",
  code_name = "Gains",
  stat_equation = "Gains =~ pganalyze + pgthink + pgwork + pgvalues + pgprobsolve"
)
add_row(
  NA,
  "Supportive Environment (latent)",
  "Dependent",
  "latent",
  construct_code = "SuppEnv",
  code_name = "SuppEnv",
  stat_equation = "SuppEnv =~ SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse"
)
add_row(
  NA,
  "Satisfaction (latent)",
  "Dependent",
  "latent",
  construct_code = "Satisf",
  code_name = "Satisf",
  stat_equation = "Satisf =~ sameinst + evalexp"
)
add_row(
  NA,
  "Developmental Adjustment (2nd-order)",
  "Dependent",
  "latent",
  construct_code = "DevAdj",
  code_name = "DevAdj",
  stat_equation = "DevAdj =~ Belong + Gains + SuppEnv + Satisf",
  notes = "Second-order factor measured by Belong/Gains/SuppEnv/Satisf"
)
add_row(
  NA,
  "EmoDiss: Emotional distress/dysregulation (latent)",
  "Mediator 1",
  "latent",
  construct_code = "M1",
  code_name = "EmoDiss",
  stat_equation = "EmoDiss =~ MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinance"
)
add_row(
  NA,
  "QualEngag: Quality/engagement (latent)",
  "Mediator 2",
  "latent",
  construct_code = "M2",
  code_name = "QualEngag",
  stat_equation = "QualEngag =~ QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff + SFcareer + SFotherwork + SFdiscuss + SFperform"
)

# ----------------------------
# Measurement indicators (ordered/categorical items)
# K values follow infer_K_for_item() in r/mc/02_mc_allRQs_pooled_mg_psw.R
# ----------------------------
# Belong indicators (5-point)
belong_labels <- c(
  sbvalued = "Belonging: I feel valued",
  sbmyself = "Belonging: I can be myself",
  sbcommunity = "Belonging: I feel a sense of community"
)
for (v in names(belong_labels)) {
  add_row(
    v,
    belong_labels[[v]],
    "Dependent",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 5,
    construct_code = "Belong",
    code_name = v
  )
}

# Gains indicators (4-point)
gains_labels <- c(
  pganalyze = "Gains: Analyze information",
  pgthink = "Gains: Think critically",
  pgwork = "Gains: Work effectively",
  pgvalues = "Gains: Clarify values",
  pgprobsolve = "Gains: Solve problems"
)
for (v in names(gains_labels)) {
  add_row(
    v,
    gains_labels[[v]],
    "Dependent",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 4,
    construct_code = "Gains",
    code_name = v
  )
}

# Supportive environment indicators (4-point)
suppenv_labels <- c(
  SEacademic = "Supportive environment: Academic support",
  SEwellness = "Supportive environment: Wellness support",
  SEnonacad = "Supportive environment: Non-academic support",
  SEactivities = "Supportive environment: Activities/engagement support",
  SEdiverse = "Supportive environment: Support for diverse students"
)
for (v in names(suppenv_labels)) {
  add_row(
    v,
    suppenv_labels[[v]],
    "Dependent",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 4,
    construct_code = "SuppEnv",
    code_name = v
  )
}

# Satisfaction indicators (4-point)
satisf_labels <- c(
  sameinst = "Satisfaction: Would choose same institution again",
  evalexp = "Satisfaction: Overall evaluation of experience"
)
for (v in names(satisf_labels)) {
  add_row(
    v,
    satisf_labels[[v]],
    "Dependent",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 4,
    construct_code = "Satisf",
    code_name = v
  )
}

# Second-order measurement (latent indicators of DevAdj)
for (v in c("Belong","Gains","SuppEnv","Satisf")) {
  add_row(
    NA,
    paste0("Second-order indicator (latent): ", v),
    "Dependent",
    "latent",
    construct_code = "DevAdj",
    code_name = "DevAdj",
    stat_equation = paste0("DevAdj =~ ", v)
  )
}

# M1 = EmoDiss indicators (6-point)
m1_labels <- c(
  MHWdacad = "EmoDiss: Academic distress",
  MHWdlonely = "EmoDiss: Loneliness",
  MHWdmental = "EmoDiss: Mental health distress",
  MHWdexhaust = "EmoDiss: Exhaustion",
  MHWdsleep = "EmoDiss: Sleep difficulties",
  MHWdfinance = "EmoDiss: Financial stress"
)
for (v in names(m1_labels)) {
  add_row(
    v,
    m1_labels[[v]],
    "Mediator 1",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 6,
    construct_code = "M1",
    code_name = v
  )
}

# M2 = QualEngag indicators: Quality of Interactions (7-point)
qi_labels <- c(
  QIadmin = "QualEngag: Quality of interactions: Administrators",
  QIstudent = "QualEngag: Quality of interactions: Students",
  QIadvisor = "QualEngag: Quality of interactions: Advisors",
  QIfaculty = "QualEngag: Quality of interactions: Faculty",
  QIstaff = "QualEngag: Quality of interactions: Staff"
)
for (v in names(qi_labels)) {
  add_row(
    v,
    qi_labels[[v]],
    "Mediator 2",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 7,
    construct_code = "M2",
    code_name = v
  )
}

# M2 = QualEngag indicators: Student-faculty Interaction (4-point)
sf_labels <- c(
  SFcareer = "QualEngag: Student-faculty interaction: Career planning",
  SFotherwork = "QualEngag: Student-faculty interaction: Other work/collaboration",
  SFdiscuss = "QualEngag: Student-faculty interaction: Discuss ideas",
  SFperform = "QualEngag: Student-faculty interaction: Feedback on performance"
)
for (v in names(sf_labels)) {
  add_row(
    v,
    sf_labels[[v]],
    "Mediator 2",
    "ordinal",
    scale = scale_ordinal,
    scale_points = 4,
    construct_code = "M2",
    code_name = v
  )
}

# ----------------------------
# Baseline covariates (selection-bias proxies)
# ----------------------------
add_row(
  "hgrades_AF",
  "High school grades (A-F)",
  "Covariate",
  "ordinal",
  scale = scale_ordinal,
  scale_points = 5,
  levels = "F|D|C|B|A",
  code_name = "hgrades_AF",
  notes = "Stored as ordered factor; numeric versions below used in SEM"
)
add_row(
  "hgrades",
  "High school grades (standardized numeric)",
  "Covariate",
  "continuous",
  scale = scale_interval,
  code_name = "hgrades",
  stat_equation = "hgrades = z(as.numeric(hgrades_AF))",
  notes = "Derived from hgrades_AF then standardized"
)
add_row(
  "hgrades_c",
  "High school grades (centered)",
  "Covariate",
  "continuous",
  scale = scale_interval,
  code_name = "hgrades_c",
  stat_equation = "hgrades_c = as.numeric(scale(hgrades, scale = FALSE))",
  notes = "Centered (mean=0)"
)

add_row(
  "bparented",
  "Parental education proxy (continuous)",
  "Covariate",
  "continuous",
  scale = scale_interval,
  code_name = "bparented"
)
add_row(
  "bparented_c",
  "Parental education proxy (centered)",
  "Covariate",
  "continuous",
  scale = scale_interval,
  code_name = "bparented_c",
  stat_equation = "bparented_c = as.numeric(scale(bparented, scale = FALSE))",
  notes = "Centered (mean=0)"
)

add_row(
  "pell",
  "Pell Grant recipient",
  "Moderator 1",
  "binary",
  scale = scale_nominal,
  scale_points = 2,
  levels = "0|1",
  code_name = "pell",
  notes = "Appears in W_LIST for MG runs; also used as a PSW covariate"
)
add_row("hapcl",      "Completed >2 AP courses in HS",         "Covariate", "binary", scale = scale_nominal, scale_points = 2, levels = "0|1", code_name = "hapcl")
add_row("hprecalc13", "HS attendance type: Public vs Private-bucket", "Covariate", "binary", scale = scale_nominal, scale_points = 2, levels = "0|1", code_name = "hprecalc13", notes = "1 includes: private/home school/other")

add_row("hchallenge",   "HS academic challenge (continuous)", "Covariate", "continuous", scale = scale_interval, code_name = "hchallenge")
add_row("hchallenge_c", "HS academic challenge (centered)",   "Covariate", "continuous", scale = scale_interval, code_name = "hchallenge_c", stat_equation = "hchallenge_c = as.numeric(scale(hchallenge, scale = FALSE))", notes = "Centered (mean=0)")

add_row("cSFcareer",   "Baseline career orientation/goals (continuous)", "Covariate", "continuous", scale = scale_interval, code_name = "cSFcareer")
add_row("cSFcareer_c", "Baseline career orientation/goals (centered)",   "Covariate", "continuous", scale = scale_interval, code_name = "cSFcareer_c", stat_equation = "cSFcareer_c = as.numeric(scale(cSFcareer, scale = FALSE))", notes = "Centered (mean=0)")

add_row("cohort", "Cohort indicator", "Covariate", "binary", scale = scale_nominal, scale_points = 2, levels = "0|1", code_name = "cohort")

# ----------------------------
# Treatment / dose / derived predictors
# ----------------------------
add_row(
  "trnsfr_cr",
  "BCSSE transfer credits at entry (trnsfr_cr)",
  "Independent",
  "count",
  scale = scale_ratio,
  code_name = "trnsfr_cr",
  notes = "Source variable for treatment/dose recodes; used to define X, credit_dose, credit_band"
)
add_row(
  "trnsfr_cr_ge12",
  "Treatment eligibility: 1(trnsfr_cr >= 12)",
  "Independent",
  "binary",
  scale = scale_nominal,
  scale_points = 2,
  levels = "0|1",
  code_name = "X",
  stat_equation = "X = 1(trnsfr_cr >= 12)",
  notes = "Recoded from BCSSE trnsfr_cr; stored as X in analysis code"
)
add_row(
  "credit_dose",
  "Dose above threshold (10-credit units): max(0, trnsfr_cr - 12)/10",
  "Independent",
  "continuous",
  scale = scale_ratio,
  code_name = "credit_dose",
  stat_equation = "credit_dose = pmax(0, trnsfr_cr - 12)/10",
  notes = "Recoded from BCSSE trnsfr_cr; 0.0, 1.2, 2.4, 3.6, 4.8 correspond to 12/24/36/48/60 entry credits"
)
add_row(
  "credit_dose_c",
  "Dose above threshold (centered)",
  "Independent",
  "continuous",
  scale = scale_interval,
  code_name = "credit_dose_c",
  stat_equation = "credit_dose_c = as.numeric(scale(credit_dose, scale = FALSE))",
  notes = "Centered as as.numeric(scale(credit_dose, scale = FALSE))"
)

# Moderation placeholders used by pooled moderation models.
# In the MC runner, Z is constructed from the selected moderator and centered to Z_c;
# then XZ_c is computed as X * Z_c.
add_row(
  "moderator_raw",
  "Moderator (varies by analysis): pooled moderation models",
  "Moderator 1",
  "varies",
  code_name = "Z",
  notes = "Set inside the MC runner from the selected moderator (W); stored as Z then centered to Z_c"
)
add_row(
  "moderator_centered",
  "Moderator (centered): as.numeric(scale(Z, scale = FALSE))",
  "Moderator 1",
  "continuous",
  scale = scale_interval,
  code_name = "Z_c",
  stat_equation = "Z_c = as.numeric(scale(Z, scale = FALSE))",
  notes = "Only defined when Z exists; stored as Z_c in analysis code"
)
add_row(
  "treat_x_moderator",
  "Treatment-by-moderator interaction: X * Z_c",
  "Moderator 1",
  "continuous",
  scale = scale_interval,
  code_name = "XZ_c",
  stat_equation = "XZ_c = X * Z_c",
  notes = "Only defined when Z exists; stored as XZ_c in analysis code; recomputed post-imputation in MI"
)

# Optional derived band used for descriptives in some scripts
add_row(
  "credit_band",
  "Credit band from trnsfr_cr",
  "Independent",
  "categorical",
  scale = scale_ordinal,
  scale_points = 3,
  levels = "0|1-11|12+",
  code_name = "credit_band",
  stat_equation = "credit_band = f(trnsfr_cr) -> {0, 1-11, 12+}",
  notes = "Present in some representative-study outputs"
)

# ----------------------------
# Weights (diagnostic / optional sampling weights)
# ----------------------------
add_row(
  "psw",
  "Propensity-score overlap weight",
  "Weight",
  "continuous",
  scale = scale_ratio,
  code_name = "psw",
  stat_equation = "ps=Pr(X=1|C); psw_raw = X*(1-ps) + (1-X)*ps; psw = psw_raw/mean(psw_raw)",
  notes = "Computed from X ~ covariates; normalized to mean 1"
)

# ----------------------------
# Grouping / moderator variables
# ----------------------------
add_row(
  "re_all",
  "Race/ethnicity (grouping variable)",
  "Moderator 1",
  "categorical",
  scale = scale_nominal,
  scale_points = 5,
  levels = "Hispanic/Latino|White|Asian|Black/African American|Other/Multiracial/Unknown",
  code_name = "re_all"
)
add_row("firstgen", "First-generation student", "Moderator 1", "binary", scale = scale_nominal, scale_points = 2, levels = "0|1", code_name = "firstgen")
add_row(
  "living18",
  "Living situation (grouping variable)",
  "Moderator 1",
  "categorical",
  scale = scale_nominal,
  scale_points = 3,
  levels = "With family (commuting)|Off-campus (rent/apartment)|On-campus (residence hall)",
  code_name = "living18"
)
add_row(
  "sex",
  "Sex/Gender (grouping variable)",
  "Moderator 1",
  "categorical",
  scale = scale_nominal,
  scale_points = 2,
  levels = "Woman|Man",
  code_name = "sex",
  notes = "May be collapsed to 2 groups for MG stability"
)

# Standalone rep_data grouping variable for FASt vs non-FASt model
add_row(
  "x_FASt",
  "FASt participation indicator (grouping variable)",
  "Moderator 2",
  "binary",
  scale = scale_nominal,
  scale_points = 2,
  levels = "0|1",
  code_name = "x_FASt",
  notes = "Used only in standalone FASt vs non-FASt MG model"
)

var_table <- do.call(rbind, rows)

# Survey instrument/source for each variable (dissertation-facing)
# Values: BCSSE, NSSE, MHW
var_table$survey_instrument <- NA_character_

# Grouping for presentation (construct-first) and a stable "importance" sort.
var_table$group <- NA_character_

# Construct groups
var_table$group[var_table$construct_code == "DevAdj"] <- "DevAdj (2nd-order)"
var_table$group[var_table$construct_code == "Belong"] <- "Belong"
var_table$group[var_table$construct_code == "Gains"] <- "Gains"
var_table$group[var_table$construct_code == "SuppEnv"] <- "SuppEnv"
var_table$group[var_table$construct_code == "Satisf"] <- "Satisf"
var_table$group[var_table$construct_code == "M1"] <- "EmoDiss (M1)"
var_table$group[var_table$construct_code == "M2"] <- "QualEngag (M2)"

# Non-construct groups
treatment_vars <- c(
  "trnsfr_cr", "trnsfr_cr_ge12", "credit_dose", "credit_dose_c", "credit_band",
  "moderator_raw", "moderator_centered", "treat_x_moderator"
)
psw_covariates <- c(
  "hgrades_c", "bparented_c", "pell", "hapcl", "hprecalc13", "hchallenge_c", "cSFcareer_c", "cohort"
)
baseline_covariates <- c(
  "hgrades_AF", "hgrades", "hgrades_c",
  "bparented", "bparented_c",
  "hapcl", "hprecalc13",
  "hchallenge", "hchallenge_c",
  "cSFcareer", "cSFcareer_c",
  "cohort"
)
# W variables used for MG runs in r/mc/02_mc_allRQs_pooled_mg_psw.R
grouping_vars <- c("re_all", "firstgen", "pell", "living18", "sex", "x_FASt")
weights_vars <- c("psw", psw_covariates)

# Survey instrument assignment
nsse_constructs <- c("DevAdj", "Belong", "Gains", "SuppEnv", "Satisf", "M2")
var_table$survey_instrument[var_table$construct_code %in% nsse_constructs] <- "NSSE"
var_table$survey_instrument[var_table$construct_code == "M1"] <- "MHW"

bcsse_vars <- unique(c(treatment_vars, baseline_covariates, grouping_vars, weights_vars, "moderator_raw"))
var_table$survey_instrument[is.na(var_table$survey_instrument) & var_table$variable %in% bcsse_vars] <- "BCSSE"
is_treatment <- var_table$variable %in% treatment_vars
var_table$group[is.na(var_table$group) & is_treatment] <- "Treatment / Dose / Moderation terms"
var_table$group[is.na(var_table$group) & var_table$variable %in% weights_vars] <- "Weights"
var_table$group[is.na(var_table$group) & var_table$variable %in% baseline_covariates] <- "Baseline covariates"
var_table$group[is.na(var_table$group) & var_table$variable %in% grouping_vars] <- "Grouping variables"
var_table$group[is.na(var_table$group)] <- "Other"

# Stable ordering for readability (and dissertation-friendly grouping)
order_group <- c(
  "DevAdj (2nd-order)",
  "Belong",
  "Gains",
  "SuppEnv",
  "Satisf",
  "EmoDiss (M1)",
  "QualEngag (M2)",
  "Treatment / Dose / Moderation terms",
  "Baseline covariates",
  "Grouping variables",
  "Weights",
  "Other"
)

order_role <- c(
  "Dependent",
  "Mediator 1",
  "Mediator 2",
  "Independent",
  "Moderator 1",
  "Moderator 2",
  "Covariate",
  "Weight"
)
var_table$group <- factor(var_table$group, levels = order_group)
var_table$role <- factor(var_table$role, levels = order_role)

# Custom within-group ordering for treatment/dose terms
var_table$variable_order <- NA_integer_
var_table$variable_order[var_table$variable %in% treatment_vars] <- match(var_table$variable[var_table$variable %in% treatment_vars], treatment_vars)

# Put PSW covariates directly under PSW in the Weights section
var_table$variable_order[var_table$variable %in% weights_vars] <- match(var_table$variable[var_table$variable %in% weights_vars], weights_vars)

# Internal sort key for within-group readability (latent rows first, then their indicators)
var_table$row_kind <- ifelse(
  is.na(var_table$variable) & grepl("^Second-order indicator", var_table$label),
  "latent_indicator",
  ifelse(is.na(var_table$variable), "latent",
         ifelse(!is.na(var_table$construct_code) & var_table$measurement_type == "ordinal", "indicator", "observed"))
)
var_table$row_kind <- factor(var_table$row_kind, levels = c("latent", "latent_indicator", "indicator", "observed"))

vo <- ifelse(is.na(var_table$variable_order), 999999L, as.integer(var_table$variable_order))
var_table <- var_table[order(var_table$group, var_table$row_kind, vo, var_table$role, var_table$construct_code, var_table$variable), ]
var_table$group <- as.character(var_table$group)
var_table$role <- as.character(var_table$role)
var_table$variable_order <- NULL
var_table$row_kind <- NULL

# Put survey_instrument at the end (as requested)
var_table <- var_table[, c(setdiff(names(var_table), "survey_instrument"), "survey_instrument"), drop = FALSE]

utils::write.csv(var_table, out_path, row.names = FALSE)
cat("Wrote variable table:", normalizePath(out_path), "\n")

