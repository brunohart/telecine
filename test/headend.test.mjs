import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// One bake, three copies: the pages' input, the head-end every receiver re-reads at launch, and the
// Apple bundle. If they drift, the web set and the Apple set show different films at the same minute.
const bytes = (p) => readFileSync(new URL(p, import.meta.url));
const network = JSON.parse(bytes('../src/data/network.json'));
const graph = JSON.parse(bytes('../src/data/graph.json'));

test('the head-end and the Apple bundle are byte-identical to the baked network', () => {
  const baked = bytes('../src/data/network.json');
  assert.ok(baked.equals(bytes('../public/network.json')), 'public/network.json ≠ src/data/network.json — run npm run bake');
  assert.ok(baked.equals(bytes('../apple/TelecineKit/Resources/network.json')), 'copy src/data/network.json to apple/TelecineKit/Resources/');
  assert.ok(bytes('../src/data/graph.json').equals(bytes('../apple/TelecineKit/Resources/graph.json')), 'copy src/data/graph.json to apple/TelecineKit/Resources/');
  const fixture = JSON.parse(bytes('../apple/TelecineTests/Fixtures/parity.json'));
  assert.equal(fixture.networkGeneratedAt, network.generatedAt, 'regenerate: node scripts/parity-fixture.mjs');
});

test('every baked link is https', () => {
  const https = (v, where) => assert.equal(new URL(v).protocol, 'https:', `${where}: ${v}`);
  for (const ch of network.channels) for (const b of ch.blocks) if (b.type === 'film') https(b.src, `${ch.id}/${b.film}.src`);
  for (const f of Object.values(network.films)) (https(f.src, `${f.slug}.src`), https(f.itemUrl, `${f.slug}.itemUrl`));
  for (const [slug, g] of Object.entries(graph.films)) for (const k of ['poster', 'posterSource']) if (g[k]) https(g[k], `${slug}.${k}`);
  for (const p of Object.values(graph.people)) for (const k of ['image', 'imageSource']) if (p[k]) https(p[k], `${p.slug}.${k}`);
});
