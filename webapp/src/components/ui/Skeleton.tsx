import styles from './Skeleton.module.css';

interface SkeletonProps {
  /** Width - can be number (px) or string (e.g., '100%', '12rem') */
  width?: number | string;
  /** Height - can be number (px) or string */
  height?: number | string;
  /** Border radius variant */
  variant?: 'text' | 'circular' | 'rectangular' | 'rounded';
  /** Additional class name */
  className?: string;
  /** Number of skeleton lines for text variant */
  lines?: number;
}

export default function Skeleton({
  width,
  height,
  variant = 'rectangular',
  className = '',
  lines = 1,
}: SkeletonProps) {
  const style: React.CSSProperties = {
    width: typeof width === 'number' ? `${width}px` : width,
    height: typeof height === 'number' ? `${height}px` : height,
  };

  if (variant === 'text' && lines > 1) {
    return (
      <div className={`${styles.textGroup} ${className}`}>
        {Array.from({ length: lines }).map((_, i) => (
          <span
            key={i}
            className={`${styles.skeleton} ${styles.text}`}
            style={{
              ...style,
              width: i === lines - 1 ? '70%' : width, // Last line shorter
            }}
          />
        ))}
      </div>
    );
  }

  return (
    <span
      className={`${styles.skeleton} ${styles[variant]} ${className}`}
      style={style}
      aria-hidden="true"
    />
  );
}

// Preset skeleton compositions
export function SkeletonCard({ className = '' }: { className?: string }) {
  return (
    <div className={`${styles.card} ${className}`}>
      <Skeleton variant="text" width="40%" height={16} />
      <Skeleton variant="text" width="60%" height={32} />
      <Skeleton variant="text" width="80%" height={14} />
    </div>
  );
}

export function SkeletonChart({ className = '' }: { className?: string }) {
  return (
    <div className={`${styles.chart} ${className}`}>
      <Skeleton variant="rectangular" width="100%" height={200} />
    </div>
  );
}

export function SkeletonStatCard({ className = '' }: { className?: string }) {
  return (
    <div className={`${styles.statCard} ${className}`}>
      <Skeleton variant="text" width="60%" height={14} />
      <Skeleton variant="text" width="40%" height={36} />
      <Skeleton variant="text" width="80%" height={12} />
    </div>
  );
}
