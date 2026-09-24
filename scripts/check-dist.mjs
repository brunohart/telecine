#!/usr/bin/env node
// check-dist.mjs — after `astro build`: every inline <script> in dist/ must be allowed by the
// Content-Security-Policy in vercel.json (enforced, or still Report-Only while it is watched), or the deploy would ship pages whose [data-settle]
// content never appears (opacity 0 until reveal.js runs). Fails the build instead.
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dist = path.resolve(root, process.argv[2] ?? 'dist');
const vercel = JSON.parse(await readFile(path.join(root, 'vercel.json'), 'utf8'));
const csp = vercel.headers.flatMap((h) => h.headers).find((h) => h.key === 'Content-Security-Policy' || h.key === 'Content-Security-Policy-Report-Only')?.value ?? '';
const scriptSrc = csp.split(';').map((d) => d.trim().split(/\s+/)).find(([name]) => name === 'script-src') ?? [];

const bad = [];
for (const file of await readdir(dist, { recursive: true })) {
  if (!file.endsWith('.html')) continue;
  const html = await readFile(path.join(dist, file), 'utf8');
  for (const [, attrs, body] of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
    if (/\bsrc\s*=/.test(attrs)) continue;
    const hash = `'sha256-${createHash('sha256').update(body).digest('base64')}'`;
    if (!scriptSrc.includes(hash) && !scriptSrc.includes("'unsafe-inline'")) bad.push(`${file}: inline script ${hash}`);
  }
}
if (bad.length) {
  console.error(`check-dist: inline scripts the CSP (vercel.json) would block:\n  ${[...new Set(bad)].join('\n  ')}`);
  process.exit(1);
}
console.log('check-dist: no inline script outside the CSP');
