# Webapp Bug Tracker

> **Last Updated:** January 11, 2026  
> **Status:** 5 open items, 22 archived

---

## 🎯 Current Focus

1. **Aria-label audit** — Ensure all interactive elements have proper labels
2. **GroupComparison hardcoded data** — HIGH priority, blocks accurate equity comparisons
3. **Data validation layer** — Recommended, catches pipeline/webapp schema drift
4. **Chart theme centralization** — Recommended, improves maintainability
5. **E2E test coverage** — Recommended, prevents regressions

---

## 🔴 Open Issues

### 0. Aria-Label Audit
**Priority:** HIGH  
**Status:** ⏳ In progress

#### ✅ Elements WITH aria-labels (22 total)

| File | Element | Label |
|------|---------|-------|
| `LandingPage.tsx` | CTA button | "Enter the research visualization" |
| `LandingPage.tsx` | Scroll indicator | "Begin exploring the research" |
| `DoseExplorerPage.tsx` | Dose zone buttons | Dynamic: "Set dose to {zone} ({range})" |
| `DemographicsPage.tsx` | Group buttons container | "Student grouping options" |
| `DemographicsPage.tsx` | GroupComparison (a1) | "Chart comparing stress outcomes..." |
| `DemographicsPage.tsx` | GroupComparison (a2) | "Chart comparing engagement outcomes..." |
| `Header.tsx` | Progress bar | "Page scroll progress" |
| `Header.tsx` | Brand link | "Go to home" |
| `Header.tsx` | Nav | "Primary navigation" |
| `MobileNav.tsx` | Nav | "Mobile navigation" |
| `ThemeToggle.tsx` | Button | "Theme: Dark mode" |
| `BackToTop.tsx` | Button | "Back to top" |
| `GlossaryTerm.tsx` | Term button | Dynamic: "Definition: {definition}" |
| `Slider.tsx` | Input | Dynamic via `label` prop |
| `ProgressRing.tsx` | SVG | Dynamic via `label` prop |
| `JohnsonNeymanPlot.tsx` | SVG | "Johnson-Neyman plot..." |
| `DoseResponseCurve.tsx` | SVG | "Dose-response curve..." |
| `PathwayDiagram.tsx` | SVG | "Pathway diagram..." |
| `PathwayDiagram.tsx` | Nodes | Dynamic node labels |
| `EffectDecomposition.tsx` | SVG | "Effect decomposition chart" |
| `GroupComparison.tsx` | SVG | "Forest plot comparing..." |
| `Accordion.tsx` | Panels | `aria-labelledby` linked to button |

#### ⚠️ Elements MISSING aria-labels

| File | Element | Suggested Label |
|------|---------|-----------------|
| `HomePage.tsx` | "Explore Pathways" link | "View pathway analysis" |
| `HomePage.tsx` | "Explore Dose Effects" link | "View dose-response analysis" |
| `HomePage.tsx` | "Explore by Group" link | "View demographic comparisons" |
| `MethodsPage.tsx` | "View the Model" link | "View pathway model" |
| `SoWhatPage.tsx` | "About the Researcher" link | "View researcher info" |
| `DoseExplorerPage.tsx` | "What Does This Mean?" link | "View implications" |
| `PathwayPage.tsx` | Pathway toggle buttons | Need dynamic labels |
| `DemographicsPage.tsx` | Individual group buttons | Need per-button labels |

---

### 1. GroupComparison Hardcoded Data
**Priority:** HIGH  
**Location:** `webapp/src/components/charts/GroupComparison.tsx#L47-L95`

**Issue:** `firstgen`, `pell`, `sex`, `living` groups have hardcoded effect estimates instead of reading from pipeline output.

**Fix:** Add multi-group results to `groupComparisons.json` for all grouping variables, not just race.

**Status:** ⏳ Not started

---

## 🔵 Recommendations

### 2. Create Data Validation Layer
**Priority:** MEDIUM

