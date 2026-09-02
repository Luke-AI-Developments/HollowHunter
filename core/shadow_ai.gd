class_name ShadowAI
## Phase 3/step 2: automatic move/target selection for shadows -- also
## reused for the player's own turns under Auto-battle/Skip (§16). One
## function per class role, matching §16's exact stated priorities. Pure
## -- given a battle state (self + allies + enemies as plain combatant
## dicts, and the moves currently usable), returns which move to use and
## on whom. No cooldown/unlock-level filtering happens here -- that's the
## turn engine's job (step 3); this only ever sees moves already filtered
## down to "currently usable this turn".
##
## Combatant dict shape (only the fields each check actually needs):
## {"id": String, "hp": int, "max_hp": int, "debuffed": bool -- has an
## active negative status a matching move cares about (Assassin's Weaken/
## Support's Cleanse); "is_taunting": bool, self only -- Guardian's Taunt
## currently active}.
##
## Spec gap, flagged: §16's Support AI line says it should "attack when
## the team's topped up and nothing else is needed", but Support's full
## 5-move kit (content/moves.json) is entirely heal/buff/cleanse -- no
## attack move exists in the class's kit at all. Rather than invent a 6th
## move that isn't in the given moveset, Support's "nothing else needed"
## fallback here re-applies Mend instead of attacking -- keeps it doing
## something useful every turn using only the moves that actually exist,
## instead of fabricating new content to paper over the gap.

const LOW_HP_THRESHOLD := 0.25  ## invented v0: "low-HP" for Execute/Shadowstep Execute targeting
const GUARDIAN_BRACE_THRESHOLD := 0.4  ## invented v0: self-HP fraction that triggers Brace
const SUPPORT_HEAL_THRESHOLD := 0.5  ## invented v0: ally-HP fraction that counts as "low"
const SUPPORT_AOE_HEAL_MIN_HURT_ALLIES := 2  ## invented v0: hurt-ally count before Sanctuary > Mend


static func choose_action(
	clazz: String,
	self_combatant: Dictionary,
	moves: Array,
	allies: Array,
	enemies: Array,
	focus_target_id: String = ""
) -> Dictionary:
	var action := _dispatch(clazz, self_combatant, moves, allies, enemies)
	return _apply_focus(action, moves, enemies, focus_target_id)


static func _dispatch(
	clazz: String, self_combatant: Dictionary, moves: Array, allies: Array, enemies: Array
) -> Dictionary:
	match clazz.to_upper():
		"WARRIOR":
			return _choose_warrior(moves, enemies)
		"GUARDIAN":
			return _choose_guardian(self_combatant, moves, allies, enemies)
		"ASSASSIN":
			return _choose_assassin(moves, enemies)
		"MAGE":
			return _choose_mage(moves, enemies)
		"SUPPORT":
			return _choose_support(moves, allies)
	return {"move_id": "", "target_id": ""}


## Spec §7.4: redirect a single-enemy action onto the player-set Focus
## target when that enemy is alive. AoE / heal / buff / self moves are
## left alone (their target_id is "" or an ally).
static func _apply_focus(
	action: Dictionary, moves: Array, enemies: Array, focus_target_id: String
) -> Dictionary:
	if focus_target_id == "" or String(action.get("move_id", "")) == "":
		return action
	var focus_alive := false
	for e: Dictionary in enemies:
		if e.get("id", "") == focus_target_id and int(e.get("hp", 0)) > 0:
			focus_alive = true
			break
	if not focus_alive:
		return action
	var move := Content.move_by_id(moves, String(action["move_id"]))
	if String(move.get("target_type", "")) == "single_enemy":
		action["target_id"] = focus_target_id
	return action


## Warrior: finish low-HP enemies with Execute; Cleave into groups;
## otherwise the strongest available single-target hit on the lowest-HP
## enemy.
static func _choose_warrior(moves: Array, enemies: Array) -> Dictionary:
	var alive := _alive(enemies)
	if alive.is_empty():
		return {"move_id": "", "target_id": ""}

	var low_hp_target := _lowest_hp_fraction_below(alive, LOW_HP_THRESHOLD)
	var execute := _find_by_tag(moves, "bonus_vs_low_hp")
	if not execute.is_empty() and not low_hp_target.is_empty():
		return {"move_id": execute["id"], "target_id": low_hp_target["id"]}

	var cleave := _strongest_by_target_type(moves, "all_enemies")
	if not cleave.is_empty() and alive.size() >= 2:
		return {"move_id": cleave["id"], "target_id": ""}

	return _strongest_single_target_attack(moves, alive)


