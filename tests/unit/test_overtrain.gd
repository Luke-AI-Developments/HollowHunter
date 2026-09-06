extends GutTest


func test_multiplier_is_half_when_overtrained() -> void:
	assert_eq(GameLogic.overtrain_exp_mult(true), 0.5)
	assert_eq(GameLogic.overtrain_exp_mult(false), 1.0)


func test_scaled_exp_halves_and_rounds() -> void:
	assert_eq(GameLogic.scaled_exp(100, true), 50)
	assert_eq(GameLogic.scaled_exp(101, true), 51)  # Godot round(50.5) -> 51 (away-from-zero)
	assert_eq(GameLogic.scaled_exp(100, false), 100)


func test_overtrain_days_constant() -> void:
	assert_eq(GameLogic.OVERTRAIN_DAYS, 6)
