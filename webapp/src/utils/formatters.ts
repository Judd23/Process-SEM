// Format a number to a specified number of decimal places
export function formatNumber(value: number, decimals = 3): string {
  return value.toFixed(decimals);
}

// Format a p-value with proper notation
export function formatPValue(p: number): string {
  if (p < 0.001) return '< .001';
  if (p < 0.01) return '< .01';
  if (p < 0.05) return '< .05';
  return `= ${p.toFixed(3).replace('0.', '.')}`;
}

// Get significance stars
export function getSignificanceStars(p: number): string {
  if (p < 0.001) return '***';
  if (p < 0.01) return '**';
  if (p < 0.05) return '*';
  return '';
}

// Format a confidence interval
export function formatCI(lower: number, upper: number, decimals = 3): string {
  return `[${lower.toFixed(decimals)}, ${upper.toFixed(decimals)}]`;
}

// Format effect size with interpretation
export function formatEffectSize(d: number): { value: string; interpretation: string } {
  const absD = Math.abs(d);
  let interpretation = '';

  if (absD < 0.2) interpretation = 'negligible';
  else if (absD < 0.5) interpretation = 'small';
  else if (absD < 0.8) interpretation = 'medium';
  else interpretation = 'large';

  return {
    value: d.toFixed(3),
    interpretation,
  };
}

// Format percentage
export function formatPercent(value: number, decimals = 1): string {
  return `${(value * 100).toFixed(decimals)}%`;
}

// Format sample size with commas
export function formatN(n: number): string {
  return n.toLocaleString();
}

// Variable label mappings for display
export const variableLabels: Record<string, string> = {
  // Treatment
  x_FASt: 'FASt Status (≥12 credits)',
  XZ_c: 'FASt × Credit Dose',
  credit_dose: 'Credit Dose',
  credit_dose_c: 'Credit Dose (centered)',

  // Mediators
  EmoDiss: 'Emotional Distress',
  QualEngag: 'Quality of Engagement',

  // Outcome
  DevAdj: 'Developmental Adjustment',
  Belong: 'Belonging',
  Gains: 'Perceived Gains',
  SupportEnv: 'Supportive Environment',
  Satisf: 'Satisfaction',

  // Path labels
  a1: 'FASt → Distress',
  a1z: 'FASt × Dose → Distress',
  a2: 'FASt → Engagement',
  a2z: 'FASt × Dose → Engagement',
  b1: 'Distress → Adjustment',
  b2: 'Engagement → Adjustment',
  c: 'FASt → Adjustment (direct)',
  cz: 'FASt × Dose → Adjustment (direct)',

  // Demographics
  re_all: 'Race/Ethnicity',
  firstgen: 'First-Generation Status',
  pell: 'Pell Grant Eligibility',
  sex: 'Gender',
  living18: 'Living Situation',

  // Distress indicators
  MHWdacad: 'Academic Difficulties',
  MHWdlonely: 'Loneliness',
  MHWdmental: 'Mental Health',
  MHWdexhaust: 'Exhaustion',
  MHWdsleep: 'Sleep Problems',
  MHWdfinancial: 'Financial Stress',

  // Engagement indicators
  QIadmin: 'Administrative Staff',
  QIstudent: 'Other Students',
  QIadvisor: 'Academic Advisors',
  QIfaculty: 'Faculty',
  QIstaff: 'Student Services Staff',
};

// Get human-readable label for a variable
export function getLabel(variable: string): string {
  return variableLabels[variable] || variable;
}

// Pathway descriptions for tooltips
export const pathwayDescriptions: Record<string, string> = {
  a1: 'The effect of FASt status on emotional distress',
  a1z: 'How credit dose moderates the FASt → distress relationship',
  a2: 'The effect of FASt status on quality of engagement',
  a2z: 'How credit dose moderates the FASt → engagement relationship',
  b1: 'The effect of emotional distress on developmental adjustment',
  b2: 'The effect of quality engagement on developmental adjustment',
  c: 'The direct effect of FASt status on developmental adjustment',
  cz: 'How credit dose moderates the direct FASt → adjustment effect',
};
