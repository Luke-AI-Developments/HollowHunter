extends GutTest
## core/traits.gd -- §6b trait roll + resolve. Cosmetic this cycle.

var pool: Array


func before_all() -> void:
	pool = Traits.load_pool()


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_load_pool_matches_content() -> void:
	assert_eq(pool.size(), 15)


func test_roll_returns_one_to_three_ids() -> void:
	for i in range(200):
		var rolled := Traits.roll_traits(pool, _seeded(i))
		assert_between(rolled.size(), 1, 3, "roll %d out of range: %s" % [i, rolled])


func test_roll_ids_are_distinct() -> void:
	for i in range(200):
		var rolled := Traits.roll_traits(pool, _seeded(i))
		var seen := {}
		for id: String in rolled:
			assert_false(seen.has(id), "duplicate id in roll %d: %s" % [i, rolled])
			seen[id] = true


func test_roll_ids_all_exist_in_pool() -> void:
	var pool_ids := {}
	for t: Dictionary in pool:
		pool_ids[t["id"]] = true
	for i in range(200):
		for id: String in Traits.roll_traits(pool, _seeded(i)):
			assert_true(pool_ids.has(id), "unknown id %s in roll %d" % [id, i])


func test_roll_is_deterministic_for_a_seed() -> void:
	assert_eq(Traits.roll_traits(pool, _seeded(42)), Traits.roll_traits(pool, _seeded(42)))


func test_common_far_outnumbers_legendary_over_many_rolls() -> void:
	var by_rarity := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0, "legendary": 0}
	var lookup := {}
	for t: Dictionary in pool:
		lookup[t["id"]] = t["rarity"]
	for i in range(2000):
		for id: String in Traits.roll_traits(pool, _seeded(i)):
			by_rarity[lookup[id]] += 1
	assert_gt(by_rarity["common"], by_rarity["uncommon"], "common should beat uncommon")
	assert_gt(by_rarity["uncommon"], by_rarity["rare"], "uncommon should beat rare")
	assert_gt(by_rarity["rare"], by_rarity["legendary"], "rare should beat legendary")


func test_resolve_maps_ids_to_full_dicts_in_order() -> void:
	var out := Traits.resolve(pool, ["ironhide", "sturdy"])
	assert_eq(out.size(), 2)
	assert_eq(out[0]["id"], "ironhide")
	assert_eq(out[0]["name"], "Ironhide")
	assert_eq(out[0]["rarity"], "uncommon")
	assert_eq(out[0]["polarity"], "positive")
	assert_eq(out[1]["id"], "sturdy")


func test_resolve_drops_unknown_ids() -> void:
	var out := Traits.resolve(pool, ["sturdy", "not_a_real_trait", "keen"])
	assert_eq(out.size(), 2)
	assert_eq(out[0]["id"], "sturdy")
	assert_eq(out[1]["id"], "keen")


func test_resolve_empty_returns_empty() -> void:
	assert_eq(Traits.resolve(pool, []), [])
