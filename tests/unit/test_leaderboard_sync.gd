extends GutTest
## LeaderboardSync: pure payload building/parsing for the backend/rankings
## sync (§9/§31). No network -- see autoload/backend_service.gd for that.

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


func test_upsert_payload_has_the_documented_fields() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.level = 10
	s.hunter_rank = "C"
	s.nadir_deepest_floor = 7
	var payload := LeaderboardSync.upsert_payload(s, equipment)
	assert_eq(payload["hunter_rank"], "C")
	assert_eq(payload["hunter_level"], 10)
	assert_eq(payload["deepest_nadir_floor"], 7)
	assert_eq(payload["personal_power"], s.personal_power(equipment))


func test_upsert_payload_does_not_include_user_id_or_display_name() -> void:
	# BackendService adds those (session-derived / a separate name claim),
	# not HunterState -- keeps this function from needing session state.
	var s := HunterState.new_default("WARRIOR")
	var payload := LeaderboardSync.upsert_payload(s, equipment)
	assert_false(payload.has("user_id"))
	assert_false(payload.has("display_name"))


func test_rank_rows_numbers_positions_starting_at_1() -> void:
	var rows := [
		{"display_name": "Alice", "hunter_rank": "S", "hunter_level": 40, "personal_power": 9000},
		{"display_name": "Bob", "hunter_rank": "A", "hunter_level": 30, "personal_power": 5000},
	]
	var ranked := LeaderboardSync.rank_rows(rows)
	assert_eq(ranked[0]["position"], 1)
	assert_eq(ranked[0]["display_name"], "Alice")
	assert_eq(ranked[1]["position"], 2)
	assert_eq(ranked[1]["display_name"], "Bob")


func test_rank_rows_preserves_the_given_order() -> void:
	# Sorting is Supabase's job (the caller's order_by query param) --
	# this only numbers positions, never re-sorts.
	var rows := [
		{"display_name": "Weakest", "personal_power": 1},
		{"display_name": "Strongest", "personal_power": 9999},
	]
	var ranked := LeaderboardSync.rank_rows(rows)
	assert_eq(ranked[0]["display_name"], "Weakest")
	assert_eq(ranked[1]["display_name"], "Strongest")


func test_rank_rows_defaults_missing_fields() -> void:
	var ranked := LeaderboardSync.rank_rows([{}])
	assert_eq(ranked[0]["display_name"], "Hunter")
	assert_eq(ranked[0]["hunter_rank"], "E")
	assert_eq(ranked[0]["hunter_level"], 1)
	assert_eq(ranked[0]["personal_power"], 0)
	assert_eq(ranked[0]["deepest_nadir_floor"], 0)


func test_rank_rows_empty_is_empty() -> void:
	assert_eq(LeaderboardSync.rank_rows([]), [])


func test_is_valid_email_accepts_a_normal_address() -> void:
	assert_true(LeaderboardSync.is_valid_email("hunter@example.com"))


func test_is_valid_email_rejects_missing_at() -> void:
	assert_false(LeaderboardSync.is_valid_email("hunterexample.com"))


func test_is_valid_email_rejects_missing_domain_dot() -> void:
	assert_false(LeaderboardSync.is_valid_email("hunter@example"))


func test_is_valid_email_rejects_multiple_at_signs() -> void:
	assert_false(LeaderboardSync.is_valid_email("hunter@ex@ample.com"))


func test_is_valid_email_rejects_leading_at() -> void:
	assert_false(LeaderboardSync.is_valid_email("@example.com"))


func test_is_valid_email_rejects_trailing_dot() -> void:
	assert_false(LeaderboardSync.is_valid_email("hunter@example.com."))
