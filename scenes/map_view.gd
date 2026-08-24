class_name MapView
extends Node2D

## Vector-line map renderer (§19b/§19c). Loads the pre-projected street/water
## extract (content/map_data/*.bin -- see tools/map_extract/fetch_and_convert.py)
## once at _ready(), draws it in the game's dark palette (colors/widths from
## core/map_geometry.gd), with the live GPS position (player, drawn centred at
## this node's local origin) and rank-matched gates layered on top. The view
## is locked to the live GPS position -- no drag-to-pan; pinch-zoom is the
## only manual control, layered on the same coordinate space (see
## _world_to_screen()). All positions -- roads, water, gates, player -- share
## one Mercator-relative-to-origin metre space (_project()), so nothing
## drifts out of alignment between them.

const PLAYER_RADIUS := 14.0  ## fallback draw_circle() radius, used only if
## ArtPaths.map_marker("player") has no art yet (placeholder-first, §24).
const PLAYER_MARKER_SIZE := 48.0  ## on-screen diameter for the real marker
## texture, before the zoom-scale clamp below -- bigger than PLAYER_RADIUS's
## 28px circle since the real icon has fine detail (an arrow/compass shape)
## that needs more room to read than a flat dot did.
const GATE_RADIUS := 20.0  ## fallback draw_circle() radius, used only if
## ArtPaths.map_marker("gate") has no art yet (placeholder-first, §24).
const GATE_MARKER_SIZE := 44.0  ## on-screen diameter for the real marker
## texture -- see PLAYER_MARKER_SIZE, same reasoning.
const SANCTUARY_MARKER_SIZE := 44.0  ## same reasoning as GATE_MARKER_SIZE.
const LORESTONE_MARKER_SIZE := 40.0  ## slightly smaller -- a discoverable
## flavour POI, not as prominent as a Sanctuary's recurring daily stop.
const STRONGHOLD_MARKER_SIZE := 44.0  ## same reasoning as GATE_MARKER_SIZE.
const INCURSION_BADGE_SIZE := 32.0  ## fixed screen-space size -- this is a
## HUD badge for an area-wide effect, not a world-space marker, so it
## doesn't scale with marker_scale/zoom like the point markers above do.

const RANK_COLORS := {
	"E": Color.DIM_GRAY,
	"D": Color.LIME_GREEN,
	"C": Color.DODGER_BLUE,
	"B": Color.MEDIUM_PURPLE,
	"A": Color.ORANGE,
	"S": Color.CRIMSON,
}

const NORMAL_GATE_COUNT := 5
const INCURSION_GATE_COUNT := 8  ## invented v0: §19's "denser" -- see core/incursion.gd

const MAP_DATA_PATH := "res://content/map_data/darlington.bin"

const MIN_ZOOM_PX_PER_M := 0.5
const MAX_ZOOM_PX_PER_M := 8.0
const DEFAULT_ZOOM_PX_PER_M := 2.0
const LOW_ZOOM_THRESHOLD := 1.0  ## px/m -- below this, draw each way's cached
## simplified_points tier instead of full-detail points (see _load_map_data()).
## Half of DEFAULT_ZOOM_PX_PER_M, i.e. "zoomed out to about half the default view".

var _center_lat: float = 0.0
var _center_lon: float = 0.0
var _has_fix := false
var _gates: Array = []
var _active_incursion_family := ""  ## Phase 2/P9: "" if this area+week isn't under one (§19)

var _ways: Array = []  ## Array[Dictionary]: {"class_id": int, "points": PackedVector2Array,
## "simplified_points": PackedVector2Array} -- world metres, relative to _origin_x/_origin_y
## below. Loaded once at _ready().
var _origin_x: float = 0.0  ## Web Mercator metres of the extract's bbox centre --
var _origin_y: float = 0.0  ## every live GPS/gate lat-lon must subtract this same
## origin after projecting, to land in the same relative-metres space the loaded
## road/water geometry is already in.
var _player_world_pos: Vector2 = Vector2.ZERO  ## set by show_position() via _project()

var _zoom_px_per_m: float = DEFAULT_ZOOM_PX_PER_M
var _active_touches: Dictionary = {}  ## touch index -> Vector2 screen position,
## for pinch-zoom only -- the view stays locked to the player's live GPS
## position, so there's no pan offset to track alongside this.
var _pinch_last_distance: float = -1.0

var _player_texture: Texture2D = null  ## null until real art exists for it
## (ArtPaths.map_marker) -- _draw() falls back to the old placeholder circle.
var _gate_texture: Texture2D = null  ## same fallback story as _player_texture.
## One universal marker for every gate regardless of rank (§19: "rank is
## revealed on tap", not shown on the map) -- unlike the old per-rank
## RANK_COLORS circle, this doesn't vary by g["rank"] at all.

var _sanctuaries: Array = []  ## Array[Dictionary]: {"id", "lat", "lon"} -- spawned
## once at the first GPS fix, same as _gates (see show_position()).
var _lorestones: Array = []  ## Array[Dictionary]: {"id", "lat", "lon", "lore_index"}.
var _sanctuary_texture: Texture2D = null  ## same fallback story as _gate_texture.
var _lorestone_texture: Texture2D = null
var _stronghold_texture: Texture2D = null
var _incursion_texture: Texture2D = null

