# The Transmission Format — v0.1

**A television station as a file.**

A *Transmission* is a complete definition of a linear broadcast channel: a fixed
epoch and an ordered list of blocks that loop forever. Any client that can read
a clock can tune in — and every client that reads the same Transmission at the
same moment shows the same frame. There is no server. The schedule *is* the
broadcast.

This is the format Telecine's channels are written in. It is deliberately small,
deliberately open, and hostable by anyone: publish a Transmission file and a
player, and you are a broadcaster.

## The format

A Transmission is a JSON document:

```json
{
  "transmission": "0.1",
  "id": "noir-after-dark",
  "name": "Noir After Dark",
  "epoch": "2026-07-01T00:00:00Z",
  "blocks": [
    { "type": "interstitial", "next": "detour-1945", "durationSec": 90 },
    {
      "type": "film",
      "film": "detour-1945",
      "durationSec": 4075,
      "src": "https://archive.org/download/Detour_movie/Detour.mp4"
    }
  ]
}
```

### Fields

| Field | Type | Meaning |
|---|---|---|
| `transmission` | string | Spec version. Currently `"0.1"`. |
| `id` | string | Stable channel identifier (URL-safe). |
| `name` | string | Display name. |
| `epoch` | ISO 8601 string | The instant block 0 began. Any moment in the past. The broadcast is defined for all time — before the epoch, the schedule extends backwards (the loop is congruent). |
| `blocks` | array | The loop, in order. Total duration = one loop. |

### Blocks

Every block has a `type` and an exact `durationSec` (integer seconds).

- **`film`** — `film` (a stable slug), `src` (a direct video URL that honours
  HTTP `Range` requests), `durationSec` (the *exact* duration of that file,
  to the second — the schedule's arithmetic depends on it).
- **`interstitial`** — a station break rendered by the client (a card, a
  countdown, a test pattern — the spec does not care how). `next` names the
  film block it precedes.

Clients MUST treat block boundaries as half-open intervals: the instant a block
ends belongs to the next block.

## Resolution

Given a Transmission `T` and a wall-clock instant `t`:

```
loop  = Σ durationSec over T.blocks
into  = ((t − T.epoch) mod loop + loop) mod loop      // seconds, always ≥ 0
```

Walk the blocks accumulating durations; the block containing `into` is on air,
and `into − cumulativeStart` is the playback offset to seek to.

That is the whole protocol. A reference implementation — `resolve`,
`airingsBetween`, `nextAiring`, `upNext` — lives in
[`src/lib/broadcast.js`](./src/lib/broadcast.js) (pure functions, no
dependencies, identical in Node and the browser) with its test suite in
[`test/broadcast.test.mjs`](./test/broadcast.test.mjs).

## Properties that fall out of the design

- **Synchrony without infrastructure.** Every viewer computes the same answer
  from the same file and the same clock. A static host is a television station.
- **The schedule is inspectable.** A channel is diffable, versionable,
  forkable — curation with provenance, in version control.
- **Graceful drift.** Clients periodically re-resolve and reseek if playback
  drifts beyond tolerance (the reference player uses ±2 s). Clock skew between
  viewers is bounded by their system clocks, which NTP keeps within fractions
  of a second.
- **No pause.** Not a limitation — the point. A broadcast is a shared present
  tense.

## Versioning

Breaking changes bump the `transmission` version. Additive metadata (per-block
or per-channel) is permitted at any time; clients ignore fields they do not
understand.
