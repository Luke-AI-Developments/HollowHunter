extends Node2D
## First scene on launch (run/main_scene). Purpose is purely the LOOK: force
## portrait orientation before anything visible, show the hero key-art on a
## near-black ground for a beat, then hand off to the real game scene. No
## content loading happens here -- scenes/main.gd._ready() still does all of
## that, synchronously and fast; this scene is not an async loader, just a
## branded curtain so the player never sees Godot's own landscape splash.
##
## Why it exists: on the custom Gradle Android build, Godot 4.7.1's engine
## startup calls Activity.setRequestedOrientation(LANDSCAPE) before any
## project script runs. Calling screen_set_orientation() again from our code
## (here, the earliest project code) runs after that and wins the race --
## same trick scenes/main.gd already uses, moved one scene earlier.

const MIN_SHOW_SEC := 0.7  ## how long the branded screen stays up before handing off
const MAIN_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	await get_tree().create_timer(MIN_SHOW_SEC).timeout
	get_tree().change_scene_to_file(MAIN_SCENE)
