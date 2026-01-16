import { useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import {
  PAGE_FADE,
  DANCE_SPRING,
  DANCE_SPRING_HEAVY,
  HOVER_SUBTLE,
  TAP_SUBTLE,
} from "../lib/transitionConfig";
import styles from "./LandingPageAlt.module.css";

// ============================================
// PARTICLE SPHERE ANIMATION
// ============================================
function useParticleSphere(
  canvasRef: React.RefObject<HTMLCanvasElement | null>
) {
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const particleCount = 800;
    const sphereRadius = 180;
    const rotationSpeed = 0.003;

    const width = canvas.width;
    const height = canvas.height;
    let animationId: number;

    class Particle {
      x: number;
      y: number;
      z: number;
      size: number;
      baseOpacity: number;

      constructor() {
        const theta = Math.random() * 2 * Math.PI;
        const phi = Math.acos(2 * Math.random() - 1);
        this.x = sphereRadius * Math.sin(phi) * Math.cos(theta);
        this.y = sphereRadius * Math.sin(phi) * Math.sin(theta);
        this.z = sphereRadius * Math.cos(phi);
        this.size = Math.random() * 1.5 + 0.5;
        this.baseOpacity = Math.random() * 0.5 + 0.2;
      }

      rotate(angleX: number, angleY: number) {
        let cos = Math.cos(angleY);
        let sin = Math.sin(angleY);
        let x = this.x * cos - this.z * sin;
        let z = this.z * cos + this.x * sin;
        this.x = x;
        this.z = z;
        cos = Math.cos(angleX);
        sin = Math.sin(angleX);
        let y = this.y * cos - this.z * sin;
        z = this.z * cos + this.y * sin;
        this.y = y;
        this.z = z;
      }

      draw(ctx: CanvasRenderingContext2D, centerX: number, centerY: number) {
        const scale = 300 / (300 + this.z);
        const x2d = centerX + this.x * scale;
        const y2d = centerY + this.y * scale;
        const opacity = Math.max(0, this.baseOpacity + (this.z / sphereRadius) * 0.4);
        ctx.beginPath();
        ctx.arc(x2d, y2d, this.size * scale, 0, Math.PI * 2);
        if (this.x > 50) {
          ctx.fillStyle = `rgba(6, 244, 255, ${opacity})`;
        } else if (this.x < -50) {
          ctx.fillStyle = `rgba(196, 181, 253, ${opacity})`;
        } else {
          ctx.fillStyle = `rgba(203, 213, 225, ${opacity})`;
        }
        ctx.fill();
      }
    }

    const particles: Particle[] = [];
    for (let i = 0; i < particleCount; i++) {
      particles.push(new Particle());
    }

    const animate = () => {
      ctx.clearRect(0, 0, width, height);
      const centerX = width / 2;
      const centerY = height / 2;
      particles.sort((a, b) => b.z - a.z);
      particles.forEach((p) => {
        p.rotate(rotationSpeed, rotationSpeed * 0.6);
        p.draw(ctx, centerX, centerY);
      });
      animationId = requestAnimationFrame(animate);
    };

    animate();
    return () => cancelAnimationFrame(animationId);
  }, [canvasRef]);
}


// ============================================
// ANIMATION VARIANTS
// ============================================
const containerVariants = {
  hidden: { opacity: 1 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.12,
      delayChildren: 0.2,
    },
  },
};

const fadeUpVariants = {
  hidden: { opacity: 0, y: 40 },
  visible: {
    opacity: 1,
    y: 0,
    transition: DANCE_SPRING,
  },
};

