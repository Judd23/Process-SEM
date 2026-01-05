import styles from './ResearcherPage.module.css';

export default function ResearcherPage() {
  return (
    <div className={styles.page}>
      {/* Full-width Hero with Photo */}
      <section className={styles.hero}>
        <div className={styles.heroImage}>
          <img 
            src={`${import.meta.env.BASE_URL}researcher.jpg`}
            alt="Judd Johnson"
          />
          <div className={styles.heroOverlay}></div>
        </div>
        <div className={styles.heroContent}>
          <div className={styles.heroText}>
            <span className={styles.tagline}>The Researcher</span>
            <h1>Judd Johnson</h1>
            <p className={styles.credentials}>M.F.A., Ed.D.-(May '26)</p>
            <p className={styles.role}>Higher Education Leadership & Policy Scholar</p>
          </div>
        </div>
        <div className={styles.scrollIndicator}>
          <span>Scroll</span>
          <div className={styles.scrollLine}></div>
        </div>
      </section>

      {/* Main Content */}
      <main className={styles.main}>
        {/* Quote Section - Full Width */}
        <section className={styles.quoteSection}>
          <blockquote>
            <p>
              "I believe every student deserves to <em>thrive</em> in college, not just survive."
            </p>
          </blockquote>
        </section>

        {/* Story Section */}
        <section className={styles.storySection}>
          <div className={styles.storyGrid}>
            <div className={styles.storyLabel}>
              <span>01</span>
              <h2>Background</h2>
            </div>
            <div className={styles.storyContent}>
              <p>
                Years of working directly with first-generation and low-income students 
                sparked my fascination with a deceptively simple question: 
              </p>
              <p className={styles.highlight}>
                What makes some students thrive while others struggle?
              </p>
              <p>
                This question became the foundation of my research—exploring not just 
                academic preparation, but the psychological and social dimensions of 
                the college transition.
              </p>
            </div>
          </div>
        </section>

        {/* Research Interests */}
        <section className={styles.interestsSection}>
          <div className={styles.interestsHeader}>
            <span>02</span>
            <h2>Research Focus</h2>
          </div>
          <div className={styles.interestsGrid}>
            <div className={styles.interestItem}>
              <div className={styles.interestNumber}>01</div>
              <h3>Student Success</h3>
              <p>Developmental adjustment, belonging, and first-year transitions</p>
            </div>
            <div className={styles.interestItem}>
              <div className={styles.interestNumber}>02</div>
              <h3>Accelerated Pathways</h3>
              <p>Dual enrollment, early college, and credit accumulation effects</p>
            </div>
            <div className={styles.interestItem}>
              <div className={styles.interestNumber}>03</div>
              <h3>Educational Equity</h3>
              <p>Supporting historically underrepresented students in higher education</p>
            </div>
            <div className={styles.interestItem}>
              <div className={styles.interestNumber}>04</div>
              <h3>Quantitative Methods</h3>
              <p>Structural equation modeling, causal inference, and process analysis</p>
            </div>
          </div>
        </section>

        {/* Contact Section */}
        <section className={styles.contactSection}>
          <div className={styles.contactInner}>
            <div className={styles.contactLabel}>
              <span>03</span>
              <h2>Connect</h2>
            </div>
            <div className={styles.contactContent}>
              <p>
                Interested in discussing research, collaboration, or opportunities 
                in higher education research and policy?
              </p>
              <a href="mailto:jjohnson4039@SDSU.edu" className={styles.emailLink}>
                <span className={styles.emailText}>jjohnson4039@SDSU.edu</span>
                <span className={styles.emailArrow}>→</span>
              </a>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
