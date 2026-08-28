# App-wide UI theme + map palette — design spec

**Date:** 2026-08-28
**Status:** Approved by user, ready for implementation planning.

## Summary

The game is a styled cyan-glass *shell* (map HUD, fold-out nav menu,
popups) wrapped around unstyled *guts* — every panel's buttons and labels
use Godot's built-in default look (flat grey buttons, plain white text,
default font). There is **no `Theme` resource** in the project.

This spec creates one project-default `Theme` so every panel lifts at
once, bundles a display font, restyles the panel backgrounds, strips the
now-redundant per-node overrides, and — separately — lightens the map
palette, which is too dark to read on a phone in daylight.

Almost entirely visual: one new `.tres`, `project.godot` +
`main.tscn` edits, and 5 colour constants in `core/map_geometry.gd` (with
their test assertions). No gameplay/logic change.

## Part 1 — Theme resource, assignment, font

- **Create** `res://ui/theme/hollowhunter.tres` (`Theme`).
- **Assign as project default:** `project.godot` gains
  `[gui] theme/custom="res://ui/theme/hollowhunter.tres"`. Every `Control`
  engine-wide inherits it unless it carries its own `theme` /
  `theme_override_*`. (The `GameUI` panels are `Node2D`, so per-panel
  assignment is impossible — project-default is the only route.)
- **Font (added last, separately):** the theme ships **without** a
  `default_font` entry first — every stylebox / colour / size in Parts 2–4
  works with the engine default font. Then, as the final step: bundle
  **Chakra Petch** (SIL OFL, Google Fonts) at
  `res://ui/fonts/ChakraPetch-Regular.ttf` +
  `res://ui/fonts/ChakraPetch-SemiBold.ttf` (user supplies the files;
  fonts.google.com/specimen/Chakra+Petch), then add the one theme line
  `default_font = ExtResource(<SemiBold ttf>)`. Splitting it this way
  means a missing font file never blocks the rest of the pass, and the
  font swaps in with a one-line edit. Fallbacks if rejected: Rajdhani or
  Saira.
- **Colours** (theme-wide defaults):
  - `default_font_color` / `font_color` = cyan `Color(0.498, 0.941, 1.0)`
  - disabled / secondary = `Color(0.498, 0.941, 1.0, 0.4)`
  - `default_font_size` = `22`

## Part 2 — Control styles in the theme

### `Button` (standard — the dense-panel button)
`StyleBoxFlat`:
- `bg_color = Color(0.06, 0.10, 0.15, 0.95)`
- `border_width_* = 2`, `border_color = Color(0.498, 0.941, 1.0, 0.35)`
- `corner_radius_* = 6`
- `content_margin_*` ≈ 10 / 6 (h / v)
- `hover`: `bg_color = Color(0.09, 0.15, 0.22, 0.98)`, `border_color`
  alpha → `0.6`
- `pressed`: `bg_color = Color(0.04, 0.07, 0.11, 1.0)`, `border_color`
  alpha → `0.8`
- `disabled`: `bg_color = Color(0.05, 0.07, 0.09, 0.6)`, `border_color =
  Color(0.498, 0.941, 1.0, 0.12)`
- `focus`: same as `hover` (no separate focus ring)
- Button `font_color` = theme default cyan; `font_disabled_color` =
  `Color(0.498, 0.941, 1.0, 0.35)`

### `BannerButton` (`theme_type_variation` of `Button`)
- `normal` / `hover` / `pressed` / `focus` = **one** `StyleBoxTexture`
  → `res://art/ui/ui_system_frame.webp`, `texture_margin_* = 64`,
  `content_margin_*` ≈ 16 / 12 (matches the current nav-banner look).
