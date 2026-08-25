# Tap-to-Marker POI Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-visible `Enter Nearest Gate`/`Claim Sanctuary`/`Lore Stone` buttons with direct marker taps on the map — tapping a gate enters that gate, tapping a Sanctuary/Lore Stone opens a small popup card with its status and an action button, tapping the Stronghold marker opens the existing Stronghold panel.

**Architecture:** A pure closest-marker-selection algorithm goes into `core/map_geometry.gd` (tested). `scenes/map_view.gd` gathers each visible marker's on-screen position/tap-radius and delegates to it from a new `hit_test_marker()`, wired into `_unhandled_input()` behind two new signals. `scenes/main.gd` reacts to those signals: gates act immediately (reusing the exact existing battle-start code), Sanctuary/Lore Stone show a new `MarkerCard` scene node computing the same range/cooldown/discovery state the old buttons checked, and Stronghold opens `stronghold_view` directly. No gameplay-rule changes — this is entirely an input/presentation rework.

**Tech Stack:** Godot 4.7.1 mono, GDScript, GUT (for the one new `core/` function only).

## Global Constraints

- `core/` stays pure (no `Node`, no engine calls) and gets a GUT test per new function; `scenes/` stays thin and is manually/on-device verified only — see `CLAUDE.md`'s folder-layout table. No exceptions in this plan.
- Gates keep their existing proximity-free rule (spec: "Interaction model" — tap only changes *which* gate, not whether you can reach it). Do not add a distance check to gate entry.
- Sanctuary/Lore Stone keep their exact existing rules unchanged: `GameLogic.POI_PROXIMITY_RADIUS_M` proximity radius, `state.claim_sanctuary(...)`/`state.discover_lorestone(...)`'s existing cooldown/discovery logic. No `core/hunter_state.gd` or `core/game_logic.gd` changes anywhere in this plan.
- The action button's status-label messages must be byte-for-byte identical to what the old buttons already printed (e.g. `"\n\nSanctuary claimed: +%d Essence, +%d Gate Ticket"`) — this is a rework of *how* the action is triggered, not what it says.
- Any new UI node added as a sibling of `MapView` under `GameUI` MUST set `z_index = 1` (or inherit it), exactly like `GameUI/Label` already does. `MapView._draw_map_geometry()` opens with an opaque full-screen background rect every frame; without `z_index = 1` a new sibling silently renders *behind* it — this is the exact bug fixed earlier this session for the status label. `MarkerCard` in Task 3 must not reintroduce it.
- Static typing everywhere, tabs for indentation, `gdformat`/`gdlint` clean (enforced automatically by the post-edit hook on `.gd` files — not on `.tscn`).
- The nav-bar `Stronghold` button and everything inside `stronghold_view.gd`'s panel (Collect/Assign/Unassign/Upgrade, its own proximity gate) are unchanged by this plan.

---

### Task 1: Pure closest-marker selection in `core/map_geometry.gd`

**Files:**
- Modify: `core/map_geometry.gd` (append after `rect_intersects`, currently the last function in the file)
- Test: `tests/unit/test_map_geometry.gd` (append after the existing tests)

**Interfaces:**
- Consumes: nothing new — pure `Vector2`/`Dictionary`/`Array` only.
- Produces: `MapGeometry.closest_marker_within_radius(tap_pos: Vector2, candidates: Array) -> Dictionary`, used by Task 2's `MapView.hit_test_marker()`. Each candidate is a `Dictionary` with at least `"screen_pos": Vector2` and `"radius": float`; any other keys (e.g. `"type"`, `"index"`) are opaque to this function and returned untouched on the winning candidate. Returns `{}` if no candidate qualifies.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_map_geometry.gd`:

