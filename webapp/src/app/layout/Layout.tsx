import { Outlet } from 'react-router-dom';
import Header from './Header';
import Footer from './Footer';
import BackToTop from '../../components/ui/BackToTop';
import MobileNav from './MobileNav';
import { TransitionOrchestrator } from '../../features/transitions';
import { useScrollRestoration } from '../../lib/hooks/useScrollRestoration';
import { useModelData } from '../contexts/ModelDataContext';
import styles from './Layout.module.css';

export default function Layout() {
  const { handleExitComplete } = useScrollRestoration();
  const { validation } = useModelData();
  const showDataInvalidBanner = import.meta.env.DEV && !validation.isValid;

  return (
    <div className={styles.layout}>
      {showDataInvalidBanner && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            zIndex: 9999,
            padding: '8px 12px',
            fontSize: 12,
            background: 'rgba(180, 30, 30, 0.9)',
            color: '#fff',
            borderBottom: '1px solid rgba(255, 255, 255, 0.2)',
            fontFamily: 'ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif',
          }}
          role="status"
          aria-live="polite"
        >
          Data invalid (dev): {validation.errors[0] ?? 'Unknown error'}
        </div>
      )}
      <a href="#main-content" className={styles.skipLink}>
        Skip to main content
      </a>
      <div className={styles.background}>
        <div className={styles.gradient} />
      </div>
      <Header />
      <main
        id="main-content"
        className={styles.main}
      >
        <TransitionOrchestrator
          scrollOnTransition={false}
          onExitComplete={handleExitComplete}
        >
          <Outlet />
        </TransitionOrchestrator>
      </main>
      <BackToTop />
      <MobileNav />
      <Footer />
    </div>
  );
}
