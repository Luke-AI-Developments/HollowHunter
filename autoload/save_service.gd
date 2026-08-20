extends Node
## Autoload singleton (registered in project.godot as "SaveService" -- that
## registration is what makes the name globally accessible, so this can't
## also declare class_name SaveService; Godot rejects a class hiding an
## autoload of the same name). Thin wrapper over FileAccess -- the only
## place in the project that touches disk for save data. All actual logic
## (serialization, defaults) lives in the pure HunterState class; this just
## calls it.

const SAVE_PATH := "user://save.json"


func save(state: HunterState) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error(
			(
				"SaveService: failed to open %s for write (%s)"
				% [SAVE_PATH, FileAccess.get_open_error()]
			)
		)
		return
	f.store_string(JSON.stringify(state.to_dict()))
	f.close()


## Loads existing save data, or creates+saves a fresh default if none exists
## (or the save is unreadable).
func load_or_create(
	default_subclass: String = "WARRIOR", default_preset: String = "m1"
) -> HunterState:
	if not FileAccess.file_exists(SAVE_PATH):
		var fresh := HunterState.new_default(default_subclass, default_preset)
		save(fresh)
		return fresh

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error(
			(
				"SaveService: failed to open %s for read (%s)"
				% [SAVE_PATH, FileAccess.get_open_error()]
			)
		)
		return HunterState.new_default(default_subclass, default_preset)

	var text := f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("SaveService: %s did not contain valid JSON, using a fresh default" % SAVE_PATH)
		return HunterState.new_default(default_subclass, default_preset)

	return HunterState.from_dict(data)
