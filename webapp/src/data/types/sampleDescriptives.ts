export interface DemographicGroup {
  n: number;
  pct: number;
}

export interface TransferCreditsStats {
  mean: number;
  sd: number;
  min: number;
  max: number;
  median: number;
}

export interface SampleDescriptives {
  n: number;
  demographics: {
    race: Record<string, DemographicGroup>;
    firstgen: { yes: DemographicGroup; no: DemographicGroup };
    pell: { yes: DemographicGroup; no: DemographicGroup };
    fast: { yes: DemographicGroup; no: DemographicGroup };
    sex: { women: DemographicGroup; men: DemographicGroup };
    transferCredits: TransferCreditsStats;
    living: Record<string, DemographicGroup>;
    [key: string]: unknown;
  };
}
