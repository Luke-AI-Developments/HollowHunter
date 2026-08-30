extends GutTest
## Battle: the turn engine (§16 combat overhaul). Constructs small,
## hand-controlled combatants (via Battle's own factories, with fields
## overridden for each scenario) rather than full HunterState/monster
## wiring -- that wiring is step 5's job, this only tests the engine.

var moves: Array


func before_all() -> void:
	moves = Content.load_moves()


# --- Factories ---


func test_make_ally_combatant_derives_combat_stats() -> void:
	var c := Battle.make_ally_combatant("x", "WARRIOR", 1, GameLogic.stats_from(1, "WARRIOR"))
	assert_eq(c["hp"], 82)
	assert_eq(c["max_hp"], 82)
	assert_eq(c["patk"], 20.0)


func test_make_enemy_combatant_derives_from_base_power() -> void:
	var c := Battle.make_enemy_combatant("e1", 120.0)
	assert_eq(c["hp"], 72)
	assert_eq(c["patk"], 18.0)
	assert_true(c["is_enemy"])
	assert_false(c["is_boss"])


func test_combatant_display_name_defaults_to_id() -> void:
	var ally := Battle.make_ally_combatant(
		"x", "WARRIOR", 1, {"STR": 1, "AGI": 1, "VIT": 1, "END": 1, "SEN": 1}
	)
	assert_eq(ally["name"], "x")
	var enemy := Battle.make_enemy_combatant("e1", 100.0)
	assert_eq(enemy["name"], "e1")


func test_ally_combatant_with_no_synergy_bonus_is_unchanged() -> void:
	var c := Battle.make_ally_combatant("x", "WARRIOR", 1, GameLogic.stats_from(1, "WARRIOR"))
	assert_eq(c["hp"], 82)
	assert_eq(c["patk"], 20.0)


func test_ally_combatant_synergy_bonus_scales_hp_patk_matk_def() -> void:
	var base := Battle.make_ally_combatant("x", "WARRIOR", 1, GameLogic.stats_from(1, "WARRIOR"))
	var boosted := Battle.make_ally_combatant(
		"x", "WARRIOR", 1, GameLogic.stats_from(1, "WARRIOR"), "", 0.5
	)
	assert_eq(boosted["hp"], int(round(base["hp"] * 1.5)))
	assert_eq(boosted["max_hp"], boosted["hp"])
	assert_eq(boosted["patk"], base["patk"] * 1.5)
	assert_eq(boosted["matk"], base["matk"] * 1.5)
	assert_eq(boosted["def"], base["def"] * 1.5)


func test_ally_combatant_synergy_bonus_leaves_crit_and_speed_untouched() -> void:
	var base := Battle.make_ally_combatant(
		"x", "ASSASSIN", 10, GameLogic.stats_from(10, "ASSASSIN")
	)
	var boosted := Battle.make_ally_combatant(
		"x", "ASSASSIN", 10, GameLogic.stats_from(10, "ASSASSIN"), "", 0.5
	)
	assert_eq(boosted["crit_chance"], base["crit_chance"])
	assert_eq(boosted["speed"], base["speed"])


func test_combatant_display_name_uses_the_given_name() -> void:
	var enemy := Battle.make_enemy_combatant("e1", 100.0, false, "Grubmaw")
	assert_eq(enemy["name"], "Grubmaw")


# --- Trait flags / family (§6b part 3) ---


func test_ally_combatant_with_no_trait_ids_has_all_flags_false() -> void:
	var c := Battle.make_ally_combatant("x", "WARRIOR", 1, GameLogic.stats_from(1, "WARRIOR"))
	var f: Dictionary = c["trait_flags"]
	for key in ["bloodhunger", "warcaller", "frostblooded", "relentless", "executioner"]:
		assert_false(f[key], "%s should default false" % key)


