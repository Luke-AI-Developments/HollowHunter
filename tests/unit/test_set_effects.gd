extends GutTest
## Combat v1 §10.3: armour-set combat effects wired into the fight --
## the `stat_pct` build fold plus the nine behavioural hook sites in
## core/battle.gd, and SquadBuilder.enrich_army exposing `combat_set_effects`.
## Split out of test_battle.gd, which is at the 1500-line lint cap.

var moves: Array
var monsters: Array


func before_all() -> void:
	moves = Content.load_moves()
	monsters = Content.load_monsters()


func _stats() -> Dictionary:
	return {"STR": 200, "AGI": 80, "VIT": 200, "END": 50, "SEN": 200}


func _ally(id: String, clazz: String, effects: Array = []) -> Dictionary:
	return Battle.make_ally_combatant(id, clazz, 10, _stats(), "", 0.0, [], effects)


func _seeded_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _grunt(id: String, role: String = "bruiser") -> Dictionary:
	return Battle.make_enemy_combatant(id, 300.0, false, id, "", false, role, "physical")


func _boss(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(id, 1400.0, true, "Boss", "", false, "bruiser", "physical")


func _strike() -> Dictionary:
	return Content.move_by_id(moves, "move_warrior_strike")


func _last_damage(b: Battle) -> int:
	for i in range(b.log.size() - 1, -1, -1):
		if String(b.log[i].get("type", "")) == "damage":
			return int(b.log[i]["damage"])
	return -1


func _last_crit(b: Battle) -> bool:
	for i in range(b.log.size() - 1, -1, -1):
		if String(b.log[i].get("type", "")) == "damage":
			return bool(b.log[i]["crit"])
	return false


func test_stat_pct_folds_into_the_built_combatant() -> void:
	var base := Battle.make_ally_combatant("p", "WARRIOR", 10, _stats())
	var boosted := Battle.make_ally_combatant(
		"p",
		"WARRIOR",
		10,
		_stats(),
		"",
		0.0,
		[],
		[{"effect": "stat_pct", "stat": "patk", "value": 12}]
	)
	assert_almost_eq(
		float(boosted["patk"]), float(base["patk"]) * 1.12, float(base["patk"]) * 0.005
	)
	assert_eq(int(boosted["set_effects"].size()), 1)
	assert_eq(base["set_effects"], [])


func test_break_contribution_raises_boss_break_fill() -> void:
	var res := {"damage": 400, "crit": false}
	var plain := Battle.new([_ally("p", "WARRIOR")], [_boss("b")], moves, false, _seeded_rng(1))
	var bc := plain._combatant_by_id("b")
	plain._land_hit(plain._combatant_by_id("p"), bc, res.duplicate(), "", "", true)
	var plain_fill: float = bc["break_current"]
	var eff := [{"effect": "break_contribution", "value": 0.15}]
	var buffed := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_boss("b")], moves, false, _seeded_rng(1)
	)
	var bc2 := buffed._combatant_by_id("b")
	buffed._land_hit(buffed._combatant_by_id("p"), bc2, res.duplicate(), "", "", true)
	assert_almost_eq(float(bc2["break_current"]), plain_fill * 1.15, plain_fill * 0.02)


func test_focus_damage_only_applies_to_the_focus_target() -> void:
	var eff := [{"effect": "focus_damage", "value": 40}]
	var b1 := Battle.new([_ally("p", "WARRIOR", eff)], [_grunt("e")], moves, false, _seeded_rng(5))
	b1.focus_target_id = "e"
	b1._apply_attack(b1._combatant_by_id("p"), _strike(), "e")
	var dmg_focus := _last_damage(b1)
	var b2 := Battle.new([_ally("p", "WARRIOR")], [_grunt("e")], moves, false, _seeded_rng(5))
	b2.focus_target_id = "e"
	b2._apply_attack(b2._combatant_by_id("p"), _strike(), "e")
	var dmg_plain := _last_damage(b2)
	assert_gt(dmg_focus, dmg_plain)
	var b3 := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_grunt("e"), _grunt("f")], moves, false, _seeded_rng(5)
	)
	b3.focus_target_id = "f"
	b3._apply_attack(b3._combatant_by_id("p"), _strike(), "e")
	assert_eq(_last_damage(b3), dmg_plain)


