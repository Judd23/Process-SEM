import { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import { useTheme } from '../../app/contexts';
import { getRaceColor, getSignificanceColor } from '../../lib/colorScales';
import DataTimestamp from '../../components/ui/DataTimestamp';
import { groupComparisons } from '../../data/adapters/groupComparisons';
import { sampleDescriptives } from '../../data/adapters/sampleDescriptives';
import type { GroupingJson } from '../../data/types/groupComparisons';
import styles from './GroupComparison.module.css';

// Type for group data structure
interface GroupEffect {
  label: string;
  estimate: number;
  se: number;
  pvalue: number;
  n: number;
}

interface PathwayGroups {
  groups: GroupEffect[];
}

interface GroupingData {
  a1: PathwayGroups;
  a2: PathwayGroups;
}

// Build group data from pipeline JSON + sample descriptives for sample sizes
const buildGroupData = (): Record<string, GroupingData> => {
  const demographics = sampleDescriptives.demographics;
  
  // Sample size lookups
  const sampleSizes: Record<string, Record<string, number>> = {
    race: {
      'Hispanic/Latino': demographics.race['Hispanic/Latino'].n,
      'White': demographics.race['White'].n,
      'Asian': demographics.race['Asian'].n,
      'Black/African American': demographics.race['Black/African American'].n,
      'Other/Multiracial': demographics.race['Other/Multiracial/Unknown'].n,
    },
    firstgen: {
      'First-Gen': demographics.firstgen.yes.n,
      'Continuing-Gen': demographics.firstgen.no.n,
    },
    pell: {
      'Pell Eligible': demographics.pell.yes.n,
      'Not Pell Eligible': demographics.pell.no.n,
    },
    sex: {
      'Women': demographics.sex.women.n,
      'Men': demographics.sex.men.n,
    },
    living: {
      'With Family': 2360,
      'Off-Campus': 1315,
      'On-Campus': 1325,
    },
  };

  // Helper to build pathway groups from JSON
  const buildPathwayGroups = (
    jsonData: GroupingJson,
    sizeKey: string
  ): GroupingData => ({
    a1: {
      groups: jsonData.groups.map(g => ({
        label: g.label,
        estimate: g.effects.a1.estimate,
        se: g.effects.a1.se,
        pvalue: g.effects.a1.pvalue,
        n: sampleSizes[sizeKey]?.[g.label] || 0
      }))
    },
    a2: {
      groups: jsonData.groups.map(g => ({
        label: g.label,
        estimate: g.effects.a2.estimate,
        se: g.effects.a2.se,
        pvalue: g.effects.a2.pvalue,
        n: sampleSizes[sizeKey]?.[g.label] || 0
      }))
    }
  });

  return {
    race: buildPathwayGroups(groupComparisons.byRace, 'race'),
    firstgen: buildPathwayGroups(groupComparisons.byFirstgen, 'firstgen'),
    pell: buildPathwayGroups(groupComparisons.byPell, 'pell'),
    sex: buildPathwayGroups(groupComparisons.bySex, 'sex'),
    living: buildPathwayGroups(groupComparisons.byLiving, 'living'),
  };
};

const groupData = buildGroupData();

interface GroupComparisonProps {
  grouping: 'race' | 'firstgen' | 'pell' | 'sex' | 'living';
  pathway: 'a1' | 'a2';
}

export default function GroupComparison({
  grouping,
  pathway,
}: GroupComparisonProps) {
  const tooltipId = `group-comparison-tooltip-${grouping}-${pathway}`;
  const svgRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const { resolvedTheme } = useTheme();
  const [dimensions, setDimensions] = useState({ width: 600, height: 300 });
  const [tooltip, setTooltip] = useState<{
    x: number;
    y: number;
    label: string;
    estimate: number;
    se: number;
    pvalue: number;
    n: number;
  } | null>(null);

  // Responsive sizing
  useEffect(() => {
    const updateDimensions = () => {
      if (containerRef.current) {
        const containerWidth = containerRef.current.clientWidth;
        // Maintain aspect ratio of 2:1, with min width 300
        const width = Math.max(300, Math.min(containerWidth, 600));
        const height = Math.max(200, width * 0.5);
        setDimensions({ width, height });
      }
    };

    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  }, []);

  useEffect(() => {
    if (!svgRef.current) return;

    const { width, height } = dimensions;
    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove();

    const data = groupData[grouping]?.[pathway]?.groups || [];
    if (data.length === 0) return;

    // Responsive margins
    const isMobile = width < 400;
    const margin = {
      top: 30,
      right: isMobile ? 80 : 120,
      bottom: 40,
      left: isMobile ? 100 : 150
    };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    // Get theme-aware colors
    const chartBg = getComputedStyle(document.documentElement).getPropertyValue('--color-chart-background').trim() || '#ffffff';
    const gridColor = getComputedStyle(document.documentElement).getPropertyValue('--color-chart-grid').trim() || '#e0e0e0';
    const axisColor = getComputedStyle(document.documentElement).getPropertyValue('--color-chart-axis').trim() || '#cccccc';
    const textMutedColor = getComputedStyle(document.documentElement).getPropertyValue('--color-text-muted').trim() || '#666666';

    // Add background for proper dark mode support
    svg.append('rect')
      .attr('width', width)
      .attr('height', height)
      .attr('fill', chartBg)
      .attr('rx', 8);

    const g = svg
      .append('g')
      .attr('transform', `translate(${margin.left}, ${margin.top})`);

    // Scales
    const yScale = d3
      .scaleBand()
      .domain(data.map((d) => d.label))
      .range([0, innerHeight])
      .padding(0.3);

    const xExtent = d3.extent(data.flatMap((d) => [d.estimate - 1.96 * d.se, d.estimate + 1.96 * d.se])) as [number, number];
    const xPadding = (xExtent[1] - xExtent[0]) * 0.2;
    const xScale = d3
      .scaleLinear()
      .domain([Math.min(xExtent[0] - xPadding, -0.15), Math.max(xExtent[1] + xPadding, 0.25)])
      .range([0, innerWidth]);

    // Zero reference line
    g.append('line')
      .attr('x1', xScale(0))
      .attr('x2', xScale(0))
      .attr('y1', 0)
      .attr('y2', innerHeight)
      .attr('stroke', textMutedColor)
      .attr('stroke-width', 1)
      .attr('stroke-dasharray', '4,4');

    // Grid
    g.append('g')
      .call(d3.axisBottom(xScale).tickSize(innerHeight).tickFormat(() => ''))
      .call((g) => g.selectAll('line').attr('stroke', gridColor).attr('stroke-dasharray', '2,2'))
      .call((g) => g.select('.domain').remove());

    // Draw forest plot
    data.forEach((d) => {
      const y = yScale(d.label)! + yScale.bandwidth() / 2;
      const color = grouping === 'race' ? getRaceColor(d.label) : getSignificanceColor(d.pvalue);

      // CI whisker
      g.append('line')
        .attr('x1', xScale(d.estimate - 1.96 * d.se))
        .attr('x2', xScale(d.estimate + 1.96 * d.se))
        .attr('y1', y)
        .attr('y2', y)
        .attr('stroke', color)
        .attr('stroke-width', 2);

      // CI caps
      g.append('line')
        .attr('x1', xScale(d.estimate - 1.96 * d.se))
        .attr('x2', xScale(d.estimate - 1.96 * d.se))
        .attr('y1', y - 6)
        .attr('y2', y + 6)
        .attr('stroke', color)
        .attr('stroke-width', 2);

      g.append('line')
        .attr('x1', xScale(d.estimate + 1.96 * d.se))
        .attr('x2', xScale(d.estimate + 1.96 * d.se))
        .attr('y1', y - 6)
        .attr('y2', y + 6)
        .attr('stroke', color)
        .attr('stroke-width', 2);

      // Point estimate
      const point = g.append('circle')
        .attr('cx', xScale(d.estimate))
        .attr('cy', y)
        .attr('r', 8)
        .attr('fill', color)
        .attr('stroke', 'white')
        .attr('stroke-width', 2)
        .attr('cursor', 'pointer')
        .attr('tabindex', 0)
        .attr('role', 'button')
        .attr(
          'aria-label',
          `${d.label}. Effect ${d.estimate.toFixed(3)}. SE ${d.se.toFixed(3)}. p ${d.pvalue.toFixed(3)}. n ${d.n.toLocaleString()}.`
        )
        .attr('aria-describedby', tooltipId);

      point
        .on('mouseenter', (event) => {
          const rect = containerRef.current?.getBoundingClientRect();
          if (!rect) return;
          setTooltip({
            x: event.clientX - rect.left + 12,
            y: event.clientY - rect.top + 12,
            label: d.label,
            estimate: d.estimate,
            se: d.se,
            pvalue: d.pvalue,
            n: d.n,
          });
        })
        .on('mouseleave', () => setTooltip(null))
        .on('focus', () => {
          const rect = containerRef.current?.getBoundingClientRect();
          if (!rect) return;
          setTooltip({
            x: margin.left + xScale(d.estimate) + 12,
            y: margin.top + y + 12,
            label: d.label,
            estimate: d.estimate,
            se: d.se,
            pvalue: d.pvalue,
            n: d.n,
          });
        })
        .on('blur', () => setTooltip(null))
        .on('keydown', (event) => {
          if (event.key === 'Escape') {
            setTooltip(null);
          }
        });

      // Value label
      g.append('text')
        .attr('x', innerWidth + 10)
        .attr('y', y)
        .attr('dy', '0.35em')
        .attr('font-family', 'var(--font-mono)')
        .attr('font-size', isMobile ? 9 : 11)
        .attr('fill', 'var(--color-text-muted)')
        .text(`${d.estimate.toFixed(3)}${d.pvalue < 0.05 ? '*' : ''}`);

      // N label (hide on very small screens)
      if (!isMobile) {
        g.append('text')
          .attr('x', innerWidth + 70)
          .attr('y', y)
          .attr('dy', '0.35em')
          .attr('font-size', 10)
          .attr('fill', 'var(--color-text-light)')
          .text(`n=${d.n.toLocaleString()}`);
      }
    });

    // Y axis (group labels)
    g.append('g')
      .call(d3.axisLeft(yScale))
      .call((g) => g.select('.domain').remove())
      .call((g) => g.selectAll('line').remove())
      .call((g) =>
        g.selectAll('text')
          .attr('font-size', isMobile ? 10 : 12)
          .attr('fill', 'var(--color-text)')
      );

    // X axis
    g.append('g')
      .attr('transform', `translate(0, ${innerHeight})`)
      .call(d3.axisBottom(xScale).ticks(6))
      .call((g) => g.select('.domain').attr('stroke', axisColor))
      .call((g) => g.selectAll('line').attr('stroke', axisColor))
      .call((g) => g.selectAll('text').attr('fill', 'var(--color-text-muted)'));

    // X axis label
    g.append('text')
      .attr('x', innerWidth / 2)
      .attr('y', innerHeight + 35)
      .attr('text-anchor', 'middle')
      .attr('fill', 'var(--color-text-muted)')
      .attr('font-size', 12)
      .text('Effect Size (β)');

  }, [grouping, pathway, dimensions, resolvedTheme, tooltipId]);

  return (
    <div ref={containerRef} className={styles.container}>
      <svg
        ref={svgRef}
        width={dimensions.width}
        height={dimensions.height}
        className={styles.svg}
        role="img"
        aria-label="Forest plot comparing treatment effects across demographic groups"
      />
      {tooltip && (
        <div
          className={styles.tooltip}
          style={{ left: tooltip.x, top: tooltip.y }}
          id={tooltipId}
          role="tooltip"
          aria-live="polite"
        >
          <div className={styles.tooltipTitle}>{tooltip.label}</div>
          <div className={styles.tooltipRow}>Effect: {tooltip.estimate.toFixed(3)}</div>
          <div className={styles.tooltipRow}>SE: {tooltip.se.toFixed(3)}</div>
          <div className={styles.tooltipRow}>p: {tooltip.pvalue.toFixed(3)}</div>
          <div className={styles.tooltipRow}>n: {tooltip.n.toLocaleString()}</div>
        </div>
      )}
      {grouping !== 'race' && (
        <div className={styles.legend}>
          <div className={styles.legendItem}>
            <span className={styles.legendSwatch} style={{ background: 'var(--color-significant)' }} />
            <span className={styles.legendLabel}>Significant (p &lt; .05)</span>
          </div>
          <div className={styles.legendItem}>
            <span className={styles.legendSwatch} style={{ background: 'var(--color-text-muted)' }} />
            <span className={styles.legendLabel}>Not significant</span>
          </div>
        </div>
      )}
      <p className={styles.note}>
        * p &lt; .05. Error bars represent 95% confidence intervals. For race comparisons, color encodes group.
      </p>
      <DataTimestamp />
    </div>
  );
}
