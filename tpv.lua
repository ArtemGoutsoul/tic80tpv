-- title:   Total Perspective Vortex
-- author:  Artem Goutsoul
-- desc:    A Douglas Adams inspired TIC-80 demoscene demo
-- site:    https://github.com/ArtemGoutsoul/tic80tpv
-- license: MIT License
-- version: 0.2
-- script:  lua

-- Theme background: see docs/total-perspective-vortex.md for a summary of
-- Douglas Adams' Hitchhiker's Guide works and the Total Perspective Vortex.

-- Music engine (soundtrack + a timing source for keyframing visuals; see the
-- music-in-code skill). The required libs mean this cart must launch with --fs:
--   tic80.exe tpv.lua --fs C:\dev\tic80\test2 --cmd=run
package.path = package.path .. ";C:/dev/tic80/test2/?.lua"
require "tracker"
require "music01"

-- =========================================================================
-- TITLE REVEAL. Every non-transparent logo pixel is one particle that knows
-- its final home (radius + angle from the logo centre) and its colour. The
-- reveal plays in three stages:
--
--   IMPLODE   the logo starts zoomed ~4x (bigger than the screen); a ray is
--             drawn from every pixel straight to the centre, then the rays'
--             outer ends retract into a single bright dot in the middle.
--   DOT HOLD  a short beat on the bright singularity.
--   EXPLODE   the dot blooms back out. A sine-shaped zoom (_.-'``') swells it
--             past 100% to a 150% overshoot then settles, while a vortex swirl
--             untwists to zero -- every particle spirals home onto its true
--             logo pixel and the title snaps into focus.
--
-- The swirl is the *trajectory* (angle offset proportional to radius -> a
-- logarithmic spiral that untwists); the particles are the *representation*
-- (single dithered pixels). No offscreen buffer -- swirl and convergence are
-- the same formula. Colours always come from the logo bitmap.
-- =========================================================================

-- Screen
local SCREEN_W, SCREEN_H = 240, 136
local MAX_X, MAX_Y = SCREEN_W - 1, SCREEN_H - 1

-- Logo (128x128 built from 16x16 FG sprite tiles starting at sprite 256)
local LOGO_FIRST_SPRITE = 256
local LOGO_TILES = 16
local LOGO_PIXELS = LOGO_TILES * 8
local LOGO_X = (SCREEN_W - LOGO_PIXELS) // 2
local LOGO_Y = (SCREEN_H - LOGO_PIXELS) // 2
local LOGO_KEY = 0                      -- transparent palette index
local CENTER_X = LOGO_X + LOGO_PIXELS // 2
local CENTER_Y = LOGO_Y + LOGO_PIXELS // 2

-- FG sprite RAM at byte 0x6000 = nibble 0xC000; 64 nibbles per 8x8 sprite.
local FG_SPRITE_NIBBLES = 0xC000

-- Reveal timeline (seconds). Plays once; ~10s total.
local IMPLODE_DURATION = 2.0              -- rays retract into the dot (equal speed)
local DOT_HOLD = 0.3                      -- a beat on the bright singularity
local EXPLODE_DURATION = 6.0              -- dot blooms back out into the logo
local REVEAL_DURATION = IMPLODE_DURATION + DOT_HOLD + EXPLODE_DURATION

-- Implosion: picture the logo zoomed this many times (way bigger than the
-- screen); a ray is drawn from each pixel straight to the centre, and every
-- ray's outer end retracts inward at the SAME speed. Each ray starts dark and
-- brightens to its pixel's true colour as its tip reaches the centre.
--   RAY_START_SCALE  how far out (x logo size) the rays begin
--   RAY_DRAW_MAX     clamp on drawn ray length so off-screen lines stay cheap
--   RAY_DARK_NEAR    shades darker at the centre end (~50% darker)
--   RAY_DARK_FAR     shades darker at the far (dim) end
--   RAY_STRIDE       draw every Nth pixel's ray (perf)
local RAY_START_SCALE = 20.0
local RAY_DRAW_MAX = 200
local RAY_DARK_NEAR = 2
local RAY_DARK_FAR = 4
local RAY_STRIDE = 2

