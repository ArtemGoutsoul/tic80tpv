# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a TIC-80 demoscene demo called **Total Perspective Vortex**, inspired by Douglas Adams' works. TIC-80 is a free fantasy computer for making, playing and sharing tiny games and demos.

The project is currently in development (work in progress).

## File Structure

- **tpv.lua** - Main demo source file (work in progress):
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

The TIC-80 executable lives one directory up from this project: `C:\dev\tic80\tic80.exe` (it is **not** on PATH).

To run the demo:
```
C:\dev\tic80\tic80.exe tpv.lua
```

Or load in TIC-80 console:
```
load tpv.lua
run
```

To play the test music:
```
C:\dev\tic80\tic80.exe october.tic
```

### Launching from an automated/non-interactive shell

TIC-80 needs its own window. Invoking it directly with `&` from a background PowerShell task causes it to load the cart and exit immediately (no TTY). Use `Start-Process` so it launches detached:

```powershell
Start-Process -FilePath "C:\dev\tic80\tic80.exe" -ArgumentList "C:\dev\tic80\test2\tpv.lua" -WorkingDirectory "C:\dev\tic80\test2"
```

### Screenshot capture (window grab)

For verifying visual changes from an automated session, capture the TIC-80 window via `System.Drawing` + `GetWindowRect`:

```powershell
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
$proc = Get-Process tic80 | ? { $_.MainWindowHandle -ne 0 } | Select -First 1
[Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null  # SW_RESTORE
[Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 800  # let the window come forward and redraw
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$bmp = New-Object System.Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$bmp.Save('.screenshots/<name>.png', [System.Drawing.Imaging.ImageFormat]::Png)
```

Notes:
- **Each `PowerShell` tool call has fresh shell state** — `Add-Type` definitions don't persist between calls, so re-declare them in every screenshot script.
- The screen capture reads whatever pixels are currently on-screen at the window's rect — if the OS lock screen is up, you'll capture the lock screen, not TIC-80.
- After restarting TIC-80 (`Stop-Process` + `Start-Process`), wait ~3–4 seconds before screenshotting so the cart has time to compile and run; otherwise you'll catch the boot/loading screen.

#### Screenshot folder & cleanup

