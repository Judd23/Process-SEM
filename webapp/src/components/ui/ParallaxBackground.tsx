import { motion, useScroll, useTransform, useSpring } from 'framer-motion';
import { usePointerParallax } from '../../lib/hooks/usePointerParallax';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';
import styles from './ParallaxBackground.module.css';

/**
 * ParallaxBackground
 * 
 * Three-layer fixed parallax background system with:
 * - Scroll-based parallax (layers move at different speeds)
 * - Pointer-based parallax (subtle world reaction to mouse)
 * - Uses existing "How It Works" gradients and glow layers
 * 
 * Architecture:
 * - bgFar: slowest layer, deep ambient gradients
 * - bgMid: medium layer, glow orbs
 * - bgNear: fastest layer, subtle highlights
 */
export function ParallaxBackground() {
  const { scrollY } = useScroll();

  // Pointer position for subtle world parallax
  const pointer = usePointerParallax({ smoothing: 0.05, enabled: true });

  // Scroll-based transforms for each layer
  // Far layer moves slowest (creates depth)
  const farY = useTransform(scrollY, [0, 3000], [0, -150]);
  const farYSpring = useSpring(farY, { stiffness: 50, damping: 30 });

  // Mid layer moves medium speed
  const midY = useTransform(scrollY, [0, 3000], [0, -300]);
  const midYSpring = useSpring(midY, { stiffness: 60, damping: 25 });

  // Near layer moves fastest
  const nearY = useTransform(scrollY, [0, 3000], [0, -500]);
  const nearYSpring = useSpring(nearY, { stiffness: 70, damping: 20 });

  // Pointer-based subtle translations (world reacts to mouse)
  const pointerXFar = pointer.x * 8;
  const pointerYFar = pointer.y * 6;
  const pointerXMid = pointer.x * 15;
  const pointerYMid = pointer.y * 12;
  const pointerXNear = pointer.x * 25;
  const pointerYNear = pointer.y * 20;

  return (
    <div className={styles.container} aria-hidden="true">
      {/* FAR LAYER - Deep ambient gradients (slowest) */}
      <motion.div
        className={styles.layerFar}
        style={{
          y: farYSpring,
          x: pointerXFar,
          translateY: pointerYFar,
        }}
        transition={DANCE_SPRING_HEAVY}
      />

      {/* MID LAYER - Glow orbs (medium speed) */}
      <motion.div
        className={styles.layerMid}
        style={{
          y: midYSpring,
          x: pointerXMid,
          translateY: pointerYMid,
        }}
        transition={DANCE_SPRING_HEAVY}
      />

      {/* NEAR LAYER - Subtle highlights (fastest) */}
      <motion.div
        className={styles.layerNear}
        style={{
          y: nearYSpring,
          x: pointerXNear,
          translateY: pointerYNear,
        }}
        transition={DANCE_SPRING_HEAVY}
      />

      {/* GRAIN/NOISE overlay (static, no parallax) */}
      <div className={styles.grain} />
    </div>
  );
}

export default ParallaxBackground;
