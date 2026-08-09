extends GutTest
## Stronghold: idle production math + upgrade costs (§22). See
## core/stronghold.gd for why every number here is an invented v0 pick.


func test_slots_for_level_equals_level() -> void:
	assert_eq(Stronghold.slots_for_level(1), 1)
	assert_eq(Stronghold.slots_for_level(3), 3)


func test_idle_hours_converts_seconds() -> void:
	assert_almost_eq(Stronghold.idle_hours(3600.0), 1.0, 0.0001)
	assert_almost_eq(Stronghold.idle_hours(7200.0), 2.0, 0.0001)


func test_idle_hours_caps_at_offline_cap() -> void:
	var far_future := Stronghold.OFFLINE_CAP_HOURS * 3600.0 * 10.0
	assert_eq(Stronghold.idle_hours(far_future), Stronghold.OFFLINE_CAP_HOURS)


func test_accrued_scales_with_level_and_assigned_count() -> void:
	var one_shadow := Stronghold.accrued(Stronghold.RELIQUARY, 3600.0, 1, 1)
	var two_shadows := Stronghold.accrued(Stronghold.RELIQUARY, 3600.0, 1, 2)
	assert_almost_eq(two_shadows, one_shadow * 2.0, 0.0001)

	var higher_level := Stronghold.accrued(Stronghold.RELIQUARY, 3600.0, 2, 1)
	assert_almost_eq(higher_level, one_shadow * 2.0, 0.0001)


func test_accrued_with_no_assigned_shadows_is_zero() -> void:
	assert_eq(Stronghold.accrued(Stronghold.RELIQUARY, 3600.0, 3, 0), 0.0)


func test_accrued_unknown_facility_is_zero() -> void:
	assert_eq(Stronghold.accrued("NOT_A_FACILITY", 3600.0, 1, 1), 0.0)


func test_apply_idle_xp_below_1_only_accumulates_progress() -> void:
	var result := Stronghold.apply_idle_xp(1, 0.2, 0.3)
	assert_eq(result["level"], 1)
	assert_almost_eq(result["progress"], 0.5, 0.0001)
	assert_eq(result["levels_gained"], 0)


func test_apply_idle_xp_crossing_1_grants_a_level_and_keeps_remainder() -> void:
	var result := Stronghold.apply_idle_xp(1, 0.8, 0.5)
	assert_eq(result["level"], 2)
	assert_almost_eq(result["progress"], 0.3, 0.0001)
	assert_eq(result["levels_gained"], 1)


func test_apply_idle_xp_can_grant_multiple_levels_at_once() -> void:
	var result := Stronghold.apply_idle_xp(1, 0.0, 2.5)
	assert_eq(result["level"], 3)
	assert_almost_eq(result["progress"], 0.5, 0.0001)
	assert_eq(result["levels_gained"], 2)


func test_apply_idle_xp_stops_at_level_cap() -> void:
	# 100.0 idle-XP is way more than enough to blow past the cap
	var result := Stronghold.apply_idle_xp(ShadowLeveling.LEVEL_CAP - 1, 0.0, 100.0)
	assert_eq(result["level"], ShadowLeveling.LEVEL_CAP)
	assert_eq(result["progress"], 0.0)
	assert_eq(result["levels_gained"], 1)


func test_facility_upgrade_cost_escalates() -> void:
	assert_true(Stronghold.facility_upgrade_cost(2) > Stronghold.facility_upgrade_cost(1))


func test_stronghold_upgrade_cost_escalates() -> void:
	assert_true(Stronghold.stronghold_upgrade_cost(2) > Stronghold.stronghold_upgrade_cost(1))


func test_army_capacity_at_level_1_is_the_base() -> void:
	assert_eq(Stronghold.army_capacity(1), Stronghold.BASE_ARMY_CAPACITY)


func test_army_capacity_rises_with_stronghold_level() -> void:
	assert_true(Stronghold.army_capacity(3) > Stronghold.army_capacity(1))
