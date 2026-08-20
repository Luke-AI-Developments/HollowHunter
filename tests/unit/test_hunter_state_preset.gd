extends GutTest
## Tests for HunterState's preset_id field (character-select preset
## system) -- split into its own file because test_hunter_state.gd is
## already at gdlint's max-public-methods ceiling (120), same precedent
## as test_hunter_state_inventory.gd / test_hunter_state_shop.gd.


func test_new_default_sets_preset_from_arg() -> void:
	var s := HunterState.new_default("WARRIOR", "f3")
	assert_eq(s.preset_id, "f3")


func test_new_default_preset_defaults_to_m1() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.preset_id, "m1")


func test_preset_id_round_trips_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR", "f6")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.preset_id, "f6")


func test_from_dict_defaults_preset_id_to_m1_for_old_saves() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.preset_id, "m1")
