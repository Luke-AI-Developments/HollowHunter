extends GutTest
## PoiSpawner: deterministic-by-area Sanctuary/Lore Stone spawning (§19).
## Unlike GateSpawner (per-session RNG), every player physically standing
## anywhere inside the same area cell must compute IDENTICAL positions --
## these are shared world POIs, not per-player scatter.


func test_spawn_sanctuaries_returns_requested_count() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549, 3)
	assert_eq(sanctuaries.size(), 3)


func test_spawn_sanctuaries_default_count_is_two() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	assert_eq(sanctuaries.size(), 2)


func test_spawn_lorestones_default_count_is_one() -> void:
	var lorestones := PoiSpawner.spawn_lorestones(54.5235, -1.5549)
	assert_eq(lorestones.size(), 1)


func test_spawn_sanctuaries_identical_for_two_players_in_the_same_cell() -> void:
	# Both points fall in the same ~5.5km area cell (Incursion.AREA_CELL_DEGREES
	# = 0.05) but are not the same point -- simulates two different players
	# standing in different spots within one area.
	var a := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	var b := PoiSpawner.spawn_sanctuaries(54.5210, -1.5520)
	assert_eq(a, b)


func test_spawn_lorestones_identical_for_two_players_in_the_same_cell() -> void:
	var a := PoiSpawner.spawn_lorestones(54.5235, -1.5549)
	var b := PoiSpawner.spawn_lorestones(54.5210, -1.5520)
	assert_eq(a, b)


func test_spawn_sanctuaries_differ_across_distant_cells() -> void:
	var here := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549)
	var far_away := PoiSpawner.spawn_sanctuaries(51.5074, -0.1278)  # London
	assert_ne(here[0]["id"], far_away[0]["id"])


func test_spawn_sanctuaries_ids_are_unique_within_a_call() -> void:
	var sanctuaries := PoiSpawner.spawn_sanctuaries(54.5235, -1.5549, 5)
	var seen := {}
	for s: Dictionary in sanctuaries:
		seen[s["id"]] = true
	assert_eq(seen.size(), sanctuaries.size())


func test_spawn_sanctuaries_offsets_stay_within_gate_spawner_bound() -> void:
	# Offsets are measured from the CELL's own anchor (its fixed centroid),
	# not from the raw input point -- the input can be anywhere within the
	# cell, up to half a cell-width from that centroid, so bounding against
	# the raw input directly would fail even for a correct implementation.
	var lat := 54.5235
	var lon := -1.5549
	var cell_lat: float = floor(lat / Incursion.AREA_CELL_DEGREES)
	var cell_lon: float = floor(lon / Incursion.AREA_CELL_DEGREES)
	var anchor_lat := (cell_lat + 0.5) * Incursion.AREA_CELL_DEGREES
	var anchor_lon := (cell_lon + 0.5) * Incursion.AREA_CELL_DEGREES

	var sanctuaries := PoiSpawner.spawn_sanctuaries(lat, lon, 10)
	for s: Dictionary in sanctuaries:
		assert_lt(absf(s["lat"] - anchor_lat), GateSpawner.MAX_OFFSET_DEGREES * 1.5)
		assert_lt(absf(s["lon"] - anchor_lon), GateSpawner.MAX_OFFSET_DEGREES * 1.5)


func test_spawn_lorestones_assigns_lore_index_within_snippet_bounds() -> void:
	var lorestones := PoiSpawner.spawn_lorestones(54.5235, -1.5549, 4)
	for ls: Dictionary in lorestones:
		assert_gte(ls["lore_index"], 0)
		assert_lt(ls["lore_index"], PoiSpawner.LORE_SNIPPETS.size())


func test_lore_snippets_has_at_least_four_entries() -> void:
	assert_gte(PoiSpawner.LORE_SNIPPETS.size(), 4)


func test_spawn_lorestones_lore_index_varies_across_distant_cells() -> void:
	# Guards against the shipped count=1 bug where lore_index was derived from
	# the index WITHIN one call's array (always 0 at count=1) instead of from
	# something that actually varies between different Lore Stones.
	var here := PoiSpawner.spawn_lorestones(54.5235, -1.5549)
	var far_away := PoiSpawner.spawn_lorestones(-33.8688, 151.2093)  # Sydney
	assert_ne(here[0]["lore_index"], far_away[0]["lore_index"])
