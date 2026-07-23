-- music01.lua -- the Total Perspective Vortex song data (iteration 01).
--
-- Song iterations are versioned: music01.lua, music02.lua, ... -- keep old ones
-- as reference/inspiration; a player cart requires whichever one is current.
--
-- Instruments, drum loops and the tune, built with the `tracker.lua` engine.
-- `require`d by the player carts (music-tester.lua, tpv.lua); it calls
-- Tracker.setSong at load. See the `music-in-code` skill for the composing API
-- and docs/ (music-plan) for the arrangement.

require "tracker"

local WAVE = Tracker.WAVE
local OFF = Tracker.OFF

-- ===========================================================================
-- INSTRUMENTS
-- ===========================================================================

-- D&B reese sub: fat detuned saw with a slow cutoff-LFO sweep, punchy amp.
local BASS = Tracker.instrument{
	wave = WAVE.HSAW, peak = 12, sustain = 10, attack = 1, decay = 10, release = 6,
	gate = nil, reeseDetune = 0.04,
	cutoff = 0.4, cutoffEnv = { attack = 1, decay = 18, sustain = 0.45, release = 6, amp = 0.5 },
	cutoffLfo = { rate = 0.7, depth = 0.18 },
}

-- PWM lead: hollow->full duty sweep + gentle cutoff shimmer.
local LEAD = Tracker.instrument{
	wave = WAVE.PULSE, peak = 8, sustain = 5, attack = 3, decay = 10, release = 12,
	gate = 16, pwm = true, pwmRate = 0.5, pwmDepth = 0.35,
	cutoff = 0.75, cutoffLfo = { rate = 0.25, depth = 0.2 },
}

-- thin plucky pulse for the fast arp.
local ARP = Tracker.instrument{
	wave = WAVE.PULSE, peak = 6, sustain = 0, attack = 1, decay = 5, release = 3,
	gate = 4, cutoff = 0.85,
}

-- slow evolving pad: starts dark, blooms open.
local PAD = Tracker.instrument{
	wave = WAVE.HSINE, peak = 7, sustain = 6, attack = 10, decay = 24, release = 30,
	gate = nil,
	cutoff = 0.22, cutoffEnv = { attack = 40, decay = 60, sustain = 0.5, release = 40, amp = 0.6 },
	cutoffLfo = { rate = 0.1, depth = 0.12 },
}

-- ===========================================================================
-- DRUM LOOPS (whole bars; started/stopped from the drums column)
-- ===========================================================================
local KICK      = Tracker.drumLoop("KICK",      "k  .  .  .  .  .  .  .  k  .  .  .  .  .  .  .")
local HALF      = Tracker.drumLoop("HALF",      "k  .  .  .  h  .  .  .  s  .  .  .  h  .  .  .")
local AMEN      = Tracker.drumLoop("AMEN",      "k  .  h  [s s] s  .  h  k  .  k  h  s  s  [h h] .  [s h]")
local AMEN_BUSY = Tracker.drumLoop("AMEN_BUSY", "k  [h h] h  [s s] s  .  [h h] k  [s h] k  h  s  [s s] [h h] .  [s h]")
local FILL      = Tracker.drumLoop("FILL",      "[k k] s  [s s] h  k  [s s] h  [s s] [k k] s  [s s] [h h] [s s] s  [s h] [s s h]")
local FORTY_TWO = Tracker.drumLoop("FORTY_TWO", "k  k  k  k  s  s  .  .  k  k  k  k  s  s  .  .")

