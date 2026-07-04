import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://telecine.vercel.app',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file' },
});
