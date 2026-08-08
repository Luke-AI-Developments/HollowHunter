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
## above); pass it explicitly once/if a real source exists.
static func exp_for_today(
	steps: int, workouts_json: String, subclass: String, active_minutes: int = 0
) -> int:
	var workouts := parse_workouts(workouts_json)
	var workout_minutes := total_workout_minutes(workouts)
	var matches := matches_signature_training(workouts, subclass)
	return GameLogic.daily_exp(steps, active_minutes, workout_minutes, matches)