```gdscript
func test_closest_marker_within_radius_returns_only_candidate_when_within_range() -> void:
	var candidates := [{"screen_pos": Vector2(100, 100), "radius": 30.0, "type": "gate"}]
	var hit := MapGeometry.closest_marker_within_radius(Vector2(105, 100), candidates)
	assert_eq(hit["type"], "gate")


func test_closest_marker_within_radius_returns_empty_when_out_of_range() -> void:
	var candidates := [{"screen_pos": Vector2(100, 100), "radius": 30.0, "type": "gate"}]
	var hit := MapGeometry.closest_marker_within_radius(Vector2(200, 200), candidates)
	assert_eq(hit, {})


func test_closest_marker_within_radius_returns_empty_for_no_candidates() -> void:
	var hit := MapGeometry.closest_marker_within_radius(Vector2(0, 0), [])
	assert_eq(hit, {})


func test_closest_marker_within_radius_picks_nearer_of_two_candidates() -> void:
	var candidates := [
		{"screen_pos": Vector2(100, 100), "radius": 50.0, "type": "a"},
		{"screen_pos": Vector2(110, 100), "radius": 50.0, "type": "b"},
	]
	# tap at (102, 100): 2px from "a", 8px from "b" -- "a" is nearer.
	var hit := MapGeometry.closest_marker_within_radius(Vector2(102, 100), candidates)
	assert_eq(hit["type"], "a")


func test_closest_marker_within_radius_ignores_candidate_outside_its_own_radius() -> void:
	var candidates := [
		# geometrically nearer to the tap (10px away) but outside its own 5px radius
		{"screen_pos": Vector2(100, 100), "radius": 5.0, "type": "small"},
		# farther away (40px) but within its own larger 60px radius
		{"screen_pos": Vector2(150, 100), "radius": 60.0, "type": "large"},
	]
	var hit := MapGeometry.closest_marker_within_radius(Vector2(110, 100), candidates)
	assert_eq(hit["type"], "large")


func test_closest_marker_within_radius_preserves_extra_keys_on_winner() -> void:
	var candidates := [{"screen_pos": Vector2(0, 0), "radius": 10.0, "type": "lorestone", "index": 7}]
	var hit := MapGeometry.closest_marker_within_radius(Vector2(0, 0), candidates)
	assert_eq(hit["type"], "lorestone")
	assert_eq(hit["index"], 7)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_map_geometry.gd -gexit`

Expected: FAIL — `closest_marker_within_radius` doesn't exist yet ("Nonexistent function" or similar).

- [ ] **Step 3: Implement**

Append to `core/map_geometry.gd`, after `rect_intersects`:

```gdscript
## Given a tap point and a list of candidate markers (each a Dictionary with
## at least "screen_pos": Vector2 and "radius": float, plus whatever other
## keys the caller wants carried through untouched -- e.g. "type"/"index"),
## returns whichever candidate's screen_pos is closest to tap_pos among all
## candidates within their OWN radius of it, or {} if none qualify. Ties
## (exact equal distance) resolve to whichever candidate appears earlier in
## the array. Used by scenes/map_view.gd's hit_test_marker() -- kept here,
## not there, because "which marker did this tap land on" is a pure
## geometric decision with no engine dependency, same reasoning as every
## other function in this file.
static func closest_marker_within_radius(tap_pos: Vector2, candidates: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for candidate: Dictionary in candidates:
		var dist: float = tap_pos.distance_to(candidate["screen_pos"])
		if dist <= candidate["radius"] and dist < best_dist:
			best_dist = dist
			best = candidate
	return best
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_map_geometry.gd -gexit`

Expected: PASS — all tests in the file, old and new, green.

- [ ] **Step 5: Run the full suite to confirm nothing else broke**

