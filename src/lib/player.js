/**
 * player.js — the reference Transmission player ("The Set").
 *
 * Broadcast rules, enforced here:
 *   · you join what is on, at the moment it is at — never from the top
 *   · there is no pause and no scrubbing; the LIVE point is the only point
 *   · drift is corrected quietly; two sets in two houses show the same frame
 */

import network from '../data/network.json';
import { resolve, upNext } from './broadcast.js';

const $ = (id) => document.getElementById(id);

const state = {
  channel: null,
  powered: false,
  transitionTimer: null,
  tickTimer: null,
  retryTimer: null,
  srcKey: null,
  driftAt: 0,
};

const els = {};

function fmt(sec) {
  sec = Math.max(0, Math.round(sec));
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  const mm = String(m).padStart(2, '0');
  const ss = String(s).padStart(2, '0');
  return h ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

function filmOf(block) {
  return network.films[block.type === 'film' ? block.film : block.next];
}

function nowOnLine(channel, at = Date.now()) {
  const r = resolve(channel, at);
  const film = filmOf(r.block);
  return r.block.type === 'film'
    ? `On air — ${film.title} (${film.year})`
    : `Station break — next: ${film.title}`;
}

/* ── the dial ── */

function paintDial() {
  const at = Date.now();
  for (const btn of els.dialButtons) {
    const ch = network.channels.find((c) => c.id === btn.dataset.channel);
    btn.setAttribute('aria-pressed', String(ch.id === state.channel.id));
    btn.querySelector('.dial-now').textContent = nowOnLine(ch, at);
  }
}

function setChannel(id, save = true) {
  state.channel = network.channels.find((c) => c.id === id) ?? network.channels[0];
  state.srcKey = null;
  els.chLabel.textContent = `CH ${state.channel.number} · ${state.channel.name}`;
  history.replaceState(null, '', `#${state.channel.number}`);
  if (save) try { localStorage.setItem('telecine:channel', state.channel.id); } catch {}
  paintDial();
  if (state.powered) sync();
  else els.tuneNow.textContent = nowOnLine(state.channel);
}

/* ── noise / signal states ── */

function noise(msg) {
  if (msg == null) {
    els.noise.hidden = true;
  } else {
    els.noise.hidden = false;
    els.noiseLabel.textContent = msg;
  }
}

/* ── the broadcast loop ── */

function sync() {
  clearTimeout(state.transitionTimer);
  const now = Date.now();
  const r = resolve(state.channel, now);
  if (r.block.type === 'film') showFilm(r);
  else showBreak(r);
  document.title = `CH ${state.channel.number} · ${filmOf(r.block).title} — Telecine`;
  state.transitionTimer = setTimeout(sync, r.blockEnd.getTime() - now + 300);
  paintDial();
}

function seekLive() {
  const r = resolve(state.channel, Date.now());
  if (r.block.type === 'film') els.screen.currentTime = r.offsetSec;
}

function showFilm(r) {
  const film = filmOf(r.block);
  els.card.hidden = true;
  els.onair.innerHTML = '';
  els.onair.append(
    Object.assign(document.createElement('em'), { textContent: film.title }),
    ` (${film.year}) · ${film.director}`
  );
  const nx = upNext(state.channel, Date.now());
  els.upnext.textContent = nx ? `Up next: ${network.films[nx.film].title} (${network.films[nx.film].year})` : '';
  els.total.textContent = fmt(r.block.durationSec);

  const key = `${state.channel.id}:${r.index}`;
  if (state.srcKey !== key) {
    state.srcKey = key;
    noise('TUNING');
    els.screen.src = r.block.src;
    els.screen.addEventListener(
      'loadedmetadata',
      () => {
        seekLive();
        els.screen.play().catch(() => noise('TAP THE SCREEN TO RESUME'));
      },
      { once: true }
    );
    els.screen.load();
  } else {
    seekLive();
    els.screen.play().catch(() => {});
  }
}

function showBreak(r) {
  const film = filmOf(r.block);
  els.screen.pause();
  els.screen.removeAttribute('src');
  state.srcKey = null;
  noise(null);
  els.cardNum.textContent = state.channel.number;
  els.cardName.textContent = state.channel.name;
  els.cardTitle.textContent = film.title;
  els.cardMeta.textContent = `${film.year} · ${film.director}`;
  els.card.hidden = false;
  els.onair.textContent = 'Station break';
  els.upnext.textContent = '';
  els.total.textContent = fmt(r.block.durationSec);
}

function tick() {
  if (!state.powered) {
    els.tuneNow.textContent = nowOnLine(state.channel);
    return;
  }
  const now = Date.now();
  const r = resolve(state.channel, now);
  els.elapsed.textContent = fmt(r.offsetSec);
  els.progFill.style.width = `${(r.offsetSec / r.block.durationSec) * 100}%`;
  if (!els.card.hidden) {
    els.cardCount.textContent = fmt((r.blockEnd.getTime() - now) / 1000);
  }
  // quiet drift correction, at most every 15s
  if (r.block.type === 'film' && els.screen.readyState >= 2 && now - state.driftAt > 15000) {
    state.driftAt = now;
    if (Math.abs(els.screen.currentTime - r.offsetSec) > 2.5) seekLive();
  }
}

/* ── power ── */

function powerOn() {
  state.powered = true;
  els.tune.hidden = true;
  els.cabinet.dataset.on = 'true';
  sync();
}

export function initPlayer() {
  Object.assign(els, {
    cabinet: $('cabinet'),
    screen: $('screen'),
    noise: $('noise'),
    noiseLabel: $('noise-label'),
    card: $('card'),
    cardNum: $('card-num'),
    cardName: $('card-name'),
    cardTitle: $('card-title'),
    cardMeta: $('card-meta'),
    cardCount: $('card-count'),
    tune: $('tune'),
    tuneNow: $('tune-now'),
    chLabel: $('ch-label'),
    onair: $('onair'),
    upnext: $('upnext'),
    elapsed: $('elapsed'),
    total: $('total'),
    progFill: $('prog-fill'),
    dialButtons: [...document.querySelectorAll('[data-channel]')],
  });

  // choose the opening channel: hash → memory → CH 01
  const byHash = network.channels.find((c) => `#${c.number}` === location.hash);
  let remembered = null;
  try { remembered = localStorage.getItem('telecine:channel'); } catch {}
  setChannel((byHash ?? network.channels.find((c) => c.id === remembered) ?? network.channels[0]).id, false);

  els.tune.addEventListener('click', powerOn);
  for (const btn of els.dialButtons) btn.addEventListener('click', () => setChannel(btn.dataset.channel));

  // broadcast discipline: no scrubbing — snap back to the LIVE point
  els.screen.addEventListener('seeking', () => {
    const r = resolve(state.channel, Date.now());
    if (r.block.type === 'film' && Math.abs(els.screen.currentTime - r.offsetSec) > 4) seekLive();
  });
  els.screen.addEventListener('waiting', () => noise('TUNING'));
  els.screen.addEventListener('playing', () => noise(null));
  els.screen.addEventListener('ended', sync);
  els.screen.addEventListener('click', () => els.screen.play().catch(() => {}));
  els.screen.addEventListener('error', () => {
    if (!state.powered) return;
    noise('SIGNAL LOST · RETRYING');
    clearTimeout(state.retryTimer);
    state.retryTimer = setTimeout(() => { state.srcKey = null; sync(); }, 8000);
  });

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && state.powered) sync();
  });

  // set-side switches
  $('mute').addEventListener('click', (e) => {
    els.screen.muted = !els.screen.muted;
    e.currentTarget.textContent = els.screen.muted ? 'SOUND OFF' : 'SOUND ON';
  });
  $('full').addEventListener('click', () => {
    const frame = $('screen-frame');
    if (document.fullscreenElement) document.exitFullscreen();
    else frame.requestFullscreen?.();
  });
  document.addEventListener('keydown', (e) => {
    if (e.target.closest('input, textarea')) return;
    const n = Number(e.key);
    if (n >= 1 && n <= network.channels.length) setChannel(network.channels[n - 1].id);
    if (e.key === 'm') $('mute').click();
    if (e.key === 'f') $('full').click();
  });

  state.tickTimer = setInterval(tick, 500);
  tick();
}
