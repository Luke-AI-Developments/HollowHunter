extends GutTest
## GateSpawner: rank pool selection (by EARNED rank, §28) and placeholder
## gate scattering.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


func test_rank_pool_for_rank_e_has_no_tier_below() -> void:
	assert_eq(GateSpawner.rank_pool_for_rank("E"), ["E", "D"])


func test_rank_pool_for_rank_spans_one_tier_each_way() -> void:
	assert_eq(GateSpawner.rank_pool_for_rank("C"), ["C", "D", "B"])


func test_rank_pool_for_rank_s_has_no_tier_above() -> void:
	assert_eq(GateSpawner.rank_pool_for_rank("S"), ["S", "A"])


func test_spawn_gates_returns_requested_count() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var gates := GateSpawner.spawn_gates(51.5, -0.1, "E", monsters, 5, rng)
	assert_eq(gates.size(), 5)


func test_spawn_gates_only_uses_the_rank_appropriate_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var gates := GateSpawner.spawn_gates(51.5, -0.1, "E", monsters, 10, rng)
	var pool := GateSpawner.rank_pool_for_rank("E")
	for g: Dictionary in gates:
		assert_true(pool.has(g["rank"]))


func test_spawn_gates_positions_stay_within_max_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var gates := GateSpawner.spawn_gates(51.5, -0.1, "E", monsters, 20, rng)
	for g: Dictionary in gates:
		assert_true(absf(g["lat"] - 51.5) <= GateSpawner.MAX_OFFSET_DEGREES)
		assert_true(absf(g["lon"] - (-0.1)) <= GateSpawner.MAX_OFFSET_DEGREES)


func test_spawn_gates_deterministic_with_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var gates_a := GateSpawner.spawn_gates(51.5, -0.1, "C", monsters, 5, rng_a)
	var gates_b := GateSpawner.spawn_gates(51.5, -0.1, "C", monsters, 5, rng_b)
	assert_eq(gates_a, gates_b)


func test_spawn_gates_each_has_a_real_monster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gates := GateSpawner.spawn_gates(51.5, -0.1, "E", monsters, 5, rng)
	for g: Dictionary in gates:
		assert_ne(g["monster_id"], "")
		assert_true(g["monster_base_power"] > 0)


func test_spawn_ticket_gate_is_placed_exactly_at_the_given_coords() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var gate := GateSpawner.spawn_ticket_gate(51.5, -0.1, "E", monsters, rng)
	assert_eq(gate["lat"], 51.5)
	assert_eq(gate["lon"], -0.1)


func test_spawn_ticket_gate_uses_the_rank_appropriate_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var pool := GateSpawner.rank_pool_for_rank("C")
	for i in 10:
		var gate := GateSpawner.spawn_ticket_gate(51.5, -0.1, "C", monsters, rng)
		assert_true(pool.has(gate["rank"]))


func test_spawn_ticket_gate_has_a_real_monster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var gate := GateSpawner.spawn_ticket_gate(51.5, -0.1, "E", monsters, rng)
	assert_ne(gate["monster_id"], "")
	assert_true(gate["monster_base_power"] > 0)


func test_spawn_ticket_gate_deterministic_with_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var gate_a := GateSpawner.spawn_ticket_gate(51.5, -0.1, "C", monsters, rng_a)
	var gate_b := GateSpawner.spawn_ticket_gate(51.5, -0.1, "C", monsters, rng_b)
	assert_eq(gate_a, gate_b)


func test_spawn_incursion_gates_returns_requested_count() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var gates := GateSpawner.spawn_incursion_gates(
		51.5, -0.1, "C", "Hollow Brood", monsters, 6, rng
	)
	assert_eq(gates.size(), 6)


func test_spawn_incursion_gates_are_all_the_incursion_family() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var gates := GateSpawner.spawn_incursion_gates(
		51.5, -0.1, "C", "Hollow Brood", monsters, 10, rng
	)
	for g: Dictionary in gates:
		var m := Content.monster_by_id(monsters, g["monster_id"])
		assert_eq(m["family"], "Hollow Brood")


func test_spawn_incursion_gates_are_flagged_with_incursion_bonus() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var gates := GateSpawner.spawn_incursion_gates(51.5, -0.1, "E", "Gloamwing", monsters, 5, rng)
	for g: Dictionary in gates:
		assert_true(g["incursion_bonus"])


func test_spawn_incursion_gates_skew_higher_than_the_normal_pool() -> void:
	# Normal E-rank pool is ["E", "D"]; incursion should bump toward ["D", "C"]
	# (no E gates at all -- "a rank higher").
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var gates := GateSpawner.spawn_incursion_gates(
		51.5, -0.1, "E", "Hollow Brood", monsters, 20, rng
	)
	for g: Dictionary in gates:
		assert_ne(g["rank"], "E")


func test_spawn_incursion_gates_handles_a_thin_family_at_the_bumped_rank() -> void:
	# Tarlings only has E/D monsters -- an E-rank hunter's incursion pool
	# bumps to ["D", "C"], which has no Tarlings at all; this must still
	# fall back to a real Tarlings monster rather than skip/crash.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var gates := GateSpawner.spawn_incursion_gates(51.5, -0.1, "E", "Tarlings", monsters, 5, rng)
	assert_eq(gates.size(), 5)
	for g: Dictionary in gates:
		var m := Content.monster_by_id(monsters, g["monster_id"])
		assert_eq(m["family"], "Tarlings")
