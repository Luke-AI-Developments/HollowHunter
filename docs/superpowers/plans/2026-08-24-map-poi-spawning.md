# Map POI spawning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the 4 remaining map-marker POI types (Sanctuary, Lore Stone, Stronghold, Incursion badge) into real game data and rendering, per `docs/superpowers/specs/2026-08-24-map-poi-spawning-design.md`. `map_nadir.webp` gets no wiring — confirmed a deliberate no-op in that spec.

**Architecture:** Pure spawning/distance/state-mutation logic lives in `core/` (fully unit-tested, no engine dependency). All rendering, touch input, and the placement-mode tap-to-lat/lon inversion stay in `scenes/map_view.gd` (engine-dependent), manually verified — matching this project's established `core`/`scenes` split, same as the rest of the map renderer.

**Tech Stack:** Godot 4.7.1 (mono), GDScript. No new dependencies.

## Global Constraints

- Static typing everywhere. Tabs for indentation. `snake_case`/`PascalCase` conventions (see `CLAUDE.md`).
- Every `core/` function gets a GUT test in the matching `tests/unit/test_*.gd` file. `scenes/` changes are manually verified only (this project's established convention — no GUT coverage for engine-dependent code).
- `gdformat`/`gdlint` run automatically via the post-edit hook on `.gd` files — if the hook doesn't fire, run both manually before committing (`gdformat <file>` then `gdlint <file>`).
- **Coordinate convention:** every `Vector2` representing a lon/lat pair in this codebase is `Vector2(x=lon, y=lat)` (matches `MapGeometry.lonlat_to_mercator(lon, lat) -> Vector2`) — never `(lat, lon)`. Keep this consistent in every new function that touches one.
- **Proximity radius:** `GameLogic.POI_PROXIMITY_RADIUS_M := 50.0` is the one distance every gated interaction below (Sanctuary claim, Lore Stone discovery, Stronghold collect/reassign) uses — don't hand-roll a second value anywhere.
- **Deterministic POI anchor:** Sanctuary/Lore Stone positions must be identical for every player physically standing anywhere inside the same `Incursion.area_key()` grid cell (~5.5km), not just for the same player across sessions. This means the RNG seed AND the scatter center must both derive from the cell's own fixed centroid — never from the caller's raw (possibly different-per-player) lat/lon directly. Task 2 below gets this exactly right; don't regress it in later tasks.

---

### Task 1: `core/map_geometry.gd` — `distance_metres()` + `mercator_to_lonlat()`

**Files:**
- Modify: `core/map_geometry.gd`
- Test: `tests/unit/test_map_geometry.gd`

**Interfaces:**
- Produces: `MapGeometry.distance_metres(lat1: float, lon1: float, lat2: float, lon2: float) -> float`, `MapGeometry.mercator_to_lonlat(x: float, y: float) -> Vector2`. Consumed by Task 2 (`PoiSpawner`), Task 4 (`HunterState` proximity checks are done by the caller, not `HunterState` itself — see Task 8/9), and Task 6 (`MapView`'s placement-tap inversion).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_map_geometry.gd` (after the existing `test_rect_intersects_disjoint` test, at the end of the file):

```gdscript
func test_distance_metres_at_same_point_is_zero() -> void:
	var d := MapGeometry.distance_metres(54.5235, -1.5549, 54.5235, -1.5549)
	assert_almost_eq(d, 0.0, 0.01)


func test_distance_metres_known_short_distance() -> void:
	# Two points ~0.001 degrees of latitude apart (~111m at any longitude,
	# since 1 degree of latitude is always ~111,320m regardless of position).
	var d := MapGeometry.distance_metres(54.5235, -1.5549, 54.5245, -1.5549)
	assert_almost_eq(d, 111.3, 2.0)


func test_distance_metres_is_symmetric() -> void:
	var a_to_b := MapGeometry.distance_metres(54.5235, -1.5549, 54.53, -1.56)
	var b_to_a := MapGeometry.distance_metres(54.53, -1.56, 54.5235, -1.5549)
	assert_almost_eq(a_to_b, b_to_a, 0.01)


func test_mercator_to_lonlat_round_trips_with_lonlat_to_mercator() -> void:
	var merc := MapGeometry.lonlat_to_mercator(-1.5549, 54.5235)
	var back := MapGeometry.mercator_to_lonlat(merc.x, merc.y)
	assert_almost_eq(back.x, -1.5549, 0.0001)
	assert_almost_eq(back.y, 54.5235, 0.0001)


func test_mercator_to_lonlat_at_origin() -> void:
	var result := MapGeometry.mercator_to_lonlat(0.0, 0.0)
	assert_almost_eq(result.x, 0.0, 0.0001)
	assert_almost_eq(result.y, 0.0, 0.0001)
```

- [ ] **Step 2: Run tests to verify they fail**

```
"/c/Users/luket/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: FAIL on all 5 new tests with "Invalid call. Nonexistent function 'distance_metres'/'mercator_to_lonlat'". No other test's pass count changes.

- [ ] **Step 3: Implement**

Add to `core/map_geometry.gd`, directly after `lonlat_to_mercator()`:

```gdscript
## Inverse of lonlat_to_mercator() -- must stay in sync with it the same way
## the Python conversion script's own formula does. Returns Vector2(lon,
## lat), matching this file's Vector2(x=lon, y=lat) convention throughout.
static func mercator_to_lonlat(x: float, y: float) -> Vector2:
	var lon := rad_to_deg(x / EARTH_RADIUS_M)
	var lat := rad_to_deg(2.0 * atan(exp(y / EARTH_RADIUS_M)) - PI / 2.0)
	return Vector2(lon, lat)


## Great-circle distance in metres between two lat/lon points (haversine).
## Deliberately NOT built on lonlat_to_mercator() -- Web Mercator's scale
## factor is sec(latitude), so a Mercator-space distance is inflated by
## ~72% at Darlington's ~54.5° latitude (191.8m computed for a true 111.3m
## gap -- caught by the Task 1 implementer's own test run). That distortion
## is invisible for on-screen rendering (a few pixels either way) but would
## silently break every real-world proximity check this function feeds
## (Sanctuary/Lore Stone/Stronghold's 50m radius), so this earns its own,
## separate, standard formula instead of reusing the projection.
static func distance_metres(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var lat1_rad := deg_to_rad(lat1)
	var lat2_rad := deg_to_rad(lat2)
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2.0) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2.0) ** 2
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return EARTH_RADIUS_M * c
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: 5 new tests pass, total pass count is exactly 5 higher than before this task, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/map_geometry.gd tests/unit/test_map_geometry.gd
git commit -m "Map POI: MapGeometry.distance_metres() + mercator_to_lonlat()"
```

---

### Task 2: `core/poi_spawner.gd` — deterministic Sanctuary/Lore Stone spawning

**Files:**
- Create: `core/poi_spawner.gd`
- Test: `tests/unit/test_poi_spawner.gd`

**Interfaces:**
- Consumes: `Incursion.area_key(lat, lon) -> String`, `Incursion.AREA_CELL_DEGREES` (existing, `core/incursion.gd`), `GateSpawner.MAX_OFFSET_DEGREES` (existing, `core/gate_spawner.gd`).
- Produces: `PoiSpawner.spawn_sanctuaries(center_lat: float, center_lon: float, count: int = PoiSpawner.SANCTUARY_COUNT) -> Array[Dictionary]` (`{"id": String, "lat": float, "lon": float}`), `PoiSpawner.spawn_lorestones(center_lat: float, center_lon: float, count: int = PoiSpawner.LORESTONE_COUNT) -> Array[Dictionary]` (adds `"lore_index": int`), `PoiSpawner.LORE_SNIPPETS: Array[String]`. Consumed by Task 6 (`MapView.show_position()`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_poi_spawner.gd`:

```gdscript
extends GutTest
## PoiSpawner: deterministic-by-area Sanctuary/Lore Stone spawning (§19).
## Unlike GateSpawner (per-session RNG), every player physically standing
## anywhere inside the same area cell must compute IDENTICAL positions --
## these are shared world POIs, not per-player scatter.


func test_spawn_sanctuaries_returns_requested_count() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549, 3)
	assert_eq(sanctuaries.size(), 3)


func test_spawn_sanctuaries_default_count_is_two() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	assert_eq(sanctuaries.size(), 2)


func test_spawn_lorestones_default_count_is_one() -> void:
	var lorestones := PoiSpawner.spawn_lorestones(54.5235, -1.5549)
	assert_eq(lorestones.size(), 1)


func test_spawn_sanctuaries_identical_for_two_players_in_the_same_cell() -> void:
	# Both points fall in the same ~5.5km area cell (Incursion.AREA_CELL_DEGREES
	# = 0.05) but are not the same point -- simulates two different players
	# standing in different spots within one area.
	var a := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	var b := PoiSpawner.spawn_sanctuaries(54.5210, -1.5520)
	assert_eq(a, b)


func test_spawn_lorestones_identical_for_two_players_in_the_same_cell() -> void:
	var a := PoiSpawner.spawn_lorestones(54.5235, -1.5549)
	var b := PoiSpawner.spawn_lorestones(54.5210, -1.5520)
	assert_eq(a, b)


func test_spawn_sanctuaries_differ_across_distant_cells() -> void:
	var here := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	var far_away := PoiSpawner.spawn_sanctuaries(51.5074, -0.1278)  # London
	assert_ne(here[0]["id"], far_away[0]["id"])


func test_spawn_sanctuaries_ids_are_unique_within_a_call() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549, 5)
	var seen := {}
	for s: Dictionary in sanctuaries:
		seen[s["id"]] = true
	assert_eq(seen.size(), sanctuaries.size())


func test_spawn_sanctuaries_offsets_stay_within_gate_spawner_bound() -> void:
	# Offsets are measured from the CELL's own anchor (its fixed centroid),
	# not from the raw input point -- the input can be anywhere within the
	# cell, up to half a cell-width from that centroid, so bounding against
	# the raw input directly would fail even for a correct implementation.
	var lat := 54.5235
	var lon := -1.5549
	var cell_lat: float = floor(lat / Incursion.AREA_CELL_DEGREES)
	var cell_lon: float = floor(lon / Incursion.AREA_CELL_DEGREES)
	var anchor_lat := (cell_lat + 0.5) * Incursion.AREA_CELL_DEGREES
	var anchor_lon := (cell_lon + 0.5) * Incursion.AREA_CELL_DEGREES

	var sanctuaries := PoiSpawner.spawn_sanctuaries(lat, lon, 10)
	for s: Dictionary in sanctuaries:
		assert_lt(absf(s["lat"] - anchor_lat), GateSpawner.MAX_OFFSET_DEGREES * 1.5)
		assert_lt(absf(s["lon"] - anchor_lon), GateSpawner.MAX_OFFSET_DEGREES * 1.5)


func test_spawn_lorestones_assigns_lore_index_within_snippet_bounds() -> void:
	var lorestones := PoiSpawner.spawn_lorestones(54.5235, -1.5549, 4)
	for ls: Dictionary in lorestones:
		assert_gte(ls["lore_index"], 0)
		assert_lt(ls["lore_index"], PoiSpawner.LORE_SNIPPETS.size())


func test_lore_snippets_has_at_least_four_entries() -> void:
	assert_gte(PoiSpawner.LORE_SNIPPETS.size(), 4)
```

- [ ] **Step 2: Run tests to verify they fail**

Same GUT command as Task 1. Expected: FAIL with "Nonexistent class 'PoiSpawner'" or similar on all 10 new tests.

- [ ] **Step 3: Implement**

Create `core/poi_spawner.gd`:

```gdscript
class_name PoiSpawner
## Deterministic-by-area spawning for Sanctuary and Lore Stone map POIs
## (§19) -- sibling to core/gate_spawner.gd, but unlike gates (which reroll
## every session via an unseeded RNG) these are seeded from the area's own
## fixed grid-cell centroid, not the caller's raw lat/lon -- so every
## player physically anywhere inside the same cell computes the exact same
## positions. Matches "anchored to real notable places" (§19): these read
## as fixed real landmarks, not per-player scatter. Reuses
## Incursion.area_key()/AREA_CELL_DEGREES rather than a new cell-size
## constant, and GateSpawner.MAX_OFFSET_DEGREES for the same ~300-400m
## scatter radius gates already use.

const SANCTUARY_COUNT := 2
const LORESTONE_COUNT := 1

## Short placeholder in-fiction blurbs (§19: "reveal worldbuilding -- the
## Ascendancy, the families, the Nadir") -- explicitly not a real writing
## pass, see the design spec's "Explicitly out of scope" section. Picked
## round-robin by a stone's lore_index, not randomly.
const LORE_SNIPPETS := [
	(
		"The Ascendancy is not a system, not a god -- it is the pressure the world puts on "
		+ "those who refuse to stay ordinary."
	),
	(
		"Every family traces itself to a Gate that never closed. The families did not choose "
		+ "their colours; the colours chose them."
	),
	(
		"Before it was called the Nadir, it had no name at all -- because nothing had ever "
		+ "climbed far enough to need one."
	),
	"Extraction is not domestication. What kneels in the CLAIM light remembers exactly what it was.",
]


static func spawn_sanctuaries(
	center_lat: float, center_lon: float, count: int = SANCTUARY_COUNT
) -> Array:
	return _spawn_points(center_lat, center_lon, count, "sanctuary")


static func spawn_lorestones(
	center_lat: float, center_lon: float, count: int = LORESTONE_COUNT
) -> Array:
	var points := _spawn_points(center_lat, center_lon, count, "lorestone")
	for i in points.size():
		points[i]["lore_index"] = i % LORE_SNIPPETS.size()
	return points


static func _spawn_points(center_lat: float, center_lon: float, count: int, type_tag: String) -> Array:
	var area := Incursion.area_key(center_lat, center_lon)
	var anchor := _area_anchor(center_lat, center_lon)  # Vector2(lon, lat)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [area, type_tag])
	var points := []
	for i in count:
		points.append(
			{
				"id": "%s_%s_%d" % [area, type_tag, i],
				"lat": anchor.y + _rand_offset(rng),
				"lon": anchor.x + _rand_offset(rng),
			}
		)
	return points


## The fixed centre point of the area cell `lat`/`lon` falls in --
## reconstructed the same way Incursion.area_key() buckets, so two
## different players inside the same cell always compute the same anchor
## regardless of exactly where in the cell they each are. Vector2(lon,
## lat), matching this project's Mercator-coordinate convention.
static func _area_anchor(lat: float, lon: float) -> Vector2:
	var cell_lat: float = floor(lat / Incursion.AREA_CELL_DEGREES)
	var cell_lon: float = floor(lon / Incursion.AREA_CELL_DEGREES)
	return Vector2(
		(cell_lon + 0.5) * Incursion.AREA_CELL_DEGREES, (cell_lat + 0.5) * Incursion.AREA_CELL_DEGREES
	)


static func _rand_offset(rng: RandomNumberGenerator) -> float:
	return (rng.randf() - 0.5) * 2.0 * GateSpawner.MAX_OFFSET_DEGREES
```

`_area_anchor()`'s two locals use explicit `: float =` rather than `:=` -- this project's Godot build treats `floor()`'s return here as ambiguously Variant-inferred under plain `:=` and raises a hard parse error ("Warning treated as error"), which cascades into breaking the whole script's compilation (every static func in the file becomes uncallable, surfacing as "Nonexistent function" everywhere else -- confusing to debug from that symptom alone, so noting the actual cause here). The explicit type annotation resolves it.

- [ ] **Step 4: Run tests to verify they pass**

Same GUT command. Expected: 10 new tests pass, total pass count exactly 10 higher than after Task 1, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/poi_spawner.gd tests/unit/test_poi_spawner.gd
git commit -m "Map POI: core/poi_spawner.gd -- deterministic Sanctuary/Lore Stone spawning"
```

---

### Task 3: `core/game_logic.gd` — POI constants

**Files:**
- Modify: `core/game_logic.gd`

**Interfaces:**
- Produces: `GameLogic.POI_PROXIMITY_RADIUS_M`, `GameLogic.SANCTUARY_ESSENCE_REWARD`, `GameLogic.SANCTUARY_TICKET_REWARD`, `GameLogic.SANCTUARY_CLAIM_COOLDOWN_S`, `GameLogic.LORESTONE_ESSENCE_REWARD` (all `const`, no functions — matches this file's existing plain-constant sections like `ESSENCE_PER_GATE_RANK`, which also have no dedicated test). Consumed by Task 8/9 (`main.gd`/`stronghold_view.gd`).

- [ ] **Step 1: Add the constants**

Add to `core/game_logic.gd`, directly after the existing `ESSENCE_PER_CONVERTED_SHADOW` block (around line 60):

```gdscript
# --- §19 map POIs: invented v0 -- the source gives the mechanics (proximity
# required, "a daily bonus", "a one-time small reward") but no exact
# amounts for any of them. ---
const POI_PROXIMITY_RADIUS_M := 50.0  ## how close (metres) a player must be
## to claim a Sanctuary, discover a Lore Stone, or collect/reassign at
## their own Stronghold.
const SANCTUARY_ESSENCE_REWARD := 30  ## roughly an E-rank gate's worth (see
## ESSENCE_PER_GATE_RANK above) -- a daily bonus, not a grind replacement.
const SANCTUARY_TICKET_REWARD := 1
const SANCTUARY_CLAIM_COOLDOWN_S := 86400  ## 24h, not calendar-day-exact --
## avoids timezone edge cases a "same calendar date" check would introduce.
const LORESTONE_ESSENCE_REWARD := 15  ## smaller than Sanctuary's -- a
## one-time flavour find, not a repeatable income source.
```

- [ ] **Step 2: Run the full test suite to confirm nothing broke**

Same GUT command as Task 1. Expected: pass count unchanged from the end of Task 2 (this step adds no new tests -- plain constants, matching this file's own convention).

- [ ] **Step 3: Commit**

```bash
git add core/game_logic.gd
git commit -m "Map POI: GameLogic constants for Sanctuary/Lore Stone/proximity"
```

---

### Task 4: `core/hunter_state.gd` — Sanctuary/Lore Stone/Stronghold-placement state

**Files:**
- Modify: `core/hunter_state.gd`
- Test: Create `tests/unit/test_hunter_state_poi.gd` (split out per this file's established convention -- see `test_hunter_state_shop.gd`/`test_hunter_state_preset.gd`, both split from `test_hunter_state.gd` for the same reason: keeping each topic's tests together and the base file from growing past gdlint's method-count limit)

**Interfaces:**
- Consumes: nothing new.
- Produces: `HunterState.stronghold_lat/lon: float`, `HunterState.stronghold_placed: bool`, `HunterState.last_sanctuary_claim_at: int`, `HunterState.discovered_lorestone_ids: Array`, `HunterState.place_stronghold(lat: float, lon: float) -> void`, `HunterState.claim_sanctuary(now_unix: int, essence_reward: int, ticket_reward: int, cooldown_seconds: int) -> bool`, `HunterState.discover_lorestone(stone_id: String, essence_reward: int) -> bool`. Consumed by Task 8/9 (`main.gd`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_hunter_state_poi.gd`:

```gdscript
extends GutTest
## HunterState: Sanctuary claim / Lore Stone discovery / Stronghold map
## placement (§19/§22, map POI spawning). Split out per this file's
## established one-topic-per-test-file convention (see
## test_hunter_state_shop.gd's own header comment).


func test_new_default_has_no_stronghold_placed() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.stronghold_placed)
	assert_eq(s.stronghold_lat, 0.0)
	assert_eq(s.stronghold_lon, 0.0)


func test_new_default_has_never_claimed_sanctuary() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.last_sanctuary_claim_at, 0)


func test_new_default_has_no_discovered_lorestones() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.discovered_lorestone_ids, [])


func test_place_stronghold_sets_location_and_placed_flag() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	assert_true(s.stronghold_placed)
	assert_eq(s.stronghold_lat, 54.5235)
	assert_eq(s.stronghold_lon, -1.5549)


func test_place_stronghold_can_be_called_again_to_relocate() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	s.place_stronghold(51.5074, -0.1278)
	assert_eq(s.stronghold_lat, 51.5074)
	assert_eq(s.stronghold_lon, -0.1278)


func test_claim_sanctuary_succeeds_first_time() -> void:
	var s := HunterState.new_default("WARRIOR")
	var claimed := s.claim_sanctuary(1000, 30, 1, 86400)
	assert_true(claimed)
	assert_eq(s.essence, 30)
	assert_eq(s.gate_tickets, 1)
	assert_eq(s.last_sanctuary_claim_at, 1000)


func test_claim_sanctuary_fails_within_cooldown() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.claim_sanctuary(1000, 30, 1, 86400)
	var claimed_again := s.claim_sanctuary(1000 + 3600, 30, 1, 86400)
	assert_false(claimed_again)
	assert_eq(s.essence, 30)  # unchanged -- no double reward
	assert_eq(s.gate_tickets, 1)


func test_claim_sanctuary_succeeds_after_cooldown_elapses() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.claim_sanctuary(1000, 30, 1, 86400)
	var claimed_again := s.claim_sanctuary(1000 + 86400, 30, 1, 86400)
	assert_true(claimed_again)
	assert_eq(s.essence, 60)
	assert_eq(s.gate_tickets, 2)


func test_discover_lorestone_succeeds_first_time() -> void:
	var s := HunterState.new_default("WARRIOR")
	var discovered := s.discover_lorestone("0,0_lorestone_0", 15)
	assert_true(discovered)
	assert_eq(s.essence, 15)
	assert_eq(s.discovered_lorestone_ids, ["0,0_lorestone_0"])


func test_discover_lorestone_fails_if_already_discovered() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.discover_lorestone("0,0_lorestone_0", 15)
	var discovered_again := s.discover_lorestone("0,0_lorestone_0", 15)
	assert_false(discovered_again)
	assert_eq(s.essence, 15)  # unchanged -- no double reward


func test_discover_lorestone_allows_a_different_stone() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.discover_lorestone("0,0_lorestone_0", 15)
	var discovered := s.discover_lorestone("1,1_lorestone_0", 15)
	assert_true(discovered)
	assert_eq(s.essence, 30)
	assert_eq(s.discovered_lorestone_ids.size(), 2)


func test_poi_fields_round_trip_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	s.claim_sanctuary(1000, 30, 1, 86400)
	s.discover_lorestone("0,0_lorestone_0", 15)

	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.stronghold_lat, 54.5235)
	assert_eq(restored.stronghold_lon, -1.5549)
	assert_true(restored.stronghold_placed)
	assert_eq(restored.last_sanctuary_claim_at, 1000)
	assert_eq(restored.discovered_lorestone_ids, ["0,0_lorestone_0"])


func test_from_dict_defaults_poi_fields_for_an_old_save() -> void:
	# Simulates a save written before these fields existed.
	var restored := HunterState.from_dict({"level": 5, "essence": 100})
	assert_false(restored.stronghold_placed)
	assert_eq(restored.last_sanctuary_claim_at, 0)
	assert_eq(restored.discovered_lorestone_ids, [])
```

- [ ] **Step 2: Run tests to verify they fail**

Same GUT command. Expected: FAIL on all 13 new tests ("Invalid get index 'stronghold_placed'"/"Invalid call. Nonexistent function 'place_stronghold'" etc.).

- [ ] **Step 3: Implement**

In `core/hunter_state.gd`, add three new fields directly after the `preset_id` field declaration (around line 85, before the blank line preceding `new_default()`):

```gdscript
var stronghold_lat: float = 0.0  ## §22 map placement (new): where the player has
var stronghold_lon: float = 0.0  ## deployed their Stronghold, if anywhere yet.
var stronghold_placed: bool = false  ## false until place_stronghold() is called
## once -- old saves (before this field existed) default to false via
## from_dict(), same as a brand-new hunter who hasn't placed one yet: no
## marker shown, no proximity gate active.
var last_sanctuary_claim_at: int = 0  ## Unix seconds of the last Sanctuary
## claim, 0 = never. Global per-player, not per-sanctuary-id -- "a daily
## bonus" (§19) is singular, not stacked across however many Sanctuaries
## happen to be in the player's area.
var discovered_lorestone_ids: Array = []  ## Array[String] of PoiSpawner-
## generated lorestone ids ever discovered -- one-time-per-id-forever
## (§19: "a one-time small reward for finding them"), persists across
## areas so a player who walks to a new area can still discover its stone.
```

Add three new mutator methods directly after `unlock_cosmetic()` (around line 730, before `to_dict()`):

```gdscript
## §22 map placement (new): sets/moves the Stronghold's map location.
## Callable any number of times -- re-placement is just calling this
## again, no separate first-time-vs-move code path.
func place_stronghold(lat: float, lon: float) -> void:
	stronghold_lat = lat
	stronghold_lon = lon
	stronghold_placed = true


## §19 Sanctuary claim (new): true and applies the reward if the cooldown
## has elapsed since the last claim; false (no change) otherwise. `now_unix`
## and the reward amounts are supplied by the caller (GameLogic constants +
## the scene layer's wall clock) -- stays pure, same convention as
## collect_stronghold().
func claim_sanctuary(
	now_unix: int, essence_reward: int, ticket_reward: int, cooldown_seconds: int
) -> bool:
	# last_sanctuary_claim_at == 0 means "never claimed" (its own doc comment) --
	# exempt from the cooldown check, or a fresh hunter's very first claim
	# would incorrectly fail (0 always looks like "within cooldown" of any
	# small now_unix). Caught by the Task 4 implementer's own test run.
	if last_sanctuary_claim_at != 0 and now_unix - last_sanctuary_claim_at < cooldown_seconds:
		return false
	essence += essence_reward
	gate_tickets += ticket_reward
	last_sanctuary_claim_at = now_unix
	return true


## §19 Lore Stone discovery (new): true and applies the reward if `stone_id`
## hasn't been discovered before; false (no change) if it has.
func discover_lorestone(stone_id: String, essence_reward: int) -> bool:
	if discovered_lorestone_ids.has(stone_id):
		return false
	discovered_lorestone_ids.append(stone_id)
	essence += essence_reward
	return true
```

Update `new_default()` -- add these three lines directly after `s.preset_id = hunter_preset`:

```gdscript
	s.stronghold_lat = 0.0
	s.stronghold_lon = 0.0
	s.stronghold_placed = false
	s.last_sanctuary_claim_at = 0
	s.discovered_lorestone_ids = []
```

Update `to_dict()` -- add these five entries directly after `"preset_id": preset_id,`:

```gdscript
			"stronghold_lat": stronghold_lat,
			"stronghold_lon": stronghold_lon,
			"stronghold_placed": stronghold_placed,
			"last_sanctuary_claim_at": last_sanctuary_claim_at,
			"discovered_lorestone_ids": discovered_lorestone_ids,
```

Update `from_dict()` -- add these five lines directly after `s.preset_id = String(d.get("preset_id", "m1"))`:

```gdscript
	s.stronghold_lat = float(d.get("stronghold_lat", 0.0))
	s.stronghold_lon = float(d.get("stronghold_lon", 0.0))
	s.stronghold_placed = bool(d.get("stronghold_placed", false))
	s.last_sanctuary_claim_at = int(d.get("last_sanctuary_claim_at", 0))
	s.discovered_lorestone_ids = d.get("discovered_lorestone_ids", [])
```

- [ ] **Step 4: Run tests to verify they pass**

Same GUT command. Expected: 13 new tests pass, total pass count exactly 13 higher than after Task 3, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd tests/unit/test_hunter_state_poi.gd
git commit -m "Map POI: HunterState Sanctuary/Lore Stone/Stronghold-placement state"
```

---

### Task 5: `scenes/map_view.gd` — Sanctuary + Lore Stone spawn, draw, in-range queries

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `PoiSpawner.spawn_sanctuaries()`/`spawn_lorestones()` (Task 2), `MapGeometry.distance_metres()` (Task 1), `ArtPaths.map_marker()` (existing).
- Produces: `MapView.nearest_sanctuary_index_in_range(player_lat, player_lon, radius_m) -> int`, `MapView.nearest_lorestone_index_in_range(player_lat, player_lon, radius_m) -> int`, `MapView.get_sanctuary(index) -> Dictionary`, `MapView.get_lorestone(index) -> Dictionary`. Consumed by Task 9 (`main.gd`).

- [ ] **Step 1: Add spawn storage, load textures, spawn on first fix**

In `scenes/map_view.gd`, add two new constants directly after `GATE_MARKER_SIZE`'s doc comment (around line 24):

```gdscript
const SANCTUARY_MARKER_SIZE := 44.0  ## same reasoning as GATE_MARKER_SIZE.
const LORESTONE_MARKER_SIZE := 40.0  ## slightly smaller -- a discoverable
## flavour POI, not as prominent as a Sanctuary's recurring daily stop.
```

Add two new vars directly after `_gate_texture`'s declaration (around line 73):

```gdscript
var _sanctuaries: Array = []  ## Array[Dictionary]: {"id", "lat", "lon"} -- spawned
## once at the first GPS fix, same as _gates (see show_position()).
var _lorestones: Array = []  ## Array[Dictionary]: {"id", "lat", "lon", "lore_index"}.
var _sanctuary_texture: Texture2D = null  ## same fallback story as _gate_texture.
var _lorestone_texture: Texture2D = null
```

In `_ready()`, add two more texture loads:

```gdscript
func _ready() -> void:
	_load_map_data()
	_player_texture = ArtPaths.map_marker("player")
	_gate_texture = ArtPaths.map_marker("gate")
	_sanctuary_texture = ArtPaths.map_marker("sanctuary")
	_lorestone_texture = ArtPaths.map_marker("lorestone")
```

In `show_position()`, add spawning directly after the existing `_gates = GateSpawner.spawn_gates(...)` / incursion-gates `if`/`else` block (still inside the `if not _has_fix:` body, so this also only runs once):

```gdscript
		_sanctuaries = PoiSpawner.spawn_sanctuaries(lat, lon)
		_lorestones = PoiSpawner.spawn_lorestones(lat, lon)
```

- [ ] **Step 2: Draw Sanctuary and Lore Stone markers**

In `_draw()`, add two new loops directly after the existing gate-drawing `for g: Dictionary in _gates:` loop, before the player marker block:

```gdscript
	for s: Dictionary in _sanctuaries:
		var pos := _world_to_screen(_project(s["lat"], s["lon"]))
		if _sanctuary_texture != null:
			var size := SANCTUARY_MARKER_SIZE * marker_scale
			draw_texture_rect(
				_sanctuary_texture, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false
			)
		else:
			draw_circle(pos, GATE_RADIUS * marker_scale, Color.LIGHT_GREEN)

	for ls: Dictionary in _lorestones:
		var pos := _world_to_screen(_project(ls["lat"], ls["lon"]))
		if _lorestone_texture != null:
			var size := LORESTONE_MARKER_SIZE * marker_scale
			draw_texture_rect(
				_lorestone_texture, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false
			)
		else:
			draw_circle(pos, GATE_RADIUS * marker_scale * 0.8, Color.LIGHT_YELLOW)
```

- [ ] **Step 3: Add in-range query methods**

Add directly after `remove_gate()`:

```gdscript
## Index of the nearest Sanctuary within `radius_m` of the player's live
## position, or -1 if none qualify. Used by the "Claim Sanctuary" button
## (main.gd) -- pure lookup, doesn't itself check/apply the daily cooldown
## (that's HunterState.claim_sanctuary()'s job).
func nearest_sanctuary_index_in_range(player_lat: float, player_lon: float, radius_m: float) -> int:
	return _nearest_in_range(_sanctuaries, player_lat, player_lon, radius_m)


func nearest_lorestone_index_in_range(player_lat: float, player_lon: float, radius_m: float) -> int:
	return _nearest_in_range(_lorestones, player_lat, player_lon, radius_m)


func get_sanctuary(index: int) -> Dictionary:
	if index < 0 or index >= _sanctuaries.size():
		return {}
	return _sanctuaries[index]


func get_lorestone(index: int) -> Dictionary:
	if index < 0 or index >= _lorestones.size():
		return {}
	return _lorestones[index]


func _nearest_in_range(points: Array, player_lat: float, player_lon: float, radius_m: float) -> int:
	var best_idx := -1
	var best_dist := INF
	for i in points.size():
		var p: Dictionary = points[i]
		var dist := MapGeometry.distance_metres(player_lat, player_lon, p["lat"], p["lon"])
		if dist <= radius_m and dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx
```

- [ ] **Step 4: Manually verify**

Run the full GUT suite (no `core/` file this task touches, so pass count is unchanged from Task 4). Re-read the diff: confirm `_sanctuaries`/`_lorestones` are populated inside the `if not _has_fix:` block (spawned once, not every `show_position()` call) and that the two new draw loops sit between the gate loop and the player-marker block (draw order: water/roads → gates → sanctuaries → lorestones → player, so the player marker stays visually on top of everything).

- [ ] **Step 5: Commit**

```bash
git add scenes/map_view.gd
git commit -m "Map POI: Sanctuary + Lore Stone spawn, draw, in-range queries"
```

---

### Task 6: `scenes/map_view.gd` — Stronghold marker + tap-to-place flow

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `MapGeometry.mercator_to_lonlat()` (Task 1).
- Produces: `MapView.set_stronghold(lat, lon, placed) -> void`, `MapView.begin_stronghold_placement() -> void`, `MapView.end_stronghold_placement() -> void`, `MapView.has_pending_stronghold_position() -> bool`, `MapView.pending_stronghold_position() -> Vector2` (returns `Vector2(lon, lat)`). Consumed by Task 8 (`main.gd`, `stronghold_view.gd`).

No `.tscn` change in this task — `MapView` already exists as a node in `main.tscn`; Task 8 is the one that adds new buttons.

- [ ] **Step 1: Add Stronghold state and the marker/placement constants**

Add directly after `LORESTONE_MARKER_SIZE` (from Task 5):

```gdscript
const STRONGHOLD_MARKER_SIZE := 44.0  ## same reasoning as GATE_MARKER_SIZE.
```

Add directly after `_lorestone_texture` (from Task 5):

```gdscript
var _stronghold_texture: Texture2D = null

var _stronghold_lat: float = 0.0  ## set via set_stronghold() -- MapView doesn't
var _stronghold_lon: float = 0.0  ## read HunterState directly, main.gd feeds it in.
var _stronghold_placed: bool = false

var _placement_mode: bool = false  ## true between begin_stronghold_placement()
## and end_stronghold_placement() -- while true, a single-finger tap sets a
## pending (not-yet-saved) location instead of doing nothing.
var _pending_stronghold_lon: float = 0.0
var _pending_stronghold_lat: float = 0.0
var _has_pending_stronghold: bool = false
```

Add the texture load to `_ready()`:

```gdscript
	_stronghold_texture = ArtPaths.map_marker("stronghold")
```

- [ ] **Step 2: Public setter + placement-mode API**

Add directly after `get_lorestone()` (from Task 5):

```gdscript
## Feeds the Stronghold's saved map location in from HunterState -- called
## by main.gd once state is loaded/whenever it changes (place/relocate).
## MapView itself never reads HunterState directly (matches how it already
## receives the player's own position via show_position() rather than
## reaching for state on its own).
func set_stronghold(lat: float, lon: float, placed: bool) -> void:
	_stronghold_lat = lat
	_stronghold_lon = lon
	_stronghold_placed = placed
	queue_redraw()


func begin_stronghold_placement() -> void:
	_placement_mode = true
	_has_pending_stronghold = false


## Called by main.gd on BOTH Confirm and Cancel -- MapView doesn't care
## which happened, only that placement mode is over. The Confirm handler
## reads pending_stronghold_position() before calling this (this call
## clears the pending value).
func end_stronghold_placement() -> void:
	_placement_mode = false
	_has_pending_stronghold = false
	queue_redraw()


func has_pending_stronghold_position() -> bool:
	return _has_pending_stronghold


## Vector2(lon, lat) -- matches this file's Mercator-coordinate convention
## (see _project()/_world_to_screen()). Only meaningful when
## has_pending_stronghold_position() is true.
func pending_stronghold_position() -> Vector2:
	return Vector2(_pending_stronghold_lon, _pending_stronghold_lat)
```

- [ ] **Step 3: Screen-tap to lat/lon inversion**

Add directly after `_world_to_screen()`:

```gdscript
## Inverse of _project()+_world_to_screen() combined: a raw viewport touch
## position -> the real-world lon/lat it corresponds to. Used only by the
## Stronghold placement flow below -- every other position in this file
## flows the opposite direction (lat/lon -> screen). Vector2(lon, lat),
## matching this file's convention.
func _screen_to_lonlat(screen_pos: Vector2) -> Vector2:
	var local_pos := to_local(screen_pos)
	var relative := Vector2(local_pos.x, -local_pos.y) / _zoom_px_per_m
	var world_pos := _player_world_pos + relative
	var merc := world_pos + Vector2(_origin_x, _origin_y)
	return MapGeometry.mercator_to_lonlat(merc.x, merc.y)
```

- [ ] **Step 4: Handle the placement tap in `_unhandled_input()`**

Modify the existing `InputEventScreenTouch` branch's `if touch_event.pressed:` block -- add an `elif` after the existing pinch-seed `if _active_touches.size() == 2:` line:

```gdscript
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
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
		else:
			_active_touches.erase(touch_event.index)
			_pinch_last_distance = -1.0
		return
```

- [ ] **Step 5: Draw the Stronghold marker (confirmed and/or pending)**

Add directly after the Lore Stone draw loop (from Task 5), before the player marker block:

```gdscript
	if _has_pending_stronghold:
		_draw_stronghold_marker(_pending_stronghold_lat, _pending_stronghold_lon, marker_scale)
	elif _stronghold_placed:
		_draw_stronghold_marker(_stronghold_lat, _stronghold_lon, marker_scale)
```

Add the helper directly after `_draw_map_geometry()`:

```gdscript
func _draw_stronghold_marker(lat: float, lon: float, marker_scale: float) -> void:
	var pos := _world_to_screen(_project(lat, lon))
	if _stronghold_texture != null:
		var size := STRONGHOLD_MARKER_SIZE * marker_scale
		draw_texture_rect(
			_stronghold_texture, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false
		)
	else:
		draw_circle(pos, GATE_RADIUS * marker_scale, Color.YELLOW)
```

- [ ] **Step 6: Manually verify**

Run the full GUT suite (unchanged pass count from Task 5 -- `scenes/`-only). Re-read the diff and confirm: (1) `_screen_to_lonlat()` is the algebraic inverse of `_world_to_screen()`/`_project()` -- work through it by hand once: `_world_to_screen` computes `Vector2(rel.x, -rel.y) * zoom` where `rel = world - player_world_pos`; `_screen_to_lonlat` undoes that as `local/zoom` with the y-flip re-applied, then adds `player_world_pos`, matching exactly. (2) the placement tap branch only fires when exactly one touch is down (`_active_touches.size() == 1` after insertion, i.e. it was the only touch), so it can never fire on the same event as the two-touch pinch-seed branch above it. (3) pending vs. confirmed Stronghold marker draw is mutually exclusive (`elif`), so there's never a stale double-marker during placement.

- [ ] **Step 7: Commit**

```bash
git add scenes/map_view.gd
git commit -m "Map POI: Stronghold marker + tap-to-place flow"
```

---

### Task 7: `scenes/map_view.gd` — Incursion badge

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `ArtPaths.map_marker()` (existing).
- Produces: nothing new consumed elsewhere -- purely a presentation change to the existing `_active_incursion_family` banner.

- [ ] **Step 1: Load the texture**

Add to `_ready()`:

```gdscript
	_incursion_texture = ArtPaths.map_marker("incursion")
```

Add the var directly after `_stronghold_texture` (from Task 6):

```gdscript
var _incursion_texture: Texture2D = null
```

Add the constant directly after `STRONGHOLD_MARKER_SIZE` (from Task 6):

```gdscript
const INCURSION_BADGE_SIZE := 32.0  ## fixed screen-space size -- this is a
## HUD badge for an area-wide effect, not a world-space marker, so it
## doesn't scale with marker_scale/zoom like the point markers above do.
```

- [ ] **Step 2: Replace the text-only banner**

Replace the existing incursion block in `_draw()` (currently right after the "Waiting for GPS fix..." early-return):

```gdscript
	if _active_incursion_family != "":
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-100, -60),
			"⚡ Incursion: %s" % _active_incursion_family,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			24,
			Color.ORANGE_RED
		)
