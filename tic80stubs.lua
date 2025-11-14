---@meta

---@diagnostic disable: missing-return
-- TIC-80 Lua stubs (EmmyLua style)
-- Put in /stubs/tic80_api.lua and mark as Library in PhpStorm

---@diagnostic disable: unused-local, lowercase-global

---Milliseconds since the cartridge started (wraps around).
---@return number # milliseconds since start
function time() end

---Draw a line.
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param color number|nil @0..15 (palette index). Default: current pen.
function line(x0, y0, x1, y1, color) end

---Draw a filled triangle.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param x3 number
---@param y3 number
---@param color number|nil @0..15 (palette index). Default: current pen.
function tri(x1, y1, x2, y2, x3, y3, color) end

---Clear screen to a color.
---@param color number|nil @0..15 (palette index). Default: 0 (black).
function cls(color) end

---Write a value to a RAM address.
---@param addr number @0x00000..0x17FFF (RAM address)
---@param value number @Value to write (0..255 for 8 bits, 0..15 for 4 bits, etc.)
---@param bits number|nil @Number of bits to write (1, 2, 4, or 8). Default: 8.
function poke(addr, value, bits) end

---Read a value from a RAM address.
---@param addr number @0x00000..0x17FFF (RAM address)
---@param bits number|nil @Number of bits to read (1, 2, 4, or 8). Default: 8.
---@return number @Value read from RAM
function peek(addr, bits) end
