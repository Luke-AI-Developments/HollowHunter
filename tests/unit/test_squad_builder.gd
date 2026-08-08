extends GutTest
## SquadBuilder: army enrichment and class-slotted auto-fill.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


static func _shadow(monster_id: String, level: int = 1) -> Dictionary:
	return {"instance_id": monster_id, "monster_id": monster_id, "grade": "E", "level": level}


func test_enrich_army_looks_up_name_class_and_power() -> void:
	var army := [_shadow("mon_ashen_warden")]
	var enriched := SquadBuilder.enrich_army(army, monsters, 10)
	assert_eq(enriched.size(), 1)
	assert_eq(enriched[0]["monster_name"], "Ashen Warden")
	assert_eq(enriched[0]["clazz"], "WARRIOR")
	assert_true(enriched[0]["power"] > 0)


func test_enrich_army_skips_unknown_monster_ids() -> void:
	var army := [_shadow("mon_does_not_exist")]
	assert_eq(SquadBuilder.enrich_army(army, monsters, 10), [])


func test_auto_fill_squad_picks_best_per_class_plus_flex() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR, base 350 -- class-best
		_shadow("mon_grubmaw"),  # WARRIOR, base 120 -- weaker leftover
		_shadow("mon_carapax"),  # GUARDIAN, base 500
		_shadow("mon_runtclaw"),  # ASSASSIN, base 200
		_shadow("mon_cindergnat"),  # MAGE, base 150
		_shadow("mon_snarlpack"),  # SUPPORT, base 1350
		_shadow("mon_nipclaw"),  # WARRIOR, base 210 -- stronger leftover, should win flex
	]
	var squad := SquadBuilder.auto_fill_squad(army, monsters, 1)
	assert_eq(squad.size(), 6)

	var by_class := {}
	for member: Dictionary in squad:
		by_class[member["clazz"]] = by_class.get(member["clazz"], 0) + 1
	assert_eq(by_class.get("WARRIOR", 0), 2)  # class slot + flex
	assert_eq(by_class.get("GUARDIAN", 0), 1)
	assert_eq(by_class.get("ASSASSIN", 0), 1)
	assert_eq(by_class.get("MAGE", 0), 1)
	assert_eq(by_class.get("SUPPORT", 0), 1)

	var ids: Array = squad.map(func(m: Dictionary) -> String: return m["monster_id"])
	assert_true(ids.has("mon_tuskrend"))  # WARRIOR class slot (stronger of the two)
	assert_true(ids.has("mon_nipclaw"))  # flex (stronger leftover than grubmaw)
	assert_false(ids.has("mon_grubmaw"))  # weaker leftover, not picked


func test_auto_fill_squad_never_duplicates_a_shadow() -> void:
	var army := [_shadow("mon_tuskrend")]
	var squad := SquadBuilder.auto_fill_squad(army, monsters, 1)
	var seen := {}
	for member: Dictionary in squad:
		assert_false(seen.has(member["instance_id"]))
		seen[member["instance_id"]] = true


func test_auto_fill_squad_with_empty_army_is_empty() -> void:
	assert_eq(SquadBuilder.auto_fill_squad([], monsters, 1), [])


func test_auto_fill_squad_with_one_shadow_returns_one() -> void:
	var army := [_shadow("mon_grubmaw")]
	var squad := SquadBuilder.auto_fill_squad(army, monsters, 1)
	assert_eq(squad.size(), 1)
	assert_eq(squad[0]["monster_id"], "mon_grubmaw")


func test_enrich_army_gear_raises_shadow_power() -> void:
	var equipment := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0}
	]
	var shadow := _shadow("mon_ashen_warden")  # WARRIOR, matches eq_warcleaver's clazz
	var baseline: int = SquadBuilder.enrich_army([shadow], monsters, 10)[0]["power"]

	shadow["equipped"] = {"WEAPON": "i0"}
	var geared: int = (
		SquadBuilder.enrich_army([shadow], monsters, 10, equipment, inventory)[0]["power"]
	)
	assert_true(geared > baseline)


func test_enrich_army_armor_set_bonus_raises_shadow_power() -> void:
	var equipment := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_ashen_vanguard_helm", "enhancement_level": 0},
		{
			"instance_id": "i1",
			"equipment_def_id": "eq_ashen_vanguard_cuirass",
			"enhancement_level": 0
		},
	]
	var shadow := _shadow("mon_ashen_warden")  # WARRIOR, matches the set's clazz
	var baseline: int = SquadBuilder.enrich_army([shadow], monsters, 10)[0]["power"]

	shadow["equipped"] = {"HEAD": "i0", "BODY": "i1"}
	var geared: int = (
		SquadBuilder.enrich_army([shadow], monsters, 10, equipment, inventory)[0]["power"]
	)
	assert_true(geared > baseline)


func test_enrich_army_includes_grade_name() -> void:
	var shadow := _shadow("mon_ashen_warden")
	shadow["grade"] = "B"
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_eq(enriched[0]["grade_name"], "General")


func test_surplus_shadow_ids_excludes_the_squad() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR, base 350 -- class slot
		_shadow("mon_grubmaw"),  # WARRIOR, base 120 -- weaker leftover, surplus
		_shadow("mon_carapax"),  # GUARDIAN, base 500 -- class slot
		_shadow("mon_runtclaw"),  # ASSASSIN, base 200 -- class slot
		_shadow("mon_cindergnat"),  # MAGE, base 150 -- class slot
		_shadow("mon_snarlpack"),  # SUPPORT, base 1350 -- class slot
		_shadow("mon_nipclaw"),  # WARRIOR, base 210 -- stronger leftover, wins flex
	]
	var surplus := SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5)
	assert_eq(surplus, ["mon_grubmaw"])


func test_surplus_shadow_ids_sorts_weakest_first_and_respects_count() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR 350 -- class slot
		_shadow("mon_nipclaw"),  # WARRIOR 210 -- wins flex over the two below
		_shadow("mon_grubmaw"),  # WARRIOR 120 -- surplus
		_shadow("mon_tarling"),  # WARRIOR 110 -- surplus, weakest of all
	]
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 1), ["mon_tarling"])
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5), ["mon_tarling", "mon_grubmaw"])


func test_surplus_shadow_ids_with_no_surplus_is_empty() -> void:
	var army := [_shadow("mon_grubmaw")]
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5), [])


func test_surplus_shadow_ids_skips_locked_shadows() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR 350 -- class slot
		_shadow("mon_nipclaw"),  # WARRIOR 210 -- wins flex
		_shadow("mon_grubmaw"),  # WARRIOR 120 -- surplus, but locked
		_shadow("mon_tarling"),  # WARRIOR 110 -- surplus, weakest, unlocked
	]
	army[2]["locked"] = true
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5), ["mon_tarling"])


func test_enrich_army_includes_locked_and_favorite() -> void:
	var shadow := _shadow("mon_ashen_warden")
	shadow["locked"] = true
	shadow["favorite"] = true
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_true(enriched[0]["locked"])
	assert_true(enriched[0]["favorite"])
