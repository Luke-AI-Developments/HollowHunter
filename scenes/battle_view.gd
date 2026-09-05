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
const ADVANCE_DELAY := 0.6  ## v0

## Battle VFX Polish §3: move_type -> (style, colour). "bolt" travels
## caster->target before the impact fx fire; "pulse" appears directly on the
## target with no travel (a heal/buff flying at an ally like a weapon reads
## wrong). Every colour here is a new v0 choice.
const MOVE_VFX := {
	"physical": {"style": "bolt", "color": Color(0.9, 0.9, 0.85)},  ## v0: pale steel
	"magic": {"style": "bolt", "color": Color(0.4, 0.85, 1.0)},  ## v0: cyan
	"heal": {"style": "pulse", "color": Color(0.5, 0.95, 0.6)},  ## v0: green
	"buff": {"style": "pulse", "color": Color(1.0, 0.85, 0.4)},  ## v0: gold
	"cleanse": {"style": "pulse", "color": Color(0.9, 0.95, 1.0)},  ## v0: pale white
	"revive": {"style": "pulse", "color": Color(1.0, 0.85, 0.4)},  ## v0: gold
}
const _BOLT_FLIGHT_TIME := 0.35  ## v0
const _PULSE_TIME := 0.4  ## v0

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
var _gauge_was_full: bool = false  ## Task 5: edge-track so gauge_bar.flash() fires once per fill
var _ult_tween: Tween = null  ## Task 5: looped pulse on ultimate_button while it's swapped in
var _ticker_lines: Array[String] = []  ## Task 6: rolling ticker copy, trimmed to the last 3
var _last_consumed: Array = []  ## Task 6: raw dicts _refresh_ticker just walked (Task 7 replays)
var _num_pool: Array[Label] = []  ## Task 7: pooled floating damage-number Labels under $Stage
var _num_next: int = 0  ## Task 7: round-robin cursor into _num_pool
var _banner_tween: Tween = null  ## Task 7 review: kill an in-flight banner tween before a new one
var _shake_tweens: Dictionary = {}  ## final review I2: Control -> live shake Tween, so an
## overlapping shake on the same node kills the old one instead of stranding it mid-offset
var _vfx_pool: Array[Control] = []  ## Battle VFX Polish §3: pooled bolt/pulse nodes under $Stage
var _vfx_next: int = 0  ## round-robin cursor into _vfx_pool, mirrors _num_pool/_num_next

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
	advance_timer.wait_time = ADVANCE_DELAY
	ultimate_button.pivot_offset = ultimate_button.size / 2.0  ## v0: centre for the scale pulse
	# final review I3: $Stage (BattlePanel child index 4) sits before PartyRow/Command in
	# the .tscn, so floating damage numbers and the banner painted underneath the ~98%-
	# opaque party/command panels. Raise both above every other band via z_index instead
	# of reordering the .tscn (M1's Vignette full-screen tint needs the same treatment).
	$Stage.z_index = 10  ## v0
	vignette.z_index = 20  ## v0


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
	_awaiting_player_input = false
	_current_player_moves = []
	_focus_arm = false
	_gauge_was_full = false
	_log_cursor = _battle.log.size()
	_ticker_lines.clear()
	_last_consumed.clear()
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
	_build_stage_nodes()
	_build_enemy_nodes()
	_build_party_nodes()
	_build_turn_chip_nodes()
	_build_number_pool()
	_build_vfx_pool()
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
	_play_new_events(_last_consumed)


