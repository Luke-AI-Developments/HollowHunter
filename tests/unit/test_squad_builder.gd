extends GutTest
## SquadBuilder: army enrichment, sort_shadows, resolve_party, surplus_shadow_ids.

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


func test_enrich_army_includes_the_monster_base_power():
	var army := [_shadow("mon_ashen_warden")]
	var enriched := SquadBuilder.enrich_army(army, monsters, 10)
	var monster := Content.monster_by_id(monsters, "mon_ashen_warden")
	assert_eq(enriched[0]["base_power"], monster["base_power"])


func test_enrich_army_skips_unknown_monster_ids() -> void:
	var army := [_shadow("mon_does_not_exist")]
	assert_eq(SquadBuilder.enrich_army(army, monsters, 10), [])


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


func test_enrich_army_display_name_falls_back_to_monster_name() -> void:
	var shadow := _shadow("mon_ashen_warden")
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_eq(enriched[0]["nickname"], "")
	assert_eq(enriched[0]["display_name"], "Ashen Warden")


func test_enrich_army_display_name_uses_nickname_when_set() -> void:
	var shadow := _shadow("mon_ashen_warden")
	shadow["nickname"] = "Duskfang"
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_eq(enriched[0]["nickname"], "Duskfang")
	assert_eq(enriched[0]["display_name"], "Duskfang")
	assert_eq(enriched[0]["monster_name"], "Ashen Warden")


func test_surplus_shadow_ids_still_excludes_locked_and_fielded() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR 350 -- fielded
		_shadow("mon_grubmaw"),  # WARRIOR 120 -- locked
		_shadow("mon_runtclaw"),  # ASSASSIN 200 -- free, weakest free
		_shadow("mon_carapax"),  # GUARDIAN 500 -- free
	]
	army[1]["locked"] = true
	var surplus := SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5, ["mon_tuskrend"])
	assert_false(surplus.has("mon_tuskrend"))  # fielded -- protected
	assert_false(surplus.has("mon_grubmaw"))  # locked -- protected
	assert_eq(surplus, ["mon_runtclaw", "mon_carapax"])  # free, weakest first


func test_surplus_shadow_ids_sorts_weakest_first_and_respects_count() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR 350
		_shadow("mon_nipclaw"),  # WARRIOR 210
		_shadow("mon_grubmaw"),  # WARRIOR 120
		_shadow("mon_tarling"),  # WARRIOR 110 -- weakest of all
	]
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 1, []), ["mon_tarling"])
	assert_eq(
		SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5, []),
		["mon_tarling", "mon_grubmaw", "mon_nipclaw", "mon_tuskrend"]
	)


func test_surplus_shadow_ids_with_no_surplus_is_empty() -> void:
	# the sole shadow is fielded -> nothing left to offer as fodder
	var army := [_shadow("mon_grubmaw")]
	assert_eq(SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5, ["mon_grubmaw"]), [])


func test_surplus_shadow_ids_skips_locked_shadows() -> void:
	var army := [
		_shadow("mon_tuskrend"),  # WARRIOR 350 -- fielded
		_shadow("mon_nipclaw"),  # WARRIOR 210 -- fielded
		_shadow("mon_grubmaw"),  # WARRIOR 120 -- surplus, but locked
		_shadow("mon_tarling"),  # WARRIOR 110 -- surplus, weakest, unlocked
	]
	army[2]["locked"] = true
	assert_eq(
		SquadBuilder.surplus_shadow_ids(army, monsters, 1, 5, ["mon_tuskrend", "mon_nipclaw"]),
		["mon_tarling"]
	)


func test_surplus_shadow_ids_never_includes_a_fielded_shadow() -> void:
	var army := [
		{
			"instance_id": "weak",
			"monster_id": "mon_grubmaw",
			"grade": "E",
			"level": 1,
			"locked": false
		},
		{
			"instance_id": "mid",
			"monster_id": "mon_runtclaw",
			"grade": "E",
			"level": 1,
			"locked": false
		},
	]
	# "weak" is the weakest but it's fielded -> must not be offered as fodder
	var ids := SquadBuilder.surplus_shadow_ids(army, Content.load_monsters(), 10, 2, ["weak"])
	assert_false(ids.has("weak"))
	assert_true(ids.has("mid"))


func test_enrich_army_includes_locked_and_favorite() -> void:
	var shadow := _shadow("mon_ashen_warden")
	shadow["locked"] = true
	shadow["favorite"] = true
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_true(enriched[0]["locked"])
	assert_true(enriched[0]["favorite"])