```

with:

```gdscript
	if _active_incursion_family != "":
		if _incursion_texture != null:
			draw_texture_rect(
				_incursion_texture,
				Rect2(Vector2(-140, -90), Vector2(INCURSION_BADGE_SIZE, INCURSION_BADGE_SIZE)),
				false
			)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-100, -60),
				_active_incursion_family,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				24,
				Color.ORANGE_RED
			)
		else:
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-100, -60),
				"⚡ Incursion: %s" % _active_incursion_family,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				24,
				Color.ORANGE_RED
			)
```

- [ ] **Step 3: Manually verify**

Run the full GUT suite (unchanged pass count). Re-read the diff: confirm the fallback branch (no art) is byte-identical to the banner this replaces, so nothing visually changes for anyone running without the `incursion` marker art.

- [ ] **Step 4: Commit**

```bash
git add scenes/map_view.gd
git commit -m "Map POI: Incursion zone badge (icon + text, was text-only)"
```

---

### Task 8: Stronghold placement UI + proximity gate on existing actions

**Files:**
- Modify: `scenes/main.tscn`, `scenes/stronghold_view.gd`, `scenes/main.gd`

**Interfaces:**
- Consumes: `MapView.begin_stronghold_placement()`/`end_stronghold_placement()`/`has_pending_stronghold_position()`/`pending_stronghold_position()`/`set_stronghold()` (Task 6), `HunterState.place_stronghold()` (Task 4), `GameLogic.POI_PROXIMITY_RADIUS_M` (Task 3), `MapGeometry.distance_metres()` (Task 1).
- Produces: `StrongholdView.update_position(lat: float, lon: float) -> void`. Nothing else consumed by a later task.

- [ ] **Step 1: Add scene nodes**

In `scenes/main.tscn`, add a "Place Stronghold" button to `StrongholdPanel` -- insert directly after the existing `UpgradeStrongholdButton` node block (around line 944, before `InfoLabel`):

```
[node name="PlaceStrongholdButton" type="Button" parent="GameUI/StrongholdPanel"]
offset_left = 720.0
offset_top = 90.0
offset_right = 1000.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 20
text = "Place Stronghold"
```

Add two new `GameUI`-level buttons (visible only during placement, hidden the rest of the time) -- insert directly after the existing `EnterGateButton` node block (around line 131, before `NavScroll`):

```
[node name="ConfirmStrongholdButton" type="Button" parent="GameUI"]
visible = false
offset_left = 40.0
offset_top = 280.0
offset_right = 340.0
offset_bottom = 330.0
theme_override_font_sizes/font_size = 20
text = "Confirm Location"

