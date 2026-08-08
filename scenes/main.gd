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
var _equipment: Dictionary
var _steps: int = -1
var _workouts_json: String = ""
var _health_applied := false
var _hunter_gear_rows: Array = []  ## Array[Dictionary]: {slot, label, equip_btn, unequip_btn}
var _shadow_gear_rows: Array = []  ## same shape, for whichever shadow is selected
var _shadow_gear_index: int = 0  ## index into state.army for the Shadow Gear panel

@onready var subclass_picker: Node2D = $SubclassPicker
@onready var game_ui: Node2D = $GameUI
@onready var label: Label = $GameUI/Label
@onready var map_view: MapView = $GameUI/MapView
@onready var enter_gate_button: Button = $GameUI/EnterGateButton
@onready var army_label: Label = $GameUI/ArmyLabel
@onready var inventory_label: Label = $GameUI/InventoryLabel
@onready var hunter_gear_button: Button = $GameUI/HunterGearButton
@onready var shadow_gear_button: Button = $GameUI/ShadowGearButton
@onready var hunter_gear_panel: Node2D = $GameUI/HunterGearPanel
@onready var shadow_gear_panel: Node2D = $GameUI/ShadowGearPanel
@onready var shadow_gear_title: Label = $GameUI/ShadowGearPanel/Title


func _ready() -> void:
	_monsters = Content.load_monsters()
	_equipment = Content.load_equipment()

	if FileAccess.file_exists(SaveService.SAVE_PATH):
		state = SaveService.load_or_create()
		subclass_picker.visible = false
		game_ui.visible = true
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
	_refresh_inventory_label()
	if not enter_gate_button.pressed.is_connected(_on_enter_gate_pressed):
		enter_gate_button.pressed.connect(_on_enter_gate_pressed)
	_setup_gear_panels()


## Phase 2 patch 1 step 4: builds the 7 slot rows for both gear panels at
## runtime (rather than hand-authoring 7x3 nodes per panel in the .tscn) and
## wires every button once. Idempotency guards mirror the enter_gate_button
## pattern above -- _start_game() can run again (e.g. after picking a
## subclass) without double-connecting.
func _setup_gear_panels() -> void:
	if _hunter_gear_rows.is_empty():
		_hunter_gear_rows = _build_gear_rows($GameUI/HunterGearPanel/Rows, 180.0)
		for row: Dictionary in _hunter_gear_rows:
			var slot: String = row["slot"]
			row["equip_btn"].pressed.connect(_on_hunter_equip_best_pressed.bind(slot))
			row["unequip_btn"].pressed.connect(_on_hunter_unequip_pressed.bind(slot))
	if _shadow_gear_rows.is_empty():
		_shadow_gear_rows = _build_gear_rows($GameUI/ShadowGearPanel/Rows, 180.0)
		for row: Dictionary in _shadow_gear_rows:
			var slot: String = row["slot"]
			row["equip_btn"].pressed.connect(_on_shadow_equip_best_pressed.bind(slot))
			row["unequip_btn"].pressed.connect(_on_shadow_unequip_pressed.bind(slot))

	if not hunter_gear_button.pressed.is_connected(_on_hunter_gear_button_pressed):
		hunter_gear_button.pressed.connect(_on_hunter_gear_button_pressed)
		$GameUI/HunterGearPanel/AutoEquipButton.pressed.connect(_on_hunter_auto_equip_pressed)
		$GameUI/HunterGearPanel/CloseButton.pressed.connect(_on_hunter_gear_close_pressed)
		shadow_gear_button.pressed.connect(_on_shadow_gear_button_pressed)
		$GameUI/ShadowGearPanel/AutoEquipButton.pressed.connect(_on_shadow_auto_equip_pressed)
		$GameUI/ShadowGearPanel/CloseButton.pressed.connect(_on_shadow_gear_close_pressed)
		$GameUI/ShadowGearPanel/PrevButton.pressed.connect(_on_shadow_gear_prev_pressed)
		$GameUI/ShadowGearPanel/NextButton.pressed.connect(_on_shadow_gear_next_pressed)


