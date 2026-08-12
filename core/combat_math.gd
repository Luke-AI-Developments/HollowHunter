class_name CombatMath
## Phase 3: combat stat derivation + damage resolution for the active
## party battle system (§16 combat overhaul). Pure -- turns a hunter's or
## shadow's existing STR/AGI/VIT/END/SEN stats (from GameLogic.stats_from
## or shadow gear-merged stats, both already shipped/tested) into real
## combat stats, and resolves a single hit's damage. All formulas are the
## source's own v0 numbers (§16), not invented here -- see the doc's
## worked Lv1/Lv40 Warrior example, reproduced exactly by
## combat_stats(GameLogic.stats_from(level, "WARRIOR")) (verified in
## tests below).
##
## RNG-touching functions take an optional RandomNumberGenerator, same
## determinism convention as every other pure RNG function in this
## project (GateEncounter, Nadir, RankAssessment, etc.).

const CRIT_CHANCE_BASE := 0.05  # §16: "5% + AGI×0.05%"
const CRIT_CHANCE_PER_AGI := 0.0005  # 0.05% per AGI point
const CRIT_CHANCE_CAP := 0.35  # §16: "min(35%, ...)"
const CRIT_MULTIPLIER := 1.5

const DAMAGE_VARIANCE_MIN := 0.9
const DAMAGE_VARIANCE_MAX := 1.1

const ENEMY_HP_SCALE := 0.6  # §16: enemy_HP = base_power × 0.6
const ENEMY_ATK_SCALE := 0.15  # §16: enemy_ATK = base_power × 0.15
const ENEMY_SPEED_SCALE := 0.02  # invented v0, real gap: §16 never gives enemies a
## speed stat at all (SPEED=AGI is only defined for the player/shadows) -- but the turn
## queue needs everyone ordered, so this derives one from base_power the same way HP/ATK
## are derived, landing enemy speed in roughly the same range as player/shadow AGI-speed.


static func hp_from_stats(stats: Dictionary) -> int:
	return int(round(50.0 + float(stats.get("VIT", 0)) * 4.0 + float(stats.get("END", 0)) * 2.0))


static func patk_from_stats(stats: Dictionary) -> int:
	return int(round(5.0 + float(stats.get("STR", 0)) * 1.5))


static func matk_from_stats(stats: Dictionary) -> int:
	return int(round(5.0 + float(stats.get("SEN", 0)) * 1.5))


static func def_from_stats(stats: Dictionary) -> float:
	return float(stats.get("END", 0)) * 0.5 + float(stats.get("VIT", 0)) * 0.2


static func crit_chance_from_stats(stats: Dictionary) -> float:
	var chance := CRIT_CHANCE_BASE + float(stats.get("AGI", 0)) * CRIT_CHANCE_PER_AGI
	return minf(chance, CRIT_CHANCE_CAP)


static func speed_from_stats(stats: Dictionary) -> int:
	return int(stats.get("AGI", 0))


## All combat stats derived from a raw STR/AGI/VIT/END/SEN dict (from
## GameLogic.stats_from() or a shadow's gear-merged effective stats) in
## one call -- the shape a combatant needs to enter battle.
static func combat_stats(stats: Dictionary) -> Dictionary:
	return {
		"HP": hp_from_stats(stats),
		"PATK": patk_from_stats(stats),
		"MATK": matk_from_stats(stats),
		"DEF": def_from_stats(stats),
		"CRIT_CHANCE": crit_chance_from_stats(stats),
		"SPEED": speed_from_stats(stats),
	}


## Enemy combat stats derived straight from a monster's/floor's already-
## tuned base_power (§16: "nothing gets re-authored, it's just
## reinterpreted"). Enemies don't crit or split PATK/MATK in this v0 --
## the source only defines a flat HP/ATK pair for them (SPEED is also
## derived here, out of necessity -- see ENEMY_SPEED_SCALE above).
static func enemy_stats(base_power: float) -> Dictionary:
	return {
		"HP": int(round(base_power * ENEMY_HP_SCALE)),
		"ATK": int(round(base_power * ENEMY_ATK_SCALE)),
		"SPEED": int(round(base_power * ENEMY_SPEED_SCALE)),
	}


## A single hit's damage: `max(1, move_power × atk − target_def) ×
## variance(0.9-1.1) × (1.5 if crit)` (§16). `atk` is whichever of the
## attacker's PATK/MATK the move uses -- picking between them is the
## caller's job (move data decides physical vs. magic), not this
## function's. Returns both the damage and whether it crit, since the
## caller needs to know for the floating-number/toast display (§16b).
static func resolve_damage(
	move_power: float,
	atk: float,
	target_def: float,
	crit_chance: float,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var variance := _randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX, rng)
	var crit_roll := rng.randf() if rng else randf()
	var is_crit := crit_roll < crit_chance
	var base := move_power * atk - target_def
	var multiplier := CRIT_MULTIPLIER if is_crit else 1.0
	var damage := maxf(1.0, base) * variance * multiplier
	return {"damage": int(round(damage)), "crit": is_crit}


static func _randf_range(lo: float, hi: float, rng: RandomNumberGenerator) -> float:
	var f := rng.randf() if rng else randf()
	return lo + f * (hi - lo)
