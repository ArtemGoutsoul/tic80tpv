---
name: tic80-sound
description: >-
  How sound works on TIC-80 and how to drive it from code: the fixed 4-channel
  wavetable model, the sfx()/music() API, poking instrument RAM and the raw
  sound registers at 0xFF9C, note/frequency math, and the register-level synth
  building blocks (compute-your-own envelopes, a live wavetable low-pass filter,
  PWM, reese, synthesized drums) that our code synth is built from. Use this to
  understand or EDIT THE SYNTH ENGINE; to write the actual song, use the
  `music-in-code` skill. Trigger words: tic80 sound, how sound works, sfx,
  waveform, sound registers, poke 0xFF9C, synthesizer, envelope, filter, cutoff,
  noise, note frequency, chiptune, edit the synth engine.
---

# How TIC-80 sound works (and driving it from code)

A reference for TIC-80 audio **from Lua** — the machine model, the API, and the
register-level synthesis techniques our engine is built on. This is what you need
to **understand or edit the synth engine** in `tracker.lua` (the reusable synth +
sequencer lib). To **write the song** (notes, drum loops, arrangement), use the
**`music-in-code`** skill instead.

Environment: Windows native, PowerShell tool preferred; run carts with
`Start-Process` (see project `CLAUDE.md` "Launching from an automated shell").

## The one constraint that shapes everything

TIC-80 has **no raw PCM/sample output**. You cannot hand it an audio buffer.
The chip is a **fixed 4-channel wavetable synth + LFSR noise**:

- **4 channels** (0–3). Each plays one 32-step, 4-bit **waveform** at a given
  **12-bit frequency** and **4-bit volume**.
- **16 shared waveforms** (32 nibbles each). A waveform that is all-`0` or all-`F`
  plays as **noise** (white, then periodic) instead of a tone.
- Everything else — envelopes, arpeggios, vibrato, pitch slides, filters — is
  either a feature of the **SFX** layer or something **you compute yourself** per
  tick.

So "program a synthesizer" in TIC-80 means one of two things:
1. **Drive the built-in synth** via `sfx()` (reuse its envelopes/effects), or
2. **Be the synth**: write each channel's frequency/volume/waveform registers
   yourself every frame (`poke` at `0x0FF9C`). ← *our engine does this.*

There is no third "emit samples" option. (PCM "playback" carts fake it by
streaming bytes into the waveform register at a few kHz — a size-coding trick.)

## Field notes (hard-won, verified in this project — read first)

1. **A text cart with no `<PALETTE>` section loads an all-black palette** — every
   `cls`/`print`/`rect` draws black. Symptom: black screen *with working sound*.
   Always include a palette (see "Two gotchas").
2. **When driving the registers, rewrite the WAVEFORM every frame.** TIC-80 clears
   the waveform registers each tick; a waveform set once decays to all-zero next
   frame = **noise**. Pitch/volume (rewritten each frame) still look right, so only
   the *timbre* breaks — every pitched voice quietly turns to noise. (See level 3.)
3. **The 12-bit frequency register value ≈ the output pitch in Hz** — poke
   `round(440 * 2^((midi-69)/12))`. Relative tuning is exact; verify absolute pitch
   by ear.
4. **A low sawtooth is buzzy/gritty** (energy in every harmonic); use
   `triangle`/`sine` for a clean sub, `saw`/`hsaw` deliberately for a reese, or run
   it through the low-pass filter (below).
5. **You cannot screenshot sound.** Pitch/timbre correctness can't be seen — an
   on-screen register readback (`peek`) confirms what the synth *reads*; final
   judgement is **by ear**.

## Three levels of control

| Level | You call | You control | Use when |
|---|---|---|---|
| **1. API** | `sfx(id, note, dur, chan, vol, spd)` / `music(...)` | which instrument + note plays | musicality with least code |
| **2. Instrument RAM** | `poke` the WAVES (`0x0FFE4`) / SFX (`0x100E4`) | instrument definitions, from code | instruments in code, no editor |
| **3. Sound registers** | `poke` at `0x0FF9C` every tick | raw freq / volume / waveform per channel | a fully custom synth (**our engine**) |

## Level 1 — the API

### `sfx(id, [note=-1], [duration=-1], [channel=0], [volume=15], [speed=0])`

