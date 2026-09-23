import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { playerSlice } from '../src/lib/slice.js';
import { resolve, upNext, airingsBetween } from '../src/lib/broadcast.js';

const load = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url), 'utf8'));
const network = load('../src/data/network.json');
const client = load('../src/data/network.client.json');

test('the committed slice is the slice of the committed network (re-bake after editing either)', () => {
  assert.deepEqual(client, playerSlice(network));
});

test('the slice tunes exactly as the whole network does', () => {
  const t0 = Date.parse('2026-09-01T00:00:00Z');
  for (const [i, ch] of network.channels.entries()) {
    const sliced = client.channels[i];
    assert.equal(sliced.id, ch.id);
    for (let k = 0; k < 500; k++) {
      const at = t0 + k * 7_919_000; // ~2.2 h steps: every block of every loop, at varied offsets
      assert.deepEqual(resolve(sliced, at), resolve(ch, at));
      assert.deepEqual(upNext(sliced, at), upNext(ch, at));
    }
    assert.deepEqual(airingsBetween(sliced, t0, t0 + 86_400_000), airingsBetween(ch, t0, t0 + 86_400_000));
  }
});

test('every film the schedule names has its title card in the slice', () => {
  for (const ch of client.channels) {
    for (const b of ch.blocks) {
      const film = client.films[b.type === 'film' ? b.film : b.next];
      assert.ok(film, `${ch.id}: no card for ${b.film ?? b.next}`);
      for (const k of ['slug', 'title', 'year', 'director', 'durationSec']) assert.ok(film[k] != null, `${film.slug}.${k}`);
    }
  }
});

test('the programme notes stay in the pages', () => {
  for (const f of Object.values(client.films)) {
    for (const k of ['note', 'logline', 'itemUrl', 'identifier', 'src', 'channel']) assert.equal(k in f, false, `${f.slug}.${k}`);
  }
  for (const ch of client.channels) {
    for (const k of ['tagline', 'description']) assert.equal(k in ch, false, `${ch.id}.${k}`);
  }
});
