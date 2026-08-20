# Character-select preset system Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a permanent, 12-portrait preset picker to onboarding (before the
existing subclass picker), store the choice on `HunterState`, and display the
resulting rank-tier portrait on the Hunter/character screen.

**Architecture:** Pure data/logic (the `preset_id` field, its serialization
defaults, and the rank→art-stage mapping) lives in `core/` and is
GUT-tested. Art-path resolution and all UI (the new onboarding screen, the
character-screen portrait) live in `scenes/`, are engine-dependent, and are
manually verified — the same split every other screen in this project
follows.

**Tech Stack:** Godot 4.7.1 (mono), GDScript, GUT test framework.

## Global Constraints

- Static typing everywhere (`var x: Type = ...`, `func f(x: Type) -> Type:`).
- Tabs for indentation. `snake_case` for files/vars/functions, `PascalCase`
  for classes/nodes.
- `core/` stays pure GDScript — no `Node`, no scene tree, no engine calls.
  Every `core/` change needs a matching GUT test.
- `scenes/` stays thin view code — no game rules, manually verified (no
  GUT test), following the existing `SubclassPicker`/`ArtPaths` precedent.
- The 12 preset ids, in order, are exactly:
  `["f1", "f2", "f3", "f4", "f5", "f6", "m1", "m2", "m3", "m4", "m5", "m6"]`.
- The three art stages, in rank order, are exactly:
  `"early"` (ranks E, D), `"mid"` (ranks C, B), `"late"` (ranks A, S).
- Old-save / no-arg default preset id is exactly `"m1"` throughout (field
  default, `new_default()` default arg, `from_dict()` fallback,
  `load_or_create()` default arg) — one fixed value, never blank.
- Art files already exist at
  `res://art/presets/preset_hunter_<id>_<stage>.png` for all 12×3
  combinations — this plan does not create or edit any art file.
- `gdformat`/`gdlint` run automatically via the post-edit hook — do not
  hand-format around them.
- `tests/unit/test_hunter_state.gd` is already at gdlint's
  `max-public-methods: 120` ceiling (exactly 120 test functions as of this
  plan). Any new `HunterState` tests MUST go in a new file
  `tests/unit/test_hunter_state_preset.gd`, following the existing split
  precedent (`test_hunter_state_inventory.gd`, `test_hunter_state_shop.gd`)
  — do not add test functions to `test_hunter_state.gd` itself.

---

### Task 1: `GameLogic.stage_for_rank()` — rank-to-art-stage mapping

**Files:**
- Modify: `core/game_logic.gd` (add function near `RANK_ORDER`, which is
  declared as `const RANK_ORDER := ["E", "D", "C", "B", "A", "S"]`)
- Test: `tests/unit/test_game_logic.gd`

**Interfaces:**
- Produces: `GameLogic.stage_for_rank(rank: String) -> String`, returning
  `"early"`, `"mid"`, or `"late"`. Used by Task 5 (`CharacterView`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_game_logic.gd` (place near the existing
`test_rank_for_level` test for locality):

```gdscript
func test_stage_for_rank_early_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("E"), "early")
	assert_eq(GameLogic.stage_for_rank("D"), "early")


func test_stage_for_rank_mid_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("C"), "mid")
	assert_eq(GameLogic.stage_for_rank("B"), "mid")


func test_stage_for_rank_late_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("A"), "late")
	assert_eq(GameLogic.stage_for_rank("S"), "late")


func test_stage_for_rank_unknown_falls_back_to_early() -> void:
	assert_eq(GameLogic.stage_for_rank("Z"), "early")
```

- [ ] **Step 2: Run tests to verify they fail**

Run the project's GUT suite (headless Godot run, same invocation used
earlier in this project) and confirm these four new tests fail with
"function not found" / parse error, and no other test's pass count changed.

- [ ] **Step 3: Implement `stage_for_rank()`**

Add to `core/game_logic.gd`, near `RANK_ORDER`:

```gdscript
## §9b/§25: maps an earned hunter_rank to one of the three preset-portrait
## art stages (art/presets/preset_hunter_<id>_<stage>.png). Unknown input
## falls back to "early" rather than erroring, same degrade-gracefully
## convention as grade_name()/essence_for_gate() elsewhere in this file.
static func stage_for_rank(rank: String) -> String:
	if rank == "C" or rank == "B":
		return "mid"
	if rank == "A" or rank == "S":
		return "late"
	return "early"
