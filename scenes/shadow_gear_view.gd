class_name ShadowGearView
extends Node2D
## See HunterGearView's doc comment for the split-out rationale (both
## panels are the two halves of the same gear-panel code, split out
## together). Adds shadow selection (prev/next through the army) and
## shadow-only actions (level up, fuse duplicate, convert to Essence,
## lock, favorite) that Hunter Gear doesn't have.

signal state_changed
signal closed  ## emitted on CloseButton -- lets a caller like ArmyView return to its own screen

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _inventory_view: InventoryView
var _index: int = 0  ## index into state.army for whichever shadow is being viewed
var _rows: Array = []

@onready var title_label: Label = $Title
@onready var sets_label: Label = $SetsLabel
@onready var lore_label: Label = $LoreLabel
@onready var lock_button: Button = $LockButton
@onready var favorite_button: Button = $FavoriteButton


func _ready() -> void:
	$CloseButton.pressed.connect(_on_close_pressed)
	$AutoEquipButton.pressed.connect(_on_auto_equip_pressed)
	$PrevButton.pressed.connect(_on_prev_pressed)
	$NextButton.pressed.connect(_on_next_pressed)
	$LevelUpButton.pressed.connect(_on_level_up_pressed)
	$FuseButton.pressed.connect(_on_fuse_pressed)
	$ConvertButton.pressed.connect(_on_convert_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	favorite_button.pressed.connect(_on_favorite_pressed)
	_rows = GearPanelHelpers.build_gear_rows($Rows, 250.0)
	for row: Dictionary in _rows:
		var slot: String = row["slot"]
		row["equip_btn"].pressed.connect(_on_equip_best_pressed.bind(slot))
		row["unequip_btn"].pressed.connect(_on_unequip_pressed.bind(slot))
		row["enhance_btn"].pressed.connect(_on_enhance_pressed.bind(slot))
		row["browse_btn"].pressed.connect(_on_browse_pressed.bind(slot))


## Called from main.gd's _start_game() (both the existing-save and
## new-game bootstrap paths) -- state/_equipment/_monsters aren't ready at
## _ready().
func bind(
	state: HunterState, equipment: Dictionary, monsters: Array, inventory_view: InventoryView
) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_inventory_view = inventory_view
	if not _inventory_view.item_equipped.is_connected(refresh):
		_inventory_view.item_equipped.connect(refresh)


## False (no-op, panel stays closed) if the army is empty -- main.gd shows
## the "No shadows yet" message, the one side effect this view doesn't
## own (it has no shared label to write to).
func open() -> bool:
	if _state.army.is_empty():
		return false
	_index = clampi(_index, 0, _state.army.size() - 1)
	visible = true
	refresh()
	return true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_prev_pressed() -> void:
	if _state.army.is_empty():
		return
	_index = (_index - 1 + _state.army.size()) % _state.army.size()
	refresh()


func _on_next_pressed() -> void:
	if _state.army.is_empty():
		return
	_index = (_index + 1) % _state.army.size()
	refresh()


## Jumps directly to a known army index (e.g. from ArmyView's roster tap,
## which knows exactly which shadow was pressed) rather than only stepping
## via Prev/Next. Clamped the same way open()/refresh() already are.
func jump_to_index(index: int) -> void:
	if _state.army.is_empty():
		return
	_index = clampi(index, 0, _state.army.size() - 1)
	refresh()


func _current_shadow_instance_id() -> String:
	if _state.army.is_empty() or _index >= _state.army.size():
		return ""
	return _state.army[_index]["instance_id"]


func _on_equip_best_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	_state.equip_best_to_shadow(shadow_id, slot, _equipment, _monsters)
	_after_mutation()


func _on_unequip_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	_state.unequip_from_shadow(shadow_id, slot)
	_after_mutation()


func _on_auto_equip_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	_state.auto_equip_shadow(shadow_id, _equipment, _monsters)
	_after_mutation()


## The item itself (not the wearer) holds enhancement_level, so this is
## the same HunterState.enhance_item() call as the hunter's -- just
## reading the instance_id from the shadow's own equipped dict instead.
func _on_enhance_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var shadow_idx := _state.army.find_custom(
		func(s: Dictionary) -> bool: return s["instance_id"] == shadow_id
	)
	if shadow_idx < 0:
		return
	var shadow_equipped: Dictionary = _state.army[shadow_idx].get("equipped", {})
	var instance_id: String = shadow_equipped.get(slot, "")
	if instance_id == "":
		return
	_state.enhance_item(instance_id)
	_after_mutation()


func _on_browse_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var monster := Content.monster_by_id(_monsters, _state.army[_index].get("monster_id", ""))
	_inventory_view.open_for_slot(
		slot, monster.get("clazz", ""), {"kind": "shadow", "shadow_instance_id": shadow_id}
	)


## No-op (no error UI yet, same placeholder-simplicity as the gear
## buttons) if there's no shadow, it's capped, or Essence is short.
func _on_level_up_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	_state.level_up_shadow(shadow_id)
	_after_mutation()


## Fuses the first owned duplicate of the currently-viewed shadow into it
## (HunterState.find_duplicate_of picks which one -- no picker UI to
## choose a specific duplicate when more than one is owned). No-op if
## there's no shadow, no duplicate owned, it's capped, or Essence is short.
func _on_fuse_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var duplicate_id := _state.find_duplicate_of(shadow_id)
	if duplicate_id == "":
		return
	_state.fuse_shadow(shadow_id, duplicate_id)
	_after_mutation()


## Converts the currently-viewed shadow straight to Essence and removes it
## from the army. Immediate, no confirmation prompt (placeholder UI).
func _on_convert_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	_state.convert_shadow(shadow_id)
	_after_mutation()


## Toggles the currently-viewed shadow's locked flag (protects it from
## Mass-Convert Weakest, §17). Doesn't emit state_changed -- lock/favorite
## don't touch Essence/Tickets/army/inventory, only this panel cares.
func _on_lock_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var idx := _shadow_index(shadow_id)
	if idx < 0:
		return
	_state.set_shadow_locked(shadow_id, not _state.army[idx].get("locked", false))
	SaveService.save(_state)
	refresh()


func _on_favorite_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var idx := _shadow_index(shadow_id)
	if idx < 0:
		return
	_state.set_shadow_favorite(shadow_id, not _state.army[idx].get("favorite", false))
	SaveService.save(_state)
	refresh()


func _shadow_index(shadow_id: String) -> int:
	return _state.army.find_custom(
		func(s: Dictionary) -> bool: return s["instance_id"] == shadow_id
	)


func _after_mutation() -> void:
	SaveService.save(_state)
	refresh()
	state_changed.emit()


func refresh() -> void:
	if _state.army.is_empty():
		title_label.text = "No shadows yet"
		for row: Dictionary in _rows:
			row["label"].text = "%s: --" % row["slot"]
		sets_label.text = "Active sets: (none)"
		lore_label.text = ""
		return

	_index = clampi(_index, 0, _state.army.size() - 1)
	var shadow: Dictionary = _state.army[_index]
	var monster := Content.monster_by_id(_monsters, shadow.get("monster_id", ""))
	var locked: bool = shadow.get("locked", false)
	var favorite: bool = shadow.get("favorite", false)
	var family: String = monster.get("family", "?")
	title_label.text = (
		"%s%s%s (%s·%s Lv%d/%d %s · %s)  [%d/%d]"
		% [
			"★" if favorite else "",
			"🔒" if locked else "",
			monster.get("name", "?"),
			GameLogic.grade_name(shadow.get("grade", "")),
			shadow.get("grade", ""),
			shadow.get("level", 1),
			ShadowLeveling.LEVEL_CAP,
			monster.get("clazz", "?"),
			family,
			_index + 1,
			_state.army.size(),
		]
	)
	lore_label.text = "%s\nTraits: (coming soon)" % String(monster.get("lore", ""))
	lock_button.text = "Unlock" if locked else "Lock"
	favorite_button.text = "Unfavorite" if favorite else "Favorite"
	var shadow_equipped: Dictionary = shadow.get("equipped", {})
	for row: Dictionary in _rows:
		var slot: String = row["slot"]
		var instance_id: String = shadow_equipped.get(slot, "")
		row["label"].text = (
			"%s: %s"
			% [
				slot,
				GearPanelHelpers.equipped_item_display(instance_id, _state.inventory, _equipment)
			]
		)
	sets_label.text = GearPanelHelpers.active_sets_display(
		shadow_equipped, _state.inventory, _equipment
	)
