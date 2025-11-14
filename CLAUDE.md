# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a TIC-80 demoscene demo called **Total Perspective Vortex**, inspired by Douglas Adams' works. TIC-80 is a free fantasy computer for making, playing and sharing tiny games and demos.

The project is currently in development (work in progress).

## File Structure

- **test2.lua** - Main demo source file (work in progress):
  - Demo metadata in header comments
  - Global variables and demo state
  - TIC() function - the main demo loop called 60 times per second
  - Demo effects functions (e.g., Pir() for animated pyramid effects)
  - Embedded data sections: TILES, WAVES, SFX, TRACKS, PALETTE

- **tic80stubs.lua** - TIC-80 API type definitions for Lua LSP (EmmyLua format)
  - Provides autocomplete and type checking for TIC-80 API functions
  - Not part of the actual demo runtime

- **october.tic** - Test music for the demo

- **tpv01.png, tpv02.gif** - Logo drafts for "Total Perspective Vortex"

## TIC-80 Development Commands

To run the demo:
```
tic80 test2.lua
```

Or load in TIC-80 console:
```
load test2.lua
run
```

To play the test music:
```
tic80 october.tic
```

## TIC-80 Architecture

### Core Concepts

- **TIC() function**: The main game loop - called 60 times per second (60 FPS)
- **Embedded Data**: Asset data (sprites, sounds, music, palette) is embedded directly in the Lua file using special comment sections
- **Screen**: 240x136 pixels
- **Palette**: 16 colors (indices 0-15)

### Common TIC-80 API Functions

- `time()` - Get milliseconds since cartridge start
- `cls(color)` - Clear screen
- `line(x0, y0, x1, y1, color)` - Draw line
- `tri(x1, y1, x2, y2, x3, y3, color)` - Draw filled triangle

### Code Organization Pattern

1. Metadata comments at the top (title, author, desc, etc.)
2. Global variable declarations
3. Helper functions
4. TIC() function implementation
5. Embedded data sections (TILES, WAVES, SFX, TRACKS, PALETTE)

## Demoscene Context

