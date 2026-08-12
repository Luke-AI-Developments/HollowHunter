class_name GateEncounter
## Phase 1 step 5: the gate fight itself. Pure -- composes GameLogic's
## existing primitives (resolve_clear, attempt_claim), doesn't invent new
## formulas. Optional RNG param for deterministic tests.
##
## Design call, since neither the user's spec nor game_logic.gd pin down
## exactly what "3-round auto clash" resolves to: three independent
## resolve_clear() rolls against the same power values, cleared on a
## best-of-3 (>=2 wins). Adds real round-to-round tension without
## fabricating any new math beyond sequencing the given formula.
##
## Target power: game_logic.gd's own gate_power() computes the HUNTER's
## attacking power, not an enemy difficulty value -- the design bible's
## rank-power table (E~150, D~400...) isn't in the source of truth code
## anywhere. Using each gate's real monster base_power as the target
## instead of inventing a parallel table.
##
## Phase 3/step 5 status update (§16 combat overhaul): gates no longer
## resolve through this class at all -- scenes/main.gd now launches a
## real core/battle.gd Battle instead. `resolve_rounds()` is still fully
## alive, just relocated: RankAssessment (§28 Rank-Up Trials) reuses it
## and was deliberately NOT migrated to real combat in this patch (out of
## scope for "wire it into the gate flow and Nadir floor flow", §16's own
## build order). `run()` -- the gate-specific clash+CLAIM wrapper -- is
## now genuinely dead code: nothing in the live game calls it anymore.
## Kept (not deleted) since it's still correct, still tested, and CLAIM's
## resolution logic (GameLogic.attempt_claim) is unchanged and still the
## real claim flow -- just no longer reached through this particular
## wrapper. Its GUT tests stay green because the code is still right, not
## because anything's exercising it live; flagged here rather than left
## silently green-but-irrelevant.

const ROUNDS := 3
const ROUNDS_NEEDED_TO_CLEAR := 2


static func resolve_rounds(
	total_power: float, target_power: float, rng: RandomNumberGenerator = null
) -> Dictionary:
	var round_results := []
	var wins := 0
	for i in ROUNDS:
		var won := GameLogic.resolve_clear(total_power, target_power, rng)
		round_results.append(won)
		if won:
			wins += 1
	return {"cleared": wins >= ROUNDS_NEEDED_TO_CLEAR, "rounds": round_results, "wins": wins}


## The full encounter: clash, then (only if cleared) the boss CLAIM
## (GameLogic.attempt_claim already does its own 3 tries internally).
## DEAD CODE as of the §16 combat overhaul -- see the class doc comment.
static func run(
	total_power: float, gate: Dictionary, hunter_level: int, rng: RandomNumberGenerator = null
) -> Dictionary:
	var clash := resolve_rounds(total_power, gate.get("monster_base_power", 0), rng)
	var claimed := false
	if clash["cleared"]:
		claimed = GameLogic.attempt_claim(
			gate.get("monster_extract_chance", 0.0), hunter_level, rng
		)
	return {"cleared": clash["cleared"], "rounds": clash["rounds"], "claimed": claimed}
