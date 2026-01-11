import sampleDescriptivesData from '../sampleDescriptives.json';
import type { SampleDescriptives } from '../types/sampleDescriptives';

const sampleDescriptives = sampleDescriptivesData as unknown as SampleDescriptives;

export function getSampleDescriptives(): SampleDescriptives {
  return sampleDescriptives;
}

export { sampleDescriptives };
