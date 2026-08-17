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


func test_personal_power_includes_active_armor_set_bonus() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	# set_ashen_vanguard_plate 2pc: VIT+6 -- equipping 2 pieces should raise
	# power over having zero gear equipped at all.
	var baseline := s.personal_power(equipment)
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_helm")["instance_id"], equipment)
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_cuirass")["instance_id"], equipment)
	assert_true(s.personal_power(equipment) > baseline)


func test_personal_power_4pc_set_bonus_beats_2pc_alone() -> void:
	var s := HunterState.new_default("WARRIOR")
	var equipment := Content.load_equipment()
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_helm")["instance_id"], equipment)
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_cuirass")["instance_id"], equipment)
	var at_2pc := s.personal_power(equipment)
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_gauntlets")["instance_id"], equipment)
	s.equip_to_hunter(s.add_to_inventory("eq_ashen_vanguard_sabatons")["instance_id"], equipment)
	assert_true(s.personal_power(equipment) > at_2pc)  # +4th piece's own power AND the 4pc %


func test_level_up_shadow_spends_essence_and_raises_level() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.level_up_shadow(shadow["instance_id"])
	assert_true(ok)
	assert_eq(s.army[0]["level"], 2)
	assert_eq(s.essence, 1000 - ShadowLeveling.level_up_cost(2))


func test_level_up_shadow_insufficient_essence_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 10  # level_up_cost(2) == 400
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_false(s.level_up_shadow(shadow["instance_id"]))
	assert_eq(s.army[0]["level"], 1)
	assert_eq(s.essence, 10)


func test_level_up_shadow_cannot_exceed_cap() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 10000000
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	for _i in ShadowLeveling.LEVEL_CAP:
		s.level_up_shadow(shadow["instance_id"])
	assert_eq(s.army[0]["level"], ShadowLeveling.LEVEL_CAP)
	assert_false(s.level_up_shadow(shadow["instance_id"]))
	assert_eq(s.army[0]["level"], ShadowLeveling.LEVEL_CAP)


func test_level_up_shadow_unknown_shadow_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000
	assert_false(s.level_up_shadow("shadow_none"))


func test_level_up_shadow_raises_enriched_power() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1000
	var monsters := Content.load_monsters()
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var before: int = SquadBuilder.enrich_army(s.army, monsters, s.level)[0]["power"]
	s.level_up_shadow(shadow["instance_id"])
	var after: int = SquadBuilder.enrich_army(s.army, monsters, s.level)[0]["power"]
	assert_true(after > before)


func test_find_duplicate_of_finds_a_matching_monster_id() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	var b := s.claim_shadow("mon_ashen_warden", "C")
	assert_eq(s.find_duplicate_of(a["instance_id"]), b["instance_id"])


func test_find_duplicate_of_with_none_owned_is_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	s.claim_shadow("mon_grubmaw", "E")  # different monster
	assert_eq(s.find_duplicate_of(a["instance_id"]), "")


func test_fuse_shadow_consumes_duplicate_and_levels_target() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var target := s.claim_shadow("mon_ashen_warden", "C")
	var dup := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.fuse_shadow(target["instance_id"], dup["instance_id"])
	assert_true(ok)
	assert_eq(s.army.size(), 1)
	assert_eq(s.army[0]["instance_id"], target["instance_id"])
	assert_eq(s.army[0]["level"], ShadowLeveling.fuse_result_level(1))


func test_fuse_shadow_spends_the_discounted_cost() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var target := s.claim_shadow("mon_ashen_warden", "C")
	var dup := s.claim_shadow("mon_ashen_warden", "C")
	s.fuse_shadow(target["instance_id"], dup["instance_id"])
	assert_eq(s.essence, 100000 - ShadowLeveling.fuse_cost(1))


func test_fuse_shadow_mismatched_monster_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var target := s.claim_shadow("mon_ashen_warden", "C")
	var other := s.claim_shadow("mon_grubmaw", "E")
	var ok := s.fuse_shadow(target["instance_id"], other["instance_id"])
	assert_false(ok)
	assert_eq(s.army.size(), 2)


func test_fuse_shadow_insufficient_essence_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 10
	var target := s.claim_shadow("mon_ashen_warden", "C")
	var dup := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.fuse_shadow(target["instance_id"], dup["instance_id"])
	assert_false(ok)
	assert_eq(s.army.size(), 2)
	assert_eq(s.essence, 10)


func test_fuse_shadow_with_itself_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var target := s.claim_shadow("mon_ashen_warden", "C")
	assert_false(s.fuse_shadow(target["instance_id"], target["instance_id"]))


func test_convert_shadow_removes_it_and_grants_essence_by_grade() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "B")
	var ok := s.convert_shadow(shadow["instance_id"])
	assert_true(ok)
	assert_eq(s.army.size(), 0)
	assert_eq(s.essence, GameLogic.essence_for_converted_shadow("B"))


