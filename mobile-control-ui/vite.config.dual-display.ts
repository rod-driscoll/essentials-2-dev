/**
 * Dual-display app build config.
 *
 *   npm run build:dual-display
 *
 * Produces a deployable web app in dist-dual-display/ using a separate entry
 * point that renders DualDisplayRoomControl instead of HuddleRoomControl.
 */

import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import tsConfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  base: '/mc/app/',
  plugins: [
    react(),
    tsConfigPaths(),
  ],
  build: {
    outDir: 'dist-dual-display',
    emptyOutDir: true,
    rollupOptions: {
      input: 'index.dual-display.html',
    },
  },
});
