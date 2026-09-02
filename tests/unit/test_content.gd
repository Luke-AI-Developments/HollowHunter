extends GutTest
## Content loader tests, plus one test proving content wires cleanly into
## GameLogic's pure functions (a real monster's base_power -> shadow_power).

var monsters: Array
var equipment: Dictionary
var moves: Array
var traits: Array


func before_all() -> void:
	monsters = Content.load_monsters()
	equipment = Content.load_equipment()
	moves = Content.load_moves()
	traits = Content.load_traits()


func test_all_54_monsters_load() -> void:
	assert_eq(monsters.size(), 54)


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
	assert_eq(e_rank.size(), 9)


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


func test_all_26_moves_load() -> void:
	assert_eq(moves.size(), 26)


func test_move_by_id_found() -> void:
	var m := Content.move_by_id(moves, "move_warrior_execute")
	assert_eq(m["name"], "Execute")
	assert_eq(m["unlock_level"], 15)


func test_moves_by_class_returns_expected_per_class() -> void:
	for clazz in ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE"]:
		assert_eq(Content.moves_by_class(moves, clazz).size(), 5)
	assert_eq(Content.moves_by_class(moves, "SUPPORT").size(), 6)  # + Reconstitute (§9.2)


func test_reconstitute_move_exists_and_is_support_sixth() -> void:
	var mv := Content.load_moves()
	var support := Content.moves_by_class(mv, "SUPPORT")
	assert_eq(support.size(), 6)
	var recon := Content.move_by_id(mv, "move_support_reconstitute")
	assert_eq(recon["move_type"], "revive")
	assert_eq(recon["target_type"], "downed_ally")
	assert_eq(int(recon["unlock_level"]), 12)
	assert_eq(int(recon["cooldown"]), 6)


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


func test_traits_pool_loads_with_valid_shape() -> void:
	assert_eq(traits.size(), 15, "expected the 15-entry v0 trait pool")
	var rarities := ["common", "uncommon", "rare", "epic", "legendary"]
	var polarities := ["positive", "negative"]
	var ids := {}
	for t: Dictionary in traits:
		assert_true(String(t.get("id", "")).length() > 0, "trait missing id")
		assert_false(ids.has(t["id"]), "duplicate trait id: %s" % t.get("id", "?"))
		ids[t["id"]] = true
		assert_true(String(t.get("name", "")).length() > 0, "trait %s missing name" % t["id"])
		assert_true(rarities.has(t.get("rarity", "")), "trait %s bad rarity" % t["id"])
		assert_true(polarities.has(t.get("polarity", "")), "trait %s bad polarity" % t["id"])
		assert_true(
			String(t.get("effect_text", "")).length() > 0, "trait %s missing effect_text" % t["id"]
		)


func test_every_trait_has_valid_mods() -> void:
	var stat_keys := ["STR", "AGI", "VIT", "END", "SEN"]
	for t: Dictionary in traits:
		assert_true(t.has("mods"), "trait %s missing mods" % t["id"])
		var mods: Dictionary = t["mods"]
		var has_effect := false
		if mods.has("power_pct"):
			assert_true(mods["power_pct"] is float, "trait %s power_pct not a float" % t["id"])
			has_effect = true
		if mods.has("combat_pct"):
			var cp: Dictionary = mods["combat_pct"]
			assert_false(cp.is_empty(), "trait %s combat_pct is empty" % t["id"])
			for k in cp.keys():
				assert_true(stat_keys.has(k), "trait %s combat_pct bad stat %s" % [t["id"], k])
			has_effect = true
		assert_true(has_effect, "trait %s mods has neither power_pct nor combat_pct" % t["id"])


func test_monster_role_and_atk_type_fields_are_valid_when_present() -> void:
	for m: Dictionary in Content.load_monsters():
		if m.has("role"):
			assert_true(
				m["role"] in ["bruiser", "skirmisher", "armoured"],
				"%s bad role %s" % [m["id"], m["role"]]
			)
		if m.has("atk_type"):
			assert_true(m["atk_type"] in ["physical", "magic"], "%s bad atk_type" % m["id"])


func test_heavy_tag_present_on_power_strike_and_guard_strike() -> void:
	var mv := Content.load_moves()
	assert_eq(Content.move_by_id(mv, "move_warrior_power_strike")["tag"], "heavy")
	assert_eq(Content.move_by_id(mv, "move_guardian_guard_strike")["tag"], "heavy")


func test_applies_status_moves_have_valid_shape() -> void:
	var mv := Content.load_moves()
	for m: Dictionary in mv:
		if not m.has("applies_status"):
			continue
		var a: Dictionary = m["applies_status"]
		assert_true(
			a["name"] in ["vulnerable", "stun", "regen"], "%s bad applies_status name" % m["id"]
		)
		assert_true(int(a.get("turns", 0)) >= 1, "%s applies_status turns" % m["id"])
	assert_eq(
		Content.move_by_id(mv, "move_assassin_exploit_weakness")["applies_status"]["name"],
		"vulnerable"
	)
	assert_eq(Content.move_by_id(mv, "move_support_ward")["applies_status"]["name"], "regen")
	assert_eq(Content.move_by_id(mv, "move_mage_nova_burst")["applies_status"]["name"], "stun")
