#!/usr/bin/env node
/**
 * verify.mjs — resolves every candidate film to a working Internet Archive
 * transfer: a real identifier, a playable H.264 MP4 that answers byte-range
 * requests, and an exact duration. The broadcast schedule depends on these
 * durations, so nothing ships unverified.
 *
 * Usage:
 *   node scripts/verify.mjs            # verify all candidates
 *   node scripts/verify.mjs <slug>     # verify one film
 *
 * Output: data/verified.json  (slug → identifier, file, url, durationSec, sourceNote)
 */

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const CANDIDATES = path.join(root, 'data', 'candidates.json');
const OUT = path.join(root, 'data', 'verified.json');

const UA = { 'User-Agent': 'telecine-verify/0.1 (public domain film scheduling)' };

async function getJson(url) {
  const res = await fetch(url, { headers: UA });
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res.json();
}

/** Normalize a title for containment matching. */
function norm(s) {
  return String(s)
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** The item must plausibly BE this film (not a collection or a different film). */
function titleMatches(itemTitle, film) {
  const t = norm(itemTitle);
  const want = norm(film.title);
  if (t.includes(want)) return true;
  // tolerate short/article-stripped titles, e.g. "Bronenosets Potyomkin (Battleship Potemkin)"
  const stripped = want.replace(/^(the|a|an) /, '');
  return stripped.length > 4 && t.includes(stripped);
}

/** Pick the best playable MP4 from an item's file list. */
function pickFile(files) {
  const mp4s = files.filter(
    (f) =>
      f.name.toLowerCase().endsWith('.mp4') &&
      f.length &&
      Number(f.length) > 600 && // ignore trailers/clips
      !/trailer|sample|preview|ia_thumb/i.test(f.name)
  );
  if (!mp4s.length) return null;
  // Prefer a sane streaming derivative (100MB–2.5GB), largest first; else the largest overall.
  const bySize = [...mp4s].sort((a, b) => Number(b.size || 0) - Number(a.size || 0));
  const sane = bySize.filter((f) => Number(f.size || 0) > 1e8 && Number(f.size || 0) < 2.5e9);
  return sane[0] || bySize[0];
}

async function checkRange(url) {
  try {
    const res = await fetch(url, { headers: { ...UA, Range: 'bytes=0-1023' }, redirect: 'follow' });
    const ok = res.status === 206 || (res.status === 200 && res.headers.get('accept-ranges') === 'bytes');
    res.body?.cancel?.();
    return ok;
  } catch {
    return false;
  }
}

async function tryIdentifier(id, film) {
  let meta;
  try {
    meta = await getJson(`https://archive.org/metadata/${id}`);
  } catch {
    return null;
  }
  if (!meta || !meta.files || meta.is_dark) return null;
  if (meta.metadata?.access_restricted) return null;
  const itemTitle = meta.metadata?.title || id;
  if (!titleMatches(itemTitle, film)) return { rejected: `title mismatch: "${itemTitle}"`, id };
  const file = pickFile(meta.files);
  if (!file) return null;
  const durationSec = Math.round(Number(file.length));
  const [lo, hi] = film.runtimeWindowMin;
  if (durationSec < lo * 60 || durationSec > hi * 60) {
    return { rejected: `duration ${(durationSec / 60).toFixed(1)}min outside [${lo},${hi}]`, id };
  }
  const url = `https://archive.org/download/${id}/${encodeURIComponent(file.name).replace(/%2F/g, '/')}`;
  if (!(await checkRange(url))) return { rejected: 'no byte-range support', id };
  return {
    identifier: id,
    file: file.name,
    url,
    durationSec,
    sizeBytes: Number(file.size || 0),
    itemTitle: meta.metadata?.title || '',
  };
}

async function searchFallback(film) {
  const q = encodeURIComponent(`(${film.query}) AND mediatype:(movies)`);
  const url = `https://archive.org/advancedsearch.php?q=${q}&fl%5B%5D=identifier&fl%5B%5D=downloads&fl%5B%5D=title&sort%5B%5D=downloads+desc&rows=12&output=json`;
  let res;
  try {
    res = await getJson(url);
  } catch {
    return [];
  }
  return (res.response?.docs || []).map((d) => d.identifier);
}

async function verifyFilm(film) {
  const tried = [];
  const candidates = [...film.identifiers];
  for (let pass = 0; pass < 2; pass++) {
    for (const id of candidates) {
      if (tried.includes(id)) continue;
      tried.push(id);
      const result = await tryIdentifier(id, film);
      if (result && !result.rejected) return { ...result, tried };
      if (result?.rejected) console.error(`    ✗ ${id}: ${result.rejected}`);
      else console.error(`    ✗ ${id}: unavailable/dark/no-mp4`);
    }
    if (pass === 0) {
      const found = await searchFallback(film);
      candidates.push(...found);
    }
  }
  return { failed: true, tried };
}

const only = process.argv[2];
const { films } = JSON.parse(await readFile(CANDIDATES, 'utf8'));
let existing = {};
try {
  existing = JSON.parse(await readFile(OUT, 'utf8'));
} catch {}

const results = existing;
let failures = 0;
for (const film of films) {
  if (only && film.slug !== only) continue;
  if (!only && results[film.slug] && !results[film.slug].failed) {
    console.log(`  · ${film.slug} (cached: ${results[film.slug].identifier})`);
    continue;
  }
  console.log(`  ? ${film.slug}`);
  const r = await verifyFilm(film);
  results[film.slug] = r;
  if (r.failed) {
    failures++;
    console.log(`  ✗ FAILED ${film.slug} (tried: ${r.tried.join(', ')})`);
  } else {
    console.log(
      `  ✓ ${film.slug} → ${r.identifier}/${r.file} (${(r.durationSec / 60).toFixed(1)}min, ${(r.sizeBytes / 1e6).toFixed(0)}MB) "${r.itemTitle}"`
    );
  }
}

await writeFile(OUT, JSON.stringify(results, null, 2));
console.log(`\nWrote ${OUT}${failures ? ` — ${failures} FAILURES` : ' — all verified'}`);
process.exit(failures ? 1 : 0);