-- Explosion zoom, sine-shaped (_.-'``'): a smooth S-rise from the dot up to a
-- PEAK_SCALE overshoot (reached at PEAK_Q of the explosion), then a gentle sine
-- settle back to 1.0 (the true logo size).
local PEAK_Q = 0.60
local PEAK_SCALE = 1.5
local EXPLODE_POWER = 4.0                 -- explosion punch: higher = faster initial burst

-- Explosion blast: the same rays fired outward the instant the dot explodes,
-- drawn underneath the swirling logo. One shade darker than the logo (brighter
-- than the incoming rays, but never brighter than the logo). They shoot out and
-- off-screen fast while the logo swirls into shape on top.
local BLAST_DURATION = 1.0                -- window (s) during which blast rays are drawn
local BLAST_SPEED_MIN = 450               -- per-ray outward speed range (px/sec)
local BLAST_SPEED_MAX = 950
local BLAST_MAX_DELAY = 0.18              -- rays launch staggered over this window (s)
local BLAST_TAIL_MIN = 40                 -- per-ray streak length range (px)
local BLAST_TAIL_MAX = 150
local BLAST_MAX_RADIUS = 190              -- stop drawing a ray once its inner end passes this
local BLAST_DARK = 1                      -- shade steps darker than the logo
local BLAST_STRIDE = 2                    -- draw every Nth ray (perf)

-- Vortex / particle shaping (explosion stage only)
local MAX_TWIST = 8.0                      -- radians of swirl at R_REF when q = 0
local SPIN_TOTAL = 5.0                     -- whole-field rotation, unwinds to 0
local R_REF = 64                           -- reference radius (logo half-size)
local JITTER_MAX = 0.6                     -- per-particle angular chaos at start
local PARTICLE_STRIDE = 1                  -- keep every Nth opaque pixel (perf)

-- Resolved idle: a darker copy of the logo keeps rotating and slowly zooming in
-- underneath the fixed crisp logo, so the title stays alive.
local ECHO_SPIN_SPEED = -1.0              -- rad/sec; ~matches the swirl's spin as it settles
local ECHO_ZOOM_SPEED = 0.7               -- scale gained per second (zoom in)
local ECHO_DARK_STEPS = 2                 -- shade steps darker than the logo
local ECHO_LEAD = 0.5                     -- start the echo this early so the handoff has no dead beat

-- Trails: instead of clearing, darken the whole framebuffer one shade per
-- frame so moving particles leave fading comet tails -- sells the vortex.
local TRAILS = true

-- One-shade-darker LUT (DB16-tuned: warm -> brown, cool -> dark blue, all
-- chains terminate at 0). Repeated application fades any pixel to black.
local FADE = {
	[0] = 0,  [1] = 0, [2] = 0, [3] = 1,
	[4] = 1,  [5] = 1, [6] = 4, [7] = 1,
	[8] = 2,  [9] = 4, [10] = 3, [11] = 5,
	[12] = 7, [13] = 8, [14] = 9, [15] = 10,
}

local DEBUG = true                       -- frametime / fps / particle count HUD
local LOOP = false                       -- play once (set true to auto-replay while iterating)
local RESOLVED_HOLD = 2.0                 -- debug: seconds to hold the logo before looping

-- Particle table (parallel arrays for speed), built once from the logo mask.
local particleR = {}                     -- final radius from logo center
local particleAngle = {}                 -- final angle from logo center
local particleColor = {}                 -- palette index of the logo pixel
local particleColorDark = {}             -- darkened colour for the idle echo
local particleColorBlast = {}            -- colour for the explosion blast rays
local particleBlastSpeed = {}            -- per-ray outward speed (px/sec)
local particleBlastDelay = {}            -- per-ray launch delay (s)
local particleBlastLen = {}              -- per-ray streak length (px)
local particleJitter = {}                -- per-particle [-1,1] chaos seed
local particleCount = 0
local maxParticleR = 0                    -- largest rest radius (equal-speed rays)