func test_ally_combatant_resolves_known_battle_trait_ids_to_flags() -> void:
	var c := Battle.make_ally_combatant(
		"x",
		"WARRIOR",
		1,
		GameLogic.stats_from(1, "WARRIOR"),
		"",
		0.0,
		["executioner", "bloodhunger", "sturdy", "not_a_trait"]
	)
	var f: Dictionary = c["trait_flags"]
	assert_true(f["executioner"])
	assert_true(f["bloodhunger"])
	assert_false(f["warcaller"])
	# non-battle ids ("sturdy") and unknowns are simply not battle flags
	assert_false(f.has("sturdy"))


func test_enemy_combatant_family_defaults_empty_and_is_stored_when_given() -> void:
	assert_eq(Battle.make_enemy_combatant("e1", 100.0)["family"], "")
	assert_eq(
		Battle.make_enemy_combatant("e2", 100.0, false, "Frostquill", "Rime Sylphs")["family"],
		"Rime Sylphs"
	)


func test_enemy_combatant_elite_defaults_false_and_is_stored() -> void:
	assert_false(Battle.make_enemy_combatant("e", 100.0)["elite"])
	assert_true(Battle.make_enemy_combatant("e", 100.0, true, "e", "", true)["elite"])


func test_enemy_combatant_has_all_false_trait_flags() -> void:
	var f: Dictionary = Battle.make_enemy_combatant("e1", 100.0)["trait_flags"]
	assert_false(f["executioner"])
	assert_false(f["frostblooded"])


func test_warcaller_raises_every_party_members_patk_and_matk() -> void:
	var stats := {"STR": 100, "AGI": 50, "VIT": 100, "END": 100, "SEN": 100}
	var base_p := Battle.make_ally_combatant("p", "WARRIOR", 10, stats)
	var base_s := Battle.make_ally_combatant("s", "MAGE", 10, stats)
	var plain := Battle.new(
		[base_p.duplicate(true), base_s.duplicate(true)],
		[Battle.make_enemy_combatant("e", 100.0)],
		moves
	)
	var p_with := Battle.make_ally_combatant("p", "WARRIOR", 10, stats, "", 0.0, ["warcaller"])
	var s_with := Battle.make_ally_combatant("s", "MAGE", 10, stats)
	var aura := Battle.new([p_with, s_with], [Battle.make_enemy_combatant("e", 100.0)], moves)
	assert_almost_eq(
		aura.party[0]["patk"], plain.party[0]["patk"] * (1.0 + Battle.WARCALLER_AURA), 0.001
	)
	assert_almost_eq(
		aura.party[1]["matk"], plain.party[1]["matk"] * (1.0 + Battle.WARCALLER_AURA), 0.001
	)
	assert_eq(aura.party[0]["speed"], plain.party[0]["speed"])  # speed untouched
	assert_eq(aura.party[0]["def"], plain.party[0]["def"])  # def untouched


func test_no_warcaller_leaves_party_atk_unchanged() -> void:
	var stats := {"STR": 100, "AGI": 50, "VIT": 100, "END": 100, "SEN": 100}
	var a := Battle.new(
		[Battle.make_ally_combatant("p", "WARRIOR", 10, stats)],
		[Battle.make_enemy_combatant("e", 100.0)],
		moves
	)
	var expected := Battle.make_ally_combatant("p", "WARRIOR", 10, stats)
	assert_eq(a.party[0]["patk"], expected["patk"])


func test_warcaller_does_not_touch_enemy_stats() -> void:
	var stats := {"STR": 100, "AGI": 50, "VIT": 100, "END": 100, "SEN": 100}
	var with_aura := Battle.new(
		[Battle.make_ally_combatant("p", "WARRIOR", 10, stats, "", 0.0, ["warcaller"])],
		[Battle.make_enemy_combatant("e", 300.0)],
		moves
	)
	var bare_enemy := Battle.make_enemy_combatant("e", 300.0)
	assert_eq(with_aura.enemies[0]["patk"], bare_enemy["patk"])


