import { useState } from 'react';
import { useResearch } from '../context/ResearchContext';
import GroupComparison from '../components/charts/GroupComparison';
import Toggle from '../components/ui/Toggle';
import { useScrollReveal, useStaggeredReveal } from '../hooks/useScrollReveal';
import fastComparison from '../data/fastComparison.json';
import sampleDescriptives from '../data/sampleDescriptives.json';
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
  const [showComparison, setShowComparison] = useState(false);
  const demographics = sampleDescriptives.demographics;

  // Scroll reveal refs
  const headerRef = useScrollReveal<HTMLElement>({ threshold: 0.2 });
  const demographicsRef = useStaggeredReveal<HTMLElement>();
  const chartsRef = useStaggeredReveal<HTMLElement>();
  const interpretRef = useStaggeredReveal<HTMLElement>();

  return (
    <div className={styles.page}>
      <div className="container">
        <header ref={headerRef} className={`${styles.header} reveal`}>
          <span className={styles.eyebrow}>Equity Framework</span>
          <h1>Do Effects Differ for Different Students?</h1>
          <p className="lead">
            An important question: Do transfer credits affect all students the same way?
            Here you can compare whether stress and engagement patterns differ across
            student backgrounds.
          </p>
        </header>

        {/* Demographics Breakdown with Comparison Toggle */}
        <section ref={demographicsRef} className={`${styles.demographicsBreakdown} stagger-children`}>
          <div className={styles.demographicsHeader}>
            <h2>Sample Demographics</h2>
            <Toggle
              checked={showComparison}
              onChange={() => setShowComparison(!showComparison)}
              label="Compare FASt vs Non-FASt"
              id="demographics-page-comparison-toggle"
            />
          </div>

          <div className={styles.demographicsGrid}>
            {/* Race/Ethnicity Breakdown */}
            <div className={`${styles.demoCard} reveal`}>
              <h3>Race & Ethnicity</h3>
              <div className={styles.demoStats}>
                {Object.entries(demographics.race).map(([group, data]) => (
                  <div key={group} className={styles.demoStat}>
                    {!showComparison ? (
                      <>
                        <div className={styles.demoLabel}>
                          <span>{group}</span>
                          <span>{data.pct}%</span>
                        </div>
                        <div className={styles.demoBar}>
                          <div className={styles.demoBarFill} style={{ width: `${data.pct}%` }} />
                        </div>
                      </>
                    ) : (
                      <div className={styles.demoComparison}>
                        <div className={styles.demoLabel}><span>{group}</span></div>
                        <div className={styles.comparisonRow}>
                          <span className={styles.comparisonLabel}>FASt</span>
                          <div className={styles.demoBar}>
                            <div className={styles.demoBarFill} style={{
                              width: `${(fastComparison.demographics.race as any)[group]?.fast.pct || 0}%`,
                              backgroundColor: 'var(--color-fast)'
                            }} />
                          </div>
                          <span>{(fastComparison.demographics.race as any)[group]?.fast.pct || 0}%</span>
                        </div>
                        <div className={styles.comparisonRow}>
                          <span className={styles.comparisonLabel}>Non-FASt</span>
                          <div className={styles.demoBar}>
                            <div className={styles.demoBarFill} style={{
                              width: `${(fastComparison.demographics.race as any)[group]?.nonfast.pct || 0}%`,
                              backgroundColor: 'var(--color-text-muted)'
                            }} />
                          </div>
                          <span>{(fastComparison.demographics.race as any)[group]?.nonfast.pct || 0}%</span>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* First-Gen & Pell */}
            <div className={`${styles.demoCard} reveal`}>
              <h3>Access & Equity</h3>
              <div className={styles.demoStats}>
                <div className={styles.demoStat}>
                  <div className={styles.demoLabel}>
                    <span>First-Generation</span>
                    <span>{!showComparison ? `${demographics.firstgen.yes.pct}%` : ''}</span>
                  </div>
                  {!showComparison ? (
                    <div className={styles.demoBar}>
                      <div className={styles.demoBarFill} style={{ width: `${demographics.firstgen.yes.pct}%` }} />
                    </div>
                  ) : (
                    <div className={styles.demoComparison}>
                      <div className={styles.comparisonRow}>
                        <span className={styles.comparisonLabel}>FASt</span>
                        <div className={styles.demoBar}>
                          <div className={styles.demoBarFill} style={{
                            width: `${fastComparison.demographics.firstgen.yes.fast.pct}%`,
                            backgroundColor: 'var(--color-fast)'
                          }} />
                        </div>
                        <span>{fastComparison.demographics.firstgen.yes.fast.pct}%</span>
                      </div>
                      <div className={styles.comparisonRow}>
                        <span className={styles.comparisonLabel}>Non-FASt</span>
                        <div className={styles.demoBar}>
                          <div className={styles.demoBarFill} style={{
                            width: `${fastComparison.demographics.firstgen.yes.nonfast.pct}%`,
                            backgroundColor: 'var(--color-text-muted)'
                          }} />
                        </div>
                        <span>{fastComparison.demographics.firstgen.yes.nonfast.pct}%</span>
                      </div>
                    </div>
                  )}
                </div>
                <div className={styles.demoStat}>
                  <div className={styles.demoLabel}>
                    <span>Pell Grant Recipients</span>
                    <span>{!showComparison ? `${demographics.pell.yes.pct}%` : ''}</span>
                  </div>
                  {!showComparison ? (
                    <div className={styles.demoBar}>
                      <div className={styles.demoBarFill} style={{ width: `${demographics.pell.yes.pct}%` }} />
                    </div>
                  ) : (
                    <div className={styles.demoComparison}>
                      <div className={styles.comparisonRow}>
                        <span className={styles.comparisonLabel}>FASt</span>
                        <div className={styles.demoBar}>
                          <div className={styles.demoBarFill} style={{
                            width: `${fastComparison.demographics.pell.yes.fast.pct}%`,
                            backgroundColor: 'var(--color-fast)'
                          }} />
                        </div>
                        <span>{fastComparison.demographics.pell.yes.fast.pct}%</span>
                      </div>
                      <div className={styles.comparisonRow}>
                        <span className={styles.comparisonLabel}>Non-FASt</span>
                        <div className={styles.demoBar}>
                          <div className={styles.demoBarFill} style={{
                            width: `${fastComparison.demographics.pell.yes.nonfast.pct}%`,
                            backgroundColor: 'var(--color-text-muted)'
                          }} />
                        </div>
                        <span>{fastComparison.demographics.pell.yes.nonfast.pct}%</span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </section>

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

        <section ref={chartsRef} className={`${styles.charts} stagger-children`}>
          <div className={`${styles.chartContainer} reveal`}>
            <h2>Effect on Stress by {groupingOptions.find((o) => o.value === groupingVariable)?.label}</h2>
            <p className={styles.chartDescription}>
              Does earning transfer credits lead to different stress levels across equity groups?
            </p>
            <GroupComparison grouping={groupingVariable} pathway="a1" />
          </div>

          <div className={`${styles.chartContainer} reveal`}>
            <h2>Effect on Engagement by {groupingOptions.find((o) => o.value === groupingVariable)?.label}</h2>
            <p className={styles.chartDescription}>
              Does earning transfer credits change campus engagement differently across equity groups?
            </p>
            <GroupComparison grouping={groupingVariable} pathway="a2" />
          </div>
        </section>

        <section ref={interpretRef} className={`${styles.interpretation} stagger-children`}>
          <h2>Why This Matters for Equity</h2>
          <div className={styles.interpretationGrid}>
            <article className={`${styles.interpretationCard} reveal`}>
              <h3>Fair Comparisons</h3>
              <p>
                Before comparing groups, we checked that our survey questions work
                the same way for all students. This ensures we're measuring the
                same things across different backgrounds.
              </p>
            </article>
            <article className={`${styles.interpretationCard} reveal`}>
              <h3>Looking for Differences</h3>
              <p>
                If the bars look similar across groups, it means transfer credits
                affect students similarly regardless of background. If they differ,
                some students might need different support.
              </p>
            </article>
            <article className={`${styles.interpretationCard} reveal`}>
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
