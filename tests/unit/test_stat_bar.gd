extends GutTest
## scenes/stat_bar.gd -- pure colour math for the HP bar.


func test_hp_color_is_green_at_or_above_half() -> void:
	assert_eq(StatBar.hp_color(1.0), Color(0.34, 0.88, 0.54))
	assert_eq(StatBar.hp_color(0.5), Color(0.34, 0.88, 0.54))


func test_hp_color_is_amber_between_a_fifth_and_a_half() -> void:
	assert_eq(StatBar.hp_color(0.49), Color(0.91, 0.76, 0.29))
	assert_eq(StatBar.hp_color(0.2), Color(0.91, 0.76, 0.29))


func test_hp_color_is_red_below_a_fifth() -> void:
	assert_eq(StatBar.hp_color(0.19), Color(0.91, 0.38, 0.29))
	assert_eq(StatBar.hp_color(0.0), Color(0.91, 0.38, 0.29))
