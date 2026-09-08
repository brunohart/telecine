// parity-fixture.mjs — freezes the reference resolver's answers so a second
// implementation (the Swift engine in apple/) can be proven to agree with it.
// Two receivers that disagree about what is on are not one network.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolve, airingsBetween, nextAiring, upNext, loopDuration } from '../src/lib/broadcast.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const network = JSON.parse(await readFile(path.join(root, 'src', 'data', 'network.json'), 'utf8'));

// deterministic pseudo-random instants — LCG, seeded
let seed = 20260701;
const rand = () => (seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296;

const cases = [];
for (const ch of network.channels) {
  const epoch = Date.parse(ch.epoch);
  const loopMs = loopDuration(ch) * 1000;
  const instants = [epoch, epoch - 1, epoch + 1, epoch - 10_000, epoch + loopMs, epoch + loopMs - 1, epoch + 3 * loopMs + 12_345];
  // every block boundary, and one ms either side
  let cum = 0;
  for (const b of ch.blocks) {
    instants.push(epoch + cum * 1000 - 1, epoch + cum * 1000, epoch + cum * 1000 + 1);
    cum += b.durationSec;
  }
  for (let i = 0; i < 40; i++) instants.push(Math.round(epoch + (rand() * 6 - 1) * loopMs));
  for (const at of instants) {
    const r = resolve(ch, at);
    const nx = upNext(ch, at);
    cases.push({
      channel: ch.id, atMs: at,
      index: r.index, offsetSec: r.offsetSec,
      blockStartMs: r.blockStart.getTime(), blockEndMs: r.blockEnd.getTime(), loopSec: r.loopSec,
      upNext: nx ? nx.film : null,
      nextAiringOfFirstFilm: (() => { const first = ch.blocks.find((b) => b.type === 'film').film; const a = nextAiring(ch, first, at); return a ? a.start.getTime() : null; })(),
    });
  }
}
const windows = [];
for (const ch of network.channels) {
  const epoch = Date.parse(ch.epoch);
  const loopMs = loopDuration(ch) * 1000;
  for (const [from, to] of [[epoch, epoch + 24 * 3600 * 1000], [epoch - 3600 * 1000, epoch + 3600 * 1000], [epoch + loopMs - 5000, epoch + loopMs + 5000], [epoch + 123456789, epoch + 123456789 + 36 * 3600 * 1000]]) {
    windows.push({ channel: ch.id, fromMs: from, toMs: to, airings: airingsBetween(ch, from, to).map((a) => ({ film: a.block.film, index: a.index, startMs: a.start.getTime(), endMs: a.end.getTime() })) });
  }
}
const out = path.join(root, 'apple', 'TelecineTests', 'Fixtures', 'parity.json');
await writeFile(out, JSON.stringify({ generatedAt: new Date().toISOString(), networkGeneratedAt: network.generatedAt, cases, windows }, null, 1));
console.log(`✓ ${cases.length} resolutions, ${windows.length} windows → apple/TelecineTests/Fixtures/parity.json`);
