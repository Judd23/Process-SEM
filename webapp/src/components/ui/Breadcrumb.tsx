import { useLocation } from 'react-router-dom';
import { navItems } from '../../app/layout/navItems';
import { TransitionNavLink } from '../../features/transitions';
import styles from './Breadcrumb.module.css';
interface BreadcrumbProps {
  className?: string;
}

export default function Breadcrumb({ className = '' }: BreadcrumbProps) {
  const location = useLocation();
  const currentPath = location.pathname;

  // Find the current nav item
  const currentNavItem = navItems.find(item => item.to === currentPath);

  // Don't show breadcrumb on home page
  if (currentPath === '/home' || currentPath === '/') {
    return null;
  }

  return (
    <nav className={`${styles.breadcrumb} ${className}`} aria-label="Breadcrumb">
      <ol className={styles.list}>
        <li className={styles.item}>
          <TransitionNavLink to="/home" className={styles.link}>
            <svg className={styles.homeIcon} viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
            </svg>
            <span className={styles.srOnly}>Home</span>
          </TransitionNavLink>
        </li>
        <li className={styles.separator} aria-hidden="true">
          <svg viewBox="0 0 6 20" fill="currentColor">
            <path d="M4.878 4.34l-3.5 10.2c-.1.3.1.46.4.36l3.5-10.2c.1-.3-.1-.46-.4-.36z" />
          </svg>
        </li>
        <li className={styles.item}>
          <span className={styles.current} aria-current="page">
            {currentNavItem?.label || 'Page'}
          </span>
        </li>
      </ol>
    </nav>
  );
}
