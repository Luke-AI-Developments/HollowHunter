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


func test_rank_for_level():
	assert_eq(GameLogic.rank_for_level(1), "E")
	assert_eq(GameLogic.rank_for_level(5), "D")
	assert_eq(GameLogic.rank_for_level(12), "C")
	assert_eq(GameLogic.rank_for_level(40), "S")


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
