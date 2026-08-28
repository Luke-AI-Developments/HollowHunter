# App-Wide UI Theme + Map Palette Implementation Plan

> **STATUS: TASKS 1–4 IMPLEMENTED 2026-08-28** on `master`:
> `b005eea` (T1 theme + project default), `2dc4f7b` (T2 panel Bg fills),
> `83ca489` (T3 strip overrides + BannerButton/Title), `e39e391` (T4 map palette, TDD),
> then whole-branch-review fixes `6a21a03` + `f59a9bb` (stronghold button size,
> DetailBg colour, MarkerCard 18pt, build_theme.gd dedupe/typing). Per-task +
> whole-branch reviews all clean. GUT held 532.
> **TASK 5 (Chakra Petch font) BLOCKED** — needs `ui/fonts/ChakraPetch-{Regular,SemiBold}.ttf`
> from the user; then re-run `godot --headless --script res://tools/build_theme.gd`.
> The theme works on the engine default font until then.
> **Outstanding:** device screenshot pass (every panel, small BannerButton buttons,
> onboarding screens, MarkerCard, the lighter map). Deferred: a `font_size = 20`
> unify pass (~50 `.tscn` lines + 5 code overrides opt out of the theme).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every panel a consistent cyan-glass look via one project-default `Theme`, and lighten the map palette so streets read on a phone.

**Architecture:** A headless GDScript (`tools/build_theme.gd`) constructs the `Theme` via the engine API and saves `res://ui/theme/hollowhunter.tres` — no hand-authored `.tres`. `project.godot` sets it as `gui/theme/custom`. `scenes/main.tscn` gets uniform panel `Bg` fills and has its now-redundant per-node style overrides stripped. `core/map_geometry.gd` (+ its test) gets 5 lighter colour constants. Font is added last as a one-line change once the `.ttf` files exist.

**Tech Stack:** Godot 4.7 / GDScript. GUT for `core/`. `gdformat` + `gdlint` + full GUT via the post-edit hook on every `.gd` save.

## Global Constraints

- Static typing everywhere; tabs; `snake_case` funcs/vars/files, `PascalCase` classes/nodes. One class per file. Per `CLAUDE.md`.
- `core/` is pure + unit-tested; `scenes/` is thin view code with **no game rules and no GUT coverage** — verified manually. Per `CLAUDE.md`.
- The post-edit hook reformats + lints every saved `.gd` and runs the whole GUT suite; a red hook is a blocker. Don't hand-fix whitespace the formatter reflows.
- **GUT suite count stays at 532.** Only `tests/unit/test_map_geometry.gd` changes — same 2 test functions, new expected colour values (Task 4). Count unchanged.
- Cyan for interactive elements is `Color(0.498, 0.941, 1.0)`.
- `ExtResource("15")` in `main.tscn` is `res://art/ui/ui_system_frame.webp`.
- Viewport is a fixed `1080 x 2424`; hardcoded-pixel `.tscn` layout is house style.
- Godot binary (headless): `"/c/Users/luket/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64.exe"` (or `godot`).
- Manual GUT run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Commit messages end with the `Co-Authored-By:` and `Claude-Session:` trailers.

---

### Task 1: Theme resource + project-default assignment

**Files:**
- Create: `tools/build_theme.gd`
- Generate (by running it): `ui/theme/hollowhunter.tres`
- Modify: `project.godot`

**Interfaces:**
- Produces: `res://ui/theme/hollowhunter.tres` — a `Theme` with `Button`, `BannerButton` (variation of `Button`), `Panel`, `Label`, `Title` (variation of `Label`), `LineEdit`, `VScrollBar`, `HScrollBar` styled. Consumed by every `Control` in the game via the project default. Task 3 sets `theme_type_variation = "BannerButton"` / `"Title"` on specific nodes. Task 5 adds `default_font`.

- [ ] **Step 1: Write `tools/build_theme.gd`**

