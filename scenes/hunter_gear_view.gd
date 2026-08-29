class_name HunterGearView
extends Node2D
## The Hunter Gear panel as its own controller script -- split out of
## scenes/main.gd, which was at the project's max-file-lines lint cap.
## Unlike BattleView/PartyView/ShopView (pure display, signal-request
## pattern -- main.gd keeps mutation authority), this and its sibling
## controllers (ShadowGearView, StrongholdView, CharacterView) hold a
## direct reference to HunterState and mutate it themselves: every action
## here is fully self-contained to this one panel (equip/unequip/
## enhance), so routing each button through main.gd would just be
## indirection with no benefit. `state_changed` fires after any mutation
## so main.gd can refresh the shared HUD (Essence/Tickets/Crystals/army)
## -- the one thing this panel doesn't own.

signal state_changed

var _state: HunterState
var _equipment: Dictionary
var _inventory_view: InventoryView
## Array[Dictionary]: {slot, label, equip_btn, unequip_btn, enhance_btn, browse_btn}
var _rows: Array = []

@onready var sets_label: Label = $SetsLabel


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: visible = false)
	$AutoEquipButton.pressed.connect(_on_auto_equip_pressed)
	_rows = GearPanelHelpers.build_gear_rows($Rows, 180.0)
	for row: Dictionary in _rows:
		var slot: String = row["slot"]
		row["equip_btn"].pressed.connect(_on_equip_best_pressed.bind(slot))
		row["unequip_btn"].pressed.connect(_on_unequip_pressed.bind(slot))
		row["enhance_btn"].pressed.connect(_on_enhance_pressed.bind(slot))
		row["browse_btn"].pressed.connect(_on_browse_pressed.bind(slot))


## Called from main.gd's _start_game() (both the existing-save and
## new-game bootstrap paths) -- state/_equipment aren't ready at _ready().
func bind(state: HunterState, equipment: Dictionary, inventory_view: InventoryView) -> void:
	_state = state
	_equipment = equipment
	_inventory_view = inventory_view
	if not _inventory_view.item_equipped.is_connected(refresh):
		_inventory_view.item_equipped.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	for row: Dictionary in _rows:
		var slot: String = row["slot"]
		var instance_id: String = _state.equipped.get(slot, "")
		row["label"].text = (
			"%s: %s"
			% [
				slot,
				GearPanelHelpers.equipped_item_display(instance_id, _state.inventory, _equipment)
			]
		)
	sets_label.text = GearPanelHelpers.active_sets_display(
		_state.equipped, _state.inventory, _equipment
	)


func _on_equip_best_pressed(slot: String) -> void:
	_state.equip_best_to_hunter(slot, _equipment)
	_after_mutation()


func _on_unequip_pressed(slot: String) -> void:
	_state.unequip_from_hunter(slot)
	_after_mutation()


func _on_browse_pressed(slot: String) -> void:
	_inventory_view.open_for_slot(
		slot, _state.subclass, {"kind": "hunter", "shadow_instance_id": ""}
	)


func _on_auto_equip_pressed() -> void:
	_state.auto_equip_hunter(_equipment)
	_after_mutation()


## No-op if the slot's empty, already maxed, or Essence is short --
## enhance_item() reports which via its bool, but there's no separate
## error UI yet, same placeholder-simplicity as the other gear actions.
func _on_enhance_pressed(slot: String) -> void:
	var instance_id: String = _state.equipped.get(slot, "")
	if instance_id == "":
		return
	_state.enhance_item(instance_id)
	_after_mutation()


func _after_mutation() -> void:
	SaveService.save(_state)
	refresh()
	state_changed.emit()
