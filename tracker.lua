-- tracker.lua -- reusable code-synth + tracker for TIC-80.
--
-- A drop-in music engine: a small subtractive synth (oscillator -> live low-pass
-- filter -> sound registers, rewritten every frame) plus a flat row-by-row
-- sequencer with looping drum patterns. It holds NO song data and draws NO UI --
-- the song lives in a separate file, the debug UI in the player cart.
--
-- Loads as a global `Tracker` (so amalgamation later is a plain prepend). See the
-- `music-in-code` skill for the composing API and `tic80-sound` for how the synth
-- works internally.
--
-- Minimal use (e.g. in a demo):
--     require "tracker"; require "music01"      -- the song file calls Tracker.setSong
--     function TIC() Tracker.update(); local row = Tracker.row() ... end
--
-- Building a song (in the song file, e.g. music01.lua):
--     local OFF = Tracker.OFF
--     local BASS = Tracker.instrument{ wave = Tracker.WAVE.HSAW, ... }
--     local AMEN = Tracker.drumLoop("AMEN", "k . h [s s] ...")
--     Tracker.setSong{ { {BASS,"a2"}, {}, {}, {AMEN}, part="Intro" }, ... }

Tracker = {}

local floor, sin, abs = math.floor, math.sin, math.abs
local poke, poke4, peek = poke, poke4, peek
local TAU = math.pi * 2

-- Fixed hardware layout; STEPS/STEP_FRAMES/CHANNELS are configurable.
local SOUND_BASE = 0xFF9C
local CHANNEL_STRIDE = 18
local FREQ_MAX = 0xFFF
local CHANNELS = 4
local STEPS = 16          -- steps per bar
local STEP_FRAMES = 5     -- frames per step (60/5 = 12 rows/sec; 180 BPM)

-- ---------------------------------------------------------------------------
-- Waveforms (32 samples, 0..15). all-zero plays as noise.
-- ---------------------------------------------------------------------------
local WAVE_SQUARE, WAVE_PULSE, WAVE_SAW = "square", "pulse", "saw"
local WAVE_TRIANGLE, WAVE_SINE, WAVE_NOISE = "triangle", "sine", "noise"
local WAVE_HSAW, WAVE_HSINE, WAVE_HSQUARE = "hsaw", "hsine", "hsquare"

Tracker.WAVE = {
	SQUARE = WAVE_SQUARE, PULSE = WAVE_PULSE, SAW = WAVE_SAW,
	TRIANGLE = WAVE_TRIANGLE, SINE = WAVE_SINE, NOISE = WAVE_NOISE,
	HSAW = WAVE_HSAW, HSINE = WAVE_HSINE, HSQUARE = WAVE_HSQUARE,
}

local function buildWave(shape, harmonic)
	harmonic = harmonic or 1
	local wave = {}
	for i = 0, 31 do
		local phase = (i / 32 * harmonic) % 1
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
		else
			value = 0
		end
		wave[i + 1] = value
	end
	return wave
end

local function mixWave(a, b, weightA, weightB)
	local wave = {}
	for i = 1, 32 do
		local value = a[i] * weightA + b[i] * weightB
		if value < 0 then value = 0 elseif value > 15 then value = 15 end
		wave[i] = value
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
	[WAVE_HSAW] = mixWave(buildWave(WAVE_SAW, 1), buildWave(WAVE_SAW, 3), 0.8, 0.4),
	[WAVE_HSINE] = mixWave(buildWave(WAVE_SINE, 1), buildWave(WAVE_SINE, 3), 0.8, 0.4),
	[WAVE_HSQUARE] = mixWave(buildWave(WAVE_SQUARE, 1), buildWave(WAVE_SQUARE, 3), 0.8, 0.4),
}

-- Register a custom 32-sample waveform under a name.
function Tracker.wave(name, samples)
	WAVEFORMS[name] = samples
end

-- ---------------------------------------------------------------------------
-- Notes -> Hz (equal temperament).
-- ---------------------------------------------------------------------------
local SEMITONE = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }

