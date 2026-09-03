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
	if result.get("waiting_for_player", false):
		_active_id = String(result.get("actor_id", "player"))
	elif not _battle.turn_queue.is_empty():
		_active_id = String(_battle.turn_queue[0])
	else:
		_active_id = ""
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


## Task 2: the real enemy arena band. One `Control` column per enemy named
## `E<i>` (index-matched to `_battle.enemies`, so targeting stays by index),
## laid out as a horizontally-centred strip across the 1040-wide arena -- a
## boss column is 300 wide, grunts 180. Each column stacks, top->bottom:
## name caption / HP capsule / break capsule (bosses only) / portrait block
## (dim platform + portrait + telegraph badge + unused targeting ring) /
## status pips. Targeting/focus/defeated feedback is done by tinting
## `pic.modulate` (see `_refresh_enemy_slots`), not the ring, for v0.
## Every colour/size here is a v0 hypothesis (sub-project C tunes them).
func _build_enemy_nodes() -> void:
	for c in arena.get_children():
		c.queue_free()
	var n := _battle.enemies.size()
	var gap := 20.0  ## v0
	var widths: Array[float] = []
	var total := 0.0
	for i in n:
		var w := 300.0 if _battle.enemies[i].get("is_boss") else 180.0  ## v0
		widths.append(w)
		total += w
	total += gap * maxi(n - 1, 0)
	var x := (1040.0 - total) / 2.0
	for i in n:
		var e: Dictionary = _battle.enemies[i]
		var col_w: float = widths[i]
		var col := Control.new()
		col.name = "E%d" % i
		col.position = Vector2(x, 0)
		col.custom_minimum_size = Vector2(col_w, 0)
		x += col_w + gap

		# All internal stack offsets / insets / heights below are v0 layout
		# hypotheses (sub-project C retunes): cap h 26, hpbar y 30, brkbar y 48,
		# pics y 62, the 10px side inset, plat h 24, telegraph offset (40, 2),
		# pips y-gap 8 and h 44.
		var cap := Label.new()
		cap.name = "cap"
		cap.position = Vector2(0, 0)
		cap.size = Vector2(col_w, 26)  ## v0
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)

		var hpbar := StatBar.new()
		hpbar.name = "hpbar"
		hpbar.set_palette("hp")
		hpbar.position = Vector2(10, 30)  ## v0
		hpbar.custom_minimum_size = Vector2(col_w - 20, 14)  ## v0
		hpbar.size = Vector2(col_w - 20, 14)  ## v0
		col.add_child(hpbar)

		var brkbar := StatBar.new()
		brkbar.name = "brkbar"
		brkbar.set_palette("break")
		brkbar.position = Vector2(10, 48)  ## v0
		brkbar.custom_minimum_size = Vector2(col_w - 20, 8)  ## v0
		brkbar.size = Vector2(col_w - 20, 8)  ## v0
		brkbar.visible = bool(e.get("is_boss")) and e.has("break_max")
		col.add_child(brkbar)

		var pics := Control.new()
		pics.name = "pics"
		pics.position = Vector2(0, 62)  ## v0
		pics.custom_minimum_size = Vector2(col_w, col_w)
		pics.size = Vector2(col_w, col_w)
		col.add_child(pics)

		var plat := ColorRect.new()
		plat.name = "plat"
		plat.color = Color(0, 0, 0, 0.5)  ## v0
		plat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plat.position = Vector2(0, col_w - 24)  ## v0
		plat.size = Vector2(col_w, 24)  ## v0
		pics.add_child(plat)

		var pic := TextureRect.new()
		pic.name = "pic"
		pic.position = Vector2(0, 0)
		pic.size = Vector2(col_w, col_w)
		pic.custom_minimum_size = Vector2(col_w, col_w)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_STOP
		pic.gui_input.connect(_on_enemy_pic_input.bind(i))
		pics.add_child(pic)

		# v0 placeholder: an inert outline node. Targeting/focus feedback is
		# shown by tinting `pic.modulate` in `_refresh_enemy_slots`; the ring
		# stays alpha 0 until a later task drives it.
		var ring := ColorRect.new()
		ring.name = "ring"
		ring.color = Color(0.498, 0.941, 1, 0)  ## v0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.position = Vector2(-3, -3)  ## v0
		ring.size = Vector2(col_w + 6, col_w + 6)  ## v0
		pics.add_child(ring)

		var telegraph := Label.new()
		telegraph.name = "telegraph"
		telegraph.text = "⚠"
		telegraph.add_theme_color_override("font_color", Color(1, 0.66, 0.3))  ## v0
		telegraph.add_theme_font_size_override("font_size", 32)  ## v0
		telegraph.position = Vector2(col_w - 40, 2)  ## v0
		telegraph.visible = false
		pics.add_child(telegraph)

		var pips := Label.new()
		pips.name = "pips"
		pips.position = Vector2(0, 62 + col_w + 8)  ## v0
		pips.size = Vector2(col_w, 44)  ## v0
		pips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(pips)

		arena.add_child(col)

		# Repeating fade so the telegraph badge reads as "incoming". Started
		# once here; harmless while the badge is hidden.
		var tw := telegraph.create_tween().set_loops()
		tw.tween_property(telegraph, "modulate:a", 0.3, 0.6)  ## v0
		tw.tween_property(telegraph, "modulate:a", 1.0, 0.6)  ## v0


