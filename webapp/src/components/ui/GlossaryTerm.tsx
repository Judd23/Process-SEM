import { useState, useRef } from "react";
import styles from "./GlossaryTerm.module.css";

interface GlossaryTermProps {
  term: string;
  definition: string;
  children: React.ReactNode;
}

/**
 * Editorial-style glossary term with styled tooltip.
 * Shows definition on hover/focus with smooth animation.
 */
export default function GlossaryTerm({
  term,
  definition,
  children,
}: GlossaryTermProps) {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState<"above" | "below">("above");
  const termRef = useRef<HTMLSpanElement>(null);
  const tooltipRef = useRef<HTMLSpanElement>(null);

  const showTooltip = () => {
    if (termRef.current) {
      const rect = termRef.current.getBoundingClientRect();
      const spaceAbove = rect.top;
      const spaceBelow = window.innerHeight - rect.bottom;
      setPosition(
        spaceAbove > 100 || spaceAbove > spaceBelow ? "above" : "below"
      );
    }
    setIsVisible(true);
  };
  const hideTooltip = () => setIsVisible(false);

  return (
    <span
      ref={termRef}
      className={styles.term}
      onMouseEnter={showTooltip}
      onMouseLeave={hideTooltip}
      onFocus={showTooltip}
      onBlur={hideTooltip}
      tabIndex={0}
      role="term"
      aria-describedby={isVisible ? `tooltip-${term}` : undefined}
    >
      {children}
      <span
        ref={tooltipRef}
        id={`tooltip-${term}`}
        className={`${styles.tooltip} ${isVisible ? styles.visible : ""} ${
          styles[position]
        }`}
        role="tooltip"
        aria-hidden={!isVisible}
      >
        <strong className={styles.tooltipTerm}>{term}</strong>
        <span className={styles.tooltipDefinition}>{definition}</span>
      </span>
    </span>
  );
}
