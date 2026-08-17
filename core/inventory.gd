class_name Inventory
## §17b: pure browse/maintain logic for the hunter's equipment inventory --
## filtering, sorting, the equipped-by lookup, stat-delta compare, and
## bulk-scrap candidate selection. Kept separate from Equip (slot/class-
## gating mechanics) per this project's one-class-one-responsibility
## convention -- Equip answers "can this be worn"; this answers "how do I
## browse/bulk-manage a pile of these".

const RARITY_ORDER := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const SOFT_CAP := 200  ## invented v0 number, flagged -- no source figure given
## (§17b design decision #4); generous for a fresh save, reachable mid-game.


## Enriches each inventory item with its resolved (enhancement-scaled) def
## data, then applies `filters`. Filter keys (all optional -- omit or "ALL"
## means no filter on that dimension): class, slot, rarity, set_id,
## equipped ("EQUIPPED"/"UNEQUIPPED"). `hunter_equipped`/`army` are only
## needed to resolve the `equipped` filter -- pass {}/[] if not filtering
## on it. Preserves `inventory`'s own order (acquisition order).
static func filter_by(
	inventory: Array,
	equipment: Dictionary,
	hunter_equipped: Dictionary,
	army: Array,
	filters: Dictionary
) -> Array:
	var result := []
	for item: Dictionary in inventory:
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		var effective := Equip.enhanced_def(def, item.get("enhancement_level", 0))
		var enriched := {
			"instance_id": item.get("instance_id", ""),
			"equipment_def_id": item.get("equipment_def_id", ""),
			"enhancement_level": item.get("enhancement_level", 0),
			"locked": item.get("locked", false),
			"name": def.get("name", ""),
			"slot": def.get("slot", ""),
			"rarity": def.get("rarity", ""),
			"clazz": def.get("clazz", ""),
			"set_id": def.get("set_id", ""),
			"power_bonus": effective.get("power_bonus", 0),
			"stat_mods": effective.get("stat_mods", {}),
		}
		if filters.get("class", "ALL") != "ALL" and enriched["clazz"] != filters["class"]:
			continue
		if filters.get("slot", "ALL") != "ALL" and enriched["slot"] != filters["slot"]:
			continue
		if filters.get("rarity", "ALL") != "ALL" and enriched["rarity"] != filters["rarity"]:
			continue
		if filters.get("set_id", "ALL") != "ALL" and enriched["set_id"] != filters["set_id"]:
			continue
		var equipped_filter: String = filters.get("equipped", "ALL")
		if equipped_filter != "ALL":
			var is_worn: bool = (
				wearer_of(enriched["instance_id"], hunter_equipped, army)["kind"] != "none"
			)
			if equipped_filter == "EQUIPPED" and not is_worn:
				continue
			if equipped_filter == "UNEQUIPPED" and is_worn:
				continue
		result.append(enriched)
	return result


## `mode`: "power" (highest first), "rarity" (rarest first, RARITY_ORDER),
## "slot" (Equip.SLOTS order), "newest" (most-recently-acquired first --
## reverses the input, since filter_by already returns acquisition order).
static func sort_by(items: Array, mode: String) -> Array:
	var result := items.duplicate()
	match mode:
		"power":
			result.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return a["power_bonus"] > b["power_bonus"]
			)
		"rarity":
			result.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return RARITY_ORDER.find(b["rarity"]) < RARITY_ORDER.find(a["rarity"])
			)
		"slot":
			result.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return Equip.SLOTS.find(a["slot"]) < Equip.SLOTS.find(b["slot"])
			)
		"newest":
			result.reverse()
	return result


## Who currently wears `instance_id` -- {"kind": "none"|"hunter"|"shadow",
## "shadow_instance_id": ""}. Backs both the "equipped by <shadow>" label
## and the scrap guard (an item can't be scrapped while worn).
static func wearer_of(instance_id: String, hunter_equipped: Dictionary, army: Array) -> Dictionary:
	if hunter_equipped.values().has(instance_id):
		return {"kind": "hunter", "shadow_instance_id": ""}
	for shadow: Dictionary in army:
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		if shadow_equipped.values().has(instance_id):
			return {"kind": "shadow", "shadow_instance_id": shadow.get("instance_id", "")}
	return {"kind": "none", "shadow_instance_id": ""}


## Per-stat and power deltas between a candidate item and whatever's
## currently worn in the target slot -- the Compare feature's green/red
## arrows. Both dicts are the enhancement-scaled ("effective") shape
## filter_by's enrichment produces. `current` may be {} (empty slot),
## treated as all-zero.
static func compare_delta(candidate: Dictionary, current: Dictionary) -> Dictionary:
	var stat_delta := {}
	var candidate_stats: Dictionary = candidate.get("stat_mods", {})
	var current_stats: Dictionary = current.get("stat_mods", {})
	for stat in candidate_stats:
		stat_delta[stat] = int(candidate_stats[stat]) - int(current_stats.get(stat, 0))
	for stat in current_stats:
		if not stat_delta.has(stat):
			stat_delta[stat] = -int(current_stats[stat])
	var power_delta := int(candidate.get("power_bonus", 0)) - int(current.get("power_bonus", 0))
	return {"stat_delta": stat_delta, "power_delta": power_delta}


## Eligible-to-scrap instance_ids: rarity strictly below `threshold`,
## excluding locked/equipped items.
static func scrap_candidates_below_rarity(
	inventory: Array,
	equipment: Dictionary,
	threshold: String,
	hunter_equipped: Dictionary,
	army: Array
) -> Array:
	var threshold_idx := RARITY_ORDER.find(threshold)
	var result := []
	for item: Dictionary in inventory:
		if item.get("locked", false):
			continue
		if wearer_of(item.get("instance_id", ""), hunter_equipped, army)["kind"] != "none":
			continue
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		var rarity_idx := RARITY_ORDER.find(def.get("rarity", ""))
		if rarity_idx >= 0 and rarity_idx < threshold_idx:
			result.append(item["instance_id"])
	return result


## Every unequipped copy of a def_id owned more than once -- keeps none
## spare (§17b design decision #5: scraps ALL unequipped duplicates, even
## if one copy of that def_id is equipped and stays).
static func scrap_candidates_unequipped_duplicates(
	inventory: Array, hunter_equipped: Dictionary, army: Array
) -> Array:
	var counts := {}
	for item: Dictionary in inventory:
		var def_id: String = item.get("equipment_def_id", "")
		counts[def_id] = counts.get(def_id, 0) + 1
	var result := []
	for item: Dictionary in inventory:
		if item.get("locked", false):
			continue
		var def_id: String = item.get("equipment_def_id", "")
		if counts.get(def_id, 0) <= 1:
			continue
		if wearer_of(item.get("instance_id", ""), hunter_equipped, army)["kind"] != "none":
			continue
		result.append(item["instance_id"])
	return result


static func is_over_soft_cap(inventory: Array) -> bool:
	return inventory.size() >= SOFT_CAP
