import { Outlet, useLocation } from 'react-router-dom';
import { AnimatePresence } from 'framer-motion';
import Header from './Header';
import Footer from './Footer';
import BackToTop from '../ui/BackToTop';
import MobileNav from './MobileNav';
import PageTransition from './PageTransition';
import styles from './Layout.module.css';

export default function Layout() {
  const location = useLocation();

  return (
    <div className={styles.layout}>
      <a href="#main-content" className={styles.skipLink}>
        Skip to main content
      </a>
      <div className={styles.background}>
        <div className={styles.gradient} />
      </div>
      <Header />
      <main id="main-content" className={styles.main}>
        <AnimatePresence mode="wait" initial={false}>
          <PageTransition key={location.pathname}>
            <Outlet />
          </PageTransition>
        </AnimatePresence>
      </main>
      <BackToTop />
      <MobileNav />
      <Footer />
    </div>
  );
}