func test_vs_armoured_only_applies_to_armoured_role() -> void:
	var eff := [{"effect": "vs_armoured", "value": 50}]
	var arm := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_grunt("e", "armoured")], moves, false, _seeded_rng(9)
	)
	arm._apply_attack(arm._combatant_by_id("p"), _strike(), "e")
	var arm_plain := Battle.new(
		[_ally("p", "WARRIOR")], [_grunt("e", "armoured")], moves, false, _seeded_rng(9)
	)
	arm_plain._apply_attack(arm_plain._combatant_by_id("p"), _strike(), "e")
	assert_gt(_last_damage(arm), _last_damage(arm_plain))
	var bru := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_grunt("e", "bruiser")], moves, false, _seeded_rng(9)
	)
	bru._apply_attack(bru._combatant_by_id("p"), _strike(), "e")
	var bru_plain := Battle.new(
		[_ally("p", "WARRIOR")], [_grunt("e", "bruiser")], moves, false, _seeded_rng(9)
	)
	bru_plain._apply_attack(bru_plain._combatant_by_id("p"), _strike(), "e")
	assert_eq(_last_damage(bru), _last_damage(bru_plain))


func test_vulnerable_potency_deepens_damage_only_when_target_is_vulnerable() -> void:
	var eff := [{"effect": "vulnerable_potency", "value": 0.20}]
	var vuln := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_grunt("e")], moves, false, _seeded_rng(3)
	)
	vuln.apply_status(vuln._combatant_by_id("e"), "vulnerable", 3)
	vuln._apply_attack(vuln._combatant_by_id("p"), _strike(), "e")
	var base := Battle.new([_ally("p", "WARRIOR")], [_grunt("e")], moves, false, _seeded_rng(3))
	base.apply_status(base._combatant_by_id("e"), "vulnerable", 3)
	base._apply_attack(base._combatant_by_id("p"), _strike(), "e")
	assert_gt(_last_damage(vuln), _last_damage(base))
	# M3: potency DEEPENS the x1.25 Vulnerable (x1.25 -> x1.25+v), it does not
	# stack a separate multiplier. With v = 0.20 the potency hit is ~1.45/1.25
	# above the plain-Vulnerable hit (slightly more, as DEF is subtracted after
	# the power scale).
	var ratio := float(_last_damage(vuln)) / float(_last_damage(base))
	assert_almost_eq(ratio, 1.45 / 1.25, 0.08)
	var nv := Battle.new([_ally("p", "WARRIOR", eff)], [_grunt("e")], moves, false, _seeded_rng(3))
	nv._apply_attack(nv._combatant_by_id("p"), _strike(), "e")
	var nv_plain := Battle.new([_ally("p", "WARRIOR")], [_grunt("e")], moves, false, _seeded_rng(3))
	nv_plain._apply_attack(nv_plain._combatant_by_id("p"), _strike(), "e")
	assert_eq(_last_damage(nv), _last_damage(nv_plain))


func test_first_strike_crit_fires_once_then_stops() -> void:
	var eff := [{"effect": "first_strike_crit"}]
	var b := Battle.new(
		[_ally("p", "WARRIOR", eff)], [_grunt("e", "armoured")], moves, false, _seeded_rng(1)
	)
	var e := b._combatant_by_id("e")
	e["hp"] = 100000
	e["max_hp"] = 100000
	var p := b._combatant_by_id("p")
	b._apply_attack(p, _strike(), "e")
	assert_true(_last_crit(b), "the unit's first attack is a forced crit")
	assert_true(bool(p.get("_first_strike_done", false)))
	b._apply_attack(p, _strike(), "e")
	assert_false(_last_crit(b), "its second attack rolls crit normally (seed picked to miss)")


func test_shield_on_turn_grants_shield_each_turn() -> void:
	var eff := [{"effect": "shield_on_turn", "value": 8}]
	var b := Battle.new([_ally("p", "GUARDIAN", eff)], [_grunt("e")], moves, true, _seeded_rng(1))
	var pc := b._combatant_by_id("p")
	assert_eq(int(pc.get("shield_hp", 0)), 0)
	b._tick_start_of_turn(pc)
	var expected := int(round(float(pc["max_hp"]) * 0.08))
	assert_gt(expected, 0)
	assert_eq(int(pc["shield_hp"]), expected)
	b._tick_start_of_turn(pc)
	assert_eq(int(pc["shield_hp"]), expected * 2)


