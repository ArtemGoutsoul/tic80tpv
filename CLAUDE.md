# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a TIC-80 demoscene demo called **Total Perspective Vortex**, inspired by Douglas Adams' works. TIC-80 is a free fantasy computer for making, playing and sharing tiny games and demos.

The project is currently in development (work in progress).

## File Structure

- **tpv.lua** - Main demo source file (work in progress):
  - Demo metadata in header comments
  - Global variables and demo state
  - Helper functions: `waveX`/`waveY` (shared wave field), `ditheredTri` and `drawPyramid`/`drawPyramidGrid` (the pyramid mesh), `drawLogoShadow` and `drawLogoOnTop` (the logo)
  - TIC() function - the main demo loop called 60 times per second
  - Embedded data sections: TILES, SPRITES, WAVES, SFX, TRACKS, PALETTE

- **snow.lua** - Standalone secondary cart: procedural 6-fold-symmetric snowfall with parallax depth layers, sine-wave drift, and spacebar-triggered wind gusts

- **tic80stubs.lua** - TIC-80 API type definitions for Lua LSP (EmmyLua format)
  - Provides autocomplete and type checking for TIC-80 API functions
  - Not part of the actual demo runtime

- **october.tic** - Test music for the demo

- **tpv01.png, tpv02.gif** - Logo drafts for "Total Perspective Vortex"

