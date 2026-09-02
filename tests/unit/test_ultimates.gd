extends GutTest
## core/ultimates.gd -- the 5 Hunter Ultimate resolvers (spec §6.3).

var moves: Array


func before_all() -> void:
	moves = Content.load_moves()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _hunter(clazz: String) -> Dictionary:
	return Battle.make_ally_combatant(
		"player", clazz, 20, {"STR": 300, "AGI": 150, "VIT": 300, "END": 80, "SEN": 300}
	)


func _shadow(id: String, clazz: String) -> Dictionary:
	return Battle.make_ally_combatant(
		id, clazz, 15, {"STR": 200, "AGI": 100, "VIT": 200, "END": 50, "SEN": 100}
	)


func test_for_subclass_names() -> void:
	assert_eq(Ultimates.for_subclass("WARRIOR"), "Monarch's Wrath")
	assert_eq(Ultimates.for_subclass("GUARDIAN"), "Aegis Dominion")
	assert_eq(Ultimates.for_subclass("ASSASSIN"), "Thousand Cuts")
	assert_eq(Ultimates.for_subclass("MAGE"), "Nova Cataclysm")
	assert_eq(Ultimates.for_subclass("SUPPORT"), "Sovereign's Grace")
	assert_eq(Ultimates.for_subclass("bogus"), "")


func test_warriors_wrath_hits_every_enemy_for_a_lot() -> void:
	var party := [_hunter("WARRIOR")]
	# base_power scaled up from the brief's draft so a single Ultimate hit does
	# not one-shot / fully-Break these against real CombatMath numbers (hunter
	# PATK ~= 455 from STR 300); the Ultimate magnitudes stay exactly per spec.
	var enemies := [
		Battle.make_enemy_combatant("a", 12000.0, false),
		Battle.make_enemy_combatant("b", 12000.0, true, "Boss"),
	]
	var b := Battle.new(party, enemies, moves, true, _rng(1))
	var hp_a_before: int = b._combatant_by_id("a")["hp"]
	var hp_b_before: int = b._combatant_by_id("b")["hp"]
	Ultimates.resolve(b, "WARRIOR")
	assert_lt(b._combatant_by_id("a")["hp"], hp_a_before)
	assert_lt(b._combatant_by_id("b")["hp"], hp_b_before)
	# boss break bar took the telegraph-rate contribution
	assert_gt(float(b._combatant_by_id("b")["break_current"]), 0.0)


func test_guardian_aegis_grants_party_invuln_and_defbuff_and_taunts() -> void:
	var party := [_hunter("GUARDIAN"), _shadow("s1", "MAGE")]
	var enemies := [
		Battle.make_enemy_combatant("big", 900.0, false),
		Battle.make_enemy_combatant("small", 300.0, false)
	]
	var b := Battle.new(party, enemies, moves, true, _rng(2))
	Ultimates.resolve(b, "GUARDIAN")
	for c in b.party:
		assert_eq(int(c["statuses"].get("invuln", 0)), 1)
		assert_almost_eq(float(c["def_multiplier"]), 1.4, 0.001)
		assert_eq(int(c["def_mod_turns"]), 3)
	assert_true(b._combatant_by_id("player")["is_taunting"])
	# hit the highest-MAX-HP enemy ("big")
	assert_lt(b._combatant_by_id("big")["hp"], b._combatant_by_id("big")["max_hp"])
	assert_eq(b._combatant_by_id("small")["hp"], b._combatant_by_id("small")["max_hp"])


func test_assassin_thousand_cuts_is_six_hits_and_applies_vulnerable() -> void:
	var party := [_hunter("ASSASSIN")]
	# base_power scaled up from the brief's draft: at real CombatMath numbers a
	# 1200-power boss dies after ~2 auto-crit cuts; a big bag of HP lets all 6
	# land so the hit-count + Vulnerable-cap assertions mean something.
	var enemies := [Battle.make_enemy_combatant("lone", 20000.0, true, "Boss")]
	var b := Battle.new(party, enemies, moves, true, _rng(3))
	Ultimates.resolve(b, "ASSASSIN")
	var hits := 0
	for ev in b.log:
		if ev.get("type", "") == "damage" and ev.get("ultimate", false):
			hits += 1
			assert_true(ev["crit"])  # every cut auto-crits
	assert_eq(hits, 6)
	assert_eq(int(b._combatant_by_id("lone")["statuses"].get("vulnerable", 0)), 2)  # capped at 2