```

- [ ] **Step 4: Run tests to verify they pass**

Run the GUT suite again. All four new tests pass; total pass count is
exactly 4 higher than before this task, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/game_logic.gd tests/unit/test_game_logic.gd
git commit -m "Preset system: GameLogic.stage_for_rank() rank->art-stage mapping"
```

---

### Task 2: `HunterState.preset_id` field + serialization

**Files:**
- Modify: `core/hunter_state.gd` (var declaration near `hunter_rank`,
  `new_default()`, `to_dict()`, `from_dict()`)
- Modify: `autoload/save_service.gd` (`load_or_create()`)
- Test: create `tests/unit/test_hunter_state_preset.gd` (new file — see
  Global Constraints on why this can't go in `test_hunter_state.gd`)

**Interfaces:**
- Produces: `HunterState.preset_id: String`; `HunterState.new_default(hunter_subclass: String = "WARRIOR", hunter_preset: String = "m1") -> HunterState`;
  `SaveService.load_or_create(default_subclass: String = "WARRIOR", default_preset: String = "m1") -> HunterState`.
  Consumed by Task 4 (onboarding writes `_pending_preset_id` through
  `load_or_create`) and Task 5 (`CharacterView` reads `_state.preset_id`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_hunter_state_preset.gd`:

```gdscript
extends GutTest
## Tests for HunterState's preset_id field (character-select preset
## system) -- split into its own file because test_hunter_state.gd is
## already at gdlint's max-public-methods ceiling (120), same precedent
## as test_hunter_state_inventory.gd / test_hunter_state_shop.gd.


func test_new_default_sets_preset_from_arg() -> void:
	var s := HunterState.new_default("WARRIOR", "f3")
	assert_eq(s.preset_id, "f3")


func test_new_default_preset_defaults_to_m1() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.preset_id, "m1")


func test_preset_id_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR", "f6")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.preset_id, "f6")


func test_from_dict_defaults_preset_id_to_m1_for_old_saves() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.preset_id, "m1")
```

- [ ] **Step 2: Run tests to verify they fail**

Run the GUT suite; confirm all four new tests fail (missing `preset_id` /
wrong arity on `new_default`), no other tests regress.

- [ ] **Step 3: Implement the field and serialization**

In `core/hunter_state.gd`:

1. Add the field declaration near `hunter_rank` (same section of the file,
   following the existing doc-comment style on neighboring vars):

```gdscript
var preset_id: String  ## §9b/§25: the 12 curated preset-hunter portraits
## (art/HollowHunter_ArtDropTool.html's PRESET_IDS -- "f1".."f6"/"m1"..
## "m6"). Picked once during onboarding, permanent -- same no-respec
## precedent as subclass (§21). Combined with GameLogic.stage_for_rank()
## to resolve the rank-appropriate portrait via
## ArtPaths.preset_portrait().
```

2. Change the `new_default()` signature and body:

```gdscript
static func new_default(hunter_subclass: String = "WARRIOR", hunter_preset: String = "m1") -> HunterState:
	var s := HunterState.new()
	s.level = 1
	s.exp_into_level = 0
	s.total_exp = 0
	s.subclass = hunter_subclass
	s.essence = 0
	s.gate_tickets = 0
	s.army = []
	s.last_exp_date = ""
	s.inventory = []
	s.next_inventory_id = 0
	s.equipped = {}
	s.nadir_deepest_floor = 0
	s.stronghold_level = 1
	s.stronghold_facilities = _default_facilities()
	s.stronghold_last_collected = 0
	s.current_streak = 0
	s.hunter_rank = "E"
	s.last_gate_break_offer = 0
	s.active_party_ids = []
	s.crystals = 0
	s.owned_cosmetics = []
	s.preset_id = hunter_preset
	return s
