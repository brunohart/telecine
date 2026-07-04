/**
 * broadcast.js — the Telecine broadcast engine.
 *
 * A channel is a Transmission: a fixed epoch and an ordered list of blocks
 * (films and interstitials) that loop forever. Given the real clock, this
 * module answers the only question a broadcast needs to answer:
 * what is on, and how far into it are we.
 *
 * Pure functions, no dependencies, no state. The same file runs at build
 * time (guide generation), in tests, and in the browser (the player).
 * See SPEC.md for the Transmission format.
 */

/** Total length of one loop of the schedule, in seconds. */
export function loopDuration(channel) {
  return channel.blocks.reduce((sum, b) => sum + b.durationSec, 0);
}

/**
 * Resolve a channel against a moment in time.
 * @param {object} channel - a Transmission (epoch ISO string + blocks)
 * @param {Date|number} now - the moment to resolve
 * @returns {{ block: object, index: number, offsetSec: number,
 *            blockStart: Date, blockEnd: Date, loopSec: number }}
 */
export function resolve(channel, now) {
  const t = typeof now === 'number' ? now : now.getTime();
  const epoch = Date.parse(channel.epoch);
  const loop = loopDuration(channel);
  if (loop <= 0) throw new Error(`channel ${channel.id}: empty schedule`);
  // seconds into the current loop (well-defined for t before the epoch too)
  const into = (((t - epoch) / 1000) % loop + loop) % loop;
  let cum = 0;
  for (let i = 0; i < channel.blocks.length; i++) {
    const b = channel.blocks[i];
    if (into < cum + b.durationSec) {
      const loopStart = t - into * 1000;
      return {
        block: b,
        index: i,
        offsetSec: into - cum,
        blockStart: new Date(loopStart + cum * 1000),
        blockEnd: new Date(loopStart + (cum + b.durationSec) * 1000),
        loopSec: loop,
      };
    }
    cum += b.durationSec;
  }
  /* unreachable: `into` is always < loop */
  throw new Error('resolve: fell off the schedule');
}

/**
 * All film airings on a channel that begin within [from, to).
 * @returns {Array<{ block: object, index: number, start: Date, end: Date }>}
 */
export function airingsBetween(channel, from, to) {
  const fromMs = typeof from === 'number' ? from : from.getTime();
  const toMs = typeof to === 'number' ? to : to.getTime();
  const epoch = Date.parse(channel.epoch);
  const loopMs = loopDuration(channel) * 1000;
  const airings = [];
  // first loop whose start could place a block inside the window
  let k = Math.floor((fromMs - epoch) / loopMs) - 1;
  for (; ; k++) {
    const loopStart = epoch + k * loopMs;
    if (loopStart >= toMs) break;
    let cum = 0;
    for (let i = 0; i < channel.blocks.length; i++) {
      const b = channel.blocks[i];
      const start = loopStart + cum * 1000;
      cum += b.durationSec;
      if (b.type !== 'film') continue;
      if (start >= fromMs && start < toMs) {
        airings.push({ block: b, index: i, start: new Date(start), end: new Date(start + b.durationSec * 1000) });
      }
    }
  }
  return airings;
}

/** The next airing of a given film on a channel, at or after `now`. */
export function nextAiring(channel, filmSlug, now) {
  const t = typeof now === 'number' ? now : now.getTime();
  const horizon = t + loopDuration(channel) * 1000 + 1000;
  return airingsBetween(channel, t, horizon).find((a) => a.block.film === filmSlug) ?? null;
}

/** What follows the current block (skipping nothing) — used by the player and the "up next" line. */
export function upNext(channel, now) {
  const { index } = resolve(channel, now);
  for (let step = 1; step <= channel.blocks.length; step++) {
    const b = channel.blocks[(index + step) % channel.blocks.length];
    if (b.type === 'film') return b;
  }
  return null;
}
