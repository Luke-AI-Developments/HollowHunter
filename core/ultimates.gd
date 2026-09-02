class_name Ultimates
## The five Hunter Ultimates (spec §6.3), one fixed per subclass. Pure --
## every resolver mutates the passed-in `Battle` through its public API
## (deal_ultimate_damage / apply_status / living_* / _combatant_by_id) and
## adds log events; none of them touch `battle.monarch_gauge` (the caller
## zeroes it -- spec §6.2). All magnitudes are v0 (spec §6.3 / §12).

const NAMES := {
	"WARRIOR": "Monarch's Wrath",
	"GUARDIAN": "Aegis Dominion",
	"ASSASSIN": "Thousand Cuts",
	"MAGE": "Nova Cataclysm",
	"SUPPORT": "Sovereign's Grace",
}

const WRATH_POWER := 3.0  ## spec §6.3, v0
const WRATH_DEF_PIERCE := 0.5  ## spec §6.3, v0: ignores 50% DEF
const WRATH_BREAK_MULT := 2.5  ## spec §6.3, v0: break contribution at the telegraph rate

const AEGIS_INVULN_TURNS := 1  ## spec §6.3, v0
const AEGIS_DEF_MULT := 1.4  ## spec §6.3, v0
const AEGIS_DEF_TURNS := 3  ## spec §6.3, v0
const AEGIS_STRIKE_POWER := 2.5  ## spec §6.3, v0

const CUTS_HITS := 6  ## spec §6.3, v0
const CUTS_POWER := 0.7  ## spec §6.3, v0
const CUTS_VULN_TURNS := 2  ## spec §6.3, v0: each hit applies a stack; status capped here

const NOVA_POWER := 3.2  ## spec §6.3, v0
const NOVA_STUN_TURNS := 1  ## spec §6.3, v0

const GRACE_REVIVE_HP_FRAC := 0.6  ## spec §6.3, v0
const GRACE_OVERDRIVE_TURNS := 2  ## spec §6.3, v0


static func for_subclass(subclass: String) -> String:
	return String(NAMES.get(subclass.to_upper(), ""))


static func resolve(battle: Battle, subclass: String) -> void:
	match subclass.to_upper():
		"WARRIOR":
			_wrath(battle)
		"GUARDIAN":
			_aegis(battle)
		"ASSASSIN":
			_thousand_cuts(battle)
		"MAGE":
			_nova(battle)
		"SUPPORT":
			_grace(battle)
		_:
			battle.log.append({"type": "ultimate_noop", "subclass": subclass})


static func _wrath(battle: Battle) -> void:
	battle.log.append({"type": "ultimate", "name": NAMES["WARRIOR"]})
	for e: Dictionary in battle.living_enemies():
		battle.deal_ultimate_damage(
			e, WRATH_POWER, "physical", false, WRATH_DEF_PIERCE, WRATH_BREAK_MULT
		)


static func _aegis(battle: Battle) -> void:
	battle.log.append({"type": "ultimate", "name": NAMES["GUARDIAN"]})
	for c: Dictionary in battle.party:
		battle.apply_status(c, "invuln", AEGIS_INVULN_TURNS)
		c["def_multiplier"] = AEGIS_DEF_MULT
		c["def_mod_turns"] = AEGIS_DEF_TURNS
	var enemies: Array = battle.living_enemies()
	if not enemies.is_empty():
		var tank_target: Dictionary = enemies[0]
		for e: Dictionary in enemies:
			if int(e.get("max_hp", 0)) > int(tank_target.get("max_hp", 0)):
				tank_target = e
		battle.deal_ultimate_damage(tank_target, AEGIS_STRIKE_POWER, "physical", false, 0.0, 1.0)
	if not battle.party.is_empty():
		battle.party[0]["is_taunting"] = true
		battle.party[0]["taunt_turns"] = battle.BUFF_DEBUFF_DURATION_TURNS


static func _thousand_cuts(battle: Battle) -> void:
	battle.log.append({"type": "ultimate", "name": NAMES["ASSASSIN"]})
	for i in CUTS_HITS:
		var enemies: Array = battle.living_enemies()
		if enemies.is_empty():
			return
		var target: Dictionary = enemies[i % enemies.size()]
		battle.deal_ultimate_damage(target, CUTS_POWER, "physical", true, 0.0, 1.0)
		if int(target.get("hp", 0)) > 0:
			battle.apply_status(target, "vulnerable", CUTS_VULN_TURNS)


static func _nova(battle: Battle) -> void:
	battle.log.append({"type": "ultimate", "name": NAMES["MAGE"]})
	for e: Dictionary in battle.living_enemies():
		battle.deal_ultimate_damage(e, NOVA_POWER, "magic", false, 0.0, 1.0)
	for e: Dictionary in battle.living_enemies():
		var is_boss: bool = e.get("is_boss", false)
		if not is_boss:
			battle.apply_status(e, "stun", NOVA_STUN_TURNS)
		elif int(e.get("broken_turns", 0)) > 0:
			battle.apply_status(e, "stun", NOVA_STUN_TURNS)


static func _grace(battle: Battle) -> void:
	battle.log.append({"type": "ultimate", "name": NAMES["SUPPORT"]})
	for c: Dictionary in battle.party:
		if int(c.get("hp", 0)) <= 0:
			c["hp"] = int(round(float(c["max_hp"]) * GRACE_REVIVE_HP_FRAC))
			battle.log.append({"type": "revive", "target_id": c["id"], "hp": c["hp"]})
		else:
			c["hp"] = int(c["max_hp"])
		battle.apply_status(c, "overdrive", GRACE_OVERDRIVE_TURNS)
	# revived members were dropped from the turn queue when they fell; rebuild
	battle._build_turn_queue()
