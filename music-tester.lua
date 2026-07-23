-- title:  Music Tester
-- author: Enkora / TPV
-- desc:   Debug player for the TPV soundtrack (mute + skip parts)
-- script: lua

-- Standalone player for auditioning the song while composing. It only adds a
-- debug UI on top of the engine: the music lives in tracker.lua + music01.lua.
-- Point `require` at the song iteration you want to hear (music01, music02, ...).
-- Run from the project folder so `require` can find the libs:
--   tic80.exe music-tester.lua --fs C:\dev\tic80\test2 --cmd=run

package.path = package.path .. ";C:/dev/tic80/test2/?.lua"
require "tracker"
require "music02"

-- ---------------------------------------------------------------------------
-- Debug UI
-- ---------------------------------------------------------------------------
local CHANNELS = Tracker.channelCount()
local LANE_LABELS = { "BASS", "LEAD", "ARP ", "DRUM" }
local ROW_TOP, ROW_HEIGHT = 46, 13
local ROW_LEFT, ROW_RIGHT = 4, 158
local PROGRESS_Y, PROGRESS_STEP, PROGRESS_W = 110, 14, 12

local mouseX, mouseY = 0, 0
local prevClick = false

local function laneAtPoint(mx, my)
	for c = 0, CHANNELS - 1 do
		local y = ROW_TOP + c * ROW_HEIGHT
		if mx >= ROW_LEFT and mx < ROW_RIGHT
				and my >= y - 2 and my < y + ROW_HEIGHT - 2 then
			return c
		end
	end
	return nil
end

local function progressAtPoint(mx, my)
	if my < PROGRESS_Y or my >= PROGRESS_Y + 8 then return nil end
	for i = 1, Tracker.partCount() do
		local x = 6 + (i - 1) * PROGRESS_STEP
		if mx >= x and mx < x + PROGRESS_W then return i end
	end
	return nil
end

local function handleInput()
	local mx, my, left = mouse()
	mouseX, mouseY = mx, my
	if left and not prevClick then
		local c = laneAtPoint(mx, my)
		if c then
			Tracker.toggleMute(c)
		else
			local part = progressAtPoint(mx, my)
			if part then Tracker.jumpToPart(part) end
		end
	end
	prevClick = left
	if btnp(2) then Tracker.jumpToPart(Tracker.currentPartIndex() - 1) end   -- Left
	if btnp(3) then Tracker.jumpToPart(Tracker.currentPartIndex() + 1) end   -- Right
end

local function drawReadout()
	cls(0)
	local partIndex = Tracker.currentPartIndex()
	local part = Tracker.partAt(partIndex)
	local transpose = Tracker.transpose()
	local barsInPart = Tracker.partBars(partIndex)
	local barInPart = (Tracker.row() - part.row) // Tracker.stepsPerBar() + 1

	print("TOTAL PERSPECTIVE VORTEX", 6, 6, 11)
	print(part.name, 6, 20, 12)
	if transpose ~= 0 then print("key +" .. transpose, 198, 20, 14) end
	print("part " .. partIndex .. "/" .. Tracker.partCount()
		.. "   bar " .. barInPart .. "/" .. barsInPart
		.. "   " .. Tracker.bpm() .. " BPM", 6, 32, 13, false, 1, true)

	local hovered = laneAtPoint(mouseX, mouseY)
	for c = 0, CHANNELS - 1 do
		local y = ROW_TOP + c * ROW_HEIGHT
		if c == hovered then
			rect(ROW_LEFT - 2, y - 2, ROW_RIGHT - ROW_LEFT, ROW_HEIGHT - 1, 1)
		end
		if Tracker.isMuted(c) then
			print(LANE_LABELS[c + 1], 6, y, 8)
			print("muted", 44, y, 8, false, 1, true)
		else
			print(LANE_LABELS[c + 1], 6, y, 6)
			local volume = Tracker.channelLevel(c)
			rect(44, y, volume * 10, 7, volume > 0 and (8 + c) or 15)
		end
	end

	local hoveredPart = progressAtPoint(mouseX, mouseY)
	for i = 1, Tracker.partCount() do
		local x = 6 + (i - 1) * PROGRESS_STEP
		rectb(x, PROGRESS_Y, PROGRESS_W, 8, i == hoveredPart and 12 or 15)
		if i == partIndex then
			rect(x + 1, PROGRESS_Y + 1, PROGRESS_W - 2, 6, 11)
		elseif i < partIndex then
			rect(x + 1, PROGRESS_Y + 1, PROGRESS_W - 2, 6, 5)
		end
	end
	print("lane = mute    block / <> keys = skip part", 6, 124, 13, false, 1, true)

	line(mouseX - 3, mouseY, mouseX + 3, mouseY, 12)
	line(mouseX, mouseY - 3, mouseX, mouseY + 3, 12)
end

function TIC()
	handleInput()
	Tracker.update()
	drawReadout()
end

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>
