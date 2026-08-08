extends GutTest
## HunterState: level/EXP progression, subclass stats wiring, dict round trip.


func test_new_default_starts_at_level_1() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.level, 1)
	assert_eq(s.total_exp, 0)
	assert_eq(s.exp_into_level, 0)
	assert_eq(s.essence, 0)
	assert_eq(s.gate_tickets, 0)


func test_add_exp_below_threshold_does_not_level_up() -> void:
	var s := HunterState.new_default("WARRIOR")
	var gained := s.add_exp(50)  # exp_to_next(1) == 100
	assert_eq(gained, 0)
	assert_eq(s.level, 1)
	assert_eq(s.exp_into_level, 50)
	assert_eq(s.total_exp, 50)


func test_add_exp_crossing_threshold_levels_up_once() -> void:
	var s := HunterState.new_default("WARRIOR")
	var gained := s.add_exp(150)  # exp_to_next(1) == 100 -> level 2, 50 left over
	assert_eq(gained, 1)
	assert_eq(s.level, 2)
	assert_eq(s.exp_into_level, 50)
	assert_eq(s.total_exp, 150)


func test_add_exp_can_gain_multiple_levels_at_once() -> void:
	var s := HunterState.new_default("WARRIOR")
	# exp_to_next(1)=100, exp_to_next(2)=200 -> 100+200=300 exactly hits level 3
	var gained := s.add_exp(300)
	assert_eq(gained, 2)
	assert_eq(s.level, 3)
	assert_eq(s.exp_into_level, 0)


func test_add_exp_zero_or_negative_is_a_no_op() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.add_exp(0), 0)
	assert_eq(s.add_exp(-10), 0)
	assert_eq(s.total_exp, 0)


func test_stats_wires_into_game_logic() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.level = 20
	var stats := s.stats()
	assert_eq(stats, GameLogic.stats_from(20, "WARRIOR"))


func test_to_dict_from_dict_round_trip() -> void:
	var s := HunterState.new_default("MAGE")
	s.add_exp(250)
	s.essence = 40
	s.gate_tickets = 2
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.level, s.level)
	assert_eq(restored.exp_into_level, s.exp_into_level)
	assert_eq(restored.total_exp, s.total_exp)
	assert_eq(restored.subclass, s.subclass)
	assert_eq(restored.essence, s.essence)
	assert_eq(restored.gate_tickets, s.gate_tickets)


func test_from_dict_defaults_missing_fields() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.level, 1)
	assert_eq(restored.subclass, "WARRIOR")


func test_new_default_army_is_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.army, [])


func test_claim_shadow_adds_a_level_1_shadow() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_eq(s.army.size(), 1)
	assert_eq(shadow["monster_id"], "mon_ashen_warden")
	assert_eq(shadow["grade"], "C")
	assert_eq(shadow["level"], 1)


func test_claim_shadow_ids_are_unique() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_grubmaw", "E")
	var b := s.claim_shadow("mon_grubmaw", "E")
	assert_ne(a["instance_id"], b["instance_id"])


func test_army_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.claim_shadow("mon_ashen_warden", "C")
	s.claim_shadow("mon_grubmaw", "E")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.army.size(), 2)
	assert_eq(restored.army[0]["monster_id"], "mon_ashen_warden")


func test_new_default_has_never_applied_exp() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.last_exp_date, "")
	assert_false(s.has_applied_exp_today("2026-08-08"))


func test_mark_exp_applied_then_has_applied_true_for_same_date() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.mark_exp_applied("2026-08-08")
	assert_true(s.has_applied_exp_today("2026-08-08"))


func test_mark_exp_applied_still_false_for_a_different_date() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.mark_exp_applied("2026-08-08")
	assert_false(s.has_applied_exp_today("2026-08-09"))


func test_last_exp_date_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.mark_exp_applied("2026-08-08")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.last_exp_date, "2026-08-08")
	assert_true(restored.has_applied_exp_today("2026-08-08"))


func test_new_default_inventory_is_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.inventory, [])


func test_add_to_inventory_adds_an_unenhanced_item() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	assert_eq(s.inventory.size(), 1)
	assert_eq(item["equipment_def_id"], "eq_warcleaver")
	assert_eq(item["enhancement_level"], 0)


func test_add_to_inventory_ids_are_unique() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.add_to_inventory("eq_warcleaver")
	var b := s.add_to_inventory("eq_warcleaver")
	assert_ne(a["instance_id"], b["instance_id"])


func test_inventory_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.add_to_inventory("eq_warcleaver")
	s.add_to_inventory("eq_ironbrow_helm")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.inventory.size(), 2)
	assert_eq(restored.inventory[0]["equipment_def_id"], "eq_warcleaver")