-- Explosion zoom curve, sine-shaped (_.-'``'): an S-rise from 0 up to
-- PEAK_SCALE by q = PEAK_Q, then a sine settle from PEAK_SCALE back to 1.0 by
-- q = 1. Velocity is zero at the peak, giving the little plateau at the top.
local function sineZoom(q)
	local pi, cos = math.pi, math.cos
	if q <= PEAK_Q then
		-- Ease-out burst: high initial velocity, heavy deceleration into the
		-- peak (derivative 0 at u = 1, so the top still plateaus smoothly).
		local u = q / PEAK_Q
		return PEAK_SCALE * (1 - (1 - u) ^ EXPLODE_POWER)
	end
	local u = (q - PEAK_Q) / (1 - PEAK_Q)
	return 1.0 + (PEAK_SCALE - 1.0) * (0.5 + 0.5 * cos(pi * u))
end

-- Nibble address of pixel (lx, ly) inside the logo's 128x128 sprite mask.
local function logoMaskAddr(lx, ly)
	local sprite = (ly // 8) * LOGO_TILES + (lx // 8)
	return FG_SPRITE_NIBBLES + sprite * 64 + (ly % 8) * 8 + (lx % 8)
end

-- Scan the logo mask; each non-transparent pixel becomes a particle whose
-- resting place (radius, angle, color) is stored relative to the logo center.
local function buildParticles()
	local random, sqrt, atan = math.random, math.sqrt, math.atan
	local count, opaque, maxR = 0, 0, 0
	for ly = 0, LOGO_PIXELS - 1 do
		for lx = 0, LOGO_PIXELS - 1 do
			local color = peek4(logoMaskAddr(lx, ly))
			if color ~= LOGO_KEY then
				opaque = opaque + 1
				if opaque % PARTICLE_STRIDE == 0 then
					count = count + 1
					local rx = (LOGO_X + lx) - CENTER_X
					local ry = (LOGO_Y + ly) - CENTER_Y
					local rr = sqrt(rx * rx + ry * ry)
					particleR[count] = rr
					particleAngle[count] = atan(ry, rx)
					particleColor[count] = color
					local dark = color
					for _ = 1, ECHO_DARK_STEPS do
						dark = FADE[dark]
					end
					particleColorDark[count] = dark
					local blast = color
					for _ = 1, BLAST_DARK do
						blast = FADE[blast]
					end
					particleColorBlast[count] = blast
					particleBlastSpeed[count] = BLAST_SPEED_MIN + random() * (BLAST_SPEED_MAX - BLAST_SPEED_MIN)
					particleBlastDelay[count] = random() * BLAST_MAX_DELAY
					particleBlastLen[count] = BLAST_TAIL_MIN + random() * (BLAST_TAIL_MAX - BLAST_TAIL_MIN)
					particleJitter[count] = random() * 2 - 1
					if rr > maxR then maxR = rr end
				end
			end
		end
	end
	particleCount = count
	maxParticleR = maxR
end

-- Darken every framebuffer pixel one shade (the trail feedback pass).
local function fadeScreen()
	local peek, poke, fade = peek4, poke4, FADE
	for addr = 0, SCREEN_W * SCREEN_H - 1 do
		poke(addr, fade[peek(addr)])
	end
end

-- The bright, pulsing seed the whole reveal blooms from.
local function drawSeed(elapsed)
	local pulse = 0.5 + 0.5 * math.sin(elapsed * 10)
	local arm = (pulse > 0.66) and 15 or ((pulse > 0.33) and 13 or 12)
	local base = CENTER_Y * SCREEN_W + CENTER_X
	poke4(base, 15)
	poke4(base - 1, arm)
	poke4(base + 1, arm)
	poke4(base - SCREEN_W, arm)
	poke4(base + SCREEN_W, arm)
end

-- Draw the whole particle field for one frame. radiusScale scales every
-- particle's rest radius; swirl adds an angle proportional to radius (the
-- vortex); spin rotates the whole field; jitterAmount adds per-particle
-- angular chaos. Colours always come from the logo bitmap.
local function drawField(radiusScale, swirl, spin, jitterAmount, colors)
	local sin, cos, floor, random = math.sin, math.cos, math.floor, math.random
	local invRef = 1 / R_REF
	local pr, pa, pj = particleR, particleAngle, particleJitter
	local pc = colors or particleColor

	for i = 1, particleCount do
		local r = pr[i]
		local angle = pa[i] + spin + swirl * (r * invRef) + pj[i] * jitterAmount
		local radius = r * radiusScale
		local x = CENTER_X + radius * cos(angle)
		local y = CENTER_Y + radius * sin(angle)

		-- Sub-pixel dither: slide the centroid smoothly across the int grid.
		local fx, fy = floor(x), floor(y)
		local sx = (random() < x - fx) and (fx + 1) or fx
		local sy = (random() < y - fy) and (fy + 1) or fy

		if sx >= 0 and sx <= MAX_X and sy >= 0 and sy <= MAX_Y then
			poke4(sy * SCREEN_W + sx, pc[i])
		end
	end
