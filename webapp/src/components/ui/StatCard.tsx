import styles from './StatCard.module.css';

interface StatCardProps {
  label: string;
  value: string | number;
  subtext?: string;
  color?: 'default' | 'positive' | 'negative' | 'accent';
  size?: 'small' | 'medium' | 'large';
}

export default function StatCard({
  label,
  value,
  subtext,
  color = 'default',
  size = 'medium',
}: StatCardProps) {
  return (
    <div className={`${styles.card} ${styles[size]}`}>
      <div className={styles.label}>{label}</div>
      <div className={`${styles.value} ${styles[color]}`}>{value}</div>
      {subtext && <div className={styles.subtext}>{subtext}</div>}
    </div>
  );
}