```

3. Add `"preset_id": preset_id,` to the dictionary literal in `to_dict()`
   (any position is fine; append after `"owned_cosmetics": owned_cosmetics,`
   for locality with the newest existing field).

4. Add `s.preset_id = String(d.get("preset_id", "m1"))` to `from_dict()`
   (append after the existing `s.owned_cosmetics = ...` line).

In `autoload/save_service.gd`, change `load_or_create()`:

```gdscript
func load_or_create(default_subclass: String = "WARRIOR", default_preset: String = "m1") -> HunterState:
	if not FileAccess.file_exists(SAVE_PATH):
		var fresh := HunterState.new_default(default_subclass, default_preset)
		save(fresh)
		return fresh

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error(
			(
				"SaveService: failed to open %s for read (%s)"
				% [SAVE_PATH, FileAccess.get_open_error()]
			)
		)
		return HunterState.new_default(default_subclass, default_preset)

	var text := f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("SaveService: %s did not contain valid JSON, using a fresh default" % SAVE_PATH)
		return HunterState.new_default(default_subclass, default_preset)

	return HunterState.from_dict(data)
```

(Only the two `new_default(...)` call signatures and the `func` line
change; the rest of the function body is unchanged — shown in full only so
the diff is unambiguous.)

- [ ] **Step 4: Run tests to verify they pass**

Run the GUT suite. All four new tests pass; total pass count is exactly 4
higher than after Task 1; 0 failures anywhere (in particular, confirm no
existing `HunterState`/`SaveService` test broke from the new default arg).

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd autoload/save_service.gd tests/unit/test_hunter_state_preset.gd
git commit -m "Preset system: HunterState.preset_id field + serialization"
```

---

### Task 3: `ArtPaths` preset-art resolution

**Files:**
- Modify: `scenes/art_paths.gd`

**Interfaces:**
- Consumes: nothing new (existing file/class).
- Produces: `ArtPaths.PRESET_IDS: Array` (12 fixed strings, exact order
  given in Global Constraints); `ArtPaths.preset_portrait(preset_id: String, stage: String) -> Texture2D`.
  Consumed by Task 4 (onboarding grid) and Task 5 (`CharacterView`).

No test file — `scenes/` convention, matches this file's three existing
functions (`monster_portrait`, `equipment_icon`, `set_showcase`), none of
which have GUT tests.

- [ ] **Step 1: Add the constant and function**

Add to `scenes/art_paths.gd`, after the `class_name ArtPaths` line and its
doc comment, before the first `static func`:

```gdscript
## §9b/§25: the 12 curated preset-hunter ids, exactly matching
## art/HollowHunter_ArtDropTool.html's PRESET_IDS constant -- single
## source of truth the onboarding preset-picker screen (scenes/main.gd)
## loops over to build its grid, rather than duplicating this list there.
const PRESET_IDS := ["f1", "f2", "f3", "f4", "f5", "f6", "m1", "m2", "m3", "m4", "m5", "m6"]
```

Add a fourth resolver function, following the existing three exactly:

```gdscript
static func preset_portrait(preset_id: String, stage: String) -> Texture2D:
	var path := "res://art/presets/preset_hunter_%s_%s.png" % [preset_id, stage]
	return load(path) if ResourceLoader.exists(path) else null
```

- [ ] **Step 2: Manually verify**

Open the Godot editor (or run a headless `--check-only`/parse pass) and
confirm `scenes/art_paths.gd` has no parse errors. No runtime check is
possible in isolation yet — Task 4 and Task 5 exercise this function for
real; this step just confirms the file is syntactically sound before other
tasks depend on it.

- [ ] **Step 3: Commit**

```bash
git add scenes/art_paths.gd
git commit -m "Preset system: ArtPaths.preset_portrait() art-path resolution"
```

---

### Task 4: Onboarding — `PresetPicker` screen