end

-- Implosion (q in 0..1): the logo starts zoomed RAY_START_SCALE times; a ray is
-- drawn from every pixel straight to the centre, so the screen fills with
-- colour rays converging on one dot. Every ray's tip retracts inward at the
-- SAME speed (the longest just reaches the centre at q = 1); a ray starts dark
-- and brightens to its pixel's true colour as its tip nears the centre.
local function drawImplode(q)
	local cos, sin, floor = math.cos, math.sin, math.floor
	local cx, cy = CENTER_X, CENTER_Y
	local pr, pa, pc, pj = particleR, particleAngle, particleColor, particleJitter
	local fade = FADE
	local s0 = RAY_START_SCALE
	local maxTip = maxParticleR * s0
	local retract = maxTip * q                   -- equal-speed inward travel
	local invMaxTip = 1 / maxTip
	local drawMax = RAY_DRAW_MAX
	local near, far = RAY_DARK_NEAR, RAY_DARK_FAR

	for i = 1, particleCount, RAY_STRIDE do
		local tip = pr[i] * s0 - retract
		if tip < 0 then tip = 0 end
		-- Darkest at the far tip, ~50% darker (RAY_DARK_NEAR) at the centre end.
		-- The per-ray dither term spreads the shade steps so it reads as smooth.
		local steps = floor(near + tip * invMaxTip * (far - near) + (pj[i] * 0.5 + 0.5))
		local color = pc[i]
		for _ = 1, steps do
			color = fade[color]
		end
		local drawR = (tip > drawMax) and drawMax or tip
		local ang = pa[i]
		line(cx + drawR * cos(ang), cy + drawR * sin(ang), cx, cy, color)
	end
end

-- Explosion (q in 0..1): the dot blooms back out. Sine zoom for size; swirl,
-- spin and jitter all unwind to zero as q -> 1, so the vortex untwists exactly
-- as the logo reaches full size.
local function drawExplode(q)
	drawField(sineZoom(q), MAX_TWIST * (1 - q), SPIN_TOTAL * (1 - q), JITTER_MAX * (1 - q))
end