## Task 2: the real enemy arena band. One `Control` column per enemy named
## `E<i>` (index-matched to `_battle.enemies`, so targeting stays by index),
## laid out as a horizontally-centred strip across the 1040-wide arena -- a
## boss column is 300 wide, grunts 180. Each column stacks, top->bottom:
## name caption / HP capsule / break capsule (bosses only) / portrait block
## (dim platform + portrait + telegraph badge + unused targeting ring) /
## status pips. Targeting/focus/defeated feedback is done by tinting
## `pic.modulate` (see `_refresh_enemy_slots`), not the ring, for v0.
## Every colour/size here is a v0 hypothesis (sub-project C tunes them).
## final review I4: `_battle.enemies` grows unbounded over a fight (dead Brood Spawn
## adds are never removed, even though only a capped number are ever alive at once), so
## building one column per array entry can overflow the 1040px arena. Cap to
## MAX_ENEMY_SLOTS, boss always included (found by `is_boss`, not by array position),
## then living adds before dead ones fill the rest -- otherwise a dead add sitting
## earlier in the array could push a live one off-screen and untappable. Column names
## stay "E<i>" with `i` = the real `_battle.enemies` index (not a sequential 0..k), so
## every other `arena.get_node_or_null("E%d" % i)` site (`_refresh_enemy_slots`,
## `_enemy_bar_flash`, `_anchor_for`, `_on_enemy_pic_input`'s bound index) keeps working
## unchanged -- they already tolerate a missing column via their null checks.
func _visible_enemy_indices() -> Array[int]:
	var all_idx: Array[int] = []
	for i in _battle.enemies.size():
		all_idx.append(i)
	if all_idx.size() <= MAX_ENEMY_SLOTS:
		return all_idx
	var boss_i := -1
	for i in all_idx:
		if bool(_battle.enemies[i].get("is_boss", false)):
			boss_i = i
			break
	var living: Array[int] = []
	var dead: Array[int] = []
	for i in all_idx:
		if i == boss_i:
			continue
		if int(_battle.enemies[i]["hp"]) > 0:
			living.append(i)
		else:
			dead.append(i)
	var out: Array[int] = []
	if boss_i != -1:
		out.append(boss_i)
	for i in living:
		if out.size() >= MAX_ENEMY_SLOTS:
			break
		out.append(i)
	for i in dead:
		if out.size() >= MAX_ENEMY_SLOTS:
			break
		out.append(i)
	out.sort()
	return out


func _ensure_cave_backdrop() -> void:
	var existing := arena.get_node_or_null("CaveBackdrop")
	if existing != null:
		return
	var backdrop := CaveBackdrop.new()
	backdrop.name = "CaveBackdrop"
	backdrop.position = Vector2.ZERO
	arena.add_child(backdrop)
	arena.move_child(backdrop, 0)
	backdrop.set_band_size(arena.size)


func _build_enemy_nodes() -> void:
	for c in arena.get_children():
		if c.name == "CaveBackdrop":
			continue
		arena.remove_child(c)
		c.queue_free()
	_ensure_cave_backdrop()
	var indices := _visible_enemy_indices()
	var n := indices.size()
	var gap := 20.0  ## v0
	var widths: Array[float] = []
	var total := 0.0
	for idx in indices:
		var w := 300.0 if _battle.enemies[idx].get("is_boss") else 180.0  ## v0
		widths.append(w)
		total += w
	total += gap * maxi(n - 1, 0)
	var x := (1040.0 - total) / 2.0
	for k in n:
		var i := indices[k]
		var e: Dictionary = _battle.enemies[i]
		var col_w: float = widths[k]
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
		cap.clip_text = true
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.material = ArtPaths.portrait_material()
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
			pic.modulate = Color(0.35, 0.35, 0.4)  ## v0
		elif focused:
			pic.modulate = Color(0.7, 1.0, 1.0)  ## v0
		elif targeting:
			pic.modulate = Color(0.85, 0.95, 1.0)  ## v0
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
## shader-recoloured shadow thumb (the hunter's preset portrait instead gets
## `portrait_material()` -- knockout only, no recolour) / name caption (gets
## a `▶` prefix + brightened `self_modulate`
## while this unit is the acting one, per `_active_id`) / class icon / HP
## StatBar + number / cooldown dots / status pips. Card size and the thumb /
## icon dimensions are the brief's; every internal offset/height is a v0
## layout hypothesis (sub-project C retunes). Per-frame state is applied in
## `_refresh_party_slots`.
func _build_party_nodes() -> void:
	for c in party_row.get_children():
		party_row.remove_child(c)
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
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if String(c["id"]) != "player":
			thumb.material = ArtPaths.shadow_material()
		else:
			thumb.material = ArtPaths.portrait_material()
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
		cls.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cls.material = ArtPaths.portrait_material()
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
		card.self_modulate = Color(1.25, 1.25, 1.3) if active else Color.WHITE  ## v0
		var nm: Label = card.get_node("name")
		nm.text = ("▶ " if active else "") + String(c["name"])
		var thumb: TextureRect = card.get_node("thumb")
		thumb.texture = _party_portraits.get(String(c["id"]), null)
		var hpbar: StatBar = card.get_node("hpbar")
		hpbar.set_values(float(c["hp"]), float(c["max_hp"]))
		var hpnum: Label = card.get_node("hpnum")
		hpnum.text = "%d / %d" % [int(c["hp"]), int(c["max_hp"])]
		var down := int(c["hp"]) <= 0
		thumb.modulate = Color(0.35, 0.35, 0.4) if down else Color.WHITE  ## v0
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