func test_cooldown_reduction_ticks_cooldowns_faster() -> void:
	var eff := [{"effect": "cooldown_reduction", "value": 1}]
	var b := Battle.new([_ally("p", "WARRIOR", eff)], [_grunt("e")], moves, true, _seeded_rng(1))
	var pc := b._combatant_by_id("p")
	pc["cooldowns"] = {"move_warrior_cleave": 2}
	b._tick_start_of_turn(pc)
	assert_eq(int(pc["cooldowns"]["move_warrior_cleave"]), 0)
	var b2 := Battle.new([_ally("q", "WARRIOR")], [_grunt("e")], moves, true, _seeded_rng(1))
	var qc := b2._combatant_by_id("q")
	qc["cooldowns"] = {"move_warrior_cleave": 2}
	b2._tick_start_of_turn(qc)
	assert_eq(int(qc["cooldowns"]["move_warrior_cleave"]), 1)


func test_overdrive_on_low_only_below_25_percent_hp() -> void:
	var eff := [{"effect": "overdrive_on_low", "value": 30}]
	var b := Battle.new([_ally("p", "WARRIOR", eff)], [_grunt("e")], moves, false, _seeded_rng(1))
	var p := b._combatant_by_id("p")
	var full := b._outgoing_atk(p, true)
	p["hp"] = int(p["max_hp"] * 0.5)
	assert_almost_eq(b._outgoing_atk(p, true), full, full * 0.001)
	p["hp"] = int(p["max_hp"] * 0.15)
	assert_almost_eq(b._outgoing_atk(p, true), full * 1.30, full * 0.001)


func test_healing_effect_scales_a_mend() -> void:
	var eff := [{"effect": "healing", "value": 20}]
	var mend := Content.move_by_id(moves, "move_support_mend")
	var b := Battle.new(
		[_ally("p", "SUPPORT", eff), _ally("q", "WARRIOR")],
		[_grunt("e")],
		moves,
		true,
		_seeded_rng(1)
	)
	var q := b._combatant_by_id("q")
	q["hp"] = 1
	b._apply_heal(b._combatant_by_id("p"), mend, "q")
	var healed_buffed: int = int(q["hp"]) - 1
	var b2 := Battle.new(
		[_ally("p", "SUPPORT"), _ally("q", "WARRIOR")], [_grunt("e")], moves, true, _seeded_rng(1)
	)
	var q2 := b2._combatant_by_id("q")
	q2["hp"] = 1
	b2._apply_heal(b2._combatant_by_id("p"), mend, "q")
	var healed_plain: int = int(q2["hp"]) - 1
	assert_gt(healed_plain, 0)
	assert_almost_eq(float(healed_buffed), float(healed_plain) * 1.2, float(healed_plain) * 0.03)


func test_enrich_army_exposes_combat_set_effects_at_four_pieces() -> void:
	var equipment := Content.load_equipment()
	var inv := [
		{"instance_id": "i0", "equipment_def_id": "eq_ashen_vanguard_helm", "enhancement_level": 0},
		{
			"instance_id": "i1",
			"equipment_def_id": "eq_ashen_vanguard_cuirass",
			"enhancement_level": 0
		},
		{
			"instance_id": "i2",
			"equipment_def_id": "eq_ashen_vanguard_gauntlets",
			"enhancement_level": 0,
		},
		{
			"instance_id": "i3",
			"equipment_def_id": "eq_ashen_vanguard_sabatons",
			"enhancement_level": 0
		},
	]
	var shadow := {"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 5}
	shadow["equipped"] = {"HEAD": "i0", "BODY": "i1", "HANDS": "i2", "FEET": "i3"}
	var four: Dictionary = SquadBuilder.enrich_army([shadow], monsters, 10, equipment, inv)[0]
	assert_eq(int(four["combat_set_effects"].size()), 1)
	assert_eq(String(four["combat_set_effects"][0]["effect"]), "stat_pct")
	shadow["equipped"] = {"HEAD": "i0", "BODY": "i1", "HANDS": "i2"}
	var three: Dictionary = SquadBuilder.enrich_army([shadow], monsters, 10, equipment, inv)[0]
	assert_eq(three["combat_set_effects"], [])
