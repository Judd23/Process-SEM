import { TransitionNavLink } from '../transitions';
import { navItems } from './navItems';
import styles from './MobileNav.module.css';

export default function MobileNav() {
  return (
    <nav className={styles.nav} aria-label="Mobile navigation">
      {navItems.map((item) => (
        <TransitionNavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) =>
            `${styles.link} ${isActive ? styles.active : ''}`
          }
          end={item.to === '/home'}
        >
          <span className={styles.label}>{item.shortLabel}</span>
        </TransitionNavLink>
      ))}
    </nav>
  );
}
