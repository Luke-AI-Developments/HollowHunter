extends Node2D

## Checkpoint 2 smoke test: call the native plugin's hello-world method and
## print the result, so it's visible in `adb logcat`. Torn out again once
## checkpoints 3-4 (GPS/Health Connect) replace it with the real thing.


func _ready() -> void:
	if Engine.has_singleton("GpsHealthBridge"):
		var bridge: Object = Engine.get_singleton("GpsHealthBridge")
		print("CHECKPOINT2: ", bridge.helloWorld())
	else:
		print("CHECKPOINT2: GpsHealthBridge singleton not found")
