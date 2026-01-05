import { useNavigate } from 'react-router-dom';
import styles from './LandingPage.module.css';

export default function LandingPage() {
  const navigate = useNavigate();

  return (
    <div className={styles.landing}>
      <div className={styles.background}>
        <div className={styles.gradient} />
      </div>
      
      <main className={styles.content}>
        <div className={styles.titleBlock}>
          <h1 className={styles.title}>
            The Psychosocial Effects of Dual Credit Accumulation on Developmental Adjustment Among Equity Impacted Student Populations in California
          </h1>
          <p className={styles.subtitle}>
            A Conditional Process Structural Equation Model Analysis
          </p>
        </div>

        <div className={styles.authorBlock}>
          <p className={styles.by}>by</p>
          <p className={styles.author}>Jay Johnson</p>
          <p className={styles.affiliation}>San Diego State University</p>
          <p className={styles.degree}>Doctoral Candidate</p>
        </div>

        <button 
          className={styles.enterButton}
          onClick={() => navigate('/home')}
        >
          Explore the Findings
        </button>

        <footer className={styles.footer}>
          <p>Ed.D. Dissertation Research · 2026</p>
        </footer>
      </main>
    </div>
  );
}
