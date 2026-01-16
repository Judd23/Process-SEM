import styles from "./ProgressRing.module.css";

interface ProgressRingProps {
  label: string;
  value: number;
  displayValue?: string;
  format?: (v: number) => string;
  invert?: boolean;
  color?: string;
  size?: number;
  strokeWidth?: number;
}

export default function ProgressRing({
  label,
  value,
  displayValue,
  format,
  invert = false,
  color = "var(--color-accent)",
  size = 96,
  strokeWidth = 8,
}: ProgressRingProps) {
  // For inverted metrics (RMSEA, SRMR), lower is better, so invert the visual fill
  const normalized = invert
    ? Math.min(Math.max(1 - value, 0), 1)
    : Math.min(Math.max(value, 0), 1);
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference * (1 - normalized);

  const ariaValue = Math.round(normalized * 100);

  // Use format function if provided, otherwise use displayValue
  const formattedValue = format ? format(value) : displayValue;

  return (
    <div
      className={styles.ring}
      role="progressbar"
      aria-valuenow={ariaValue}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={label}
    >
      <svg width={size} height={size} className={styles.svg} aria-hidden="true">
        <circle
          className={styles.track}
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
        />
        <circle
          className={styles.progress}
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
          style={{
            stroke: color,
            strokeDasharray: circumference,
            strokeDashoffset: dashOffset,
          }}
        />
      </svg>
      <div className={styles.value}>{formattedValue}</div>
      <div className={styles.label}>{label}</div>
    </div>
  );
}
