# Map vector-line rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Phase-1 placeholder map (`draw_circle()` dots on a flat lat/lon approximation) with a real rendering of Darlington's actual street/water geometry, drawn directly with Godot draw calls in the game's dark palette, with pan and pinch-zoom — per §19b/§19c and `prompts/prompt_for_code_map_render_spike.md`.

**Architecture:** Pure projection/simplification/style-lookup logic lives in a new `core/map_geometry.gd`, fully unit-tested. The binary data loader and all rendering/input handling stay in `scenes/map_view.gd` (engine-dependent: `FileAccess`, `_draw()`, touch input), manually verified per this project's `core`/`scenes` split.

**Tech Stack:** Godot 4.7.1 (mono), GDScript. No new native plugin, no new external dependency — this whole approach exists specifically to avoid that (see the spike report / §19b's RESOLVED banner).

## Already done (prerequisite, not part of this plan's tasks)

The data pipeline is complete and verified with real data — this plan starts from its output:

- `tools/map_extract/fetch_and_convert.py` — documented, re-runnable Python 3 script (stdlib only) that fetches OSM road/water geometry from the Overpass API for a bounding box and converts it to the binary format below. Already run once for the Darlington test bbox.
- `content/map_data/darlington.bin` — the committed extract. **Real measured numbers** (not estimates): 4,826 ways, 29,544 points, **245,863 bytes (240.1 KB)** — well under the ~0.4 MB estimate in the brief.
- Binary format (little-endian), full detail in the script's own docstring:
  ```
  Header: magic b"HHMD" (4 bytes), version uint8=1, bbox 4x float32
          (south, west, north, east), origin_x/origin_y float32 (Web
          Mercator metres of the bbox centre), way_count uint32
  Per way: class_id uint8, point_count uint16,
           point_count * (float32 x, float32 y) -- Web Mercator metres,
           RELATIVE TO origin_x/origin_y (keeps values within a few km of
           zero -- absolute Web Mercator values are in the millions of
           metres at this latitude, which would blow float32's precision
           budget at the sub-metre scale roads need)
  ```
- `class_id` values: `0` = major_road, `1` = minor_road, `2` = path, `3` = water_line, `4` = water_area. `water_area` ways are closed rings (first point == last point) meant to be filled; every other class is an open polyline meant to be stroked.

## Global Constraints

- Static typing everywhere. Tabs for indentation. `snake_case`/`PascalCase` conventions.
- `core/map_geometry.gd` is pure GDScript — no `Node`, no scene tree, no `FileAccess`/engine I/O. Every function in it gets a GUT test in `tests/unit/test_map_geometry.gd`.
- All rendering, input handling, and file loading stays in `scenes/map_view.gd` — manually verified, no GUT test (matches this project's established `scenes/` convention).
- Palette (from §19b, already converted to hex for direct use — no MapLibre style JSON, no runtime theme switching):
  - Background: `#050b12` (matches this project's already-locked near-black from §9b, inside the brief's `#03070d`–`#080d14` range)
  - Water: `#02040a` (darker and cooler than background)
  - Major road: `#1b2532`
  - Minor road: `#0f1620`
  - Path: `#0a0f16`
  - No labels anywhere, no POI icons from OSM data — the game supplies its own gate markers.
- World-space unit is **metres** (Web Mercator, relative to the file's stored origin) throughout `core/map_geometry.gd` and the loaded way data. Screen-space is pixels. The conversion between them is a single explicit `zoom` value (pixels per metre) plus a pan offset — no `Camera2D` node, no relying on node/parent `scale` for the conversion (Godot's `draw_polyline` width parameter is affected by node transform scale, which would make road line width shrink to invisible at low zoom instead of respecting a minimum on-screen width; doing the transform explicitly in code keeps line-width behavior fully controllable).
- Existing gate/player marker rendering (`RANK_COLORS`, `draw_circle` for markers, gate rank text) stays visually as-is — only the *positioning math* changes (from the flat `PIXELS_PER_DEGREE` approximation to the same Mercator-relative-to-origin space the road data uses). Marker art/rank-coloring itself is explicitly out of scope (flagged separately per §19's "one universal marker" revision).
- `gdformat`/`gdlint` run automatically via the post-edit hook on `.gd` files.

---

### Task 1: `core/map_geometry.gd` — pure projection, simplification, and style lookup

**Files:**
- Create: `core/map_geometry.gd`
- Test: `tests/unit/test_map_geometry.gd`

**Interfaces:**
- Produces: `MapGeometry.lonlat_to_mercator(lon, lat) -> Vector2`, `MapGeometry.CLASS_MAJOR_ROAD`/`CLASS_MINOR_ROAD`/`CLASS_PATH`/`CLASS_WATER_LINE`/`CLASS_WATER_AREA` (int constants matching the binary format's `class_id` values exactly), `MapGeometry.road_color(class_id) -> Color`, `MapGeometry.road_width_px(class_id) -> float`, `MapGeometry.simplify_polyline(points, tolerance) -> PackedVector2Array`, `MapGeometry.way_bounds(points) -> Rect2`, `MapGeometry.rect_intersects(a: Rect2, b: Rect2) -> bool`. Consumed by Task 2.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_map_geometry.gd`:

```gdscript
extends GutTest
## Pure projection/simplification/style-lookup logic for the vector-line
## map renderer (§19b/§19c) -- no engine dependency, so it's covered here
## rather than only manually verified like scenes/map_view.gd.


func test_lonlat_to_mercator_at_origin() -> void:
	var result := MapGeometry.lonlat_to_mercator(0.0, 0.0)
	assert_almost_eq(result.x, 0.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.01)


func test_lonlat_to_mercator_known_point() -> void:
	# Darlington town centre, roughly. Web Mercator X should be strongly
	# negative (west of the prime meridian); Y should be positive (well
	# north of the equator).
	var result := MapGeometry.lonlat_to_mercator(-1.5549, 54.5235)
	assert_lt(result.x, 0.0)
	assert_gt(result.y, 0.0)
	# Sanity-check the magnitude: -1.5549 degrees of longitude at this
	# latitude is roughly -173,100m in Web Mercator (radius * radians).
	assert_almost_eq(result.x, -173100.0, 500.0)


func test_lonlat_to_mercator_longitude_scales_linearly() -> void:
	# Mercator X is a pure linear function of longitude (no latitude
	# dependence) -- doubling longitude doubles X.
	var a := MapGeometry.lonlat_to_mercator(-1.0, 54.5)
	var b := MapGeometry.lonlat_to_mercator(-2.0, 54.5)
	assert_almost_eq(b.x, a.x * 2.0, 1.0)


func test_road_color_matches_class() -> void:
	assert_eq(MapGeometry.road_color(MapGeometry.CLASS_MAJOR_ROAD), Color(0x1b / 255.0, 0x25 / 255.0, 0x32 / 255.0))
	assert_eq(MapGeometry.road_color(MapGeometry.CLASS_MINOR_ROAD), Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0))
	assert_eq(MapGeometry.road_color(MapGeometry.CLASS_PATH), Color(0x0a / 255.0, 0x0f / 255.0, 0x16 / 255.0))
	assert_eq(MapGeometry.road_color(MapGeometry.CLASS_WATER_AREA), Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0))
	assert_eq(MapGeometry.road_color(MapGeometry.CLASS_WATER_LINE), Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0))


func test_road_width_major_wider_than_minor_wider_than_path() -> void:
	var major := MapGeometry.road_width_px(MapGeometry.CLASS_MAJOR_ROAD)
	var minor := MapGeometry.road_width_px(MapGeometry.CLASS_MINOR_ROAD)
	var path := MapGeometry.road_width_px(MapGeometry.CLASS_PATH)
	assert_gt(major, minor)
	assert_gt(minor, path)
	assert_gt(path, 0.0)  # never literally zero/invisible


func test_simplify_polyline_removes_collinear_points() -> void:
	var points := PackedVector2Array(
		[Vector2(0, 0), Vector2(1, 0.001), Vector2(2, 0), Vector2(10, 0)]
	)
	var simplified := MapGeometry.simplify_polyline(points, 0.5)
	# The two near-collinear middle points should collapse away, keeping
	# just the endpoints (both roughly on the same line).
	assert_eq(simplified.size(), 2)
	assert_eq(simplified[0], Vector2(0, 0))
	assert_eq(simplified[1], Vector2(10, 0))


func test_simplify_polyline_keeps_a_real_corner() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(5, 5), Vector2(10, 0)])
	var simplified := MapGeometry.simplify_polyline(points, 0.5)
	# A sharp corner well outside the tolerance must survive.
	assert_eq(simplified.size(), 3)


func test_simplify_polyline_short_input_unchanged() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])
	var simplified := MapGeometry.simplify_polyline(points, 5.0)
	assert_eq(simplified.size(), 2)


func test_way_bounds() -> void:
	var points := PackedVector2Array([Vector2(-5, 10), Vector2(20, -3), Vector2(0, 0)])
	var bounds := MapGeometry.way_bounds(points)
	assert_eq(bounds.position, Vector2(-5, -3))
	assert_eq(bounds.size, Vector2(25, 13))


func test_rect_intersects_overlapping() -> void:
	var a := Rect2(Vector2(0, 0), Vector2(10, 10))
	var b := Rect2(Vector2(5, 5), Vector2(10, 10))
	assert_true(MapGeometry.rect_intersects(a, b))


func test_rect_intersects_disjoint() -> void:
	var a := Rect2(Vector2(0, 0), Vector2(10, 10))
	var b := Rect2(Vector2(100, 100), Vector2(10, 10))
	assert_false(MapGeometry.rect_intersects(a, b))
```

- [ ] **Step 2: Run tests to verify they fail**

Run the project's GUT suite and confirm every new test fails with "Identifier MapGeometry not declared" or similar (the class doesn't exist yet), and no other test's pass count changed.

- [ ] **Step 3: Implement `core/map_geometry.gd`**

```gdscript
class_name MapGeometry
## Pure projection/simplification/style-lookup logic for the vector-line
## map renderer (§19b/§19c). No engine dependency (no Node, no FileAccess)
## -- scenes/map_view.gd owns loading the binary extract and all drawing;
## this class is the testable math underneath it.

const EARTH_RADIUS_M := 6378137.0  ## WGS84 semi-major axis -- also the
## sphere radius Web Mercator (EPSG:3857) uses. Must match
## tools/map_extract/fetch_and_convert.py's EARTH_RADIUS_M exactly, or
## the live GPS position/gate markers won't land in the same coordinate
## space as the pre-projected road data.

## Matches content/map_data/*.bin's per-way class_id byte exactly --
## see tools/map_extract/fetch_and_convert.py's WAY_CLASSES.
const CLASS_MAJOR_ROAD := 0
const CLASS_MINOR_ROAD := 1
const CLASS_PATH := 2
const CLASS_WATER_LINE := 3
const CLASS_WATER_AREA := 4


## Same formula as the Python conversion script -- must stay in sync.
static func lonlat_to_mercator(lon: float, lat: float) -> Vector2:
	var x := deg_to_rad(lon) * EARTH_RADIUS_M
	var y := log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0)) * EARTH_RADIUS_M
	return Vector2(x, y)


## §19b palette, converted to hex once here rather than duplicated at
## every call site.
static func road_color(class_id: int) -> Color:
	match class_id:
		CLASS_MAJOR_ROAD:
			return Color(0x1b / 255.0, 0x25 / 255.0, 0x32 / 255.0)
		CLASS_MINOR_ROAD:
			return Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0)
		CLASS_PATH:
			return Color(0x0a / 255.0, 0x0f / 255.0, 0x16 / 255.0)
		CLASS_WATER_LINE, CLASS_WATER_AREA:
			return Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0)
		_:
			return Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0)


## Base on-screen width in pixels, BEFORE any zoom scaling scenes/
## map_view.gd applies -- deliberately not true-to-real-world-scale so
## roads stay legible at any zoom rather than vanishing to sub-pixel
## width when zoomed out (§19b: "grid legible, no more").
static func road_width_px(class_id: int) -> float:
	match class_id:
		CLASS_MAJOR_ROAD:
			return 4.0
		CLASS_MINOR_ROAD:
			return 2.0
		CLASS_PATH:
			return 1.0
		_:
			return 2.0


## Ramer-Douglas-Peucker polyline simplification. `tolerance` is in the
## same units as `points` (metres, for this project's callers). Available
## for scenes/map_view.gd to apply at low zoom if on-device performance
## needs it -- see this plan's Task 3.
static func simplify_polyline(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var max_dist := 0.0
	var max_index := 0
	var start := points[0]
	var end := points[points.size() - 1]

	for i in range(1, points.size() - 1):
		var dist := _point_segment_distance(points[i], start, end)
		if dist > max_dist:
			max_dist = dist
			max_index = i

	if max_dist <= tolerance:
		return PackedVector2Array([start, end])

	var left := simplify_polyline(points.slice(0, max_index + 1), tolerance)
	var right := simplify_polyline(points.slice(max_index, points.size()), tolerance)
	# `right`'s first point duplicates `left`'s last point (both are
	# points[max_index]) -- drop it before concatenating.
	return left + right.slice(1, right.size())


static func _point_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg := seg_end - seg_start
	var seg_len_sq := seg.length_squared()
	if seg_len_sq == 0.0:
		return point.distance_to(seg_start)
	var t: float = clamp((point - seg_start).dot(seg) / seg_len_sq, 0.0, 1.0)
	var projection := seg_start + seg * t
	return point.distance_to(projection)


static func way_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


static func rect_intersects(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)
```

- [ ] **Step 4: Run tests to verify they pass**

Run the full GUT suite. All 11 new tests pass; total pass count is exactly 11 higher than before this task, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/map_geometry.gd tests/unit/test_map_geometry.gd
git commit -m "Map render: core/map_geometry.gd -- projection, simplification, style lookup"
```

---

### Task 2: `scenes/map_view.gd` — load the extract, render roads/water, reposition existing markers

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `MapGeometry.lonlat_to_mercator()`, `MapGeometry.road_color()`, `MapGeometry.road_width_px()`, `MapGeometry.CLASS_*` constants (Task 1).
- Produces: nothing new consumed by a later task in this plan — Task 3 adds pan/zoom on top of the same `_ways`/rendering this task builds, in the same file.

No `.tscn` change in this task (the `MapView` node itself is unchanged; Task 3 is the one that may add input-handling wiring).

- [ ] **Step 1: Load the binary extract once, at `_ready()`**

Add a `_ready()` function (this class doesn't have one today) and the loading logic. Read the file header, then each way's `class_id`/`point_count`/points, matching `tools/map_extract/fetch_and_convert.py`'s format exactly:

```gdscript
const MAP_DATA_PATH := "res://content/map_data/darlington.bin"

var _ways: Array = []  ## Array[Dictionary]: {"class_id": int, "points": PackedVector2Array}
## -- world metres, relative to _origin below. Loaded once at _ready().
var _origin_x: float = 0.0  ## Web Mercator metres of the extract's bbox centre --
var _origin_y: float = 0.0  ## every live GPS/gate lat-lon must subtract this same
## origin after projecting, to land in the same relative-metres space the
## loaded road/water geometry is already in.


func _ready() -> void:
	_load_map_data()


func _load_map_data() -> void:
	var file := FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MapView: failed to open %s (%s)" % [MAP_DATA_PATH, FileAccess.get_open_error()])
		return

	var magic := file.get_buffer(4).get_string_from_ascii()
	if magic != "HHMD":
		push_error("MapView: %s has bad magic %s, expected HHMD" % [MAP_DATA_PATH, magic])
		return
	var version := file.get_8()
	if version != 1:
		push_error("MapView: %s has unsupported version %d" % [MAP_DATA_PATH, version])
		return

	file.get_float()  # bbox south -- kept in the file for reference/debugging, unused here
	file.get_float()  # bbox west
	file.get_float()  # bbox north
	file.get_float()  # bbox east
	_origin_x = file.get_float()
	_origin_y = file.get_float()
	var way_count := file.get_32()

	_ways = []
	for i in way_count:
		var class_id := file.get_8()
		var point_count := file.get_16()
		var points := PackedVector2Array()
		points.resize(point_count)
		for p in point_count:
			var x := file.get_float()
			var y := file.get_float()
			points[p] = Vector2(x, y)
		# Precomputed once here, not per-frame: a fixed, generous tolerance
		# for use when zoomed out (Task 3 picks between this and `points`
		# based on current zoom). Running Douglas-Peucker every _draw()
		# call would cost more than the simplification saves; caching it
		# at load time is what makes "simplify aggressively at low zoom"
		# actually cheap.
		var simplified := MapGeometry.simplify_polyline(points, 3.0)
		_ways.append({"class_id": class_id, "points": points, "simplified_points": simplified})

	file.close()
```

- [ ] **Step 2: Reposition the player and gates into the same coordinate space**

The existing `show_position()`/`_draw()` code positions gates and the player using `_center_lat`/`_center_lon` and the flat `PIXELS_PER_DEGREE` approximation. Replace that with Mercator-relative-to-origin, matching the loaded road data's space.

Add a helper:

```gdscript
## Projects a live lat/lon (player position, a gate's spawn point) into
## the SAME world-metres space the loaded road/water geometry already
## uses -- Mercator, relative to the extract's own origin.
func _project(lat: float, lon: float) -> Vector2:
	var merc := MapGeometry.lonlat_to_mercator(lon, lat)
	return Vector2(merc.x - _origin_x, merc.y - _origin_y)
```

Update `show_position()` and `get_nearest_gate_index()`/`_draw()` to compute and use `_project()`'d positions instead of the old `(lon - _center_lon) * PIXELS_PER_DEGREE` math. Keep `_center_lat`/`_center_lon` as the raw lat/lon the game logic already reads elsewhere (`Incursion.area_key()` etc. still need real lat/lon, not metres) -- add a new `var _player_world_pos: Vector2 = Vector2.ZERO` set inside `show_position()` via `_project(lat, lon)`, and use that for all screen-space math instead.

`get_nearest_gate_index()` currently computes distance in raw lat/lon degrees (`dlat`/`dlon`) -- this still works fine as a *relative* nearest-neighbor comparison (degrees are monotonic with real distance at any fixed latitude for a "which is closest" comparison, even though they're not a true distance in metres), so leave that function's math as-is; only the *drawing* positions change in this task.

- [ ] **Step 3: Render water, then roads, then the existing markers, in `_draw()`**

Replace the body of `_draw()`. Keep the existing "no fix yet" early-return and incursion-label text exactly as they are today (just after the `_has_fix` check) -- only the geometry/marker drawing below that changes:

```gdscript
func _draw() -> void:
	if not _has_fix:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-100, 0),
			"Waiting for GPS fix...",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			24
		)
		return

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

	_draw_map_geometry()

	for g: Dictionary in _gates:
		var pos := _project(g["lat"], g["lon"]) - _player_world_pos
		var color: Color = RANK_COLORS.get(g["rank"], Color.WHITE)
		draw_circle(pos, GATE_RADIUS, color)
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-8, 8),
			g["rank"],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			28,
			Color.BLACK
		)

	draw_circle(Vector2.ZERO, PLAYER_RADIUS, Color.DEEP_SKY_BLUE)


