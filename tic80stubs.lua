---@meta

---@diagnostic disable: missing-return
-- TIC-80 Lua stubs (EmmyLua style)
-- Complete API reference for TIC-80 fantasy computer

---@diagnostic disable: unused-local, lowercase-global

-- ============================================================================
-- CALLBACKS
-- ============================================================================

---Main loop callback, called 60 times per second (required).
function TIC() end

---Boot callback, called once when cartridge starts.
function BOOT() end

---Border callback, called before each scanline (0-143).
---@param scanline number @Scanline number (0-143)
function BDR(scanline) end

---Overlay callback for drawing overlay layer (deprecated, use vbank).
function OVR() end

---Menu callback for handling custom menu items.
---@param index number @Menu item index
function MENU(index) end

---Scanline callback (deprecated, use BDR instead).
---@param scanline number @Scanline number
function SCN(scanline) end

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

---Clear screen to a color.
---@param color number|nil @0..15 (palette index). Default: 0 (black).
function cls(color) end

---Set or reset clipping region.
---@param x number|nil @X position of clip region
---@param y number|nil @Y position of clip region
---@param width number|nil @Width of clip region
---@param height number|nil @Height of clip region
function clip(x, y, width, height) end

---Get or set pixel color.
---@param x number @X coordinate
---@param y number @Y coordinate
---@param color number|nil @Color index (0-15). If nil, returns current color.
---@return number|nil @Current color if color parameter is nil
function pix(x, y, color) end

---Draw a line.
---@param x0 number @Start X coordinate
---@param y0 number @Start Y coordinate
---@param x1 number @End X coordinate
---@param y1 number @End Y coordinate
---@param color number @Color index (0-15)
function line(x0, y0, x1, y1, color) end

---Draw a filled circle.
---@param x number @Center X coordinate
---@param y number @Center Y coordinate
---@param radius number @Circle radius
---@param color number @Color index (0-15)
function circ(x, y, radius, color) end

---Draw a circle border.
---@param x number @Center X coordinate
---@param y number @Center Y coordinate
---@param radius number @Circle radius
---@param color number @Color index (0-15)
function circb(x, y, radius, color) end

---Draw a filled ellipse.
---@param x number @Center X coordinate
---@param y number @Center Y coordinate
---@param a number @Horizontal radius
---@param b number @Vertical radius
---@param color number @Color index (0-15)
function elli(x, y, a, b, color) end

---Draw an ellipse border.
---@param x number @Center X coordinate
---@param y number @Center Y coordinate
---@param a number @Horizontal radius
---@param b number @Vertical radius
---@param color number @Color index (0-15)
function ellib(x, y, a, b, color) end

---Draw a filled rectangle.
---@param x number @X position
---@param y number @Y position
---@param width number @Rectangle width
---@param height number @Rectangle height
---@param color number @Color index (0-15)
function rect(x, y, width, height, color) end

---Draw a rectangle border.
---@param x number @X position
---@param y number @Y position
---@param width number @Rectangle width
---@param height number @Rectangle height
---@param color number @Color index (0-15)
function rectb(x, y, width, height, color) end

---Draw a filled triangle.
---@param x1 number @First vertex X
---@param y1 number @First vertex Y
---@param x2 number @Second vertex X
---@param y2 number @Second vertex Y
---@param x3 number @Third vertex X
---@param y3 number @Third vertex Y
---@param color number @Color index (0-15)
function tri(x1, y1, x2, y2, x3, y3, color) end

---Draw a triangle border.
---@param x1 number @First vertex X
---@param y1 number @First vertex Y
---@param x2 number @Second vertex X
---@param y2 number @Second vertex Y
---@param x3 number @Third vertex X
---@param y3 number @Third vertex Y
---@param color number @Color index (0-15)
function trib(x1, y1, x2, y2, x3, y3, color) end

---Draw a textured triangle.
---@param x1 number @First vertex X
---@param y1 number @First vertex Y
---@param x2 number @Second vertex X
---@param y2 number @Second vertex Y
---@param x3 number @Third vertex X
---@param y3 number @Third vertex Y
---@param u1 number @First texture U coordinate
---@param v1 number @First texture V coordinate
---@param u2 number @Second texture U coordinate
---@param v2 number @Second texture V coordinate
---@param u3 number @Third texture U coordinate
---@param v3 number @Third texture V coordinate
---@param texsrc number|nil @Texture source (0=foreground, 1=background). Default: 0
---@param chroma number|nil @Transparent color index. Default: -1 (none)
---@param z1 number|nil @First vertex depth. Default: 0
---@param z2 number|nil @Second vertex depth. Default: 0
---@param z3 number|nil @Third vertex depth. Default: 0
function ttri(x1, y1, x2, y2, x3, y3, u1, v1, u2, v2, u3, v3, texsrc, chroma, z1, z2, z3) end

