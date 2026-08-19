class_name InventoryView
extends Node2D
## §17b: the Equipment inventory screen -- filterable/sortable icon grid
## over the whole owned pool (hunter + every shadow share one inventory,
## see core/equip.gd's own doc comment), item detail, and (added in later
## tasks) a Sets-progress tab and bulk scrap-to-Essence. Self-contained
## controller (holds HunterState directly, mutates it, saves), same
## pattern as ArmyView/StrongholdView.
##
## This task builds the Grid tab and item detail WITHOUT Compare or Equip
## -- those need a context (which shadow/hunter slot triggered the open),
## which only exists once Task 7 retrofits the gear panels to carry it in.
## Standalone opens (this task's only entry point) have no context.

signal state_changed

const CLASS_OPTIONS := ["ALL", "WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]
const EQUIPPED_OPTIONS := ["ALL", "EQUIPPED", "UNEQUIPPED"]
const SORT_MODES := ["power", "rarity", "slot", "newest"]

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _slot_options: Array = ["ALL"]  ## filled in bind() from Equip.SLOTS
var _set_options: Array = ["ALL"]  ## filled in bind() from equipment["armor_sets"]
var _filters := {"class": "ALL", "slot": "ALL", "rarity": "ALL", "set_id": "ALL", "equipped": "ALL"}
var _sort_mode: String = "power"
var _selected_instance_id: String = ""
var _grid_items: Array = []  ## the last filtered+sorted list, so detail can look an item back up

@onready var grid: GridContainer = $GridTab/GridScroll/Grid
@onready var class_filter_button: Button = $GridTab/FilterBar/ClassFilterButton
@onready var slot_filter_button: Button = $GridTab/FilterBar/SlotFilterButton
@onready var rarity_filter_button: Button = $GridTab/FilterBar/RarityFilterButton
@onready var set_filter_button: Button = $GridTab/FilterBar/SetFilterButton
@onready var equipped_filter_button: Button = $GridTab/FilterBar/EquippedFilterButton
@onready var sort_button: Button = $GridTab/FilterBar/SortButton
@onready var capacity_warning_label: Label = $GridTab/CapacityWarningLabel
@onready var detail_panel: Node2D = $DetailPanel
@onready var name_label: Label = $DetailPanel/NameLabel
@onready var stats_label: Label = $DetailPanel/StatsLabel
@onready var wearer_label: Label = $DetailPanel/WearerLabel
@onready var lock_button: Button = $DetailPanel/LockButton
@onready var scrap_button: Button = $DetailPanel/ScrapButton
@onready var sets_rows: Node2D = $SetsTab/SetsScroll/SetsRows


func _ready() -> void:
	$GridTabButton.pressed.connect(_on_grid_tab_pressed)
	$SetsTabButton.pressed.connect(_on_sets_tab_pressed)
	$CloseButton.pressed.connect(func() -> void: visible = false)
	class_filter_button.pressed.connect(_on_class_filter_pressed)
	slot_filter_button.pressed.connect(_on_slot_filter_pressed)
	rarity_filter_button.pressed.connect(_on_rarity_filter_pressed)
	set_filter_button.pressed.connect(_on_set_filter_pressed)
	equipped_filter_button.pressed.connect(_on_equipped_filter_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	$DetailPanel/BackButton.pressed.connect(_on_detail_back_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	scrap_button.pressed.connect(_on_scrap_pressed)


func bind(state: HunterState, equipment: Dictionary, monsters: Array) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_slot_options = ["ALL"] + Equip.SLOTS
	_set_options = ["ALL"]
	for set_def: Dictionary in equipment.get("armor_sets", []):
		_set_options.append(String(set_def.get("id", "")))


## Standalone entry point -- no shadow/hunter context, Compare never
## renders (Task 7 adds a second, context-carrying open variant).
func open() -> void:
	visible = true
	$GridTabButton.visible = true  # re-shown in case a later task's tab hid it
	_on_grid_tab_pressed()


func _on_grid_tab_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	$SetsTab.visible = false
	_refresh_grid()


func _on_sets_tab_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = false
	$SetsTab.visible = true
	_refresh_sets()


## Rebuilds one row per set in equipment["armor_sets"] -- name, owned/4
## (ArmorSets.owned_set_counts), and both tier bonus strings verbatim
## (same "display only, see core/armor_sets.gd for what's mechanical"
## convention GearPanelHelpers.active_sets_display already uses).
func _refresh_sets() -> void:
	for child in sets_rows.get_children():
		child.queue_free()
	var counts := ArmorSets.owned_set_counts(_state.inventory, _equipment)
	var y := 0.0
	for set_def: Dictionary in _equipment.get("armor_sets", []):
		var owned: int = counts.get(set_def.get("id", ""), 0)
		var label := Label.new()
		label.position = Vector2(40, y)
		label.size = Vector2(2340, 80)
		label.add_theme_font_size_override("font_size", 18)
		label.text = (
			"%s  %d/4\n  2pc: %s\n  4pc: %s"
			% [
				set_def.get("name", ""),
				owned,
				set_def.get("bonus_2pc", ""),
				set_def.get("bonus_4pc", "")
			]
		)
		sets_rows.add_child(label)
		y += 90


func _cycle(options: Array, current: String) -> String:
	return options[(options.find(current) + 1) % options.size()]


func _on_class_filter_pressed() -> void:
	_filters["class"] = _cycle(CLASS_OPTIONS, _filters["class"])
	class_filter_button.text = "Class: %s" % _filters["class"]
	_refresh_grid()


func _on_slot_filter_pressed() -> void:
	_filters["slot"] = _cycle(_slot_options, _filters["slot"])
	slot_filter_button.text = "Slot: %s" % _filters["slot"]
	_refresh_grid()


func _on_rarity_filter_pressed() -> void:
	_filters["rarity"] = _cycle(["ALL"] + Inventory.RARITY_ORDER, _filters["rarity"])
	rarity_filter_button.text = "Rarity: %s" % _filters["rarity"]
	_refresh_grid()


func _on_set_filter_pressed() -> void:
	_filters["set_id"] = _cycle(_set_options, _filters["set_id"])
	set_filter_button.text = "Set: %s" % _filters["set_id"]
	_refresh_grid()


func _on_equipped_filter_pressed() -> void:
	_filters["equipped"] = _cycle(EQUIPPED_OPTIONS, _filters["equipped"])
	equipped_filter_button.text = "Show: %s" % _filters["equipped"]
	_refresh_grid()


func _on_sort_pressed() -> void:
	_sort_mode = SORT_MODES[(SORT_MODES.find(_sort_mode) + 1) % SORT_MODES.size()]
	sort_button.text = "Sort: %s" % _sort_mode.capitalize()
	_refresh_grid()


func _refresh_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var filtered := Inventory.filter_by(
		_state.inventory, _equipment, _state.equipped, _state.army, _filters
	)
	_grid_items = Inventory.sort_by(filtered, _sort_mode)

	for item: Dictionary in _grid_items:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(560, 160)
		var lock_mark := " [L]" if item["locked"] else ""
		cell.text = (
			"%s\n%s · %s%s\npwr:%d"
			% [item["name"], item["rarity"], item["slot"], lock_mark, item["power_bonus"]]
		)
		cell.pressed.connect(_on_cell_pressed.bind(item["instance_id"]))
		grid.add_child(cell)

	if Inventory.is_over_soft_cap(_state.inventory):
		capacity_warning_label.text = (
			"⚠ Inventory is large (%d items) -- consider scrapping unwanted gear."
			% _state.inventory.size()
		)
	else:
		capacity_warning_label.text = ""


func _on_cell_pressed(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_show_detail()


func _find_grid_item(instance_id: String) -> Dictionary:
	for item: Dictionary in _grid_items:
		if item["instance_id"] == instance_id:
			return item
	return {}


func _show_detail() -> void:
	var item := _find_grid_item(_selected_instance_id)
	if item.is_empty():
		_on_detail_back_pressed()
		return
	$GridTab.visible = false
	detail_panel.visible = true
	name_label.text = "%s%s" % [item["name"], " [LOCKED]" if item["locked"] else ""]
	var stat_lines := [
		"Rarity: %s" % item["rarity"], "Slot: %s" % item["slot"], "Class: %s" % item["clazz"]
	]
	stat_lines.append("Power bonus: +%d" % item["power_bonus"])
	for stat in item["stat_mods"]:
		stat_lines.append("%s: +%d" % [stat, item["stat_mods"][stat]])
	if item["set_id"] != "":
		stat_lines.append("Set: %s" % item["set_id"])
	stats_label.text = "\n".join(stat_lines)

	var wearer := Inventory.wearer_of(_selected_instance_id, _state.equipped, _state.army)
	match wearer["kind"]:
		"hunter":
			wearer_label.text = "Currently equipped by: you (the hunter)"
		"shadow":
			var shadow_idx := _state.army.find_custom(
				func(s: Dictionary) -> bool: return s["instance_id"] == wearer["shadow_instance_id"]
			)
			var shadow_name := "a shadow"
			if shadow_idx >= 0:
				var monster := Content.monster_by_id(
					_monsters, _state.army[shadow_idx].get("monster_id", "")
				)
				shadow_name = monster.get("name", "a shadow")
			wearer_label.text = "Currently equipped by: %s" % shadow_name
		_:
			wearer_label.text = "Unequipped"

	lock_button.text = "Unlock" if item["locked"] else "Lock"
	var worn: bool = wearer["kind"] != "none"
	scrap_button.visible = not worn and not item["locked"]


func _on_detail_back_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	_selected_instance_id = ""


func _on_lock_pressed() -> void:
	if _selected_instance_id == "":
		return
	var item := _find_grid_item(_selected_instance_id)
	_state.set_item_locked(_selected_instance_id, not item.get("locked", false))
	_after_mutation()
	_show_detail()


## Structural guard already lives in HunterState.scrap_item() (returns 0
## for locked/equipped) -- this button is also hidden for those cases in
## _show_detail(), so the guard and the UI agree, not just a confirm
## dialog papering over a UI-only restriction.
func _on_scrap_pressed() -> void:
	if _selected_instance_id == "":
		return
	_state.scrap_item(_selected_instance_id, _equipment)
	_after_mutation()
	_on_detail_back_pressed()


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
	_refresh_grid()
