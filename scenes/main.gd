extends Node2D

## Checkpoint 3 test harness: request GPS permission, start live updates,
## show lat/lon/accuracy on screen. Torn out again once checkpoint 4
## (Health Connect) is layered in and once real game code replaces this.

var bridge: Object
@onready var label: Label = $Label


func _ready() -> void:
	if not Engine.has_singleton("GpsHealthBridge"):
		label.text = "GpsHealthBridge singleton not found"
		return
	bridge = Engine.get_singleton("GpsHealthBridge")
	bridge.location_permission_result.connect(_on_location_permission_result)
	bridge.location_update.connect(_on_location_update)
	label.text = "Requesting location permission..."
	bridge.requestLocationPermission()


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		label.text = "Permission granted. Waiting for GPS fix..."
		bridge.startLocationUpdates()
	else:
		label.text = "Location permission denied"


func _on_location_update(lat: float, lon: float, accuracy: float, timestamp_ms: int) -> void:
	label.text = "Lat: %.6f\nLon: %.6f\n+/- %.1fm" % [lat, lon, accuracy]
	print("CHECKPOINT3: lat=%f lon=%f acc=%f ts=%d" % [lat, lon, accuracy, timestamp_ms])
