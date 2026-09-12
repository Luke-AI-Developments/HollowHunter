class_name BattleView
extends Node2D
## Thin view script for ONE fight (§16b): owns no game rules, just drives a
## core/battle.gd Battle and renders its state into six stacked bands (title /
## arena / turn strip / stage ticker / party row / command). Sequencing a gate's
## sub-battles is the caller's job (step 5). Portrait art loads via ArtPaths where
## it exists, else null. ADVANCE_DELAY (pacing) and LOG_LINES_SHOWN are v0.

signal battle_finished(won: bool)

const LOG_LINES_SHOWN := 3
const MAX_ENEMY_SLOTS := 4
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
var _gauge_was_full: bool = false  ## Task 5: edge-track so gauge_bar.flash() fires once per fill
var _ult_tween: Tween = null  ## Task 5: looped pulse on ultimate_button while it's swapped in
var _ticker_lines: Array[String] = []  ## Task 6: rolling ticker copy, trimmed to the last 3
var _last_consumed: Array = []  ## Task 6: raw dicts _refresh_ticker just walked (Task 7 replays)
var _breathe_tweens: Dictionary = {}  ## Battle VFX Polish §4: Control -> live breathing Tween,
## mirrors BattleFx._shake_tweens -- guards stacking a 2nd loop on an already-breathing node
var _fx: BattleFx  ## visual round 2: the battle-screen effects layer (scenes/battle_fx.gd)

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
	# final review I3: $Stage sits before PartyRow/Command in the .tscn, so numbers +
	# banner painted under the near-opaque panels. Raise via z_index, not .tscn reorder.
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
	if _fx == null:
		_fx = BattleFx.new($Stage, arena, party_row, vignette)
	_fx.begin_fight(_battle, _moves, _rebuild_enemy_columns)
	_fx.build_number_pool()
	_fx.build_vfx_pool()
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
	_fx.play_new_events(_last_consumed)


