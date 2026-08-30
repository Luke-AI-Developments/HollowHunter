extends GutTest
## core/debug_grant.gd -- debug-only grant-one-of-everything for art auditing.

var _monsters: Array
var _equipment: Dictionary


func before_all() -> void:
	_monsters = Content.load_monsters()
	_equipment = Content.load_equipment()


func test_grant_all_gives_one_of_every_shadow_and_item() -> void:
	var s := HunterState.new_default("WARRIOR")
	var before_army := s.army.size()
	var before_inv := s.inventory.size()
	var r := DebugGrant.grant_all(s, _monsters, _equipment)
	assert_eq(r["shadows_added"], _monsters.size())
	assert_eq(r["items_added"], _equipment["base_equipment"].size())
	assert_eq(s.army.size(), before_army + _monsters.size())
	assert_eq(s.inventory.size(), before_inv + _equipment["base_equipment"].size())


func test_grant_all_is_idempotent() -> void:
	var s := HunterState.new_default("WARRIOR")
	DebugGrant.grant_all(s, _monsters, _equipment)
	var army_after_first := s.army.size()
	var inv_after_first := s.inventory.size()
	var r2 := DebugGrant.grant_all(s, _monsters, _equipment)
	assert_eq(r2["shadows_added"], 0)
	assert_eq(r2["items_added"], 0)
	assert_eq(s.army.size(), army_after_first)
	assert_eq(s.inventory.size(), inv_after_first)


func test_grant_all_skips_already_owned() -> void:
	var s := HunterState.new_default("WARRIOR")
	var first_monster: String = String(_monsters[0]["id"])
	var first_def: String = String(_equipment["base_equipment"][0]["id"])
	s.claim_shadow(first_monster, String(_monsters[0]["rank"]))
	s.add_to_inventory(first_def)
	var r := DebugGrant.grant_all(s, _monsters, _equipment)
	assert_eq(r["shadows_added"], _monsters.size() - 1)
	assert_eq(r["items_added"], _equipment["base_equipment"].size() - 1)