---Draw sprite(s).
---@param id number @Sprite ID (0-511)
---@param x number @X position
---@param y number @Y position
---@param colorkey number|nil @Transparent color index. Default: -1 (none)
---@param scale number|nil @Scale factor. Default: 1
---@param flip number|nil @Flip flags (0=none, 1=horizontal, 2=vertical, 3=both). Default: 0
---@param rotate number|nil @Rotation (0=none, 1=90°, 2=180°, 3=270°). Default: 0
---@param w number|nil @Sprite width in tiles. Default: 1
---@param h number|nil @Sprite height in tiles. Default: 1
function spr(id, x, y, colorkey, scale, flip, rotate, w, h) end

---Draw map region.
---@param x number|nil @Map X cell coordinate. Default: 0
---@param y number|nil @Map Y cell coordinate. Default: 0
---@param w number|nil @Width in cells. Default: 30
---@param h number|nil @Height in cells. Default: 17
---@param sx number|nil @Screen X position. Default: 0
---@param sy number|nil @Screen Y position. Default: 0
---@param colorkey number|nil @Transparent color index. Default: -1 (none)
---@param scale number|nil @Scale factor. Default: 1
---@param remap function|nil @Remap function(tile, x, y) -> tile
function map(x, y, w, h, sx, sy, colorkey, scale, remap) end

---Print text using system font.
---@param text string @Text to print
---@param x number|nil @X position. Default: 0
---@param y number|nil @Y position. Default: 0
---@param color number|nil @Color index (0-15). Default: 15
---@param fixed boolean|nil @Fixed width font. Default: false
---@param scale number|nil @Scale factor. Default: 1
---@param smallfont boolean|nil @Use small font. Default: false
---@return number @Text width in pixels
function print(text, x, y, color, fixed, scale, smallfont) end

---Print text using sprite font.
---@param text string @Text to print
---@param x number @X position
---@param y number @Y position
---@param transcolor number|nil @Transparent color index
---@param char_width number|nil @Character width. Default: 8
---@param char_height number|nil @Character height. Default: 8
---@param fixed boolean|nil @Fixed width font. Default: false
---@param scale number|nil @Scale factor. Default: 1
---@param alt boolean|nil @Use alternative font page. Default: false
---@return number @Text width in pixels
function font(text, x, y, transcolor, char_width, char_height, fixed, scale, alt) end

-- ============================================================================
-- INPUT FUNCTIONS
-- ============================================================================

---Get button state (held).
---@param id number|nil @Button ID (0-31). If nil, returns bitmask of all buttons.
---@return boolean|number @True if pressed (single button) or bitmask (all buttons)
function btn(id) end

---Get button state (just pressed with repeat).
---@param id number|nil @Button ID (0-31). If nil, returns bitmask of all buttons.
---@param hold number|nil @Frames to wait before repeat. Default: -1 (no repeat)
---@param period number|nil @Frames between repeats. Default: -1 (no repeat)
---@return boolean|number @True if pressed (single button) or bitmask (all buttons)
function btnp(id, hold, period) end

---Get key state (held).
---@param code number|nil @Key code. If nil, returns code of any pressed key.
---@return boolean|number @True if pressed (single key) or key code (any key)
function key(code) end

---Get key state (just pressed with repeat).
---@param code number|nil @Key code. If nil, returns code of any pressed key.
---@param hold number|nil @Frames to wait before repeat. Default: -1 (no repeat)
---@param period number|nil @Frames between repeats. Default: -1 (no repeat)
---@return boolean|number @True if pressed (single key) or key code (any key)
function keyp(code, hold, period) end

---Get mouse/touch state.
---@return number x @Mouse X coordinate
---@return number y @Mouse Y coordinate
---@return boolean left @Left button pressed
---@return boolean middle @Middle button pressed
---@return boolean right @Right button pressed
---@return number scrollx @Horizontal scroll
---@return number scrolly @Vertical scroll
function mouse() end

-- ============================================================================
-- SOUND FUNCTIONS
-- ============================================================================

