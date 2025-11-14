-- title:   game title
-- author:  game developer, email, etc.
-- desc:    short description
-- site:    website link
-- license: MIT License (change this to your license of choice)
-- version: 0.1
-- script:  lua

-- Constants
local PYRAMID_SIZE = 25
local GRID_SPACING = 28
local PALETTE_RAM_BASE = 0x3FC0

-- Draw a pyramid with four colored triangular faces
function DrawPyramid(x, y, width, height, centerX, centerY, timeValue)
	local baseColor = timeValue / 400 % 4 + 1
	local apexX = width / 2 + centerX
	local apexY = height / 2 + centerY

	-- Front face
	tri(x, y, apexX, apexY, x + width, y, baseColor + 1)
	-- Right face
	tri(x + width, y, apexX, apexY, x + width, y + height, baseColor + 2)
	-- Left face
	tri(x, y, apexX, apexY, x, y + height, baseColor + 3)
	-- Back face
	tri(x, y + height, apexX, apexY, x + width, y + height, baseColor + 4)
end

-- Store original palette colors
local originalPalette = {}
for i = 0, 15 do
	local address = PALETTE_RAM_BASE + i * 3
	originalPalette[i] = {peek(address), peek(address + 1), peek(address + 2)}
end

-- BDR callback - called for each scanline
-- Creates an animated rainbow wave effect
function BDR(scanline)
	local currentTime = time()
	-- Create a wave offset based on scanline and time
	local wave = scanline / 15 + currentTime / 400

	-- Apply color shift to palette colors (skip color 0 to keep lines black)
	for i = 1, 15 do
		local address = PALETTE_RAM_BASE + i * 3
		local red, green, blue = originalPalette[i][1], originalPalette[i][2], originalPalette[i][3]

		-- Use oscillating values that stay positive (0.5 to 1.5 range)
		local redShift = 0.5 + math.cos(wave) * 0.5
		local greenShift = 0.5 + math.sin(wave + currentTime / 250) * 0.5
		local blueShift = 0.5 + math.cos(wave + currentTime / 300 + 2) * 0.5

		-- Blend colors to create rainbow effect while staying bright
		poke(address, math.min(255, red * redShift + 60 * math.abs(math.sin(wave))))
		poke(address + 1, math.min(255, green * greenShift + 60 * math.abs(math.sin(wave + 2))))
		poke(address + 2, math.min(255, blue * blueShift + 60 * math.abs(math.sin(wave + 4))))
	end
end

cls()
function TIC()
	for x = 0, 240, GRID_SPACING do
		local previousX = x
		local previousY = 0.0

		for y = 0, 136, GRID_SPACING do
			-- Calculate animated offset for pyramid apex
			local offsetX = 12 * math.sin(time() / 10000 * (x + y + 1))
			local offsetY = 12 * math.cos(time() / 10000 * (x + y + 1))

			-- Draw pyramid
			DrawPyramid(x, y, PYRAMID_SIZE, PYRAMID_SIZE, x + offsetX, y + offsetY, 1)

			-- Calculate center point of pyramid
			local centerX = x + PYRAMID_SIZE / 2 + offsetX
			local centerY = y + PYRAMID_SIZE / 2 + offsetY

			-- Draw connecting line between pyramids
			line(previousX, previousY, centerX, centerY, 0)

			previousX = centerX
			previousY = centerY
		end
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
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45edeeed6
-- </PALETTE>
