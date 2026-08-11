extends GutTest
## CombatMath: stat derivation + damage resolution (§16 combat overhaul).
## The Lv1/Lv40 Warrior tests reproduce the design doc's worked example
## exactly, via the same GameLogic.stats_from() the doc itself used.


func test_hp_and_patk_match_worked_lv1_warrior_example() -> void:
	var stats := GameLogic.stats_from(1, "WARRIOR")
	var combat := CombatMath.combat_stats(stats)
	assert_eq(combat["HP"], 82)
	assert_eq(combat["PATK"], 20)


func test_hp_and_patk_match_worked_lv40_warrior_example() -> void:
	var stats := GameLogic.stats_from(40, "WARRIOR")
	var combat := CombatMath.combat_stats(stats)
	assert_eq(combat["HP"], 1350)
	assert_eq(combat["PATK"], 605)


func test_matk_uses_sen() -> void:
	# L1 Mage has the highest SEN share -- matk_from_stats should track
	# SEN the same way patk_from_stats tracks STR.
	var stats := GameLogic.stats_from(1, "MAGE")
	assert_eq(CombatMath.matk_from_stats(stats), int(round(5.0 + float(stats["SEN"]) * 1.5)))


func test_def_from_stats_combines_end_and_vit() -> void:
	var def := CombatMath.def_from_stats({"END": 10, "VIT": 20})
	assert_eq(def, 10 * 0.5 + 20 * 0.2)


func test_speed_from_stats_equals_agi() -> void:
	assert_eq(CombatMath.speed_from_stats({"AGI": 37}), 37)


func test_crit_chance_scales_with_agi() -> void:
	var low := CombatMath.crit_chance_from_stats({"AGI": 10})
	var high := CombatMath.crit_chance_from_stats({"AGI": 200})
	assert_true(high > low)


func test_crit_chance_caps_at_35_percent() -> void:
	var chance := CombatMath.crit_chance_from_stats({"AGI": 100000})
	assert_eq(chance, CombatMath.CRIT_CHANCE_CAP)


func test_crit_chance_at_zero_agi_is_the_base() -> void:
	assert_eq(CombatMath.crit_chance_from_stats({"AGI": 0}), CombatMath.CRIT_CHANCE_BASE)


func test_enemy_stats_from_grubmaw_base_power() -> void:
	# Real content: mon_grubmaw base_power=120.
	var stats := CombatMath.enemy_stats(120)
	assert_eq(stats["HP"], 72)
	assert_eq(stats["ATK"], 18)


func test_enemy_stats_from_a_high_base_power_boss() -> void:
	# Real content: mon_nyxaris (S-rank) base_power=14000.
	var stats := CombatMath.enemy_stats(14000)
	assert_eq(stats["HP"], 8400)
	assert_eq(stats["ATK"], 2100)


func test_resolve_damage_floors_at_1_when_def_overwhelms_the_hit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := CombatMath.resolve_damage(1.0, 5.0, 10000.0, 0.0, rng)
	assert_eq(result["damage"], 1)
	assert_false(result["crit"])


func test_resolve_damage_never_crits_when_chance_is_zero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var result := CombatMath.resolve_damage(1.0, 100.0, 0.0, 0.0, rng)
		assert_false(result["crit"])


func test_resolve_damage_always_crits_when_chance_is_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := CombatMath.resolve_damage(1.0, 100.0, 0.0, 1.0, rng)
	assert_true(result["crit"])


func test_resolve_damage_crit_multiplies_the_hit() -> void:
	var rng_crit := RandomNumberGenerator.new()
	rng_crit.seed = 1
	var rng_no_crit := RandomNumberGenerator.new()
	rng_no_crit.seed = 1
	var crit_result := CombatMath.resolve_damage(1.0, 1000.0, 0.0, 1.0, rng_crit)
	var normal_result := CombatMath.resolve_damage(1.0, 1000.0, 0.0, 0.0, rng_no_crit)
	assert_true(crit_result["damage"] > normal_result["damage"])


func test_resolve_damage_deterministic_with_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var a := CombatMath.resolve_damage(1.3, 50.0, 5.0, 0.1, rng_a)
	var b := CombatMath.resolve_damage(1.3, 50.0, 5.0, 0.1, rng_b)
	assert_eq(a, b)