## Task 4: the real turn-order strip. A fixed pool of 7 portrait chips is
## built ONCE here (the strip shows at most the first 7 entries of a
## turn_queue that CAN grow -- spawn/reinforcement turns append to it in
## core/battle.gd), each a `C<i>` container holding a `ring`
## ColorRect bg + a `pic` TextureRect portrait; a static `"NOW"` Label sits
## before chip 0. `_refresh_turn_order` then only re-fills texture / ring
## colour / visibility -- no per-`_advance` node churn. Ring tint reads
## party (cyan) vs enemy (red) via `_is_enemy_id`; chips past the live
## `turn_queue.size()` hide. Chip 60x60 + the two ring colours are the
## brief's; the ring's 3px bleed / strip separation are v0 hypotheses.
func _build_turn_chip_nodes() -> void:
	for c in turn_strip.get_children():
		turn_strip.remove_child(c)
		c.queue_free()
	turn_strip.add_theme_constant_override("separation", 10)  ## v0
	var now := Label.new()
	now.name = "NOW"
	now.text = "NOW"
	turn_strip.add_child(now)
	for i in 7:
		var chip := Control.new()
		chip.name = "C%d" % i
		chip.custom_minimum_size = Vector2(60, 60)
		var ring := ColorRect.new()
		ring.name = "ring"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.position = Vector2(-3, -3)  ## v0
		ring.size = Vector2(66, 66)  ## v0
		chip.add_child(ring)
		var pic := TextureRect.new()
		pic.name = "pic"
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.position = Vector2(0, 0)
		pic.size = Vector2(60, 60)
		pic.custom_minimum_size = Vector2(60, 60)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.add_child(pic)
		turn_strip.add_child(chip)


func _refresh_turn_order() -> void:
	var q := _battle.turn_queue
	for i in 7:
		var chip := turn_strip.get_node_or_null("C%d" % i)
		if chip == null:
			continue
		if i >= q.size():
			chip.visible = false
			continue
		chip.visible = true
		var id := String(q[i])
		var is_enemy := _is_enemy_id(id)
		var ring: ColorRect = chip.get_node("ring")
		ring.color = Color(0.85, 0.3, 0.3, 0.9) if is_enemy else Color(0.498, 0.941, 1, 0.9)  ## v0
		var pic: TextureRect = chip.get_node("pic")
		pic.texture = ArtPaths.monster_portrait(id) if is_enemy else _party_portraits.get(id, null)
		if is_enemy or id == "player":
			pic.material = ArtPaths.portrait_material()
		else:
			pic.material = ArtPaths.shadow_material()


func _is_enemy_id(id: String) -> bool:
	for e: Dictionary in _battle.enemies:
		if String(e["id"]) == id:
			return true
	return false


## Task 6: the rolling ticker's three stacked fading Labels, built under
## $Stage at runtime (oldest -> newest = L0 -> L2). Runtime rather than in
## the .tscn so the pre-rebuild $Stage/TickerLabel can stay untouched (it is
## just hidden). Safe to call again -- Nadir floors reuse one BattleView, so
## any prior L0/L1/L2 are freed first.
func _build_stage_nodes() -> void:
	ticker_label.visible = false
	var alphas := [0.3, 0.55, 1.0]  ## v0: oldest dim -> newest bright
	for i in LOG_LINES_SHOWN:
		var old_lab := $Stage.get_node_or_null("L%d" % i)
		if old_lab != null:
			$Stage.remove_child(old_lab)
			old_lab.queue_free()
		var lab := Label.new()
		lab.name = "L%d" % i
		lab.position = Vector2(0, 78 * i)  ## v0: 78px per ticker line
		lab.size = Vector2(1000, 78)  ## v0: $Stage inner width, one line's band
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 22)  ## v0
		lab.modulate.a = alphas[i]
		$Stage.add_child(lab)


## Task 6: classify a _battle.log event type into a ticker render lane.
## "banner" = the big beats Task 7's effects layer also reacts to; "silent"
## = telemetry the ticker drops; "line" = everything else.
static func _render_style_for(event_type: String) -> String:
	if (
		event_type
		in ["break", "phase", "undying", "undying_shatter", "ultimate", "revive", "undying_revive"]
	):
		return "banner"
	if event_type in ["break_fill", "gauge", "status"]:
		return "silent"
	return "line"


