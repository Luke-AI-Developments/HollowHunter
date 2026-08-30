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


func test_stat_modifiers_empty_is_zeros() -> void:
	var m := Traits.stat_modifiers(pool, [])
	assert_eq(m["power_pct"], 0.0)
	assert_eq(m["combat_pct"], {})


func test_stat_modifiers_sums_power_pct() -> void:
	# soulbound 0.10 + frostblooded 0.08
	var m := Traits.stat_modifiers(pool, ["soulbound", "frostblooded"])
	assert_almost_eq(m["power_pct"], 0.18, 0.0001)
	assert_eq(m["combat_pct"], {})


func test_stat_modifiers_sums_combat_pct_per_stat() -> void:
	# sturdy VIT +0.10, ironhide END +0.10
	var m := Traits.stat_modifiers(pool, ["sturdy", "ironhide"])
	assert_almost_eq(m["combat_pct"]["VIT"], 0.10, 0.0001)
	assert_almost_eq(m["combat_pct"]["END"], 0.10, 0.0001)
	assert_almost_eq(m["power_pct"], 0.10, 0.0001)  # sturdy 0.05 + ironhide 0.05


func test_stat_modifiers_same_stat_from_two_traits_adds() -> void:
	# keen STR +0.10, monarchs_favour STR +0.08
	var m := Traits.stat_modifiers(pool, ["keen", "monarchs_favour"])
	assert_almost_eq(m["combat_pct"]["STR"], 0.18, 0.0001)
	assert_almost_eq(m["power_pct"], 0.17, 0.0001)  # keen 0.05 + monarchs_favour 0.12


func test_stat_modifiers_negative_subtracts() -> void:
	# sturdy VIT +0.10 then brittle END -0.12 (different stats) + cowardly STR -0.10
	var m := Traits.stat_modifiers(pool, ["brittle", "cowardly"])
	assert_almost_eq(m["combat_pct"]["END"], -0.12, 0.0001)
	assert_almost_eq(m["combat_pct"]["STR"], -0.10, 0.0001)
	assert_almost_eq(m["power_pct"], -0.11, 0.0001)  # brittle -0.06 + cowardly -0.05


func test_stat_modifiers_unknown_id_contributes_nothing() -> void:
	var m := Traits.stat_modifiers(pool, ["sturdy", "not_a_trait"])
	assert_almost_eq(m["combat_pct"]["VIT"], 0.10, 0.0001)
	assert_eq(m["combat_pct"].size(), 1)
	assert_almost_eq(m["power_pct"], 0.05, 0.0001)  # sturdy 0.05, unknown id contributes nothing


func test_combat_only_trait_now_contributes_visible_power_pct() -> void:
	# The whole point of §6b-part-3 Item 3: a combat-only trait must move the
	# power number, not just the hidden combat stats.
	assert_almost_eq(Traits.stat_modifiers(pool, ["fleet"])["power_pct"], 0.06, 0.0001)
	assert_almost_eq(Traits.stat_modifiers(pool, ["sluggish"])["power_pct"], -0.06, 0.0001)
