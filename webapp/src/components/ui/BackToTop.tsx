import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';
import styles from './BackToTop.module.css';

export default function BackToTop() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsVisible(window.scrollY > 500);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();

    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleClick = () => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    window.scrollTo({ top: 0, behavior: prefersReducedMotion ? 'auto' : 'smooth' });
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.button
          type="button"
          className={`${styles.button} ${styles.visible}`}
          onClick={handleClick}
          aria-label="Back to top"
          initial={{ opacity: 0, scale: 0.8, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.8, y: 20 }}
          whileHover={{ scale: 1.1, y: -2 }}
          whileTap={{ scale: 0.95 }}
          transition={DANCE_SPRING_HEAVY}
        >
          <span className={styles.arrow} aria-hidden="true">↑</span>
          <span className={styles.label}>Top</span>
        </motion.button>
      )}
    </AnimatePresence>
  );
}