- `font_size = 26`, cyan font.
- Consumers set `theme_type_variation = "BannerButton"`: the 9 nav
  banners, `MenuButton`, `ConfirmStrongholdButton`,
  `CancelStrongholdButton`, and any other "hero / primary CTA" button
  (the `SystemPanel` / `GateBreakPanel` / `ClaimNicknamePanel` action
  buttons — implementer's judgement, keep it to the prominent ones).

### `Panel` / `PanelContainer`
`StyleBoxFlat`: `bg_color = Color(0.03, 0.06, 0.10, 0.98)`,
`border_width_* = 1`, `border_color = Color(0.498, 0.941, 1.0, 0.20)`,
`corner_radius_* = 4`. (`MarkerCard` is a `Panel` and picks this up.)

### `Label`
- `font` = Chakra Petch SemiBold, `font_size = 22`, `font_color` = cyan.
- `font_outline_size = 1`, `font_outline_color = Color(0, 0, 0, 0.6)` —
  readability over the map / varied panel content.
- **`Title`** (`theme_type_variation` of `Label`): `font_size = 30`, no
  behavioural diff otherwise. Panel title labels set
  `theme_type_variation = "Title"`.

### `LineEdit`
- `normal` `StyleBoxFlat`: `bg_color = Color(0.04, 0.08, 0.12, 0.95)`,
  `border_width_* = 2`, `border_color = Color(0.498, 0.941, 1.0, 0.3)`,
  `corner_radius_* = 6`, `content_margin` ≈ 10 / 6.
- `focus`: `border_color` alpha → `0.7`.
- `font_color` = cyan; `caret_color` = cyan;
  `selection_color = Color(0.498, 0.941, 1.0, 0.25)`;
  `font_placeholder_color = Color(0.498, 0.941, 1.0, 0.35)`.

### `VScrollBar` / `HScrollBar`
- `grabber` / `grabber_highlight` / `grabber_pressed` `StyleBoxFlat`:
  `bg_color = Color(0.498, 0.941, 1.0, 0.25 / 0.4 / 0.55)`,
  `corner_radius_* = 4`.
- `scroll` (track): `bg_color = Color(1, 1, 1, 0.03)`.
- Affects the Army roster / Inventory / Shop / Leaderboard scroll lists.

Other classes (`CheckButton`, `OptionButton`, `Tree`, `ItemList`) — only
theme them if a panel actually uses one (grep first); the Army
"Grade: ALL" / "Sort: Power" controls are plain `Button`s.

## Part 3 — Panel background fills

Every `GameUI/*Panel/Bg` `ColorRect` (14 of them: HunterGear, ShadowGear,
Army, Army/SquadTab, Inventory, Shop, Leaderboard, Nadir, Stronghold,
Character, GateBreak, Battle, SystemPanel, ClaimNicknamePanel) gets one
consistent `color = Color(0.02, 0.05, 0.09, 0.99)` (near-opaque dark
blue-black, matching the popup bg). They stay `ColorRect`; no frame
chrome.

## Part 4 — Strip redundant per-node overrides (`scenes/main.tscn`)

Once the project theme covers `Button` / `Label` / `Panel` / `LineEdit`,
most shell styling is duplicated. Remove where the theme now does the job;
**keep** overrides that are genuinely intentional (a bigger title size, a
decorative frame texture).

- **Nav menu** (`GameUI/NavMenu`): `MenuButton` + the 9 `*Banner` buttons
  — delete every `theme_override_styles/*`, `theme_override_colors/*`,
  `theme_override_font_sizes/*`; add `theme_type_variation = "BannerButton"`.
  **Delete** the `[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_navbanner"]`
  (now lives in the theme).
- **HUD** (`GameUI/Label`): drop `theme_override_colors/font_color`
  (redundant — theme default is cyan); **keep**
  `theme_override_font_sizes/font_size = 28`. `HudFrame` is a decorative
  `NinePatchRect` — unchanged.
- **`MarkerCard`**: `TypeLabel` / `SubtitleLabel` — drop `font_color`,
  keep `font_size`. `ActionButton` — drop style/colour overrides; it's a
  themed `Button`.
- **`SystemPanel` / `SystemToast` / `GateBreakPanel` / `ClaimNicknamePanel`**:
  their labels — drop redundant `font_color`, keep `font_size` /
  `horizontal_alignment` / `autowrap_mode`. Their `Bg` / `Frame`
  `NinePatchRect`s are decorative frame art — **unchanged**. Their action
  buttons (`DismissButton`, `AcceptButton`, `SaveButton`, `SkipButton`,
  `CloseButton`) become themed `Button` or `BannerButton`.
- **`ConfirmStrongholdButton` / `CancelStrongholdButton`** — drop the
  cyan `font_*` + `StyleBoxTexture` overrides added in the HUD pass; set
  `theme_type_variation = "BannerButton"`.
- **Shadow Gear `RenameInput`** and every other `LineEdit` — remove any
  local styling; themed.

This task is done panel-by-panel with a device screenshot per panel
(before/after). Over-stripping (removing an intentional size) or
under-stripping (leaving a stale override that fights the theme) are the
failure modes.

## Part 5 — Lighten the map palette (`core/map_geometry.gd` + test)

The §19b near-black palette is unreadable on a phone outdoors — flagged
as a risk in the original spec. Bump the 5 colour constants so the street
grid reads while staying "quiet" (cyan still pops):

| Constant | Now (`#hex`) | Proposed |
|---|---|---|
| `BACKGROUND_COLOR` | `050b12` | `0c1420` |
| `road_color(CLASS_MAJOR_ROAD)` | `1b2532` | `3a4a5e` |
| `road_color(CLASS_MINOR_ROAD)` | `0f1620` | `26313f` |
| `road_color(CLASS_PATH)` | `0a0f16` | `1c2430` |
| `road_color(CLASS_WATER_LINE / _AREA)` | `02040a` | `070d16` |

`tests/unit/test_map_geometry.gd` asserts these exact values
(`test_background_color_is_locked`, `test_road_color_matches_class`) —
update those assertions to the new hex in the same commit. Values are a
starting point; fine-tune against a device screenshot.

Update the §19b palette table in `HollowHunter_Concept.md` to the new hex
(one-line edit) so the doc and code agree.

## Non-goals

- **No layout changes.** Offsets, sizes, node positions are untouched
  (except deleting the `StyleBoxTexture_navbanner` sub-resource).
- **No new panels, no functional change**, no `core/` change beyond the 5
  map colours.
- **No per-panel bespoke theming** — one theme, uniform. Bespoke panel
  looks are a later pass.
- **Battle screen stays text-based** — it inherits the theme (buttons,
  log label) but the text HP bars / combat log format are unchanged.
- **The Chakra Petch `.ttf` files** are a prerequisite the user supplies;
  the theme degrades gracefully without them.
- Known-issue carried forward, NOT fixed here: the Shadow Gear rename
  strip's `Save`/`Close` button overlap + un-hidden nav row.

## Testing

Visual / scene-layer → manual verification per `CLAUDE.md`.

- **GUT**: unchanged **except** `tests/unit/test_map_geometry.gd` — its 5
  colour assertions move to the new hex (Part 5). Net suite count
  unchanged (same test functions, new expected values).
- `gdformat` / `gdlint` clean on `core/map_geometry.gd`.
- The theme `.tres`, `project.godot`, and `main.tscn` edits are validated
  by a headless scene-load (no parse errors) + on-device screenshots.
- **Device pass**: screenshot every panel — Shadow Gear, Army
  (roster + squad), Inventory, Character, Shop, Leaderboard, Nadir,
  Stronghold, a battle, plus the map, the nav menu, and each popup —
  confirming consistent cyan-glass styling, the Chakra Petch font, legible
  scrollbars, and the lighter, readable map.
