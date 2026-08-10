class_name MapView
extends Node2D

## Phase 1 step 4: simple placeholder map. Live GPS position (player, drawn
## at this node's local origin) plus a handful of rank-matched placeholder
## gates scattered around it. No real map tiles -- lat/lon deltas project
## straight to pixels via a flat approximation, which is fine at this scale
## and matches "placeholder art only" for this phase.

const PIXELS_PER_DEGREE := 100000.0
const PLAYER_RADIUS := 14.0
const GATE_RADIUS := 20.0

const RANK_COLORS := {
	"E": Color.DIM_GRAY,
	"D": Color.LIME_GREEN,
	"C": Color.DODGER_BLUE,
	"B": Color.MEDIUM_PURPLE,
	"A": Color.ORANGE,
	"S": Color.CRIMSON,
}

var _center_lat: float = 0.0
var _center_lon: float = 0.0
var _has_fix := false
var _gates: Array = []


## Gates are rolled once, from the first fix -- moving around doesn't
## reroll them (that would just be jittery placeholder noise, not a
## feature). Re-call from a "new gates" action once that exists.
func show_position(lat: float, lon: float, hunter_rank: String) -> void:
	if not _has_fix:
		_center_lat = lat
		_center_lon = lon
		_has_fix = true
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_gates = GateSpawner.spawn_gates(lat, lon, hunter_rank, Content.load_monsters(), 5, rng)
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

	for g: Dictionary in _gates:
		var dx: float = (g["lon"] - _center_lon) * PIXELS_PER_DEGREE
		var dy: float = -(g["lat"] - _center_lat) * PIXELS_PER_DEGREE
		var pos := Vector2(dx, dy)
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
