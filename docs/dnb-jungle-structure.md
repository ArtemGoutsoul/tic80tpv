# Drum & Bass and Jungle — Structure & Composition Reference

A practical reference on how good drum & bass (D&B) and jungle are built, aimed at
informing short electronic music written in code (e.g. `music01.lua` for the
TIC-80 demo). Concrete numbers (BPM, bar counts, Hz) are given wherever possible.
Sources at the end.

---

## 1. History & Genre Context

**Roots (1990–1992).** Both genres descend from **breakbeat hardcore** (a.k.a. hardcore
rave / oldskool hardcore), which combined four-on-the-floor rave rhythms with breakbeats
sampled from hip-hop, over the early-'90s UK rave scene. As hardcore fragmented
(1992–93), two directions emerged: lighter "happy hardcore," and darker,
breakbeat-driven material ("darkcore" / "hardcore jungle").

**Jungle (≈1993–1995).** Jungle crystallised as a distinct genre out of that darker
strand, fusing:

- **Rapid, chopped breakbeats** (heavily the Amen break) and syncopated percussion, and
- **Jamaican sound-system culture** — deep dub/reggae basslines, dancehall/ragga vocal
  samples, melodies from dub.

It was described as "Britain's own hip-hop" and simultaneously "a raved-up, digitised
offshoot of Jamaican reggae." "Valley of the Shadows" (Origin Unknown) is cited as an
early genre-defining track. **Ragga jungle** (peaked 1994–95) leaned hardest on reggae —
e.g. M-Beat "Incredible," UK Apachi & Shy FX "Original Nuttah." Key infrastructure:
pirate radio (Kool FM), DJs (DJ Hype, Fabio & Grooverider, LTJ Bukem, Randall, Kenny
Ken), labels (Moving Shadow, V Recordings, Suburban Base).

**Drum & bass (mid-1990s onward).** D&B is the direct descendant. In practice the terms
overlap and are often used interchangeably for '93–'95 material; the useful distinction
is:

- **Jungle** — more overtly reggae/ragga, more raw chopped-break-forward, warmer,
  "rougher."
- **Drum & bass** — the term that stuck as the music got cleaner, more
  designed/engineered, more synth-bass-driven (and, some argued at the time,
  "smoother/more industrial, less danceable"). Today "jungle" often signals a
  deliberately breakbeat-heavy, retro-leaning aesthetic within the wider D&B umbrella.

**Subgenres (the map you should know):**

- **Liquid (liquid funk)** — the melodic, soulful, atmospheric strand: lush jazzy
  chords, uplifting melodies, clean sub-bass, emotional. (Emerged early–mid 2000s from
  "intelligent"/jazzstep lineage.)
