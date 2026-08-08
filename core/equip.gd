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
