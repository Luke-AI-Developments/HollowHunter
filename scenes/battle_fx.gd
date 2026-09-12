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

## Battle VFX Families (design 2026-09-05): per-family v0 default colour for the
## missing-block fallback in _fallback_family and the Task-4 atk_type / tick
## stubs -- used only when a move carries no authored `vfx` block (or none at
## all, for enemy hits / passive ticks). Authored moves override every value.
const _FAMILY_DEFAULT_COLOR := {
	"slash": Color(0.91, 0.91, 0.87),  ## v0: pale steel
	"fireball": Color(0.55, 0.75, 1.0),  ## v0: cyan-blue
	"nova": Color(0.62, 0.85, 1.0),  ## v0: ice-blue
	"pulse": Color(0.55, 0.95, 0.7),  ## v0: green
}

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
## Task 5 (bug B2): count of family VFX whose visible motion + on_arrive impact fx
## are still in flight. Incremented ONCE per _fx_* invocation -- in _play_move_family
## (every dispatch arm calls exactly one terminal _fx_*) and in _emit_one_nova (the
## coalesced multi-target ring, which bypasses _play_move_family); decremented in each
## family's terminal tween_callback and defensively on every anchor-less early-out.
## BattleView._show_results() awaits this hitting 0 (or a 1.2s cap) before it swaps
## the mid-battle bands for VICTORY!/DEFEAT, so the killing-blow animation is seen.
var _vfx_pending: int = 0


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
	_vfx_pending = 0  ## Task 5: a fresh fight never inherits a torn-down fight's stuck count


## Task 5 (bug B2): outstanding in-flight family VFX. BattleView._show_results()
## polls this and holds the results screen until it returns to 0 (or its 1.2s cap).
func vfx_pending() -> int:
	return _vfx_pending


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


## Battle VFX Families (design 2026-09-05): resolve an event to the family it
## renders with -- {family: String, color: Color, scale: float}. Player moves
## carry `move_id` -> the move's authored `vfx` block, else a move_type /
## target_type fallback (_fallback_family). Ultimates / raw enemy hits carry
## `atk_type` (_atk_type_family -- Task 4). Passive ticks carry neither and go by
## `ev.type` (_tick_family -- Task 4). Supersedes the VFX-polish MOVE_VFX /
## _vfx_style_for_move_type path (both deleted).
func _move_vfx_for_event(ev: Dictionary) -> Dictionary:
	var move_id := String(ev.get("move_id", ""))
	if move_id != "":
		var move: Dictionary = Content.move_by_id(_moves, move_id)
		var v: Dictionary = move.get("vfx", {})
		var out: Dictionary
		if v.has("family") and v.get("color") is Color and float(v.get("scale", 0.0)) > 0.0:
			out = {
				"family": String(v["family"]),
				"color": v["color"],
				"scale": float(v["scale"]),
			}
		else:
			out = _fallback_family(move)
		## v0: Weaken-style debuff pulse shows no +N; Reconstitute adds the lift beam.
		if String(move.get("move_type", "")) == "debuff":
			out["no_number"] = true
		if String(move.get("target_type", "")) == "downed_ally":
			out["lift"] = true
		return out
	if String(ev.get("atk_type", "")) != "":
		return _atk_type_family(ev)
	return _tick_family(ev)


## Missing / partial `vfx` block (spec "Missing-block fallback"): derive the
## family from the move's move_type + target_type -- physical -> slash; magic +
## single_enemy -> fireball; magic + all_enemies -> nova; heal / buff / cleanse /
## revive / taunt / debuff -> pulse; anything else -> slash. Per-family v0 default
## colour, scale 1.0.
func _fallback_family(move: Dictionary) -> Dictionary:
	var mt := String(move.get("move_type", ""))
	var tt := String(move.get("target_type", ""))
	var fam := "slash"  ## v0: default for anything unmapped
	if mt == "magic" and tt == "single_enemy":
		fam = "fireball"
	elif mt == "magic" and tt == "all_enemies":
		fam = "nova"
	elif mt in ["heal", "buff", "cleanse", "revive", "taunt", "debuff"]:
		fam = "pulse"
	var out := {"family": fam, "color": _FAMILY_DEFAULT_COLOR[fam], "scale": 1.0}
	if mt == "debuff":
		out["no_number"] = true  ## v0: Weaken debuff shows no +N
	if tt == "downed_ally":
		out["lift"] = true  ## v0: Reconstitute lift beam
	return out


