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
