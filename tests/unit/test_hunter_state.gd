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


func test_claim_shadow_starts_with_no_gear() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_eq(shadow["equipped"], {})


func test_equip_to_hunter_matching_class_succeeds() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_warcleaver")  # WARRIOR WEAPON
	var ok := s.equip_to_hunter(item["instance_id"], equipment)
	assert_true(ok)
	assert_eq(s.equipped["WEAPON"], item["instance_id"])


func test_equip_to_hunter_wrong_class_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_blightwood_wand")  # MAGE WEAPON
	var ok := s.equip_to_hunter(item["instance_id"], equipment)
	assert_false(ok)
	assert_false(s.equipped.has("WEAPON"))


func test_equip_to_hunter_unknown_item_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.equip_to_hunter("eq_inst_does_not_exist", Content.load_equipment()))


func test_equip_to_hunter_swaps_out_the_old_item() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var first := s.add_to_inventory("eq_warcleaver")
	var second := s.add_to_inventory("eq_gravebite_greataxe")  # also WARRIOR WEAPON
	s.equip_to_hunter(first["instance_id"], equipment)
	s.equip_to_hunter(second["instance_id"], equipment)
	assert_eq(s.equipped["WEAPON"], second["instance_id"])
	assert_false(s.is_instance_equipped(first["instance_id"]))  # freed, not lost


func test_unequip_from_hunter_clears_the_slot() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], equipment)
	s.unequip_from_hunter("WEAPON")
	assert_false(s.equipped.has("WEAPON"))


func test_equip_to_shadow_matching_class_succeeds() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	var item := s.add_to_inventory("eq_warcleaver")
	var ok := s.equip_to_shadow(shadow["instance_id"], item["instance_id"], equipment, monsters)
	assert_true(ok)
	assert_eq(s.army[0]["equipped"]["WEAPON"], item["instance_id"])


func test_equip_to_shadow_wrong_class_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	var item := s.add_to_inventory("eq_blightwood_wand")  # MAGE WEAPON
	var ok := s.equip_to_shadow(shadow["instance_id"], item["instance_id"], equipment, monsters)
	assert_false(ok)
	assert_eq(s.army[0]["equipped"], {})


func test_equip_to_shadow_unknown_shadow_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var item := s.add_to_inventory("eq_warcleaver")
	assert_false(s.equip_to_shadow("shadow_none", item["instance_id"], equipment, monsters))


func test_same_item_cannot_equip_hunter_and_shadow_at_once() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], equipment)
	var ok := s.equip_to_shadow(shadow["instance_id"], item["instance_id"], equipment, monsters)
	assert_false(ok)
	assert_eq(s.army[0]["equipped"], {})


func test_unequip_from_shadow_clears_the_slot() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_shadow(shadow["instance_id"], item["instance_id"], equipment, monsters)
	s.unequip_from_shadow(shadow["instance_id"], "WEAPON")
	assert_false(s.army[0]["equipped"].has("WEAPON"))


func test_equipped_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], equipment)
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.equipped["WEAPON"], item["instance_id"])


func test_personal_power_with_no_gear_matches_base_formula() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.level = 10
	var equipment := Content.load_equipment()
	assert_eq(s.personal_power(equipment), GameLogic.personal_power(s.stats(), s.level, 0))


func test_personal_power_rises_when_gear_is_equipped() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var baseline := s.personal_power(equipment)
	var item := s.add_to_inventory("eq_warcleaver")  # power_bonus 25, STR+3
	s.equip_to_hunter(item["instance_id"], equipment)
	assert_true(s.personal_power(equipment) > baseline)


func test_personal_power_matches_hand_computed_gear_bonus() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_warcleaver")  # power_bonus 25, STR+3
	s.equip_to_hunter(item["instance_id"], equipment)
	var expected_stats := s.stats().duplicate()
	expected_stats["STR"] += 3
	var expected := GameLogic.personal_power(expected_stats, s.level, 25)
	assert_eq(s.personal_power(equipment), expected)


func test_equip_best_to_hunter_picks_the_strongest_owned_match() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var weak := s.add_to_inventory("eq_warcleaver")  # 25
	var strong := s.add_to_inventory("eq_gravebite_greataxe")  # 170
	var changed := s.equip_best_to_hunter("WEAPON", equipment)
	assert_true(changed)
	assert_eq(s.equipped["WEAPON"], strong["instance_id"])
	assert_false(s.is_instance_equipped(weak["instance_id"]))


