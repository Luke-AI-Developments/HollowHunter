extends GutTest
## Loot: rank-locked rarity drops, plus armor-set pieces (patch 3) joining
## the pool by their set's OWN tier rather than the piece's rarity -- see
## core/loot.gd for why a D-tier (RARE-rarity) set doesn't ride along with
## the generic RANK_TO_RARITY's B-rank->RARE mapping.

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


func test_e_rank_drops_common() -> void:
	# No E-tier armor set exists, so E-rank's pool is regular items only.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("E", equipment, rng).get("rarity"), "COMMON")


func test_c_rank_drops_uncommon() -> void:
	# No C-tier armor set exists, so C-rank's pool is regular items only.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("C", equipment, rng).get("rarity"), "UNCOMMON")


func test_a_rank_drops_epic() -> void:
	# No A-tier armor set exists, so A-rank's pool is regular items only.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("A", equipment, rng).get("rarity"), "EPIC")


func test_unknown_rank_defaults_to_common() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("Z", equipment, rng).get("rarity"), "COMMON")


func test_drop_is_a_real_equipment_def() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var drop := Loot.roll_drop("B", equipment, rng)
	assert_ne(drop.get("id", ""), "")
	assert_true(drop.has("power_bonus"))
	assert_true(drop.has("clazz"))


## D/B/S all have a matching-tier armor set, so their pools are a MIX of the
## rank's regular rarity and that tier's (higher) set-piece rarity. Sampling
## across many fixed seeds (deterministic, not flaky) rather than asserting
## on one roll, since either outcome is a valid, intended result.
func test_d_rank_pool_mixes_common_items_and_rare_set_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	var seen_regular := false
	var seen_set_piece := false
	for seed in range(1, 60):
		rng.seed = seed
		var drop := Loot.roll_drop("D", equipment, rng)
		if drop.get("set_id", "") != "":
			seen_set_piece = true
			assert_eq(drop.get("rarity"), "RARE")
		else:
			seen_regular = true
			assert_eq(drop.get("rarity"), "COMMON")
	assert_true(seen_regular)
	assert_true(seen_set_piece)


func test_b_rank_pool_mixes_rare_items_and_epic_set_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	var seen_regular := false
	var seen_set_piece := false
	for seed in range(1, 60):
		rng.seed = seed
		var drop := Loot.roll_drop("B", equipment, rng)
		if drop.get("set_id", "") != "":
			seen_set_piece = true
			assert_eq(drop.get("rarity"), "EPIC")
		else:
			seen_regular = true
			assert_eq(drop.get("rarity"), "RARE")
	assert_true(seen_regular)
	assert_true(seen_set_piece)


## The real content file has zero regular LEGENDARY base_equipment entries
## -- only S-tier set pieces are Legendary -- so S-rank's pool is now
## entirely (and always) S-tier set pieces, never empty like before patch 3.
func test_s_rank_drops_only_legendary_set_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var drop := Loot.roll_drop("S", equipment, rng)
	assert_ne(drop.get("set_id", ""), "")
	assert_eq(drop.get("rarity"), "LEGENDARY")
