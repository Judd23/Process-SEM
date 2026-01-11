/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, type ReactNode } from 'react';
import {
  parseModelData,
  modelResultsData,
  doseEffectsData,
  sampleDescriptivesData,
} from '../../data/adapters/modelData';
import type { ModelData } from '../../data/types/modelData';

const ModelDataContext = createContext<ModelData | null>(null);

const modelData = parseModelData();

export function ModelDataProvider({ children }: { children: ReactNode }) {
  return (
    <ModelDataContext.Provider value={modelData}>
      {children}
    </ModelDataContext.Provider>
  );
}

export function useModelData(): ModelData {
  const context = useContext(ModelDataContext);
  if (!context) {
    throw new Error('useModelData must be used within ModelDataProvider');
  }
  return context;
}

// Export raw data for components that need direct access
export { modelResultsData, doseEffectsData, sampleDescriptivesData };
