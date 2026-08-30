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
## family (String, enemies only)}. Build these via
## make_ally_combatant()/make_enemy_combatant() below rather than by hand.
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
const LOW_HP_THRESHOLD := ShadowAI.LOW_HP_THRESHOLD  ## same threshold ShadowAI targets by

## invented v0: frostblooded's "Rime" target family (content/monsters.json)
const FROSTBLOODED_FAMILY := "Rime Sylphs"
## invented v0: executioner (vs boss) / frostblooded (vs Rime) damage multiplier
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
	rng: RandomNumberGenerator = null
) -> void:
	party = party_combatants
	enemies = enemy_combatants
	_moves = moves
	auto_battle = auto
	_rng = rng
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
		"trait_flags": trait_flags,
	}


## A ready-to-fight enemy combatant from a monster's/floor's base_power
## (§16's enemy_stats). No DEF stat -- the doc only defines enemy HP/ATK
## from base_power, nothing else, so enemies take full damage rather than
## inventing a defense number the source never gave them. No crit either
## (CombatMath.enemy_stats' own docstring already covers that).
## Monsters have no traits -- the all-false `trait_flags` is emitted only
## so the `_apply_attack` read sites can look it up unconditionally
## without special-casing enemies. `family` is the monster's content
## family string (content/monsters.json), used by frostblooded's
## vs-family bonus; "" when the caller doesn't supply one.
static func make_enemy_combatant(
	id: String,
	base_power: float,
	is_boss: bool = false,
	display_name: String = "",
	family: String = ""
) -> Dictionary:
	var combat := CombatMath.enemy_stats(base_power)
	return {
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
		"def": 0.0,
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
		"trait_flags":
		{
			"bloodhunger": false,
			"warcaller": false,
			"frostblooded": false,
			"relentless": false,
			"executioner": false,
		},
	}


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

	_tick_start_of_turn(actor)
	if _apply_poison_tick(actor):
		return _finish_check()  # poison finished them off before they could act

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
	log.append({"type": "poison_tick", "target_id": actor["id"], "damage": poison_dmg})
	return actor["hp"] <= 0


## Resolves the player's manually-chosen move -- only valid right after
## step() returned waiting_for_player for this actor.
func resolve_player_action(move_id: String, target_id: String) -> Dictionary:
	var actor := _combatant_by_id(player_id)
	if actor.is_empty() or actor["hp"] <= 0:
		return _finish_check()
	return _apply_move(actor, move_id, target_id)


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
	var cd_step := (
		RELENTLESS_COOLDOWN_TICK if actor.get("trait_flags", {}).get("relentless", false) else 1
	)
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
	var result := CombatMath.resolve_damage(move_power, atk, target_def, 0.0, _rng)
	var actual := _apply_shield(target, result["damage"])
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
	var base_atk: float = actor["patk"] if is_physical else actor["matk"]
	var atk := base_atk * float(actor.get("atk_multiplier", 1.0))
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
		if actor_flags.get("executioner", false) and bool(target.get("is_boss", false)):
			bonus_mult *= TRAIT_DAMAGE_BONUS
		if (
			actor_flags.get("frostblooded", false)
			and String(target.get("family", "")) == FROSTBLOODED_FAMILY
		):
			bonus_mult *= TRAIT_DAMAGE_BONUS
		var target_def: float = target["def"] * float(target.get("def_multiplier", 1.0))
		var result := CombatMath.resolve_damage(
			power * bonus_mult, atk, target_def, float(actor.get("crit_chance", 0.0)), _rng
		)
		var actual := _apply_shield(target, result["damage"])
		target["hp"] = maxi(0, target["hp"] - actual)
		if target["hp"] == 0 and actor_flags.get("bloodhunger", false) and actor["hp"] > 0:
			var heal := int(round(float(actor["max_hp"]) * BLOODHUNGER_HEAL_FRAC))
			var hp_before: int = actor["hp"]
			actor["hp"] = mini(int(actor["max_hp"]), actor["hp"] + heal)
			events.append(
				{"type": "lifesteal", "actor_id": actor["id"], "amount": actor["hp"] - hp_before}
			)
		(
			events
			. append(
				{
					"type": "damage",
					"actor_id": actor["id"],
					"target_id": target["id"],
					"damage": actual,
					"crit": result["crit"],
				}
			)
		)
		if tag == "dot":
			target["poison_turns"] = POISON_DURATION_TURNS
			target["poison_damage"] = int(round(atk * POISON_DAMAGE_SCALE))
	return events


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
	return events


## Weaken is the only debuff move in the whole moveset -- always
## single-target, straight from the AI/player's chosen target_id.
func _apply_debuff(actor: Dictionary, move: Dictionary, target_id: String) -> Array:
	var target := _combatant_by_id(target_id)
	if target.is_empty() or target["hp"] <= 0:
		return []
	target["def_multiplier"] = 1.0 - float(move.get("power", 0.0))
	target["def_mod_turns"] = BUFF_DEBUFF_DURATION_TURNS
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


func _apply_shield(target: Dictionary, damage: int) -> int:
	var shield: int = target.get("shield_hp", 0)
	if shield <= 0:
		return damage
	var absorbed := mini(shield, damage)
	target["shield_hp"] = shield - absorbed
	return damage - absorbed


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
