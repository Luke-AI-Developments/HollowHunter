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
signal item_equipped  ## fired after a successful Equip-from-detail, so the caller (a gear
## panel) can refresh itself -- distinct from state_changed, which the shared HUD listens to;
## this one specifically tells "your paper-doll may now be stale, refresh your own display"

const CLASS_OPTIONS := ["ALL", "WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]
const EQUIPPED_OPTIONS := ["ALL", "EQUIPPED", "UNEQUIPPED"]
const SORT_MODES := ["power", "rarity", "slot", "newest"]
const RARITY_BELOW_OPTIONS := ["UNCOMMON", "RARE", "EPIC", "LEGENDARY"]  ## "below COMMON" is empty

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _slot_options: Array = ["ALL"]  ## filled in bind() from Equip.SLOTS
var _set_options: Array = ["ALL"]  ## filled in bind() from equipment["armor_sets"]
var _filters := {"class": "ALL", "slot": "ALL", "rarity": "ALL", "set_id": "ALL", "equipped": "ALL"}
var _sort_mode: String = "power"
var _selected_instance_id: String = ""
var _grid_items: Array = []  ## the last filtered+sorted list, so detail can look an item back up
var _multi_select_mode: bool = false
var _multi_selected: Dictionary = {}  ## instance_id -> true, only while _multi_select_mode
var _pending_scrap_ids: Array = []  ## computed by whichever bulk action was tapped
var _rarity_below_threshold: String = "UNCOMMON"
## set by open_for_slot(), cleared by open()
var _context := {"kind": "none", "shadow_instance_id": ""}
var _context_slot: String = ""

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
	$GridTab/BulkBar/MultiSelectToggleButton.pressed.connect(_on_multi_select_toggle_pressed)
	$GridTab/BulkBar/ScrapSelectedButton.pressed.connect(_on_scrap_selected_pressed)
	$GridTab/BulkBar/ScrapBelowRarityButton.pressed.connect(_on_scrap_below_rarity_pressed)
	$GridTab/BulkBar/ScrapDuplicatesButton.pressed.connect(_on_scrap_duplicates_pressed)
	$ConfirmScrapPanel/ConfirmButton.pressed.connect(_on_confirm_scrap_pressed)
	$ConfirmScrapPanel/CancelButton.pressed.connect(_on_cancel_scrap_pressed)
	$DetailPanel/EquipButton.pressed.connect(_on_equip_pressed)


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
	_context = {"kind": "none", "shadow_instance_id": ""}
	_context_slot = ""
	visible = true
	$GridTabButton.visible = true  # re-shown in case a later task's tab hid it
	_on_grid_tab_pressed()


## Called from a gear panel's new "Browse" button -- opens pre-filtered to
## `slot` and (if given) `class_filter`, with `context` carried through so
## Compare and Equip-from-detail both work. `context`: {"kind": "hunter"|
## "shadow", "shadow_instance_id": ""}.
func open_for_slot(slot: String, class_filter: String, context: Dictionary) -> void:
	_context = context
	_context_slot = slot
	_filters["slot"] = slot
	_filters["class"] = class_filter
	visible = true
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
		var select_mark := " [✓]" if _multi_selected.has(item["instance_id"]) else ""
		cell.text = (
			"%s\n%s · %s%s%s\npwr:%d"
			% [
				item["name"],
				item["rarity"],
				item["slot"],
				lock_mark,
				select_mark,
				item["power_bonus"]
			]
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
	if _multi_select_mode:
		if _multi_selected.has(instance_id):
			_multi_selected.erase(instance_id)
		else:
			_multi_selected[instance_id] = true
		_refresh_grid()  # redraw so selected cells can show a mark
		return
	_selected_instance_id = instance_id
	_show_detail()


func _on_multi_select_toggle_pressed() -> void:
	_multi_select_mode = not _multi_select_mode
	_multi_selected.clear()
	$GridTab/BulkBar/MultiSelectToggleButton.text = (
		"Cancel Multi-Select" if _multi_select_mode else "Select Multiple"
	)
	_refresh_grid()


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

	var equip_button: Button = $DetailPanel/EquipButton
	equip_button.visible = _context["kind"] != "none" and item["slot"] == _context_slot
	$DetailPanel/CompareLabel.text = ""
	if equip_button.visible:
		var current_def := _current_context_def()
		var delta := Inventory.compare_delta(item, current_def)
		var lines := ["vs. currently equipped:", "Power: %+d" % delta["power_delta"]]
		for stat in delta["stat_delta"]:
			lines.append("%s: %+d" % [stat, delta["stat_delta"][stat]])
		$DetailPanel/CompareLabel.text = "\n".join(lines)


func _on_detail_back_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	_selected_instance_id = ""


## The def dict (enhancement-scaled, same shape filter_by's enrichment
## produces) of whatever's currently in _context_slot for the current
## context -- {} if the slot's empty. compare_delta() treats {} as
## all-zero, so an empty slot just shows the full candidate as pure gain.
func _current_context_def() -> Dictionary:
	var current_instance_id := ""
	if _context["kind"] == "hunter":
		current_instance_id = _state.equipped.get(_context_slot, "")
	elif _context["kind"] == "shadow":
		var idx := _state.army.find_custom(
			func(s: Dictionary) -> bool: return s["instance_id"] == _context["shadow_instance_id"]
		)
		if idx >= 0:
			current_instance_id = _state.army[idx].get("equipped", {}).get(_context_slot, "")
	if current_instance_id == "":
		return {}
	var current_items := Inventory.filter_by(
		_state.inventory, _equipment, _state.equipped, _state.army, {}
	)
	for i: Dictionary in current_items:
		if i["instance_id"] == current_instance_id:
			return i
	return {}


func _on_equip_pressed() -> void:
	if _selected_instance_id == "" or _context["kind"] == "none":
		return
	var ok := false
	if _context["kind"] == "hunter":
		ok = _state.equip_to_hunter(_selected_instance_id, _equipment)
	elif _context["kind"] == "shadow":
		ok = _state.equip_to_shadow(
			_context["shadow_instance_id"], _selected_instance_id, _equipment, _monsters
		)
	if not ok:
		return
	_after_mutation()
	item_equipped.emit()
	_on_detail_back_pressed()


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


func _on_scrap_selected_pressed() -> void:
	if _multi_selected.is_empty():
		return
	_offer_scrap_confirm(_multi_selected.keys())


func _on_scrap_below_rarity_pressed() -> void:
	_rarity_below_threshold = RARITY_BELOW_OPTIONS[
		(RARITY_BELOW_OPTIONS.find(_rarity_below_threshold) + 1) % RARITY_BELOW_OPTIONS.size()
	]
	$GridTab/BulkBar/ScrapBelowRarityButton.text = "Scrap Below: %s" % _rarity_below_threshold
	# Cycling the threshold is a separate tap from committing to it -- a second, explicit
	# "go" isn't specced, so this button both cycles AND immediately offers the confirm
	# for whatever it now reads, matching "no extra taps beyond what's needed" elsewhere
	# in this project's placeholder UI.
	var candidates := Inventory.scrap_candidates_below_rarity(
		_state.inventory, _equipment, _rarity_below_threshold, _state.equipped, _state.army
	)
	_offer_scrap_confirm(candidates)


func _on_scrap_duplicates_pressed() -> void:
	var candidates := Inventory.scrap_candidates_unequipped_duplicates(
		_state.inventory, _state.equipped, _state.army
	)
	_offer_scrap_confirm(candidates)


## Filters instance_ids down to what HunterState.bulk_scrap() will actually
## scrap (skips locked/equipped, same guard as scrap_item()) so the preview
## total can never overstate the real yield -- matters for "Scrap Selected"
## since multi-select has no such guard on what can be tapped; the below-
## rarity/duplicates candidate lists are already pre-filtered, so this is a
## no-op for those.
func _offer_scrap_confirm(instance_ids: Array) -> void:
	var eligible_ids: Array = []
	var total := 0
	for instance_id in instance_ids:
		var idx := _state.inventory.find_custom(
			func(i: Dictionary) -> bool: return i["instance_id"] == instance_id
		)
		if idx < 0:
			continue
		var item: Dictionary = _state.inventory[idx]
		if item.get("locked", false):
			continue
		if Inventory.wearer_of(instance_id, _state.equipped, _state.army)["kind"] != "none":
			continue
		var def := Content.equipment_by_id(_equipment, item.get("equipment_def_id", ""))
		total += GameLogic.essence_for_scrapped_item(def.get("rarity", ""))
		eligible_ids.append(instance_id)
	if eligible_ids.is_empty():
		return
	_pending_scrap_ids = eligible_ids
	$ConfirmScrapPanel/ConfirmLabel.text = (
		"Scrap %d item(s) for %d Essence?" % [eligible_ids.size(), total]
	)
	$ConfirmScrapPanel.visible = true


func _on_confirm_scrap_pressed() -> void:
	$ConfirmScrapPanel.visible = false
	_state.bulk_scrap(_pending_scrap_ids, _equipment)
	_pending_scrap_ids = []
	_multi_selected.clear()
	_after_mutation()


func _on_cancel_scrap_pressed() -> void:
	$ConfirmScrapPanel.visible = false
	_pending_scrap_ids = []


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
	_refresh_grid()
