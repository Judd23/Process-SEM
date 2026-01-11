import { useEffect, useState, useRef } from 'react';

interface PointerPosition {
  x: number; // -1 to 1 (left to right)
  y: number; // -1 to 1 (top to bottom)
  clientX: number;
  clientY: number;
}

interface UsePointerParallaxOptions {
  /** Smoothing factor 0-1 (lower = smoother/slower) */
  smoothing?: number;
  /** Whether to track pointer */
  enabled?: boolean;
}

/**
 * Global pointer position hook for parallax effects.
 * Returns normalized coordinates (-1 to 1) for viewport-relative position.
 */
export function usePointerParallax({
  smoothing = 0.1,
  enabled = true,
}: UsePointerParallaxOptions = {}): PointerPosition {
  const [position, setPosition] = useState<PointerPosition>({
    x: 0,
    y: 0,
    clientX: 0,
    clientY: 0,
  });

  const targetRef = useRef({ x: 0, y: 0, clientX: 0, clientY: 0 });
  const rafRef = useRef<number | null>(null);

  // Use ref for animate to avoid circular dependency
  const animateRef = useRef<(() => void) | null>(null);

  animateRef.current = () => {
    if (!enabled) {
      setPosition({ x: 0, y: 0, clientX: 0, clientY: 0 });
      return;
    }

    setPosition((prev) => {
      const dx = targetRef.current.x - prev.x;
      const dy = targetRef.current.y - prev.y;

      // If close enough, snap to target
      if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) {
        return {
          x: targetRef.current.x,
          y: targetRef.current.y,
          clientX: targetRef.current.clientX,
          clientY: targetRef.current.clientY,
        };
      }

      return {
        x: prev.x + dx * smoothing,
        y: prev.y + dy * smoothing,
        clientX: targetRef.current.clientX,
        clientY: targetRef.current.clientY,
      };
    });

    rafRef.current = requestAnimationFrame(() => animateRef.current?.());
  };

  useEffect(() => {
    if (typeof window === 'undefined' || !enabled) return;

    const handleMove = (e: PointerEvent) => {
      const { clientX, clientY } = e;
      const { innerWidth, innerHeight } = window;

      // Normalize to -1 to 1
      targetRef.current = {
        x: (clientX / innerWidth) * 2 - 1,
        y: (clientY / innerHeight) * 2 - 1,
        clientX,
        clientY,
      };
    };

    const handleLeave = () => {
      // Gradually return to center when pointer leaves
      targetRef.current = { x: 0, y: 0, clientX: 0, clientY: 0 };
    };

    window.addEventListener('pointermove', handleMove, { passive: true });
    window.addEventListener('blur', handleLeave);
    window.addEventListener('mouseleave', handleLeave);

    // Start animation loop
    rafRef.current = requestAnimationFrame(() => animateRef.current?.());

    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('blur', handleLeave);
      window.removeEventListener('mouseleave', handleLeave);
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current);
      }
    };
  }, [enabled]);

  return position;
}

/**
 * Element-local pointer parallax for tilt effects.
 * Returns rotation values based on pointer position relative to element.
 */
export function useElementTilt(
  elementRef: React.RefObject<HTMLElement | null>,
  options: {
    maxRotation?: number;
    enabled?: boolean;
  } = {}
) {
  const { maxRotation = 8, enabled = true } = options;
  const [tilt, setTilt] = useState({ rotateX: 0, rotateY: 0 });
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    const element = elementRef.current;
    if (!element || !enabled) return;

    const handleMove = (e: PointerEvent) => {
      if (rafRef.current) return;

      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null;
        const rect = element.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;

        // Normalize to -1 to 1 relative to element center
        const x = (e.clientX - centerX) / (rect.width / 2);
        const y = (e.clientY - centerY) / (rect.height / 2);

        // Clamp values
        const clampedX = Math.max(-1, Math.min(1, x));
        const clampedY = Math.max(-1, Math.min(1, y));

        setTilt({
          rotateX: -clampedY * maxRotation, // Negative: tilt toward pointer
          rotateY: clampedX * maxRotation,
        });
      });
    };

    const handleLeave = () => {
      setTilt({ rotateX: 0, rotateY: 0 });
    };

    element.addEventListener('pointermove', handleMove, { passive: true });
    element.addEventListener('pointerleave', handleLeave);

    return () => {
      element.removeEventListener('pointermove', handleMove);
      element.removeEventListener('pointerleave', handleLeave);
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current);
      }
    };
  }, [elementRef, maxRotation, enabled]);

  return tilt;
}