---Play sound effect.
---@param id number @Sound effect ID (0-63)
---@param note number|nil @Note (0-95, or -1 to use sound's note). Default: -1
---@param duration number|nil @Duration in frames (-1 to use sound's duration). Default: -1
---@param channel number|nil @Audio channel (0-3). Default: 0
---@param volume number|nil @Volume (0-15). Default: 15
---@param speed number|nil @Speed (0-7). Default: 0
function sfx(id, note, duration, channel, volume, speed) end

---Play music track.
---@param track number|nil @Track number (0-7, or -1 to stop music). Default: -1
---@param frame number|nil @Starting frame. Default: -1 (current)
---@param row number|nil @Starting row. Default: -1 (current)
---@param loop boolean|nil @Loop track. Default: true
---@param sustain boolean|nil @Sustain notes. Default: false
---@param tempo number|nil @Tempo (-1 to use track's tempo). Default: -1
---@param speed number|nil @Speed (-1 to use track's speed). Default: -1
function music(track, frame, row, loop, sustain, tempo, speed) end

-- ============================================================================
-- MEMORY FUNCTIONS
-- ============================================================================

---Read a value from a RAM address.
---@param addr number @0x00000..0x17FFF (RAM address)
---@param bits number|nil @Number of bits to read (1, 2, 4, or 8). Default: 8.
---@return number @Value read from RAM
function peek(addr, bits) end

---Read 1 bit from RAM.
---@param bitaddr number @Bit address
---@return number @Bit value (0 or 1)
function peek1(bitaddr) end

---Read 2 bits from RAM.
---@param addr2 number @2-bit address
---@return number @2-bit value (0-3)
function peek2(addr2) end

---Read 4 bits (nibble) from RAM.
---@param addr4 number @Nibble address
---@return number @Nibble value (0-15)
function peek4(addr4) end

---Write a value to a RAM address.
---@param addr number @0x00000..0x17FFF (RAM address)
---@param value number @Value to write (0..255 for 8 bits, 0..15 for 4 bits, etc.)
---@param bits number|nil @Number of bits to write (1, 2, 4, or 8). Default: 8.
function poke(addr, value, bits) end

---Write 1 bit to RAM.
---@param bitaddr number @Bit address
---@param bit number @Bit value (0 or 1)
function poke1(bitaddr, bit) end

---Write 2 bits to RAM.
---@param addr2 number @2-bit address
---@param val2 number @2-bit value (0-3)
function poke2(addr2, val2) end

---Write 4 bits (nibble) to RAM.
---@param addr4 number @Nibble address
---@param nibble number @Nibble value (0-15)
function poke4(addr4, nibble) end

---Copy memory region.
---@param dest number @Destination address
---@param source number @Source address
---@param size number @Number of bytes to copy
function memcpy(dest, source, size) end

---Set memory region to value.
---@param dest number @Destination address
---@param value number @Value to set (0-255)
---@param size number @Number of bytes to set
function memset(dest, value, size) end

---Persistent memory access (256 bytes, 32-bit values).
---@param index number @Index (0-255)
---@param value number|nil @Value to write. If nil, reads instead.
---@return number @Current value at index
function pmem(index, value) end

---Synchronize RAM with cartridge.
---@param mask number|nil @Bitmask of sections to sync. Default: 0 (all)
---@param bank number|nil @Bank number (0-7). Default: 0
---@param tocart boolean|nil @Direction: true=RAM→cart, false=cart→RAM. Default: false
function sync(mask, bank, tocart) end

---Switch video RAM bank.
---@param bank number|nil @Bank number (0 or 1). If nil, returns current bank.
---@return number @Previous bank number
function vbank(bank) end

-- ============================================================================
-- MAP/SPRITE UTILITIES
-- ============================================================================

---Get map tile at coordinates.
---@param x number @Map X cell coordinate
---@param y number @Map Y cell coordinate
---@return number @Tile ID (0-255)
function mget(x, y) end

---Set map tile at coordinates.
---@param x number @Map X cell coordinate
---@param y number @Map Y cell coordinate
---@param tile_id number @Tile ID (0-255)
function mset(x, y, tile_id) end

---Get sprite flag(s).
---@param sprite_id number @Sprite ID (0-511)
---@param flag number|nil @Flag bit (0-7). If nil, returns all flags as bitmask.
---@return boolean|number @Flag value (single bit) or bitmask (all flags)
function fget(sprite_id, flag) end

---Set sprite flag.
---@param sprite_id number @Sprite ID (0-511)
---@param flag number|nil @Flag bit (0-7). If nil, sets all flags.
---@param value boolean|number @Flag value (boolean for single bit, number for all flags)
function fset(sprite_id, flag, value) end

-- ============================================================================
-- SYSTEM FUNCTIONS
-- ============================================================================

---Get milliseconds since cartridge started.
---@return number @Milliseconds since start
function time() end

---Get current Unix timestamp.
---@return number @Unix timestamp (seconds since epoch)
function tstamp() end

---Exit to TIC-80 console.
function exit() end

---Reset cartridge (restart).
function reset() end

---Print debug message to console.
---@param message string @Message to print
---@param color number|nil @Color index (0-15). Default: 15
function trace(message, color) end