Add Zod schemas for JSON data files to catch schema drift between R pipeline and webapp.

```typescript
// webapp/src/schemas/modelResults.ts
import { z } from 'zod';

export const ModelResultsSchema = z.object({
  mainModel: z.object({
    fitMeasures: z.object({...}),
    structuralPaths: z.array(...)
  })
});
```

**Status:** ⏳ Not started

---

### 3. Centralize Chart Theme
**Priority:** LOW

Create `ChartTheme` context that provides D3-compatible colors, fonts, and dimensions.

**Status:** ⏳ Not started

---

### 4. Add E2E Tests
**Priority:** LOW

Add Playwright or Cypress tests for critical user flows (navigate all pages, interact with dose slider, verify data displays).

**Status:** ⏳ Not started

---

## 🛠️ Quick Commands

```bash
# TypeScript check
cd webapp && npx tsc --noEmit

# ESLint  
cd webapp && npm run lint

# Banned terms (should return nothing)
grep -r "QualInteract" webapp/src --include="*.tsx" --include="*.ts"

# Visual testing
cd webapp && npm run dev  # Test at 320px, 480px, 768px, 1024px
```

---

<details>
<summary>📦 Archived (22 completed bugs)</summary>

### Bug #2: Missing Accessibility - SVG Charts ✅
**Fixed:** Jan 6, 2026  
Added `role="img"` and `aria-label` to all chart SVGs.

---

### Bug #3: ParticleCanvas Variable Hoisting Error ✅
**Fixed:** Jan 6, 2026  
Used ref pattern for self-referencing callback.

---

### Bug #4: SharedElement Unused Variable ✅
**Fixed:** Jan 6, 2026  
Removed unused `fallback` prop from destructuring.

---

### Bug #5: StatCard setState in useEffect ✅
**Fixed:** Jan 6, 2026  
Used `queueMicrotask()` to avoid synchronous setState.

---

### Bug #6: TransitionContext setState in useEffect ✅
**Fixed:** Jan 6, 2026  
Used `queueMicrotask()` for batched updates.

---

### Bug #7: useParallax setState in useEffect ✅
**Fixed:** Jan 6, 2026  
Used `queueMicrotask()`.

---

### Bug #8: useScrollReveal Ref Access During Render ✅
**Fixed:** Jan 6, 2026  
Moved ref access into useEffect.

---

### Bug #9: particleEngine Unused Parameters ✅
**Fixed:** Jan 6, 2026  
Added eslint-disable comments for intentionally unused `_dt`.

---

### Bug #10: Chart Components Missing useEffect Dependencies ✅
**Fixed:** Jan 6, 2026  
Added `tooltipId` to dependency arrays.

---

### Bug #11: Context Files React Fast Refresh Warnings ✅
**Fixed:** Jan 6, 2026  
Added eslint-disable directive.

---

### Bug #12: JohnsonNeymanPlot Fixed Dimensions ✅
**Fixed:** Jan 6, 2026  
Added ResizeObserver responsive sizing.

---

### Bug #13: PathwayDiagram Mobile Horizontal Scroll ✅
**Fixed:** Already implemented  
Uses containerRef + ResizeObserver with mobile-adaptive layout.

---

### Bug #14: Duplicate Color Definitions ✅
**Fixed:** Jan 6, 2026  
Added `getColor()` helper that reads CSS variables.

---

### Bug #15: Slider Missing ARIA Attributes ✅
**Fixed:** Jan 6, 2026  
Added `aria-label`, `aria-valuetext`, `aria-valuenow`.

---

### Bug #16: MobileNav Missing Icon Support ✅
**Fixed:** Jan 6, 2026  
Added SVG path icons to navItems and MobileNav.

---

### Bug #17: Header Progress Bar on Landing ✅
**Fixed:** Jan 6, 2026  
Added `/home` to progress bar exclusion.

---

### Bug #18: DoseResponseCurve Duplicate Color Variable ✅
**Fixed:** Jan 6, 2026  
Removed duplicate color variable.