```gdscript
extends SceneTree
## Headless theme builder. Run: godot --headless --script res://tools/build_theme.gd
## Rebuilds res://ui/theme/hollowhunter.tres from the values below -- edit
## here, never hand-edit the .tres. Font is picked up automatically once
## res://ui/fonts/ChakraPetch-SemiBold.ttf exists (Task 5).

const OUT_PATH := "res://ui/theme/hollowhunter.tres"
const FRAME_TEX := "res://art/ui/ui_system_frame.webp"
const FONT_PATH := "res://ui/fonts/ChakraPetch-SemiBold.ttf"

const CYAN := Color(0.498, 0.941, 1.0, 1.0)
const CYAN_DIM := Color(0.498, 0.941, 1.0, 0.4)


func _flat(bg: Color, border_a: float, radius: int, mh: int, mv: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = Color(0.498, 0.941, 1.0, border_a)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	return sb


func _banner_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(FRAME_TEX)
	sb.texture_margin_left = 64.0
	sb.texture_margin_top = 64.0
	sb.texture_margin_right = 64.0
	sb.texture_margin_bottom = 64.0
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


func _initialize() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	if FileAccess.file_exists(FONT_PATH):
		t.default_font = load(FONT_PATH)

	# --- Button (standard) ---
	t.set_color("font_color", "Button", CYAN)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_focus_color", "Button", CYAN)
	t.set_color("font_disabled_color", "Button", Color(0.498, 0.941, 1.0, 0.35))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", _flat(Color(0.06, 0.10, 0.15, 0.95), 0.35, 6, 10, 6))
	t.set_stylebox("hover", "Button", _flat(Color(0.09, 0.15, 0.22, 0.98), 0.6, 6, 10, 6))
	t.set_stylebox("pressed", "Button", _flat(Color(0.04, 0.07, 0.11, 1.0), 0.8, 6, 10, 6))
	t.set_stylebox("focus", "Button", _flat(Color(0.09, 0.15, 0.22, 0.98), 0.6, 6, 10, 6))
	t.set_stylebox("disabled", "Button", _flat(Color(0.05, 0.07, 0.09, 0.6), 0.12, 6, 10, 6))

	# --- BannerButton (variation of Button) ---
	t.add_type("BannerButton")
	t.set_type_variation("BannerButton", "Button")
	t.set_font_size("font_size", "BannerButton", 26)
	for s in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(s, "BannerButton", _banner_box())

	# --- Panel ---
	var panel_sb := _flat(Color(0.03, 0.06, 0.10, 0.98), 0.20, 4, 0, 0)
	panel_sb.set_border_width_all(1)
	t.set_stylebox("panel", "Panel", panel_sb)

	# --- Label ---
	t.set_color("font_color", "Label", CYAN)
	t.set_font_size("font_size", "Label", 22)
	t.set_constant("outline_size", "Label", 1)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))

	# --- Title (variation of Label) ---
	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	t.set_font_size("font_size", "Title", 30)

	# --- LineEdit ---
	t.set_color("font_color", "LineEdit", CYAN)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("selection_color", "LineEdit", Color(0.498, 0.941, 1.0, 0.25))
	t.set_color("font_placeholder_color", "LineEdit", Color(0.498, 0.941, 1.0, 0.35))
	t.set_stylebox("normal", "LineEdit", _flat(Color(0.04, 0.08, 0.12, 0.95), 0.3, 6, 10, 6))
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.04, 0.08, 0.12, 0.95), 0.7, 6, 10, 6))

	# --- Scrollbars ---
	for cls in ["VScrollBar", "HScrollBar"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(0.498, 0.941, 1.0, 0.25)
		g.set_corner_radius_all(4)
		var gh := StyleBoxFlat.new()
		gh.bg_color = Color(0.498, 0.941, 1.0, 0.4)
		gh.set_corner_radius_all(4)
		var gp := StyleBoxFlat.new()
		gp.bg_color = Color(0.498, 0.941, 1.0, 0.55)
		gp.set_corner_radius_all(4)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.03)
		t.set_stylebox("grabber", cls, g)
		t.set_stylebox("grabber_highlight", cls, gh)
		t.set_stylebox("grabber_pressed", cls, gp)
		t.set_stylebox("scroll", cls, track)

	var dir := DirAccess.open("res://")
	dir.make_dir_recursive("ui/theme")
	var err := ResourceSaver.save(t, OUT_PATH)
	print("[build_theme] saved %s err=%d" % [OUT_PATH, err])
	quit(0 if err == OK else 1)
```

> `CYAN_DIM` is declared for reuse; if `gdlint` flags it unused, inline
> its literal at the `font_disabled_color` call sites and drop the const.

- [ ] **Step 2: Run it**

