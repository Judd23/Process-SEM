import { NavLink } from 'react-router-dom';
import ThemeToggle from '../ui/ThemeToggle';
import styles from './Header.module.css';

const navItems = [
  { to: '/home', label: 'Home' },
  { to: '/dose', label: 'Credit Levels' },
  { to: '/demographics', label: 'Student Groups' },
  { to: '/pathway', label: 'How It Works' },
  { to: '/methods', label: 'About the Study' },
];

export default function Header() {
  return (
    <header className={styles.header}>
      <div className={styles.container}>
        <div className={styles.brand}>
          <h1 className={styles.title}>Dual Credit & Developmental Adjustment</h1>
          <span className={styles.subtitle}>Psychosocial Effects Among California's Equity-Impacted Students</span>
        </div>
        <nav className={styles.nav}>
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `${styles.navLink} ${isActive ? styles.active : ''}`
              }
              end={item.to === '/home'}
            >
              {item.label}
            </NavLink>
          ))}
          <ThemeToggle />
        </nav>
      </div>
    </header>
  );
}
