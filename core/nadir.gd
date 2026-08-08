class_name Nadir
## Phase 2/P3 step 2: Nadir floor clear resolution (§20). Pure.
##
## A SINGLE clear-check per floor -- "auto-resolved per floor as a
## clear-check (§5 RNG) vs that floor's fixed, escalating power... No
## attrition -- a pure power gate" -- unlike gates' best-of-3
## (GateEncounter). Reuses GameLogic.floor_power/resolve_clear as-is, no
## new formula invented here. A loss doesn't move progress backward or
## forward -- the caller just doesn't call HunterState.clear_nadir_floor()
## on a loss, per §20's "floor stays; come back stronger".


static func attempt_floor(
	raid_power: float, floor_n: int, rng: RandomNumberGenerator = null
) -> Dictionary:
	var target := GameLogic.floor_power(floor_n)
	var cleared := GameLogic.resolve_clear(raid_power, float(target), rng)
	return {"cleared": cleared, "target_power": target}
