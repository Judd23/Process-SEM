import dataMetadataRaw from '../dataMetadata.json';
import type { DataMetadata } from '../types/dataMetadata';

const dataMetadata = dataMetadataRaw as DataMetadata;

export function getDataMetadata(): DataMetadata {
  return dataMetadata;
}

export { dataMetadata };
