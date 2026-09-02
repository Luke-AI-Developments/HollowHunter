extends GutTest
## Battle: multi-phase boss transitions (spec §3.5). Split out of
## test_battle.gd, which is at the 1500-line lint cap -- same engine,
## same factories, just the `kit` / `is_multiphase` / `phase` surface.

var moves: Array


func before_all() -> void:
	moves = Content.load_moves()


func _ally(id: String, clazz: String) -> Dictionary:
	return Battle.make_ally_combatant(
		id, clazz, 10, {"STR": 200, "AGI": 80, "VIT": 200, "END": 50, "SEN": 200}
	)


func _seeded_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_multiphase_boss_enters_phase_2_at_half_hp() -> void:
	var boss := Battle.make_enemy_combatant(
		"boss", 1500.0, true, "Boss", "Emberdrakes", true, "bruiser", "physical", "berserker", true
	)
	var b := Battle.new([_ally("p", "WARRIOR")], [boss], moves, false, _seeded_rng(1))
	var bc := b._combatant_by_id("boss")
	assert_eq(int(bc["phase"]), 1)
	assert_eq(bc["kit"], "berserker")
	bc["hp"] = int(bc["max_hp"] * 0.45)
	b._check_phase_transition(bc)
	assert_eq(int(bc["phase"]), 2)
	var phased := false
	for ev in b.log:
		if ev.get("type", "") == "phase" and ev["actor_id"] == "boss":
			phased = true
	assert_true(phased)


func test_single_phase_boss_never_phases() -> void:
	var boss := Battle.make_enemy_combatant(
		"boss",
		1500.0,
		true,
		"Boss",
		"Emberdrakes",
		false,
		"bruiser",
		"physical",
		"berserker",
		false
	)
	var b := Battle.new([_ally("p", "WARRIOR")], [boss], moves, true, _seeded_rng(1))
	var bc := b._combatant_by_id("boss")
	bc["hp"] = 1
	b._check_phase_transition(bc)
	assert_eq(int(bc["phase"]), 1)


func test_non_boss_never_gets_a_kit() -> void:
	var g := Battle.make_enemy_combatant(
		"g", 500.0, false, "G", "Emberdrakes", false, "skirmisher", "physical", "berserker", true
	)
	assert_eq(g["kit"], "")
	assert_false(g.get("is_multiphase", false))


func test_boss_telegraph_interval_is_kit_and_phase_aware() -> void:
	var colossus := Battle.make_enemy_combatant(
		"c", 2000.0, true, "C", "Rime Sylphs", true, "bruiser", "physical", "colossus", true
	)
	var plain := Battle.make_enemy_combatant("p", 2000.0, true, "P")
	var b := Battle.new([_ally("x", "WARRIOR")], [colossus, plain], moves, true, _seeded_rng(1))
	assert_eq(b._boss_telegraph_interval(b._combatant_by_id("c")), 4)
	b._combatant_by_id("c")["phase"] = 2
	assert_eq(b._boss_telegraph_interval(b._combatant_by_id("c")), 3)
	assert_eq(b._boss_telegraph_interval(b._combatant_by_id("p")), Battle.BOSS_BIG_HIT_INTERVAL)


func test_kit_on_turn_stub_falls_through_to_a_basic_boss_attack() -> void:
	# With every kit arm still a stub, a kitted boss still attacks each turn.
	var actor := Battle.make_ally_combatant(
		"player", "WARRIOR", 15, {"STR": 100, "AGI": 5, "VIT": 900, "END": 400, "SEN": 10}
	)
	var boss := Battle.make_enemy_combatant(
		"boss", 1200.0, true, "Boss", "Ashen Wardens", false, "bruiser", "physical", "warden", false
	)
	var b := Battle.new([actor], [boss], moves, true, _seeded_rng(4))
	b.step()  # boss is faster -> it acts; stub on_turn returns false -> basic attack
	var attacked := false
	for ev in b.log:
		if ev.get("type", "") == "enemy_attack" and ev["actor_id"] == "boss":
			attacked = true
	assert_true(attacked)


