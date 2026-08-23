class_name MapGeometry
## Pure projection/simplification/style-lookup logic for the vector-line
## map renderer (§19b/§19c). No engine dependency (no Node, no FileAccess)
## -- scenes/map_view.gd owns loading the binary extract and all drawing;
## this class is the testable math underneath it.

const EARTH_RADIUS_M := 6378137.0  ## WGS84 semi-major axis -- also the
## sphere radius Web Mercator (EPSG:3857) uses. Must match
## tools/map_extract/fetch_and_convert.py's EARTH_RADIUS_M exactly, or
## the live GPS position/gate markers won't land in the same coordinate
## space as the pre-projected road data.

## Matches content/map_data/*.bin's per-way class_id byte exactly --
## see tools/map_extract/fetch_and_convert.py's WAY_CLASSES.
const CLASS_MAJOR_ROAD := 0
const CLASS_MINOR_ROAD := 1
const CLASS_PATH := 2
const CLASS_WATER_LINE := 3
const CLASS_WATER_AREA := 4

## §19b: near-black, matching this project's already-locked §9b background.
## scenes/map_view.gd draws this explicitly as its first _draw() call --
## MapView is a bare Node2D with no inherent fill, so without this the map
## would show whatever panel happens to sit behind it instead of the
## intended dark basemap.
const BACKGROUND_COLOR := Color(0x05 / 255.0, 0x0b / 255.0, 0x12 / 255.0)


## Same formula as the Python conversion script -- must stay in sync.
static func lonlat_to_mercator(lon: float, lat: float) -> Vector2:
	var x := deg_to_rad(lon) * EARTH_RADIUS_M
	var y := log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0)) * EARTH_RADIUS_M
	return Vector2(x, y)


## Inverse of lonlat_to_mercator() -- must stay in sync with it the same way
## the Python conversion script's own formula does. Returns Vector2(lon,
## lat), matching this file's Vector2(x=lon, y=lat) convention throughout.
static func mercator_to_lonlat(x: float, y: float) -> Vector2:
	var lon := rad_to_deg(x / EARTH_RADIUS_M)
	var lat := rad_to_deg(2.0 * atan(exp(y / EARTH_RADIUS_M)) - PI / 2.0)
	return Vector2(lon, lat)


## Great-circle distance in metres between two lat/lon points (haversine).
## Deliberately NOT built on lonlat_to_mercator() -- Web Mercator's scale
## factor is sec(latitude), so a Mercator-space distance is inflated by
## ~72% at Darlington's ~54.5° latitude (191.8m computed for a true 111.3m
## gap -- caught by the Task 1 implementer's own test run). That distortion
## is invisible for on-screen rendering (a few pixels either way) but would
## silently break every real-world proximity check this function feeds
## (Sanctuary/Lore Stone/Stronghold's 50m radius), so this earns its own,
## separate, standard formula instead of reusing the projection.
static func distance_metres(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var lat1_rad := deg_to_rad(lat1)
	var lat2_rad := deg_to_rad(lat2)
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2.0) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2.0) ** 2
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return EARTH_RADIUS_M * c


## §19b palette, converted to hex once here rather than duplicated at
## every call site.
static func road_color(class_id: int) -> Color:
	match class_id:
		CLASS_MAJOR_ROAD:
			return Color(0x1b / 255.0, 0x25 / 255.0, 0x32 / 255.0)
		CLASS_MINOR_ROAD:
			return Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0)
		CLASS_PATH:
			return Color(0x0a / 255.0, 0x0f / 255.0, 0x16 / 255.0)
		CLASS_WATER_LINE, CLASS_WATER_AREA:
			return Color(0x02 / 255.0, 0x04 / 255.0, 0x0a / 255.0)
		_:
			return Color(0x0f / 255.0, 0x16 / 255.0, 0x20 / 255.0)


## Base on-screen width in pixels, BEFORE any zoom scaling scenes/
## map_view.gd applies -- deliberately not true-to-real-world-scale so
## roads stay legible at any zoom rather than vanishing to sub-pixel
## width when zoomed out (§19b: "grid legible, no more").
static func road_width_px(class_id: int) -> float:
	match class_id:
		CLASS_MAJOR_ROAD:
			return 4.0
		CLASS_MINOR_ROAD:
			return 2.0
		CLASS_PATH:
			return 1.0
		_:
			return 2.0


## Ramer-Douglas-Peucker polyline simplification. `tolerance` is in the
## same units as `points` (metres, for this project's callers). Available
## for scenes/map_view.gd to apply at low zoom if on-device performance
## needs it -- see this plan's Task 3.
static func simplify_polyline(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var max_dist := 0.0
	var max_index := 0
	var start := points[0]
	var end := points[points.size() - 1]

	for i in range(1, points.size() - 1):
		var dist := _point_segment_distance(points[i], start, end)
		if dist > max_dist:
			max_dist = dist
			max_index = i

	if max_dist <= tolerance:
		return PackedVector2Array([start, end])

	var left := simplify_polyline(points.slice(0, max_index + 1), tolerance)
	var right := simplify_polyline(points.slice(max_index, points.size()), tolerance)
	# `right`'s first point duplicates `left`'s last point (both are
	# points[max_index]) -- drop it before concatenating.
	return left + right.slice(1, right.size())


static func _point_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg := seg_end - seg_start
	var seg_len_sq := seg.length_squared()
	if seg_len_sq == 0.0:
		return point.distance_to(seg_start)
	var t: float = clamp((point - seg_start).dot(seg) / seg_len_sq, 0.0, 1.0)
	var projection := seg_start + seg * t
	return point.distance_to(projection)


static func way_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


static func rect_intersects(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)
