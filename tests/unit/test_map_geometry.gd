extends GutTest
## Pure projection/simplification/style-lookup logic for the vector-line
## map renderer (§19b/§19c) -- no engine dependency, so it's covered here
## rather than only manually verified like scenes/map_view.gd.


func test_lonlat_to_mercator_at_origin() -> void:
	var result := MapGeometry.lonlat_to_mercator(0.0, 0.0)
	assert_almost_eq(result.x, 0.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.01)


func test_lonlat_to_mercator_known_point() -> void:
	# Darlington town centre, roughly. Web Mercator X should be strongly
	# negative (west of the prime meridian); Y should be positive (well
	# north of the equator).
	var result := MapGeometry.lonlat_to_mercator(-1.5549, 54.5235)
	assert_lt(result.x, 0.0)
	assert_gt(result.y, 0.0)
	# Sanity-check the magnitude: -1.5549 degrees of longitude at this
	# latitude is roughly -173,100m in Web Mercator (radius * radians).
	assert_almost_eq(result.x, -173100.0, 500.0)


func test_lonlat_to_mercator_longitude_scales_linearly() -> void:
	# Mercator X is a pure linear function of longitude (no latitude
	# dependence) -- doubling longitude doubles X.
	var a := MapGeometry.lonlat_to_mercator(-1.0, 54.5)
	var b := MapGeometry.lonlat_to_mercator(-2.0, 54.5)
	assert_almost_eq(b.x, a.x * 2.0, 1.0)


func test_background_color_is_the_locked_near_black() -> void:
	assert_eq(MapGeometry.BACKGROUND_COLOR, Color(0x05 / 255.0, 0x0b / 255.0, 0x12 / 255.0))


func test_road_color_matches_class() -> void:
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_MAJOR_ROAD),
		Color(0x1b / 255.0, 0x25 / 255.0, 0x32 / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_MINOR_ROAD),
		Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_PATH),
		Color(0x0a / 255.0, 0x0f / 255.0, 0x16 / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_WATER_AREA),
		Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0)
	)
	assert_eq(
		MapGeometry.road_color(MapGeometry.CLASS_WATER_LINE),
		Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0)
	)


func test_road_width_major_wider_than_minor_wider_than_path() -> void:
	var major := MapGeometry.road_width_px(MapGeometry.CLASS_MAJOR_ROAD)
	var minor := MapGeometry.road_width_px(MapGeometry.CLASS_MINOR_ROAD)
	var path := MapGeometry.road_width_px(MapGeometry.CLASS_PATH)
	assert_gt(major, minor)
	assert_gt(minor, path)
	assert_gt(path, 0.0)  # never literally zero/invisible


func test_simplify_polyline_removes_collinear_points() -> void:
	var points := PackedVector2Array(
		[Vector2(0, 0), Vector2(1, 0.001), Vector2(2, 0), Vector2(10, 0)]
	)
	var simplified := MapGeometry.simplify_polyline(points, 0.5)
	# The two near-collinear middle points should collapse away, keeping
	# just the endpoints (both roughly on the same line).
	assert_eq(simplified.size(), 2)
	assert_eq(simplified[0], Vector2(0, 0))
	assert_eq(simplified[1], Vector2(10, 0))


func test_simplify_polyline_keeps_a_real_corner() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(5, 5), Vector2(10, 0)])
	var simplified := MapGeometry.simplify_polyline(points, 0.5)
	# A sharp corner well outside the tolerance must survive.
	assert_eq(simplified.size(), 3)


func test_simplify_polyline_short_input_unchanged() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])
	var simplified := MapGeometry.simplify_polyline(points, 5.0)
	assert_eq(simplified.size(), 2)


func test_way_bounds() -> void:
	var points := PackedVector2Array([Vector2(-5, 10), Vector2(20, -3), Vector2(0, 0)])
	var bounds := MapGeometry.way_bounds(points)
	assert_eq(bounds.position, Vector2(-5, -3))
	assert_eq(bounds.size, Vector2(25, 13))


func test_rect_intersects_overlapping() -> void:
	var a := Rect2(Vector2(0, 0), Vector2(10, 10))
	var b := Rect2(Vector2(5, 5), Vector2(10, 10))
	assert_true(MapGeometry.rect_intersects(a, b))


func test_rect_intersects_disjoint() -> void:
	var a := Rect2(Vector2(0, 0), Vector2(10, 10))
	var b := Rect2(Vector2(100, 100), Vector2(10, 10))
	assert_false(MapGeometry.rect_intersects(a, b))