func test_convert_shadow_unknown_shadow_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.convert_shadow("shadow_none"))


func test_mass_convert_sums_essence_across_shadows() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "B")  # 8
	var b := s.claim_shadow("mon_grubmaw", "E")  # 1
	var gained := s.mass_convert([a["instance_id"], b["instance_id"]])
	assert_eq(gained, 9)
	assert_eq(s.army.size(), 0)
	assert_eq(s.essence, 9)


func test_mass_convert_skips_unknown_ids() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "E")
	var gained := s.mass_convert([a["instance_id"], "shadow_does_not_exist"])
	assert_eq(gained, 1)
	assert_eq(s.army.size(), 0)


func test_claim_shadow_starts_unlocked_and_unfavorited() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	assert_false(shadow["locked"])
	assert_false(shadow["favorite"])


func test_set_shadow_locked_toggles_the_flag() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	assert_true(s.set_shadow_locked(shadow["instance_id"], true))
	assert_true(s.army[0]["locked"])
	assert_true(s.set_shadow_locked(shadow["instance_id"], false))
	assert_false(s.army[0]["locked"])


func test_set_shadow_locked_unknown_shadow_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.set_shadow_locked("shadow_none", true))


func test_set_shadow_favorite_toggles_the_flag() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	assert_true(s.set_shadow_favorite(shadow["instance_id"], true))
	assert_true(s.army[0]["favorite"])


func test_locked_shadow_can_still_be_explicitly_converted() -> void:
	# Locking protects from mass-convert specifically, not a single
	# deliberate convert_shadow() call.
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.set_shadow_locked(shadow["instance_id"], true)
	assert_true(s.convert_shadow(shadow["instance_id"]))
	assert_eq(s.army.size(), 0)


func test_new_default_has_cleared_no_nadir_floors() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.nadir_deepest_floor, 0)
	assert_eq(s.nadir_current_floor(), 1)


func test_clear_nadir_floor_advances_deepest_and_current() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.clear_nadir_floor(1)
	assert_eq(s.nadir_deepest_floor, 1)
	assert_eq(s.nadir_current_floor(), 2)


func test_clear_nadir_floor_never_moves_backward() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.clear_nadir_floor(5)
	s.clear_nadir_floor(2)  # out of order / re-clear -- must not regress
	assert_eq(s.nadir_deepest_floor, 5)


func test_nadir_deepest_floor_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.clear_nadir_floor(7)
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.nadir_deepest_floor, 7)
	assert_eq(restored.nadir_current_floor(), 8)


func test_from_dict_defaults_nadir_deepest_floor_to_zero() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.nadir_deepest_floor, 0)


func test_new_default_has_all_three_facilities_at_level_1_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.stronghold_level, 1)
	for facility_id in Stronghold.FACILITY_IDS:
		assert_true(s.stronghold_facilities.has(facility_id))
		assert_eq(s.stronghold_facilities[facility_id]["level"], 1)
		assert_eq(s.stronghold_facilities[facility_id]["assigned"], [])


func test_assign_shadow_to_facility_succeeds_when_slot_free() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	var ok := s.assign_shadow_to_facility(Stronghold.RELIQUARY, shadow["instance_id"])
	assert_true(ok)
	assert_true(s.is_shadow_assigned(shadow["instance_id"]))
	assert_eq(s.stronghold_facilities[Stronghold.RELIQUARY]["assigned"], [shadow["instance_id"]])


func test_assign_shadow_to_facility_fails_when_already_assigned() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.RELIQUARY, shadow["instance_id"])
	var ok := s.assign_shadow_to_facility(Stronghold.GATE_WATCH, shadow["instance_id"])
	assert_false(ok)
	assert_eq(s.stronghold_facilities[Stronghold.GATE_WATCH]["assigned"], [])


func test_assign_shadow_to_facility_fails_when_full() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "E")
	var b := s.claim_shadow("mon_grubmaw", "E")
	s.assign_shadow_to_facility(Stronghold.RELIQUARY, a["instance_id"])  # fills the 1 slot at lvl 1
	var ok := s.assign_shadow_to_facility(Stronghold.RELIQUARY, b["instance_id"])
	assert_false(ok)


func test_assign_shadow_to_facility_fails_for_unknown_shadow_or_facility() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	assert_false(s.assign_shadow_to_facility(Stronghold.RELIQUARY, "shadow_none"))
	assert_false(s.assign_shadow_to_facility("NOT_A_FACILITY", shadow["instance_id"]))


func test_unassign_shadow_frees_it() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.RELIQUARY, shadow["instance_id"])
	s.unassign_shadow(shadow["instance_id"])
	assert_false(s.is_shadow_assigned(shadow["instance_id"]))
	assert_eq(s.stronghold_facilities[Stronghold.RELIQUARY]["assigned"], [])