-- Explosion blast (et = seconds into the explosion): the same rays fired
-- outward the instant the dot explodes. Each ray has its own launch delay,
-- speed and length (randomised at build time), so the burst looks ragged rather
-- than a uniform ring. A ray is a streak inner..outer travelling out; once its
-- inner end passes the screen it is skipped. Drawn underneath the swirling logo,
-- a shade brighter than the incoming rays but never brighter than the logo.
local function drawBlast(et)
	local cos, sin = math.cos, math.sin
	local cx, cy = CENTER_X, CENTER_Y
	local pa, pcb = particleAngle, particleColorBlast
	local bs, bd, bl = particleBlastSpeed, particleBlastDelay, particleBlastLen
	local maxRadius = BLAST_MAX_RADIUS
	for i = 1, particleCount, BLAST_STRIDE do
		local age = et - bd[i]
		if age > 0 then
			local outer = bs[i] * age
			local inner = outer - bl[i]
			if inner < 0 then inner = 0 end
			if inner < maxRadius then
				local ang = pa[i]
				local ca, sa = cos(ang), sin(ang)
				line(cx + inner * ca, cy + inner * sa, cx + outer * ca, cy + outer * sa, pcb[i])
			end
		end
	end
end

-- Resolved idle echo: the same particle logo, darker, rotated and scaled up,
-- drawn underneath the crisp logo so the title keeps moving.
local function drawEcho(angleOffset, radiusScale)
	drawField(radiusScale, 0, angleOffset, 0, particleColorDark)
end

-- Crisp logo blit for the resolved state.
local function drawLogoOnTop()
	spr(LOGO_FIRST_SPRITE, LOGO_X, LOGO_Y, LOGO_KEY, 1, 0, 0, LOGO_TILES, LOGO_TILES)
end

local debugLastMs = 0
local function drawDebug(elapsed)
	local now = time()
	local dt = now - debugLastMs
	debugLastMs = now
	local fps = (dt > 0) and (1000 / dt) or 0
	print(string.format("%.1fms  %.0ffps", dt, fps), 2, 2, 12, false, 1, true)
	print(string.format("particles:%d  t:%.1f", particleCount, elapsed), 2, 9, 12, false, 1, true)
end

-- time() base so the reveal can be replayed (press A / Z) while iterating.
local timeBaseMs = 0

cls(0)
function TIC()
	Tracker.update()          -- advance + play the soundtrack

	if particleCount == 0 then
		buildParticles()
	end
	if btnp(4) then
		timeBaseMs = time()   -- replay the reveal (gamepad A / Z)
	end

	local t = (time() - timeBaseMs) / 1000

	if t < REVEAL_DURATION then
		if t < IMPLODE_DURATION then
			cls(0)                                                  -- crisp rays
			drawImplode(t / IMPLODE_DURATION)
		elseif t < IMPLODE_DURATION + DOT_HOLD then
			cls(0)
			drawSeed(t)                                             -- the singularity
		else
			if TRAILS then fadeScreen() else cls(0) end             -- swirl trails
			local et = t - IMPLODE_DURATION - DOT_HOLD              -- seconds into the explosion
			if et < BLAST_DURATION then
				drawBlast(et)                                      -- blast rays underneath
			end
			drawExplode(et / EXPLODE_DURATION)                     -- swirling logo on top
		end
	else
		-- Resolved: a darker copy of the logo keeps rotating and zooming in
		-- underneath, with the crisp logo fixed on top. Spin gets a lead-in so
		-- the echo is already turned out of hiding at the handoff (no dead beat);
		-- zoom starts at 1.0 so the shadow doesn't pop in already enlarged.
		cls(0)
		local sinceResolve = t - REVEAL_DURATION
		drawEcho(ECHO_SPIN_SPEED * (sinceResolve + ECHO_LEAD), 1 + ECHO_ZOOM_SPEED * sinceResolve)
		drawLogoOnTop()
		if LOOP and sinceResolve > RESOLVED_HOLD then
			timeBaseMs = time()
		end
	end

	if DEBUG then
		drawDebug(t)
	end
end

-- <TILES>
-- 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
-- 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
-- 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
-- 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
-- 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- </TILES>

