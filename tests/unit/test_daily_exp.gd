extends GutTest
## DailyExp: parsing the plugin's raw workouts JSON, duration summing,
## signature-training keyword matching, and the full wire-through to
## GameLogic.daily_exp().


static func _workout(
	title: String, start: String, end: String, exercise_type: int = 0
) -> Dictionary:
	return {"title": title, "exercise_type": exercise_type, "start_time": start, "end_time": end}


static func _json(workouts: Array) -> String:
	return JSON.stringify(workouts)


func test_parse_workouts_handles_empty_array() -> void:
	assert_eq(DailyExp.parse_workouts("[]"), [])


func test_parse_workouts_handles_garbage() -> void:
	assert_eq(DailyExp.parse_workouts("not json"), [])


func test_total_workout_minutes_single_workout() -> void:
	var run := _workout("Morning Run", "2026-08-08T07:00:00.000Z", "2026-08-08T07:30:00.000Z")
	var workouts := DailyExp.parse_workouts(_json([run]))
	assert_eq(DailyExp.total_workout_minutes(workouts), 30)


func test_total_workout_minutes_sums_multiple() -> void:
	var leg_day := _workout("Leg Day", "2026-08-08T06:00:00.000Z", "2026-08-08T06:45:00.000Z")
	var run := _workout("Evening Run", "2026-08-08T18:00:00.000Z", "2026-08-08T18:20:00.000Z")
	var workouts := DailyExp.parse_workouts(_json([leg_day, run]))
	assert_eq(DailyExp.total_workout_minutes(workouts), 65)  # 45 + 20


func test_matches_signature_training_true_for_matching_title() -> void:
	var run := _workout("Morning Run", "2026-08-08T07:00:00.000Z", "2026-08-08T07:30:00.000Z")
	var workouts := DailyExp.parse_workouts(_json([run]))
	assert_true(DailyExp.matches_signature_training(workouts, "ASSASSIN"))


func test_matches_signature_training_false_for_other_class() -> void:
	var run := _workout("Morning Run", "2026-08-08T07:00:00.000Z", "2026-08-08T07:30:00.000Z")
	var workouts := DailyExp.parse_workouts(_json([run]))
	assert_false(DailyExp.matches_signature_training(workouts, "MAGE"))


func test_matches_signature_training_case_insensitive() -> void:
	var yoga := _workout("Yoga Flow", "2026-08-08T07:00:00.000Z", "2026-08-08T07:20:00.000Z")
	var workouts := DailyExp.parse_workouts(_json([yoga]))
	assert_true(DailyExp.matches_signature_training(workouts, "MAGE"))


func test_exp_for_today_wires_into_game_logic() -> void:
	# 8000 steps + 30 workout minutes matching ASSASSIN's signature training:
	# matches GameLogic.daily_exp(8000, 0, 30, true) exactly.
	var run := _workout("Morning Run", "2026-08-08T07:00:00.000Z", "2026-08-08T07:30:00.000Z")
	var exp := DailyExp.exp_for_today(8000, _json([run]), "ASSASSIN")
	assert_eq(exp, GameLogic.daily_exp(8000, 0, 30, true))


func test_exp_for_today_no_match_uses_1x_multiplier() -> void:
	var run := _workout("Morning Run", "2026-08-08T07:00:00.000Z", "2026-08-08T07:30:00.000Z")
	var exp := DailyExp.exp_for_today(8000, _json([run]), "MAGE")
	assert_eq(exp, GameLogic.daily_exp(8000, 0, 30, false))


func test_exp_for_today_with_no_workouts_is_steps_only() -> void:
	var exp := DailyExp.exp_for_today(8000, "[]", "WARRIOR")
	assert_eq(exp, GameLogic.daily_exp(8000, 0, 0, false))


func test_next_streak_first_day_ever_is_1() -> void:
	assert_eq(DailyExp.next_streak("2026-08-08", "", 0), 1)


func test_next_streak_consecutive_day_increments() -> void:
	assert_eq(DailyExp.next_streak("2026-08-08", "2026-08-07", 5), 6)


func test_next_streak_gap_resets_to_1() -> void:
	assert_eq(DailyExp.next_streak("2026-08-08", "2026-08-05", 12), 1)


func test_next_streak_same_day_is_unchanged() -> void:
	assert_eq(DailyExp.next_streak("2026-08-08", "2026-08-08", 4), 4)


func test_next_streak_crosses_a_month_boundary() -> void:
	assert_eq(DailyExp.next_streak("2026-09-01", "2026-08-31", 3), 4)