func _berserker(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(
		id, 1400.0, true, "Boss", "Emberdrakes", true, "bruiser", "physical", "berserker", true
	)


func _colossus(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(
		id, 1800.0, true, "Boss", "Rime Sylphs", true, "bruiser", "physical", "colossus", true
	)


func test_berserker_immolate_hits_the_lowest_hp_party_member_on_a_telegraph_turn() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")],
		[_berserker("boss")],
		moves,
		true,
		_seeded_rng(3)
	)
	var bc := b._combatant_by_id("boss")
	var lo := b._combatant_by_id("p2")
	lo["hp"] = int(lo["max_hp"] * 0.3)
	var lo_before: int = lo["hp"]
	var hi_before: int = b._combatant_by_id("p1")["hp"]
	bc["turns_until_big_hit"] = 0
	assert_true(BossKits.on_turn(b, bc))
	assert_lt(int(lo["hp"]), lo_before)
	assert_eq(int(b._combatant_by_id("p1")["hp"]), hi_before)
	var immolated := false
	for ev in b.log:
		if (
			ev.get("type", "") == "enemy_attack"
			and ev.get("target_id", "") == "p2"
			and ev.get("big_hit", false)
		):
			immolated = true
	assert_true(immolated)


func test_berserker_off_telegraph_even_turn_poisons_its_target() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_berserker("boss")], moves, true, _seeded_rng(7))
	var bc := b._combatant_by_id("boss")
	var p := b._combatant_by_id("p")
	BossKits.on_turn(b, bc)  # kit-turn 1 -> plain basic
	assert_eq(int(p.get("poison_turns", 0)), 0)
	BossKits.on_turn(b, bc)  # kit-turn 2 -> basic + burn
	assert_eq(int(p["poison_turns"]), int(BossKits.BOSS_KITS["berserker"]["burn_turns"]))
	assert_gt(int(p["poison_damage"]), 0)


func test_berserker_on_phase_fires_a_free_immolate() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")],
		[_berserker("boss")],
		moves,
		true,
		_seeded_rng(5)
	)
	var bc := b._combatant_by_id("boss")
	var lo := b._combatant_by_id("p2")
	lo["hp"] = int(lo["max_hp"] * 0.25)
	var lo_before: int = lo["hp"]
	BossKits.on_phase(b, bc)
	assert_lt(int(lo["hp"]), lo_before)
	var hit := false
	for ev in b.log:
		if ev.get("type", "") == "enemy_attack" and ev.get("target_id", "") == "p2":
			hit = true
	assert_true(hit)


func test_colossus_avalanche_splashes_the_rest_of_the_party_when_not_broken() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR"), _ally("p3", "WARRIOR")],
		[_colossus("boss")],
		moves,
		true,
		_seeded_rng(11)
	)
	var bc := b._combatant_by_id("boss")
	b._combatant_by_id("p2")["hp"] = int(b._combatant_by_id("p2")["max_hp"] * 0.4)  # primary target
	var p1_before: int = b._combatant_by_id("p1")["hp"]
	var p3_before: int = b._combatant_by_id("p3")["hp"]
	bc["turns_until_big_hit"] = 0
	bc["broken_turns"] = 0
	BossKits.on_turn(b, bc)
	assert_lt(int(b._combatant_by_id("p1")["hp"]), p1_before)
	assert_lt(int(b._combatant_by_id("p3")["hp"]), p3_before)