## Task 2 + Task 4: the enemy arena band -- one `Control` column per enemy
## named `E<i>` (index-matched to `_battle.enemies`, so targeting stays by
## index). Task 4 doubled the columns (boss 600 wide, grunts 360) and replaced
## the side-by-side strip with an OVERLAP layout: the boss (or `enemies[0]` when
## nothing is `is_boss`) sits centred in the 1040-wide arena and is added LAST so
## it draws in front; grunts fan left/right of centre by a fixed step and are
## added deepest-first so nearer grunts overlap farther ones (the outer/rank-2
## grunt in a 4-enemy fight is scaled + dimmed for depth). Per-column stack: a
## header block (caption / HP / break capsule / status pips) ABOVE the portrait
## so a behind-enemy's readouts aren't hidden by the enemy in front, then the
## portrait block. Targeting/focus/defeat feedback tints `pic.modulate`
## (see `_refresh_enemy_slots`). All colours/sizes are v0 (sub-project C).
## `_battle.enemies` grows unbounded (dead adds are never removed), so this caps
## the visible columns to MAX_ENEMY_SLOTS: boss always (by `is_boss`), then living
## adds before dead. `i` stays the real array index so every `E%d` lookup still works.
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
	# Task 5: enemies stand ON the cave floor line. `_ensure_cave_backdrop` just
	# ran so "CaveBackdrop" exists; the guard is belt-and-braces. `floor_y()` is
	# in CaveBackdrop-local == arena-local space (the backdrop fills the arena).
	var backdrop := arena.get_node_or_null("CaveBackdrop")
	var floor_y: float = backdrop.floor_y() if backdrop != null else arena.size.y  ## v0 fallback
	var indices := _visible_enemy_indices()
	var n := indices.size()
	# Task 4 overlap layout. `centre_x` is the middle of the 1040-wide arena; the
	# boss (or the first visible enemy when nothing is `is_boss`) is placed there
	# and added LAST so it draws in front. Grunts fan left/right of centre by a
	# fixed step (rank 1 = adjacent, rank 2 = the outer 4th enemy) and are added
	# deepest-first so they stack behind. `centre_by_slot` / `depth_by_slot` are
	# keyed by the visible-slot index `k`.
	var centre_x := 1040.0 / 2.0  ## v0
	var overlap_step := 220.0  ## v0: x fan between the boss and an adjacent grunt
	var overlap_step_far := 340.0  ## v0: rank-2 grunt sits wider but stays on-screen
	var boss_slot := -1
	for k in n:
		if bool(_battle.enemies[indices[k]].get("is_boss", false)):
			boss_slot = k
			break
	if boss_slot == -1 and n > 0:
		boss_slot = 0
	var centre_by_slot := {}
	var depth_by_slot := {}
	if boss_slot != -1:
		centre_by_slot[boss_slot] = centre_x
		depth_by_slot[boss_slot] = 0
	var grunt_i := 0
	for k in n:
		if k == boss_slot:
			continue
		var rank := grunt_i / 2 + 1  ## v0: 1, 1, 2 for up to three grunts
		var side := -1.0 if grunt_i % 2 == 0 else 1.0
		var step: float = overlap_step if rank == 1 else overlap_step_far
		centre_by_slot[k] = centre_x + side * step
		depth_by_slot[k] = rank
		grunt_i += 1
	var add_order: Array[int] = []
	for k in n:
		if k != boss_slot and int(depth_by_slot[k]) >= 2:
			add_order.append(k)
	for k in n:
		if k != boss_slot and int(depth_by_slot[k]) < 2:
			add_order.append(k)
	if boss_slot != -1:
		add_order.append(boss_slot)

	for k in add_order:
		var i := indices[k]
		var e: Dictionary = _battle.enemies[i]
		var is_boss := bool(e.get("is_boss", false))
		var col_w := 600.0 if is_boss else 360.0  ## v0: 2x the round-1 widths (300 / 180)
		var depth := int(depth_by_slot[k])
		var hdr_w := 300.0  ## v0: header narrower than the column so a fanned grunt shows it
		var hdr_x := (col_w - hdr_w) / 2.0
		var col := Control.new()
		col.name = "E%d" % i
		col.position = Vector2(float(centre_by_slot[k]) - col_w / 2.0, 0)
		col.custom_minimum_size = Vector2(col_w, 0)
		if depth >= 2:
			col.pivot_offset = Vector2(col_w / 2.0, col_w / 2.0)  ## v0
			col.scale = Vector2(0.9, 0.9)  ## v0: outer grunt reads smaller / further back
			col.modulate = Color(0.72, 0.72, 0.8)  ## v0: ...and dimmer

		# Task 5: bottom-align the PORTRAIT's base to the cave floor line so every
		# monster stands on the ground -- a 600-tall boss column rises higher than
		# a 360-tall grunt, both "standing". `pics` starts at col-local y 96 and is
		# `col_w` tall, so the portrait's bottom edge is col-local y `96 + col_w`.
		# A Control scales about `pivot_offset`, so a child at local y `p` lands at
		# parent y `position.y + piv + (p - piv) * scale.y`. Solving that == floor_y:
		#   position.y = floor_y - piv - (portrait_bottom - piv) * scale.y
		# For an unscaled column (piv 0, scale 1) this is just floor_y -
		# portrait_bottom; for the depth>=2 grunt (piv col_w/2, scale 0.9) it folds
		# in the shrink so its SCALED feet still land on the line (Task 4 review F2).
		var portrait_bottom := 96.0 + col_w  ## v0: pics y-offset (96) + its height (col_w)
		var piv_y := col.pivot_offset.y
		col.position.y = floor_y - piv_y - (portrait_bottom - piv_y) * col.scale.y

		# Header block sits ABOVE the portrait (all offsets v0, sub-project C
		# retunes): cap h 26, hpbar y 28 h 14, brkbar y 46 h 8, pips y 58 h 34,
		# telegraph at the header's top-right. Portrait block starts at y 96;
		# plat (ground shadow) h 32 / ~60% width, flush with the portrait base;
		# ring 3px bleed. Task 5 then grounds the whole column on the cave floor.
		var cap := Label.new()
		cap.name = "cap"
		cap.position = Vector2(hdr_x, 0)
		cap.size = Vector2(hdr_w, 26)  ## v0
		cap.clip_text = true
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cap)

		var hpbar := StatBar.new()
		hpbar.name = "hpbar"
		hpbar.set_palette("hp")
		hpbar.position = Vector2(hdr_x + 8, 28)  ## v0
		hpbar.custom_minimum_size = Vector2(hdr_w - 16, 14)  ## v0
		hpbar.size = Vector2(hdr_w - 16, 14)  ## v0
		col.add_child(hpbar)

		var brkbar := StatBar.new()
		brkbar.name = "brkbar"
		brkbar.set_palette("break")
		brkbar.position = Vector2(hdr_x + 8, 46)  ## v0
		brkbar.custom_minimum_size = Vector2(hdr_w - 16, 8)  ## v0
		brkbar.size = Vector2(hdr_w - 16, 8)  ## v0
		brkbar.visible = bool(e.get("is_boss")) and e.has("break_max")
		col.add_child(brkbar)

		var pips := Label.new()
		pips.name = "pips"
		pips.position = Vector2(hdr_x, 58)  ## v0
		pips.size = Vector2(hdr_w, 34)  ## v0
		pips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(pips)

		var pics := Control.new()
		pics.name = "pics"
		pics.position = Vector2(0, 96)  ## v0
		pics.custom_minimum_size = Vector2(col_w, col_w)
		pics.size = Vector2(col_w, col_w)
		col.add_child(pics)

		# Task 5: `plat` is the monster's ground shadow -- a soft dark slab centred
		# under the portrait, its own bottom edge flush with the portrait base (==
		# the cave floor line once the column is grounded above). Narrower than the
		# column so it reads as a footprint, not a full-width bar.
		var plat := ColorRect.new()
		plat.name = "plat"
		plat.color = Color(0, 0, 0, 0.5)  ## v0
		plat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plat_w := col_w * 0.6  ## v0: shadow ~60% of the column width
		var plat_h := 32.0  ## v0
		plat.position = Vector2((col_w - plat_w) / 2.0, col_w - plat_h)  ## v0
		plat.size = Vector2(plat_w, plat_h)  ## v0
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
		telegraph.position = Vector2(hdr_x + hdr_w - 30, 0)  ## v0: header top-right
		telegraph.visible = false
		col.add_child(telegraph)

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
		pic.texture = ArtPaths.monster_portrait(String(e.get("portrait_id", e["id"])))
		var focused := String(e["id"]) == _battle.focus_target_id
		if not alive:
			_set_breathing(pic, false)
			pic.modulate = Color(0.35, 0.35, 0.4)  ## v0
		elif focused:
			_set_breathing(pic, false)
			pic.modulate = Color(0.7, 1.0, 1.0)  ## v0
		elif targeting:
			pic.modulate = Color.WHITE
			_set_breathing(pic, true)
		else:
			_set_breathing(pic, false)
			pic.modulate = Color.WHITE
		var tele: Label = col.get_node("telegraph")
		tele.visible = alive and _battle.is_boss_next_hit_big(String(e["id"]))
		var pips: Label = col.get_node("pips")
		pips.text = _enemy_pips(e)