- **id** `0..63` (which SFX), or `-1` to stop (`sfx(-1, nil, nil, ch)` stops `ch`).
- **note** integer `0..95` **or** a string `"D-4"` / `"C#3"` (UPPER-CASE, `-`=natural
  or `#`=sharp, one octave digit `0..8`; no flats). `-1` = reuse last note.
- **duration** in ticks (60/sec); `-1` = until stopped/retriggered.
- **channel** `0..3`. **volume** `0..15`. **speed** `-4..3`.

```lua
if t % 30 == 0 then sfx(0, "D-4", 20, 1, 10) end
```

### `music([track=-1], [frame=-1], [row=-1], [loop=true], [sustain=false], ...)`

Plays a track from the Music Editor. **Gotcha:** `music(0)` inside `TIC()`
restarts it 60×/sec — guard with a `started` flag. `music()` with no args stops.
For **code-composed** songs, don't use this — drive the registers (level 3).

## Level 2 — waveforms (easy)

WAVES are the one instrument component trivial to define in code — 16 slots of 32
nibbles at `0x0FFE4`:

```lua
local function setWave(slot, samples)          -- samples: 32 values 0..15
  for i = 0, 31 do poke4(0xFFE4 * 2 + slot * 32 + i, samples[i + 1]) end
end
```

Build `square`/`pulse`/`saw`/`triangle`/`sine` tables in Lua. **Harmonic
enrichment (`mixWave`):** blend a wave with a 3×-frequency copy of itself for a
fatter timbre than a single cycle — `hsaw = mix(saw(1), saw(3), .8, .4)`. Our
engine builds all of these at load.

## Level 3 — the sound registers (the real synth)

RAM map (from `tic80wiki/RAM.md`):

```
0x0FF9C SOUND REGISTERS  72 bytes = 4 channels × 18 bytes
        per channel: frequency 12-bit + volume 4-bit (2 bytes), then waveform 32×4-bit (16 bytes)
0x0FFE4 WAVEFORMS        256 bytes = 16 waveforms × 32 nibbles
0x100E4 SFX             4224 bytes = 64 SFX × 66 bytes (bit-packed; see RAM.md)
```

### Addressing a channel `c` (0–3)

```lua
local base = 0xFF9C + 18 * c     -- c0=65436, c1=65454, c2=65472, c3=65490
poke(base,     freq & 0xFF)                                  -- low 8 bits of freq
poke(base + 1, ((freq >> 8) & 0x0F) | ((vol & 0x0F) << 4))   -- hi 4 bits + volume
for i = 0, 31 do poke4((base + 2) * 2 + i, wave[i]) end       -- 32 nibbles, each 0..15
```

Read back: `v = peek(base+1)<<8 | peek(base); freq = v & 0x0FFF; vol = (v & 0xF000)>>12`.

### Note → frequency

The 12-bit register value **is the output pitch in Hz**:

```lua
local function noteHz(midi) return 440 * 2 ^ ((midi - 69) / 12) end  -- A4(69)=440, C4(60)≈262
-- poke round(noteHz(midi)) as freq. Register is 12-bit (max 4095 ≈ C8).
```

Parse `"c#4"`-style names: `midi = (octave + 1) * 12 + semitone`, where
`semitone` uses `C=0,D=2,E=4,F=5,G=7,A=9,B=11`, `+1` for `#`, `-1` for `-`(flat).

### Silence / noise

- Silence a channel: poke `base+1` with `vol = 0` (every frame).
- Noise: fill the waveform with all `0x0` (white) or all `0xF` (periodic).

### Gotchas (level 3)