func test_colossus_avalanche_does_not_splash_when_the_boss_is_broken() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR"), _ally("p3", "WARRIOR")],
		[_colossus("boss")],
		moves,
		true,
		_seeded_rng(11)
	)
	var bc := b._combatant_by_id("boss")
	b._combatant_by_id("p2")["hp"] = int(b._combatant_by_id("p2")["max_hp"] * 0.4)  # primary target
	var p1_before: int = b._combatant_by_id("p1")["hp"]
	var p2_before: int = b._combatant_by_id("p2")["hp"]
	var p3_before: int = b._combatant_by_id("p3")["hp"]
	bc["turns_until_big_hit"] = 0
	bc["broken_turns"] = 2
	BossKits.on_turn(b, bc)
	assert_eq(int(b._combatant_by_id("p1")["hp"]), p1_before)
	assert_eq(int(b._combatant_by_id("p3")["hp"]), p3_before)
	assert_lt(int(b._combatant_by_id("p2")["hp"]), p2_before)  # primary still lands


func test_colossus_kit_bakes_slower_speed_and_a_bigger_break_bar() -> void:
	var col := _colossus("c")
	var plain := Battle.make_enemy_combatant("p", 1800.0, true, "P")
	var col_kit: Dictionary = BossKits.BOSS_KITS["colossus"]
	assert_eq(int(col["speed"]), int(round(float(plain["speed"]) * float(col_kit["speed_mult"]))))
	assert_almost_eq(
		float(col["break_max"]), float(plain["break_max"]) * float(col_kit["break_max_mult"]), 0.5
	)


func _warden(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(
		id, 1200.0, true, "Boss", "Ashen Wardens", true, "bruiser", "physical", "warden", true
	)


func _hexer(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(
		id, 1200.0, true, "Boss", "Abyssal Fiends", true, "bruiser", "physical", "hexer", true
	)


func _count_events(b: Battle, kind: String) -> int:
	var n := 0
	for ev in b.log:
		if ev.get("type", "") == kind:
			n += 1
	return n


func test_warden_kit_bakes_def_x1_4() -> void:
	var warden := _warden("w")
	var plain := Battle.make_enemy_combatant("p", 1200.0, true, "P")
	assert_almost_eq(
		float(warden["def"]),
		float(plain["def"]) * float(BossKits.BOSS_KITS["warden"]["def_mult"]),
		0.01
	)


func test_bulwark_softens_physical_break_fill_but_not_magic() -> void:
	var b := Battle.new(
		[_ally("p", "WARRIOR")],
		[_warden("w"), Battle.make_enemy_combatant("q", 1200.0, true, "Q")],
		moves,
		true,
		_seeded_rng(2)
	)
	var w := b._combatant_by_id("w")
	var q := b._combatant_by_id("q")
	var actor := b._combatant_by_id("p")
	var hit := {"damage": 400, "crit": false}
	b._land_hit(actor, w, hit, "", "", true)
	b._land_hit(actor, q, hit, "", "", true)
	assert_almost_eq(
		float(w["break_current"]),
		float(q["break_current"]) * float(BossKits.BOSS_KITS["warden"]["break_phys_mult"]),
		0.01
	)
	w["break_current"] = 0.0
	q["break_current"] = 0.0
	b._land_hit(actor, w, hit, "", "", false)
	b._land_hit(actor, q, hit, "", "", false)
	assert_almost_eq(float(w["break_current"]), float(q["break_current"]), 0.01)


func test_shield_bash_stuns_the_lowest_hp_party_member_on_a_telegraph_turn() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")],
		[_warden("w")],
		moves,
		true,
		_seeded_rng(3)
	)
	var w := b._combatant_by_id("w")
	var lo := b._combatant_by_id("p2")
	lo["hp"] = int(lo["max_hp"] * 0.5)
	var lo_before: int = lo["hp"]
	var hi_before: int = b._combatant_by_id("p1")["hp"]
	w["turns_until_big_hit"] = 0
	assert_true(BossKits.on_turn(b, w))
	assert_lt(int(lo["hp"]), lo_before)
	assert_eq(int(b._combatant_by_id("p1")["hp"]), hi_before)
	assert_true(b.has_status(lo, "stun"))


func test_bastion_fires_under_60_percent_and_self_cleanses() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_warden("w")], moves, true, _seeded_rng(4))
	var w := b._combatant_by_id("w")
	w["hp"] = int(w["max_hp"] * 0.5)
	w["statuses"] = {"stun": 2, "vulnerable": 3}
	w["atk_multiplier"] = 0.8
	w["atk_buff_turns"] = 2
	assert_true(BossKits.on_turn(b, w))
	assert_true((w["statuses"] as Dictionary).is_empty())
	assert_almost_eq(
		float(w["def_multiplier"]), float(BossKits.BOSS_KITS["warden"]["bastion_def_mult"]), 0.001
	)
	assert_eq(int(w["def_mod_turns"]), int(BossKits.BOSS_KITS["warden"]["bastion_turns"]))
	assert_almost_eq(float(w["atk_multiplier"]), 1.0, 0.001)
	assert_eq(_count_events(b, "bastion"), 1)