```
godot --headless --script res://tools/build_theme.gd
```
Expected: `[build_theme] saved res://ui/theme/hollowhunter.tres err=0`. A
new `ui/theme/hollowhunter.tres` exists.

- [ ] **Step 3: Assign as project default**

In `project.godot`, add a `[gui]` section (alphabetical order among the
top-level sections — after `[filesystem]`/`[input]` if present, before
`[rendering]`):

```
[gui]

theme/custom="res://ui/theme/hollowhunter.tres"
```

- [ ] **Step 4: Headless load check**

```
godot --headless --path . --quit-after 3 -e
```
Expected: no `ERROR`/`SCRIPT ERROR` lines mentioning the theme or
`main.tscn` (the harmless `EditorSettings not instantiated` line is fine).
Full GUT run: still **532**, green.

- [ ] **Step 5: Commit**

```bash
git add tools/build_theme.gd ui/theme/hollowhunter.tres ui/theme/hollowhunter.tres.uid project.godot
git commit -m "feat: app-wide UI theme (cyan-glass Button/Panel/Label/LineEdit + BannerButton)

Headless builder tools/build_theme.gd generates ui/theme/hollowhunter.tres;
project.godot sets it as gui/theme/custom so every Control inherits it.
No font yet (Task 5). No node-level changes yet (Tasks 2-3).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

- [ ] **Step 6: Manual verification (device or editor)**

Open 2-3 panels (Shadow Gear, Army, Shop). Every button is now a dark
cyan-bordered box (not flat grey); labels are cyan; scrollbars show a
cyan grabber. Layout/positions unchanged. Nav banners still look like the
frame (their per-node overrides still win — cleaned up in Task 3).

---

### Task 2: Uniform panel background fills

**Files:**
- Modify: `scenes/main.tscn` — the `color` of every `*Panel/Bg` `ColorRect`.

**Interfaces:** none consumed/produced. Independent of Tasks 1/3/4/5.

`scenes/`-only: no GUT test, manual verification, GUT count unchanged.

- [ ] **Step 1: Set every panel `Bg` colour**

For each `[node name="Bg" type="ColorRect" parent="GameUI/<X>"]` block in
`scenes/main.tscn` (14 of them: `HunterGearPanel`, `ShadowGearPanel`,
`ArmyPanel`, `ArmyPanel/SquadTab`, `InventoryPanel`, `ShopPanel`,
`LeaderboardPanel`, `NadirPanel`, `StrongholdPanel`, `CharacterPanel`,
`GateBreakPanel`, `BattlePanel`, `SystemPanel`, `ClaimNicknamePanel`),
set the `color` line to:

```
color = Color(0.02, 0.05, 0.09, 0.99)
```

If a block has no `color` line, add one (after its `offset_bottom`).
Change nothing else in these blocks. Grep `type="ColorRect"` to confirm
you found all 14 and touched no non-`Bg` ColorRect (e.g.
`SystemPanel/Frame` children).

- [ ] **Step 2: Headless load check + commit**

```
godot --headless --path . --quit-after 3 -e   # no new errors
```

```bash
git add scenes/main.tscn
git commit -m "style: uniform dark Bg fill on all 14 panels

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

- [ ] **Step 3: Manual verification**

Open several panels — each has the same solid dark-blue-black backdrop.

---

### Task 3: Strip redundant overrides + apply `BannerButton` / `Title` variations

**Files:**
- Modify: `scenes/main.tscn` — many nodes; delete one sub-resource.

**Interfaces:** consumes the theme's `BannerButton` / `Title` variations (Task 1). Independent of Tasks 2/4/5.

`scenes/`-only: no GUT test, per-surface manual verification, GUT count unchanged. This is the highest-risk task — work node group by node group, screenshot each.

- [ ] **Step 1: Nav menu — `BannerButton` variation**

For `GameUI/NavMenu/MenuButton` and each of the 9
`GameUI/NavMenu/BannerList/*Banner` nodes:
- Delete all `theme_override_styles/normal`, `.../hover`, `.../pressed`,
  `.../focus` lines.
- Delete all `theme_override_colors/font_color`,
  `.../font_hover_color`, `.../font_pressed_color`, `.../font_focus_color`
  lines.
- Delete `theme_override_font_sizes/font_size`.
- Add one line: `theme_type_variation = &"BannerButton"`.