## Enemy attacks and Ultimate-attributed `damage` events carry `atk_type` but no
## `move_id`. magic -> fireball / violet; physical (or anything else) -> slash /
## dull red-bone. scale: an Ultimate `damage` (distinguished by `type == "damage"`
## -- a player-move `damage` never reaches here, it took the `move_id` branch;
## `enemy_attack` events carry `type == "enemy_attack"`) -> 1.5; a plain
## `enemy_attack` -> 1.4 if telegraphed (`big_hit`) else 1.0. The subclass Ultimate
## colour is not on the event, so just use the atk_type default (spec note).
func _atk_type_family(ev: Dictionary) -> Dictionary:
	var is_magic := String(ev.get("atk_type", "")) == "magic"
	var fam := "fireball" if is_magic else "slash"
	## v0: magic -> violet; physical / other -> dull red / bone
	var col := Color(0.77, 0.52, 0.9) if is_magic else Color(0.85, 0.55, 0.5)
	var sc := 1.0  ## v0: plain enemy_attack
	if String(ev.get("type", "")) == "damage":
		sc = 1.5  ## v0: Ultimate-attributed damage
	elif bool(ev.get("big_hit", false)):
		sc = 1.4  ## v0: telegraphed big hit
	return {"family": fam, "color": col, "scale": sc}


## Passive ticks carry neither move_id nor atk_type -- go by ev.type. poison_tick
## is a small green in-place pulse with NO floating "+N" (`no_number`); regen /
## lifesteal / devour / leech ticks are a slightly larger green pulse WITH the "+N".
func _tick_family(ev: Dictionary) -> Dictionary:
	if String(ev.get("type", "")) == "poison_tick":
		## v0: green, no +N
		return {"family": "pulse", "color": Color(0.5, 0.85, 0.4), "scale": 0.7, "no_number": true}
	## v0: green, with +N
	return {"family": "pulse", "color": Color(0.5, 0.88, 0.6), "scale": 0.8}


## Battle VFX Families: 10 pooled Controls under $Stage, drawn by _draw_vfx_node
## dispatching on each node's `family` meta as a slash / fireball / burst / nova /
## pulse -- only that meta + the params the tween writes differ per use. Pooled +
## round-robin, mirroring _num_pool/_num_next exactly.
func build_vfx_pool() -> void:
	for old in _vfx_pool:
		if is_instance_valid(old):
			_stage.remove_child(old)
			old.queue_free()
	_vfx_pool.clear()
	_vfx_next = 0
	for i in 10:  ## v0: AoE headroom -- nova/cleave fire several pooled nodes at once
		var node := Control.new()
		node.name = "VfxSlot%d" % i
		node.visible = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(24, 24)  ## v0
		node.pivot_offset = node.size * 0.5  ## final review M3: pulse scales from centre
		node.set_meta("family", "circle")  ## v0: draw-dispatch key; _fx_* routines overwrite
		node.set_meta("radius", 8.0)  ## v0, read by the shared _draw below
		node.set_meta("draw_color", Color.WHITE)
		node.draw.connect(_draw_vfx_node.bind(node))
		_stage.add_child(node)
		_vfx_pool.append(node)
	# final review M4: these 10 nodes append AFTER build_number_pool's banner-raise,
	# so re-raise the banner or the VFX draw over BREAK! / PHASE 2.
	_stage.move_child(_banner, _stage.get_child_count() - 1)


## Shared _draw() for every pooled VFX node -- branches on the "family" meta the
## caller set. All geometry is node-local around `c` (the node centre); the tween
## drives the animated params (radius, sweep, ring width, alpha) through metas and
## a queue_redraw(). "circle" is the filled disc -- the nova flash-disc branch.
func _draw_vfx_node(node: Control) -> void:
	var c: Vector2 = node.size * 0.5
	var col: Color = node.get_meta("draw_color", Color.WHITE)
	match String(node.get_meta("family", "circle")):
		"slash":
			_draw_slash(node, c, col)
		"fireball":
			_draw_fireball(node, c, col)
		"burst":
			var br: float = node.get_meta("burst_r", 10.0)
			var bw: float = node.get_meta("burst_width", 3.0)
			node.draw_arc(c, maxf(br, 0.5), 0.0, TAU, 48, col, bw, true)  ## v0
		"nova":
			_draw_nova(node, c, col)
		"pulse":
			_draw_pulse(node, c, col)
		_:
			var radius: float = node.get_meta("radius", 8.0)
			node.draw_circle(c, radius, col)  ## v0: centred in the 24x24 node


