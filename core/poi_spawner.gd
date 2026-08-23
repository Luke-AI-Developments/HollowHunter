class_name PoiSpawner
## Deterministic-by-area spawning for Sanctuary and Lore Stone map POIs
## (§19) -- sibling to core/gate_spawner.gd, but unlike gates (which reroll
## every session via an unseeded RNG) these are seeded from the area's own
## fixed grid-cell centroid, not the caller's raw lat/lon -- so every
## player physically anywhere inside the same cell computes the exact same
## positions. Matches "anchored to real notable places" (§19): these read
## as fixed real landmarks, not per-player scatter. Reuses
## Incursion.area_key()/AREA_CELL_DEGREES rather than a new cell-size
## constant, and GateSpawner.MAX_OFFSET_DEGREES for the same ~300-400m
## scatter radius gates already use.

const SANCTUARY_COUNT := 2
const LORESTONE_COUNT := 1

## Short placeholder in-fiction blurbs (§19: "reveal worldbuilding -- the
## Ascendancy, the families, the Nadir") -- explicitly not a real writing
## pass, see the design spec's "Explicitly out of scope" section. Picked
## round-robin by a stone's lore_index, not randomly.
const LORE_SNIPPETS := [
	(
		"The Ascendancy is not a system, not a god -- it is the pressure the world puts on "
		+ "those who refuse to stay ordinary."
	),
	(
		"Every family traces itself to a Gate that never closed. The families did not choose "
		+ "their colours; the colours chose them."
	),
	(
		"Before it was called the Nadir, it had no name at all -- because nothing had ever "
		+ "climbed far enough to need one."
	),
	"Extraction is not domestication. What kneels in the CLAIM light remembers exactly what it was.",
]


static func spawn_sanctuaries(
	center_lat: float, center_lon: float, count: int = SANCTUARY_COUNT
) -> Array:
	return _spawn_points(center_lat, center_lon, count, "sanctuary")


static func spawn_lorestones(
	center_lat: float, center_lon: float, count: int = LORESTONE_COUNT
) -> Array:
	var points := _spawn_points(center_lat, center_lon, count, "lorestone")
	for i in points.size():
		points[i]["lore_index"] = i % LORE_SNIPPETS.size()
	return points


static func _spawn_points(
	center_lat: float, center_lon: float, count: int, type_tag: String
) -> Array:
	var area := Incursion.area_key(center_lat, center_lon)
	var anchor := _area_anchor(center_lat, center_lon)  # Vector2(lon, lat)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [area, type_tag])
	var points: Array = []
	for i in count:
		var poi: Dictionary = {
			"id": "%s_%s_%d" % [area, type_tag, i],
			"lat": anchor.y + _rand_offset(rng),
			"lon": anchor.x + _rand_offset(rng),
		}
		points.append(poi)
	return points


## The fixed centre point of the area cell `lat`/`lon` falls in --
## reconstructed the same way Incursion.area_key() buckets, so two
## different players inside the same cell always compute the same anchor
## regardless of exactly where in the cell they each are. Vector2(lon,
## lat), matching this project's Mercator-coordinate convention.
static func _area_anchor(lat: float, lon: float) -> Vector2:
	var cell_lat: float = floor(lat / Incursion.AREA_CELL_DEGREES)
	var cell_lon: float = floor(lon / Incursion.AREA_CELL_DEGREES)
	return Vector2(
		(cell_lon + 0.5) * Incursion.AREA_CELL_DEGREES,
		(cell_lat + 0.5) * Incursion.AREA_CELL_DEGREES
	)


static func _rand_offset(rng: RandomNumberGenerator) -> float:
	return (rng.randf() - 0.5) * 2.0 * GateSpawner.MAX_OFFSET_DEGREES