var _stronghold_lat: float = 0.0  ## set via set_stronghold() -- MapView doesn't
var _stronghold_lon: float = 0.0  ## read HunterState directly, main.gd feeds it in.
var _stronghold_placed: bool = false

var _placement_mode: bool = false  ## true between begin_stronghold_placement()
## and end_stronghold_placement() -- while true, a single-finger tap sets a
## pending (not-yet-saved) location instead of doing nothing.
var _pending_stronghold_lon: float = 0.0
var _pending_stronghold_lat: float = 0.0
var _has_pending_stronghold: bool = false


func _ready() -> void:
	_load_map_data()
	_player_texture = ArtPaths.map_marker("player")
	_gate_texture = ArtPaths.map_marker("gate")
	_sanctuary_texture = ArtPaths.map_marker("sanctuary")
	_lorestone_texture = ArtPaths.map_marker("lorestone")
	_stronghold_texture = ArtPaths.map_marker("stronghold")
	_incursion_texture = ArtPaths.map_marker("incursion")


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
		# Precomputed once here, not per-frame: a fixed, generous tolerance for
		# use when zoomed out. Running Douglas-Peucker every _draw() call would
		# cost more than the simplification saves; caching it at load time is
		# what makes "simplify aggressively at low zoom" actually cheap.
		var simplified := MapGeometry.simplify_polyline(points, 3.0)
		_ways.append({"class_id": class_id, "points": points, "simplified_points": simplified})

	file.close()


## Projects a live lat/lon (player position, a gate's spawn point) into the
## SAME world-metres space the loaded road/water geometry already uses --
## Mercator, relative to the extract's own origin.
func _project(lat: float, lon: float) -> Vector2:
	var merc := MapGeometry.lonlat_to_mercator(lon, lat)
	return Vector2(merc.x - _origin_x, merc.y - _origin_y)


## World metres (relative to the extract's origin) -> local draw-space
## pixels. Always centred on wherever the player currently is (the view is
## locked to the live GPS position -- no drag-to-pan), scaled by the
## current zoom.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var relative := world_pos - _player_world_pos
	# Y-axis flip matches the existing gate/player marker convention: world-
	# space Y increases northward, screen-space Y increases downward.
	return Vector2(relative.x, -relative.y) * _zoom_px_per_m


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


## Gates are rolled once, from the first fix -- moving around doesn't
## reroll them (that would just be jittery placeholder noise, not a
## feature). Re-call from a "new gates" action once that exists.
##
## Phase 2/P9: also checks Incursion.active_family() for this spot/week at
## that same first fix -- deterministic, so it's fine to compute once and
## hold rather than re-check on every position update.
func show_position(lat: float, lon: float, hunter_rank: String) -> void:
	_player_world_pos = _project(lat, lon)
	if not _has_fix:
		_center_lat = lat
		_center_lon = lon
		_has_fix = true
		var monsters := Content.load_monsters()
		var rng := RandomNumberGenerator.new()
		rng.randomize()

		var area := Incursion.area_key(lat, lon)
		var week := Incursion.week_number(int(Time.get_unix_time_from_system()))
		_active_incursion_family = Incursion.active_family(
			area, week, Content.monster_families(monsters)
		)

		if _active_incursion_family != "":
			_gates = GateSpawner.spawn_incursion_gates(
				lat, lon, hunter_rank, _active_incursion_family, monsters, INCURSION_GATE_COUNT, rng
			)
		else:
			_gates = GateSpawner.spawn_gates(
				lat, lon, hunter_rank, monsters, NORMAL_GATE_COUNT, rng
			)
		_sanctuaries = PoiSpawner.spawn_sanctuaries(lat, lon)
		_lorestones = PoiSpawner.spawn_lorestones(lat, lon)
	queue_redraw()


func get_nearest_gate_index() -> int:
	if _gates.is_empty():
		return -1
	var best_idx := 0
	var best_dist_sq := INF
	for i in _gates.size():
		var g: Dictionary = _gates[i]
		var dlat: float = g["lat"] - _center_lat
		var dlon: float = g["lon"] - _center_lon
		var dist_sq := dlat * dlat + dlon * dlon
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_idx = i
	return best_idx


func get_gate(index: int) -> Dictionary:
	if index < 0 or index >= _gates.size():
		return {}
	return _gates[index]


