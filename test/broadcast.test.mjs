import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolve, loopDuration, airingsBetween, nextAiring, upNext } from '../src/lib/broadcast.js';

const EPOCH = '2026-07-01T00:00:00Z';
const epochMs = Date.parse(EPOCH);

const channel = {
  id: 'test',
  epoch: EPOCH,
  blocks: [
    { type: 'interstitial', next: 'a', durationSec: 90 },
    { type: 'film', film: 'a', durationSec: 3600 },
    { type: 'interstitial', next: 'b', durationSec: 90 },
    { type: 'film', film: 'b', durationSec: 5400 },
  ],
};
const LOOP = 90 + 3600 + 90 + 5400;

test('loopDuration sums all blocks', () => {
  assert.equal(loopDuration(channel), LOOP);
});

test('resolves the opening interstitial at the epoch', () => {
  const r = resolve(channel, epochMs);
  assert.equal(r.index, 0);
  assert.equal(r.block.type, 'interstitial');
  assert.equal(r.offsetSec, 0);
});

test('resolves mid-film with the correct offset', () => {
  const r = resolve(channel, epochMs + (90 + 1000) * 1000);
  assert.equal(r.block.film, 'a');
  assert.equal(r.offsetSec, 1000);
  assert.equal(r.blockStart.getTime(), epochMs + 90 * 1000);
  assert.equal(r.blockEnd.getTime(), epochMs + (90 + 3600) * 1000);
});

test('block boundaries are half-open: the end instant belongs to the next block', () => {
  const r = resolve(channel, epochMs + (90 + 3600) * 1000);
  assert.equal(r.index, 2);
  assert.equal(r.offsetSec, 0);
});

test('wraps around the loop', () => {
  const r = resolve(channel, epochMs + (LOOP + 90 + 5) * 1000);
  assert.equal(r.block.film, 'a');
  assert.equal(r.offsetSec, 5);
});

test('is well-defined before the epoch (broadcast has always been on)', () => {
  const r = resolve(channel, epochMs - 10 * 1000);
  assert.equal(r.index, 3); // 10s before epoch = 10s before the end of film b
  assert.equal(Math.round(r.block.durationSec - r.offsetSec), 10);
});

test('two clients at the same instant see the same frame', () => {
  const at = epochMs + 123456 * 1000 + 789;
  const r1 = resolve(channel, at);
  const r2 = resolve(channel, new Date(at));
  assert.equal(r1.index, r2.index);
  assert.equal(r1.offsetSec, r2.offsetSec);
});

test('airingsBetween lists film starts inside the window only', () => {
  const from = epochMs;
  const to = epochMs + LOOP * 2 * 1000;
  const airings = airingsBetween(channel, from, to);
  assert.equal(airings.length, 4); // a, b, a, b
  assert.deepEqual(airings.map((x) => x.block.film), ['a', 'b', 'a', 'b']);
  assert.equal(airings[0].start.getTime(), epochMs + 90 * 1000);
  assert.equal(airings[2].start.getTime(), epochMs + (LOOP + 90) * 1000);
});

test('nextAiring finds the soonest future start of a film', () => {
  // during film a, the next airing of a is one loop later
  const during = epochMs + (90 + 10) * 1000;
  const next = nextAiring(channel, 'a', during);
  assert.equal(next.start.getTime(), epochMs + (LOOP + 90) * 1000);
  // and the next airing of b is later this loop
  const nb = nextAiring(channel, 'b', during);
  assert.equal(nb.start.getTime(), epochMs + (90 + 3600 + 90) * 1000);
});

test('upNext skips interstitials and wraps', () => {
  const duringB = epochMs + (90 + 3600 + 90 + 10) * 1000;
  assert.equal(upNext(channel, duringB).film, 'a');
});

test('channels resolve independently', () => {
  const other = { ...channel, epoch: '2026-07-01T00:30:00Z' };
  const at = epochMs + 45 * 60 * 1000;
  const r1 = resolve(channel, at);
  const r2 = resolve(other, at);
  assert.notEqual(r1.offsetSec, r2.offsetSec);
});
