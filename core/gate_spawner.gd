class_name GateSpawner
## Placeholder gate spawning for the Phase 1 map: picks ranks near the
## hunter's EARNED rank and scatters them at small lat/lon offsets from a
## center point. Pure -- takes content + an (optional, for deterministic
## tests) RNG in, returns plain gate dicts out. No map/rendering here.
##
## Phase 2/P6 correction: was originally keyed off the hunter's LEVEL
## (current rank-for-level + one tier down); §28 is explicit that "the map
## shows gates within ±1 of your rank... rank, not raw level, sets what
## content appears" -- rank here means the EARNED rank (HunterState.
## hunter_rank), not GameLogic.rank_for_level(level)'s assessment-eligible
## threshold. Now takes the earned rank directly and spans ±1 tier (both
## up AND down, per that exact wording, not just one tier down as before).
## Exact spawn WEIGHTING across that ±1 pool still isn't given anywhere,
## so it stays a flat/uniform pick, same as before this fix.

const RANKS := ["E", "D", "C", "B", "A", "S"]

## Roughly a ~300-400m scatter radius around the center point (1 degree of
## latitude/longitude is treated as ~111km, a flat-earth approximation --
## fine at this scale, wrong far from the equator or over long distances).
const MAX_OFFSET_DEGREES := 0.003


static func rank_pool_for_rank(earned_rank: String) -> Array:
	var idx := RANKS.find(earned_rank)
	if idx < 0:
		idx = 0
	var pool := [RANKS[idx]]
	if idx > 0:
		pool.append(RANKS[idx - 1])
	if idx < RANKS.size() - 1:
		pool.append(RANKS[idx + 1])
	return pool


static func spawn_gates(
	center_lat: float,
	center_lon: float,
	hunter_rank: String,
	monsters: Array,
	count: int = 5,
	rng: RandomNumberGenerator = null
) -> Array:
	var pool := rank_pool_for_rank(hunter_rank)
	var gates := []
	for i in count:
		var rank: String = pool[_rand_index(pool.size(), rng)]
		var candidates := Content.monsters_by_rank(monsters, rank)
		if candidates.is_empty():
			continue
		var monster: Dictionary = candidates[_rand_index(candidates.size(), rng)]
		var gate := {
			"rank": rank,
			"lat": center_lat + _rand_offset(rng),
			"lon": center_lon + _rand_offset(rng),
			"monster_id": monster.get("id", ""),
			"monster_name": monster.get("name", ""),
			"monster_base_power": monster.get("base_power", 0),
			"monster_extract_chance": monster.get("extract_chance", 0.0),
		}
		gates.append(gate)
	return gates


## Phase 2/P7 step 1: a single gate for a spent ticket (§8a "instantly open
## a gate at your current location -- no walking"), placed exactly at
## `lat`/`lon` (no scatter offset, unlike spawn_gates -- a ticket gate IS
## "where you are", not a nearby placeholder to walk to). Rolls a rank from
## the same ±1-of-earned-rank pool as normal map spawns ("the ticketed
## gate's rank scales around your level" -- rank pool already scales on the
## hunter's earned rank here, consistent with every other gate on the map).
## Returns {} if content has no monster anywhere in that pool (falls
## through the whole pool before giving up, unlike spawn_gates() which just
## skips one slot in a batch -- a ticket can't silently produce nothing).
static func spawn_ticket_gate(
	lat: float, lon: float, hunter_rank: String, monsters: Array, rng: RandomNumberGenerator = null
) -> Dictionary:
	var pool := rank_pool_for_rank(hunter_rank)
	var rolled: String = pool[_rand_index(pool.size(), rng)]
	var ordered_ranks := [rolled] + pool.filter(func(r: String) -> bool: return r != rolled)
	for rank: String in ordered_ranks:
		var candidates := Content.monsters_by_rank(monsters, rank)
		if candidates.is_empty():
			continue
		var monster: Dictionary = candidates[_rand_index(candidates.size(), rng)]
		return {
			"rank": rank,
			"lat": lat,
			"lon": lon,
			"monster_id": monster.get("id", ""),
			"monster_name": monster.get("name", ""),
			"monster_base_power": monster.get("base_power", 0),
			"monster_extract_chance": monster.get("extract_chance", 0.0),
		}
	return {}


## Phase 2/P9: gates for an active Incursion zone (§19) -- same rank pool
## as a normal spawn, but every rolled rank is bumped one tier higher
## ("a rank higher") and every monster is restricted to `family`
## ("all that family"). "Denser" isn't this function's concern -- that's
## just a bigger `count` from the caller, same knob as spawn_gates().
## Falls back to the family's own highest-rank monster if the bumped rank
## has no member of that family (several families are thin -- e.g.
## Tarlings/Gloamwing only span E-D, so a bumped-to-C roll would otherwise
## come up empty for them).
static func spawn_incursion_gates(
	center_lat: float,
	center_lon: float,
	hunter_rank: String,
	incursion_family: String,
	monsters: Array,
	count: int = 5,
	rng: RandomNumberGenerator = null
) -> Array:
	var pool := _bumped_rank_pool(hunter_rank)
	var family_monsters := Content.monsters_by_family(monsters, incursion_family)
	var gates := []
	for i in count:
		var rank: String = pool[_rand_index(pool.size(), rng)]
		var candidates := family_monsters.filter(
			func(m: Dictionary) -> bool: return m.get("rank", "") == rank
		)
		if candidates.is_empty():
			candidates = family_monsters
		if candidates.is_empty():
			continue
		var monster: Dictionary = candidates[_rand_index(candidates.size(), rng)]
		(
			gates
			. append(
				{
					"rank": String(monster.get("rank", rank)),
					"lat": center_lat + _rand_offset(rng),
					"lon": center_lon + _rand_offset(rng),
					"monster_id": monster.get("id", ""),
					"monster_name": monster.get("name", ""),
					"monster_base_power": monster.get("base_power", 0),
					"monster_extract_chance": monster.get("extract_chance", 0.0),
					"incursion_bonus": true,
				}
			)
		)
	return gates


static func _bumped_rank_pool(earned_rank: String) -> Array:
	var deduped := []
	for r: String in rank_pool_for_rank(earned_rank):
		var bumped := _bump_rank(r)
		if not deduped.has(bumped):
			deduped.append(bumped)
	return deduped


static func _bump_rank(rank: String) -> String:
	var idx := RANKS.find(rank)
	if idx < 0:
		return rank
	return RANKS[mini(idx + 1, RANKS.size() - 1)]


static func _rand_index(size: int, rng: RandomNumberGenerator) -> int:
	var f := rng.randf() if rng else randf()
	return min(int(f * size), size - 1)


static func _rand_offset(rng: RandomNumberGenerator) -> float:
	var f := rng.randf() if rng else randf()
	return (f - 0.5) * 2.0 * MAX_OFFSET_DEGREES