## Task 6: the rolling 3-line ticker. Walks every _battle.log entry added
## since _log_cursor (advancing it inline -- no separate bump in _advance),
## drops "silent" telemetry, appends the _describe_event() copy for the rest,
## keeps the last LOG_LINES_SHOWN, and renders them into L0/L1/L2 with the
## newest on the bottom. The raw dicts it walked are stashed in
## _last_consumed so Task 7 can replay the same slice without a second cursor.
func _refresh_ticker() -> void:
	var consumed: Array = []
	while _log_cursor < _battle.log.size():
		var ev: Dictionary = _battle.log[_log_cursor]
		_log_cursor += 1
		consumed.append(ev)
		if _render_style_for(String(ev.get("type", ""))) == "silent":
			continue
		var line := _describe_event(ev)
		if line == "":
			continue
		_ticker_lines.append(line)
	while _ticker_lines.size() > LOG_LINES_SHOWN:
		_ticker_lines.pop_front()
	var labels := [$Stage/L0, $Stage/L1, $Stage/L2]
	for i in LOG_LINES_SHOWN:
		var idx := _ticker_lines.size() - LOG_LINES_SHOWN + i
		labels[i].text = _ticker_lines[idx] if idx >= 0 else ""
	_last_consumed = consumed


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
	var was_ult_visible := ultimate_button.visible
	ultimate_button.visible = false
	# Gauge readout updates even while resolving / target-picking / under Auto.
	gauge_label.text = "MONARCH GAUGE %d / 100" % int(round(_battle.monarch_gauge))
	gauge_bar.set_values(_battle.monarch_gauge, 100.0)
	# Flash once per fill: only on the not-full -> full edge, not every refresh.
	if _battle.can_use_ultimate() and not _gauge_was_full:
		gauge_bar.flash()
	_gauge_was_full = _battle.can_use_ultimate()
	chain_pill.visible = _battle.chain_count > 0
	if _battle.chain_count > 0:
		chain_pill.text = "CHAIN x%.1f" % (1.0 + Battle.CHAIN_DAMAGE_STEP * _battle.chain_count)
	var focus_name := _name_for(_battle.focus_target_id) if _battle.focus_target_id != "" else ""
	focus_button.text = (
		"FOCUS: %s" % focus_name
		if focus_name != ""
		else ("FOCUS: tap an enemy" if _focus_arm else "FOCUS")
	)

	if not _pending_move.is_empty():
		for b in action_buttons:
			b.visible = false
		waiting_label.visible = true
		waiting_label.text = "Choose a target for %s" % _pending_move["name"]
		_update_ultimate_pulse(was_ult_visible, false)
		return

	if not _awaiting_player_input:
		waiting_label.visible = true
		waiting_label.text = (
			"◈ %s is acting..." % _name_for(_active_id) if _active_id != "" else "Resolving..."
		)
		for b in action_buttons:
			b.visible = false
		focus_button.visible = false
		defend_button.visible = false
		_update_ultimate_pulse(was_ult_visible, false)
		return

	waiting_label.visible = false
	focus_button.visible = true
	defend_button.visible = true
	var player: Dictionary = _battle.party[0]
	_current_player_moves = Content.unlocked_moves(
		_moves, String(player["class"]), int(player["level"])
	)
	var cooldowns: Dictionary = player.get("cooldowns", {})
	var can_ult := _awaiting_player_input and _battle.can_use_ultimate()
	for i in action_buttons.size():
		var b := action_buttons[i]
		# Top row (0,1) yields its y-band to the wide Ultimate button when it's up.
		if can_ult and i < 2:
			b.visible = false
			continue
		if i >= _current_player_moves.size():
			b.visible = false
			continue
		var move: Dictionary = _current_player_moves[i]
		var cd := int(cooldowns.get(move["id"], 0))
		b.visible = true
		b.disabled = cd > 0
		b.text = "%s%s" % [move["name"], (" (CD %d)" % cd) if cd > 0 else ""]

	ultimate_button.visible = can_ult
	if can_ult:
		ultimate_button.text = "★ %s ★" % _battle.ultimate_name()
	_update_ultimate_pulse(was_ult_visible, can_ult)


## Task 5: drive the looped "ready" pulse on the gold Ultimate button off its
## visibility edges -- start a fresh looped Tween on the hidden->visible edge,
## kill it and hard-reset scale/modulate on the visible->hidden edge. Guarded
## by `_ult_tween` so a mid-cycle refresh at steady visibility is a no-op.
func _update_ultimate_pulse(was_visible: bool, now_visible: bool) -> void:
	if now_visible and not was_visible:
		if _ult_tween != null:
			_ult_tween.kill()
		_ult_tween = ultimate_button.create_tween().set_loops()
		_ult_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ult_tween.tween_property(ultimate_button, "scale", Vector2(1.04, 1.04), 0.7)  ## v0
		_ult_tween.parallel().tween_property(
			ultimate_button, "modulate", Color(1.04, 1.04, 1.04), 0.7
		)  ## v0
		_ult_tween.tween_property(ultimate_button, "scale", Vector2.ONE, 0.7)  ## v0
		_ult_tween.parallel().tween_property(ultimate_button, "modulate", Color.WHITE, 0.7)  ## v0
	elif was_visible and not now_visible:
		if _ult_tween != null:
			_ult_tween.kill()
			_ult_tween = null
		ultimate_button.scale = Vector2.ONE
		ultimate_button.modulate = Color.WHITE


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


