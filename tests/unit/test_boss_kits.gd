extends GutTest
## core/boss_kits.gd -- the six boss archetype kits (spec §4).


func test_every_family_maps_to_a_known_kit() -> void:
	for fam in BossKits.FAMILY_KIT:
		assert_true(String(BossKits.FAMILY_KIT[fam]) in BossKits.KIT_IDS, "%s -> unknown kit" % fam)


func test_boss_kits_table_has_an_entry_per_kit() -> void:
	for kit_id in BossKits.KIT_IDS:
		assert_true(BossKits.BOSS_KITS.has(kit_id), "no BOSS_KITS entry for %s" % kit_id)
		assert_true(int(BossKits.BOSS_KITS[kit_id].get("telegraph_interval", 0)) >= 1)


func test_colossus_has_the_slow_telegraph_cadence() -> void:
	assert_eq(int(BossKits.BOSS_KITS["colossus"]["telegraph_interval"]), 4)
	assert_eq(int(BossKits.BOSS_KITS["colossus"]["phase2_telegraph_interval"]), 3)


func test_rising_fury_mult_ramps_and_caps() -> void:
	var boss := {"kit": "berserker", "phase": 1}
	assert_almost_eq(BossKits.rising_fury_mult(boss, 1), 1.0, 0.0001)
	assert_almost_eq(BossKits.rising_fury_mult(boss, 6), 1.20, 0.0001)
	assert_almost_eq(BossKits.rising_fury_mult(boss, 100), 1.6, 0.0001)


func test_rising_fury_mult_phase2_cap_and_non_berserker() -> void:
	assert_almost_eq(BossKits.rising_fury_mult({"kit": "berserker", "phase": 2}, 100), 2.0, 0.0001)
	assert_almost_eq(BossKits.rising_fury_mult({"kit": "colossus", "phase": 1}, 100), 1.0, 0.0001)
	assert_almost_eq(BossKits.rising_fury_mult({"kit": "", "phase": 1}, 50), 1.0, 0.0001)
