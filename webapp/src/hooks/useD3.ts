import { useRef, useEffect } from 'react';
import * as d3 from 'd3';

// Hook for D3 integration with React
export function useD3<T extends SVGSVGElement>(
  renderFn: (svg: d3.Selection<T, unknown, null, undefined>) => void,
  dependencies: unknown[]
) {
  const ref = useRef<T>(null);

  useEffect(() => {
    if (ref.current) {
      const svg = d3.select(ref.current);
      renderFn(svg);
    }
  }, dependencies);

  return ref;
}

// Hook for responsive container sizing
export function useContainerSize(containerRef: React.RefObject<HTMLElement>) {
  const getSize = () => {
    if (containerRef.current) {
      return {
        width: containerRef.current.clientWidth,
        height: containerRef.current.clientHeight,
      };
    }
    return { width: 0, height: 0 };
  };

  return getSize();
}

// Standard margins for charts
export const chartMargins = {
  top: 40,
  right: 40,
  bottom: 60,
  left: 80,
};

// Get inner dimensions after margins
export function getInnerDimensions(
  width: number,
  height: number,
  margins = chartMargins
) {
  return {
    innerWidth: Math.max(0, width - margins.left - margins.right),
    innerHeight: Math.max(0, height - margins.top - margins.bottom),
  };
}