## Water first (so roads draw on top of it, not the reverse), then roads
## by class. Every world position is drawn relative to the player's own
## world position, matching how gates/the player marker are drawn below
## (Vector2.ZERO is always "where the player currently is" in this node's
## local draw space) -- this task doesn't yet add pan, so the player stays
## visually centred; Task 3 adds a pan offset to this same subtraction.
func _draw_map_geometry() -> void:
	for way: Dictionary in _ways:
		var class_id: int = way["class_id"]
		var points: PackedVector2Array = way["points"]
		if points.size() < 2:
			continue
		var screen_points := PackedVector2Array()
		screen_points.resize(points.size())
		for i in points.size():
			screen_points[i] = points[i] - _player_world_pos
		if class_id == MapGeometry.CLASS_WATER_AREA:
			draw_colored_polygon(screen_points, MapGeometry.road_color(class_id))
		else:
			draw_polyline(
				screen_points, MapGeometry.road_color(class_id), MapGeometry.road_width_px(class_id), true
			)
```

- [ ] **Step 4: Manually verify**

Run the full GUT suite (no `core/` file besides Task 1's untouched-by-this-task `map_geometry.gd` is affected, so pass count should just include Task 1's 11 new tests, nothing else changes). No runtime rendering check is possible without a device -- Task 3 and the final on-device build are where this actually gets seen; for this task, re-read the diff against the exact code above and confirm: `_load_map_data()` reads fields in the exact order `fetch_and_convert.py` writes them (magic, version, 4x bbox float, origin_x, origin_y, way_count, then per-way class_id/point_count/points) -- a field-order mismatch here would silently read garbage without necessarily crashing.

- [ ] **Step 5: Commit**

```bash
git add scenes/map_view.gd
git commit -m "Map render: load extract, draw real roads/water, reproject markers"
```

---

### Task 3: Pan and pinch-zoom

**Files:**
- Modify: `scenes/map_view.gd`

**Interfaces:**
- Consumes: `_ways`, `_player_world_pos`, `_draw_map_geometry()` (Task 2) -- extends them with a pan offset and a zoom scale, not a redesign.

No `.tscn` change needed -- `Node2D` receives `_unhandled_input()` without any extra wiring, and `MapView` already exists as a node in `main.tscn`.

- [ ] **Step 1: Add zoom/pan state and the world-to-screen transform**

```gdscript
const MIN_ZOOM_PX_PER_M := 0.5
const MAX_ZOOM_PX_PER_M := 8.0
const DEFAULT_ZOOM_PX_PER_M := 2.0

