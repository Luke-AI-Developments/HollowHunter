class_name GateSpawner
## Placeholder gate spawning for the Phase 1 map: picks ranks near the
## hunter's current power and scatters them at small lat/lon offsets from a
## center point. Pure -- takes content + an (optional, for deterministic
## tests) RNG in, returns plain gate dicts out. No map/rendering here.
##
## Rank weighting is deliberately simple (current rank + one tier down) --
## the design bible discusses spawn weighting narratively but game_logic.gd
## (the source of truth) has no formula for it, so this doesn't invent one.

const RANKS := ["E", "D", "C", "B", "A", "S"]

## Roughly a ~300-400m scatter radius around the center point (1 degree of
## latitude/longitude is treated as ~111km, a flat-earth approximation --
## fine at this scale, wrong far from the equator or over long distances).
const MAX_OFFSET_DEGREES := 0.003


static func rank_pool_for_level(level: int) -> Array:
	var current := GameLogic.rank_for_level(level)
	var idx := RANKS.find(current)
	var pool := [current]
	if idx > 0:
		pool.append(RANKS[idx - 1])
	return pool


static func spawn_gates(
	center_lat: float,
	center_lon: float,
	hunter_level: int,
	monsters: Array,
	count: int = 5,
	rng: RandomNumberGenerator = null
) -> Array:
	var pool := rank_pool_for_level(hunter_level)
	var gates := []
	for i in count:
		var rank: String = pool[_rand_index(pool.size(), rng)]
		var candidates := Content.monsters_by_rank(monsters, rank)
		if candidates.is_empty():
			continue
		var monster: Dictionary = candidates[_rand_index(candidates.size(), rng)]
		(
			gates
			. append(
				{
					"rank": rank,
					"lat": center_lat + _rand_offset(rng),
					"lon": center_lon + _rand_offset(rng),
					"monster_id": monster.get("id", ""),
					"monster_name": monster.get("name", ""),
					"monster_base_power": monster.get("base_power", 0),
				}
			)
		)
	return gates


static func _rand_index(size: int, rng: RandomNumberGenerator) -> int:
	var f := rng.randf() if rng else randf()
	return min(int(f * size), size - 1)


static func _rand_offset(rng: RandomNumberGenerator) -> float:
	var f := rng.randf() if rng else randf()
	return (f - 0.5) * 2.0 * MAX_OFFSET_DEGREES
