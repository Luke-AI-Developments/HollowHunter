extends GutTest
## HunterState: Sanctuary claim / Lore Stone discovery / Stronghold map
## placement (§19/§22, map POI spawning). Split out per this file's
## established one-topic-per-test-file convention (see
## test_hunter_state_shop.gd's own header comment).


func test_new_default_has_no_stronghold_placed() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.stronghold_placed)
	assert_eq(s.stronghold_lat, 0.0)
	assert_eq(s.stronghold_lon, 0.0)


func test_new_default_has_never_claimed_sanctuary() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.last_sanctuary_claim_at, 0)


func test_new_default_has_no_discovered_lorestones() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.discovered_lorestone_ids, [])


func test_place_stronghold_sets_location_and_placed_flag() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	assert_true(s.stronghold_placed)
	assert_eq(s.stronghold_lat, 54.5235)
	assert_eq(s.stronghold_lon, -1.5549)


func test_place_stronghold_can_be_called_again_to_relocate() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	s.place_stronghold(51.5074, -0.1278)
	assert_eq(s.stronghold_lat, 51.5074)
	assert_eq(s.stronghold_lon, -0.1278)


func test_claim_sanctuary_succeeds_first_time() -> void:
	var s := HunterState.new_default("WARRIOR")
	var claimed := s.claim_sanctuary(1000, 30, 1, 86400)
	assert_true(claimed)
	assert_eq(s.essence, 30)
	assert_eq(s.gate_tickets, 1)
	assert_eq(s.last_sanctuary_claim_at, 1000)


func test_claim_sanctuary_fails_within_cooldown() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.claim_sanctuary(1000, 30, 1, 86400)
	var claimed_again := s.claim_sanctuary(1000 + 3600, 30, 1, 86400)
	assert_false(claimed_again)
	assert_eq(s.essence, 30)  # unchanged -- no double reward
	assert_eq(s.gate_tickets, 1)


func test_claim_sanctuary_succeeds_after_cooldown_elapses() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.claim_sanctuary(1000, 30, 1, 86400)
	var claimed_again := s.claim_sanctuary(1000 + 86400, 30, 1, 86400)
	assert_true(claimed_again)
	assert_eq(s.essence, 60)
	assert_eq(s.gate_tickets, 2)


func test_discover_lorestone_succeeds_first_time() -> void:
	var s := HunterState.new_default("WARRIOR")
	var discovered := s.discover_lorestone("0,0_lorestone_0", 15)
	assert_true(discovered)
	assert_eq(s.essence, 15)
	assert_eq(s.discovered_lorestone_ids, ["0,0_lorestone_0"])


func test_discover_lorestone_fails_if_already_discovered() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.discover_lorestone("0,0_lorestone_0", 15)
	var discovered_again := s.discover_lorestone("0,0_lorestone_0", 15)
	assert_false(discovered_again)
	assert_eq(s.essence, 15)  # unchanged -- no double reward


func test_discover_lorestone_allows_a_different_stone() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.discover_lorestone("0,0_lorestone_0", 15)
	var discovered := s.discover_lorestone("1,1_lorestone_0", 15)
	assert_true(discovered)
	assert_eq(s.essence, 30)
	assert_eq(s.discovered_lorestone_ids.size(), 2)


func test_poi_fields_round_trip_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.place_stronghold(54.5235, -1.5549)
	s.claim_sanctuary(1000, 30, 1, 86400)
	s.discover_lorestone("0,0_lorestone_0", 15)

	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.stronghold_lat, 54.5235)
	assert_eq(restored.stronghold_lon, -1.5549)
	assert_true(restored.stronghold_placed)
	assert_eq(restored.last_sanctuary_claim_at, 1000)
	assert_eq(restored.discovered_lorestone_ids, ["0,0_lorestone_0"])


func test_from_dict_defaults_poi_fields_for_an_old_save() -> void:
	# Simulates a save written before these fields existed.
	var restored := HunterState.from_dict({"level": 5, "essence": 100})
	assert_false(restored.stronghold_placed)
	assert_eq(restored.last_sanctuary_claim_at, 0)
	assert_eq(restored.discovered_lorestone_ids, [])
