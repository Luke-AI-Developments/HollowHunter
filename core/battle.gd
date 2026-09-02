class_name Battle
extends RefCounted
## Phase 3/step 3: the turn engine driving one fight (§16 combat
## overhaul) -- AGI-ordered turns, applying move effects, cooldowns/
## status, win/loss. Pure -- RefCounted, no scene tree/engine dependency,
## GUT-testable by constructing a Battle directly and calling step().
## One Battle instance = one fight (a single gate/break/Nadir-floor
## sub-encounter); the scene layer makes a fresh one per fight.
##
## Combatant dict shape (party[0] is always the player; everything else
## in `party` is a chosen shadow; `enemies` are the gate/floor's
## monsters): {id, class ("" for enemies), level, is_enemy, is_boss, hp,
## max_hp, patk, matk, def, crit_chance, speed, cooldowns
## {move_id: turns_left}, is_taunting, taunt_turns, atk_multiplier,
## atk_buff_turns, def_multiplier, def_mod_turns, poison_turns,
## poison_damage, shield_hp, turns_until_big_hit (bosses only),
## trait_flags (Dictionary of 5 bools:
## bloodhunger/warcaller/frostblooded/relentless/executioner),
## family (String, enemies only), elite (bool, enemies only),
## role (String, enemies only -- grunt profile / "boss", spec §3.2),
## atk_type (String, enemies only -- "physical"/"magic", drives DEF pierce)}.
## Enemy `def` is derived from base_power/role in v1 -- no longer always 0.
## Build these via make_ally_combatant()/make_enemy_combatant() below
## rather than by hand.
##
## MASSIVE gap between what §16 specifies and what a working turn engine
## needs, flagged in full here rather than scattered: the doc gives move
## FLAVOR (Taunt "forces enemies to target this Guardian", Weaken "lowers
## enemy defense", Poison Edge "damage-over-time", boss hits "~2x a
## normal attack every few turns") but zero numbers for any of it --
## durations, magnitudes, poison-tick damage, telegraph cadence, or even
## an enemy SPEED stat (§16 only defines SPEED=AGI for the player/
## shadows; enemies have no AGI to derive one from at all, yet the turn
## queue needs everyone ordered). Every constant below is an invented v0
## fill of one of those gaps, not sourced from the doc.

const BUFF_DEBUFF_DURATION_TURNS := 3  ## invented v0: how long a buff/debuff/taunt lasts,
## counted down on the AFFECTED unit's own turns (not globally) -- also used for Taunt.
const POISON_DURATION_TURNS := 3  ## invented v0
const POISON_DAMAGE_SCALE := 0.3  ## invented v0: poison tick = applier's ATK x this, per turn
const BONUS_VS_LOW_HP_MULTIPLIER := 1.5  ## invented v0: Execute/Shadowstep Execute's "bonus"
const BONUS_VS_DEBUFFED_MULTIPLIER := 1.5  ## invented v0: Exploit Weakness's "bonus"
const BLESSING_ATK_BUFF_MAGNITUDE := 0.15  ## invented v0: Blessing's "attack buff" half
## (its heal half already has its own `power` field in moves.json)
const BOSS_BIG_HIT_INTERVAL := 3  ## invented v0: "every few turns" (§16)
const BOSS_BIG_HIT_MULTIPLIER := 2.0  ## the doc's own number: "~2x a normal attack"
const MAGIC_DEF_PIERCE := 0.60  ## spec §2.3, invented v0: DEF fraction a magic hit ignores

## --- Break bar (spec §5 / §12, all v0) -------------------------------------
const BREAK_MAX_HP_FRACTION := 0.45  ## spec §5.1, v0: first break_max = enemy_HP x this
const BREAK_REFILL_MULT := 1.5  ## spec §5.1/§5.3, v0: break_max x= this after each Break
const BREAK_FILL_PER_DAMAGE := 0.5  ## spec §5.2, v0: break_current += damage x this
const BREAK_FILL_DEBUFF_FRAC := 0.12  ## spec §5.2, v0: debuff landed ->
## break_current += break_max x this
const BREAK_FILL_TELEGRAPH_MULT := 2.5  ## spec §5.2, v0: hit on the boss's
## telegraph turn -> damage contribution x this
const BREAK_FILL_HEAVY_FRAC := 0.08  ## spec §5.2, v0: heavy / all-enemies-magic
## hit -> break_current += break_max x this
const BREAK_OVERFILL_LONG_STUN := 0.5  ## spec §5.3, v0: overshoot break_max by
## >= this fraction -> long stagger
const BREAK_STUN_TURNS_SHORT := 1  ## spec §5.3, v0
const BREAK_STUN_TURNS_LONG := 2  ## spec §5.3, v0
const BROKEN_DAMAGE_TAKEN_MULT := 1.5  ## spec §5.3, v0: a broken boss takes
## x this damage from all sources

## --- Monarch Gauge (spec §6.1 / §12, all v0) ------------------------------
const MONARCH_GAUGE_MAX := 100.0  ## spec §6.1
const MONARCH_GAUGE_PER_HIT_SCALE := 20.0  ## spec §6.1, v0:
## += clamp(dmg / target_max_hp x this, 0, cap)
const MONARCH_GAUGE_PER_HIT_CAP := 8.0  ## spec §6.1, v0
const MONARCH_GAUGE_ON_CRIT := 5.0  ## spec §6.1, v0
const MONARCH_GAUGE_ON_BREAK := 25.0  ## spec §6.1/§5.3, v0

const LOW_HP_THRESHOLD := ShadowAI.LOW_HP_THRESHOLD  ## same threshold ShadowAI targets by

