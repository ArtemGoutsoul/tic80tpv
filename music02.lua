-- music02.lua -- Total Perspective Vortex song data (iteration 02): "You Are Here".
--
-- A D&B chiptune realising docs/music-plan-02.md: fast drum & bass drums under a
-- slow, trippy chiptune lead, over a HEAVY-but-SPARSE sub-bass. The arc is one
-- long zoom: a single point -> the vast, complex cosmos -> a hard shock of
-- silence -> back to the singularity. Home key F minor; the mode around the fixed
-- F tonic morphs pentatonic -> Dorian (wonder) -> Phrygian (dread) -> back.
--
-- Built with the tracker.lua engine; `require`d by the player carts. See the
-- `music-in-code` skill for the composing API.
--
-- Design notes (constraints of the 4-channel engine):
--   * Channels: ch0 bass, ch1 lead, ch2 arp/pad, ch3 drums.
--   * Only 3 melodic channels, so ch2 TIME-SHARES: it is the PAD during the zoom,
--     then the fast ARP "starfield" from the drop onward.
--   * One bass channel, so "the growling layer joins the sub" is realised as a
--     timbre switch: clean heavy SUB -> gritty GROWL for the dread sections
--     (can't literally stack two basses on one voice).
--   * Bass is triggered SPARSELY (about one huge hit per bar, tonic-F pedal) and
--     does NOT track the kick -- the kick carries the fast low transients, the sub
--     carries the rare weight. The silences between sub hits are the void.
--   * Tempo is global & integer-framed -> 180 BPM (the plan's 168 = 42x4 isn't on
--     the grid). The "42" wink lives in the FORTY_TWO fill + the 4-then-2 motif.

require "tracker"

local WAVE = Tracker.WAVE
local OFF, STOP = Tracker.OFF, Tracker.STOP

-- ===========================================================================
-- INSTRUMENTS
-- ===========================================================================

-- Heavy sub: deep, round sine, punchy attack, long release so a single hit
-- swells and rings out into silence. Sparse by use, huge by design.
local SUB = Tracker.instrument{
	wave = WAVE.SINE, peak = 15, sustain = 13, attack = 1, decay = 16, release = 44,
	gate = 54, cutoff = 1,
}

-- Gritty character bass: the "growling" reese layer for the dread sections.
-- Same weight + sparseness as SUB, but detuned and darker, with a moving filter.
local GROWL = Tracker.instrument{
	wave = WAVE.HSAW, peak = 14, sustain = 12, attack = 1, decay = 18, release = 40,
	gate = 56, reeseDetune = 0.05,
	cutoff = 0.32, cutoffEnv = { attack = 2, decay = 24, sustain = 0.4, release = 8, amp = 0.4 },
	cutoffLfo = { rate = 0.6, depth = 0.16 },
}

-- Slow trippy lead: hollow PWM pulse, woozy vibrato, a scoop into each note, long
-- release. gate=nil so notes ring legato until the next one (float). The mind.
local LEAD = Tracker.instrument{
	wave = WAVE.PULSE, peak = 8, sustain = 6, attack = 4, decay = 12, release = 24,
	gate = nil, pwm = true, pwmRate = 0.4, pwmDepth = 0.3,
	vibratoDepth = 8, vibratoRate = 4,
	pitchEnv = { attack = 8, decay = 6, sustain = 0, release = 1, semis = -2 },
	cutoff = 0.7, cutoffLfo = { rate = 0.2, depth = 0.2 },
}

-- Thin plucky pulse for the fast arpeggio starfield.
local ARP = Tracker.instrument{
	wave = WAVE.PULSE, peak = 6, sustain = 0, attack = 1, decay = 5, release = 3,
	gate = 4, cutoff = 0.85,
}

-- Slow evolving pad: the cosmic atmosphere that opens during the zoom (rides ch2).
local PAD = Tracker.instrument{
	wave = WAVE.HSINE, peak = 7, sustain = 6, attack = 12, decay = 24, release = 30,
	gate = nil,
	cutoff = 0.22, cutoffEnv = { attack = 40, decay = 60, sustain = 0.5, release = 40, amp = 0.6 },
	cutoffLfo = { rate = 0.1, depth = 0.12 },
}

-- ===========================================================================
-- DRUM LOOPS (whole bars; started/stopped from the drums column)
-- ===========================================================================
local TICKS     = Tracker.drumLoop("TICKS",     "k  .  h  .  h  .  h  .  k  .  h  .  h  .  s  .")
local HALF      = Tracker.drumLoop("HALF",      "k  .  .  .  h  .  .  .  s  .  .  .  h  .  .  .")
local AMEN      = Tracker.drumLoop("AMEN",      "k  .  h  [s s] s  .  h  k  .  k  h  s  s  [h h] .  [s h]")
local AMEN_BUSY = Tracker.drumLoop("AMEN_BUSY", "k  [h h] h  [s s] s  .  [h h] k  [s h] k  h  s  [s s] [h h] .  [s h]")
local FILL      = Tracker.drumLoop("FILL",      "[k k] s  [s s] h  k  [s s] h  [s s] [k k] s  [s s] [h h] [s s] s  [s h] [s s h]")
local FORTY_TWO = Tracker.drumLoop("FORTY_TWO", "k  k  k  k  s  s  .  .  k  k  k  k  s  s  .  .")

-- ===========================================================================
-- BUILDER -- paint events onto whole-bar parts, then concatenate.
-- Rows are { ch0_bass, ch1_lead, ch2_arp, drums }; each starts as three empty
-- cells (a 4th is added only when the drum column is written). Row indices are
-- 1-based within a part; bar b (0-based) starts at row b*16 + 1.
-- ===========================================================================
local tune = {}

local function makePart(bars)
	local t = {}
	for i = 1, bars * 16 do t[i] = { {}, {}, {} } end
	return t
end

local function appendPart(t)
	for i = 1, #t do tune[#tune + 1] = t[i] end
end

local function pset(t, i, col, cell) if t[i] then t[i][col] = cell end end
local function pBass(t, i, c) pset(t, i, 1, c) end
local function pLead(t, i, c) pset(t, i, 2, c) end
local function pArp(t, i, c)  pset(t, i, 3, c) end
local function pDrum(t, i, c) pset(t, i, 4, c) end

-- Lay a repeating arpeggio across a bar: notes cycled at every `every`th 16th.
local function arpBar(t, bar, notes, every, vol)
	local base, k = bar * 16, 0
	for r = 1, 16, every do
		pArp(t, base + r, { ARP, notes[(k % #notes) + 1], vol })
		k = k + 1
	end
end

-- ===========================================================================
-- I. "You Are Here" -- the singularity (8 bars)
-- One small voice alone in silence: the seed motif ("four-then-two"), pentatonic,
-- slow. No drums, no bass. A single point of light and sound.
-- ===========================================================================
local P1 = makePart(8)
P1[1].part = "You Are Here"
pDrum(P1, 1, { OFF })

-- 2-bar seed phrase: four notes climbing, then two settling.
local SEED = { { 1, "f4" }, { 5, "a-4" }, { 9, "c5" }, { 13, "e-5" }, { 17, "c5" }, { 25, "b-4" } }
for rep = 0, 3 do
	local off = rep * 32
	for _, ev in ipairs(SEED) do
		pLead(P1, off + ev[1], { LEAD, ev[2], 0.65, 0.55 })
	end
end
pLead(P1, 125, { OFF })   -- let the last note breathe before the machine wakes
appendPart(P1)

-- ===========================================================================
-- II. "The Machine Wakes" -- the zoom begins (16 bars)
-- A pad opens (Dorian brightening), skittering machinery ticks in, and the first
-- lonely huge sub hits fall into the void (one every 4 bars). The seed reaches up.
-- ===========================================================================
local P2 = makePart(16)
P2[1].part = "The Machine Wakes"
pDrum(P2, 1, { TICKS })
pDrum(P2, 8 * 16 + 1, { HALF })            -- bar 9: hint the half-time groove

-- pad chords on ch2, one per 4 bars (Dorian: i - III - bVII - IV roots)
local PAD_ROOTS = { "f3", "a-3", "e-3", "b-3" }
for q = 0, 3 do
	pArp(P2, q * 64 + 1, { PAD, PAD_ROOTS[q + 1], 0.6 })
end

-- first lonely sub hits: one huge f2, ringing, every 4 bars
for q = 0, 3 do
	pBass(P2, q * 64 + 1, { SUB, "f2", 0.85 })
end

-- lead: the seed now reaches upward toward f5
local SEED2 = { { 1, "f4" }, { 5, "a-4" }, { 9, "c5" }, { 13, "e-5" }, { 17, "f5" }, { 21, "e-5" }, { 25, "c5" } }
for rep = 0, 7 do
	local off = rep * 32
	for _, ev in ipairs(SEED2) do
		pLead(P2, off + ev[1], { LEAD, ev[2], 0.7, 0.6 })
	end
end
appendPart(P2)

-- ===========================================================================
-- III. "The Drop" -- vastness unfolds (32 bars)
-- Full fast D&B. Frantic rolling drums under the slow floating lead, huge sub hits
-- landing sparsely (tonic-F pedal, one per bar, moving to the 5th every 4th bar),
-- and the arp starfield switches on. Harmony opens (F Dorian, i-III-bVII-IV).
-- ===========================================================================
local P3 = makePart(32)
P3[1].part = "The Drop"

-- drums: 3 bars AMEN + 1 bar AMEN_BUSY, with a mid FILL and a "42" fill to close
for b = 0, 31 do
	if b % 4 == 3 then pDrum(P3, b * 16 + 1, { AMEN_BUSY })
	elseif b % 4 == 0 then pDrum(P3, b * 16 + 1, { AMEN }) end
end
pDrum(P3, 15 * 16 + 1, { FILL })        -- bar 16 fill
pDrum(P3, 31 * 16 + 1, { FORTY_TWO })   -- bar 32: the 42 wink into complexity

-- sub: heavy + sparse, one hit per bar. F pedal, up to the 5th (c2) every 4th bar.
for b = 0, 31 do
	pBass(P3, b * 16 + 1, { SUB, (b % 4 == 3) and "c2" or "f2", 0.9 })
end

-- arp starfield (8th notes), chord tones by bar in the 4-bar cycle
local DROP_CHORDS = {
	{ "f4", "a-4", "c5", "f5" },   -- Fm
	{ "a-4", "c5", "e-5", "a-5" }, -- Ab
	{ "e-4", "g4", "b-4", "e-5" }, -- Eb
	{ "b-4", "d5", "f5", "b-5" },  -- Bb (D natural = Dorian colour)
}
for b = 0, 31 do arpBar(P3, b, DROP_CHORDS[(b % 4) + 1], 2, 0.5) end

-- lead: slow floating phrase, only two notes per bar (drifting over the fast drums)
local DROP_LEAD = {
	{ "f4", "c5" }, { "e-5", "c5" }, { "b-4", "g4" }, { "d5", "f5" },
}
for b = 0, 31 do
	local ph = DROP_LEAD[(b % 4) + 1]
	pLead(P3, b * 16 + 1, { LEAD, ph[1], 0.8, 0.6 })
	pLead(P3, b * 16 + 9, { LEAD, ph[2], 0.8, 0.6 })
end
appendPart(P3)

-- ===========================================================================
-- IV. "Further Out" -- complexity & dread (28 bars)
-- Busier break, the growling gritty bass (still sparse), higher/busier 16th arps,
-- and the harmony slides into F Phrygian (flat-2nd Gb, Db) -- vertiginous, dark.
-- The slow lead fragments, tiny against the churning immensity.
-- ===========================================================================
local P4 = makePart(28)
P4[1].part = "Further Out"
pDrum(P4, 1, { AMEN_BUSY })
pDrum(P4, 11 * 16 + 1, { FILL })
pDrum(P4, 12 * 16 + 1, { AMEN_BUSY })
pDrum(P4, 23 * 16 + 1, { FILL })
pDrum(P4, 24 * 16 + 1, { AMEN_BUSY })

-- gritty sub, still one hit per bar; a dark Db landmark every 4th bar
for b = 0, 27 do
	pBass(P4, b * 16 + 1, { GROWL, (b % 4 == 2) and "d-2" or "f2", 0.9 })
end

-- busier 16th arps, Phrygian dissonance climbing to a Gb top
local CX_ARPS = {
	{ "f4", "g-4", "a-4", "c5" },
	{ "a-4", "c5", "d-5", "f5" },
	{ "c5", "d-5", "f5", "a-5" },
	{ "a-4", "c5", "e-5", "g-5" },
}
for b = 0, 27 do arpBar(P4, b, CX_ARPS[(b % 4) + 1], 1, 0.5) end

-- fragmented, irregular lead cells (Gb/Db shadows)
local CX_LEAD = {
	{ "f4", "g-4", "f4" }, { "a-4", "g-4", "f4" },
	{ "d-5", "c5", "a-4" }, { "c5", "a-4", "g-4" },
}
for b = 0, 27 do
	local ph = CX_LEAD[(b % 4) + 1]
	pLead(P4, b * 16 + 1, { LEAD, ph[1], 0.75, 0.55 })
	pLead(P4, b * 16 + 5, { LEAD, ph[2], 0.7, 0.55 })
	pLead(P4, b * 16 + 11, { LEAD, ph[3], 0.7, 0.5 })
end
appendPart(P4)

-- ===========================================================================
-- V. "Total Perspective" -- the shock (12 bars)
-- Maximum density: relentless break, the heaviest/most-present sub, cascading
-- highest arps, the lead climbing to a stark cry. A big roll winds up... then a
-- hard hit and a beat of TOTAL SILENCE -- the annihilation.
-- ===========================================================================
local P5 = makePart(12)
P5[1].part = "Total Perspective"
pDrum(P5, 1, { AMEN_BUSY })
pDrum(P5, 9 * 16 + 1, { FILL })   -- bars 10-11: the wind-up roll

-- heaviest sub: f2 every bar, doubling to two hits/bar at the peak
for b = 0, 10 do
	pBass(P5, b * 16 + 1, { GROWL, "f2", 1.0 })
	if b >= 6 and b <= 8 then pBass(P5, b * 16 + 9, { GROWL, "f2", 0.9 }) end
end

-- cascading highest arps across the whole climax
for b = 0, 10 do arpBar(P5, b, { "c5", "d-5", "f5", "a-5" }, 1, 0.55) end

-- lead climbs to a stark statement (one note per bar, then rising in the build)
local CLIMB = { "f4", "a-4", "c5", "e-5", "f5", "e-5", "c5", "e-5", "f5" }
for b = 0, 8 do pLead(P5, b * 16 + 1, { LEAD, CLIMB[b + 1], 0.9, 0.6 }) end
pLead(P5, 9 * 16 + 1, { LEAD, "f5", 0.95, 0.65 })
pLead(P5, 9 * 16 + 9, { LEAD, "a-5", 0.95, 0.7 })
pLead(P5, 10 * 16 + 1, { LEAD, "c5", 0.95, 0.7 })
pLead(P5, 10 * 16 + 9, { LEAD, "f5", 1.0, 0.75 })

-- bar 12: the shock -- a colossal hit, then everything cut to silence
pBass(P5, 177, { SUB, "f1", 1.0 })      -- deepest, biggest hit
pLead(P5, 177, { LEAD, "f5", 1.0, 0.75 })
pArp(P5, 177, { ARP, "f5", 0.6 })
-- (drums keep crashing on the held FILL through rows 177-180)
pBass(P5, 181, { STOP })
pLead(P5, 181, { STOP })
pArp(P5, 181, { STOP })
pDrum(P5, 181, { OFF })
appendPart(P5)

-- ===========================================================================
-- VI. "You Are Here (reprise)" -- back to the singularity (12 bars)
-- Out of the silence, one last colossal sub note marks the implosion. Then the
-- opening motif returns, bare, thinning to a single F -- the dot. A faint, cheeky
-- flourish (optional -- Zaphod strolling out unfazed), then silence.
-- ===========================================================================
local P6 = makePart(12)
P6[1].part = "You Are Here (reprise)"
pDrum(P6, 1, { OFF })
pBass(P6, 1, { SUB, "f1", 1.0 })   -- the implosion: rings, then dies into silence

-- the bare seed returns (bars 3-6), softening each time
local SEED_R = { { 1, "f4" }, { 5, "a-4" }, { 9, "c5" }, { 13, "e-5" }, { 17, "c5" }, { 25, "a-4" } }
for _, ev in ipairs(SEED_R) do
	pLead(P6, 32 + ev[1], { LEAD, ev[2], 0.6, 0.55 })
	pLead(P6, 64 + ev[1], { LEAD, ev[2], 0.5, 0.5 })
end
-- thinning toward one point
pLead(P6, 97, { LEAD, "f4", 0.5, 0.5 })
pLead(P6, 105, { LEAD, "a-4", 0.45, 0.5 })
pLead(P6, 129, { LEAD, "f4", 0.45, 0.5 })
pLead(P6, 161, { LEAD, "f4", 0.4, 0.5 })   -- the single dot
pLead(P6, 169, { OFF })

-- optional Zaphod flourish (faint) -- delete these 4 lines to end on pure silence
pArp(P6, 177, { ARP, "f4", 0.3 })
pArp(P6, 179, { ARP, "a-4", 0.3 })
pArp(P6, 181, { ARP, "c5", 0.3 })
pArp(P6, 183, { ARP, "f5", 0.3 })

-- clean end (nothing rings into the loop restart)
pBass(P6, 192, { STOP })
pLead(P6, 192, { STOP })
pArp(P6, 192, { STOP })
pDrum(P6, 192, { OFF })
appendPart(P6)

Tracker.setSong(tune)
