# Home-screen fold-out nav menu — design spec

**Date:** 2026-08-28
**Status:** Approved by user, ready for implementation planning.

## Summary

Replace the home screen's bottom horizontal scrolling nav bar
(`GameUI/NavScroll` → `NavRow`, 9 buttons) with a **fold-out menu**: a
single `☰ Menu` button in the top-left just below the stats HUD, which
toggles a vertical stack of 9 full-width navigation **banners** over the
map. Banners and the menu button use the same cyan-glass nine-patch
styling (`art/ui/ui_system_frame.webp`, `ExtResource("15")`) as
`MarkerCard` / `SystemPanel` / the HUD frame.

Pure `scenes/` change — `main.tscn` layout + `main.gd` wiring. No `core/`
change, no new game rules, no new art. Every existing nav handler
(`_on_army_button_pressed`, `_on_use_ticket_pressed`, …) is reused
unchanged.

## Layout (`scenes/main.tscn`)

### Removed
`GameUI/NavScroll` (`ScrollContainer`) and its entire subtree —
`NavRow` (`HBoxContainer`) plus the 9 child `Button`s: `HunterGearButton`,
`ArmyButton`, `InventoryButton`, `NadirButton`, `StrongholdButton`,
`CharacterButton`, `UseTicketButton`, `ShopButton`, `LeaderboardButton`.

### Added: `GameUI/NavMenu` (`Node2D`)

Inserted **after `MapView`** in `GameUI`'s child order so its buttons win
overlapping input by tree order (Godot resolves input by tree order, not
`z_index` — the same rule that governs `SystemToast` / `ClaimNicknamePanel`
placement). It contains:

- **`MenuButton`** (`Button`) — always visible.
  `offset_left = 20, offset_top = 220, offset_right = 200, offset_bottom = 290`
  (just under `HudFrame`, which ends at y 210). `text = "☰ Menu"`,
  `theme_override_font_sizes/font_size = 24`. Cyan-glass style (below).
- **`BannerList`** (`Node2D`) — `visible = false` by default. Holds 9
  `Button` children, full-width, stacked from y 300 downward:
  - each: `offset_left = 20, offset_right = 1060`; height 96 with a 12px
    gap → banner *i* (0-indexed) is `offset_top = 300 + i*108`,
    `offset_bottom = 396 + i*108`. Banner 8 (Use Ticket) ends at y 1260 —
    clear of the map centre and well above the old nav position.
  - `theme_override_font_sizes/font_size = 26`.
  - Cyan-glass style (below).

Banner nodes, **in this order** (this is the "sort"):

| # | node name | text | existing handler |
|---|---|---|---|
| 1 | `ArmyBanner` | `Army` | `army_button`'s handler (inline lambda in `_setup_gear_panels`) |
| 2 | `HunterGearBanner` | `Hunter Gear` | `_on_hunter_gear_button_pressed` |
| 3 | `InventoryBanner` | `Inventory` | `inventory_button`'s handler |
| 4 | `StrongholdBanner` | `Stronghold` | `stronghold_button`'s handler |
| 5 | `CharacterBanner` | `Character` | `_on_character_button_pressed` |
| 6 | `NadirBanner` | `The Nadir` | `_on_nadir_button_pressed` |
| 7 | `ShopBanner` | `Shop` | `_on_shop_button_pressed` |
| 8 | `LeaderboardBanner` | `Leaderboard` | `leaderboard_button`'s handler |
| 9 | `UseTicketBanner` | `Use Ticket` | `_on_use_ticket_pressed` |

### Cyan-glass style

One `[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_navbanner"]`
in `main.tscn`:
- `texture = ExtResource("15")` (`res://art/ui/ui_system_frame.webp`)
- `texture_margin_left/top/right/bottom = 64.0`

`MenuButton` and all 9 banners set:
- `theme_override_styles/normal`, `theme_override_styles/hover`,
  `theme_override_styles/pressed`, `theme_override_styles/focus` → all the
  same `SubResource("StyleBoxTexture_navbanner")` (one shared box, so no
  pressed/hover color flash — matches the static popups).
