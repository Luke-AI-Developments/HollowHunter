# Home-Screen Fold-Out Nav Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home screen's bottom horizontal scrolling nav bar with a top-left `☰ Menu` button that unfolds a vertical stack of 9 full-width cyan-glass navigation banners over the map.

**Architecture:** Pure `scenes/` change — `main.tscn` layout + `main.gd` wiring. Remove `GameUI/NavScroll` and its 9 buttons; add `GameUI/NavMenu` (`MenuButton` + `BannerList` of 9 banner `Button`s) after `MapView`. Repoint the 9 existing `@onready` button refs to the new banner nodes; every nav handler is reused unchanged. Banners + button share one `StyleBoxTexture` sub-resource pointing at `art/ui/ui_system_frame.webp` for the popup cyan-glass look.

**Tech Stack:** Godot 4.7 / GDScript. No `core/` change, no new tests — scene code. `gdformat` + `gdlint` + full GUT run via the post-edit hook on every `.gd` save.

## Global Constraints

- Static typing everywhere; tabs; `snake_case` vars/functions, `PascalCase` nodes. One class per file. Per `CLAUDE.md`.
- `scenes/` is thin view code with **no game rules and no GUT coverage** — verified manually. Per `CLAUDE.md`.
- The post-edit hook reformats + lints every saved `.gd` and runs the whole GUT suite; a red hook is a blocker. Don't hand-fix whitespace the formatter reflows.
- **GUT suite count must stay at 532** — no `core/` or test file is touched by this plan.
- Viewport is a fixed `1080 x 2424` (`project.godot`); hardcoded-pixel `.tscn` layout is the house style.
- Cyan for interactive elements is `Color(0.498, 0.941, 1.0, 1.0)` (used by `MarkerCard` `TypeLabel`, `SystemPanel` labels, gate markers).
- `ExtResource("15")` in `main.tscn` is `res://art/ui/ui_system_frame.webp` (already declared; also used by `HudFrame`).
- Commit messages end with the `Co-Authored-By:` and `Claude-Session:` trailers, matching existing history.
- Manual GUT run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: Replace the nav bar with the fold-out menu

**Files:**
- Modify: `scenes/main.tscn` — remove the `GameUI/NavScroll` subtree; add a `StyleBoxTexture` sub-resource and the `GameUI/NavMenu` subtree.
- Modify: `scenes/main.gd` — repoint 9 `@onready` refs (~lines 69–90); add 2 refs; add 2 functions; add connects in `_setup_gear_panels()` (~lines 271–325).

**Interfaces:**
- Consumes: existing nav handlers — `_on_hunter_gear_button_pressed`, `_on_nadir_button_pressed`, `_on_character_button_pressed`, `_on_use_ticket_pressed`, `_on_shop_button_pressed` (named), and the 4 inline lambdas currently connected to `army_button` / `inventory_button` / `stronghold_button` / `leaderboard_button` `.pressed` (each calls `_hide_marker_card()` then `<view>.open()`).
- Produces: `menu_button: Button`, `banner_list: Node2D`, `_on_menu_button_pressed()`, `_close_nav_menu()` — Task 2 consumes `_close_nav_menu()` and `menu_button`.

- [ ] **Step 1: Remove the old nav bar from `scenes/main.tscn`**

Delete the entire `GameUI/NavScroll` block — the `[node name="NavScroll" ...]`, `[node name="NavRow" ...]`, and all 9 `[node name="*Button" type="Button" parent="GameUI/NavScroll/NavRow"]` blocks (`HunterGearButton`, `ArmyButton`, `InventoryButton`, `NadirButton`, `StrongholdButton`, `CharacterButton`, `UseTicketButton`, `ShopButton`, `LeaderboardButton`). Currently contiguous, ~`main.tscn:192–250`, ending right before `[node name="HunterGearPanel" type="Node2D" parent="GameUI"]`.

