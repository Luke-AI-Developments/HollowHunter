class_name DailyExp
## Wires Health Connect data (steps + the workouts_result JSON from the
## GpsHealthBridge native plugin) into GameLogic.daily_exp(). Pure -- takes
## already-fetched data, no plugin/engine access itself (see
## autoload/health_service.gd for the wiring that calls the plugin).
##
## KNOWN v0 LIMITATION: Health Connect's ExerciseSessionRecord.exerciseType
## is a numeric enum, but its exact integer values aren't available to
## verify safely (context7 turned up the named Kotlin constants, not their
## runtime values), and guessing them risked silently misclassifying every
## workout. Matching on the workout's free-text `title` instead is weaker
## (titles are often user-typed) but honest about what we can actually
## check -- swap for exerciseType once the constants are verified.
##
## Similarly, "active_minutes" from §4's formula has no source yet (would
## need Health Connect's ActiveCaloriesBurned or similar, not wired) --
## always 0 here, parameterized for when it is.

const SIGNATURE_KEYWORDS := {
	"WARRIOR": ["strength", "weight", "lift", "gym"],
	"ASSASSIN": ["run", "sprint", "hiit", "interval"],
	"GUARDIAN":
	["cycle", "cycling", "bike", "biking", "row", "rowing", "hike", "hiking", "endurance"],
	"MAGE": ["yoga", "pilates", "mobility", "stretch"],
	"SUPPORT": ["swim", "swimming", "core", "crossfit", "cross-training", "circuit"],
}


static func parse_workouts(workouts_json: String) -> Array:
	var data: Variant = JSON.parse_string(workouts_json)
	if data == null or typeof(data) != TYPE_ARRAY:
		return []
	return data


## Kotlin's Instant.toString() gives e.g. "2026-08-08T07:23:27.564Z";
## Godot's datetime parser wants "YYYY-MM-DD HH:MM:SS". Normalize rather
## than trust the engine parser to be lenient about it.
static func _parse_iso_to_unix(iso: String) -> float:
	if iso.is_empty():
		return 0.0
	var normalized := iso.replace("T", " ")
	var dot_idx := normalized.find(".")
	if dot_idx != -1:
		normalized = normalized.substr(0, dot_idx)
	normalized = normalized.replace("Z", "").strip_edges()
	return float(Time.get_unix_time_from_datetime_string(normalized))


## §4/§21: the subset of `workouts` that started on calendar date `day`
## ("YYYY-MM-DD"), by string-prefix match on the workout's `start_time` ISO
## date. The plugin stamps `start_time` from Kotlin `Instant.toString()`,
## which is always UTC ("...Z"), so a caller passes BOTH the device-local
## date and the UTC date as `day` / `day_alt` and a workout matching either
## is kept -- otherwise every evening session in a negative-UTC timezone
## would be dropped from "today" (lost EXP, broken streak). Proper fix is
## native (emit a tz-aware local date from the plugin); this is the v0
## stopgap. Empty / missing / malformed start_time -> excluded.
static func workouts_for_day(workouts: Array, day: String, day_alt: String = "") -> Array:
	var out: Array = []
	for w: Dictionary in workouts:
		var start := String(w.get("start_time", ""))
		if start.length() < 10:
			continue
		var prefix := start.substr(0, 10)
		if prefix == day or (day_alt != "" and prefix == day_alt):
			out.append(w)
	return out


static func total_workout_minutes(workouts: Array) -> int:
	var total_seconds := 0.0
	for w: Dictionary in workouts:
		var start := _parse_iso_to_unix(String(w.get("start_time", "")))
		var end := _parse_iso_to_unix(String(w.get("end_time", "")))
		if end > start:
			total_seconds += end - start
	return int(round(total_seconds / 60.0))


static func matches_signature_training(workouts: Array, subclass: String) -> bool:
	var keywords: Array = SIGNATURE_KEYWORDS.get(subclass.to_upper(), [])
	for w: Dictionary in workouts:
		var title: String = String(w.get("title", "")).to_lower()
		for kw: String in keywords:
			if title.contains(kw):
				return true
	return false


## The wiring point: real steps + the plugin's raw workouts JSON + subclass
## -> GameLogic.daily_exp(). active_minutes defaults to 0 (see limitation
## above); pass it explicitly once/if a real source exists. `rest_bonus`
## passes straight through to GameLogic.daily_exp() -- see
## rest_bonus_applies() below for how a caller decides it.
static func exp_for_today(
	steps: int,
	workouts_json: String,
	subclass: String,
	active_minutes: int = 0,
	rest_bonus: bool = false,
	today: String = "",
	today_utc: String = ""
) -> int:
	var workouts := parse_workouts(workouts_json)
	if today != "":
		workouts = workouts_for_day(workouts, today, today_utc)
	var workout_minutes := total_workout_minutes(workouts)
	var matches := matches_signature_training(workouts, subclass)
	return GameLogic.daily_exp(steps, active_minutes, workout_minutes, matches, rest_bonus)


## Phase 2/P5 step 1: the hunter screen's "streak" (§21's "the motivating
## core"). Standard consecutive-day counter, same mechanic as any habit
## app -- not an invented number so much as an obvious implementation of
## an unambiguous concept. `today`/`last_exp_date` are "YYYY-MM-DD"
## device-local dates, same convention as HunterState.last_exp_date;
## `current_streak` is the value BEFORE today's grant. Call with the OLD
## last_exp_date, before HunterState.mark_exp_applied(today) overwrites it.
static func next_streak(today: String, last_exp_date: String, current_streak: int) -> int:
	if last_exp_date == "":
		return 1  # first day ever
	if last_exp_date == today:
		return current_streak  # already counted today (shouldn't happen given the daily guard)
	if last_exp_date == _date_minus_one_day(today):
		return current_streak + 1  # consecutive day
	return 1  # gap -- streak resets


static func _date_minus_one_day(date_str: String) -> String:
	var unix_time := Time.get_unix_time_from_datetime_string(date_str + " 00:00:00")
	return Time.get_date_string_from_unix_time(int(unix_time) - 86400)


## Phase 2/P10: whether today's EXP grant should get the rest-day bonus
## (§4/§27 "reward recovery") -- true when there's a genuine gap since the
## last day EXP was banked (not "", not today, not yesterday). Same
## day-math as next_streak()'s reset case, checked independently since a
## streak reset and a rest bonus are different concerns that happen to
## share a condition today. Approximation, flagged: this reads "no EXP
## banked yesterday" from save data, which conflates "genuinely rested"
## with "didn't open the app" -- verifying real rest would need querying
## Health Connect for a specific PAST day, which the native plugin doesn't
## support (it only reads today's steps + a rolling 24h workout window).
## Call with the OLD last_exp_date, same convention as next_streak().
static func rest_bonus_applies(today: String, last_exp_date: String) -> bool:
	if last_exp_date == "" or last_exp_date == today:
		return false
	return last_exp_date != _date_minus_one_day(today)