- `theme_override_colors/font_color`,
  `theme_override_colors/font_hover_color`,
  `theme_override_colors/font_pressed_color`,
  `theme_override_colors/font_focus_color` →
  `Color(0.498, 0.941, 1.0, 1.0)` (the cyan used by `MarkerCard`
  `TypeLabel`, `SystemPanel` labels, gate markers).

## Wiring (`scenes/main.gd`)

### `@onready` refs
The 9 existing button refs (currently `$GameUI/NavScroll/NavRow/*`, lines
~69–90) repoint to `$GameUI/NavMenu/BannerList/<NewName>Banner`. Names in
code stay (`army_button`, `use_ticket_button`, …) — only the node paths
change. Add:
- `@onready var menu_button: Button = $GameUI/NavMenu/MenuButton`
- `@onready var banner_list: Node2D = $GameUI/NavMenu/BannerList`

### `_setup_gear_panels()` — inside the existing `if not …is_connected(…)` guard
- Add `menu_button.pressed.connect(_on_menu_button_pressed)`.
- The 9 banner `.pressed.connect(...)` lines stay exactly as they are
  (same target handlers) — only the node they resolve from moved. Each
  banner also needs to **close the menu on press**. Rather than editing 9
  connect sites, wrap: keep the existing `<button>.pressed.connect(<handler>)`
  and add one more `<button>.pressed.connect(_close_nav_menu)` per banner,
  or connect every banner to a single `_on_banner_pressed(callable)` —
  implementer's call; the plan will pick one. Net effect: pressing a
  banner runs its handler AND sets `banner_list.visible = false`.

### New functions
```gdscript
func _on_menu_button_pressed() -> void:
	banner_list.visible = not banner_list.visible


func _close_nav_menu() -> void:
	banner_list.visible = false
```

### Map-tap closes the menu
`_on_map_tapped_empty()` and `_on_marker_tapped()` already call
`_hide_marker_card()`; add `_close_nav_menu()` alongside in both. A tap on
a banner is consumed by the `Button`, so the map never receives it — no
conflict.

### Stronghold placement mode
`MenuButton` (y 220–290) overlaps `ConfirmStrongholdButton` /
`CancelStrongholdButton` (y 210–270, shown only during placement).
- `_on_place_stronghold_pressed()` — add `menu_button.visible = false`
  and `_close_nav_menu()`.
- `_on_confirm_stronghold_pressed()` and `_on_cancel_stronghold_pressed()`
  — add `menu_button.visible = true`.

## Non-goals

- **No open/close animation** — instant `visible` toggle for v0. A
  slide/unfold is later polish (§24 placeholder-first).
- **No new nav destinations** — same 9, reordered. No "More" submenu, no
  grouping headers.
- **No banner art** — the `ui_system_frame` nine-patch is the styling; no
  per-destination icons.
- **No change to any destination screen** or its handler.
- **No `core/` change; no save-data change.**
- Bottom-of-screen space freed by removing `NavScroll` is left empty (the
  map extends into it visually already).

## Testing

Entirely scene-layer (`main.tscn` layout + `main.gd` wiring, no game
rules) → manual verification per `CLAUDE.md`. The GUT suite (**532**) must
stay unchanged — no `core/` or test file is touched.

Manual checklist:
- `☰ Menu` sits top-left below the HUD; tapping it unfolds the 9 banners
  over the map; tapping it again folds them away.
- Each banner opens the correct screen (Army → army panel, etc.) **and**
  closes the menu.
- `Use Ticket` banner fires the ticket-gate preview card (from §6c/§18
  work) and closes the menu.
- Tapping the map (empty or a marker) with the menu open closes it;
  tapping a banner does not fall through to the map.
- Enter stronghold placement → `MenuButton` disappears and any open menu
  closes; Confirm or Cancel → `MenuButton` returns.
- Banners and the menu button render in the cyan-glass nine-patch style,
  visually consistent with `MarkerCard` / `SystemPanel`.
- Full GUT suite still 532, green.
- On-device screenshot of the open menu over the real map → `devmedia/`.
