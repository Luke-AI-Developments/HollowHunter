extends GutTest
## Unit tests for GameLogic — mirrors the worked examples in the design bible.
## Run with GUT. All values match the doc (§16/§29/§30).


func test_exp_to_next_is_linear():
	assert_eq(GameLogic.exp_to_next(5), 500)
	assert_eq(GameLogic.exp_to_next(40), 4000)


func test_stats_from_warrior_l20():
	# L20 Warrior: 500 points -> STR 200 / VIT 125 / END 75 / AGI 50 / SEN 50 (§16)
	var s := GameLogic.stats_from(20, "WARRIOR")
	assert_eq(s["STR"], 200)
	assert_eq(s["VIT"], 125)
	assert_eq(s["END"], 75)
	assert_eq(s["AGI"], 50)
	assert_eq(s["SEN"], 50)


func test_stats_sum_matches_points():
	var s := GameLogic.stats_from(12, "MAGE")
	var total := 0
	for v in s.values():
		total += v
	# allow small rounding drift
	assert_almost_eq(total, 12 * GameLogic.STAT_POINTS_PER_LEVEL, 3)


func test_new_hunter_personal_power_is_145():
	# L1: 25 stat points -> sum 25; personal = 25*5 + 1*20 = 145 (§16 worked example)
	var s := GameLogic.stats_from(1, "WARRIOR")
	assert_eq(GameLogic.personal_power(s, 1, 0), 145)


func test_shadow_combat_stats_higher_base_power_beats_lower_at_same_level_class():
	var weak := GameLogic.shadow_combat_stats(120, 1, "WARRIOR")  # Grubmaw-tier (E)
	var strong := GameLogic.shadow_combat_stats(2650, 1, "WARRIOR")  # Duskdrake-tier (B)
	assert_true(strong["STR"] > weak["STR"])
	assert_true(strong["VIT"] > weak["VIT"])


func test_shadow_combat_stats_scales_up_with_level_at_same_base_power():
	var low_level := GameLogic.shadow_combat_stats(1000, 1, "MAGE")
	var high_level := GameLogic.shadow_combat_stats(1000, 20, "MAGE")
	assert_true(high_level["SEN"] > low_level["SEN"])


func test_shadow_combat_stats_preserves_the_class_profile_shape():
	# A Warrior's grade/level scaling is a uniform multiplier -- it doesn't
	# change which stat the class profile favors.
	var stats := GameLogic.shadow_combat_stats(5000, 15, "WARRIOR")
	assert_true(stats["STR"] > stats["SEN"])


func test_shadow_combat_stats_matches_the_documented_multiplier():
	var level := 10
	var clazz := "ASSASSIN"
	var base_power := 2650
	var raw := GameLogic.stats_from(level, clazz)
	var baseline := GameLogic.personal_power(raw, level, 0)
	var grade_scale := GameLogic.shadow_power(base_power, level, 0)
	var multiplier := float(grade_scale) / float(baseline)
	var scaled := GameLogic.shadow_combat_stats(base_power, level, clazz)
	for stat in raw.keys():
		assert_eq(scaled[stat], int(round(float(raw[stat]) * multiplier)))


func test_shadow_combat_stats_handles_level_zero_without_dividing_by_zero():
	var stats := GameLogic.shadow_combat_stats(1000, 0, "WARRIOR")
	assert_eq(stats.keys().size(), 5)


func test_clear_probability_is_even_at_ratio_one():
	assert_almost_eq(GameLogic.clear_probability(1000, 1000), 0.5, 0.001)


func test_clear_probability_is_monotonic():
	assert_true(GameLogic.clear_probability(2000, 1000) > 0.5)
	assert_true(GameLogic.clear_probability(500, 1000) < 0.5)


func test_gate_weight_dampens_army():
	# 1000 + 4000*0.25 = 2000
	assert_eq(GameLogic.gate_power(1000, 4000), 2000)


func test_raid_weight_uses_full_army():
	# 1000 + 4000*1.0 = 5000
	assert_eq(GameLogic.raid_power(1000, 4000), 5000)


func test_claim_chance_rises_with_level_and_caps():
	assert_true(GameLogic.claim_chance_per_try(0.02, 40) > GameLogic.claim_chance_per_try(0.02, 0))
	assert_true(GameLogic.claim_chance_per_try(0.90, 100) <= GameLogic.CLAIM_CAP + 0.0001)


