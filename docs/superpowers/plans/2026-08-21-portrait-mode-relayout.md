# Portrait-mode relayout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch HollowHunter from landscape to portrait, adding the engine
config this project has never had and redoing every one of its 14 screens'
coordinates (and in several cases their arrangement) against a new
1080×2424 portrait reference canvas.

**Architecture:** Pure `scenes/`-layer (`.tscn` node coordinates + the
handful of `scenes/*.gd` files that build rows/buttons dynamically in code)
plus one `project.godot` engine-config edit. No `core/` change anywhere in
this plan — nothing here is game logic, so nothing here gets a GUT test;
every task is manually verified, same convention as the rest of this
project's `scenes/` work.

**Tech Stack:** Godot 4.7.1 (mono), GDScript.

## Global Constraints

**Canvas:**
- New reference canvas: **1080 wide × 2424 tall** (`CANVAS_W=1080`,
  `CANVAS_H=2424`).
- Standard side margin: **40px** each side (`MARGIN=40`) — matches this
  project's existing convention (every landscape screen already starts
  its leftmost content at `x=40`).
- Usable content width: **1000px** (`CONTENT_W = CANVAS_W - 2*MARGIN`).
  Every row of elements on every screen must fit inside
  `x=40` to `x=1040`. This is the single hard constraint every task must
  satisfy — if a row of elements doesn't fit inside 1000px, it must wrap
  to more than one line, not overflow.
- **Vertical space is abundant, not scarce.** The canvas is 2424 tall vs
  1080 wide — more than double the landscape canvas's height. When a
  screen needs more room, add another row *downward*; do not shrink text
  or buttons to cram things into fewer rows. None of the tasks in this
  plan need to worry about running out of vertical space — every one of
  them has been checked against `CANVAS_H=2424` and fits with margin to
  spare.
- Every screen's background `ColorRect` (`Bg` or `*Bg` node, wherever one
  exists) gets `offset_right` changed from `2424.0` to `1080.0` and
  `offset_bottom` changed from `1080.0` to `2424.0`. This one-line change
  is not repeated in every task's step list below — do it as the first
  edit of every task that has a `Bg`/`*Bg` node, alongside that task's
  other changes, in the same commit.

**Engine:**
- `project.godot` gains a `[display]` section (task 1) — every other task
  in this plan assumes that section already exists but does not depend on
  it at the `.tscn`/`.gd` level (Godot's editor doesn't require the
  project's declared viewport size to match what you type into a `.tscn`
  file — the two are independent), so tasks 2-12 do not need to wait for
  task 1 to be reviewed before starting, but task 1 must still be done
  first in execution order since it's this plan's foundation and its own
  review is trivial.

**Style:**
- Static typing everywhere in any `.gd` changes. Tabs for indentation.
  `snake_case` for vars/functions, `PascalCase` for node names.
- `gdformat`/`gdlint` run automatically via the post-edit hook on `.gd`
  files — don't hand-format around it. `.tscn` files are not touched by
  the hook; match the existing serialization style exactly (see any
  unedited node in the same file for the pattern: floats as `40.0`, no
  trailing zeros beyond one decimal place).
- No `content/*.json` changes anywhere in this plan.

**Testing:**
- No GUT test is added or should be affected by any task in this plan.
  Every task's verification is: (a) run the full GUT suite and confirm
  the pass count is *exactly* unchanged from before the task (proves no
  parse error was introduced anywhere in the project — this project's
  tests will fail to even start if any script has a parse error); (b) a
  manual/static review of the diff against this task's exact values,
  since no implementer or reviewer in this environment has had GUI
  access this session, in every prior task in this project's history.
- **After Task 12 (the last content task), the controller performs a real
  on-device build+install+launch** (Godot CLI export + `adb install` +
  `adb shell monkey` launch — this exact pipeline was exercised
  successfully earlier this session) so a human can actually look at the
  result. This is a controller-run step, not a dispatched task — it needs
  the physical device already connected to this machine, not a fresh
  subagent.

---

### Task 1: Engine config — `project.godot`

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Produces: the project's portrait viewport/orientation/stretch config.
  No other task's `.tscn`/`.gd` values depend on this file's content to
  be internally correct (see Global Constraints, Engine).

- [ ] **Step 1: Add the `[display]` section**

`project.godot` currently has no `[display]` section at all. Add one
after the existing `[application]` section (before `[autoload]`):

```ini
[display]

window/size/viewport_width=1080
window/size/viewport_height=2424
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation="portrait"
```

- [ ] **Step 2: Manually verify**