func test_relentless_ticks_cooldowns_down_by_two() -> void:
	var actor := Battle.make_ally_combatant(
		"player",
		"GUARDIAN",
		1,
		{"STR": 10, "AGI": 10, "VIT": 10, "END": 10, "SEN": 10},
		"",
		0.0,
		["relentless"]
	)
	actor["cooldowns"] = {"move_x": 4}
	var battle := Battle.new([actor], [Battle.make_enemy_combatant("e", 50.0)], moves, true)
	battle._tick_start_of_turn(actor)
	assert_eq(int(actor["cooldowns"]["move_x"]), 2)
	battle._tick_start_of_turn(actor)
	assert_eq(int(actor["cooldowns"]["move_x"]), 0)


func test_non_relentless_ticks_cooldowns_down_by_one() -> void:
	var actor := Battle.make_ally_combatant(
		"player", "GUARDIAN", 1, {"STR": 10, "AGI": 10, "VIT": 10, "END": 10, "SEN": 10}
	)
	actor["cooldowns"] = {"move_x": 4}
	var battle := Battle.new([actor], [Battle.make_enemy_combatant("e", 50.0)], moves, true)
	battle._tick_start_of_turn(actor)
	assert_eq(int(actor["cooldowns"]["move_x"]), 3)


# --- Turn order ---


func test_turn_queue_orders_by_speed_descending() -> void:
	var fast_player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 10, "AGI": 100, "VIT": 10, "END": 10, "SEN": 10}
	)
	var slow_shadow := Battle.make_ally_combatant(
		"shadow1", "ASSASSIN", 1, {"STR": 10, "AGI": 1, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 500.0)  # speed = round(500*0.02) = 10
	var battle := Battle.new([fast_player, slow_shadow], [enemy], moves)
	assert_eq(battle.turn_queue[0], "player")
	assert_eq(battle.turn_queue[2], "shadow1")


# --- Basic attack + win/loss ---


func test_step_resolves_a_basic_attack_and_reduces_enemy_hp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 50, "AGI": 100, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 200.0)
	var battle := Battle.new([player], [enemy], moves, true, rng)
	var hp_before: int = battle.enemies[0]["hp"]
	battle.step()
	assert_true(battle.enemies[0]["hp"] < hp_before)


func test_run_to_completion_wins_when_enemies_are_overwhelmed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 40, {"STR": 1000, "AGI": 100, "VIT": 500, "END": 500, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 50.0)
	var battle := Battle.new([player], [enemy], moves, true, rng)
	var result := battle.run_to_completion()
	assert_true(result["battle_over"])
	assert_true(result["won"])


func test_run_to_completion_loses_when_overwhelmed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 1, "AGI": 1, "VIT": 1, "END": 1, "SEN": 1}
	)
	var enemy := Battle.make_enemy_combatant("e1", 100000.0)
	var battle := Battle.new([player], [enemy], moves, true, rng)
	var result := battle.run_to_completion()
	assert_true(result["battle_over"])
	assert_false(result["won"])


func test_run_to_completion_stops_and_waits_in_manual_mode() -> void:
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 10, "AGI": 100, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 50.0)
	var battle := Battle.new([player], [enemy], moves, false)
	var result := battle.run_to_completion()
	assert_false(result["battle_over"])


func test_resolve_pending_player_turn_via_ai_resolves_a_real_action() -> void:
	# Simulates toggling Auto-battle on while step() is already paused on
	# the player's turn -- must resolve THAT turn via AI, not skip it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 50, "AGI": 100, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 200.0)
	var battle := Battle.new([player], [enemy], moves, false, rng)
	var paused := battle.step()
	assert_true(paused.get("waiting_for_player", false))
	var hp_before: int = battle.enemies[0]["hp"]
	battle.resolve_pending_player_turn_via_ai()
	assert_true(battle.enemies[0]["hp"] < hp_before)


# --- Cooldowns ---