[node name="CancelStrongholdButton" type="Button" parent="GameUI"]
visible = false
offset_left = 360.0
offset_top = 280.0
offset_right = 560.0
offset_bottom = 330.0
theme_override_font_sizes/font_size = 20
text = "Cancel"
```

- [ ] **Step 2: `StrongholdView.update_position()` + proximity gate**

In `scenes/stronghold_view.gd`, add a new var directly after `var _state: HunterState`:

```gdscript
var _player_lat: float = 0.0  ## fed in from main.gd's GPS callback -- used only
var _player_lon: float = 0.0  ## by the Collect/Assign/Unassign proximity gate below.
var _has_player_position: bool = false
```

Add the public setter directly after `bind()`:

```gdscript
## Called from main.gd's _on_location_update() every GPS fix -- this panel
## needs the player's live position for the Collect/reassign proximity
## gate (§22: "collect resources and reassign shadows when you're near
## your Stronghold... remote viewing is fine, hands-on management happens
## on-site" -- viewing/refresh/upgrades stay unrestricted, only those two
## actions are gated).
func update_position(lat: float, lon: float) -> void:
	_player_lat = lat
	_player_lon = lon
	_has_player_position = true
```

Add the gate check as a new private method directly after `_node_prefix()`:

```gdscript
func _is_near_stronghold() -> bool:
	if not _state.stronghold_placed or not _has_player_position:
		return false
	var dist := MapGeometry.distance_metres(
		_player_lat, _player_lon, _state.stronghold_lat, _state.stronghold_lon
	)
	return dist <= GameLogic.POI_PROXIMITY_RADIUS_M