func _refresh_enemy_slots() -> void:
	var targeting := not _pending_move.is_empty() or _focus_arm
	for i in _battle.enemies.size():
		var e: Dictionary = _battle.enemies[i]
		var col := arena.get_node_or_null("E%d" % i)
		if col == null:
			continue
		var alive := int(e["hp"]) > 0
		var cap: Label = col.get_node("cap")
		var tag := (" · " + String(e.get("kit", "")).to_upper()) if e.get("kit", "") != "" else ""
		cap.text = String(e["name"]) + tag
		var hpbar: StatBar = col.get_node("hpbar")
		hpbar.set_values(float(e["hp"]), float(e["max_hp"]))
		var brkbar: StatBar = col.get_node("brkbar")
		if brkbar.visible:
			brkbar.set_values(_battle.break_fraction(String(e["id"])), 1.0)
		var pic: TextureRect = col.get_node("pics/pic")
		pic.texture = ArtPaths.monster_portrait(String(e["id"]))
		var focused := String(e["id"]) == _battle.focus_target_id
		if not alive:
			pic.modulate = Color(0.35, 0.35, 0.4)
		elif focused:
			pic.modulate = Color(0.7, 1.0, 1.0)
		elif targeting:
			pic.modulate = Color(0.85, 0.95, 1.0)
		else:
			pic.modulate = Color.WHITE
		var tele: Label = col.get_node("pics/telegraph")
		tele.visible = alive and _battle.is_boss_next_hit_big(String(e["id"]))
		var pips: Label = col.get_node("pips")
		pips.text = _enemy_pips(e)


func _enemy_pips(e: Dictionary) -> String:
	var out: Array[String] = []
	if _battle.has_status(e, "vulnerable"):
		out.append("VULN %d" % int(e["statuses"]["vulnerable"]))
	if _battle.has_status(e, "stun"):
		out.append("STUN %d" % int(e["statuses"]["stun"]))
	if _battle.is_broken(String(e["id"])):
		out.append("BROKEN")
	if int(e.get("phase", 1)) >= 2:
		out.append("PHASE 2")
	if bool(e.get("death_window", false)):
		out.append("DEATH-WINDOW")
	if String(e["id"]) == _battle.focus_target_id:
		out.append("◎ FOCUS")
	return "  ".join(out)