Run: `"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS — full suite green (511/511: 505 existing + 6 new).

- [ ] **Step 6: Commit**

```bash
git add core/map_geometry.gd tests/unit/test_map_geometry.gd
git commit -m "feat: add MapGeometry.closest_marker_within_radius for tap-to-marker hit testing"
```

---

### Task 2: `hit_test_marker()` + tap signals in `scenes/map_view.gd`

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `MapGeometry.closest_marker_within_radius(tap_pos: Vector2, candidates: Array) -> Dictionary` from Task 1. Reads existing `_gates`/`_sanctuaries`/`_lorestones`/`_stronghold_placed`/`_stronghold_lat`/`_stronghold_lon`/`_has_pending_stronghold`/`_zoom_px_per_m`/`_placement_mode`/`_active_touches`, and existing methods `_project()`, `_world_to_screen()`, `to_local()`, `to_global()`. Existing consts `GATE_MARKER_SIZE`, `SANCTUARY_MARKER_SIZE`, `LORESTONE_MARKER_SIZE`, `STRONGHOLD_MARKER_SIZE`, `DEFAULT_ZOOM_PX_PER_M`.
- Produces: `MapView.hit_test_marker(screen_pos: Vector2) -> Dictionary` returning `{"type": "gate"|"sanctuary"|"lorestone"|"stronghold", "index": int, "screen_pos": Vector2}` (index `-1` for `"stronghold"`) or `{}`. `screen_pos` in the *returned* dict is in **global/viewport** coordinates (via `to_global()`) — this is what Task 3's `main.gd` needs to position `MarkerCard`, a `GameUI`-level Control. Two new signals: `marker_tapped(info: Dictionary)` and `map_tapped_empty`, both consumed by Task 3.

- [ ] **Step 1: Add the tap-tolerance constant**

In `scenes/map_view.gd`, add after `STRONGHOLD_MARKER_SIZE` (around line 28):

```gdscript
const TAP_TOLERANCE_PX := 16.0  ## extra hit-test radius beyond a marker's own
## on-screen half-size, so small icons stay comfortably tappable with a
## finger without the icon itself needing to grow.
```

- [ ] **Step 2: Add the two new signals**

Near the top of the file, after the class doc comment and before the `const` block (or alongside any existing `signal` lines — there are none yet, so add a new block right after the doc comment):

```gdscript
signal marker_tapped(info: Dictionary)  ## emitted by _unhandled_input() when a
## plain single-finger tap (outside placement mode) lands on a marker --
## info is a hit_test_marker() result, always non-empty when this fires.
signal map_tapped_empty  ## emitted instead of marker_tapped when that same
## tap doesn't land on anything -- main.gd uses this to dismiss MarkerCard.
```

- [ ] **Step 3: Implement `hit_test_marker()`**

Add as a new method, near `get_nearest_gate_index()` (around line 223) since it serves the same "which POI" purpose:

```gdscript
## Screen_pos is in global/viewport coordinates (same convention as
## touch_event.position, passed straight through from _unhandled_input()).
## Returns the closest marker within its own tap-tolerance radius across
## all four marker types, or {} if nothing qualifies -- see
## MapGeometry.closest_marker_within_radius() for the actual selection
## rule. The stronghold is only a candidate when it's actually placed and
## not mid-relocation (a pending placement-mode position isn't a real,
## tappable marker yet).
func hit_test_marker(screen_pos: Vector2) -> Dictionary:
	var local_pos := to_local(screen_pos)
	var marker_scale: float = clamp(_zoom_px_per_m / DEFAULT_ZOOM_PX_PER_M, 0.6, 1.4)
	var candidates: Array = []

	for i in _gates.size():
		var g: Dictionary = _gates[i]
		candidates.append(
			{
				"type": "gate",
				"index": i,
				"screen_pos": _world_to_screen(_project(g["lat"], g["lon"])),
				"radius": GATE_MARKER_SIZE * marker_scale / 2.0 + TAP_TOLERANCE_PX,
			}
		)

	for i in _sanctuaries.size():
		var s: Dictionary = _sanctuaries[i]
		candidates.append(
			{
				"type": "sanctuary",
				"index": i,
				"screen_pos": _world_to_screen(_project(s["lat"], s["lon"])),
				"radius": SANCTUARY_MARKER_SIZE * marker_scale / 2.0 + TAP_TOLERANCE_PX,
			}
		)

	for i in _lorestones.size():
		var ls: Dictionary = _lorestones[i]
		candidates.append(
			{
				"type": "lorestone",
				"index": i,
				"screen_pos": _world_to_screen(_project(ls["lat"], ls["lon"])),
				"radius": LORESTONE_MARKER_SIZE * marker_scale / 2.0 + TAP_TOLERANCE_PX,
			}
		)

	if _stronghold_placed and not _has_pending_stronghold:
		candidates.append(
			{
				"type": "stronghold",
				"index": -1,
				"screen_pos": _world_to_screen(_project(_stronghold_lat, _stronghold_lon)),
				"radius": STRONGHOLD_MARKER_SIZE * marker_scale / 2.0 + TAP_TOLERANCE_PX,
			}
		)

	var hit := MapGeometry.closest_marker_within_radius(local_pos, candidates)
	if hit.is_empty():
		return {}
	return {"type": hit["type"], "index": hit["index"], "screen_pos": to_global(hit["screen_pos"])}
