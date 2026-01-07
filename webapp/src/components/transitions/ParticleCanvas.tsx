import { useRef, useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { ParticleSystem, samplePageColors } from '../../utils/particleEngine';
import { useTransition } from '../../context/TransitionContext';
import styles from './ParticleCanvas.module.css';

interface ParticleCanvasProps {
  active: boolean;
  onComplete?: () => void;
}

export default function ParticleCanvas({ active, onComplete }: ParticleCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const systemRef = useRef<ParticleSystem | null>(null);
  const animationRef = useRef<number>(0);
  const animateFnRef = useRef<((lastTime: number) => void) | null>(null);
  const { particleCount, reducedMotion } = useTransition();

  const render = useCallback(() => {
    const canvas = canvasRef.current;
    const system = systemRef.current;
    if (!canvas || !system) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw particles
    system.particles.forEach((p) => {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fillStyle = p.color;
      ctx.globalAlpha = p.alpha;
      ctx.fill();
    });

    ctx.globalAlpha = 1;
  }, []);

  // Store animate function in ref to avoid hoisting issues with self-reference
  useEffect(() => {
    animateFnRef.current = (lastTime: number) => {
      const system = systemRef.current;
      if (!system || !active) return;

      const currentTime = performance.now();
      const deltaTime = (currentTime - lastTime) / 1000;

      system.update(deltaTime);
      render();

      if (!system.isComplete()) {
        animationRef.current = requestAnimationFrame(() => animateFnRef.current?.(currentTime));
      } else {
        onComplete?.();
      }
    };
  }, [active, render, onComplete]);

  useEffect(() => {
    if (!active || reducedMotion) {
      onComplete?.();
      return;
    }

    const canvas = canvasRef.current;
    if (!canvas) return;

    // Set canvas size to window
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    // Initialize particle system
    const system = new ParticleSystem(canvas.width, canvas.height);
    const colors = samplePageColors(particleCount);
    system.initFromColors(colors, particleCount);
    system.onPhaseComplete = onComplete;
    systemRef.current = system;

    // Start animation
    animationRef.current = requestAnimationFrame(() => animateFnRef.current?.(performance.now()));

    return () => {
      cancelAnimationFrame(animationRef.current);
      systemRef.current?.reset();
    };
  }, [active, particleCount, reducedMotion, onComplete, render]);

  // Handle window resize
  useEffect(() => {
    const handleResize = () => {
      const canvas = canvasRef.current;
      if (canvas) {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
      }
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (!active || reducedMotion) {
    return null;
  }

  return createPortal(
    <canvas ref={canvasRef} className={styles.canvas} aria-hidden="true" />,
    document.body
  );
}