```

Modify `_on_collect_pressed()`, `_on_assign_pressed()`, and `_on_unassign_pressed()` to check it first. `_on_collect_pressed()` becomes:

```gdscript
func _on_collect_pressed() -> void:
	if not _is_near_stronghold():
		collected.emit("\n\nNot near your Stronghold")
		return
	var result := _state.collect_stronghold(Time.get_unix_time_from_system())
	SaveService.save(_state)
	refresh()
	state_changed.emit()

	var msg := (
		"\n\nStronghold collected: +%d Essence, +%d Gate Tickets"
		% [result["essence_gained"], result["tickets_gained"]]
	)
	var shadow_levels_gained: Dictionary = result["shadow_levels_gained"]
	if not shadow_levels_gained.is_empty():
		msg += "\n%d shadow(s) leveled up from idle training" % shadow_levels_gained.size()
	collected.emit(msg)
```

`_on_assign_pressed()` becomes:

```gdscript
func _on_assign_pressed(facility_id: String) -> void:
	if not _is_near_stronghold():
		collected.emit("\n\nNot near your Stronghold")
		return
	for shadow: Dictionary in _state.army:
		var shadow_id: String = shadow["instance_id"]
		if not _state.is_shadow_assigned(shadow_id):
			if _state.assign_shadow_to_facility(facility_id, shadow_id):
				SaveService.save(_state)
				refresh()
			return
