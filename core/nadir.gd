class_name Nadir
## Phase 2/P3 steps 2-3: Nadir floor clear resolution + reward sizing (§20).
## Pure.
##
## Clear check: a SINGLE clear-check per floor -- "auto-resolved per floor
## as a clear-check (§5 RNG) vs that floor's fixed, escalating power... No
## attrition -- a pure power gate" -- unlike gates' best-of-3
## (GateEncounter). Reuses GameLogic.floor_power/resolve_clear as-is, no
## new formula invented here. A loss doesn't move progress backward or
## forward -- the caller just doesn't call HunterState.clear_nadir_floor()
## on a loss, per §20's "floor stays; come back stronger".
##
## Rewards: §20 says a clear grants "loot (Essence, gear, EXP) scaling with
## depth" -- EXP dropped per an explicit user call: it directly contradicts
## §26's "hard line" that hunter EXP is exercise-only and can never be
## bought/granted, so only Essence + gear are implemented. Essence has no
## formula given beyond "scaling with depth" -- invented v0, flagged: half
## of that floor's own power requirement, so the reward scales exactly with
## how hard the floor was to reach.
const NADIR_ESSENCE_FRACTION := 0.5


static func attempt_floor(
	raid_power: float, floor_n: int, rng: RandomNumberGenerator = null
) -> Dictionary:
	var target := GameLogic.floor_power(floor_n)
	var cleared := GameLogic.resolve_clear(raid_power, float(target), rng)
	return {"cleared": cleared, "target_power": target}


static func essence_for_floor(floor_n: int) -> int:
	return int(round(GameLogic.floor_power(floor_n) * NADIR_ESSENCE_FRACTION))


## Gear: no per-floor rarity table exists in the source either. Rather than
## invent a parallel drop-pool system for the Nadir specifically, this maps
## floor depth onto the same E-S ranks Loot.roll_drop already understands
## (one rank every 10 floors, invented breakpoints) and reuses that pool
## as-is -- so Nadir gear drops are exactly as real/testable as gate drops,
## just gated by depth instead of gate rank.
static func rank_for_floor(floor_n: int) -> String:
	if floor_n >= 50:
		return "S"
	if floor_n >= 40:
		return "A"
	if floor_n >= 30:
		return "B"
	if floor_n >= 20:
		return "C"
	if floor_n >= 10:
		return "D"
	return "E"
