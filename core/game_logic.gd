class_name GameLogic
## Pure, engine-independent game logic for Shadow Hunter.
## Every function is static and side-effect free — unit-testable with GUT,
## no scene/device needed. Numbers are v0 from the design bible
## (§3/§4/§5/§16/§18/§20/§26/§28/§29/§30) — all tunable knobs.

# --- Core constants (§16) ---
const STAT_WEIGHT := 5
const LEVEL_WEIGHT := 20
const SHADOW_BASE_SCALE := 0.5
const SHADOW_LEVEL_SCALE := 0.05
const MONARCH_SCALE := 0.01
const SQUAD_SIZE := 6
const GATE_ARMY_WEIGHT := 0.25  # squad counts 25% at gates — level dominates
const RAID_ARMY_WEIGHT := 1.0  # full army counts in the Nadir raid
const CLAIM_TRIES := 3
const CLAIM_LEVEL_BONUS := 0.01
const CLAIM_CAP := 0.90
const STAT_POINTS_PER_LEVEL := 25
const CLASS_EXP_MULT := 1.5
const CLEAR_K := 3  # swinginess of the clear check

# --- §4/§27 wellbeing guardrails: invented v0 numbers -- the source calls
# for "a daily EXP soft-cap / diminishing returns so marathoners don't
# break the curve" and a "rest-day bonus" but gives no numbers for
# either. ---
const DAILY_EXP_SOFT_CAP := 600  # full rate up to here (~a solid matched workout day)
const DAILY_EXP_TAPER_RATE := 0.3  # EXP above the cap counts at 30% instead of 100%
const REST_BONUS_MULT := 1.15  # +15% on a day that follows a genuine gap in banked EXP

# --- Class stat profiles (§16): share of stat points per class ---
const CLASS_PROFILES := {
	"WARRIOR": {"STR": 0.40, "AGI": 0.10, "VIT": 0.25, "END": 0.15, "SEN": 0.10},
	"GUARDIAN": {"STR": 0.20, "AGI": 0.05, "VIT": 0.35, "END": 0.30, "SEN": 0.10},
	"ASSASSIN": {"STR": 0.25, "AGI": 0.40, "VIT": 0.15, "END": 0.10, "SEN": 0.10},
	"MAGE": {"STR": 0.15, "AGI": 0.15, "VIT": 0.15, "END": 0.10, "SEN": 0.45},
	"SUPPORT": {"STR": 0.20, "AGI": 0.10, "VIT": 0.25, "END": 0.15, "SEN": 0.30},
}

# --- Hunter rank thresholds: min level for that rank's assessment (§28/§29) ---
const RANK_LEVEL := {"D": 5, "C": 12, "B": 20, "A": 30, "S": 40}

# --- Canonical rank ladder, low to high (§28) ---
const RANK_ORDER := ["E", "D", "C", "B", "A", "S"]

# --- Essence per gate clear (§26): real source numbers, not invented ---
const ESSENCE_PER_GATE_RANK := {"E": 20, "D": 50, "C": 120, "B": 300, "A": 700, "S": 1500}

# --- Shadow grade ladder (§6): rank -> display name. Static, no promotion. ---
const GRADE_NAME := {
	"E": "Wraith",
	"D": "Soldier",
	"C": "Knight",
	"B": "General",
	"A": "Warlord",
	"S": "Sovereign",
}

# --- Essence per mass-converted shadow, by grade (§26/§17): real source numbers ---
const ESSENCE_PER_CONVERTED_SHADOW := {"E": 1, "D": 2, "C": 4, "B": 8, "A": 15, "S": 30}


# --- Progression (§3): linear curve ---
static func exp_to_next(level: int) -> int:
	return 100 * level


# --- Workout -> EXP (§4). 1.5x on workout minutes if it matches your
# subclass, a soft cap/taper above DAILY_EXP_SOFT_CAP (§4's "marathoners
# don't break the curve" guardrail), and an optional rest-day bonus
# (§4/§27's "reward recovery") applied to the capped total. ---
static func daily_exp(
	steps: int,
	active_minutes: int,
	workout_minutes: int,
	workout_matches_class: bool,
	rest_bonus: bool = false
) -> int:
	var mult := CLASS_EXP_MULT if workout_matches_class else 1.0
	var raw := steps / 100.0 + active_minutes * 5.0 + workout_minutes * 10.0 * mult
	var capped := raw
	if raw > DAILY_EXP_SOFT_CAP:
		capped = DAILY_EXP_SOFT_CAP + (raw - DAILY_EXP_SOFT_CAP) * DAILY_EXP_TAPER_RATE
	if rest_bonus:
		capped *= REST_BONUS_MULT
	return int(round(capped))


# --- Stats derived from level x class (§3/§16) ---
# Largest-remainder apportionment: naive per-stat rounding lets the total
# drift off `points` (L1 Warrior rounded to 26, not 25, breaking the §16
# worked example of personal_power=145). Floor each share, then hand the
# leftover points one at a time to the largest fractional remainders, so
# the stats always sum to exactly `points`.
static func stats_from(level: int, clazz: String) -> Dictionary:
	var profile: Dictionary = CLASS_PROFILES.get(clazz.to_upper(), CLASS_PROFILES["WARRIOR"])
	var points := level * STAT_POINTS_PER_LEVEL
	var keys: Array = profile.keys()
	var out := {}
	var remainders := {}
	var allocated := 0
	for stat in keys:
		var exact: float = points * profile[stat]
		var floor_val := int(floor(exact))
		out[stat] = floor_val
		remainders[stat] = exact - floor_val
		allocated += floor_val
	var order: Array = range(keys.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var ra: float = remainders[keys[a]]
			var rb: float = remainders[keys[b]]
			if ra != rb:
				return ra > rb
			return a < b
	)
	for i in points - allocated:
		out[keys[order[i]]] += 1
	return out


