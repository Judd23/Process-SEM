# MG SEM: FASt (x_FASt=1) vs non-FASt (0)
# Grouping variable: x_FASt
# X is not included inside the model because it defines groups

model_mg_fast_vs_nonfast <- '
# measurement (marker-variable identification)
Belong =~ 1*sbvalued + sbmyself + sbcommunity
Gains  =~ 1*pganalyze + pgthink + pgwork + pgvalues + pgprobsolve
SuppEnv =~ 1*SEacademic + SEwellness + SEnonacad + SEactivities + SEdiverse
Satisf =~ 1*sameinst + evalexp
DevAdj =~ 1*Belong + Gains + SuppEnv + Satisf

M1 =~ 1*MHWdacad + MHWdlonely + MHWdmental + MHWdexhaust + MHWdsleep + MHWdfinancial
M2 =~ 1*QIadmin + QIstudent + QIadvisor + QIfaculty + QIstaff +
      SFcareer + SFotherwork + SFdiscuss + SFperform

# structural (estimated separately by group unless constrained in the fit call)
M1 ~ a1z*credit_dose_c + g1*cohort +
     hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

M2 ~ a2z*credit_dose_c + d*M1 + g2*cohort +
     hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

DevAdj ~ cz*credit_dose_c + b1*M1 + b2*M2 + g3*cohort +
         hgrades_c + bparented_c + pell + hapcl + hprecalc13 + hchallenge_c + cSFcareer_c

# effects (per group)
ind_M1     := a1z*b1
ind_M2     := a2z*b2
ind_serial := a1z*d*b2
total_dose := cz + ind_M1 + ind_M2 + ind_serial
'

fit_mg_fast_vs_nonfast <- function(dat,
                                  estimator = "MLR",
                                  missing = "fiml",
                                  fixed.x = FALSE,
                                  ...) {
  lavaan::sem(
    model = model_mg_fast_vs_nonfast,
    data = dat,
    group = "x_FASt",
    estimator = estimator,
    missing = missing,
    fixed.x = fixed.x,
    ...
  )
}
