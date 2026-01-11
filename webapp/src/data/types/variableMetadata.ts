export interface VariableMetadataEntry {
  label?: string;
  description?: string;
  [key: string]: unknown;
}

export interface VariableMetadata {
  constructs?: Record<string, VariableMetadataEntry>;
  paths?: Record<string, VariableMetadataEntry>;
  variables?: Record<string, VariableMetadataEntry> | Array<unknown>;
  [key: string]: unknown;
}
