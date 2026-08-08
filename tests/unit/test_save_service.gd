extends GutTest
## SaveService round-trip, against the real autoload singleton (registered
## in project.godot, globally accessible as "SaveService"). Runs against
## the real user:// filesystem (works fine headless); each test cleans up.


func before_each() -> void:
	if FileAccess.file_exists(SaveService.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH))


func after_each() -> void:
	if FileAccess.file_exists(SaveService.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH))


func test_load_or_create_with_no_save_creates_and_persists_default() -> void:
	assert_false(FileAccess.file_exists(SaveService.SAVE_PATH))
	var s := SaveService.load_or_create("ASSASSIN")
	assert_eq(s.level, 1)
	assert_eq(s.subclass, "ASSASSIN")
	assert_true(FileAccess.file_exists(SaveService.SAVE_PATH))


func test_save_then_load_round_trips_state() -> void:
	var original := HunterState.new_default("MAGE")
	original.add_exp(250)
	original.essence = 40
	original.gate_tickets = 3
	SaveService.save(original)

	var loaded := SaveService.load_or_create()
	assert_eq(loaded.level, original.level)
	assert_eq(loaded.exp_into_level, original.exp_into_level)
	assert_eq(loaded.total_exp, original.total_exp)
	assert_eq(loaded.subclass, original.subclass)
	assert_eq(loaded.essence, original.essence)
	assert_eq(loaded.gate_tickets, original.gate_tickets)