var _zoom_px_per_m: float = DEFAULT_ZOOM_PX_PER_M
var _pan_offset: Vector2 = Vector2.ZERO  ## world metres, added to the player's
## own world position to get the point currently at screen-centre -- manual
## dragging adjusts this; it is NOT reset by a new GPS fix (see show_position()).
var _drag_touch_index: int = -1
var _drag_last_screen_pos: Vector2 = Vector2.ZERO
var _pinch_touch_indices: Array = []  ## up to 2 active touch indices, for pinch
var _pinch_last_distance: float = -1.0


## World metres (relative to the extract's origin) -> local draw-space
## pixels. Centred on wherever the player currently is, offset by any
## manual pan, then scaled by the current zoom.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var relative := world_pos - _player_world_pos - _pan_offset
	return Vector2(relative.x, -relative.y) * _zoom_px_per_m
```

(The Y-axis flip here matches the existing code's own `-(g["lat"] - _center_lat)` convention: world-space Y increases northward, screen-space Y increases downward.)

- [ ] **Step 2: Use the transform in `_draw_map_geometry()` and marker drawing**

Update Task 2's `_draw_map_geometry()` to call `_world_to_screen(points[i])` instead of the bare `points[i] - _player_world_pos` subtraction, and update the gate/player marker drawing in `_draw()` the same way (`_world_to_screen(_project(g["lat"], g["lon"]))` for gates, `_world_to_screen(_player_world_pos)` for the player marker, which will always resolve to `-_pan_offset * _zoom_px_per_m` -- i.e. still `Vector2.ZERO` exactly when the player hasn't manually panned, matching Task 2's unpanned behavior exactly).

Also scale the constant marker sizes and gate-rank-text offset by `_zoom_px_per_m` so they don't visually shrink to nothing at low zoom or balloon at high zoom the way true-to-world-scale objects would -- multiply `PLAYER_RADIUS`/`GATE_RADIUS` by `clamp(_zoom_px_per_m / DEFAULT_ZOOM_PX_PER_M, 0.6, 1.4)` at the two `draw_circle` call sites (markers are a UI/game-logic element, not a mapped feature, so they should stay legible and roughly-constant-sized rather than literally scaling with the map).

- [ ] **Step 3: Cull ways outside the visible area, pick a detail tier by zoom, scale road width by zoom**

Compute the current visible world-space rect once per `_draw()` call and skip any way whose bounds don't intersect it, using Task 1's `MapGeometry.way_bounds()`/`rect_intersects()`. Below `LOW_ZOOM_THRESHOLD`, use each way's cached `simplified_points` (Task 2, Step 1) instead of its full `points` -- computed once at load, so switching tiers here costs nothing per-frame. Road width also scales with zoom (the brief's explicit ask), clamped so it never vanishes when zoomed out or balloons when zoomed in:

```gdscript
const LOW_ZOOM_THRESHOLD := 1.0  ## px/m -- below this, draw the cached
## simplified tier instead of full-detail points (Task 2, Step 1). Half of
## DEFAULT_ZOOM_PX_PER_M, i.e. "zoomed out to about half the default view".


