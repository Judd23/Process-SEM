import styles from './Slider.module.css';

interface SliderProps {
  value: number;
  onChange: (value: number) => void;
  min: number;
  max: number;
  step?: number;
  label: string;
  id: string;
  formatValue?: (value: number) => string;
  showThreshold?: number;
  thresholdLabel?: string;
  tickMarks?: number[]; // Array of values where tick marks should appear
}

export default function Slider({
  value,
  onChange,
  min,
  max,
  step = 1,
  label,
  id,
  formatValue = (v) => String(v),
  showThreshold,
  thresholdLabel = 'Threshold',
  tickMarks = [],
}: SliderProps) {
  const percentage = ((value - min) / (max - min)) * 100;
  const thresholdPercentage = showThreshold !== undefined
    ? ((showThreshold - min) / (max - min)) * 100
    : null;

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <label htmlFor={id} className={styles.label}>{label}</label>
        <span className={styles.value}>{formatValue(value)}</span>
      </div>
      <div className={styles.sliderWrapper}>
        <input
          type="range"
          id={id}
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className={styles.slider}
          style={{ '--percentage': `${percentage}%` } as React.CSSProperties}
        />
        {thresholdPercentage !== null && (
          <div
            className={styles.threshold}
            style={{ left: `${thresholdPercentage}%` }}
          >
            <span className={styles.thresholdLine} />
            <span className={styles.thresholdLabel}>{thresholdLabel}</span>
          </div>
        )}
        {tickMarks.length > 0 && (
          <div className={styles.tickMarks}>
            {tickMarks.map((tick) => {
              const tickPercentage = ((tick - min) / (max - min)) * 100;
              return (
                <div
                  key={tick}
                  className={styles.tick}
                  style={{ left: `${tickPercentage}%` }}
                >
                  <span className={styles.tickMark} />
                  <span className={styles.tickLabel}>{formatValue(tick)}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>
      <div className={styles.range}>
        <span>{formatValue(min)}</span>
        <span>{formatValue(max)}</span>
      </div>
    </div>
  );
}
