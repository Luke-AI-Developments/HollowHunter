class_name BattleView
extends Node2D
## Phase 3/step 4: the battle screen (§16b) -- the shared UI every fight
## (gates, gate-breaks, Nadir floors) plays out on. Thin view script: owns
## no game rules, just drives a core/battle.gd Battle instance and
## renders its state. One BattleView node handles ONE fight at a time
## ("one Battle instance = one fight" per battle.gd's own doc comment) --
## a gate's "up to 3 sequential sub-battles" (trash/trash/boss, §16b) is
## the CALLER's job (step 5) to sequence via repeated start_battle()
## calls, not something this component does internally.
##
## Placeholder-art convention, same as every other screen built this
## project: §16b assumes real portrait art ("existing preset-hunter
## portraits and monster portraits... work directly as static battle-HUD
## icons"), but this project has shipped zero art all session by design
## (placeholder shapes + text only) -- so "portraits" here are just
## Buttons/Labels showing name + a text HP bar (`[======----] 45/72`,
## the same ASCII-bar convention the Character screen already
## established), not sprites. A real art pass can swap these buttons'
## icons in later without touching any of this logic.
##
## Invented v0, flagged: ADVANCE_DELAY_SECONDS (pacing between
## automatically-resolved turns so the player can actually read the log/
## toast before the next one fires -- the doc never gives a number,
## just "no dead air"). LOG_LINES_SHOWN (how much history stays visible).

signal battle_finished(won: bool)

const LOG_LINES_SHOWN := 6
const MAX_ENEMY_SLOTS := 4
const MAX_PARTY_SLOTS := 4
const MAX_ACTION_BUTTONS := 5

var _battle: Battle
var _moves: Array = []
var _current_player_moves: Array = []  ## this turn's unlocked moves, matched to action_buttons
var _pending_move: Dictionary = {}  ## a single_enemy move awaiting a target tap, {} if none
var _awaiting_player_input := false  ## set from step()'s own waiting_for_player result --
## NOT inferred, since by the time a refresh runs, the turn queue has already moved past
## whoever just acted (see _advance()).
var _party_portraits: Dictionary = {}  ## combatant id -> Texture2D, set by start_battle()'s
## caller (which already has the real monster_id per shadow before it's flattened into a
## combatant dict) -- core/battle.gd itself carries no art data, stays pure. "player" has no
## entry (no preset-selection feature exists yet to pick a hunter portrait from), so the
## icon is null for that slot -- same "load if it exists" fallback ArtPaths uses everywhere.

@onready var title_label: Label = $TitleLabel
@onready var enemy_slots: Array[Button] = [$EnemySlot1, $EnemySlot2, $EnemySlot3, $EnemySlot4]
@onready var turn_order_label: Label = $TurnOrderLabel
@onready var log_label: Label = $LogLabel
@onready var party_slots: Array[Button] = [$PartySlot1, $PartySlot2, $PartySlot3, $PartySlot4]
@onready var waiting_label: Label = $WaitingLabel
@onready var action_buttons: Array[Button] = [
	$ActionButton1, $ActionButton2, $ActionButton3, $ActionButton4, $ActionButton5
]
@onready var auto_button: Button = $AutoButton
@onready var skip_button: Button = $SkipButton
@onready var result_label: Label = $ResultLabel
@onready var close_button: Button = $CloseButton
@onready var advance_timer: Timer = $AdvanceTimer
@onready var ultimate_button: Button = $UltimateButton
@onready var gauge_label: Label = $GaugeLabel


func _ready() -> void:
	for i in enemy_slots.size():
		enemy_slots[i].pressed.connect(_on_enemy_slot_pressed.bind(i))
	for i in action_buttons.size():
		action_buttons[i].pressed.connect(_on_action_button_pressed.bind(i))
	auto_button.toggled.connect(_on_auto_toggled)
	skip_button.pressed.connect(_on_skip_pressed)
	close_button.pressed.connect(_on_close_pressed)
	advance_timer.timeout.connect(_advance)
	ultimate_button.pressed.connect(_on_ultimate_pressed)


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
	result_label.visible = false
	close_button.visible = false
	visible = true
	auto_button.button_pressed = auto
	auto_button.text = "Auto-battle: ON" if auto else "Auto-battle: OFF"
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
	_refresh_turn_order_label()
	_refresh_log_label()
	_refresh_action_bar()