## invented v0: frostblooded's "Rime" target family (content/monsters.json)
const FROSTBLOODED_FAMILY := "Rime Sylphs"
## invented v0: executioner (vs elite) / frostblooded (vs Rime) damage multiplier
const TRAIT_DAMAGE_BONUS := 1.25
## invented v0: on-kill self-heal, fraction of the killer's max HP
const BLOODHUNGER_HEAL_FRAC := 0.15
## invented v0: party-wide PATK/MATK bump if any party member has warcaller
const WARCALLER_AURA := 0.08
## invented v0: cooldown decrement per turn for a relentless actor (vs 1)
const RELENTLESS_COOLDOWN_TICK := 2

const _BATTLE_TRAIT_IDS := ["bloodhunger", "warcaller", "frostblooded", "relentless", "executioner"]

var party: Array = []
var enemies: Array = []
var log: Array = []  ## event dicts, oldest first -- the battle-stage/toast feed (§16b)
var round_number: int = 1
var turn_queue: Array = []  ## remaining combatant ids to act this round
var auto_battle: bool = false
var is_over: bool = false
var won: bool = false
var player_id: String = ""
var monarch_gauge: float = 0.0  ## spec §6: one shared party gauge, 0..MONARCH_GAUGE_MAX

var _moves: Array = []
var _rng: RandomNumberGenerator


## `_apply_warcaller_aura()` mutates the passed-in party combatant dicts in
## place, so constructing a second `Battle` over the same array objects would
## re-apply the aura -- callers build fresh combatant dicts per fight
## (`main.gd._build_battle_party` does).
func _init(
	party_combatants: Array,
	enemy_combatants: Array,
	moves: Array,
	auto: bool = false,
	rng: RandomNumberGenerator = null,
	initial_monarch_gauge: float = 0.0
) -> void:
	party = party_combatants
	enemies = enemy_combatants
	_moves = moves
	auto_battle = auto
	_rng = rng
	monarch_gauge = clampf(initial_monarch_gauge, 0.0, MONARCH_GAUGE_MAX)
	if not party.is_empty():
		player_id = party[0]["id"]
	_build_turn_queue()
	_apply_warcaller_aura()


## A ready-to-fight ally combatant from a raw STR/AGI/VIT/END/SEN dict
## (GameLogic.stats_from() or a shadow's gear-merged effective stats) --
## the shared entry point for both the player and every chosen shadow.
## `display_name` is purely for the battle screen (§16b) -- falls back to
## `id` if not given, same convention as content dicts elsewhere in this
## project that default a missing display field to something non-empty.
## `synergy_bonus` is the Army Synergy fraction (§16/§20, CombatMath.
## army_synergy_bonus) -- 0.0 for gates (no synergy), the caller's computed
## bench-power bonus for raids/the Nadir. Applied as a flat +X% multiplier
## on HP/PATK/MATK/DEF only, per §16's own wording -- crit chance and speed
## are untouched.
## `trait_ids` are the shadow's resolved trait id strings (from
## SquadBuilder.enrich_army -- the caller maps the trait dicts to their
## ids). Only the five battle-relevant ids
## (bloodhunger/warcaller/frostblooded/relentless/executioner) become
## entries in the returned `trait_flags` dict; any other id is ignored.
## The player passes `[]` -- the hunter is not a shadow and carries no
## traits.
static func make_ally_combatant(
	id: String,
	clazz: String,
	level: int,
	stats: Dictionary,
	display_name: String = "",
	synergy_bonus: float = 0.0,
	trait_ids: Array = []
) -> Dictionary:
	var combat := CombatMath.combat_stats(stats)
	var mult := 1.0 + synergy_bonus
	var hp := int(round(float(combat["HP"]) * mult))
	var trait_flags := {}
	for tid in _BATTLE_TRAIT_IDS:
		trait_flags[tid] = trait_ids.has(tid)
	return {
		"id": id,
		"name": display_name if display_name != "" else id,
		"class": clazz,
		"level": level,
		"is_enemy": false,
		"is_boss": false,
		"hp": hp,
		"max_hp": hp,
		"patk": float(combat["PATK"]) * mult,
		"matk": float(combat["MATK"]) * mult,
		"def": float(combat["DEF"]) * mult,
		"crit_chance": combat["CRIT_CHANCE"],
		"speed": combat["SPEED"],
		"cooldowns": {},
		"is_taunting": false,
		"taunt_turns": 0,
		"atk_multiplier": 1.0,
		"atk_buff_turns": 0,
		"def_multiplier": 1.0,
		"def_mod_turns": 0,
		"poison_turns": 0,
		"poison_damage": 0,
		"shield_hp": 0,
		"statuses": {},
		"trait_flags": trait_flags,
	}


