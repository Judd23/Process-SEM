import type { ReactNode } from 'react';
import { HashRouter } from 'react-router-dom';
import { MotionConfig } from 'framer-motion';
import { ResearchProvider, ThemeProvider, ModelDataProvider, ChoreographerProvider, TransitionProvider } from '../app/contexts';
import { DANCE_SPRING_HEAVY } from '../lib/transitionConfig';

interface AppProvidersProps {
  children: ReactNode;
}

/**
 * Global spring physics configuration.
 * All Framer Motion components inherit this transition by default.
 * reducedMotion="never" ensures animations run (user can still use CSS prefers-reduced-motion).
 */
export function AppProviders({ children }: AppProvidersProps) {
  return (
    <ThemeProvider>
      <MotionConfig reducedMotion="never" transition={DANCE_SPRING_HEAVY}>
        <ModelDataProvider>
          <ResearchProvider>
            <TransitionProvider>
              <ChoreographerProvider>
                <HashRouter>
                  {children}
                </HashRouter>
              </ChoreographerProvider>
            </TransitionProvider>
          </ResearchProvider>
        </ModelDataProvider>
      </MotionConfig>
    </ThemeProvider>
  );
}
