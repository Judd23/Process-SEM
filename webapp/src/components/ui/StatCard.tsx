import { useEffect, useState, useRef } from 'react';
import styles from './StatCard.module.css';

interface StatCardProps {
  label: string | React.ReactNode;
  value: string | number;
  subtext?: string;
  color?: 'default' | 'positive' | 'negative' | 'accent';
  size?: 'small' | 'medium' | 'large';
  animate?: boolean;
}

export default function StatCard({
  label,
  value,
  subtext,
  color = 'default',
  size = 'medium',
  animate = true,
}: StatCardProps) {
  const [displayValue, setDisplayValue] = useState<string | number>(value);
  const cardRef = useRef<HTMLDivElement>(null);
  const hasAnimated = useRef(false);

  useEffect(() => {
    // Only animate numeric values
    if (!animate || typeof value !== 'number' || hasAnimated.current) {
      setDisplayValue(value);
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !hasAnimated.current) {
          hasAnimated.current = true;
          const duration = 1200; // ms
          const start = performance.now();
          const startValue = 0;
          const endValue = value;

          const animate = (currentTime: number) => {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);

            // Ease-out-cubic for smooth deceleration
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = startValue + (endValue - startValue) * eased;

            setDisplayValue(Math.round(current));

            if (progress < 1) {
              requestAnimationFrame(animate);
            } else {
              setDisplayValue(endValue);
            }
          };

          requestAnimationFrame(animate);
        }
      },
      { threshold: 0.3 }
    );

    if (cardRef.current) {
      observer.observe(cardRef.current);
    }

    return () => observer.disconnect();
  }, [value, animate]);

  return (
    <div ref={cardRef} className={`${styles.card} ${styles[size]}`}>
      <div className={styles.label}>{label}</div>
      <div className={`${styles.value} ${styles[color]}`}>{displayValue}</div>
      {subtext && <div className={styles.subtext}>{subtext}</div>}
    </div>
  );
}