```

`_on_unassign_pressed()` becomes:

```gdscript
func _on_unassign_pressed(facility_id: String) -> void:
	if not _is_near_stronghold():
		collected.emit("\n\nNot near your Stronghold")
		return
	var assigned: Array = _state.stronghold_facilities[facility_id]["assigned"].duplicate()
	for shadow_id in assigned:
		_state.unassign_shadow(shadow_id)
	SaveService.save(_state)
	refresh()
```

- [ ] **Step 3: Wire the placement flow in `main.gd`**

Add three new `@onready` vars directly after `@onready var stronghold_view: StrongholdView = $GameUI/StrongholdPanel`:

```gdscript
@onready var place_stronghold_button: Button = $GameUI/StrongholdPanel/PlaceStrongholdButton
@onready var confirm_stronghold_button: Button = $GameUI/ConfirmStrongholdButton
@onready var cancel_stronghold_button: Button = $GameUI/CancelStrongholdButton
```

In `_setup_gear_panels()`, add three new connections directly after the existing `stronghold_view.collected.connect(...)` line:

```gdscript
		place_stronghold_button.pressed.connect(_on_place_stronghold_pressed)
		confirm_stronghold_button.pressed.connect(_on_confirm_stronghold_pressed)
		cancel_stronghold_button.pressed.connect(_on_cancel_stronghold_pressed)
