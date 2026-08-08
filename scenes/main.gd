extends Node2D

## Phase 1 steps 3-6 (+ subclass picker, daily-EXP double-count guard): real
## daily EXP from Health Connect -> level up, a simple map (live GPS
## position + placeholder gates), gate encounters (3-round clash -> boss
## CLAIM -> shadow), and an army list with an auto-filled class-slotted
## squad -- replacing the native-plugin-spike test harness (checkpoints
## 2-4) with actual game wiring. GPS/Health Connect permission requests
## start immediately regardless of the picker, so they're ready by the
## time a subclass is chosen.

const CLASSES := ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]

var bridge: Object
var state: HunterState
var _monsters: Array
var _steps: int = -1
var _workouts_json: String = ""
var _health_applied := false

@onready var subclass_picker: Node2D = $SubclassPicker
@onready var game_ui: Node2D = $GameUI
@onready var label: Label = $GameUI/Label
@onready var map_view: MapView = $GameUI/MapView
@onready var enter_gate_button: Button = $GameUI/EnterGateButton
@onready var army_label: Label = $GameUI/ArmyLabel


func _ready() -> void:
	_monsters = Content.load_monsters()

	if FileAccess.file_exists(SaveService.SAVE_PATH):
		state = SaveService.load_or_create()
		_start_game()
	else:
		_show_subclass_picker()

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


## The subclass is permanent once picked (design bible §21) -- this screen
## only shows for a genuinely new hunter (no save file yet), never again.
func _show_subclass_picker() -> void:
	subclass_picker.visible = true
	game_ui.visible = false
	for clazz in CLASSES:
		var button: Button = subclass_picker.get_node("%sButton" % clazz.capitalize())
		button.pressed.connect(_on_subclass_chosen.bind(clazz))


func _on_subclass_chosen(subclass: String) -> void:
	state = SaveService.load_or_create(subclass)
	subclass_picker.visible = false
	game_ui.visible = true
	_start_game()


func _start_game() -> void:
	_refresh_label()
	_refresh_army_label()
	if not enter_gate_button.pressed.is_connected(_on_enter_gate_pressed):
		enter_gate_button.pressed.connect(_on_enter_gate_pressed)


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		bridge.startLocationUpdates()
	else:
		label.text += "\n\nGPS permission denied"


func _on_location_update(lat: float, lon: float, _accuracy: float, _timestamp_ms: int) -> void:
	if state == null:
		return  # subclass not chosen yet
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
## computing EXP once. Also waits on `state` existing (subclass not chosen
## yet on a fresh install) and on HunterState's own has_applied_exp_today()
## guard, so relaunching same calendar day no longer double-counts.
func _maybe_apply_daily_exp() -> void:
	if state == null or _health_applied or _steps < 0 or _workouts_json.is_empty():
		return
	_health_applied = true

	var today := Time.get_date_string_from_system()
	if state.has_applied_exp_today(today):
		print("PHASE1: daily EXP already applied for %s, skipping" % today)
		return

	var exp := DailyExp.exp_for_today(_steps, _workouts_json, state.subclass)
	var levels_gained := state.add_exp(exp)
	state.mark_exp_applied(today)
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


func _on_enter_gate_pressed() -> void:
	var idx := map_view.get_nearest_gate_index()
	if idx < 0:
		label.text += "\n\nNo gates nearby"
		return
	var gate := map_view.get_gate(idx)

	var squad := SquadBuilder.auto_fill_squad(state.army, _monsters, state.level)
	var squad_power := 0
	for member: Dictionary in squad:
		squad_power += member["power"]
	var personal := GameLogic.personal_power(state.stats(), state.level, 0)
	var total_power := GameLogic.gate_power(personal, squad_power)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := GateEncounter.run(total_power, gate, state.level, rng)
	map_view.remove_gate(idx)

	var msg := (
		"\n\n%s gate (%s): %s"
		% [gate["rank"], gate["monster_name"], "CLEARED" if result["cleared"] else "LOST"]
	)
	if result["cleared"] and result["claimed"]:
		state.claim_shadow(gate["monster_id"], gate["rank"])
		msg += "\nCLAIMED! %s joins your army." % gate["monster_name"]
	elif result["cleared"]:
		msg += "\nBoss escaped (claim failed)."

	SaveService.save(state)
	_refresh_label()
	_refresh_army_label()
	label.text += msg
	print(
		(
			"PHASE1_GATE: rank=%s rounds=%s cleared=%s claimed=%s"
			% [gate["rank"], result["rounds"], result["cleared"], result["claimed"]]
		)
	)


func _refresh_army_label() -> void:
	if state.army.is_empty():
		army_label.text = "Army: (none yet)"
		return

	var enriched := SquadBuilder.enrich_army(state.army, _monsters, state.level)
	var squad := SquadBuilder.auto_fill_squad(state.army, _monsters, state.level)
	var squad_ids := {}
	for member: Dictionary in squad:
		squad_ids[member["instance_id"]] = true

	var lines := [
		(
			"Army (%d) -- squad marked [S] (%d/%d):"
			% [enriched.size(), squad.size(), GameLogic.SQUAD_SIZE]
		)
	]
	for e: Dictionary in enriched:
		var marker := " [S]" if squad_ids.has(e["instance_id"]) else ""
		lines.append(
			(
				" - %s (%s Lv%d %s) pwr:%d%s"
				% [e["monster_name"], e["grade"], e["level"], e["clazz"], e["power"], marker]
			)
		)
	army_label.text = "\n".join(lines)


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
