class_name Content
## Loads static game content (monsters, equipment) from res://content/*.json
## into plain Dictionaries/Arrays. Pure and side-effect free except for the
## file read itself -- no engine/scene dependency, unit-testable with GUT.


static func load_monsters(path: String = "res://content/monsters.json") -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null or not data.has("monsters"):
		return []
	return data["monsters"]


static func load_equipment(path: String = "res://content/equipment.json") -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		return {"base_equipment": [], "armor_sets": []}
	return data


static func monster_by_id(monsters: Array, id: String) -> Dictionary:
	for m: Dictionary in monsters:
		if m.get("id") == id:
			return m
	return {}


static func monsters_by_rank(monsters: Array, rank: String) -> Array:
	return monsters.filter(func(m: Dictionary) -> bool: return m.get("rank") == rank)


## Phase 2/P9: distinct family names across all monsters, in first-seen
## order -- Incursion.active_family() picks from this list.
static func monster_families(monsters: Array) -> Array:
	var seen := {}
	var families := []
	for m: Dictionary in monsters:
		var family: String = m.get("family", "")
		if family != "" and not seen.has(family):
			seen[family] = true
			families.append(family)
	return families


static func monsters_by_family(monsters: Array, family: String) -> Array:
	return monsters.filter(func(m: Dictionary) -> bool: return m.get("family", "") == family)


static func equipment_by_id(equipment: Dictionary, id: String) -> Dictionary:
	for e: Dictionary in equipment.get("base_equipment", []):
		if e.get("id") == id:
			return e
	return {}


## Phase 3/step 2: the 5 class movesets for the active combat system
## (§16 combat overhaul, content/moves.json). See that file's _comment
## for what's the source's own text (names/unlock levels/flavor) vs.
## invented v0 (power/cooldown/tag numbers).
static func load_moves(path: String = "res://content/moves.json") -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null or not data.has("moves"):
		return []
	return data["moves"]


static func move_by_id(moves: Array, id: String) -> Dictionary:
	for m: Dictionary in moves:
		if m.get("id") == id:
			return m
	return {}


static func moves_by_class(moves: Array, clazz: String) -> Array:
	return moves.filter(func(m: Dictionary) -> bool: return m.get("class", "") == clazz.to_upper())


## The moves of `clazz` unlocked by `level`, sorted lowest unlock_level
## first (a stable, predictable order for the action bar, §16b, and for
## shadow AI to scan in a consistent priority-adjacent order).
static func unlocked_moves(moves: Array, clazz: String, level: int) -> Array:
	var result := moves_by_class(moves, clazz).filter(
		func(m: Dictionary) -> bool: return int(m.get("unlock_level", 1)) <= level
	)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("unlock_level", 1)) < int(b.get("unlock_level", 1))
	)
	return result
