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


func test_workouts_for_day_keeps_todays_and_drops_yesterdays() -> void:
	var ws := [
		_workout("run", "2026-08-30T07:00:00Z", "2026-08-30T07:30:00Z"),
		_workout("run", "2026-08-29T18:00:00Z", "2026-08-29T18:51:00Z"),
	]
	var kept := DailyExp.workouts_for_day(ws, "2026-08-30")
	assert_eq(kept.size(), 1)
	assert_eq(kept[0]["start_time"], "2026-08-30T07:00:00Z")


func test_workouts_for_day_drops_malformed_and_empty_start() -> void:
	var ws := [
		_workout("a", "", "2026-08-30T07:30:00Z"),
		_workout("b", "not-a-date", "x"),
		_workout("c", "2026-08-30T09:00:00Z", "2026-08-30T09:20:00Z"),
	]
	assert_eq(DailyExp.workouts_for_day(ws, "2026-08-30").size(), 1)


func test_workouts_for_day_empty_input() -> void:
	assert_eq(DailyExp.workouts_for_day([], "2026-08-30"), [])


func test_workouts_for_day_matches_the_utc_alt_date() -> void:
	# Negative-UTC player: 19:00 local Aug 30 stamps as 2026-08-31T00:00Z.
	# local "today" is 2026-08-30, UTC "today" is 2026-08-31 -- must keep it.
	var ws := [
		_workout("run", "2026-08-31T00:00:00Z", "2026-08-31T00:45:00Z"),
		_workout("run", "2026-08-28T10:00:00Z", "2026-08-28T10:30:00Z"),
	]
	var kept := DailyExp.workouts_for_day(ws, "2026-08-30", "2026-08-31")
	assert_eq(kept.size(), 1)
	assert_eq(kept[0]["start_time"], "2026-08-31T00:00:00Z")


func test_exp_for_today_with_today_ignores_yesterdays_workout() -> void:
	var two := _json(
		[
			_workout("lift", "2026-08-30T07:00:00Z", "2026-08-30T07:30:00Z"),
			_workout("lift", "2026-08-29T20:00:00Z", "2026-08-29T20:51:00Z"),
		]
	)
	var one := _json([_workout("lift", "2026-08-30T07:00:00Z", "2026-08-30T07:30:00Z")])
	assert_eq(
		DailyExp.exp_for_today(5000, two, "WARRIOR", 0, false, "2026-08-30"),
		DailyExp.exp_for_today(5000, one, "WARRIOR", 0, false, "2026-08-30")
	)


func test_exp_for_today_without_today_counts_all_workouts_legacy() -> void:
	var two := _json(
		[
			_workout("lift", "2026-08-30T07:00:00Z", "2026-08-30T07:30:00Z"),
			_workout("lift", "2026-08-29T20:00:00Z", "2026-08-29T20:51:00Z"),
		]
	)
	var one := _json([_workout("lift", "2026-08-30T07:00:00Z", "2026-08-30T07:30:00Z")])
	assert_ne(
		DailyExp.exp_for_today(5000, two, "WARRIOR"), DailyExp.exp_for_today(5000, one, "WARRIOR")
	)


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


func test_rest_bonus_applies_after_a_genuine_gap() -> void:
	assert_true(DailyExp.rest_bonus_applies("2026-08-08", "2026-08-05"))


func test_rest_bonus_does_not_apply_on_the_first_day_ever() -> void:
	assert_false(DailyExp.rest_bonus_applies("2026-08-08", ""))


func test_rest_bonus_does_not_apply_for_consecutive_days() -> void:
	assert_false(DailyExp.rest_bonus_applies("2026-08-08", "2026-08-07"))


func test_rest_bonus_does_not_apply_for_the_same_day() -> void:
	assert_false(DailyExp.rest_bonus_applies("2026-08-08", "2026-08-08"))


func test_exp_for_today_passes_rest_bonus_through() -> void:
	var without_bonus := DailyExp.exp_for_today(2000, "[]", "WARRIOR", 0, false)
	var with_bonus := DailyExp.exp_for_today(2000, "[]", "WARRIOR", 0, true)
	assert_eq(with_bonus, int(round(without_bonus * GameLogic.REST_BONUS_MULT)))