- **docs/** - Background and reference notes (searched on demand, not loaded every session):
  - **total-perspective-vortex.md** - Summary of Douglas Adams' Hitchhiker's Guide works and the Total Perspective Vortex (the demo's theme and source material)
  - **tic80-api-reference.md** - Indexed TIC-80 API quick reference (moved out of this file); full per-function docs in `tic80wiki/`

- **.claude/skills/** - Task playbooks auto-surfaced by trigger words (local-only; `.claude/` is gitignored):
  - **tic80-sound** - Making sound/music in TIC-80 from Lua (API, instrument RAM, raw sound registers)
  - **tic80-screenshot** - Screenshotting the running TIC-80 window to verify visual changes from an automated session

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

To verify a visual change by screenshotting the running TIC-80 window from an
automated session, use the **tic80-screenshot** skill. It covers the Windows
`System.Drawing` + `GetWindowRect` window grab, the `.screenshots/` folder
convention with session-start cleanup, and the gotchas (minimized window →
blank grab, fresh-shell `Add-Type`, waiting ~3–4 s for the cart to compile).

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
5. Embedded data sections (TILES, SPRITES, WAVES, SFX, TRACKS, PALETTE)

## Demoscene Context

This is a **demoscene production** - an audiovisual artistic demo showcasing programming and artistic skills within TIC-80's constraints. Demoscene demos typically feature:
- Real-time generated effects synchronized to music
- Creative use of limited resources (240x136 screen, 16-color palette)
- Mathematical/procedural animations and visual effects
- Thematic coherence (in this case: Douglas Adams' "Total Perspective Vortex" — see [docs/total-perspective-vortex.md](docs/total-perspective-vortex.md) for the source material)

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

### General Lua style (community consensus)

Summarized from the [LuaRocks/Olivine-Labs style guide](https://github.com/luarocks/lua-style-guide) and the [lua-users wiki Style Guide](http://lua-users.org/wiki/LuaStyleGuide). Where this repo deliberately differs, the house conventions below win — the golden rule is **be consistent with the surrounding code**.

- **Scope:** always declare with `local`; never create accidental globals. Give a variable the smallest scope that works. The wider the scope, the more descriptive the name (a one-letter name is fine in a tight loop, wrong for a module-level value).
- **Naming (mainstream default):** `snake_case` for variables and functions, `UPPER_SNAKE_CASE` for true constants, `PascalCase` for classes/types, lowercase for module names. Prefix boolean-returning functions with `is`/`has`. Use `_` for a value you intentionally ignore. Names starting with `_UPPERCASE` are reserved by Lua — don't define them.
- **One statement per line;** never terminate statements with semicolons. Keep single-line `if ... then ... end` only for trivial `then return` / `then break` guards; use multi-line blocks otherwise.
- **Spacing:** one space after `--`, around binary operators, and after commas; no space between a function name and its `(`; no spaces just inside `(` `)` or `{` `}`. Blank line between function definitions. Don't column-align assignments (noisy diffs — but see the deliberate ramp/table alignment in this repo, which is a readability exception for data tables).
- **Calls & tables:** use parentheses on calls (`require("x")`, `f("s")`), even for single string/table args. Prefer `t.field` over `t["field"]` unless the key isn't a valid identifier. Trailing commas on multi-line table literals are encouraged.
- **`and`/`or` idiom:** fine for a pseudo-ternary (`x = cond and a or b`), but not when the "true" branch can be `false`/`nil` — it silently falls through to the `or` branch.
- **Comments:** explain *why*, not *how*; if a block needs a lot of inline how-to, that's a hint to extract a well-named function. Use `TODO` for missing features and `FIXME` for known bugs.
- **Errors:** return `nil, message` for expected/recoverable failures (I/O, parsing); use `error()`/`assert()` for programmer mistakes (bad arguments, broken invariants).
- **Static analysis:** code should pass [luacheck](https://github.com/lunarmodules/luacheck) with defaults; keep a `.luacheckrc` for intentional exceptions rather than scattering inline ignores.

### House conventions (this repo)

`tpv.lua` follows the community rules above **except** where TIC-80 / demoscene practice or the existing code says otherwise. Match these when editing:

- **Indentation: tabs**, not spaces (the project is formatted with tabs; don't reintroduce spaces). This is the one clear departure from the mainstream "spaces only" advice — consistency with the existing file wins.
- **Function naming: `camelCase` for every function and local** — both the top-level drawing/effect routines (`ditheredTri`, `drawPyramid`, `drawPyramidGrid`, `drawLogoShadow`, `drawLogoOnTop`) and the small helpers (`waveX`, `waveY`, `logoMaskAddr`, `cellCols`, `edgeWeight`, `brightStep`). We diverge from the mainstream `snake_case` default, but stay uniform: no `snake_case`, and no `PascalCase` (which Lua reserves for classes/types — this demo has none).
  - TIC-80 callbacks stay ALL-CAPS because the platform requires it (`TIC`, `BOOT`, `BDR`, `OVR`, `MENU`, `SCN`).
- **Constants** are `UPPER_SNAKE_CASE` module-level `local`s declared at the top of the file, before any function that uses them (see the "Lua / TIC-80 Gotchas" note on `local` ordering).
- **Localize hot library functions** at the top of inner-loop functions (`local floor, random = math.floor, math.random`) — a performance idiom, covered under "Performance budget".
- No globals, no semicolons, parentheses on calls — same as the mainstream rules.

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

This is how `drawLogoShadow` tests the logo's transparency mask without re-rendering the sprite.

### Dithered gradients (faking >16 colors)

**`ditheredTri(x1, y1, x2, y2, x3, y3, colorList, b1, b2, b3)`** (arbitrary triangle) is the workhorse. Scanline rasterizer: vertices sorted by Y, left/right `x` and `brightness` advanced incrementally along the triangle edges, brightness then steps once per pixel across each scanline. A per-pixel `math.random(0, 15)` threshold picks between the two adjacent stops in `colorList`, producing animated white-noise dither. The four faces of every pyramid are drawn this way (see `drawPyramid`).

`colorList` is an ordered ramp of palette indices from dark to light (e.g. `{4, 9, 14, 15}` = brown → orange → yellow → white). The per-vertex `bN` values in `[0, 1]` map to a position along the ramp.

### Sub-pixel rendering via random dithering

To smoothly slide a single-pixel-thick element (sprite, shadow, particle) between integer screen coordinates, use:

```lua
local fx = math.floor(targetX)
local sx = (math.random() < targetX - fx) and (fx + 1) or fx
```

As `targetX` smoothly crosses 4.0 → 4.5 → 5.0, the proportion of pixels at `fx + 1` grows 0% → 50% → 100%. The visible centroid moves continuously even though every pixel is still on the integer grid. Used by `drawLogoShadow` so the shadow doesn't snap as its offset changes.

### Wavy mesh via shared-corner table

`drawPyramidGrid` builds a `(cellCols + 1) × (cellRows + 1)` table of warped corner positions once per frame and looks them up per cell. Adjacent cells share corners exactly (no overlap, no gap), so the grid bends like a sheet of cloth. The outer ring of corners is anchored (`edgeWeight = 0`) so the screen border stays covered. **Snap corners to integer pixels** with `math.floor(x + 0.5)` to avoid sub-pixel rounding artifacts at shared rasterizer edges.

### Coupling effects to one wave function

When two effects should look like they belong to the same world, key them off the **same** wave function. The logo shadow's height field uses the exact `cos(...) * 0.6 + cos(...) * 0.4` formula the grid uses for vertical corner displacement (`dy`), evaluated at the shadow pixel's grid coordinates. The shadow then sways in lockstep with the surface bending below it.

### Per-palette darkening LUT

For a "darken this pixel by one shade" effect (drop shadow, pressed-button highlight, etc.), hand-tune a 16-entry table mapping each palette index to its darker counterpart. Nest the lookup for a deeper darken — `drawLogoShadow` applies `SHADOW_DARKEN` two or three levels deep and dithers 50/50 between the two depths, so the shadow edge reads as soft rather than a hard step. The DB16 mapping in `SHADOW_DARKEN` walks warm colors toward brown and cool colors toward dark blue.

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

The full API index (callbacks, drawing, input, sound, memory, map/sprite, and
system functions, each with signature and a link to per-function docs) lives in
**[docs/tic80-api-reference.md](docs/tic80-api-reference.md)**. Complete
per-function documentation is in the [`tic80wiki/`](tic80wiki/) folder (local
copy of the official TIC-80 wiki). Look there rather than keeping it in context.