func remove_gate(index: int) -> void:
	if index < 0 or index >= _gates.size():
		return
	_gates.remove_at(index)
	queue_redraw()


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

	_draw_map_geometry()

	# Marker sizes/text offset scale with zoom too, clamped so they stay
	# legible rather than literally scaling with the map like a mapped
	# feature would -- markers are a UI/game-logic element, not terrain.
	var marker_scale: float = clamp(_zoom_px_per_m / DEFAULT_ZOOM_PX_PER_M, 0.6, 1.4)
	for g: Dictionary in _gates:
		var pos := _world_to_screen(_project(g["lat"], g["lon"]))
		if _gate_texture != null:
			var size := GATE_MARKER_SIZE * marker_scale
			draw_texture_rect(
				_gate_texture, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false
			)
		else:
			var color: Color = RANK_COLORS.get(g["rank"], Color.WHITE)
			draw_circle(pos, GATE_RADIUS * marker_scale, color)
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(-8, 8) * marker_scale,
				g["rank"],
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				28,
				Color.BLACK
			)

	for s: Dictionary in _sanctuaries:
		var pos := _world_to_screen(_project(s["lat"], s["lon"]))
		if _sanctuary_texture != null:
			var size := SANCTUARY_MARKER_SIZE * marker_scale
			draw_texture_rect(
				_sanctuary_texture,
				Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)),
				false
			)
		else:
			draw_circle(pos, GATE_RADIUS * marker_scale, Color.LIGHT_GREEN)

	for ls: Dictionary in _lorestones:
		var pos := _world_to_screen(_project(ls["lat"], ls["lon"]))
		if _lorestone_texture != null:
			var size := LORESTONE_MARKER_SIZE * marker_scale
			draw_texture_rect(
				_lorestone_texture,
				Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)),
				false
			)
		else:
			draw_circle(pos, GATE_RADIUS * marker_scale * 0.8, Color.LIGHT_YELLOW)

	if _has_pending_stronghold:
		_draw_stronghold_marker(_pending_stronghold_lat, _pending_stronghold_lon, marker_scale)
	elif _stronghold_placed:
		_draw_stronghold_marker(_stronghold_lat, _stronghold_lon, marker_scale)

	var player_pos := _world_to_screen(_player_world_pos)
	if _player_texture != null:
		var size := PLAYER_MARKER_SIZE * marker_scale
		draw_texture_rect(
			_player_texture,
			Rect2(player_pos - Vector2(size, size) / 2.0, Vector2(size, size)),
			false
		)
	else:
		draw_circle(player_pos, PLAYER_RADIUS * marker_scale, Color.DEEP_SKY_BLUE)


## Water first (so roads draw on top of it, not the reverse), then roads by
## class, culled to the visible area and detail-tiered by zoom. Every world
## position routes through _world_to_screen(), so zoom applies uniformly to
## roads, water, and markers alike.
func _draw_map_geometry() -> void:
	# MapView is a bare Node2D -- it has no fill of its own, so without this
	# the map shows whatever sits behind it in the scene tree instead of the
	# §19b dark basemap. Screen-space, not world-space: the same flat color
	# everywhere, so it doesn't need to move with the view, just to be big
	# enough to cover any device screen regardless of where MapView sits.
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(4000, 4000)), MapGeometry.BACKGROUND_COLOR)

	var half_extent_m := 1200.0 / _zoom_px_per_m  ## generous margin either side
	## of the node's local draw area -- MapView's own screen footprint is
	## roughly ~1000px wide in the final layout, so 1200 world-space
	## px-equivalent of margin comfortably covers it at any zoom without this
	## function needing to know its exact on-screen rect.
	var visible_rect := Rect2(
		_player_world_pos - Vector2(half_extent_m, half_extent_m),
		Vector2(half_extent_m, half_extent_m) * 2.0
	)
	var use_simplified := _zoom_px_per_m < LOW_ZOOM_THRESHOLD
	var width_scale: float = clamp(_zoom_px_per_m / DEFAULT_ZOOM_PX_PER_M, 0.5, 2.5)

	for way: Dictionary in _ways:
		var points: PackedVector2Array = (
			way["simplified_points"] if use_simplified else way["points"]
		)
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


func _draw_stronghold_marker(lat: float, lon: float, marker_scale: float) -> void:
	var pos := _world_to_screen(_project(lat, lon))
	if _stronghold_texture != null:
		var size := STRONGHOLD_MARKER_SIZE * marker_scale
		draw_texture_rect(
			_stronghold_texture, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false
		)
	else:
		draw_circle(pos, GATE_RADIUS * marker_scale, Color.YELLOW)


## The view is locked to the live GPS position (no drag-to-pan), so the
## only gesture this handles is a two-finger pinch. Single-finger touches/
## drags are tracked in _active_touches so a second finger landing can be
## recognized, but never move the view on their own.
func _unhandled_input(event: InputEvent) -> void:
	if not _has_fix:
		return

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

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if not _active_touches.has(drag_event.index):
			return
		_active_touches[drag_event.index] = drag_event.position
		if _active_touches.size() == 2:
			_update_pinch_zoom()
			queue_redraw()


func _pinch_distance() -> float:
	var positions: Array = _active_touches.values()
	return (positions[0] as Vector2).distance_to(positions[1])


func _update_pinch_zoom() -> void:
	var distance := _pinch_distance()
	if _pinch_last_distance > 0.0 and distance > 0.0:
		_zoom_px_per_m = clamp(
			_zoom_px_per_m * (distance / _pinch_last_distance), MIN_ZOOM_PX_PER_M, MAX_ZOOM_PX_PER_M
		)
	_pinch_last_distance = distance
