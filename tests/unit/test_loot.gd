extends GutTest
## Loot: rank-locked rarity drops.

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


func test_e_and_d_rank_drop_common() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("E", equipment, rng).get("rarity"), "COMMON")
	assert_eq(Loot.roll_drop("D", equipment, rng).get("rarity"), "COMMON")


func test_c_rank_drops_uncommon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("C", equipment, rng).get("rarity"), "UNCOMMON")


func test_b_rank_drops_rare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("B", equipment, rng).get("rarity"), "RARE")


func test_a_rank_drops_epic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("A", equipment, rng).get("rarity"), "EPIC")


func test_s_rank_has_no_legendary_base_equipment_yet() -> void:
	# The real content file has zero Legendary base_equipment entries (only
	# armor-set pieces would be Legendary, and sets are excluded this
	# patch) -- so S-rank correctly drops nothing, not a bug.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(Loot.roll_drop("S", equipment, rng), {})


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
