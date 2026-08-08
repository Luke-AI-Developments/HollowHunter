extends GutTest
## GateEncounter: 3-round clash resolution and the full run() (clash then
## CLAIM). Extreme power ratios make outcomes deterministic regardless of
## RNG stream, except the one genuinely-probabilistic claim test.


func test_resolve_rounds_all_win_when_power_dominates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := GateEncounter.resolve_rounds(1000000.0, 1.0, rng)
	assert_true(result["cleared"])
	assert_eq(result["wins"], 3)
	assert_eq(result["rounds"], [true, true, true])


func test_resolve_rounds_all_lose_when_power_is_negligible() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := GateEncounter.resolve_rounds(1.0, 1000000.0, rng)
	assert_false(result["cleared"])
	assert_eq(result["wins"], 0)
	assert_eq(result["rounds"], [false, false, false])


func test_run_does_not_attempt_claim_when_not_cleared() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var gate := {"monster_base_power": 1000000, "monster_extract_chance": 0.9}
	var result := GateEncounter.run(1.0, gate, 50, rng)
	assert_false(result["cleared"])
	assert_false(result["claimed"])


func test_run_can_successfully_claim_when_power_dominates() -> void:
	# claim chance is capped at 90%/try over 3 tries (~99.9% overall) --
	# not literally guaranteed, so try a small spread of seeds.
	var claimed_at_least_once := false
	for seed in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var gate := {"monster_base_power": 1, "monster_extract_chance": 1.0}
		var result := GateEncounter.run(1000000.0, gate, 100, rng)
		assert_true(result["cleared"])
		if result["claimed"]:
			claimed_at_least_once = true
			break
	assert_true(claimed_at_least_once)