## Task 3: the real party row band. One `Panel` card per `_battle.party`
## member named `P<i>` (index-matched to `_battle.party`), each stacking:
## shader-recoloured shadow thumb (the hunter's preset portrait stays raw --
## no material) / name caption (gets a `▶` prefix + brightened `self_modulate`
## while this unit is the acting one, per `_active_id`) / class icon / HP
## StatBar + number / cooldown dots / status pips. Card size and the thumb /
## icon dimensions are the brief's; every internal offset/height is a v0
## layout hypothesis (sub-project C retunes). Per-frame state is applied in
## `_refresh_party_slots`.
func _build_party_nodes() -> void:
	for c in party_row.get_children():
		c.queue_free()
	for i in _battle.party.size():
		var c: Dictionary = _battle.party[i]
		var card := Panel.new()
		card.name = "P%d" % i
		card.custom_minimum_size = Vector2(250, 360)

		var thumb := TextureRect.new()
		thumb.name = "thumb"
		thumb.position = Vector2(12, 12)  ## v0
		thumb.size = Vector2(60, 60)
		thumb.custom_minimum_size = Vector2(60, 60)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if String(c["id"]) != "player":
			thumb.material = ArtPaths.shadow_material()
		card.add_child(thumb)

		var nm := Label.new()
		nm.name = "name"
		nm.position = Vector2(84, 14)  ## v0
		nm.size = Vector2(154, 24)  ## v0
		card.add_child(nm)

		var cls := TextureRect.new()
		cls.name = "cls"
		cls.position = Vector2(84, 44)  ## v0
		cls.size = Vector2(24, 24)
		cls.custom_minimum_size = Vector2(24, 24)
		cls.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path := "res://art/ui/ui_class_%s.webp" % String(c["class"]).to_lower()
		if ResourceLoader.exists(icon_path):
			cls.texture = load(icon_path)
		card.add_child(cls)

		var hpbar := StatBar.new()
		hpbar.name = "hpbar"
		hpbar.set_palette("hp")
		hpbar.position = Vector2(12, 82)  ## v0
		hpbar.custom_minimum_size = Vector2(226, 14)  ## v0
		hpbar.size = Vector2(226, 14)  ## v0
		card.add_child(hpbar)

		var hpnum := Label.new()
		hpnum.name = "hpnum"
		hpnum.position = Vector2(12, 100)  ## v0
		hpnum.size = Vector2(226, 20)  ## v0
		card.add_child(hpnum)

		var cds := Label.new()
		cds.name = "cds"
		cds.position = Vector2(12, 126)  ## v0
		cds.size = Vector2(226, 24)  ## v0
		card.add_child(cds)

		var pips := Label.new()
		pips.name = "pips"
		pips.position = Vector2(12, 156)  ## v0
		pips.size = Vector2(226, 192)  ## v0
		pips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(pips)

		party_row.add_child(card)


func _refresh_party_slots() -> void:
	for i in _battle.party.size():
		var c: Dictionary = _battle.party[i]
		var card := party_row.get_node_or_null("P%d" % i)
		if card == null:
			continue
		var active := String(c["id"]) == _active_id
		card.self_modulate = Color(1.25, 1.25, 1.3) if active else Color.WHITE
		var nm: Label = card.get_node("name")
		nm.text = ("▶ " if active else "") + String(c["name"])
		var thumb: TextureRect = card.get_node("thumb")
		thumb.texture = _party_portraits.get(String(c["id"]), null)
		var hpbar: StatBar = card.get_node("hpbar")
		hpbar.set_values(float(c["hp"]), float(c["max_hp"]))
		var hpnum: Label = card.get_node("hpnum")
		hpnum.text = "%d / %d" % [int(c["hp"]), int(c["max_hp"])]
		var down := int(c["hp"]) <= 0
		thumb.modulate = Color(0.35, 0.35, 0.4) if down else Color.WHITE
		var cds: Label = card.get_node("cds")
		var on_cd := 0
		for v in c.get("cooldowns", {}).values():
			if int(v) > 0:
				on_cd += 1
		cds.text = "●".repeat(on_cd)
		var pips: Label = card.get_node("pips")
		var pl: Array[String] = []
		if down:
			pl.append("DOWN")
		if bool(c.get("is_taunting", false)):
			pl.append("TAUNT")
		if bool(c.get("defending", false)):
			pl.append("DEF")
		if _battle.has_status(c, "regen"):
			pl.append("REGEN")
		pips.text = "  ".join(pl)


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
	_active_id = ""
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
	_active_id = ""
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
	_active_id = ""
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
