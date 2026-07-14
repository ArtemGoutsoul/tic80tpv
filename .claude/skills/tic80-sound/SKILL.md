---
name: tic80-sound
description: >-
  Work with sound and music in TIC-80 from code instead of the mouse-driven
  editors. Covers the three levels of audio control (the sfx()/music() API,
  poking instrument RAM, and writing the raw sound registers at 0xFF9C), the
  note/frequency math, and two ready-to-use patterns for composing tracked
  music entirely in Lua: an sfx()-driven code tracker and a register-level
  code synthesizer. Trigger words: tic80 sound, tic80 music, sfx, music editor,
  sfx editor, waveform, chiptune, compose music in code, code tracker,
  sequencer, sound registers, poke 0xFF9C, synthesizer, envelope, arpeggio,
  note frequency, play a note from code.
---

# TIC-80 Sound & Music from Code

A playbook for making sound and composing tracked music in TIC-80 **from Lua**,
without touching the built-in SFX / Music editors. Environment: Windows native,
PowerShell tool preferred; run carts with `Start-Process` (see the project
`CLAUDE.md` "Launching from an automated/non-interactive shell").

## The one constraint that shapes everything

TIC-80 has **no raw PCM/sample output**. You cannot hand it an audio buffer.
The chip is a **fixed 4-channel wavetable synth + LFSR noise**:

- **4 channels** (0–3). Each channel plays one 32-step, 4-bit **waveform** at a
  given **12-bit frequency** and **4-bit volume**.
- **16 shared waveforms** (32 nibbles each). A waveform that is all-`0` or
  all-`F` plays as **noise** (white, then periodic) instead of a tone.
- Everything else — envelopes, arpeggios, vibrato, pitch slides — is either a
  feature of the **SFX** layer or something **you compute yourself** per tick.

So "program a synthesizer" in TIC-80 means one of two things:
1. **Drive the built-in synth** via `sfx()` (reuse its envelopes/effects), or
2. **Be the synth**: write the channel's frequency/volume/waveform registers
   yourself every frame (`poke` at `0x0FF9C`).

There is no third "emit samples" option. (PCM "playback" carts fake it by
streaming bytes into the waveform register at a few kHz — a size-coding trick,
not general audio.)

## Three levels of control

| Level | You call | You control | Use when |
|---|---|---|---|
| **1. API** | `sfx(id, note, dur, chan, vol, spd)` / `music(...)` | which instrument + note plays | You want musicality with least code. **Start here.** |
| **2. Instrument RAM** | `poke` the WAVES (`0x0FFE4`) and SFX (`0x100E4`) regions | the actual instrument definitions, from code | You want instruments version-controlled in code, no editor. |
| **3. Sound registers** | `poke` at `0x0FF9C` every tick | raw frequency / volume / waveform per channel | You want a fully custom synth / demoscene voice, zero SFX. |

## Decision guide: composing tracked music in code

You want to write music as **Lua data + a playback loop**, not clicks in the
editor. Two good patterns — pick by how much of the synth you want to own:

- **Recommended for real music — `sfx()`-driven code tracker.** Define a small
  instrument bank **once** (a few SFX: lead, bass, drum), then keep *all
  composition* — patterns, order, tempo — in Lua tables. A tiny engine advances
  a row cursor at your tempo inside `TIC()` and calls `sfx()` per channel per
  row. You get TIC-80's envelopes, arpeggios, pitch macros and effects for free.
  The instrument bank can live as `<SFX>`/`<WAVES>` cart data (authored once) or
  be `poke`d in at `BOOT` (level 2) so even instruments are code.

- **Recommended for a custom synth / zero editor — register-level code
  synthesizer + tracker.** Skip SFX entirely. Define waveforms and simple
  envelopes as Lua data, and `poke` the sound registers each frame. This is the
  approach in the runnable demo shipped with this skill
  (`music_in_code.lua`) — it is 100% code, needs no editor, and is the most
  literal answer to "program a simple synthesizer." Trade-off: you reimplement
  envelopes/arps yourself, so it's more work to sound as rich as `sfx()`.

- **External generator (rarely worth it).** A script (e.g. Python) that writes
  SFX/pattern/track bytes into a `.tic`/cart binary offline. Only for
  algorithmic generation or PCM streaming — not for live, code-composed tracks.

## Level 1 — the API

### `sfx(id, [note=-1], [duration=-1], [channel=0], [volume=15], [speed=0])`

- **id** `0..63` (which SFX/instrument), or `-1` to stop. `sfx(-1)` stops
  channel 0; `sfx(-1, nil, nil, ch)` stops channel `ch`.
- **note** integer `0..95` (8 octaves × 12 semitones, `0`=C in octave 0) **or**
  a string `"D-4"` / `"C#3"` (note UPPER-CASE, `-`=natural or `#`=sharp, one
  octave digit `0..8`; no flats). `-1` = reuse the SFX's last note.
