import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/Dissertation-Model-Simulation/",

  optimizeDeps: {
    include: [
      "react",
      "react-dom",
      "react-router-dom",
      "framer-motion",
      "d3",
      "zod",
    ],
  },

  build: {
    minify: "esbuild",
    target: "es2022",
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          "vendor-react": ["react", "react-dom", "react-router-dom"],
          "vendor-motion": ["framer-motion"],
          "vendor-d3": ["d3"],
        },
      },
    },
  },

  esbuild: {
    legalComments: "none",
  },
});
