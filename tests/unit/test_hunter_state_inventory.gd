extends GutTest
## HunterState: inventory instance-id scheme, item locking, scrap/bulk-scrap
## (§17b). Split out of test_hunter_state.gd purely because that file hit
## gdlint's max-public-methods (120) limit -- same reasoning
## test_hunter_state_shop.gd was already split out for. Same
## one-field/one-behavior-per-test convention as the rest of
## test_hunter_state.gd, just relocated.


func test_add_to_inventory_ids_survive_a_scrap_without_colliding() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.add_to_inventory("eq_warcleaver")
	var b := s.add_to_inventory("eq_warcleaver")
	var c := s.add_to_inventory("eq_warcleaver")
	s.scrap_item(b["instance_id"], Content.load_equipment())  # removes the middle one
	var d := s.add_to_inventory("eq_warcleaver")
	# d's id must not collide with a's or c's, which are both still present
	assert_ne(d["instance_id"], a["instance_id"])
	assert_ne(d["instance_id"], c["instance_id"])
	var ids: Array = s.inventory.map(func(i: Dictionary) -> String: return i["instance_id"])
	var seen := {}
	for id in ids:
		seen[id] = true
	assert_eq(ids.size(), seen.size())  # no duplicates anywhere


func test_add_to_inventory_starts_unlocked() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	assert_false(item["locked"])


func test_set_item_locked() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	assert_true(s.set_item_locked(item["instance_id"], true))
	assert_true(s.inventory[0]["locked"])


func test_set_item_locked_unknown_item_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.set_item_locked("does_not_exist", true))


func test_scrap_item_grants_essence_and_removes_it() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")  # COMMON
	var before := s.essence
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_true(gained > 0)
	assert_eq(s.essence, before + gained)
	assert_eq(s.inventory.size(), 0)


func test_scrap_item_locked_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	s.set_item_locked(item["instance_id"], true)
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_eq(gained, 0)
	assert_eq(s.inventory.size(), 1)


func test_scrap_item_equipped_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], Content.load_equipment())
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_eq(gained, 0)
	assert_eq(s.inventory.size(), 1)


func test_scrap_item_unknown_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.scrap_item("does_not_exist", Content.load_equipment()), 0)


func test_bulk_scrap_sums_essence_and_skips_ineligible() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.add_to_inventory("eq_warcleaver")
	var b := s.add_to_inventory("eq_warcleaver")
	s.set_item_locked(b["instance_id"], true)  # ineligible, skipped
	var gained := s.bulk_scrap([a["instance_id"], b["instance_id"]], Content.load_equipment())
	assert_true(gained > 0)
	assert_eq(s.inventory.size(), 1)  # only b (locked) survives
	assert_eq(s.inventory[0]["instance_id"], b["instance_id"])


func test_next_inventory_id_persists_through_dict_round_trip() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.add_to_inventory("eq_warcleaver")
	s.add_to_inventory("eq_warcleaver")
	var d := s.to_dict()
	var restored := HunterState.from_dict(d)
	assert_eq(restored.next_inventory_id, s.next_inventory_id)


func test_from_dict_migrates_old_saves_without_next_inventory_id() -> void:
	# an old save's dict has no "next_inventory_id" key at all
	var old_dict := HunterState.new_default("WARRIOR").to_dict()
	old_dict["inventory"] = [
		{"instance_id": "eq_inst_0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
		{"instance_id": "eq_inst_1", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
	]
	old_dict.erase("next_inventory_id")
	var restored := HunterState.from_dict(old_dict)
	# must default to inventory.size() (2), NOT 0 -- else the next add_to_inventory()
	# would generate "eq_inst_0" again and collide with the existing first item
	assert_eq(restored.next_inventory_id, 2)
