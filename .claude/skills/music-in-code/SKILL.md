---
name: music-in-code
description: >-
  Compose and edit the Total Perspective Vortex soundtrack with the reusable
  code-synth engine, split across `tracker.lua` (the synth + sequencer lib),
  `music01.lua` (the song), and `music-tester.lua` (the debug player cart). Covers
  the flat row-by-row `tune` (positional columns per channel), note cells, the
  `Tracker.*` API (instruments, drum loops, sentinels, timing accessors),
  part/transpose markers, the whole-bar invariants that keep drums locked, the
  BPM/row math, how to run with `require`, and how to drive a demo off the music
  clock. Use this to WRITE MUSIC; use `tic80-sound` to edit the synth ENGINE.
  Trigger words: write music, compose, edit the tune, add a part, bassline,
  melody, drum loop, arrangement, transpose, soundtrack, TPV music, tracker,
  music01.lua, add an instrument, sync music to visuals.
---

# Writing music with the TPV code-synth

The soundtrack engine is split into a **reusable library + a song + player carts**
so the same music can run in a debug player and in the demo:

| File | What | Kind |
|---|---|---|
| **`tracker.lua`** | the synth + sequencer engine; sets a global `Tracker`. No song data, no UI. | lib (`require`d) |
| **`music01.lua`** | the song — instruments, drum loops, the `tune`; calls `Tracker.setSong`. | lib (`require`d) |
| **`music-tester.lua`** | debug player cart: mute switches, part skipping, readout. | cart (`TIC()`) |
| **`tpv.lua`** | the demo cart; drives visuals off the music clock. | cart (`TIC()`) |

**Song files are versioned** — `music01.lua`, `music02.lua`, … Keep old
iterations for reference/inspiration; the player carts pick the current one via
`require` (e.g. `require "music01"`). To start a new iteration, copy the latest to
the next number and update the `require` in `music-tester.lua` (and `tpv.lua`).

This skill is about **writing the song** (edit the current `musicNN.lua`). To
change *how a voice sounds* — the filter, envelopes, register pokes — edit
`tracker.lua` and see the **`tic80-sound`** skill. Song plan lives in
[`docs/music-plan.md`](../../../docs/music-plan.md).

## Running the tester

`require` needs the project folder as the TIC-80 filesystem (`--fs`):

```powershell
Start-Process -FilePath "C:\dev\tic80\tic80.exe" `
  -ArgumentList 'music-tester.lua --fs C:\dev\tic80\test2 --cmd=run' `
  -WorkingDirectory "C:\dev\tic80\test2"
```

Both `music-tester.lua` and `tpv.lua` set `package.path = package.path ..
";C:/dev/tic80/test2/?.lua"` so `require "tracker"` / `require "music01"` resolve.
(No build step yet — we amalgamate into one file only when packaging to ship.)

## The tune — one flat table, row by row (in `music01.lua`)

`Tracker.setSong(tune)` takes a flat list. **Each row is one 1/16 step** with four
positional cells — one per channel:

```lua
{ ch0_bass, ch1_lead, ch2_arp, ch3_drums }
```

Each cell is a table:

| Cell | Meaning |
|---|---|
| `{}` | **no change** — a held note keeps ringing / the drum loop keeps looping |
| `{INST, "note", vol, cutoff}` | trigger a note. `vol` & `cutoff` optional, `0..1` |
| `{OFF}` | note-off (release) · in the **drums** column: stop the loop |
| `{STOP}` | hard cut |
| `{LOOP}` | **drums column only** — start / switch to a drum loop |

- `OFF`/`STOP` are `Tracker.OFF` / `Tracker.STOP` (alias them locally: `local OFF = Tracker.OFF`).
- **Notes** are `"a2"`, `"c5"`, `"a#3"`, `"b-2"` (letter + optional `#`/`-` + octave).
- **Instruments / drum loops** are the handles returned by `Tracker.instrument` /
  `Tracker.drumLoop` — used directly in cells: `{BASS,"a2"}`, `{AMEN}`.
- **Trailing empty columns can be omitted**: `{ {BASS,"a2"} }` == `{ {BASS,"a2"},{},{},{} }`.
- The 3rd/4th values scale that note's **volume** and set its **filter cutoff**
  (0 dark … 1 open), overriding the instrument — write filter movement into the score.

## Parts & transpose

