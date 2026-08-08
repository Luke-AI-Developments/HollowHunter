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


static func equipment_by_id(equipment: Dictionary, id: String) -> Dictionary:
	for e: Dictionary in equipment.get("base_equipment", []):
		if e.get("id") == id:
			return e
	return {}
