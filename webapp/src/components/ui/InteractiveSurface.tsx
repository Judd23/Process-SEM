import type {
  ReactNode,
  CSSProperties,
  MouseEventHandler,
  Ref,
  RefObject,
  MouseEvent,
} from "react";
import { motion } from "framer-motion";
import { Link, type LinkProps } from "react-router-dom";
import { DANCE_SPRING_HEAVY } from "../../lib/transitionConfig";
import { usePageTransition } from "../../lib/hooks";

// Create motion-compatible Link
const MotionLink = motion.create(Link);

type SupportedElement =
  | "div"
  | "article"
  | "section"
  | "button"
  | "a"
  | "span"
  | "link"
  | "aside";

interface InteractiveSurfaceProps {
  as?: SupportedElement;
  to?: LinkProps["to"];
  hoverLift?: number;
  hoverScale?: number;
  tapScale?: number;
  children?: ReactNode;
  className?: string;
  style?: CSSProperties;
  onClick?: MouseEventHandler;
  "aria-label"?: string;
  "aria-pressed"?: boolean;
  "aria-expanded"?: boolean;
  "aria-controls"?: string;
  role?: string;
  type?: "button" | "submit" | "reset";
  id?: string;
  title?: string;
  ref?: Ref<HTMLElement> | RefObject<HTMLElement | null>;
}

/**
 * InteractiveSurface
 * Framer Motion controls transform using a heavy spring preset.
 * CSS should handle border/shadow/sheen only (no transform rules).
 */
export function InteractiveSurface({
  as = "div",
  to,
  className,
  children,
  style,
  hoverLift = 8,
  hoverScale = 1.035,
  tapScale = 0.98,
  onClick,
  "aria-label": ariaLabel,
  "aria-pressed": ariaPressed,
  "aria-expanded": ariaExpanded,
  "aria-controls": ariaControls,
  role,
  type,
  id,
  title,
  ref,
}: InteractiveSurfaceProps) {
  const { navigate } = usePageTransition();

  const hoverProps = {
    y: -hoverLift,
    scale: hoverScale,
  };

  const tapProps = {
    y: -(hoverLift * 0.5),
    scale: tapScale,
  };

  const commonProps = {
    className,
    style,
    whileHover: hoverProps,
    whileTap: tapProps,
    transition: DANCE_SPRING_HEAVY,
    onClick,
    "aria-label": ariaLabel,
    role,
    id,
    title,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    ref: ref as any, // Safe: ref forwarding for polymorphic component
  };

  // Handle Link special case with page transition
  if (as === "link" && to) {
    const handleLinkClick = (e: MouseEvent<HTMLAnchorElement>) => {
      e.preventDefault();
      onClick?.(e);
      const path = typeof to === "string" ? to : to.pathname ?? "";
      if (path) void navigate(path);
    };

    return (
      <MotionLink to={to} {...commonProps} onClick={handleLinkClick}>
        {children}
      </MotionLink>
    );
  }

  if (as === "button") {
    return (
      <motion.button
        type={type || "button"}
        aria-pressed={ariaPressed}
        aria-expanded={ariaExpanded}
        aria-controls={ariaControls}
        {...commonProps}
      >
        {children}
      </motion.button>
    );
  }

  if (as === "a") {
    return <motion.a {...commonProps}>{children}</motion.a>;
  }

  if (as === "article") {
    return <motion.article {...commonProps}>{children}</motion.article>;
  }

  if (as === "section") {
    return <motion.section {...commonProps}>{children}</motion.section>;
  }

  if (as === "span") {
    return <motion.span {...commonProps}>{children}</motion.span>;
  }

  if (as === "aside") {
    return <motion.aside {...commonProps}>{children}</motion.aside>;
  }

  // Default: div
  return <motion.div {...commonProps}>{children}</motion.div>;
}
