extends GutTest
## Nadir: floor clear resolution + rewards + boss floors (§20). Single
## clear-check, no rounds.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


func test_attempt_floor_uses_the_real_floor_power_curve() -> void:
	var result := Nadir.attempt_floor(1000000.0, 5, 10, monsters)
	assert_eq(result["target_power"], GameLogic.floor_power(5))


func test_overwhelming_power_clears_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1000000.0, 1, 10, monsters, rng)
	assert_true(result["cleared"])


func test_negligible_power_fails_reliably() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1.0, 51, 10, monsters, rng)
	assert_false(result["cleared"])


func test_deeper_floors_have_higher_target_power() -> void:
	var shallow := Nadir.attempt_floor(1000.0, 1, 10, monsters)
	var deep := Nadir.attempt_floor(1000.0, 20, 10, monsters)
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


func test_is_boss_floor_every_10th_floor() -> void:
	assert_false(Nadir.is_boss_floor(0))
	assert_false(Nadir.is_boss_floor(1))
	assert_false(Nadir.is_boss_floor(9))
	assert_true(Nadir.is_boss_floor(10))
	assert_false(Nadir.is_boss_floor(11))
	assert_true(Nadir.is_boss_floor(20))
	assert_true(Nadir.is_boss_floor(50))


func test_boss_monster_id_is_the_strongest_of_that_floors_rank() -> void:
	# floor 10 -> rank D; the strongest D-rank monster should be picked
	var boss_id := Nadir.boss_monster_id(10, monsters)
	var boss := Content.monster_by_id(monsters, boss_id)
	assert_eq(boss["rank"], "D")
	for m: Dictionary in Content.monsters_by_rank(monsters, "D"):
		assert_true(boss["base_power"] >= m["base_power"])


func test_attempt_floor_on_a_non_boss_floor_never_claims() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1000000.0, 5, 40, monsters, rng)
	assert_false(result["is_boss"])
	assert_false(result["claimed"])
	assert_eq(result["boss_monster_id"], "")


func test_attempt_floor_on_a_boss_floor_can_claim_with_high_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	# hunter_level 100 pushes claim_chance_per_try to its cap (§18)
	var result := Nadir.attempt_floor(1000000.0, 10, 100, monsters, rng)
	assert_true(result["cleared"])
	assert_true(result["is_boss"])
	assert_ne(result["boss_monster_id"], "")


func test_attempt_floor_boss_claim_only_attempted_when_cleared() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := Nadir.attempt_floor(1.0, 10, 100, monsters, rng)
	assert_false(result["cleared"])
	assert_false(result["claimed"])