## Visual round 2: the hook BattleFx.play_new_events calls on a "spawn" event --
## _build_enemy_nodes only runs in start_battle, so a spawned add has no E<i>
## column until this rebuilds (idempotent) then re-fills every column.
func _rebuild_enemy_columns() -> void:
	_build_enemy_nodes()
	_refresh_enemy_slots()


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


## Task 3 (visual round 2): the party row band -- one `Panel` card per
## `_battle.party` member named `P<i>` (index-matched). The card IS the unit's
## portrait: a `portrait` TextureRect covers the whole card (shadow art gets
## `shadow_material()`, the hunter `portrait_material()`), a bottom-up `scrim`
## gradient darkens the lower half, and every readout -- `name` / `cls` class
## icon / `hpbar` StatBar + `hpnum` / `cds` cooldown pips / `pips` status pips --
## is overlaid on top, card-relative, over the scrim. A cyan `bd` border marks
## the active unit. Null portrait art -> the Panel's dark fill shows through (no
## crash). All card sizes / offsets / colours are v0 (sub-project C retunes).
## Per-frame state: `_refresh_party_slots`.
func _build_party_nodes() -> void:
	for c in party_row.get_children():
		party_row.remove_child(c)
		c.queue_free()
	for i in _battle.party.size():
		var c: Dictionary = _battle.party[i]
		var card := Panel.new()
		card.name = "P%d" % i
		card.custom_minimum_size = Vector2(240, 500)  ## v0
		card.clip_contents = true

		var portrait := TextureRect.new()
		portrait.name = "portrait"
		portrait.position = Vector2.ZERO
		portrait.size = Vector2(240, 500)  ## v0
		portrait.custom_minimum_size = Vector2(240, 500)  ## v0
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if String(c["id"]) != "player":
			portrait.material = ArtPaths.shadow_material()
		else:
			portrait.material = ArtPaths.portrait_material()
		card.add_child(portrait)

		var dark := Color(0.02, 0.04, 0.07, 0.92)  ## v0: cave-blue scrim base
		var grad := Gradient.new()
		grad.set_color(0, Color(dark, 0.0))
		grad.set_color(1, dark)
		grad.add_point(0.55, Color(dark, 0.0))  ## v0: clear until 55% of card height
		var gtex := GradientTexture2D.new()
		gtex.gradient = grad
		gtex.width = 8  ## v0
		gtex.height = 512  ## v0
		gtex.fill_from = Vector2(0, 0)
		gtex.fill_to = Vector2(0, 1)  ## v0: vertical fill, top -> bottom
		var scrim := TextureRect.new()
		scrim.name = "scrim"
		scrim.position = Vector2.ZERO
		scrim.size = Vector2(240, 500)  ## v0
		scrim.stretch_mode = TextureRect.STRETCH_SCALE
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.texture = gtex
		card.add_child(scrim)

		var nm := Label.new()
		nm.name = "name"
		nm.position = Vector2(10, 8)  ## v0
		nm.size = Vector2(198, 24)  ## v0
		nm.clip_text = true
		nm.add_theme_font_size_override("font_size", 18)  ## v0
		card.add_child(nm)

		var cls := TextureRect.new()
		cls.name = "cls"
		cls.position = Vector2(208, 8)  ## v0: top-right corner
		cls.size = Vector2(28, 28)  ## v0
		cls.custom_minimum_size = Vector2(28, 28)  ## v0
		cls.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cls.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cls.material = ArtPaths.portrait_material()  ## class icons ship on a white bg
		var icon_path := "res://art/ui/ui_class_%s.webp" % String(c["class"]).to_lower()
		if ResourceLoader.exists(icon_path):
			cls.texture = load(icon_path)
		card.add_child(cls)

		var hpbar := StatBar.new()
		hpbar.name = "hpbar"
		hpbar.set_palette("hp")
		hpbar.position = Vector2(12, 396)  ## v0: lower third, over the scrim
		hpbar.custom_minimum_size = Vector2(216, 16)  ## v0
		hpbar.size = Vector2(216, 16)  ## v0
		card.add_child(hpbar)

		var hpnum := Label.new()
		hpnum.name = "hpnum"
		hpnum.position = Vector2(12, 414)  ## v0
		hpnum.size = Vector2(216, 20)  ## v0
		hpnum.add_theme_font_size_override("font_size", 16)  ## v0
		card.add_child(hpnum)

		var cds := Label.new()
		cds.name = "cds"
		cds.position = Vector2(12, 438)  ## v0: just below the HP
		cds.size = Vector2(216, 22)  ## v0
		cds.add_theme_font_size_override("font_size", 16)  ## v0
		card.add_child(cds)

		var pips := Label.new()
		pips.name = "pips"
		pips.position = Vector2(12, 462)  ## v0
		pips.size = Vector2(216, 34)  ## v0
		pips.add_theme_font_size_override("font_size", 15)  ## v0
		pips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(pips)

		var bd := ReferenceRect.new()
		bd.name = "bd"
		bd.editor_only = false
		bd.border_width = 2.0  ## v0
		bd.border_color = Color(0.35, 0.85, 1.0)  ## v0: active-unit cyan
		bd.position = Vector2.ZERO
		bd.size = Vector2(240, 500)  ## v0
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.visible = false
		card.add_child(bd)

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
		var bd: ReferenceRect = card.get_node("bd")
		bd.visible = active
		var portrait: TextureRect = card.get_node("portrait")
		portrait.texture = _party_portraits.get(String(c["id"]), null)
		var hpbar: StatBar = card.get_node("hpbar")
		hpbar.set_values(float(c["hp"]), float(c["max_hp"]))
		var hpnum: Label = card.get_node("hpnum")
		hpnum.text = "%d / %d" % [int(c["hp"]), int(c["max_hp"])]
		var down := int(c["hp"]) <= 0
		portrait.modulate = Color(0.35, 0.35, 0.4) if down else Color.WHITE  ## v0
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


