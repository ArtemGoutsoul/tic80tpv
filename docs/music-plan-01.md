# Music plan — Total Perspective Vortex demo

The soundtrack for the TPV demo. Composed in code: the song in
[`music01.lua`](../music01.lua), played by the reusable
[`tracker.lua`](../tracker.lua) synth+tracker engine (see the `music-in-code` and
`tic80-sound` skills).

## Concept

The Vortex is built by **extrapolating the entire universe from a single piece
of fairy cake**. So is the music: one small **seed motif** in the intro, from
which every later layer (bass, arps, breakbeat, lead theme) is grown. Simple →
overwhelming → the tiny "you are here" dot → a cheeky wink. The rising
complexity/energy is thematic, not just "add more stuff".

## Locked decisions

1. **Ending: cheeky** — Zaphod survives the Vortex, ego intact. The demo ends on
   a triumphant chiptune fanfare and a smile, not annihilation.
2. **Harmony: modulate** — mostly A minor; lift **+2 semitones (B minor)** for
   the grandeur of *Vastness* and *Total Perspective*, resolve back for the outro.
3. **Easter eggs: leaned into.**
   - **42** — *Total Perspective* (the "see the whole universe" climax) is
     exactly **42 bars** long. The Answer.
   - **DON'T PANIC** — the deliberately calm, un-panicked intro.
   - **"You are here"** — the comedown is the seed motif's single note, alone.
   - **4–2 rhythm** — the Zaphod outro's fill is four kicks then two snares.

## Style & tempo

- **Chiptune × drum-and-bass.** 180 BPM (framesPerStep = 5), 16-step bars
  (1 bar ≈ 1.33 s). Half-time feel (snare on the "3") in calm sections; full amen
  breakbeat with rolls in the drops.
- **Key:** A natural minor. Progression vamp **Am – F – C – G** (i–VI–III–VII)
  over 2 bars. Transposed +2 → **Bm – G – D – A** in the modulated sections.
- **Seed motif:** `a4 · c5 · e5 · d5` (Am with a leaning D). Recurs and grows.

## Channels

| Ch | Role | Calm | Drops |
|----|------|------|-------|
| 0 | Bass | clean triangle sub | gnarly detuned-saw **reese** |
| 1 | Lead | sparse **PWM** seed | soaring PWM theme |
| 2 | Arp | sparse, follows chords | fast cascading arps (= chords) |
| 3 | Drums | half-time / heartbeat | full **amen** + rolls + fills |

## Arrangement (≈2:32, 114 bars)

Part numbers match the running UI (1-based).

| Part | Section | Bars | ~Start | Beat | Energy |
|------|---------|------|--------|------|--------|
| 1 | **Fairy Cake** | 12 | 0:00 | DON'T PANIC — the seed alone, huge space | ▁ |
| 2 | **Extrapolation** | 12 | 0:16 | machine starts: sub + half-time break + arp fade-in | ▂ |
| 3 | **The Universe Unfolds** | 14 | 0:32 | full break drops, reese, lead states the theme | ▅ |
| 4 | **Vastness** | 12 | 0:50 | drums back, spacious, **key +2**, cosmic grandeur | ▃ |
| 5 | **Total Perspective** | **42** | 1:06 | everything at once, max complexity — **the Answer** | ▇ |
| 6 | **"You Are Here"** | 8 | 2:02 | cut to one lonely bleep, vast emptiness | ▁ |
| 7 | **Zaphod Wins** | 14 | 2:13 | cheeky triumphant fanfare, 4–2 fill, loops to seed | ▆ |

## Composition model (revised)

Inspired by Rift's *Verisimilitude* (see
[docs/synth-inspiration-from-verisimilitude.md](synth-inspiration-from-verisimilitude.md)),
the song is **one flat `tune`, row by row** — no `PATTERNS`/`ARRANGEMENT`
abstraction:

- **Melody** is written explicitly, one cell per channel (positional columns
  `{ ch0, ch1, ch2, drums }`). A cell is `{}` (hold), `{INST, "note", vol, cutoff}`,
  `{OFF}`, or `{STOP}`.
- **Drums** are named looping patterns (mini-notation strings: `HALF`, `AMEN`,
  `FILL`, …) started/stopped from the drums column: `{AMEN}` starts, `{OFF}`
  stops, `{}` keeps looping.
- **Instruments are named constants** (`BASS`, `LEAD`, `ARP`, `PAD`), not numbers.
- **Parts** are inline markers: attach `part="Name"` / `transpose=N` to a row.
  The engine scans them to drive the readout, the progress bar, and Left/Right
  (or clicking a block) to **skip between parts**.

## Synth (revised)

Each channel is a small subtractive voice: oscillator → **live two-pole low-pass
filter** (cutoff by envelope + LFO, per-note cutoff override) → registers, still
rewritten every frame. Waveforms include fattened `hsaw`/`hsine`/`hsquare`
(fundamental + 3rd-harmonic mix). Modulation available per instrument: volume
ADSR, cutoff env+LFO, pitch vibrato/env, PWM duty sweep, reese detune.

## Status

Draft 1 engine + a first-pass **sketch tune** (~6 parts, 1 bar each) that
exercises every feature. Everything is tunable from the tables at the top of the
cart; we flesh out and refine section by section **by ear**.
