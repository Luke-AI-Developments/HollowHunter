extends GutTest
## ShadowAI: per-class action selection (§16 combat overhaul). Uses real
## content/moves.json data throughout, same convention as the rest of
## this project's tests.

var moves: Array


func before_all() -> void:
	moves = Content.load_moves()


static func _combatant(id: String, hp: int, max_hp: int, debuffed: bool = false) -> Dictionary:
	return {"id": id, "hp": hp, "max_hp": max_hp, "debuffed": debuffed}


# --- Warrior ---


func test_warrior_executes_a_low_hp_enemy_when_available() -> void:
	var available := Content.unlocked_moves(moves, "WARRIOR", 15)
	var enemies := [_combatant("e1", 100, 100), _combatant("e2", 10, 200)]  # e2 is at 5% HP
	var action := ShadowAI.choose_action("WARRIOR", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_warrior_execute")
	assert_eq(action["target_id"], "e2")


func test_warrior_cleaves_when_no_low_hp_target_and_multiple_enemies() -> void:
	var available := Content.unlocked_moves(moves, "WARRIOR", 6)
	var enemies := [_combatant("e1", 100, 100), _combatant("e2", 100, 100)]
	var action := ShadowAI.choose_action("WARRIOR", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_warrior_cleave")
	assert_eq(action["target_id"], "")


func test_warrior_uses_strongest_single_target_on_one_enemy() -> void:
	var available := Content.unlocked_moves(moves, "WARRIOR", 3)  # Strike + Power Strike
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("WARRIOR", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_warrior_power_strike")
	assert_eq(action["target_id"], "e1")


func test_warrior_at_level_1_only_has_strike() -> void:
	var available := Content.unlocked_moves(moves, "WARRIOR", 1)
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("WARRIOR", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_warrior_strike")


func test_warrior_with_no_enemies_takes_no_action() -> void:
	var available := Content.unlocked_moves(moves, "WARRIOR", 15)
	var action := ShadowAI.choose_action("WARRIOR", {}, available, [], [])
	assert_eq(action["move_id"], "")


# --- Guardian ---


func test_guardian_taunts_when_not_already_taunting() -> void:
	var available := Content.unlocked_moves(moves, "GUARDIAN", 14)
	var self_combatant := {"hp": 100, "max_hp": 100, "is_taunting": false}
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("GUARDIAN", self_combatant, available, [], enemies)
	assert_eq(action["move_id"], "move_guardian_taunt")


func test_guardian_braces_when_already_taunting_and_own_hp_is_low() -> void:
	var available := Content.unlocked_moves(moves, "GUARDIAN", 14)
	var self_combatant := {"hp": 20, "max_hp": 100, "is_taunting": true}
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("GUARDIAN", self_combatant, available, [], enemies)
	assert_eq(action["move_id"], "move_guardian_brace")


func test_guardian_shields_the_lowest_hp_ally() -> void:
	var available := Content.unlocked_moves(moves, "GUARDIAN", 14)
	var self_combatant := {"hp": 100, "max_hp": 100, "is_taunting": true}
	var allies := [_combatant("a1", 90, 100), _combatant("a2", 20, 100)]
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("GUARDIAN", self_combatant, available, allies, enemies)
	assert_eq(action["move_id"], "move_guardian_shield_ally")
	assert_eq(action["target_id"], "a2")


func test_guardian_guard_strikes_when_nothing_else_applies() -> void:
	var available := Content.unlocked_moves(moves, "GUARDIAN", 1)  # Guard Strike + Taunt only
	var self_combatant := {"hp": 100, "max_hp": 100, "is_taunting": true}
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("GUARDIAN", self_combatant, available, [], enemies)
	assert_eq(action["move_id"], "move_guardian_guard_strike")
	assert_eq(action["target_id"], "e1")


# --- Assassin ---


func test_assassin_weakens_the_toughest_undebuffed_enemy() -> void:
	var available := Content.unlocked_moves(moves, "ASSASSIN", 15)
	var enemies := [_combatant("e1", 100, 100), _combatant("e2", 200, 200)]
	var action := ShadowAI.choose_action("ASSASSIN", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_assassin_weaken")
	assert_eq(action["target_id"], "e2")  # both at 100% HP; e2 has the higher absolute HP


func test_assassin_finishes_a_low_hp_enemy_over_weaken() -> void:
	var available := Content.unlocked_moves(moves, "ASSASSIN", 15)
	var enemies := [_combatant("e1", 5, 100, true), _combatant("e2", 100, 100, true)]
	var action := ShadowAI.choose_action("ASSASSIN", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_assassin_shadowstep_execute")
	assert_eq(action["target_id"], "e1")


func test_assassin_exploits_a_debuffed_enemy_when_none_are_low_hp() -> void:
	var available := Content.unlocked_moves(moves, "ASSASSIN", 15)
	var enemies := [_combatant("e1", 80, 100, true), _combatant("e2", 60, 100, true)]
	var action := ShadowAI.choose_action("ASSASSIN", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_assassin_exploit_weakness")
	assert_eq(action["target_id"], "e2")  # lowest HP among the debuffed


func test_assassin_quick_strikes_when_nothing_else_applies() -> void:
	var available := Content.unlocked_moves(moves, "ASSASSIN", 1)
	var enemies := [_combatant("e1", 100, 100, true)]
	var action := ShadowAI.choose_action("ASSASSIN", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_assassin_quick_strike")


# --- Mage ---


func test_mage_uses_aoe_with_multiple_enemies() -> void:
	var available := Content.unlocked_moves(moves, "MAGE", 16)
	var enemies := [_combatant("e1", 100, 100), _combatant("e2", 100, 100)]
	var action := ShadowAI.choose_action("MAGE", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_mage_nova_burst")  # strongest AoE unlocked
	assert_eq(action["target_id"], "")


func test_mage_uses_strongest_single_target_with_one_enemy() -> void:
	var available := Content.unlocked_moves(moves, "MAGE", 8)
	var enemies := [_combatant("e1", 100, 100)]
	var action := ShadowAI.choose_action("MAGE", {}, available, [], enemies)
	assert_eq(action["move_id"], "move_mage_arcane_barrage")


# --- Support ---


func test_support_mends_the_lowest_hp_ally() -> void:
	var available := Content.unlocked_moves(moves, "SUPPORT", 1)
	var allies := [_combatant("a1", 100, 100), _combatant("a2", 30, 100)]
	var action := ShadowAI.choose_action("SUPPORT", {}, available, allies, [])
	assert_eq(action["move_id"], "move_support_mend")
	assert_eq(action["target_id"], "a2")


func test_support_uses_sanctuary_with_multiple_hurt_allies() -> void:
	var available := Content.unlocked_moves(moves, "SUPPORT", 14)
	var allies := [_combatant("a1", 30, 100), _combatant("a2", 20, 100)]
	var action := ShadowAI.choose_action("SUPPORT", {}, available, allies, [])
	assert_eq(action["move_id"], "move_support_sanctuary")
	assert_eq(action["target_id"], "")


func test_support_cleanses_a_debuffed_ally_when_no_one_is_hurt() -> void:
	var available := Content.unlocked_moves(moves, "SUPPORT", 14)
	var allies := [_combatant("a1", 100, 100, true), _combatant("a2", 100, 100)]
	var action := ShadowAI.choose_action("SUPPORT", {}, available, allies, [])
	assert_eq(action["move_id"], "move_support_cleanse")
	assert_eq(action["target_id"], "a1")


func test_support_buffs_proactively_when_healthy_and_undebuffed() -> void:
	var available := Content.unlocked_moves(moves, "SUPPORT", 3)  # Mend + Ward only
	var allies := [_combatant("a1", 100, 100), _combatant("a2", 100, 100)]
	var action := ShadowAI.choose_action("SUPPORT", {}, available, allies, [])
	assert_eq(action["move_id"], "move_support_ward")


func test_support_falls_back_to_mend_when_no_attack_move_exists() -> void:
	# Spec gap (see core/shadow_ai.gd): Support has no attack move at
	# all, so "attack when nothing else needed" resolves to re-healing.
	var available := Content.unlocked_moves(moves, "SUPPORT", 1)  # Mend only
	var allies := [_combatant("a1", 100, 100), _combatant("a2", 100, 100)]
	var action := ShadowAI.choose_action("SUPPORT", {}, available, allies, [])
	assert_eq(action["move_id"], "move_support_mend")


# --- Focus lever (§7.3-7.4) ---


func test_focus_target_overrides_single_enemy_selection() -> void:
	var self_v := {"id": "s1", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false}
	var allies := []
	var enemies := [
		{"id": "weak", "hp": 10, "max_hp": 100, "debuffed": false, "is_taunting": false},
		{"id": "focused", "hp": 90, "max_hp": 100, "debuffed": false, "is_taunting": false},
	]
	var mv := Content.moves_by_class(Content.load_moves(), "WARRIOR")
	var no_focus := ShadowAI.choose_action("WARRIOR", self_v, mv, allies, enemies)
	var with_focus := ShadowAI.choose_action("WARRIOR", self_v, mv, allies, enemies, "focused")
	# WARRIOR would normally pile onto "weak"; Focus redirects it to "focused".
	assert_eq(no_focus["target_id"], "weak")
	assert_eq(with_focus["target_id"], "focused")


func test_focus_target_ignored_when_dead_or_absent() -> void:
	var self_v := {"id": "s1", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false}
	var enemies := [
		{"id": "weak", "hp": 10, "max_hp": 100, "debuffed": false, "is_taunting": false}
	]
	var mv := Content.moves_by_class(Content.load_moves(), "WARRIOR")
	var r := ShadowAI.choose_action("WARRIOR", self_v, mv, [], enemies, "ghost")
	assert_eq(r["target_id"], "weak")  # "ghost" not present -> ignored


func test_focus_target_does_not_redirect_aoe() -> void:
	var self_v := {"id": "s1", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false}
	var enemies := [
		{"id": "a", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false},
		{"id": "b", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false},
	]
	var mv := Content.moves_by_class(Content.load_moves(), "MAGE")
	var r := ShadowAI.choose_action("MAGE", self_v, mv, [], enemies, "a")
	# Mage picks an all_enemies spell with 2 up -> Focus must NOT redirect it
	# to a single target; target_id stays "" (AoE).
	assert_true(String(r["move_id"]).begins_with("move_mage_"))
	assert_eq(r["target_id"], "")


func test_support_ai_revives_a_downed_ally_when_reconstitute_is_available() -> void:
	var self_v := {"id": "p", "hp": 100, "max_hp": 100, "debuffed": false, "is_taunting": false}
	var allies := [
		{"id": "corpse", "hp": 0, "max_hp": 500, "debuffed": false, "is_taunting": false},
		{"id": "ok", "hp": 300, "max_hp": 400, "debuffed": false, "is_taunting": false},
	]
	var mv := Content.moves_by_class(Content.load_moves(), "SUPPORT")
	var r := ShadowAI.choose_action("SUPPORT", self_v, mv, allies, [], "")
	assert_eq(r["move_id"], "move_support_reconstitute")
	assert_eq(r["target_id"], "corpse")
