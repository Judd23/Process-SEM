import { type ReactNode } from 'react';
import { LayoutGroup } from 'framer-motion';

interface MorphProviderProps {
  children: ReactNode;
}

export default function MorphProvider({ children }: MorphProviderProps) {
  return <LayoutGroup id="route-morph">{children}</LayoutGroup>;
}
