extends Node2D

## Phase 1 steps 3-4: real daily EXP from Health Connect -> level up, and a
## simple map (live GPS position + placeholder gates), replacing the
## native-plugin-spike test harness (checkpoints 2-4) with actual game
## wiring. Subclass is hardcoded to WARRIOR for now -- no picker UI yet
## (not part of the minimum lovable loop). Simplification: applies today's
## totals every launch with no "already counted today" guard, so relaunching
## same-day double-counts EXP -- fine for this phase, flagged rather than
## silently shipped.

var bridge: Object
var state: HunterState
var _steps: int = -1
var _workouts_json: String = ""
var _health_applied := false

@onready var label: Label = $Label
@onready var map_view: Node2D = $MapView


func _ready() -> void:
	state = SaveService.load_or_create("WARRIOR")
	_refresh_label()

	if not Engine.has_singleton("GpsHealthBridge"):
		label.text += "\n\nGpsHealthBridge singleton not found"
		return
	bridge = Engine.get_singleton("GpsHealthBridge")

	bridge.location_permission_result.connect(_on_location_permission_result)
	bridge.location_update.connect(_on_location_update)
	bridge.health_connect_available.connect(_on_health_connect_available)
	bridge.health_permission_result.connect(_on_health_permission_result)
	bridge.steps_result.connect(_on_steps_result)
	bridge.workouts_result.connect(_on_workouts_result)

	bridge.requestLocationPermission()
	bridge.checkHealthConnectAvailable()


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		bridge.startLocationUpdates()
	else:
		label.text += "\n\nGPS permission denied"


func _on_location_update(lat: float, lon: float, _accuracy: float, _timestamp_ms: int) -> void:
	map_view.show_position(lat, lon, state.level)


func _on_health_connect_available(available: bool) -> void:
	if available:
		bridge.requestHealthPermissions()
	else:
		label.text += "\n\nHealth Connect not available"


func _on_health_permission_result(granted: bool) -> void:
	if granted:
		bridge.readTodaySteps()
		bridge.readRecentWorkouts(24)
	else:
		label.text += "\n\nHealth permission denied"


func _on_steps_result(count: int) -> void:
	_steps = count
	_maybe_apply_daily_exp()


func _on_workouts_result(workouts_json: String) -> void:
	_workouts_json = workouts_json
	_maybe_apply_daily_exp()


## Both signals arrive independently and in either order; wait for both
## (steps defaults to the never-real -1, workouts_result is always at least
## the 2-char "[]" so an empty string means "not arrived yet") before
## computing EXP once.
func _maybe_apply_daily_exp() -> void:
	if _health_applied or _steps < 0 or _workouts_json.is_empty():
		return
	_health_applied = true

	var exp := DailyExp.exp_for_today(_steps, _workouts_json, state.subclass)
	var levels_gained := state.add_exp(exp)
	SaveService.save(state)
	_refresh_label()
	if levels_gained > 0:
		label.text += "\n\nLEVEL UP! (+%d)" % levels_gained
	print(
		(
			"PHASE1: steps=%d workouts=%s exp=%d levels_gained=%d"
			% [_steps, _workouts_json, exp, levels_gained]
		)
	)


func _refresh_label() -> void:
	var stats := state.stats()
	label.text = (
		"Lv %d %s\nEXP: %d / %d\nEssence: %d  Tickets: %d\nSTR %d AGI %d VIT %d END %d SEN %d"
		% [
			state.level,
			state.subclass,
			state.exp_into_level,
			GameLogic.exp_to_next(state.level),
			state.essence,
			state.gate_tickets,
			stats["STR"],
			stats["AGI"],
			stats["VIT"],
			stats["END"],
			stats["SEN"],
		]
	)
