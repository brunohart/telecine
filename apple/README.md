# Telecine for Apple platforms

**A public broadcast receiver.** The same network as [telecine.vercel.app](https://telecine.vercel.app),
on iPhone, iPad and Apple TV — a television in a walnut cabinet on the phone; the picture *is* the room
on the TV. You don't press play. You tune in.

The app is one more receiver of the same [Transmission](../SPEC.md). It ships with the network's
schedule inside it, re-reads `https://telecine.vercel.app/network.json` at launch so new seasons arrive
without an App Store update, and can tune any other station published in the format.

## What's here

```
project.yml            xcodegen — Telecine (iOS), TelecineTV (tvOS), TelecineWidgets, TelecineTests
TelecineKit/           the engine: Transmission types, the resolver, the editorial graph, the bundled network
Telecine/              the app — Design (inks, faces, furniture, motion) · Set · Guide · Channels · Films · Licence · About
TelecineWidgets/       On Air — Home Screen and Lock Screen, timeline computed from the file, no network
TelecineTests/         the reference suite ported clause for clause, plus parity with src/lib/broadcast.js
Telecine.storekit      local StoreKit configuration for the Receiving Licence
scripts/               build.sh [tv] · test.sh · make-icon.swift
```

## Build

```bash
brew install xcodegen          # once
bash scripts/build.sh          # iOS Simulator
bash scripts/build.sh tv       # tvOS Simulator (needs the tvOS simulator runtime installed in Xcode)
bash scripts/test.sh           # 18 tests: the ported suite + 368 frozen resolutions + 16 windows
```

`scripts/test.sh` fails if the Swift engine disagrees with the JavaScript reference about any instant in
`TelecineTests/Fixtures/parity.json`. Regenerate that fixture with `node scripts/parity-fixture.mjs`
from the repo root whenever `network.json` is re-baked; the parity suite also checks the fixture and
the bundled network were cut from the same bake.

## Broadcast rules the receiver enforces

- You join what is on, at the moment it is at. Never from the top.
- No pause, no scrubbing: the remote's play/pause key answers *"A broadcast does not pause. Rejoining live."*
  Lock-screen pause switches the set off; play switches it on and rejoins live.
- Drift is corrected quietly every fifteen seconds beyond ±2.5 s; two sets in two houses show the same frame.
- The next reel pre-buffers behind the station-break card. If a print stalls the set says TUNING; if the
  signal is lost it says so and retries. It never pretends.

## The Receiving Licence

Free to watch, permanently — stated in the app and in the code. The licence (an annual subscription,
or a one-time Founding Patron) gates nothing; it stamps the document, puts a name in the credit roll,
and funds the programming. Products are loaded through StoreKit 2; with none configured the office
"opens with Season Two". Family Sharing is on for both.

## Privacy

No accounts, no analytics, no tracking. The app keeps on-device: the channel you left it on, the
addresses of stations you added, a cached copy of the schedule, and the name you typed on the licence.
