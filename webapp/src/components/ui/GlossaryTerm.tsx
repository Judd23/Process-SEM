import { useState, useRef, useEffect } from 'react';
import styles from './GlossaryTerm.module.css';

interface GlossaryTermProps {
  term: string;
  definition: string;
  children: React.ReactNode;
}

export default function GlossaryTerm({ term, definition, children }: GlossaryTermProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [position, setPosition] = useState<'top' | 'bottom'>('bottom');
  const termRef = useRef<HTMLSpanElement>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen && termRef.current && tooltipRef.current) {
      const termRect = termRef.current.getBoundingClientRect();
      const tooltipHeight = tooltipRef.current.offsetHeight;
      const spaceBelow = window.innerHeight - termRect.bottom;
      const spaceAbove = termRect.top;

      // Show tooltip above if not enough space below
      if (spaceBelow < tooltipHeight + 20 && spaceAbove > tooltipHeight + 20) {
        setPosition('top');
      } else {
        setPosition('bottom');
      }
    }
  }, [isOpen]);

  return (
    <span className={styles.container}>
      <span
        ref={termRef}
        className={styles.term}
        onMouseEnter={() => setIsOpen(true)}
        onMouseLeave={() => setIsOpen(false)}
        onFocus={() => setIsOpen(true)}
        onBlur={() => setIsOpen(false)}
        tabIndex={0}
        role="button"
        aria-label={`Definition: ${definition}`}
      >
        {children}
        <span className={styles.indicator} aria-hidden="true">?</span>
      </span>
      {isOpen && (
        <div
          ref={tooltipRef}
          className={`${styles.tooltip} ${styles[position]}`}
          role="tooltip"
        >
          <div className={styles.tooltipTerm}>{term}</div>
          <div className={styles.tooltipDefinition}>{definition}</div>
        </div>
      )}
    </span>
  );
}
