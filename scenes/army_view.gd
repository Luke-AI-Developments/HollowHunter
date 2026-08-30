class_name ArmyView
extends Node2D
## §17: the Army management screen. Roster tab (§9b Layout C: a pinned
## fielded strip of up to 3 big shadow cards, then a scrolling 3-column
## bench grid of the rest, grade-filtered and sortable) and Party tab (party_view.gd:
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

## §9b Layout-C grade ramp -- the mock's `--g-*` swatches, used for the
## per-card meta line colour so grade reads at a glance in the grid.
const GRADE_COLOR := {
	"E": Color("9fb2b8"),
	"D": Color("5fd6a4"),
	"C": Color("5db4ff"),
	"B": Color("c08bff"),
	"A": Color("ffcf5c"),
	"S": Color("ff7b6b"),
}
const CARD_BIG := Vector2(300, 250)
const CARD_SMALL := Vector2(333, 150)

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _shadow_gear_view: ShadowGearView
var _shadow_reveal_card: ShadowRevealCard
var _awaiting_reveal_close: bool = false
var _grade_filter: String = "ALL"
var _sort_mode: String = "power"
var _party_sort_mode: String = "power"  ## Party tab's own sort cycle (PartyView.sort_changed)

@onready var roster_tab: Node2D = $RosterTab
@onready var party_tab: PartyView = $SquadTab
@onready var field_strip_heading: Label = $RosterTab/FieldStrip/Heading
@onready var field_strip_cards: HBoxContainer = $RosterTab/FieldStrip/Cards
@onready var bench_title: Label = $RosterTab/BenchHeader/Title
@onready var grade_filter_button: Button = $RosterTab/BenchHeader/GradeFilterButton
@onready var sort_button: Button = $RosterTab/BenchHeader/SortButton
@onready var bench_grid: GridContainer = $RosterTab/BenchScroll/BenchGrid
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


## §9b Layout C: a pinned "fielded strip" of up to PARTY_SIZE big shadow
## cards (active_party_ids in pick order, padded with dim placeholders when
## understrength), then a scrolling 3-column "bench grid" of every other
## owned shadow, grade-filtered and sorted by the bench header's buttons.
## Class grouping is gone. Each real card is a Button routing to the shadow
## detail hub, same as the old roster rows. Rebuilds from scratch each call.
func _refresh_roster() -> void:
	for c in field_strip_cards.get_children():
		c.queue_free()
	for c in bench_grid.get_children():
		c.queue_free()

	var enriched := SquadBuilder.enrich_army(
		_state.army, _monsters, _state.level, _equipment, _state.inventory
	)
	var fielded_ids := {}
	for id in _state.active_party_ids:
		fielded_ids[id] = true

	# --- fielded strip: active_party_ids in pick order, padded to PARTY_SIZE ---
	var by_id := {}
	for e: Dictionary in enriched:
		by_id[e["instance_id"]] = e
	var fielded_count := 0
	for id in _state.active_party_ids:
		if by_id.has(id):
			field_strip_cards.add_child(_make_shadow_card(by_id[id], true, true))
			fielded_count += 1
	for _i in range(GameLogic.PARTY_SIZE - fielded_count):
		field_strip_cards.add_child(_make_empty_slot_card())
	field_strip_heading.text = (
		"YOUR PARTY -- %d / %d fielded" % [fielded_count, GameLogic.PARTY_SIZE]
	)

	# --- bench: everything not fielded, grade-filtered, sorted ---
	var bench: Array = enriched.filter(
		func(e: Dictionary) -> bool: return not fielded_ids.has(e["instance_id"])
	)
	if _grade_filter != "ALL":
		bench = bench.filter(func(e: Dictionary) -> bool: return e["grade"] == _grade_filter)
	bench.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if _sort_mode == "power":
				return a["power"] > b["power"]
			return GameLogic.RANK_ORDER.find(b["grade"]) < GameLogic.RANK_ORDER.find(a["grade"])
	)
	for e: Dictionary in bench:
		bench_grid.add_child(_make_shadow_card(e, false, false))
	bench_title.text = "BENCH (%d)" % bench.size()


## Builds one shadow card: shader-recoloured portrait, name and a
## "grade_name·grade  Lv N  ·  power" meta line coloured by grade, plus
## P/L/F pips. The whole card is a Button routing to the detail card,
## same as the old roster rows. `big` toggles the fielded-strip size.
func _make_shadow_card(e: Dictionary, fielded: bool, big: bool) -> Control:
	var card := Button.new()
	card.custom_minimum_size = CARD_BIG if big else CARD_SMALL
	card.clip_contents = true
	card.pressed.connect(_on_shadow_row_pressed.bind(e["instance_id"]))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, (150 if big else 92))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := ArtPaths.monster_portrait(e["monster_id"])
	if tex != null:
		portrait.texture = tex
		portrait.material = ArtPaths.shadow_material()
	box.add_child(portrait)

	var name_label := Label.new()
	name_label.text = String(e["display_name"])
	name_label.add_theme_font_size_override("font_size", 18 if big else 14)
	box.add_child(name_label)

	var meta := Label.new()
	meta.text = (
		"%s·%s  Lv %d  ·  %s"
		% [e["grade_name"], e["grade"], int(e["level"]), _grouped(int(e["power"]))]
	)
	meta.add_theme_font_size_override("font_size", 13 if big else 11)
	meta.add_theme_color_override("font_color", GRADE_COLOR.get(String(e["grade"]), Color.WHITE))
	box.add_child(meta)

	var markers := PackedStringArray()
	if fielded:
		markers.append("P")
	if bool(e["locked"]):
		markers.append("L")
	if bool(e["favorite"]):
		markers.append("F")
	if not markers.is_empty():
		var pips := Label.new()
		pips.text = " ".join(markers)
		pips.add_theme_font_size_override("font_size", 12)
		box.add_child(pips)

	return card


## A dim placeholder filling an unused party slot in the fielded strip
## (early game / understrength party). Not tappable.
func _make_empty_slot_card() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = CARD_BIG
	slot.modulate = Color(1, 1, 1, 0.28)
	var l := Label.new()
	l.text = "empty slot"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(l)
	return slot


## Thousands-separated integer for card power text -- mirrors
## shadow_reveal_card.gd._grouped so the two shadow surfaces read alike.
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