```

- [ ] **Step 4: Wire the tap branch into `_unhandled_input()`**

In `_unhandled_input()`, the touch-pressed branch currently reads (around line 502-509):

```gdscript
		if touch_event.pressed:
			_active_touches[touch_event.index] = touch_event.position
			if _active_touches.size() == 2:
				_pinch_last_distance = _pinch_distance()
			elif _placement_mode and _active_touches.size() == 1:
				var lonlat := _screen_to_lonlat(touch_event.position)
				_pending_stronghold_lon = lonlat.x
				_pending_stronghold_lat = lonlat.y
				_has_pending_stronghold = true
				queue_redraw()
```

Add one more `elif` branch, mirroring the exact same "single active touch, on press" pattern the placement-mode branch already uses (no separate drag-vs-tap distinction exists anywhere in this file — a single-finger touch never pans the locked-to-player view, so treating touch-down itself as the tap is consistent with how placement mode already behaves):

```gdscript
		if touch_event.pressed:
			_active_touches[touch_event.index] = touch_event.position
			if _active_touches.size() == 2:
				_pinch_last_distance = _pinch_distance()
			elif _placement_mode and _active_touches.size() == 1:
				var lonlat := _screen_to_lonlat(touch_event.position)
				_pending_stronghold_lon = lonlat.x
				_pending_stronghold_lat = lonlat.y
				_has_pending_stronghold = true
				queue_redraw()
			elif not _placement_mode and _active_touches.size() == 1:
				var hit := hit_test_marker(touch_event.position)
				if hit.is_empty():
					map_tapped_empty.emit()
				else:
					marker_tapped.emit(hit)
```

- [ ] **Step 5: Format and lint**

The post-edit hook runs `gdformat`/`gdlint` automatically on save. Confirm no warnings: `python -m gdtoolkit.linter scenes/map_view.gd` (use this form, not the bare `gdlint`, which can transiently fail with a Windows "Permission denied" error in this environment).

- [ ] **Step 6: Sanity-check with a headless debug script**

`hit_test_marker()` can't be unit-tested (it's `Node2D`-dependent, per this project's `core/`-vs-`scenes/` convention), but its pure decision logic is already covered by Task 1's tests. Sanity-check the wiring itself with a throwaway headless script (delete it after):

```gdscript
extends SceneTree

func _init():
	var mv := MapView.new()
	mv._has_fix = true
	mv._zoom_px_per_m = MapView.DEFAULT_ZOOM_PX_PER_M
	mv._gates = [{"lat": 54.5, "lon": -1.5, "rank": "E", "monster_id": "mon_x"}]
	var world_pos: Vector2 = mv._project(54.5, -1.5)
	# tap exactly on the gate's own screen position (player at the same spot,
	# so world_to_screen(world_pos) == Vector2.ZERO local, i.e. mv.position global)
	mv._player_world_pos = world_pos
	var tap_screen_pos: Vector2 = mv.to_global(mv._world_to_screen(world_pos))
	var hit: Dictionary = mv.hit_test_marker(tap_screen_pos)
	print("hit: ", hit)
	assert(hit.get("type", "") == "gate")
	var miss: Dictionary = mv.hit_test_marker(tap_screen_pos + Vector2(500, 500))
	print("miss: ", miss)
	assert(miss.is_empty())
	print("OK")
	quit()
