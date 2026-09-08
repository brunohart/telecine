# Decisions

**ADR-001 — Native, and the television first.** A broadcast network belongs on the television. iOS and tvOS share one codebase; the cabinet is an iOS
construct, the full-bleed room is tvOS's. macOS and visionOS come from the same sources later.

**ADR-002 — The engine is a second implementation, held to the first.** `TelecineKit/Broadcast.swift`
re-implements `src/lib/broadcast.js` in Swift rather than embedding a JavaScript runtime. The two are
proven to agree by `ParityTests` against a fixture the reference cuts from the real network — every block
boundary and one millisecond either side, plus deterministic instants across six loops. A receiver that
disagrees with the site about what is on is not on the network.

**ADR-003 — The file ships inside the app and is refreshed from the head-end.** The set never needs the
network to know what is on. `public/network.json` is the head-end; the app validates a fresh file
(non-empty, every loop positive, every scheduled film described) before replacing the bundled one and
caches it. New seasons need no app update.

**ADR-004 — Federation is a URL.** Any Transmission or network file can be added as a station and sits on
the dial like ours, stamped *Affiliate*. This is the Affiliate tier's technical substrate and the spec's
promise ("publish a Transmission and you are a broadcaster") made true on the receiving end. A bare
Transmission may carry an inline `films` map — an additive v0.1 extension; clients ignoring it lose
nothing but titles.

**ADR-005 — No transport controls, anywhere.** A custom `AVPlayerLayer`, not `VideoPlayer` or
`AVPlayerViewController`, because both ship a scrubber. Seek, skip and position commands are disabled in
`MPRemoteCommandCenter`. Pause from the lock screen is "power off"; play is "power on and rejoin live".
The Siri Remote's play/pause is answered in words.

**ADR-006 — The licence gates nothing.** StoreKit 2 entitlements change a stamp, a plate inscription
and a credit-roll name. There is no code path in which a transaction unlocks content, and there will not
be; the network's freedom is stated on the licence itself.

**ADR-007 — Platform type.** New York and SF Mono rather than bundling Fraunces and IBM Plex Mono.
They scale with Dynamic Type for free and are the platform's own serif and mono. If brand parity with
the site is wanted later, the OFL files drop in via `UIAppFonts` and `Face` changes in one place.

**ADR-008 — No analytics, no account, no server.** The only network calls are the head-end refresh,
affiliate stations the viewer added, Archive prints, and Commons images. Nothing goes out about the viewer.

**ADR-009 — Widgets compute, they do not fetch.** The On Air widget's timeline is every block boundary
for six hours, computed from the bundled file. It is never wrong about the time and never needs a
background refresh budget.
