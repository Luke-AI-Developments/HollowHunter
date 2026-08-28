# Home-screen HUD top inset + fit — design spec

**Date:** 2026-08-28
**Status:** Approved by user. Trivial `.tscn`-only change — implemented inline (no plan/SDD).

## Problem

On the Pixel 9a (1080×2424, full-screen), the stats HUD is jammed against
the top edge and its text overflows the frame:

- `GameUI/Label` starts at `offset_top = 10`, so the first line ("Lv N
  SUBCLASS") has its glyph tops clipped by the screen edge.
- The `Label` box is y 10–200 (190px) but holds 5 lines at 28pt (~190px of
  text). `HudFrame`'s visible bottom border (y ~200) cuts between line 4
  and line 5, so "Power: N" renders below the frame, on the map.

Nothing wraps — the fix is vertical room + a top inset, not font size.

## Change (all `scenes/main.tscn`, direct-child nodes of `GameUI`)

| Node | Before | After |
|---|---|---|
| `HudFrame` (NinePatchRect) | `offset_top = 0`, `offset_bottom = 210` | `offset_top = 48`, `offset_bottom = 320` |
| `Label` | `offset_top = 10`, `offset_bottom = 200` | `offset_top = 64`, `offset_bottom = 300` |
| `NavMenu/MenuButton` (Button) | `offset_top = 220`, `offset_bottom = 290` | `offset_top = 340`, `offset_bottom = 410` |
| `NavMenu/BannerList/*Banner` (9) | `offset_top = 300 + i*108`, `offset_bottom = 396 + i*108` | `offset_top = 424 + i*108`, `offset_bottom = 520 + i*108` |
| `ConfirmStrongholdButton` (Button) | `offset_top = 210`, `offset_bottom = 270` | `offset_top = 340`, `offset_bottom = 410` |
| `CancelStrongholdButton` (Button) | `offset_top = 210`, `offset_bottom = 270` | `offset_top = 340`, `offset_bottom = 410` |
| `SystemToast` (Control) | `offset_top = 210`, `offset_bottom = 370` | `offset_top = 340`, `offset_bottom = 500` |

- `48` = fixed top inset (~status-bar height on the Pixel 9a). Hardcoded
  pixel, consistent with the rest of `main.tscn`; no `get_display_safe_area()`.
- Font stays 28pt. `Label` box is now 236px tall (64–300) for ~190px of
  text — comfortable.
- `MenuButton` bottom (410) clears `HudFrame` bottom (320) with a 20px gap;
  first banner top (424) clears `MenuButton` bottom (410); last banner
  (i=8, Use Ticket) bottom = 520 + 864 = 1384, well inside 2424.
- `ConfirmStrongholdButton` / `CancelStrongholdButton` share the
  `MenuButton` band — they never co-exist (`MenuButton` hides during
  stronghold placement).
- `SystemToast` moves fully below the taller HUD (x 660–1040 unchanged).

## Not in scope

- **`MapView.position` (`540, 1265`)** — picked to centre the player
  between the old top HUD and the removed bottom nav bar; the player marker
  now sits low. Re-centring to ~`(540, 1422)` is a separate tweak the user
  chose to defer.
- No `main.gd` change; no `core/`; no save-data change; no font/theme
  change. `_refresh_label()`'s 5-line format string is untouched.

## Verification

Manual/on-device only (`.tscn` layout, no logic): rebuild + reinstall,
screenshot the home screen — HUD sits clear of the top edge, all 5 lines
(incl. "Power: N") inside the frame, `☰ Menu` below the frame, open the
menu and confirm the banners start below the button. GUT suite unaffected
(532, no `.gd` touched).