func _six_class_army() -> Array:
	return [
		_shadow("mon_tuskrend"),  # WARRIOR, base 350
		_shadow("mon_carapax"),  # GUARDIAN, base 500
		_shadow("mon_runtclaw"),  # ASSASSIN, base 200
		_shadow("mon_cindergnat"),  # MAGE, base 150
		_shadow("mon_snarlpack"),  # SUPPORT, base 1350
	]


func test_resolve_party_honors_a_full_manual_pick_in_order() -> void:
	var army := _six_class_army()
	var enriched := SquadBuilder.enrich_army(army, monsters, 1)
	# Pick the 3 weakest of the enriched army, in a specific order -- the
	# opposite of what auto-pick-by-power would choose.
	var by_power := enriched.duplicate()
	by_power.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] < b["power"])
	var picks := [
		by_power[0]["instance_id"], by_power[1]["instance_id"], by_power[2]["instance_id"]
	]
	var resolved := SquadBuilder.resolve_party(army, monsters, 1, picks)
	var resolved_ids: Array = resolved.map(func(m: Dictionary) -> String: return m["instance_id"])
	assert_eq(resolved_ids, picks)


func test_resolve_party_empty_pick_returns_empty() -> void:
	var army := [{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 1}]
	assert_eq(SquadBuilder.resolve_party(army, Content.load_monsters(), 10, []), [])


func test_resolve_party_returns_only_the_picked_in_pick_order() -> void:
	var army := [
		{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 9},  # strong
		{"instance_id": "b", "monster_id": "mon_runtclaw", "grade": "E", "level": 1},  # weak
	]
	# pick weak-then-strong -- order must be preserved, NOT power-sorted
	var out := SquadBuilder.resolve_party(army, Content.load_monsters(), 10, ["b", "a"])
	assert_eq(out.map(func(e: Dictionary) -> String: return e["instance_id"]), ["b", "a"])


func test_resolve_party_caps_at_three() -> void:
	var army := []
	for i in 5:
		army.append(
			{"instance_id": "s%d" % i, "monster_id": "mon_grubmaw", "grade": "E", "level": 1}
		)
	var out := SquadBuilder.resolve_party(
		army, Content.load_monsters(), 10, ["s0", "s1", "s2", "s3", "s4"]
	)
	assert_eq(out.size(), 3)
	assert_eq(out.map(func(e: Dictionary) -> String: return e["instance_id"]), ["s0", "s1", "s2"])


func test_resolve_party_skips_a_stale_id() -> void:
	var army := [{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 1}]
	var out := SquadBuilder.resolve_party(army, Content.load_monsters(), 10, ["ghost", "a"])
	assert_eq(out.map(func(e: Dictionary) -> String: return e["instance_id"]), ["a"])


func test_resolve_party_ignores_a_duplicate_id() -> void:
	var army := [{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 1}]
	var out := SquadBuilder.resolve_party(army, Content.load_monsters(), 10, ["a", "a"])
	assert_eq(out.size(), 1)


func test_enrich_army_includes_family() -> void:
	var army := [{"instance_id": "s0", "monster_id": "mon_grubmaw", "grade": "E", "level": 1}]
	var enriched := SquadBuilder.enrich_army(army, monsters, 10)
	assert_eq(enriched[0]["family"], "Hollow Brood")


func test_enrich_army_resolves_traits_when_pool_supplied() -> void:
	var army := [
		{
			"instance_id": "s0",
			"monster_id": "mon_grubmaw",
			"grade": "E",
			"level": 1,
			"traits": ["ironhide", "sturdy"],
		}
	]
	var enriched := SquadBuilder.enrich_army(army, monsters, 10, {}, [], Traits.load_pool())
	assert_eq(enriched[0]["traits"].size(), 2)
	assert_eq(enriched[0]["traits"][0]["id"], "ironhide")
	assert_eq(enriched[0]["traits"][0]["name"], "Ironhide")


func test_enrich_army_auto_loads_the_trait_pool_when_none_passed() -> void:
	var army := [
		{
			"instance_id": "s0",
			"monster_id": "mon_grubmaw",
			"grade": "E",
			"level": 1,
			"traits": ["ironhide"],
		}
	]
	var enriched := SquadBuilder.enrich_army(army, monsters, 10)
	assert_eq(enriched[0]["traits"].size(), 1)
	assert_eq(enriched[0]["traits"][0]["id"], "ironhide")


