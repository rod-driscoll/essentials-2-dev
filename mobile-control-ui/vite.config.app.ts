/**
 * App build config — produces a deployable web app (index.html + assets).
 * Use this to build for a touchpanel or production server:
 *
 *   npm run build:app
 *
 * This is separate from vite.config.ts, which builds the library package for npm.
 * Key differences:
 *   - No build.lib → Vite builds index.html as the entry point
 *   - No externals → all dependencies bundled into the output
 *   - base: '/mc/app/' → matches where Mobile Control serves the UI on port 50002
 *   - outDir: dist-app → separate from the library dist/ folder
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
    outDir: 'dist-app',
    emptyOutDir: true,
  },
});
