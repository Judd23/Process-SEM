# Webapp - AI Instructions

## ⚠️ CRITICAL RULE - READ FIRST

**DO NOT MAKE ANY CHANGES WITHOUT EXPLICIT USER PERMISSION.**

This is a core rule. Before modifying any file, running any command, or making any change:
1. Describe what you plan to do
2. Wait for explicit approval ("yes", "go", "approved", etc.)
3. Only then proceed with the change

This applies to ALL actions: file edits, terminal commands, deployments, etc.

---

## Tech Stack

- React 19 + TypeScript + Vite
- Framer Motion for page transitions
- CSS Modules for component styling
- React Router v6 with HashRouter (GitHub Pages)
- D3.js for pathway diagrams

## Key Files

- `src/App.tsx` - Root routing with AnimatePresence morph transitions
- `src/styles/variables.css` - CSS design tokens
- `src/hooks/useScrollReveal.ts` - Intersection Observer reveal system

## Deploy Command

```bash
cd webapp && rm -rf node_modules/.cache/gh-pages 2>/dev/null && GIT_TERMINAL_PROMPT=0 npm run deploy 2>&1
```

## Live URL

https://judd23.github.io/Dissertation-Model-Simulation

---

## 📋 UX Improvement Checklist (January 9, 2026)

### HomePage (Intro)
- [x] **Shorten intro text** — Front-load value proposition, reduce paragraph length
- [x] **Add context to sample metrics** — Tooltip/micro-copy explaining why 5,000 and 27% matter
- [x] **Improve glossary affordances** — Increase hit area on "?" buttons, ensure keyboard focus, add descriptive ARIA labels
- [x] **Theme switcher clarity** — Add clearer label or icon for dark/light mode

### DemographicsPage (Equity Frame)
- [x] **Toggle feedback** — Animate or highlight panels when "Compare FASt vs non-FASt" switch is toggled
- [x] **Group comparison active state** — Add strong visual active state to buttons + keyboard accessibility
- [x] **Snapshot card layout** — Align text, add borders/separators, standardize decimal places
- [x] **Expand plain-language callouts** — Use "Plain talk:" pattern elsewhere

### MethodsPage (Technical Methods)
- [x] **Pipeline card interactivity** — Hover/click details on pipeline cards with glossary links
- [x] **Fit indices thresholds** — Show explicit thresholds next to CFI, TLI, RMSEA, SRMR
- [x] **Chi-square table completion** — Fill in target values, add conditional formatting
- [x] **Jargon reduction** — Add collapsible plain-language interpretations

### PathwayPage (Interactive Model)
- [x] **Persistent path labels** — Add "Stress route," "Engagement route," "Direct benefit" labels
- [x] **Filter active state** — Highlight active filter button, show path count
- [x] **Mobile responsiveness** — Horizontal scroll guidance for narrow screens
- [x] **Evidence badge footnotes** — Add color coding key and explanatory footnotes

### DoseExplorerPage (Credit Levels)
- [x] **Slider tick marks** — Show ticks at meaningful thresholds, keyboard control
- [x] **Interactive dose badges** — Clicking Low/Moderate/High snaps slider to range
- [x] **Chart line visibility** — Thicker lines, improved contrast
- [x] **Dose indicator prominence** — Make selected dose more visible
- [x] **Uncertainty explanation** — Add note explaining CI shaded areas

### SoWhatPage (Research Implications)
- [x] **Sub-heading clarity** — State core finding explicitly in sub-heading
- [x] **Call-out visibility** — Add icon or bold header to call-out box
- [x] **Standardize bullet style** — Ensure all points start with action verbs
- [x] **Link to resources** — Add links to external resources

### ResearcherPage (About)
- [x] **Image alt text** — Add descriptive alt text
- [x] **Email affordance** — Add envelope icon to make email link discoverable
- [x] **Quote attribution** — Clarify quotes as personal reflections
- [x] **Responsive layout** — Fix image/text stacking on smaller screens
