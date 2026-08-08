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


## Phase 2 patch 1 step 3: sums an equipped loadout's power_bonus and merges
## its stat_mods (§16 wiring). `equipped`: slot->instance_id, `inventory`:
## the owner's Array of {instance_id, equipment_def_id, enhancement_level}
## (hunter and shadows share the one inventory pool), `equipment`: loaded
## equipment.json. Unknown/missing instance ids are skipped rather than
## erroring, so a stale equipped slot can't crash power calc. Enhancement
## isn't factored in yet (step 5) -- always reads the base, unenhanced def.
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
		power_bonus += def.get("power_bonus", 0)
		for stat in def.get("stat_mods", {}):
			stat_mods[stat] = stat_mods.get(stat, 0) + def["stat_mods"][stat]
	return {"power_bonus": power_bonus, "stat_mods": stat_mods}


static func _item_by_instance(inventory: Array, instance_id: String) -> Dictionary:
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


## Phase 2 patch 1 step 4: the highest power_bonus owned item for `slot`
## that `wearer_class` can equip and whose instance_id isn't in
## `taken_ids` -- "" if nothing qualifies. Pure; used for both a single-slot
## "Equip Best" action and auto-equip-all. Ties keep the first one found
## (inventory order) -- no tiebreak rule is given in the source.
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
		var power: int = def.get("power_bonus", 0)
		if power > best_power:
			best_power = power
			best_id = instance_id
	return best_id
