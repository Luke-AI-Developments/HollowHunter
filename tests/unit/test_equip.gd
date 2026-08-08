extends GutTest
## Equip: slot assignment + class-gating, pure. See core/equip.gd for why
## gating is a flat clazz-match on every slot (incl. ACCESSORY), not the
## "Accessory + Aura universal" rule the design doc's prose describes.

const WARRIOR_WEAPON := {"id": "eq_warcleaver", "slot": "WEAPON", "clazz": "WARRIOR"}
const MAGE_WEAPON := {"id": "eq_blightwood_wand", "slot": "WEAPON", "clazz": "MAGE"}


func test_can_equip_matching_class() -> void:
	assert_true(Equip.can_equip(WARRIOR_WEAPON, "WARRIOR"))


func test_can_equip_wrong_class() -> void:
	assert_false(Equip.can_equip(MAGE_WEAPON, "WARRIOR"))


func test_equip_places_item_in_its_slot() -> void:
	var result := Equip.equip({}, WARRIOR_WEAPON, "eq_inst_0", "WARRIOR")
	assert_eq(result["WEAPON"], "eq_inst_0")


func test_equip_wrong_class_is_a_no_op() -> void:
	var result := Equip.equip({}, MAGE_WEAPON, "eq_inst_0", "WARRIOR")
	assert_eq(result, {})


func test_equip_does_not_mutate_input() -> void:
	var original := {}
	Equip.equip(original, WARRIOR_WEAPON, "eq_inst_0", "WARRIOR")
	assert_eq(original, {})


func test_equip_replaces_whatever_was_in_the_slot() -> void:
	var equipped := {"WEAPON": "eq_inst_old"}
	var result := Equip.equip(equipped, WARRIOR_WEAPON, "eq_inst_new", "WARRIOR")
	assert_eq(result["WEAPON"], "eq_inst_new")


func test_unequip_clears_the_slot() -> void:
	var result := Equip.unequip({"WEAPON": "eq_inst_0", "HEAD": "eq_inst_1"}, "WEAPON")
	assert_false(result.has("WEAPON"))
	assert_true(result.has("HEAD"))


func test_unequip_does_not_mutate_input() -> void:
	var original := {"WEAPON": "eq_inst_0"}
	Equip.unequip(original, "WEAPON")
	assert_true(original.has("WEAPON"))


func test_gear_bonus_empty_loadout_is_zero() -> void:
	var bonus := Equip.gear_bonus({}, [], Content.load_equipment())
	assert_eq(bonus["power_bonus"], 0)
	assert_eq(bonus["stat_mods"], {})


func test_gear_bonus_sums_power_bonus_across_slots() -> void:
	var equipment := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
		{"instance_id": "i1", "equipment_def_id": "eq_ironbrow_helm", "enhancement_level": 0},
	]
	var equipped := {"WEAPON": "i0", "HEAD": "i1"}
	var bonus := Equip.gear_bonus(equipped, inventory, equipment)
	assert_eq(bonus["power_bonus"], 25 + 60)  # eq_warcleaver + eq_ironbrow_helm power_bonus


func test_gear_bonus_merges_stat_mods_across_slots() -> void:
	var equipment := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
		{"instance_id": "i1", "equipment_def_id": "eq_trampling_sabatons", "enhancement_level": 0},
	]
	var equipped := {"WEAPON": "i0", "FEET": "i1"}
	var bonus := Equip.gear_bonus(equipped, inventory, equipment)
	# eq_warcleaver STR+3; eq_trampling_sabatons VIT+8 STR+5 -> STR should merge, not overwrite
	assert_eq(bonus["stat_mods"]["STR"], 8)
	assert_eq(bonus["stat_mods"]["VIT"], 8)


func test_gear_bonus_skips_unknown_instance_id() -> void:
	var bonus := Equip.gear_bonus({"WEAPON": "does_not_exist"}, [], Content.load_equipment())
	assert_eq(bonus["power_bonus"], 0)
