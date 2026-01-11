import React, { forwardRef } from 'react';
import type { ReactNode, ElementType, Ref } from 'react';
import { motion, type HTMLMotionProps, type MotionProps } from 'framer-motion';
import { Link, type LinkProps } from 'react-router-dom';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';

// Create motion-compatible Link
const MotionLink = motion.create(Link);

type BaseSurfaceProps = {
  hoverLift?: number;   // px (positive number, component will lift upward)
  hoverScale?: number;  // e.g., 1.01
  tapScale?: number;    // e.g., 0.995
  children?: ReactNode;
  className?: string;
};

// When as="link", use LinkProps
type LinkSurfaceProps = BaseSurfaceProps & {
  as: 'link';
  to: LinkProps['to'];
} & Omit<LinkProps, 'to' | 'className' | 'children'>;

// For HTML elements
type HtmlSurfaceProps<T extends ElementType> = BaseSurfaceProps & {
  as?: T;
} & Omit<HTMLMotionProps<T extends keyof JSX.IntrinsicElements ? T : never>, keyof BaseSurfaceProps | 'as'>;

type Props<T extends ElementType = 'div'> = T extends 'link' ? LinkSurfaceProps : HtmlSurfaceProps<T>;

/**
 * InteractiveSurface
 * Framer Motion controls transform using a heavy spring preset.
 * CSS should handle border/shadow/sheen only (no transform rules).
 * 
 * Usage:
 *   <InteractiveSurface as="button" className="..." onClick={...}>Click</InteractiveSurface>
 *   <InteractiveSurface as="link" to="/path" className="...">Navigate</InteractiveSurface>
 *   <InteractiveSurface as="article" className="...">Card content</InteractiveSurface>
 */
function InteractiveSurfaceInner<T extends ElementType = 'div'>(
  {
    as,
    className,
    children,
    hoverLift = 4,
    hoverScale = 1.02,
    tapScale = 0.995,
    ...rest
  }: Props<T>,
  ref: Ref<HTMLElement>
) {
  const sharedMotionProps: Partial<MotionProps> = {
    whileHover: { y: -hoverLift, scale: hoverScale },
    whileTap: { y: -(hoverLift * 0.5), scale: tapScale },
    transition: DANCE_SPRING_HEAVY,
  };

  // Handle Link special case
  if (as === 'link') {
    const { to, ...linkRest } = rest as Omit<LinkSurfaceProps, keyof BaseSurfaceProps | 'as'> & { to: LinkProps['to'] };
    return (
      <MotionLink
        ref={ref as Ref<HTMLAnchorElement>}
        to={to}
        className={className}
        {...sharedMotionProps}
        {...linkRest}
      >
        {children}
      </MotionLink>
    );
  }

  // For all other HTML elements
  const Comp = motion[as as keyof typeof motion] || motion.div;

  return (
    <Comp
      ref={ref}
      className={className}
      {...sharedMotionProps}
      {...rest}
    >
      {children}
    </Comp>
  );
}

// Cast to preserve generic type
export const InteractiveSurface = forwardRef(InteractiveSurfaceInner) as <T extends ElementType = 'div'>(
  props: Props<T> & { ref?: Ref<HTMLElement> }
) => React.ReactElement | null;