```

Run: `"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s _hit_test_debug.gd` (save the script above as `_hit_test_debug.gd` in the project root first, delete it once this passes — it is scratch, not part of the plan's deliverables).

Expected: prints `hit: {...type: gate...}`, `miss: {}`, `OK`.

- [ ] **Step 7: Commit**

```bash
git add scenes/map_view.gd
git commit -m "feat: add MapView.hit_test_marker() and marker_tapped/map_tapped_empty signals"
```

---

### Task 3: `MarkerCard` UI + `main.gd`/`main.tscn` wiring

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `scenes/main.gd`

**Interfaces:**
- Consumes: `map_view.marker_tapped(info)` / `map_view.map_tapped_empty` signals and `map_view.hit_test_marker()`'s dict shape from Task 2. Existing `map_view.get_gate(index)`, `map_view.remove_gate(index)`, `map_view.get_sanctuary(index)`, `map_view.get_lorestone(index)`. Existing `state.claim_sanctuary(...)`, `state.discover_lorestone(...)`, `state.last_sanctuary_claim_at`, `state.discovered_lorestone_ids`. Existing `MapGeometry.distance_metres(...)`, `GameLogic.POI_PROXIMITY_RADIUS_M`, `GameLogic.SANCTUARY_ESSENCE_REWARD`, `GameLogic.SANCTUARY_TICKET_REWARD`, `GameLogic.SANCTUARY_CLAIM_COOLDOWN_S`, `GameLogic.LORESTONE_ESSENCE_REWARD`, `PoiSpawner.LORE_SNIPPETS`, `_start_gate_battle(gate: Dictionary)`, `_refresh_label()`, `SaveService.save(state)`, `_last_lat`/`_last_lon`.
- Produces: nothing consumed elsewhere in this plan — this is the last task.

- [ ] **Step 1: Remove the three old buttons from `main.tscn`**

Delete these three node blocks entirely (currently at lines 127-146 in `scenes/main.tscn`):

```
[node name="EnterGateButton" type="Button" parent="GameUI"]
offset_left = 40.0
offset_top = 210.0
offset_right = 340.0
offset_bottom = 270.0
theme_override_font_sizes/font_size = 24
text = "Enter Nearest Gate"

[node name="ClaimSanctuaryButton" type="Button" parent="GameUI"]
offset_left = 40.0
offset_top = 280.0
offset_right = 340.0
offset_bottom = 330.0
theme_override_font_sizes/font_size = 20
text = "Claim Sanctuary"

[node name="LoreStoneButton" type="Button" parent="GameUI"]
offset_left = 360.0
offset_top = 280.0
offset_right = 660.0
offset_bottom = 330.0
theme_override_font_sizes/font_size = 20
text = "Lore Stone"
```

- [ ] **Step 2: Move Confirm/Cancel Stronghold buttons up to fill the freed gap**

They currently sit at `offset_top = 340`/`offset_bottom = 390`, right below the buttons just deleted, which leaves a large empty gap above them when they become visible during Stronghold placement. Move both up by 130px, to exactly where `EnterGateButton` used to start (`offset_top = 210`/`offset_bottom = 270`) — same height, no other change:

```
[node name="ConfirmStrongholdButton" type="Button" parent="GameUI"]
visible = false
offset_left = 40.0
offset_top = 210.0
offset_right = 340.0
offset_bottom = 270.0
theme_override_font_sizes/font_size = 20
text = "Confirm Location"

[node name="CancelStrongholdButton" type="Button" parent="GameUI"]
visible = false
offset_left = 360.0
offset_top = 210.0
offset_right = 560.0
offset_bottom = 270.0
theme_override_font_sizes/font_size = 20
text = "Cancel"
```

- [ ] **Step 3: Add the `MarkerCard` node tree**

Add this node tree as a child of `GameUI`, anywhere after the `MapView` node block (e.g. right after it, before where `EnterGateButton` used to be):

