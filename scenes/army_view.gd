class_name ArmyView
extends Node2D
## §17: the Army management screen. Roster tab (class-grouped, sortable/
## filterable browse over the whole owned army) and Squad tab (the existing
## squad-of-6 picker, squad_view.gd, absorbed here unchanged bar one new
## button) in one panel. Self-contained controller -- holds HunterState
## directly and mutates it itself, same pattern as StrongholdView/
## CharacterView -- replaces the old standalone ShadowGearButton/
## SquadButton/MassConvertButton entry points and the flat ArmyLabel text.
##
## Deliberately does NOT open or reference an inventory screen anywhere --
## that's §17b, a later, separate build.

signal state_changed
signal mass_convert_result(message: String)
signal squad_full_message(message: String)

const GRADE_FILTER_OPTIONS := ["ALL", "E", "D", "C", "B", "A", "S"]
const SORT_MODES := ["power", "grade"]
const MASS_CONVERT_COUNT := 3  ## same v0 batch size main.gd used before this split

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _shadow_gear_view: ShadowGearView
var _grade_filter: String = "ALL"
var _sort_mode: String = "power"
var _collapsed: Dictionary = {}  ## clazz -> bool, session-only (resets on reopen)

@onready var roster_tab: Node2D = $RosterTab
@onready var squad_tab: SquadView = $SquadTab
@onready var grade_filter_button: Button = $RosterTab/FilterBar/GradeFilterButton
@onready var sort_button: Button = $RosterTab/FilterBar/SortButton
@onready var sections_container: Control = $RosterTab/SectionsScroll/Sections
@onready var mass_convert_button: Button = $RosterTab/BulkBar/MassConvertButton