func test_bastion_fires_only_once_per_phase() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_warden("w")], moves, true, _seeded_rng(5))
	var w := b._combatant_by_id("w")
	w["hp"] = int(w["max_hp"] * 0.5)
	BossKits.on_turn(b, w)
	assert_eq(_count_events(b, "bastion"), 1)
	w["hp"] = int(w["max_hp"] * 0.5)
	BossKits.on_turn(b, w)
	assert_eq(_count_events(b, "bastion"), 1, "a second sub-60% turn must not re-fire Bastion")


func test_warden_on_phase_fires_bastion_immediately() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_warden("w")], moves, true, _seeded_rng(6))
	var w := b._combatant_by_id("w")
	w["hp"] = int(w["max_hp"] * 0.9)  # above the 60% gate -- on_phase ignores it
	w["phase"] = 2
	w["statuses"] = {"stun": 1}
	BossKits.on_phase(b, w)
	assert_true((w["statuses"] as Dictionary).is_empty())
	assert_almost_eq(
		float(w["def_multiplier"]), float(BossKits.BOSS_KITS["warden"]["bastion_def_mult"]), 0.001
	)
	assert_eq(int(w.get("_bastion_phase_used", 0)), 2)
	w["hp"] = int(w["max_hp"] * 0.4)
	BossKits.on_turn(b, w)
	assert_eq(_count_events(b, "bastion"), 1, "on-phase Bastion consumes the phase's ability slot")


func test_doom_hits_every_living_party_member_and_atk_downs_all() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR"), _ally("p3", "WARRIOR")],
		[_hexer("h")],
		moves,
		true,
		_seeded_rng(7)
	)
	var h := b._combatant_by_id("h")
	var before := {}
	for pid in ["p1", "p2", "p3"]:
		before[pid] = int(b._combatant_by_id(pid)["hp"])
	h["turns_until_big_hit"] = 0
	assert_true(BossKits.on_turn(b, h))
	for pid in ["p1", "p2", "p3"]:
		var c := b._combatant_by_id(pid)
		assert_lt(int(c["hp"]), int(before[pid]), "%s took Doom damage" % pid)
		assert_almost_eq(
			float(c["atk_multiplier"]), float(BossKits.BOSS_KITS["hexer"]["atkdown_mult"]), 0.001
		)
		assert_eq(int(c["atk_buff_turns"]), int(BossKits.BOSS_KITS["hexer"]["atkdown_turns"]))
	assert_eq(_count_events(b, "doom"), 1)


func test_doom_atk_down_is_deeper_in_phase_2() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")], [_hexer("h")], moves, true, _seeded_rng(8)
	)
	var h := b._combatant_by_id("h")
	h["phase"] = 2
	h["turns_until_big_hit"] = 0
	BossKits.on_turn(b, h)
	for pid in ["p1", "p2"]:
		assert_almost_eq(
			float(b._combatant_by_id(pid)["atk_multiplier"]),
			float(BossKits.BOSS_KITS["hexer"]["atkdown_mult_phase2"]),
			0.001
		)


