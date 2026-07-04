#!/usr/bin/env node
/**
 * enrich.mjs — enriches the catalogue from Wikidata/Wikimedia Commons:
 * poster (public-domain media only — Commons hosts nothing else), cast,
 * cinematographer, and one-line person descriptions.
 *
 * Every film resolves to a Wikidata QID by exact English label + release
 * year (override with `wikidataTitle` / `wikidataQid` in candidates.json
 * where labels differ). Nothing is guessed: no QID, no enrichment.
 *
 * Output: data/enriched.json
 */

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const read = async (p) => JSON.parse(await readFile(path.join(root, p), 'utf8'));

const SPARQL = 'https://query.wikidata.org/sparql';
const UA = { 'User-Agent': 'telecine-enrich/0.1 (public-domain film programme; contact via github.com/brunohart/telecine)' };

async function sparql(query, attempt = 0) {
  let res;
  try {
    res = await fetch(`${SPARQL}?query=${encodeURIComponent(query)}&format=json`, { headers: UA });
  } catch (err) {
    // connection resets are routine on WDQS — retry them like a 503
    if (attempt < 4) {
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      return sparql(query, attempt + 1);
    }
    throw err;
  }
  if (!res.ok) {
    if (attempt < 4 && [429, 502, 503, 504].includes(res.status)) {
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
      return sparql(query, attempt + 1);
    }
    throw new Error(`SPARQL ${res.status}`);
  }
  return (await res.json()).results.bindings;
}

const qid = (uri) => uri.split('/').pop();
// P18/P3383 values arrive percent-encoded — decode before re-encoding once
const commonsFile = (uri) => decodeURIComponent(uri.split('/').pop());
const commonsUrl = (file, width = 700) =>
  `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(commonsFile(file))}?width=${width}`;

/**
 * Search-then-verify: entity search for candidates, then confirm each is a
 * film whose release year matches ±1 and whose director agrees with ours.
 */
async function findFilm(film) {
  if (film.wikidataQid) return film.wikidataQid;
  const title = film.wikidataTitle ?? film.title;
  let search;
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(
      `https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${encodeURIComponent(title)}&language=en&type=item&limit=12&format=json`,
      { headers: UA }
    );
    const text = await res.text();
    try {
      search = JSON.parse(text);
      break;
    } catch {
      if (attempt >= 3) throw new Error(`entity search rate-limited: ${text.slice(0, 40)}`);
      await new Promise((r) => setTimeout(r, 4000 * (attempt + 1)));
    }
  }
  const ids = (search.search ?? []).map((s) => s.id);
  if (!ids.length) return null;

  const rows = await sparql(`
    SELECT DISTINCT ?film (YEAR(?date) AS ?y) ?dirLabel WHERE {
      VALUES ?film { ${ids.map((i) => `wd:${i}`).join(' ')} }
      ?film wdt:P31/wdt:P279* wd:Q11424; wdt:P577 ?date.
      OPTIONAL { ?film wdt:P57 ?dir. }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }`);

  const surnames = film.director.split(/&|,/).map((d) => d.trim().split(' ').pop().toLowerCase());
  const matches = new Set();
  for (const r of rows) {
    const y = Number(r.y?.value);
    if (Math.abs(y - film.year) > 1) continue;
    const dir = (r.dirLabel?.value ?? '').toLowerCase();
    if (dir && !surnames.some((s) => dir.includes(s))) continue;
    matches.add(qid(r.film.value));
  }
  return matches.size === 1 ? [...matches][0] : null;
}

async function enrichFilm(film) {
  const id = await findFilm(film);
  if (!id) return { failed: 'no unique wikidata match' };

  const rows = await sparql(`
    SELECT ?poster ?image ?castMember ?castMemberLabel ?castMemberDescription
           ?dop ?dopLabel ?dopDescription ?director ?directorLabel ?directorDescription WHERE {
      OPTIONAL { wd:${id} wdt:P3383 ?poster. }
      OPTIONAL { wd:${id} wdt:P18 ?image. }
      OPTIONAL { wd:${id} wdt:P161 ?castMember. }
      OPTIONAL { wd:${id} wdt:P344 ?dop. }
      OPTIONAL { wd:${id} wdt:P57 ?director. }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }`);

  const posterFile = rows.find((r) => r.poster)?.poster.value ?? rows.find((r) => r.image)?.image.value ?? null;
  const seen = new Set();
  const cast = [];
  for (const r of rows) {
    if (!r.castMember) continue;
    const pid = qid(r.castMember.value);
    if (seen.has(pid)) continue;
    seen.add(pid);
    cast.push({
      qid: pid,
      name: r.castMemberLabel?.value ?? pid,
      description: r.castMemberDescription?.value ?? '',
    });
  }
  const dopRow = rows.find((r) => r.dop);
  const directors = [];
  const dseen = new Set();
  for (const r of rows) {
    if (!r.director) continue;
    const pid = qid(r.director.value);
    if (dseen.has(pid)) continue;
    dseen.add(pid);
    directors.push({ qid: pid, name: r.directorLabel?.value ?? pid, description: r.directorDescription?.value ?? '' });
  }
  return {
    qid: id,
    poster: posterFile ? commonsUrl(posterFile) : null,
    posterSource: posterFile ? `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(commonsFile(posterFile))}` : null,
    cast: cast.slice(0, 8),
    directors,
    cinematographer: dopRow
      ? { qid: qid(dopRow.dop.value), name: dopRow.dopLabel?.value, description: dopRow.dopDescription?.value ?? '' }
      : null,
  };
}

const { films } = await read('data/candidates.json');
let existing = {};
try { existing = await read('data/enriched.json'); } catch {}

const out = existing;
let failures = 0;
for (const film of films) {
  if (!process.env.FORCE && !process.argv[2] && out[film.slug] && !out[film.slug].failed) {
    console.log(`  · ${film.slug} (cached)`);
    continue;
  }
  if (process.argv[2] && film.slug !== process.argv[2]) continue;
  try {
    const e = await enrichFilm(film);
    out[film.slug] = e;
    if (e.failed) { failures++; console.log(`  ✗ ${film.slug}: ${e.failed}`); }
    else console.log(`  ✓ ${film.slug} → ${e.qid} · poster:${e.poster ? 'yes' : 'NO'} · cast:${e.cast.length}${e.cinematographer ? ' · dop:' + e.cinematographer.name : ''}`);
  } catch (err) {
    failures++;
    console.log(`  ✗ ${film.slug}: ${err.message}`);
  }
  await new Promise((r) => setTimeout(r, 2200)); // be polite to WDQS + the search API
}

await writeFile(path.join(root, 'data', 'enriched.json'), JSON.stringify(out, null, 2));
console.log(`\nWrote data/enriched.json${failures ? ` — ${failures} to review` : ' — complete'}`);