- [ ] **Step 2: Add the shared style sub-resource**

In `scenes/main.tscn`, add this to the `[sub_resource]` section (near the top, after the existing sub-resources / before the node tree — match where other `[sub_resource]` blocks sit; if there are none, put it immediately after the last `[ext_resource]` line):

```
[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_navbanner"]
texture = ExtResource("15")
texture_margin_left = 64.0
texture_margin_top = 64.0
texture_margin_right = 64.0
texture_margin_bottom = 64.0
```

- [ ] **Step 3: Add the `NavMenu` subtree**

Insert immediately **after** the `[node name="MapView" ...]` block and its `script =` line (so `NavMenu` is a later `GameUI` sibling than `MapView` → its buttons win overlapping input by tree order), and before `[node name="MarkerCard" ...]`.

`MenuButton` (full):

```
[node name="NavMenu" type="Node2D" parent="GameUI"]

[node name="MenuButton" type="Button" parent="GameUI/NavMenu"]
offset_left = 20.0
offset_top = 220.0
offset_right = 200.0
offset_bottom = 290.0
theme_override_colors/font_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_hover_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_pressed_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_focus_color = Color(0.498, 0.941, 1.0, 1)
theme_override_font_sizes/font_size = 24
theme_override_styles/normal = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/hover = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/pressed = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/focus = SubResource("StyleBoxTexture_navbanner")
text = "☰ Menu"

[node name="BannerList" type="Node2D" parent="GameUI/NavMenu"]
visible = false
```

`ArmyBanner` (full — the template for the other 8):

```
[node name="ArmyBanner" type="Button" parent="GameUI/NavMenu/BannerList"]
offset_left = 20.0
offset_top = 300.0
offset_right = 1060.0
offset_bottom = 396.0
theme_override_colors/font_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_hover_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_pressed_color = Color(0.498, 0.941, 1.0, 1)
theme_override_colors/font_focus_color = Color(0.498, 0.941, 1.0, 1)
theme_override_font_sizes/font_size = 26
theme_override_styles/normal = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/hover = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/pressed = SubResource("StyleBoxTexture_navbanner")
theme_override_styles/focus = SubResource("StyleBoxTexture_navbanner")
text = "Army"
```

The other 8 banners are **identical to `ArmyBanner`** (same 4 font-color overrides, `font_size = 26`, same 4 style overrides) except for `name`, `text`, `offset_top`, `offset_bottom`:

| node name | text | offset_top | offset_bottom |
|---|---|---|---|
| `HunterGearBanner` | `Hunter Gear` | 408.0 | 504.0 |
| `InventoryBanner` | `Inventory` | 516.0 | 612.0 |
| `StrongholdBanner` | `Stronghold` | 624.0 | 720.0 |
| `CharacterBanner` | `Character` | 732.0 | 828.0 |
| `NadirBanner` | `The Nadir` | 840.0 | 936.0 |
| `ShopBanner` | `Shop` | 948.0 | 1044.0 |
| `LeaderboardBanner` | `Leaderboard` | 1056.0 | 1152.0 |
| `UseTicketBanner` | `Use Ticket` | 1164.0 | 1260.0 |

All 9 use `offset_left = 20.0`, `offset_right = 1060.0`, `parent="GameUI/NavMenu/BannerList"`.

- [ ] **Step 4: Repoint the `@onready` refs in `scenes/main.gd`**

Change these 9 lines (currently ~`:69–90`; match on the `var` name, not the line number) from `$GameUI/NavScroll/NavRow/<X>Button` to the new banner path. Keep the `var` names unchanged — only the `$` path moves:

```gdscript
@onready var inventory_button: Button = $GameUI/NavMenu/BannerList/InventoryBanner
@onready var hunter_gear_button: Button = $GameUI/NavMenu/BannerList/HunterGearBanner
@onready var army_button: Button = $GameUI/NavMenu/BannerList/ArmyBanner
@onready var nadir_button: Button = $GameUI/NavMenu/BannerList/NadirBanner
@onready var stronghold_button: Button = $GameUI/NavMenu/BannerList/StrongholdBanner
@onready var character_button: Button = $GameUI/NavMenu/BannerList/CharacterBanner
@onready var use_ticket_button: Button = $GameUI/NavMenu/BannerList/UseTicketBanner
@onready var shop_button: Button = $GameUI/NavMenu/BannerList/ShopBanner
@onready var leaderboard_button: Button = $GameUI/NavMenu/BannerList/LeaderboardBanner
```

Add two refs alongside them:

```gdscript
@onready var menu_button: Button = $GameUI/NavMenu/MenuButton
@onready var banner_list: Node2D = $GameUI/NavMenu/BannerList
```

- [ ] **Step 5: Add the toggle + close functions in `scenes/main.gd`**

Add near the other small `_on_*` UI handlers (e.g. just before `_on_place_stronghold_pressed()`):

```gdscript
func _on_menu_button_pressed() -> void:
	banner_list.visible = not banner_list.visible


func _close_nav_menu() -> void:
	banner_list.visible = false
```

- [ ] **Step 6: Wire the connects in `_setup_gear_panels()`**

Inside the existing `if not hunter_gear_button.pressed.is_connected(_on_hunter_gear_button_pressed):` guarded block, add the menu-button connect (put it right after the `hunter_gear_button.pressed.connect(_on_hunter_gear_button_pressed)` line):

```gdscript
		menu_button.pressed.connect(_on_menu_button_pressed)
```

Then add a `_close_nav_menu` connect for **each** of the 9 nav buttons, immediately after that button's existing `.pressed.connect(...)`. The existing connect (named handler or inline lambda) is unchanged; this is a *second* connection, and Godot fires connections in connection order, so the navigation handler runs first, then the menu closes. Example for the two shapes:

```gdscript
		# after the existing: army_button.pressed.connect(func() -> void: ...)
		army_button.pressed.connect(_close_nav_menu)
		...
		# after the existing: nadir_button.pressed.connect(_on_nadir_button_pressed)
		nadir_button.pressed.connect(_close_nav_menu)
```

Do this for all 9: `hunter_gear_button`, `army_button`, `inventory_button`, `nadir_button`, `stronghold_button`, `character_button`, `use_ticket_button`, `shop_button`, `leaderboard_button`.

- [ ] **Step 7: Let the post-edit hook run; confirm green**

Saving `scenes/main.gd` triggers `gdformat` + `gdlint` + the full GUT suite. Expected: format/lint clean, GUT **532/532** (no `core/`/test touched). A `.tscn` save doesn't trigger the hook — after editing it, do a manual GUT run and confirm 532. Red = fix before commit.

- [ ] **Step 8: Manual verification**

Run the project (Godot editor F5 / `run` skill), get past onboarding to the map:
- `☰ Menu` button sits top-left just under the HUD frame, cyan-glass styled.
- Tap it → 9 banners unfold down the screen over the map, cyan-glass styled, in order Army → Hunter Gear → Inventory → Stronghold → Character → The Nadir → Shop → Leaderboard → Use Ticket.
- Tap `☰ Menu` again → banners fold away.
- Tap each banner in turn → the matching screen opens (Army → army panel, etc.; `Use Ticket` → the ticket-gate preview card) **and** the banner list is hidden when you return/close.
- No visible remnant of the old bottom nav bar; the bottom strip is just map now.

- [ ] **Step 9: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "feat: fold-out home nav menu replaces the bottom scroll bar

☰ Menu button top-left unfolds 9 full-width cyan-glass banners over the
map (ui_system_frame nine-patch, cyan font, matching the popups). The 9
@onready button refs repoint from NavScroll/NavRow to NavMenu/BannerList;
every nav handler is reused. Each banner also connects _close_nav_menu so
picking one navigates and folds the menu away. Nav order re-sorted:
management screens first, Use Ticket last.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 2: Menu dismissal edge cases

