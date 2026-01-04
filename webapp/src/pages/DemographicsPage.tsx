import { useResearch } from '../context/ResearchContext';
import GroupComparison from '../components/charts/GroupComparison';
import styles from './DemographicsPage.module.css';

const groupingOptions = [
  { value: 'race', label: 'Race/Ethnicity', description: 'Compare across Hispanic/Latino, White, Asian, Black/African American, and Other groups' },
  { value: 'firstgen', label: 'First-Generation', description: 'Compare first-generation college students vs. students with college-educated parents' },
  { value: 'pell', label: 'Financial Need', description: 'Compare students receiving Pell grants (lower income) vs. those who don\'t' },
  { value: 'sex', label: 'Gender', description: 'Compare female vs. male students' },
  { value: 'living', label: 'Living Situation', description: 'Compare students living with family, on-campus, or off-campus' },
] as const;

export default function DemographicsPage() {
  const { groupingVariable, setGroupingVariable } = useResearch();

  return (
    <div className={styles.page}>
      <div className="container">
        <header className={styles.header}>
          <h1>Do Effects Differ for Different Students?</h1>
          <p className="lead">
            An important question: Do transfer credits affect all students the same way?
            Here you can compare whether stress and engagement patterns differ across
            student backgrounds.
          </p>
        </header>

        <section className={styles.controls}>
          <label className={styles.selectLabel}>Compare students by:</label>
          <div className={styles.groupButtons}>
            {groupingOptions.map((option) => (
              <button
                key={option.value}
                className={`${styles.groupButton} ${groupingVariable === option.value ? styles.active : ''}`}
                onClick={() => setGroupingVariable(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
          <p className={styles.groupDescription}>
            {groupingOptions.find((o) => o.value === groupingVariable)?.description}
          </p>
        </section>

        <section className={styles.charts}>
          <div className={styles.chartContainer}>
            <h2>Effect on Stress by {groupingOptions.find((o) => o.value === groupingVariable)?.label}</h2>
            <p className={styles.chartDescription}>
              Does earning transfer credits lead to different stress levels across student groups?
            </p>
            <GroupComparison grouping={groupingVariable} pathway="a1" />
          </div>

          <div className={styles.chartContainer}>
            <h2>Effect on Engagement by {groupingOptions.find((o) => o.value === groupingVariable)?.label}</h2>
            <p className={styles.chartDescription}>
              Does earning transfer credits change campus engagement differently across groups?
            </p>
            <GroupComparison grouping={groupingVariable} pathway="a2" />
          </div>
        </section>

        <section className={styles.interpretation}>
          <h2>Why This Matters for Equity</h2>
          <div className={styles.interpretationGrid}>
            <article className={styles.interpretationCard}>
              <h3>Fair Comparisons</h3>
              <p>
                Before comparing groups, we checked that our survey questions work
                the same way for all students. This ensures we're measuring the
                same things across different backgrounds.
              </p>
            </article>
            <article className={styles.interpretationCard}>
              <h3>Looking for Differences</h3>
              <p>
                If the bars look similar across groups, it means transfer credits
                affect students similarly regardless of background. If they differ,
                some students might need different support.
              </p>
            </article>
            <article className={styles.interpretationCard}>
              <h3>Targeted Support</h3>
              <p>
                If effects are similar for everyone, universal programs may work best.
                If effects differ, colleges might need specialized support for
                specific student populations.
              </p>
            </article>
          </div>
        </section>
      </div>
    </div>
  );
}
