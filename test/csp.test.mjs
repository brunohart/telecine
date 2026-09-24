import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// The Content-Security-Policy in vercel.json must admit every origin the baked data points the
// browser at — a re-bake that moves a print off archive.org fails here, not as a dead set in prod.
const load = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url), 'utf8'));
const network = load('../src/data/network.json');
const graph = load('../src/data/graph.json');
const csp = load('../vercel.json').headers.flatMap((h) => h.headers).find((h) => h.key === 'Content-Security-Policy' || h.key === 'Content-Security-Policy-Report-Only').value;
const directive = (name) => csp.split(';').map((d) => d.trim().split(/\s+/)).find(([n]) => n === name)?.slice(1) ?? [];
const admits = (sources, value) => {
  const { protocol, hostname } = new URL(value);
  return protocol === 'https:' && sources.some((s) => {
    if (!s.startsWith('https://')) return false;
    const host = s.slice('https://'.length);
    return host.startsWith('*.') ? hostname.endsWith(host.slice(1)) : hostname === host;
  });
};

test('the CSP admits every print the set tunes and every image the pages show', () => {
  const media = directive('media-src');
  const img = directive('img-src');
  for (const ch of network.channels)
    for (const b of ch.blocks) if (b.type === 'film') assert.ok(admits(media, b.src), `${ch.id}/${b.film}: ${b.src} is outside media-src`);
  for (const [slug, g] of Object.entries(graph.films)) if (g.poster) assert.ok(admits(img, g.poster), `${slug}: ${g.poster} is outside img-src`);
  for (const p of Object.values(graph.people)) if (p.image) assert.ok(admits(img, p.image), `${p.slug}: ${p.image} is outside img-src`);
});
