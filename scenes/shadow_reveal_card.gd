class_name ShadowRevealCard
extends Node2D
## §6b/§6c: near-fullscreen shadow reveal + detail card (layout C). Thin
## view -- no game rules. Reads HunterState, calls existing mutators
## (set_shadow_nickname, convert_shadow), emits signals for main.gd /
## army_view.gd to route navigation.

signal closed
signal manage_gear_requested(instance_id: String)
signal state_changed

enum Mode { CLAIM, DETAIL }

const _RARITY_COLOR := {
	"common": Color(0.62, 0.70, 0.72),
	"uncommon": Color(0.37, 0.84, 0.64),
	"rare": Color(0.36, 0.70, 1.0),
	"epic": Color(0.75, 0.55, 1.0),
	"legendary": Color(1.0, 0.81, 0.36),
}
const _NEGATIVE_COLOR := Color(1.0, 0.48, 0.42)

var _state: HunterState
var _monsters: Array = []
var _equipment: Dictionary = {}
var _trait_pool: Array = []
var _mode: int = Mode.CLAIM
var _instance_id: String = ""

@onready var _card: Panel = $Card
@onready var _portrait: TextureRect = $Card/Portrait
@onready var _flash: ColorRect = $Card/FlashRect
@onready var _species_label: Label = $Card/Content/SpeciesLabel
@onready var _nick_label: Label = $Card/Content/NickLabel
@onready var _grade_chip: Label = $Card/Content/ChipRow/GradeChip
@onready var _class_chip: Label = $Card/Content/ChipRow/ClassChip
@onready var _family_chip: Label = $Card/Content/ChipRow/FamilyChip
@onready var _level_stat: Label = $Card/Content/StatsRow/LevelStat
@onready var _power_stat: Label = $Card/Content/StatsRow/PowerStat
@onready var _gear_stat: Label = $Card/Content/StatsRow/GearStat
@onready var _nick_input: LineEdit = $Card/Content/NameRow/NicknameInput
@onready var _nick_save: Button = $Card/Content/NameRow/NicknameSaveButton
@onready var _nick_skip: Button = $Card/Content/NameRow/NicknameSkipButton
@onready var _traits_list: VBoxContainer = $Card/Content/TraitsList
@onready var _close_button: Button = $Card/ActionBar/CloseButton
@onready var _primary: Button = $Card/ActionBar/PrimaryButton
@onready var _relinquish: Button = $Card/ActionBar/RelinquishButton
@onready var _confirm_bar: PanelContainer = $Card/ConfirmBar
@onready var _confirm_label: Label = $Card/ConfirmBar/VBox/ConfirmLabel
@onready var _confirm_cancel: Button = $Card/ConfirmBar/VBox/ConfirmButtons/ConfirmCancelButton
@onready var _confirm_ok: Button = $Card/ConfirmBar/VBox/ConfirmButtons/ConfirmRelinquishButton


func _ready() -> void:
	_close_button.pressed.connect(_dismiss)
	_nick_save.pressed.connect(_on_nick_save_pressed)
	_nick_skip.pressed.connect(_on_nick_skip_pressed)
	_primary.pressed.connect(_on_primary_pressed)
	_relinquish.pressed.connect(_on_relinquish_pressed)
	_confirm_cancel.pressed.connect(func() -> void: _confirm_bar.visible = false)
	_confirm_ok.pressed.connect(_on_confirm_relinquish_pressed)


func bind(state: HunterState, monsters: Array, equipment: Dictionary, trait_pool: Array) -> void:
	_state = state
	_monsters = monsters
	_equipment = equipment
	_trait_pool = trait_pool


