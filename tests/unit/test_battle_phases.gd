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
