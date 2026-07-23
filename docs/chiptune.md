# Chiptune / Chip Music — Reference Notes

Reference notes for composing music-in-code on a fantasy console with a limited sound
chip (relevant to `music01.lua`/`tracker.lua` and the TIC-80 demo). Focus is on how the
constraints work and how composers exploit them, with concrete channel counts, waveforms,
and duty cycles. Sources at the end.

---

## 1. What Is Chiptune

**Definition.** Chiptune (also "chip music," "8-bit music," though not all of it is 8-bit)
is electronic music — and a whole subculture — made with the **programmable sound
generator (PSG)** chips or synthesizers found in vintage arcade machines, home computers,
and game consoles. The term also covers **tracker music built from extremely short looped
waveforms/samples** that an old machine could produce, plus modern music that blends PSG
timbres with contemporary styles. Core trait: sound is *generated* from simple geometric
waveforms (pulse, square, triangle, sawtooth, noise) rather than sampled/recorded.

**History — three overlapping streams:**

- **Arcade origins (mid-1970s–1980s).** Early game audio: *Gun Fight* (Tomohiro
  Nishikado, 1975) had an opening tune; *Space Invaders* (1978) was the first game with a
  **continuous background soundtrack** (four descending bass notes looping). *Rally-X*
  (Namco, 1980) is cited as the first game with continuous *melodic* background music.
  Yellow Magic Orchestra sampled *Space Invaders*/*Gun Fight* on their 1978 debut.
- **Home computers & consoles (1980s = the heyday).** The Commodore 64's SID and the
  NES's 2A03 became the canonical "voices" of the era; composers like Rob Hubbard, Martin
  Galway, and Chris Hülsbeck (C64) and the Konami/Sega/Capcom in-house teams
  (arcade/console) pushed the chips to their limits.
- **FM synthesis era (early 1980s–1994).** Yamaha FM chips arrived in arcades and PCs
  (AdLib 1987, Sound Blaster 1989). Composers: Konami's Miki Higashino (*Gradius*), Sega's
  Hiroshi Kawaguchi (*Out Run*), Yuzo Koshiro (*Streets of Rage 2*, 1992).

**The demoscene / tracker-scene connection.** Karsten Obarski's **Ultimate Soundtracker
(1987, Amiga)** launched the tracker paradigm. An offshoot of that culture deliberately
used *tiny* synthetic waveforms instead of big digitized samples — to save memory. Because
these small samples lived in the Amiga's **"chip RAM,"** the resulting modules were dubbed
**"chip tunes."** Earliest tracker chiptunes (~1989) are credited to demoscene musicians
**4mat, Baroque, TDK, Turtle, and Duz.** As commercial games moved to CD/Red Book audio in
the early 1990s, professional chip composers left, and the **demoscene became the
custodian of chip music** — which is why many in the scene argue chip music is a *distinct
subculture*, not merely leftover game music. Chip music also spread via software crackers'
"crack intros" (musical calling cards).

**Modern revival.** Declined post-1980s, resurged late 1990s→2000s. Touchpoints:
Smithsonian's *The Art of Video Games* (2012); the documentary *Reformat the Planet*
(2008); the **Blip Festival** (NYC) and **MAGFest Chipspace**; chiptune elements in
mainstream tracks (Beck, The Killers, Kesha's "Tik Tok," Perfume) and in game scores like
*Shovel Knight* and *Undertale*. A live-hardware scene thrives around LSDj (Game Boy) and
the Elektron SidStation (used by Depeche Mode, Daft Punk, The Prodigy).

**"Fakebit" debate.** Music made with modern DAW/VST emulations of chips (rather than real
hardware/authentic chip emulation) is sometimes derided as "fakebit" — it lacks the
hardware's characteristic distortion and, more importantly, loses the *creative
constraint* that defined the form. (For a TIC-80 demo this debate is moot — the fantasy
console *is* your constrained chip.)

---

## 2. The Classic Hardware & Sound Chips

Reference table (channels / waveforms / pitch resolution / amplitude), then notes on what
each is *known for*:

| Chip / machine | Channels | Waveforms | Pitch res. | Amplitude |
|---|---|---|---|---|
| **MOS SID** (Commodore 64) | 3 voices | tri, saw, pulse, noise (per voice) | 16-bit (65,536) | 4-bit (16), per-voice ADSR |
| **Ricoh 2A03 APU** (NES/Famicom) | 5 | 2 pulse, 1 triangle, 1 noise, 1 DPCM | 11-bit (2048) | 4-bit (16) |
| **Game Boy (DMG)** | 4 | 2 pulse, 1 wavetable (4-bit), 1 noise | — | 4-bit |
| **Atari POKEY** (400/800, arcade) | 4 | square/noise variants | 256 pitches | 4-bit |
| **Atari TIA** (2600) | 2 | limited | 5-bit (32, many detuned) | 4-bit |
| **AY-3-8910 / YM2149F** | 3 + noise + env | pulse (fixed duty), noise, env-driven | 12-bit (4096) | 4-bit |
| **TI SN76489** | 3 square + 1 noise | square, noise | 10-bit (1024) | 4-bit |
| **YM2612 (OPN2)** (Genesis) | 6 FM | FM, 4 operators/ch | — | — |
| **Amiga (Paula)** | 4 PCM | any 8-bit sample | — | 6-bit volume |

**Commodore 64 — MOS SID (6581/8580).** The most celebrated chip in the culture. 3 voices,
each freely switchable between **triangle, sawtooth, pulse (variable duty), and noise**.
Finest pitch resolution of its generation (16-bit). Beyond raw waveforms it had genuine
synth features composers exploited hard: **per-voice ADSR envelopes, a shared multimode
resonant filter (low/band/high-pass), ring modulation, and oscillator (hard) sync.** The
6581 has "characterful" filter distortion; the 8580 is cleaner but less gritty. Its
3-voice limit is what makes classic SID music sound "choppy/frenetic" — everything is
arpeggios and fast interleaving.

**NES / Famicom — Ricoh 2A03.** 5 channels, unusually rich for its day: **2 pulse
channels** (duty **12.5%, 25%, 50%, 75%**), **1 triangle** (fixed volume — used for bass
and occasional lead), **1 noise** (percussion / effects), **1 DPCM** delta-modulation
channel (low-fi 7-bit samples, often for drums or voice). The "classic NES sound" is two
pulse voices trading lead/harmony over a triangle bass and noise drums.

**Game Boy.** 4 channels: **2 pulse** (same 4 duty settings), **1 wave channel** playing a
**user-defined 32-step 4-bit wavetable**, and **1 noise**. This wavetable channel is
distinctive — you draw a custom periodic waveform. This is the closest classic analog to
TIC-80's own waveform model (see §6).

**Atari POKEY.** 4 channels; big step up from the 2-channel TIA. Distinctive gritty/metallic
timbres and its own detuning quirks. Also handled keyboard/paddle I/O.

**AY-3-8910 / Yamaha YM2149.** The ubiquitous "home computer" PSG (**ZX Spectrum 128,
Amstrad CPC, MSX, Atari ST**). 3 tone channels (**pulse with essentially fixed duty**,
unlike the NES), a single shared noise generator, and a **hardware envelope generator**.
Known for buzzy envelope-driven basslines and needing tricks (see §4) to get vibrato/duty
variety it doesn't natively offer.

**Sega Master System / Genesis.**

- **SN76489** (TI PSG): 3 square + 1 noise. Also in BBC Micro, ColecoVision. Provided the
  Master System's whole sound and the Genesis's PSG layer.
- **Genesis/Mega Drive = SN76489 (PSG) + Yamaha YM2612 (OPN2, FM)** together: **6 FM
  channels, 4 operators each**, synthesized in real time. FM synthesis builds timbre by
  having operators (oscillators) *modulate each other's frequency* — the Yamaha DX7
  principle — giving metallic, bell-like, punchy tones very different from the geometric
  PSG waveforms. The Genesis's grungy FM bass/leads are its signature.

**Other Yamaha FM chips:** OPL2/YM3812 (AdLib, Sound Blaster) = 9 channels, 2 operators;
YM2203 (OPN) = 3 FM + AY PSG, 4 operators; YM2151 (OPM, Sharp X68000/arcade) = 8 channels,
4 operators.

**Amiga.** The **Paula** chip: **4 hardware PCM channels playing 8-bit samples** —
*sample-based*, not a synthesis PSG. This is the machine that birthed the MOD tracker and
the word "chiptune" (small samples in chip RAM). Its influence is the *tracker workflow*
and the MOD/XM heritage more than a specific timbre.

**Also worth knowing:** the **Konami SCC** (MSX wavetable, 5 channels, 32-byte custom
waveforms); **1-bit "beeper" music** (ZX Spectrum — CPU toggles a single speaker bit;
polyphony faked with PWM; Tim Follin's *Agent X* got five voices out of it).

---

## 3. Waveforms & Timbre

The whole chiptune palette is built from a handful of waveforms; timbre = harmonic content
of the wave.

- **Square wave (50%-duty pulse).** Contains only **odd harmonics** → hollow, full,
  "clarinet-ish" tone. The default chiptune lead. Bright and cutting.
- **Pulse wave (variable duty).** A rectangle whose **duty cycle** (on-time ÷ period) sets
  the timbre:
  - **50%** = square (fullest, hollow).
  - **25%** = brighter, thinner, more nasal.
  - **12.5%** = thin, buzzy, reedy/"nasal" — great for distinct leads that cut through.
  - **75%** = sounds identical to 25% (a duty and its complement are timbrally
    equivalent).
  Cycling/sweeping duty over time is a core expressive move (see PWM, §4).
- **Triangle wave.** Odd harmonics but rolling off fast → soft, mellow, flute-/recorder-like.
  On the NES it's the **bass** (and it has fixed volume there). Good for smooth
  sub-melodies.
- **Sawtooth wave.** Contains **all** harmonics (odd + even) → bright, buzzy, brassy/raspy.
  Common on SID; good for aggressive leads and fat bass.
- **Noise channel.** Pseudo-random generator → static/hiss. The universal **percussion**
  source (and explosions/SFX). Pitch/period and volume shaping turn it into kick, snare,
  hat (see §4).

**Working within limited voices.** Because most chips give **3–5 channels** and each
channel is essentially **monophonic** (one note at a time), *timbre selection is a
per-channel budgeting decision*, and richness comes from **motion and trickery** rather
than layering. This is the root cause of "the chiptune sound."

---

## 4. Core Techniques

These are the tricks that make a few mono channels sound like a full arrangement. Nearly
all are expressible as per-row/per-frame tracker effect commands.

- **Arpeggio (fake chords).** Rapidly cycle one channel through the notes of a chord — a
  new note **every frame/row** (~1/60 s each). Too fast to hear as separate notes, so it
  reads as a **chord shimmer** on a single voice. In trackers this is the `0xy` command:
  `0 4 7` = root, +4 semitones (major third), +7 semitones (fifth) = **major chord**;
  `0 3 7` = **minor**. This is *the* signature chiptune technique and the reason so much of
  it sounds "bubbly/rippling."
- **Pulse-width modulation (PWM).** Continuously sweep a pulse channel's duty cycle over
  time. Produces a **chorus-like, evolving, "breathing"** timbre from a single oscillator —
  motion/thickness without a second channel.
- **Vibrato.** Small periodic pitch wobble (an LFO on pitch). Tracker `4xy` (x = speed,
  y = depth). Adds life/expression to sustained lead notes. On chips without native vibrato
  (e.g. AY) it's done by hand, altering the pitch register every few frames.
- **Portamento / pitch slide.** Glide continuously between pitches. `1xx` slide up, `2xx`
  slide down, `3xx` = "tone portamento" gliding to a target note (trombone-like). A quick
  slide up into a high note makes a lead "scream"; slides on note tails add interest.
- **"Echo" / delay by hand.** No reverb hardware, so echo is *composed in*: repeat the note
  (on the same or a spare channel) a fixed number of rows later at **lower volume**,
  sometimes a second fainter repeat after that. Offbeat delayed repeats create the classic
  chip "space."
- **Volume envelopes.** Shape each note's amplitude over time (attack/decay/sustain/release,
  or a simple fast fade). Sharp attack + quick decay = plucky/percussive; slow attack =
  pad-like swell. Envelopes are how a single square becomes a "pluck," a "pad," or a drum
  hit.
- **Note-cut & retrigger.** Cut a note early (staccato, groove, making room) or retrigger
  it rapidly (rolls, buzz, machine-gun snares). Precise per-row control is what the tracker
  grid is *for*.
- **Noise-channel percussion.** Shape the noise generator with pitch + a fast volume
  envelope: **high pitch + very short decay = hi-hat**, **mid pitch = snare**, **low pitch
  + slightly longer decay = kick/tom**. Sometimes a tuned pulse/triangle "click" is layered
  under the noise for a kick's body.
- **Phasing / detune.** Play the same note on two channels **slightly detuned**; the
  beating between them = a fat, chorused, "wide" sound (costs two channels, so used
  sparingly).
- **Hard restart (SID-specific).** Force-reset a voice's ADSR envelope in the frame *before*
  a new note so the attack always triggers cleanly and consistently — a classic C64 trick
  for tight, punchy note articulation. (Analogous "re-trigger the envelope" thinking
  applies on any chip with per-note envelopes.)

---

## 5. Composition Within Constraints

Limited polyphony (typically **3–4 usable channels**) is the central compositional fact and
shapes everything.

- **Channel budgeting — assign roles first.** A classic 4-channel plan (NES-style):
  **Pulse 1 = lead melody**, **Pulse 2 = harmony / counter-melody / arpeggios**,
  **Triangle = bass**, **Noise = drums**. TIC-80's 4 channels map onto this cleanly. Decide
  roles *before* writing, not after.
- **Every channel must earn its place.** With so few voices, the rule is: if a channel
  isn't adding *new information* (a new line, rhythm, or harmonic movement) at a given
  moment, free it up for something that does.
- **Time-share channels.** A single channel can do several jobs across a bar — e.g. hold a
  bass note, then break into a fast fill, then double the melody — because it's
  rearticulated constantly. Channels are a *time* resource, not just a *layer* resource.
- **Imply harmony instead of stating it.** Since you usually can't hold a full sustained
  chord, harmony is implied by (a) **arpeggios** on one channel, (b) an active **bassline**
  outlining the chord roots/fifths, and (c) **counterpoint** — two independent melodic
  lines that together spell the harmony.
- **Why chiptune melodies are busy/fast.** You can't sustain rich pads or thick chords, so
  **motion fills the sonic space**: fast runs, ornaments (grace notes, trills), arpeggios,
  and constant rearticulation keep the texture full. Sparse, slow writing exposes how thin
  a single square wave is; dense writing hides it and creates energy.
- **Let the bass anchor, then get out of the way.** A strong, rhythmic bass establishes
  harmony + groove; keep it simple and let the lead breathe on top.
- **Call-and-response / counterpoint** between the two lead voices is the workhorse for
  making 2 melodic channels feel like a band.

---

## 6. Trackers & Tools

**The tracker paradigm.** A music tracker is a **pattern-based step-sequencer** with a
**vertical, spreadsheet-like grid**:

- **Columns = channels** (one per hardware voice, e.g. 4 on TIC-80).
- **Rows = time steps** (e.g. 16 or 32 per pattern), and **time flows top→bottom** — the
  playhead scrolls downward through rows at the current tempo/groove.
- **Each cell** holds a **note + octave**, an **instrument/sample id**, an optional
  **volume**, and one or more **effect commands** (hex). Effects are typically 3 hex digits:
  **effect type + 2-digit parameter** (e.g. `0xy` arpeggio, `1xx/2xx/3xx` slides, `4xy`
  vibrato, `Axy` volume slide).
- **Patterns** are chained via an **order list / song sequence** to form the whole piece.
  It's often likened to "assembly language for music."

**MOD/XM demoscene heritage (the lineage):**

- **Ultimate Soundtracker** (Obarski, 1987, Amiga) → **.MOD** format: 4 channels, 15
  (later 31) samples. The origin.
- **ProTracker** (Amiga) — the definitive MOD tracker.
- **Scream Tracker** → **.S3M**; **FastTracker 2** → **.XM** (written by the PC demo group
  **Triton**; introduced "instruments" with volume/panning envelopes, multi-channel beyond
  4); **Impulse Tracker** → **.IT** (resonant filters, New Note Actions). **OpenMPT** and
  **MilkyTracker** are the modern descendants (MilkyTracker is Amiga/MOD-XM focused and
  widely recommended for *learning* the paradigm).

**Chip-specific trackers:**

- **FamiTracker** — free NES/Famicom (2A03) tracker; supports expansion chips (VRC6, N163,
  etc.). The standard for authentic NES writing.
- **LSDj (Little Sound Dj)** — a **Game Boy cartridge** tracker (Johan Kotlinski).
  Hierarchy: **Song → Chain → Phrase → Instrument → Table → Groove.** A *Phrase* is a
  16-row single-channel pattern; *Chains* sequence phrases; the Song screen has 4 columns
  for the GB's 4 channels. Beloved for **live performance** (live mode, MIDI sync).
- **GoatTracker** — C64/SID.
- **DefleMask** — multi-system (Genesis, SMS, Game Boy, NES, C64, PC Engine, etc.).
- **Furnace** — open-source, actively developed **multi-chip** tracker; DefleMask-compatible;
  supports a huge range of chips. The current community favorite for cross-chip work.

**Fantasy-console synthesis (directly relevant):**

- **TIC-80** — **4 channels**. Each channel plays a **repeating 4-bit waveform of up to 32
  steps** (sound registers/waveforms at memory `0xFF9C`). You author sounds in the **SFX
  editor** (waveform shape + volume/arpeggio/pitch envelopes), then trigger them:
  - `sfx(id, note, duration, channel, volume, speed)`:
    - `id` **0–63** (or −1 to stop),
    - `note` **0–95** (8 octaves × 12 semitones) or a string like `"C#4"`,
    - `duration` in frames (60 FPS; −1 = continuous),
    - `channel` **0–3**,
    - `volume` **0–15**,
    - `speed` **−4…3** (rate the SFX envelope is traversed).
  - `music(track, ...)` plays tracked patterns authored in TIC-80's music editor. The
    SFX-editor "loops" and envelope columns are where you build arps, vibrato, PWM-like
    sweeps, and drum shapes. TIC-80's custom-waveform-per-channel model is close in spirit
    to the Game Boy wave channel — you *draw* the timbre.
- **PICO-8** (useful for comparison) — **4 channels**, **8 built-in waveforms** (sine,
  triangle, sawtooth, "long square" ≈50% pulse, "short square" ≈narrow pulse, ringing,
  noise, ringing sine) **plus 8 custom** waveforms; per-note **effects** (slide, vibrato,
  drop, fade-in/out, fast/slow **arpeggio**) and per-SFX filters (noise, buzz, detune,
  reverb, dampen). SFX are 32-note patterns; music is a sequence of patterns each assigning
  up to 4 SFX to the 4 channels.

Both fantasy consoles deliberately reproduce the **tracker + limited-channel PSG**
experience, so the classic techniques (§4) and channel-budgeting (§5) transfer directly.

---

## 7. Aesthetic & Musical Style — "The Chiptune Sound"

- **Timbral signature:** bright, sharp "**beeps and bloops**" — square/pulse leads that
  **cut through any mix**, soft triangle bass, hissy noise drums. Sounds are **clear,
  immediate, and rhythmically strong**.
- **Emotional character:** tends toward **brightness, energy, and forward motion**, even
  when melancholic — arguably because the medium grew out of the "sonic language of play"
  (games). It's rarely dark or muddy; it's punchy and legible.
- **Tempo & rhythm feel:** generally **upbeat and driving**, with **busy, fast note
  movement** (see §5 — motion compensates for the lack of sustain/polyphony). Strong, tight
  grooves; syncopation and fast arps give it bounce.
- **Genres commonly done in chiptune:** dance/electronic and EDM, synth-pop, **chip-rock /
  "nintendocore"** (chip leads + real guitars/drums), techno/house, ambient, and jazz-/prog-
  influenced pieces. The demoscene tradition also favors highly technical, melodic,
  mood-shifting multi-part compositions.
- **Why it sounds the way it does:** it's the direct audible fingerprint of the
  **constraints** — few monophonic channels, no reverb, geometric waveforms, coarse
  pitch/volume steps — combined with the **techniques invented to overcome them** (arps for
  chords, hand-built echo, PWM/vibrato for movement, noise for drums). The "charm" is
  inseparable from the limitation.

---

## 8. Practical Composition Tips

Actionable guidance, roughly in the order you'd apply it:

1. **Commit channel roles up front.** e.g. TIC-80: ch0 = lead, ch1 = harmony/arp, ch2 =
   triangle-style bass, ch3 = noise drums. Design your SFX instruments to match these roles.
2. **Lock a solid rhythmic bass early.** Simple root/fifth movement outlining the chords;
   let it define groove and harmony, then keep it out of the melody's way.
3. **Use arpeggios to imply chords** on the harmony channel (`047` major, `037` minor,
   etc.). This is the single biggest "instant chiptune" move and frees other channels.
4. **Sculpt drums from the noise channel** by frequency + a fast volume envelope: high+short
   = hat, mid = snare, low = kick. Optionally layer a short pitched click under the kick for
   body.
5. **Keep melodies active.** Fill space with runs, ornaments, grace notes and
   rearticulation — sparse writing exposes the thin single-oscillator timbre; density reads
   as energy.
6. **Add per-note expression** so lines don't feel static: a touch of **vibrato** on held
   notes, **pitch slides** into accents ("screaming" leads), **duty-cycle sweeps (PWM)** for
   evolving timbre.
7. **Build echo by hand** — delayed, quieter repeats of key notes — to create depth without
   any reverb unit.
8. **Interleave, don't stack.** Have channels take turns (lead ↔ answer ↔ fill) rather than
   all sounding constantly; time-share a channel between bass and fills.
9. **Shape every note with an envelope.** Attack/decay choices (pluck vs. pad vs. percussive)
   do most of the work of making a bare waveform feel like an instrument.
10. **Mind the constraints deliberately** — coarse volume steps, mono channels, limited
    pitch. Composing *to* the limits (and to your target console's exact channel/waveform
    model) is what separates convincing chiptune from generic square-wave presets.

**What separates good from generic:**

- **Motion and variation** over static loops — evolving duty, moving basslines, drum fills,
  dynamic (volume) changes across sections.
- **Expressive per-note detail** (slides, vibrato, note-cuts, hard-restart-style clean
  attacks) instead of flat, quantized note-on/note-off.
- **Smart use of the whole channel budget** — arps and counterpoint to imply far more
  harmony than the voice count would suggest.
- **Strong melodic writing + a tight groove** — the constraints reward memorable tunes and
  rhythmic drive, and expose weak ones.
- **Respecting the hardware model** (right waveform per role, right duty for the timbre you
  want) so it sounds native to the chip rather than like a DAW imitation.

> **Note on the demo's genre goal:** D&B/jungle (see `docs/dnb-jungle-structure.md`) leans
> heavily on chopped breakbeat *samples* — which TIC-80's synthesis-only, sample-light chip
> can't reproduce literally. The chiptune workarounds are: build drums from the noise
> channel (§4), imply the half-time swing with note timing, and use the sub/lead channels
> for the sine sub + Reese-ish detuned saw. The result is "chiptune D&B," not sampled
> jungle — which is itself a recognised demoscene style.

---

## Sources

- [Chiptune — Wikipedia](https://en.wikipedia.org/wiki/Chiptune)
- [Sound chips and chip music — Introduction to Demoscene (compumuseum GitBook)](https://compumuseum.gitbook.io/introduction-to-demoscene/07-soundchip-chiptune)
- [Tracker music / Module file — Wikipedia](https://en.wikipedia.org/wiki/Tracker_music)
- [Chiptune — Grokipedia](https://grokipedia.com/page/Chiptune)
- [sfx — nesbox/TIC-80 Wiki (GitHub)](https://github.com/nesbox/TIC-80/wiki/sfx)
- [music — nesbox/TIC-80 Wiki (GitHub)](https://github.com/nesbox/TIC-80/wiki/music)
- [TIC-80 — SizeCoding wiki](http://www.sizecoding.org/wiki/TIC-80)
- [PICO-8 Manual — Lexaloffle](https://www.lexaloffle.com/dl/docs/pico-8_manual.html)
- [Sfx — PICO-8 Wiki (Fandom)](https://pico-8.fandom.com/wiki/Sfx)
- [How to make 8-bit music — a comprehensive guide (Ozzed.net)](https://ozzed.net/how-to-make-8-bit-music.shtml)
- [Consoles & Sound Chips — 8-Bit Music Exhibit (University of Michigan)](https://sites.lsa.umich.edu/8bitmusic/consoles-sound-chips/)
- [We Got Your Sega Chiptunes Right Here — Hackaday](https://hackaday.com/2018/10/04/we-got-your-sega-chiptunes-right-here/)
- [Kickin' it old school: Setting up NES style chiptunes — OpenGameArt.org](https://opengameart.org/forumtopic/kickin-it-old-school-setting-up-nes-style-chiptunes)
- [Little Sound Dj (LSDj) — GameBrew wiki](https://www.gamebrew.org/wiki/Little_Sound_Dj_GB)
- [Chiptune | Origins, Lineage, and Sound — The Sound Atlas](https://thesoundatlas.org/discover/chiptune)
- [How to Make Chiptune Music — eMastered](https://emastered.com/blog/how-to-make-chiptune-music)
- [Mastering Chiptune: Techniques To Create Retro Video Game Sounds — SoundCy](https://soundcy.com/article/how-to-make-chiptune-sound)
