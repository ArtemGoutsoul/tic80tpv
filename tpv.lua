-- title:   game title
-- author:  game developer, email, etc.
-- desc:    short description
-- site:    website link
-- license: MIT License (change this to your license of choice)
-- version: 0.1
-- script:  lua

-- Constants
local GRID_SPACING = 28
local PYRAMID_SIZE = GRID_SPACING  -- pyramids tile flush, no black gaps

-- Wave parameters for grid-corner displacement (also reused by the logo
-- shadow's height field, hence declared up here before any function uses it)
local WAVE_AMP = 7           -- pixels of corner displacement (peak)
local WAVE_SPEED = 0.0042    -- radians per ms (faster motion)

-- Logo sprite constants
local LOGO_SPR = 256       -- starting sprite index (top-left corner of bank 0)
local LOGO_W = 16        -- 128 pixels / 8 = 16 sprites wide
local LOGO_H = 16        -- 128 pixels / 8 = 16 sprites tall
local KEY = 0            -- transparent color in the logo

-- Draw a triangle whose interior is a dithered gradient through a list of
-- palette indices. Scanline rasterizer: vertices are sorted by Y, then for
-- each scanline the left/right x and brightness are linearly interpolated
-- along the triangle edges. Brightness then advances by a constant step
-- across each scanline (one add per pixel) and is mapped to a color-list
-- position; a fresh random threshold per pixel picks between the two
-- adjacent stops, giving white-noise dither that animates every frame.
function DitheredTri(x1, y1, x2, y2, x3, y3, colorList, b1, b2, b3)
	local segments = #colorList - 1
	if segments < 1 then return end

	-- Sort vertices by Y ascending: v1 top, v2 middle, v3 bottom
	if y1 > y2 then x1, y1, b1, x2, y2, b2 = x2, y2, b2, x1, y1, b1 end
	if y2 > y3 then x2, y2, b2, x3, y3, b3 = x3, y3, b3, x2, y2, b2 end
	if y1 > y2 then x1, y1, b1, x2, y2, b2 = x2, y2, b2, x1, y1, b1 end

	local floor = math.floor
	local yTop = floor(y1)
	local yBot = floor(y3)
	if yTop < 0 then yTop = 0 end
	if yBot > 135 then yBot = 135 end

	-- Per-Y slopes for x and brightness on each of the three edges
	local dy13 = y3 - y1
	local dy12 = y2 - y1
	local dy23 = y3 - y2
	local mx13 = (dy13 ~= 0) and (x3 - x1) / dy13 or 0
	local mb13 = (dy13 ~= 0) and (b3 - b1) / dy13 or 0
	local mx12 = (dy12 ~= 0) and (x2 - x1) / dy12 or 0
	local mb12 = (dy12 ~= 0) and (b2 - b1) / dy12 or 0
	local mx23 = (dy23 ~= 0) and (x3 - x2) / dy23 or 0
	local mb23 = (dy23 ~= 0) and (b3 - b2) / dy23 or 0

	for y = yTop, yBot do
		local dy = y - y1
		-- Long edge v1->v3 (covers full height)
		local xa = x1 + mx13 * dy
		local ba = b1 + mb13 * dy
		-- Short edge: v1->v2 above the middle vertex, v2->v3 below
		local xb, bb
		if y < y2 then
			xb = x1 + mx12 * dy
			bb = b1 + mb12 * dy
		else
			local dy2 = y - y2
			xb = x2 + mx23 * dy2
			bb = b2 + mb23 * dy2
		end

		-- Order endpoints so xL <= xR (carry brightness with them)
		local xL, xR, bL, bR
		if xa <= xb then
			xL, xR, bL, bR = xa, xb, ba, bb
		else
			xL, xR, bL, bR = xb, xa, bb, ba
		end

		local pxL = floor(xL)
		local pxR = floor(xR)
		local span = pxR - pxL
		local brightStep = (span > 0) and (bR - bL) / span or 0
		local brightness = bL

		-- Clip to screen X; advance brightness past the clipped pixels
		if pxL < 0 then
			brightness = brightness - brightStep * pxL
			pxL = 0
		end
		if pxR > 239 then pxR = 239 end

		if pxL <= pxR then
			local random = math.random
			local rowBase = y * 240

			for x = pxL, pxR do
				local b = brightness
				if b < 0 then b = 0
				elseif b > 1 then b = 1 end

				local position = b * segments
				local segIdx = floor(position)
				if segIdx >= segments then segIdx = segments - 1 end
				local intensity = floor((position - segIdx) * 16 + 0.5)

				if intensity > random(0, 15) then
					poke4(rowBase + x, colorList[segIdx + 2])
				else
					poke4(rowBase + x, colorList[segIdx + 1])
				end

				brightness = brightness + brightStep
			end
		end
	end
end

-- Color ramps for the four pyramid faces. Each ramp goes from the face's
-- base color (dark, at the base corners) to white (at the apex), traversing
-- intermediate palette entries so the dither produces a smooth shaded look.
local PYRAMID_FACE_RAMPS = {
	{2,  8, 13, 15},  -- front: dark blue -> light blue -> cyan -> white
	{3, 10, 15},      -- right: dark gray -> light gray -> white
	{4,  9, 14, 15},  -- left:  brown -> orange -> yellow -> white
	{5, 11, 14, 15},  -- back:  green -> light green -> yellow -> white
}

-- Draw the logo centered on screen
function DrawLogoOnTop()
	local pixelWidth = LOGO_W * 8
	local pixelHeight = LOGO_H * 8

	-- Center on 240x136 screen
	local x = (240 - 128) // 2
	local y = (136 - 128) // 2

	spr(256, x, y, 0, 1, 0, 0, 16, 16)
end

-- Per-palette-index "one shade darker" lookup, used by the logo drop shadow.
-- Hand-tuned for the DB16 palette: warm colors fall toward brown, cool colors
-- fall toward blue/dark, and already-dark indices saturate at 0.
local SHADOW_DARKEN = {
	[0]  = 0,  [1]  = 0, [2]  = 0, [3]  = 1,
	[4]  = 1,  [5]  = 1, [6]  = 4, [7]  = 1,
	[8]  = 2,  [9]  = 4, [10] = 3, [11] = 5,
	[12] = 7,  [13] = 8, [14] = 9, [15] = 10,
}

local SHADOW_OFFSET_X = 4
local SHADOW_OFFSET_Y = 4

-- Draw a dithered drop shadow under the logo with fake 3D depth.
--
-- For each non-transparent logo pixel we sample a sine-wave "surface height"
-- at the would-be shadow location and scale the shadow offset by (1 - h*k).
-- A high surface point sits closer to the logo, so the shadow lands closer to
-- the logo (small offset); a low surface point is further from the logo, so
-- the shadow lands further away (big offset). The wavefield is keyed off the
-- same WAVE_SPEED used by the grid, so the shadow drifts in sync with the
-- bending pyramids and looks like it's projected onto a real surface.
--
-- Coverage is 100%, but each pixel randomly picks between one-step (75%) and
-- two-step (25%) darkening for an animated dither texture. The mix is lighter
-- than the previous 50/50 single/double scheme.
function DrawLogoShadow()
	local logoX = (240 - 128) // 2
	local logoY = (136 - 128) // 2
	local random = math.random
	local cos = math.cos
	local floor = math.floor
	local t = time()
	local heightT = t * WAVE_SPEED

	for ly = 0, 127 do
		local logoSy = logoY + ly
		local spriteRow = ly // 8
		local pixelRow = ly % 8
		for lx = 0, 127 do
			local spriteCol = lx // 8
			local pixelCol = lx % 8
			local spriteAddr = 0xC000 + (spriteRow * 16 + spriteCol) * 64
			if peek4(spriteAddr + pixelRow * 8 + pixelCol) ~= KEY then
				local logoSx = logoX + lx

				-- Use the SAME wave function the grid uses for vertical corner
				-- displacement (the dy formula in DrawPyramidGrid), evaluated
				-- at this pixel's grid coordinates. The shadow's depth thus
				-- oscillates in phase with the underlying surface — when the
				-- pyramid grid bulges up here, the shadow tucks closer to the
				-- logo; when it dips, the shadow stretches further away.
				local sampleX = logoSx + SHADOW_OFFSET_X
				local sampleY = logoSy + SHADOW_OFFSET_Y
				local gxF = sampleX / GRID_SPACING
				local gyF = sampleY / GRID_SPACING
				local heightAt = (
					cos(heightT * 1.1  + gxF * 0.7 + gyF * 0.4) * 0.6 +
					cos(heightT * 0.83 + gxF * 0.4 + gyF * 0.8) * 0.4
				)
				local distFactor = 1 - heightAt * 0.4

				-- Subpixel rendering via dithering: instead of snapping each
				-- pixel to its nearest integer screen coord, randomly pick
				-- floor or floor+1 with probability equal to the fractional
				-- part. As the offset continuously crosses an integer (e.g.
				-- 4.3 → 4.7), the proportion of pixels at the ceil grows
				-- 30% → 70% smoothly, so the shadow's centroid slides
				-- sub-pixel-smoothly across the screen even though every
				-- individual pixel is still placed on the integer grid.
				local shadowFx = logoSx + SHADOW_OFFSET_X * distFactor
				local shadowFy = logoSy + SHADOW_OFFSET_Y * distFactor
				local fx = floor(shadowFx)
				local fy = floor(shadowFy)
				local shadowSx = (random() < shadowFx - fx) and (fx + 1) or fx
				local shadowSy = (random() < shadowFy - fy) and (fy + 1) or fy

				if shadowSx >= 0 and shadowSx < 240 and shadowSy >= 0 and shadowSy < 136 then
					local addr = shadowSy * 240 + shadowSx
					local current = peek4(addr)
					-- 50/50 double vs triple darken for a deep, saturated
					-- shadow that still has random-dither texture
					local twice = SHADOW_DARKEN[SHADOW_DARKEN[current]]
					if random(0, 1) == 0 then
						poke4(addr, SHADOW_DARKEN[twice])
					else
						poke4(addr, twice)
					end
				end
			end
		end
	end
end

-- Draw a pyramid with four dithered-gradient triangular faces.
-- Takes the four base corners (top-left, top-right, bottom-left, bottom-right)
-- explicitly so the caller can warp them; apex is supplied directly. Each face
-- shades from its ramp's dark color at the base corners (b=0) to white at the
-- apex (b=1), giving a spotlight-on-the-tip look.
function DrawPyramid(tlX, tlY, trX, trY, blX, blY, brX, brY, apexX, apexY)
	-- Front face (top edge)
	DitheredTri(tlX, tlY, apexX, apexY, trX, trY, PYRAMID_FACE_RAMPS[1], 0, 1, 0)
	-- Right face (right edge)
	DitheredTri(trX, trY, apexX, apexY, brX, brY, PYRAMID_FACE_RAMPS[2], 0, 1, 0)
	-- Left face (left edge)
	DitheredTri(tlX, tlY, apexX, apexY, blX, blY, PYRAMID_FACE_RAMPS[3], 0, 1, 0)
	-- Back face (bottom edge)
	DitheredTri(blX, blY, apexX, apexY, brX, brY, PYRAMID_FACE_RAMPS[4], 0, 1, 0)
end

-- Draw a grid of pyramids whose shared corners ride a 2D wave that's the
-- sum of two sine/cosine harmonics at different speeds and phases, giving
-- an irregular, non-periodic-looking flow. Corner positions are precomputed
-- once per frame so adjacent cells share endpoints exactly (gap-free), and
-- snapped to integer pixels so the rasterizer doesn't produce sub-pixel
-- seam artifacts at shared edges. Outermost ring of corners is anchored.
function DrawPyramidGrid()
	local t = time()
	local waveT = t * WAVE_SPEED
	local sin, cos, min, floor = math.sin, math.cos, math.min, math.floor

	local cellCols = (240 // GRID_SPACING) + 1
	local cellRows = (136 // GRID_SPACING) + 1

	-- Precompute warped corner positions (integer-snapped)
	local cornerX = {}
	local cornerY = {}
	for gy = 0, cellRows do
		local rowX = {}
		local rowY = {}
		local y0 = gy * GRID_SPACING
		local edgeY = min(gy, cellRows - gy)
		for gx = 0, cellCols do
			local x0 = gx * GRID_SPACING
			local edgeX = min(gx, cellCols - gx)
			local edgeWeight = min(edgeX, edgeY, 1)  -- 0 at outer ring, 1 inside

			-- Two harmonics at incommensurate ratios (1.0 and 1.73) give a
			-- wave that doesn't look periodic over short timescales.
			local dx = WAVE_AMP * (
				sin(waveT        + gx * 0.45 + gy * 0.6) * 0.6 +
				sin(waveT * 1.73 + gx * 0.9  + gy * 0.3) * 0.4
			) * edgeWeight
			local dy = WAVE_AMP * (
				cos(waveT * 1.1  + gx * 0.7  + gy * 0.4) * 0.6 +
				cos(waveT * 0.83 + gx * 0.4  + gy * 0.8) * 0.4
			) * edgeWeight

			rowX[gx] = floor(x0 + dx + 0.5)
			rowY[gx] = floor(y0 + dy + 0.5)
		end
		cornerX[gy] = rowX
		cornerY[gy] = rowY
	end

	-- Draw each cell using its 4 warped corners + an oscillating apex
	for gy = 0, cellRows - 1 do
		local rowX0, rowX1 = cornerX[gy], cornerX[gy + 1]
		local rowY0, rowY1 = cornerY[gy], cornerY[gy + 1]
		for gx = 0, cellCols - 1 do
			local tlX, tlY = rowX0[gx],     rowY0[gx]
			local trX, trY = rowX0[gx + 1], rowY0[gx + 1]
			local blX, blY = rowX1[gx],     rowY1[gx]
			local brX, brY = rowX1[gx + 1], rowY1[gx + 1]

			-- Apex oscillates around the cell's (warped) center, snapped too
			local centerX = (tlX + trX + blX + brX) * 0.25
			local centerY = (tlY + trY + blY + brY) * 0.25
			local angSpeed = (gx * GRID_SPACING + gy * GRID_SPACING + 1) / 10000
			local apexX = floor(centerX + 12 * sin(t * angSpeed) + 0.5)
			local apexY = floor(centerY + 12 * cos(t * angSpeed) + 0.5)

			DrawPyramid(tlX, tlY, trX, trY, blX, blY, brX, brY, apexX, apexY)
		end
	end
end

cls()
function TIC()
	-- Draw pyramid grid effect
	DrawPyramidGrid()

	-- Dithered drop shadow goes underneath the logo (drawn after the grid so
	-- it darkens the grid pixels, but before the logo so the logo covers it
	-- where they overlap).
	DrawLogoShadow()

	-- Draw logo on top (last = rendered on top)
	DrawLogoOnTop()
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

