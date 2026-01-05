import styles from './KeyTakeaway.module.css';

interface KeyTakeawayProps {
  children: React.ReactNode;
  icon?: string;
}

export default function KeyTakeaway({ children, icon = '💡' }: KeyTakeawayProps) {
  return (
    <aside className={styles.takeaway}>
      <div className={styles.icon}>{icon}</div>
      <div className={styles.content}>{children}</div>
    </aside>
  );
}
