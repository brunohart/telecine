#!/usr/bin/env node
/**
 * qa.mjs — drives real Chrome against the site: tunes in, watches the video
 * element, reports playback state, and takes screenshots for design review.
 *
 * Usage: node scripts/qa.mjs [url] [outdir]
 */
import { chromium } from 'playwright-core';
import path from 'node:path';

const url = process.argv[2] ?? 'https://telecine.vercel.app';
const outdir = process.argv[3] ?? '/tmp/telecine-qa';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

const consoleLines = [];
page.on('console', (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => consoleLines.push(`[pageerror] ${e.message}`));

await page.goto(url, { waitUntil: 'networkidle' });
await page.screenshot({ path: path.join(outdir, '01-set-off.png') });

const state = async () =>
  page.evaluate(() => {
    const v = document.getElementById('screen');
    return {
      src: v.currentSrc?.slice(0, 90),
      readyState: v.readyState,
      networkState: v.networkState,
      currentTime: Math.round(v.currentTime),
      paused: v.paused,
      muted: v.muted,
      error: v.error ? { code: v.error.code, message: v.error.message } : null,
      cardHidden: document.getElementById('card')?.hidden,
      noiseHidden: document.getElementById('noise')?.hidden,
      noiseLabel: document.getElementById('noise-label')?.textContent,
      onair: document.getElementById('onair')?.textContent,
    };
  });

await page.click('#tune');
console.log('t+0s  ', JSON.stringify(await state()));
await page.waitForTimeout(4000);
console.log('t+4s  ', JSON.stringify(await state()));
await page.waitForTimeout(8000);
const s = await state();
console.log('t+12s ', JSON.stringify(s));
await page.screenshot({ path: path.join(outdir, '02-set-on.png') });

// verdict
const playing = !s.paused && s.readyState >= 2 && s.currentTime > 0 && !s.error;
console.log(playing ? '\n✓ VIDEO PLAYING at ' + s.currentTime + 's' : '\n✗ VIDEO NOT PLAYING');

console.log('\nconsole output:');
for (const l of consoleLines.slice(0, 30)) console.log('  ' + l);

await browser.close();
process.exit(playing ? 0 : 1);