- **duration** in ticks (60/sec); `-1` = play continuously until stopped/retriggered.
- **channel** `0..3`. **volume** `0..15`. **speed** `-4..3` (envelope traversal speed).

```lua
if t % 30 == 0 then sfx(0, "D-4", 20, 1, 10) end  -- D octave 4, 20 ticks, ch1, vol 10
```

### `music([track=-1], [frame=-1], [row=-1], [loop=true], [sustain=false], [tempo=-1], [speed=-1])`

Plays a track authored in the Music Editor. **Gotcha:** calling `music(0)`
inside `TIC()` restarts it 60×/sec. Guard it:

```lua
local started = false
function TIC()
  if not started then music(0); started = true end
end
```

`music()` with no args stops. Use this to play editor-authored songs; for
code-composed songs use a tracker engine (below) instead.

## Level 3 — the sound registers (the real synth)

RAM map (from `tic80wiki/RAM.md`):

```
0x0FF9C SOUND REGISTERS  72 bytes = 4 channels × 18 bytes
        per channel: frequency 12-bit + volume 4-bit (2 bytes), then waveform 32×4-bit (16 bytes)
0x0FFE4 WAVEFORMS        256 bytes = 16 waveforms × 32 nibbles
0x100E4 SFX             4224 bytes = 64 SFX × 66 bytes (bit-packed; see RAM.md)
0x11164 MUSIC PATTERNS
0x13E64 MUSIC TRACKS
```

### Addressing a channel `c` (0–3)

```lua
local base = 0xFF9C + 18 * c     -- c0=65436, c1=65454, c2=65472, c3=65490
-- frequency (12-bit) + volume (4-bit), packed little-endian across base, base+1:
poke(base,     freq & 0xFF)                          -- low 8 bits of freq
poke(base + 1, ((freq >> 8) & 0x0F) | ((vol & 0x0F) << 4))  -- hi 4 bits of freq + volume
-- waveform: 32 nibbles at nibble-address (base+2)*2
for i = 0, 31 do poke4((base + 2) * 2 + i, wave[i]) end   -- each value 0..15
```

To read back: `v = peek(base+1)<<8 | peek(base); freq = v & 0x0FFF; vol = (v & 0xF000)>>12`.

### Note → frequency

The 12-bit register value **is the output pitch in Hz** (the 32-step wave cycles
once per `freq` updates). So convert equal-tempered notes directly:

```lua
-- MIDI note (A4=69) → Hz. C4 (middle C, MIDI 60) ≈ 262. A4 = 440.
local function noteHz(midi) return 440 * 2 ^ ((midi - 69) / 12) end
-- then poke round(noteHz(midi)) as `freq`. Register is 12-bit (max 4095 ≈ C8),
-- and internally clamped to 10..4096, so the full musical range is covered.
```

To parse `"C#4"`-style names: `midi = (octave + 1) * 12 + semitone`, where
`semitone` uses `C=0,D=2,E=4,F=5,G=7,A=9,B=11` plus 1 for `#`.

### Making silence / noise

- Silence a channel: `poke(base+1, ...)` with `vol = 0` (do it every frame).
- Noise: fill the channel's waveform with all `0x0` (white noise) or all `0xF`
  (periodic noise) instead of a tone shape.

### Key facts & gotchas (level 3)

- **Poke every frame.** The registers drive the DAC continuously; write them
  each `TIC()`. Don't mix `sfx()`/`music()` on a channel you're register-driving
  — they write the same registers and will fight you.