## Battle VFX Families: dispatch a resolved {family, color, scale} to its family
## routine, binding `on_arrive` (a _hit_fx / _heal_fx closure -- the SAME args the
## retired _play_move_vfx bound) to that family's impact moment. `delay` staggers
## a slash-AoE run down the enemy line (ignored by every other family -- pulse
## `all_allies` stays evenly spaced by the pool round-robin, per spec). Unknown
## family -> slash as a safe fallback. Purely cosmetic timing: core/battle.gd
## already resolved the whole turn synchronously before this runs.
func _play_move_family(
	fam: Dictionary, actor_id: String, target_id: String, on_arrive: Callable, delay: float = 0.0
) -> void:
	## Task 5 (bug B2): one increment per dispatch -- every arm below (incl. the `_:`
	## fallback) calls exactly one terminal _fx_*; that routine's terminal callback (or
	## its anchor-less early-out) owns the matching decrement.
	_vfx_pending += 1
	var famname := String(fam["family"])
	var col: Color = fam["color"]
	var sc := float(fam["scale"])
	match famname:
		"slash":
			_fx_slash(col, sc, anchor_for(target_id), on_arrive, delay)
		"fireball":
			_fx_fireball(col, sc, anchor_for(actor_id), anchor_for(target_id), on_arrive)
		"nova":
			_fx_nova(
				col,
				sc,
				_anchor_centre_for(target_id),
				[{"anchor": anchor_for(target_id), "on_arrive": on_arrive}]
			)
		"pulse":
			var flags := {}
			if fam.get("no_number", false):
				flags["no_number"] = true
			if fam.get("lift", false):
				flags["lift"] = true
			_fx_pulse(col, sc, anchor_for(target_id), on_arrive, flags)
		_:
			_fx_slash(col, sc, anchor_for(target_id), on_arrive, delay)  ## v0: safe fallback


## _stage-local centre of the anchor for combat id `id` -- the String-keyed
## sibling of _anchor_centre(Control). anchor_for's null fallback is _stage
## itself, so guard that to a usable mid-stage point (nova centring must never
## key off a bad value).
func _anchor_centre_for(id: String) -> Vector2:
	var a := anchor_for(id)
	if a == _stage:
		return _stage.size * 0.5
	return _anchor_centre(a)


## Indices into `events` of the "move events" -- those carrying BOTH a non-empty
## actor_id and a non-empty move_id. Everything else (break_fill / break / phase /
## spawn / ultimate / raw ticks) is a cosmetic or non-move event that core/
## battle.gd::_land_hit can interleave between a boss's and an add's damage
## events, and MUST NOT split an AoE run (review fix 1).
func _move_event_indices(events: Array) -> Array:
	var out: Array = []
	for i in events.size():
		var ev: Dictionary = events[i]
		if String(ev.get("actor_id", "")) != "" and String(ev.get("move_id", "")) != "":
			out.append(i)
	return out


## Run-local index of events[idx] among the *move events* sharing its non-empty
## actor_id + move_id (counting only move events, so an interleaved break / phase
## event adds no gap -- review fix 1). 0 for a lone event / non-move event. slash
## AoE -- Cleave logs one `damage` event per living enemy -- reads this * 0.06s
## as its _fx_slash `delay` so the crescents sweep down the line.
func _run_offset(events: Array, idx: int) -> int:
	var aid := String(events[idx].get("actor_id", ""))
	var mid := String(events[idx].get("move_id", ""))
	if aid == "" or mid == "":
		return 0
	var off := 0
	for j in idx:
		if (
			String(events[j].get("actor_id", "")) == aid
			and String(events[j].get("move_id", "")) == mid
		):
			off += 1
	return off


## Battle VFX Families AoE pass (spec "AoE handling" + review fix 1): group the
## batch's move events (via _move_event_indices, so interleaved actor-less
## cosmetic events don't split a run) into maximal runs sharing actor_id +
## move_id. A run of >= 2 whose family resolves to "nova" collapses into ONE
## _fx_nova (see _emit_one_nova); its damage-event indices go in the returned
## skip-set so the main loop `continue`s past them (the cosmetic events are left
## in for the main loop to render). slash runs are NOT coalesced -- they stagger
## via _run_offset; pulse `all_allies` runs are left entirely to the main loop.
func _emit_nova_runs(events: Array) -> Dictionary:
	var skip := {}
	var moves: Array = _move_event_indices(events)
	var a := 0
	while a < moves.size():
		var first: Dictionary = events[moves[a]]
		var aid := String(first.get("actor_id", ""))
		var mid := String(first.get("move_id", ""))
		var b := a + 1
		while (
			b < moves.size()
			and String(events[moves[b]].get("actor_id", "")) == aid
			and String(events[moves[b]].get("move_id", "")) == mid
		):
			b += 1
		if b - a >= 2 and String(_move_vfx_for_event(first).get("family", "")) == "nova":
			var run: Array = moves.slice(a, b)
			_emit_one_nova(events, run)
			for idx in run:
				skip[idx] = true
		a = b
	return skip


