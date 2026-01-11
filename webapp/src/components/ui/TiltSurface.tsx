import React, { useCallback, useRef } from 'react';
import type { ReactNode, Ref, CSSProperties, MouseEventHandler } from 'react';
import { motion } from 'framer-motion';
import { Link, type LinkProps } from 'react-router-dom';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';
import { useElementTilt } from '../../lib/hooks/usePointerParallax';

// Create motion-compatible Link
const MotionLink = motion.create(Link);

type SupportedElement = 'div' | 'article' | 'section' | 'button' | 'a' | 'span' | 'link';

interface TiltSurfaceProps {
  as?: SupportedElement;
  to?: LinkProps['to'];
  hoverLift?: number;
  hoverScale?: number;
  tapScale?: number;
  maxRotation?: number;
  tiltEnabled?: boolean;
  children?: ReactNode;
  className?: string;
  style?: CSSProperties;
  onClick?: MouseEventHandler;
  'aria-label'?: string;
  'aria-pressed'?: boolean;
  type?: 'button' | 'submit' | 'reset';
}

/**
 * TiltSurface
 * 
 * 3D pointer-driven parallax surface with rotateX/rotateY.
 * Also applies spring-based lift and scale on hover (like InteractiveSurface).
 */
export function TiltSurface({
  as = 'div',
  to,
  className,
  children,
  style: userStyle,
  hoverLift = 6,
  hoverScale = 1.02,
  tapScale = 0.98,
  maxRotation = 8,
  tiltEnabled = true,
  onClick,
  'aria-label': ariaLabel,
  'aria-pressed': ariaPressed,
  type,
}: TiltSurfaceProps) {
  // Internal ref for tilt tracking
  const internalRef = useRef<HTMLElement>(null);

  // Callback ref to attach internal ref
  const setRef = useCallback((node: HTMLElement | null) => {
    (internalRef as React.MutableRefObject<HTMLElement | null>).current = node;
  }, []);

  // Get tilt values from pointer position
  const { rotateX, rotateY } = useElementTilt(internalRef, {
    maxRotation,
    enabled: tiltEnabled,
  });

  const motionStyle: CSSProperties & { rotateX?: number; rotateY?: number } = {
    transformStyle: 'preserve-3d',
    rotateX: tiltEnabled ? rotateX : 0,
    rotateY: tiltEnabled ? rotateY : 0,
    ...userStyle,
  };

  const hoverProps = {
    y: -hoverLift,
    scale: hoverScale,
  };

  const tapProps = {
    y: -(hoverLift * 0.5),
    scale: tapScale,
  };

  // Handle Link special case
  if (as === 'link' && to) {
    return (
      <MotionLink
        ref={setRef as Ref<HTMLAnchorElement>}
        to={to}
        className={className}
        style={motionStyle}
        whileHover={hoverProps}
        whileTap={tapProps}
        transition={DANCE_SPRING_HEAVY}
      >
        {children}
      </MotionLink>
    );
  }

  // Shared props for all HTML element types
  const commonProps = {
    className,
    style: motionStyle,
    whileHover: hoverProps,
    whileTap: tapProps,
    transition: DANCE_SPRING_HEAVY,
    onClick,
    'aria-label': ariaLabel,
  };

  if (as === 'button') {
    return (
      <motion.button
        ref={setRef as Ref<HTMLButtonElement>}
        type={type || 'button'}
        aria-pressed={ariaPressed}
        {...commonProps}
      >
        {children}
      </motion.button>
    );
  }

  if (as === 'a') {
    return (
      <motion.a ref={setRef as Ref<HTMLAnchorElement>} {...commonProps}>
        {children}
      </motion.a>
    );
  }

  if (as === 'article') {
    return (
      <motion.article ref={setRef as Ref<HTMLElement>} {...commonProps}>
        {children}
      </motion.article>
    );
  }

  if (as === 'section') {
    return (
      <motion.section ref={setRef as Ref<HTMLElement>} {...commonProps}>
        {children}
      </motion.section>
    );
  }

  if (as === 'span') {
    return (
      <motion.span ref={setRef as Ref<HTMLSpanElement>} {...commonProps}>
        {children}
      </motion.span>
    );
  }

  // Default: div
  return (
    <motion.div ref={setRef as Ref<HTMLDivElement>} {...commonProps}>
      {children}
    </motion.div>
  );
}
