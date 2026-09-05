extends GutTest
## scenes/battle_view.gd -- pure move_type -> VFX style lookup.


func test_physical_and_magic_are_bolt() -> void:
	assert_eq(BattleView._vfx_style_for_move_type("physical"), "bolt")
	assert_eq(BattleView._vfx_style_for_move_type("magic"), "bolt")


func test_support_types_are_pulse() -> void:
	for t in ["heal", "buff", "cleanse", "revive"]:
		assert_eq(BattleView._vfx_style_for_move_type(t), "pulse", t)


func test_unknown_type_defaults_to_pulse() -> void:
	assert_eq(BattleView._vfx_style_for_move_type("something_new"), "pulse")
