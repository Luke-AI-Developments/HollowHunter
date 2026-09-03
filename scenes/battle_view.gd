class_name BattleView
extends Node2D
## Phase 3/step 4 (§16b), rebuilt as a classic-JRPG band layout, driven by
## the same `core/battle.gd` state. Thin view script: owns no game rules,
## just drives a core/battle.gd Battle instance and renders its state into
## six stacked bands (title / arena / turn strip / stage ticker / party row
## / command panel). One BattleView node handles ONE fight at a time
## ("one Battle instance = one fight" per battle.gd's own doc comment) --
## a gate's "up to 3 sequential sub-battles" (trash/trash/boss, §16b) is
## the CALLER's job (step 5) to sequence via repeated start_battle()
## calls, not something this component does internally.
##
## Placeholder-art convention, same as every other screen built this
## project: real portrait art is loaded through ArtPaths where it exists
## and simply falls back to null (name + a drawn HP bar) where it does not.
##
## Invented v0, flagged: ADVANCE_DELAY (pacing between automatically-
## resolved turns so the player can read the ticker before the next one
## fires -- the doc never gives a number, just "no dead air").
## LOG_LINES_SHOWN (how much history stays visible in the ticker).

signal battle_finished(won: bool)

const LOG_LINES_SHOWN := 3
const MAX_ENEMY_SLOTS := 4
const MAX_PARTY_SLOTS := 4
const MAX_ACTION_BUTTONS := 6
const ADVANCE_DELAY := 0.6  ## v0

var _battle: Battle
var _moves: Array = []
var _current_player_moves: Array = []  ## this turn's unlocked moves, matched to action_buttons
var _pending_move: Dictionary = {}  ## a single_enemy move awaiting a target tap, {} if none
var _awaiting_player_input := false  ## set from step()'s own waiting_for_player result --
## NOT inferred, since by the time a refresh runs, the turn queue has already moved past
## whoever just acted (see _advance()).
var _focus_arm := false  ## when true, the next enemy-slot tap sets Focus instead of a move target
var _party_portraits: Dictionary = {}  ## combatant id -> Texture2D, set by start_battle()'s
## caller (which already has the real monster_id per shadow before it's flattened into a
## combatant dict) -- core/battle.gd itself carries no art data, stays pure.
var _log_cursor: int = 0  ## Task 6 ticker roll-in reset point; declared now for class-var stability
var _active_id: String = ""  ## Task 3 active-combatant highlight; declared now

@onready var title_label: Label = $TitleLabel
@onready var arena: Control = $Arena
@onready var turn_strip: HBoxContainer = $TurnStrip
@onready var ticker_label: Label = $Stage/TickerLabel
@onready var banner: Label = $Stage/Banner
@onready var vignette: ColorRect = $Vignette
@onready var party_row: HBoxContainer = $PartyRow
@onready var command: Panel = $Command
@onready var gauge_label: Label = $Command/GaugeLabel
@onready var gauge_bar: StatBar = $Command/GaugeBar
@onready var chain_pill: Label = $Command/ChainPill
@onready var auto_button: Button = $Command/AutoButton
@onready var skip_button: Button = $Command/SkipButton
@onready var waiting_label: Label = $Command/WaitingLabel
@onready var ultimate_button: Button = $Command/UltimateButton
@onready var action_buttons: Array[Button] = [
	$Command/ActionButton1,
	$Command/ActionButton2,
	$Command/ActionButton3,
	$Command/ActionButton4,
	$Command/ActionButton5,
	$Command/ActionButton6,
]
@onready var focus_button: Button = $Command/FocusButton
@onready var defend_button: Button = $Command/DefendButton
@onready var result_label: Label = $ResultLabel
@onready var close_button: Button = $CloseButton
@onready var advance_timer: Timer = $AdvanceTimer