## Task 4: the turn-order strip -- a fixed pool of 7 chips built ONCE here
## (turn_queue can grow past 7 via spawns), each a `C<i>` with a `ring` bg +
## `pic` portrait, a static `"NOW"` Label before chip 0. `_refresh_turn_order`
## then only re-fills texture / ring colour / visibility. Ring tint: party
## cyan vs enemy red via `_enemy_by_id`. 3px ring bleed / separation are v0.
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
		var enemy := _enemy_by_id(id)
		var is_enemy := not enemy.is_empty()
		var ring: ColorRect = chip.get_node("ring")
		ring.color = Color(0.85, 0.3, 0.3, 0.9) if is_enemy else Color(0.498, 0.941, 1, 0.9)  ## v0
		var pic: TextureRect = chip.get_node("pic")
		var por_id := String(enemy.get("portrait_id", id))
		pic.texture = (
			ArtPaths.monster_portrait(por_id) if is_enemy else _party_portraits.get(id, null)
		)
		if is_enemy or id == "player":
			pic.material = ArtPaths.portrait_material()
		else:
			pic.material = ArtPaths.shadow_material()


func _enemy_by_id(id: String) -> Dictionary:
	for e: Dictionary in _battle.enemies:
		if String(e["id"]) == id:
			return e
	return {}


