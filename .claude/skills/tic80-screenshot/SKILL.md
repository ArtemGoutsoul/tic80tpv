---
name: tic80-screenshot
description: >-
  Capture a screenshot of the running TIC-80 window from an automated/headless
  session on Windows, to verify visual changes to a cart. Covers the
  System.Drawing + GetWindowRect window-grab, restoring a minimized window,
  the fresh-shell Add-Type caveat, waiting for the cart to compile, and the
  .screenshots/ folder convention with session-start cleanup. Trigger words:
  screenshot, screen grab, capture the window, capture TIC-80, verify visual
  change, does it render, show me the demo, grab the screen, window grab,
  GetWindowRect, CopyFromScreen, .screenshots.
---

# Screenshot the running TIC-80 window

A playbook for verifying visual changes to a TIC-80 cart from an automated
session (no human at the screen). Environment: Windows native, `PowerShell`
tool preferred. To launch the cart first, see the project `CLAUDE.md`
("Launching from an automated/non-interactive shell") — TIC-80 must already be
running in its own window before you grab it.

## The window grab

Capture the TIC-80 window via `System.Drawing` + `GetWindowRect`:

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
[Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null  # SW_RESTORE (un-minimizes)
[Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 800  # let the window come forward and redraw
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$bmp = New-Object System.Drawing.Bitmap(($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$bmp.Save('.screenshots/<name>.png', [System.Drawing.Imaging.ImageFormat]::Png)
```

Then view the PNG with the Read tool to confirm what rendered.

## Gotchas (each has burned us)

- **Each `PowerShell` tool call has fresh shell state** — `Add-Type` definitions
  don't persist between calls, so re-declare the `Win32` type in every
  screenshot script.
- **The window may be minimized** — a minimized TIC-80 captures as a blank/white
  strip. Always call `ShowWindow(handle, 9)` (SW_RESTORE) **before** measuring
  the rect (the snippet already does). If a grab comes back blank, the window
  was almost certainly minimized or behind the lock screen.
- **The capture reads live on-screen pixels** at the window's rect — if the OS
  lock screen is up, you capture the lock screen, not TIC-80.
- **Wait for compile.** After launching or restarting TIC-80 (`Stop-Process` +
  `Start-Process`), wait ~3–4 s before grabbing so the cart has compiled and run;
  otherwise you catch the boot/loading screen instead of the demo. TIC-80 also
  plays a short startup ("surf") animation on launch — an extra second or two
  avoids catching that.
- **A blank window title still says `[cart.lua]`** even on a Lua error; to tell a
  successful run from an error, look at the captured pixels (an error shows the
  red console text), not just the title.

## The `.screenshots/` folder

- Save to `.screenshots/` in the project root — **not** the project root itself,
  **not** `.local/`. The folder is gitignored (see `.gitignore`; it lists
  `.screenshots/`). Create it if missing.
- Use descriptive names that reflect what's being verified
  (`tic80_shadow_subpixel.png`, `tic80_wavy_irregular.png`) — the folder is a
  debugging scratchpad, not history worth preserving.
- **Clean up old screenshots at the start of a screenshotting session** (anything
  older than ~1 hour is from a prior session):

```powershell
Get-ChildItem .screenshots -File -ErrorAction SilentlyContinue |
  Where-Object LastWriteTime -lt (Get-Date).AddHours(-1) |
  Remove-Item
```

Do this only at session start (not after every shot) so intra-session
comparisons survive while the folder stays bounded.