## Task 7: eight reusable floating-number Labels parented to $Stage, hidden
## until _pop_number lifts one. Safe to call again on a later start_battle
## (Nadir floors reuse this view) -- any prior pool is freed first. The
## trailing move_child is the Task 6 review fix: $Stage/L0..L2 (built by
## _build_stage_nodes) are added after $Stage/Banner and paint over it, so
## the banner is raised back to the top of the child order here, once every
## sibling that could occlude it exists, so _banner_fx reads above the ticker.
func _build_number_pool() -> void:
	for old_lbl in _num_pool:
		if is_instance_valid(old_lbl):
			$Stage.remove_child(old_lbl)
			old_lbl.queue_free()
	_num_pool.clear()
	_num_next = 0
	for _i in 8:  ## v0: pool size
		var lbl := Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 34)  ## v0
		$Stage.add_child(lbl)
		_num_pool.append(lbl)
	$Stage.move_child($Stage/Banner, $Stage.get_child_count() - 1)


## Task 7: take the next pooled Label, place it at `anchor`'s centre in $Stage
## local space, then rise + fade it over 0.7 s and hide on finish. `big` picks
## the larger font and a longer rise (crit / boss BIG HIT).
func _pop_number(anchor: Control, text: String, col: Color, big: bool) -> void:
	if anchor == null or _num_pool.is_empty():
		return
	var lbl := _num_pool[_num_next]
	_num_next = (_num_next + 1) % _num_pool.size()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 48 if big else 34)  ## v0
	var stage: Control = $Stage
	var origin := anchor.get_global_position() + anchor.size * 0.5 - stage.get_global_position()
	lbl.position = origin
	lbl.modulate = Color(1, 1, 1, 1)
	lbl.visible = true
	# final review I1: bind to the Label, not BattleView, so a pool rebuild
	# (_build_number_pool, M3) auto-kills any in-flight rise/fade instead of it later
	# touching a freed instance.
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", origin.y - (60.0 if big else 40.0), 0.7)  ## v0
	t.tween_property(lbl, "modulate:a", 0.0, 0.7)  ## v0
	t.chain().tween_callback(
		func() -> void:
			if is_instance_valid(lbl):
				lbl.visible = false
	)


## Battle VFX Polish §3: pure move_type -> VFX style. Unknown/absent types
## (a DoT tick with no move behind it, or a future move_type this table
## hasn't seen yet) default to "pulse" -- the less visually aggressive choice.
static func _vfx_style_for_move_type(move_type: String) -> String:
	return String(MOVE_VFX.get(move_type, {}).get("style", "pulse"))


## Battle VFX Polish §3: resolve which MOVE_VFX entry an event should use.
## Player-chosen moves carry `move_id` (Task 3); Ultimates and raw enemy
## attacks carry `atk_type` instead (no moves.json entry exists for either);
## passive per-turn ticks (poison_tick/regen_tick/lifesteal) carry neither --
## poison defaults to physical, the other two default to heal, matching what
## they visually are.
func _move_vfx_for_event(ev: Dictionary) -> Dictionary:
	var move_id := String(ev.get("move_id", ""))
	var move_type := ""
	if move_id != "":
		move_type = String(Content.move_by_id(_moves, move_id).get("move_type", ""))
	if move_type == "":
		move_type = String(ev.get("atk_type", ""))
	if move_type == "":
		match String(ev.get("type", "")):
			"poison_tick":
				move_type = "physical"
			"regen_tick", "lifesteal":
				move_type = "heal"
			_:
				move_type = "physical"
	return MOVE_VFX.get(move_type, MOVE_VFX["physical"])


