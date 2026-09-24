import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://telecine.vercel.app',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file' },
  // never inline scripts: the CSP in vercel.json is script-src 'self' (checked by scripts/check-dist.mjs)
  vite: { build: { assetsInlineLimit: 0 } },
});
