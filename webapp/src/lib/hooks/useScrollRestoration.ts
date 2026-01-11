import { useEffect, useRef, useCallback } from 'react';
import { useLocation } from 'react-router-dom';

// Store scroll positions for each route
const scrollPositions = new Map<string, number>();

// Track navigation direction
let navigationDirection: 'forward' | 'back' | 'unknown' = 'unknown';
let historyLength = 0;

/**
 * Hook to manage scroll restoration for back/forward navigation.
 * 
 * - Forward navigation: Scroll to top (handled by onExitComplete)
 * - Back navigation: Restore previous scroll position
 * 
 * @returns Object with scroll handler for onExitComplete
 */
export function useScrollRestoration() {
  const location = useLocation();
  const previousPathRef = useRef<string | null>(null);

  // Track navigation direction by comparing history length
  useEffect(() => {
    const currentLength = window.history.length;
    
    if (currentLength > historyLength) {
      navigationDirection = 'forward';
    } else if (currentLength < historyLength || currentLength === historyLength) {
      // Same length could be back then forward, or replace - treat as back for safety
      navigationDirection = 'back';
    }
    
    historyLength = currentLength;
  }, [location.pathname]);

  // Save scroll position when leaving a page
  useEffect(() => {
    const saveScrollPosition = () => {
      if (previousPathRef.current) {
        scrollPositions.set(previousPathRef.current, window.scrollY);
      }
      previousPathRef.current = location.pathname;
    };

    // Save on route change
    saveScrollPosition();

    // Also save on scroll (debounced would be better but simple for now)
    const handleScroll = () => {
      scrollPositions.set(location.pathname, window.scrollY);
    };
    
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [location.pathname]);

  // Handle scroll on exit complete
  const handleExitComplete = useCallback(() => {
    const targetPath = location.pathname;
    
    if (navigationDirection === 'back') {
      // Restore scroll position for back navigation
      const savedPosition = scrollPositions.get(targetPath);
      if (savedPosition !== undefined) {
        // Small delay to ensure DOM is ready
        requestAnimationFrame(() => {
          window.scrollTo({ top: savedPosition, behavior: 'auto' });
        });
        return;
      }
    }
    
    // Default: scroll to top for forward navigation
    window.scrollTo({ top: 0, behavior: 'auto' });
  }, [location.pathname]);

  return { handleExitComplete, navigationDirection };
}

/**
 * Get the current navigation direction
 */
export function getNavigationDirection() {
  return navigationDirection;
}

/**
 * Manually set navigation direction (useful for programmatic navigation)
 */
export function setNavigationDirection(direction: 'forward' | 'back') {
  navigationDirection = direction;
}
