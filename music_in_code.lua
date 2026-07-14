-- title:  Music In Code
-- author: Enkora / TPV
-- desc:   Code synth + mini-notation tracker. D&B / jungle x chiptune.
-- script: lua

-- =============================================================================
-- Compose entirely in code, one readable string per lane (TidalCycles-style
-- mini-notation). The engine synthesizes everything by poking the sound
-- registers at 0x0FF9C -- including the DRUMS, so we get breakbeats, not beeps.
--
-- 4 channels: BASS, LEAD, ARP, and DRUMS (all percussion multiplexed on one
-- channel, NES-style). To compose: edit LANES / INSTRUMENTS / DRUMS / PATTERN;
-- the mini-notation is documented above the LANES table.
-- The <PALETTE> section at the bottom is REQUIRED (no palette => all black).
-- =============================================================================

local floor, sin, abs = math.floor, math.sin, math.abs
local poke, poke4, peek = poke, poke4, peek  -- localize hot register access
local TAU = math.pi * 2

local SOUND_BASE = 0xFF9C     -- base of the sound registers
local CHANNEL_STRIDE = 18     -- bytes per channel in the register block
local CHANNELS = 4
local FREQ_MAX = 0xFFF        -- frequency register is 12-bit
local TRANSPOSE = 0           -- global shift in semitones

-- Waveform names (also the keys into WAVEFORMS).
local WAVE_SQUARE = "square"
local WAVE_PULSE = "pulse"
local WAVE_SAW = "saw"
local WAVE_TRIANGLE = "triangle"
local WAVE_SINE = "sine"
local WAVE_NOISE = "noise"

-- Voice playback modes.
local MODE_MELODIC = "melodic"
local MODE_DRUM = "drum"

-- Mini-notation tokens.
local TOKEN_REST = "."
local TOKEN_REST_ALT = "~"
local TOKEN_HOLD = "-"
local TOKEN_OFF = "="
local TOKEN_GROUP_OPEN = "["
local TOKEN_GROUP_CLOSE = "]"

-- -----------------------------------------------------------------------------
-- Note names -> Hz. The 12-bit frequency register value IS the pitch in Hz.
-- -----------------------------------------------------------------------------
local SEMITONE = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }

local function parseHz(atom)
	local letter, accidental, octave = atom:match("^(%a)([#%-]?)(%d)$")
	if not letter then return nil end
	local semitone = SEMITONE[letter:upper()]
	if not semitone then return nil end
	local midi = (tonumber(octave) + 1) * 12 + semitone
	if accidental == "#" then midi = midi + 1 end
	return 440 * 2 ^ ((midi - 69) / 12)
end

-- -----------------------------------------------------------------------------
-- Waveforms -- 32 samples in [0..15]. An all-zero table plays as noise.
-- -----------------------------------------------------------------------------
local function buildWave(shape)
	local wave = {}
	for i = 0, 31 do
		local phase = i / 32
		local value
		if shape == WAVE_SQUARE then
			value = (phase < 0.5) and 15 or 0
		elseif shape == WAVE_PULSE then
			value = (phase < 0.25) and 15 or 0
		elseif shape == WAVE_SAW then
			value = floor(phase * 15 + 0.5)
		elseif shape == WAVE_TRIANGLE then
			value = floor((1 - abs(phase * 2 - 1)) * 15 + 0.5)
		elseif shape == WAVE_SINE then
			value = floor((sin(phase * TAU) * 0.5 + 0.5) * 15 + 0.5)
		else -- WAVE_NOISE: an all-zero table plays as noise
			value = 0
		end
		wave[i + 1] = value
	end
	return wave
end

local WAVEFORMS = {
	[WAVE_SQUARE] = buildWave(WAVE_SQUARE),
	[WAVE_PULSE] = buildWave(WAVE_PULSE),
	[WAVE_SAW] = buildWave(WAVE_SAW),
	[WAVE_TRIANGLE] = buildWave(WAVE_TRIANGLE),
	[WAVE_SINE] = buildWave(WAVE_SINE),
	[WAVE_NOISE] = buildWave(WAVE_NOISE),
}