- **Intelligent / atmospheric / jazzstep** — smoother, ambient/jazz/soul-influenced
  (LTJ Bukem's Good Looking sound); jazzstep uses jazz scales, chords and instrumentation.
- **Techstep** — dark, sci-fi soundscapes, machine aesthetic, gritty synthetic bass
  (mid-late '90s: Ed Rush, Trace, No U-Turn).
- **Neurofunk ("neuro")** — evolution of techstep with jazz/funk complexity: heavily
  distorted, modulated, "talking" basses, surgical sound design, dark industrial
  atmospheres, mechanical groove (Noisia, Phace, etc.).
- **Jump-up** — heavy, energetic, "robotic"/bouncy bass sounds; playful, dancefloor
  humour; simple hooky riffs.
- **Hardstep / darkstep** — harder, gritty basslines and simple aggressive melodies
  (hardstep); fast drums + dark ambient/industrial mood (darkstep).
- **Ragga jungle** — jungle + heavy reggae/dancehall vocals and basslines.
- **Drumfunk / drill 'n' bass** — very complex, chopped, irregular breakbeat programming
  (Amen-heavy, edit-intensive; Squarepusher/Aphex-adjacent lineage).
- **Halftime** — D&B where the beat is felt at half-time (single snare on beat 3) while
  keeping D&B sub-bass and ~170+ tempo; sits close to but distinct from dubstep.
- **Sambass** (Latin fusion), **jazzstep**, **minimal/autonomic**, and crossover
  **liquid/pop** variants round out the field.

---

## 2. Tempo & Rhythm

- **Canonical range: ~160–180 BPM.** Wikipedia gives 165–185; production consensus is
  **170–180 BPM, with 174 BPM the de-facto standard** (many producers just default to
  174; 172–175 is the sweet spot). Jungle/D&B historically drifted up: ~130 BPM
  (1990–91) → ~155–165 (1993) → **170–180 (1996+)**. Some modern/liquid and halftime
  works sit 150–170.
- **The double/half-time feel is the genre's core trick.** The drums run fast (~170), but
  the **kick-snare backbone and the bassline are felt at roughly half that (~85 BPM)**. A
  single snare lands on beat 3 of the bar (the "half-time" anchor), so the *pulse* feels
  like ~85 while the *detail* (hats, ghost snares, break slices, 16th/32nd chatter)
  sprints at 170. This is why D&B can be simultaneously frantic and head-noddingly
  laid-back.
- **Metre:** 4/4. Think in 16th notes per beat (16 steps per bar). The "musical" layer
  (chords, bass movement, melody) typically changes on the half-time grid; the drums fill
  in the fast grid.
- **Swing/shuffle is mandatory for feel.** Straight 16ths sound robotic. Apply swing
  (roughly **~55–62%**) to hi-hats and ghost snares — offset certain hits slightly late —
  to get the rolling propulsion. The shuffle (a run of 16ths after the first snare,
  borrowed from funk drumming) is a signature.

---

## 3. The Breakbeat (the soul of the genre)

**What a "break" is:** a short drum-solo passage lifted from a funk/soul record, then
looped, sliced, and rearranged. The art of jungle/D&B is *editing* breaks, not just
looping them.

**The classic breaks:**

| Break | Source | Notes |
|---|---|---|
| **Amen** | The Winstons – "Amen, Brother" (1969), drummer Gregory C. Coleman | THE break. **4 bars, ~7 seconds**, starts ~1:26 in; original tempo **~136 BPM**. Structure: 2 bars of the groove, 3rd bar delays a snare, 4th bar opens with a gap then syncopation + crash. Its internal variation is *why* it chops so well. |
| **Think** | Lyn Collins – "Think (About It)" (1972) | Shorter (~2 s); bright, snappy; the source of the ubiquitous "woo/yeah" vocal stabs too. |
| **Apache** | Incredible Bongo Band – "Apache" (1973) | Funky, bongo-inflected; huge in hip-hop and D&B. |
| **Funky Drummer** | James Brown – "Funky Drummer" (1970), drummer Clyde Stubblefield | Snappy snare, tight syncopation; the most-sampled break overall. |
| Others | "Soul Pride," "Scorpio," "Tighten Up," "Hot Pants" | Common secondary breaks. |

**Working with breaks:**

- **Chop & resequence.** Slice the loop into individual hits (kick, snare, hats, ghosts)
  at 16th/32nd boundaries, then re-order them as MIDI/steps to build a *new* pattern —
  you're not stuck with the drummer's original groove. Reordering slices to imitate
  **ghost notes** and rolls is central.
- **Time-stretch to tempo.** Because breaks were played at ~120–140 BPM, they're stretched
  to ~170 (early jungle's audible "grainy" stretch artifacts became an aesthetic in
  themselves).
- **Two-break switching.** A classic technique: alternate between two different breaks
  each bar (or each 2 bars) for variation. The "Tramen" is a well-known composite of Amen
  + a James Brown break + an Alex Reece break.
- **Sampled break vs programmed drums.** Two philosophies, usually combined:
  - *Sampled/chopped break* → organic swing, human ghost notes, grit, "rolling" feel
    (jungle, drumfunk, liquid).
  - *Programmed one-shots* (individual tuned kick/snare/hat samples) → punchy, controlled,
    modern (neuro, jump-up).
  - Best practice is **layering both**: a chopped break for movement + a punchy programmed
    kick and a big "main" snare on top for weight and consistency, plus a sub-layer for
    the snare body.
- **Ghost notes** — low-velocity snare/hat hits between the main backbeats — are what give
  the beat its rolling, percussive life. Program them quieter than the main snare.

---

## 4. Bassline

The "bass" half of the name carries as much weight as the drums.

**Sub-bass (the foundation):**

- Usually a **pure sine** (sometimes triangle) with no harmonics; felt more than heard.
  Keep it **mono** and centred.
- Practical pitch window: root notes around **D#1–G#1 (~39–52 Hz)** balance "felt on a
  club rig" vs "audible on small speakers." Below ~39 Hz you lose it on most systems;
  above ~52 Hz it stops being *felt*. The bulk of low-end energy lives **~50–120 Hz**.
- Common keys chosen partly to keep the sub in that window: **E, F, F# minor** (also
  D minor / A minor in liquid).

**Reese bass (the signature "designed" bass):**

- **Origin:** Kevin "Reese" Saunderson, "Just Another Chance" (1988) — a Detroit-house
  invention, later adopted by jungle/D&B and dubstep.
- **How it's made:** two-or-more **detuned sawtooth** oscillators (optionally a pulse on
  osc 2) beating against each other. The detuning causes continuous **phase
  cancellation** → the characteristic slow-moving, "brooding," growling movement. Add
  unison voices (~3–5 per osc), lowpass filter with some resonance (a smooth jungle Reese
  sits with cutoff ~650 Hz, moderate resonance), and, for neuro, heavy
  distortion/saturation, chorus/phaser, and multiband processing.
