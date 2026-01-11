import modelResultsData from '../modelResults.json';
import doseEffectsData from '../doseEffects.json';
import sampleDescriptivesData from '../sampleDescriptives.json';
import { DoseEffectsDataSchema, ModelResultsSchema, SampleDescriptivesSchema, safeParseData } from '../schemas/modelData';
import type { ModelData, StructuralPath, FitMeasures, DoseCoefficients, DoseEffect, ModelDataValidation } from '../types/modelData';

// Parse the JSON data into stable view models.
export function parseModelData(): ModelData {
  const errors: string[] = [];

  const modelResultsResult = safeParseData(ModelResultsSchema, modelResultsData, 'modelResults.json');
  const doseEffectsResult = safeParseData(DoseEffectsDataSchema, doseEffectsData, 'doseEffects.json');
  const sampleDescriptivesResult = safeParseData(
    SampleDescriptivesSchema,
    sampleDescriptivesData,
    'sampleDescriptives.json'
  );

  if (!modelResultsResult.success) errors.push(modelResultsResult.error);
  if (!doseEffectsResult.success) errors.push(doseEffectsResult.error);
  if (!sampleDescriptivesResult.success) errors.push(sampleDescriptivesResult.error);

  const validation: ModelDataValidation = { isValid: errors.length === 0, errors };

  const structuralPaths = modelResultsResult.success
    ? (modelResultsResult.data.mainModel.structuralPaths as StructuralPath[])
    : [];
  const fitMeasures = modelResultsResult.success
    ? (modelResultsResult.data.mainModel.fitMeasures as FitMeasures)
    : ({} as FitMeasures);
  const doseCoefficients = doseEffectsResult.success
    ? (doseEffectsResult.data.coefficients as DoseCoefficients)
    : ({} as DoseCoefficients);

  const safeDoseCoefficients: DoseCoefficients = doseEffectsResult.success
    ? doseCoefficients
    : ({
        distress: { main: 0, moderation: 0, se: 0 },
        engagement: { main: 0, moderation: 0, se: 0 },
        adjustment: { main: 0, moderation: 0, se: 0 },
      } as DoseCoefficients);

  const doseEffects = doseEffectsResult.success ? (doseEffectsResult.data.effects as DoseEffect[]) : [];
  const doseRange = doseEffectsResult.success
    ? doseEffectsResult.data.creditDoseRange
    : { min: 0, max: 0, threshold: 0, units: '' };

  // Create path lookup
  const pathMap: Record<string, StructuralPath> = {};
  structuralPaths.forEach(p => {
    pathMap[p.id] = p;
  });

  const getPath = (id: string) => pathMap[id] || null;

  // Calculate effect at any dose level
  const getEffectAtDose = (dose: number) => {
    const doseUnits = (dose - 12) / 10; // 10-credit units above threshold
    return {
      distress: safeDoseCoefficients.distress.main + doseUnits * safeDoseCoefficients.distress.moderation,
      engagement: safeDoseCoefficients.engagement.main + doseUnits * safeDoseCoefficients.engagement.moderation,
      adjustment: safeDoseCoefficients.adjustment.main + doseUnits * safeDoseCoefficients.adjustment.moderation,
    };
  };

  const sampleSize = sampleDescriptivesResult.success ? sampleDescriptivesResult.data.n : 0;
  const fastCount = sampleDescriptivesResult.success ? sampleDescriptivesResult.data.demographics.fast.yes.n : 0;
  const fastPercent = sampleDescriptivesResult.success ? sampleDescriptivesResult.data.demographics.fast.yes.pct : 0;

  return {
    paths: {
      a1: getPath('a1'),
      a1z: getPath('a1z'),
      a2: getPath('a2'),
      a2z: getPath('a2z'),
      b1: getPath('b1'),
      b2: getPath('b2'),
      c: getPath('c'),
      cz: getPath('cz'),
      g1: getPath('g1'),
      g2: getPath('g2'),
      g3: getPath('g3'),
    },
    allPaths: structuralPaths,
    fitMeasures,
    doseCoefficients: safeDoseCoefficients,
    doseEffects,
    doseRange: {
      min: doseRange.min,
      max: doseRange.max,
      threshold: doseRange.threshold,
      units: (doseRange as any).units ?? '',
    },
    sampleSize,
    fastCount,
    fastPercent,
    getPath,
    getEffectAtDose,
    validation,
  };
}

export { modelResultsData, doseEffectsData, sampleDescriptivesData };
