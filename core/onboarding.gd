class_name Onboarding
## Phase 2/P10: "the first five minutes" (§25) -- value before permissions.
## A brand-new hunter gets a free starter shadow and a scripted,
## guaranteed-win first gate/CLAIM *before* GPS/Health permissions are
## ever requested (the section's "one real decision", recommended: value
## first). Pure -- picks monster ids and resolves the scripted fight;
## scenes/main.gd owns the actual permission-request timing and save
## writes.

const STARTER_GRADE := "E"


## The free starter shadow granted at hunter creation (§25 step 3, "a
## gentle first taste of the CLAIM fantasy... your first soldier").
## Prefers an E-rank monster whose class matches the chosen subclass (a
## small flavor touch -- fitting to start with "your own kind" -- not
## mechanically required); falls back to the first E-rank monster in
## content if none match. No specific species is named in the source.
static func starter_monster_id(subclass: String, monsters: Array) -> String:
	var e_rank := Content.monsters_by_rank(monsters, STARTER_GRADE)
	if e_rank.is_empty():
		return ""
	for m: Dictionary in e_rank:
		if String(m.get("clazz", "")) == subclass.to_upper():
			return String(m.get("id", ""))
	return String(e_rank[0].get("id", ""))


## The monster for the guided first gate (§25 step 4) -- deliberately a
## DIFFERENT E-rank monster than the starter shadow, so the first CLAIM
## feels like an actual kill, not a duplicate of what you were just
## handed for free.
static func guided_gate_monster_id(starter_id: String, monsters: Array) -> String:
	var e_rank := Content.monsters_by_rank(monsters, STARTER_GRADE)
	for m: Dictionary in e_rank:
		if String(m.get("id", "")) != starter_id:
			return String(m.get("id", ""))
	# Only one E-rank monster exists in content -- falls back to it. Never
	# happens with the real monsters.json (10 E-rank monsters), but content
	# could theoretically be trimmed to fewer.
	return starter_id


## The scripted first gate itself: "run the 3-round clash (win
## guaranteed), then the first CLAIM" -- no RNG, no chance of failure, by
## design (§25: "a big, can't-miss moment"). Shaped like GateEncounter's
## result dict (cleared/claimed) plus the monster's display name, but
## intentionally NOT routed through GateEncounter.run()/attempt_claim() --
## this one moment is scripted, not a real probabilistic encounter.
static func resolve_guided_gate(monster_id: String, monsters: Array) -> Dictionary:
	var monster := Content.monster_by_id(monsters, monster_id)
	return {
		"cleared": true,
		"claimed": true,
		"monster_id": monster_id,
		"monster_name": String(monster.get("name", "")),
	}