- **Critical trick:** a detuned Reese has weak/absent fundamental (phase cancellation eats
  it) and is **not mono-safe**, so **split it**: keep a **clean mono sine sub** for the
  low fundamental, and let the detuned Reese layer live **above ~120 Hz** for the movement
  and grit. Sidechain only the sub's low band to the kick if needed.
- **Liquid vs neuro bass:** liquid uses clean/lightly saturated sub sines (little
  distortion — heavy distortion pushes it into neuro); neuro uses one-note, heavily
  modulated, distorted, "talking" Reese-derived basses, often in **Phrygian/Locrian**
  darkness.

**Kick/sub relationship & the two-step:**

- The kick and sub must **share the low end without colliding.** Tune the kick so its
  pitched body sits at a different note than the sub, or carve one with EQ; then use
  **sidechain** so the sub ducks briefly under each kick.
- The **two-step** bass/drum pattern: snares on beats 2 and 4; a kick on beat 1 and
  typically on the "and" region (around the 6th 16th), with extra kicks free to land on
  almost any 16th. The bass moves on the half-time grid underneath.
- **Reggae/dub influence:** long, sustained sub notes, off-beat "skank" stabs, and
  dub-style space/echo on the bass are direct inheritances from Jamaican sound-system
  music.

---

## 5. Song Structure / Arrangement

D&B/jungle is **DJ tool first**: arrangement is organised in **8/16/32-bar phrases** so
DJs can beatmatch and blend. At 174 BPM, **32 bars ≈ 44 s, 16 bars ≈ 22 s**.

**Standard template (~5–7 min):**

| Section | Bars | ~Time @174 | Role |
|---|---|---|---|
| **DJ Intro** | 32 | ~44 s | Stripped drums + atmosphere, minimal mid-range. First bass hit often at bar 17. Must layer cleanly under another track's outro. |
| **Build 1** | 16 | ~22 s | Rising tension: noise riser, snare roll (4–8 bars, accelerating), filter opening, added ghosts/hats. |
| **First Drop** | 64 (2×32) | ~88 s | Full arrangement. Split into two 32-bar halves with variation to avoid repetition. |
| **Mid / bridge** | 16–32 | — | Transition. |
| **Breakdown** | 32 | ~44 s | Drums often removed; new melodic material (pads, piano, strings, vocal hook); strategic silence (1–2 bars). Emotional contrast + the setup for the big second drop. |
| **Build 2** | 16 | ~22 s | More dramatic than build 1. |
| **Second Drop** | 64 | ~88 s | Must hit **harder** than the first. |
| **Outro** | 32 | ~44 s | Mirrors the intro (same drum density/pattern) for mix-out. |

Ranges seen in the wild: intro/build 32–144 bars, drops 32–96, breakdown/bridge 32–64.

**"The drop":** the moment full drums + bass re-enter after a build. Its impact is
*bought* by the contrast before it — a long, sparse breakdown makes the drop feel
enormous. Mark the transition deliberately (a beat of silence, an impact/riser tail, a
filtered kick).

**Double drop (two meanings):**

1. *Arrangement*: the track has two drops; the **second is bigger** — add layers (2nd bass
   patch, layered drums, vocal punch-ins, synth lead), more processing, and a
   related-but-distinct bass design.
2. *DJ technique*: aligning **two tracks' drops to hit simultaneously** — the reason
   phrase-accurate 8/16/32-bar structure and clean intros/outros matter.

**Tension & release** is the engine: strip back (breakdown) → wind up (build: riser +
snare roll + filter sweep) → release (drop). Automation *is* arrangement here — filter
sweeps, reverb sends up in breakdowns and down in drops, macro morphs between sections.

