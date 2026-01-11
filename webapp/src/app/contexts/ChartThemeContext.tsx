/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, type ReactNode } from 'react';
import { useTheme } from './ThemeContext';

/**
 * ChartTheme - Centralized theme configuration for D3 charts
 * 
 * Provides consistent colors, fonts, and dimensions across all visualizations.
 * Automatically adapts to light/dark mode via ThemeContext.
 */

export interface ChartThemeConfig {
  // Colors
  colors: {
    // Semantic colors
    accent: string;
    accentLight: string;
    distress: string;
    engagement: string;
    belonging: string;
    fast: string;
    nonfast: string;
    positive: string;
    negative: string;
    
    // UI colors
    text: string;
    textMuted: string;
    background: string;
    surface: string;
    border: string;
    borderLight: string;
    
    // Chart-specific
    gridLine: string;
    axisLine: string;
    ciRibbon: string;
  };
  
  // Typography
  fonts: {
    heading: string;
    body: string;
    mono: string;
  };
  
  // Sizes
  fontSizes: {
    xs: number;
    sm: number;
    base: number;
    lg: number;
    xl: number;
  };
  
  // Chart dimensions (defaults)
  dimensions: {
    margin: { top: number; right: number; bottom: number; left: number };
    tooltipOffset: number;
    strokeWidth: {
      thin: number;
      normal: number;
      thick: number;
    };
  };
  
  // Animation
  transitions: {
    fast: number;
    normal: number;
    slow: number;
  };
}

const lightTheme: ChartThemeConfig = {
  colors: {
    accent: '#e35205',
    accentLight: 'rgba(227, 82, 5, 0.12)',
    distress: '#dc2626',
    engagement: '#2563eb',
    belonging: '#9333ea',
    fast: '#f97316',
    nonfast: '#6b7280',
    positive: '#16a34a',
    negative: '#dc2626',
    
    text: '#1a1a2e',
    textMuted: '#6b7280',
    background: '#fafbfc',
    surface: '#ffffff',
    border: '#e5e7eb',
    borderLight: '#f3f4f6',
    
    gridLine: 'rgba(0, 0, 0, 0.06)',
    axisLine: 'rgba(0, 0, 0, 0.12)',
    ciRibbon: 'rgba(0, 0, 0, 0.08)',
  },
  
  fonts: {
    heading: "'Source Serif Pro', Georgia, serif",
    body: "'Source Sans Pro', -apple-system, BlinkMacSystemFont, sans-serif",
    mono: "'Source Code Pro', 'Fira Code', monospace",
  },
  
  fontSizes: {
    xs: 10,
    sm: 12,
    base: 14,
    lg: 16,
    xl: 18,
  },
  
  dimensions: {
    margin: { top: 20, right: 30, bottom: 40, left: 50 },
    tooltipOffset: 10,
    strokeWidth: {
      thin: 1,
      normal: 2,
      thick: 3,
    },
  },
  
  transitions: {
    fast: 150,
    normal: 300,
    slow: 500,
  },
};

const darkTheme: ChartThemeConfig = {
  ...lightTheme,
  colors: {
    ...lightTheme.colors,
    text: '#f1f5f9',
    textMuted: '#9ca3af',
    background: '#0f0f1a',
    surface: '#1a1a2e',
    border: '#374151',
    borderLight: '#1f2937',
    
    gridLine: 'rgba(255, 255, 255, 0.06)',
    axisLine: 'rgba(255, 255, 255, 0.12)',
    ciRibbon: 'rgba(255, 255, 255, 0.08)',
  },
};

const ChartThemeContext = createContext<ChartThemeConfig | null>(null);

export function ChartThemeProvider({ children }: { children: ReactNode }) {
  const { resolvedTheme } = useTheme();
  const theme = resolvedTheme === 'dark' ? darkTheme : lightTheme;
  
  return (
    <ChartThemeContext.Provider value={theme}>
      {children}
    </ChartThemeContext.Provider>
  );
}

export function useChartTheme(): ChartThemeConfig {
  const context = useContext(ChartThemeContext);
  if (!context) {
    // Return light theme as fallback if not in provider
    return lightTheme;
  }
  return context;
}

// Export themes for direct access if needed
export { lightTheme, darkTheme };