func test_unassign_shadow_not_assigned_is_a_no_op() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.unassign_shadow(shadow["instance_id"])  # never assigned -- should not error
	assert_false(s.is_shadow_assigned(shadow["instance_id"]))


func test_stronghold_state_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.RELIQUARY, shadow["instance_id"])
	s.stronghold_level = 3
	s.stronghold_last_collected = 12345
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.stronghold_level, 3)
	assert_eq(restored.stronghold_last_collected, 12345)
	assert_true(restored.is_shadow_assigned(shadow["instance_id"]))


func test_from_dict_defaults_stronghold_fields_for_old_saves() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.stronghold_level, 1)
	assert_eq(restored.stronghold_last_collected, 0)
	assert_eq(restored.stronghold_facilities[Stronghold.RELIQUARY]["level"], 1)


func test_collect_stronghold_with_nothing_assigned_gains_nothing() -> void:
	var s := HunterState.new_default("WARRIOR")
	var result := s.collect_stronghold(3600)
	assert_eq(result["essence_gained"], 0)
	assert_eq(result["tickets_gained"], 0)
	assert_eq(result["shadow_levels_gained"], {})
	assert_eq(s.stronghold_last_collected, 3600)


func test_collect_stronghold_grants_essence_from_reliquary() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.RELIQUARY, shadow["instance_id"])
	var result := s.collect_stronghold(3600)  # 1 hour
	var expected := int(round(Stronghold.accrued(Stronghold.RELIQUARY, 3600.0, 1, 1)))
	assert_eq(result["essence_gained"], expected)
	assert_eq(s.essence, expected)


func test_collect_stronghold_grants_tickets_from_gate_watch() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.GATE_WATCH, shadow["instance_id"])
	var result := s.collect_stronghold(3600)
	var expected := int(round(Stronghold.accrued(Stronghold.GATE_WATCH, 3600.0, 1, 1)))
	assert_eq(result["tickets_gained"], expected)
	assert_eq(s.gate_tickets, expected)


func test_collect_stronghold_levels_up_training_yard_shadows() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "E")
	s.assign_shadow_to_facility(Stronghold.TRAINING_YARD, shadow["instance_id"])
	# Each collection is capped at OFFLINE_CAP_HOURS -- repeat enough
	# collections (as if returning once a day) to cross 1.0 progress.
	var now := 0
	var any_level_gain := false
	for _i in 12:
		now += int(Stronghold.OFFLINE_CAP_HOURS * 3600.0)
		var result := s.collect_stronghold(now)
		if result["shadow_levels_gained"].has(shadow["instance_id"]):
			any_level_gain = true
	assert_true(s.army[0]["level"] > 1)
	assert_true(any_level_gain)


func test_collect_stronghold_caps_elapsed_time_never_negative() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.stronghold_last_collected = 1000
	var result := s.collect_stronghold(500)  # "now" before last_collected -- clock weirdness
	assert_eq(result["essence_gained"], 0)
	assert_eq(s.stronghold_last_collected, 500)


func test_upgrade_facility_spends_essence_and_raises_level() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var ok := s.upgrade_facility(Stronghold.RELIQUARY)
	assert_true(ok)
	assert_eq(s.stronghold_facilities[Stronghold.RELIQUARY]["level"], 2)
	assert_eq(s.essence, 100000 - Stronghold.facility_upgrade_cost(2))


func test_upgrade_facility_insufficient_essence_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 1
	assert_false(s.upgrade_facility(Stronghold.RELIQUARY))
	assert_eq(s.stronghold_facilities[Stronghold.RELIQUARY]["level"], 1)


func test_upgrade_facility_unknown_id_fails() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	assert_false(s.upgrade_facility("NOT_A_FACILITY"))


func test_upgrade_facility_cannot_exceed_cap() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000000
	for _i in Stronghold.FACILITY_LEVEL_CAP:
		s.upgrade_facility(Stronghold.RELIQUARY)
	assert_eq(s.stronghold_facilities[Stronghold.RELIQUARY]["level"], Stronghold.FACILITY_LEVEL_CAP)
	assert_false(s.upgrade_facility(Stronghold.RELIQUARY))


func test_upgrade_stronghold_spends_essence_and_raises_level_and_capacity() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000
	var before_capacity := Stronghold.army_capacity(s.stronghold_level)
	var ok := s.upgrade_stronghold()
	assert_true(ok)
	assert_eq(s.stronghold_level, 2)
	assert_eq(s.essence, 100000 - Stronghold.stronghold_upgrade_cost(2))
	assert_true(Stronghold.army_capacity(s.stronghold_level) > before_capacity)


