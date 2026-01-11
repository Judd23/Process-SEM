import variableMetadataRaw from '../variableMetadata.json';
import type { VariableMetadata } from '../types/variableMetadata';

const variableMetadata = variableMetadataRaw as VariableMetadata;

export function getVariableMetadata(): VariableMetadata {
  return variableMetadata;
}

export { variableMetadata };
