# Portrait-mode relayout — design spec

**Date:** 2026-08-21
**Status:** Approved by user, ready for implementation planning.

## Summary

Switches HollowHunter from landscape to portrait orientation. This is not a
settings flip: the project currently has **no `[display]` section in
`project.godot` at all** (no viewport size, no stretch mode, no orientation
— it runs in landscape purely because that's the engine default), and every
one of the game's 14 screens is laid out with hardcoded absolute pixel
offsets sized for a ~2424×1080 landscape canvas, with zero use of anchors or
layout containers anywhere in the project. Switching to portrait means: (1)
adding the engine config this project has never had, and (2) redoing every
screen's coordinates — and in several cases their actual arrangement, since
wide horizontal rows of content don't fit a canvas roughly 2.2× narrower —
against a new portrait reference canvas.

Decided via the visual brainstorming companion (mockups + user selections),
recorded below.

## Canvas & engine config

- New reference canvas: **1080×2424** (the current 2424×1080 canvas turned
  90°, same aspect ratio).
- `project.godot` gains a `[display]` section (currently absent entirely):
  ```ini
  [display]

  window/size/viewport_width=1080
  window/size/viewport_height=2424
  window/stretch/mode="canvas_items"
  window/stretch/aspect="keep"
  window/handheld/orientation="portrait"
  ```
- `stretch/mode="canvas_items"` + `aspect="keep"` scales the 1080×2424
  reference canvas uniformly to fit any real device screen, letterboxing
  (thin bars) only on devices whose aspect ratio differs meaningfully from
  1080:2424. This is also the first time this project gets *any*
  device-independent scaling — today, in landscape, the root viewport just
  becomes whatever the device's native resolution is, and the hardcoded
  2424×1080 coordinates only actually fill the screen on a device that
  happens to match that exact resolution.
- `export_presets.cfg` needs no change — Android orientation is driven
  entirely by the `window/handheld/orientation` project setting, not a
  per-preset export option (confirmed: the existing `[preset.0.options]`
  block has no orientation key today).

## Layout conversion rules

Established via the visual companion (mockups + user's selections) for the
handful of screens with genuine structural conflicts, then applied by the
same logic to the rest of the game:

1. **List-like item rows → vertical stacks**, not grids. Each item carries
   real per-item information (name, HP bar, status), so a single column of
   full-width rows reads better than a cramped multi-column grid. Applies
   to:
   - Battle screen: `EnemySlot1-4` (today one row of 4) → stacked column of
     4.
   - Battle screen: `PartySlot1-4` (today one row of 4) → stacked column of
     4.
   - Battle screen: `ActionButton1-5` (today one row of 5 move buttons) →
     stacked column of up to 5.
2. **Pure visual/browsing grids stay grids.** The onboarding preset picker
   (12 portraits) keeps its existing 6-column arrangement — it's browsing
   by look, not reading per-item text, so a grid is the right shape; only
   the cell geometry is re-measured for the new canvas width.
3. **Info + visual side-by-side splits → stack, visual on top.** The
   Hunter/character screen's portrait (today next to the stats/fitness
   text) moves above it — matches §21's "avatar showcase" framing, and a
   tall canvas gives the portrait real presence instead of a cramped
   sliver.
4. **Home screen: map fills most of the screen, nav becomes a bottom
   strip.** Today the map sits in a fixed position on the right half of a
   wide canvas with 9 nav buttons in a row on the left. In portrait, the
   map (the core "there's a real gate near you" hook) fills roughly the
   top 70% of the screen; the 9 nav buttons (`HunterGearButton`,
   `ArmyButton`, `InventoryButton`, `NadirButton`, `StrongholdButton`,
   `CharacterButton`, `UseTicketButton`, `ShopButton`,
   `LeaderboardButton`) become a compact, horizontally-scrollable strip
   along the bottom rather than an inline row (which would no longer fit).
5. **Wide multi-button toolbars → wrap into 2-3 shorter rows**, each kept
   under ~1000px (1080 canvas width minus ~40px margin each side).
   Mechanical, not a design judgment call — exact wrap points are worked
   out per-screen when writing the implementation plan, not in this spec.
   Applies to:
   - `ShadowGearPanel`'s action-button row (9 buttons: Prev, Next,
     Auto-Equip, Close, Level Up, Fuse, Convert, Lock, Favorite).
   - `InventoryPanel`'s `FilterBar` (6 buttons: Class, Slot, Rarity, Set,
     Equipped, Sort) and `BulkBar` (4 buttons: Multi-Select toggle, Scrap
     Selected, Scrap Below Rarity, Scrap Duplicates).
   - `StrongholdPanel`'s three facility rows (Reliquary, Training Yard,
     Gate Watch), each currently a label + Assign/Unassign/Upgrade in one
     line — label moves to its own line, the 3 buttons wrap below it.