func test_upgrade_stronghold_cannot_exceed_cap() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.essence = 100000000
	for _i in Stronghold.STRONGHOLD_LEVEL_CAP:
		s.upgrade_stronghold()
	assert_eq(s.stronghold_level, Stronghold.STRONGHOLD_LEVEL_CAP)
	assert_false(s.upgrade_stronghold())


func test_new_default_starts_with_no_streak() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.current_streak, 0)


func test_current_streak_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.current_streak = 7
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.current_streak, 7)


func test_from_dict_defaults_current_streak_to_zero() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.current_streak, 0)


func test_new_default_starts_at_rank_e() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.hunter_rank, "E")


func test_pass_assessment_promotes_to_the_next_rank() -> void:
	var s := HunterState.new_default("WARRIOR")
	var ok := s.pass_assessment("D")
	assert_true(ok)
	assert_eq(s.hunter_rank, "D")


func test_pass_assessment_rejects_a_skipped_rank() -> void:
	var s := HunterState.new_default("WARRIOR")
	var ok := s.pass_assessment("C")  # skips D -- must fail
	assert_false(ok)
	assert_eq(s.hunter_rank, "E")


func test_pass_assessment_rejects_a_lower_or_equal_rank() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.pass_assessment("D")
	assert_false(s.pass_assessment("D"))
	assert_false(s.pass_assessment("E"))
	assert_eq(s.hunter_rank, "D")


func test_hunter_rank_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.pass_assessment("D")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.hunter_rank, "D")


func test_from_dict_defaults_hunter_rank_to_e() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.hunter_rank, "E")


func test_spend_gate_ticket_decrements_when_available() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.gate_tickets = 2
	var ok := s.spend_gate_ticket()
	assert_true(ok)
	assert_eq(s.gate_tickets, 1)


func test_spend_gate_ticket_fails_when_none_held() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.gate_tickets, 0)
	var ok := s.spend_gate_ticket()
	assert_false(ok)
	assert_eq(s.gate_tickets, 0)


func test_new_default_never_offered_a_gate_break() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.last_gate_break_offer, 0)


func test_last_gate_break_offer_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.last_gate_break_offer = 123456789
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.last_gate_break_offer, 123456789)


func test_from_dict_defaults_last_gate_break_offer_to_zero() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.last_gate_break_offer, 0)


func test_active_party_ids_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.active_party_ids = ["shadow_0", "shadow_2"]
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.active_party_ids, ["shadow_0", "shadow_2"])


func test_from_dict_defaults_active_party_ids_to_empty() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.active_party_ids, [])


func test_new_default_has_no_active_party_ids() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.active_party_ids, [])


func test_toggle_party_member_adds_and_removes() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_true(s.toggle_party_member("shadow_0", true))
	assert_eq(s.active_party_ids, ["shadow_0"])
	assert_true(s.toggle_party_member("shadow_0", false))
	assert_eq(s.active_party_ids, [])


func test_toggle_party_member_rejects_a_4th_member() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.toggle_party_member("shadow_0", true)
	s.toggle_party_member("shadow_1", true)
	s.toggle_party_member("shadow_2", true)
	assert_false(s.toggle_party_member("shadow_3", true))
	assert_eq(s.active_party_ids.size(), 3)
	assert_false(s.active_party_ids.has("shadow_3"))


func test_toggle_party_member_adding_an_already_fielded_member_is_a_noop_success() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.toggle_party_member("shadow_0", true)
	assert_true(s.toggle_party_member("shadow_0", true))
	assert_eq(s.active_party_ids, ["shadow_0"])


func test_toggle_party_member_respects_a_custom_max_size() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.toggle_party_member("shadow_0", true, 1)
	assert_false(s.toggle_party_member("shadow_1", true, 1))
	assert_eq(s.active_party_ids, ["shadow_0"])


func test_auto_equip_squad_equips_every_given_shadow() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")  # WARRIOR
	var b := s.claim_shadow("mon_carapax", "D")  # GUARDIAN
	var equipment := Content.load_equipment()
	s.add_to_inventory("eq_warcleaver")  # WARRIOR weapon, matches Ashen Warden
	var monsters := Content.load_monsters()
	var changed := s.auto_equip_squad([a["instance_id"], b["instance_id"]], equipment, monsters)
	assert_true(changed > 0)
	assert_true(s.army[0]["equipped"].has("WEAPON"))


func test_auto_equip_squad_with_no_matching_gear_changes_nothing() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	var changed := s.auto_equip_squad(
		[a["instance_id"]], Content.load_equipment(), Content.load_monsters()
	)
	assert_eq(changed, 0)


func test_auto_equip_squad_skips_unknown_shadow_ids() -> void:
	var s := HunterState.new_default("WARRIOR")
	var changed := s.auto_equip_squad(
		["does_not_exist"], Content.load_equipment(), Content.load_monsters()
	)
	assert_eq(changed, 0)


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