func _draw_map_geometry() -> void:
	var half_extent_m := 1200.0 / _zoom_px_per_m  ## generous margin either
	## side of the node's local draw area -- MapView's own screen footprint
	## is roughly ~1000px wide in the final layout, so 1200 world-space
	## px-equivalent of margin comfortably covers it at any zoom without
	## needing this function to know its exact on-screen rect.
	var view_center := _player_world_pos + _pan_offset
	var visible_rect := Rect2(
		view_center - Vector2(half_extent_m, half_extent_m), Vector2(half_extent_m, half_extent_m) * 2.0
	)
	var use_simplified := _zoom_px_per_m < LOW_ZOOM_THRESHOLD
	var width_scale: float = clamp(_zoom_px_per_m / DEFAULT_ZOOM_PX_PER_M, 0.5, 2.5)

	for way: Dictionary in _ways:
		var points: PackedVector2Array = way["simplified_points"] if use_simplified else way["points"]
		if points.size() < 2:
			continue
		if not MapGeometry.rect_intersects(MapGeometry.way_bounds(points), visible_rect):
			continue
		var class_id: int = way["class_id"]
		var screen_points := PackedVector2Array()
		screen_points.resize(points.size())
		for i in points.size():
			screen_points[i] = _world_to_screen(points[i])
		if class_id == MapGeometry.CLASS_WATER_AREA:
			draw_colored_polygon(screen_points, MapGeometry.road_color(class_id))
		else:
			draw_polyline(
				screen_points,
				MapGeometry.road_color(class_id),
				MapGeometry.road_width_px(class_id) * width_scale,
				true
			)