6. **Everything else just gets re-measured, no structural change** — it
   already fits comfortably under ~1000px content width in the landscape
   design: `SubclassPicker` (5 stacked class buttons, already a single
   narrow column), `PresetPicker`'s title/frame (grid handled by rule 2),
   `HunterGearPanel` (2 buttons), `ArmyPanel`'s tab bar and both tabs'
   toolbars (2-3 buttons each — only the roster row width and the
   `SectionsScroll`/grid containers need their width reduced to fit),
   `InventoryPanel`'s tab bar and `DetailPanel`/`ConfirmScrapPanel` (their
   button rows are 2-3 buttons, already narrow — only text label widths
   need reducing to fit under 1080), `ShopPanel`, `LeaderboardPanel`
   (including its account-link row — email + password + button already
   totals exactly 1080px in the landscape design, which has zero margin
   for error at the new canvas width, so this row gets stacked instead of
   kept in one line as a safety margin, not because it structurally
   conflicts), `NadirPanel`, `GateBreakPanel`, `BattlePanel`'s
   `TitleLabel`/`TurnOrderLabel`/`LogLabel`/`WaitingLabel`/`AutoButton`/
   `SkipButton` (text elements and 2 buttons, no row-width conflict once
   the 4+4+5 item rows above are handled).

## Scope

- Pure `scenes/`-layer changes (`.tscn` node coordinates) plus one
  `project.godot` edit. No `core/` changes — this is entirely visual
  layout, not game logic.
- No `content/*.json` changes.
- No art asset changes — `art/hero/`/`art/promo/` images aren't wired into
  any scene today (confirmed via search), so no orientation-dependent art
  conflict exists to resolve.
- All 14 screens are in scope and ship together: `PresetPicker`,
  `SubclassPicker`, the base `GameUI` home/map view, `HunterGearPanel`,
  `ShadowGearPanel`, `ArmyPanel`, `InventoryPanel`, `ShopPanel`,
  `LeaderboardPanel`, `NadirPanel`, `StrongholdPanel`, `CharacterPanel`,
  `GateBreakPanel`, `BattlePanel`. A half-landscape/half-portrait game
  would be worse than not starting this at all, so nothing merges until
  the whole pass is done.

## Testing scope

Per this project's `core`/`scenes` split: `scenes/` code is manually
verified, not GUT-tested, and this entire change lives in `scenes/` +
`project.godot`. No GUT test file is affected or added by this plan (the
full existing suite must still pass unchanged, since nothing in `core/`
is touched — that's the regression check).

Given a materially identical class of bug (missing `Button.expand_icon`)
slipped past five task-scoped static reviews on the preceding
character-select-preset-system work and was only caught by the final
whole-branch review, and this project now has a *proven, working*
on-device deploy pipeline (Godot CLI export + `adb install` + `adb shell
monkey` launch, exercised successfully this session) — the implementation
plan should end with an actual build-and-install-for-review step, not
rely on static diff review alone for a change this purely visual.

## Out of scope for this pass

- No rearchitecting to anchors/containers — this pass keeps the project's
  existing hardcoded-absolute-offset convention, just re-measured for the
  new canvas (a deliberate choice made during design: see the design
  conversation for the anchors-vs-recoordinate tradeoff).
- No landscape/portrait dual support (e.g. `window/handheld/orientation
  ="sensor"` with two coordinate sets per screen) — portrait-only, per the
  request.
- No changes to `export_presets.cfg` — confirmed unnecessary (orientation
  is a project setting, not a per-preset export option).