## Emit the single coalesced _fx_nova for a nova run given as explicit `idxs` into
## `events` (review fix 1: the run's damage events may be non-adjacent). centre =
## average of each entry's target-anchor centre (an approximation of the
## living-enemy-line centre; good enough for v0), one {anchor, on_arrive} per
## entry with on_arrive bound to that entry's own _hit_fx so each hit fires the
## frame the ring passes it.
func _emit_one_nova(events: Array, idxs: Array) -> void:
	var fam := _move_vfx_for_event(events[idxs[0]])
	var col: Color = fam["color"]
	var sc := float(fam["scale"])
	var hits: Array = []
	var sum := Vector2.ZERO
	for idx in idxs:
		var ev: Dictionary = events[idx]
		var tgt := String(ev.get("target_id", ""))
		var d := int(ev.get("damage", 0))
		var cr := bool(ev.get("crit", false))
		sum += _anchor_centre_for(tgt)
		hits.append(
			{
				"anchor": anchor_for(tgt),
				"on_arrive": func() -> void: _hit_fx(tgt, d, cr, false),
			}
		)
	## Task 5 (bug B2): the coalesced ring bypasses _play_move_family -- count it here,
	## once per _fx_nova call (one ring = one terminal decrement in _nova_finish),
	## matching the "once per _fx_* invocation" rule.
	_vfx_pending += 1
	_fx_nova(col, sc, sum / float(idxs.size()), hits)