## A ready-to-fight enemy combatant from a monster's/floor's base_power
## (§16's enemy_stats). `role` is the grunt profile (spec §3.2:
## bruiser/skirmisher/armoured) and scales HP/SPEED/DEF; a boss ignores
## the passed role and takes the "boss" DEF coefficient with plain
## (bruiser) HP/SPEED, and its stored `role` field reads "boss" to match.
## DEF is real in v1 -- enemies no longer take full
## damage. `atk_type` ("physical"/"magic") decides whether this enemy's
## attacks pierce 60% of party DEF (spec §2.3). No crit
## (CombatMath.enemy_stats' own docstring already covers that).
## Monsters have no traits -- the all-false `trait_flags` is emitted only
## so the `_apply_attack` read sites can look it up unconditionally
## without special-casing enemies. `family` is the monster's content
## family string (content/monsters.json), used by frostblooded's
## vs-family bonus; "" when the caller doesn't supply one. `elite` is
## true only for rank A/S gates and Nadir boss floors; executioner's
## damage bonus keys off it, not `is_boss` (which is true for every gate,
## to drive the §18 CLAIM telegraph). A boss (`is_boss`) also carries
## `break_max / break_current / break_count / broken_turns` (spec §5); every
## combatant carries `statuses` (`{name: turns_left}`, spec §8 primitive).
static func make_enemy_combatant(
	id: String,
	base_power: float,
	is_boss: bool = false,
	display_name: String = "",
	family: String = "",
	elite: bool = false,
	role: String = "bruiser",
	atk_type: String = "physical"
) -> Dictionary:
	var combat := CombatMath.enemy_stats(base_power, "boss" if is_boss else role)
	var c := {
		"id": id,
		"name": display_name if display_name != "" else id,
		"class": "",
		"level": 1,
		"is_enemy": true,
		"is_boss": is_boss,
		"hp": combat["HP"],
		"max_hp": combat["HP"],
		"patk": float(combat["ATK"]),
		"matk": float(combat["ATK"]),
		"def": combat["DEF"],
		"crit_chance": 0.0,
		"speed": combat["SPEED"],
		"cooldowns": {},
		"is_taunting": false,
		"taunt_turns": 0,
		"atk_multiplier": 1.0,
		"atk_buff_turns": 0,
		"def_multiplier": 1.0,
		"def_mod_turns": 0,
		"poison_turns": 0,
		"poison_damage": 0,
		"shield_hp": 0,
		"turns_until_big_hit": BOSS_BIG_HIT_INTERVAL,
		"family": family,
		"elite": elite,
		"role": "boss" if is_boss else role,
		"atk_type": atk_type,
		"statuses": {},
		"trait_flags":
		{
			"bloodhunger": false,
			"warcaller": false,
			"frostblooded": false,
			"relentless": false,
			"executioner": false,
		},
	}
	if is_boss:
		c["break_max"] = float(combat["HP"]) * BREAK_MAX_HP_FRACTION
		c["break_current"] = 0.0
		c["break_count"] = 0
		c["broken_turns"] = 0
	return c


## Advances one combatant's turn. Returns {"battle_over": bool, "won":
## bool} once resolved, or {"waiting_for_player": true, "actor_id": ...,
## "battle_over": false, "won": false} when it's the player's turn and
## auto_battle is off -- the caller must then call resolve_player_action().
func step() -> Dictionary:
	if is_over:
		return {"battle_over": true, "won": won}

	var actor := _next_actor()
	if actor.is_empty():
		return _finish_check()  # nobody left able to act -- shouldn't happen if not is_over

	# `was_*` captured BEFORE _tick_start_of_turn, which decrements the counters.
	var was_stunned := _has_status(actor, "stun")
	var was_broken := int(actor.get("broken_turns", 0)) > 0
	_tick_start_of_turn(actor)
	# poison finished them off, OR they forfeit the turn (broken/stunned).
	if _apply_poison_tick(actor) or _skip_incapacitated_turn(actor, was_broken, was_stunned):
		return _finish_check()

	if actor.get("is_enemy", false):
		return _resolve_enemy_turn(actor)
	if actor["id"] == player_id and not auto_battle:
		return {
			"waiting_for_player": true,
			"actor_id": actor["id"],
			"battle_over": false,
			"won": false,
		}
	return _resolve_ai_turn(actor)


## Pops the next living combatant off the queue, refilling/advancing the
## round as needed. {} if nobody's left able to act.
func _next_actor() -> Dictionary:
	while true:
		if turn_queue.is_empty():
			round_number += 1
			_build_turn_queue()
			if turn_queue.is_empty():
				return {}
		var actor_id: String = turn_queue.pop_front()
		var actor := _combatant_by_id(actor_id)
		if not actor.is_empty() and actor["hp"] > 0:
			return actor
	return {}


## Applies this turn's poison tick (if any) and reports whether it killed
## the actor -- separated out purely to keep step()'s own return count
## under the project's max-returns lint limit.
func _apply_poison_tick(actor: Dictionary) -> bool:
	if actor.get("poison_turns", 0) <= 0:
		return false
	var poison_dmg: int = actor.get("poison_damage", 0)
	actor["hp"] = maxi(0, actor["hp"] - poison_dmg)
	# v0: DoT ticks are deliberately NOT routed into break-bar / Monarch-Gauge
	# fill (spec §5.2 "any damage" / §6.1). Poison carries no applier reference,
	# so gauge attribution would be arbitrary; the debuff's ONE-TIME break-fill
	# already fired when Poison Edge landed (see _apply_attack). Revisit with the
	# full status roster in Plan 3.
	log.append({"type": "poison_tick", "target_id": actor["id"], "damage": poison_dmg})
	return actor["hp"] <= 0


## A broken boss (spec §5.3) or a stun-statused actor (spec §8) forfeits
## its turn. Decrements the broken counter, logs the skip, and reports
## whether the actor was skipped. Split out of step() for the same reason
## as _apply_poison_tick -- keeping step()'s return count under the
## max-returns lint limit. `was_broken` / `was_stunned` are the pre-tick
## flags captured in step() before _tick_start_of_turn ran.
func _skip_incapacitated_turn(actor: Dictionary, was_broken: bool, was_stunned: bool) -> bool:
	if was_broken:
		actor["broken_turns"] = maxi(0, int(actor.get("broken_turns", 0)) - 1)
		log.append({"type": "broken_skip", "actor_id": actor["id"]})
		return true
	if was_stunned:
		log.append({"type": "stunned", "actor_id": actor["id"]})
		return true
	return false


## Resolves the player's manually-chosen move -- only valid right after
## step() returned waiting_for_player for this actor.
func resolve_player_action(move_id: String, target_id: String) -> Dictionary:
	var actor := _combatant_by_id(player_id)
	if actor.is_empty() or actor["hp"] <= 0:
		return _finish_check()
	return _apply_move(actor, move_id, target_id)


func ultimate_name() -> String:
	if party.is_empty():
		return ""
	return Ultimates.for_subclass(String(party[0].get("class", "")))


