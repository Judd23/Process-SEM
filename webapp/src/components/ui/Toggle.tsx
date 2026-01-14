import { motion } from "framer-motion";
import {
  DANCE_SPRING_HEAVY,
  HOVER_SUBTLE,
  TAP_SUBTLE,
} from "../../lib/transitionConfig";
import styles from "./Toggle.module.css";

interface ToggleProps {
  checked: boolean;
  onChange: () => void;
  label: string;
  id: string;
}

export default function Toggle({ checked, onChange, label, id }: ToggleProps) {
  return (
    <motion.label
      className={`${styles.toggle} interactiveSurface`}
      htmlFor={id}
      whileHover={HOVER_SUBTLE}
      whileTap={TAP_SUBTLE}
      transition={DANCE_SPRING_HEAVY}
    >
      <input
        type="checkbox"
        id={id}
        checked={checked}
        onChange={onChange}
        className={styles.input}
      />
      <span className={styles.slider} />
      <span className={styles.label}>{label}</span>
    </motion.label>
  );
}
