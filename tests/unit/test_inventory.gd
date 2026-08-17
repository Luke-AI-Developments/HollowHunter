extends GutTest
## Inventory: filter/sort/wearer-lookup/compare/scrap-candidate logic (§17b). Pure.

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


static func _item(instance_id: String, def_id: String, locked: bool = false) -> Dictionary:
	return {
		"instance_id": instance_id,
		"equipment_def_id": def_id,
		"enhancement_level": 0,
		"locked": locked
	}


func test_filter_by_enriches_with_def_data() -> void:
	var inv := [_item("i0", "eq_warcleaver")]
	var result := Inventory.filter_by(inv, equipment, {}, [], {})
	assert_eq(result.size(), 1)
	assert_eq(result[0]["name"], "Warcleaver")
	assert_eq(result[0]["slot"], "WEAPON")
	assert_eq(result[0]["clazz"], "WARRIOR")


func test_filter_by_skips_unknown_def_ids() -> void:
	var inv := [_item("i0", "eq_does_not_exist")]
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {}), [])


func test_filter_by_class_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # WARRIOR
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"class": "WARRIOR"}).size(), 1)
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"class": "MAGE"}).size(), 0)


func test_filter_by_slot_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # WEAPON
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"slot": "WEAPON"}).size(), 1)
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"slot": "HEAD"}).size(), 0)


func test_filter_by_equipped_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver"), _item("i1", "eq_warcleaver")]
	var hunter_equipped := {"WEAPON": "i0"}
	var equipped_only := Inventory.filter_by(
		inv, equipment, hunter_equipped, [], {"equipped": "EQUIPPED"}
	)
	assert_eq(equipped_only.size(), 1)
	assert_eq(equipped_only[0]["instance_id"], "i0")
	var unequipped_only := Inventory.filter_by(
		inv, equipment, hunter_equipped, [], {"equipped": "UNEQUIPPED"}
	)
	assert_eq(unequipped_only.size(), 1)
	assert_eq(unequipped_only[0]["instance_id"], "i1")


func test_sort_by_power_descending() -> void:
	var items := [{"power_bonus": 10}, {"power_bonus": 50}, {"power_bonus": 30}]
	var sorted := Inventory.sort_by(items, "power")
	assert_eq(sorted[0]["power_bonus"], 50)
	assert_eq(sorted[2]["power_bonus"], 10)


func test_sort_by_rarity_rarest_first() -> void:
	var items := [{"rarity": "COMMON"}, {"rarity": "LEGENDARY"}, {"rarity": "RARE"}]
	var sorted := Inventory.sort_by(items, "rarity")
	assert_eq(sorted[0]["rarity"], "LEGENDARY")
	assert_eq(sorted[2]["rarity"], "COMMON")


func test_sort_by_newest_reverses_input_order() -> void:
	var items := [{"instance_id": "i0"}, {"instance_id": "i1"}, {"instance_id": "i2"}]
	var sorted := Inventory.sort_by(items, "newest")
	assert_eq(sorted[0]["instance_id"], "i2")
	assert_eq(sorted[2]["instance_id"], "i0")


func test_wearer_of_hunter() -> void:
	var result := Inventory.wearer_of("i0", {"WEAPON": "i0"}, [])
	assert_eq(result["kind"], "hunter")


func test_wearer_of_shadow() -> void:
	var army := [{"instance_id": "shadow_0", "equipped": {"WEAPON": "i0"}}]
	var result := Inventory.wearer_of("i0", {}, army)
	assert_eq(result["kind"], "shadow")
	assert_eq(result["shadow_instance_id"], "shadow_0")


func test_wearer_of_none() -> void:
	assert_eq(Inventory.wearer_of("i0", {}, [])["kind"], "none")


func test_compare_delta_against_empty_slot() -> void:
	var candidate := {"power_bonus": 100, "stat_mods": {"STR": 10}}
	var delta := Inventory.compare_delta(candidate, {})
	assert_eq(delta["power_delta"], 100)
	assert_eq(delta["stat_delta"]["STR"], 10)


func test_compare_delta_against_current_item() -> void:
	var candidate := {"power_bonus": 100, "stat_mods": {"STR": 10}}
	var current := {"power_bonus": 60, "stat_mods": {"STR": 15, "VIT": 5}}
	var delta := Inventory.compare_delta(candidate, current)
	assert_eq(delta["power_delta"], 40)
	assert_eq(delta["stat_delta"]["STR"], -5)
	assert_eq(delta["stat_delta"]["VIT"], -5)


func test_scrap_candidates_below_rarity_excludes_locked_and_equipped() -> void:
	var inv := [
		_item("i0", "eq_warcleaver"),  # COMMON, unlocked, unequipped -- candidate
		_item("i1", "eq_warcleaver", true),  # locked -- excluded
	]
	var hunter_equipped := {}
	var candidates := Inventory.scrap_candidates_below_rarity(
		inv, equipment, "UNCOMMON", hunter_equipped, []
	)
	assert_true(candidates.has("i0"))
	assert_false(candidates.has("i1"))


func test_scrap_candidates_below_rarity_excludes_equal_or_above() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # COMMON
	assert_eq(Inventory.scrap_candidates_below_rarity(inv, equipment, "COMMON", {}, []), [])


func test_scrap_candidates_unequipped_duplicates_keeps_none_spare() -> void:
	var inv := [
		_item("i0", "eq_warcleaver"), _item("i1", "eq_warcleaver"), _item("i2", "eq_warcleaver")
	]
	var hunter_equipped := {"WEAPON": "i0"}
	var candidates := Inventory.scrap_candidates_unequipped_duplicates(inv, hunter_equipped, [])
	assert_eq(candidates.size(), 2)
	assert_true(candidates.has("i1"))
	assert_true(candidates.has("i2"))
	assert_false(candidates.has("i0"))  # worn, excluded even though it's a duplicate


func test_scrap_candidates_unequipped_duplicates_no_duplicates_is_empty() -> void:
	var inv := [_item("i0", "eq_warcleaver")]
	assert_eq(Inventory.scrap_candidates_unequipped_duplicates(inv, {}, []), [])


func test_is_over_soft_cap() -> void:
	var small: Array = []
	for i in 5:
		small.append(_item("i%d" % i, "eq_warcleaver"))
	assert_false(Inventory.is_over_soft_cap(small))
	var big: Array = []
	for i in Inventory.SOFT_CAP:
		big.append(_item("i%d" % i, "eq_warcleaver"))
	assert_true(Inventory.is_over_soft_cap(big))
