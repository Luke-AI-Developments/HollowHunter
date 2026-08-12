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
## Phase 3/step 5 status update (§16/§20 combat overhaul): floor clearing
## no longer runs through attempt_floor()'s resolve_clear() check --
## scenes/main.gd now launches a real core/battle.gd Battle per floor
## (enemy stats derived from floor_power via CombatMath.enemy_stats, same
## formula gates use for monster base_power). attempt_floor() itself is
## now dead code -- nothing in the live game calls it -- kept (not
## deleted) since it's still correct and still tested, same treatment as
## GateEncounter.run(). is_boss_floor(), boss_monster_id(),
## essence_for_floor(), and rank_for_floor() are all still fully alive:
## main.gd calls them directly to build the floor's enemy, apply rewards,
## and run the post-win CLAIM roll (via GameLogic.attempt_claim, same
## pattern the gate flow already uses -- see scenes/main.gd).
##
## Rewards: §20 says a clear grants "loot (Essence, gear, EXP) scaling with
## depth" -- EXP dropped per an explicit user call: it directly contradicts
## §26's "hard line" that hunter EXP is exercise-only and can never be
## bought/granted, so only Essence + gear are implemented. Essence has no
## formula given beyond "scaling with depth" -- invented v0, flagged: half
## of that floor's own power requirement, so the reward scales exactly with
## how hard the floor was to reach.
##
## Boss floors: "at milestones" with no interval given -- BOSS_FLOOR_INTERVAL
## (10) is invented, chosen to land exactly where rank_for_floor's own tier
## boundaries do, so a boss floor is always where the loot pool steps up a
## rank too ("reward spike" lining up with "harder tier"). The source names
## no boss monster for the Nadir at all (unlike gates, which roll a real
## monster per encounter) -- boss_monster_id() stands in with the strongest
## owned-rank monster from content, and its CLAIM roll reuses that
## monster's own real extract_chance rather than inventing a separate
## Nadir-boss number.
const NADIR_ESSENCE_FRACTION := 0.5
const BOSS_FLOOR_INTERVAL := 10


static func is_boss_floor(floor_n: int) -> bool:
	return floor_n > 0 and floor_n % BOSS_FLOOR_INTERVAL == 0


## The strongest (highest base_power) monster of `floor_n`'s rank tier --
## "" if content has no monster of that rank at all.
static func boss_monster_id(floor_n: int, monsters: Array) -> String:
	var candidates := Content.monsters_by_rank(monsters, rank_for_floor(floor_n))
	var best_id := ""
	var best_power := -1
	for m: Dictionary in candidates:
		var power: int = m.get("base_power", 0)
		if power > best_power:
			best_power = power
			best_id = m.get("id", "")
	return best_id


## Resolves a floor attempt: the clear-check, plus (only if cleared and
## it's a boss floor) a CLAIM attempt on that floor's stand-in boss.
## DEAD CODE as of the §16/§20 combat overhaul -- see the class doc comment.
static func attempt_floor(
	raid_power: float,
	floor_n: int,
	hunter_level: int,
	monsters: Array,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var target := GameLogic.floor_power(floor_n)
	var cleared := GameLogic.resolve_clear(raid_power, float(target), rng)
	var is_boss := is_boss_floor(floor_n)
	var claimed := false
	var boss_id := ""
	if cleared and is_boss:
		boss_id = boss_monster_id(floor_n, monsters)
		if boss_id != "":
			var monster := Content.monster_by_id(monsters, boss_id)
			claimed = GameLogic.attempt_claim(monster.get("extract_chance", 0.0), hunter_level, rng)
	return {
		"cleared": cleared,
		"target_power": target,
		"is_boss": is_boss,
		"claimed": claimed,
		"boss_monster_id": boss_id,
	}


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
