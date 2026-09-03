extends GutTest
## FocusChain (spec §7.2/§7.3): the cross-class focus-fire chain + the free
## Focus target lever, extracted out of core/battle.gd (whole-branch review
## I4). State still lives on the Battle instance; these tests drive the new
## FocusChain.* static entry points directly.

var moves: Array


func before_all() -> void:
	moves = Content.load_moves()


func _seeded_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _party() -> Array:
	return [
		Battle.make_ally_combatant(
			"player", "WARRIOR", 15, {"STR": 300, "AGI": 200, "VIT": 250, "END": 60, "SEN": 10}
		),
		Battle.make_ally_combatant(
			"s_assassin", "ASSASSIN", 15, {"STR": 260, "AGI": 260, "VIT": 200, "END": 50, "SEN": 40}
		),
	]


func _battle() -> Battle:
	return Battle.new(
		_party(),
		[Battle.make_enemy_combatant("boss", 40000.0, true, "Boss")],
		moves,
		true,
		_seeded_rng(4)
	)


func test_advance_builds_the_chain_on_cross_class_hits_and_caps() -> void:
	var b := _battle()
	FocusChain.advance(b, "WARRIOR", "boss")  # opens the chain
	assert_eq(b.chain_target_id, "boss")
	assert_eq(b.chain_count, 0)
	FocusChain.advance(b, "ASSASSIN", "boss")  # cross-class -> count 1
	assert_eq(b.chain_count, 1)
	FocusChain.advance(b, "ASSASSIN", "boss")  # same class -> reset count, keep target
	assert_eq(b.chain_count, 0)
	assert_eq(b.chain_target_id, "boss")


func test_chain_multiplier_reads_the_current_count_and_caps_at_four() -> void:
	var b := _battle()
	b.chain_target_id = "boss"
	b.chain_count = 0
	assert_almost_eq(FocusChain.chain_multiplier(b, "boss"), 1.0, 0.001)
	b.chain_count = 3
	assert_almost_eq(FocusChain.chain_multiplier(b, "boss"), 1.30, 0.001)
	b.chain_count = 9  # clamped to CHAIN_COUNT_CAP
	assert_almost_eq(FocusChain.chain_multiplier(b, "boss"), 1.40, 0.001)
	assert_almost_eq(FocusChain.chain_multiplier(b, "someone_else"), 1.0, 0.001)


func test_reset_keep_target_drops_count_and_last_chainer_only() -> void:
	var b := _battle()
	FocusChain.advance(b, "WARRIOR", "boss")
	FocusChain.advance(b, "ASSASSIN", "boss")
	assert_eq(b.chain_count, 1)
	FocusChain.reset_keep_target(b)
	assert_eq(b.chain_count, 0)
	assert_eq(b.chain_target_id, "boss")
	assert_eq(b._last_chainer_class, "")


func test_set_focus_needs_a_living_enemy_and_clear_if_dead_drops_a_stale_focus() -> void:
	var b := Battle.new(
		[
			Battle.make_ally_combatant(
				"player", "WARRIOR", 10, {"STR": 200, "AGI": 80, "VIT": 200, "END": 50, "SEN": 10}
			)
		],
		[Battle.make_enemy_combatant("e1", 500.0), Battle.make_enemy_combatant("e2", 500.0)],
		moves,
		true
	)
	FocusChain.set_focus(b, "e2")
	assert_eq(b.focus_target_id, "e2")
	FocusChain.set_focus(b, "ghost")  # not a living enemy -> unchanged
	assert_eq(b.focus_target_id, "e2")
	b._combatant_by_id("e2")["hp"] = 0
	FocusChain.clear_if_dead(b)
	assert_eq(b.focus_target_id, "")
	FocusChain.set_focus(b, "e1")
	FocusChain.clear_focus(b)
	assert_eq(b.focus_target_id, "")