func test_floor_power_grows():
	assert_true(GameLogic.floor_power(20) > GameLogic.floor_power(1))


func test_daily_exp_signature_bonus():
	var plain := GameLogic.daily_exp(8000, 30, 30, false)
	var matched := GameLogic.daily_exp(8000, 30, 30, true)
	assert_true(matched > plain)


func test_daily_exp_below_soft_cap_is_unaffected() -> void:
	# Below GameLogic.DAILY_EXP_SOFT_CAP, the taper never kicks in --
	# same result as the raw formula.
	var exp := GameLogic.daily_exp(2000, 0, 20, false)
	var raw := int(round(2000 / 100.0 + 20 * 10.0))
	assert_eq(exp, raw)


func test_daily_exp_above_soft_cap_is_tapered() -> void:
	# A big day (way above the cap) should score much less than the raw
	# linear formula would give, but still more than the cap itself.
	var raw := 2000 / 100.0 + 300 * 10.0  # a 300-workout-minute day
	var capped := GameLogic.daily_exp(2000, 0, 300, false)
	assert_true(capped < raw)
	assert_true(capped > GameLogic.DAILY_EXP_SOFT_CAP)


func test_daily_exp_taper_never_reduces_a_huge_day_below_the_cap() -> void:
	var exp := GameLogic.daily_exp(100000, 0, 1000, false)
	assert_true(exp >= GameLogic.DAILY_EXP_SOFT_CAP)


func test_daily_exp_rest_bonus_scales_up_the_final_total() -> void:
	var plain := GameLogic.daily_exp(2000, 0, 20, false, false)
	var rested := GameLogic.daily_exp(2000, 0, 20, false, true)
	assert_eq(rested, int(round(plain * GameLogic.REST_BONUS_MULT)))


func test_rank_for_level():
	assert_eq(GameLogic.rank_for_level(1), "E")
	assert_eq(GameLogic.rank_for_level(5), "D")
	assert_eq(GameLogic.rank_for_level(12), "C")
	assert_eq(GameLogic.rank_for_level(40), "S")


func test_stage_for_rank_early_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("E"), "early")
	assert_eq(GameLogic.stage_for_rank("D"), "early")


func test_stage_for_rank_mid_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("C"), "mid")
	assert_eq(GameLogic.stage_for_rank("B"), "mid")


func test_stage_for_rank_late_ranks() -> void:
	assert_eq(GameLogic.stage_for_rank("A"), "late")
	assert_eq(GameLogic.stage_for_rank("S"), "late")


func test_stage_for_rank_unknown_falls_back_to_early() -> void:
	assert_eq(GameLogic.stage_for_rank("Z"), "early")


func test_essence_for_gate_matches_the_source_table():
	# §26: Essence per gate ≈ E 20 · D 50 · C 120 · B 300 · A 700 · S 1,500
	assert_eq(GameLogic.essence_for_gate("E"), 20)
	assert_eq(GameLogic.essence_for_gate("D"), 50)
	assert_eq(GameLogic.essence_for_gate("C"), 120)
	assert_eq(GameLogic.essence_for_gate("B"), 300)
	assert_eq(GameLogic.essence_for_gate("A"), 700)
	assert_eq(GameLogic.essence_for_gate("S"), 1500)


func test_essence_for_gate_unknown_rank_is_zero():
	assert_eq(GameLogic.essence_for_gate("Z"), 0)


func test_apply_set_power_pct_zero_is_unchanged():
	assert_eq(GameLogic.apply_set_power_pct(1000, 0.0), 1000)


func test_apply_set_power_pct_scales_up():
	assert_eq(GameLogic.apply_set_power_pct(1000, 0.10), 1100)
	assert_eq(GameLogic.apply_set_power_pct(1000, 0.06), 1060)


func test_grade_name_matches_the_ladder():
	# §6: Wraith (E) - Soldier (D) - Knight (C) - General (B) - Warlord (A) - Sovereign (S)
	assert_eq(GameLogic.grade_name("E"), "Wraith")
	assert_eq(GameLogic.grade_name("D"), "Soldier")
	assert_eq(GameLogic.grade_name("C"), "Knight")
	assert_eq(GameLogic.grade_name("B"), "General")
	assert_eq(GameLogic.grade_name("A"), "Warlord")
	assert_eq(GameLogic.grade_name("S"), "Sovereign")


func test_grade_name_unknown_rank_falls_back_to_the_letter():
	assert_eq(GameLogic.grade_name("Z"), "Z")