## Fires the Hunter Ultimate for the pending player turn (spec §6.2).
## Valid only right after step() returned waiting_for_player. No-op (no
## gauge spent, turn not consumed here -- caller should fall back to a
## normal move) if the gauge is not full or the player is down. The
## Ultimate resolves FIRST, then the gauge is zeroed -- spec §6.2's
## "resolves the Ultimate, gauge -> 0" -- so a Break or crit the Ultimate
## itself causes does not leave the gauge partly refilled afterward.
func resolve_player_ultimate() -> Dictionary:
	var actor := _combatant_by_id(player_id)
	if actor.is_empty() or actor["hp"] <= 0 or not can_use_ultimate():
		return _finish_check()
	Ultimates.resolve(self, String(actor.get("class", "")))
	monarch_gauge = 0.0
	return _finish_check()


## Resolves the CURRENTLY-PENDING player turn via ShadowAI, same as any
## auto-controlled ally -- for when Auto-battle gets toggled on while
## step() is already paused waiting on the player specifically. Calling
## step() again in that situation would just advance the queue past the
## player's pending turn without ever resolving it (that turn's queue
## slot was already consumed the first time step() returned
## waiting_for_player).
func resolve_pending_player_turn_via_ai() -> Dictionary:
	var actor := _combatant_by_id(player_id)
	if actor.is_empty() or actor["hp"] <= 0:
		return _finish_check()
	return _resolve_ai_turn(actor)


## Loops step() to completion -- Auto-battle/Skip (§16) are both just
## "don't render every intermediate step"; the engine itself doesn't
## distinguish them. Only completes battles constructed with
## auto_battle=true (a manual battle mid-wait returns without finishing,
## rather than silently overriding the player's mode).
func run_to_completion() -> Dictionary:
	while not is_over:
		var result := step()
		if result.get("waiting_for_player", false):
			break
	return {"battle_over": is_over, "won": won}


## Whether this boss's NEXT turn (not its current one) will be a
## telegraphed big hit -- what the battle screen's telegraph icon (§16b)
## queries, before that turn actually happens.
func is_boss_next_hit_big(enemy_id: String) -> bool:
	var e := _combatant_by_id(enemy_id)
	if e.is_empty() or not e.get("is_boss", false) or e["hp"] <= 0:
		return false
	return int(e.get("turns_until_big_hit", BOSS_BIG_HIT_INTERVAL)) <= 0


## Fraction (0..1) of a boss's break bar that is filled. 0.0 for a
## non-boss, an unknown id, a dead combatant, or a boss whose bar is
## empty -- the battle screen (§16b) and Plan 3's follow-up bonuses read
## this without having to special-case "no bar".
func break_fraction(enemy_id: String) -> float:
	var e := _combatant_by_id(enemy_id)
	if e.is_empty() or not e.get("is_boss", false) or e["hp"] <= 0:
		return 0.0
	var bmax: float = e.get("break_max", 0.0)
	if bmax <= 0.0:
		return 0.0
	return clampf(float(e.get("break_current", 0.0)) / bmax, 0.0, 1.0)


## Whether a living boss is currently in the broken/stagger window (spec
## §5.3) -- takes x1.5 damage and is skipping its turns.
func is_broken(enemy_id: String) -> bool:
	var e := _combatant_by_id(enemy_id)
	return not e.is_empty() and e["hp"] > 0 and int(e.get("broken_turns", 0)) > 0


func living_enemies() -> Array:
	return _alive(enemies)


func living_party() -> Array:
	return _alive(party)


func downed_party() -> Array:
	return party.filter(func(c: Dictionary) -> bool: return int(c.get("hp", 0)) <= 0)


## Spec §8 primitive: set a status to at least `turns` on `target`.
## `amount_frac` is used only for `regen` -- the per-tick heal as a fraction
## of the target's max HP (spec §8.2), stashed on the combatant for
## _tick_start_of_turn to read.
func apply_status(target: Dictionary, name: String, turns: int, amount_frac: float = 0.0) -> void:
	var statuses: Dictionary = target.get("statuses", {})
	statuses[name] = maxi(int(statuses.get(name, 0)), turns)
	target["statuses"] = statuses
	if name == "regen":
		target["regen_amount_frac"] = amount_frac
	log.append(
		{"type": "status", "target_id": target["id"], "status": name, "turns": int(statuses[name])}
	)


## One Hunter-Ultimate hit from party[0]. See core/ultimates.gd.
func deal_ultimate_damage(
	target: Dictionary,
	power: float,
	atk_type: String,
	auto_crit: bool,
	def_pierce: float,
	break_fill_mult: float
) -> int:
	if party.is_empty() or int(target.get("hp", 0)) <= 0:
		return 0
	var hunter: Dictionary = party[0]
	var is_physical := atk_type != "magic"
	var atk := _outgoing_atk(hunter, is_physical)
	var target_def: float = float(target["def"]) * float(target.get("def_multiplier", 1.0))
	var pierce := maxf(def_pierce, MAGIC_DEF_PIERCE if atk_type == "magic" else 0.0)
	var crit_chance := 1.0 if auto_crit else float(hunter.get("crit_chance", 0.0))
	var result := CombatMath.resolve_damage(power, atk, target_def, crit_chance, _rng, pierce)
	# Route through _land_hit for shield/hp/gauge/log; break_fill_mult is the
	# ultimate's TOTAL per-damage break rate (spec §6.3), applied inside _land_hit
	# so it does NOT compound with the telegraph auto-bump on a telegraph turn.
	return _land_hit(
		hunter, target, result, "", "", is_physical, {"ultimate": true}, break_fill_mult
	)


func _build_turn_queue() -> void:
	var ids := []
	for c: Dictionary in party:
		if c["hp"] > 0:
			ids.append(c["id"])
	for c: Dictionary in enemies:
		if c["hp"] > 0:
			ids.append(c["id"])
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			return int(_combatant_by_id(a)["speed"]) > int(_combatant_by_id(b)["speed"])
	)
	turn_queue = ids