func _refresh_enemy_slots() -> void:
	var targeting := not _pending_move.is_empty()
	for i in enemy_slots.size():
		var slot := enemy_slots[i]
		if i >= _battle.enemies.size():
			slot.visible = false
			continue
		var e: Dictionary = _battle.enemies[i]
		slot.visible = true
		# `id` is a real monster_id for gate enemies (e.g. "mon_grubmaw") but a
		# synthetic "nadir_floor_N" for Nadir floors, which has no matching art --
		# ArtPaths falls back to null (no icon) for those, same placeholder-first
		# convention as everywhere else.
		slot.icon = ArtPaths.monster_portrait(String(e["id"]))
		slot.expand_icon = true
		if int(e["hp"]) <= 0:
			slot.text = "%s\n[DEFEATED]" % e["name"]
			slot.disabled = true
			continue
		var telegraph := "\n⚠ BIG HIT NEXT" if _battle.is_boss_next_hit_big(e["id"]) else ""
		var brk := ""
		if e.get("is_boss", false) and e.has("break_max"):
			var bf := int(round(_battle.break_fraction(e["id"]) * 100.0))
			brk = "\nBREAK %d%%%s" % [bf, " [BROKEN]" if _battle.is_broken(e["id"]) else ""]
		slot.text = "%s\nHP: %s%s%s" % [e["name"], _hp_bar(e), telegraph, brk]
		slot.disabled = not targeting


func _refresh_party_slots() -> void:
	for i in party_slots.size():
		var slot := party_slots[i]
		if i >= _battle.party.size():
			slot.visible = false
			continue
		var c: Dictionary = _battle.party[i]
		slot.visible = true
		slot.icon = _party_portraits.get(c["id"], null)
		slot.expand_icon = true
		var status := ""
		if int(c["hp"]) <= 0:
			status = "\n[DOWN]"
		elif bool(c.get("is_taunting", false)):
			status = "\n[TAUNTING]"
		slot.text = "%s (%s)\nHP: %s%s" % [c["name"], c["class"], _hp_bar(c), status]


func _refresh_turn_order_label() -> void:
	var names := []
	for id: String in _battle.turn_queue:
		names.append(_name_for(id))
	turn_order_label.text = (
		"Turn order: %s" % (" -> ".join(names) if not names.is_empty() else "--")
	)


func _refresh_log_label() -> void:
	var lines := []
	var start := maxi(0, _battle.log.size() - LOG_LINES_SHOWN)
	for i in range(start, _battle.log.size()):
		lines.append(_describe_event(_battle.log[i]))
	log_label.text = "\n".join(lines)


## Only touches the action bar/waiting label when NOT already mid-target-
## selection (_on_action_button_pressed already set that state and
## _refresh_enemy_slots() handles the tappable-enemy side of it -- this
## would otherwise stomp it every time step() advances something else).
## While it's genuinely the player's turn (_awaiting_player_input, set by
## _advance() from step()'s own result -- not inferred): shows ALL the
## player's unlocked moves, not just currently-usable ones, disabling any
## still on cooldown (§16b: "name + cooldown state"). Otherwise shows a
## generic "Resolving..." placeholder (§16b's "no dead air") -- not naming
## who's acting, since by the time a refresh runs the turn queue has
## already moved past them.
func _refresh_action_bar() -> void:
	ultimate_button.visible = false
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

	gauge_label.text = "Monarch Gauge: %d / 100" % int(round(_battle.monarch_gauge))
	var can_ult := _awaiting_player_input and _battle.can_use_ultimate()
	ultimate_button.visible = can_ult
	if can_ult:
		ultimate_button.text = "★ %s ★" % _battle.ultimate_name()


func _hp_bar(c: Dictionary) -> String:
	var hp: int = c["hp"]
	var max_hp: int = c["max_hp"]
	var pct := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	var filled := int(round(pct * 10.0))
	return "[%s%s] %d/%d" % ["=".repeat(filled), "-".repeat(10 - filled), hp, max_hp]


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
	return text


func _on_action_button_pressed(index: int) -> void:
	if index >= _current_player_moves.size():
		return
	var move: Dictionary = _current_player_moves[index]
	if String(move.get("target_type", "")) == "single_enemy":
		_pending_move = move
		_refresh_enemy_slots()
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


func _on_enemy_slot_pressed(index: int) -> void:
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


## Hides everything the mid-battle layout used (enemy/party slots, turn
## order, log) so result_label/close_button -- which occupy the same
## screen space those did, not empty space of their own -- aren't drawn
## over/under still-visible combat UI. Before this, close_button rendered
## squeezed between two still-visible party slot buttons, easy to miss
## entirely (found via on-device report: "no close button after winning
## or losing a battle").
func _show_results() -> void:
	waiting_label.visible = false
	for b in action_buttons:
		b.visible = false
	for slot in enemy_slots:
		slot.visible = false
	for slot in party_slots:
		slot.visible = false
	turn_order_label.visible = false
	log_label.visible = false
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
