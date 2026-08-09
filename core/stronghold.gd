class_name Stronghold
## Phase 2/P4 steps 1-2: Stronghold idle production (§22). Pure.
##
## No rate numbers exist anywhere in the source -- everything is
## qualitative ("slowly", "modest", "a fraction of an active day of
## gate-clearing", "bigger/more facilities = more slots and higher rates").
## Every constant below is an invented v0 number, flagged as a group here
## rather than repeating the disclaimer on each one:
##  - OFFLINE_CAP_HOURS (10): picked from the source's own "~8-12h" range.
##  - slots_for_level(level) = level: 1 slot at level 1, +1 per level.
##  - BASE_RATE per facility: resource generated per assigned shadow per
##    hour at facility level 1 -- picked small enough that a full offline
##    cap of idle Reliquary output (10 shadows x 10h x rate x level 1)
##    stays well under a single E-rank gate's Essence (20, §26), matching
##    "idle output is modest... a fraction of an active day".
##  - Training Yard's "idle XP" (see apply_idle_xp) is a SEPARATE, free
##    leveling path from Equipment patch's paid ShadowLeveling -- §22
##    explicitly frames it as passive/automatic ("gain a trickle of idle
##    XP"), not another Essence sink. TRAINING_YARD_RATE is idle-XP
##    progress per shadow per hour; crossing 1.0 grants a level (still
##    capped at ShadowLeveling.LEVEL_CAP).
##  - Facility/Stronghold upgrade costs: same quadratic shape as every
##    other Essence sink in this project (Equip's enhancement, Shadow-
##    Leveling's level-up), own bases so the systems don't read as
##    directly interchangeable.
##  - army_capacity(): the source says Stronghold upgrades "raise army
##    roster capacity" but a capacity number/base never existed anywhere
##    before this patch (army is currently unbounded) -- BASE_ARMY_CAPACITY
##    picked comfortably above §17's SQUAD_SIZE (6) and well above what a
##    new player accumulates in the early game.

const OFFLINE_CAP_HOURS := 10.0

const RELIQUARY := "RELIQUARY"
const TRAINING_YARD := "TRAINING_YARD"
const GATE_WATCH := "GATE_WATCH"
const FACILITY_IDS := [RELIQUARY, TRAINING_YARD, GATE_WATCH]
const FACILITY_LEVEL_CAP := 5

const BASE_RATE := {
	RELIQUARY: 1.5,  # Essence per assigned shadow per hour, at facility level 1
	TRAINING_YARD: 0.01,  # idle-XP progress per assigned shadow per hour, at level 1
	GATE_WATCH: 0.02,  # gate tickets per assigned shadow per hour, at level 1
}

const FACILITY_UPGRADE_BASE_COST := 200
const STRONGHOLD_LEVEL_CAP := 5
const STRONGHOLD_UPGRADE_BASE_COST := 800
const BASE_ARMY_CAPACITY := 20
const ARMY_CAPACITY_PER_LEVEL := 5


static func slots_for_level(level: int) -> int:
	return level


static func idle_hours(elapsed_seconds: float) -> float:
	return min(elapsed_seconds / 3600.0, OFFLINE_CAP_HOURS)


## Resource accrued by one facility over `elapsed_seconds` (capped at
## OFFLINE_CAP_HOURS), given its level and how many shadows are assigned.
## Same formula for all three facilities -- what the number MEANS (Essence,
## idle-XP progress, gate tickets) depends on which facility_id it's for.
static func accrued(
	facility_id: String, elapsed_seconds: float, level: int, assigned_count: int
) -> float:
	var rate: float = BASE_RATE.get(facility_id, 0.0)
	return rate * level * assigned_count * idle_hours(elapsed_seconds)


## Applies accrued Training Yard idle-XP to one shadow's level progress.
## Crossing 1.0 grants a level (capped at ShadowLeveling.LEVEL_CAP);
## remainder carries over. Progress is discarded once capped -- nothing
## left to bank toward.
static func apply_idle_xp(
	current_level: int, current_progress: float, idle_xp: float
) -> Dictionary:
	var level := current_level
	var progress := current_progress + idle_xp
	var levels_gained := 0
	while progress >= 1.0 and level < ShadowLeveling.LEVEL_CAP:
		progress -= 1.0
		level += 1
		levels_gained += 1
	if level >= ShadowLeveling.LEVEL_CAP:
		progress = 0.0
	return {"level": level, "progress": progress, "levels_gained": levels_gained}


static func facility_upgrade_cost(target_level: int) -> int:
	return FACILITY_UPGRADE_BASE_COST * target_level * target_level


static func stronghold_upgrade_cost(target_level: int) -> int:
	return STRONGHOLD_UPGRADE_BASE_COST * target_level * target_level


static func army_capacity(stronghold_level: int) -> int:
	return BASE_ARMY_CAPACITY + (stronghold_level - 1) * ARMY_CAPACITY_PER_LEVEL
