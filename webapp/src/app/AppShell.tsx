import { AppProviders } from './providers';
import { AppRoutes } from './routes';
import '../styles/global.css';

/**
 * AppShell - Root component with providers and router.
 *
 * Provider order (outside -> inside):
 * 1. ThemeProvider - CSS variables for theming
 * 2. MotionConfig - Global reduced motion handling
 * 3. ModelDataProvider - Research data context
 * 4. ResearchProvider - Research state
 * 5. TransitionProvider - Transition state
 * 6. ChoreographerProvider - Viewport tracking for center-out stagger
 * 7. HashRouter - Client-side routing (GitHub Pages compatible)
 */
export default function AppShell() {
  return (
    <AppProviders>
      <AppRoutes />
    </AppProviders>
  );
}
