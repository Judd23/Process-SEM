/**
 * Motion Interaction Contract
 * ==========================
 * Single source of truth for all Motion-driven interactions.
 * 
 * PRINCIPLE: Motion owns ALL transforms (translate/scale/rotate/skew).
 * CSS owns visuals only (color, opacity, blur, shadows, borders, gradients).
 * 
 * Spring tuning: "longer entrance path" + "heavier mass" + "gentle settle"
 * - mass: 1.2–1.8
 * - stiffness: 90–140
 * - damping: 18–26
 */

import { type Transition, type Variants } from 'framer-motion';

// =============================================================================
// SPRING CONFIGURATIONS
// =============================================================================

/**
 * Card interaction spring - for cards, panels, blocks
 * Heavier feel with gentle settle
 */
export const CARD_SPRING: Transition = {
  type: 'spring',
  stiffness: 120,
  damping: 22,
  mass: 1.4,
};

/**
 * Link interaction spring - for buttons, links, small interactive elements
 * Slightly lighter for responsive feel
 */
export const LINK_SPRING: Transition = {
  type: 'spring',
  stiffness: 140,
  damping: 20,
  mass: 1.2,
};

/**
 * Underline reveal spring - for decorative underlines
 * Quick but not snappy
 */
export const UNDERLINE_SPRING: Transition = {
  type: 'spring',
  stiffness: 100,
  damping: 24,
  mass: 1.3,
};

/**
 * Scale indicator spring - for scale-based feedback
 */
export const SCALE_SPRING: Transition = {
  type: 'spring',
  stiffness: 130,
  damping: 18,
  mass: 1.2,
};

// =============================================================================
// MOTION PRESETS (for motion.* components)
// =============================================================================

/**
 * Card motion preset
 * Use: motion.article, motion.div for card-like surfaces
 */
export const cardMotion = {
  initial: { y: 0, scale: 1 },
  animate: { y: 0, scale: 1 },
  whileHover: { y: -6, scale: 1.01 },
  whileTap: { scale: 0.98 },
  transition: CARD_SPRING,
} as const;

/**
 * Light card motion - subtle hover lift
 * Use: smaller cards, stat cards
 */
export const cardMotionLight = {
  initial: { y: 0, scale: 1 },
  animate: { y: 0, scale: 1 },
  whileHover: { y: -4, scale: 1.005 },
  whileTap: { scale: 0.99 },
  transition: CARD_SPRING,
} as const;

/**
 * Link/button motion preset
 * Use: motion.a, motion.button for interactive links
 */
export const linkMotion = {
  whileHover: { y: -2 },
  whileTap: { scale: 0.96 },
  transition: LINK_SPRING,
} as const;

/**
 * Dose zone button motion
 * Use: dose zone selector buttons
 */
export const doseZoneMotion = {
  initial: { scale: 1 },
  animate: { scale: 1 },
  whileHover: { scale: 1.02 },
  whileTap: { scale: 0.98 },
  transition: SCALE_SPRING,
} as const;

/**
 * Active dose zone (selected state)
 */
export const doseZoneActiveMotion = {
  initial: { scale: 1.05 },
  animate: { scale: 1.05 },
  whileHover: { scale: 1.07 },
  whileTap: { scale: 1.03 },
  transition: SCALE_SPRING,
} as const;

/**
 * Hero figure motion
 * Use: hero images with dramatic hover
 */
export const heroFigureMotion = {
  initial: { y: 0, rotate: 0, scale: 1 },
  animate: { y: 0, rotate: 0, scale: 1 },
  whileHover: { y: -8, rotate: -1, scale: 1.01 },
  whileTap: { scale: 0.98 },
  transition: CARD_SPRING,
} as const;

/**
 * Block/panel motion - for content blocks
 */
export const blockMotion = {
  initial: { y: 0 },
  animate: { y: 0 },
  whileHover: { y: -6 },
  whileTap: { scale: 0.98 },
  transition: CARD_SPRING,
} as const;

/**
 * Fact card motion
 */
export const factMotion = {
  initial: { y: 0, scale: 1 },
  animate: { y: 0, scale: 1 },
  whileHover: { y: -2, scale: 1.03 },
  whileTap: { scale: 0.98 },
  transition: CARD_SPRING,
} as const;

/**
 * List item motion - for hoverable list items
 */
export const listItemMotion = {
  whileHover: { x: 8 },
  whileTap: { x: 4 },
  transition: LINK_SPRING,
} as const;

/**
 * CTA button motion
 */
export const ctaMotion = {
  whileHover: { y: -2 },
  whileTap: { scale: 0.96 },
  transition: LINK_SPRING,
} as const;

/**
 * Chart container motion
 */
export const chartMotion = {
  initial: { y: 0, scale: 1 },
  animate: { y: 0, scale: 1 },
  whileHover: { y: -4, scale: 1.01 },
  whileTap: { scale: 0.99 },
  transition: CARD_SPRING,
} as const;

/**
 * Interpretation card motion
 */
export const interpretationCardMotion = {
  initial: { y: 0 },
  animate: { y: 0 },
  whileHover: { y: -4 },
  whileTap: { scale: 0.99 },
  transition: CARD_SPRING,
} as const;

/**
 * Touch-only tap scale (for mobile)
 */
export const touchTapMotion = {
  whileTap: { scale: 0.98 },
  transition: SCALE_SPRING,
} as const;

/**
 * Arrow slide motion (e.g., CTA arrows)
 */
export const arrowSlideMotion = {
  whileHover: { x: 6 },
  transition: LINK_SPRING,
} as const;

// =============================================================================
// VARIANT GENERATORS
// =============================================================================

/**
 * Generate scale variants for an element
 */
export function scaleVariants(
  hoverScale = 1.02,
  tapScale = 0.98,
  activeScale = 1.05
): Variants {
  return {
    initial: { scale: 1 },
    hover: { scale: hoverScale },
    tap: { scale: tapScale },
    active: { scale: activeScale },
  };
}

/**
 * Generate lift variants for an element
 */
export function liftVariants(
  hoverY = -4,
  tapScale = 0.98
): Variants {
  return {
    initial: { y: 0, scale: 1 },
    hover: { y: hoverY, scale: 1 },
    tap: { scale: tapScale },
  };
}

// =============================================================================
// UTILITIES
// =============================================================================

/**
 * Disable motion for touch devices (returns empty object)
 * Use in conjunction with media queries
 */
export const noMotion = {
  whileHover: {},
  whileTap: {},
} as const;

/**
 * Create responsive motion props that disable hover on touch
 */
export function responsiveMotion<T extends object>(
  desktopMotion: T,
  _isTouchDevice = false
): T | typeof noMotion {
  // Note: Actual touch detection should happen in component
  // This is a placeholder for the pattern
  return desktopMotion;
}
