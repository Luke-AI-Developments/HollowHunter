class_name PartyView
extends Node2D
## §17: the Party panel -- the manual "pick who fights" screen. Lists the
## WHOLE owned army (one row per shadow), lets the player cycle a sort
## order (power/level/rank/role) and field up to 3 of them. Split out of
## scenes/main.gd purely to stay under the project's max-file-lines lint
## limit, same reasoning battle_view.gd was split out for the battle
## screen. Owns display + input forwarding only; SquadBuilder/HunterState
## still own the actual rules -- army_view.gd calls refresh() with data it
## already sorted and reacts to this script's signals rather than mutating
## state here.

signal toggle_requested(instance_id: String)
signal auto_equip_requested  ## equips gear onto the currently-fielded party
signal sort_changed(mode: String)
signal close_requested

var _sort_mode: String = "power"

@onready var info_label: Label = $InfoLabel
@onready var sort_button: Button = $SortButton
@onready var rows_container: VBoxContainer = $RowsScroll/Rows


func _ready() -> void:
	# Touch: let a near-stationary tap reach a row's Field button instead of being
	# captured as a scroll drag (ScrollContainer's default deadzone 0 eats taps).
	($RowsScroll as ScrollContainer).scroll_deadzone = 12
	$CloseButton.pressed.connect(func() -> void: close_requested.emit())
	$AutoEquipSquadButton.pressed.connect(func() -> void: auto_equip_requested.emit())
	$SortButton.pressed.connect(_on_sort_pressed)


## Cycles the sort order through power -> level -> rank -> role -> power and
## asks army_view.gd to re-sort + re-refresh (this view never sorts itself).
func _on_sort_pressed() -> void:
	var modes := ["power", "level", "rank", "role"]
	var idx := modes.find(_sort_mode)
	_sort_mode = modes[(idx + 1) % modes.size()]
	sort_button.text = "Sort: %s" % _sort_mode.capitalize()
	sort_changed.emit(_sort_mode)


## `sorted_army` is the whole owned army (SquadBuilder.enrich_army then
## SquadBuilder.sort_shadows), `active_party_ids` is the player's manual
## pick (HunterState, in pick order). Rebuilds every row from scratch --
## the list changes rarely enough (claim/level/fuse/convert) that
## rebuild-on-refresh is simpler and cheap.
func refresh(sorted_army: Array, active_party_ids: Array) -> void:
	for c in rows_container.get_children():
		rows_container.remove_child(c)
		c.queue_free()

	var party_full := active_party_ids.size() >= GameLogic.PARTY_SIZE
	for e: Dictionary in sorted_army:
		var instance_id: String = e["instance_id"]
		var fielded := active_party_ids.has(instance_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size = Vector2(0, 44)

		var row_label := Label.new()
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.text = (
			"%s (%s·%s Lv%d) pwr:%d"
			% [
				e["display_name"],
				e["grade_name"],
				e["grade"],
				e["level"],
				e["power"],
			]
		)
		row.add_child(row_label)

		var toggle := Button.new()
		toggle.text = "Fielded [x]" if fielded else "Field"
		toggle.disabled = party_full and not fielded
		toggle.pressed.connect(func() -> void: toggle_requested.emit(instance_id))
		row.add_child(toggle)

		rows_container.add_child(row)

	info_label.text = (
		"Party: %d/%d fielded -- %s"
		% [
			active_party_ids.size(),
			GameLogic.PARTY_SIZE,
			", ".join(_fielded_names(sorted_army, active_party_ids)),
		]
	)


## Maps each id in `active_party_ids` (pick order) to its display_name from
## `sorted_army`; silently skips ids with no match.
func _fielded_names(sorted_army: Array, active_party_ids: Array) -> Array:
	var by_id := {}
	for e: Dictionary in sorted_army:
		by_id[e["instance_id"]] = e["display_name"]
	var names := []
	for id: String in active_party_ids:
		if by_id.has(id):
			names.append(String(by_id[id]))
	return names