**Common mistakes:** intro too short/too mid-heavy to mix; identical first/second drops; a
build that doesn't justify its drop; no breakdown (back-to-back drops with no rest);
tracks running past ~7 min without justification.

---

## 6. Harmony & Melody

- **Minor keys dominate.** Liquid favours **D minor, A minor, F minor**; **D Dorian** is
  prized for a warmer, soulful colour (raised 6th). Dark styles (neuro/techstep) lean
  **Phrygian/Locrian** and dissonance.
- **Liquid harmony** = jazz/soul vocabulary: **7ths, 9ths, 11ths**, extended chords, lush
  pads, Rhodes/piano, warm evolving atmospheres; melody and emotion are the point.
- **Neuro/techstep harmony** = minimal or absent conventional melody; the "melody" is the
  **bass timbre modulation** and rhythmic sound design; mood is dark, mechanical, sci-fi.
- **Stabs** — short, rhythmic chord/organ hits (often reggae/ragga "skank" stabs, or the
  "hoover"/Reese stab) — punctuate on off-beats.
- **Pads & atmospheres** live mostly in the intro/breakdown; keep them out of the low-mids
  so they don't fight the bass (high-pass them).
- **Sampled vocals** are a defining texture: soulful hooks and acapellas in liquid;
  ragga/dancehall toasting and chopped one-shot phrases ("woo," "yeah," "amen") in jungle.
  Vocal snippets often double as rhythmic/percussive elements.

---

## 7. Production / Mix Specifics

- **Low-end is mono below ~120 Hz.** Kick + sub centred; the felt weight lives ~50–120 Hz.
  Split the Reese (mono sub sine + stereo detuned layer above ~120 Hz).
- **Kick + bass as one unit via sidechain.** Fast attack (~1–5 ms) catches the kick
  transient; medium release (~80–150 ms) lets the bass breathe back; ratio ~4:1–6:1.
  Advanced: **multiband sidechain only the bass's sub band** so the mids/highs stay
  constant and it's tight without audible pumping.
- **Keep drum transients sharp.** The break has to cut through a dense low end. **Prefer
  transient shapers over heavy compression** on drums (compression flattens exactly the
  punch you need). Layer a punchy programmed kick/snare over a chopped break for weight +
  attack.
- **Mud lives at ~150–500 Hz** — where sub harmonics, bass body, snare weight, pads and
  Reese mids all collide. Carve here first. Also tame harshness ~1–3 kHz. High-pass
  everything that doesn't need lows. Cut before you boost.
- **Level hierarchy (loud & punchy):** kick + main snare slightly on top; bass level
  roughly on par with drums; melodic hooks just under drums/bass; FX pushed back except
  during builds.
- **Reverb & space:** subtle reverb on hats/ghost snares; **high-pass the reverb/delay
  sends** so space doesn't muddy the low-mids. Big reverbs/verbed vocals belong to
  breakdowns; drops stay dry and tight (automate reverb send down on the drop).
- **Bass layering:** one clean sub + 2–3 character layers (mid growl, high grit) split by
  frequency is a reliable recipe.
- **Master chain:** gentle bus compression (~1–2 dB GR for glue) → multiband to control
  problem bands → limiter for competitive loudness. D&B masters are loud but must preserve
  drum transients.

---

## 8. Practical Composition Tips (good vs generic)

1. **Nail the break first.** Everything hangs off a rolling, swung drum groove with real
   ghost notes. A great chopped break with correct swing already sounds like D&B before
   anything else is added.
2. **Groove = shuffle + ghosts + swing.** Offset hats/ghost snares ~55–62% swing; vary
   velocities. Straight, evenly-loud 16ths = generic.
3. **Kick/sub tuning is step one of the low end.** Put kick body and sub at complementary
   pitches, then sidechain. Untuned kick-vs-bass clashing is the #1 "amateur" tell.
4. **Use silence as a weapon.** Turn things down *between* hits; the gaps make the hits
   punch. Negative space > over-layering.
5. **Design contrast into the arrangement.** The drop is only as big as the breakdown
   before it is empty. Build → release is the whole game; make builds (riser +
   accelerating snare roll + opening filter) actually earn the drop.
6. **Make the two drops different.** Second drop = new layer, new bass variation, more
   energy — never a copy-paste.
