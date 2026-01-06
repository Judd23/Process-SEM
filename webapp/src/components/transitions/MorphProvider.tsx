import { type ReactNode } from 'react';
import { LayoutGroup, AnimatePresence, motion } from 'framer-motion';
import { useLocation } from 'react-router-dom';

interface MorphProviderProps {
  children: ReactNode;
}

export default function MorphProvider({ children }: MorphProviderProps) {
  const location = useLocation();

  return (
    <LayoutGroup>
      <AnimatePresence mode="sync" initial={false}>
        <motion.div key={location.pathname} layout>
          {children}
        </motion.div>
      </AnimatePresence>
    </LayoutGroup>
  );
}
