import styles from './Toggle.module.css';

interface ToggleProps {
  checked: boolean;
  onChange: () => void;
  label: string;
  id: string;
}

export default function Toggle({ checked, onChange, label, id }: ToggleProps) {
  return (
    <label className={styles.toggle} htmlFor={id}>
      <input
        type="checkbox"
        id={id}
        checked={checked}
        onChange={onChange}
        className={styles.input}
      />
      <span className={styles.slider} />
      <span className={styles.label}>{label}</span>
    </label>
  );
}