**Files:**
- Modify: `scenes/main.gd` — `_on_map_tapped_empty()`, `_on_marker_tapped()`, `_on_place_stronghold_pressed()`, `_on_confirm_stronghold_pressed()`, `_on_cancel_stronghold_pressed()`.

**Interfaces:**
- Consumes: `_close_nav_menu()`, `menu_button` (Task 1).
- Produces: nothing for later tasks.

`scenes/`-only: no GUT test, manual verification, GUT count unchanged at 532.

- [ ] **Step 1: Close the menu on a map tap**

`_on_map_tapped_empty()` currently is just `_hide_marker_card()`. Add `_close_nav_menu()`:

```gdscript
func _on_map_tapped_empty() -> void:
	_hide_marker_card()
	_close_nav_menu()
```

`_on_marker_tapped(info: Dictionary)` currently opens with `match info["type"]:` (no top-level `_hide_marker_card()` — the sanctuary/lorestone branches deliberately keep a card open). Add `_close_nav_menu()` as the **first** statement so any marker tap folds the menu:

```gdscript
func _on_marker_tapped(info: Dictionary) -> void:
	_close_nav_menu()
	match info["type"]:
		"gate":
			_show_gate_card(info["index"], info["screen_pos"])
		# ...rest unchanged
```

(A tap that lands on a banner is consumed by the banner `Button`, so `MapView` never emits for it — no conflict.)

- [ ] **Step 2: Hide the menu button during stronghold placement**

`_on_place_stronghold_pressed()` currently:

```gdscript
func _on_place_stronghold_pressed() -> void:
	stronghold_view.visible = false
	map_view.begin_stronghold_placement()
	confirm_stronghold_button.visible = true
	cancel_stronghold_button.visible = true
```

Add two lines (the `MenuButton` at y 220–290 overlaps `ConfirmStrongholdButton` at y 210–270):

```gdscript
func _on_place_stronghold_pressed() -> void:
	stronghold_view.visible = false
	map_view.begin_stronghold_placement()
	confirm_stronghold_button.visible = true
	cancel_stronghold_button.visible = true
	menu_button.visible = false
	_close_nav_menu()
```

- [ ] **Step 3: Restore the menu button after placement ends**

In **both** `_on_confirm_stronghold_pressed()` and `_on_cancel_stronghold_pressed()`, add `menu_button.visible = true` next to where they set `confirm_stronghold_button.visible = false` / `cancel_stronghold_button.visible = false`:

```gdscript
	map_view.end_stronghold_placement()
	confirm_stronghold_button.visible = false
	cancel_stronghold_button.visible = false
	menu_button.visible = true
```

(Applies to both handlers; `_on_confirm_stronghold_pressed()` also has the `place_stronghold()` block above this — leave that untouched.)

- [ ] **Step 4: Let the post-edit hook run; confirm green**

Format/lint clean; GUT **532/532** unchanged.

- [ ] **Step 5: Manual verification**

Run the project:
- Open the menu, then tap the map (empty spot) → menu folds away.
- Open the menu, then tap a gate / sanctuary / lorestone / stronghold marker → menu folds away; the marker's own card/behaviour is unaffected.
- Tap a banner → it does NOT also register as a map tap (no double action).
- Open the Stronghold screen → tap **Place / Move Stronghold** → the `☰ Menu` button disappears (and any open menu closes); the Confirm / Cancel buttons show without overlap.
- Tap **Confirm** (with a pending position) → stronghold placed, `☰ Menu` button returns.
- Repeat, tap **Cancel** → `☰ Menu` button returns, no placement.

- [ ] **Step 6: On-device capture**

Build + install on the device (same pipeline as prior scene work). Screenshot the open fold-out menu over the real Darlington map and save to `devmedia/2026-08-28/` with a one-line `CAPTURE_LOG.md` entry.

