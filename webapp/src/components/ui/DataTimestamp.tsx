import dataMetadata from '../../data/dataMetadata.json';
import styles from './DataTimestamp.module.css';

interface DataTimestampProps {
  className?: string;
  note?: string;
}

export default function DataTimestamp({ className, note = 'Simulated data' }: DataTimestampProps) {
  const timestamp = dataMetadata.generatedAtShort || 'Unknown';

  return (
    <div className={`${styles.timestamp} ${className || ''}`}>
      <span className={styles.label}>Data:</span>
      <time dateTime={dataMetadata.generatedAt} className={styles.time}>
        {timestamp}
      </time>
      <span className={styles.note}>{note}</span>
    </div>
  );
}
