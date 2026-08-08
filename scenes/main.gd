extends Node2D

## Checkpoint 4 test harness: GPS (checkpoint 3) plus Health Connect --
## availability check, permission request, today's steps, most recent
## workout, all shown on screen. Last checkpoint of the spike; torn out
## once real game code replaces this.

var bridge: Object
@onready var label: Label = $Label

var _gps_line := "GPS: waiting..."
var _health_line := "Health: waiting..."


func _ready() -> void:
	if not Engine.has_singleton("GpsHealthBridge"):
		label.text = "GpsHealthBridge singleton not found"
		return
	bridge = Engine.get_singleton("GpsHealthBridge")

	bridge.location_permission_result.connect(_on_location_permission_result)
	bridge.location_update.connect(_on_location_update)
	bridge.health_connect_available.connect(_on_health_connect_available)
	bridge.health_permission_result.connect(_on_health_permission_result)
	bridge.steps_result.connect(_on_steps_result)
	bridge.workouts_result.connect(_on_workouts_result)

	bridge.requestLocationPermission()
	bridge.checkHealthConnectAvailable()
	_refresh_label()


func _refresh_label() -> void:
	label.text = _gps_line + "\n\n" + _health_line


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		bridge.startLocationUpdates()
	else:
		_gps_line = "GPS: permission denied"
		_refresh_label()


func _on_location_update(lat: float, lon: float, accuracy: float, _timestamp_ms: int) -> void:
	_gps_line = "Lat: %.6f\nLon: %.6f\n+/- %.1fm" % [lat, lon, accuracy]
	_refresh_label()


func _on_health_connect_available(available: bool) -> void:
	if available:
		_health_line = "Health Connect: available, requesting permission..."
		bridge.requestHealthPermissions()
	else:
		_health_line = "Health Connect: not available on this device"
	_refresh_label()


func _on_health_permission_result(granted: bool) -> void:
	if granted:
		_health_line = "Health: permission granted, reading..."
		bridge.readTodaySteps()
		bridge.readRecentWorkouts(24)
	else:
		_health_line = "Health: permission denied"
	_refresh_label()
	print("CHECKPOINT4: health_permission_result=", granted)


func _on_steps_result(count: int) -> void:
	_health_line = "Steps today: %d" % count
	_refresh_label()
	print("CHECKPOINT4: steps_result=", count)


func _on_workouts_result(workouts_json: String) -> void:
	_health_line += "\nWorkouts (24h): " + workouts_json
	_refresh_label()
	print("CHECKPOINT4: workouts_result=", workouts_json)
