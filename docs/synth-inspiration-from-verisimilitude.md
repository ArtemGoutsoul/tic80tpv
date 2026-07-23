# Synth inspiration — *Verisimilitude* by Rift

Notes from studying the code of **Verisimilitude** (TIC-80, 1st place Fantasy
Computer compo at **rsync 2024**), specifically its music/synth system. Music &
code by **Mantratronic**; code also by **jtruk**; graphics by **Decca**.

- Demozoo: <https://demozoo.org/productions/335735/>
- Pouët: <https://www.pouet.net/prod.php?which=95792>
- Playable / video: <https://tic80.com/play?cart=3695> · <https://www.youtube.com/watch?v=_RltFsuLuS0>
- License: **MIT** (per the cart header) — safe to learn from and adapt.

> The cart's own text file says it best: *"Uses a new custom synth that isn't
> finished yet. Quietly at first, and then louder."* The synth is unfinished and
> a bit messy, but the **ideas** are exactly what we're missing.

## How to re-extract the source

The `.tic` is a binary cart. TIC-80 itself converts it to a text cart with the
code plus embedded data sections — no manual chunk parsing needed:

```powershell
# grab the release, then:
& "C:\dev\tic80\tic80.exe" --cli --fs . --cmd "load verisimilitude.tic & save verisimilitude.lua & exit"
```

`--cli` runs headless (no window); `save cart.lua` writes the `tpv.lua`-style
text cart. (The manual `.tic` chunk walk kept desyncing — the CLI export is the
reliable route.)

---

## TL;DR — what's worth stealing

Verisimilitude is a **full subtractive softsynth in Lua** that ignores TIC-80's
native tracker entirely and rewrites each channel's waveform in the sound
registers **every frame**. That register-poke foundation is the *same* one our
`tracker.lua` already uses — but Verisimilitude layers real synthesis on
top that we don't have yet:

| Idea | Verisimilitude has it | We have it (`tracker.lua`) |
|------|-----------------------|----------------------------------|
| Per-frame waveform poke to `0xFF9C` | ✅ | ✅ |
| Note name → pitch | hand-typed integer Hz table (with a rant) | ✅ computed equal-temperament (nicer) |
| ADSR envelopes | ✅ on volume **and** cutoff, pitch, phase | volume only |
| **Runtime low-pass filter** (cutoff) | ✅ two-pole RC, filters the wavetable live | ❌ — **biggest gap** |
| LFOs (any param) | ✅ generic `lfo(type,amp,freq,phase)` | vibrato/PWM only, hard-coded |
| Cutoff **keytracking** | ✅ | ❌ |
| Wavetable **phase shift** | ✅ | ❌ |
| Harmonic-enrich by mixing octaves | ✅ `mixWave` → `hsaw`/`hsine`/`hsquare` | ❌ |
| Instruments as param bundles | ✅ | ✅ |
| Pattern/arrangement layer | ✗ (flat pattern list, no sections) | ✅ (named patterns + sections — ours is better) |

**Net:** our arrangement/mini-notation layer is more advanced; their **voice
engine** (live filter + full modulation matrix) is more advanced. The prize to
port is the **cutoff filter with an envelope/LFO** — that's what makes their
pads breathe and evolve, and it's the one thing our chiptune-y voices lack.

---

## The music "syntax" (as authored in the cart)

### 1. Notes — a hand-typed name→Hz table

```lua
-- it's not my fault that frequency has to be an integer, but why. why. wtf. gaaaah
NOTE = {c1=33,  db1=35,  d1=37, ...  a4=440, ... b7=3951,
        off=-1, stop=-2}
```

- Flats spelled `db`, `eb`, … ; octave suffix (`a2`, `c4`).
- Two sentinels: **`off`** = release (enter envelope release), **`stop`** = hard
  kill. Our equivalents are the mini-notation `=` (off) and rests.
- The rant in the comment is real: TIC-80's frequency register is an **integer
  Hz** value, so the table is pre-rounded. **We do this better** — we compute
  `440 * 2^((midi-69)/12)` and round at poke time, so transposition stays in
  tune. No reason to copy their table.

### 2. Waveforms — named indices

```lua
WAVE = {square=1, triangle=2, saw=3, sine=4,
        hsquare=5, hsaw=6, hsine=7, noise=16}
```

The `h*` ("half") variants are the clever bit — see `mixWave` below.

### 3. Instruments — a bundle of oscillator + modulation