## Battle VFX Polish §3: 6 pooled Controls under $Stage, each capable of being
## either a "bolt" (a small filled circle that tweens position caster->target)
## or a "pulse" (a small ring that scales/fades in place on the target) --
## the same node is reused for both, only its _draw() colour/state differs
## per use. Pooled + round-robin, mirroring _num_pool/_num_next exactly.
func _build_vfx_pool() -> void:
	for old in _vfx_pool:
		if is_instance_valid(old):
			$Stage.remove_child(old)
			old.queue_free()
	_vfx_pool.clear()
	_vfx_next = 0
	for i in 6:  ## v0: enough for a 4-target AoE with headroom
		var node := Control.new()
		node.name = "VfxSlot%d" % i
		node.visible = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(24, 24)  ## v0
		node.set_meta("radius", 8.0)  ## v0, read by the shared _draw below
		node.set_meta("draw_color", Color.WHITE)
		node.draw.connect(_draw_vfx_node.bind(node))
		$Stage.add_child(node)
		_vfx_pool.append(node)


func _draw_vfx_node(node: Control) -> void:
	var radius: float = node.get_meta("radius", 8.0)
	var col: Color = node.get_meta("draw_color", Color.WHITE)
	node.draw_circle(Vector2(12, 12), radius, col)  ## v0: centred in the 24x24 node


## Battle VFX Polish §3: fires a "bolt" (travels actor_id's anchor -> target_id's
## anchor) or a "pulse" (appears in place on target_id's anchor) using the
## given style/colour, then calls on_arrive when the animation completes --
## the caller binds on_arrive to the existing _hit_fx/_heal_fx call so the
## damage number / shake / flash / tint only fire once the VFX visually
## lands. Purely cosmetic timing: core/battle.gd already resolved the whole
## turn synchronously before this ever runs.
func _play_move_vfx(
	style: String, col: Color, actor_id: String, target_id: String, on_arrive: Callable
) -> void:
	var target_anchor := _anchor_for(target_id)
	if _vfx_pool.is_empty() or target_anchor == null:
		on_arrive.call()
		return
	var stage: Control = $Stage
	var node := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	node.set_meta("draw_color", col)
	var target_pos := (
		target_anchor.get_global_position()
		+ target_anchor.size * 0.5
		- stage.get_global_position()
		- node.size * 0.5
	)
	node.visible = true
	node.modulate = Color(1, 1, 1, 1)
	node.scale = Vector2.ONE
	if style == "bolt":
		var actor_anchor := _anchor_for(actor_id)
		var start_pos := target_pos
		if actor_anchor != null:
			start_pos = (
				actor_anchor.get_global_position()
				+ actor_anchor.size * 0.5
				- stage.get_global_position()
				- node.size * 0.5
			)
		node.position = start_pos
		node.queue_redraw()
		var t := node.create_tween()
		t.tween_property(node, "position", target_pos, _BOLT_FLIGHT_TIME)
		t.tween_callback(
			func() -> void:
				node.visible = false
				on_arrive.call()
		)
	else:  # "pulse"
		node.position = target_pos
		node.scale = Vector2(0.3, 0.3)
		node.modulate.a = 0.0
		node.queue_redraw()
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "scale", Vector2(1.4, 1.4), _PULSE_TIME)
		t.tween_property(node, "modulate:a", 1.0, _PULSE_TIME * 0.4)
		t.chain().tween_property(node, "modulate:a", 0.0, _PULSE_TIME * 0.6)
		t.chain().tween_callback(
			func() -> void:
				node.visible = false
				on_arrive.call()
		)


