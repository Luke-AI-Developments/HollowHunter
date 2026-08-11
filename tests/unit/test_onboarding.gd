extends GutTest
## Onboarding: starter shadow + guided first gate (§25). See
## core/onboarding.gd for why permission timing lives in main.gd, not here.

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


func test_starter_monster_id_prefers_a_class_matching_e_rank() -> void:
	var id := Onboarding.starter_monster_id("WARRIOR", monsters)
	var m := Content.monster_by_id(monsters, id)
	assert_eq(m["rank"], "E")
	assert_eq(m["clazz"], "WARRIOR")


func test_starter_monster_id_is_always_a_real_e_rank_monster() -> void:
	for subclass in ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]:
		var id := Onboarding.starter_monster_id(subclass, monsters)
		var m := Content.monster_by_id(monsters, id)
		assert_eq(m["rank"], "E")


func test_guided_gate_monster_id_differs_from_the_starter() -> void:
	var starter := Onboarding.starter_monster_id("MAGE", monsters)
	var guided := Onboarding.guided_gate_monster_id(starter, monsters)
	assert_ne(guided, starter)


func test_guided_gate_monster_id_is_a_real_e_rank_monster() -> void:
	var starter := Onboarding.starter_monster_id("SUPPORT", monsters)
	var guided := Onboarding.guided_gate_monster_id(starter, monsters)
	var m := Content.monster_by_id(monsters, guided)
	assert_eq(m["rank"], "E")


func test_resolve_guided_gate_always_clears_and_claims() -> void:
	var starter := Onboarding.starter_monster_id("ASSASSIN", monsters)
	var guided := Onboarding.guided_gate_monster_id(starter, monsters)
	var result := Onboarding.resolve_guided_gate(guided, monsters)
	assert_true(result["cleared"])
	assert_true(result["claimed"])
	assert_eq(result["monster_id"], guided)
	assert_ne(result["monster_name"], "")
