extends GutTest
## Content loader tests, plus one test proving content wires cleanly into
## GameLogic's pure functions (a real monster's base_power -> shadow_power).

var monsters: Array
var equipment: Dictionary
var moves: Array


func before_all() -> void:
	monsters = Content.load_monsters()
	equipment = Content.load_equipment()
	moves = Content.load_moves()


func test_all_57_monsters_load() -> void:
	assert_eq(monsters.size(), 57)


func test_every_monster_has_lore_text() -> void:
	for m: Dictionary in monsters:
		assert_true(String(m.get("lore", "")).length() > 0, "missing lore: %s" % m.get("id", "?"))


func test_equipment_loads_50_base_60_set_pieces_15_sets() -> void:
	# 50 non-set base pieces + 60 armor-set pieces (4/slot x 15 sets, §15
	# patch 3) = 110 base_equipment entries.
	assert_eq(equipment["base_equipment"].size(), 110)
	var non_set: Array = equipment["base_equipment"].filter(
		func(i: Dictionary) -> bool: return i.get("set_id", "") == ""
	)
	assert_eq(non_set.size(), 50)
	assert_eq(equipment["armor_sets"].size(), 15)


func test_monster_by_id_found() -> void:
	var m := Content.monster_by_id(monsters, "mon_ashen_warden")
	assert_eq(m["name"], "Ashen Warden")
	assert_eq(m["rank"], "C")


func test_monsters_by_rank_filters() -> void:
	var e_rank := Content.monsters_by_rank(monsters, "E")
	assert_eq(e_rank.size(), 10)


func test_equipment_by_id_found() -> void:
	var e := Content.equipment_by_id(equipment, "eq_warcleaver")
	assert_eq(e["power_bonus"], 25)


func test_monster_base_power_wires_into_game_logic_shadow_power() -> void:
	var m := Content.monster_by_id(monsters, "mon_ashen_warden")
	var power := GameLogic.shadow_power(m["base_power"], 1, 10)
	assert_true(power > 0)


func test_monster_families_lists_every_distinct_family_once() -> void:
	var families := Content.monster_families(monsters)
	assert_eq(families.size(), 8)
	assert_true(families.has("Hollow Brood"))
	assert_true(families.has("Rime Sylphs"))


func test_monsters_by_family_filters() -> void:
	var brood := Content.monsters_by_family(monsters, "Hollow Brood")
	assert_true(brood.size() > 0)
	for m: Dictionary in brood:
		assert_eq(m["family"], "Hollow Brood")


func test_all_25_moves_load() -> void:
	assert_eq(moves.size(), 25)


func test_move_by_id_found() -> void:
	var m := Content.move_by_id(moves, "move_warrior_execute")
	assert_eq(m["name"], "Execute")
	assert_eq(m["unlock_level"], 15)


func test_moves_by_class_returns_5_per_class() -> void:
	for clazz in ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]:
		assert_eq(Content.moves_by_class(moves, clazz).size(), 5)


func test_unlocked_moves_at_level_1_is_just_the_basic() -> void:
	var unlocked := Content.unlocked_moves(moves, "WARRIOR", 1)
	assert_eq(unlocked.size(), 1)
	assert_eq(unlocked[0]["name"], "Strike")


func test_unlocked_moves_grows_with_level() -> void:
	var unlocked := Content.unlocked_moves(moves, "WARRIOR", 15)
	assert_eq(unlocked.size(), 5)


func test_unlocked_moves_is_sorted_by_unlock_level() -> void:
	var unlocked := Content.unlocked_moves(moves, "MAGE", 20)
	var levels: Array = []
	for m: Dictionary in unlocked:
		# JSON numbers parse as float (same as monsters.json/equipment.json
		# elsewhere in this project) -- cast at the assertion, not at load
		# time, to match that existing convention.
		levels.append(int(m["unlock_level"]))
	assert_eq(levels, [1, 4, 8, 12, 16])


func test_load_shop_has_all_three_sections() -> void:
	var shop := Content.load_shop()
	assert_true(shop.has("ticket_bundles"))
	assert_true(shop.has("essence_bundles"))
	assert_true(shop.has("cosmetics"))
	assert_true(shop["ticket_bundles"].size() > 0)
	assert_true(shop["essence_bundles"].size() > 0)
	assert_true(shop["cosmetics"].size() > 0)


func test_shop_item_by_id_finds_a_real_entry() -> void:
	var shop := Content.load_shop()
	var item := Content.shop_item_by_id(shop["essence_bundles"], "shop_essence_small")
	assert_eq(int(item["essence"]), 500)  # JSON numbers parse as float, cast at assertion


func test_shop_item_by_id_unknown_id_is_empty() -> void:
	var shop := Content.load_shop()
	assert_eq(Content.shop_item_by_id(shop["cosmetics"], "cosmetic_does_not_exist"), {})
