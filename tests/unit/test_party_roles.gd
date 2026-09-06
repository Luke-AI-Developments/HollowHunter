extends GutTest


func test_role_for_class_maps_all_five_plus_unknown() -> void:
	assert_eq(GameLogic.role_for_class("GUARDIAN"), "tank")
	assert_eq(GameLogic.role_for_class("SUPPORT"), "support")
	assert_eq(GameLogic.role_for_class("WARRIOR"), "attacker")
	assert_eq(GameLogic.role_for_class("ASSASSIN"), "attacker")
	assert_eq(GameLogic.role_for_class("MAGE"), "attacker")
	assert_eq(GameLogic.role_for_class("mage"), "attacker")  # case-insensitive
	assert_eq(GameLogic.role_for_class("SOMETHING"), "attacker")  # unknown -> attacker


func test_party_role_status_hunter_covers_tank() -> void:
	# Guardian hunter + a Support shadow + an Assassin shadow = all 3 covered
	var party := [{"clazz": "SUPPORT"}, {"clazz": "ASSASSIN"}]
	var r := SquadBuilder.party_role_status(party, "GUARDIAN")
	assert_true(r["valid"])
	assert_eq(r["missing"], [])


func test_party_role_status_missing_attacker() -> void:
	# Guardian hunter + Support shadow only -> no attacker
	var r := SquadBuilder.party_role_status([{"clazz": "SUPPORT"}], "GUARDIAN")
	assert_false(r["valid"])
	assert_eq(r["missing"], ["attacker"])


func test_party_role_status_empty_party_mage_hunter() -> void:
	var r := SquadBuilder.party_role_status([], "MAGE")
	assert_false(r["valid"])
	assert_eq(r["missing"].size(), 2)  # attacker covered by hunter; tank + support missing


func test_role_requirement_inactive_until_army_has_all_roles() -> void:
	assert_false(SquadBuilder.role_requirement_active([{"clazz": "WARRIOR"}, {"clazz": "MAGE"}]))
	assert_true(
		SquadBuilder.role_requirement_active(
			[{"clazz": "GUARDIAN"}, {"clazz": "SUPPORT"}, {"clazz": "MAGE"}]
		)
	)
