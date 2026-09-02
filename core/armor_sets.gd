class_name ArmorSets
## Phase 2 patch 3: 2pc/4pc armor-SET bonuses (§15). Pure.
##
## §15's bonus_2pc strings are clean "STAT+N[, STAT+N]" text -- parsed and
## applied as real stat bonuses. bonus_4pc strings mix a "+N% power" (or
## "+N% melee/spell power") modifier with free-form proc text ("frost
## shield absorbs one hit", "spells chain to a second target", "+20% max
## HP", etc) in ONE string -- there's no status/proc/HP engine to run those
## on (combat is pure summed power, §30), and parsing the prose beyond the
## power number would mean inventing mechanics the source never specifies.
## So: the "N% power" token in bonus_4pc (when present) is extracted and
## applied mechanically; everything else in both bonus strings is kept
## verbatim for display only, with zero further mechanical effect. Some
## sets' 4pc bonus has no %power token at all (e.g. "block chance up;
## shadows behind take less damage") -- those contribute 0 power, 0 stats.

const PIECES_FOR_2PC := 2
const PIECES_FOR_4PC := 4

## Matches "12% power", "15% melee power", "20% spell power" -- but NOT
## "20% max HP" or "10% crit", which use the same "N%" shape for an
## unrelated (unimplemented) stat.
const _POWER_PCT_PATTERN := "(\\d+)%\\s+(?:melee\\s+|spell\\s+)?power\\b"


## Counts equipped pieces per set_id (set_id -> count). `equipped`:
## slot->instance_id, `inventory`: owner's item Array, `equipment`: loaded
## equipment.json.
static func equipped_set_counts(
	equipped: Dictionary, inventory: Array, equipment: Dictionary
) -> Dictionary:
	var counts := {}
	for instance_id in equipped.values():
		var item := _item_by_instance(inventory, instance_id)
		if item.is_empty():
			continue
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		var set_id: String = def.get("set_id", "")
		if set_id == "":
			continue
		counts[set_id] = counts.get(set_id, 0) + 1
	return counts


## §17b: owned piece count per set_id across the WHOLE inventory (not just
## equipped) -- feeds the Inventory screen's Sets tab "3/4" readout.
## Sibling to equipped_set_counts(), same counting logic, a different
## source array (every owned copy counts, worn or not).
static func owned_set_counts(inventory: Array, equipment: Dictionary) -> Dictionary:
	var counts := {}
	for item: Dictionary in inventory:
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		var set_id: String = def.get("set_id", "")
		if set_id == "":
			continue
		counts[set_id] = counts.get(set_id, 0) + 1
	return counts


## Parses a clean "STAT+N[, STAT+N...]" bonus string into {STAT: N, ...}.
## Returns {} for anything that doesn't match that exact shape (e.g.
## bonus_4pc's prose) -- not an error, just "no stat bonus here".
static func parse_stat_bonus(text: String) -> Dictionary:
	var result := {}
	var regex := RegEx.new()
	regex.compile("^([A-Z]+)\\+(\\d+)$")
	for part in text.split(","):
		var m := regex.search(part.strip_edges())
		if m:
			result[m.get_string(1)] = int(m.get_string(2))
	return result


## Extracts the "N% power" token from a bonus string, as a fraction
## (e.g. "+10% power" -> 0.10). 0.0 if no such token is present.
static func parse_power_pct_bonus(text: String) -> float:
	var regex := RegEx.new()
	regex.compile(_POWER_PCT_PATTERN)
	var m := regex.search(text)
	if m:
		return float(m.get_string(1)) / 100.0
	return 0.0


## One entry per set with >=2 equipped pieces: which thresholds are active
## and both bonus strings verbatim (for display -- see class doc for what
## of that text is actually mechanical vs flavor-only).
static func active_set_bonuses(
	equipped: Dictionary, inventory: Array, equipment: Dictionary
) -> Array:
	var counts := equipped_set_counts(equipped, inventory, equipment)
	var armor_sets: Array = equipment.get("armor_sets", [])
	var result := []
	for set_def: Dictionary in armor_sets:
		var count: int = counts.get(set_def.get("id", ""), 0)
		if count < PIECES_FOR_2PC:
			continue
		(
			result
			. append(
				{
					"set_id": set_def.get("id", ""),
					"name": set_def.get("name", ""),
					"pieces_equipped": count,
					"active_2pc": count >= PIECES_FOR_2PC,
					"active_4pc": count >= PIECES_FOR_4PC,
					"bonus_2pc_text": set_def.get("bonus_2pc", ""),
					"bonus_4pc_text": set_def.get("bonus_4pc", ""),
				}
			)
		)
	return result


## Total mechanical bonus across every active set: merged stat_mods (from
## active bonus_2pc text) and a combined power_pct multiplier (summed from
## active bonus_4pc "N% power" tokens, additively -- no stacking rule is
## given in the source, additive is the simplest reading).
static func total_set_bonus(
	equipped: Dictionary, inventory: Array, equipment: Dictionary
) -> Dictionary:
	var stat_mods := {}
	var power_pct := 0.0
	for active: Dictionary in active_set_bonuses(equipped, inventory, equipment):
		if active["active_2pc"]:
			var stat_bonus := parse_stat_bonus(active["bonus_2pc_text"])
			for stat in stat_bonus:
				stat_mods[stat] = stat_mods.get(stat, 0) + stat_bonus[stat]
		if active["active_4pc"]:
			power_pct += parse_power_pct_bonus(active["bonus_4pc_text"])
	return {"stat_mods": stat_mods, "power_pct": power_pct}


## Spec §10.3: the STRUCTURED combat effects from every active armour set --
## `combat_4pc` at >= PIECES_FOR_4PC pieces, `combat_2pc` at >= PIECES_FOR_2PC.
## Each entry is a copy of the set's `{effect, ...}` object. Order follows the
## `armor_sets` array (deterministic). Distinct from `total_set_bonus`, which
## parses the free-form `bonus_2pc`/`bonus_4pc` TEXT for stat_mods / % power.
static func combat_effects(equipped: Dictionary, inventory: Array, equipment: Dictionary) -> Array:
	var counts := equipped_set_counts(equipped, inventory, equipment)
	var out := []
	for set_def: Dictionary in equipment.get("armor_sets", []):
		var count: int = counts.get(set_def.get("id", ""), 0)
		if count >= PIECES_FOR_2PC and set_def.has("combat_2pc"):
			out.append((set_def["combat_2pc"] as Dictionary).duplicate())
		if count >= PIECES_FOR_4PC and set_def.has("combat_4pc"):
			out.append((set_def["combat_4pc"] as Dictionary).duplicate())
	return out


static func _item_by_instance(inventory: Array, instance_id: String) -> Dictionary:
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}
