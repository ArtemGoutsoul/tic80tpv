-- title:  Music In Code
-- author: Enkora / TPV
-- desc:   Code synth + mini-notation tracker. D&B / jungle x chiptune.
-- script: lua

-- =============================================================================
-- Compose entirely in code, one readable string per lane (TidalCycles-style
-- mini-notation). The engine synthesizes everything by poking the sound
-- registers at 0x0FF9C -- including the DRUMS, so we get breakbeats, not beeps.
--
-- MINI-NOTATION (per lane, space-separated steps):
--   c4 c#4 c-4  a note (accidental '#', '-' = natural; octave 0..8)
--   .  or  ~    rest (silence)
--   -           hold (let the current note keep ringing)
--   =           note off (cut the note)
--   k s h       drum hits on a drum lane (kick / snare / hat)
--   [a b]       subdivide ONE step into 2 (or 3+) faster hits  <- jungle rolls
--   x*4         repeat x four times inside its step (same as [x x x x])
--
-- 4 channels: BASS, LEAD, ARP, and DRUMS (all percussion multiplexed on one
-- channel, NES-style). To compose: edit LANES / INSTRUMENTS / DRUMS / PATTERN.
-- The <PALETTE> section at the bottom is REQUIRED (no palette => all black).
-- =============================================================================

local floor, sin, abs = math.floor, math.sin, math.abs
local TAU = math.pi * 2

local SOUND_BASE = 0xFF9C  -- 4 channels, 18 bytes each (see tic80-sound skill)
local CHANNELS = 4
local TRANSPOSE = 0        -- global shift in semitones

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
		if shape == "square" then
			value = (phase < 0.5) and 15 or 0
		elseif shape == "pulse25" then
			value = (phase < 0.25) and 15 or 0
		elseif shape == "saw" then
			value = floor(phase * 15 + 0.5)
		elseif shape == "triangle" then
			value = floor((1 - abs(phase * 2 - 1)) * 15 + 0.5)
		elseif shape == "sine" then
			value = floor((sin(phase * TAU) * 0.5 + 0.5) * 15 + 0.5)
		else -- noise
			value = 0
		end
		wave[i + 1] = value
	end
	return wave
end

local WAVEFORMS = {
	square = buildWave("square"),
	pulse = buildWave("pulse25"),
	saw = buildWave("saw"),
	triangle = buildWave("triangle"),
	sine = buildWave("sine"),
	noise = buildWave("noise"),
}

-- -----------------------------------------------------------------------------
-- Mini-notation compiler. Turns "k h . [h h] s" into timed events per lane.
-- -----------------------------------------------------------------------------

-- Split a pattern into top-level tokens, keeping [ ... ] groups intact.
local function tokenize(str)
	local tokens, buffer, depth = {}, "", 0
	for i = 1, #str do
		local ch = str:sub(i, i)
		if ch == "[" then depth = depth + 1; buffer = buffer .. ch
		elseif ch == "]" then depth = depth - 1; buffer = buffer .. ch
		elseif ch == " " and depth == 0 then
			if #buffer > 0 then tokens[#tokens + 1] = buffer; buffer = "" end
		else buffer = buffer .. ch end
	end
	if #buffer > 0 then tokens[#tokens + 1] = buffer end
	return tokens
end

-- Expand one step token into its atoms (handles [a b] groups and x*n repeats).
local function expandStep(token)
	local raw
	if token:sub(1, 1) == "[" then
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

