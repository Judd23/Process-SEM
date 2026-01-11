import { InteractiveSurface } from './InteractiveSurface';
import styles from './ThemeToggle.module.css';

// Dark mode only - toggle disabled but component kept for UI consistency
export default function ThemeToggle() {
  return (
    <InteractiveSurface
      as="button"
      className={`${styles.toggle} interactiveSurface`}
      aria-label="Theme: Dark mode"
      title="Dark ☾"
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
      </svg>
      <span className={styles.label}>Dark ☾</span>
    </InteractiveSurface>
  );
}
