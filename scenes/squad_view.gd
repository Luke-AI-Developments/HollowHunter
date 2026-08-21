class_name SquadView
extends Node2D
## Phase 3/step 6: the Squad panel (§17's "tweak by hand" 3-of-6 picker) as
## its own thin view script -- split out of scenes/main.gd purely to stay
## under the project's max-file-lines lint limit, same reasoning
## battle_view.gd was split out for the battle screen. Owns display + input
## forwarding only; SquadBuilder/HunterState still own the actual rules --
## main.gd calls refresh() with data it already computed and reacts to this
## script's signals rather than mutating state here.

signal toggle_requested(instance_id: String)
signal auto_fill_requested
signal auto_equip_squad_requested
signal close_requested

var _rows: Array = []  ## Array[Dictionary]: {label, toggle_btn, instance_id} -- one per
## squad-of-6 slot (GameLogic.SQUAD_SIZE), positional not shadow-bound; instance_id is
## refreshed every refresh() call since who occupies a slot can change (army growth/leveling)

@onready var info_label: Label = $InfoLabel
@onready var rows_container: Node2D = $Rows


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: close_requested.emit())
	$AutoFillButton.pressed.connect(func() -> void: auto_fill_requested.emit())
	$AutoEquipSquadButton.pressed.connect(func() -> void: auto_equip_squad_requested.emit())
	_rows = _build_rows(rows_container, 230.0)


## Builds GameLogic.SQUAD_SIZE (6) fixed row slots (label + a Field/Unfield
## toggle button) under `parent`, stacked from `y_start`. Placeholder art,
## same text-only convention as the rest of this project.
func _build_rows(parent: Node2D, y_start: float) -> Array:
	var rows := []
	var y := y_start
	for i in GameLogic.SQUAD_SIZE:
		var row_label := Label.new()
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(760, 40)
		row_label.add_theme_font_size_override("font_size", 20)
		parent.add_child(row_label)

		var toggle_btn := Button.new()
		toggle_btn.position = Vector2(800, y)
		toggle_btn.size = Vector2(220, 40)
		toggle_btn.text = "Field"
		parent.add_child(toggle_btn)
		toggle_btn.pressed.connect(_on_row_toggle_pressed.bind(i))

		rows.append({"label": row_label, "toggle_btn": toggle_btn, "instance_id": ""})
		y += 90
	return rows


## `row_index` is the fixed row slot the button belongs to (bound at build
## time) -- looked up against that row's CURRENT occupant, set fresh every
## refresh() call.
func _on_row_toggle_pressed(row_index: int) -> void:
	if row_index >= _rows.size():
		return
	var instance_id: String = _rows[row_index]["instance_id"]
	if instance_id != "":
		toggle_requested.emit(instance_id)


## `squad` is the class-slotted squad-of-6 (SquadBuilder.auto_fill_squad),
## `active_party_ids` is the player's manual pick (HunterState, in pick
## order), `resolved_party` is what will ACTUALLY fight (SquadBuilder.
## resolve_party) -- shown separately so a partial manual pick (auto-
## backfilled the rest) still reads clearly.
func refresh(squad: Array, active_party_ids: Array, resolved_party: Array) -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if i < squad.size():
			var member: Dictionary = squad[i]
			row["instance_id"] = member["instance_id"]
			var fielded := active_party_ids.has(member["instance_id"])
			row["label"].text = (
				"%s (%s·%s Lv%d) pwr:%d"
				% [
					member["monster_name"],
					member["grade_name"],
					member["grade"],
					member["level"],
					member["power"],
				]
			)
			row["toggle_btn"].text = "Fielded [x]" if fielded else "Field"
			row["toggle_btn"].disabled = false
		else:
			row["instance_id"] = ""
			row["label"].text = "-- empty squad slot --"
			row["toggle_btn"].text = "Field"
			row["toggle_btn"].disabled = true

	var chosen_names: Array = resolved_party.map(
		func(m: Dictionary) -> String: return String(m["monster_name"])
	)
	var manual_note := "" if active_party_ids.is_empty() else " (manual)"
	info_label.text = (
		"Party: %d/3 chosen%s -- fielded: %s"
		% [active_party_ids.size(), manual_note, ", ".join(chosen_names)]
	)
