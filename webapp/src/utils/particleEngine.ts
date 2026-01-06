// SEM Diagram focal points (normalized 0-1 coordinates)
const SEM_NODES = [
  { x: 0.15, y: 0.5, label: 'FASt Status' },
  { x: 0.5, y: 0.3, label: 'Emotional Distress' },
  { x: 0.5, y: 0.7, label: 'Quality of Engagement' },
  { x: 0.85, y: 0.5, label: 'Developmental Adjustment' },
];

// Paths connecting nodes (for particle distribution)
const SEM_PATHS = [
  { from: 0, to: 1 }, // FASt -> Distress
  { from: 0, to: 2 }, // FASt -> Engagement
  { from: 1, to: 3 }, // Distress -> Adjustment
  { from: 2, to: 3 }, // Engagement -> Adjustment
  { from: 0, to: 3 }, // FASt -> Adjustment (direct)
];

export interface Particle {
  x: number;
  y: number;
  originX: number;
  originY: number;
  targetX: number;
  targetY: number;
  vx: number;
  vy: number;
  color: string;
  size: number;
  alpha: number;
  progress: number;
}

export type ParticlePhase = 'converging' | 'holding' | 'exploding' | 'complete';

export class ParticleSystem {
  particles: Particle[] = [];
  phase: ParticlePhase = 'converging';
  progress: number = 0;
  width: number;
  height: number;
  onPhaseComplete?: () => void;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }

  // Initialize particles from sampled colors
  initFromColors(colors: string[], count: number) {
    this.particles = [];
    this.phase = 'converging';
    this.progress = 0;

    for (let i = 0; i < count; i++) {
      // Random starting position across screen
      const originX = Math.random() * this.width;
      const originY = Math.random() * this.height;

      // Target: distribute along SEM diagram shape
      const target = this.getSEMTarget(i, count);

      this.particles.push({
        x: originX,
        y: originY,
        originX,
        originY,
        targetX: target.x * this.width,
        targetY: target.y * this.height,
        vx: 0,
        vy: 0,
        color: colors[i % colors.length] || '#6366f1',
        size: 3 + Math.random() * 4,
        alpha: 1,
        progress: 0,
      });
    }
  }

  // Distribute particles along SEM diagram nodes and paths
  private getSEMTarget(index: number, total: number): { x: number; y: number } {
    const nodeCount = SEM_NODES.length;
    const pathCount = SEM_PATHS.length;

    // 40% on nodes, 60% along paths
    const nodeParticles = Math.floor(total * 0.4);

    if (index < nodeParticles) {
      // Place on a node with slight jitter
      const nodeIndex = index % nodeCount;
      const node = SEM_NODES[nodeIndex];
      return {
        x: node.x + (Math.random() - 0.5) * 0.05,
        y: node.y + (Math.random() - 0.5) * 0.05,
      };
    } else {
      // Place along a path
      const pathIndex = (index - nodeParticles) % pathCount;
      const path = SEM_PATHS[pathIndex];
      const fromNode = SEM_NODES[path.from];
      const toNode = SEM_NODES[path.to];
      const t = Math.random(); // Position along path

      return {
        x: fromNode.x + (toNode.x - fromNode.x) * t + (Math.random() - 0.5) * 0.03,
        y: fromNode.y + (toNode.y - fromNode.y) * t + (Math.random() - 0.5) * 0.03,
      };
    }
  }

  // Easing functions
  private easeOutExpo(t: number): number {
    return t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
  }

  private easeOutBack(t: number): number {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  }

  // Update particle positions
  update(deltaTime: number) {
    const dt = Math.min(deltaTime, 0.05); // Cap delta to prevent jumps
    this.progress += dt;

    switch (this.phase) {
      case 'converging':
        this.updateConverging(dt);
        if (this.progress >= 0.4) {
          this.phase = 'holding';
          this.progress = 0;
        }
        break;

      case 'holding':
        // Brief pause at SEM shape
        if (this.progress >= 0.1) {
          this.phase = 'exploding';
          this.progress = 0;
          this.prepareExplosion();
        }
        break;

      case 'exploding':
        this.updateExploding(dt);
        if (this.progress >= 0.4) {
          this.phase = 'complete';
          this.onPhaseComplete?.();
        }
        break;
    }
  }

  private updateConverging(_dt: number) {
    const t = this.easeOutExpo(Math.min(this.progress / 0.4, 1));

    this.particles.forEach((p) => {
      // Interpolate from origin to SEM target
      p.x = p.originX + (p.targetX - p.originX) * t;
      p.y = p.originY + (p.targetY - p.originY) * t;
      p.progress = t;
    });
  }

  private prepareExplosion() {
    // Set new targets (random positions for explosion, will be replaced by new page)
    this.particles.forEach((p) => {
      // Store current position as new origin
      p.originX = p.x;
      p.originY = p.y;

      // New target: explode outward from center
      const centerX = this.width / 2;
      const centerY = this.height / 2;
      const angle = Math.atan2(p.y - centerY, p.x - centerX);
      const distance = 200 + Math.random() * 400;

      p.targetX = p.x + Math.cos(angle) * distance;
      p.targetY = p.y + Math.sin(angle) * distance;
    });
  }

  private updateExploding(_dt: number) {
    const t = this.easeOutBack(Math.min(this.progress / 0.4, 1));

    this.particles.forEach((p) => {
      // Interpolate from SEM position to explosion target
      p.x = p.originX + (p.targetX - p.originX) * t;
      p.y = p.originY + (p.targetY - p.originY) * t;
      p.alpha = 1 - t * 0.8; // Fade out
      p.progress = t;
    });
  }

  // Set new targets for entering new page
  setEnterTargets(positions: Array<{ x: number; y: number; color: string }>) {
    this.particles.forEach((p, i) => {
      if (positions[i]) {
        p.targetX = positions[i].x;
        p.targetY = positions[i].y;
        p.color = positions[i].color;
      }
    });
  }

  isComplete(): boolean {
    return this.phase === 'complete';
  }

  reset() {
    this.particles = [];
    this.phase = 'converging';
    this.progress = 0;
  }
}

// Helper to sample colors from the page (simplified)
export function samplePageColors(count: number): string[] {
  // Use semantic colors from the app's design system
  const semanticColors = [
    '#f97316', // FASt/accent (orange)
    '#ef4444', // Distress (red)
    '#3b82f6', // Engagement (blue)
    '#22c55e', // Success (green)
    '#8b5cf6', // Purple
    '#6366f1', // Indigo
    '#64748b', // Slate
  ];

  const colors: string[] = [];
  for (let i = 0; i < count; i++) {
    colors.push(semanticColors[i % semanticColors.length]);
  }
  return colors;
}
