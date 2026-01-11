import groupComparisonsRaw from '../groupComparisons.json';
import type { GroupComparisonsJson } from '../types/groupComparisons';

const groupComparisons = groupComparisonsRaw as GroupComparisonsJson;

export function getGroupComparisons(): GroupComparisonsJson {
  return groupComparisons;
}

export { groupComparisons };
