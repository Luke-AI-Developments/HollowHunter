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


func test_add_exp_halves_when_overtrained() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.level = 1
	s.overtrained = true
	s.add_exp(100)
	assert_eq(s.total_exp, 50, "banked EXP is halved")


func test_add_exp_full_when_not_overtrained() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.level = 1
	s.overtrained = false
	s.add_exp(100)
	assert_eq(s.total_exp, 100)


func test_overtrain_fields_round_trip() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.consecutive_workout_days = 4
	s.overtrained = true
	var s2 := HunterState.from_dict(s.to_dict())
	assert_eq(s2.consecutive_workout_days, 4)
	assert_eq(s2.overtrained, true)


func test_overtrain_fields_default_for_old_saves() -> void:
	var s := HunterState.from_dict({})
	assert_eq(s.consecutive_workout_days, 0)
	assert_eq(s.overtrained, false)