- Envelope, vibrato, arpeggio, slide are **yours to compute** (track "frames
  since note-on" per channel and derive volume/pitch from it).
- Volume in the SFX macro editor is *inverted* (editor 15→0 maps to stored 0→15);
  irrelevant if you write registers directly, relevant if you poke SFX RAM.

## Waveforms (level 2, easy)

WAVES are the one instrument component that's trivial to define in code — 16
slots of 32 nibbles at `0x0FFE4`:

```lua
local function setWave(slot, samples)          -- samples: 32 values 0..15
  for i = 0, 31 do poke4((0xFFE4) * 2 + slot * 32 + i, samples[i + 1]) end
end
```

The cart already ships three in its `<WAVES>` section: `square`, `ramp`,
`sawtooth`. Build sine/triangle/pulse tables in Lua for more timbres.

## The runnable demo: `music_in_code.lua`

Ships with this skill's project. A self-contained **code synthesizer + code
tracker** (level 3). It uses **per-lane mini-notation strings** (below),
**synthesized drums** (kick/snare/hat multiplexed on one channel), and a
**frame scheduler** so subdivided rolls land off the main grid. Waveforms,
instruments, drums and the song are all Lua tables; the engine pokes the sound
registers each frame. Run it (see the launch gotcha below — a bare cart path
loads but does **not** auto-run):

```powershell
Start-Process -FilePath "C:\dev\tic80\tic80.exe" `
  -ArgumentList 'C:\dev\tic80\test2\music_in_code.lua --skip --scale=3 --cmd="run"' `
  -WorkingDirectory "C:\dev\tic80\test2"
```

Compose by editing the `INSTRUMENTS`, `PATTERNS`, and `SONG` tables at the top
(`SONG.transpose` shifts the whole song in semitones; per-instrument `peak`/
`sustain` are the volumes) — no editor, diffable in git. Use it as the template
for putting music into `tpv.lua`.

## Mini-notation lanes (the maintainable way to write patterns)

Per-row tuple arrays (`{ {"C-5","lead"}, {"C-3","bass"}, ... }`) are unreadable.
Instead give **each lane one string** you read horizontally, borrowing a subset
of [TidalCycles mini-notation](https://tidalcycles.org/docs/reference/mini_notation/)
(the same idea the Lua [pattrns](https://renoise.github.io/pattrns/guide/cycles.html)
engine uses). The demo compiles these:

| Token | Meaning | Example |
|---|---|---|
| `c4` `c#4` `c-4` | note (`#` sharp, `-` natural), octave 0–8 | `"a4 c5 e5"` |
| `.` or `~` | rest | `"a4 . e4 ."` |
| `-` | hold (let the note ring) | `"a4 - - -"` |
| `=` | note off (cut) | `"a4 . . ="` |
| `k` `s` `h` | drum hits on a drum lane | `"k h s h"` |
| `[a b]` | subdivide one step into faster hits — **jungle rolls** | `"s . [s s] ."` |
| `x*n` | repeat x n times inside its step | `"h*4 . h*2 ."` |

Each lane binds to one channel + one instrument (or `drums = true`), so the
instrument isn't repeated per note. Subdivisions and `*n` give faster notes
*without* changing the step grid, which keeps lanes aligned. A frame scheduler
compiles every lane to absolute frame offsets once, then fires hits by frame —
this is what lets `[h h]` land between 16th-note steps.

## Synthesized drums (breakbeats, not beeps)

Because you own the registers, you can synthesize percussion and **multiplex all
of it onto one channel** (the NES trick), freeing the other three for
bass/lead/arp. Recipes (see [kometbomb](https://kometbomb.net/2011/10/11/chiptune-drums/)):

- **Kick** — a *pitched* one-shot: `triangle`, frequency envelope dropping fast
  (≈200 Hz → 48 Hz over ~5 frames), amplitude decaying over ~9 frames.
- **Snare** — `noise` waveform (all-zero wavetable), mid `noiseFreq` (~1400),
  sharp amplitude decay (~8 frames).
- **Hat** — `noise`, high `noiseFreq` (~2600), very short decay (~3 frames).

Drum voices are one-shots (retrigger resets age); pitched voices sustain with an
ADSR envelope and an optional `gate` (auto note-off after N frames). For d&b,
16 steps × 5 frames/step ≈ 180 BPM.

## Two gotchas that will waste an hour (learned the hard way)

- **A hand-written text cart MUST include a `<PALETTE>` section.** With no
  palette, TIC-80 loads an **all-black palette** — every `cls`/`print`/`rect`
  color renders as black, so the screen looks dead *even though the cart is
  running and making sound* (audio doesn't use the palette). Symptom: black
  screen + working sound. Fix: append the default SWEETIE-16 palette:
  ```
  -- <PALETTE>
  -- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
  -- </PALETTE>
  ```

- **Launching `tic80.exe cart.lua` LOADS but does not auto-run** (build 1.1.x).
  To run headlessly, pass the cart as the positional arg *and* `--cmd="run"`
  (a single token — avoid `--cmd="load x.lua & run"`, whose spaces/`&` get
  mangled by `Start-Process` quoting and by the console's arg splitting). When
  driving interactively, click the TIC-80 window and press `Ctrl+R`, or press
  `Esc` to reach the console and type `run`.

## Verifying audio changes from an automated session

You **cannot screenshot sound**. To verify a sound cart from here:
1. Launch with `Start-Process`, wait ~3–4 s for compile, screenshot the window
   (see project `CLAUDE.md`) to confirm it **runs without a Lua error** and the
   on-screen readout shows the expected song position / channel activity.
2. Confirm register values programmatically if needed (draw them, or `trace()`).
3. Actual *pitch/timbre* correctness must be checked **by ear** by the user —
   say so explicitly rather than claiming the sound is correct.

## Sources

- TIC-80 wiki (local copies): `tic80wiki/RAM.md` (sound registers, SFX/pattern
  bit layout), `tic80wiki/sfx.md`, `tic80wiki/music.md`,
  `tic80wiki/SFX-Editor.md`, `tic80wiki/Music-Editor.md` (BPM math, commands).
- [TIC-80 RAM wiki](https://github.com/nesbox/TIC-80/wiki/RAM)
- [sfx](https://github.com/nesbox/TIC-80/wiki/sfx) · [music](https://github.com/nesbox/TIC-80/wiki/music)
- [SizeCoding: TIC-80](http://www.sizecoding.org/wiki/TIC-80) — register-poke sound tricks.