## Guardian: keep Taunt up at all times; Brace when its own HP drops;
## Shield Ally on the lowest-HP teammate; Guard Strike otherwise.
static func _choose_guardian(
	self_combatant: Dictionary, moves: Array, allies: Array, enemies: Array
) -> Dictionary:
	var taunt := _find_by_tag(moves, "taunt")
	if not taunt.is_empty() and not bool(self_combatant.get("is_taunting", false)):
		return {"move_id": taunt["id"], "target_id": ""}

	var brace := _find_by_tag(moves, "self_defense_buff")
	if not brace.is_empty() and _hp_fraction(self_combatant) < GUARDIAN_BRACE_THRESHOLD:
		return {"move_id": brace["id"], "target_id": ""}

	var shield := _find_by_tag(moves, "damage_soak")
	var lowest_ally := _lowest_hp(_alive(allies))
	if not shield.is_empty() and not lowest_ally.is_empty():
		return {"move_id": shield["id"], "target_id": lowest_ally["id"]}

	return _strongest_single_target_attack(moves, _alive(enemies))


## Assassin: debuff fresh (undebuffed) targets; finish already-debuffed/
## low-HP targets; Quick Strike otherwise.
static func _choose_assassin(moves: Array, enemies: Array) -> Dictionary:
	var alive := _alive(enemies)
	if alive.is_empty():
		return {"move_id": "", "target_id": ""}

	var undebuffed := _undebuffed(alive)
	var weaken := _find_by_tag(moves, "lower_def")
	if not weaken.is_empty() and not undebuffed.is_empty():
		var target := _highest_hp(undebuffed)  # weaken the toughest fresh target
		return {"move_id": weaken["id"], "target_id": target["id"]}

	var low_hp_target := _lowest_hp_fraction_below(alive, LOW_HP_THRESHOLD)
	var finisher := _find_by_tag(moves, "bonus_vs_low_hp")
	if not finisher.is_empty() and not low_hp_target.is_empty():
		return {"move_id": finisher["id"], "target_id": low_hp_target["id"]}

	var debuffed := _debuffed(alive)
	var exploit := _find_by_tag(moves, "bonus_vs_debuffed")
	if not exploit.is_empty() and not debuffed.is_empty():
		var target2 := _lowest_hp(debuffed)
		return {"move_id": exploit["id"], "target_id": target2["id"]}

	return _strongest_single_target_attack(moves, alive)


## Mage: AoE when 2+ enemies are up; otherwise the strongest single-
## target spell available.
static func _choose_mage(moves: Array, enemies: Array) -> Dictionary:
	var alive := _alive(enemies)
	if alive.is_empty():
		return {"move_id": "", "target_id": ""}

	if alive.size() >= 2:
		var aoe := _strongest_by_target_type(moves, "all_enemies")
		if not aoe.is_empty():
			return {"move_id": aoe["id"], "target_id": ""}

	return _strongest_single_target_attack(moves, alive)


## Support: heal whoever's low; cleanse debuffs; buff proactively; attack
## when the team's topped up and nothing else is needed (see the class
## doc comment above for the moveset-gap fallback this last branch uses).
static func _choose_support(moves: Array, allies: Array) -> Dictionary:
	var alive_allies := _alive(allies)
	var hurt := _hurt_below(alive_allies, SUPPORT_HEAL_THRESHOLD)
	if not hurt.is_empty():
		var aoe_heal := _find_by_tag(moves, "big_heal")
		if not aoe_heal.is_empty() and hurt.size() >= SUPPORT_AOE_HEAL_MIN_HURT_ALLIES:
			return {"move_id": aoe_heal["id"], "target_id": ""}
		var mend := _find_by_target_type_and_move_type(moves, "lowest_hp_ally", "heal")
		if not mend.is_empty():
			var lowest := _lowest_hp(hurt)
			return {"move_id": mend["id"], "target_id": lowest["id"]}

	var debuffed_allies := _debuffed(alive_allies)
	var cleanse := _find_by_tag(moves, "cleanse_debuff")
	if not cleanse.is_empty() and not debuffed_allies.is_empty():
		return {"move_id": cleanse["id"], "target_id": debuffed_allies[0]["id"]}

	var buff := _find_by_tag(moves, "ally_defense_buff")
	if not buff.is_empty() and not alive_allies.is_empty():
		var lowest_ally := _lowest_hp(alive_allies)
		return {"move_id": buff["id"], "target_id": lowest_ally["id"]}

	# Fallback: no attack move exists in the kit (see class doc comment),
	# so top someone off instead of doing nothing.
	var fallback_heal := _find_by_target_type_and_move_type(moves, "lowest_hp_ally", "heal")
	if not fallback_heal.is_empty() and not alive_allies.is_empty():
		var target := _lowest_hp(alive_allies)
		return {"move_id": fallback_heal["id"], "target_id": target["id"]}
	return {"move_id": "", "target_id": ""}