-- <SPRITES>
-- 048:000000020002ffff0000dfff00007fff00002fff00002ddd0000270000000000
-- 049:277d7dd7fffffffffffffffffffffffffdddfffd7007fffd0002ffff0000dfff
-- 050:dfd7dff7ffffff72fffffd2ddf72700dd200000f2000000f2000000f7000000f
-- 051:07dd7ddfdffffddffffffffdffffd77ffff00000ffd00000ffd00000ffd00000
-- 052:d7ddddfdffd7dffffff70dffffff07d7dfff70000fffd0000dffd2002dffd700
-- 053:fdfffffffffffffffffffdfd7dff77f707ff7d7000ff7f2000dfdf2000df2d20
-- 054:ffff727ffffddfffdd770dff00000dff00000fff00000fff00002fff00007fff
-- 055:fd7007dfffdf2007fffff200f7dffd20d007ff70d007dfd2d000dff7d0077ffd
-- 056:ddd20000ffff70007ffff2000fffdf7007ff7dd002ffd0d700fff27d00dffd0d
-- 057:0000000000000000000000000000000000000000000000000000000070000022
-- 058:000000000000000000000000000000000000000000000000000000000d227720
-- 065:0000dfff00002fff00000dff000007ff000002ff000000df0000002f00000002
-- 066:d000000dd000000df2000007fd000000fd000000ffd20000fffd77ddfffffffd
-- 067:ffd00000fff20000ffff720ddfffffff2dffffff00dfffff770777fffd202000
-- 068:2fff27002fff0d00dff70d00ffd2d200fdddd200ffdd2000d700000000000000
-- 069:00df777000dfff7000ddfd70007fffd7000dffff00027dff0000000000000000
-- 070:00007fff0000dfff0000dfff0002fffdd27fffd0ffdf70000000000000000000
-- 071:dddfffff7dddddff000002ff0000002f00000007000000000000000000000000
-- 072:007fffdfd02fffffd00dffffdd00dfdd7d700220000000000000000000000000
-- 073:ddfd7277ffffffd2fffffffdfdf7220020000000000000000000000000000000
-- 074:7dff720222277d72272000000000000000000000000000000000000000000000
-- 075:7720000020000000000000000000000000000000000000000000000000000000
-- 082:27fffd72000220000000000000000000000000000000000d0000000700000000
-- 083:0000000000000000000000000000000000000000dddddd00dfffffd0df007ffd
-- 091:00000000000000000000000000000000000000000007dd000000df000000df00
-- 092:0000000000000000000000000000000000007dd000000ff00000000000000000
-- 099:df0007dfdf0007dfdf007dfddfdddfd0dffffd00df000000df0000007f000000
-- 100:00007dd7000ddfff007df00d00df700700dffddd00dfffff00dfd700000dfddd
-- 101:000ddd07d007dfdffd00dffddf00dfd0df00df00ff00df000000df00d2007f00
-- 102:ddd700ddffff0dff0000df700000dfd200000dff000000000000ddd200000dfd
-- 103:dd000dddffd007dd07fd00df000000dfffd000df2dfd00df00df00dfddf200df
-- 104:0ddd0000dfffd000d22dfd002002df000000df002002df00f72dfd00dfdff000
-- 105:007ddd000ddfffd07df27ff7df7002dddffddddfdfffffffdfd700000dfdddd0
-- 106:0000ddd7000ddfff00ddf00d00df000000df000000df000000dfd00d000dfddf
-- 107:007ddfddd00dfffffd00df000000df000000df000000df00dd00df00d000dfff
-- 108:d00dddd0f00dfff000000df000000df000000df000000df000000df0f00dddfd
-- 109:07dd000007ff000002df000000df0000007f0002007f7007000ff72dd007fddf
-- 110:dd00007ddf000ddfdf007df7df00df70dd00dffdfd00dffff000dfd720000dfd
-- 111:dd000000ffd000002ffd000000df0000dddf0000ffff000000000000ddd00000
-- 112:0000000000000000000000000000000000000000000000000000000000000020
-- 113:00000000000000000000000000000002000000070000000d0000000d0000000d
-- 114:00000000000000000000000000000000000000002000000072000000d7200000
-- 115:7f00000000000000000000000000000000000000000000000000000000000000
-- 116:0000dffd00000000000000000000000000000000000000000000000000000000
-- 117:20007f0000000000000000000000000000000000000000000000000000000000
-- 118:000000df00000000000000000000000000000000000000000000000000000000
-- 119:fd2000df000000df000000df0000007f0000007f000000000000000000000000
-- 120:0dfd00000000000000000000000000000000000000000000000000000000000d
-- 121:00dffd000000000000000000000000000000000002000000dd000000fffdd000
-- 122:0000dffd00000000000000000000000000000000000000000000000000000000
-- 123:00000dff0000000000000000000000000000000000000000000000007d0000fd
-- 124:d00dffff00000000000000000000000000000000000000000000000070000000
-- 125:f0002ff200000000000000000000000000000000000000000000000000000000
-- 126:0000007f00000000000000000000000000000000000000000000000000000000
-- 127:fd00000000000000000000000000000000000000000000000000000002200000
-- 128:0000007000000270000007d000002fd00007dfd2002ffdd702ffdfd72ffffdf7
-- 129:0000000700000002000000020000000000000000000000000000000000000000
-- 130:fd720000f7d72000fdffd720fddffdfdffdfdfdffdfddddddfddfdd2dffddfd0
-- 131:000000000000000000000000d2000000d000007d00000dff0000ffff000dffff
-- 132:00000000000000000000000000000000dfffffd7fffffdfdffffffff72d7ffff
-- 133:0000000000000000000000000000000020000000f700007fdfd0007fffdd002d
-- 134:0000000000000000000007dd007fffffdffffffffffffdfdfddfddddfffdf772
-- 135:0000000000000000fffdd700ffffdfd7fffffdfdfdddfffd7227dffd00007dff
-- 136:000027dd277dfff7007dfdfd000277ff70000022d7000000d7000000fd000000
-- 137:fddfffffdddddffff7d7277ddfdfdf777dfdfdff00000ddf000007ff000007df
-- 138:fd77727dfffffffdfffffd7d227707fdfddfdfdffffdd720ffd00000ffd00000
-- 139:df0002ffdd0007fff70007ffd0000dff00000dff00000dff00000fff00000fff
-- 140:fffd7000ffffffffdffffffffddfffdfdd72ddfdfd722200dd000000fd720000
-- 141:00202000dfffd002fffd000ddfd700dffdf002ff7d200dff000007df00000000
-- 142:0000000000000000d7000000ffd00000fddd0000fffdd000ffffd700dffffd7d
-- 143:00df000000dffd0002ffffd007fffdf70fffffd77ffffdd0ffffdf00fffffd00
-- 144:2dffffd700fffdfd00dffffd002fffdf000ffffd0007ffff0000ffff0000dfff
-- 145:0000000000000000000000000000000070000000d0000007d0000007f200000d
-- 146:dffddf70dfffdd20fffddf20ffffd700fffdd200fffd7000ffdf2000ffdf2000
-- 147:000ffff7007fffd700dfff7d00ffff7f00ffffdd00dfffdf007ffffd000fffff
-- 148:7fdfdfffd70007df7000000d00000000000000000000000000000000d0000000
-- 149:ffdf7007fffdd000ffffd700dfffdd000ffdfd000ffffd000fffdf00dfffdd00
-- 150:dfffd700dffdfd007fffdd070dffffff0dffffff00ffffff00dffdfd007ffdd7
-- 151:0000dffd027dffffddfffdfdffffffddfdfddd70ffdffdd7ffffdd777dfffffd
-- 152:dd000000d7000000d00000000000000000000000000000000000000077000000
-- 153:000002ff000000df000000ff000000ff000000ff000002ff000002ff000007ff
-- 154:ff700000fdd00000ffd00000fdf00000ffd00000fdf00000ffd00000d7d00000
-- 155:00000fff00000fff00007fff0000dfff0000fffd0000ffff0007fffd000dffdf
-- 156:fdd7dd72ffffdfdfdffffdfddddfdfdff0007dd7d0000027d000000070000000
-- 157:70000000f0000000700000000000000000000000000000000000000000000000
-- 158:0dffffdf00dfffff000dffff0000ffff0000ffff000dffff002fffff00dfffdf
-- 159:fffdd000ffdf2000fff70000dfd20000fdd00000dfdd0000fffd7000dffdd000
-- 160:0000dfff00000fff00000dff000007ff000000df000000df0000000f0000000d
-- 161:dd00000dff00000dfd70000ffdd0000ffff0007fffd2007ffffd00dfffdf007f
-- 162:fffd0000ffd70000fff20000ffd20000fdf20000ffd20000fd700000fd700000
-- 163:000dffff0000ffff00007fff000007ff0000000d000000000000000000000000
-- 164:ffd700dfffffffffffffffffffffffffdfdddfdd27fdfdff0072777700000000
-- 165:fffddf00fffffd00fddfd200dfdfd000fdfd0000f7d000007700000000000000
-- 166:007ffffd000fffdd002ffffd007fffff00dffffd00dfffff00ddffff07fdffff
-- 167:002dfffd00007dffd00002dfd000002df7000002fd200000df200000ddd00000
-- 168:fd720000dfdd7700fddfdf72fffdfdfd7fffffdd0dfffffd027fdfdf0027fdf7
-- 169:00000dff00000fff00002fff70007fffd7772fd2ffd20000d000000000000000
-- 170:fdd00000dfd00000dd700000fdd0000007d20000000000000000000000000000
-- 171:000ffffd00dfffdf00ffffdf07fffffd0dfffff707ddffff00007ddf00000002
-- 172:7000000070000000d7772002ffddd7d77dffffdffd72ddfdffffd727dffffffd
-- 173:000000000000000000000000ddd70000dff200077d70000ddd00007ff70000df
-- 174:02fffffd0dfffdd02fffffd0dfffdd00fffff700fffdd000ffff2000ffdd0000
-- 175:fffff7000dffdd2000dfff70000ffdd20002ffd20000dffd00000fd0000007f7
-- 176:0000000200000000000000000000000000000000000000000000000000000000
-- 177:ffffd7ffdffffdff7fffdfff0ffffffd02fffffd00dfffdd007ffdfd000fdfdf
-- 178:dd700000fd000000dd000000fd000000dd000000f2000000d0000000d0000000
-- 182:00007ffd00000027000000000000000000000000000000000000000000000000
-- 183:ffd20000ddd200007fd2000002770000007d0000000200000000000000000000
-- 184:0000d70000007000000000000000000000000000000000000000000000000000
-- 188:007fdfdd0002ddff00002fd7000002d700000022000000000000000000000000
-- 189:d00007ff70000dff2000dfff0000dfff0007ffff000fffff007ffffd02ffffdd
-- 190:fff20000fdd00000ff700000fd000000d7000000f2000000d200000070000000
-- 191:000002f700000020000000000000000000000000000000000000000000000000
-- 193:0007fffd0000dfdf0000dfdf00007ffd00000fd7000007d200000d7000000d70
-- 194:7000000070000000200000000000000000000000000000000000000000000000
-- 205:00fffffd007ffddd000ddffd0007fdf70002dfd20000df7000007d7000002d20
-- 206:2000000000000000000000000000000000000000000000000000000000000000
-- 209:0000070000000200000000000000000000000000000000000000000000000000
-- 221:0000072000000700000007000000000000000000000000000000000000000000
-- </SPRITES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <TRACKS>
-- 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45ededed6
-- </PALETTE>
