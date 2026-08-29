class_name ArmyView
extends Node2D
## §17: the Army management screen. Roster tab (class-grouped, sortable/
## filterable browse over the whole owned army) and Party tab (party_view.gd:
## the manual "pick up to 3 who fight" picker over a sorted full-army list)
## in one panel. Self-contained controller -- holds HunterState
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
var _shadow_reveal_card: ShadowRevealCard
var _awaiting_reveal_close: bool = false
var _grade_filter: String = "ALL"
var _sort_mode: String = "power"
var _party_sort_mode: String = "power"  ## Party tab's own sort cycle (PartyView.sort_changed)
var _collapsed: Dictionary = {}  ## clazz -> bool, session-only (resets on reopen)

@onready var roster_tab: Node2D = $RosterTab
@onready var party_tab: PartyView = $SquadTab
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
	party_tab.close_requested.connect(func() -> void: visible = false)
	party_tab.toggle_requested.connect(_on_squad_toggle_requested)
	party_tab.auto_equip_requested.connect(_on_squad_auto_equip_requested)
	party_tab.sort_changed.connect(_on_party_sort_changed)


func bind(
	state: HunterState,
	equipment: Dictionary,
	monsters: Array,
	shadow_gear_view: ShadowGearView,
	shadow_reveal_card: ShadowRevealCard
) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_shadow_gear_view = shadow_gear_view
	_shadow_reveal_card = shadow_reveal_card
	# Reopens this panel's Roster tab whenever Shadow Gear closes -- correct
	# as long as ArmyView is the only path that opens Shadow Gear, which
	# holds once the old standalone ShadowGearButton entry point is retired.
	if not _shadow_gear_view.closed.is_connected(_on_shadow_gear_view_closed):
		_shadow_gear_view.closed.connect(_on_shadow_gear_view_closed)
	if not _shadow_reveal_card.closed.is_connected(_on_reveal_card_closed):
		_shadow_reveal_card.closed.connect(_on_reveal_card_closed)


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
	party_tab.visible = false
	_refresh_roster()


func _on_squad_tab_pressed() -> void:
	roster_tab.visible = false
	party_tab.visible = true
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

	var fielded_ids := {}
	for id in _state.active_party_ids:
		fielded_ids[id] = true

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
			var marker := " [P]" if fielded_ids.has(e["instance_id"]) else ""
			marker += " [L]" if e["locked"] else ""
			marker += " [F]" if e["favorite"] else ""
			row.text = (
				"%s (%s·%s Lv%d) pwr:%d%s"
				% [e["display_name"], e["grade_name"], e["grade"], e["level"], e["power"], marker]
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
	# ArmyPanel and the reveal card are sibling full-screen panels -- hide
	# this one only once the card will actually show (its opaque Bg would
	# sit in front otherwise).
	if not _shadow_reveal_card.show_for(shadow_instance_id, ShadowRevealCard.Mode.DETAIL):
		return
	visible = false
	_awaiting_reveal_close = true


## The reveal card closed. Only act on a close that originated from a roster
## tap (DETAIL mode, flagged by _on_shadow_row_pressed) -- CLAIM-mode closes
## fire this same signal and must not pop the roster over the map. On the
## "Manage Gear" route the flag is set but Shadow Gear is already visible, so
## defer to it -- it re-shows the roster itself when IT closes
## (_on_shadow_gear_view_closed).
func _on_reveal_card_closed() -> void:
	if not _awaiting_reveal_close:
		return
	_awaiting_reveal_close = false
	if not _shadow_gear_view.visible:
		open()


## Closing Shadow Gear (opened from a roster tap) returns to the Army
## screen's Roster tab rather than leaving both panels hidden.
func _on_shadow_gear_view_closed() -> void:
	open()


## Phase 2/P2 step 4 logic, moved here from main.gd unchanged (§17's
## "mass-convert weak shadows" QoL bullet) -- immediate, no confirmation,
## same as before this split.
func _on_mass_convert_pressed() -> void:
	var surplus := SquadBuilder.surplus_shadow_ids(
		_state.army,
		_monsters,
		_state.level,
		MASS_CONVERT_COUNT,
		_state.active_party_ids,
		_equipment,
		_state.inventory
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
	var sorted_army := SquadBuilder.sort_shadows(
		SquadBuilder.enrich_army(
			_state.army, _monsters, _state.level, _equipment, _state.inventory
		),
		_party_sort_mode
	)
	# Defensive prune: a stale save (or an older build) could hold a fielded id
	# for a shadow that's no longer in the army, which would disable every
	# picker row. Drop any such id and persist before refreshing.
	var live_ids := {}
	for e: Dictionary in sorted_army:
		live_ids[e["instance_id"]] = true
	var pruned := _state.active_party_ids.filter(func(id: String) -> bool: return live_ids.has(id))
	if pruned.size() != _state.active_party_ids.size():
		_state.active_party_ids = pruned
		_after_mutation()
	party_tab.refresh(sorted_army, _state.active_party_ids)


func _on_party_sort_changed(mode: String) -> void:
	_party_sort_mode = mode
	_refresh_squad()


func _on_squad_toggle_requested(instance_id: String) -> void:
	var fielded := _state.active_party_ids.has(instance_id)
	if not _state.toggle_party_member(instance_id, not fielded):
		squad_full_message.emit("\n\n3 already fielded -- unfield one first.")
		return
	_after_mutation()
	_refresh_squad()


func _on_squad_auto_equip_requested() -> void:
	# auto_equip_squad skips unknown ids, so a 0/1/2-member party is a safe no-op.
	_state.auto_equip_squad(_state.active_party_ids, _equipment, _monsters)
	_after_mutation()
	_refresh_squad()


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
