# §17 Army Management Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** replace the flat `ArmyLabel` HUD text and the standalone Shadow-Gear/Squad/Mass-Convert buttons with one real Army screen: a class-grouped, sortable/filterable Roster tab and a Squad tab (the existing squad-of-6 picker, absorbed unchanged).

**Architecture:** one new self-contained controller, `scenes/army_view.gd` (holds `HunterState` directly and mutates it itself, same pattern as `StrongholdView`/`CharacterView`), hosting two tabs. The Squad tab is the existing `squad_view.gd` re-parented under it with one new button added. The Roster tab is new. `shadow_gear_view.gd` (already the shadow detail hub) gets three new identity fields. This is **§17 only** — §17b (Equipment inventory) is a separate follow-up plan per the design doc's explicit build order; nothing here opens or references an inventory screen.

**Tech Stack:** Godot 4 / GDScript, GUT for `core/` tests, text-format `.tscn` editing.

## Global Constraints

- Static typing everywhere, tabs for indentation, `snake_case` functions/vars — per `CLAUDE.md`.
- `core/` stays pure/engine-free and unit-tested; `scenes/` stays thin view code — per `CLAUDE.md`'s folder-layout rule. Scene-layer tasks below are verified manually (Godot editor / on-device), not via GUT, matching every other scene controller in this project.
- The post-edit hook (`.claude/settings.json`) runs `gdformat` + `gdlint` + the full GUT suite on every `core/`/`scenes/` `.gd` save.
- Spec source: `docs/superpowers/specs/2026-08-16-army-equipment-screens-design.md` — read it for the "why" behind each decision below; this plan only restates what's needed to build.
- Element → Family, lore-from-§14b-comment, trait placeholder, and the Squad-tab-absorption decisions are already made (design doc decisions #1–#3, #7) — do not re-litigate them.
- The slot-tap-opens-Inventory interaction is **explicitly out of scope here** — it's §17b's work. Gear rows in `shadow_gear_view.gd` keep today's "Equip Best"/"Unequip"/"Enhance" buttons only.

---

## File Structure

- **Modify:** `content/monsters.json` — add a `"lore"` field to all 57 entries.
- **Modify:** `tests/unit/test_content.gd` — coverage test for the above.
- **Modify:** `core/hunter_state.gd` — new `auto_equip_squad()`.
- **Modify:** `tests/unit/test_hunter_state.gd` — tests for the above.
- **Modify:** `scenes/shadow_gear_view.gd` — identity block gains Family/Lore/Traits.
- **Modify:** `scenes/squad_view.gd` — new "Auto-Equip Squad" button + signal.
- **Create:** `scenes/army_view.gd` — the new screen shell.
- **Modify:** `scenes/main.tscn` — new `ArmyPanel` (Roster + re-parented Squad tab), remove the old standalone nodes.
- **Modify:** `scenes/main.gd` — remove the logic `army_view.gd` now owns, wire the new panel.

---

### Task 1: Monster lore content + coverage test

**Files:**
- Modify: `content/monsters.json`
- Modify: `tests/unit/test_content.gd`

**Interfaces:**
- Produces: every monster dict returned by `Content.load_monsters()`/`Content.monster_by_id()` now has a non-empty `"lore"` string — consumed by Task 3.

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/test_content.gd`, near `test_all_57_monsters_load`:

```gdscript
func test_every_monster_has_lore_text() -> void:
	for m: Dictionary in monsters:
		assert_true(
			String(m.get("lore", "")).length() > 0, "missing lore: %s" % m.get("id", "?")
		)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_content.gd -gexit`
Expected: FAIL — every monster missing `"lore"`.

- [ ] **Step 3: Add `"lore"` to all 57 entries in `content/monsters.json`**

Source each string from that monster's existing §14b art-direction comment in `HollowHunter_Concept.md` (decision #2), lightly turned into a sentence — do not invent new lore, transcribe what's already there. Example for the first entry:

```json
{"id": "mon_grubmaw", "name": "Grubmaw", "rank": "E", "family": "Hollow Brood", "clazz": "WARRIOR", "base_power": 120, "extract_chance": 0.40, "lore": "A teardrop larva with one giant toothy maw."},
```

Repeat for all 57 entries using each one's own §14b comment (e.g. `mon_ashen_warden` → its `# elite undead warden...` comment, etc.) — every monster's comment is already in the doc's §14b `MonsterDef` blocks and expanded-roster tables (§14b, `HollowHunter_Concept.md` lines ~635–905).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_content.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Run the full suite to check for regressions, then commit**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests still passing (adding a field doesn't change `monsters.size()` or any existing assertion).

```bash
git add content/monsters.json tests/unit/test_content.gd
git commit -m "§17 step 1: monster lore text (57 entries, sourced from §14b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 2: `HunterState.auto_equip_squad()`

**Files:**
- Modify: `core/hunter_state.gd` (new method, placed after the existing `auto_equip_shadow()`, currently at `core/hunter_state.gd:502-507`)
- Modify: `tests/unit/test_hunter_state.gd`

**Interfaces:**
- Consumes: existing `auto_equip_shadow(shadow_instance_id, equipment, monsters) -> int`.
- Produces: `auto_equip_squad(instance_ids: Array, equipment: Dictionary, monsters: Array) -> int` — consumed by Task 6 (`army_view.gd`'s Squad tab).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_hunter_state.gd`, near the existing gear tests:

```gdscript
func test_auto_equip_squad_equips_every_given_shadow() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	var b := s.claim_shadow("mon_carapax", "D")  # GUARDIAN
	var equipment := Content.load_equipment()
	s.add_to_inventory("eq_warcleaver")  # WARRIOR weapon, matches Ashen Warden
	var monsters := Content.load_monsters()
	var changed := s.auto_equip_squad(
		[a["instance_id"], b["instance_id"]], equipment, monsters
	)
	assert_true(changed > 0)
	assert_true(s.army[0]["equipped"].has("WEAPON"))


func test_auto_equip_squad_with_no_matching_gear_changes_nothing() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	var changed := s.auto_equip_squad([a["instance_id"]], Content.load_equipment(), Content.load_monsters())
	assert_eq(changed, 0)


func test_auto_equip_squad_skips_unknown_shadow_ids() -> void:
	var s := HunterState.new_default("WARRIOR")
	var changed := s.auto_equip_squad(["does_not_exist"], Content.load_equipment(), Content.load_monsters())
	assert_eq(changed, 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: FAIL — `auto_equip_squad` not defined.

- [ ] **Step 3: Write the minimal implementation**

In `core/hunter_state.gd`, after `auto_equip_shadow()`:

```gdscript
## Runs auto_equip_shadow() over every shadow instance_id given -- the
## Squad tab's "Auto-Equip Squad" action (§17 QoL: "auto-equip best gear...
## across the whole squad"). Unknown ids are silently skipped (same
## tolerance auto_equip_shadow's own _army_index lookup already has).
## Returns the total number of slots changed across all shadows.
func auto_equip_squad(instance_ids: Array, equipment: Dictionary, monsters: Array) -> int:
	var count := 0
	for instance_id in instance_ids:
		count += auto_equip_shadow(instance_id, equipment, monsters)
	return count
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: PASS, plus all pre-existing tests in the file still green.

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd tests/unit/test_hunter_state.gd
git commit -m "§17 step 2: HunterState.auto_equip_squad

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 3: Shadow detail hub — Family, Lore, Traits placeholder

**Files:**
- Modify: `scenes/shadow_gear_view.gd:200-227` (`refresh()`)
- Modify: `scenes/main.tscn` (new `LoreLabel` node under `GameUI/ShadowGearPanel`)

**Interfaces:**
- Consumes: `monster["family"]` (already loaded via `Content.monster_by_id`), the new `monster["lore"]` (Task 1).

- [ ] **Step 1: Add the `LoreLabel` node to `scenes/main.tscn`**

Insert right after the existing `SetsLabel` node block (currently `offset_top = 560.0` … `offset_bottom = 900.0`, ending the `GameUI/ShadowGearPanel` node list):

```
[node name="LoreLabel" type="Label" parent="GameUI/ShadowGearPanel"]
offset_left = 40.0
offset_top = 910.0
offset_right = 2380.0
offset_bottom = 1040.0
theme_override_font_sizes/font_size = 16
autowrap_mode = 3
text = ""
```

(`autowrap_mode = 3` = `TextServer.AUTOWRAP_WORD_SMART`, so lore text wraps inside the panel instead of overflowing.)

- [ ] **Step 2: Wire it and rewrite the identity line in `shadow_gear_view.gd`**

Add the `@onready` var alongside the existing ones:

```gdscript
@onready var lore_label: Label = $LoreLabel
```

In `refresh()`, replace the `title_label.text` assignment (currently lines 213-227) with:

```gdscript
	var family: String = monster.get("family", "?")
	title_label.text = (
		"%s%s%s (%s·%s Lv%d/%d %s · %s)  [%d/%d]"
		% [
			"★" if favorite else "",
			"🔒" if locked else "",
			monster.get("name", "?"),
			GameLogic.grade_name(shadow.get("grade", "")),
			shadow.get("grade", ""),
			shadow.get("level", 1),
			ShadowLeveling.LEVEL_CAP,
			monster.get("clazz", "?"),
			family,
			_index + 1,
			_state.army.size(),
		]
	)
	lore_label.text = (
		"%s\nTraits: (coming soon)" % String(monster.get("lore", ""))
	)
```

(Only the added `family` local, the `%s` for it in the format string, and the new `lore_label.text` line are new — everything else in that block is unchanged, shown in full so the diff context is unambiguous. The Traits line is the placeholder-only slot from design decision #3 — no real trait data exists yet.)

Also update the empty-army early return (currently lines 201-206) to clear it:

```gdscript
	if _state.army.is_empty():
		title_label.text = "No shadows yet"
		for row: Dictionary in _rows:
			row["label"].text = "%s: --" % row["slot"]
		sets_label.text = "Active sets: (none)"
		lore_label.text = ""
		return
```

- [ ] **Step 3: Manual verification**

Open Shadow Gear on an owned shadow (Godot editor or on-device). Confirm the identity line now shows `Family` after the class, and the lore/traits text renders below the sets line without overflowing the panel. Page through Prev/Next and confirm lore updates per-shadow.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn scenes/shadow_gear_view.gd
git commit -m "§17 step 3: shadow detail hub shows family + lore + traits placeholder

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 4: Squad tab gets an Auto-Equip Squad button

**Files:**
- Modify: `scenes/main.tscn` (new `AutoEquipSquadButton` under the current `SquadPanel`, before Task 5 renames/reparents it)
- Modify: `scenes/squad_view.gd`

**Interfaces:**
- Produces: new signal `auto_equip_squad_requested` — consumed by Task 6 (`army_view.gd`).

- [ ] **Step 1: Add the button node**

In `scenes/main.tscn`, inside the `GameUI/SquadPanel` node block, add (next to the existing `AutoFillButton`):

```
[node name="AutoEquipSquadButton" type="Button" parent="GameUI/SquadPanel"]
offset_left = 260.0
offset_top = 90.0
offset_right = 480.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 18
text = "Auto-Equip Squad"
```

(Match the existing `AutoFillButton`'s `offset_top`/height in that file — place this one immediately to its right.)

- [ ] **Step 2: Wire it in `scenes/squad_view.gd`**

Add the signal at the top, alongside the existing ones:

```gdscript
signal auto_equip_squad_requested
```

In `_ready()`, alongside the existing button connections:

```gdscript
	$AutoEquipSquadButton.pressed.connect(func() -> void: auto_equip_squad_requested.emit())
```

- [ ] **Step 3: Manual verification**

Open the Squad panel (still reachable via today's own Squad button at this point in the plan — Task 6 moves the entry point). Confirm the new button renders and is clickable (it won't do anything yet until Task 6 wires a listener — that's expected at this step).

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn scenes/squad_view.gd
git commit -m "§17 step 4: Squad tab gains an Auto-Equip Squad button (signal only, not yet wired)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 5: `army_view.gd` — the new screen shell (Roster + Squad tabs)

**Files:**
- Create: `scenes/army_view.gd`
- Modify: `scenes/main.tscn` — new `ArmyPanel` node tree; `SquadPanel` renamed to `SquadTab` and re-parented under it.

**Interfaces:**
- Consumes: `SquadBuilder.enrich_army()`, `SquadBuilder.auto_fill_squad()`, `SquadBuilder.resolve_party()`, `SquadBuilder.surplus_shadow_ids()` (all existing), `HunterState.auto_equip_squad()` (Task 2), `HunterState.mass_convert()`/`toggle_party_member()`/`active_party_ids` (existing), `GameLogic.RANK_ORDER`, `GameLogic.SQUAD_SIZE`, `SquadBuilder.CLASSES` (existing consts), `ShadowGearView.open()`/`bind()` (existing, unchanged).
- Produces: `signal state_changed` (same convention as every other self-contained controller) and `func bind(state: HunterState, equipment: Dictionary, monsters: Array, shadow_gear_view: ShadowGearView) -> void` / `func open() -> void` — consumed by Task 7 (`main.gd`).

- [ ] **Step 1: Build the `ArmyPanel` node tree in `scenes/main.tscn`**

First, rename the existing `SquadPanel` node to `SquadTab` and change its `parent` from `GameUI` to `GameUI/ArmyPanel` (a plain find/replace of that one node's `name`/`parent` attributes — its own children and script (`ExtResource("4")`) stay exactly as they are; `squad_view.gd`'s `$CloseButton`/`$AutoFillButton`/etc. lookups are relative to this node, so they keep working unchanged after the move).

Then insert the new `ArmyPanel` node block (with `SquadTab` now nested under it) in place of where `SquadPanel` used to sit at the top level:

```
[node name="ArmyPanel" type="Node2D" parent="GameUI"]
visible = false
script = ExtResource("<next available id>")

[node name="Bg" type="ColorRect" parent="GameUI/ArmyPanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 2424.0
offset_bottom = 1080.0
color = Color(0.05, 0.05, 0.05, 0.95)

[node name="RosterTabButton" type="Button" parent="GameUI/ArmyPanel"]
offset_left = 40.0
offset_top = 20.0
offset_right = 260.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Roster"

[node name="SquadTabButton" type="Button" parent="GameUI/ArmyPanel"]
offset_left = 280.0
offset_top = 20.0
offset_right = 500.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Squad"

[node name="CloseButton" type="Button" parent="GameUI/ArmyPanel"]
offset_left = 2260.0
offset_top = 20.0
offset_right = 2380.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Close"

[node name="RosterTab" type="Node2D" parent="GameUI/ArmyPanel"]

[node name="FilterBar" type="Node2D" parent="GameUI/ArmyPanel/RosterTab"]
position = Vector2(0, 90)

[node name="GradeFilterButton" type="Button" parent="GameUI/ArmyPanel/RosterTab/FilterBar"]
offset_left = 40.0
offset_top = 0.0
offset_right = 260.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Grade: ALL"

[node name="SortButton" type="Button" parent="GameUI/ArmyPanel/RosterTab/FilterBar"]
offset_left = 280.0
offset_top = 0.0
offset_right = 500.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Sort: Power"

[node name="Sections" type="Node2D" parent="GameUI/ArmyPanel/RosterTab"]
position = Vector2(0, 160)

[node name="BulkBar" type="Node2D" parent="GameUI/ArmyPanel/RosterTab"]
position = Vector2(0, 900)

[node name="MassConvertButton" type="Button" parent="GameUI/ArmyPanel/RosterTab/BulkBar"]
offset_left = 40.0
offset_top = 0.0
offset_right = 460.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Mass-Convert Weakest 3"
```

(Use `ExtResource` numbering consistent with however many `ExtResource` ids already exist in the file at this point — check the file's own `[ext_resource ...]` header block and add the next free index for `army_view.gd`, same as every other panel script reference in this file.)

- [ ] **Step 2: Write `scenes/army_view.gd`**

```gdscript
class_name ArmyView
extends Node2D
## §17: the Army management screen. Roster tab (class-grouped, sortable/
## filterable browse over the whole owned army) and Squad tab (the existing
## squad-of-6 picker, squad_view.gd, absorbed here unchanged bar one new
## button) in one panel. Self-contained controller -- holds HunterState
## directly and mutates it itself, same pattern as StrongholdView/
## CharacterView -- replaces the old standalone ShadowGearButton/
## SquadButton/MassConvertButton entry points and the flat ArmyLabel text.
##
## Deliberately does NOT open or reference an inventory screen anywhere --
## that's §17b, a later, separate build.

signal state_changed

const GRADE_FILTER_OPTIONS := ["ALL", "E", "D", "C", "B", "A", "S"]
const SORT_MODES := ["power", "grade"]
const MASS_CONVERT_COUNT := 3  ## same v0 batch size main.gd used before this split

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _shadow_gear_view: ShadowGearView
var _grade_filter: String = "ALL"
var _sort_mode: String = "power"
var _collapsed: Dictionary = {}  ## clazz -> bool, session-only (resets on reopen)

@onready var roster_tab: Node2D = $RosterTab
@onready var squad_tab: SquadView = $SquadTab
@onready var grade_filter_button: Button = $RosterTab/FilterBar/GradeFilterButton
@onready var sort_button: Button = $RosterTab/FilterBar/SortButton
@onready var sections_container: Node2D = $RosterTab/Sections
@onready var mass_convert_button: Button = $RosterTab/BulkBar/MassConvertButton


func _ready() -> void:
	$RosterTabButton.pressed.connect(_on_roster_tab_pressed)
	$SquadTabButton.pressed.connect(_on_squad_tab_pressed)
	$CloseButton.pressed.connect(func() -> void: visible = false)
	grade_filter_button.pressed.connect(_on_grade_filter_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	mass_convert_button.pressed.connect(_on_mass_convert_pressed)
	squad_tab.close_requested.connect(func() -> void: visible = false)
	squad_tab.auto_fill_requested.connect(_on_squad_auto_fill_requested)
	squad_tab.toggle_requested.connect(_on_squad_toggle_requested)
	squad_tab.auto_equip_squad_requested.connect(_on_squad_auto_equip_requested)


func bind(
	state: HunterState, equipment: Dictionary, monsters: Array, shadow_gear_view: ShadowGearView
) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_shadow_gear_view = shadow_gear_view


func open() -> void:
	visible = true
	_on_roster_tab_pressed()


func _on_roster_tab_pressed() -> void:
	roster_tab.visible = true
	squad_tab.visible = false
	_refresh_roster()


func _on_squad_tab_pressed() -> void:
	roster_tab.visible = false
	squad_tab.visible = true
	_refresh_squad()


func _on_grade_filter_pressed() -> void:
	var idx := GRADE_FILTER_OPTIONS.find(_grade_filter)
	_grade_filter = GRADE_FILTER_OPTIONS[(idx + 1) % GRADE_FILTER_OPTIONS.size()]
	grade_filter_button.text = "Grade: %s" % _grade_filter
	_refresh_roster()


func _on_sort_pressed() -> void:
	var idx := SORT_MODES.find(_sort_mode)
	_sort_mode = SORT_MODES[(idx + 1) % SORT_MODES.size()]
	sort_button.text = "Sort: %s" % _sort_mode.capitalize()
	_refresh_roster()


## Builds one collapsible section per class, each holding that class's
## (filtered, sorted) shadows as tappable rows -- opens the shadow detail
## hub on tap, same panel the old flat ArmyLabel + ShadowGearButton used to
## reach separately. Rebuilds from scratch each call (Sections' children
## are freed first) rather than diffing -- this list changes rarely enough
## (claim/level/fuse/convert) that rebuild-on-refresh is simpler and cheap.
func _refresh_roster() -> void:
	for child in sections_container.get_children():
		child.queue_free()

	var enriched := SquadBuilder.enrich_army(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	if _grade_filter != "ALL":
		enriched = enriched.filter(
			func(e: Dictionary) -> bool: return e["grade"] == _grade_filter
		)
	var sort_key := "power" if _sort_mode == "power" else "grade"
	enriched.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if sort_key == "power":
				return a["power"] > b["power"]
			return GameLogic.RANK_ORDER.find(b["grade"]) < GameLogic.RANK_ORDER.find(a["grade"])
	)

	var y := 0.0
	for clazz in SquadBuilder.CLASSES:
		var class_shadows: Array = enriched.filter(
			func(e: Dictionary) -> bool: return e["clazz"] == clazz
		)
		var header := Button.new()
		header.position = Vector2(40, y)
		header.size = Vector2(2340, 44)
		var collapsed: bool = _collapsed.get(clazz, false)
		header.text = "%s %s (%d)" % ["▸" if collapsed else "▾", clazz.capitalize(), class_shadows.size()]
		sections_container.add_child(header)
		y += 50

		var row_start_y := y
		for e: Dictionary in class_shadows:
			var row := Button.new()
			row.position = Vector2(60, y)
			row.size = Vector2(2300, 40)
			var marker := " [L]" if e["locked"] else ""
			marker += " [F]" if e["favorite"] else ""
			row.text = (
				"%s (%s·%s Lv%d) pwr:%d%s"
				% [e["monster_name"], e["grade_name"], e["grade"], e["level"], e["power"], marker]
			)
			row.visible = not collapsed
			row.pressed.connect(_on_shadow_row_pressed.bind(e["instance_id"]))
			sections_container.add_child(row)
			y += 44
		header.pressed.connect(_on_section_header_pressed.bind(clazz, header, row_start_y, y))


func _on_section_header_pressed(clazz: String, header: Button, row_start_y: float, row_end_y: float) -> void:
	var collapsed: bool = not _collapsed.get(clazz, false)
	_collapsed[clazz] = collapsed
	header.text = header.text.replace("▾" if not collapsed else "▸", "▸" if collapsed else "▾")
	for child in sections_container.get_children():
		if child is Button and child.position.y >= row_start_y and child.position.y < row_end_y:
			child.visible = not collapsed


func _on_shadow_row_pressed(shadow_instance_id: String) -> void:
	_shadow_gear_view.open()
	# ShadowGearView.open() opens on whichever _index it last had -- jump it
	# to the tapped shadow before showing, same lookup shadow_gear_view's
	# own Prev/Next buttons use internally.
	var idx := _state.army.find_custom(
		func(s: Dictionary) -> bool: return s["instance_id"] == shadow_instance_id
	)
	if idx >= 0:
		_shadow_gear_view.jump_to_index(idx)


## Phase 2/P2 step 4 logic, moved here from main.gd unchanged (§17's
## "mass-convert weak shadows" QoL bullet) -- immediate, no confirmation,
## same as before this split.
func _on_mass_convert_pressed() -> void:
	var surplus := SquadBuilder.surplus_shadow_ids(
		_state.army, _monsters, _state.level, MASS_CONVERT_COUNT, _equipment, _state.inventory
	)
	if surplus.is_empty():
		return
	var gained := _state.mass_convert(surplus)
	_after_mutation()
	_refresh_roster()
	print("Mass-converted %d shadow(s) -> +%d Essence" % [surplus.size(), gained])


func _refresh_squad() -> void:
	var squad := SquadBuilder.auto_fill_squad(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	var chosen := SquadBuilder.resolve_party(
		_state.army, _monsters, _state.level, _state.active_party_ids, _equipment, _state.inventory
	)
	squad_tab.refresh(squad, _state.active_party_ids, chosen)


func _on_squad_auto_fill_requested() -> void:
	_state.active_party_ids = []
	_after_mutation()
	_refresh_squad()


func _on_squad_toggle_requested(instance_id: String) -> void:
	var fielded := _state.active_party_ids.has(instance_id)
	if not _state.toggle_party_member(instance_id, not fielded):
		return
	_after_mutation()
	_refresh_squad()


func _on_squad_auto_equip_requested() -> void:
	var squad := SquadBuilder.auto_fill_squad(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	var ids: Array = squad.map(func(m: Dictionary) -> String: return m["instance_id"])
	_state.auto_equip_squad(ids, _equipment, _monsters)
	_after_mutation()
	_refresh_squad()


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
```

**Note on `_on_mass_convert_pressed`'s `print(...)` line:** the old `main.gd` version wrote its result to the shared `label` (`"\n\nMass-converted..."`). This controller has no reference to that shared label by design (self-contained controllers don't reach back into `main.gd`'s UI — see `HunterGearView`'s own doc comment on this). Task 7 below restores that one-off message by having `main.gd` listen for it: replace the `print(...)` with `state_changed.emit()` only for now if a dedicated result-message signal feels like scope creep — **flag this to the user before implementing**: either (a) add a small `mass_convert_result(message: String)` signal here that `main.gd` forwards to `label.text`, matching `StrongholdView.collected`'s existing precedent, or (b) accept the message is silently dropped for this pass. Recommended: (a), it's a two-line addition and keeps user-visible feedback that already existed.

- [ ] **Step 3: Add `jump_to_index()` to `shadow_gear_view.gd`**

The row-tap handler above needs a way to open the hub on a *specific* shadow rather than wherever `_index` last was. Add, near `_on_next_pressed()`:

```gdscript
## Jumps directly to a known army index (e.g. from ArmyView's roster tap,
## which knows exactly which shadow was pressed) rather than only stepping
## via Prev/Next. Clamped the same way open()/refresh() already are.
func jump_to_index(index: int) -> void:
	if _state.army.is_empty():
		return
	_index = clampi(index, 0, _state.army.size() - 1)
	refresh()
```

- [ ] **Step 4: Manual verification**

Open the Army screen (once Task 7 wires its entry point — do Task 7 before verifying this step). Confirm: Roster tab shows 5 class sections, each collapsible; tapping a shadow row opens the Shadow Gear panel on that exact shadow; Grade/Sort buttons cycle and visibly reorder/filter the list; Mass-Convert Weakest 3 in the lower bulk bar still converts correctly. Switch to Squad tab: existing auto-fill/manual-toggle behavior unchanged; new Auto-Equip Squad button now actually equips best gear across the fielded squad.

- [ ] **Step 5: Commit**

```bash
git add scenes/army_view.gd scenes/main.tscn scenes/shadow_gear_view.gd
git commit -m "§17 step 5: army_view.gd -- Roster + Squad tabs, the new Army screen shell

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 6: Wire it into `main.gd`, remove what it replaced

**Files:**
- Modify: `scenes/main.gd`
- Modify: `scenes/main.tscn` (new `ArmyButton`, remove `ShadowGearButton`/`SquadButton`/`MassConvertButton`/`ArmyLabel`)

**Interfaces:**
- Consumes: `ArmyView.bind()`/`open()`/`state_changed` (Task 5).

- [ ] **Step 1: Replace the old HUD buttons in `scenes/main.tscn`**

Remove the `ShadowGearButton` (`scenes/main.tscn:120-126`), `MassConvertButton` (`:128-134`), `SquadButton` (`:168-174`), and `ArmyLabel` (`:192-198`) node blocks entirely (their behavior now lives inside `ArmyPanel`, built in Task 5). Add one new button in their place:

```
[node name="ArmyButton" type="Button" parent="GameUI"]
offset_left = 220.0
offset_top = 370.0
offset_right = 380.0
offset_bottom = 410.0
theme_override_font_sizes/font_size = 18
text = "Army"
```

- [ ] **Step 2: Update `scenes/main.gd`**

Remove: the `army_label`, `shadow_gear_button`, `mass_convert_button`, `squad_button`, `squad_view` `@onready` vars (lines 46, 50, 52, 62-63); the `shadow_gear_button`/`mass_convert_button`/`squad_button`/`squad_view` wiring in `_setup_gear_panels()` (lines 203-205, 216-219); `_on_squad_button_pressed()`, `_on_squad_auto_fill_requested()`, `_on_squad_toggle_requested()`, `_refresh_squad_view()`, `_on_shadow_gear_button_pressed()`, `_on_mass_convert_pressed()`, `_refresh_army_label()` in full (lines 587-619, 667-712, 765-784) — all of this logic now lives in `army_view.gd`.

Replace every call site of `_refresh_army_label()` (lines 179, 496, 782→removed with its function, 874, 891) with `army_view.refresh_if_open()` — add this one small public wrapper to `army_view.gd` from Task 5 so external callers (a gate win, a Nadir claim) can ask it to refresh without reaching into its tab-specific internals:

```gdscript
## Called by main.gd after any army-changing event (gate win, Nadir claim,
## Stronghold idle-XP) so the Roster tab doesn't show stale data if it's
## already open when the change happens.
func refresh_if_open() -> void:
	if visible and roster_tab.visible:
		_refresh_roster()
```

Add the new `@onready var army_button: Button = $GameUI/ArmyButton` and `@onready var army_view: ArmyView = $GameUI/ArmyPanel`. In `_start_game()`, alongside the other `.bind()` calls:

```gdscript
	army_view.bind(state, _equipment, _monsters, shadow_gear_view)
```

In `_setup_gear_panels()`, alongside the other panel wiring:

```gdscript
		army_button.pressed.connect(func() -> void: army_view.open())
		army_view.state_changed.connect(_on_state_changed)
```

(`_on_state_changed` already exists — same shared-HUD-refresh handler every other self-contained controller's `state_changed` already connects to.)

- [ ] **Step 3: Manual verification**

Full run-through: fresh save reaches the home screen with an "Army" button instead of separate Shadow Gear/Squad/Mass-Convert buttons; clearing a gate and claiming a shadow, then opening Army → Roster shows it in the right class section with correct power/grade immediately (no stale data); Squad tab's fielded party still flows into a real battle correctly (unchanged `_build_battle_party()` reads `state.active_party_ids` exactly as before).

- [ ] **Step 4: Run the full test suite, then commit**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests still passing — this task only touches `scenes/`, no `core/` change, so this is a pure regression check.

```bash
git add scenes/main.gd scenes/main.tscn scenes/army_view.gd
git commit -m "§17 step 6: wire ArmyView into main.gd, remove the screens it replaced

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

## Self-Review

**Spec coverage:** roster grouped by class with collapsible sections (Task 5), sort/filter by grade and power (Task 5), squad-of-6 fixed class slots with auto-optimize + manual tweak (already built, absorbed Task 5-6 + new Auto-Equip Squad Task 4/5), shadow detail hub identity/family/lore/traits (Task 3), auto-equip per-shadow (already built) and whole-squad (Task 2/5), mass-convert (moved, Task 5), lock/favorite (already built, markers shown in Task 5's rows), raid readiness readout (already built elsewhere, untouched, out of this plan's scope since nothing here changes it) — all covered.

**Placeholder scan:** one intentional, explicitly-flagged decision point left for the user in Task 5 (the mass-convert result-message signal) rather than a silent gap — flagged inline with a recommendation, not a "TODO."

**Type consistency:** `ArmyView.bind()`'s 4th parameter is typed `ShadowGearView`, matching the class that already exists; `auto_equip_squad`'s signature (`Array, Dictionary, Array`) matches how Task 5 calls it; `refresh_if_open()` is the one new public method external callers need and is named consistently everywhere it's referenced (Task 6).