## §6b part 3: if any living party member has warcaller, the whole party's
## PATK/MATK get a one-time flat bump for the rest of the fight. The flavour
## ("aura while the warcaller lives") is simplified to battle-long in v0 --
## no dynamic recompute when the warcaller falls.
func _apply_warcaller_aura() -> void:
	var has_warcaller := false
	for c: Dictionary in party:
		if c["hp"] > 0 and c.get("trait_flags", {}).get("warcaller", false):
			has_warcaller = true
			break
	if not has_warcaller:
		return
	for c: Dictionary in party:
		c["patk"] = float(c["patk"]) * (1.0 + WARCALLER_AURA)
		c["matk"] = float(c["matk"]) * (1.0 + WARCALLER_AURA)


func _tick_start_of_turn(actor: Dictionary) -> void:
	var cd_step := 1
	if actor.get("trait_flags", {}).get("relentless", false):
		cd_step = RELENTLESS_COOLDOWN_TICK
	if _has_status(actor, "overdrive"):
		cd_step = maxi(cd_step, 2)  ## spec §6.3, v0
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	for move_id in cooldowns.keys():
		cooldowns[move_id] = maxi(0, int(cooldowns[move_id]) - cd_step)
	if actor.get("atk_buff_turns", 0) > 0:
		actor["atk_buff_turns"] -= 1
		if actor["atk_buff_turns"] <= 0:
			actor["atk_multiplier"] = 1.0
	if actor.get("def_mod_turns", 0) > 0:
		actor["def_mod_turns"] -= 1
		if actor["def_mod_turns"] <= 0:
			actor["def_multiplier"] = 1.0
	if actor.get("taunt_turns", 0) > 0:
		actor["taunt_turns"] -= 1
		if actor["taunt_turns"] <= 0:
			actor["is_taunting"] = false
	var statuses: Dictionary = actor.get("statuses", {})
	for sname in statuses.keys():
		statuses[sname] = maxi(0, int(statuses[sname]) - 1)
		if statuses[sname] == 0:
			statuses.erase(sname)
	# Regen heal AFTER the decrement loop -- a status ticking to 0 this turn does
	# not also heal, matching how `stun` is read post-decrement elsewhere (spec §8.2, v0).
	if _has_status(actor, "regen"):
		var heal := int(round(float(actor["max_hp"]) * float(actor.get("regen_amount_frac", 0.0))))
		if heal > 0 and actor["hp"] > 0:
			var before: int = actor["hp"]
			actor["hp"] = mini(int(actor["max_hp"]), actor["hp"] + heal)
			log.append(
				{"type": "regen_tick", "target_id": actor["id"], "amount": actor["hp"] - before}
			)


func _resolve_enemy_turn(actor: Dictionary) -> Dictionary:
	var target := _enemy_target()
	if target.is_empty():
		return _finish_check()

	var is_big_hit := false
	if actor.get("is_boss", false):
		var remaining: int = actor.get("turns_until_big_hit", BOSS_BIG_HIT_INTERVAL)
		is_big_hit = remaining <= 0
		actor["turns_until_big_hit"] = BOSS_BIG_HIT_INTERVAL if is_big_hit else remaining - 1

	var move_power := BOSS_BIG_HIT_MULTIPLIER if is_big_hit else 1.0
	var atk: float = actor["patk"] * float(actor.get("atk_multiplier", 1.0))
	var target_def: float = target["def"] * float(target.get("def_multiplier", 1.0))
	var pierce := MAGIC_DEF_PIERCE if String(actor.get("atk_type", "physical")) == "magic" else 0.0
	var result := CombatMath.resolve_damage(move_power, atk, target_def, 0.0, _rng, pierce)
	var scaled := int(round(float(result["damage"]) * _incoming_damage_mult(target)))
	var actual := _apply_shield(target, scaled)
	target["hp"] = maxi(0, target["hp"] - actual)
	(
		log
		. append(
			{
				"type": "enemy_attack",
				"actor_id": actor["id"],
				"target_id": target["id"],
				"damage": actual,
				"big_hit": is_big_hit,
			}
		)
	)
	return _finish_check()


func _resolve_ai_turn(actor: Dictionary) -> Dictionary:
	if actor["id"] == player_id and can_use_ultimate():
		Ultimates.resolve(self, String(actor.get("class", "")))
		monarch_gauge = 0.0
		return _finish_check()
	var available := _available_moves_for(actor)
	var self_view := _combatant_view(actor)
	var allies_view := _combatant_views(_allies_of(actor))
	var enemies_view := _combatant_views(_alive(enemies))
	var action := ShadowAI.choose_action(
		actor["class"], self_view, available, allies_view, enemies_view
	)
	if String(action.get("move_id", "")) == "":
		log.append({"type": "pass", "actor_id": actor["id"]})
		return _finish_check()
	return _apply_move(actor, action["move_id"], action["target_id"])


func _apply_move(actor: Dictionary, move_id: String, target_id: String) -> Dictionary:
	var move := Content.move_by_id(_moves, move_id)
	if move.is_empty():
		return _finish_check()

	var cooldowns: Dictionary = actor.get("cooldowns", {})
	cooldowns[move_id] = int(move.get("cooldown", 0))

	var events: Array = []
	match String(move.get("move_type", "")):
		"physical", "magic":
			events = _apply_attack(actor, move)
		"heal":
			events = _apply_heal(actor, move, target_id)
		"buff":
			events = _apply_buff(actor, move, target_id)
		"debuff":
			events = _apply_debuff(actor, move, target_id)
		"taunt":
			events = _apply_taunt(actor)
		"cleanse":
			events = _apply_cleanse(actor, move, target_id)
		_:
			events = []

	for e: Dictionary in events:
		log.append(e)
	return _finish_check()