## Creates one row (slot label + Equip Best + Unequip buttons) per
## Equip.SLOTS under `parent`, stacked from `y_start`. Placeholder art --
## plain Label/Button, no icons/paper-doll art yet.
func _build_gear_rows(parent: Node2D, y_start: float) -> Array:
	var rows := []
	var y := y_start
	for slot in Equip.SLOTS:
		var row_label := Label.new()
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(600, 40)
		row_label.add_theme_font_size_override("font_size", 20)
		parent.add_child(row_label)

		var equip_btn := Button.new()
		equip_btn.position = Vector2(660, y)
		equip_btn.size = Vector2(150, 40)
		equip_btn.text = "Equip Best"
		parent.add_child(equip_btn)

		var unequip_btn := Button.new()
		unequip_btn.position = Vector2(820, y)
		unequip_btn.size = Vector2(130, 40)
		unequip_btn.text = "Unequip"
		parent.add_child(unequip_btn)

		rows.append(
			{"slot": slot, "label": row_label, "equip_btn": equip_btn, "unequip_btn": unequip_btn}
		)
		y += 50
	return rows


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

	var squad := SquadBuilder.auto_fill_squad(
		state.army, _monsters, state.level, _equipment, state.inventory
	)
	var squad_power := 0
	for member: Dictionary in squad:
		squad_power += member["power"]
	var personal := state.personal_power(_equipment)
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

	if result["cleared"]:
		var drop := Loot.roll_drop(gate["rank"], _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			msg += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]

	SaveService.save(state)
	_refresh_label()
	_refresh_army_label()
	_refresh_inventory_label()
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

	var enriched := SquadBuilder.enrich_army(
		state.army, _monsters, state.level, _equipment, state.inventory
	)
	var squad := SquadBuilder.auto_fill_squad(
		state.army, _monsters, state.level, _equipment, state.inventory
	)
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


func _refresh_inventory_label() -> void:
	if state.inventory.is_empty():
		inventory_label.text = "Inventory: (none yet)"
		return

	var lines := ["Inventory (%d):" % state.inventory.size()]
	for item: Dictionary in state.inventory:
		var def := Content.equipment_by_id(_equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		lines.append(
			(
				" - %s [%s] %s +%d (Lv%d)"
				% [
					def["name"],
					def["slot"],
					def["rarity"],
					def["power_bonus"],
					item.get("enhancement_level", 0)
				]
			)
		)
	inventory_label.text = "\n".join(lines)


func _refresh_label() -> void:
	var stats := state.stats()
	label.text = (
		(
			"Lv %d %s\nEXP: %d / %d\nEssence: %d  Tickets: %d\n"
			+ "STR %d AGI %d VIT %d END %d SEN %d\nPower: %d"
		)
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
			state.personal_power(_equipment),
		]
	)


func _on_hunter_gear_button_pressed() -> void:
	hunter_gear_panel.visible = true
	_refresh_hunter_gear_panel()


func _on_hunter_gear_close_pressed() -> void:
	hunter_gear_panel.visible = false


func _on_hunter_equip_best_pressed(slot: String) -> void:
	state.equip_best_to_hunter(slot, _equipment)
	SaveService.save(state)
	_refresh_hunter_gear_panel()
	_refresh_label()
	_refresh_inventory_label()


func _on_hunter_unequip_pressed(slot: String) -> void:
	state.unequip_from_hunter(slot)
	SaveService.save(state)
	_refresh_hunter_gear_panel()
	_refresh_label()
	_refresh_inventory_label()


func _on_hunter_auto_equip_pressed() -> void:
	state.auto_equip_hunter(_equipment)
	SaveService.save(state)
	_refresh_hunter_gear_panel()
	_refresh_label()
	_refresh_inventory_label()