Then **delete** the `[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_navbanner"]`
block near the top of the file (nothing references it now — grep
`StyleBoxTexture_navbanner` returns zero hits after this step). Decrement
`load_steps` in the `[gd_scene ...]` header by 1.

- [ ] **Step 2: HUD label**

`GameUI/Label`: delete `theme_override_colors/font_color`. **Keep**
`theme_override_font_sizes/font_size = 28`.

- [ ] **Step 3: MarkerCard**

`GameUI/MarkerCard/TypeLabel` and `.../SubtitleLabel`: delete
`theme_override_colors/font_color`; keep `theme_override_font_sizes`.
`GameUI/MarkerCard/ActionButton`: delete any `theme_override_*` — it's a
themed `Button`.

- [ ] **Step 4: SystemPanel / SystemToast / GateBreakPanel / ClaimNicknamePanel**

For the `Label`-type children (`HeaderLabel`, `BodyLabel`, `Label`,
`InfoLabel`, etc.): delete `theme_override_colors/font_color`; **keep**
`theme_override_font_sizes/*`, `horizontal_alignment`, `autowrap_mode`.
Leave every `NinePatchRect` (`Bg`, `Frame`) untouched — decorative frame
art, not theme-driven. For the action buttons (`DismissButton`,
`AcceptButton`, `SaveButton`, `SkipButton`, and any `CloseButton`):
delete `theme_override_*`; add `theme_type_variation = &"BannerButton"`
(these are prominent CTAs).

- [ ] **Step 5: Stronghold Confirm/Cancel + LineEdits**

`GameUI/ConfirmStrongholdButton` and `GameUI/CancelStrongholdButton`:
delete the `theme_override_colors/font_*` and `theme_override_styles/*`
lines added in the HUD pass; add `theme_type_variation = &"BannerButton"`.
Every `LineEdit` node (`RenameInput`, `NicknameInput`, and 2 more —
grep `type="LineEdit"`): delete any local `theme_override_*` styling.

- [ ] **Step 6: Panel title labels — `Title` variation**

Each panel's title `Label` (the top-of-panel heading, e.g.
`GameUI/ShadowGearPanel/Title`, `GameUI/HunterGearPanel/Title`,
`GameUI/ShopPanel/Title`, `GameUI/NadirPanel/Title`,
`GameUI/StrongholdPanel/Title`, `GameUI/CharacterPanel/Title`,
`GameUI/LeaderboardPanel/Title`, and the Army/ShadowGear title labels):
if it currently sets `theme_override_font_sizes/font_size`, replace that
with `theme_type_variation = &"Title"` (which the theme sizes at 30).
Leave labels that are body text alone.

- [ ] **Step 7: Headless load check**

```
godot --headless --path . --quit-after 3 -e
```
Expected: no new `ERROR` / parse errors. `grep -n "StyleBoxTexture_navbanner\|theme_override_styles/normal = SubResource" scenes/main.tscn` — the navbanner id is gone; remaining `SubResource` style overrides are only the intentional decorative ones you chose to keep (none, ideally).

- [ ] **Step 8: Commit**

```bash
git add scenes/main.tscn
git commit -m "style: drop per-node overrides now covered by the theme; BannerButton/Title variations

Nav banners + MenuButton + stronghold + popup CTAs -> theme_type_variation
BannerButton; panel titles -> Title; redundant font_color overrides
removed; StyleBoxTexture_navbanner sub-resource deleted. HUD/popup frame
NinePatchRects and intentional font_size overrides kept.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

- [ ] **Step 9: Manual verification (device)**

Screenshot: the map (HUD frame + label unchanged), the open nav menu
(banners still the frame look, via the variation), Shadow Gear (title big,
buttons themed), and trigger a `SystemToast` / `SystemPanel` /
`GateBreakPanel` / the post-CLAIM prompt — labels cyan, CTAs framed,
decorative frames intact. Nothing lost its styling; nothing double-framed.

---

### Task 4: Lighten the map palette

**Files:**
- Modify: `core/map_geometry.gd` (`BACKGROUND_COLOR` const ~`:26`, `road_color()` ~`:66-77`)
- Modify: `tests/unit/test_map_geometry.gd` (`test_background_color_is_locked` ~`:34`, `test_road_color_matches_class` ~`:37-52`)
- Modify: `HollowHunter_Concept.md` (§19b palette table)

**Interfaces:** none. Independent of Tasks 1/2/3/5.

- [ ] **Step 1: Update the test assertions first (RED)**

In `tests/unit/test_map_geometry.gd`, change the 5 expected colours:

```gdscript
func test_background_color_is_locked() -> void:
	assert_eq(MapGeometry.BACKGROUND_COLOR, Color(0x0c / 255.0, 0x14 / 255.0, 0x20 / 255.0))


