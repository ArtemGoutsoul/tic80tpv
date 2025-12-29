-- title:   Snow
-- author:
-- desc:    Procedural snowfall with 6-fold symmetric flakes,
--          parallax depth layers, sine wave drift, and
--          wind gusts triggered by spacebar
-- site:
-- license: MIT License
-- version: 0.1
-- script:  lua

-- =============================================================================
-- Constants
-- =============================================================================

-- Screen dimensions
local SCREEN_WIDTH = 240
local SCREEN_HEIGHT = 136

-- Colors
local COLOR_BLACK = 0

-- Input keys
local KEY_SPACE = 48

-- Snowflake pattern configuration
local FLAKE_SIZE = 11
local FLAKE_CENTER = 6
local FLAKE_PATTERN_COUNT = 20
local FLAKE_ARM_LENGTH_MIN = 3
local FLAKE_ARM_LENGTH_MAX = 5
local FLAKE_BRANCH_STYLE_COUNT = 4

-- Precomputed trigonometry for 60-degree rotations
local SIN_60 = 0.8660254037844386
local COS_60 = 0.5

-- Snowflake spawning
local SNOWFLAKE_COUNT = 100
local SPAWN_MARGIN = 20
local SPAWN_SIDE_MIN = -20
local SPAWN_SIDE_MAX_LEFT = -5
local SPAWN_SIDE_MIN_RIGHT = 245
local SPAWN_SIDE_MAX_RIGHT = 260

-- Depth and movement
local DEPTH_COLOR_MAP = {2, 3, 10, 8, 13, 15}  -- Far (dark) to close (bright)
local BASE_SPEED_MIN = 0.15
local BASE_SPEED_RANGE = 0.5
local SPEED_VARIATION = 0.03
local WAVE_AMPLITUDE_BASE = 8
local WAVE_AMPLITUDE_PER_DEPTH = 2
local WAVE_SPEED_MIN = 0.001
local WAVE_SPEED_MAX = 0.003

-- Wind and swirl effects
local WIND_INITIAL_STRENGTH = 5
local WIND_DECAY_RATE = 0.97
local WIND_THRESHOLD = 0.1
local WIND_SPAWN_THRESHOLD = 0.5
local SWIRL_INITIAL_STRENGTH = 1.5
local SWIRL_DECAY_RATE = 0.99
local SWIRL_THRESHOLD = 0.01
local SWIRL_SPEED_FACTOR = 0.01
local SWIRL_AMPLITUDE = 15

-- =============================================================================
-- Pattern Generation
-- =============================================================================

local function generateSnowflakePattern()
	local pattern = {}

	for row = 1, FLAKE_SIZE do
		pattern[row] = {}
		for col = 1, FLAKE_SIZE do
			pattern[row][col] = 0
		end
	end

	local function setPixel(dx, dy)
		local col = FLAKE_CENTER + dx
		local row = FLAKE_CENTER + dy
		if row >= 1 and row <= FLAKE_SIZE and col >= 1 and col <= FLAKE_SIZE then
			pattern[row][col] = 1
		end
	end

	local function setSymmetric(dx, dy)
		-- 0° and 180°
		setPixel(dx, dy)
		setPixel(-dx, -dy)

		-- 60° and 240°
		local x60 = math.floor(dx * COS_60 - dy * SIN_60 + 0.5)
		local y60 = math.floor(dx * SIN_60 + dy * COS_60 + 0.5)
		setPixel(x60, y60)
		setPixel(-x60, -y60)

		-- 120° and 300°
		local x120 = math.floor(-dx * COS_60 - dy * SIN_60 + 0.5)
		local y120 = math.floor(dx * SIN_60 - dy * COS_60 + 0.5)
		setPixel(x120, y120)
		setPixel(-x120, -y120)
	end

	-- Center pixel
	pattern[FLAKE_CENTER][FLAKE_CENTER] = 1

	-- Main arms
	local armLength = math.random(FLAKE_ARM_LENGTH_MIN, FLAKE_ARM_LENGTH_MAX)
	for i = 1, armLength do
		setSymmetric(i, 0)
	end

	-- Branch variations
	local branchStyle = math.random(1, FLAKE_BRANCH_STYLE_COUNT)

	if branchStyle == 1 then
		local branchPos = math.random(2, armLength - 1)
		setSymmetric(branchPos, 1)
		setSymmetric(branchPos, -1)
	elseif branchStyle == 2 then
		for i = 2, armLength - 1 do
			if i % 2 == 0 then
				setSymmetric(i, 1)
				setSymmetric(i, -1)
			end
		end
	elseif branchStyle == 3 then
		local branchPos = math.random(2, armLength - 1)
		setSymmetric(branchPos, 1)
		setSymmetric(branchPos, -1)
		setSymmetric(branchPos - 1, 2)
		setSymmetric(branchPos - 1, -2)
	else
		setSymmetric(1, 1)
		setSymmetric(1, -1)
	end

	return pattern