7. **Respect the phrase grid (8/16/32 bars) and give it DJ-ready 32-bar intro/outro** with
   matching drum density, minimal mid-range. This is what separates a "track" from a
   "loop."
8. **Layer/stack for a 3D sound.** Blend sampled-break character with punchy modern
   one-shots; stack bass in frequency bands.
9. **Steal texture from outside D&B and from odd sources.** Pitch down vocals, horns,
   foley, speech for bass and stabs; cross-genre influence is what makes standout tracks.
   Sampling culture (funk breaks, reggae, film dialogue) is baked into the genre's DNA.
10. **Pick a lane and commit to its palette.** Liquid = clean sub, jazzy 7th/9th chords,
    soulful vocals, warmth. Neuro = distorted modulated Reese, Phrygian darkness, surgical
    drums, no soft edges. Jungle = chopped Amen-forward breaks, dub sub, ragga vocals.
    Mixing signals muddily = generic.

**For a code/demoscene context specifically** (the highest-leverage, cheapest-to-synthesize
essentials): (a) a **half-time kick/snare skeleton at ~170 BPM** with (b) **swung 16th
ghost hats/snares**, over (c) a **mono sine sub** on the half-time grid in a **minor key
(E/F/F# minor)**, plus (d) an optional **detuned-saw Reese** layer for movement — arranged
in **32/16-bar phrases** with one clear **build → drop → breakdown → bigger drop**
contrast. That set alone reads unmistakably as D&B. (See also `docs/chiptune.md` for how to
approximate these within 4 mono channels and a limited waveform palette.)

---

## Sources

- [Drum and bass — Wikipedia](https://en.wikipedia.org/wiki/Drum_and_bass)
- [Jungle music — Wikipedia](https://en.wikipedia.org/wiki/Jungle_music)
- [History of drum and bass — Wikipedia](https://en.wikipedia.org/wiki/History_of_drum_and_bass)
- [Breakbeat hardcore — Wikipedia](https://en.wikipedia.org/wiki/Breakbeat_hardcore)
- [Amen break — Wikipedia](https://en.wikipedia.org/wiki/Amen_break)
- [Liquid drum and bass — Wikipedia](https://en.wikipedia.org/wiki/Liquid_drum_and_bass)
- [How To Make Drum & Bass: The Complete Guide — EDMProd](https://www.edmprod.com/how-to-make-drum-and-bass/)
- [Drum and Bass Track Structure & Arrangement — KAN Samples](https://kansamples.com/blogs/learn/dnb-track-arrangement)
- [How to Chop the Amen Break — KAN Samples](https://kansamples.com/blogs/learn/how-to-chop-amen-break)
- [Everything You Need To Know About The Reese Bass — Toolroom Academy](https://toolroomacademy.com/features/everything-you-need-to-know-about-the-reese-bass/)
- [How to Make Reese Basses for Drum and Bass — Noise Masters](https://noisemasters.eu/blogs/dnb-guides/how-to-make-reese-basses-for-drum-and-bass-a-step-by-step-guide)
- [How to Make Liquid Drum and Bass — BeatKey](https://www.beatkey.app/how-to-make-liquid-dnb-music)
- [Neurofunk — Melodigging](https://www.melodigging.com/genre/neurofunk)
- [How to Mix Drum and Bass (Without It Sounding Muddy) — Remasterify](https://blog.remasterify.com/how-to-mix-drum-and-bass-without-it-sounding-muddy/)
- [How to program 6 different jungle and drum 'n' bass grooves — MusicRadar](https://www.musicradar.com/how-to/program-6-different-jungle-6-dnb-grooves)
- [Creating Mind-Blowing DnB Drum Patterns — Unison](https://unison.audio/dnb-drum-patterns/)
- [Breakbeats: The 10 Best Drum Breaks Ever Recorded — LANDR](https://blog.landr.com/drum-breaks/)
- [Top 10 Iconic Drum & Bass / Jungle Breakbeats — WhoSampled](https://www.whosampled.com/news/2015/03/05/top-10-iconic-drum-bass-jungle-breakbeats/)
- [Drum and Bass (DnB) Explained: BPM, Sound & Subgenres — MelodyCraft](https://melodycraft.app/insights/drum-and-bass-dnb-breakbeat-explained)
- [Step-by-Step Guide to Producing Drum and Bass — Beatportal](https://www.beatportal.com/articles/818379-step-by-step-guide-to-producing-drum-and-bass-like-sub-focus-a-m-c-and-delta-heavy)