local function parseHz(atom)
	local letter, accidental, octave = atom:match("^(%a)([#%-]?)(%d)$")
	if not letter then return nil end
	local semitone = SEMITONE[letter:upper()]
	if not semitone then return nil end
	local midi = (tonumber(octave) + 1) * 12 + semitone
	if accidental == "#" then midi = midi + 1 end
	if accidental == "-" then midi = midi - 1 end
	return 440 * 2 ^ ((midi - 69) / 12)
end

-- Cell sentinels used by song tables.
Tracker.OFF = {}
Tracker.STOP = {}
local OFF, STOP = Tracker.OFF, Tracker.STOP

-- ---------------------------------------------------------------------------
-- Mini-notation compiler (drum loops).
-- ---------------------------------------------------------------------------
local function tokenize(str)
	local tokens, buffer, depth = {}, "", 0
	for i = 1, #str do
		local ch = str:sub(i, i)
		if ch == "[" then
			depth = depth + 1
			buffer = buffer .. ch
		elseif ch == "]" then
			depth = depth - 1
			buffer = buffer .. ch
		elseif ch == " " and depth == 0 then
			if #buffer > 0 then tokens[#tokens + 1] = buffer; buffer = "" end
		else
			buffer = buffer .. ch
		end
	end
	if #buffer > 0 then tokens[#tokens + 1] = buffer end
	return tokens
end

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

local function isSilentAtom(atom)
	return atom == "." or atom == "~" or atom == "-"
end