func test_siphon_drains_8_percent_of_a_party_member_and_heals_the_boss() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_hexer("h")], moves, true, _seeded_rng(9))
	var h := b._combatant_by_id("h")
	var p := b._combatant_by_id("p")
	h["hp"] = int(h["max_hp"] * 0.5)
	var boss_before: int = h["hp"]
	var p_before: int = p["hp"]
	var frac := float(BossKits.BOSS_KITS["hexer"]["siphon_frac"])
	var expected_drain := int(round(float(p_before) * frac))
	h["_kit_turn"] = 2  # next kit-turn 3 -> Siphon
	h["turns_until_big_hit"] = 5  # keep it off the telegraph
	assert_true(BossKits.on_turn(b, h))
	assert_eq(int(p["hp"]), p_before - expected_drain)
	assert_eq(int(h["hp"]), boss_before + expected_drain)
	var siphoned := false
	for ev in b.log:
		if ev.get("type", "") == "siphon" and int(ev.get("amount", 0)) == expected_drain:
			siphoned = true
	assert_true(siphoned)


func test_withering_aura_atk_downs_the_target_on_an_even_non_telegraph_turn() -> void:
	var b := Battle.new([_ally("p", "WARRIOR")], [_hexer("h")], moves, true, _seeded_rng(10))
	var h := b._combatant_by_id("h")
	var p := b._combatant_by_id("p")
	h["_kit_turn"] = 1  # next kit-turn 2: even, not a telegraph, 2 % 3 != 0
	h["turns_until_big_hit"] = 5
	var p_before: int = p["hp"]
	assert_true(BossKits.on_turn(b, h))
	assert_lt(int(p["hp"]), p_before)
	assert_almost_eq(
		float(p["atk_multiplier"]), float(BossKits.BOSS_KITS["hexer"]["atkdown_mult"]), 0.001
	)
	assert_eq(int(p["atk_buff_turns"]), int(BossKits.BOSS_KITS["hexer"]["atkdown_turns"]))
	p["atk_multiplier"] = 1.0
	p["atk_buff_turns"] = 0
	h["_kit_turn"] = 4  # next kit-turn 5: odd, 5 % 3 != 0 -> plain basic, no fresh atk-down
	h["turns_until_big_hit"] = 5
	assert_true(BossKits.on_turn(b, h))
	assert_almost_eq(float(p["atk_multiplier"]), 1.0, 0.001)


func _broodmother(id: String) -> Dictionary:
	return Battle.make_enemy_combatant(
		id, 1200.0, true, "Boss", "Hollow Brood", true, "bruiser", "physical", "broodmother", true
	)


func test_make_enemy_combatant_stashes_base_power() -> void:
	assert_almost_eq(float(Battle.make_enemy_combatant("x", 1234.0)["base_power"]), 1234.0, 0.01)


func test_devour_telegraph_hits_lowest_hp_and_lifesteals_for_the_boss() -> void:
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")],
		[_broodmother("boss")],
		moves,
		true,
		_seeded_rng(3)
	)
	var bc := b._combatant_by_id("boss")
	var lo := b._combatant_by_id("p2")
	lo["hp"] = int(lo["max_hp"] * 0.6)  # lowest-HP, but survives a 2.0x Devour
	bc["hp"] = int(bc["max_hp"] * 0.5)  # room to lifesteal without capping at max
	var boss_before: int = bc["hp"]
	var lo_before: int = lo["hp"]
	var hi_before: int = b._combatant_by_id("p1")["hp"]
	bc["turns_until_big_hit"] = 0
	assert_true(BossKits.on_turn(b, bc))
	assert_lt(int(lo["hp"]), lo_before)  # Devour hit the lowest-HP member
	assert_eq(int(b._combatant_by_id("p1")["hp"]), hi_before)  # not the healthy one
	var dmg := lo_before - int(lo["hp"])
	var frac := float(BossKits.BOSS_KITS["broodmother"]["devour_heal_frac"])
	var expected_heal := int(round(float(dmg) * frac))
	assert_eq(int(bc["hp"]), boss_before + expected_heal)
	var logged := false
	for ev in b.log:
		if ev.get("type", "") == "devour_heal" and ev["actor_id"] == "boss":
			logged = true
			assert_eq(int(ev["amount"]), expected_heal)
	assert_true(logged)