```

Add three new handler functions directly after `_on_use_ticket_pressed()`'s function body ends (find it via its existing doc comment "Phase 2/P7 step 1: spends a gate ticket..."; add these after its closing brace):

```gdscript
func _on_place_stronghold_pressed() -> void:
	stronghold_view.visible = false
	map_view.begin_stronghold_placement()
	confirm_stronghold_button.visible = true
	cancel_stronghold_button.visible = true


func _on_confirm_stronghold_pressed() -> void:
	if map_view.has_pending_stronghold_position():
		var lonlat := map_view.pending_stronghold_position()
		state.place_stronghold(lonlat.y, lonlat.x)
		SaveService.save(state)
		map_view.set_stronghold(state.stronghold_lat, state.stronghold_lon, true)
		place_stronghold_button.text = "Move Stronghold"
	map_view.end_stronghold_placement()
	confirm_stronghold_button.visible = false
	cancel_stronghold_button.visible = false


func _on_cancel_stronghold_pressed() -> void:
	map_view.end_stronghold_placement()
	confirm_stronghold_button.visible = false
	cancel_stronghold_button.visible = false
```

Feed the live position into `stronghold_view` from `_on_location_update()` -- add directly after the existing `map_view.show_position(lat, lon, state.hunter_rank)` line:

```gdscript
	stronghold_view.update_position(lat, lon)
