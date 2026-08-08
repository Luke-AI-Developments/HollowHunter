extends GutTest
## ShadowLeveling: level-up cost curve + duplicate-fuse chunk/discount (§6/§17/
## §26). See core/shadow_leveling.gd for why these numbers are invented.


func test_level_up_cost_scales_quadratically() -> void:
	assert_eq(ShadowLeveling.level_up_cost(1), 100)
	assert_eq(ShadowLeveling.level_up_cost(10), 10000)
	assert_true(ShadowLeveling.level_up_cost(10) > ShadowLeveling.level_up_cost(1))


func test_fuse_result_level_adds_the_chunk() -> void:
	assert_eq(ShadowLeveling.fuse_result_level(1), 4)
	assert_eq(ShadowLeveling.fuse_result_level(5), 8)


func test_fuse_result_level_caps_at_level_cap() -> void:
	assert_eq(ShadowLeveling.fuse_result_level(9), ShadowLeveling.LEVEL_CAP)
	assert_eq(ShadowLeveling.fuse_result_level(10), ShadowLeveling.LEVEL_CAP)


func test_fuse_cost_matches_discounted_individual_levels() -> void:
	# from level 1 -> 4: individual costs for levels 2,3,4 = 400+900+1600=2900
	var expected := int(round(2900 * ShadowLeveling.FUSE_DISCOUNT))
	assert_eq(ShadowLeveling.fuse_cost(1), expected)


func test_fuse_cost_near_cap_only_covers_remaining_levels() -> void:
	# from level 9 -> capped at 10: only level 10's cost applies
	var expected := int(round(ShadowLeveling.level_up_cost(10) * ShadowLeveling.FUSE_DISCOUNT))
	assert_eq(ShadowLeveling.fuse_cost(9), expected)


func test_fuse_is_cheaper_than_buying_the_same_levels_individually() -> void:
	var individual := (
		ShadowLeveling.level_up_cost(2)
		+ ShadowLeveling.level_up_cost(3)
		+ ShadowLeveling.level_up_cost(4)
	)
	assert_true(ShadowLeveling.fuse_cost(1) < individual)