func test_spawn_adds_a_brood_skirmisher_and_queues_it() -> void:
	var b := Battle.new(
		[_ally("p", "WARRIOR")], [_broodmother("boss")], moves, true, _seeded_rng(5)
	)
	var bc := b._combatant_by_id("boss")
	var add := b.spawn_add(bc)
	assert_false(add.is_empty())
	assert_eq(String(add["name"]), "Brood Spawn")
	assert_eq(String(add["role"]), "skirmisher")
	assert_false(bool(add["is_boss"]))
	assert_true(b.enemies.has(add))
	assert_true(b.turn_queue.has(add["id"]))
	assert_almost_eq(
		float(add["base_power"]),
		float(bc["base_power"]) * float(BossKits.BOSS_KITS["broodmother"]["spawn_power_frac"]),
		0.01
	)


func test_spawn_is_capped_at_two_living_adds() -> void:
	var b := Battle.new(
		[_ally("p", "WARRIOR")], [_broodmother("boss")], moves, true, _seeded_rng(6)
	)
	var bc := b._combatant_by_id("boss")
	assert_false(b.spawn_add(bc).is_empty())
	assert_false(b.spawn_add(bc).is_empty())
	assert_true(b.spawn_add(bc).is_empty(), "a 3rd add past the +2 cap is skipped")
	assert_eq(b.living_enemies().size(), 3)  # boss + 2 adds


func test_spawn_is_skipped_when_the_enemy_row_is_full() -> void:
	var row := [
		_broodmother("boss"),
		Battle.make_enemy_combatant("g1", 400.0),
		Battle.make_enemy_combatant("g2", 400.0),
		Battle.make_enemy_combatant("g3", 400.0),
	]
	var b := Battle.new([_ally("p", "WARRIOR")], row, moves, true, _seeded_rng(7))
	var bc := b._combatant_by_id("boss")
	assert_eq(b.living_enemies().size(), 4)
	assert_true(b.spawn_add(bc).is_empty())
	assert_eq(b.enemies.size(), 4)


func test_on_phase_fires_an_immediate_double_spawn() -> void:
	var b := Battle.new(
		[_ally("p", "WARRIOR")], [_broodmother("boss")], moves, true, _seeded_rng(8)
	)
	var bc := b._combatant_by_id("boss")
	BossKits.on_phase(b, bc)
	var adds := b.enemies.filter(
		func(e: Dictionary) -> bool: return String(e["id"]).find("_add_") != -1
	)
	assert_eq(adds.size(), 2)


func test_a_spawned_add_actually_gets_a_turn_when_the_battle_is_stepped() -> void:
	# A beefy boss so the party cannot end the fight before the add's first turn;
	# the Broodmother's own kit-turn 1 is a Spawn (not an attack), so nobody is hurt.
	var boss := Battle.make_enemy_combatant(
		"boss",
		9000.0,
		true,
		"Boss",
		"Hollow Brood",
		false,
		"bruiser",
		"physical",
		"broodmother",
		false
	)
	var b := Battle.new(
		[_ally("p1", "WARRIOR"), _ally("p2", "WARRIOR")], [boss], moves, true, _seeded_rng(9)
	)
	var add := b.spawn_add(b._combatant_by_id("boss"))
	assert_false(add.is_empty())
	assert_true(b.turn_queue.has(add["id"]))  # appended directly, not via _build_turn_queue
	var acted := false
	for _i in range(8):
		if b.is_over:
			break
		b.step()
		for ev in b.log:
			if ev.get("type", "") == "enemy_attack" and ev.get("actor_id", "") == add["id"]:
				acted = true
	assert_true(acted, "the freshly-appended add is popped off turn_queue and takes its turn")