-- ===========================================================================
-- THE TUNE -- one row per 1/16 step: { ch0_bass, ch1_lead, ch2_arp, drums }.
-- Cells: {} hold · {INST,"note",vol,cutoff} · {OFF} · {STOP} · {LOOP} (drums).
-- part="Name"/transpose=N ride on rows. Each part is a whole number of bars.
-- ===========================================================================
local tune = {
	-- ###### Fairy Cake (2 bars) -- DON'T PANIC: seed alone, huge space ########
	-- bar 1  Am (sub pedal)
	{ {BASS,"a2",0.55}, {LEAD,"a4",0.8,0.6}, {}, {KICK}, part = "Fairy Cake", transpose = 0 },
	{}, {},
	{ {}, {LEAD,"c5",0.75,0.6} },
	{}, {},
	{ {}, {LEAD,"e5",0.8,0.7} },
	{}, {}, {},
	{ {}, {LEAD,"d5",0.75,0.7} },
	{}, {},
	{ {}, {LEAD,"c5",0.7,0.6} },
	{}, {},
	-- bar 2  Am
	{ {BASS,"a2",0.55}, {LEAD,"a4",0.8,0.6} },
	{},
	{ {}, {LEAD,"e5",0.8,0.7} },
	{}, {}, {},
	{ {}, {LEAD,"d5",0.75,0.7} },
	{},
	{ {}, {LEAD,"c5",0.7,0.6} },
	{}, {}, {},
	{ {}, {LEAD,"a4",0.7,0.6} },
	{}, {}, {},

	-- ###### Extrapolation (2 bars) -- vamp + half break + soft arp ############
	-- bar 1  Am -> F
	{ {BASS,"a2",0.8}, {LEAD,"a4",0.8}, {ARP,"a4",0.55}, {HALF}, part = "Extrapolation" },
	{},
	{ {}, {}, {ARP,"c5",0.55} },
	{ {}, {LEAD,"c5",0.8} },
	{ {}, {}, {ARP,"e5",0.55} },
	{},
	{ {BASS,"a2",0.5}, {LEAD,"e5",0.8}, {ARP,"c5",0.55} },
	{},
	{ {BASS,"f2",0.8}, {}, {ARP,"f4",0.55} },
	{},
	{ {}, {LEAD,"d5",0.8}, {ARP,"a4",0.55} },
	{},
	{ {}, {}, {ARP,"c5",0.55} },
	{ {}, {LEAD,"c5",0.75} },
	{ {}, {}, {ARP,"a4",0.55} },
	{},
	-- bar 2  C -> G
	{ {BASS,"c2",0.8}, {LEAD,"a4",0.8}, {ARP,"c5",0.55} },
	{},
	{ {}, {}, {ARP,"e5",0.55} },
	{ {}, {LEAD,"e5",0.8} },
	{ {}, {}, {ARP,"g5",0.55} },
	{},
	{ {BASS,"c2",0.5}, {LEAD,"d5",0.8}, {ARP,"e5",0.55} },
	{},
	{ {BASS,"g2",0.8}, {}, {ARP,"g4",0.55} },
	{},
	{ {}, {LEAD,"c5",0.8}, {ARP,"b4",0.55} },
	{},
	{ {}, {}, {ARP,"d5",0.55} },
	{ {}, {LEAD,"a4",0.75} },
	{ {}, {}, {ARP,"b4",0.55} },
	{},

	-- ###### The Universe Unfolds (2 bars) -- full break, reese, theme #########
	-- bar 1  Am -> F   (amen break)
	{ {BASS,"a2",0.9}, {LEAD,"a4",0.9,0.5}, {ARP,"a4",0.5}, {AMEN}, part = "The Universe Unfolds" },
	{ {}, {}, {ARP,"c5",0.5} },
	{ {}, {LEAD,"c5",0.9}, {ARP,"e5",0.5} },
	{ {BASS,"a2",0.85}, {}, {ARP,"c5",0.5} },
	{ {}, {}, {ARP,"a4",0.5} },
	{ {}, {LEAD,"d5",0.9}, {ARP,"c5",0.5} },
	{ {BASS,"a2",0.85}, {}, {ARP,"e5",0.5} },
	{ {}, {LEAD,"e5",0.9}, {ARP,"c5",0.5} },
	{ {BASS,"f2",0.9}, {}, {ARP,"f4",0.5} },
	{ {}, {}, {ARP,"a4",0.5} },
	{ {}, {LEAD,"d5",0.9}, {ARP,"c5",0.5} },
	{ {BASS,"f2",0.85}, {}, {ARP,"a4",0.5} },
	{ {}, {LEAD,"c5",0.9}, {ARP,"f4",0.5} },
	{ {}, {}, {ARP,"a4",0.5} },
	{ {BASS,"f2",0.85}, {LEAD,"a4",0.9}, {ARP,"c5",0.5} },
	{ {}, {OFF}, {ARP,"a4",0.5} },
	-- bar 2  C -> G   (busier break)
	{ {BASS,"c2",0.9}, {LEAD,"c5",0.9,0.5}, {ARP,"c5",0.5}, {AMEN_BUSY} },
	{ {}, {}, {ARP,"e5",0.5} },
	{ {}, {LEAD,"e5",0.9}, {ARP,"g5",0.5} },
	{ {BASS,"c2",0.85}, {}, {ARP,"e5",0.5} },
	{ {}, {}, {ARP,"c5",0.5} },
	{ {}, {LEAD,"g5",0.9}, {ARP,"e5",0.5} },
	{ {BASS,"c2",0.85}, {}, {ARP,"g5",0.5} },
	{ {}, {LEAD,"e5",0.9}, {ARP,"e5",0.5} },
	{ {BASS,"g2",0.9}, {}, {ARP,"g4",0.5} },
	{ {}, {}, {ARP,"b4",0.5} },
	{ {}, {LEAD,"d5",0.9}, {ARP,"d5",0.5} },
	{ {BASS,"g2",0.85}, {}, {ARP,"b4",0.5} },
	{ {}, {LEAD,"c5",0.9}, {ARP,"g4",0.5} },
	{ {}, {}, {ARP,"b4",0.5} },
	{ {BASS,"g2",0.85}, {LEAD,"b4",0.9}, {ARP,"d5",0.5} },
	{ {}, {OFF}, {ARP,"b4",0.5} },

	-- ###### Vastness (2 bars, key +2) -- cosmic pad blooms, drums pull back ####
	-- bar 1  Bm -> G  (transposed +2)
	{ {PAD,"a3",0.7}, {LEAD,"a4",0.8,0.6}, {OFF}, {HALF}, part = "Vastness", transpose = 2 },
	{}, {},
	{ {}, {LEAD,"e5",0.8} },
	{}, {},
	{ {}, {LEAD,"d5",0.8} },
	{}, {},
	{ {PAD,"f3",0.7}, {LEAD,"c5",0.8} },
	{}, {},
	{ {}, {LEAD,"e5",0.8} },
	{},
	{ {}, {LEAD,"d5",0.75} },
	{},
	-- bar 2  D -> A
	{ {PAD,"c4",0.7}, {LEAD,"a4",0.8} },
	{}, {},
	{ {}, {LEAD,"c5",0.8} },
	{}, {},
	{ {}, {LEAD,"e5",0.8} },
	{}, {},
	{ {PAD,"g3",0.7}, {LEAD,"d5",0.8} },
	{}, {},
	{ {}, {LEAD,"c5",0.8} },
	{},
	{ {}, {OFF} },
	{},

	-- ###### You Are Here (2 bars) -- one lonely bleep, vast emptiness #########
	-- bar 1
	{ {OFF}, {LEAD,"a4",0.6,0.85}, {OFF}, {OFF}, part = "You Are Here", transpose = 0 },
	{}, {}, {}, {}, {}, {}, {}, {}, {},
	{ {}, {OFF} },
	{}, {}, {}, {}, {},
	-- bar 2  (a faint higher echo)
	{ {}, {LEAD,"e5",0.45,0.85} },
	{}, {}, {}, {}, {}, {}, {}, {}, {},
	{ {}, {OFF} },
	{}, {}, {}, {}, {},

	-- ###### Zaphod Wins (2 bars) -- triumphant fanfare, then the 4-2 fill #####
	-- bar 1  Am -> F   (big fill)
	{ {BASS,"a2",0.9}, {LEAD,"a4",1.0,0.7}, {ARP,"a4",0.6}, {FILL}, part = "Zaphod Wins" },
	{ {}, {LEAD,"c5",1.0}, {ARP,"c5",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"e5",0.6} },
	{ {}, {LEAD,"a5",1.0}, {ARP,"c5",0.6} },
	{ {BASS,"a2",0.85}, {}, {ARP,"a4",0.6} },
	{ {}, {LEAD,"g5",1.0}, {ARP,"c5",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"e5",0.6} },
	{ {}, {}, {ARP,"c5",0.6} },
	{ {BASS,"f2",0.9}, {LEAD,"a5",1.0}, {ARP,"f4",0.6} },
	{ {}, {}, {ARP,"a4",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"c5",0.6} },
	{ {}, {LEAD,"c5",1.0}, {ARP,"a4",0.6} },
	{ {BASS,"f2",0.85}, {LEAD,"a4",1.0}, {ARP,"f4",0.6} },
	{ {}, {}, {ARP,"a4",0.6} },
	{ {}, {}, {ARP,"c5",0.6} },
	{ {}, {OFF}, {ARP,"a4",0.6} },
	-- bar 2  Am -> F   (the 4-kick / 2-snare "42" fill)
	{ {BASS,"a2",0.9}, {LEAD,"a4",1.0,0.7}, {ARP,"a4",0.6}, {FORTY_TWO} },
	{ {}, {LEAD,"c5",1.0}, {ARP,"c5",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"e5",0.6} },
	{ {}, {LEAD,"a5",1.0}, {ARP,"c5",0.6} },
	{ {BASS,"a2",0.85}, {}, {ARP,"a4",0.6} },
	{ {}, {LEAD,"g5",1.0}, {ARP,"c5",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"e5",0.6} },
	{ {}, {}, {ARP,"c5",0.6} },
	{ {BASS,"f2",0.9}, {LEAD,"c5",1.0}, {ARP,"f4",0.6} },
	{ {}, {LEAD,"e5",1.0}, {ARP,"a4",0.6} },
	{ {}, {LEAD,"a5",1.0}, {ARP,"c5",0.6} },
	{ {}, {}, {ARP,"a4",0.6} },
	{ {BASS,"f2",0.85}, {LEAD,"a4",1.0}, {ARP,"f4",0.6} },
	{ {}, {}, {ARP,"a4",0.6} },
	{ {}, {}, {ARP,"c5",0.6} },
	{ {}, {OFF}, {ARP,"a4",0.6} },
}

Tracker.setSong(tune)
