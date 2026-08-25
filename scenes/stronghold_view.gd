class_name StrongholdView
extends Node2D
## The Stronghold panel (§22) as its own controller script -- see
## HunterGearView's doc comment for the split-out rationale. Self-
## contained: only touches state.stronghold_*/army, no cross-panel data
## needed. `collected` carries the one-off summary message main.gd
## appends to the shared main label -- the one thing this panel doesn't
## have its own place to show.

signal state_changed
signal collected(message: String)
signal proximity_denied

var _state: HunterState
var _player_lat: float = 0.0  ## fed in from main.gd's GPS callback -- used only
var _player_lon: float = 0.0  ## by the Collect/Assign/Unassign proximity gate below.
var _has_player_position: bool = false

@onready var info_label: Label = $InfoLabel
@onready var facility_labels: Dictionary = {
	Stronghold.RELIQUARY: $ReliquaryLabel,
	Stronghold.TRAINING_YARD: $TrainingYardLabel,
	Stronghold.GATE_WATCH: $GateWatchLabel,
}


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: visible = false)
	$CollectButton.pressed.connect(_on_collect_pressed)
	$UpgradeStrongholdButton.pressed.connect(_on_upgrade_stronghold_pressed)
	for facility_id in Stronghold.FACILITY_IDS:
		var node_prefix := _node_prefix(facility_id)
		get_node(node_prefix + "AssignButton").pressed.connect(_on_assign_pressed.bind(facility_id))
		get_node(node_prefix + "UnassignButton").pressed.connect(
			_on_unassign_pressed.bind(facility_id)
		)
		get_node(node_prefix + "UpgradeButton").pressed.connect(
			_on_facility_upgrade_pressed.bind(facility_id)
		)


## Called from main.gd's _start_game() (both the existing-save and
## new-game bootstrap paths) -- state isn't ready at _ready().
func bind(state: HunterState) -> void:
	_state = state


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


func open() -> void:
	if _state.stronghold_last_collected == 0:
		_state.stronghold_last_collected = Time.get_unix_time_from_system()
	visible = true
	refresh()


func refresh() -> void:
	info_label.text = (
		"Stronghold Lv%d/%d -- Army roster: %d/%d"
		% [
			_state.stronghold_level,
			Stronghold.STRONGHOLD_LEVEL_CAP,
			_state.army.size(),
			Stronghold.army_capacity(_state.stronghold_level),
		]
	)
	for facility_id in Stronghold.FACILITY_IDS:
		var facility: Dictionary = _state.stronghold_facilities[facility_id]
		var level: int = facility["level"]
		var assigned: Array = facility["assigned"]
		facility_labels[facility_id].text = (
			"%s Lv%d/%d (%d/%d slots)"
			% [
				_node_prefix(facility_id),
				level,
				Stronghold.FACILITY_LEVEL_CAP,
				assigned.size(),
				Stronghold.slots_for_level(level),
			]
		)


## Node names for each facility follow "<Prefix><Suffix>Button" (e.g.
## ReliquaryAssignButton) -- this maps a facility id to its prefix once
## instead of a lookup table per button.
func _node_prefix(facility_id: String) -> String:
	match facility_id:
		Stronghold.RELIQUARY:
			return "Reliquary"
		Stronghold.TRAINING_YARD:
			return "TrainingYard"
		Stronghold.GATE_WATCH:
			return "GateWatch"
	return ""


func _is_near_stronghold() -> bool:
	if not _state.stronghold_placed or not _has_player_position:
		return false
	var dist := MapGeometry.distance_metres(
		_player_lat, _player_lon, _state.stronghold_lat, _state.stronghold_lon
	)
	return dist <= GameLogic.POI_PROXIMITY_RADIUS_M


## Assigns the first owned shadow not already busy elsewhere. No picker UI
## for choosing a specific shadow -- same auto-pick convention as
## Equip Best/Fuse Duplicate elsewhere in this project.
func _on_assign_pressed(facility_id: String) -> void:
	if not _is_near_stronghold():
		proximity_denied.emit()
		return
	for shadow: Dictionary in _state.army:
		var shadow_id: String = shadow["instance_id"]
		if not _state.is_shadow_assigned(shadow_id):
			if _state.assign_shadow_to_facility(facility_id, shadow_id):
				SaveService.save(_state)
				refresh()
			return


func _on_unassign_pressed(facility_id: String) -> void:
	if not _is_near_stronghold():
		proximity_denied.emit()
		return
	var assigned: Array = _state.stronghold_facilities[facility_id]["assigned"].duplicate()
	for shadow_id in assigned:
		_state.unassign_shadow(shadow_id)
	SaveService.save(_state)
	refresh()


func _on_facility_upgrade_pressed(facility_id: String) -> void:
	_state.upgrade_facility(facility_id)
	SaveService.save(_state)
	refresh()
	state_changed.emit()


func _on_upgrade_stronghold_pressed() -> void:
	_state.upgrade_stronghold()
	SaveService.save(_state)
	refresh()
	state_changed.emit()


## Collects everything accrued since the last visit, banking Essence/
## tickets and applying Training Yard level-ups, then reports a summary.
func _on_collect_pressed() -> void:
	if not _is_near_stronghold():
		proximity_denied.emit()
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
