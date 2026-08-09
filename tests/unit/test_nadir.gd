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


func test_essence_for_floor_is_half_the_floor_power() -> void:
	var floor_power := GameLogic.floor_power(10)
	assert_eq(Nadir.essence_for_floor(10), int(round(floor_power * 0.5)))


func test_essence_for_floor_scales_with_depth() -> void:
	assert_true(Nadir.essence_for_floor(30) > Nadir.essence_for_floor(5))


func test_rank_for_floor_climbs_one_tier_every_10_floors() -> void:
	assert_eq(Nadir.rank_for_floor(1), "E")
	assert_eq(Nadir.rank_for_floor(9), "E")
	assert_eq(Nadir.rank_for_floor(10), "D")
	assert_eq(Nadir.rank_for_floor(19), "D")
	assert_eq(Nadir.rank_for_floor(20), "C")
	assert_eq(Nadir.rank_for_floor(30), "B")
	assert_eq(Nadir.rank_for_floor(40), "A")
	assert_eq(Nadir.rank_for_floor(50), "S")
	assert_eq(Nadir.rank_for_floor(200), "S")