```
[node name="MarkerCard" type="Panel" parent="GameUI"]
visible = false
z_index = 1
offset_left = 0.0
offset_top = 0.0
offset_right = 240.0
offset_bottom = 110.0

[node name="TypeLabel" type="Label" parent="GameUI/MarkerCard"]
offset_left = 12.0
offset_top = 8.0
offset_right = 228.0
offset_bottom = 34.0
theme_override_font_sizes/font_size = 16
text = "SANCTUARY"

[node name="SubtitleLabel" type="Label" parent="GameUI/MarkerCard"]
offset_left = 12.0
offset_top = 36.0
offset_right = 228.0
offset_bottom = 62.0
theme_override_font_sizes/font_size = 14
text = "0m away"

[node name="ActionButton" type="Button" parent="GameUI/MarkerCard"]
offset_left = 12.0
offset_top = 68.0
offset_right = 228.0
offset_bottom = 102.0
theme_override_font_sizes/font_size = 18
text = "Claim"
```

`z_index = 1` on the top-level `Panel` is load-bearing — see Global Constraints. `position` (i.e. `offset_left`/`offset_top`) is overwritten every time the card is shown (Step 6 below); the values above are just its at-rest/editor-preview position.

- [ ] **Step 4: Remove the old onready vars and connections in `main.gd`**

Remove these three lines (around lines 50, 67-68):

```gdscript
@onready var enter_gate_button: Button = $GameUI/EnterGateButton
```
```gdscript
@onready var claim_sanctuary_button: Button = $GameUI/ClaimSanctuaryButton
@onready var lorestone_button: Button = $GameUI/LoreStoneButton
```

Remove the `enter_gate_button` connect block from `_start_game()` (around line 226-227):

```gdscript
	if not enter_gate_button.pressed.is_connected(_on_enter_gate_pressed):
		enter_gate_button.pressed.connect(_on_enter_gate_pressed)
```

Remove these two lines from `_setup_gear_panels()`'s connect block (around line 265-266):

```gdscript
		claim_sanctuary_button.pressed.connect(_on_claim_sanctuary_pressed)
		lorestone_button.pressed.connect(_on_lorestone_pressed)
```

Remove the three old handler functions entirely: `_on_enter_gate_pressed()`, `_on_claim_sanctuary_pressed()`, `_on_lorestone_pressed()` (including `_on_claim_sanctuary_pressed()`'s and `_on_lorestone_pressed()`'s doc comment directly above them).

- [ ] **Step 5: Add new onready vars and state fields**

Add alongside the other `@onready var` declarations (near where `enter_gate_button` used to be):

```gdscript
@onready var marker_card: Panel = $GameUI/MarkerCard
@onready var marker_card_type_label: Label = $GameUI/MarkerCard/TypeLabel
@onready var marker_card_subtitle_label: Label = $GameUI/MarkerCard/SubtitleLabel
@onready var marker_card_action_button: Button = $GameUI/MarkerCard/ActionButton
```

Add alongside the other plain `var` fields near the top of the file (near `_pending_break_gate` or similar one-off state):

```gdscript
var _card_poi_type: String = ""  ## which POI MarkerCard's action button currently
var _card_poi_index: int = -1  ## acts on -- set by _show_sanctuary_card()/
## _show_lorestone_card(), read by _on_marker_card_action_pressed().
```

- [ ] **Step 6: Wire the new signals in `_setup_gear_panels()`**

Add these three lines inside the existing `if not hunter_gear_button.pressed.is_connected(...)` guard block (anywhere in that block — e.g. right after the `gate_break_timer.timeout.connect(...)` line at the end):

```gdscript
		map_view.marker_tapped.connect(_on_marker_tapped)
		map_view.map_tapped_empty.connect(_on_map_tapped_empty)
		marker_card_action_button.pressed.connect(_on_marker_card_action_pressed)
```

- [ ] **Step 7: Add the marker-tap dispatcher and card positioning**

Add these new functions (e.g. where `_on_enter_gate_pressed()` used to be):

