extends GutTest

var monsters: Array


func before_all() -> void:
	monsters = Content.load_monsters()


static func _shadow(instance_id: String, monster_id: String, level: int = 1) -> Dictionary:
	return {"instance_id": instance_id, "monster_id": monster_id, "grade": "E", "level": level}


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


func test_suggest_valid_party_produces_a_valid_role_comp() -> void:
	# GUARDIAN hunter already covers tank. Army has two SUPPORT shadows of
	# different power (same monster, different level) plus attackers and a
	# strong GUARDIAN. The suggestion must pick the STRONGER support and end
	# up role-valid.
	var army := [
		_shadow("guard1", "mon_sepulcher_knight", 5),  # GUARDIAN, base 2300
		_shadow("supp_hi", "mon_snarlpack", 20),  # SUPPORT, base 1350
		_shadow("supp_lo", "mon_snarlpack", 1),  # SUPPORT, weaker twin
		_shadow("atk1", "mon_cindermaw_drake", 1),  # MAGE (attacker), base 2700
		_shadow("atk2", "mon_tuskrend", 1),  # WARRIOR (attacker), base 350
	]
	var ids := SquadBuilder.suggest_valid_party(army, monsters, 10, "GUARDIAN")
	assert_true(ids.size() <= 3, "never fields more than PARTY_SIZE")
	var party := SquadBuilder.resolve_party(army, monsters, 10, ids)
	assert_true(SquadBuilder.party_role_status(party, "GUARDIAN")["valid"], "comp is role-valid")
	assert_true(ids.has("supp_hi"), "picks the strongest SUPPORT for the support role")
	assert_false(ids.has("supp_lo"), "never picks the weaker SUPPORT twin")


func test_suggest_valid_party_uses_hunter_coverage_to_power_fill() -> void:
	# The only tank in the army is weak. A GUARDIAN hunter covers tank, so the
	# suggestion skips the weak tank and power-fills with a stronger attacker.
	var army := [
		_shadow("weak_tank", "mon_carapax", 1),  # GUARDIAN, base 500 -- only tank
		_shadow("supp1", "mon_snarlpack", 1),  # SUPPORT, base 1350
		_shadow("atk_big", "mon_cindermaw_drake", 1),  # MAGE, base 2700
		_shadow("atk_mid", "mon_emberling", 1),  # ASSASSIN, base 1250
	]
	var ids := SquadBuilder.suggest_valid_party(army, monsters, 10, "GUARDIAN")
	assert_eq(ids.size(), 3)
	assert_false(ids.has("weak_tank"), "hunter covers tank -> weak tank not forced in")
	assert_true(ids.has("supp1"))
	assert_true(ids.has("atk_big"))
	assert_true(ids.has("atk_mid"), "third slot power-filled with the stronger attacker")
	var party := SquadBuilder.resolve_party(army, monsters, 10, ids)
	assert_true(SquadBuilder.party_role_status(party, "GUARDIAN")["valid"])


func test_suggest_valid_party_empty_army_is_empty() -> void:
	assert_eq(SquadBuilder.suggest_valid_party([], monsters, 10, "MAGE"), [])
