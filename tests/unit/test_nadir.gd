extends GutTest
## Nadir: floor clear resolution (§20). Single clear-check, no rounds.


func test_attempt_floor_uses_the_real_floor_power_curve() -> void:
	var result := Nadir.attempt_floor(1000000.0, 5)
	assert_eq(result["target_power"], GameLogic.floor_power(5))


func test_overwhelming_power_clears_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1000000.0, 1, rng)
	assert_true(result["cleared"])


func test_negligible_power_fails_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1.0, 50, rng)
	assert_false(result["cleared"])


func test_deeper_floors_have_higher_target_power() -> void:
	var shallow := Nadir.attempt_floor(1000.0, 1)
	var deep := Nadir.attempt_floor(1000.0, 20)
	assert_true(deep["target_power"] > shallow["target_power"])
