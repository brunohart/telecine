#!/usr/bin/env node
/** qa-visual.mjs — screenshot every surface for design review. */
import { chromium } from 'playwright-core';
import path from 'node:path';

const base = process.argv[2] ?? 'http://localhost:4321';
const outdir = process.argv[3] ?? '/tmp/telecine-qa';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
page.on('pageerror', (e) => console.log('[pageerror]', e.message));

const shot = (name) => page.screenshot({ path: path.join(outdir, name + '.png') });

// the set, off
await page.goto(base + '/', { waitUntil: 'networkidle' });
await page.waitForTimeout(800);
await shot('10-set-off');

// tune in, let it play
await page.click('#tune');
await page.waitForTimeout(6000);
await shot('11-set-on');

// switch channel (dial button 2) — catch the burst mid-flight then settled
const dial = page.locator('[data-channel]').nth(1);
await dial.click();
await page.waitForTimeout(120);
await shot('12-channel-burst');
await page.waitForTimeout(6000);
await shot('13-channel-2');

// playback state verdict
const s = await page.evaluate(() => {
  const v = document.getElementById('screen');
  return { readyState: v.readyState, t: Math.round(v.currentTime), paused: v.paused, muted: v.muted, err: v.error?.code ?? null };
});
console.log('player state after switch:', JSON.stringify(s));

// other surfaces
for (const [file, url] of [
  ['20-guide', '/guide'],
  ['21-channels', '/channels'],
  ['22-channel-noir', '/channels/noir-after-dark'],
  ['23-film-detour', '/films/detour-1945'],
  ['24-about', '/about'],
  ['25-patrons', '/patrons'],
]) {
  await page.goto(base + url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1100); // let the settle choreography finish
  await shot(file);
}

await browser.close();
console.log('screenshots →', outdir);