func test_essence_for_converted_shadow_matches_the_source_table():
	# §26: Essence per converted shadow ≈ E1 D2 C4 B8 A15 S30
	assert_eq(GameLogic.essence_for_converted_shadow("E"), 1)
	assert_eq(GameLogic.essence_for_converted_shadow("D"), 2)
	assert_eq(GameLogic.essence_for_converted_shadow("C"), 4)
	assert_eq(GameLogic.essence_for_converted_shadow("B"), 8)
	assert_eq(GameLogic.essence_for_converted_shadow("A"), 15)
	assert_eq(GameLogic.essence_for_converted_shadow("S"), 30)


func test_essence_for_converted_shadow_unknown_grade_is_zero():
	assert_eq(GameLogic.essence_for_converted_shadow("Z"), 0)


func test_essence_for_scrapped_item_by_rarity() -> void:
	assert_eq(GameLogic.essence_for_scrapped_item("COMMON"), 2)
	assert_eq(GameLogic.essence_for_scrapped_item("LEGENDARY"), 32)


func test_essence_for_scrapped_item_unknown_rarity_is_zero() -> void:
	assert_eq(GameLogic.essence_for_scrapped_item("NOT_A_RARITY"), 0)


func test_shadow_power_trait_pct_scales_the_result() -> void:
	var base_p := GameLogic.shadow_power(1000, 5, 10, 0, 0, 0.0)
	var boosted := GameLogic.shadow_power(1000, 5, 10, 0, 0, 0.10)
	assert_almost_eq(float(boosted) / float(base_p), 1.10, 0.01)


func test_shadow_power_default_trait_pct_is_a_no_op() -> void:
	assert_eq(
		GameLogic.shadow_power(1234, 7, 12, 30, 8), GameLogic.shadow_power(1234, 7, 12, 30, 8, 0.0)
	)


func test_shadow_combat_stats_trait_pct_raises_the_named_stat() -> void:
	var baseline := GameLogic.shadow_combat_stats(2000, 5, "WARRIOR")
	var boosted := GameLogic.shadow_combat_stats(2000, 5, "WARRIOR", {"VIT": 0.20})
	assert_gt(boosted["VIT"], baseline["VIT"])
	assert_almost_eq(float(boosted["VIT"]) / float(baseline["VIT"]), 1.20, 0.05)
	# a stat not in the dict is untouched
	assert_eq(boosted["AGI"], baseline["AGI"])


func test_shadow_combat_stats_negative_trait_pct_lowers_the_stat() -> void:
	var baseline := GameLogic.shadow_combat_stats(2000, 5, "WARRIOR")
	var weakened := GameLogic.shadow_combat_stats(2000, 5, "WARRIOR", {"END": -0.15})
	assert_lt(weakened["END"], baseline["END"])


func test_shadow_combat_stats_empty_dict_is_a_no_op() -> void:
	assert_eq(
		GameLogic.shadow_combat_stats(1500, 6, "MAGE"),
		GameLogic.shadow_combat_stats(1500, 6, "MAGE", {})
	)


func test_army_power_reads_per_shadow_trait_power_pct() -> void:
	var plain := [{"base_power": 1000, "level": 5}]
	var boosted := [{"base_power": 1000, "level": 5, "trait_power_pct": 0.10}]
	assert_gt(GameLogic.army_power(boosted, 10), GameLogic.army_power(plain, 10))


func test_trait_essence_multiplier_empty_is_one() -> void:
	assert_eq(GameLogic.trait_essence_multiplier([]), 1.0)


func test_trait_essence_multiplier_scavenger_and_soulbound() -> void:
	assert_almost_eq(GameLogic.trait_essence_multiplier(["scavenger"]), 1.10, 0.0001)
	assert_almost_eq(GameLogic.trait_essence_multiplier(["soulbound"]), 1.20, 0.0001)
	assert_almost_eq(GameLogic.trait_essence_multiplier(["scavenger", "soulbound"]), 1.30, 0.0001)


func test_trait_essence_multiplier_stacks_duplicates_and_ignores_others() -> void:
	assert_almost_eq(GameLogic.trait_essence_multiplier(["scavenger", "scavenger"]), 1.20, 0.0001)
	assert_almost_eq(
		GameLogic.trait_essence_multiplier(["sturdy", "executioner", "soulbound"]), 1.20, 0.0001
	)