- [ ] **Step 7: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: fold-out nav menu closes on map tap; hides during stronghold placement

Any map / marker tap folds the menu (banners consume their own taps, so
no double-action). MenuButton (y220-290) overlaps the stronghold
Confirm/Cancel buttons, so it hides on Place/Move and returns on
Confirm/Cancel.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

## Post-plan checklist (controller, after all tasks)

- [ ] Full GUT suite green, **still 532** — no `core/` or test file touched anywhere.
- [ ] `gdformat` / `gdlint` clean on `scenes/main.gd`.
- [ ] Manual run-through of both tasks in one session: menu toggles; all 9 banners navigate + close; `Use Ticket` fires its card; map/marker tap folds the menu; banner taps don't double-fire; menu button hides/returns around stronghold placement; cyan-glass styling matches the popups.
- [ ] `devmedia/` screenshot of the open menu over the real map, logged.
- [ ] No stray reference to `NavScroll` / `NavRow` / `*Button` old paths anywhere in `scenes/` (grep).
- [ ] Non-goals hold: no open/close animation; same 9 destinations; no banner icons; no destination-screen changes; no `core/`/save change.

## Self-Review

**Spec coverage:**
- "Remove `NavScroll` + `NavRow` + 9 buttons" → Task 1 Step 1.
- "Add `NavMenu` after `MapView`; `MenuButton` at y 220; `BannerList` visible=false; 9 full-width banners stacked from y 300, 96h + 12 gap" → Task 1 Step 3 (exact offsets in the table; banner *i* = `300 + i*108` .. `396 + i*108`).
- "One `StyleBoxTexture` sub-resource → `ExtResource(15)`, 64 margins; all styles point to it; cyan font colors" → Task 1 Step 2 + Step 3.
- "9 `@onready` refs repoint, names unchanged; add `menu_button` + `banner_list`" → Task 1 Step 4.
- "`_on_menu_button_pressed` toggle; `_close_nav_menu`" → Task 1 Step 5.
- "menu-button connect + banner-close-on-press, inside the idempotency guard" → Task 1 Step 6 (chose: a *second* `.pressed.connect(_close_nav_menu)` per banner, leaving the 9 existing connects — named + lambda — untouched; fires after the nav handler).
- "map-tap closes the menu" → Task 2 Step 1 (`_on_map_tapped_empty` + top of `_on_marker_tapped`).
- "stronghold placement hides `MenuButton`, confirm/cancel restore it" → Task 2 Steps 2–3.
- "banner order: Army, Hunter Gear, Inventory, Stronghold, Character, The Nadir, Shop, Leaderboard, Use Ticket" → Task 1 Step 3 table, top-to-bottom.
- Testing "scene-layer, manual, GUT stays 532" → every task's hook step asserts 532; no task writes a test.

**Placeholder scan:** no TBD/TODO. The 8 non-template banners are given as an exact (name, text, offset) table with "identical to `ArmyBanner` except these" — not a vague "similar to". Every code step has literal code. Manual steps list concrete taps + expected results.

**Type consistency:**
- `menu_button: Button`, `banner_list: Node2D` — declared Task 1 Step 4, used in Task 1 Steps 5–6 and Task 2 Steps 2–3. `banner_list.visible` (Node2D has `visible`). Consistent.
- The 9 repointed refs keep their exact existing `var` names (`army_button`, `use_ticket_button`, …) and `: Button` type — only the node path string changes, so every downstream use (the `is_connected` guard on `hunter_gear_button`, all `.pressed.connect` sites) is unaffected.
- `_close_nav_menu()` / `_on_menu_button_pressed()` — defined Task 1 Step 5, referenced Task 1 Step 6 and Task 2 Steps 1–2. Consistent.
- `StyleBoxTexture_navbanner` — sub-resource id defined Task 1 Step 2, referenced by every node in Step 3. Consistent.
