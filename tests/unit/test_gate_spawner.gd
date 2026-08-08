extends GutTest
## GateSpawner: rank pool selection and placeholder gate scattering.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


func test_rank_pool_for_level_1_is_just_e() -> void:
	# rank_for_level(1) == "E", index 0 -> no tier below.
	assert_eq(GateSpawner.rank_pool_for_level(1), ["E"])


func test_rank_pool_for_level_12_includes_current_and_one_below() -> void:
	# rank_for_level(12) == "C" -> pool is [C, D].
	assert_eq(GateSpawner.rank_pool_for_level(12), ["C", "D"])


func test_spawn_gates_returns_requested_count() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var gates := GateSpawner.spawn_gates(51.5, -0.1, 1, monsters, 5, rng)
	assert_eq(gates.size(), 5)


func test_spawn_gates_only_uses_the_level_appropriate_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var gates := GateSpawner.spawn_gates(51.5, -0.1, 1, monsters, 10, rng)
	var pool := GateSpawner.rank_pool_for_level(1)
	for g: Dictionary in gates:
		assert_true(pool.has(g["rank"]))


func test_spawn_gates_positions_stay_within_max_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var gates := GateSpawner.spawn_gates(51.5, -0.1, 1, monsters, 20, rng)
	for g: Dictionary in gates:
		assert_true(absf(g["lat"] - 51.5) <= GateSpawner.MAX_OFFSET_DEGREES)
		assert_true(absf(g["lon"] - (-0.1)) <= GateSpawner.MAX_OFFSET_DEGREES)


func test_spawn_gates_deterministic_with_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var gates_a := GateSpawner.spawn_gates(51.5, -0.1, 5, monsters, 5, rng_a)
	var gates_b := GateSpawner.spawn_gates(51.5, -0.1, 5, monsters, 5, rng_b)
	assert_eq(gates_a, gates_b)


func test_spawn_gates_each_has_a_real_monster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gates := GateSpawner.spawn_gates(51.5, -0.1, 1, monsters, 5, rng)
	for g: Dictionary in gates:
		assert_ne(g["monster_id"], "")
		assert_true(g["monster_base_power"] > 0)
