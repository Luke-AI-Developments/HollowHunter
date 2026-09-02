class_name Content
## Loads static game content (monsters, equipment) from res://content/*.json
## into plain Dictionaries/Arrays. Pure and side-effect free except for the
## file read itself -- no engine/scene dependency, unit-testable with GUT.
## (load_traits() additionally memoises the default-path result -- see there.)

static var _traits_cache: Array = []  ## load_traits() memo for the default path only


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


## The attack type ("physical"/"magic") a monster's combatant should use
## (spec §2.3 -- decides party-DEF pierce). Honours an explicit `atk_type`
## on the monster def; otherwise MAGE/SUPPORT classes default to "magic"
## and everything else to "physical". Shared by _start_gate_battle and
## _start_nadir_battle so the default rule lives in one place.
static func monster_atk_type(mdef: Dictionary) -> String:
	var explicit := String(mdef.get("atk_type", ""))
	if explicit != "":
		return explicit
	return "magic" if String(mdef.get("clazz", "")) in ["MAGE", "SUPPORT"] else "physical"


## The boss-kit id for a monster (spec §3.4): an explicit `kit` on the def
## wins; else the family default; else "" (no kit -- plain boss). Only
## meaningful for a boss.
static func monster_kit(mdef: Dictionary) -> String:
	var explicit := String(mdef.get("kit", ""))
	if explicit != "":
		return explicit
	return String(BossKits.FAMILY_KIT.get(String(mdef.get("family", "")), ""))


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


## The item shop's catalog (§14/§26, content/shop.json): {ticket_bundles,
## essence_bundles, cosmetics}, each an Array of Dictionaries. See that
## file's own _comment for what's the source's own text (what Crystals
## buy) vs. invented v0 (every crystal_cost number).
static func load_shop(path: String = "res://content/shop.json") -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		return {"ticket_bundles": [], "essence_bundles": [], "cosmetics": []}
	return data


## §6b shadow traits pool (content/traits.json). §6b traits pool -- see
## that file's _comment. Memoised for the default path (see _traits_cache):
## claim_shadow() rolls traits per shadow and DebugGrant.grant_all fires 50+
## claims in one frame, so re-reading + re-parsing the file each time is pure
## startup waste. The data is immutable at runtime; a non-default `path`
## bypasses the cache.
static func load_traits(path: String = "res://content/traits.json") -> Array:
	var is_default := path == "res://content/traits.json"
	if is_default and not _traits_cache.is_empty():
		return _traits_cache
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null or not data.has("traits"):
		return []
	if is_default:
		_traits_cache = data["traits"]
	return data["traits"]


## Looks up one entry by id within a single shop catalog section (e.g.
## `shop["cosmetics"]`) -- same {} -not-found convention as monster_by_id/
## move_by_id/equipment_by_id.
static func shop_item_by_id(section: Array, id: String) -> Dictionary:
	for item: Dictionary in section:
		if item.get("id") == id:
			return item
	return {}