```

Finally, in `_start_game()`, feed the saved Stronghold location into `map_view` once state is bound -- add directly after the existing `stronghold_view.bind(state)` line:

```gdscript
	map_view.set_stronghold(state.stronghold_lat, state.stronghold_lon, state.stronghold_placed)
	if state.stronghold_placed:
		place_stronghold_button.text = "Move Stronghold"
```

- [ ] **Step 4: Manually verify**

Run the full GUT suite (unchanged pass count -- this task is `scenes/`-only). Re-read the diff and confirm: (1) `_is_near_stronghold()` is checked at the very top of all three gated handlers, before any state mutation; (2) `_on_confirm_stronghold_pressed()` correctly un-swaps lon/lat when calling `place_stronghold(lat, lon)` -- `pending_stronghold_position()` returns `Vector2(lon, lat)` per Task 6, so it must be called as `place_stronghold(lonlat.y, lonlat.x)`, not `(lonlat.x, lonlat.y)`; (3) the "Move Stronghold" button relabel happens both right after a successful placement AND on a fresh `_start_game()` for a returning player who already placed one (so it's never stuck showing "Place Stronghold" for someone who already has).

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn scenes/stronghold_view.gd scenes/main.gd
git commit -m "Map POI: Stronghold tap-to-place UI + proximity gate on collect/reassign"
```