Open `project.godot` in a text editor (not the Godot editor GUI, which
isn't available in this environment) and confirm the file still parses as
valid INI — no stray characters, section header exactly `[display]`,
placed between `[application]` and `[autoload]`. Run the full GUT suite
(command below) and confirm it still starts and passes at the same count
as before this change — a malformed `project.godot` would make Godot fail
to even launch the test runner, so a clean run is real evidence this step
succeeded.

```
"/c/Users/luket/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "Portrait mode: add display/viewport/orientation config"
```

---

### Task 2: Trivial screens — SubclassPicker, PresetPicker, NadirPanel, GateBreakPanel

**Files:**
- Modify: `scenes/main.tscn` (four node subtrees: `SubclassPicker`,
  `PresetPicker`, `GameUI/NadirPanel`, `GameUI/GateBreakPanel`)

**Interfaces:**
- Consumes: nothing from Task 1 (see Global Constraints, Engine).
- Produces: nothing consumed by later tasks — these four screens have no
  shared code with any other screen in this plan.

No `.gd` changes — all four screens build their content entirely from
static `.tscn` nodes; none of them has a dynamic row-builder in code.

- [ ] **Step 1: `SubclassPicker`**

Already a single narrow column (all elements at `x=40` to `x=340` or
narrower) — no structural change, just narrow the two wide labels:

| Node | Property | Old | New |
|---|---|---|---|
| `TitleLabel` | `offset_right` | `900.0` | `1040.0` |
| `WelcomeLabel` | `offset_right` | `2000.0` | `1040.0` |
| `WelcomeLabel` | `offset_bottom` | `700.0` | `2200.0` (more room for the onboarding welcome text — vertical space is abundant, see Global Constraints) |
| `ContinueButton` | `offset_top` | `720.0` | `2240.0` |
| `ContinueButton` | `offset_bottom` | `790.0` | `2310.0` |

`WarriorButton`/`GuardianButton`/`AssassinButton`/`MageButton`/
`SupportButton` are already `x=40` to `x=340` — no change needed.

- [ ] **Step 2: `PresetPicker`**

The 12-button grid stays 6 columns (per the design spec) — only the
container's width and the title label need narrowing:

| Node | Property | Old | New |
|---|---|---|---|
| `TitleLabel` | `offset_right` | `900.0` | `1040.0` |
| `Grid` | `offset_right` | `2000.0` | `1040.0` |
| `Grid` | `offset_bottom` | `900.0` | `2300.0` |

`Grid`'s `columns=6` is unchanged. Each button is built in code at
`160×212` (`scenes/main.gd`'s `_show_preset_picker()`, already correct
from an earlier task in a different plan) — 6 columns × 160px = 960px
plus 5 gaps of Godot's `GridContainer` default `theme_override_constants/
h_separation` (4px default = 20px total) = 980px, fits inside the
1000px content width with margin to spare. No code change needed here.

- [ ] **Step 3: `NadirPanel`**

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1800.0` | `1040.0` |
| `InfoLabel` | `offset_right` | `1400.0` | `1040.0` |
| `InfoLabel` | `offset_bottom` | `400.0` | `700.0` (more room — see Global Constraints) |
| `TakeOnButton` | `offset_top` | `420.0` | `720.0` |
| `TakeOnButton` | `offset_bottom` | `480.0` | `790.0` |

`CloseButton` is already `x=40` to `x=180` — no change needed.

- [ ] **Step 4: `GateBreakPanel`**

| Node | Property | Old | New |
|---|---|---|---|
| `InfoLabel` | `offset_right` | `2000.0` | `1040.0` |
| `InfoLabel` | `offset_top` | `300.0` | `400.0` |
| `InfoLabel` | `offset_bottom` | `600.0` | `900.0` |
| `AcceptButton` | `offset_top` | `640.0` | `940.0` |
| `AcceptButton` | `offset_bottom` | `710.0` | `1010.0` |
| `DismissButton` | `offset_top` | `640.0` | `940.0` |
| `DismissButton` | `offset_bottom` | `710.0` | `1010.0` |

`AcceptButton`/`DismissButton`'s `offset_left`/`offset_right` are
unchanged (`40/400` and `420/780` respectively — both already well under
1000px combined).

- [ ] **Step 5: `Bg` nodes**

Per Global Constraints, change `offset_right` `2424.0`→`1080.0` and
`offset_bottom` `1080.0`→`2424.0` on `PresetPicker` has no `Bg` node
(it's transparent over whatever's behind it, matching `SubclassPicker`'s
existing lack of one — leave both as-is, no `Bg` to add). `NadirPanel/Bg`
and `GateBreakPanel/Bg` both get the change.

- [ ] **Step 6: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff
against the tables above — confirm every changed node's new offsets keep
`offset_right <= 1040.0` and, for `PresetPicker`'s `Grid`, that the
`columns` property was NOT touched.

- [ ] **Step 7: Commit**

```bash
git add scenes/main.tscn
git commit -m "Portrait mode: recoordinate SubclassPicker, PresetPicker, NadirPanel, GateBreakPanel"
```

---

### Task 3: Home screen — `GameUI` base (map + nav)

**Files:**
- Modify: `scenes/main.tscn` (`GameUI` node's direct children — NOT any
  of its `*Panel` children, which are separate tasks)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks. `scenes/main.gd`'s
  `_ready()` wires `$HunterGearButton`, `$ArmyButton`, `$InventoryButton`,
  `$NadirButton`, `$StrongholdButton`, `$CharacterButton`,
  `$UseTicketButton`, `$ShopButton`, `$LeaderboardButton`,
  `$EnterGateButton` via `.pressed.connect(...)` (verify these exact
  paths exist in `scenes/main.gd` before changing any node's *name* —
  this task changes positions and reparents nodes into a
  `ScrollContainer`, but must NOT rename any of the 10 button nodes
  listed above, since `main.gd` looks them up by name via `$NodeName`).

No `.gd` changes required — reparenting a `Button` node into a
`ScrollContainer` does not change its `$NodeName` lookup path as long as
the button keeps the same name and `main.gd` doesn't use a path that
encodes the old parent (it doesn't — confirm this by grepping
`scenes/main.gd` for `$HunterGearButton` etc. before starting: every
reference is a bare `$ButtonName`, not `$GameUI/ButtonName` or similar,
so reparenting under GameUI is safe).

- [ ] **Step 1: Map fills the top ~70% of the screen**

`MapView` is currently positioned via `position = Vector2(1700, 540)`
(a `Node2D`, not an offset-based `Control`, so it's centered on that
point rather than bounded by a rect). Change to:

```
position = Vector2(540, 750)
```

(Horizontally centered on the new 1080-wide canvas; vertically centered
within a ~1500px-tall top region, leaving room for the nav strip below.)
`map_view.gd`'s own internal drawing (gate markers, radius circle, "GPS
fix"/incursion text) is confirmed safe to leave untouched: its `_draw()`
(the only place it draws anything) positions everything with
`Vector2(dx, dy)`/`Vector2(-100, 0)`-style offsets relative to `MapView`'s
own local origin, and never calls `get_viewport_rect()` or otherwise reads
the canvas's absolute size — moving `MapView`'s `position` is the only
change this step needs.

- [ ] **Step 2: Nav buttons become a horizontally-scrollable bottom strip**

Currently the 9 nav buttons (`HunterGearButton`, `ArmyButton`,
`InventoryButton`, `NadirButton`, `StrongholdButton`, `CharacterButton`,
`UseTicketButton`, `ShopButton`, `LeaderboardButton`) are direct children
of `GameUI`, each with its own `offset_left`/`offset_top`/`offset_right`/
`offset_bottom` scattered across a wide row (see the existing `.tscn` for
current values).

Add a new `ScrollContainer` node as a direct child of `GameUI`, named
`NavScroll`, positioned along the bottom of the canvas:

```
[node name="NavScroll" type="ScrollContainer" parent="GameUI"]
offset_left = 0.0
offset_top = 2260.0
offset_right = 1080.0
offset_bottom = 2380.0
horizontal_scroll_mode = 3
vertical_scroll_mode = 0
```

(`horizontal_scroll_mode = 3` is `SCROLL_MODE_SHOW_ALWAYS`,
`vertical_scroll_mode = 0` is `SCROLL_MODE_DISABLED` — the strip only
ever scrolls sideways.)

Add an `HBoxContainer` inside it, named `NavRow`:

```
[node name="NavRow" type="HBoxContainer" parent="GameUI/NavScroll"]
layout_mode = 2
theme_override_constants/separation = 12
```

**Reparent** each of the 9 existing nav buttons (do not delete and
recreate them — Godot's `.tscn` format encodes parenting via the
`parent="..."` field on each `[node ...]` line; change each button's
`parent` from `"GameUI"` to `"GameUI/NavScroll/NavRow"`) and remove their
`offset_left`/`offset_top`/`offset_right`/`offset_bottom` properties
entirely (an `HBoxContainer`'s children are laid out by the container, not
by manual offsets — leaving stale offsets on a container child is
harmless in Godot but is dead data; remove it for cleanliness). Set each
button's `custom_minimum_size` instead, matching its current width so the
strip's proportions look the same as today, just in a row:

| Node | `custom_minimum_size` |
|---|---|
| `HunterGearButton` | `Vector2(160, 60)` |
| `ArmyButton` | `Vector2(160, 60)` |
| `InventoryButton` | `Vector2(160, 60)` |
| `NadirButton` | `Vector2(160, 60)` |
| `StrongholdButton` | `Vector2(180, 60)` |
| `CharacterButton` | `Vector2(160, 60)` |
| `UseTicketButton` | `Vector2(160, 60)` |
| `ShopButton` | `Vector2(140, 60)` |
| `LeaderboardButton` | `Vector2(200, 60)` |

Keep each button's existing `theme_override_font_sizes/font_size = 18`
and `text = "..."` unchanged — only positioning changes.

- [ ] **Step 3: `EnterGateButton` and the status `Label`**

`EnterGateButton` (currently `offset_left=40, offset_top=300,
offset_right=340, offset_bottom=360`) and `Label` (the "Waiting for
location..." status text, currently `offset_left=40, offset_top=40,
offset_right=700, offset_bottom=260`) sit above the map in the landscape
layout. In portrait, place them above the map (which now starts around
`y=0` per Step 1's vertical centering — recompute: if `MapView` is
centered at `y=750` and roughly 1400px tall as drawn by `map_view.gd`,
its top edge is near `y=50`, leaving no room above it. Instead, place
`Label` and `EnterGateButton` in a thin strip at the very top,
`y=10` to `y=140`, and shift `MapView`'s `position` from Step 1 down to
`Vector2(540, 800)` so the map begins below them):

| Node | Property | Old | New |
|---|---|---|---|
| `Label` | `offset_left/top/right/bottom` | `40/40/700/260` | `40/10/1040/70` |
| `EnterGateButton` | `offset_left/top/right/bottom` | `40/300/340/360` | `40/80/340/140` |

Re-derive `MapView`'s `position` from Step 1 to `Vector2(540, 800)` to
sit below this top strip (supersedes the `Vector2(540, 750)` value given
in Step 1 — use `Vector2(540, 800)` as the final value).

- [ ] **Step 4: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm all 9 nav buttons kept their exact original names (no renames),
confirm each button's `parent=` field now reads
`"GameUI/NavScroll/NavRow"`, confirm no button node has leftover
`offset_*` properties after reparenting into the `HBoxContainer`.

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn
git commit -m "Portrait mode: home screen -- map on top, scrollable nav strip"
```

---

### Task 4: Hunter & Shadow Gear panels

**Files:**
- Modify: `scenes/gear_panel_helpers.gd` (shared row-builder, used by
  both panels)
- Modify: `scenes/main.tscn` (`GameUI/HunterGearPanel`,
  `GameUI/ShadowGearPanel` node subtrees)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `gear_panel_helpers.gd`'s shared row layout**

The current 5-element row (`row_label` 600 wide + `equip_btn` 150 +
`unequip_btn` 130 + `enhance_btn` 160 + `browse_btn` 130, starting at
`x=40/660/820/960/1140`) spans to `x=1270` — over the 1000px content
width. The buttons alone (150+130+160+130=570) already fit comfortably;
only the label is oversized for what it actually shows (a slot name like
"Weapon" or "Aura" — short text). Narrow the label and tighten the
button `x` positions so the whole row fits in one line without wrapping:

```gdscript
static func build_gear_rows(parent: Node2D, y_start: float) -> Array:
	var rows := []
	var y := y_start
	for slot in Equip.SLOTS:
		var row_label := Label.new()
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(340, 40)
		row_label.add_theme_font_size_override("font_size", 20)
		parent.add_child(row_label)

		var equip_btn := Button.new()
		equip_btn.position = Vector2(390, y)
		equip_btn.size = Vector2(150, 40)
		equip_btn.text = "Equip Best"
		parent.add_child(equip_btn)

		var unequip_btn := Button.new()
		unequip_btn.position = Vector2(550, y)
		unequip_btn.size = Vector2(130, 40)
		unequip_btn.text = "Unequip"
		parent.add_child(unequip_btn)

		var enhance_btn := Button.new()
		enhance_btn.position = Vector2(690, y)
		enhance_btn.size = Vector2(160, 40)
		enhance_btn.text = "Enhance"
		parent.add_child(enhance_btn)

		var browse_btn := Button.new()
		browse_btn.position = Vector2(860, y)
		browse_btn.size = Vector2(130, 40)
		browse_btn.text = "Browse"
		parent.add_child(browse_btn)

		(
			rows
			. append(
				{
					"slot": slot,
					"label": row_label,
					"equip_btn": equip_btn,
					"unequip_btn": unequip_btn,
					"enhance_btn": enhance_btn,
					"browse_btn": browse_btn,
				}
			)
		)
		y += 50
	return rows
```

(Only the five `position`/`size` value changes shown above; every other
line — signal wiring, the dictionary shape, `y += 50` — is unchanged. The
row now spans `x=40` to `x=990`, inside the 1000px content width.)

- [ ] **Step 2: `HunterGearPanel` frame**

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `900.0` | `1040.0` |
| `SetsLabel` | `offset_right` | `2380.0` | `1040.0` |
| `SetsLabel` | `offset_top` | `560.0` | `760.0` (below the now-narrower-but-same-row-count gear rows, which start at whatever `y_start` `hunter_gear_view.gd` passes to `build_gear_rows()` — confirm that `y_start` value and place `SetsLabel` at least 60px below the last row: 7 slots × 50px step from `y_start`, plus 60px gap) |

`AutoEquipButton` (`40/90/400/140`) and `CloseButton` (`420/90/560/140`)
are already narrow — no change needed.

- [ ] **Step 3: `ShadowGearPanel` frame — 9-button top row wraps to 4+5**

The 9 buttons (`PrevButton`, `NextButton`, `AutoEquipButton`,
`CloseButton`, `LevelUpButton`, `FuseButton`, `ConvertButton`,
`LockButton`, `FavoriteButton`) currently span one row from `x=40` to
`x=1850` — far over budget. Split into two rows of 4 and 5, each fitting
under 1000px:

**Row 1** (`offset_top=90, offset_bottom=140`, unchanged from today):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `PrevButton` | `40.0` | `140.0` |
| `NextButton` | `160.0` | `260.0` |
| `AutoEquipButton` | `280.0` | `640.0` |
| `CloseButton` | `660.0` | `800.0` |

(Unchanged from today — this row already totals 800px, under budget on
its own. Only rows 2 is new.)

**Row 2** (new `offset_top=160, offset_bottom=210`):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `LevelUpButton` | `40.0` | `200.0` |
| `FuseButton` | `220.0` | `440.0` |
| `ConvertButton` | `460.0` | `670.0` |
| `LockButton` | `690.0` | `850.0` |
| `FavoriteButton` | `870.0` | `1040.0` (was `1650/1850`) |

(Each button keeps its existing width — `LevelUpButton` 160,
`FuseButton` 220, `ConvertButton` 210, `LockButton` 160,
`FavoriteButton` 200 — just repositioned; total row width 950px plus 4×20
gaps = fits under 1040.)

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1200.0` | `1040.0` |
| `SetsLabel` | `offset_right` | `2380.0` | `1040.0` |
| `SetsLabel` | `offset_top` | `560.0` | `630.0` (shifted down 70px for the new second button row from Step 3) |
| `LoreLabel` | `offset_right` | `2380.0` | `1040.0` |
| `LoreLabel` | `offset_top` | `910.0` | `980.0` (same 70px shift) |

`shadow_gear_view.gd:36` currently calls
`GearPanelHelpers.build_gear_rows($Rows, 180.0)` — since Step 3's new
second button row pushes everything below it down by 70px, change this
call's `y_start` argument from `180.0` to `250.0`.

- [ ] **Step 4: `Bg` nodes**

Both panels' `Bg` — per Global Constraints, `offset_right` →`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 5: Manually verify**

Run the full GUT suite, confirm pass count unchanged (this task touches
`.gd` code, unlike Tasks 2-3 — this is the first real regression risk in
this plan; check no `Equip.SLOTS` iteration logic or dictionary shape in
`gear_panel_helpers.gd` was accidentally changed, only the four
`position`/`size` numeric literals). Re-read the diff: confirm
`shadow_gear_view.gd`'s `y_start` argument is a plain numeric literal
increase (old value + 70), not a formula or unrelated refactor.

- [ ] **Step 6: Commit**

```bash
git add scenes/gear_panel_helpers.gd scenes/shadow_gear_view.gd scenes/main.tscn
git commit -m "Portrait mode: Hunter & Shadow Gear panels"
```

---

### Task 5: Army panel — Roster & Squad tabs

**Files:**
- Modify: `scenes/army_view.gd` (Roster tab row-builder)
- Modify: `scenes/squad_view.gd` (Squad tab row-builder)
- Modify: `scenes/main.tscn` (`GameUI/ArmyPanel` node subtree)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `army_view.gd`'s Roster tab rows**

Current: section `header` at `size = Vector2(2340, 44)`, each shadow
`row` at `size = Vector2(2300, 40)`, `sections_container.custom_minimum_
size = Vector2(2340, y)`. Narrow all three to fit the 1000px content
width (leave `position.x` at their current `40`/`60` — only the widths
change):

| Line (function) | Old | New |
|---|---|---|
| `header.size` (in the section-header–building loop) | `Vector2(2340, 44)` | `Vector2(1000, 44)` |
| `row.size` (in the per-shadow row loop) | `Vector2(2300, 40)` | `Vector2(960, 40)` |
| `sections_container.custom_minimum_size` | `Vector2(2340, y)` | `Vector2(1000, y)` |

(`row.icon = ArtPaths.monster_portrait(...)` and `row.expand_icon = true`
— both already present from earlier work — are unaffected; a `960`-wide
button with `expand_icon` still scales its square 1024×1024 icon inside
whatever height the button ends up, unchanged by this width edit.)

- [ ] **Step 2: `squad_view.gd`'s Squad tab rows**

Current: `row_label.size = Vector2(1600, 40)` at `position.x = 40`,
`toggle_btn` at `position.x = 1660, size = Vector2(220, 40)` — spans to
`x=1880`. Narrow:

| Line | Old | New |
|---|---|---|
| `row_label.size` | `Vector2(1600, 40)` | `Vector2(760, 40)` |
| `toggle_btn.position` | `Vector2(1660, y)` | `Vector2(800, y)` |
| `toggle_btn.size` | `Vector2(220, 40)` | `Vector2(220, 40)` (unchanged) |

(New row total: `40 + 760 + 20(gap) + 220 = 1040` — right at the content
edge; if this feels too tight once you can see it rendered, `row_label`
can go narrower still, e.g. `700`, with `toggle_btn.position.x` at
`740` — use your judgment here, the hard requirement is only that the row
not exceed `x=1040`.)

- [ ] **Step 3: `ArmyPanel` frame — tab bar, both tabs' toolbars**

| Node | Property | Old | New |
|---|---|---|---|
| `RosterTabButton` | unchanged (`40/20/260/70`) | — | — |
| `SquadTabButton` | unchanged (`280/20/500/70`) | — | — |
| `CloseButton` | `offset_left` | `2260.0` | `900.0` |
| `CloseButton` | `offset_right` | `2380.0` | `1020.0` |
| `RosterTab/FilterBar/GradeFilterButton` | unchanged (`40/0/260/50`) | — | — |
| `RosterTab/FilterBar/SortButton` | unchanged (`280/0/500/50`) | — | — |
| `RosterTab/SectionsScroll` | `offset_right` | `2424.0` | `1080.0` |
| `RosterTab/BulkBar/MassConvertButton` | unchanged (`40/0/460/50`) | — | — |
| `SquadTab/Bg` | `offset_right` | `2424.0` | `1080.0` |
| `SquadTab/CloseButton` | unchanged (`40/90/180/140`) | — | — |
| `SquadTab/AutoFillButton` | unchanged (`200/90/460/140`) | — | — |
| `SquadTab/AutoEquipSquadButton` | unchanged (`480/90/700/140`) | — | — |
| `SquadTab/InfoLabel` | `offset_right` | `2380.0` | `1040.0` |

- [ ] **Step 4: `Bg` node**

`ArmyPanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 5: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm `army_view.gd`'s three width changes are the only changes in that
file (no logic touched), same for `squad_view.gd`'s two.

- [ ] **Step 6: Commit**

```bash
git add scenes/army_view.gd scenes/squad_view.gd scenes/main.tscn
git commit -m "Portrait mode: Army panel (Roster & Squad tabs)"
```

---

### Task 6: Inventory panel — Grid tab

**Files:**
- Modify: `scenes/inventory_view.gd` (Grid tab cell-builder only — NOT
  the Sets tab code, that's Task 7)
- Modify: `scenes/main.tscn` (`GameUI/InventoryPanel` node subtree —
  `GridTabButton`, `SetsTabButton`, `CloseButton`, and everything under
  `GridTab` only; `SetsTab`/`DetailPanel`/`ConfirmScrapPanel` are Task 7)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `inventory_view.gd`'s grid cells — 4 columns become 2**

Current: `cell.custom_minimum_size = Vector2(560, 160)` inside a
`GridContainer` with `columns = 4` (in `main.tscn`, changed in Step 3
below) — 4×560=2240px, far over budget. Drop to 2 columns and grow the
cell height to use the extra vertical room for the now-taller card
(icon + name + rarity/slot + power, same text as today, just in a
narrower box that may wrap to more lines):

```gdscript
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(480, 220)
		cell.icon = ArtPaths.equipment_icon(item["equipment_def_id"])
		cell.expand_icon = true
```

(Only the `custom_minimum_size` value changes — `560,160` →
`480,220`. Everything else in `_refresh_grid()`'s cell-building loop is
unchanged.)

- [ ] **Step 2: No other code change needed for the bulk-bar buttons**

`ScrapBelowRarityButton`'s text is set dynamically at
`inventory_view.gd:437` (`$GridTab/BulkBar/ScrapBelowRarityButton.text =
"Scrap Below: %s" % _rarity_below_threshold`) — a plain string
assignment with no width/position math attached to it, and no other
button in this file computes its own size or position from the grid's
column count. No code change needed here; this step is just confirming
that fact so Step 3's `.tscn` repositioning is the only change this
button needs.

- [ ] **Step 3: `InventoryPanel` frame — tab bar, Grid tab toolbars**

| Node | Property | Old | New |
|---|---|---|---|
| `GridTabButton` | unchanged (`40/20/260/70`) | — | — |
| `SetsTabButton` | unchanged (`280/20/500/70`) | — | — |
| `CloseButton` | `offset_left` | `2260.0` | `900.0` |
| `CloseButton` | `offset_right` | `2380.0` | `1020.0` |

**`GridTab/FilterBar` — 6 buttons wrap to 3+3** (today: `ClassFilterButton`
40-260, `SlotFilterButton` 280-500, `RarityFilterButton` 520-740,
`SetFilterButton` 760-980, `EquippedFilterButton` 1000-1220,
`SortButton` 1240-1460 — one row spanning to 1460):

**Row 1** (`offset_top=0, offset_bottom=50`, unchanged):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `ClassFilterButton` | `40.0` | `260.0` |
| `SlotFilterButton` | `280.0` | `500.0` |
| `RarityFilterButton` | `520.0` | `740.0` |

**Row 2** (new `offset_top=60, offset_bottom=110`):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `SetFilterButton` | `40.0` | `260.0` |
| `EquippedFilterButton` | `280.0` | `500.0` |
| `SortButton` | `520.0` | `740.0` |

Since `FilterBar` now takes two rows instead of one, shift everything
below it down by 60px: `GridScroll`'s `offset_top` goes from `160.0` to
`220.0`.

| Node | Property | Old | New |
|---|---|---|---|
| `GridScroll` | `offset_top` | `160.0` | `220.0` |
| `GridScroll` | `offset_right` | `2424.0` | `1080.0` |
| `GridScroll` | `offset_bottom` | `890.0` | `1900.0` (more room for the now-2-column, taller-card grid — see Global Constraints) |
| `Grid` | `columns` | `4` | `2` |
| `CapacityWarningLabel` | `offset_top` | `900.0` | `1920.0` |
| `CapacityWarningLabel` | `offset_right` | `2380.0` | `1040.0` |

**`GridTab/BulkBar` — 4 buttons wrap to 2+2** (today: `MultiSelectToggleButton`
40-340, `ScrapSelectedButton` 360-640, `ScrapBelowRarityButton` 660-1020,
`ScrapDuplicatesButton` 1040-1400 — spans to 1400):

`BulkBar`'s `position` (currently `Vector2(0, 940)`) moves to
`Vector2(0, 1960)` (below the relocated `CapacityWarningLabel`).

**Row 1** (`offset_top=0, offset_bottom=50`):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `MultiSelectToggleButton` | `40.0` | `340.0` |
| `ScrapSelectedButton` | `360.0` | `640.0` |

**Row 2** (new `offset_top=60, offset_bottom=110`):

| Node | `offset_left` | `offset_right` |
|---|---|---|
| `ScrapBelowRarityButton` | `40.0` | `400.0` |
| `ScrapDuplicatesButton` | `420.0` | `1040.0` |

(`ScrapBelowRarityButton`'s text is dynamic — e.g.
`"Scrap Below: UNCOMMON"` — so its width stays generous at 360px;
`ScrapDuplicatesButton`'s longer static text "Scrap Unequipped
Duplicates" gets the remaining 620px.)

- [ ] **Step 4: `Bg` node**

`InventoryPanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 5: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm `Grid`'s `columns` is exactly `2`, confirm `cell.custom_minimum_
size` in `inventory_view.gd` is exactly `Vector2(480, 220)`, confirm no
change touched `SetsTab`/`DetailPanel`/`ConfirmScrapPanel` (Task 7's
scope).

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory_view.gd scenes/main.tscn
git commit -m "Portrait mode: Inventory panel Grid tab"
```

---

### Task 7: Inventory panel — Sets tab, Detail panel, Confirm-scrap panel

**Files:**
- Modify: `scenes/inventory_view.gd` (Sets tab row-builder only)
- Modify: `scenes/main.tscn` (`GameUI/InventoryPanel/SetsTab`,
  `GameUI/InventoryPanel/DetailPanel`,
  `GameUI/InventoryPanel/ConfirmScrapPanel`)

**Interfaces:**
- Consumes: nothing from Task 6 at the code level (different function in
  the same file) — safe to execute in either order relative to Task 6,
  but listed second since it's a smaller, lower-risk follow-up.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `inventory_view.gd`'s Sets tab rows**

Current: `icon.position = Vector2(40, y)`, `icon.size = Vector2(80, 80)`
(unchanged — 80px icon is fine), `label.position = Vector2(140, y)`,
`label.size = Vector2(2240, 80)` (needs narrowing), `sets_rows.custom_
minimum_size = Vector2(2340, y)` (needs narrowing):

| Line | Old | New |
|---|---|---|
| `label.size` | `Vector2(2240, 80)` | `Vector2(860, 80)` |
| `sets_rows.custom_minimum_size` | `Vector2(2340, y)` | `Vector2(1000, y)` |

(`icon.position`/`icon.size` and `label.position` are unchanged — the
icon stays at `x=40`, the label stays at `x=140`; only the label's width
and the container's overall width shrink.)

- [ ] **Step 2: `SetsTab`**

| Node | Property | Old | New |
|---|---|---|---|
| `SetsScroll` | `offset_right` | `2424.0` | `1080.0` |
| `SetsScroll` | `offset_bottom` | `1000.0` | `2380.0` |

- [ ] **Step 3: `DetailPanel`**

| Node | Property | Old | New |
|---|---|---|---|
| `DetailBg` | `offset_right` | `2424.0` | `1080.0` |
| `DetailBg` | `offset_bottom` | `1080.0` | `2424.0` |
| `NameLabel` | `offset_right` | `2380.0` | `1040.0` |
| `StatsLabel` | `offset_right` | `2380.0` | `1040.0` |
| `StatsLabel` | `offset_bottom` | `400.0` | `700.0` |
| `WearerLabel` | `offset_top` | `410.0` | `710.0` |
| `WearerLabel` | `offset_right` | `2380.0` | `1040.0` |
| `WearerLabel` | `offset_bottom` | `450.0` | `750.0` |
| `CompareLabel` | `offset_top` | `460.0` | `760.0` |
| `CompareLabel` | `offset_right` | `2380.0` | `1040.0` |
| `CompareLabel` | `offset_bottom` | `650.0` | `1200.0` |
| `EquipButton`/`LockButton`/`ScrapButton` | `offset_top`/`offset_bottom` | `900.0`/`950.0` | `2260.0`/`2320.0` |

`EquipButton` (`40/300`), `LockButton` (`320/580`), `ScrapButton`
(`600/860`) keep their existing `offset_left`/`offset_right` — the row
already totals 860px, under budget.

- [ ] **Step 4: `ConfirmScrapPanel`**

| Node | Property | Old | New |
|---|---|---|---|
| `ConfirmBg` | `offset_right` | `2424.0` | `1080.0` |
| `ConfirmBg` | `offset_bottom` | `1080.0` | `2424.0` |
| `ConfirmLabel` | `offset_left` | `400.0` | `40.0` |
| `ConfirmLabel` | `offset_right` | `2024.0` | `1040.0` |
| `ConfirmLabel` | `offset_top` | `400.0` | `900.0` |
| `ConfirmLabel` | `offset_bottom` | `550.0` | `1200.0` |
| `ConfirmButton` | `offset_left` | `400.0` | `140.0` |
| `ConfirmButton` | `offset_right` | `700.0` | `440.0` |
| `ConfirmButton` | `offset_top` | `900.0` | `1240.0` |
| `ConfirmButton` | `offset_bottom` | `950.0` | `1300.0` |
| `CancelButton` | `offset_left` | `720.0` | `460.0` |
| `CancelButton` | `offset_right` | `960.0` | `700.0` |
| `CancelButton` | `offset_top` | `900.0` | `1240.0` |
| `CancelButton` | `offset_bottom` | `950.0` | `1300.0` |

- [ ] **Step 5: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff
against the tables above.

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory_view.gd scenes/main.tscn
git commit -m "Portrait mode: Inventory panel Sets/Detail/Confirm-scrap"
```

---

### Task 8: Shop panel

**Files:**
- Modify: `scenes/shop_view.gd`
- Modify: `scenes/main.tscn` (`GameUI/ShopPanel`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `shop_view.gd`'s rows**

Current: `row_label.size = Vector2(1600, 40)` at `position.x = 40`,
`buy_btn.position = Vector2(1660, y)`, `buy_btn.size = Vector2(220, 40)`
— spans to `x=1880`.

```gdscript
func _build_row(y: float, id: String, kind: String) -> Dictionary:
	var row_label := Label.new()
	row_label.position = Vector2(40, y)
	row_label.size = Vector2(720, 40)
	row_label.add_theme_font_size_override("font_size", 20)
	rows_container.add_child(row_label)

	var buy_btn := Button.new()
	buy_btn.position = Vector2(780, y)
	buy_btn.size = Vector2(220, 40)
	buy_btn.text = "Buy"
	rows_container.add_child(buy_btn)
	buy_btn.pressed.connect(_on_row_buy_pressed.bind(id, kind))
```

(Only `row_label.size` and `buy_btn.position` change — new row total
`40+720+20+220=1000`, exactly at budget.)

- [ ] **Step 2: `ShopPanel` frame**

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1800.0` | `1040.0` |
| `CrystalsLabel` | `offset_right` | `800.0` | unchanged (already under budget) |

`CloseButton` (`40/90/180/140`) unchanged.

- [ ] **Step 3: `Bg` node**

`ShopPanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 4: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm `shop_view.gd`'s only changes are the two values in Step 1, no
signal-wiring or catalog-iteration logic touched.

- [ ] **Step 5: Commit**

```bash
git add scenes/shop_view.gd scenes/main.tscn
git commit -m "Portrait mode: Shop panel"
```

---

### Task 9: Leaderboard panel

**Files:**
- Modify: `scenes/leaderboard_view.gd`
- Modify: `scenes/main.tscn` (`GameUI/LeaderboardPanel`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `leaderboard_view.gd`'s board rows**

Current: `row_label.position = Vector2(40, y)`,
`row_label.size = Vector2(2000, 30)` — single label per row, no button,
just needs narrowing:

```gdscript
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(1000, 30)
```

- [ ] **Step 2: `LeaderboardPanel` frame**

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1800.0` | `1040.0` |
| `StatusLabel` (top one) | `offset_right` | `2380.0` | `1040.0` |

`CloseButton` (`40/90/180/140`), `PowerBoardButton` (`200/90/400/140`),
`FloorBoardButton` (`420/90/660/140`) unchanged — already under budget.

**`LinkPanel`'s email/password/button row stacks** (per the design spec's
call-out: this row totals exactly 1080px in the landscape design, zero
margin at the new canvas width, so it stacks instead of staying inline):

| Node | Property | Old | New |
|---|---|---|---|
| `Label` (the "Link an account..." text) | `offset_right` | `900.0` | `1040.0` |
| `EmailInput` | `offset_top`/`offset_bottom` | `30.0`/`70.0` | `40.0`/`90.0` |
| `EmailInput` | `offset_right` | `500.0` | `1040.0` |
| `PasswordInput` | `offset_left` | `520.0` | `40.0` |
| `PasswordInput` | `offset_top`/`offset_bottom` | `30.0`/`70.0` | `100.0`/`150.0` |
| `PasswordInput` | `offset_right` | `900.0` | `1040.0` |
| `LinkButton` | `offset_left` | `920.0` | `40.0` |
| `LinkButton` | `offset_top`/`offset_bottom` | `30.0`/`70.0` | `160.0`/`210.0` |
| `LinkButton` | `offset_right` | `1080.0` | `300.0` |
| `StatusLabel` (inside `LinkPanel`) | `offset_top` | `80.0` | `220.0` |
| `StatusLabel` (inside `LinkPanel`) | `offset_right` | `1800.0` | `1040.0` |

`LinkPanel`'s own `position` (currently `Vector2(0, 900)`) is unchanged
— the three-line stack above still fits comfortably starting there.

- [ ] **Step 3: `Rows`/`Bg`**

| Node | Property | Old | New |
|---|---|---|---|
| `Bg` | `offset_right`/`offset_bottom` | `2424.0`/`1080.0` | `1080.0`/`2424.0` |
| `Rows` | `position` | `Vector2(0, 210)` | unchanged |

- [ ] **Step 4: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm `leaderboard_view.gd`'s only change is the `row_label.size`
value, confirm the `LinkPanel` stack's three rows don't overlap
vertically (each new `offset_top` is at or after the previous element's
`offset_bottom`).

- [ ] **Step 5: Commit**

```bash
git add scenes/leaderboard_view.gd scenes/main.tscn
git commit -m "Portrait mode: Leaderboard panel"
```

---

### Task 10: Stronghold panel

**Files:**
- Modify: `scenes/main.tscn` (`GameUI/StrongholdPanel`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

No `.gd` changes — all of `StrongholdPanel`'s content is static `.tscn`
nodes (`stronghold_view.gd` reads/writes their `.text` but doesn't
position them).

- [ ] **Step 1: Header row**

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1800.0` | `1040.0` |
| `InfoLabel` | `offset_right` | `1800.0` | `1040.0` |

`CloseButton` (`40/90/180/140`), `CollectButton` (`200/90/400/140`),
`UpgradeStrongholdButton` (`420/90/700/140`) unchanged — already under
budget.

- [ ] **Step 2: Three facility rows wrap — label on its own line, 3 buttons below**

Each facility (`Reliquary`, `TrainingYard`, `GateWatch`) currently has
its label and 3 buttons (`*AssignButton`, `*UnassignButton`,
`*UpgradeButton`) in one line spanning to `x=1440`. Give each facility
two lines instead of one, and space the three facilities further apart
vertically to fit (was 80px apart — `270`/`350`/`430` — now 140px apart):

**Reliquary** (label line `y=270`, button line `y=330`):

| Node | Property | Old | New |
|---|---|---|---|
| `ReliquaryLabel` | `offset_top`/`offset_bottom` | `270.0`/`320.0` | `270.0`/`320.0` (unchanged) |
| `ReliquaryLabel` | `offset_right` | `760.0` | `1040.0` |
| `ReliquaryAssignButton` | `offset_left`/`offset_right` | `780.0`/`980.0` | `40.0`/`240.0` |
| `ReliquaryAssignButton` | `offset_top`/`offset_bottom` | `270.0`/`320.0` | `330.0`/`380.0` |
| `ReliquaryUnassignButton` | `offset_left`/`offset_right` | `1000.0`/`1220.0` | `260.0`/`480.0` |
| `ReliquaryUnassignButton` | `offset_top`/`offset_bottom` | `270.0`/`320.0` | `330.0`/`380.0` |
| `ReliquaryUpgradeButton` | `offset_left`/`offset_right` | `1240.0`/`1440.0` | `500.0`/`700.0` |
| `ReliquaryUpgradeButton` | `offset_top`/`offset_bottom` | `270.0`/`320.0` | `330.0`/`380.0` |

**Training Yard** (label line `y=430`, button line `y=490` — shifted down
160px from the original `350` to clear Reliquary's now-taller two-line
block):

| Node | Property | Old | New |
|---|---|---|---|
| `TrainingYardLabel` | `offset_top`/`offset_bottom` | `350.0`/`400.0` | `430.0`/`480.0` |
| `TrainingYardLabel` | `offset_right` | `760.0` | `1040.0` |
| `TrainingYardAssignButton` | `offset_left`/`offset_right` | `780.0`/`980.0` | `40.0`/`240.0` |
| `TrainingYardAssignButton` | `offset_top`/`offset_bottom` | `350.0`/`400.0` | `490.0`/`540.0` |
| `TrainingYardUnassignButton` | `offset_left`/`offset_right` | `1000.0`/`1220.0` | `260.0`/`480.0` |
| `TrainingYardUnassignButton` | `offset_top`/`offset_bottom` | `350.0`/`400.0` | `490.0`/`540.0` |
| `TrainingYardUpgradeButton` | `offset_left`/`offset_right` | `1240.0`/`1440.0` | `500.0`/`700.0` |
| `TrainingYardUpgradeButton` | `offset_top`/`offset_bottom` | `350.0`/`400.0` | `490.0`/`540.0` |

**Gate Watch** (label line `y=590`, button line `y=650` — shifted down
160px from the original `430`):

| Node | Property | Old | New |
|---|---|---|---|
| `GateWatchLabel` | `offset_top`/`offset_bottom` | `430.0`/`480.0` | `590.0`/`640.0` |
| `GateWatchLabel` | `offset_right` | `760.0` | `1040.0` |
| `GateWatchAssignButton` | `offset_left`/`offset_right` | `780.0`/`980.0` | `40.0`/`240.0` |
| `GateWatchAssignButton` | `offset_top`/`offset_bottom` | `430.0`/`480.0` | `650.0`/`700.0` |
| `GateWatchUnassignButton` | `offset_left`/`offset_right` | `1000.0`/`1220.0` | `260.0`/`480.0` |
| `GateWatchUnassignButton` | `offset_top`/`offset_bottom` | `430.0`/`480.0` | `650.0`/`700.0` |
| `GateWatchUpgradeButton` | `offset_left`/`offset_right` | `1240.0`/`1440.0` | `500.0`/`700.0` |
| `GateWatchUpgradeButton` | `offset_top`/`offset_bottom` | `430.0`/`480.0` | `650.0`/`700.0` |

- [ ] **Step 3: `Bg` node**

`StrongholdPanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 4: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm every facility's label+3-buttons block sits entirely within
`x=40` to `x=700` (the buttons) plus the label at `x=1040` max, and that
no two facilities' vertical ranges overlap (Reliquary ends at `y=380`,
Training Yard starts at `y=430` — 50px gap; Training Yard ends at `540`,
Gate Watch starts at `590` — 50px gap).

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn
git commit -m "Portrait mode: Stronghold panel"
```

---

### Task 11: Character panel

**Files:**
- Modify: `scenes/main.tscn` (`GameUI/CharacterPanel`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

No `.gd` changes — `character_view.gd` looks up `$PortraitRect` and the
three labels by name via `@onready var`, none of which encode position;
moving nodes in `.tscn` doesn't touch this file.

- [ ] **Step 1: Portrait moves from the right side to a top showcase**

Today `PortraitRect` sits at `x=1500-2380, y=170-900` next to the text
(side-by-side). Per the design spec's stacking rule, it becomes a
full-width block at the top, with the text stacked below it:

| Node | Property | Old | New |
|---|---|---|---|
| `PortraitRect` | `offset_left` | `1500.0` | `140.0` |
| `PortraitRect` | `offset_top` | `170.0` | `170.0` (unchanged) |
| `PortraitRect` | `offset_right` | `2380.0` | `940.0` |
| `PortraitRect` | `offset_bottom` | `900.0` | `1170.0` (800px tall, centered-ish 800-wide block — the preset art's 928:1232 aspect ratio means an 800-wide box wants ~1063px of height to show uncropped at `STRETCH_KEEP_ASPECT_CENTERED`, which is already this node's `stretch_mode` from earlier work — 1000px tall would match closer; use `1170.0` here for a clean round number, minor letterboxing top/bottom is fine) |

| Node | Property | Old | New |
|---|---|---|---|
| `Title` | `offset_right` | `1800.0` | `1040.0` |
| `InfoLabel` | `offset_top` | `170.0` | `1200.0` (below the portrait) |
| `InfoLabel` | `offset_right` | `1400.0` | `1040.0` |
| `InfoLabel` | `offset_bottom` | `520.0` | `1550.0` |
| `FitnessLabel` | `offset_top` | `540.0` | `1570.0` |
| `FitnessLabel` | `offset_right` | `1400.0` | `1040.0` |
| `FitnessLabel` | `offset_bottom` | `780.0` | `1810.0` |
| `HealthStatusLabel` | `offset_top` | `800.0` | `1830.0` |
| `HealthStatusLabel` | `offset_right` | `1400.0` | `1040.0` |
| `HealthStatusLabel` | `offset_bottom` | `900.0` | `1930.0` |
| `TrialButton` | `offset_top` | `920.0` | `1950.0` |
| `TrialButton` | `offset_bottom` | `980.0` | `2010.0` |

`CloseButton` (`40/90/180/140`) unchanged.

- [ ] **Step 2: `Bg` node**

`CharacterPanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 3: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm `PortraitRect`'s `expand_mode`/`stretch_mode` properties (set in
an earlier task in a different plan) were NOT touched, only its
`offset_*` values.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn
git commit -m "Portrait mode: Character panel -- portrait on top, stats stacked below"
```

---

### Task 12: Battle panel

**Files:**
- Modify: `scenes/main.tscn` (`GameUI/BattlePanel`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

No `.gd` changes — `battle_view.gd` looks up every slot/button by name
via `@onready var ... = [$EnemySlot1, $EnemySlot2, ...]` and
`$PartySlot1` etc.; this task keeps every node's name identical, only
repositions them.

- [ ] **Step 1: Enemy slots — row of 4 becomes a stacked column of 4**

Today: `EnemySlot1-4`, each `580×160`, in one row at `y=60-220` spanning
`x=40` to `x=2380`. Stack them instead, each full content-width, `160`
tall, `10px` gaps:

| Node | `offset_left` | `offset_top` | `offset_right` | `offset_bottom` |
|---|---|---|---|---|
| `EnemySlot1` | `40.0` | `60.0` | `1040.0` | `220.0` |
| `EnemySlot2` | `40.0` | `230.0` | `1040.0` | `390.0` |
| `EnemySlot3` | `40.0` | `400.0` | `1040.0` | `560.0` |
| `EnemySlot4` | `40.0` | `570.0` | `1040.0` | `730.0` |

- [ ] **Step 2: `TurnOrderLabel`/`LogLabel` shift down**

Enemy slots now end at `y=730` (was `y=220`) — shift these down by the
same 510px:

| Node | Property | Old | New |
|---|---|---|---|
| `TurnOrderLabel` | `offset_top`/`offset_bottom` | `230.0`/`270.0` | `740.0`/`780.0` |
| `TurnOrderLabel` | `offset_right` | `2380.0` | `1040.0` |
| `LogLabel` | `offset_top`/`offset_bottom` | `280.0`/`610.0` | `790.0`/`1120.0` |
| `LogLabel` | `offset_right` | `2380.0` | `1040.0` |

- [ ] **Step 3: Party slots — row of 4 becomes a stacked column of 4**

Today: `PartySlot1-4` at `y=620-780`. Place below the now-relocated
`LogLabel` (ends at `y=1120`):

| Node | `offset_left` | `offset_top` | `offset_right` | `offset_bottom` |
|---|---|---|---|---|
| `PartySlot1` | `40.0` | `1130.0` | `1040.0` | `1290.0` |
| `PartySlot2` | `40.0` | `1300.0` | `1040.0` | `1460.0` |
| `PartySlot3` | `40.0` | `1470.0` | `1040.0` | `1630.0` |
| `PartySlot4` | `40.0` | `1640.0` | `1040.0` | `1800.0` |

- [ ] **Step 4: Action buttons — row of 5 becomes a stacked column**

Today: `ActionButton1-5` at `y=800-870`, one row spanning `x=40-2380`.
Party slots now end at `y=1800` — place the action list below that:

| Node | `offset_left` | `offset_top` | `offset_right` | `offset_bottom` |
|---|---|---|---|---|
| `ActionButton1` | `40.0` | `1810.0` | `1040.0` | `1880.0` |
| `ActionButton2` | `40.0` | `1890.0` | `1040.0` | `1960.0` |
| `ActionButton3` | `40.0` | `1970.0` | `1040.0` | `2040.0` |
| `ActionButton4` | `40.0` | `2050.0` | `1040.0` | `2120.0` |
| `ActionButton5` | `40.0` | `2130.0` | `1040.0` | `2200.0` |

`WaitingLabel` occupies the same slot as `ActionButton1` when visible
(today both are at the same rect, toggled by visibility, not
side-by-side) — keep that pattern, just move `WaitingLabel` to match
`ActionButton1`'s new rect:

| Node | Property | Old | New |
|---|---|---|---|
| `WaitingLabel` | `offset_left`/`offset_top`/`offset_right`/`offset_bottom` | `40/800/1000/850` | `40.0`/`1810.0`/`1040.0`/`1880.0` |

- [ ] **Step 5: `AutoButton`/`SkipButton`/`ResultLabel`/`CloseButton`**

Action buttons now end at `y=2200` (was `y=870`) — shift the remaining
controls down by the same 1330px, but cap against `CANVAS_H=2424`: with
only 224px left below `y=2200`, `AutoButton`/`SkipButton` fit in one
final row (they're already narrow — 300 and 200 wide respectively — no
need to stack these two):

| Node | Property | Old | New |
|---|---|---|---|
| `AutoButton` | `offset_top`/`offset_bottom` | `900.0`/`960.0` | `2220.0`/`2280.0` |
| `SkipButton` | `offset_left`/`offset_right` | `360.0`/`560.0` | `320.0`/`520.0` |
| `SkipButton` | `offset_top`/`offset_bottom` | `900.0`/`960.0` | `2220.0`/`2280.0` |

`ResultLabel` (shown only at battle end, replacing the normal view) and
`CloseButton` (shown only alongside it) don't need to coexist with the
stacked slots above — reposition them independently, centered on the
full portrait canvas:

| Node | Property | Old | New |
|---|---|---|---|
| `ResultLabel` | `offset_left`/`offset_right` | `40.0`/`2380.0` | `40.0`/`1040.0` |
| `ResultLabel` | `offset_top`/`offset_bottom` | `400.0`/`700.0` | `900.0`/`1400.0` |
| `CloseButton` | `offset_left`/`offset_right` | `1080.0`/`1340.0` | `390.0`/`690.0` |
| `CloseButton` | `offset_top`/`offset_bottom` | `900.0`/`970.0` | `1450.0`/`1520.0` |

`TitleLabel` (`40/10/2380/50`) just needs `offset_right`→`1040.0`.

- [ ] **Step 6: `Bg` node**

`BattlePanel/Bg` — per Global Constraints, `offset_right`→`1080.0`,
`offset_bottom`→`2424.0`.

- [ ] **Step 7: Manually verify**

Run the full GUT suite, confirm pass count unchanged. Re-read the diff:
confirm every one of the 8 slot buttons (4 enemy + 4 party) and 5 action
buttons kept their exact node names, confirm no vertical range overlaps
(enemy slots end `730` < turn order starts `740`; log ends `1120` <
party slots start `1130`; party slots end `1800` < action buttons start
`1810`; action buttons end `2200` < auto/skip start `2220` < canvas
bottom `2424`).

- [ ] **Step 8: Commit**

```bash
git add scenes/main.tscn
git commit -m "Portrait mode: Battle panel -- stacked enemy/party/action slots"
```

---

## Post-plan checklist

- [ ] Full GUT suite green after every task (464/464 throughout — this
      plan adds and changes nothing `core/`, so the count never moves).
- [ ] `gdformat`/`gdlint` clean on every touched `.gd` file (via the
      post-edit hook).
- [ ] Every `.tscn` node this plan touched has `offset_right <= 1040.0`
      (or lives inside a container that itself respects that budget, like
      `NavRow`'s children in Task 3).
- [ ] **Controller step (not a task):** build the Android APK
      (`godot --headless --export-debug "Android" builds/android/
      hollowhunter.apk`), `adb install -r` it to the connected device,
      launch it (`adb shell monkey -p com.hollowhunter.app -c
      android.intent.category.LAUNCHER 1`), and report back to the user
      that it's ready for them to look at — do not just report "the
      diffs look right" as if that were equivalent to seeing it render,
      given this exact plan's own rationale (see Global Constraints,
      Testing) for why that step exists.
