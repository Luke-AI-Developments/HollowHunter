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
## invented weighting would compound guesses.
##
## Armor-set pieces (patch 3) join the pool too, matched by their SET's
## tier (D/B/S) to the gate's rank -- NOT by the piece's own `rarity`
## field. A D-tier set's pieces are RARE, which under RANK_TO_RARITY is a
## B-rank drop, not D -- but every SetDef carries its own explicit
## `source` ("Ashen March (D gates)" etc), and honoring that per-set source
## is a more faithful reading than routing everything through the generic
## rarity table. So the final pool per gate clear is the union of: regular
## (non-set) items at the rank's rarity, plus set pieces whose set's tier
## equals the gate rank -- both drawn from with equal weight (no weighting
## number is given for regular-vs-set either). C/A-rank gates have no
## matching set tier (only D/B/S sets exist) and so pull from the regular
## pool only, same as before this patch.

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
	var set_tier_by_id := {}
	for set_def: Dictionary in equipment.get("armor_sets", []):
		set_tier_by_id[set_def.get("id", "")] = set_def.get("tier", "")

	var pool: Array = []
	for item: Dictionary in equipment.get("base_equipment", []):
		var set_id: String = item.get("set_id", "")
		if set_id == "":
			if item.get("rarity", "") == rarity:
				pool.append(item)
		elif set_tier_by_id.get(set_id, "") == gate_rank:
			pool.append(item)

	if pool.is_empty():
		return {}
	var f := rng.randf() if rng else randf()
	var idx: int = min(int(f * pool.size()), pool.size() - 1)
	return pool[idx]