-- -----------------------------------------------------------------------------
-- Mini-notation compiler. Turns "k h . [h h] s" into timed events per lane.
-- -----------------------------------------------------------------------------

-- Split a pattern into top-level tokens, keeping [ ... ] groups intact.
local function tokenize(str)
	local tokens, buffer, depth = {}, "", 0
	for i = 1, #str do
		local ch = str:sub(i, i)
		if ch == TOKEN_GROUP_OPEN then
			depth = depth + 1
			buffer = buffer .. ch
		elseif ch == TOKEN_GROUP_CLOSE then
			depth = depth - 1
			buffer = buffer .. ch
		elseif ch == " " and depth == 0 then
			if #buffer > 0 then
				tokens[#tokens + 1] = buffer
				buffer = ""
			end
		else
			buffer = buffer .. ch
		end
	end
	if #buffer > 0 then tokens[#tokens + 1] = buffer end
	return tokens
end

-- Expand one step token into its atoms (handles [a b] groups and x*n repeats).
local function expandStep(token)
	local raw
	if token:sub(1, 1) == TOKEN_GROUP_OPEN then
		raw = tokenize(token:sub(2, #token - 1))
	else
		raw = { token }
	end
	local atoms = {}
	for _, atom in ipairs(raw) do
		local base, count = atom:match("^(.-)%*(%d+)$")
		if base and count then
			for _ = 1, tonumber(count) do atoms[#atoms + 1] = base end
		else
			atoms[#atoms + 1] = atom
		end
	end
	return atoms
end

-- Is this atom a rest/hold, i.e. produces no trigger event?
local function isSilentAtom(atom)
	return atom == TOKEN_REST or atom == TOKEN_REST_ALT or atom == TOKEN_HOLD
end

-- Compile a lane string into {frame, atom} events over framesPerStep per step.
local function compileLane(patternStr, framesPerStep)
	local steps = tokenize(patternStr)
	local events = {}
	for stepIndex, token in ipairs(steps) do
		local baseFrame = (stepIndex - 1) * framesPerStep
		local atoms = expandStep(token)
		local count = #atoms
		for atomIndex, atom in ipairs(atoms) do
			if not isSilentAtom(atom) then
				local frame = floor(baseFrame
					+ (atomIndex - 1) / count * framesPerStep + 0.5)
				events[#events + 1] = { frame = frame, atom = atom }
			end
		end
	end
	return events
end

-- -----------------------------------------------------------------------------
-- INSTRUMENTS (pitched) -- waveform + volume envelope + optional effects:
--   gate         auto note-off after N frames (nil = ring until retriggered)
--   vibratoDepth/vibratoRate   sinusoidal pitch wobble
--   reeseDetune  fake two detuned oscillators by alternating pitch each frame
--                (jungle "reese" bass); value is the detune ratio, e.g. 0.02
--   pwm/pwmRate/pwmDepth   rebuild the pulse waveform each frame with an
--                LFO-swept duty cycle (the classic evolving chiptune lead)
-- -----------------------------------------------------------------------------
local INSTRUMENTS = {
	-- reese sub: detuned saw (jungle's gnarly bass). For a clean sub instead,
	-- set wave = WAVE_TRIANGLE and reeseDetune = nil.
	bass = {
		wave = WAVE_SAW, peak = 11, sustain = 9, attack = 2, decay = 8,
		release = 10, gate = nil, vibratoDepth = 0, vibratoRate = 0,
		reeseDetune = 0.02
	},
	-- PWM lead: the duty cycle sweeps slowly for an evolving hollow-to-full tone
	lead = {
		wave = WAVE_PULSE, peak = 8, sustain = 5, attack = 3, decay = 10,
		release = 12, gate = 16, vibratoDepth = 0, vibratoRate = 0,
		pwm = true, pwmRate = 0.5, pwmDepth = 0.35
	},
	-- thin plucky pulse for the fast arp; short so notes stay distinct
	arp = {
		wave = WAVE_PULSE, peak = 6, sustain = 0, attack = 1, decay = 5,
		release = 3, gate = 4, vibratoDepth = 0, vibratoRate = 0
	},
}

-- DRUMS (one-shots). Kick = pitched: triangle with a downward pitch envelope.
-- Snare/hat = noise; noiseFreq sets the "colour", and an optional noiseFreqEnd
-- sweeps it over the hit (bright -> dark = a natural "pshh" tail).
-- peak = volume (0..15), ampFrames = length in frames.
local DRUMS = {
	k = { wave = WAVE_TRIANGLE, pitchStart = 240, pitchEnd = 55, pitchFrames = 7, ampFrames = 12, peak = 15 },
	s = { wave = WAVE_NOISE, noiseFreq = 2200, noiseFreqEnd = 700, ampFrames = 8, peak = 12 },
	h = { wave = WAVE_NOISE, noiseFreq = 3500, ampFrames = 2, peak = 5 },
}

-- -----------------------------------------------------------------------------
-- SONG -- the grid + one string per lane. 16 steps of 5 frames => ~180 BPM.
-- -----------------------------------------------------------------------------
local PATTERN = { steps = 16, framesPerStep = 5 }

-- Each lane = one channel (0..3) + one instrument, or drums=true for the drum
-- lane. `pattern` is read left-to-right, one token per step (16 steps here).
-- Tokens:
--   a2  c#5  c-5   play a note: letter A..G, then '#' sharp / '-' natural
--                  (or nothing), then octave 0..8.  a4 = 440 Hz.
--   .   or  ~      rest -- silence / leave the channel alone this step
--   -              hold -- let the note from a previous step keep ringing
--   =              note off -- cut the ringing note
--   k  s  h        drum hits: kick / snare / hat  (drums lane only)
--   [a b]          subdivide ONE step into 2 (or 3+) faster hits -> rolls/flams
--                  e.g. "[s s]" = a two-hit snare roll inside one 16th
--   x*4            repeat a token 4x inside its step, same as "[x x x x]"
-- Extra spaces are ignored, so pad columns however lines up best for you.
-- All lanes share the 16-step grid; use [ ] and * for anything faster.
-- Add  off = true  to a lane to mute it (handy for testing; off = 1 works too).
local LANES = {
	{
		channel = 0, instrument = "bass",
		pattern = "a2 .  .  .  .  .  e2 .  a2 .  .  .  g2 .  .  ."
	},
	{
		channel = 1, instrument = "lead",
		pattern = ".  .  .  .  a4 .  .  .  .  .  c5 .  .  .  e5 ="
	},
	{
		channel = 2, instrument = "arp",
		pattern = "a4 c5 e5 c5 a4 c5 e5 c5 a4 c5 e5 c5 a4 c5 e5 c5"
	},
	{
		-- busier amen-style break: syncopated kicks, ghost snares, hat & snare rolls
		channel = 3, drums = true,
		pattern = "k  .  h  [s s] s  .  h  k  .  k  h  s  s  [h h] .  [s h]"
	},
}

-- =============================================================================
-- ENGINE -- to compose, edit above; leave this alone.
-- =============================================================================

-- Pre-compile every (non-muted) lane into an absolute-frame schedule.
local barLength = PATTERN.steps * PATTERN.framesPerStep
local schedule = {}   -- schedule[frame] = { {lane=, atom=}, ... }

local function scheduleLane(laneIndex, lane)
	if lane.off then return end
	for _, event in ipairs(compileLane(lane.pattern, PATTERN.framesPerStep)) do
		schedule[event.frame] = schedule[event.frame] or {}
		table.insert(schedule[event.frame], { lane = laneIndex, atom = event.atom })
	end
end

for laneIndex, lane in ipairs(LANES) do
	scheduleLane(laneIndex, lane)
end

local voices = {}
for c = 0, CHANNELS - 1 do
	voices[c] = { on = false, mode = MODE_MELODIC, age = 0, hz = 0,
		releasing = false, releaseAge = 0, instrument = nil, waveTable = nil }
end
local playFrame = 0
local clock = 0   -- free-running frame counter for LFOs (never wraps at bar end)

-- Envelope volume [0..15] for a pitched voice.
local function envelopeVolume(instrument, age, releasing, releaseAge)
	if releasing then
		local level = instrument.sustain
			- floor(releaseAge * instrument.sustain / (instrument.release + 1))
		return (level > 0) and level or 0
	end
	if age < instrument.attack then
		return floor(instrument.peak * age / instrument.attack)
	end
	local decayAge = age - instrument.attack
	if decayAge < instrument.decay then
		local drop = (instrument.peak - instrument.sustain) * decayAge / instrument.decay
		return floor(instrument.peak - drop)
	end
	return instrument.sustain
end

-- Load a channel's 32-nibble waveform. MUST be rewritten every frame: TIC-80's
-- sound engine clears the waveform registers each tick, so a waveform set only
-- once decays to all-zero -- which the chip plays as NOISE, not silence.
local function setWaveform(c, waveTable)
	local waveNibble = (SOUND_BASE + CHANNEL_STRIDE * c + 2) * 2
	for i = 0, 31 do
		poke4(waveNibble + i, waveTable[i + 1])
	end
end

-- Scratch waveform reused for PWM so we don't allocate a table every frame.
local dutyBuffer = {}

-- Fill a 32-nibble buffer with a pulse wave of the given duty (0..1).
local function fillPulse(buffer, duty)
	local threshold = floor(duty * 32 + 0.5)
	for i = 0, 31 do
		buffer[i + 1] = (i < threshold) and 15 or 0
	end
end

-- Update just frequency + volume for a channel (cheap; safe to call per frame).
local function pokeFreqVol(c, hz, volume)
	local base = SOUND_BASE + CHANNEL_STRIDE * c
	local freq = floor(hz + 0.5)
	if freq < 0 then
		freq = 0
	elseif freq > FREQ_MAX then
		freq = FREQ_MAX
	end
	poke(base, freq & 0xFF)
	poke(base + 1, ((freq >> 8) & 0x0F) | ((volume & 0x0F) << 4))
end

-- Silence a channel (zero its volume nibble).
local function silenceChannel(c)
	poke(SOUND_BASE + CHANNEL_STRIDE * c + 1, 0)
end

-- Fire a scheduled hit on its lane's channel.
local function triggerLane(laneIndex, atom)
	local lane = LANES[laneIndex]
	local voice = voices[lane.channel]
	if lane.drums then
		local instrument = DRUMS[atom]
		if not instrument then return end
		voice.instrument, voice.mode = instrument, MODE_DRUM
		voice.age, voice.on, voice.releasing = 0, true, false
		voice.waveTable = WAVEFORMS[instrument.wave]
		return
	end
	if atom == TOKEN_OFF then
		voice.releasing, voice.releaseAge = true, 0
		return
	end
	local hz = parseHz(atom)
	if not hz then return end
	voice.hz = hz * 2 ^ (TRANSPOSE / 12)
	voice.instrument = INSTRUMENTS[lane.instrument]
	voice.mode = MODE_MELODIC
	voice.age, voice.on, voice.releasing = 0, true, false
	voice.waveTable = WAVEFORMS[voice.instrument.wave]
end

-- Advance a drum (one-shot) voice by one frame.
local function updateDrumVoice(c, voice, instrument)
	if voice.age >= instrument.ampFrames then
		voice.on = false
		silenceChannel(c)
		return
	end
	local volume = floor(instrument.peak * (1 - voice.age / instrument.ampFrames))
	if volume < 0 then volume = 0 end
	local hz
	if instrument.wave == WAVE_NOISE then
		hz = instrument.noiseFreq
		if instrument.noiseFreqEnd then
			hz = hz + (instrument.noiseFreqEnd - hz) * (voice.age / instrument.ampFrames)
		end
	else
		local sweep = (voice.age < instrument.pitchFrames)
			and (voice.age / instrument.pitchFrames) or 1
		hz = instrument.pitchStart + (instrument.pitchEnd - instrument.pitchStart) * sweep
	end
	setWaveform(c, voice.waveTable)
	pokeFreqVol(c, hz, volume)
	voice.age = voice.age + 1
end

-- Advance a pitched (melodic) voice by one frame.
local function updateMelodicVoice(c, voice, instrument)
	if instrument.gate and not voice.releasing and voice.age >= instrument.gate then
		voice.releasing, voice.releaseAge = true, 0
	end
	local volume = envelopeVolume(instrument, voice.age, voice.releasing, voice.releaseAge)
	if voice.releasing then
		voice.releaseAge = voice.releaseAge + 1
		if volume <= 0 then voice.on = false end
	end
	local hz = voice.hz
	if instrument.vibratoDepth > 0 then
		local wobble = sin(voice.age / 60 * instrument.vibratoRate * TAU)
		hz = hz * (1 + wobble * instrument.vibratoDepth * 0.003)
	end
	-- Reese: alternate between the note and a detuned copy each frame to fake
	-- two beating oscillators (jungle bass) on a single channel.
	if instrument.reeseDetune and voice.age % 2 == 1 then
		hz = hz * (1 + instrument.reeseDetune)
	end
	-- PWM: rebuild the pulse each frame with an LFO-swept duty (evolving lead).
	if instrument.pwm then
		local duty = 0.5 + sin(clock / 60 * instrument.pwmRate * TAU) * instrument.pwmDepth
		if duty < 0.1 then duty = 0.1 elseif duty > 0.9 then duty = 0.9 end
		fillPulse(dutyBuffer, duty)
		setWaveform(c, dutyBuffer)
	else
		setWaveform(c, voice.waveTable)
	end
	pokeFreqVol(c, hz, volume)
	voice.age = voice.age + 1
end

-- Advance one channel's voice; silence it if nothing is playing.
local function updateVoice(c)
	local voice = voices[c]
	local instrument = voice.instrument
	if not (instrument and voice.on) then
		silenceChannel(c)
		return
	end
	if voice.mode == MODE_DRUM then
		updateDrumVoice(c, voice, instrument)
		return
	end
	updateMelodicVoice(c, voice, instrument)
end

local function updateVoices()
	for c = 0, CHANNELS - 1 do
		updateVoice(c)
	end
end

-- -----------------------------------------------------------------------------
-- Readout for verification without sound.
-- -----------------------------------------------------------------------------
local LANE_NAMES = { "BASS", "LEAD", "ARP ", "DRUM" }

local function DrawReadout()
	cls(0)
	local step = playFrame // PATTERN.framesPerStep
	local bpm = floor(60 * 60 / (PATTERN.framesPerStep * 4) + 0.5)
	print("MUSIC IN CODE  -  dnb x chiptune", 6, 6, 11)
	print(bpm .. " BPM    step " .. (step + 1) .. "/" .. PATTERN.steps, 6, 18, 13)
	for c = 0, CHANNELS - 1 do
		local y = 34 + c * 15
		print(LANE_NAMES[c + 1], 6, y, 6)
		local base = SOUND_BASE + CHANNEL_STRIDE * c
		local volume = (peek(base + 1) >> 4) & 0x0F
		rect(44, y, volume * 10, 8, volume > 0 and (8 + c) or 15)
	end
	-- Playhead over the 16-step grid.
	for i = 0, PATTERN.steps - 1 do
		local x = 6 + i * 14
		rectb(x, 100, 12, 8, 15)
		if i == step then rect(x + 1, 101, 10, 6, 11) end
	end
	print("edit LANES / INSTRUMENTS / DRUMS to compose", 6, 122, 13, false, 1, true)
end

function TIC()
	local hits = schedule[playFrame]
	if hits then
		for _, hit in ipairs(hits) do triggerLane(hit.lane, hit.atom) end
	end
	updateVoices()
	DrawReadout()
	clock = clock + 1
	playFrame = playFrame + 1
	if playFrame >= barLength then playFrame = 0 end
end

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>
