import styles from './GlossaryTerm.module.css';

interface GlossaryTermProps {
  term: string;
  definition: string;
  children: React.ReactNode;
}

/**
 * Editorial-style glossary term.
 * Renders the term with subtle emphasis. Definition available via title attribute.
 * No tooltips, no "?" buttons—just clean prose.
 */
export default function GlossaryTerm({
  term,
  definition,
  children,
}: GlossaryTermProps) {
  return (
    <span
      className={styles.term}
      title={`${term}: ${definition}`}
    >
      {children}
    </span>
  );
}