Attach `part="Name"` and/or `transpose=N` (semitones) to any row as **named keys**
(put them on the part's first row — they cost no time). They drive the readout,
the progress bar, Left/Right skip, and modulation.

```lua
{ {PAD,"a3"}, {LEAD,"a4"}, {OFF}, {HALF}, part = "Vastness", transpose = 2 },
```

## Instruments & drum loops (the `Tracker.*` builders)

```lua
local WAVE = Tracker.WAVE
local PLUCK = Tracker.instrument{
    wave = WAVE.TRIANGLE,                 -- SQUARE/PULSE/SAW/TRIANGLE/SINE/NOISE, HSAW/HSINE/HSQUARE
    peak = 9, sustain = 4,                -- volume ADSR levels (0..15)
    attack = 2, decay = 8, release = 8,   -- ...times in frames
    gate = 6,                             -- auto note-off after N frames (nil = ring)
    cutoff = 0.6,                         -- base filter cutoff (nil/1 = open)
    cutoffEnv = { attack=1, decay=10, sustain=0.3, release=6, amp=0.4 },  -- opens the filter
    -- optional: cutoffLfo={rate,depth}, pwm/pwmRate/pwmDepth, reeseDetune, vibratoDepth/vibratoRate, pitchEnv
}

local BREAK = Tracker.drumLoop("BREAK", "k . h s . h k h . k s . h s . h")
```

Drum-loop mini-notation: `k`/`s`/`h` hits, `.`/`~` rest, `-` hold, `[a b]`
sub-step rolls, `x*n` repeat. Default kit is `k`/`s`/`h`; override with
`Tracker.setDrum(atom, def)`. Add a custom waveform with `Tracker.wave(name, samples)`.

## The two invariants (the engine warns at load — press backtick)

1. **Every drum loop is a whole bar (16 steps)** — or a clean divisor. A 1-bar
   loop re-locks to the downbeat every bar, so it can't drift. Anything else
   (15, 24 steps) slips.
2. **Every part spans a whole number of bars** (multiple of 16 rows), else the
   next part's downbeat lands mid-loop and the groove shifts.

If the beat ever "shifts" or "speeds up," check these first. (Perceived speed
changes are almost always **density** — 8th vs 16th arps, `AMEN` vs `FILL` rolls —
tempo is globally fixed.)

## Timing / length

Tempo is **global** (one `STEP_FRAMES = 5` in `tracker.lua`) → **180 BPM**. Math:
**12 rows/second**; 16 rows = 1 bar ≈ 1.33 s; a beat = 4 rows; **~1,800 rows ≈
112 bars ≈ 2.5 min**. To retempo globally, `Tracker.configure{ stepFrames = N }`
before `setSong` (bigger = slower).

The `tune` is chunked into 32-row (2-bar) parts with `######` headers, each split
into labelled 16-row bars by blank lines — keep that when extending.

## Driving a demo off the music clock (`tpv.lua`)

The demo uses the **tiny** interface — play + read the clock to time visuals:

```lua
package.path = package.path .. ";C:/dev/tic80/test2/?.lua"
require "tracker"; require "music01"

function TIC()
    Tracker.update()                       -- advance + play (call once per frame)
    local row = Tracker.row()              -- current step id (0-based) -- master keyframe clock
    local prog = Tracker.stepProgress()    -- fractional row, for smooth interpolation
    local beat, bar = Tracker.beat(), Tracker.bar()
    local part = Tracker.partAt(Tracker.currentPartIndex()).name
    local kick = Tracker.channelLevel(3)   -- 0..15 live volume -- audio-reactive visuals
    -- ...draw effects keyed to row / beat / part / kick...
end
```

Full accessor list (all read-only): `row()`, `rowCount()`, `stepProgress()`,
`frameInStepValue()`, `beat()`, `bar()`, `transpose()`, `partCount()`,
`partAt(i)` → `{name,row,transpose}`, `partBars(i)`, `currentPartIndex()`,
`bpm()`, `stepsPerBar()`, `channelCount()`, `channelLevel(c)`. Navigation/UI:
`jumpToPart(i)`, `toggleMute(c)`, `isMuted(c)`, `Tracker.parts` (list).

## Controls (in the tester)

- **Left / Right** — previous / next part · **click a progress block** — jump there.
- **Click a channel row** — mute / unmute (audition one lane while composing).

## Workflow & verifying

Edit `music01.lua`, run the tester, and **confirm it compiles + advances** — you
can't judge the *sound* from an automated session. Watch the TIC-80 console
(backtick) for the whole-bar guard warnings. Final musical judgement is **by
ear, by the user** — say so.

1. Launch as above; wait ~5 s; screenshot (**`tic80-screenshot`** skill) — no red
   error screen, readout shows the right part/BPM.
2. Hand back to the user to listen and steer.

## Related

- **`tic80-sound`** — how the synth works; edit `tracker.lua` with it.
- **`tic80-screenshot`** — grab the running window.
- [`docs/music-plan.md`](../../../docs/music-plan.md) · [`docs/synth-inspiration-from-verisimilitude.md`](../../../docs/synth-inspiration-from-verisimilitude.md)
