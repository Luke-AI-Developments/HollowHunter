extends GutTest

const FAMILIES := ["slash", "fireball", "nova", "pulse"]


func test_every_move_has_a_valid_vfx_block() -> void:
	var moves := Content.load_moves()
	assert_gt(moves.size(), 0)
	for m: Dictionary in moves:
		var v: Dictionary = m.get("vfx", {})
		assert_true(v.has("family"), "%s has vfx.family" % m["id"])
		assert_true(FAMILIES.has(String(v.get("family", ""))), "%s family in enum" % m["id"])
		assert_true(v.get("color") is Color, "%s vfx.color parsed to Color" % m["id"])
		assert_gt(float(v.get("scale", 0.0)), 0.0, "%s vfx.scale > 0" % m["id"])
