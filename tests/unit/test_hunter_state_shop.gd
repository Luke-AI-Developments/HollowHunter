extends GutTest
## HunterState: Crystals + owned cosmetics (§14/§26 shop, Phase 4 step 1).
## Split out of test_hunter_state.gd purely because that file hit gdlint's
## max-public-methods (120) limit -- same reasoning battle_view.gd/
## squad_view.gd/shop_view.gd were split out of scenes/main.gd for its
## max-file-lines limit. Same one-field-per-test-pair convention as the
## rest of test_hunter_state.gd, just relocated.


func test_new_default_has_zero_crystals_and_no_cosmetics() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.crystals, 0)
	assert_eq(s.owned_cosmetics, [])


func test_spend_crystals_succeeds_when_affordable() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.crystals = 100
	assert_true(s.spend_crystals(60))
	assert_eq(s.crystals, 40)


func test_spend_crystals_fails_when_short() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.crystals = 10
	assert_false(s.spend_crystals(20))
	assert_eq(s.crystals, 10)


func test_unlock_cosmetic_adds_it_once() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_true(s.unlock_cosmetic("cosmetic_frost_aura"))
	assert_eq(s.owned_cosmetics, ["cosmetic_frost_aura"])
	assert_false(s.unlock_cosmetic("cosmetic_frost_aura"))
	assert_eq(s.owned_cosmetics, ["cosmetic_frost_aura"])


func test_crystals_and_cosmetics_round_trip_through_dict() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.crystals = 250
	s.unlock_cosmetic("cosmetic_void_eyes")
	var restored := HunterState.from_dict(s.to_dict())
	assert_eq(restored.crystals, 250)
	assert_eq(restored.owned_cosmetics, ["cosmetic_void_eyes"])


func test_from_dict_defaults_crystals_and_cosmetics_for_old_saves() -> void:
	var restored := HunterState.from_dict({})
	assert_eq(restored.crystals, 0)
	assert_eq(restored.owned_cosmetics, [])