func _ready() -> void:
	$RosterTabButton.pressed.connect(_on_roster_tab_pressed)
	$SquadTabButton.pressed.connect(_on_squad_tab_pressed)
	$CloseButton.pressed.connect(func() -> void: visible = false)
	grade_filter_button.pressed.connect(_on_grade_filter_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	mass_convert_button.pressed.connect(_on_mass_convert_pressed)
	squad_tab.close_requested.connect(func() -> void: visible = false)
	squad_tab.auto_fill_requested.connect(_on_squad_auto_fill_requested)
	squad_tab.toggle_requested.connect(_on_squad_toggle_requested)
	squad_tab.auto_equip_squad_requested.connect(_on_squad_auto_equip_requested)


func bind(
	state: HunterState, equipment: Dictionary, monsters: Array, shadow_gear_view: ShadowGearView
) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_shadow_gear_view = shadow_gear_view
	# Reopens this panel's Roster tab whenever Shadow Gear closes -- correct
	# as long as ArmyView is the only path that opens Shadow Gear, which
	# holds once the old standalone ShadowGearButton entry point is retired.
	if not _shadow_gear_view.closed.is_connected(_on_shadow_gear_view_closed):
		_shadow_gear_view.closed.connect(_on_shadow_gear_view_closed)


func open() -> void:
	visible = true
	_on_roster_tab_pressed()


## Called by main.gd after any army-changing event (gate win, Nadir claim,
## Stronghold idle-XP) so the Roster tab doesn't show stale data if it's
## already open when the change happens.
func refresh_if_open() -> void:
	if visible and roster_tab.visible:
		_refresh_roster()


func _on_roster_tab_pressed() -> void:
	roster_tab.visible = true
	squad_tab.visible = false
	_refresh_roster()


func _on_squad_tab_pressed() -> void:
	roster_tab.visible = false
	squad_tab.visible = true
	_refresh_squad()


func _on_grade_filter_pressed() -> void:
	var idx := GRADE_FILTER_OPTIONS.find(_grade_filter)
	_grade_filter = GRADE_FILTER_OPTIONS[(idx + 1) % GRADE_FILTER_OPTIONS.size()]
	grade_filter_button.text = "Grade: %s" % _grade_filter
	_refresh_roster()


func _on_sort_pressed() -> void:
	var idx := SORT_MODES.find(_sort_mode)
	_sort_mode = SORT_MODES[(idx + 1) % SORT_MODES.size()]
	sort_button.text = "Sort: %s" % _sort_mode.capitalize()
	_refresh_roster()


## Builds one collapsible section per class, each holding that class's
## (filtered, sorted) shadows as tappable rows -- opens the shadow detail
## hub on tap, same panel the old flat ArmyLabel + ShadowGearButton used to
## reach separately. Rebuilds from scratch each call (Sections' children
## are freed first) rather than diffing -- this list changes rarely enough
## (claim/level/fuse/convert) that rebuild-on-refresh is simpler and cheap.
func _refresh_roster() -> void:
	for child in sections_container.get_children():
		child.queue_free()

	var enriched := SquadBuilder.enrich_army(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	if _grade_filter != "ALL":
		enriched = enriched.filter(func(e: Dictionary) -> bool: return e["grade"] == _grade_filter)
	var sort_key := "power" if _sort_mode == "power" else "grade"
	enriched.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if sort_key == "power":
				return a["power"] > b["power"]
			return GameLogic.RANK_ORDER.find(b["grade"]) < GameLogic.RANK_ORDER.find(a["grade"])
	)

	var squad_ids := {}
	for member: Dictionary in SquadBuilder.auto_fill_squad(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	):
		squad_ids[member["instance_id"]] = true

	var y := 0.0
	for clazz in SquadBuilder.CLASSES:
		var class_shadows: Array = enriched.filter(
			func(e: Dictionary) -> bool: return e["clazz"] == clazz
		)
		var collapsed: bool = _collapsed.get(clazz, false)
		var header := Button.new()
		header.position = Vector2(40, y)
		header.size = Vector2(1000, 44)
		header.text = (
			"%s %s (%d)" % ["▸" if collapsed else "▾", clazz.capitalize(), class_shadows.size()]
		)
		header.pressed.connect(_on_section_header_pressed.bind(clazz))
		sections_container.add_child(header)
		y += 50

		if collapsed:
			continue

		for e: Dictionary in class_shadows:
			var row := Button.new()
			row.position = Vector2(60, y)
			row.size = Vector2(960, 40)
			row.icon = ArtPaths.monster_portrait(e["monster_id"])
			row.expand_icon = true
			var marker := " [S]" if squad_ids.has(e["instance_id"]) else ""
			marker += " [L]" if e["locked"] else ""
			marker += " [F]" if e["favorite"] else ""
			row.text = (
				"%s (%s·%s Lv%d) pwr:%d%s"
				% [e["monster_name"], e["grade_name"], e["grade"], e["level"], e["power"], marker]
			)
			row.pressed.connect(_on_shadow_row_pressed.bind(e["instance_id"]))
			sections_container.add_child(row)
			y += 44

	# Lets SectionsScroll (the ScrollContainer wrapping this node) know the
	# true content height so it knows how far there is to scroll -- a bare
	# Control reports zero minimum size otherwise since nothing here is
	# laid out by an auto-layout container.
	sections_container.custom_minimum_size = Vector2(1000, y)


## Collapsing/expanding folds the section's row space away rather than just
## hiding the rows in place -- _refresh_roster() skips building a collapsed
## section's rows entirely, so the sections below shift up to fill the gap.
func _on_section_header_pressed(clazz: String) -> void:
	_collapsed[clazz] = not _collapsed.get(clazz, false)
	_refresh_roster()


func _on_shadow_row_pressed(shadow_instance_id: String) -> void:
	# ArmyPanel and ShadowGearPanel are sibling full-screen panels -- hide
	# this one first or ShadowGearPanel opens invisibly/unclickable behind
	# ArmyPanel's own opaque Bg.
	visible = false
	_shadow_gear_view.open()
	# ShadowGearView.open() opens on whichever _index it last had -- jump it
	# to the tapped shadow before showing, same lookup shadow_gear_view's
	# own Prev/Next buttons use internally.
	var idx := _state.army.find_custom(
		func(s: Dictionary) -> bool: return s["instance_id"] == shadow_instance_id
	)
	if idx >= 0:
		_shadow_gear_view.jump_to_index(idx)


## Closing Shadow Gear (opened from a roster tap) returns to the Army
## screen's Roster tab rather than leaving both panels hidden.
func _on_shadow_gear_view_closed() -> void:
	open()


## Phase 2/P2 step 4 logic, moved here from main.gd unchanged (§17's
## "mass-convert weak shadows" QoL bullet) -- immediate, no confirmation,
## same as before this split.
func _on_mass_convert_pressed() -> void:
	var surplus := SquadBuilder.surplus_shadow_ids(
		_state.army, _monsters, _state.level, MASS_CONVERT_COUNT, _equipment, _state.inventory
	)
	if surplus.is_empty():
		return
	var gained := _state.mass_convert(surplus)
	_after_mutation()
	_refresh_roster()
	mass_convert_result.emit(
		"\n\nMass-converted %d shadow(s) -> +%d Essence" % [surplus.size(), gained]
	)


func _refresh_squad() -> void:
	var squad := SquadBuilder.auto_fill_squad(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	var chosen := SquadBuilder.resolve_party(
		_state.army, _monsters, _state.level, _state.active_party_ids, _equipment, _state.inventory
	)
	squad_tab.refresh(squad, _state.active_party_ids, chosen)


func _on_squad_auto_fill_requested() -> void:
	_state.active_party_ids = []
	_after_mutation()
	_refresh_squad()


func _on_squad_toggle_requested(instance_id: String) -> void:
	var fielded := _state.active_party_ids.has(instance_id)
	if not _state.toggle_party_member(instance_id, not fielded):
		squad_full_message.emit("\n\n3 already fielded -- unfield one first.")
		return
	_after_mutation()
	_refresh_squad()


func _on_squad_auto_equip_requested() -> void:
	var squad := SquadBuilder.auto_fill_squad(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	var ids: Array = squad.map(func(m: Dictionary) -> String: return m["instance_id"])
	_state.auto_equip_squad(ids, _equipment, _monsters)
	_after_mutation()
	_refresh_squad()


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
