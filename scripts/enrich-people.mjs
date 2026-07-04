#!/usr/bin/env node
/**
 * enrich-people.mjs — fetches a portrait (P18, Wikimedia Commons) for every
 * person in the graph, in batches. Commons hosts only free/PD-licensed media,
 * so everything returned is safe to transmit.
 *
 * Output: data/people-images.json  (person QID → commons image url + source)
 */

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const read = async (p) => JSON.parse(await readFile(path.join(root, p), 'utf8'));

const UA = { 'User-Agent': 'telecine-enrich/0.1 (public domain film programme; github.com/brunohart/telecine)' };

async function sparql(query, attempt = 0) {
  let res;
  try {
    res = await fetch(`https://query.wikidata.org/sparql?query=${encodeURIComponent(query)}&format=json`, { headers: UA });
  } catch (err) {
    if (attempt < 4) { await new Promise((r) => setTimeout(r, 2500 * (attempt + 1))); return sparql(query, attempt + 1); }
    throw err;
  }
  if (!res.ok) {
    if (attempt < 4 && [429, 502, 503, 504].includes(res.status)) {
      await new Promise((r) => setTimeout(r, 2500 * (attempt + 1)));
      return sparql(query, attempt + 1);
    }
    throw new Error(`SPARQL ${res.status}`);
  }
  return (await res.json()).results.bindings;
}

const commonsFile = (uri) => decodeURIComponent(uri.split('/').pop());
const commonsUrl = (file, width = 480) =>
  `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(commonsFile(file))}?width=${width}`;

// collect every person QID in the enrichment
const enriched = await read('data/enriched.json');
const qids = new Set();
for (const e of Object.values(enriched)) {
  if (e.failed) continue;
  for (const p of e.cast ?? []) if (p.qid) qids.add(p.qid);
  for (const p of e.directors ?? []) if (p.qid) qids.add(p.qid);
  if (e.cinematographer?.qid) qids.add(e.cinematographer.qid);
}

let existing = {};
try { existing = await read('data/people-images.json'); } catch {}

const todo = [...qids].filter((q) => !(q in existing));
console.log(`${qids.size} people, ${todo.length} to fetch`);

const out = existing;
for (let i = 0; i < todo.length; i += 50) {
  const chunk = todo.slice(i, i + 50);
  const rows = await sparql(`
    SELECT ?person ?img WHERE {
      VALUES ?person { ${chunk.map((q) => `wd:${q}`).join(' ')} }
      ?person wdt:P18 ?img.
    }`);
  const found = {};
  for (const r of rows) {
    const q = r.person.value.split('/').pop();
    if (found[q]) continue; // first image statement wins
    found[q] = true;
    out[q] = {
      image: commonsUrl(r.img.value),
      source: `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(commonsFile(r.img.value))}`,
    };
  }
  for (const q of chunk) if (!(q in out)) out[q] = null; // no portrait on record
  console.log(`  batch ${i / 50 + 1}: ${Object.keys(found).length}/${chunk.length} portraits`);
  await new Promise((r) => setTimeout(r, 1500));
}

await writeFile(path.join(root, 'data', 'people-images.json'), JSON.stringify(out, null, 2));
const withImg = Object.values(out).filter(Boolean).length;
console.log(`Wrote data/people-images.json — ${withImg}/${Object.keys(out).length} portraits`);