local function compileLane(patternStr)
	local steps = tokenize(patternStr)
	local events = {}
	for stepIndex, token in ipairs(steps) do
		local baseFrame = (stepIndex - 1) * STEP_FRAMES
		local atoms = expandStep(token)
		local count = #atoms
		for atomIndex, atom in ipairs(atoms) do
			if not isSilentAtom(atom) then
				local frame = floor(baseFrame + (atomIndex - 1) / count * STEP_FRAMES + 0.5)
				events[#events + 1] = { frame = frame, atom = atom }
			end
		end
	end
	return events, #steps
end

-- ---------------------------------------------------------------------------
-- Default drum kit (one-shots on one channel). Override with Tracker.setDrum.
-- ---------------------------------------------------------------------------
local DRUMS = {
	k = { wave = WAVE_TRIANGLE, pitchStart = 115, pitchEnd = 50,
		pitchFrames = 4, ampFrames = 12, peak = 15 },
	s = { wave = WAVE_NOISE, noiseFreq = 2200, noiseFreqEnd = 700,
		ampFrames = 8, peak = 12 },
	h = { wave = WAVE_NOISE, noiseFreq = 3500, ampFrames = 2, peak = 5 },
}

function Tracker.setDrum(atom, def)
	DRUMS[atom] = def
end

-- Compile a mini-notation string into a looping drum pattern. Keep it a whole
-- bar (STEPS) so it re-locks to the downbeat every bar and never drifts.
function Tracker.drumLoop(name, patternStr)
	local events, steps = compileLane(patternStr)
	if steps % STEPS ~= 0 and STEPS % steps ~= 0 then
		trace("WARNING: drum loop '" .. name .. "' = " .. steps
			.. " steps -- not a whole bar or clean divisor (" .. STEPS
			.. "); it will drift against the melody")
	end
	local sched = {}
	for _, event in ipairs(events) do
		sched[event.frame] = sched[event.frame] or {}
		sched[event.frame][#sched[event.frame] + 1] = event.atom
	end
	return { sched = sched, frames = steps * STEP_FRAMES }
end

-- Build an instrument (a plain table with defaults filled). See the
-- `music-in-code` skill for the full field list.
function Tracker.instrument(def)
	def.wave = def.wave or WAVE_SQUARE
	def.peak = def.peak or 12
	def.sustain = def.sustain or def.peak
	def.attack = def.attack or 1
	def.decay = def.decay or 6
	def.release = def.release or 8
	return def
end

-- ---------------------------------------------------------------------------
-- Player state
-- ---------------------------------------------------------------------------
local SONG, PARTS = {}, {}
local SONG_LENGTH, PART_TOTAL = 0, 0
local songPos, frameInStep, clock = 0, 0, 0
local drumLoop, curTranspose = nil, 0
local muted = {}

local voices = {}
local function initVoices()
	voices = {}
	for c = 0, CHANNELS - 1 do
		voices[c] = { on = false, mode = "melodic", age = 0, hz = 0, releasing = false,
			releaseAge = 0, instrument = nil, waveTable = nil, noteVol = 1, noteCutoff = nil }
	end
end
initVoices()

-- Override defaults (steps/stepFrames/channels). Call before setSong.
function Tracker.configure(cfg)
	if cfg.steps then STEPS = cfg.steps end
	if cfg.stepFrames then STEP_FRAMES = cfg.stepFrames end
	if cfg.channels then CHANNELS = cfg.channels; initVoices() end
end

-- ---------------------------------------------------------------------------
-- Synth (per-frame)
-- ---------------------------------------------------------------------------
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

local function adsr(env, age, releasing, releaseAge)
	if releasing then
		local value = env.sustain * (1 - releaseAge / (env.release + 1))
		return value > 0 and value or 0
	end
	if age < env.attack then return age / env.attack end
	local decayAge = age - env.attack
	if decayAge < env.decay then return 1 - (1 - env.sustain) * (decayAge / env.decay) end
	return env.sustain
end

local lpTmp = {}
local function lowpass(src, cutoff, dst)
	local alpha = cutoff / (1 + cutoff)
	local inv = 1 - alpha
	lpTmp[1] = alpha * src[1] + inv * src[32]
	for i = 2, 32 do lpTmp[i] = alpha * src[i] + inv * lpTmp[i - 1] end
	dst[1] = alpha * lpTmp[1] + inv * lpTmp[32]
	for i = 2, 32 do dst[i] = alpha * lpTmp[i] + inv * dst[i - 1] end
end

local function setWaveform(c, waveTable)
	local waveNibble = (SOUND_BASE + CHANNEL_STRIDE * c + 2) * 2
	for i = 0, 31 do
		local value = floor(waveTable[i + 1] + 0.5)
		if value < 0 then value = 0 elseif value > 15 then value = 15 end
		poke4(waveNibble + i, value)
	end
end

local dutyBuffer, waveOut = {}, {}

local function fillPulse(buffer, duty)
	local threshold = floor(duty * 32 + 0.5)
	for i = 0, 31 do buffer[i + 1] = (i < threshold) and 15 or 0 end
end

local function pokeFreqVol(c, hz, volume)
	local base = SOUND_BASE + CHANNEL_STRIDE * c
	local freq = floor(hz + 0.5)
	if freq < 0 then freq = 0 elseif freq > FREQ_MAX then freq = FREQ_MAX end
	poke(base, freq & 0xFF)
	poke(base + 1, ((freq >> 8) & 0x0F) | ((volume & 0x0F) << 4))
end

local function silenceChannel(c)
	poke(SOUND_BASE + CHANNEL_STRIDE * c + 1, 0)
end

local function triggerNote(channel, instrument, note, vol, cutoff, transpose)
	local hz = parseHz(note)
	if not hz then return end
	local voice = voices[channel]
	voice.instrument = instrument
	voice.mode = "melodic"
	voice.hz = hz * 2 ^ (transpose / 12)
	voice.noteVol = vol or 1
	voice.noteCutoff = cutoff
	voice.age, voice.on, voice.releasing, voice.releaseAge = 0, true, false, 0
	voice.waveTable = WAVEFORMS[instrument.wave]
end

local function fireDrums()
	if not drumLoop then return end
	local hits = drumLoop.sched[clock % drumLoop.frames]
	if not hits then return end
	local voice = voices[CHANNELS - 1]
	for _, atom in ipairs(hits) do
		local instrument = DRUMS[atom]
		if instrument then
			voice.instrument, voice.mode = instrument, "drum"
			voice.age, voice.on, voice.releasing = 0, true, false
			voice.waveTable = WAVEFORMS[instrument.wave]
		end
	end
end

local function applyRow(row)
	curTranspose = row.transpose or 0
	for col = 1, CHANNELS - 1 do
		local channel = col - 1
		local cell = row[col]
		if cell and not muted[channel] then
			local first = cell[1]
			if first == OFF then
				local voice = voices[channel]
				voice.releasing, voice.releaseAge = true, 0
			elseif first == STOP then
				voices[channel].on = false
				silenceChannel(channel)
			elseif first then
				triggerNote(channel, first, cell[2], cell[3], cell[4], curTranspose)
			end
		end
	end
	local drumCell = row[CHANNELS]
	if drumCell then
		local first = drumCell[1]
		if first == OFF then
			drumLoop = nil
			voices[CHANNELS - 1].on = false
			silenceChannel(CHANNELS - 1)
		elseif first then
			drumLoop = first
		end
	end
end

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

local function updateMelodicVoice(c, voice, instrument)
	if instrument.gate and not voice.releasing and voice.age >= instrument.gate then
		voice.releasing, voice.releaseAge = true, 0
	end
	local volume = floor(envelopeVolume(instrument, voice.age, voice.releasing, voice.releaseAge)
		* (voice.noteVol or 1) + 0.5)
	if voice.releasing then
		voice.releaseAge = voice.releaseAge + 1
		if volume <= 0 then voice.on = false end
	end

	local hz = voice.hz
	if (instrument.vibratoDepth or 0) > 0 then
		local wobble = sin(voice.age / 60 * instrument.vibratoRate * TAU)
		hz = hz * (1 + wobble * instrument.vibratoDepth * 0.003)
	end
	if instrument.pitchEnv then
		local e = adsr(instrument.pitchEnv, voice.age, voice.releasing, voice.releaseAge)
		hz = hz * 2 ^ (instrument.pitchEnv.semis * e / 12)
	end
	if instrument.reeseDetune and voice.age % 2 == 1 then
		hz = hz * (1 + instrument.reeseDetune)
	end

	local cutoff = voice.noteCutoff or instrument.cutoff or 1
	if instrument.cutoffEnv then
		cutoff = cutoff + adsr(instrument.cutoffEnv, voice.age, voice.releasing, voice.releaseAge)
			* instrument.cutoffEnv.amp
	end
	if instrument.cutoffLfo then
		cutoff = cutoff + (0.5 + 0.5 * sin(clock / 60 * instrument.cutoffLfo.rate * TAU))
			* instrument.cutoffLfo.depth
	end
	if cutoff < 0 then cutoff = 0 elseif cutoff > 1 then cutoff = 1 end

	local src
	if instrument.pwm then
		local duty = 0.5 + sin(clock / 60 * instrument.pwmRate * TAU) * instrument.pwmDepth
		if duty < 0.1 then duty = 0.1 elseif duty > 0.9 then duty = 0.9 end
		fillPulse(dutyBuffer, duty)
		src = dutyBuffer
	else
		src = voice.waveTable
	end
	if cutoff < 0.999 then
		lowpass(src, cutoff, waveOut)
		setWaveform(c, waveOut)
	else
		setWaveform(c, src)
	end

	pokeFreqVol(c, hz, volume)
	voice.age = voice.age + 1
end

local function updateVoice(c)
	if muted[c] then
		silenceChannel(c)
		return
	end
	local voice = voices[c]
	local instrument = voice.instrument
	if not (instrument and voice.on) then
		silenceChannel(c)
		return
	end
	if voice.mode == "drum" then
		updateDrumVoice(c, voice, instrument)
	else
		updateMelodicVoice(c, voice, instrument)
	end
end

-- ---------------------------------------------------------------------------
-- Song compile + navigation
-- ---------------------------------------------------------------------------

-- Compile an authored tune (flat list of { ch0, ch1, ch2, drums } rows, with
-- optional part="Name"/transpose=N keys) into a uniform SONG + PARTS index.
function Tracker.setSong(tune)
	SONG, PARTS = {}, {}
	local pendingPart, xpose, curDrum = nil, 0, nil
	for _, row in ipairs(tune) do
		if row.transpose ~= nil then xpose = row.transpose end
		if row.part ~= nil then pendingPart = row.part end
		if #row > 0 or (row.part == nil and row.transpose == nil) then
			local drumCell = row[CHANNELS]
			if drumCell then
				if drumCell[1] == OFF then curDrum = nil
				elseif drumCell[1] then curDrum = drumCell[1] end
			end
			local compiled = { row[1], row[2], row[3], row[4],
				transpose = xpose, drumActive = curDrum }
			SONG[#SONG + 1] = compiled
			if pendingPart then
				PARTS[#PARTS + 1] = { name = pendingPart, row = #SONG - 1, transpose = xpose }
				pendingPart = nil
			end
		end
	end
	SONG_LENGTH, PART_TOTAL = #SONG, #PARTS
	Tracker.parts = PARTS

	-- Guard: each part must span a whole number of bars, else drums shift.
	for i = 1, PART_TOTAL do
		local partEnd = (PARTS[i + 1] and PARTS[i + 1].row) or SONG_LENGTH
		local steps = partEnd - PARTS[i].row
		if steps % STEPS ~= 0 then
			trace("WARNING: part '" .. PARTS[i].name .. "' = " .. steps
				.. " steps, not a whole number of bars (" .. STEPS .. ") -- drums will shift")
		end
	end

	initVoices()
	songPos, frameInStep, clock, drumLoop, curTranspose = 0, 0, 0, nil, 0
end

local function jumpTo(index)
	if PART_TOTAL == 0 then return end
	index = ((index - 1) % PART_TOTAL) + 1
	local part = PARTS[index]
	songPos = part.row
	frameInStep = 0
	clock = part.row * STEP_FRAMES
	curTranspose = part.transpose
	drumLoop = SONG[songPos + 1].drumActive
	for c = 0, CHANNELS - 1 do
		voices[c].on = false
		silenceChannel(c)
	end
end

function Tracker.currentPartIndex()
	local index = 1
	for i = 1, PART_TOTAL do
		if PARTS[i].row <= songPos then index = i else break end
	end
	return index
end

function Tracker.jumpToPart(index) jumpTo(index) end

-- Call once per frame from TIC(). Advances the sequencer and drives the synth.
function Tracker.update()
	if SONG_LENGTH == 0 then return end
	if frameInStep == 0 then applyRow(SONG[songPos + 1]) end
	fireDrums()
	for c = 0, CHANNELS - 1 do updateVoice(c) end
	clock = clock + 1
	frameInStep = frameInStep + 1
	if frameInStep >= STEP_FRAMES then
		frameInStep = 0
		songPos = songPos + 1
		if songPos >= SONG_LENGTH then songPos = 0 end
	end
end

-- ---------------------------------------------------------------------------
-- Read-only accessors (timing hooks for a demo, data for a debug UI)
-- ---------------------------------------------------------------------------
function Tracker.row() return songPos end                        -- current step id (0-based)
function Tracker.rowCount() return SONG_LENGTH end
function Tracker.frameInStepValue() return frameInStep end
function Tracker.stepProgress() return songPos + frameInStep / STEP_FRAMES end  -- fractional row
function Tracker.beat() return songPos // (STEPS // 4) end        -- 4 beats per bar
function Tracker.bar() return songPos // STEPS end
function Tracker.transpose() return (SONG[songPos + 1] and SONG[songPos + 1].transpose) or 0 end
function Tracker.partCount() return PART_TOTAL end
function Tracker.partAt(i) return PARTS[i] end                    -- { name, row, transpose }
function Tracker.partBars(i)
	local partEnd = (PARTS[i + 1] and PARTS[i + 1].row) or SONG_LENGTH
	return (partEnd - PARTS[i].row) // STEPS
end
function Tracker.bpm() return floor(60 * 60 / (STEP_FRAMES * 4) + 0.5) end
function Tracker.stepsPerBar() return STEPS end
function Tracker.channelCount() return CHANNELS end
function Tracker.toggleMute(c) muted[c] = not muted[c] end
function Tracker.isMuted(c) return muted[c] == true end
function Tracker.channelLevel(c) return (peek(SOUND_BASE + CHANNEL_STRIDE * c + 1) >> 4) & 0x0F end
