import doseEffectsRaw from '../doseEffects.json';
import type { DoseEffectsData } from '../types/doseEffects';

const doseEffects = doseEffectsRaw as unknown as DoseEffectsData;

export function getDoseEffects(): DoseEffectsData {
  return doseEffects;
}

export { doseEffects };