-- Compile a lane string into {frame, atom} events over framesPerStep per step.
local function compileLane(patternStr, framesPerStep)
	local steps = tokenize(patternStr)
	local events = {}
	for stepIndex, token in ipairs(steps) do
		local baseFrame = (stepIndex - 1) * framesPerStep
		local atoms = expandStep(token)
		local count = #atoms
		for atomIndex, atom in ipairs(atoms) do
			if atom ~= "." and atom ~= "~" and atom ~= "-" then
				local frame = floor(baseFrame
					+ (atomIndex - 1) / count * framesPerStep + 0.5)
				events[#events + 1] = { frame = frame, atom = atom }
			end
		end
	end
	return events
end

-- -----------------------------------------------------------------------------
-- INSTRUMENTS (pitched) -- waveform + volume envelope + optional gate/vibrato.
-- gate = auto note-off after N frames (nil = ring until retriggered).
-- -----------------------------------------------------------------------------
local INSTRUMENTS = {
	bass = { wave = "saw", peak = 12, sustain = 10, attack = 1, decay = 6,
		release = 8, gate = nil, vibratoDepth = 2, vibratoRate = 5 },
	lead = { wave = "pulse", peak = 9, sustain = 5, attack = 2, decay = 8,
		release = 10, gate = 14, vibratoDepth = 3, vibratoRate = 6 },
	arp = { wave = "square", peak = 7, sustain = 0, attack = 1, decay = 4,
		release = 3, gate = 4, vibratoDepth = 0, vibratoRate = 0 },
}

-- DRUMS (one-shots). Pitched (kick) has a downward pitch envelope; noise
-- (snare/hat) uses noiseFreq for its "colour". peak = volume, ampFrames = length.
local DRUMS = {
	k = { wave = "triangle", pitchStart = 200, pitchEnd = 48,
		pitchFrames = 5, ampFrames = 9, peak = 14 },
	s = { wave = "noise", noiseFreq = 1400, ampFrames = 8, peak = 11 },
	h = { wave = "noise", noiseFreq = 2600, ampFrames = 3, peak = 6 },
}

-- -----------------------------------------------------------------------------
-- SONG -- the grid + one string per lane. 16 steps of 5 frames => ~180 BPM.
-- -----------------------------------------------------------------------------
local PATTERN = { steps = 16, framesPerStep = 5 }

local LANES = {
	{ channel = 0, instrument = "bass",
		pattern = "a2 .  .  .  .  .  e2 .  a2 .  .  .  g2 .  .  ." },
	{ channel = 1, instrument = "lead",
		pattern = ".  .  .  .  a4 .  .  .  .  .  c5 .  .  .  e5 =" },
	{ channel = 2, instrument = "arp",
		pattern = "a4 c5 e5 c5 a4 c5 e5 c5 a4 c5 e5 c5 a4 c5 e5 c5" },
	{ channel = 3, drums = true,
		pattern = "k  h  .  h  s  h  .  [h h] k  .  k  h  s  h  .  [s h]" },
}

-- =============================================================================
-- ENGINE -- to compose, edit above; leave this alone.
-- =============================================================================

-- Pre-compile every lane into an absolute-frame schedule for the whole loop.
local barLength = PATTERN.steps * PATTERN.framesPerStep
local schedule = {}   -- schedule[frame] = { {lane=, atom=}, ... }
for laneIndex, lane in ipairs(LANES) do
	for _, event in ipairs(compileLane(lane.pattern, PATTERN.framesPerStep)) do
		schedule[event.frame] = schedule[event.frame] or {}
		table.insert(schedule[event.frame], { lane = laneIndex, atom = event.atom })
	end
end

local voices = {}
for c = 0, CHANNELS - 1 do
	voices[c] = { on = false, mode = "melodic", age = 0, hz = 0,
		releasing = false, releaseAge = 0, instrument = nil }
end
local playFrame = 0

-- Envelope volume [0..15] for a pitched voice.
local function envelopeVolume(instrument, age, releasing, releaseAge)
	if releasing then
		local v = instrument.sustain
			- floor(releaseAge * instrument.sustain / (instrument.release + 1))
		return (v > 0) and v or 0
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

-- Write frequency + volume + waveform to a channel's registers.
local function pokeChannel(c, hz, volume, waveTable)
	local base = SOUND_BASE + 18 * c
	local freq = floor(hz + 0.5)
	if freq < 0 then freq = 0 elseif freq > 0xFFF then freq = 0xFFF end
	poke(base, freq & 0xFF)
	poke(base + 1, ((freq >> 8) & 0x0F) | ((volume & 0x0F) << 4))
	local waveNibble = (base + 2) * 2
	for i = 0, 31 do
		poke4(waveNibble + i, waveTable[i + 1])
	end
end

-- Fire a scheduled hit on its lane's channel.
local function triggerLane(laneIndex, atom)
	local lane = LANES[laneIndex]
	local voice = voices[lane.channel]
	if lane.drums then
		local instrument = DRUMS[atom]
		if instrument then
			voice.instrument, voice.mode = instrument, "drum"
			voice.age, voice.on, voice.releasing = 0, true, false
		end
	elseif atom == "=" then
		voice.releasing, voice.releaseAge = true, 0
	else
		local hz = parseHz(atom)
		if hz then
			voice.hz = hz * 2 ^ (TRANSPOSE / 12)
			voice.instrument = INSTRUMENTS[lane.instrument]
			voice.mode = "melodic"
			voice.age, voice.on, voice.releasing = 0, true, false
		end
	end
end

local function updateVoices()
	for c = 0, CHANNELS - 1 do
		local voice = voices[c]
		local instrument = voice.instrument
		if instrument and voice.on then
			if voice.mode == "drum" then
				if voice.age < instrument.ampFrames then
					local volume = floor(instrument.peak
						* (1 - voice.age / instrument.ampFrames))
					if volume < 0 then volume = 0 end
					local hz, wave
					if instrument.wave == "noise" then
						hz, wave = instrument.noiseFreq, WAVEFORMS.noise
					else
						local t = (voice.age < instrument.pitchFrames)
							and (voice.age / instrument.pitchFrames) or 1
						hz = instrument.pitchStart
							+ (instrument.pitchEnd - instrument.pitchStart) * t
						wave = WAVEFORMS[instrument.wave]
					end
					pokeChannel(c, hz, volume, wave)
					voice.age = voice.age + 1
				else
					voice.on = false
					poke(SOUND_BASE + 18 * c + 1, 0)
				end
			else
				if instrument.gate and not voice.releasing
						and voice.age >= instrument.gate then
					voice.releasing, voice.releaseAge = true, 0
				end
				local volume = envelopeVolume(instrument, voice.age,
					voice.releasing, voice.releaseAge)
				if voice.releasing then
					voice.releaseAge = voice.releaseAge + 1
					if volume <= 0 then voice.on = false end
				end
				local hz = voice.hz
				if instrument.vibratoDepth > 0 then
					local wobble = sin(voice.age / 60 * instrument.vibratoRate * TAU)
					hz = hz * (1 + wobble * instrument.vibratoDepth * 0.003)
				end
				pokeChannel(c, hz, volume, WAVEFORMS[instrument.wave])
				voice.age = voice.age + 1
			end
		else
			poke(SOUND_BASE + 18 * c + 1, 0)
		end
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
		local base = SOUND_BASE + 18 * c
		local volume = (peek(base + 1) >> 4) & 0x0F
		rect(44, y, volume * 10, 8, volume > 0 and (8 + c) or 15)
	end
	-- Playhead over the 16-step grid.
	for s = 0, PATTERN.steps - 1 do
		local x = 6 + s * 14
		rectb(x, 100, 12, 8, 15)
		if s == step then rect(x + 1, 101, 10, 6, 11) end
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
	playFrame = playFrame + 1
	if playFrame >= barLength then playFrame = 0 end
end

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>
