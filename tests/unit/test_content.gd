extends GutTest
## Content loader tests, plus one test proving content wires cleanly into
## GameLogic's pure functions (a real monster's base_power -> shadow_power).

var monsters: Array
var equipment: Dictionary


func before_all() -> void:
	monsters = Content.load_monsters()
	equipment = Content.load_equipment()


func test_all_61_monsters_load() -> void:
	assert_eq(monsters.size(), 61)


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