func test_cooldown_is_set_after_a_move_is_used() -> void:
	var guardian := Battle.make_ally_combatant(
		"player", "GUARDIAN", 1, {"STR": 10, "AGI": 10, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 100.0)
	var battle := Battle.new([guardian], [enemy], moves, true)
	battle.step()  # not yet taunting -> ShadowAI picks Taunt
	var g: Dictionary = battle.party[0]
	assert_eq(int(g["cooldowns"].get("move_guardian_taunt", 0)), 3)


# --- Taunt ---


func test_taunting_ally_draws_enemy_attacks() -> void:
	var guardian := Battle.make_ally_combatant(
		"g1", "GUARDIAN", 1, {"STR": 10, "AGI": 1000, "VIT": 200, "END": 200, "SEN": 10}
	)
	guardian["is_taunting"] = true
	guardian["taunt_turns"] = 10
	var guardian_hp_before: int = guardian["hp"]
	var mage := Battle.make_ally_combatant(
		"m1", "MAGE", 1, {"STR": 1, "AGI": 999, "VIT": 50, "END": 50, "SEN": 50}
	)
	var mage_hp_before: int = mage["hp"]
	# Low base_power keeps speed low (acts last), but HP is overridden way
	# up afterward so it survives the guardian's and mage's hits and
	# actually gets a turn -- speed and HP both derive from base_power, so
	# bumping base_power itself to raise HP would also raise speed past
	# the party's and break the intended turn order.
	var enemy := Battle.make_enemy_combatant("e1", 50.0)
	enemy["hp"] = 100000
	enemy["max_hp"] = 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var battle := Battle.new([guardian, mage], [enemy], moves, true, rng)
	battle.step()  # guardian's turn (already taunting -- attacks instead)
	battle.step()  # mage's turn
	battle.step()  # enemy's turn -- must target the taunting guardian
	assert_eq(battle.party[1]["hp"], mage_hp_before)
	assert_true(battle.party[0]["hp"] < guardian_hp_before)


# --- Shield ---


func test_shield_absorbs_enemy_damage_before_hp_loss() -> void:
	var ally := Battle.make_ally_combatant(
		"a1", "WARRIOR", 1, {"STR": 10, "AGI": 1, "VIT": 50, "END": 50, "SEN": 10}
	)
	ally["shield_hp"] = 100000
	var hp_before: int = ally["hp"]
	var enemy := Battle.make_enemy_combatant("e1", 300.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var battle := Battle.new([ally], [enemy], moves, true, rng)
	battle.step()  # ally's turn (attacks enemy)
	battle.step()  # enemy's turn (attacks ally -- fully absorbed)
	assert_eq(battle.party[0]["hp"], hp_before)
	assert_true(battle.party[0]["shield_hp"] < 100000)


# --- Poison (DOT) ---


func test_poison_edge_applies_damage_over_time() -> void:
	var assassin := Battle.make_ally_combatant(
		"player", "ASSASSIN", 6, {"STR": 50, "AGI": 1000, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 5000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var battle := Battle.new([assassin], [enemy], moves, false, rng)
	var result := battle.step()
	assert_true(result.get("waiting_for_player", false))
	battle.resolve_player_action("move_assassin_poison_edge", "e1")
	var enemy_now: Dictionary = battle.enemies[0]
	assert_true(int(enemy_now["poison_turns"]) > 0)
	assert_true(int(enemy_now["poison_damage"]) > 0)


# --- Heal cap ---


func test_heal_never_exceeds_max_hp() -> void:
	var support_player := Battle.make_ally_combatant(
		"player", "SUPPORT", 1, {"STR": 1, "AGI": 10, "VIT": 10, "END": 10, "SEN": 50}
	)
	var ally := Battle.make_ally_combatant(
		"a2", "WARRIOR", 1, {"STR": 10, "AGI": 1, "VIT": 10, "END": 10, "SEN": 10}
	)
	ally["hp"] = ally["max_hp"] - 1
	var enemy := Battle.make_enemy_combatant("e1", 50.0)
	var battle := Battle.new([support_player, ally], [enemy], moves, false)
	var result := battle.step()
	assert_true(result.get("waiting_for_player", false))
	battle.resolve_player_action("move_support_mend", "a2")
	assert_eq(battle.party[1]["hp"], battle.party[1]["max_hp"])


# --- Buff/debuff duration ---


func test_defense_buff_expires_after_its_duration() -> void:
	var guardian := Battle.make_ally_combatant(
		"player", "GUARDIAN", 5, {"STR": 10, "AGI": 1000, "VIT": 100, "END": 100, "SEN": 10}
	)
	guardian["def_multiplier"] = 1.5
	guardian["def_mod_turns"] = 1  # about to expire on its next turn
	var enemy := Battle.make_enemy_combatant("e1", 50.0)
	var battle := Battle.new([guardian], [enemy], moves, true)
	battle.step()
	assert_eq(battle.party[0]["def_multiplier"], 1.0)


func test_debuff_lowers_target_defense() -> void:
	var assassin := Battle.make_ally_combatant(
		"player", "ASSASSIN", 3, {"STR": 10, "AGI": 1000, "VIT": 10, "END": 10, "SEN": 10}
	)
	var enemy := Battle.make_enemy_combatant("e1", 500.0)
	var battle := Battle.new([assassin], [enemy], moves, false)
	battle.step()
	battle.resolve_player_action("move_assassin_weaken", "e1")
	assert_true(battle.enemies[0]["def_multiplier"] < 1.0)


# --- Boss telegraph ---


func test_boss_telegraphs_before_a_big_hit() -> void:
	var boss := Battle.make_enemy_combatant("boss", 1000.0, true)
	boss["turns_until_big_hit"] = 0
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 10, "AGI": 1, "VIT": 1000, "END": 1000, "SEN": 10}
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var battle := Battle.new([player], [boss], moves, true, rng)
	assert_true(battle.is_boss_next_hit_big("boss"))
	battle.step()  # boss speed(20) > player AGI(1) -- boss acts first
	assert_false(battle.log.is_empty())
	assert_true(bool(battle.log[0]["big_hit"]))
	assert_false(battle.is_boss_next_hit_big("boss"))


func test_non_boss_enemy_never_telegraphs() -> void:
	var grunt := Battle.make_enemy_combatant("grunt", 200.0, false)
	var player := Battle.make_ally_combatant(
		"player", "WARRIOR", 1, {"STR": 10, "AGI": 10, "VIT": 10, "END": 10, "SEN": 10}
	)
	var battle := Battle.new([player], [grunt], moves)
	assert_false(battle.is_boss_next_hit_big("grunt"))


# --- Determinism ---


func test_battle_is_deterministic_with_the_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 123
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 123
	var stats := {"STR": 100, "AGI": 50, "VIT": 100, "END": 100, "SEN": 10}
	var battle_a := Battle.new(
		[Battle.make_ally_combatant("player", "WARRIOR", 10, stats)],
		[Battle.make_enemy_combatant("e1", 300.0)],
		moves,
		true,
		rng_a
	)
	var battle_b := Battle.new(
		[Battle.make_ally_combatant("player", "WARRIOR", 10, stats)],
		[Battle.make_enemy_combatant("e1", 300.0)],
		moves,
		true,
		rng_b
	)
	var result_a := battle_a.run_to_completion()
	var result_b := battle_b.run_to_completion()
	assert_eq(result_a, result_b)
	assert_eq(battle_a.party[0]["hp"], battle_b.party[0]["hp"])
	assert_eq(battle_a.enemies[0]["hp"], battle_b.enemies[0]["hp"])


func _one_hit_damage(
	actor_trait_ids: Array,
	enemy_is_boss: bool,
	enemy_family: String,
	seed_value: int,
	enemy_elite: bool = false
) -> int:
	# One auto-battle step: the ally attacks once; return the logged damage.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var actor := Battle.make_ally_combatant(
		"player",
		"WARRIOR",
		10,
		{"STR": 300, "AGI": 100, "VIT": 200, "END": 50, "SEN": 10},
		"",
		0.0,
		actor_trait_ids
	)
	# Low base_power keeps enemy SPEED below the actor's so the actor's hit
	# lands first; HP/max_hp are then overridden way up so the measured hit
	# never drops the target below LOW_HP_THRESHOLD (which would trigger a
	# bonus_vs_low_hp move tag and skew the ratio). Same speed/HP-coupling
	# workaround the taunt/shield tests use.
	var enemy := Battle.make_enemy_combatant(
		"e1", 200.0, enemy_is_boss, "e1", enemy_family, enemy_elite
	)
	enemy["hp"] = 100000
	enemy["max_hp"] = 100000
	var battle := Battle.new([actor], [enemy], moves, true, rng)
	battle.step()
	for ev in battle.log:
		if ev.get("type", "") == "damage":
			return int(ev["damage"])
	return -1


func test_executioner_multiplies_damage_vs_an_elite() -> void:
	var plain := _one_hit_damage([], false, "", 4, false)
	var exec := _one_hit_damage(["executioner"], false, "", 4, true)
	assert_almost_eq(float(exec) / float(plain), Battle.TRAIT_DAMAGE_BONUS, 0.04)


func test_executioner_does_nothing_vs_a_non_elite() -> void:
	assert_eq(
		_one_hit_damage(["executioner"], false, "", 4, false),
		_one_hit_damage([], false, "", 4, false)
	)


func test_executioner_ignores_is_boss_when_not_elite() -> void:
	# Regression: every gate enemy is is_boss=true for the CLAIM telegraph;
	# executioner must NOT fire on a plain (non-A/S) gate.
	assert_eq(
		_one_hit_damage(["executioner"], true, "", 4, false),
		_one_hit_damage([], true, "", 4, false)
	)


func test_frostblooded_multiplies_damage_vs_rime_family_only() -> void:
	var vs_rime_plain := _one_hit_damage([], false, Battle.FROSTBLOODED_FAMILY, 4)
	var vs_rime_frost := _one_hit_damage(["frostblooded"], false, Battle.FROSTBLOODED_FAMILY, 4)
	assert_almost_eq(float(vs_rime_frost) / float(vs_rime_plain), Battle.TRAIT_DAMAGE_BONUS, 0.04)
	assert_eq(
		_one_hit_damage(["frostblooded"], false, "Gravekin", 4),
		_one_hit_damage([], false, "Gravekin", 4)
	)


func test_executioner_and_frostblooded_stack_multiplicatively() -> void:
	var plain := _one_hit_damage([], false, Battle.FROSTBLOODED_FAMILY, 4, true)
	var both := _one_hit_damage(
		["executioner", "frostblooded"], false, Battle.FROSTBLOODED_FAMILY, 4, true
	)
	var expected := Battle.TRAIT_DAMAGE_BONUS * Battle.TRAIT_DAMAGE_BONUS
	assert_almost_eq(float(both) / float(plain), expected, 0.06)


func test_bloodhunger_heals_the_killer_on_a_kill() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var actor := Battle.make_ally_combatant(
		"player",
		"WARRIOR",
		20,
		{"STR": 5000, "AGI": 100, "VIT": 400, "END": 100, "SEN": 10},
		"",
		0.0,
		["bloodhunger"]
	)
	actor["hp"] = 10  # well below max
	var expected_heal := int(round(actor["max_hp"] * Battle.BLOODHUNGER_HEAL_FRAC))
	var enemy := Battle.make_enemy_combatant("e1", 20.0)  # 12 HP -- one hit kills
	var battle := Battle.new([actor], [enemy], moves, true, rng)
	battle.step()
	assert_eq(battle.enemies[0]["hp"], 0)
	assert_eq(battle.party[0]["hp"], mini(actor["max_hp"], 10 + expected_heal))


func test_bloodhunger_does_not_heal_on_a_non_killing_hit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var actor := Battle.make_ally_combatant(
		"player",
		"WARRIOR",
		5,
		{"STR": 10, "AGI": 100, "VIT": 200, "END": 50, "SEN": 10},
		"",
		0.0,
		["bloodhunger"]
	)
	actor["hp"] = 10
	# Low base_power -> low SPEED so the actor swings first; HP overridden up
	# so the enemy survives the hit (no kill -> no bloodhunger heal).
	var enemy := Battle.make_enemy_combatant("e1", 200.0)
	enemy["hp"] = 100000
	enemy["max_hp"] = 100000
	var battle := Battle.new([actor], [enemy], moves, true, rng)
	battle.step()
	assert_eq(battle.party[0]["hp"], 10)


func test_no_bloodhunger_no_heal_on_kill() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var actor := Battle.make_ally_combatant(
		"player", "WARRIOR", 20, {"STR": 5000, "AGI": 100, "VIT": 400, "END": 100, "SEN": 10}
	)
	actor["hp"] = 10
	var enemy := Battle.make_enemy_combatant("e1", 20.0)
	var battle := Battle.new([actor], [enemy], moves, true, rng)
	battle.step()
	assert_eq(battle.party[0]["hp"], 10)


# --- Enemy role / atk_type + magic DEF pierce (combat v1 §2/§3) ---


func test_enemy_combatant_carries_role_and_atk_type_defaults() -> void:
	var c := Battle.make_enemy_combatant("e", 1000.0)
	assert_eq(c["role"], "bruiser")
	assert_eq(c["atk_type"], "physical")
	assert_almost_eq(c["def"], 1000.0 * 0.05, 0.001)


func test_enemy_combatant_armoured_role_has_high_def() -> void:
	var c := Battle.make_enemy_combatant("e", 1000.0, false, "e", "", false, "armoured")
	assert_almost_eq(c["def"], 1000.0 * 0.11, 0.001)


func test_boss_combatant_uses_boss_def_coeff_not_the_passed_grunt_role() -> void:
	var c := Battle.make_enemy_combatant("boss", 1000.0, true, "Boss", "", false, "armoured")
	assert_almost_eq(c["def"], 1000.0 * 0.06, 0.001)  # boss coeff wins over the "armoured" arg
	assert_eq(c["hp"], Battle.make_enemy_combatant("x", 1000.0)["hp"])  # boss keeps bruiser HP


func test_magic_move_pierces_enemy_def_vs_an_armoured_target() -> void:
	# Same seed, same attacker power/stats; a magic move out-damages a physical
	# move of equal power against a high-DEF armoured enemy, because magic
	# ignores 60% of the target's DEF (spec §2.3).
	var stats := {"STR": 400, "AGI": 100, "VIT": 100, "END": 50, "SEN": 400}
	var phys_dmg := _first_damage_of_move(stats, "armoured", "physical", 4)
	var magic_dmg := _first_damage_of_move(stats, "armoured", "magic", 4)
	assert_gt(magic_dmg, phys_dmg)


func _first_damage_of_move(
	stats: Dictionary, enemy_role: String, move_type: String, seed_value: int
) -> int:
	# Mirrors _one_hit_damage: one auto step, return the first logged "damage".
	# WARRIOR strike (physical) vs MAGE cyan bolt (magic) -- both power 1.0,
	# single-target, no tag, level 1 (the only attack each has), and the
	# caller's balanced STR/SEN make PATK == MATK, so the DEF pierce is the
	# only thing separating the two runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var is_magic := move_type == "magic"
	var actor := Battle.make_ally_combatant("player", "MAGE" if is_magic else "WARRIOR", 1, stats)
	var enemy := Battle.make_enemy_combatant("e1", 200.0, false, "e1", "", false, enemy_role)
	enemy["hp"] = 100000
	enemy["max_hp"] = 100000
	var battle := Battle.new([actor], [enemy], moves, true, rng)
	battle.step()
	for ev in battle.log:
		if ev.get("type", "") == "damage":
			return int(ev["damage"])
	return -1