Each instrument is a plain table: a source wave plus optional **ADSR envelopes**
and **LFOs** for *each* of cutoff / pitch / volume / phase, plus cutoff
keytracking:

```lua
iBass = {oWave=WAVE.square,
    volumeENV={amp=1, attack=0.01, decay=0.1, sustain=0.4, release=0.2},
    cutoffENV={amp=.4, attack=0.02, decay=0.05, sustain=0.0, release=0.2},
    cutoffKeytrack=nil, cutoffLFO=nil, pitchENV=nil, pitchLFO=nil, phaseENV=nil, phaseLFO=nil}

iPadSlowLow = {oWave=WAVE.saw,
    volumeENV={amp=1, attack=8, decay=8, sustain=0.7, release=6},   -- seconds!
    cutoffKeytrack=.02, cutoffLFO={type=WAVE.sine, amp=.2, freq=6000},
    cutoffENV={amp=0.3, attack=10, decay=10, sustain=0.2, release=10},
    pitchLFO={type=WAVE.sine, amp=1, freq=2000}}
```

- Envelope times are in **seconds** (real wall-clock via `time()`), not frames.
  Pads with 8–10 s attacks/releases give the long evolving swells the demo opens
  with. Ours are in **frames** — fine, just a different unit.
- Any of the four ENV/LFO slots being `nil` means "don't modulate that". Clean
  and extensible — a good pattern to mirror if we grow our INSTRUMENTS table.

### 4. Patterns / the tune — a flat 2D array

```lua
-- each row = 4 tracks; each cell = {instrument#, NOTE.x, volume, cutoff, phase}
tune = {
    {{1, NOTE.a2, .8, .11, 0}, {}, {}, {}},   -- row 1: track 1 plays inst 1
    {{}, {}, {}, {}},                          -- empty {} = no change (note holds)
    {{}, {1, NOTE.c3, .8, .11, 2}, {}, {}},
    ...
    {{}, {1, NOTE.off, .8, .11, 2}, {}, {}},   -- release on track 2
}
```

- Cell layout: `{instrument, note, volume(0..1), cutoff(0..1), phase/"effect"}`.
  So **per-note cutoff and phase** are part of the score, not just the
  instrument — you write the filter opening into the melody itself.
- Empty `{}` = leave that track alone (sustain continues). `NOTE.off`/`NOTE.stop`
  in the note slot = release/kill.
- **Downside vs us:** it's one long flat list — no named patterns, no sections,
  no reuse. Our `PATTERNS` + `ARRANGEMENT` (with per-bar cycles and `transpose`)
  is the better structure. Don't regress to their layout.

### 5. Player / clock

```lua
musicPlayer = {startTime, time=0.0, playing=false, position=-1,
               bpm=120, linesPerBeat=1, patterns=nil, looping=true}

function getMusicPos()   -- ms -> fractional row index
    return (t - musicPlayer.startTime) / (60000 / (musicPlayer.bpm * musicPlayer.linesPerBeat))
end
```

Time-based (ms) rather than frame-counted. `updateSound()` detects when the
integer row advances, fires that row's events into `mState`, then every frame
recomputes envelopes/LFOs → `sState` → registers.

---

## The synth engine — the genuinely worthy part

### A. Wavetables built in Lua (range −8..7)

32-sample tables. Generators take `pwm` (shape/duty) and `h` (harmonic/repeat
count):

```lua
squareWave(pwm, h)   sawWave(pwm, h)   triangleWave(pwm, h)   sineWave(pwm, h)
```

### B. `mixWave` → cheap harmonic enrichment (the `h*` waves)

Blend a wave with a **3×-frequency copy of itself** to add upper harmonics:

```lua
function mixWave(a, b, va, vb)
    local w = {}
    for i=1,32 do w[i] = clamp(a[i]*va + b[i]*vb, -8, 7) end
    return w
end
waves[WAVE.hsaw] = mixWave(sawWave(.5,1), sawWave(.5,3), .8, .4)   -- fatter saw
```

A one-liner to get a richer timbre than TIC-80's single-cycle wave — worth
adding to our `buildWave`/`WAVEFORMS`.

### C. ★ Live low-pass filter — `dlr` (the thing to port)

A discrete **RC low-pass run twice** (≈ two-pole / 12 dB-per-oct), applied to the
*wavetable itself* each frame, wrapping around so the cycle stays seamless:

```lua
function dlr(input, dt, rc)      -- dt = cutoff (0..1), rc fixed at 1.0
    local inter, output = {}, {}
    local alpha = dt / (rc + dt)
    inter[1] = alpha*input[1] + (1-alpha)*input[#input]
    for i=2,#input do inter[i] = alpha*input[i] + (1-alpha)*inter[i-1] end
    output[1] = alpha*inter[1] + (1-alpha)*inter[#input]
    for i=2,#input do output[i] = alpha*output[i-1]... end   -- second pass
    return output
end
```

Per channel: `if cutoff < 1.0 then tempWave = dlr(tempWave, cutoff, 1.0) end`
(cutoff `1.0` = filter fully open / bypass). The cutoff value itself is driven by
`cutoff * keytrack + LFO² + ENV²`, clamped to `[0,1]`. **This is what makes the
pads open up and breathe.** Filtering the 32-sample table (not per audio sample)
is cheap enough for 60 FPS.

> Port target for us: add an optional `cutoff` + `cutoffEnv`/`cutoffLfo` to an
> instrument, run a `dlr`-style pass over the wavetable in `setWaveform`, and let
> patterns write per-note cutoff (they already carry a 5th cell we could reuse).

### D. Phase shift — rotate the wavetable

```lua
function phase(w, b)   -- circular shift by b samples
    ... returns w rotated so sample b becomes sample 1 ...
end
```

Used with a phase LFO/value for subtle motion and (with detune-like tricks)
phasing between channels. Cheap movement for otherwise-static wavetables.

### E. Envelopes + LFOs, evaluated per frame

`updateSound()` computes, for each of cutoff/pitch/volume/phase: an ADSR value
from `cTime` (since note start) and `rTime` (since release), plus an LFO value.
The generic LFO:

```lua
function lfo(type, amplitude, frequency, phase)   -- square/saw/sine
    ... s((t/frequency + phase) * pi*2) * amplitude ...
end
```

Note they **square** the cutoff LFO/ENV contributions (`clfo^2`, `cenv^2`) so
modulation only ever opens the filter and the response feels exponential.

### F. The actual hardware hack — poke 4 channels every frame

```lua
for channel = 0, 3 do
    local note   = sState[channel+1].pitch
    local volume = (sState[channel+1].volume * 15) // 1
    local wn     = sState[channel+1].wave
    local byte1 = (note & 0x00ff)
    local byte2 = ((note & 0x0f00) >> 8) + ((volume & 0x000f) << 4)
    poke(0xff9c + 18*channel,     byte1)      -- freq low 8 bits
    poke(0xff9c + 18*channel + 1, byte2)      -- freq high nibble + volume nibble
    for i=0,31 do                              -- 32 waveform samples, +8 offset
        poke4((0xff9c + 18*channel + 2)*2 + i, currentWaves[wn+1][i+1] + 8)
    end
end
```

Same register map we use (18-byte stride, freq low / freq-hi+vol / 16 wave
bytes). The `+8` is because their tables are signed `−8..7` but the chip wants
`0..15` (our tables are already `0..15`). They also **seed** waves 0–2 from
waveform RAM via `getwave`:

```lua
function getwave(w)
    local wav = {}
    for i=0,31 do wav[i+1] = peek4(0xffe4*2 + w*32 + i) - 8 end
    return wav
end
```

so the first three `<WAVES>` slots in the cart double as synth sources.

### Note on the embedded `<SFX>/<PATTERNS>/<TRACKS>` data

The cart *does* contain native-tracker data, but the demo doesn't `music()` it —
audio is 100 % the custom synth driving `0xFF9C`. Treat the tracker chunks as
leftovers, not the sound you hear.

---

## Concrete next steps for `tracker.lua`

1. **Add a live cutoff filter** (port `dlr`): optional `cutoff`, `cutoffEnv`,
   `cutoffLfo` on an instrument; filter the wavetable in `setWaveform`. Biggest
   sonic upgrade, especially for the pad/reese material in *The Universe Unfolds*
   and *Total Perspective*.
2. **`mixWave`-style `h*` waveforms** for a fatter saw/square without new
   register tricks.
3. **Generalise modulation** toward their ENV+LFO-per-parameter shape if we find
   vibrato/PWM too rigid — but keep our named-pattern/section arrangement, which
   is better than their flat `tune`.
4. Keep our **computed** note→Hz; do **not** adopt their integer table.