end

local function generateAllPatterns()
	local patterns = {}
	math.randomseed(12345)
	for _ = 1, FLAKE_PATTERN_COUNT do
		table.insert(patterns, generateSnowflakePattern())
	end
	return patterns
end

-- =============================================================================
-- Snowflake Management
-- =============================================================================

local snowflakePatterns = generateAllPatterns()
local snowflakes = {}
local windStrength = 0
local windDirection = 1
local swirlStrength = 0
local landedSnowflakes = {}  -- List of {x, y, patternIndex, color}

local function createSnowflake(randomY, fromSide)
	local startX, startY

	if fromSide then
		if windDirection > 0 then
			startX = math.random(SPAWN_SIDE_MIN, SPAWN_SIDE_MAX_LEFT)
		else
			startX = math.random(SPAWN_SIDE_MIN_RIGHT, SPAWN_SIDE_MAX_RIGHT)
		end
		startY = math.random(-FLAKE_SIZE, SCREEN_HEIGHT - FLAKE_SIZE)
	else
		startX = math.random(0, SCREEN_WIDTH)
		startY = randomY and math.random(-FLAKE_SIZE, SCREEN_HEIGHT) or math.random(-SPAWN_MARGIN, -FLAKE_SIZE)
	end

	local depthLevel = math.random(1, #DEPTH_COLOR_MAP)
	local depthFactor = depthLevel / #DEPTH_COLOR_MAP

	return {
		x = startX,
		y = startY,
		baseX = startX,
		depthLevel = depthLevel,
		depthFactor = depthFactor,
		speed = BASE_SPEED_MIN + depthFactor * BASE_SPEED_RANGE + math.random(-3, 3) * SPEED_VARIATION,
		patternIndex = math.random(1, #snowflakePatterns),
		color = DEPTH_COLOR_MAP[depthLevel],
		waveAmplitude = WAVE_AMPLITUDE_BASE + depthLevel * WAVE_AMPLITUDE_PER_DEPTH,
		waveSpeed = math.random(100, 300) / 100000 * (0.4 + depthFactor * 0.6),
		waveOffset = math.random() * math.pi * 2,
	}
end

local COLLISION_RADIUS = 2  -- Horizontal tolerance for center-to-center collision

local function checkSnowflakeCollision(flake)
	local centerX = math.floor(flake.x + 0.5) + FLAKE_CENTER - 1
	local centerY = math.floor(flake.y + 0.5) + FLAKE_CENTER - 1

	-- Check if hit bottom of screen
	if centerY >= SCREEN_HEIGHT - FLAKE_CENTER then
		return true
	end

	-- Check against landed snowflake centers (stop when on top of another)
	for _, landed in ipairs(landedSnowflakes) do
		local dx = math.abs(centerX - landed.x)
		if dx <= COLLISION_RADIUS and centerY >= landed.y - FLAKE_CENTER then
			return true
		end
	end

	return false
end

local function freezeSnowflake(flake)
	local centerX = math.floor(flake.x + 0.5) + FLAKE_CENTER - 1
	local centerY = math.floor(flake.y + 0.5) + FLAKE_CENTER - 1

	table.insert(landedSnowflakes, {
		x = centerX,
		y = centerY,
		patternIndex = flake.patternIndex,
		color = flake.color
	})
end

local function initSnowflakes()
	math.randomseed(time())
	snowflakes = {}
	landedSnowflakes = {}
	for _ = 1, SNOWFLAKE_COUNT do
		table.insert(snowflakes, createSnowflake(true, false))
	end
end

-- =============================================================================
-- Update Logic
-- =============================================================================

local function handleWindInput()
	if keyp(KEY_SPACE) then
		windStrength = WIND_INITIAL_STRENGTH
		windDirection = math.random() < 0.5 and -1 or 1
		swirlStrength = SWIRL_INITIAL_STRENGTH
	end
end

local function updateWindAndSwirl()
	if windStrength > 0 then
		windStrength = windStrength * WIND_DECAY_RATE
		if windStrength < WIND_THRESHOLD then
			windStrength = 0
		end
	end

	if swirlStrength > 0 then
		swirlStrength = swirlStrength * SWIRL_DECAY_RATE
		if swirlStrength < SWIRL_THRESHOLD then
			swirlStrength = 0
		end
	end
end

local function updateSnowflake(flake, index, currentTime)
	flake.y = flake.y + flake.speed

	local windEffect = windStrength * windDirection * flake.depthFactor
	flake.baseX = flake.baseX + windEffect

	local swirlWave = 0
	if swirlStrength > 0 then
		local swirlPhase = currentTime * SWIRL_SPEED_FACTOR * flake.depthFactor + flake.waveOffset * 3
		swirlWave = math.sin(swirlPhase) * swirlStrength * SWIRL_AMPLITUDE * flake.depthFactor
	end

	local baseWave = math.sin(currentTime * flake.waveSpeed + flake.waveOffset) * flake.waveAmplitude
	flake.x = flake.baseX + baseWave + swirlWave

	-- Check for collision with ground or pile
	if checkSnowflakeCollision(flake) then
		freezeSnowflake(flake)
		snowflakes[index] = createSnowflake(false, false)
		return
	end

	-- Check if blown off sides
	local isOffLeft = flake.baseX < -SPAWN_MARGIN
	local isOffRight = flake.baseX > SCREEN_WIDTH + SPAWN_MARGIN

	if isOffLeft or isOffRight then
		local fromSide = windStrength > WIND_SPAWN_THRESHOLD
		snowflakes[index] = createSnowflake(false, fromSide)
	end
end

local function updateAllSnowflakes(currentTime)
	for i, flake in ipairs(snowflakes) do
		updateSnowflake(flake, i, currentTime)
	end
end

local function sortSnowflakesByDepth()
	table.sort(snowflakes, function(a, b)
		return a.depthLevel < b.depthLevel
	end)
end

-- =============================================================================
-- Rendering
-- =============================================================================

local function drawSnowflake(flake)
	local pattern = snowflakePatterns[flake.patternIndex]
	for row = 1, FLAKE_SIZE do
		for col = 1, FLAKE_SIZE do
			if pattern[row][col] == 1 then
				pix(flake.x + col - 1, flake.y + row - 1, flake.color)
			end
		end
	end
end

local function drawAllSnowflakes()
	for _, flake in ipairs(snowflakes) do
		drawSnowflake(flake)
	end
end

local function drawLandedSnowflakes()
	for _, landed in ipairs(landedSnowflakes) do
		local pattern = snowflakePatterns[landed.patternIndex]
		local flakeX = landed.x - FLAKE_CENTER + 1
		local flakeY = landed.y - FLAKE_CENTER + 1
		for row = 1, FLAKE_SIZE do
			for col = 1, FLAKE_SIZE do
				if pattern[row][col] == 1 then
					pix(flakeX + col - 1, flakeY + row - 1, landed.color)
				end
			end
		end
	end
end

-- =============================================================================
-- Main
-- =============================================================================

initSnowflakes()

function TIC()
	cls(COLOR_BLACK)

	local currentTime = time()

	handleWindInput()
	updateWindAndSwirl()
	updateAllSnowflakes(currentTime)
	sortSnowflakesByDepth()
	drawLandedSnowflakes()
	drawAllSnowflakes()
end

-- <TILES>
-- </TILES>

-- <WAVES>
-- </WAVES>

-- <SFX>
-- </SFX>

-- <TRACKS>
-- </TRACKS>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45ededed6
-- </PALETTE>
