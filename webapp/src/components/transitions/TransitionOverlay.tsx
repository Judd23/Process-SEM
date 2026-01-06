import { useTransition } from '../../context/TransitionContext';
import ParticleCanvas from './ParticleCanvas';
import styles from './TransitionOverlay.module.css';

export default function TransitionOverlay() {
  const { phase, completeTransition } = useTransition();

  const isActive = phase === 'exiting' || phase === 'transitioning';

  return (
    <>
      <ParticleCanvas active={isActive} onComplete={completeTransition} />
      {isActive && <div className={styles.backdrop} aria-hidden="true" />}
    </>
  );
}
