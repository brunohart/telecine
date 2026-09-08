# Design

One intent, then rules. The constraints come from the web set, which this app carries across whole.

## The intent

**A television, not a video player.** On the phone the set is an object: a walnut cabinet with a
curved-glass tube, a backlit display window, a lit tuning slit, keys with travel, a ridged bakelite
power knob, a jewel LIVE lamp, a punched speaker grille and an engraved maker's plate. On Apple TV the
cabinet disappears because the room already has one; the picture is full-bleed and the fascia
appears only when you touch the remote. The paper pages — the guide, the channels, the notes, the
licence — are a printed programme: letterpress serif, mono numerals, test-card bars, grain, rubber stamps,
objects that sit a fraction off level.

## Rules that follow

1. **Everything you press has travel.** Keys drop two points and lose their shadow; presets stay down with
   their lamp lit; the knob turns under your thumb. One spring family (`Motion`), tuned by feel, overshoots
   once and settles. Channel changes get a burst of static, because a real broadcast never cuts clean.
2. **The set is always the dark room.** Its inks are fixed (`Ink.Room`). The paper pages follow the
   system appearance — paper by day, the lights down by night — through dynamic colours.
3. **Type is the platform's own.** New York for display and body (the site sets Fraunces), SF Mono for
   labels and numerals. Everything scales with Dynamic Type except the engraved readouts on the fascia,
   which are engraved.
4. **Mono is a labelling system.** Uppercase, wide-tracked, small. Never decoration.
5. **Character enters only where it earns its place**: the misregistered wordmark, the bars, the stamps,
   the grain, the tilt of a one-sheet and a licence document. Not on chrome.
6. **Honest machinery.** TUNING when a print stalls. SIGNAL LOST · RETRYING when it fails. "A broadcast
   does not pause." when the remote asks it to. The About page says where the schedule came from.
7. **Respect the platform.** Reduce Motion removes tilt, overshoot, the burst and the breathing countdown.
   VoiceOver reads the set as one element ("On air: Detour, 1945, Edgar G. Ulmer") and every listing as a
   sentence. Touch targets are 44pt. Haptics punctuate the dial and the stamp; they do not decorate.
8. **When in doubt, remove.** Nothing on the fascia that a television did not have.

## Inks

| Token | Hex | Use |
|---|---|---|
| paper / room paper | `#F1EBDF` / `#12100D` | the page, the room |
| ink / room ink | `#1D1812` / `#EDE5D4` | words |
| signal | `#C24A1F` | the ghost, the filament, CH 04, the full stop |
| tube | `#1B2D4F` | CH 01, offset shadows |
| bottle | `#2F4A3A` | CH 03 |
| brass | `#A3762A` | affiliates, the fourth bar |
| live | `#B23315` | the lamp, ON AIR, the stamp |
| display dim / lit | `#B98A54` / `#E3B079` | readouts behind dark glass |

## What this is not

Glass over the picture. A scrubber. A transport bar. A thumbnail grid. A dark-mode SaaS. Motion for its
own sake. A tracked-out label where a sentence would do.
