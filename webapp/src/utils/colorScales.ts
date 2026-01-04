// Color scales matching the matplotlib figures
export const colors = {
  // Construct colors - semantic meaning
  distress: '#d62728',      // Red - Emotional Distress mediator
  engagement: '#1f77b4',    // Blue - Quality of Engagement mediator
  fast: '#ff7f0e',          // Orange - FASt treatment status
  nonfast: '#7f7f7f',       // Gray - Non-FASt control
  credits: '#f0c000',       // Yellow - Credit dose

  // Outcome subdimensions
  belonging: '#2ca02c',     // Green
  gains: '#000080',         // Navy
  support: '#9467bd',       // Purple
  satisfaction: '#8c564b',  // Brown

  // Adjustment overall
  adjustment: '#2ca02c',    // Green (positive outcome)

  // Significance
  significant: '#2ca02c',
  nonsignificant: '#cccccc',
  positive: '#2ca02c',
  negative: '#d62728',

  // Race/ethnicity palette
  hispanic: '#e377c2',
  white: '#7f7f7f',
  asian: '#bcbd22',
  black: '#17becf',
  other: '#9467bd',
} as const;

// Get color for a pathway
export function getPathwayColor(pathway: 'distress' | 'engagement' | 'direct'): string {
  switch (pathway) {
    case 'distress': return colors.distress;
    case 'engagement': return colors.engagement;
    case 'direct': return colors.nonfast;
  }
}

// Get color for effect direction
export function getEffectColor(value: number): string {
  if (value > 0) return colors.positive;
  if (value < 0) return colors.negative;
  return colors.nonsignificant;
}

// Get color for significance
export function getSignificanceColor(pvalue: number, threshold = 0.05): string {
  return pvalue < threshold ? colors.significant : colors.nonsignificant;
}

// Race/ethnicity color mapping
export function getRaceColor(race: string): string {
  const raceColors: Record<string, string> = {
    'Hispanic/Latino': colors.hispanic,
    'White': colors.white,
    'Asian': colors.asian,
    'Black/African American': colors.black,
    'Other/Multiracial/Unknown': colors.other,
  };
  return raceColors[race] || colors.nonfast;
}

// Opacity for non-highlighted elements
export function getHighlightOpacity(isHighlighted: boolean, highlightActive: boolean): number {
  if (!highlightActive) return 1;
  return isHighlighted ? 1 : 0.2;
}