func test_mage_nova_cataclysm_stuns_grunts_and_broken_bosses() -> void:
	var party := [_hunter("MAGE")]
	# base_power scaled up from the brief's draft so Nova's damage (NOVA_POWER
	# 3.2 x hunter MATK ~= 455) neither kills the grunt nor empties/Breaks the
	# boss bar -- the test is about the post-Nova stun, not the damage.
	var enemies := [
		Battle.make_enemy_combatant("grunt", 12000.0, false),
		Battle.make_enemy_combatant("boss", 20000.0, true, "Boss"),
	]
	var b := Battle.new(party, enemies, moves, true, _rng(4))
	b._combatant_by_id("boss")["broken_turns"] = 2  # broken -> eligible for the 1t stun
	Ultimates.resolve(b, "MAGE")
	assert_eq(int(b._combatant_by_id("grunt")["statuses"].get("stun", 0)), 1)
	assert_eq(int(b._combatant_by_id("boss")["statuses"].get("stun", 0)), 1)


func test_mage_nova_does_not_stun_an_unbroken_boss() -> void:
	var party := [_hunter("MAGE")]
	# Large base_power: the point is Nova's hit (NOVA_POWER 3.2 x MATK ~455,
	# then x0.5 standard break-fill) must stay well under break_max so the boss
	# does NOT Break -> no Break-induced stun. break_count/broken_turns asserted
	# too so the intent is unambiguous even if a seed drifts.
	var enemies := [Battle.make_enemy_combatant("boss", 30000.0, true, "Boss")]
	var b := Battle.new(party, enemies, moves, true, _rng(4))
	Ultimates.resolve(b, "MAGE")
	assert_eq(int(b._combatant_by_id("boss")["statuses"].get("stun", 0)), 0)
	assert_eq(int(b._combatant_by_id("boss")["break_count"]), 0)
	assert_eq(int(b._combatant_by_id("boss")["broken_turns"]), 0)


func test_grace_does_not_re_queue_a_combatant_that_already_acted() -> void:
	# Slow SUPPORT hunter (AGI 5) so a fast enemy (SPEED 120) acts before it
	# this round; C1 -- Grace must NOT rebuild the turn queue mid-round, which
	# would hand the already-acted enemy a second turn.
	var hunter := Battle.make_ally_combatant(
		"player", "SUPPORT", 20, {"STR": 200, "AGI": 5, "VIT": 400, "END": 200, "SEN": 200}
	)
	var party := [hunter, _shadow("s1", "WARRIOR")]
	var enemies := [Battle.make_enemy_combatant("fast", 6000.0, false)]
	var b := Battle.new(party, enemies, moves, true, _rng(9))
	b.step()  # the fast enemy acts and is popped off turn_queue
	assert_false(b.turn_queue.has("fast"), "fast enemy should have acted and left the queue")
	b._combatant_by_id("s1")["hp"] = 0  # KO the shadow before Grace
	Ultimates.resolve(b, "SUPPORT")
	assert_false(b.turn_queue.has("fast"), "Grace must not re-queue a combatant that already acted")
	var revived: Dictionary = b._combatant_by_id("s1")
	assert_gt(int(revived["hp"]), 0)  # revived
	assert_almost_eq(float(revived["hp"]) / float(revived["max_hp"]), 0.6, 0.05)


func test_support_sovereigns_grace_revives_heals_and_overdrives() -> void:
	var party := [_hunter("SUPPORT"), _shadow("dead", "WARRIOR"), _shadow("hurt", "MAGE")]
	var enemies := [Battle.make_enemy_combatant("e", 500.0, false)]
	var b := Battle.new(party, enemies, moves, true, _rng(5))
	b._combatant_by_id("dead")["hp"] = 0
	b._combatant_by_id("hurt")["hp"] = 1
	Ultimates.resolve(b, "SUPPORT")
	var revived: Dictionary = b._combatant_by_id("dead")
	assert_almost_eq(float(revived["hp"]) / float(revived["max_hp"]), 0.6, 0.02)
	assert_eq(b._combatant_by_id("hurt")["hp"], b._combatant_by_id("hurt")["max_hp"])  # full-healed
	for c in b.party:
		assert_eq(int(c["statuses"].get("overdrive", 0)), 2)