```gdscript
const MARKER_CARD_SIZE := Vector2(240.0, 110.0)
const MARKER_CARD_MARGIN := 12.0  ## keeps the card off the very edge of the screen
const MARKER_CARD_GAP := 16.0  ## vertical gap between the card and the marker it points at


func _on_marker_tapped(info: Dictionary) -> void:
	match info["type"]:
		"gate":
			marker_card.visible = false
			_enter_gate(info["index"])
		"sanctuary":
			_show_sanctuary_card(info["index"], info["screen_pos"])
		"lorestone":
			_show_lorestone_card(info["index"], info["screen_pos"])
		"stronghold":
			marker_card.visible = false
			stronghold_view.open()


func _on_map_tapped_empty() -> void:
	marker_card.visible = false


## Positions MarkerCard above marker_screen_pos, clamped to stay fully
## on-screen -- flips below the marker instead when there isn't enough
## room above it (near the top of the screen). 1080.0 is this project's
## fixed viewport width (project.godot's window/size/viewport_width),
## same hardcoded-pixel convention every other node in main.tscn already
## uses -- there's no responsive layout system in this codebase.
func _position_marker_card(marker_screen_pos: Vector2) -> void:
	var pos := marker_screen_pos - Vector2(
		MARKER_CARD_SIZE.x / 2.0, MARKER_CARD_SIZE.y + MARKER_CARD_GAP
	)
	if pos.y < MARKER_CARD_MARGIN:
		pos.y = marker_screen_pos.y + MARKER_CARD_GAP
	pos.x = clamp(pos.x, MARKER_CARD_MARGIN, 1080.0 - MARKER_CARD_SIZE.x - MARKER_CARD_MARGIN)
	marker_card.position = pos
	marker_card.visible = true
```

- [ ] **Step 8: Add gate entry (reusing the existing battle-start path)**

```gdscript
func _enter_gate(index: int) -> void:
	var gate := map_view.get_gate(index)
	if gate.is_empty():
		return
	map_view.remove_gate(index)
	_start_gate_battle(gate)
```

- [ ] **Step 9: Add the Sanctuary/Lore Stone card-state functions**

```gdscript
func _show_sanctuary_card(index: int, screen_pos: Vector2) -> void:
	var poi := map_view.get_sanctuary(index)
	var distance := MapGeometry.distance_metres(_last_lat, _last_lon, poi["lat"], poi["lon"])
	var in_range := distance <= GameLogic.POI_PROXIMITY_RADIUS_M
	var now := int(Time.get_unix_time_from_system())
	var on_cooldown := (
		state.last_sanctuary_claim_at != 0
		and now - state.last_sanctuary_claim_at < GameLogic.SANCTUARY_CLAIM_COOLDOWN_S
	)
	_card_poi_type = "sanctuary"
	_card_poi_index = index
	marker_card_type_label.text = "SANCTUARY"
	if not in_range:
		marker_card_subtitle_label.text = "%dm away — too far" % int(distance)
		marker_card_action_button.text = "Too far away"
		marker_card_action_button.disabled = true
	elif on_cooldown:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Already claimed today"
		marker_card_action_button.disabled = true
	else:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Claim"
		marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)


func _show_lorestone_card(index: int, screen_pos: Vector2) -> void:
	var poi := map_view.get_lorestone(index)
	var distance := MapGeometry.distance_metres(_last_lat, _last_lon, poi["lat"], poi["lon"])
	var in_range := distance <= GameLogic.POI_PROXIMITY_RADIUS_M
	var discovered: bool = state.discovered_lorestone_ids.has(poi["id"])
	_card_poi_type = "lorestone"
	_card_poi_index = index
	marker_card_type_label.text = "LORE STONE"
	if not in_range:
		marker_card_subtitle_label.text = "%dm away — too far" % int(distance)
		marker_card_action_button.text = "Too far away"
		marker_card_action_button.disabled = true
	elif discovered:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Already discovered"
		marker_card_action_button.disabled = true
	else:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Discover"
		marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)
```