```

- [ ] **Step 4: Handle drag-to-pan and pinch-to-zoom**

`InputEventScreenDrag` only carries the position of the ONE finger that moved, per event -- Godot has no "give me both current touch positions" query API -- so both pinch fingers' last-known positions have to be tracked explicitly in member variables, seeded the moment the second finger lands (not left to be filled in by whichever finger happens to drag first):

```gdscript
var _pinch_pos_a: Vector2 = Vector2.ZERO
var _pinch_pos_b: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not _has_fix:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if _drag_touch_index == -1 and _pinch_touch_indices.is_empty():
				_drag_touch_index = touch_event.index
				_drag_last_screen_pos = touch_event.position
			elif _drag_touch_index != -1 and touch_event.index != _drag_touch_index:
				# a second finger landed -- switch from drag to pinch, and
				# seed both positions/the starting distance right now so
				# the first subsequent drag event has something correct
				# to compare against.
				_pinch_touch_indices = [_drag_touch_index, touch_event.index]
				_pinch_pos_a = _drag_last_screen_pos
				_pinch_pos_b = touch_event.position
				_pinch_last_distance = _pinch_pos_a.distance_to(_pinch_pos_b)
				_drag_touch_index = -1
		else:
			if touch_event.index == _drag_touch_index:
				_drag_touch_index = -1
			_pinch_touch_indices.erase(touch_event.index)
			if _pinch_touch_indices.size() < 2:
				_pinch_last_distance = -1.0
		return

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == _drag_touch_index:
			var delta_screen := drag_event.position - _drag_last_screen_pos
			_drag_last_screen_pos = drag_event.position
			_pan_offset -= Vector2(delta_screen.x, -delta_screen.y) / _zoom_px_per_m
			queue_redraw()
		elif drag_event.index in _pinch_touch_indices:
			if drag_event.index == _pinch_touch_indices[0]:
				_pinch_pos_a = drag_event.position
			else:
				_pinch_pos_b = drag_event.position
			_update_pinch_zoom()
			queue_redraw()


