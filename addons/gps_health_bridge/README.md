# addons/gps_health_bridge/

Editor-side half of the GPS/Health Connect spike. Godot's export system reads
this addon (`plugin.cfg` + `export_plugin.gd`) to bundle the compiled Android
plugin into the exported APK.

**This folder does not contain the compiled plugin yet.** After building
`native/android/` (see that folder's README), copy the two Gradle outputs
here:

```
native/android/gps_health_bridge/build/outputs/aar/gps_health_bridge-debug.aar
  -> addons/gps_health_bridge/GpsHealthBridge.debug.aar
native/android/gps_health_bridge/build/outputs/aar/gps_health_bridge-release.aar
  -> addons/gps_health_bridge/GpsHealthBridge.release.aar
```

Then in the Godot editor: **Project > Project Settings > Plugins**, enable
"GPS + Health Bridge". Android export must use the Gradle build
(Export Preset > Android > Gradle Build > Use Gradle Build, on).

## Calling it from GDScript

```gdscript
var bridge

func _ready() -> void:
    if Engine.has_singleton("GpsHealthBridge"):
        bridge = Engine.get_singleton("GpsHealthBridge")
        bridge.location_update.connect(_on_location_update)
        bridge.steps_result.connect(_on_steps_result)
        bridge.requestLocationPermission()
        bridge.checkHealthConnectAvailable()

func _on_location_update(lat: float, lon: float, accuracy: float, timestamp_ms: int) -> void:
    print("GPS: %f, %f (+-%f m)" % [lat, lon, accuracy])

func _on_steps_result(count: int) -> void:
    print("Steps today: ", count)
```

Runs on a physical device only -- GPS and Health Connect are both no-ops in
the Android emulator.
