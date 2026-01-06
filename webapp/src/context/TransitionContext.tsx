import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
} from 'react';

type TransitionMode = 'none' | 'particles' | 'morph' | 'auto';
type TransitionPhase = 'idle' | 'exiting' | 'transitioning' | 'entering';

interface SharedElementRect {
  id: string;
  rect: DOMRect;
  route: string;
}

interface TransitionContextValue {
  mode: TransitionMode;
  setMode: (mode: TransitionMode) => void;
  phase: TransitionPhase;
  setPhase: (phase: TransitionPhase) => void;
  sourceRoute: string | null;
  targetRoute: string | null;
  reducedMotion: boolean;
  particleCount: number;
  sharedElements: Map<string, SharedElementRect>;
  registerSharedElement: (id: string, rect: DOMRect, route: string) => void;
  unregisterSharedElement: (id: string) => void;
  startTransition: (from: string, to: string) => Promise<void>;
  completeTransition: () => void;
  hasMatchingSharedElements: (targetRoute: string) => boolean;
}

const TransitionContext = createContext<TransitionContextValue | null>(null);

interface TransitionProviderProps {
  children: ReactNode;
}

export function TransitionProvider({ children }: TransitionProviderProps) {
  const [mode, setMode] = useState<TransitionMode>('morph');
  const [phase, setPhase] = useState<TransitionPhase>('idle');
  const [sourceRoute, setSourceRoute] = useState<string | null>(null);
  const [targetRoute, setTargetRoute] = useState<string | null>(null);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [particleCount, setParticleCount] = useState(200);
  const [sharedElements] = useState(() => new Map<string, SharedElementRect>());
  const [currentRoute, setCurrentRoute] = useState(() => {
    if (typeof window === 'undefined') return '/';
    const hash = window.location.hash.replace(/^#/, '');
    if (!hash) return '/';
    return hash.startsWith('/') ? hash : `/${hash}`;
  });

  // Detect reduced motion preference
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setReducedMotion(mediaQuery.matches);

    const handler = (e: MediaQueryListEvent) => setReducedMotion(e.matches);
    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', handler);
      return () => mediaQuery.removeEventListener('change', handler);
    }
    mediaQuery.addListener(handler);
    return () => mediaQuery.removeListener(handler);
  }, []);

  useEffect(() => {
    const updateRoute = () => {
      const hash = window.location.hash.replace(/^#/, '');
      if (!hash) {
        setCurrentRoute('/');
        return;
      }
      setCurrentRoute(hash.startsWith('/') ? hash : `/${hash}`);
    };

    window.addEventListener('hashchange', updateRoute);
    window.addEventListener('popstate', updateRoute);
    updateRoute();
    return () => {
      window.removeEventListener('hashchange', updateRoute);
      window.removeEventListener('popstate', updateRoute);
    };
  }, []);

  // Detect device capability for particle count
  useEffect(() => {
    const cores = navigator.hardwareConcurrency || 4;
    if (cores >= 8) {
      setParticleCount(200);
    } else if (cores >= 4) {
      setParticleCount(100);
    } else {
      setParticleCount(50);
    }
  }, []);

  const registerSharedElement = useCallback(
    (id: string, rect: DOMRect, route: string) => {
      sharedElements.set(id, { id, rect, route });
    },
    [sharedElements]
  );

  const unregisterSharedElement = useCallback(
    (id: string) => {
      sharedElements.delete(id);
    },
    [sharedElements]
  );

  const hasMatchingSharedElements = useCallback(
    (targetRoute: string) => {
      const activeRoute = sourceRoute ?? currentRoute;
      // Check if any shared elements exist on both current and target route
      const currentRouteElements = Array.from(sharedElements.values()).filter(
        (el) => el.route === activeRoute
      );
      // For auto-detection, we assume shared elements with same ID will exist on target
      return currentRouteElements.length > 0 && targetRoute !== activeRoute;
    },
    [sharedElements, sourceRoute, currentRoute]
  );

  const startTransition = useCallback(
    async (from: string, to: string) => {
      if (reducedMotion) {
        return; // Skip animation entirely
      }

      setSourceRoute(from);
      setTargetRoute(to);
      setPhase('exiting');

      // Wait for exit animation
      await new Promise((resolve) => setTimeout(resolve, 400));

      setPhase('transitioning');

      // Wait for transition
      await new Promise((resolve) => setTimeout(resolve, 400));

      setPhase('entering');
    },
    [reducedMotion]
  );

  const completeTransition = useCallback(() => {
    setPhase('idle');
    setSourceRoute(null);
    setTargetRoute(null);
  }, []);

  return (
    <TransitionContext.Provider
      value={{
        mode,
        setMode,
        phase,
        setPhase,
        sourceRoute,
        targetRoute,
        reducedMotion,
        particleCount,
        sharedElements,
        registerSharedElement,
        unregisterSharedElement,
        startTransition,
        completeTransition,
        hasMatchingSharedElements,
      }}
    >
      {children}
    </TransitionContext.Provider>
  );
}

export function useTransition() {
  const context = useContext(TransitionContext);
  if (!context) {
    throw new Error('useTransition must be used within TransitionProvider');
  }
  return context;
}

export function useReducedMotion() {
  const { reducedMotion } = useTransition();
  return reducedMotion;
}
