import type { ReactNode } from 'react';
import { HashRouter } from 'react-router-dom';
import { MotionConfig } from 'framer-motion';
import { ResearchProvider } from '../app/contexts/ResearchContext';
import { ThemeProvider } from '../app/contexts/ThemeContext';
import { ModelDataProvider } from '../app/contexts/ModelDataContext';
import { ChoreographerProvider } from '../app/contexts/ChoreographerContext';
import { TransitionProvider } from '../app/contexts/TransitionContext';

interface AppProvidersProps {
  children: ReactNode;
}

export function AppProviders({ children }: AppProvidersProps) {
  return (
    <ThemeProvider>
      <MotionConfig reducedMotion="user">
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
