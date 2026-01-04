import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
// Use '/' for custom domain, '/Dissertation-Model-Simulation/' for GitHub Pages subdomain
export default defineConfig({
  plugins: [react()],
  base: '/Dissertation-Model-Simulation/',
})
