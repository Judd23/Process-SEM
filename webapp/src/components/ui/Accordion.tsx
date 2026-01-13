import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { InteractiveSurface } from './InteractiveSurface';
import { DANCE_SPRING_HEAVY } from '../../lib/transitionConfig';
import styles from './Accordion.module.css';

interface AccordionItem {
  id: string;
  title: string;
  content: React.ReactNode;
}

interface AccordionProps {
  items: AccordionItem[];
  allowMultiple?: boolean;
  defaultOpenId?: string;
}

export default function Accordion({
  items,
  allowMultiple = false,
  defaultOpenId,
}: AccordionProps) {
  const [openIds, setOpenIds] = useState<string[]>(
    defaultOpenId ? [defaultOpenId] : []
  );

  const toggleItem = (id: string) => {
    setOpenIds((prev) => {
      const isOpen = prev.includes(id);
      if (allowMultiple) {
        return isOpen ? prev.filter((itemId) => itemId !== id) : [...prev, id];
      }
      return isOpen ? [] : [id];
    });
  };

  return (
    <div className={styles.accordion}>
      {items.map((item) => {
        const isOpen = openIds.includes(item.id);
        const buttonId = `${item.id}-toggle`;
        const panelId = `${item.id}-panel`;

        return (
          <motion.div 
            key={item.id} 
            className={`${styles.item} ${isOpen ? styles.open : ''}`}
            initial={false}
            animate={{ backgroundColor: isOpen ? 'rgba(255, 255, 255, 0.02)' : 'transparent' }}
            transition={DANCE_SPRING_HEAVY}
          >
            <InteractiveSurface
              as="button"
              type="button"
              id={buttonId}
              className={`${styles.button} interactiveSurface`}
              aria-expanded={isOpen}
              aria-controls={panelId}
              onClick={() => toggleItem(item.id)}
            >
              <span className={styles.title}>{item.title}</span>
              <motion.span 
                className={styles.icon} 
                aria-hidden="true"
                animate={{ rotate: isOpen ? 45 : 0 }}
                transition={DANCE_SPRING_HEAVY}
              >
                +
              </motion.span>
            </InteractiveSurface>
            <AnimatePresence initial={false}>
              {isOpen && (
                <motion.div
                  id={panelId}
                  className={styles.panel}
                  role="region"
                  aria-labelledby={buttonId}
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={DANCE_SPRING_HEAVY}
                >
                  <div className={styles.panelInner}>{item.content}</div>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        );
      })}
    </div>
  );
}