func test_road_color_matches_class() -> void:
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_MAJOR_ROAD),
		Color(0x3a / 255.0, 0x4a / 255.0, 0x5e / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_MINOR_ROAD),
		Color(0x26 / 255.0, 0x31 / 255.0, 0x3f / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_PATH),
		Color(0x1c / 255.0, 0x24 / 255.0, 0x30 / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_WATER_AREA),
		Color(0x07 / 255.0, 0x0d / 255.0, 0x16 / 255.0)
	)
```

(Match the file's existing structure — only the `Color(...)` literals
change. If the file also asserts `CLASS_MINOR_ROAD` as the `_` fallback,
update that too.)

- [ ] **Step 2: Run, verify RED**

`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_map_geometry.gd -gexit`
Expected: FAIL — the 2 tests, old constants vs new expected.

- [ ] **Step 3: Update the constants (GREEN)**

In `core/map_geometry.gd`:

```gdscript
const BACKGROUND_COLOR := Color(0x0c / 255.0, 0x14 / 255.0, 0x20 / 255.0)
```

In `road_color()`:

```gdscript
		CLASS_MAJOR_ROAD:
			return Color(0x3a / 255.0, 0x4a / 255.0, 0x5e / 255.0)
		CLASS_MINOR_ROAD:
			return Color(0x26 / 255.0, 0x31 / 255.0, 0x3f / 255.0)
		CLASS_PATH:
			return Color(0x1c / 255.0, 0x24 / 255.0, 0x30 / 255.0)
		CLASS_WATER_LINE, CLASS_WATER_AREA:
			return Color(0x07 / 255.0, 0x0d / 255.0, 0x16 / 255.0)
		_:
			return Color(0x26 / 255.0, 0x31 / 255.0, 0x3f / 255.0)
```

(Keep the `match` structure and the `_` fallback exactly as it is — only
the hex bytes change. If `road_width_px()` below also has per-class
literals, do NOT touch those — widths are unchanged.)

- [ ] **Step 4: Run, verify GREEN**

`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_map_geometry.gd -gexit` → PASS.
Full suite: still **532**, green. `gdformat`/`gdlint` clean (hook).

- [ ] **Step 5: Update the doc**

In `HollowHunter_Concept.md`, the §19b "Target treatment per layer" table
and any inline palette hex: change `#050b12`→`#0c1420`, `#1b2532`→`#3a4a5e`,
`#0f1620`→`#26313f`, `#0a0f16`→`#1c2430`, `#02040a`→`#070d16`. One-line
note that these were lifted for on-device daylight legibility.

- [ ] **Step 6: Commit**

```bash
git add core/map_geometry.gd tests/unit/test_map_geometry.gd HollowHunter_Concept.md
git commit -m "fix: lighten the map palette so the street grid reads on a phone

BACKGROUND 050b12->0c1420, major 1b2532->3a4a5e, minor 0f1620->26313f,
path 0a0f16->1c2430, water 02040a->070d16. Test assertions + §19b table
updated to match. Still 'quiet' -- cyan markers still pop.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

- [ ] **Step 7: Manual verification (device)**

Screenshot the map — major roads read as a soft grey against dark navy,
minor roads clearly present, water a touch darker than land. Gate markers
still stand out. Tune the hex against the screenshot if a channel is off.

---

### Task 5: Add the Chakra Petch font

**Files:**
- Add (user-supplied): `ui/fonts/ChakraPetch-Regular.ttf`, `ui/fonts/ChakraPetch-SemiBold.ttf`
- Re-run: `tools/build_theme.gd` (regenerates `ui/theme/hollowhunter.tres` with `default_font` set — the builder already picks the file up via `FileAccess.file_exists`)

**Interfaces:** consumes the font files; updates the Task 1 `.tres`.

- [ ] **Step 1: Place the font files**

Download Chakra Petch from fonts.google.com/specimen/Chakra+Petch (SIL
OFL). Put `ChakraPetch-Regular.ttf` and `ChakraPetch-SemiBold.ttf` in
`res://ui/fonts/`. **If the files are not available**, STOP and report
BLOCKED — this task can't proceed without them; the rest of the pass
(Tasks 1-4) is already complete and the theme works on the default font.