func _update_pinch_zoom() -> void:
	var distance := _pinch_pos_a.distance_to(_pinch_pos_b)
	if _pinch_last_distance > 0.0 and distance > 0.0:
		_zoom_px_per_m = clamp(
			_zoom_px_per_m * (distance / _pinch_last_distance), MIN_ZOOM_PX_PER_M, MAX_ZOOM_PX_PER_M
		)
	_pinch_last_distance = distance
```

If Godot's exact touch-event delivery order turns out to differ from what's assumed here once this is actually running on a touchscreen (e.g. both fingers' drag events arriving in an unexpected sequence right at pinch start), use your judgement to adjust and note what you changed in your report -- this is the one piece of this plan that's genuinely hard to fully pin down without a touchscreen in front of you.

- [ ] **Step 5: Manually verify**

Run the full GUT suite, confirm pass count unchanged from Task 2 (this task is `scenes/`-only, no new `core/` file). Re-read the diff: confirm `_world_to_screen()` is used consistently everywhere a world position is drawn (roads, water, gates, player marker) -- a spot that still uses the old Task-2-only `- _player_world_pos` subtraction would silently ignore pan/zoom for that one element.

- [ ] **Step 6: Commit**

```bash
git add scenes/map_view.gd
git commit -m "Map render: pan and pinch-zoom"
```

---

## Post-plan checklist (controller, after all tasks -- not a dispatched task)

- [ ] Full GUT suite green (11 new tests from Task 1, nothing else moves).
- [ ] `gdformat`/`gdlint` clean on every touched file.
- [ ] Real on-device build + install + launch (same pipeline as the portrait-mode work: `godot --export-debug`, re-patch the two Gradle manifest overrides, build via `gradlew` directly with the `-P` properties, sign with Godot's debug keystore, `adb install`).
- [ ] On-device screenshot of the real Darlington streets rendering, saved to `devmedia/` per this project's capture-log convention.
- [ ] Report back per the brief: actual data size (**already known: 245,863 bytes**, vs. the ~0.4 MB estimate), frame cost observed on device and what (if anything) had to change to keep it acceptable, whether Web Mercator vs. the old flat approximation was visibly different at this scale, and what widening coverage beyond one bbox would take (§19c, not urgent).
