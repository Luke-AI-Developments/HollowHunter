class_name Equip
## Phase 2 patch 1 step 2: the 7 gear slots + class-gating (§15). Pure --
## dict/string in, dict/bool out, no HunterState dependency, so slot and
## gating rules are testable in isolation from inventory/army bookkeeping.
##
## Real content data locks EVERY slot (including ACCESSORY) to one class via
## a single `clazz` field on each item -- there's no `allowed_classes` array
## like the design doc's prose implies, and zero AURA items exist at all.
## That contradicts §15's "Accessory + Aura are universal" line, so gating
## here follows the shipped data instead: item.clazz must exactly equal the
## wearer's class, for every slot, no exceptions. AURA stays a valid slot
## key (for the future paper-doll) with nothing to put in it yet.

const SLOTS := ["WEAPON", "HEAD", "BODY", "HANDS", "FEET", "ACCESSORY", "AURA"]

# --- Phase 2 patch 1 step 5: enhancement (§15/§26) ---
# The source gives neither a stat-scaling-per-level formula nor an Essence
# cost curve -- "+1...+10, raising its stats" and "escalating Essence costs,
# steep enough to keep you a little resource-hungry" are qualitative only.
# This is an invented v0 curve, flagged for future tuning:
#  - each level adds ENHANCE_PCT_PER_LEVEL of the BASE power_bonus/stat_mods,
#    linearly (not compounding) -- so a +10 piece is 2x its base numbers.
#  - Essence cost to reach level N is ENHANCE_BASE_ESSENCE_COST * N^2 --
#    quadratic, so it escalates the further a piece is pushed, roughly
#    tracking §26's own E->S gate-Essence spread (20 to 1500): early levels
#    are affordable off E/D-gate income, +10 needs real B/A/S-gate grinding.
const MAX_ENHANCEMENT := 10
const ENHANCE_PCT_PER_LEVEL := 0.10
const ENHANCE_BASE_ESSENCE_COST := 50


## Essence cost to enhance a piece TO `target_level` (1..MAX_ENHANCEMENT)
## from target_level - 1.
static func enhancement_cost(target_level: int) -> int:
	return ENHANCE_BASE_ESSENCE_COST * target_level * target_level


## Returns `def` with power_bonus/stat_mods scaled for `enhancement_level`
## (0 = unenhanced, returned unchanged). Doesn't mutate `def`.
static func enhanced_def(def: Dictionary, enhancement_level: int) -> Dictionary:
	if enhancement_level <= 0:
		return def
	var mult := 1.0 + ENHANCE_PCT_PER_LEVEL * enhancement_level
	var result := def.duplicate(true)
	result["power_bonus"] = int(round(def.get("power_bonus", 0) * mult))
	var stat_mods: Dictionary = def.get("stat_mods", {})
	var enhanced_stats := {}
	for stat in stat_mods:
		enhanced_stats[stat] = int(round(stat_mods[stat] * mult))
	result["stat_mods"] = enhanced_stats
	return result


static func can_equip(item_def: Dictionary, wearer_class: String) -> bool:
	return item_def.get("clazz", "") == wearer_class


## Returns a NEW equipped dict (slot -> inventory instance_id) with the item
## placed in its slot, replacing whatever was there -- doesn't mutate
## `equipped`. No-op (returns `equipped` unchanged) if the class doesn't match.
static func equip(
	equipped: Dictionary, item_def: Dictionary, instance_id: String, wearer_class: String
) -> Dictionary:
	if not can_equip(item_def, wearer_class):
		return equipped
	var result := equipped.duplicate()
	result[item_def.get("slot", "")] = instance_id
	return result


## Returns a NEW equipped dict with the given slot cleared.
static func unequip(equipped: Dictionary, slot: String) -> Dictionary:
	var result := equipped.duplicate()
	result.erase(slot)
	return result


## Sums an equipped loadout's power_bonus and merges its stat_mods (§16
## wiring), scaled by each item's enhancement_level (§15/§26 step 5).
## `equipped`: slot->instance_id, `inventory`: the owner's Array of
## {instance_id, equipment_def_id, enhancement_level} (hunter and shadows
## share the one inventory pool), `equipment`: loaded equipment.json.
## Unknown/missing instance ids are skipped rather than erroring, so a
## stale equipped slot can't crash power calc.
static func gear_bonus(equipped: Dictionary, inventory: Array, equipment: Dictionary) -> Dictionary:
	var power_bonus := 0
	var stat_mods := {}
	for instance_id in equipped.values():
		var item := _item_by_instance(inventory, instance_id)
		if item.is_empty():
			continue
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		def = enhanced_def(def, item.get("enhancement_level", 0))
		power_bonus += def.get("power_bonus", 0)
		for stat in def.get("stat_mods", {}):
			stat_mods[stat] = stat_mods.get(stat, 0) + def["stat_mods"][stat]
	return {"power_bonus": power_bonus, "stat_mods": stat_mods}


static func _item_by_instance(inventory: Array, instance_id: String) -> Dictionary:
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


## The highest EFFECTIVE (enhancement-scaled) power_bonus owned item for
## `slot` that `wearer_class` can equip and whose instance_id isn't in
## `taken_ids` -- "" if nothing qualifies. Pure; used for both a single-slot
## "Equip Best" action and auto-equip-all. Ranking by effective power means
## a heavily-enhanced weaker base item can rightly beat an unenhanced
## stronger one. Ties keep the first one found (inventory order) -- no
## tiebreak rule is given in the source.
static func best_candidate(
	slot: String, wearer_class: String, inventory: Array, equipment: Dictionary, taken_ids: Array
) -> String:
	var best_id := ""
	var best_power := -1
	for item: Dictionary in inventory:
		var instance_id: String = item.get("instance_id", "")
		if taken_ids.has(instance_id):
			continue
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty() or def.get("slot", "") != slot or not can_equip(def, wearer_class):
			continue
		var effective := enhanced_def(def, item.get("enhancement_level", 0))
		var power: int = effective.get("power_bonus", 0)
		if power > best_power:
			best_power = power
			best_id = instance_id
	return best_id