## Attack moves (physical/magic) only ever come from party members, only
## ever hit `enemies` -- enemy attacks are their own separate code path
## (_resolve_enemy_turn), never routed through here.
func _apply_attack(actor: Dictionary, move: Dictionary) -> Array:
	var target_type := String(move.get("target_type", ""))
	var targets: Array = (
		_alive(enemies) if target_type == "all_enemies" else [_single_target(enemies)]
	)
	targets = targets.filter(func(t: Dictionary) -> bool: return not t.is_empty())
	if targets.is_empty():
		return []

	var is_physical := String(move.get("move_type", "")) == "physical"
	var atk := _outgoing_atk(actor, is_physical)
	var power := float(move.get("power", 1.0))
	var tag := String(move.get("tag", ""))
	var events := []

	for target: Dictionary in targets:
		var bonus_mult := 1.0
		if tag == "bonus_vs_low_hp" and _hp_fraction(target) < LOW_HP_THRESHOLD:
			bonus_mult = BONUS_VS_LOW_HP_MULTIPLIER
		elif tag == "bonus_vs_debuffed" and float(target.get("def_multiplier", 1.0)) < 1.0:
			bonus_mult = BONUS_VS_DEBUFFED_MULTIPLIER
		var actor_flags: Dictionary = actor.get("trait_flags", {})
		if actor_flags.get("executioner", false) and bool(target.get("elite", false)):
			bonus_mult *= TRAIT_DAMAGE_BONUS
		if (
			actor_flags.get("frostblooded", false)
			and String(target.get("family", "")) == FROSTBLOODED_FAMILY
		):
			bonus_mult *= TRAIT_DAMAGE_BONUS
		var target_def: float = target["def"] * float(target.get("def_multiplier", 1.0))
		var pierce := MAGIC_DEF_PIERCE if String(move.get("move_type", "")) == "magic" else 0.0
		var result := CombatMath.resolve_damage(
			power * bonus_mult, atk, target_def, float(actor.get("crit_chance", 0.0)), _rng, pierce
		)
		var actual := _land_hit(actor, target, result, tag, target_type, is_physical)
		if target["hp"] == 0 and actor_flags.get("bloodhunger", false) and actor["hp"] > 0:
			var heal := int(round(float(actor["max_hp"]) * BLOODHUNGER_HEAL_FRAC))
			var hp_before: int = actor["hp"]
			actor["hp"] = mini(int(actor["max_hp"]), actor["hp"] + heal)
			events.append(
				{"type": "lifesteal", "actor_id": actor["id"], "amount": actor["hp"] - hp_before}
			)
		if tag == "dot":
			target["poison_turns"] = POISON_DURATION_TURNS
			target["poison_damage"] = int(round(atk * POISON_DAMAGE_SCALE))
			if target.get("is_boss", false) and target.has("break_max"):
				_add_break_fill(target, float(target["break_max"]) * BREAK_FILL_DEBUFF_FRAC)
	_resolve_applied_status(move, targets)
	return events


## Spec §8.2: a move may carry an optional `applies_status` object
## ({name, turns, grunts_only?, amount_frac?}) -- resolved AFTER the move's
## primary effect, on each target it landed on. The rider applies on-hit
## regardless of whether that hit was lethal (a status on a downed
## combatant is inert -- `_alive` filters it out, and the regen tick is
## `hp > 0`-gated), so no post-hit HP check here.
func _resolve_applied_status(move: Dictionary, targets: Array) -> void:
	var spec_status: Dictionary = move.get("applies_status", {})
	if spec_status.is_empty():
		return
	var name := String(spec_status.get("name", ""))
	var turns := int(spec_status.get("turns", 0))
	if name == "" or turns <= 0:
		return
	var grunts_only := bool(spec_status.get("grunts_only", false))
	var amount_frac := float(spec_status.get("amount_frac", 0.0))
	for t: Dictionary in targets:
		if grunts_only and bool(t.get("is_boss", false)):
			continue
		apply_status(t, name, turns, amount_frac)


## Outgoing physical/magic attack power for `actor`: base PATK/MATK x its
## atk_multiplier, then x1.25 while Sovereign's Grace overdrive is active.
## Shared by `_apply_attack` and `deal_ultimate_damage` (spec §6.3) so the
## overdrive bonus applies to Ultimate hits too, not just normal moves.
func _outgoing_atk(actor: Dictionary, is_physical: bool) -> float:
	var base_atk: float = actor["patk"] if is_physical else actor["matk"]
	var atk := base_atk * float(actor.get("atk_multiplier", 1.0))
	if _has_status(actor, "overdrive"):
		atk *= 1.25  ## spec §6.3, v0: Sovereign's Grace overdrive
	return atk


## Applies one already-resolved hit (`result` from CombatMath.resolve_damage)
## to `target`: incoming-damage multiplier, shield, hp, boss break-fill,
## Monarch Gauge fill, and the `damage` log event. Returns the actual HP
## removed. Shared by `_apply_attack` and `Ultimates` (via
## `deal_ultimate_damage`) so the hit-application rules live in one place.
## `break_fill_mult` >= 0.0 (Ultimate callers only) is the TOTAL per-damage
## break rate -- it floors at the telegraph rate on a telegraph turn but does
## NOT compound with it (spec §6.3); < 0.0 keeps the telegraph auto-bump path.
func _land_hit(
	actor: Dictionary,
	target: Dictionary,
	result: Dictionary,
	tag: String,
	target_type: String,
	is_physical: bool,
	extra_event_fields: Dictionary = {},
	break_fill_mult: float = -1.0
) -> int:
	var scaled_damage := int(round(float(result["damage"]) * _incoming_damage_mult(target)))
	var actual := _apply_shield(target, scaled_damage)
	target["hp"] = maxi(0, target["hp"] - actual)
	if target.get("is_boss", false) and target.has("break_max"):
		var on_telegraph := int(target.get("turns_until_big_hit", BOSS_BIG_HIT_INTERVAL)) <= 1
		var dmg_fill := float(actual) * BREAK_FILL_PER_DAMAGE
		if break_fill_mult >= 0.0:
			dmg_fill *= maxf(break_fill_mult, BREAK_FILL_TELEGRAPH_MULT if on_telegraph else 1.0)
		elif on_telegraph:
			dmg_fill *= BREAK_FILL_TELEGRAPH_MULT  ## spec §5.2, v0
		var flat_fill := 0.0
		if tag == "heavy":
			flat_fill += float(target["break_max"]) * BREAK_FILL_HEAVY_FRAC
		if target_type == "all_enemies" and not is_physical:
			flat_fill += float(target["break_max"]) * BREAK_FILL_HEAVY_FRAC
		_add_break_fill(target, dmg_fill + flat_fill)
	var tmax: int = maxi(1, int(target.get("max_hp", 1)))
	_add_monarch_gauge(
		clampf(
			float(actual) / float(tmax) * MONARCH_GAUGE_PER_HIT_SCALE,
			0.0,
			MONARCH_GAUGE_PER_HIT_CAP
		)
	)
	if result["crit"]:
		_add_monarch_gauge(MONARCH_GAUGE_ON_CRIT)
	var ev := {
		"type": "damage",
		"actor_id": actor["id"],
		"target_id": target["id"],
		"damage": actual,
		"crit": result["crit"],
	}
	ev.merge(extra_event_fields)
	log.append(ev)
	return actual