- [ ] **Step 10: Add the action-button handler (reusing the existing claim/discover code)**

```gdscript
func _on_marker_card_action_pressed() -> void:
	marker_card.visible = false
	match _card_poi_type:
		"sanctuary":
			_claim_sanctuary()
		"lorestone":
			_discover_lorestone()


func _claim_sanctuary() -> void:
	var claimed := state.claim_sanctuary(
		Time.get_unix_time_from_system(),
		GameLogic.SANCTUARY_ESSENCE_REWARD,
		GameLogic.SANCTUARY_TICKET_REWARD,
		GameLogic.SANCTUARY_CLAIM_COOLDOWN_S
	)
	if not claimed:
		label.text += "\n\nAlready claimed today"
		return
	SaveService.save(state)
	_refresh_label()
	label.text += (
		"\n\nSanctuary claimed: +%d Essence, +%d Gate Ticket"
		% [GameLogic.SANCTUARY_ESSENCE_REWARD, GameLogic.SANCTUARY_TICKET_REWARD]
	)


func _discover_lorestone() -> void:
	var stone := map_view.get_lorestone(_card_poi_index)
	var discovered := state.discover_lorestone(stone["id"], GameLogic.LORESTONE_ESSENCE_REWARD)
	if not discovered:
		label.text += "\n\nAlready discovered"
		return
	SaveService.save(state)
	_refresh_label()
	var lore_index: int = stone["lore_index"]
	label.text += (
		"\n\n%s\n(+%d Essence)"
		% [PoiSpawner.LORE_SNIPPETS[lore_index], GameLogic.LORESTONE_ESSENCE_REWARD]
	)
```

`_claim_sanctuary()`/`_discover_lorestone()` keep the original handlers' own `if not claimed:`/`if not discovered:` fallback exactly as it was — the card's action button is disabled whenever these would fail today, so this only guards a narrow same-frame race (e.g. cooldown ticking over between opening the card and pressing the button), matching the original code's own level of defensiveness.

- [ ] **Step 11: Format and lint**

The post-edit hook runs automatically on `.gd` file saves. Confirm no warnings: `python -m gdtoolkit.linter scenes/main.gd`.

- [ ] **Step 12: Run the full test suite**

Run: `"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: PASS — 511/511 (no `core/` changes in this task, so the count is unchanged from Task 1).

- [ ] **Step 13: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "feat: tap-to-marker interaction for gates/sanctuaries/lorestones/stronghold, remove old action buttons"
```

---

## Manual on-device verification (after Task 3, not a separate task)

`scenes/` changes are only ever verified manually/on-device per this project's convention (see Global Constraints) — there is no Task 4 subagent dispatch for this; it happens once implementation is complete, the same way the map-POI-spawning plan's final device pass did. Checklist:

- Tap a gate marker → battle starts immediately for that specific gate (test with two gates visible on screen — tapping the farther one enters *that* one, not the nearer one).
- Tap a Sanctuary marker while in range → card shows `SANCTUARY` / distance / `Claim` enabled; pressing it claims and prints the same message as before; card disappears.
- Tap the same Sanctuary again same day → card shows `Already claimed today`, disabled.
- Tap a Sanctuary while out of range → card shows `"…m away — too far"` / `Too far away`, disabled.
- Same three checks for a Lore Stone (`Discover` / `Already discovered` / `Too far away`).
- Tap the Stronghold marker → opens the Stronghold panel directly (no card).
- Tap empty map space with a card open → card dismisses.
- Tap a marker near the top edge of the screen → card flips to render below it instead of clipping off-screen.
- Confirm the nav-bar `Stronghold` button still opens the panel before any Stronghold is placed (no marker exists yet to tap).
- Confirm pinch-zoom still works (two-finger gesture untouched by this plan).
- Confirm `EnterGateButton`/`ClaimSanctuaryButton`/`LoreStoneButton` are gone from the screen and Confirm/Cancel Stronghold buttons appear in their old vertical slot during placement mode.