func test_equip_best_to_hunter_does_not_downgrade() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var strong := s.add_to_inventory("eq_gravebite_greataxe")  # 170
	s.add_to_inventory("eq_warcleaver")  # 25, weaker, unequipped
	s.equip_to_hunter(strong["instance_id"], equipment)
	var changed := s.equip_best_to_hunter("WEAPON", equipment)
	assert_false(changed)
	assert_eq(s.equipped["WEAPON"], strong["instance_id"])


func test_equip_best_to_hunter_no_owned_match_is_a_no_op() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.equip_best_to_hunter("WEAPON", Content.load_equipment()))


func test_auto_equip_hunter_fills_every_matching_slot() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	s.add_to_inventory("eq_warcleaver")  # WEAPON
	s.add_to_inventory("eq_ironbrow_helm")  # HEAD
	var changed := s.auto_equip_hunter(equipment)
	assert_eq(changed, 2)
	assert_true(s.equipped.has("WEAPON"))
	assert_true(s.equipped.has("HEAD"))


func test_equip_best_to_shadow_picks_the_strongest_owned_match() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	s.add_to_inventory("eq_warcleaver")  # 25
	var strong := s.add_to_inventory("eq_gravebite_greataxe")  # 170
	var changed := s.equip_best_to_shadow(shadow["instance_id"], "WEAPON", equipment, monsters)
	assert_true(changed)
	assert_eq(s.army[0]["equipped"]["WEAPON"], strong["instance_id"])


func test_auto_equip_shadow_fills_every_matching_slot() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	s.add_to_inventory("eq_warcleaver")  # WEAPON
	s.add_to_inventory("eq_ironbrow_helm")  # HEAD
	var changed := s.auto_equip_shadow(shadow["instance_id"], equipment, monsters)
	assert_eq(changed, 2)


func test_hunter_and_shadow_auto_equip_never_double_book_the_same_item() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR, same class as hunter
	var only_weapon := s.add_to_inventory("eq_warcleaver")  # single WARRIOR WEAPON owned
	s.auto_equip_hunter(equipment)
	s.auto_equip_shadow(shadow["instance_id"], equipment, monsters)
	assert_eq(s.equipped.get("WEAPON", ""), only_weapon["instance_id"])
	assert_false(s.army[0]["equipped"].has("WEAPON"))  # nothing left for the shadow to take


func test_enhance_item_spends_essence_and_raises_level() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000
	var item := s.add_to_inventory("eq_warcleaver")
	var ok := s.enhance_item(item["instance_id"])
	assert_true(ok)
	assert_eq(item["enhancement_level"], 1)
	assert_eq(s.essence, 1000 - Equip.enhancement_cost(1))


func test_enhance_item_insufficient_essence_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 10  # enhancement_cost(1) == 50
	var item := s.add_to_inventory("eq_warcleaver")
	var ok := s.enhance_item(item["instance_id"])
	assert_false(ok)
	assert_eq(item["enhancement_level"], 0)
	assert_eq(s.essence, 10)  # nothing spent


func test_enhance_item_unknown_item_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000
	assert_false(s.enhance_item("does_not_exist"))


func test_enhance_item_cannot_exceed_max() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000000
	var item := s.add_to_inventory("eq_warcleaver")
	for _i in Equip.MAX_ENHANCEMENT:
		s.enhance_item(item["instance_id"])
	assert_eq(item["enhancement_level"], Equip.MAX_ENHANCEMENT)
	assert_false(s.enhance_item(item["instance_id"]))
	assert_eq(item["enhancement_level"], Equip.MAX_ENHANCEMENT)


func test_enhance_item_costs_escalate_between_levels() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000000
	var item := s.add_to_inventory("eq_warcleaver")
	s.enhance_item(item["instance_id"])
	var after_level_1 := s.essence
	s.enhance_item(item["instance_id"])
	var spent_for_level_2 := after_level_1 - s.essence
	assert_eq(spent_for_level_2, Equip.enhancement_cost(2))
	assert_true(Equip.enhancement_cost(2) > Equip.enhancement_cost(1))


func test_enhance_item_raises_personal_power() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000000
	var equipment := Content.load_equipment()
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], equipment)
	var before := s.personal_power(equipment)
	s.enhance_item(item["instance_id"])
	assert_true(s.personal_power(equipment) > before)