func show_for(instance_id: String, mode: int) -> void:
	_instance_id = instance_id
	_mode = mode
	_confirm_bar.visible = false
	_nick_input.editable = true

	var enriched := SquadBuilder.enrich_army(
		_state.army, _monsters, _state.level, _equipment, _state.inventory, _trait_pool
	)
	var e := {}
	for row: Dictionary in enriched:
		if row["instance_id"] == instance_id:
			e = row
			break
	if e.is_empty():
		return

	_species_label.text = String(e["monster_name"])
	var nickname := String(e["nickname"])
	_nick_label.text = (
		"“%s” · %s" % [nickname, e["monster_name"]] if nickname != "" else "no nickname yet"
	)
	_grade_chip.text = "%s · %s" % [e["grade_name"], e["grade"]]
	_class_chip.text = String(e["clazz"]).capitalize()
	_family_chip.text = String(e["family"])
	_family_chip.visible = String(e["family"]) != ""
	_level_stat.text = "Lv %d" % int(e["level"])
	_power_stat.text = "Power %s" % _grouped(int(e["power"]))
	_gear_stat.text = "Gear %d/7" % _equipped_count(instance_id)

	_populate_traits(e["traits"])

	var monster_id := String(e["monster_id"])
	var tex_path := "res://art/monsters/por_%s.webp" % monster_id
	if ResourceLoader.exists(tex_path):
		_portrait.texture = load(tex_path)
		_portrait.visible = true
	else:
		_portrait.visible = false

	var grade := String(e["grade"])
	_relinquish.text = "Relinquish · +%d" % GameLogic.essence_for_converted_shadow(grade)
	_relinquish.visible = not bool(e["locked"])

	_close_button.visible = _mode == Mode.DETAIL
	if _mode == Mode.CLAIM:
		_nick_input.text = ""
		_nick_skip.visible = true
		_primary.text = "Add to Army"
	else:
		_nick_input.text = nickname
		_nick_skip.visible = false
		_primary.text = "Manage Gear"

	visible = true
	if _mode == Mode.CLAIM:
		_play_glitch_in()
	else:
		_card.modulate.a = 1.0
		_flash.color.a = 0.0


func _populate_traits(traits: Array) -> void:
	for child in _traits_list.get_children():
		child.queue_free()
	for t: Dictionary in traits:
		var row := Label.new()
		var is_neg := String(t["polarity"]) == "negative"
		var color: Color = (
			_NEGATIVE_COLOR if is_neg else _RARITY_COLOR.get(t["rarity"], Color.WHITE)
		)
		row.text = (
			"%s  (%s)  —  %s" % [t["name"], String(t["rarity"]).capitalize(), t["effect_text"]]
		)
		row.add_theme_color_override("font_color", color)
		_traits_list.add_child(row)


func _equipped_count(instance_id: String) -> int:
	var idx := _state.army.find_custom(
		func(s: Dictionary) -> bool: return s.get("instance_id", "") == instance_id
	)
	if idx < 0:
		return 0
	var eq: Dictionary = _state.army[idx].get("equipped", {})
	var n := 0
	for v in eq.values():
		if String(v) != "":
			n += 1
	return n


func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _play_glitch_in() -> void:
	_card.modulate.a = 0.0
	_flash.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_flash, "color:a", 0.0, 0.5)
	var base_x := _card.position.x
	for offset in [10.0, -8.0, 5.0, -3.0, 0.0]:
		tw.tween_property(_card, "position:x", base_x + offset, 0.06)
	tw.tween_property(_card, "position:x", base_x, 0.04)


func _on_nick_save_pressed() -> void:
	if _state.set_shadow_nickname(_instance_id, _nick_input.text):
		state_changed.emit()
		# refresh the nick line in place
		var nm := _nick_input.text.strip_edges()
		_nick_label.text = (
			"“%s” · %s" % [nm, _species_label.text] if nm != "" else "no nickname yet"
		)
		if _mode == Mode.CLAIM:
			_nick_input.editable = false


func _on_nick_skip_pressed() -> void:
	_nick_input.text = ""
	_nick_input.editable = false


func _on_relinquish_pressed() -> void:
	_confirm_label.text = (
		"Relinquish %s? Released for +%d Essence. Its traits and level are lost — this can't be undone."
		% [_species_label.text, GameLogic.essence_for_converted_shadow(_grade_of(_instance_id))]
	)
	_confirm_bar.visible = true


func _on_confirm_relinquish_pressed() -> void:
	_confirm_bar.visible = false
	if _state.convert_shadow(_instance_id):
		state_changed.emit()
	_dismiss()


func _on_primary_pressed() -> void:
	if _mode == Mode.DETAIL:
		manage_gear_requested.emit(_instance_id)
	_dismiss()


func _grade_of(instance_id: String) -> String:
	var idx := _state.army.find_custom(
		func(s: Dictionary) -> bool: return s.get("instance_id", "") == instance_id
	)
	return String(_state.army[idx].get("grade", "")) if idx >= 0 else ""


func _dismiss() -> void:
	visible = false
	closed.emit()