static func _alive(combatants: Array) -> Array:
	return combatants.filter(func(c: Dictionary) -> bool: return int(c.get("hp", 0)) > 0)


static func _undebuffed(combatants: Array) -> Array:
	return combatants.filter(func(c: Dictionary) -> bool: return not bool(c.get("debuffed", false)))


static func _debuffed(combatants: Array) -> Array:
	return combatants.filter(func(c: Dictionary) -> bool: return bool(c.get("debuffed", false)))


static func _hurt_below(combatants: Array, threshold: float) -> Array:
	return combatants.filter(func(c: Dictionary) -> bool: return _hp_fraction(c) < threshold)


static func _hp_fraction(c: Dictionary) -> float:
	var max_hp: int = c.get("max_hp", 1)
	if max_hp <= 0:
		return 0.0
	return float(c.get("hp", 0)) / float(max_hp)


static func _lowest_hp(combatants: Array) -> Dictionary:
	if combatants.is_empty():
		return {}
	var best: Dictionary = combatants[0]
	for c: Dictionary in combatants:
		if _hp_fraction(c) < _hp_fraction(best):
			best = c
	return best


## "Toughest" for Assassin's Weaken target selection -- absolute HP, not
## fraction, so a high-max-HP boss at full health reads as tougher than a
## low-max-HP minion also at full health (they'd tie on fraction alone).
static func _highest_hp(combatants: Array) -> Dictionary:
	if combatants.is_empty():
		return {}
	var best: Dictionary = combatants[0]
	for c: Dictionary in combatants:
		if int(c.get("hp", 0)) > int(best.get("hp", 0)):
			best = c
	return best


static func _lowest_hp_fraction_below(combatants: Array, threshold: float) -> Dictionary:
	return _lowest_hp(_hurt_below(combatants, threshold))


static func _find_by_tag(moves: Array, tag: String) -> Dictionary:
	for m: Dictionary in moves:
		if m.get("tag", "") == tag:
			return m
	return {}


static func _find_by_target_type_and_move_type(
	moves: Array, target_type: String, move_type: String
) -> Dictionary:
	for m: Dictionary in moves:
		if m.get("target_type", "") == target_type and m.get("move_type", "") == move_type:
			return m
	return {}


static func _is_attack_move(m: Dictionary) -> bool:
	var move_type: String = m.get("move_type", "")
	return move_type == "physical" or move_type == "magic"


static func _strongest_by_target_type(moves: Array, target_type: String) -> Dictionary:
	var candidates := []
	for m: Dictionary in moves:
		if m.get("target_type", "") == target_type and _is_attack_move(m):
			candidates.append(m)
	return _strongest(candidates)


## The strongest available attack move that targets a single enemy,
## aimed at whichever enemy currently has the lowest HP -- the fallback
## every class role uses ("otherwise attack the lowest-HP target", §16).
static func _strongest_single_target_attack(moves: Array, alive_enemies: Array) -> Dictionary:
	var candidates := []
	for m: Dictionary in moves:
		if m.get("target_type", "") == "single_enemy" and _is_attack_move(m):
			candidates.append(m)
	var best := _strongest(candidates)
	if best.is_empty() or alive_enemies.is_empty():
		return {"move_id": best.get("id", ""), "target_id": ""}
	var target := _lowest_hp(alive_enemies)
	return {"move_id": best["id"], "target_id": target["id"]}


static func _strongest(moves: Array) -> Dictionary:
	if moves.is_empty():
		return {}
	var best: Dictionary = moves[0]
	for m: Dictionary in moves:
		if float(m.get("power", 0.0)) > float(best.get("power", 0.0)):
			best = m
	return best
