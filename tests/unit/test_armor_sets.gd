extends GutTest
## ArmorSets: 2pc/4pc bonus detection + text parsing (§15 patch 3). See
## core/armor_sets.gd for why bonus_4pc's free-form proc text stays
## flavor-only and only its "N% power" token (when present) is mechanical.

# set_ashen_vanguard_plate (WARRIOR/D): bonus_2pc "VIT+6",
# bonus_4pc "+6% power while frontline". Pieces: STR+7 VIT+3, power 160 each.
const HELM := "eq_ashen_vanguard_helm"
const CUIRASS := "eq_ashen_vanguard_cuirass"
const GAUNTLETS := "eq_ashen_vanguard_gauntlets"
const SABATONS := "eq_ashen_vanguard_sabatons"

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


static func _inventory_for(instance_ids: Array, def_ids: Array) -> Array:
	var inv := []
	for i in instance_ids.size():
		inv.append(
			{"instance_id": instance_ids[i], "equipment_def_id": def_ids[i], "enhancement_level": 0}
		)
	return inv


func test_parse_stat_bonus_single_stat() -> void:
	assert_eq(ArmorSets.parse_stat_bonus("VIT+6"), {"VIT": 6})


func test_parse_stat_bonus_two_stats() -> void:
	assert_eq(ArmorSets.parse_stat_bonus("STR+22, VIT+12"), {"STR": 22, "VIT": 12})


func test_parse_stat_bonus_non_matching_text_is_empty() -> void:
	assert_eq(ArmorSets.parse_stat_bonus("+6% power while frontline"), {})
	assert_eq(ArmorSets.parse_stat_bonus("block chance up; shadows behind take less damage"), {})


func test_parse_power_pct_bonus_plain() -> void:
	assert_almost_eq(ArmorSets.parse_power_pct_bonus("+6% power while frontline"), 0.06, 0.0001)


func test_parse_power_pct_bonus_melee_and_spell_variants() -> void:
	assert_almost_eq(
		ArmorSets.parse_power_pct_bonus("+15% melee power; rage stacks through the fight"),
		0.15,
		0.0001
	)
	assert_almost_eq(
		ArmorSets.parse_power_pct_bonus("+20% spell power; spells chain to a second target"),
		0.20,
		0.0001
	)


func test_parse_power_pct_bonus_does_not_false_positive_on_other_percent_stats() -> void:
	# "+20% max HP" and "+10% crit" both contain "N%" but aren't power.
	assert_eq(
		ArmorSets.parse_power_pct_bonus("+20% max HP; taunt pulls enemy focus off allies"), 0.0
	)
	assert_eq(ArmorSets.parse_power_pct_bonus("+10% crit"), 0.0)
	assert_eq(
		ArmorSets.parse_power_pct_bonus("block chance up; shadows behind take less damage"), 0.0
	)


func test_equipped_set_counts_counts_pieces_sharing_a_set_id() -> void:
	var inventory := _inventory_for(["i0", "i1"], [HELM, CUIRASS])
	var equipped := {"HEAD": "i0", "BODY": "i1"}
	var counts := ArmorSets.equipped_set_counts(equipped, inventory, equipment)
	assert_eq(counts.get("set_ashen_vanguard_plate", 0), 2)


func test_active_set_bonuses_below_2pc_is_not_included() -> void:
	var inventory := _inventory_for(["i0"], [HELM])
	var equipped := {"HEAD": "i0"}
	assert_eq(ArmorSets.active_set_bonuses(equipped, inventory, equipment), [])


func test_active_set_bonuses_at_2pc() -> void:
	var inventory := _inventory_for(["i0", "i1"], [HELM, CUIRASS])
	var equipped := {"HEAD": "i0", "BODY": "i1"}
	var active := ArmorSets.active_set_bonuses(equipped, inventory, equipment)
	assert_eq(active.size(), 1)
	assert_eq(active[0]["set_id"], "set_ashen_vanguard_plate")
	assert_true(active[0]["active_2pc"])
	assert_false(active[0]["active_4pc"])


func test_active_set_bonuses_at_4pc() -> void:
	var inventory := _inventory_for(["i0", "i1", "i2", "i3"], [HELM, CUIRASS, GAUNTLETS, SABATONS])
	var equipped := {"HEAD": "i0", "BODY": "i1", "HANDS": "i2", "FEET": "i3"}
	var active := ArmorSets.active_set_bonuses(equipped, inventory, equipment)
	assert_eq(active.size(), 1)
	assert_true(active[0]["active_2pc"])
	assert_true(active[0]["active_4pc"])


func test_total_set_bonus_at_2pc_applies_stat_text_only() -> void:
	var inventory := _inventory_for(["i0", "i1"], [HELM, CUIRASS])
	var equipped := {"HEAD": "i0", "BODY": "i1"}
	var bonus := ArmorSets.total_set_bonus(equipped, inventory, equipment)
	assert_eq(bonus["stat_mods"], {"VIT": 6})
	assert_eq(bonus["power_pct"], 0.0)


func test_total_set_bonus_at_4pc_adds_power_pct() -> void:
	var inventory := _inventory_for(["i0", "i1", "i2", "i3"], [HELM, CUIRASS, GAUNTLETS, SABATONS])
	var equipped := {"HEAD": "i0", "BODY": "i1", "HANDS": "i2", "FEET": "i3"}
	var bonus := ArmorSets.total_set_bonus(equipped, inventory, equipment)
	assert_eq(bonus["stat_mods"], {"VIT": 6})  # still just the 2pc text
	assert_almost_eq(bonus["power_pct"], 0.06, 0.0001)


func test_total_set_bonus_with_no_sets_equipped_is_zero() -> void:
	var bonus := ArmorSets.total_set_bonus({}, [], equipment)
	assert_eq(bonus["stat_mods"], {})
	assert_eq(bonus["power_pct"], 0.0)


func test_owned_set_counts_counts_whole_inventory_not_just_equipped() -> void:
	var equipment_data := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warhowls_hood", "enhancement_level": 0},
		{"instance_id": "i1", "equipment_def_id": "eq_warhowls_robe", "enhancement_level": 0},
	]
	var counts := ArmorSets.owned_set_counts(inventory, equipment_data)
	assert_eq(counts.get("set_warhowls_standard", 0), 2)


func test_owned_set_counts_ignores_non_set_items() -> void:
	var equipment_data := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0}
	]
	assert_eq(ArmorSets.owned_set_counts(inventory, equipment_data), {})
