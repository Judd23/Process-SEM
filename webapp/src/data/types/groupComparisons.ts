export interface GroupEffectJson {
  estimate: number;
  se: number;
  pvalue: number;
}

export interface GroupJson {
  label: string;
  effects: {
    a1: GroupEffectJson;
    a2: GroupEffectJson;
  };
}

export interface GroupingJson {
  groupVariable: string;
  groups: GroupJson[];
}

export interface GroupComparisonsJson {
  byRace: GroupingJson;
  byFirstgen: GroupingJson;
  byPell: GroupingJson;
  bySex: GroupingJson;
  byLiving: GroupingJson;
}