- Save screenshots to `.screenshots/` in the project root, **not** the project root itself, **not** `.local/`. The folder name is gitignored (see `.gitignore` — create one with `.screenshots/` and `.local/` listed if it doesn't exist yet).
- Use descriptive names that reflect what's being verified (`tic80_shadow_subpixel.png`, `tic80_wavy_irregular.png`) — the folder is a debugging scratchpad, not history we want to preserve.
- **Clean up old screenshots at the start of a screenshotting session** (anything older than ~1 hour is from a prior session and isn't useful):

```powershell
Get-ChildItem .screenshots -File -ErrorAction SilentlyContinue |
  Where-Object LastWriteTime -lt (Get-Date).AddHours(-1) |
  Remove-Item
```

Doing this only at session start (not after every screenshot) preserves intra-session comparisons while keeping the folder from growing without bound.

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
- Main demo development happens in tpv.lua
- The stubs file is for IDE support only - it's not loaded by TIC-80
- Demo effects should be optimized to run at 60 FPS within TIC-80's constraints

## Coding Style

- **Avoid abbreviations** in variable and function names for better readability
- Exception: Use standard abbreviations like `x`, `y`, `i`, `j` for coordinates and loop counters
- Examples:
  - Good: `scanline`, `wave`, `address`, `color`
  - Avoid: `s`, `w`, `addr`, `col` (except in standard contexts)

## Demoscene Techniques in tpv.lua

These are the non-obvious patterns currently in use in `tpv.lua`. Reach for them when adding new effects.

### Direct screen RAM writes (`poke4`)

The screen is 240×136 at 4 bits/pixel starting at nibble address 0. Writing pixels via `poke4(y * 240 + x, color)` is **substantially faster** than `pix(x, y, color)` because it skips the API-call overhead. Use this in any inner pixel loop.

### Sprite-mask sampling

To read pixel data from sprites (e.g. for shadows, outlines, or per-pixel effects driven by a sprite shape), peek directly into sprite RAM:

- **BG tiles (sprite IDs 0–255)**: byte base `0x4000` → nibble base `0x8000`
- **FG sprites (sprite IDs 256–511)**: byte base `0x6000` → nibble base `0xC000`

Each sprite is 8×8 pixels at 4 bits each = 64 nibbles. For sprite `id` in the FG range and pixel `(px, py)`:

```lua
local localId = id - 256
local nibble  = peek4(0xC000 + localId * 64 + py * 8 + px)
-- 0 = transparent (typical), otherwise the palette index
```

This is how `DrawLogoShadow` tests the logo's transparency mask without re-rendering the sprite.

### Dithered gradients (faking >16 colors)

Two complementary patterns are used:

1. **`DrawDitheredGradient(x, y, w, h, colorList)`** (rectangular). Per-row brightness is constant, so the 4-pixel Bayer (or random) pattern is precomputed once per row and the inner loop is just a `poke4`. Cheap enough for full-screen backgrounds.
2. **`DitheredTri(x1, y1, x2, y2, x3, y3, colorList, b1, b2, b3)`** (arbitrary triangle). Scanline rasterizer: vertices sorted by Y, left/right `x` and `brightness` advanced incrementally along the triangle edges, brightness then steps once per pixel across each scanline. A per-pixel `math.random(0, 15)` threshold picks between the two adjacent stops in `colorList`, producing animated white-noise dither.

`colorList` is an ordered ramp of palette indices from dark to light (e.g. `{4, 9, 14, 15}` = brown → orange → yellow → white). The per-vertex `bN` values in `[0, 1]` map to a position along the ramp.

### Sub-pixel rendering via random dithering

To smoothly slide a single-pixel-thick element (sprite, shadow, particle) between integer screen coordinates, use:

```lua
local fx = math.floor(targetX)
local sx = (math.random() < targetX - fx) and (fx + 1) or fx
```

As `targetX` smoothly crosses 4.0 → 4.5 → 5.0, the proportion of pixels at `fx + 1` grows 0% → 50% → 100%. The visible centroid moves continuously even though every pixel is still on the integer grid. Used by `DrawLogoShadow` so the shadow doesn't snap as its offset changes.

### Wavy mesh via shared-corner table

`DrawPyramidGrid` builds a `(cellCols + 1) × (cellRows + 1)` table of warped corner positions once per frame and looks them up per cell. Adjacent cells share corners exactly (no overlap, no gap), so the grid bends like a sheet of cloth. The outer ring of corners is anchored (`edgeWeight = 0`) so the screen border stays covered. **Snap corners to integer pixels** with `math.floor(x + 0.5)` to avoid sub-pixel rounding artifacts at shared rasterizer edges.

### Coupling effects to one wave function

When two effects should look like they belong to the same world, key them off the **same** wave function. The logo shadow's height field uses the exact `cos(...) * 0.6 + cos(...) * 0.4` formula the grid uses for vertical corner displacement (`dy`), evaluated at the shadow pixel's grid coordinates. The shadow then sways in lockstep with the surface bending below it.

### Per-palette darkening LUT

For a "darken this pixel by one shade" effect (drop shadow, pressed-button highlight, etc.), hand-tune a 16-entry table mapping each palette index to its darker counterpart. Apply twice for a deeper darken. The DB16 mapping in `SHADOW_DARKEN` walks warm colors toward brown and cool colors toward dark blue.

## Lua / TIC-80 Gotchas

- **`local` declarations must precede every function that uses them.** Lua resolves an unknown name as a global (which is `nil`) when the function is *defined*, not when it's *called*. If `local FOO = 0.0042` is declared after a function that references `FOO`, that function gets `nil` at runtime. Put module-level `local` constants near the top of the file before any function definitions.
- **Forward function references work fine** — Lua looks up function values dynamically when the call happens, so `function A() B() end` followed by `function B() ... end` works. Only `local` *values* hit the ordering trap.
- **`math.random()` with no args** returns a float in `[0, 1)` (Lua 5.3+). With `(m, n)` returns an integer in `[m, n]`. Both forms advance the same global PRNG state, so per-pixel calls naturally vary frame-to-frame.
- **Integer division `//` is available** (Lua 5.3+), as are bitwise ops. `tpv.lua` uses `//` freely.
- **TIC-80 launches as a windowed app**, not a CLI — invoking it via `&` from a non-interactive PowerShell makes it exit immediately. Use `Start-Process` (see "Launching from an automated/non-interactive shell" above).

## Performance budget (rule of thumb)

At 60 FPS on TIC-80 Lua:

- Tens of thousands of `poke4` / `peek4` per frame: fine
- ~150k pixel-level operations per frame: borderline; profile if you add more
- Per-pixel `math.sin` / `math.cos`: ~16k–32k per frame is OK; 100k+ will dip below 60 FPS
- Prefer **scanline rasterization** with incremental brightness over per-pixel **bounding-box + barycentric** for triangle effects
- Localize `math.floor`, `math.sin`, `math.random`, `pix`/`poke4` etc. inside hot functions (`local floor = math.floor`) to skip repeated table lookups

---

## TIC-80 API Reference

Complete TIC-80 API documentation is available in `tic80wiki/` folder (local copy of the official TIC-80 wiki documentation).

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
