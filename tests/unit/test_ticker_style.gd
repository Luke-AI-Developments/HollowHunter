extends GutTest
## Task 6: BattleView._render_style_for pure helper -- classifies a
## _battle.log event type into the ticker's render lane ("banner" for the
## big beats Task 7 also reacts to, "silent" for telemetry the ticker
## drops, "line" for ordinary events).


func test_big_beats_are_banner_style() -> void:
	for t in ["break", "phase", "undying", "ultimate", "revive"]:
		assert_eq(BattleView._render_style_for(t), "banner", t)


func test_telemetry_is_silent() -> void:
	for t in ["break_fill", "gauge", "status"]:
		assert_eq(BattleView._render_style_for(t), "silent", t)


func test_ordinary_events_are_lines() -> void:
	assert_eq(BattleView._render_style_for("damage"), "line")
	assert_eq(BattleView._render_style_for("heal"), "line")
