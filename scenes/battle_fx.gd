class_name BattleFx
extends RefCounted
## Battle-screen effects layer, extracted verbatim from scenes/battle_view.gd
## (visual round 2, task 1). Owns the cosmetic-only VFX: pooled floating damage
## numbers, bolt/pulse move VFX, portrait shake / white flash / tint pulse,
## centre banner, screen + red vignette washes, enemy break-bar flash. Holds NO
## game rules -- it reads _battle only to map a combatant id to its column/card
## anchor. Constructed once by BattleView (see start_battle); begin_fight() rebinds
## the per-fight Battle / moves list / enemy-column rebuild hook each new fight.
##
## The `vignette` ctor arg is a genuine addition over the view's $Stage/arena/
## party_row trio: _screen_tint / _red_vignette paint $Vignette, which is a
## sibling of $Stage, not a child, so it can't be derived from `stage`.

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

var _stage: Control
var _arena: Control
var _party_row: Control
var _vignette: ColorRect
var _banner: Label
var _battle: Battle
var _moves: Array = []
var _rebuild_enemies: Callable = Callable()  ## view hook: rebuild + refill enemy columns on spawn
var _num_pool: Array[Label] = []  ## Task 7: pooled floating damage-number Labels under $Stage
var _num_next: int = 0  ## Task 7: round-robin cursor into _num_pool
var _banner_tween: Tween = null  ## Task 7 review: kill an in-flight banner tween before a new one
var _shake_tweens: Dictionary = {}  ## final review I2: Control -> live shake Tween, so an
## overlapping shake on the same node kills the old one instead of stranding it mid-offset
var _vfx_pool: Array[Control] = []  ## Battle VFX Polish §3: pooled bolt/pulse nodes under $Stage
var _vfx_next: int = 0  ## round-robin cursor into _vfx_pool, mirrors _num_pool/_num_next


func _init(stage: Control, arena: Control, party_row: Control, vignette: ColorRect) -> void:
	_stage = stage
	_arena = arena
	_party_row = party_row
	_vignette = vignette
	_banner = stage.get_node("Banner")


## Rebind the per-fight state each new fight (BattleView.start_battle). `battle`
## drives anchor lookups; `moves` resolves a move_id's VFX style; `rebuild_enemies`
## is the view callable that rebuilds + refills the enemy columns when a boss spawns.
func begin_fight(battle: Battle, moves: Array, rebuild_enemies: Callable) -> void:
	_battle = battle
	_moves = moves
	_rebuild_enemies = rebuild_enemies


## Task 7: eight reusable floating-number Labels under $Stage, hidden until
## _pop_number lifts one. Safe to re-call (any prior pool is freed first).
## The trailing move_child raises $Stage/Banner back above the L0..L2 ticker
## labels (built later) so _banner_fx reads on top.
func build_number_pool() -> void:
	for old_lbl in _num_pool:
		if is_instance_valid(old_lbl):
			_stage.remove_child(old_lbl)
			old_lbl.queue_free()
	_num_pool.clear()
	_num_next = 0
	for _i in 8:  ## v0: pool size
		var lbl := Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 34)  ## v0
		_stage.add_child(lbl)
		_num_pool.append(lbl)
	_stage.move_child(_banner, _stage.get_child_count() - 1)


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
	var stage: Control = _stage
	var origin := anchor.get_global_position() + anchor.size * 0.5 - stage.get_global_position()
	lbl.position = origin
	lbl.modulate = Color(1, 1, 1, 1)
	lbl.visible = true
	# final review I1: bind to the Label, not BattleView, so a pool rebuild
	# (build_number_pool, M3) auto-kills any in-flight rise/fade instead of it later
	# touching a freed instance.
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", origin.y - (60.0 if big else 40.0), 0.7)  ## v0
	t.tween_property(lbl, "modulate:a", 0.0, 0.7)  ## v0
	t.chain().tween_callback(
		func() -> void:
			if is_instance_valid(lbl):
				lbl.visible = false
	)


## Battle VFX Polish §3: pure move_type -> VFX style. Unknown/absent types fall
## to physical's style ("bolt") -- same fallback _move_vfx_for_event uses, so the
## helper and the production path can't disagree (final review M2).
static func _vfx_style_for_move_type(move_type: String) -> String:
	return String(MOVE_VFX.get(move_type, MOVE_VFX["physical"]).get("style", "bolt"))


## Battle VFX Polish §3: resolve the {style, color} an event renders with.
## Player moves carry `move_id`; Ultimates / raw enemy hits carry `atk_type`;
## passive heals/ticks (poison_tick, regen_tick, lifesteal, devour_heal,
## leech_heal) carry neither -- poison -> physical bolt, heals -> green pulse.
## Style via _vfx_style_for_move_type so this path + the pure helper agree (M2).
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
			"regen_tick", "lifesteal", "devour_heal", "leech_heal":
				move_type = "heal"
			_:
				move_type = "physical"
	var entry: Dictionary = MOVE_VFX.get(move_type, MOVE_VFX["physical"])
	return {"style": _vfx_style_for_move_type(move_type), "color": entry["color"]}


