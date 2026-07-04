#!/usr/bin/env node
/**
 * build-channels.mjs — bakes the network file the site consumes.
 *
 * Inputs:
 *   data/candidates.json  — film metadata + channel membership
 *   data/verified.json    — verified archive.org transfer per film (verify.mjs)
 *   data/programme.json   — channel identities + programme notes (the editorial layer)
 *
 * Output:
 *   src/data/network.json — Transmission per channel (SPEC.md) + film directory
 *
 * Fails loudly if any scheduled film is unverified: nothing ships unverified.
 */

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const read = async (p) => JSON.parse(await readFile(path.join(root, p), 'utf8'));

const { films: candidates } = await read('data/candidates.json');
const verified = await read('data/verified.json');
const programme = await read('data/programme.json');

const INTERSTITIAL_SEC = 90;

const filmMeta = Object.fromEntries(candidates.map((f) => [f.slug, f]));
const errors = [];

const films = {};
for (const [slug, editorial] of Object.entries(programme.films)) {
  const meta = filmMeta[slug];
  const v = verified[slug];
  if (!meta) errors.push(`programme.json film not in candidates: ${slug}`);
  if (!v || v.failed) errors.push(`unverified film scheduled: ${slug}`);
  if (!meta || !v || v.failed) continue;
  films[slug] = {
    slug,
    title: meta.title,
    year: meta.year,
    director: meta.director,
    durationSec: v.durationSec,
    src: v.url,
    identifier: v.identifier,
    itemUrl: `https://archive.org/details/${v.identifier}`,
    logline: editorial.logline,
    note: editorial.note,
  };
}

const channels = programme.channels.map((ch) => {
  const blocks = [];
  for (const slug of ch.films) {
    const film = films[slug];
    if (!film) {
      errors.push(`channel ${ch.id} schedules unknown/unverified film: ${slug}`);
      continue;
    }
    if (film.channel && film.channel !== ch.id) errors.push(`film ${slug} scheduled on two channels`);
    film.channel = ch.id;
    blocks.push({ type: 'interstitial', next: slug, durationSec: INTERSTITIAL_SEC });
    blocks.push({ type: 'film', film: slug, durationSec: film.durationSec, src: film.src });
  }
  return {
    transmission: '0.1',
    id: ch.id,
    number: ch.number,
    name: ch.name,
    tagline: ch.tagline,
    description: ch.description,
    epoch: ch.epoch,
    blocks,
  };
});

// every verified+programmed film must be on exactly one channel
for (const slug of Object.keys(films)) {
  if (!films[slug].channel) errors.push(`film has notes but no channel: ${slug}`);
}

if (errors.length) {
  console.error('build-channels: refusing to bake network.json:');
  for (const e of errors) console.error('  ✗ ' + e);
  process.exit(1);
}

const network = { generatedAt: new Date().toISOString(), interstitialSec: INTERSTITIAL_SEC, channels, films };
const out = path.join(root, 'src', 'data', 'network.json');
await writeFile(out, JSON.stringify(network, null, 2));

const totalHours = channels.reduce((s, c) => s + c.blocks.reduce((x, b) => x + b.durationSec, 0), 0) / 3600;
console.log(`✓ ${channels.length} channels, ${Object.keys(films).length} films, ${totalHours.toFixed(1)}h of programming → src/data/network.json`);
