class_name Loot
## Phase 2 patch 1 step 1: equipment drops on a cleared gate. Pure -- gate
## rank + equipment content in, an EquipmentDef (or {} if that rarity has
## no items) out.
##
## Rarity is strictly rank-locked (§15's "Drops from" table), not weighted
## across multiple rarities per drop -- the design bible gives no weight
## numbers for a richer roll table, so this is the simple reading of "rarity
## weighted by gate rank": the gate's rank determines its one rarity tier.
## v0 also always drops on clear (no drop-chance roll) -- no rate is given
## in the source either, and inventing a percentage on top of an already
## invented weighting would compound guesses. Armor-set pieces are excluded
## (left for the followup patch, per the setup prompt).

const RANK_TO_RARITY := {
	"E": "COMMON",
	"D": "COMMON",
	"C": "UNCOMMON",
	"B": "RARE",
	"A": "EPIC",
	"S": "LEGENDARY",
}


static func roll_drop(
	gate_rank: String, equipment: Dictionary, rng: RandomNumberGenerator = null
) -> Dictionary:
	var rarity: String = RANK_TO_RARITY.get(gate_rank, "COMMON")
	var pool: Array = []
	for item: Dictionary in equipment.get("base_equipment", []):
		if item.get("rarity", "") == rarity and item.get("set_id", "") == "":
			pool.append(item)
	if pool.is_empty():
		return {}
	var f := rng.randf() if rng else randf()
	var idx: int = min(int(f * pool.size()), pool.size() - 1)
	return pool[idx]
