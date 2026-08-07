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

	func _get_name() -> String:
		return _plugin_name