export default function LandingPageAlt() {
  const navigate = useNavigate();
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useParticleSphere(canvasRef);

  const handleEnter = () => {
    navigate("/home");
  };

  const logoSrc = `${
    import.meta.env.BASE_URL
  }researcher/sdsu_primary-logo_rgb_horizontal_reverse.png`;

  console.log("LandingPageAlt mounted", styles);

  return (
    <motion.div
      className={styles.landing}
      initial={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={PAGE_FADE}
      style={{ background: "#030712", minHeight: "100vh" }}
    >
      {/* Background Ambient Glow Blobs */}
      <div className={`${styles.blob} ${styles.blobCyan}`} />
      <div className={`${styles.blob} ${styles.blobViolet}`} />

      {/* Navigation */}
      <nav className={styles.nav}>
        <div className={styles.navInner}>
          {/* Logo */}
          <div className={styles.logoGroup}>
            <div className={styles.logoIcon}>DC</div>
            <span className={styles.logoText}>
              Dual Credit<span className={styles.logoMuted}>.Study</span>
            </span>
          </div>

          {/* Institution Badge */}
          <motion.a
            href="https://www.sdsu.edu"
            target="_blank"
            rel="noopener noreferrer"
            className={styles.institutionBadge}
            whileHover={HOVER_SUBTLE}
            transition={DANCE_SPRING}
          >
            <img
              src={logoSrc}
              alt="San Diego State University"
              className={styles.institutionLogo}
            />
          </motion.a>
        </div>
      </nav>

      {/* Main Content */}
      <main className={styles.main}>
        <motion.div
          className={styles.hero}
          variants={containerVariants}
          initial="hidden"
          animate="visible"
        >
          {/* Live Badge */}
          <motion.div className={styles.liveBadge} variants={fadeUpVariants}>
            <span className={styles.liveDot}>
              <span className={styles.livePing} />
              <span className={styles.liveCore} />
            </span>
            ED.D. DISSERTATION RESEARCH
          </motion.div>

          {/* Title */}
          <motion.h1 className={styles.title} variants={fadeUpVariants}>
            Psychosocial Effects of
            <br />
            Accelerated Dual Credit
          </motion.h1>

          {/* Subtitle */}
          <motion.p className={styles.subtitle} variants={fadeUpVariants}>
            Examining the psychosocial effects of accelerated dual credit on
            first-year developmental adjustment among equity-impacted California students.
          </motion.p>
        </motion.div>

        {/* Particle Sphere Container */}
        <motion.div
          className={styles.sphereContainer}
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: [0.97, 1.03, 0.97] }}
          transition={{ opacity: { duration: 0.8 }, scale: { duration: 4, repeat: Infinity, ease: "easeInOut" } }}
        >
          <canvas
            ref={canvasRef}
            className={styles.particleCanvas}
            width={512}
            height={512}
          />

          {/* Inner Breathing Orb */}
          <div className={styles.innerOrb} />

          {/* Central Pulse Ring */}
          <div className={styles.pulseRingWrapper}>
            <div className={styles.pulseRing} />
          </div>

          {/* Floating Stats */}
          <motion.div
            className={`${styles.floatingStat} ${styles.floatLeft}`}
            animate={{ y: [-8, 8, -8] }}
            transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
          >
            <span className={styles.statLabel}>FASt</span>
            <span className={styles.statValue}>Designation</span>
          </motion.div>

          <motion.div
            className={`${styles.floatingStat} ${styles.floatRight}`}
            animate={{ y: [8, -8, 8] }}
            transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
          >
            <span className={styles.statLabel}>N = 5,000</span>
            <span className={styles.statValue}>Sample Size</span>
          </motion.div>
        </motion.div>

        {/* Author Attribution */}
        <motion.div
          className={styles.author}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.6 }}
        >
          <h2 className={styles.authorName}>Jay Johnson</h2>
          <span className={styles.authorTitle}>Doctoral Candidate</span>
        </motion.div>
        {/* CTA Button */}
        <motion.div
          className={styles.ctaWrapper}
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...DANCE_SPRING, delay: 1.0 }}
        >
          <div className={styles.ctaGlow} />
          <motion.button
            className={styles.cta}
            onClick={handleEnter}
            whileHover={HOVER_SUBTLE}
            whileTap={TAP_SUBTLE}
            transition={DANCE_SPRING_HEAVY}
          >
            <span>Explore the Research</span>
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M9 18l6-6-6-6" />
            </svg>
          </motion.button>
        </motion.div>

      </main>
    </motion.div>
  );
}