This is a **demoscene production** - an audiovisual artistic demo showcasing programming and artistic skills within TIC-80's constraints. Demoscene demos typically feature:
- Real-time generated effects synchronized to music
- Creative use of limited resources (240x136 screen, 16-color palette)
- Mathematical/procedural animations and visual effects
- Thematic coherence (in this case: Douglas Adams' "Total Perspective Vortex")

## Development Notes

- The `.tic` file is the compiled/binary format - the `.lua` file is the source
- Main demo development happens in test2.lua
- The stubs file is for IDE support only - it's not loaded by TIC-80
- Demo effects should be optimized to run at 60 FPS within TIC-80's constraints

## Coding Style

- **Avoid abbreviations** in variable and function names for better readability
- Exception: Use standard abbreviations like `x`, `y`, `i`, `j` for coordinates and loop counters
- Examples:
  - Good: `scanline`, `wave`, `address`, `color`
  - Avoid: `s`, `w`, `addr`, `col` (except in standard contexts)

---

## TIC-80 API Reference

Complete TIC-80 API documentation is available in `tic80wiki/` folder (cloned from the official GitHub wiki).

### Platform Concepts

- **[RAM](tic80wiki/RAM.md)** - Memory map (96KB addressable: sprites, map, sound, code, etc.)
- **[Palette](tic80wiki/Palette.md)** - 16 colors (indices 0-15), customizable per scanline
- **[Sprites](tic80wiki/Sprite-Editor.md)** - 8×8 pixel tiles, 512 sprites total
- **[Map](tic80wiki/Map-Editor.md)** - 240×136 cells (each references a sprite)
- **[Bankswitching](tic80wiki/Bankswitching.md)** - Switch between 8 banks of assets
- **[Coordinate System](tic80wiki/coordinate.md)** - Screen is 240×136 pixels, origin at (0,0) top-left

### API Quick Reference

#### Callbacks

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **TIC** | `TIC()` | Main loop, called 60 times/second (required) | [tic80wiki/TIC.md](tic80wiki/TIC.md) |
| **BOOT** | `BOOT()` | Called once on cartridge boot | [tic80wiki/BOOT.md](tic80wiki/BOOT.md) |
| **BDR** | `BDR(scanline)` | Called before each scanline (0-143) | [tic80wiki/BDR.md](tic80wiki/BDR.md) |
| **OVR** | `OVR()` | Draw overlay layer (deprecated, use vbank) | [tic80wiki/OVR.md](tic80wiki/OVR.md) |
| **MENU** | `MENU(index)` | Handle custom menu items | [tic80wiki/MENU.md](tic80wiki/MENU.md) |
| **SCN** | `SCN(scanline)` | Per-scanline callback (deprecated, use BDR) | [tic80wiki/SCN.md](tic80wiki/SCN.md) |

#### Drawing Functions

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **cls** | `cls([color=0])` | Clear screen with color | [tic80wiki/cls.md](tic80wiki/cls.md) |
| **clip** | `clip([x, y, width, height])` | Set/reset clipping region | [tic80wiki/clip.md](tic80wiki/clip.md) |
| **pix** | `pix(x, y, [color])` | Get/set pixel color | [tic80wiki/pix.md](tic80wiki/pix.md) |
| **line** | `line(x0, y0, x1, y1, color)` | Draw line | [tic80wiki/line.md](tic80wiki/line.md) |
| **circ** | `circ(x, y, radius, color)` | Draw filled circle | [tic80wiki/circ.md](tic80wiki/circ.md) |
| **circb** | `circb(x, y, radius, color)` | Draw circle border | [tic80wiki/circb.md](tic80wiki/circb.md) |
| **elli** | `elli(x, y, a, b, color)` | Draw filled ellipse | [tic80wiki/elli.md](tic80wiki/elli.md) |
| **ellib** | `ellib(x, y, a, b, color)` | Draw ellipse border | [tic80wiki/ellib.md](tic80wiki/ellib.md) |
| **rect** | `rect(x, y, width, height, color)` | Draw filled rectangle | [tic80wiki/rect.md](tic80wiki/rect.md) |
| **rectb** | `rectb(x, y, width, height, color)` | Draw rectangle border | [tic80wiki/rectb.md](tic80wiki/rectb.md) |
| **tri** | `tri(x1, y1, x2, y2, x3, y3, color)` | Draw filled triangle | [tic80wiki/tri.md](tic80wiki/tri.md) |
| **trib** | `trib(x1, y1, x2, y2, x3, y3, color)` | Draw triangle border | [tic80wiki/trib.md](tic80wiki/trib.md) |
| **ttri** | `ttri(x1, y1, x2, y2, x3, y3, u1, v1, u2, v2, u3, v3, [texsrc=0], [chroma=-1], [z1=0], [z2=0], [z3=0])` | Draw textured triangle | [tic80wiki/ttri.md](tic80wiki/ttri.md) |
| **spr** | `spr(id, x, y, [colorkey=-1], [scale=1], [flip=0], [rotate=0], [w=1], [h=1])` | Draw sprite(s) | [tic80wiki/spr.md](tic80wiki/spr.md) |
| **map** | `map([x=0], [y=0], [w=30], [h=17], [sx=0], [sy=0], [colorkey=-1], [scale=1], [remap])` | Draw map region | [tic80wiki/map.md](tic80wiki/map.md) |
| **print** | `print(text, [x=0], [y=0], [color=15], [fixed=false], [scale=1], [smallfont=false]) -> width` | Print text (system font) | [tic80wiki/print.md](tic80wiki/print.md) |
| **font** | `font(text, x, y, [transcolor], [char_width=8], [char_height=8], [fixed=false], [scale=1], [alt=false]) -> width` | Print text (sprite font) | [tic80wiki/font.md](tic80wiki/font.md) |

#### Input Functions

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **btn** | `btn([id]) -> pressed` | Get button state (held) | [tic80wiki/btn.md](tic80wiki/btn.md) |
| **btnp** | `btnp([id], [hold=-1], [period=-1]) -> pressed` | Get button state (just pressed) | [tic80wiki/btnp.md](tic80wiki/btnp.md) |
| **key** | `key([code]) -> pressed` | Get key state (held) | [tic80wiki/key.md](tic80wiki/key.md) |
| **keyp** | `keyp([code], [hold=-1], [period=-1]) -> pressed` | Get key state (just pressed) | [tic80wiki/keyp.md](tic80wiki/keyp.md) |
| **mouse** | `mouse() -> x, y, left, middle, right, scrollx, scrolly` | Get mouse/touch state | [tic80wiki/mouse.md](tic80wiki/mouse.md) |

#### Sound Functions

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **sfx** | `sfx(id, [note=-1], [duration=-1], [channel=0], [volume=15], [speed=0])` | Play sound effect | [tic80wiki/sfx.md](tic80wiki/sfx.md) |
| **music** | `music([track=-1], [frame=-1], [row=-1], [loop=true], [sustain=false], [tempo=-1], [speed=-1])` | Play music track | [tic80wiki/music.md](tic80wiki/music.md) |

#### Memory Functions

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **peek** | `peek(addr, [bits=8]) -> value` | Read byte/nibble/bits from RAM | [tic80wiki/peek.md](tic80wiki/peek.md) |
| **peek1** | `peek1(bitaddr) -> bit` | Read 1 bit from RAM | [tic80wiki/peek1.md](tic80wiki/peek1.md) |
| **peek2** | `peek2(addr2) -> val2` | Read 2 bits from RAM | [tic80wiki/peek2.md](tic80wiki/peek2.md) |
| **peek4** | `peek4(addr4) -> nibble` | Read 4 bits (nibble) from RAM | [tic80wiki/peek4.md](tic80wiki/peek4.md) |
| **poke** | `poke(addr, value, [bits=8])` | Write byte/nibble/bits to RAM | [tic80wiki/poke.md](tic80wiki/poke.md) |
| **poke1** | `poke1(bitaddr, bit)` | Write 1 bit to RAM | [tic80wiki/poke1.md](tic80wiki/poke1.md) |
| **poke2** | `poke2(addr2, val2)` | Write 2 bits to RAM | [tic80wiki/poke2.md](tic80wiki/poke2.md) |
| **poke4** | `poke4(addr4, nibble)` | Write 4 bits (nibble) to RAM | [tic80wiki/poke4.md](tic80wiki/poke4.md) |
| **memcpy** | `memcpy(dest, source, size)` | Copy memory region | [tic80wiki/memcpy.md](tic80wiki/memcpy.md) |
| **memset** | `memset(dest, value, size)` | Set memory region to value | [tic80wiki/memset.md](tic80wiki/memset.md) |
| **pmem** | `pmem(index, [value]) -> value` | Persistent memory (256 bytes, 32-bit values) | [tic80wiki/pmem.md](tic80wiki/pmem.md) |
| **sync** | `sync([mask=0], [bank=0], [tocart=false])` | Sync RAM to/from cartridge | [tic80wiki/sync.md](tic80wiki/sync.md) |
| **vbank** | `vbank([bank]) -> prev_bank` | Switch video RAM bank (0-1) | [tic80wiki/vbank.md](tic80wiki/vbank.md) |

#### Map/Sprite Utilities

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **mget** | `mget(x, y) -> tile_id` | Get map tile at coordinates | [tic80wiki/mget.md](tic80wiki/mget.md) |
| **mset** | `mset(x, y, tile_id)` | Set map tile at coordinates | [tic80wiki/mset.md](tic80wiki/mset.md) |
| **fget** | `fget(sprite_id, [flag]) -> value` | Get sprite flag(s) | [tic80wiki/fget.md](tic80wiki/fget.md) |
| **fset** | `fset(sprite_id, [flag], value)` | Set sprite flag | [tic80wiki/fset.md](tic80wiki/fset.md) |

#### System Functions

| Function | Signature | Description | Docs |
|----------|-----------|-------------|------|
| **time** | `time() -> milliseconds` | Get elapsed time since start | [tic80wiki/time.md](tic80wiki/time.md) |
| **tstamp** | `tstamp() -> unix_timestamp` | Get current Unix timestamp | [tic80wiki/tstamp.md](tic80wiki/tstamp.md) |
| **exit** | `exit()` | Exit to console | [tic80wiki/exit.md](tic80wiki/exit.md) |
| **reset** | `reset()` | Reset cartridge | [tic80wiki/reset.md](tic80wiki/reset.md) |
| **trace** | `trace(message, [color=15])` | Print to console (debug) | [tic80wiki/trace.md](tic80wiki/trace.md) |

### Additional Resources

- **[Cheatsheet](tic80wiki/Cheatsheet.md)** - Quick reference sheet
- **[Tutorials](tic80wiki/Tutorials.md)** - Step-by-step guides
- **[Code Examples](tic80wiki/Code-examples-and-snippets.md)** - Useful code snippets
- **[RAM Map](tic80wiki/RAM.md)** - Complete memory layout (0x00000-0x17FFF)
- **[Key Map](tic80wiki/Key-Map.md)** - Keyboard/gamepad button IDs