## Task 7: replay this tick's freshly-consumed _battle.log slice (Task 6's
## _last_consumed) as cosmetic beats -- floating numbers, shake, white flash,
## centre banner, red vignette, Ultimate gold tint. Reads nothing back and
## changes no pacing; `_:` types are already covered by the ticker.
func _play_new_events(events: Array) -> void:
	for ev: Dictionary in events:
		match String(ev.get("type", "")):
			"damage", "poison_tick":
				var target_id := String(ev.get("target_id", ""))
				var dmg := int(ev.get("damage", 0))
				var crit := bool(ev.get("crit", false))
				var vfx := _move_vfx_for_event(ev)
				_play_move_vfx(
					String(vfx["style"]),
					vfx["color"],
					String(ev.get("actor_id", "")),
					target_id,
					func() -> void: _hit_fx(target_id, dmg, crit, false)
				)
			"enemy_attack":
				var target_id := String(ev.get("target_id", ""))
				var dmg := int(ev.get("damage", 0))
				var big := bool(ev.get("big_hit", false))
				var vfx := _move_vfx_for_event(ev)
				_play_move_vfx(
					String(vfx["style"]),
					vfx["color"],
					String(ev.get("actor_id", "")),
					target_id,
					func() -> void: _hit_fx(target_id, dmg, big, big)
				)
			"heal", "regen_tick", "devour_heal", "leech_heal", "lifesteal":
				var who := String(ev.get("target_id", ev.get("actor_id", "")))
				var amt := int(ev.get("amount", 0))
				var vfx := _move_vfx_for_event(ev)
				_play_move_vfx(
					String(vfx["style"]),
					vfx["color"],
					String(ev.get("actor_id", who)),
					who,
					func() -> void: _heal_fx(who, amt)
				)
			"break":
				_banner_fx("BREAK!", Color(1, 0.7, 0.3))  ## v0: amber
				_enemy_bar_flash(String(ev.get("target_id", "")))
			"phase":
				_banner_fx("PHASE %d" % int(ev.get("phase", 2)), Color(1, 0.5, 0.85))  ## v0
			"undying":
				_banner_fx("UNDYING", Color(0.8, 0.9, 1))  ## v0
			"undying_shatter":
				_banner_fx("SHATTERED", Color(1, 1, 1))  ## v0: white
			"undying_revive", "revive":
				_banner_fx("REVIVED", Color(0.5, 0.95, 0.6))  ## v0
			"ultimate":
				var nm := String(ev.get("name", "Ultimate"))
				_banner_fx("★ %s ★" % nm, Color(1, 0.85, 0.4))  ## v0: gold
				_screen_tint(Color(1, 0.85, 0.4, 0.18))  ## v0
			"spawn":
				# Task 2 review fix: _build_enemy_nodes only runs in start_battle,
				# so a spawned add has no E<i> column. Rebuild every column
				# (idempotent) then re-fill so the add gets a portrait.
				_build_enemy_nodes()
				_refresh_enemy_slots()
			_:
				pass


## Task 7: an incoming hit on `target_id` -- a rising damage number (grey
## em-dash if it did nothing, gold + larger on a crit / big hit), a positional
## shake, a white flash on the portrait, and, only for a boss BIG HIT (`big`),
## a red screen pulse.
func _hit_fx(target_id: String, dmg: int, crit: bool, big: bool) -> void:
	var anchor := _anchor_for(target_id)
	var loud := crit or big
	if dmg <= 0:
		_pop_number(anchor, "—", Color(0.7, 0.7, 0.72), false)  ## v0: grey
	else:
		_pop_number(anchor, str(dmg), Color(1, 0.85, 0.35) if crit else Color.WHITE, loud)
	_shake(anchor, 10.0 if loud else 6.0)  ## v0
	_white_flash(anchor)
	if big:
		_red_vignette()


## Task 7: a heal / regen / drain landing on `id` -- a green "+N" number plus
## a brief green tint pulse on the target's portrait.
func _heal_fx(id: String, amt: int) -> void:
	var anchor := _anchor_for(id)
	_pop_number(anchor, "+%d" % amt, Color(0.5, 0.95, 0.6), false)  ## v0: green
	_tint_pulse(anchor, Color(0.5, 1.2, 0.6))  ## v0: over-bright green


## Task 7: nudge `node` left / right around its resting x and settle back.
## final review I1/I2: bound to `node`'s own tween (not BattleView's) so a freed target
## (I1 -- the spawn arm rebuilds every enemy column mid-batch) auto-kills this instead of
## its trailing callback touching a dead instance. The rest x is stored as metadata the
## first time this node shakes and always shaken relative to THAT value (never a mid-shake
## snapshot), and any previous shake tween on this node is killed and the node restored to
## rest before the new one starts -- so two overlapping shakes on one target (e.g. the
## Assassin Ultimate's multi-hit combo) can't strand it at a mid-shake offset.
func _shake(node: Control, px: float) -> void:
	if node == null:
		return
	if not node.has_meta("shake_rest_x"):
		node.set_meta("shake_rest_x", node.position.x)
	var x0: float = node.get_meta("shake_rest_x")
	if _shake_tweens.has(node):
		var prev: Tween = _shake_tweens[node]
		if prev != null and prev.is_valid():
			prev.kill()
	node.position.x = x0
	var t := node.create_tween()
	_shake_tweens[node] = t
	t.tween_property(node, "position:x", x0 + px, 0.06)  ## v0
	t.tween_property(node, "position:x", x0 - px * 0.5, 0.07)  ## v0
	t.tween_property(node, "position:x", x0 + px * 0.25, 0.06)  ## v0
	t.tween_property(node, "position:x", x0, 0.06)  ## v0
	t.chain().tween_callback(
		func() -> void:
			if is_instance_valid(node):
				node.position.x = x0
	)