- **Poke every frame — INCLUDING the waveform** (field note #2). The single most
  common "why is everything noise" bug.
- Don't mix `sfx()`/`music()` on a channel you're register-driving — they fight
  over the same registers.
- Envelope, vibrato, arpeggio, slide, **filter** are yours to compute (track
  "frames since note-on" per channel and derive volume/pitch/timbre from it).

## Register-level synth building blocks (what our engine is made of)

Because you rebuild freq + waveform every frame anyway, rich voices are cheap.
These are the techniques in `tracker.lua` — edit there:

- **Compute-your-own ADSR** — from `age` (frames since note-on) and `releaseAge`,
  return a volume `0..15` (attack ramp → decay to sustain → release ramp). A
  normalized `0..1` version drives cutoff/pitch too. An optional `gate` auto-fires
  note-off after N frames.
- **Live wavetable low-pass filter** (the reese/pad "breath"). Run a **two-pole RC
  low-pass over the 32-sample wavetable each frame**, wrapping circularly so the
  cycle stays seamless (`alpha = cutoff/(1+cutoff)`, two passes; `cutoff >= 1`
  bypasses). Drive `cutoff` from a base value + envelope + LFO (both *open* the
  filter). This is the ported `dlr` idea — see
  [`docs/synth-inspiration-from-verisimilitude.md`](../../../docs/synth-inspiration-from-verisimilitude.md).
- **PWM lead** — regenerate a *pulse* waveform each frame with a duty swept by a
  slow LFO (`duty = 0.5 + sin(clock/60*rate*TAU)*depth`, clamp ~0.1–0.9 so it
  never hits all-0/all-15 = noise). Use a **free-running** clock, not per-note age,
  so the sweep is continuous across notes.
- **Reese / detuned bass** — fake two detuned oscillators on one channel by
  alternating the frequency each frame between the note and `hz*(1+detune)` on odd
  frames (`detune ≈ 0.02–0.04`). On `saw`/`hsaw` this is jungle's gnarly reese.
- **Fast arpeggio = chords** — with only 4 channels, imply a chord by cycling one
  channel through its notes at 16th/32nd speed.
- **Synthesized drums (breakbeats, not beeps)** — multiplex kick/snare/hat onto
  one channel (retrigger resets the one-shot), freeing the other three:
  - **Kick** — pitched one-shot: `triangle`, frequency envelope dropping **fast**
    (≈115 Hz → 50 Hz over ~4 frames — a slow drop or a sub below ~50 Hz reads as
    "off the beat / all click"), amplitude over ~12 frames.
  - **Snare** — `noise`, mid `noiseFreq` (~2200) sweeping down, ~8-frame decay.
  - **Hat** — `noise`, high `noiseFreq` (~3500), very short (~2-frame) decay.
- **Reuse one scratch buffer** for per-frame waveform generation (no per-frame
  table allocation / GC) — keep a module-level table and refill it in place.

## Two gotchas that will waste an hour

- **A hand-written text cart MUST include a `<PALETTE>` section** (field note #1).
  Append the default SWEETIE-16 palette:
  ```
  -- <PALETTE>
  -- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
  -- </PALETTE>
  ```
- **Launching the cart.** `Start-Process` with the cart path auto-runs it in this
  build (verified). If you ever land on the console instead, press `Ctrl+R` in the
  window, or add `--cmd=run`. Avoid `--cmd="load x.lua & run"` — the spaces/`&`
  get mangled by `Start-Process` quoting.

## Verifying audio changes from an automated session

You **cannot screenshot sound**. To verify:
1. Launch with `Start-Process`, wait ~5 s for compile, screenshot the window
   (**`tic80-screenshot`** skill) to confirm it **runs without a Lua error** and
   the readout looks right.
2. Confirm register values programmatically if needed (draw them, or `trace()`).
3. *Pitch/timbre* correctness must be checked **by ear by the user** — say so
   explicitly rather than claiming the sound is correct.

## Related

- **`music-in-code`** — compose the actual song (tune, drum loops, arrangement)
  with this engine. Use it to change *what plays*; use this skill to change *how
  it sounds*.
- **`tic80-screenshot`** — grab the running window.

## Sources

- TIC-80 wiki (local): `tic80wiki/RAM.md` (sound registers, SFX/pattern layout),
  `tic80wiki/sfx.md`, `tic80wiki/music.md`, `tic80wiki/SFX-Editor.md`,
  `tic80wiki/Music-Editor.md` (BPM math).
- [TIC-80 RAM wiki](https://github.com/nesbox/TIC-80/wiki/RAM) ·
  [sfx](https://github.com/nesbox/TIC-80/wiki/sfx) ·
  [music](https://github.com/nesbox/TIC-80/wiki/music)
- [SizeCoding: TIC-80](http://www.sizecoding.org/wiki/TIC-80) — register-poke tricks.
- [kometbomb: chiptune drums](https://kometbomb.net/2011/10/11/chiptune-drums/) — drum synthesis recipes.