# --- Personal power (§16) ---
static func personal_power(stats: Dictionary, level: int, equipped_power_bonus: int = 0) -> int:
	var stat_sum := 0
	for v in stats.values():
		stat_sum += v
	return stat_sum * STAT_WEIGHT + level * LEVEL_WEIGHT + equipped_power_bonus


# --- Shadow power (§16) ---
static func shadow_power(
	base_power: int,
	shadow_level: int,
	hunter_level: int,
	gear_power_bonus: int = 0,
	gear_stat_bonus: int = 0
) -> int:
	var core := (
		base_power * (SHADOW_BASE_SCALE + SHADOW_LEVEL_SCALE * shadow_level)
		+ gear_power_bonus
		+ gear_stat_bonus * STAT_WEIGHT
	)
	return int(round(core * (1.0 + MONARCH_SCALE * hunter_level)))


# --- Armor-set power%% bonus (§15 patch 3): applied as a straight multiplier
# on an already-computed power number. Where in the formula a set's "N%
# power" applies isn't specified in the source -- multiplying the final
# result (rather than e.g. only the stat contribution) is the simplest
# reading, and keeps this a pure post-processing step so it doesn't have to
# be threaded into personal_power/shadow_power's own math. ---
static func apply_set_power_pct(power: int, power_pct: float) -> int:
	return int(round(power * (1.0 + power_pct)))


# --- Army power: sum of shadow_power over a list of shadow dicts ---
# each shadow: {base_power:int, level:int, gear_power_bonus:int, gear_stat_bonus:int}
static func army_power(shadows: Array, hunter_level: int) -> int:
	var total := 0
	for s in shadows:
		total += shadow_power(
			s.get("base_power", 0),
			s.get("level", 0),
			hunter_level,
			s.get("gear_power_bonus", 0),
			s.get("gear_stat_bonus", 0)
		)
	return total


# --- Context power (§16): gates weight the army x0.25, raids x1.0 ---
static func gate_power(personal: int, squad_army_power: int) -> int:
	return int(round(personal + squad_army_power * GATE_ARMY_WEIGHT))


static func raid_power(personal: int, full_army_power: int) -> int:
	return int(round(personal + full_army_power * RAID_ARMY_WEIGHT))


# --- Clear check (§5/§30): P = r^k / (r^k + 1) ---
static func clear_probability(power: float, target_power: float, k: int = CLEAR_K) -> float:
	if target_power <= 0.0:
		return 1.0
	var r := power / target_power
	var rk := pow(r, k)
	return rk / (rk + 1.0)


static func resolve_clear(
	power: float, target_power: float, rng: RandomNumberGenerator = null
) -> bool:
	var p := clear_probability(power, target_power)
	var roll := rng.randf() if rng else randf()
	return roll < p


# --- CLAIM (§18): per-try chance rises with hunter level, capped; up to CLAIM_TRIES ---
static func claim_chance_per_try(base_extract_chance: float, hunter_level: int) -> float:
	return min(CLAIM_CAP, base_extract_chance + hunter_level * CLAIM_LEVEL_BONUS)


static func claim_overall_chance(
	base_extract_chance: float, hunter_level: int, tries: int = CLAIM_TRIES
) -> float:
	var p := claim_chance_per_try(base_extract_chance, hunter_level)
	return 1.0 - pow(1.0 - p, tries)


static func attempt_claim(
	base_extract_chance: float, hunter_level: int, rng: RandomNumberGenerator = null
) -> bool:
	var p := claim_chance_per_try(base_extract_chance, hunter_level)
	for _i in CLAIM_TRIES:
		var roll := rng.randf() if rng else randf()
		if roll < p:
			return true
	return false


# --- Nadir floor power (§20): fixed escalating curve ---
static func floor_power(n: int) -> int:
	return int(round(300.0 * pow(1.12, n)))


# --- Highest rank Assessment a hunter's LEVEL has unlocked (§28) -- NOT
# their earned rank. §28 is explicit that rank is "earned, not
# auto-granted": clearing that rank's Trial (RankAssessment.attempt) is
# what actually promotes HunterState.hunter_rank. This just answers "which
# Trial can I currently attempt". ---
static func rank_for_level(level: int) -> String:
	var rank := "E"
	for r in ["D", "C", "B", "A", "S"]:
		if level >= int(RANK_LEVEL[r]):
			rank = r
	return rank


# --- Essence granted on a gate clear (§26) -- unranked/unknown rank yields 0 ---
static func essence_for_gate(rank: String) -> int:
	return int(ESSENCE_PER_GATE_RANK.get(rank, 0))


# --- Shadow grade ladder name for a rank (§6) -- unranked/unknown rank falls
# back to the raw rank letter rather than an empty string. ---
static func grade_name(rank: String) -> String:
	return String(GRADE_NAME.get(rank, rank))


# --- Essence granted converting a shadow to Essence, by grade (§26/§17) ---
static func essence_for_converted_shadow(grade: String) -> int:
	return int(ESSENCE_PER_CONVERTED_SHADOW.get(grade, 0))