- [ ] **Step 2: Regenerate the theme**

```
godot --headless --script res://tools/build_theme.gd
```
The builder's `if FileAccess.file_exists(FONT_PATH)` branch now sets
`t.default_font`. Expected: `err=0`.

- [ ] **Step 3: Headless load check + full GUT (532, green)**

- [ ] **Step 4: Commit**

```bash
git add ui/fonts/ ui/theme/hollowhunter.tres
git commit -m "feat: bundle Chakra Petch as the UI theme font (OFL)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

- [ ] **Step 5: Manual verification (device)**

Screenshot every panel + the map HUD + a popup — text renders in Chakra
Petch, still cyan, readable at 22 / 28 / 30. No clipping from the metrics
change.

---

## Post-plan checklist (controller, after all tasks)

- [ ] Full GUT suite **532**, green — only `test_map_geometry.gd`'s colour literals changed.
- [ ] `gdformat` / `gdlint` clean on `tools/build_theme.gd`, `core/map_geometry.gd`.
- [ ] Headless editor load (`godot --headless -e --quit-after 3`) with no theme/`.tscn` errors.
- [ ] Device screenshot pass: Shadow Gear, Army (roster + squad), Inventory, Character, Shop, Leaderboard, Nadir, Stronghold, a battle, the map, the open nav menu, and each popup — consistent cyan-glass styling, Chakra Petch (if Task 5 landed), legible scrollbars, readable lighter map.
- [ ] Non-goals held: no layout/offset changes (bar the deleted sub-resource + `load_steps`); no functional change; battle screen still text; Save/Close overlap NOT touched.
- [ ] `git grep StyleBoxTexture_navbanner` → no hits. `git grep 'theme_override_styles' scenes/main.tscn` → only intentional keeps (ideally none).

## Self-Review

**Spec coverage:**
- Part 1 (theme + project default + font-last) → Task 1 (theme + `project.godot`), Task 5 (font). Builder's `file_exists` gate is the "font added last, degrades gracefully" mechanism.
- Part 2 (Button/BannerButton/Panel/Label/Title/LineEdit/scrollbars, exact values) → Task 1 Step 1, value-for-value from the spec.
- Part 3 (14 panel `Bg` = `Color(0.02,0.05,0.09,0.99)`) → Task 2.
- Part 4 (strip overrides, BannerButton/Title variations, delete navbanner sub-resource, keep decorative frames + intentional sizes) → Task 3, node group by node group.
- Part 5 (5 map constants + test + §19b doc) → Task 4, TDD.
- "grep first for OptionButton/CheckButton/Tree/ItemList" → resolved during planning: none exist; theme covers only Button/Label/LineEdit/Panel/ScrollBar. Not a task.
- Testing (GUT 532 unchanged except map_geometry values; manual + device) → every task's verification steps + post-plan checklist.

**Placeholder scan:** no TBD/TODO. `tools/build_theme.gd` is complete literal code. Task 3's node lists name concrete node paths; the "ideally none" for kept style overrides is a verification target, not a spec gap. `CYAN_DIM` unused-const risk is flagged with a concrete fallback.

**Type consistency:**
- `Theme` API calls in `build_theme.gd` use string class names (`"Button"`, `"BannerButton"`, `"Label"`, `"Title"`, `"LineEdit"`, `"VScrollBar"`, `"HScrollBar"`) consistently; variations declared with `add_type` + `set_type_variation(variation, base)` before their items are set.
- `theme_type_variation = &"BannerButton"` / `&"Title"` (StringName literal) in Task 3 matches the names registered in Task 1.
- Map colours: the same 5 hex triples appear in Task 4's test literals (Step 1) and constants (Step 3) and doc (Step 5) — `0c1420` / `3a4a5e` / `26313f` / `1c2430` / `070d16` throughout.
- `res://ui/theme/hollowhunter.tres` path identical in `build_theme.gd` `OUT_PATH`, `project.godot` `theme/custom`, and every `git add`.