---

### Task 9: "Claim Sanctuary" + "Lore Stone" buttons

**Files:**
- Modify: `scenes/main.tscn`, `scenes/main.gd`

**Interfaces:**
- Consumes: `MapView.nearest_sanctuary_index_in_range()`/`nearest_lorestone_index_in_range()`/`get_sanctuary()`/`get_lorestone()` (Task 5), `HunterState.claim_sanctuary()`/`discover_lorestone()` (Task 4), `GameLogic.POI_PROXIMITY_RADIUS_M`/`SANCTUARY_ESSENCE_REWARD`/`SANCTUARY_TICKET_REWARD`/`SANCTUARY_CLAIM_COOLDOWN_S`/`LORESTONE_ESSENCE_REWARD` (Task 3), `PoiSpawner.LORE_SNIPPETS` (Task 2).
- Produces: nothing consumed by a later task -- this is the final task in the plan.

- [ ] **Step 1: Add scene nodes**

In `scenes/main.tscn`, add two new buttons directly after the `EnterGateButton` node block (around line 131) -- **before** the `ConfirmStrongholdButton`/`CancelStrongholdButton` nodes Task 8 added, so this task's diff inserts above theirs:

```
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

Since Task 8's `ConfirmStrongholdButton`/`CancelStrongholdButton` were placed at the same `offset_top = 280.0` row, move those two down one row to `offset_top = 340.0` / `offset_bottom = 390.0` now that this row is taken -- edit the two node blocks Task 8 added so all four buttons stack in two clean rows instead of overlapping.

- [ ] **Step 2: Wire the buttons in `main.gd`**

Add two new `@onready` vars directly after `place_stronghold_button`/`confirm_stronghold_button`/`cancel_stronghold_button` (Task 8):

```gdscript
@onready var claim_sanctuary_button: Button = $GameUI/ClaimSanctuaryButton
@onready var lorestone_button: Button = $GameUI/LoreStoneButton
```

In `_setup_gear_panels()`, add two more connections directly after Task 8's three placement-button connections:

```gdscript
		claim_sanctuary_button.pressed.connect(_on_claim_sanctuary_pressed)
		lorestone_button.pressed.connect(_on_lorestone_pressed)
```

Add two new handler functions directly after Task 8's `_on_cancel_stronghold_pressed()`:

```gdscript
## Same always-visible / message-on-press convention as
## _on_enter_gate_pressed() -- no per-frame enable/disable bookkeeping.
func _on_claim_sanctuary_pressed() -> void:
	if not _has_location:
		label.text += "\n\nNo GPS fix yet"
		return
	var idx := map_view.nearest_sanctuary_index_in_range(
		_last_lat, _last_lon, GameLogic.POI_PROXIMITY_RADIUS_M
	)
	if idx < 0:
		label.text += "\n\nNo Sanctuary nearby"
		return
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


func _on_lorestone_pressed() -> void:
	if not _has_location:
		label.text += "\n\nNo GPS fix yet"
		return
	var idx := map_view.nearest_lorestone_index_in_range(
		_last_lat, _last_lon, GameLogic.POI_PROXIMITY_RADIUS_M
	)
	if idx < 0:
		label.text += "\n\nNo Lore Stone nearby"
		return
	var stone := map_view.get_lorestone(idx)
	var discovered := state.discover_lorestone(stone["id"], GameLogic.LORESTONE_ESSENCE_REWARD)
	if not discovered:
		label.text += "\n\nAlready discovered"
		return
	SaveService.save(state)
	_refresh_label()
	var lore_index: int = stone["lore_index"]
	label.text += "\n\n%s\n(+%d Essence)" % [PoiSpawner.LORE_SNIPPETS[lore_index], GameLogic.LORESTONE_ESSENCE_REWARD]
```

- [ ] **Step 3: Manually verify**

Run the full GUT suite (unchanged pass count -- `scenes/`-only). Re-read the diff and confirm: (1) both handlers check `_has_location` before calling into `map_view`, matching `_on_use_ticket_pressed()`'s existing "No GPS fix yet" pattern; (2) `_on_lorestone_pressed()` reads `stone["id"]`/`stone["lore_index"]` from `map_view.get_lorestone(idx)`, not from `_lorestones` directly (that array is private to `MapView`); (3) `.tscn` offsets for all four new `GameUI`-level buttons (`ClaimSanctuaryButton`/`LoreStoneButton` from this task, `ConfirmStrongholdButton`/`CancelStrongholdButton` from Task 8) don't visually overlap -- two rows of two, `280-330` and `340-390`.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "Map POI: Claim Sanctuary + Lore Stone buttons"
```

---

## Post-plan checklist (controller, after all tasks — not a dispatched task)

- [ ] Full GUT suite green (5 + 10 + 0 + 13 = 28 new tests from Tasks 1/2/3/4; nothing else moves; total should be exactly 28 higher than the count at the start of this plan).
- [ ] `gdformat`/`gdlint` clean on every touched file.
- [ ] Real on-device build + install + launch (same pipeline documented in `native/android/README.md`: `godot --export-debug`, re-patch the two Gradle manifest overrides, build via `gradlew` directly with the `-P` properties **including `-Paddons_directory=../../addons/gps_health_bridge`**, sign with Godot's debug keystore, `adb install`).
- [ ] On-device verification of every new interaction: Sanctuary/Lore Stone markers visible and claimable in range, out-of-range/already-claimed messages both fire correctly, Stronghold tap-to-place produces a marker that survives an app relaunch (round-trips through `SaveService`), Stronghold Collect/Assign/Unassign are blocked with "Not near your Stronghold" when far from the placed location and work normally when close, Incursion badge renders (may need `_active_incursion_family` forced via the same temp-debug-GPS-override trick used for the map-render verification, since a real active incursion in the test area on a given day isn't guaranteed).
- [ ] Report back: which of the two placeholder-vs-real judgment calls (Sanctuary reward amounts, Lore Stone snippet text) look right in context now that they're visible on a real device, vs. want adjusting.