## Task 6: the rolling ticker's three stacked fading Labels (oldest L0 -> newest
## L2), built under $Stage so the old $Stage/TickerLabel stays hidden but
## untouched. Safe to re-call -- prior L0..L2 are freed.
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
		lab.position = Vector2(0, 68 * i)  ## v0: 68px per ticker line (3 fit the 208-tall Stage band)
		lab.size = Vector2(1000, 68)  ## v0: $Stage inner width, one line's band
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


## Task 6: the rolling 3-line ticker. Walks every _battle.log entry since
## _log_cursor, drops "silent" telemetry, renders the rest into L0/L1/L2
## newest-at-bottom. The raw slice is stashed in _last_consumed for Task 7.
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


## Leaves the action bar/waiting label alone while mid-target-selection
## (_on_action_button_pressed owns that state). On the player's real turn
## (_awaiting_player_input): shows ALL unlocked moves, disabling any on
## cooldown. Otherwise a generic "Resolving..." placeholder (§16b no dead air).
func _refresh_action_bar() -> void:
	var was_ult_visible := ultimate_button.visible
	ultimate_button.visible = false
	# final review I1: SKIP/AUTO have no .tscn/refresh visibility logic (always on);
	# the pre-resolve lock hides them, so restore on every repaint (never runs mid-beat).
	skip_button.visible = true
	auto_button.visible = true
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
## visibility edges -- start a looped Tween on hidden->visible, kill it and
## hard-reset scale/modulate on visible->hidden. `_ult_tween` guards a steady no-op.
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