func _refresh_hunter_gear_panel() -> void:
	for row: Dictionary in _hunter_gear_rows:
		var slot: String = row["slot"]
		var instance_id: String = state.equipped.get(slot, "")
		row["label"].text = "%s: %s" % [slot, _equipped_item_display(instance_id)]


func _on_shadow_gear_button_pressed() -> void:
	if state.army.is_empty():
		label.text += "\n\nNo shadows yet"
		return
	_shadow_gear_index = clampi(_shadow_gear_index, 0, state.army.size() - 1)
	shadow_gear_panel.visible = true
	_refresh_shadow_gear_panel()


func _on_shadow_gear_close_pressed() -> void:
	shadow_gear_panel.visible = false


func _on_shadow_gear_prev_pressed() -> void:
	if state.army.is_empty():
		return
	_shadow_gear_index = (_shadow_gear_index - 1 + state.army.size()) % state.army.size()
	_refresh_shadow_gear_panel()


func _on_shadow_gear_next_pressed() -> void:
	if state.army.is_empty():
		return
	_shadow_gear_index = (_shadow_gear_index + 1) % state.army.size()
	_refresh_shadow_gear_panel()


func _current_shadow_instance_id() -> String:
	if state.army.is_empty() or _shadow_gear_index >= state.army.size():
		return ""
	return state.army[_shadow_gear_index]["instance_id"]


func _on_shadow_equip_best_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	state.equip_best_to_shadow(shadow_id, slot, _equipment, _monsters)
	SaveService.save(state)
	_refresh_shadow_gear_panel()
	_refresh_army_label()
	_refresh_inventory_label()


func _on_shadow_unequip_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	state.unequip_from_shadow(shadow_id, slot)
	SaveService.save(state)
	_refresh_shadow_gear_panel()
	_refresh_army_label()
	_refresh_inventory_label()


func _on_shadow_auto_equip_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	state.auto_equip_shadow(shadow_id, _equipment, _monsters)
	SaveService.save(state)
	_refresh_shadow_gear_panel()
	_refresh_army_label()
	_refresh_inventory_label()


func _refresh_shadow_gear_panel() -> void:
	if state.army.is_empty():
		shadow_gear_title.text = "No shadows yet"
		for row: Dictionary in _shadow_gear_rows:
			row["label"].text = "%s: --" % row["slot"]
		return

	_shadow_gear_index = clampi(_shadow_gear_index, 0, state.army.size() - 1)
	var shadow: Dictionary = state.army[_shadow_gear_index]
	var monster := Content.monster_by_id(_monsters, shadow.get("monster_id", ""))
	shadow_gear_title.text = (
		"%s (%s Lv%d %s)  [%d/%d]"
		% [
			monster.get("name", "?"),
			shadow.get("grade", ""),
			shadow.get("level", 1),
			monster.get("clazz", "?"),
			_shadow_gear_index + 1,
			state.army.size(),
		]
	)
	var shadow_equipped: Dictionary = shadow.get("equipped", {})
	for row: Dictionary in _shadow_gear_rows:
		var slot: String = row["slot"]
		var instance_id: String = shadow_equipped.get(slot, "")
		row["label"].text = "%s: %s" % [slot, _equipped_item_display(instance_id)]


## Shared by both gear panels: resolves an inventory instance_id to a
## display string via state.inventory + _equipment, same lookup pattern as
## _refresh_inventory_label().
func _equipped_item_display(instance_id: String) -> String:
	if instance_id == "":
		return "(empty)"
	for item: Dictionary in state.inventory:
		if item.get("instance_id", "") == instance_id:
			var def := Content.equipment_by_id(_equipment, item.get("equipment_def_id", ""))
			if not def.is_empty():
				return (
					"%s +%d (Lv%d)"
					% [def["name"], def["power_bonus"], item.get("enhancement_level", 0)]
				)
	return "(unknown)"
