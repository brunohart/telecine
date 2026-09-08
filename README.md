# TELECINE

**A public broadcast network for public-domain cinema.**

Four channels. Twenty-four hours a day. Every film chosen by hand, every viewer
on Earth seeing the same frame at the same moment. You don't press play — you
tune in.

**Live:** [telecine.vercel.app](https://telecine.vercel.app)

## What this is

Streaming solved access and dissolved occasion. Telecine restores the shared
clock: a linear broadcast of the public domain's masterpieces — Murnau, Keaton,
Lang, Lupino, Welles, Romero — programmed in hand-set rotations with written
programme notes, wrapped in the design language of a printed TV guide.

- **CH 01 · The Silent Signal** — cinema before it spoke
- **CH 02 · Noir After Dark** — the night shift of the American picture
- **CH 03 · The Haunted Screen** — what the dark does with an audience
- **CH 04 · The Matinee** — fast talk, slow afternoons

No accounts. No tracking. No algorithm. No pause button — on purpose.

## The trick

There is no streaming server. Each channel is a **[Transmission](./SPEC.md)**:
a small open file declaring an epoch and a loop of films and station breaks.
The player reads the file and the clock, computes *what is on and how far in*,
and seeks into a public-domain print held by the
[Internet Archive](https://archive.org) via HTTP range requests. Every client
performs the same arithmetic against the same clock, so every client shows the
same frame.

**A static site is a television station.** The schedule *is* the broadcast.

```
loop  = Σ block durations
into  = ((now − epoch) mod loop + loop) mod loop
→ walk blocks; the one containing `into` is on air; the remainder is the seek offset
```

The reference resolver is [`src/lib/broadcast.js`](./src/lib/broadcast.js) —
pure functions, zero dependencies, identical in Node and the browser — with
tests in [`test/`](./test). The format is documented in [`SPEC.md`](./SPEC.md);
publish a Transmission file and a player, and you are a broadcaster too.

## The receiver for Apple platforms

The same network, native on iPhone, iPad and Apple TV — a television in a walnut cabinet on the
phone; the picture *is* the room on the TV. It ships with the schedule inside it, re-reads
[`/network.json`](https://telecine.vercel.app/network.json) (the head-end) at launch, and can tune
any other station published in the Transmission format. The Swift engine is proven identical to the
JavaScript reference by a frozen parity fixture. See [`apple/`](./apple/README.md), its
[design](./apple/DESIGN.md) and [decisions](./apple/DECISIONS.md).

## Architecture

```
data/candidates.json    the catalogue: films, channels, runtime windows
data/programme.json     the editorial layer: channel identities + programme notes
scripts/verify.mjs      proves every film against archive.org (identifier,
                        title, duration, byte-range support) → data/verified.json
scripts/build-channels.mjs  bakes src/data/network.json — refuses unverified films
src/lib/broadcast.js    the Transmission resolver (the whole protocol)
src/lib/player.js       the reference player: joins live, corrects drift,
                        renders station breaks, forbids scrubbing
src/pages/              Astro static site: the Set, the Guide, channels, films
public/network.json     the head-end: the baked network, published for every receiver
apple/                  the native receiver (SwiftUI, iOS + tvOS) and its parity tests
```

```bash
npm install
npm run verify   # re-verify the catalogue against archive.org
npm run bake     # regenerate network.json
npm test         # broadcast engine tests
node scripts/parity-fixture.mjs   # freeze the reference's answers for the Swift engine
npm run dev      # local station
npm run build    # tests + static build → dist/
```

## Licensing

- **Code** — [MIT](./LICENSE).
- **Programme notes & channel copy** — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).
- **The films** — public domain. They belong to everyone, including you.
  They are served from prints preserved by the Internet Archive —
  [support them](https://archive.org/donate).

---

Telecine is a [designedbybruno](https://designedbybruno.net) production.