**Files:**
- Modify: `scenes/main.tscn` (add `PresetPicker` node tree)
- Modify: `scenes/main.gd` (`_ready()`, new `_show_preset_picker()`/
  `_on_preset_chosen()`, `_on_subclass_chosen()`'s `load_or_create` call)

**Interfaces:**
- Consumes: `ArtPaths.PRESET_IDS`, `ArtPaths.preset_portrait()` (Task 3);
  `SaveService.load_or_create(default_subclass, default_preset)` (Task 2).
- Produces: nothing consumed by a later task in this plan (this is the
  onboarding entry point).

No test file — `scenes/` convention; this is manually verified by running
the game as a brand-new hunter (no existing `user://save.json`), same as
`SubclassPicker` has no GUT test today.

- [ ] **Step 1: Add the `PresetPicker` node tree to `main.tscn`**

In `scenes/main.tscn`, add a new top-level node as a sibling of
`SubclassPicker` (same parent, `.`), placed immediately before the
`SubclassPicker` block:

```
[node name="PresetPicker" type="Node2D" parent="."]

[node name="TitleLabel" type="Label" parent="PresetPicker"]
offset_left = 40.0
offset_top = 40.0
offset_right = 900.0
offset_bottom = 100.0
theme_override_font_sizes/font_size = 32
text = "Choose your hunter."

[node name="Grid" type="GridContainer" parent="PresetPicker"]
offset_left = 40.0
offset_top = 120.0
offset_right = 2000.0
offset_bottom = 900.0
columns = 6
```

(`Grid` starts empty — `main.gd` populates its 12 buttons at runtime, same
pattern `inventory_view.gd`'s `Grid`/`GridContainer` already uses.)

- [ ] **Step 2: Wire `main.gd`**

Add two `@onready` vars near the existing `subclass_picker`/
`subclass_title_label` declarations:

```gdscript
@onready var preset_picker: Node2D = $PresetPicker
@onready var preset_grid: GridContainer = $PresetPicker/Grid
```

Add a new instance var near the top of the script (wherever other plain
`var` state like `_gps_status` is declared):

```gdscript
var _pending_preset_id: String = "m1"  ## Holds the onboarding preset pick
## between the PresetPicker and SubclassPicker screens -- no HunterState
## exists yet at pick time (created in _on_subclass_chosen()), same reason
## subclass itself isn't stored until then.
```

Change the `is_new_hunter` branch inside `_ready()` from:

```gdscript
	else:
		_show_subclass_picker()
```

to:

```gdscript
	else:
		_show_preset_picker()
```

Add two new functions, placed immediately before `_show_subclass_picker()`
for reading order (onboarding happens preset → subclass):

```gdscript
## First onboarding screen for a genuinely new hunter (§25) -- picking a
## preset portrait happens before the subclass picker. Builds the 12-cell
## grid at runtime from ArtPaths.PRESET_IDS rather than hardcoding 12
## .tscn button nodes, same dynamic-cell-into-GridContainer pattern
## inventory_view.gd already uses for its equipment grid.
func _show_preset_picker() -> void:
	preset_picker.visible = true
	subclass_picker.visible = false
	game_ui.visible = false
	for preset_id in ArtPaths.PRESET_IDS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 160)
		button.icon = ArtPaths.preset_portrait(preset_id, "early")
		button.pressed.connect(_on_preset_chosen.bind(preset_id))
		preset_grid.add_child(button)


## Permanent pick (§21 no-respec precedent) -- stored for
## _on_subclass_chosen() to pass into SaveService.load_or_create() once
## the HunterState is actually created.
func _on_preset_chosen(preset_id: String) -> void:
	_pending_preset_id = preset_id
	preset_picker.visible = false
	_show_subclass_picker()
```

Change `_on_subclass_chosen()`'s existing line:

```gdscript
	state = SaveService.load_or_create(subclass)
```

to:

```gdscript
	state = SaveService.load_or_create(subclass, _pending_preset_id)
```

No other line in `_on_subclass_chosen()` or anything after it changes.

- [ ] **Step 3: Manually verify**

Run the game with no existing save file (delete/rename
`user://save.json` if one exists in the dev environment, or run in a fresh
export). Confirm:
- `PresetPicker` shows first, with a 6-column grid of 12 tappable
  portrait buttons and no `SubclassPicker`/`GameUI` visible.
- Tapping any portrait hides `PresetPicker` and shows the existing
  `SubclassPicker` exactly as before this change.
- Completing subclass selection and the guided-gate flow proceeds exactly
  as it did before this task (this plan does not touch anything from
  `_on_subclass_chosen()`'s starter-shadow line onward).
- An existing save (an already-onboarded hunter) still boots straight into
  `GameUI` with neither picker shown, unchanged from before this task.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "Preset system: onboarding PresetPicker screen"
```

---

### Task 5: Character screen — portrait display

**Files:**
- Modify: `scenes/main.tscn` (add `PortraitRect` to `GameUI/CharacterPanel`)
- Modify: `scenes/character_view.gd` (`refresh()`, class doc comment)

**Interfaces:**
- Consumes: `_state.preset_id` (Task 2), `GameLogic.stage_for_rank()`
  (Task 1), `ArtPaths.preset_portrait()` (Task 3).
- Produces: nothing consumed elsewhere in this plan (terminal task).

No test file — `scenes/` convention, matches the rest of `character_view.gd`
(no existing GUT test file for it).

- [ ] **Step 1: Add `PortraitRect` to `main.tscn`**

In `scenes/main.tscn`, add a new `TextureRect` node under
`GameUI/CharacterPanel`, placed after the existing `TrialButton` node in
that block:

```
[node name="PortraitRect" type="TextureRect" parent="GameUI/CharacterPanel"]
offset_left = 1500.0
offset_top = 170.0
offset_right = 2380.0
offset_bottom = 900.0
expand_mode = 1
stretch_mode = 5
```

(`expand_mode = 1` is Godot 4's `TextureRect.EXPAND_IGNORE_SIZE`,
`stretch_mode = 5` is `TextureRect.STRETCH_KEEP_ASPECT_CENTERED` — the
same two settings `inventory_view.gd`'s set-showcase `TextureRect` already
applies via code; `.tscn` serializes enum properties as their raw integer
ordinal, which is what's written above.)

- [ ] **Step 2: Wire `character_view.gd`**

Add an `@onready` var alongside the existing ones:

```gdscript
@onready var portrait_rect: TextureRect = $PortraitRect
```

In `refresh()`, add one line — placed right after the `var stats := _state.stats()`
line at the top of the function, since it's a per-refresh read of `_state`
like everything else there:

```gdscript
	portrait_rect.texture = ArtPaths.preset_portrait(
		_state.preset_id, GameLogic.stage_for_rank(_state.hunter_rank)
	)
```

Update the class doc comment (currently ending with the line about
`refresh()`having "No hunter render/rank-glow art -- text only, same
placeholder-art convention as the rest of this project's UI."). Replace
that sentence with:

```
## Shows the chosen preset portrait (ArtPaths.preset_portrait(), keyed by
## the hunter's rank-derived art stage via GameLogic.stage_for_rank()) --
## no rank-glow/aura overlay or equipment paper-doll yet (§9b flags both
## as later work), so the portrait itself is still placeholder-simple.
```

- [ ] **Step 3: Manually verify**

Run the game with an onboarded hunter (a save with a `preset_id` set from
Task 4's flow, or an old save that now defaults to `"m1"` per Task 2).
Open the Hunter/character screen and confirm:
- The portrait renders in the panel's right-hand area without overlapping
  `InfoLabel`/`FitnessLabel`/`HealthStatusLabel`/`TrialButton`.
- If a save/tool is available to change `hunter_rank` (e.g. via the
  Rank-Up Trial flow already in this screen, or a temporary debug edit),
  confirm the portrait's art changes when rank crosses an
  early/mid/late boundary (e.g. D→C should visibly change the image).
- An old save with no `preset_id` in its JSON shows the `"m1"` portrait
  rather than a blank/missing texture.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn scenes/character_view.gd
git commit -m "Preset system: display preset portrait on the Hunter screen"
```

---

## Post-plan checklist

- [ ] Full GUT suite green (`core/` additions from Tasks 1-2 add exactly 8
      new passing tests; no regressions).
- [ ] `gdformat`/`gdlint` clean on every touched file (should already be
      true from the per-edit hook, but confirm on the whole diff at the
      end).
- [ ] Manual walkthrough: brand-new hunter sees PresetPicker → SubclassPicker
      → free starter shadow → guided gate → CLAIM, in that order, unchanged
      except for the new first screen.
- [ ] Manual walkthrough: Hunter/character screen shows the picked preset's
      portrait, correct stage for current rank.
