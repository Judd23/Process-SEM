import { motion } from 'framer-motion';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';
import styles from './KeyTakeaway.module.css';

interface KeyTakeawayProps {
  children: React.ReactNode;
  /** Unique ID for shared-element morphing across routes */
  layoutId?: string;
  /** Optional emoji or text icon to display instead of default SVG */
  icon?: string;
}

// Clean SVG icon that matches the academic style
function InsightIcon() {
  return (
    <svg 
      className={styles.icon} 
      viewBox="0 0 24 24" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.5" opacity="0.3" />
      <path 
        d="M12 7v6l4 2" 
        stroke="currentColor" 
        strokeWidth="2" 
        strokeLinecap="round" 
        strokeLinejoin="round"
        opacity="0.6"
      />
      <circle cx="12" cy="12" r="3" fill="currentColor" />
    </svg>
  );
}

export default function KeyTakeaway({ children, layoutId, icon }: KeyTakeawayProps) {
  return (
    <motion.aside
      className={styles.takeaway}
      layoutId={layoutId}
      layout={!!layoutId}
      transition={DANCE_SPRING_HEAVY}
    >
      {icon ? <span className={styles.emojiIcon} aria-hidden="true">{icon}</span> : <InsightIcon />}
      <div className={styles.content}>{children}</div>
    </motion.aside>
  );
}