---

### Bug #19: StatCard Animation Edge Case ✅
**Fixed:** Already implemented  
Shows actual value when non-numeric.

---

### Bug #20: ThemeContext SSR Guard ✅
**Fixed:** Already implemented  
Uses standard `typeof window` checks.

---

### Bug #21: MethodsPage surveyItems Inline JSX ✅
**Fixed:** Already implemented  
Static const outside component is correct pattern.

---

### Bug #22: SoWhatPage Missing Error Handling ✅
**Fixed:** Not needed  
Static JSON imports always available; `?? 0` is defensive coding.

---

### Bug #23: DemographicsPage `as any` Type Assertions ✅
**Fixed:** Jan 6, 2026  
Added `FastComparisonType` interface.

</details>

---

## 📝 Changelog

| Date | Change |
|------|--------|
| Jan 9, 2026 | **Design Language Standardization** — Blur values + Spring physics |
| Jan 8, 2026 | Reorganized: Split Phase 27 to `webapp/TRANSITIONS.md`, archived 22 completed bugs |
| Jan 6, 2026 | Fixed 11 ESLint errors (#3-#11) |
| Jan 6, 2026 | Fixed 4 medium priority issues (#12-#15) |
| Jan 6, 2026 | Fixed 7 low priority issues (#16-#23) |

---

## ✅ Design Language Updates (Jan 9, 2026)

### Blur Values Standardization
**Spec:** `thickness-regular` = 16px blur (cards/panels), `thickness-thick` = 12px blur (overlays)

| File | Element | Change |
|------|---------|--------|
| `GlassPanel.module.css` | `.thickness-regular` | 18px → 16px |
| `GlassPanel.module.css` | `.thickness-thick` | 22px → 12px |
| `glass.css` | `.glass-panel` base | 20px → 16px |
| `glass.css` | `.glass-panel-double::after` | 10px → 12px |
| `global.css` | `.glass-panel` | 20px → 16px |
| `StatCard.module.css` | `.statCard` | 20px → 16px |
| `KeyTakeaway.module.css` | `.takeaway` | 20px → 16px |
| `Accordion.module.css` | `.item` | 20px → 16px |
| `PathwayPage.module.css` | `.diagram` | 20px → 16px |
| `DemographicsPage.module.css` | `.demoCard` | 20px → 16px |
| `SoWhatPage.module.css` | `.stakeholderCard`, `.actionCard` | 20px → 16px |
| `LandingPage.module.css` | `.nameplate` | 20px → 16px |
| `HomePage.module.css` | `.takeawaySection` | 20px → 16px |

### Spring Physics Standardization
**Spec:** All animated panels/cards use `DANCE_SPRING_HEAVY` (stiffness: 50, damping: 22, mass: 1.5)

| File | Change |
|------|--------|
| `StatCard.tsx` | Added import + uses `DANCE_SPRING_HEAVY` |
| `KeyTakeaway.tsx` | Added import + uses `DANCE_SPRING_HEAVY` |
| `MorphProvider.tsx` | ✅ Already using `DANCE_SPRING_HEAVY` (global MotionConfig) |
| `SharedElement.tsx` | ✅ Already using `DANCE_SPRING_HEAVY` |
| `ChoreographedReveal.tsx` | ✅ Already using `DANCE_SPRING_HEAVY` (all 4 variants) |
| `MorphableElement.tsx` | ✅ Uses `CATEGORY_SPRINGS` (all = `DANCE_SPRING_HEAVY`) |

### Page-Level Transitions (Fixed Jan 9, 2026)
| File | Change |
|------|--------|
| `Layout.tsx` | Added import + `transition={DANCE_SPRING_HEAVY}` |
| `PageTransition.tsx` | Added import + uses `DANCE_SPRING_HEAVY` for non-reduced motion |

**Verification:** `npx tsc --noEmit` passes, zero `blur(20px)` values remain, all spring physics standardized
