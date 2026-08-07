@tool
extends EditorPlugin

# Registers the compiled GpsHealthBridge Android plugin (see
# native/android/gps_health_bridge/) with Godot's Android export.
# The .aar files referenced below don't exist until you build that Gradle
# project and copy the outputs here -- see this folder's README.md.

var export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name := "GpsHealthBridge"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["gps_health_bridge/GpsHealthBridge.debug.aar"])
		else:
			return PackedStringArray(["gps_health_bridge/GpsHealthBridge.release.aar"])

	# Our .aar is added as a local file dependency (_get_android_libraries
	# above), which does NOT pull in transitive Maven dependencies the way a
	# real coordinate would -- so the plugin's own dependencies have to be
	# declared here too, or classes it references throw NoClassDefFoundError
	# at runtime even though the plugin's own class loads fine.
	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.android.gms:play-services-location:21.3.0",
			"androidx.health.connect:connect-client:1.1.0-alpha07",
			"androidx.core:core-ktx:1.13.1",
			"androidx.activity:activity-ktx:1.9.0",
			"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0",
		])

	func _get_name() -> String:
		return _plugin_name

	# Same manifest-merge gap as the meta-data below: our plugin's own
	# AndroidManifest.xml (native/android/gps_health_bridge/src/main/) is
	# never merged, so its <uses-permission>/<queries> entries are dead too.
	# Re-declared here for GPS (checkpoint 3) and Health Connect (checkpoint 4).
	func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return """
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_EXERCISE" />
<queries>
	<package android:name="com.google.android.apps.healthdata" />
</queries>
"""

	# A locally file-referenced .aar (via _get_android_libraries, no Maven/
	# project coordinate) does NOT get its own manifest merged by AGP -- so
	# the plugin-registration meta-data has to be injected into the app's
	# manifest directly here instead of relying on the AAR's manifest.
	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.GpsHealthBridge" android:value="com.shadowhunter.gpshealthbridge.GpsHealthBridgePlugin" />'
