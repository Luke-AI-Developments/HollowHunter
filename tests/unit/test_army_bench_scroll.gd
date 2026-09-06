extends GutTest
## B3 regression: the Army roster bench must be touch-scrollable.
##
## Root cause of the device bug: scenes/army_view.gd built each bench card as a
## Button, which defaults to MOUSE_FILTER_STOP. On a touchscreen the card
## swallowed the initial press, so the parent BenchScroll (ScrollContainer)
## never entered its drag-to-scroll state (Godot's ScrollContainer starts touch
## scrolling only from a press it receives itself) -- the bench could not be
## flicked past the first screenful. Fix: the cards are MOUSE_FILTER_PASS so the
## press also reaches the ScrollContainer; scroll_deadzone (12) still lets a
## near-stationary tap through to the card.

## $RosterTab/BenchScroll in scenes/main.tscn is anchored to a fixed rect
## (offset_top 552 .. offset_bottom 2300) -- a bounded height, so content taller
## than this scrolls.
const BENCH_SCROLL_HEIGHT := 1748.0


func _fake_shadow() -> Dictionary:
	return {
		"instance_id": "t1",
		"monster_id": "mon_missing_art",
		"display_name": "Test Shadow",
		"grade": "C",
		"grade_name": "Common",
		"level": 5,
		"power": 1234,
		"locked": false,
		"favorite": false,
	}


func test_bench_cards_pass_touch_through_to_the_scroll_container() -> void:
	var view := ArmyView.new()
	for big in [false, true]:
		var card := view._make_shadow_card(_fake_shadow(), false, big)
		assert_eq(
			card.mouse_filter,
			Control.MOUSE_FILTER_PASS,
			"bench card (big=%s) must be MOUSE_FILTER_PASS so BenchScroll gets the press" % big
		)
		card.free()
	view.free()


func test_a_screenful_plus_of_shadows_overflows_the_bounded_bench_rect() -> void:
	var view := ArmyView.new()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_theme_constant_override("h_separation", 10)
	for _i in range(24):  # 8 rows of 3 -- comfortably past one screenful
		grid.add_child(view._make_shadow_card(_fake_shadow(), false, false))
	var content_height := grid.get_combined_minimum_size().y
	grid.free()
	view.free()
	assert_gt(
		content_height,
		BENCH_SCROLL_HEIGHT,
		"24 cards must be taller than the bench's fixed rect so there is something to scroll"
	)