## Task 7: white hit-spark on `node` -- routed through _tint_pulse so it
## always eases back to a clean Color.WHITE rest state.
func _white_flash(node: Control) -> void:
	_tint_pulse(node, Color(2, 2, 2))  ## v0: over-bright white


## Task 7: snap `node.modulate` to `col`, then tween it back to Color.WHITE
## over ~0.2 s (the next _refresh_* pass re-applies any targeting tint).
## final review I1: bound to `node`'s own tween so a freed target (the spawn arm rebuilds
## every enemy column mid-batch) auto-kills this instead of its trailing callback touching
## a dead instance; the callback also double-guards with is_instance_valid.
func _tint_pulse(node: Control, col: Color) -> void:
	if node == null:
		return
	node.modulate = col
	var t := node.create_tween()
	t.tween_property(node, "modulate", Color.WHITE, 0.2)  ## v0
	t.chain().tween_callback(
		func() -> void:
			if is_instance_valid(node):
				node.modulate = Color.WHITE
	)


## Task 7: flash the centre banner -- set copy + colour, pop scale
## 0.7 -> 1.1 -> 1.0 while alpha holds then fades, hide on finish, all inside
## 0.6 s. pivot_offset is re-centred each call (the Label's size isn't known
## until it is in the tree).
func _banner_fx(text: String, col: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.7, 0.7)  ## v0
	banner.modulate = Color(1, 1, 1, 1)
	banner.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	var t := create_tween()
	_banner_tween = t
	t.tween_property(banner, "scale", Vector2(1.1, 1.1), 0.2)  ## v0
	t.tween_property(banner, "scale", Vector2.ONE, 0.15)  ## v0
	t.tween_property(banner, "modulate:a", 0.0, 0.25)  ## v0
	t.tween_callback(func() -> void: banner.visible = false)


## Task 7: wash the full-screen vignette with `col`, then fade its alpha to 0
## over 0.25 s and hide it.
func _screen_tint(col: Color) -> void:
	vignette.color = col
	vignette.visible = true
	var t := create_tween()
	t.tween_property(vignette, "color:a", 0.0, 0.25)  ## v0
	t.tween_callback(func() -> void: vignette.visible = false)


## Task 7: the boss BIG HIT variant of _screen_tint.
func _red_vignette() -> void:
	_screen_tint(Color(0.8, 0.1, 0.1, 0.35))  ## v0


## Task 7: flash the break capsule of whichever enemy column owns `id`.
func _enemy_bar_flash(id: String) -> void:
	for i in _battle.enemies.size():
		if String(_battle.enemies[i]["id"]) == id:
			var bar := arena.get_node_or_null("E%d/brkbar" % i)
			if bar is StatBar:
				(bar as StatBar).flash()
			return


## Task 7: the Control a floating number / shake / flash anchors to for combat
## id `id` -- the enemy column's portrait, else the party card's thumb, else
## $Stage as a safe fallback so callers never get null.
func _anchor_for(id: String) -> Control:
	for i in _battle.enemies.size():
		if String(_battle.enemies[i]["id"]) == id:
			var pic := arena.get_node_or_null("E%d/pics/pic" % i)
			if pic is Control:
				return pic as Control
	for i in _battle.party.size():
		if String(_battle.party[i]["id"]) == id:
			var thumb := party_row.get_node_or_null("P%d/thumb" % i)
			if thumb is Control:
				return thumb as Control
	return $Stage as Control


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
## command panel, vignette, banner) so result_label/close_button -- which
## occupy the same screen space -- aren't drawn over still-visible combat UI,
## then styles the win/loss headline and fades it in over a one-shot tween.
func _show_results() -> void:
	arena.visible = false
	turn_strip.visible = false
	$Stage.visible = false
	party_row.visible = false
	command.visible = false
	vignette.visible = false
	banner.visible = false
	_focus_arm = false
	if _ult_tween != null and _ult_tween.is_valid():
		_ult_tween.kill()
		_ult_tween = null
	ultimate_button.scale = Vector2.ONE
	ultimate_button.modulate = Color.WHITE
	var win_color := Color(0.5, 0.95, 0.6)  ## v0
	var lose_color := Color(0.95, 0.4, 0.35)  ## v0
	result_label.text = "VICTORY!" if _battle.won else "DEFEAT"
	result_label.add_theme_color_override("font_color", win_color if _battle.won else lose_color)
	result_label.modulate.a = 0.0
	result_label.visible = true
	close_button.visible = true
	var t := create_tween()
	t.tween_property(result_label, "modulate:a", 1.0, 0.3)  ## v0
	t.tween_callback(func() -> void: result_label.modulate.a = 1.0)


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
