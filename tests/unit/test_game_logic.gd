extends GutTest


func test_add_returns_sum() -> void:
	assert_eq(GameLogic.add(2, 3), 5)


func test_clamp_percent_clamps_above_one() -> void:
	assert_eq(GameLogic.clamp_percent(1.5), 1.0)


func test_clamp_percent_clamps_below_zero() -> void:
	assert_eq(GameLogic.clamp_percent(-0.5), 0.0)


func test_clamp_percent_passes_through_mid_range() -> void:
	assert_eq(GameLogic.clamp_percent(0.42), 0.42)