## Battle VFX Polish §3: 6 pooled Controls under $Stage, each usable as a "bolt"
## (filled circle that tweens position caster->target) or a "pulse" (scales/fades
## in place on the target) -- same node, only its _draw() state differs per use.
## Pooled + round-robin, mirroring _num_pool/_num_next exactly.
func build_vfx_pool() -> void:
	for old in _vfx_pool:
		if is_instance_valid(old):
			_stage.remove_child(old)
			old.queue_free()
	_vfx_pool.clear()
	_vfx_next = 0
	for i in 6:  ## v0: enough for a 4-target AoE with headroom
		var node := Control.new()
		node.name = "VfxSlot%d" % i
		node.visible = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(24, 24)  ## v0
		node.pivot_offset = node.size * 0.5  ## final review M3: pulse scales from centre
		node.set_meta("radius", 8.0)  ## v0, read by the shared _draw below
		node.set_meta("draw_color", Color.WHITE)
		node.draw.connect(_draw_vfx_node.bind(node))
		_stage.add_child(node)
		_vfx_pool.append(node)
	# final review M4: these 6 nodes append AFTER build_number_pool's banner-raise,
	# so re-raise the banner or bolts/pulses draw over BREAK! / PHASE 2.
	_stage.move_child(_banner, _stage.get_child_count() - 1)


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
	var target_anchor := anchor_for(target_id)
	if _vfx_pool.is_empty() or target_anchor == null:
		on_arrive.call()
		return
	var stage: Control = _stage
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
		var actor_anchor := anchor_for(actor_id)
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
		node.scale = Vector2(0.3, 0.3)  ## v0
		node.modulate.a = 0.0
		node.queue_redraw()
		# final review I2: alpha in/out is one delayed sub-sequence INSIDE the parallel
		# step (not a chained step), so on_arrive chains at ~_PULSE_TIME, not ~0.64s.
		var t := node.create_tween()
		t.set_parallel(true)
		t.tween_property(node, "scale", Vector2(1.4, 1.4), _PULSE_TIME)  ## v0
		t.tween_property(node, "modulate:a", 1.0, _PULSE_TIME * 0.4)  ## v0
		t.tween_property(node, "modulate:a", 0.0, _PULSE_TIME * 0.6).set_delay(_PULSE_TIME * 0.4)  ## v0
		t.chain().tween_callback(
			func() -> void:
				node.visible = false
				on_arrive.call()
		)


## Task 7: replay this tick's freshly-consumed _battle.log slice (Task 6's
## _last_consumed) as cosmetic beats -- floating numbers, shake, white flash,
## centre banner, red vignette, Ultimate gold tint. Reads nothing back and
## changes no pacing; `_:` types are already covered by the ticker.
func play_new_events(events: Array) -> void:
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
				enemy_bar_flash(String(ev.get("target_id", "")))
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
				if _rebuild_enemies.is_valid():
					_rebuild_enemies.call()
			_:
				pass


## Task 7: an incoming hit on `target_id` -- a rising damage number (grey
## em-dash if it did nothing, gold + larger on a crit / big hit), a positional
## shake, a white flash on the portrait, and, only for a boss BIG HIT (`big`),
## a red screen pulse.
func _hit_fx(target_id: String, dmg: int, crit: bool, big: bool) -> void:
	var anchor := anchor_for(target_id)
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
	var anchor := anchor_for(id)
	_pop_number(anchor, "+%d" % amt, Color(0.5, 0.95, 0.6), false)  ## v0: green
	_tint_pulse(anchor, Color(0.5, 1.2, 0.6))  ## v0: over-bright green


## Task 7: nudge `node` left / right around its resting x and settle back.
## Bound to `node`'s own tween so a freed target auto-kills it. Rest x is
## stored as metadata on first shake and always used as the base; any prior
## shake tween on the node is killed and the node restored to rest first, so
## overlapping shakes can't strand it mid-offset.
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
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.7, 0.7)  ## v0
	_banner.modulate = Color(1, 1, 1, 1)
	_banner.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	var t := _banner.create_tween()
	_banner_tween = t
	t.tween_property(_banner, "scale", Vector2(1.1, 1.1), 0.2)  ## v0
	t.tween_property(_banner, "scale", Vector2.ONE, 0.15)  ## v0
	t.tween_property(_banner, "modulate:a", 0.0, 0.25)  ## v0
	t.tween_callback(func() -> void: _banner.visible = false)


## Task 7: wash the full-screen vignette with `col`, then fade its alpha to 0
## over 0.25 s and hide it.
func _screen_tint(col: Color) -> void:
	_vignette.color = col
	_vignette.visible = true
	var t := _vignette.create_tween()
	t.tween_property(_vignette, "color:a", 0.0, 0.25)  ## v0
	t.tween_callback(func() -> void: _vignette.visible = false)


## Task 7: the boss BIG HIT variant of _screen_tint.
func _red_vignette() -> void:
	_screen_tint(Color(0.8, 0.1, 0.1, 0.35))  ## v0


## Task 7: flash the break capsule of whichever enemy column owns `id`.
func enemy_bar_flash(id: String) -> void:
	for i in _battle.enemies.size():
		if String(_battle.enemies[i]["id"]) == id:
			var bar := _arena.get_node_or_null("E%d/brkbar" % i)
			if bar is StatBar:
				(bar as StatBar).flash()
			return


## Task 7: the Control a floating number / shake / flash anchors to for combat
## id `id` -- the enemy column's portrait, else the party card's thumb, else
## $Stage as a safe fallback so callers never get null.
func anchor_for(id: String) -> Control:
	for i in _battle.enemies.size():
		if String(_battle.enemies[i]["id"]) == id:
			var pic := _arena.get_node_or_null("E%d/pics/pic" % i)
			if pic is Control:
				return pic as Control
	for i in _battle.party.size():
		if String(_battle.party[i]["id"]) == id:
			var thumb := _party_row.get_node_or_null("P%d/thumb" % i)
			if thumb is Control:
				return thumb as Control
	return _stage as Control
