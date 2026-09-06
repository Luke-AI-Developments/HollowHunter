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
signal suggest_requested  ## §17 forced roles: fill a valid role comp from the owned army
signal sort_changed(mode: String)
signal close_requested

## §17 forced role composition role-status line glyphs + colours (v0):
## a covered role reads green with a check, a missing one amber with a cross.
const ROLE_OK_GLYPH := "✓"
const ROLE_MISSING_GLYPH := "✗"
const ROLE_OK_COLOR := Color("5fd6a4")  ## v0 green
const ROLE_MISSING_COLOR := Color("ffcf5c")  ## v0 amber

var _sort_mode: String = "power"

@onready var info_label: Label = $InfoLabel
@onready var role_status_label: Label = $RoleStatusLabel
@onready var sort_button: Button = $SortButton
@onready var rows_container: VBoxContainer = $RowsScroll/Rows


func _ready() -> void:
	# Touch: let a near-stationary tap reach a row's Field button instead of being
	# captured as a scroll drag (ScrollContainer's default deadzone 0 eats taps).
	($RowsScroll as ScrollContainer).scroll_deadzone = 12
	$CloseButton.pressed.connect(func() -> void: close_requested.emit())
	$AutoEquipSquadButton.pressed.connect(func() -> void: auto_equip_requested.emit())
	$SuggestButton.pressed.connect(func() -> void: suggest_requested.emit())
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
## pick (HunterState, in pick order). `role_status` is
## SquadBuilder.party_role_status(resolve_party(...), subclass) -- computed
## by army_view.gd, which owns state -- and drives the role-status line.
## Rebuilds every row from scratch -- the list changes rarely enough
## (claim/level/fuse/convert) that rebuild-on-refresh is simpler and cheap.
func refresh(sorted_army: Array, active_party_ids: Array, role_status: Dictionary) -> void:
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
		# Touch: PASS (not the Button default STOP) so a drag begun on this
		# button still reaches RowsScroll instead of being swallowed -- the row
		# label is already MOUSE_FILTER_IGNORE, this closes the last dead strip.
		toggle.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_refresh_role_status(role_status)


## §17 forced role composition: "Tank <glyph>  Support <glyph>  Attacker
## <glyph>" from `role_status` ({"covered": Array, "missing": Array,
## "valid": bool}). Whole line is green while the comp is valid, amber the
## moment a role is missing.
func _refresh_role_status(role_status: Dictionary) -> void:
	var covered: Array = role_status.get("covered", [])
	role_status_label.text = (
		"Tank %s   Support %s   Attacker %s"
		% [
			_role_glyph(covered, "tank"),
			_role_glyph(covered, "support"),
			_role_glyph(covered, "attacker"),
		]
	)
	var ok := bool(role_status.get("valid", false))
	role_status_label.add_theme_color_override(
		"font_color", ROLE_OK_COLOR if ok else ROLE_MISSING_COLOR
	)


func _role_glyph(covered: Array, role: String) -> String:
	return ROLE_OK_GLYPH if covered.has(role) else ROLE_MISSING_GLYPH


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