func _apply_heal(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var targets := _resolve_ally_targets(actor, move, target_id)
	if targets.is_empty():
		return []
	var heal_amount := int(round(float(move.get("power", 1.0)) * actor["matk"]))
	var events := []
	for target: Dictionary in targets:
		var before: int = target["hp"]
		target["hp"] = mini(int(target["max_hp"]), target["hp"] + heal_amount)
		(
			events
			. append(
				{
					"type": "heal",
					"actor_id": actor["id"],
					"target_id": target["id"],
					"amount": target["hp"] - before,
				}
			)
		)
	if String(move.get("tag", "")) == "team_heal_and_attack_buff":
		for target: Dictionary in targets:
			target["atk_multiplier"] = 1.0 + BLESSING_ATK_BUFF_MAGNITUDE
			target["atk_buff_turns"] = BUFF_DEBUFF_DURATION_TURNS
	return events


func _apply_buff(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var targets := _resolve_ally_targets(actor, move, target_id)
	if targets.is_empty():
		return []
	var power := float(move.get("power", 0.0))
	var tag := String(move.get("tag", ""))
	var events := []
	for target: Dictionary in targets:
		if tag == "team_attack_buff":
			target["atk_multiplier"] = 1.0 + power
			target["atk_buff_turns"] = BUFF_DEBUFF_DURATION_TURNS
		elif tag == "damage_soak":
			target["shield_hp"] = (
				int(target.get("shield_hp", 0)) + int(round(power * actor["max_hp"]))
			)
		else:  # self_defense_buff, team_defense_buff, ally_defense_buff
			target["def_multiplier"] = 1.0 + power
			target["def_mod_turns"] = BUFF_DEBUFF_DURATION_TURNS
		events.append(
			{"type": "buff", "actor_id": actor["id"], "target_id": target["id"], "tag": tag}
		)
	_resolve_applied_status(move, targets)
	return events


## Weaken is the only debuff move in the whole moveset -- always
## single-target, straight from the AI/player's chosen target_id.
func _apply_debuff(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var target := _combatant_by_id(target_id)
	if target.is_empty() or target["hp"] <= 0:
		return []
	target["def_multiplier"] = 1.0 - float(move.get("power", 0.0))
	target["def_mod_turns"] = BUFF_DEBUFF_DURATION_TURNS
	if target.get("is_boss", false) and target.has("break_max"):
		_add_break_fill(target, float(target["break_max"]) * BREAK_FILL_DEBUFF_FRAC)
	# atk-down is not in the v0 moveset; when Plan 3/4 adds one, mirror the
	# break-fill hook above.
	return [{"type": "debuff", "actor_id": actor["id"], "target_id": target["id"]}]


func _apply_taunt(actor: Dictionary) -> Array:
	actor["is_taunting"] = true
	actor["taunt_turns"] = BUFF_DEBUFF_DURATION_TURNS
	return [{"type": "taunt", "actor_id": actor["id"]}]


func _apply_cleanse(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var targets := _resolve_ally_targets(actor, move, target_id)
	if targets.is_empty():
		return []
	for target: Dictionary in targets:
		if float(target.get("def_multiplier", 1.0)) < 1.0:
			target["def_multiplier"] = 1.0
			target["def_mod_turns"] = 0
		target["poison_turns"] = 0
		target["poison_damage"] = 0
	return [{"type": "cleanse", "actor_id": actor["id"], "target_id": targets[0]["id"]}]


## Resolves who a heal/buff/cleanse move actually lands on: self, the
## whole party, an already-known target_id (from the AI or a manual
## player choice), or -- when none of those apply -- the lowest-HP living
## ally, the same default ShadowAI itself uses.
func _resolve_ally_targets(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var target_type := String(move.get("target_type", ""))
	if target_type == "self":
		return [actor]
	if target_type == "all_allies":
		return _alive(party)
	if target_id != "":
		var t := _combatant_by_id(target_id)
		if not t.is_empty() and t["hp"] > 0:
			return [t]
	var fallback := _lowest_hp(_alive(party))
	return [] if fallback.is_empty() else [fallback]


func _single_target(pool: Array) -> Dictionary:
	return _lowest_hp(_alive(pool))


func _has_status(c: Dictionary, name: String) -> bool:
	return int(c.get("statuses", {}).get(name, 0)) > 0


## Central multiplier on damage ARRIVING at `target` (spec §5.3 broken,
## §8 statuses). Composed multiplicatively; invuln wins by zeroing.
func _incoming_damage_mult(target: Dictionary) -> float:
	if _has_status(target, "invuln"):
		return 0.0
	var m := 1.0
	if int(target.get("broken_turns", 0)) > 0:
		m *= BROKEN_DAMAGE_TAKEN_MULT
	if _has_status(target, "vulnerable"):
		m *= 1.25  ## spec §8/§12, v0: Vulnerable damage-taken multiplier
	return m


func _apply_shield(target: Dictionary, damage: int) -> int:
	var shield: int = target.get("shield_hp", 0)
	if shield <= 0:
		return damage
	var absorbed := mini(shield, damage)
	target["shield_hp"] = shield - absorbed
	return damage - absorbed


## Adds `amount` (may be negative-safe: it is clamped) to a boss's break
## bar (spec §5.2). No-op for a non-boss, a boss with no bar, or a boss
## that is already broken (it refills from 0 only after the stagger ends).
func _add_break_fill(boss: Dictionary, amount: float) -> void:
	if not boss.get("is_boss", false) or not boss.has("break_max"):
		return
	if int(boss.get("broken_turns", 0)) > 0:
		return
	var bmax: float = boss["break_max"]
	var before: float = boss["break_current"]
	var raw := before + amount  ## pre-clamp total, so an overshoot is measurable (spec §5.3)
	boss["break_current"] = clampf(raw, 0.0, bmax)
	(
		log
		. append(
			{
				"type": "break_fill",
				"target_id": boss["id"],
				"amount": int(round(boss["break_current"] - before)),
				"current": int(round(boss["break_current"])),
				"max": int(round(bmax)),
			}
		)
	)
	_maybe_break(boss, raw)


## Spec §5.3: when a boss's bar is full, stagger it. Idempotent while the
## boss is already broken (broken_turns > 0 blocks re-entry, and
## _add_break_fill won't have filled it anyway). `raw_fill` is the pre-clamp
## bar total from _add_break_fill -- the overshoot the clamp on break_current
## would otherwise erase (spec §5.3's ">=50% overfill -> 2-turn stagger");
## defaults to reading break_current for the direct-poke callers (tests).
func _maybe_break(boss: Dictionary, raw_fill: float = -1.0) -> void:
	if int(boss.get("broken_turns", 0)) > 0:
		return
	var bmax: float = boss.get("break_max", 0.0)
	if bmax <= 0.0 or float(boss.get("break_current", 0.0)) < bmax:
		return
	var reached: float = raw_fill if raw_fill >= 0.0 else float(boss.get("break_current", 0.0))
	var overfill := (reached - bmax) / bmax
	var stun_turns := (
		BREAK_STUN_TURNS_LONG if overfill >= BREAK_OVERFILL_LONG_STUN else BREAK_STUN_TURNS_SHORT
	)
	boss["broken_turns"] = stun_turns
	boss["turns_until_big_hit"] = BOSS_BIG_HIT_INTERVAL  # cancel any pending telegraph
	var statuses: Dictionary = boss["statuses"]
	statuses["stun"] = maxi(int(statuses.get("stun", 0)), BREAK_STUN_TURNS_SHORT)
	boss["break_count"] = int(boss["break_count"]) + 1
	boss["break_max"] = bmax * BREAK_REFILL_MULT
	boss["break_current"] = 0.0
	(
		log
		. append(
			{
				"type": "break",
				"target_id": boss["id"],
				"break_count": boss["break_count"],
				"stun_turns": stun_turns,
				"new_break_max": int(round(boss["break_max"])),
			}
		)
	)
	_add_monarch_gauge(MONARCH_GAUGE_ON_BREAK)


## Spec §6.1. Offence-weighted party gauge fill. Emits a `gauge` event
## only on a real change so the log/HUD can react.
func _add_monarch_gauge(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var before := monarch_gauge
	monarch_gauge = clampf(monarch_gauge + amount, 0.0, MONARCH_GAUGE_MAX)
	if not is_equal_approx(before, monarch_gauge):
		(
			log
			. append(
				{
					"type": "gauge",
					"amount": int(round(monarch_gauge - before)),
					"current": int(round(monarch_gauge)),
				}
			)
		)


func can_use_ultimate() -> bool:
	return monarch_gauge >= MONARCH_GAUGE_MAX


func _enemy_target() -> Dictionary:
	for c: Dictionary in party:
		if c["hp"] > 0 and bool(c.get("is_taunting", false)):
			return c
	return _lowest_hp(_alive(party))


func _allies_of(actor: Dictionary) -> Array:
	return party.filter(func(c: Dictionary) -> bool: return c["id"] != actor["id"] and c["hp"] > 0)


func _available_moves_for(actor: Dictionary) -> Array:
	var unlocked := Content.unlocked_moves(
		_moves, String(actor.get("class", "")), int(actor.get("level", 1))
	)
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	return unlocked.filter(func(m: Dictionary) -> bool: return int(cooldowns.get(m["id"], 0)) <= 0)


func _combatant_view(c: Dictionary) -> Dictionary:
	return {
		"id": c["id"],
		"hp": c["hp"],
		"max_hp": c["max_hp"],
		"debuffed": float(c.get("def_multiplier", 1.0)) < 1.0,
		"is_taunting": c.get("is_taunting", false),
	}


func _combatant_views(list: Array) -> Array:
	var out := []
	for c: Dictionary in list:
		out.append(_combatant_view(c))
	return out


func _combatant_by_id(id: String) -> Dictionary:
	for c: Dictionary in party:
		if c["id"] == id:
			return c
	for c: Dictionary in enemies:
		if c["id"] == id:
			return c
	return {}


func _alive(list: Array) -> Array:
	return list.filter(func(c: Dictionary) -> bool: return int(c.get("hp", 0)) > 0)


func _hp_fraction(c: Dictionary) -> float:
	var max_hp: int = c.get("max_hp", 1)
	if max_hp <= 0:
		return 0.0
	return float(c.get("hp", 0)) / float(max_hp)


func _lowest_hp(list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var best: Dictionary = list[0]
	for c: Dictionary in list:
		if _hp_fraction(c) < _hp_fraction(best):
			best = c
	return best


func _finish_check() -> Dictionary:
	if _alive(enemies).is_empty():
		is_over = true
		won = true
	elif _alive(party).is_empty():
		is_over = true
		won = false
	return {"battle_over": is_over, "won": won}
