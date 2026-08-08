class_name ShadowLeveling
## Phase 2/P2 steps 2-3: shadow leveling + duplicate fuse (§6/§17/§26). Pure.
##
## The source gives no numeric Essence-cost curve for shadow leveling
## ("spend Essence to level 1->cap") nor a size for a duplicate fuse's "big
## level chunk" -- both are qualitative only ("escalating... steep enough
## to keep you a little resource-hungry", "a big level chunk"). Invented v0
## curve, flagged:
##  - level_up_cost(target_level) = 100 * N^2 -- same quadratic shape as
##    Equip's gear-enhancement cost, its own base so the two Essence sinks
##    don't accidentally read as directly comparable 1:1.
##  - fusing a duplicate grants FUSE_LEVEL_CHUNK (3) levels at once, for
##    FUSE_DISCOUNT (70%) of what buying those same levels individually
##    would cost. The discount is what makes spending a duplicate (which
##    could otherwise be mass-converted for its own Essence, §26) worth
##    more than just saving the Essence yourself.

const LEVEL_CAP := 10
const LEVEL_UP_BASE_ESSENCE_COST := 100
const FUSE_LEVEL_CHUNK := 3
const FUSE_DISCOUNT := 0.7


## Essence cost to level a shadow up TO `target_level` (1..LEVEL_CAP) from
## target_level - 1.
static func level_up_cost(target_level: int) -> int:
	return LEVEL_UP_BASE_ESSENCE_COST * target_level * target_level


## The level a fuse lands on, starting from `current_level` -- capped at
## LEVEL_CAP (a fuse that would overshoot just tops out, doesn't waste the
## excess or refuse to fuse).
static func fuse_result_level(current_level: int) -> int:
	return min(current_level + FUSE_LEVEL_CHUNK, LEVEL_CAP)


## Essence cost to fuse a duplicate into a shadow currently at
## `current_level` -- FUSE_DISCOUNT of what buying the same levels
## individually (via level_up_cost) would cost.
static func fuse_cost(current_level: int) -> int:
	var total := 0
	var target := fuse_result_level(current_level)
	for lvl in range(current_level + 1, target + 1):
		total += level_up_cost(lvl)
	return int(round(total * FUSE_DISCOUNT))
