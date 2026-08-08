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
