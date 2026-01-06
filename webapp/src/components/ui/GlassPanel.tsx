import { forwardRef } from 'react';
import type { CSSProperties, ReactNode } from 'react';
import styles from './GlassPanel.module.css';

/**
 * Glass variant inspired by Apple's Liquid Glass design system
 * - regular: Blurs and adjusts luminosity for text legibility (default)
 * - clear: Highly translucent, ideal for media/rich backgrounds
 */
export type GlassVariant = 'regular' | 'clear';

/**
 * Material thickness (Apple HIG terminology)
 * - ultraThin: Maximum translucency, minimal blur
 * - thin: Light blur, high translucency  
 * - regular: Balanced (default)
 * - thick: More opacity, stronger blur
 */
export type GlassThickness = 'ultraThin' | 'thin' | 'regular' | 'thick';

/**
 * Tint color presets
 */
export type GlassTint = 
  | 'neutral'    // Adapts to light/dark mode
  | 'navy'       // Navy blue tint
  | 'accent'     // Theme accent color
  | 'success'    // Green tint
  | 'warning'    // Amber tint
  | 'error'      // Red tint
  | 'custom';    // Use customColor prop

export interface GlassPanelProps {
  children: ReactNode;
  /** Glass variant: regular (legible) or clear (translucent) */
  variant?: GlassVariant;
  /** Material thickness */
  thickness?: GlassThickness;
  /** Tint color preset */
  tint?: GlassTint;
  /** Custom tint color (use with tint="custom") - any CSS color */
  customColor?: string;
  /** Border radius in pixels */
  radius?: number;
  /** Padding size */
  padding?: 'none' | 'sm' | 'md' | 'lg' | 'xl';
  /** Show top highlight (light edge reflection) */
  highlight?: boolean;
  /** Show subtle inner glow */
  glow?: boolean;
  /** Double-layered glass for depth effect */
  doubleLayer?: boolean;
  /** Additional CSS class */
  className?: string;
  /** Inline styles */
  style?: CSSProperties;
  /** Click handler (makes panel interactive) */
  onClick?: () => void;
  /** Accessibility label */
  'aria-label'?: string;
}

/**
 * GlassPanel - Apple-inspired Liquid Glass component
 * 
 * Creates panels with frosted glass aesthetics:
 * - Adaptive backdrop blur (responds to content behind)
 * - Luminosity adjustment for legibility
 * - Light edge highlights simulating glass refraction
 * - Vibrancy-aware tinting
 * 
 * Based on Apple's Human Interface Guidelines for Materials:
 * https://developer.apple.com/design/human-interface-guidelines/materials
 * 
 * @example
 * // Standard glass panel
 * <GlassPanel>Content</GlassPanel>
 * 
 * @example
 * // Clear variant for media backgrounds
 * <GlassPanel variant="clear" thickness="ultraThin">
 *   <img src="..." />
 * </GlassPanel>
 * 
 * @example
 * // Navy tinted thick panel
 * <GlassPanel tint="navy" thickness="thick" padding="lg">
 *   <h2>Title</h2>
 * </GlassPanel>
 * 
 * @example
 * // Custom purple tint
 * <GlassPanel tint="custom" customColor="#8b5cf6">Content</GlassPanel>
 */
const GlassPanel = forwardRef<HTMLDivElement, GlassPanelProps>(
  (
    {
      children,
      variant = 'regular',
      thickness = 'regular',
      tint = 'neutral',
      customColor,
      radius = 16,
      padding = 'md',
      highlight = true,
      glow = false,
      doubleLayer = false,
      className = '',
      style,
      onClick,
      'aria-label': ariaLabel,
    },
    ref
  ) => {
    // Build CSS custom properties
    const cssVars: CSSProperties & Record<string, string | number> = {
      '--glass-radius': `${radius}px`,
      ...(style ?? {}),
    };

    // Add custom color if provided
    if (tint === 'custom' && customColor) {
      cssVars['--glass-custom-color'] = customColor;
    }

    const classNames = [
      styles.glassPanel,
      styles[`variant-${variant}`],
      styles[`thickness-${thickness}`],
      styles[`tint-${tint}`],
      styles[`padding-${padding}`],
      highlight && styles.withHighlight,
      glow && styles.withGlow,
      doubleLayer && styles.doubleLayer,
      onClick && styles.interactive,
      className,
    ]
      .filter(Boolean)
      .join(' ');

    return (
      <div
        ref={ref}
        className={classNames}
        style={cssVars}
        onClick={onClick}
        role={onClick ? 'button' : undefined}
        tabIndex={onClick ? 0 : undefined}
        aria-label={ariaLabel}
        onKeyDown={
          onClick
            ? (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  onClick();
                }
              }
            : undefined
        }
      >
        {doubleLayer && <div className={styles.innerGlass} aria-hidden="true" />}
        {children}
      </div>
    );
  }
);

GlassPanel.displayName = 'GlassPanel';

export default GlassPanel;
