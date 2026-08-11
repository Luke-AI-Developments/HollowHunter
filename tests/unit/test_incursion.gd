extends GutTest
## Incursion: deterministic area+week zone generation (§19). See
## core/incursion.gd for why the cell size/cadence/odds/multiplier numbers
## are invented, and why real map tiles/Sanctuaries/Lore Stones aren't here.

var families: Array


func before_all() -> void:
	families = Content.monster_families(Content.load_monsters())


func test_area_key_is_stable_for_nearby_jitter() -> void:
	var a := Incursion.area_key(51.5074, -0.1278)
	var b := Incursion.area_key(51.5076, -0.1279)  # a few meters away
	assert_eq(a, b)


func test_area_key_differs_for_a_genuinely_different_area() -> void:
	var london := Incursion.area_key(51.5074, -0.1278)
	var paris := Incursion.area_key(48.8566, 2.3522)
	assert_ne(london, paris)


func test_week_number_is_stable_within_the_same_week() -> void:
	var base := 1_700_000_000
	assert_eq(Incursion.week_number(base), Incursion.week_number(base + 3600))


func test_week_number_advances_a_full_week_later() -> void:
	var base := 1_700_000_000
	assert_eq(Incursion.week_number(base) + 1, Incursion.week_number(base + Incursion.WEEK_SECONDS))


func test_active_family_is_deterministic_for_the_same_area_and_week() -> void:
	var a := Incursion.active_family("1,2", 100, families)
	var b := Incursion.active_family("1,2", 100, families)
	assert_eq(a, b)


func test_active_family_only_ever_returns_a_real_family_or_empty() -> void:
	for w in range(0, 30):
		var f := Incursion.active_family("5,-3", w, families)
		assert_true(f == "" or families.has(f))


func test_active_family_varies_across_different_areas() -> void:
	var results := {}
	for i in range(0, 40):
		results[Incursion.active_family(str(i) + ",0", 1, families)] = true
	# With 8 families and a 1-in-3 chance each, 40 different areas should
	# not all land on the exact same result (either all "" or all one family).
	assert_true(results.size() > 1)


func test_active_family_with_no_families_is_always_empty() -> void:
	assert_eq(Incursion.active_family("0,0", 1, []), "")


func test_bonus_essence_scales_above_the_base_amount() -> void:
	assert_true(Incursion.bonus_essence(100) > 100)


func test_bonus_essence_is_the_documented_multiplier() -> void:
	assert_eq(Incursion.bonus_essence(200), int(round(200 * Incursion.ESSENCE_MULTIPLIER)))