## Battle VFX Polish §4: starts (on=true) or stops (on=false) a looping alpha
## breathe on `node` -- used while a move is choosing/confirming its targets.
## Idempotent: turning on a node that's already breathing is a no-op; turning
## off a node that isn't breathing just guarantees full alpha.
func _set_breathing(node: Control, on: bool) -> void:
	if not is_instance_valid(node):  ## final review I1: a freed node is NOT `== null`
		_breathe_tweens.erase(node)  # drop the stale key instead of crashing on it
		return
	if not on:
		if _breathe_tweens.has(node):
			var prev: Tween = _breathe_tweens[node]
			if prev != null and prev.is_valid():
				prev.kill()
			_breathe_tweens.erase(node)
		node.modulate.a = 1.0
		return
	if _breathe_tweens.has(node):
		return  # already breathing, don't stack a second loop
	node.modulate.a = 1.0
	var t := node.create_tween()
	t.set_loops()
	t.tween_property(node, "modulate:a", 0.7, 0.45).set_trans(Tween.TRANS_SINE)  ## v0
	t.tween_property(node, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)  ## v0
	_breathe_tweens[node] = t


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
	_breathe_targets_then_resolve(move)


## Battle VFX Polish §4: for every target_type EXCEPT single_enemy (which
## already waits for a real tap via _pending_move), breathe the applicable
## portraits for a short fixed window before actually resolving -- purely
## cosmetic pacing so the player sees who's about to be hit/helped. The
## engine still auto-picks the real target exactly as _resolve_and_continue
## always has; this only delays WHEN the visual + resolve happen.
func _breathe_targets_then_resolve(move: Dictionary) -> void:
	# Task 5 review: lock the command UI BEFORE the cosmetic await, mirroring
	# _refresh_action_bar's "resolving" state -- otherwise a second tap during the
	# 0.35s beat could drive resolve_player_action/defend/ultimate out of turn
	# (core/battle.gd has no player-turn guard; the view is the gate).
	_awaiting_player_input = false
	var battle_at_start := _battle  ## final review I1: guard a battle swap/finish during the await
	for b in action_buttons:
		b.visible = false
	ultimate_button.visible = false
	focus_button.visible = false
	defend_button.visible = false
	skip_button.visible = false
	auto_button.visible = false
	waiting_label.visible = true
	waiting_label.text = "Resolving..."
	var target_type := String(move.get("target_type", ""))
	var nodes: Array[Control] = []
	match target_type:
		"all_enemies":
			for i in _battle.enemies.size():
				if int(_battle.enemies[i]["hp"]) > 0:
					var pic := arena.get_node_or_null("E%d/pics/pic" % i)
					if pic is Control:
						nodes.append(pic as Control)
		"self", "lowest_hp_ally", "all_allies":
			for i in _battle.party.size():
				if int(_battle.party[i]["hp"]) > 0:
					var pnode := party_row.get_node_or_null("P%d/portrait" % i)
					if pnode is Control:
						nodes.append(pnode as Control)
		"downed_ally":
			for i in _battle.party.size():
				if int(_battle.party[i]["hp"]) <= 0:
					var pnode := party_row.get_node_or_null("P%d/portrait" % i)
					if pnode is Control:
						nodes.append(pnode as Control)
	for node in nodes:
		_set_breathing(node, true)
	if nodes.is_empty():
		_resolve_and_continue(move["id"], "")
		return
	var timer := get_tree().create_timer(0.35)  ## v0: matches the bolt flight time
	await timer.timeout
	for node in nodes:
		_set_breathing(node, false)
	if _battle != battle_at_start or _battle == null or _battle.is_over:
		return  # final review I1: battle finished / swapped during the beat -- don't resolve
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
	# Bug B2: a killing blow leaves _battle.is_over true the same frame BattleFx
	# starts the family VFX for that hit. Hold the mid-battle bands visible until
	# the fireball / slash / nova + its impact number have played (BattleFx tracks
	# them in _vfx_pending), then swap in VICTORY!/DEFEAT. One await here covers all
	# six is_over callers. No BattleView test drives a flow into _show_results, so
	# the frame delay this adds breaks nothing (grep tests/ 2026-09-08).
	if _fx != null:
		var waited := 0.0
		while _fx.vfx_pending() > 0 and waited < 1.2:  ## v0: hard safety cap
			await get_tree().create_timer(0.05).timeout  ## v0: poll step
			waited += 0.05
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
