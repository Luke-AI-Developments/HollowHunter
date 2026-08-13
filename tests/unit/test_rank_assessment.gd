extends GutTest
## RankAssessment: Rank-Up Trials (§28). See core/rank_assessment.gd for
## why Trial Boss/reward numbers are invented.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


func test_next_assessment_rank_unlocked_by_level() -> void:
	# level 5 unlocks D (rank_for_level(5) == "D"); earned rank is still E.
	assert_eq(RankAssessment.next_assessment_rank(5, "E"), "D")


func test_next_assessment_rank_none_below_threshold() -> void:
	assert_eq(RankAssessment.next_assessment_rank(4, "E"), "")


func test_next_assessment_rank_only_ever_one_above_earned() -> void:
	# level 40 unlocks S, but earned rank is only D -- next Trial is C,
	# not a skip straight to S.
	assert_eq(RankAssessment.next_assessment_rank(40, "D"), "C")


func test_next_assessment_rank_none_once_maxed() -> void:
	assert_eq(RankAssessment.next_assessment_rank(100, "S"), "")


func test_trial_boss_id_is_the_strongest_of_that_rank() -> void:
	var boss_id := RankAssessment.trial_boss_id("D", monsters)
	var boss := Content.monster_by_id(monsters, boss_id)
	assert_eq(boss["rank"], "D")
	for m: Dictionary in Content.monsters_by_rank(monsters, "D"):
		assert_true(boss["base_power"] >= m["base_power"])


func test_trial_target_power_is_1_2x_the_boss() -> void:
	var boss := Content.monster_by_id(monsters, RankAssessment.trial_boss_id("D", monsters))
	var expected := int(round(boss["base_power"] * 1.2))
	assert_eq(RankAssessment.trial_target_power("D", monsters), expected)


func test_essence_reward_scales_with_rank_tier() -> void:
	assert_true(RankAssessment.essence_reward("S") > RankAssessment.essence_reward("D"))


func test_crystal_reward_scales_with_rank_tier() -> void:
	assert_true(RankAssessment.crystal_reward("S") > RankAssessment.crystal_reward("D"))


func test_crystal_reward_matches_the_per_tier_constant() -> void:
	assert_eq(RankAssessment.crystal_reward("D"), RankAssessment.CRYSTAL_REWARD_PER_RANK_TIER)


func test_attempt_overwhelming_power_clears_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := RankAssessment.attempt(10000000.0, "D", monsters, rng)
	assert_true(result["cleared"])
	assert_ne(result["boss_monster_id"], "")


func test_attempt_negligible_power_fails_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := RankAssessment.attempt(1.0, "S", monsters, rng)
	assert_false(result["cleared"])