func test_enrich_army_shadow_with_no_traits_key_gets_empty_and_zero_mods() -> void:
	var army := [{"instance_id": "s1", "monster_id": "mon_grubmaw", "grade": "E", "level": 1}]
	var e: Dictionary = SquadBuilder.enrich_army(army, monsters, 10)[0]
	assert_eq(e["traits"], [])
	assert_eq(e["trait_power_pct"], 0.0)
	assert_eq(e["trait_combat_pct"], {})


func test_enrich_army_emits_trait_modifier_fields() -> void:
	var army := [
		{
			"instance_id": "s0",
			"monster_id": "mon_grubmaw",
			"grade": "E",
			"level": 1,
			"traits": ["soulbound"],  # power_pct 0.10
		}
	]
	var e: Dictionary = SquadBuilder.enrich_army(army, monsters, 10)[0]
	assert_almost_eq(e["trait_power_pct"], 0.10, 0.0001)
	assert_eq(e["trait_combat_pct"], {})


func test_enrich_army_power_includes_the_trait_power_pct() -> void:
	var plain := [{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 3}]
	var boosted := [
		{
			"instance_id": "b",
			"monster_id": "mon_grubmaw",
			"grade": "E",
			"level": 3,
			"traits": ["soulbound"],
		}
	]
	var p: int = SquadBuilder.enrich_army(plain, monsters, 10)[0]["power"]
	var b: int = SquadBuilder.enrich_army(boosted, monsters, 10)[0]["power"]
	assert_gt(b, p)


func _pick_army() -> Array:
	# 4 shadows, deliberately mixed so every sort key reorders differently.
	# base_powers from content: mon_grubmaw 120 (WARRIOR/E), mon_runtclaw 200 (ASSASSIN/E),
	# mon_ashen_warden ~ (WARRIOR), mon_frostquill 2200 (ASSASSIN/B).
	return [
		{"instance_id": "a", "monster_id": "mon_grubmaw", "grade": "E", "level": 9},
		{"instance_id": "b", "monster_id": "mon_frostquill", "grade": "B", "level": 1},
		{"instance_id": "c", "monster_id": "mon_runtclaw", "grade": "E", "level": 3},
		{"instance_id": "d", "monster_id": "mon_ashen_warden", "grade": "C", "level": 5},
	]


func test_sort_shadows_by_power_is_descending() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	var out := SquadBuilder.sort_shadows(enr, "power")
	for i in out.size() - 1:
		assert_true(out[i]["power"] >= out[i + 1]["power"], "power not descending at %d" % i)


func test_sort_shadows_by_level_is_descending_then_power() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	var out := SquadBuilder.sort_shadows(enr, "level")
	for i in out.size() - 1:
		var li: int = out[i]["level"]
		var lj: int = out[i + 1]["level"]
		assert_true(li > lj or (li == lj and out[i]["power"] >= out[i + 1]["power"]))


func test_sort_shadows_by_rank_descending_then_power() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	var out := SquadBuilder.sort_shadows(enr, "rank")
	for i in out.size() - 1:
		var ri: int = GameLogic.RANK_ORDER.find(out[i]["grade"])
		var rj: int = GameLogic.RANK_ORDER.find(out[i + 1]["grade"])
		assert_true(ri > rj or (ri == rj and out[i]["power"] >= out[i + 1]["power"]))


func test_sort_shadows_by_role_is_class_order_then_power() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	var out := SquadBuilder.sort_shadows(enr, "role")
	for i in out.size() - 1:
		var ci: int = SquadBuilder.CLASSES.find(out[i]["clazz"])
		var cj: int = SquadBuilder.CLASSES.find(out[i + 1]["clazz"])
		assert_true(ci < cj or (ci == cj and out[i]["power"] >= out[i + 1]["power"]))


func test_sort_shadows_unknown_mode_matches_power() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	assert_eq(
		SquadBuilder.sort_shadows(enr, "banana").map(
			func(e: Dictionary) -> String: return e["instance_id"]
		),
		SquadBuilder.sort_shadows(enr, "power").map(
			func(e: Dictionary) -> String: return e["instance_id"]
		)
	)


func test_sort_shadows_does_not_mutate_input() -> void:
	var enr := SquadBuilder.enrich_army(_pick_army(), monsters, 10)
	var before := enr.map(func(e: Dictionary) -> String: return e["instance_id"])
	SquadBuilder.sort_shadows(enr, "rank")
	assert_eq(enr.map(func(e: Dictionary) -> String: return e["instance_id"]), before)
