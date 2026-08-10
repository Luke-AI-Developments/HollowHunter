class_name RankAssessment
## Phase 2/P6: Rank-Up Assessments (§28). Pure.
##
## Trial resolution: "a short gauntlet ending in a Trial Boss" reads closer
## to gates' multi-round clash than the Nadir's single power-check, so this
## reuses GateEncounter.resolve_rounds() (best-of-3 via
## GameLogic.resolve_clear) rather than inventing a new resolution shape.
## Not claimable -- explicit in the source ("the Trial Boss is not
## claimable, it's a trial, not a wild monster").
##
## Trial Boss: the source tunes it "above a normal gate of that rank
## (≈×1.2 power)" but names no boss monster for it (gates roll a real
## monster from the gate's own data; Trials don't). trial_boss_id() stands
## in with the strongest owned monster of the target rank from content --
## same convention as Nadir's boss_monster_id -- and its base_power ×1.2
## (TRIAL_POWER_MULTIPLIER, the source's own number) is the target power.
##
## First-clear reward: "a one-off milestone reward (Essence / a signature
## cosmetic)" with no number given -- invented v0, flagged: flat Essence
## scaled by the target rank's position on the ladder, so S-rank's reward
## dwarfs D-rank's.

const TRIAL_POWER_MULTIPLIER := 1.2
const REWARD_PER_RANK_TIER := 500


## The next rank the hunter is eligible to attempt, given their level and
## current EARNED rank -- "" if none (level hasn't unlocked anything past
## the earned rank yet, or already at S). Only ever one rank above
## earned_rank -- you can't skip a Trial even if level has raced ahead.
static func next_assessment_rank(level: int, earned_rank: String) -> String:
	var unlocked := GameLogic.rank_for_level(level)
	var earned_idx := GameLogic.RANK_ORDER.find(earned_rank)
	var unlocked_idx := GameLogic.RANK_ORDER.find(unlocked)
	if earned_idx < 0 or unlocked_idx <= earned_idx:
		return ""
	return GameLogic.RANK_ORDER[earned_idx + 1]


## The strongest (highest base_power) monster of `target_rank` -- "" if
## content has no monster of that rank.
static func trial_boss_id(target_rank: String, monsters: Array) -> String:
	var best_id := ""
	var best_power := -1
	for m: Dictionary in Content.monsters_by_rank(monsters, target_rank):
		var power: int = m.get("base_power", 0)
		if power > best_power:
			best_power = power
			best_id = m.get("id", "")
	return best_id


static func trial_target_power(target_rank: String, monsters: Array) -> int:
	var boss := Content.monster_by_id(monsters, trial_boss_id(target_rank, monsters))
	return int(round(boss.get("base_power", 0) * TRIAL_POWER_MULTIPLIER))


static func essence_reward(target_rank: String) -> int:
	var idx := GameLogic.RANK_ORDER.find(target_rank)
	return REWARD_PER_RANK_TIER * maxi(idx, 1)


## Resolves an attempt at `target_rank`'s Trial: best-of-3 vs the Trial
## Boss's tuned power. No CLAIM -- Trial Bosses aren't claimable.
static func attempt(
	gate_power: float, target_rank: String, monsters: Array, rng: RandomNumberGenerator = null
) -> Dictionary:
	var target := trial_target_power(target_rank, monsters)
	var clash := GateEncounter.resolve_rounds(gate_power, float(target), rng)
	return {
		"cleared": clash["cleared"],
		"rounds": clash["rounds"],
		"target_power": target,
		"boss_monster_id": trial_boss_id(target_rank, monsters),
	}