## Task 7: replay this tick's freshly-consumed _battle.log slice (Task 6's
## _last_consumed) as cosmetic beats -- floating numbers, shake, white flash,
## centre banner, red vignette, Ultimate gold tint. Reads nothing back and
## changes no pacing; `_:` types are already covered by the ticker.
func play_new_events(events: Array) -> void:
	var skip := _emit_nova_runs(events)  ## nova-AoE coalescing: one ring per run
	for i in events.size():
		if skip.has(i):
			continue
		var ev: Dictionary = events[i]
		match String(ev.get("type", "")):
			"damage", "poison_tick":
				var target_id := String(ev.get("target_id", ""))
				var dmg := int(ev.get("damage", 0))
				var crit := bool(ev.get("crit", false))
				var fam := _move_vfx_for_event(ev)
				_play_move_family(
					fam,
					String(ev.get("actor_id", "")),
					target_id,
					func() -> void: _hit_fx(target_id, dmg, crit, false),
					_run_offset(events, i) * 0.06  ## v0: slash-AoE stagger down the line
				)
			"enemy_attack":
				var target_id := String(ev.get("target_id", ""))
				var dmg := int(ev.get("damage", 0))
				var big := bool(ev.get("big_hit", false))
				var fam := _move_vfx_for_event(ev)
				_play_move_family(
					fam,
					String(ev.get("actor_id", "")),
					target_id,
					func() -> void: _hit_fx(target_id, dmg, big, big),
					_run_offset(events, i) * 0.06  ## v0
				)
			"heal", "regen_tick", "devour_heal", "leech_heal", "lifesteal":
				var who := String(ev.get("target_id", ev.get("actor_id", "")))
				var amt := int(ev.get("amount", 0))
				var fam := _move_vfx_for_event(ev)
				_play_move_family(
					fam, String(ev.get("actor_id", who)), who, func() -> void: _heal_fx(who, amt)
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
## id `id` -- the enemy column's portrait, else the party card's portrait, else
## $Stage as a safe fallback so callers never get null.
func anchor_for(id: String) -> Control:
	for i in _battle.enemies.size():
		if String(_battle.enemies[i]["id"]) == id:
			var pic := _arena.get_node_or_null("E%d/pics/pic" % i)
			if pic is Control:
				return pic as Control
	for i in _battle.party.size():
		if String(_battle.party[i]["id"]) == id:
			var pnode := _party_row.get_node_or_null("P%d/portrait" % i)
			if pnode is Control:
				return pnode as Control
	return _stage as Control


## --- Battle VFX Families (design 2026-09-05) ---------------------------------
## Four shared draw + Tween routines (slash / fireball / nova / pulse, plus the
## fireball's burst sub-effect) that supersede the bolt/pulse generic. Colour and
## `scale` are the only per-move variance. Each draws on one (AoE families: two)
## pooled Control, animates purely via a node-bound create_tween(), and fires
## `on_arrive` at that family's impact moment -- all under ADVANCE_DELAY (0.6s) so
## the next AI turn can't stomp the hit fx. NOT wired into play_new_events yet;
## that is families task 3.


## Centre of `anchor` in _stage-local coords -- the idiom _pop_number /
## _anchor_centre_for use (the caller still subtracts node.size*0.5 to place a node).
func _anchor_centre(anchor: Control) -> Vector2:
	return anchor.get_global_position() + anchor.size * 0.5 - _stage.get_global_position()


## Return a pooled node to a clean rest state before a family reuses it (mirrors
## the visible/scale/modulate/position resets the _fx_* routines expect).
func _reset_vfx_node(node: Control) -> void:
	node.visible = false
	node.scale = Vector2.ONE
	node.rotation = 0.0
	node.modulate = Color(1, 1, 1, 1)
	node.position = Vector2.ZERO


## Generic tween_method sink: write `value` to meta `key`, then queue a redraw.
func _vfx_set(value: float, node: Control, key: String) -> void:
	node.set_meta(key, value)
	node.queue_redraw()


## Toggle the slash impact-line flag (drawn ~0.14-0.34s) and redraw.
func _slash_impact(node: Control, on: bool) -> void:
	node.set_meta("slash_impact", 1.0 if on else 0.0)  ## v0
	node.queue_redraw()


## slash -- melee. A crescent arc that sweeps ~115 deg across the target in place
## (no travel), with 2 trailing ghost copies for motion blur, a bright inner edge,
## and a white impact line at the sweep end. `delay` staggers the per-enemy calls
## of an AoE cleave. on_arrive fires at ~0.16s; the node fades out over ~0.4s.
func _fx_slash(
	col: Color, scale: float, target_anchor: Control, on_arrive: Callable, delay: float = 0.0
) -> void:
	if _vfx_pool.is_empty() or target_anchor == null:
		on_arrive.call()
		_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: no tween -> no terminal callback
		return
	var node := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(node)
	node.position = _anchor_centre(target_anchor) - node.size * 0.5
	node.set_meta("family", "slash")
	node.set_meta("draw_color", col)
	node.set_meta("slash_radius", 30.0 * scale)  ## v0
	node.set_meta("slash_width", 7.5 * scale)  ## v0
	node.set_meta("slash_edge", col.lightened(0.55))  ## v0
	node.set_meta("slash_k", 0.0)
	node.set_meta("slash_impact", 0.0)
	node.queue_redraw()
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_callback(func() -> void: node.visible = true).set_delay(delay)
	t.tween_method(_vfx_set.bind(node, "slash_k"), 0.0, 1.0, 0.18).set_delay(delay)  ## v0
	t.tween_callback(_slash_impact.bind(node, true)).set_delay(delay + 0.14)  ## v0
	t.tween_callback(on_arrive).set_delay(delay + 0.16)  ## v0
	t.tween_callback(_slash_impact.bind(node, false)).set_delay(delay + 0.34)  ## v0
	t.tween_property(node, "modulate:a", 0.0, 0.4).set_delay(delay + 0.18)  ## v0
	t.chain().tween_callback(
		func() -> void:
			node.visible = false
			_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: slash terminal
	)


func _draw_slash(node: Control, c: Vector2, col: Color) -> void:
	var radius: float = node.get_meta("slash_radius", 30.0)
	var width: float = node.get_meta("slash_width", 7.5)
	var edge: Color = node.get_meta("slash_edge", col)
	var k: float = node.get_meta("slash_k", 0.0)
	var ke: float = 1.0 - pow(1.0 - k, 2.0)  ## v0: ease-out sweep
	var a0 := deg_to_rad(215.0)  ## v0: sweep start (down-left)
	var a1 := a0 + deg_to_rad(115.0) * ke  ## v0: 115 deg total sweep
	var g1 := col
	g1.a = col.a * 0.4  ## v0: ghost 1 alpha
	var g2 := col
	g2.a = col.a * 0.2  ## v0: ghost 2 alpha
	node.draw_arc(c, radius, a0 - 0.55, a1 - 0.55, 24, g2, width, true)  ## v0: -0.55 rad ghost
	node.draw_arc(c, radius, a0 - 0.28, a1 - 0.28, 24, g1, width, true)  ## v0: -0.28 rad ghost
	node.draw_arc(c, radius, a0, a1, 28, col, width, true)  ## v0: 28-seg body arc
	node.draw_arc(c, radius - width * 0.35, a0, a1, 28, edge, maxf(width * 0.4, 1.0), true)  ## v0
	if float(node.get_meta("slash_impact", 0.0)) > 0.0:
		var dir := Vector2(cos(a1), sin(a1))
		var perp := Vector2(-dir.y, dir.x) * radius * 0.9  ## v0: impact line half-length
		var p := c + dir * radius
		var wcol := col.lightened(0.8)  ## v0
		node.draw_line(p - perp, p + perp, Color(1, 1, 1, 0.5), width * 1.6)  ## v0: white glow
		node.draw_line(p - perp, p + perp, wcol, width * 0.5)  ## v0


## fireball -- magic single-target. A soft blob (core + 2 glow rings + 3-seg tail)
## travels from_anchor -> to_anchor along a slight upward quad-bezier over ~0.32s;
## on arrival it spawns a burst and fires on_arrive. Null from_anchor -> no travel.
func _fx_fireball(
	col: Color, scale: float, from_anchor: Control, to_anchor: Control, on_arrive: Callable
) -> void:
	if _vfx_pool.is_empty() or to_anchor == null:
		on_arrive.call()
		_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: no tween -> no terminal callback
		return
	var node := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(node)
	var p1 := _anchor_centre(to_anchor)
	var p0 := p1
	if from_anchor != null:
		p0 = _anchor_centre(from_anchor)
	var pc := p0.lerp(p1, 0.5) + Vector2(0.0, -40.0 * scale)  ## v0: upward bow
	node.position = p0 - node.size * 0.5
	node.set_meta("family", "fireball")
	node.set_meta("draw_color", col)
	node.set_meta("fb_core", 7.0 * scale)  ## v0
	var d0 := Vector2.RIGHT if p0.is_equal_approx(p1) else (p1 - p0).normalized()
	node.set_meta("fb_dir", d0)
	node.visible = true
	node.queue_redraw()
	var t := node.create_tween()
	t.tween_method(_fireball_step.bind(node, p0, pc, p1), 0.0, 1.0, 0.32)  ## v0
	t.tween_callback(_fireball_arrive.bind(node, col, scale, p1, on_arrive))
	## Task 5: _fireball_arrive runs on_arrive itself, so the terminal decrement is a
	## trailing callback held ~0.2s (the _fx_burst ring's life) past arrival -- keeps
	## the results hold up through the burst, mirroring slash/nova/pulse's post-arrive
	## terminal.
	t.tween_interval(0.2)  ## v0: _fx_burst ring life
	t.tween_callback(func() -> void: _vfx_pending = max(_vfx_pending - 1, 0))


func _fireball_step(t: float, node: Control, p0: Vector2, pc: Vector2, p1: Vector2) -> void:
	var te: float = lerpf(t, t * t, 0.6)  ## v0: ease-in blended toward linear
	var u := 1.0 - te
	node.position = (p0 * (u * u) + pc * (2.0 * u * te) + p1 * (te * te)) - node.size * 0.5
	var deriv := (pc - p0) * (2.0 * u) + (p1 - pc) * (2.0 * te)
	if deriv.length() > 0.01:
		node.set_meta("fb_dir", deriv.normalized())
	node.queue_redraw()


func _fireball_arrive(
	node: Control, col: Color, scale: float, centre: Vector2, on_arrive: Callable
) -> void:
	node.visible = false
	_fx_burst(col, scale, centre)
	on_arrive.call()


func _draw_fireball(node: Control, c: Vector2, col: Color) -> void:
	var r: float = node.get_meta("fb_core", 7.0)
	var dir: Vector2 = node.get_meta("fb_dir", Vector2.RIGHT)
	for i in 3:  ## v0: 3-segment tail behind travel
		var seg := col
		seg.a = col.a * 0.28 * (1.0 - i / 3.0)  ## v0
		var back := c - dir * (r * 1.4 * (i + 1))  ## v0
		node.draw_circle(back, maxf(r - r * 0.22 * (i + 1), 0.5), seg)  ## v0
	var glow_a := col
	glow_a.a = col.a * 0.3  ## v0
	var glow_b := col
	glow_b.a = col.a * 0.14  ## v0
	node.draw_circle(c, r * 2.3, glow_b)  ## v0
	node.draw_circle(c, r * 1.5, glow_a)  ## v0
	node.draw_circle(c, r, col.lightened(0.6))  ## v0: core


## burst -- the ring flash a fireball leaves on impact; also its own sub-effect so
## other families can reuse it. Ring r 10 -> ~44*scale over ~0.2s, alpha 1 -> 0.
func _fx_burst(col: Color, scale: float, centre: Vector2) -> void:
	if _vfx_pool.is_empty():
		return
	var node := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(node)
	node.position = centre - node.size * 0.5
	node.set_meta("family", "burst")
	node.set_meta("draw_color", col.lightened(0.4))  ## v0
	node.set_meta("burst_r", 10.0)  ## v0
	node.set_meta("burst_width", maxf(3.0 * scale, 1.0))  ## v0
	node.visible = true
	node.queue_redraw()
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_method(_vfx_set.bind(node, "burst_r"), 10.0, 44.0 * scale, 0.2)  ## v0
	t.tween_property(node, "modulate:a", 0.0, 0.2)  ## v0
	t.chain().tween_callback(func() -> void: node.visible = false)


## nova -- magic AoE. A flash disc (<~0.09s, reuses the "circle" draw branch) then
## an expanding stroked ring (r 0 -> ~230*scale over ~0.36s, width 10 -> 2, alpha
## 1 -> 0) with a faint inner trail ring at r*0.8. `centre` is already _stage-local
## (families task 3 computes it). Each `hits` entry {anchor, on_arrive} fires the
## frame the ring radius reaches that anchor's distance from centre; any the ring
## never reaches still fire on the terminal callback so the game can't stall.
func _fx_nova(col: Color, scale: float, centre: Vector2, hits: Array) -> void:
	if hits.is_empty():
		_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: caller pre-incremented
		return
	if _vfx_pool.size() < 2:
		for h: Dictionary in hits:
			(h.get("on_arrive") as Callable).call()
		_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: no tween -> no _nova_finish
		return
	var disc := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(disc)
	disc.position = centre - disc.size * 0.5
	disc.set_meta("family", "circle")
	disc.set_meta("draw_color", col.lightened(0.7))  ## v0
	disc.set_meta("radius", 46.0 * scale)  ## v0
	disc.visible = true
	disc.queue_redraw()
	var dt := disc.create_tween()
	dt.set_parallel(true)
	dt.tween_method(_vfx_set.bind(disc, "radius"), 46.0 * scale, 8.0 * scale, 0.09)  ## v0
	dt.tween_property(disc, "modulate:a", 0.0, 0.09)  ## v0
	dt.chain().tween_callback(func() -> void: disc.visible = false)
	var ring := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(ring)
	ring.position = centre - ring.size * 0.5
	ring.set_meta("family", "nova")
	ring.set_meta("draw_color", col)
	ring.set_meta("nova_r", 0.0)
	ring.set_meta("nova_width", 10.0 * scale)  ## v0
	ring.visible = true
	ring.queue_redraw()
	var dists: Array = []
	var fired: Array = []
	for h: Dictionary in hits:
		var a: Control = h.get("anchor")
		dists.append(0.0 if a == null else _anchor_centre(a).distance_to(centre))
		fired.append(false)
	var max_r := 230.0 * scale  ## v0: nova reach
	var rt := ring.create_tween()
	rt.set_parallel(true)
	rt.tween_method(_nova_step.bind(ring, hits, dists, fired, max_r, scale), 0.0, 1.0, 0.36)  ## v0
	rt.tween_property(ring, "modulate:a", 0.0, 0.36)  ## v0
	rt.chain().tween_callback(_nova_finish.bind(ring, hits, fired))


func _nova_step(
	k: float, ring: Control, hits: Array, dists: Array, fired: Array, max_r: float, sc: float
) -> void:
	var ke: float = 1.0 - pow(1.0 - k, 2.0)  ## v0: ease-out expansion
	var r := ke * max_r
	ring.set_meta("nova_r", r)
	ring.set_meta("nova_width", maxf(lerpf(10.0, 2.0, ke), 1.0) * sc)  ## v0: 10 -> 2 taper
	ring.queue_redraw()
	for i in hits.size():
		if not bool(fired[i]) and r >= float(dists[i]):
			fired[i] = true
			(hits[i].get("on_arrive") as Callable).call()


func _nova_finish(ring: Control, hits: Array, fired: Array) -> void:
	ring.visible = false
	for i in hits.size():
		if not bool(fired[i]):
			fired[i] = true
			(hits[i].get("on_arrive") as Callable).call()
	_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: nova terminal (one ring, N hits -> one)


func _draw_nova(node: Control, c: Vector2, col: Color) -> void:
	var r: float = node.get_meta("nova_r", 0.0)
	var w: float = node.get_meta("nova_width", 10.0)
	if r <= 1.0:
		return
	var inner := col
	inner.a = col.a * 0.35  ## v0: faint trail ring
	node.draw_arc(c, r, 0.0, TAU, 64, col, w, true)  ## v0: 64-seg ring
	node.draw_arc(c, r * 0.8, 0.0, TAU, 64, inner, maxf(w * 0.5, 1.0), true)  ## v0


## pulse -- all support. A ring that grows (r (0.3 + 1.1*ease_out(k)) * 26*scale)
## and fades (alpha sin(k*PI)) in place on the target, an inner ring at r*0.62, and
## 3 motes rising ~30*scale staggered ~40ms. style_flags.lift -> the Reconstitute
## vertical gradient beam; style_flags.no_number -> skip on_arrive (Weaken debuff,
## no "+N"); style_flags.sign ("+"/"-") is reserved. on_arrive fires at ~0.12s.
func _fx_pulse(
	col: Color,
	scale: float,
	target_anchor: Control,
	on_arrive: Callable,
	style_flags: Dictionary = {}
) -> void:
	var no_number := bool(style_flags.get("no_number", false))
	if _vfx_pool.is_empty() or target_anchor == null:
		if not no_number:
			on_arrive.call()
		_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: no tween -> no terminal callback
		return
	var lift := bool(style_flags.get("lift", false))
	var node := _vfx_pool[_vfx_next]
	_vfx_next = (_vfx_next + 1) % _vfx_pool.size()
	_reset_vfx_node(node)
	node.position = _anchor_centre(target_anchor) - node.size * 0.5
	node.set_meta("family", "pulse")
	node.set_meta("draw_color", col)
	node.set_meta("pulse_k", 0.0)
	node.set_meta("pulse_base", 26.0 * scale)  ## v0
	node.set_meta("pulse_mote", 30.0 * scale)  ## v0
	node.set_meta("pulse_scale", scale)
	node.set_meta("pulse_lift", 1.0 if lift else 0.0)
	node.set_meta("pulse_lift_w", 18.0 * scale)  ## v0
	node.set_meta("pulse_lift_h", 100.0 * scale)  ## v0
	node.visible = true
	node.queue_redraw()
	var life: float = 0.5 if lift else 0.4  ## v0
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_method(_vfx_set.bind(node, "pulse_k"), 0.0, 1.0, life)
	if not no_number:
		t.tween_callback(on_arrive).set_delay(0.12)  ## v0
	t.chain().tween_callback(
		func() -> void:
			node.visible = false
			_vfx_pending = max(_vfx_pending - 1, 0)  ## Task 5: pulse terminal
	)


func _draw_pulse(node: Control, c: Vector2, col: Color) -> void:
	var k: float = node.get_meta("pulse_k", 0.0)
	var base: float = node.get_meta("pulse_base", 26.0)
	var mote_rise: float = node.get_meta("pulse_mote", 30.0)
	var sc: float = node.get_meta("pulse_scale", 1.0)
	if float(node.get_meta("pulse_lift", 0.0)) > 0.0:
		_draw_lift_beam(node, c, col, k)
	var eo: float = 1.0 - pow(1.0 - k, 2.0)  ## v0: ease-out ring growth
	var ring_r: float = (0.3 + 1.1 * eo) * base  ## v0
	var rc := col
	rc.a = col.a * clampf(sin(k * PI), 0.0, 1.0)  ## in-then-out
	node.draw_arc(c, ring_r, 0.0, TAU, 48, rc, maxf(3.0 * sc, 1.0), true)  ## v0
	node.draw_arc(c, ring_r * 0.62, 0.0, TAU, 48, rc, maxf(2.0 * sc, 1.0), true)  ## v0
	for i in 3:  ## v0: 3 motes
		var mp: float = clampf((k - i * 0.1) / 0.7, 0.0, 1.0)  ## v0: 40ms stagger, 0.7-life rise
		if mp <= 0.0:
			continue
		var ang := deg_to_rad(-90.0 + (i - 1) * 34.0)  ## v0: upward fan
		var off := Vector2(cos(ang), sin(ang)) * base * 0.5  ## v0
		off.y -= mote_rise * mp
		var mc := col
		mc.a = col.a * (1.0 - mp)
		node.draw_circle(c + off, maxf(3.0 * sc, 1.5), mc)  ## v0


func _draw_lift_beam(node: Control, c: Vector2, col: Color, k: float) -> void:
	var w: float = node.get_meta("pulse_lift_w", 18.0)
	var h: float = node.get_meta("pulse_lift_h", 100.0)
	var grow: float = clampf(k / 0.4, 0.0, 1.0)  ## v0: rises over the first ~0.2s
	var fade: float = 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)  ## v0: fades over the second half
	var a: float = 0.55 * grow * fade  ## v0: peak alpha
	if a <= 0.0:
		return
	var hw := w * 0.5  ## v0: half-width
	var top := c.y - h * grow
	var mid := c.y - h * grow * 0.5  ## v0: gradient meets at the mid-line
	var clear := Color(col.r, col.g, col.b, 0.0)
	var bright := Color(col.r, col.g, col.b, a)
	var top_quad := PackedVector2Array(
		[
			Vector2(c.x - hw, top),
			Vector2(c.x + hw, top),
			Vector2(c.x + hw, mid),
			Vector2(c.x - hw, mid),
		]
	)
	node.draw_polygon(top_quad, PackedColorArray([clear, clear, bright, bright]))
	var bot_quad := PackedVector2Array(
		[
			Vector2(c.x - hw, mid),
			Vector2(c.x + hw, mid),
			Vector2(c.x + hw, c.y),
			Vector2(c.x - hw, c.y),
		]
	)
	node.draw_polygon(bot_quad, PackedColorArray([bright, bright, clear, clear]))