func _ready() -> void:
	for i in action_buttons.size():
		action_buttons[i].pressed.connect(_on_action_button_pressed.bind(i))
	auto_button.toggled.connect(_on_auto_toggled)
	skip_button.pressed.connect(_on_skip_pressed)
	close_button.pressed.connect(_on_close_pressed)
	advance_timer.timeout.connect(_advance)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	focus_button.pressed.connect(_on_focus_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	gauge_bar.set_palette("gauge")


## Starts a fresh fight. `party`/`enemies` are Battle combatant dicts
## (Battle.make_ally_combatant()/make_enemy_combatant()) -- constructing
## those from real HunterState/shadow/monster data is step 5's job.
## `party_portraits` (combatant id -> Texture2D, optional) resolves each
## party slot's icon -- the caller's job, since it's the one that knows
## each shadow's real monster_id before Battle.make_ally_combatant() drops
## it down to just an instance_id.
func start_battle(
	party: Array,
	enemies: Array,
	moves: Array,
	auto: bool = false,
	party_portraits: Dictionary = {},
	initial_gauge: float = 0.0
) -> void:
	_moves = moves
	_party_portraits = party_portraits
	_battle = Battle.new(party, enemies, moves, auto, null, initial_gauge)
	_pending_move = {}
	_focus_arm = false
	_log_cursor = _battle.log.size()
	_active_id = ""
	result_label.visible = false
	close_button.visible = false
	ticker_label.text = ""
	banner.visible = false
	arena.visible = true
	turn_strip.visible = true
	$Stage.visible = true
	party_row.visible = true
	command.visible = true
	vignette.visible = false
	_build_enemy_nodes()
	_build_party_nodes()
	_build_turn_chip_nodes()
	visible = true
	auto_button.button_pressed = auto
	title_label.text = "Battle"
	_advance()


func _advance() -> void:
	if _battle == null or _battle.is_over:
		return
	var result := _battle.step()
	_awaiting_player_input = result.get("waiting_for_player", false)
	_refresh_all()
	if _awaiting_player_input:
		return
	if _battle.is_over:
		_show_results()
		return
	advance_timer.start()


func _refresh_all() -> void:
	_refresh_enemy_slots()
	_refresh_party_slots()
	_refresh_turn_order()
	_refresh_ticker()
	_refresh_action_bar()


## Task-1 placeholder: one column (caption Label + drawn HP StatBar + a
## portrait TextureRect) per enemy, spread across the arena band by simple
## math. Task 2 replaces this with the real enemy band.
func _build_enemy_nodes() -> void:
	for c in arena.get_children():
		c.queue_free()
	var n := _battle.enemies.size()
	for i in n:
		var col := VBoxContainer.new()
		col.name = "E%d" % i
		col.position = Vector2(60 + i * (940.0 / maxi(n, 1)), 40)
		col.custom_minimum_size = Vector2(940.0 / maxi(n, 1) - 20, 0)
		var cap := Label.new()
		cap.name = "cap"
		col.add_child(cap)
		var hp := StatBar.new()
		hp.name = "hp"
		hp.custom_minimum_size = Vector2(160, 14)
		col.add_child(hp)
		var pic := TextureRect.new()
		pic.name = "pic"
		pic.custom_minimum_size = Vector2(0, 200)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.gui_input.connect(_on_enemy_pic_input.bind(i))
		col.add_child(pic)
		arena.add_child(col)


func _refresh_enemy_slots() -> void:
	for i in _battle.enemies.size():
		var e: Dictionary = _battle.enemies[i]
		var col := arena.get_node_or_null("E%d" % i)
		if col == null:
			continue
		var cap: Label = col.get_node("cap")
		var hp: StatBar = col.get_node("hp")
		var pic: TextureRect = col.get_node("pic")
		cap.text = String(e["name"])
		hp.set_values(float(e["hp"]), float(e["max_hp"]))
		pic.texture = ArtPaths.monster_portrait(String(e["id"]))
		pic.modulate = Color(0.4, 0.4, 0.4) if int(e["hp"]) <= 0 else Color.WHITE


## Task-1 placeholder: one column (name / class / drawn HP StatBar / HP
## number) per party member in the party row. Task 4 replaces this.
func _build_party_nodes() -> void:
	for c in party_row.get_children():
		c.queue_free()
	for i in _battle.party.size():
		var col := VBoxContainer.new()
		col.name = "P%d" % i
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Label.new()
		nm.name = "nm"
		col.add_child(nm)
		var cls := Label.new()
		cls.name = "cls"
		col.add_child(cls)
		var hp := StatBar.new()
		hp.name = "hp"
		hp.custom_minimum_size = Vector2(0, 14)
		col.add_child(hp)
		var num := Label.new()
		num.name = "num"
		col.add_child(num)
		party_row.add_child(col)


func _refresh_party_slots() -> void:
	for i in _battle.party.size():
		var c: Dictionary = _battle.party[i]
		var col := party_row.get_node_or_null("P%d" % i)
		if col == null:
			continue
		var nm: Label = col.get_node("nm")
		var cls: Label = col.get_node("cls")
		var hp: StatBar = col.get_node("hp")
		var num: Label = col.get_node("num")
		nm.text = String(c["name"])
		cls.text = String(c["class"])
		hp.set_values(float(c["hp"]), float(c["max_hp"]))
		num.text = "%d / %d" % [int(c["hp"]), int(c["max_hp"])]


## Task-1 placeholder: clears the turn strip; _refresh_turn_order() rebuilds
## the chips each step (turn_queue is dynamic). Task 3 replaces this.
func _build_turn_chip_nodes() -> void:
	for c in turn_strip.get_children():
		turn_strip.remove_child(c)
		c.queue_free()


func _refresh_turn_order() -> void:
	for c in turn_strip.get_children():
		turn_strip.remove_child(c)
		c.queue_free()
	for id: String in _battle.turn_queue:
		var chip := Label.new()
		chip.text = _name_for(id).substr(0, 3)
		turn_strip.add_child(chip)


## Plain last-N event lines, no fade (Task 6 adds the roll-in). Same
## take-last-N-then-drop-empties semantics as the old _refresh_log_label.
func _refresh_ticker() -> void:
	var lines := []
	var start := maxi(0, _battle.log.size() - LOG_LINES_SHOWN)
	for i in range(start, _battle.log.size()):
		var line := _describe_event(_battle.log[i])
		if line != "":
			lines.append(line)
	ticker_label.text = "\n".join(lines)


## Only touches the action bar/waiting label when NOT already mid-target-
## selection (_on_action_button_pressed already set that state and
## _refresh_enemy_slots() handles the tappable-enemy side of it -- this
## would otherwise stomp it every time step() advances something else).
## While it's genuinely the player's turn (_awaiting_player_input, set by
## _advance() from step()'s own result -- not inferred): shows ALL the
## player's unlocked moves, not just currently-usable ones, disabling any
## still on cooldown (§16b: "name + cooldown state"). Otherwise shows a
## generic "Resolving..." placeholder (§16b's "no dead air").
func _refresh_action_bar() -> void:
	ultimate_button.visible = false
	# Gauge readout updates even while resolving / target-picking / under Auto.
	gauge_label.text = "MONARCH GAUGE %d / 100" % int(round(_battle.monarch_gauge))
	gauge_bar.set_values(_battle.monarch_gauge, 100.0)
	chain_pill.visible = _battle.chain_count > 0
	if _battle.chain_count > 0:
		chain_pill.text = "CHAIN x%.1f" % (1.0 + Battle.CHAIN_DAMAGE_STEP * _battle.chain_count)
	var focus_name := _name_for(_battle.focus_target_id) if _battle.focus_target_id != "" else ""
	focus_button.text = (
		"Focus: %s" % focus_name
		if focus_name != ""
		else ("Focus: tap an enemy" if _focus_arm else "Focus: none")
	)
	if not _pending_move.is_empty():
		return

	if not _awaiting_player_input:
		waiting_label.visible = true
		waiting_label.text = "Resolving..."
		for b in action_buttons:
			b.visible = false
		return

	waiting_label.visible = false
	var player: Dictionary = _battle.party[0]
	_current_player_moves = Content.unlocked_moves(
		_moves, String(player["class"]), int(player["level"])
	)
	var cooldowns: Dictionary = player.get("cooldowns", {})
	for i in action_buttons.size():
		var b := action_buttons[i]
		if i >= _current_player_moves.size():
			b.visible = false
			continue
		var move: Dictionary = _current_player_moves[i]
		var cd := int(cooldowns.get(move["id"], 0))
		b.visible = true
		b.disabled = cd > 0
		b.text = "%s%s" % [move["name"], (" (CD %d)" % cd) if cd > 0 else ""]

	var can_ult := _awaiting_player_input and _battle.can_use_ultimate()
	ultimate_button.visible = can_ult
	if can_ult:
		ultimate_button.text = "★ %s ★" % _battle.ultimate_name()


func _name_for(id: String) -> String:
	for c: Dictionary in _battle.party:
		if c["id"] == id:
			return String(c["name"])
	for c: Dictionary in _battle.enemies:
		if c["id"] == id:
			return String(c["name"])
	return id


func _describe_event(e: Dictionary) -> String:
	var actor_name := _name_for(String(e.get("actor_id", "")))
	var target_name := _name_for(String(e.get("target_id", "")))
	var text := ""
	match String(e.get("type", "")):
		"damage":
			var crit_tag := " (CRIT!)" if e.get("crit", false) else ""
			text = "%s hit %s for %d%s" % [actor_name, target_name, e["damage"], crit_tag]
		"enemy_attack":
			var big_tag := " -- BIG HIT!" if e.get("big_hit", false) else ""
			text = "%s attacked %s for %d%s" % [actor_name, target_name, e["damage"], big_tag]
		"heal":
			text = "%s healed %s for %d" % [actor_name, target_name, e["amount"]]
		"lifesteal":
			text = "%s drains %d HP" % [actor_name, e["amount"]]
		"buff":
			text = "%s buffed %s" % [actor_name, target_name]
		"debuff":
			text = "%s weakened %s" % [actor_name, target_name]
		"taunt":
			text = "%s used Taunt!" % actor_name
		"cleanse":
			text = "%s cleansed %s" % [actor_name, target_name]
		"poison_tick":
			text = "%s takes %d poison damage" % [target_name, e["damage"]]
		"pass":
			text = "%s has nothing to do" % actor_name
		"break":
			text = "%s is BROKEN! (x%d)" % [target_name, int(e.get("break_count", 1))]
		"broken_skip":
			text = "%s is staggered and cannot act" % actor_name
		"stunned":
			text = "%s is stunned!" % actor_name
		"ultimate":
			text = "★ %s ★" % String(e.get("name", "Ultimate"))
		"revive":
			text = "%s is revived!" % target_name
		"focus":
			text = (
				"Focus: %s" % target_name
				if String(e.get("target_id", "")) != ""
				else "Focus cleared"
			)
		"defend":
			text = "%s braces" % actor_name
		"regen_tick":
			text = "%s regenerates %d" % [target_name, int(e.get("amount", 0))]
		"phase":
			text = "%s enters PHASE %d!" % [actor_name, int(e.get("phase", 2))]
		"spawn":
			text = "%s spawns an add!" % actor_name
		"undying":
			text = "%s refuses to die -- Death Window!" % actor_name
		"undying_revive":
			text = "%s claws back to life" % actor_name
		"undying_shatter":
			text = "%s shatters!" % actor_name
		"bastion":
			text = "%s raises a Bastion" % actor_name
		"doom":
			text = "%s casts Doom on the party" % actor_name
		"siphon":
			text = "%s siphons %d HP from %s" % [actor_name, int(e.get("amount", 0)), target_name]
		"devour_heal", "leech_heal":
			text = "%s heals %d" % [actor_name, int(e.get("amount", 0))]
	return text


func _on_action_button_pressed(index: int) -> void:
	if index >= _current_player_moves.size():
		return
	var move: Dictionary = _current_player_moves[index]
	if String(move.get("target_type", "")) == "single_enemy":
		_pending_move = move
		_refresh_enemy_slots()
		ultimate_button.visible = false
		waiting_label.visible = true
		waiting_label.text = "Choose a target for %s" % move["name"]
		for b in action_buttons:
			b.visible = false
		return
	_pending_move = {}
	_resolve_and_continue(move["id"], "")


## Fires the party leader's class Ultimate (§6.2). Mirrors
## _resolve_and_continue's post-action flow exactly -- the Ultimate IS the
## turn, so it resolves immediately then paces the following turns the
## same as any other resolved player action.
func _on_ultimate_pressed() -> void:
	if _battle == null or not _awaiting_player_input or not _battle.can_use_ultimate():
		return
	_pending_move = {}
	_battle.resolve_player_ultimate()
	_awaiting_player_input = false
	_refresh_all()
	if _battle.is_over:
		_show_results()
		return
	advance_timer.start()


## Free, no-turn-cost Focus toggle (§7.3 / §11.1). If a Focus target is
## already set, tapping clears it; otherwise it arms the next enemy-slot
## tap to set Focus instead of resolving a move.
func _on_focus_pressed() -> void:
	if _battle == null or _battle.is_over:
		return
	if _battle.focus_target_id != "":
		_battle.clear_focus_target()
		_focus_arm = false
	else:
		if not _pending_move.is_empty():
			return
		_focus_arm = true
	_refresh_all()


## Defend pseudo-move (§11.1): halves incoming damage until this ally's
## next turn. Mirrors _resolve_and_continue's post-action flow exactly.
func _on_defend_pressed() -> void:
	if _battle == null or not _awaiting_player_input:
		return
	_pending_move = {}
	_battle.resolve_player_defend()
	_awaiting_player_input = false
	_refresh_all()
	if _battle.is_over:
		_show_results()
		return
	advance_timer.start()


func _on_enemy_pic_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_on_enemy_slot_pressed(index)


func _on_enemy_slot_pressed(index: int) -> void:
	if _focus_arm:
		_focus_arm = false
		if index < _battle.enemies.size():
			_battle.set_focus_target(String(_battle.enemies[index]["id"]))
		_refresh_all()
		return
	if _pending_move.is_empty() or index >= _battle.enemies.size():
		return
	var target: Dictionary = _battle.enemies[index]
	if int(target["hp"]) <= 0:
		return
	var move_id: String = _pending_move["id"]
	_pending_move = {}
	_resolve_and_continue(move_id, target["id"])


## Resolves the player's chosen move immediately (so the log/HP bars
## update right away instead of waiting for the next auto-advance tick),
## then paces the following turn(s) the same as any auto-resolved one.
func _resolve_and_continue(move_id: String, target_id: String) -> void:
	_battle.resolve_player_action(move_id, target_id)
	_awaiting_player_input = false
	_refresh_all()
	if _battle.is_over:
		_show_results()
		return
	advance_timer.start()


func _on_auto_toggled(pressed: bool) -> void:
	_battle.auto_battle = pressed
	auto_button.text = "Auto-battle: ON" if pressed else "Auto-battle: OFF"
	if not pressed or _battle.is_over:
		return
	_pending_move = {}
	if _awaiting_player_input:
		# The player's turn was already popped off the queue when step()
		# first paused on it -- resolve THAT pending turn via AI instead
		# of calling step() again, which would skip it entirely.
		_battle.resolve_pending_player_turn_via_ai()
		_awaiting_player_input = false
		_refresh_all()
		if _battle.is_over:
			_show_results()
			return
	advance_timer.start()


func _on_skip_pressed() -> void:
	if _battle == null or _battle.is_over:
		return
	_battle.auto_battle = true
	_battle.run_to_completion()
	_refresh_all()
	_show_results()


## Hides every mid-battle band (arena, turn strip, stage, party row,
## command panel, vignette) so result_label/close_button -- which occupy
## the same screen space -- aren't drawn over still-visible combat UI.
func _show_results() -> void:
	arena.visible = false
	turn_strip.visible = false
	$Stage.visible = false
	party_row.visible = false
	command.visible = false
	vignette.visible = false
	_focus_arm = false
	result_label.visible = true
	result_label.text = "VICTORY!" if _battle.won else "DEFEAT"
	close_button.visible = true


func _on_close_pressed() -> void:
	visible = false
	battle_finished.emit(_battle.won)


## The live Monarch Gauge value -- main.gd reads this when a Nadir floor
## fight finishes so the next floor's Battle can be seeded with it
## (spec §6.1: the gauge persists across a gate/Nadir run's sub-battles).
func battle_monarch_gauge() -> float:
	return _battle.monarch_gauge if _battle != null else 0.0


## Instance-ids of fielded SHADOWS that ended the just-finished fight at 0 HP
## -- main.gd carries these across a run so they stay unfielded (spec §9.1).
func downed_shadow_instance_ids() -> Array:
	var out := []
	if _battle == null:
		return out
	for c: Dictionary in _battle.party:
		if String(c.get("id", "")) != "player" and int(c.get("hp", 0)) <= 0:
			out.append(String(c["id"]))
	return out


## Whether the hunter (party slot 0) ended the just-finished fight at 0 HP.
## The hunter never "stays down" -- main.gd instead returns it at 30% HP
## in the next sub-battle (spec §9.1).
func hunter_was_downed() -> bool:
	if _battle == null or _battle.party.is_empty():
		return false
	return int(_battle.party[0].get("hp", 0)) <= 0
