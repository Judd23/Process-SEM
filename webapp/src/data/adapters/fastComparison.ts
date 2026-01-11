import fastComparisonData from '../fastComparison.json';
import type { FastComparison } from '../types/fastComparison';

const fastComparison = fastComparisonData as FastComparison;

export function getFastComparison(): FastComparison {
  return fastComparison;
}

export { fastComparison };
