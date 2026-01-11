export interface ComparisonGroup {
  n: number;
  pct: number;
}

export interface ComparisonByGroup {
  fast: ComparisonGroup;
  nonfast: ComparisonGroup;
}

export interface TransferCreditsStats {
  mean: number;
  sd: number;
  min: number;
  max: number;
  median: number;
}

export interface FastComparison {
  overall: { n: number; fast_n: number; nonfast_n: number };
  demographics: {
    race: Record<string, ComparisonByGroup>;
    firstgen: Record<string, ComparisonByGroup>;
    pell: Record<string, ComparisonByGroup>;
    sex: Record<string, ComparisonByGroup>;
    living: Record<string, ComparisonByGroup>;
    transferCredits: {
      fast: TransferCreditsStats;
      nonfast: TransferCreditsStats;
    };
  };
}
