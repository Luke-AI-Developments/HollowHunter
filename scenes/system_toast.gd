class_name SystemToast
extends Control
## Small, corner-anchored, auto-dismissing notification (§9c "Toast" tier)
## for minor/routine messages -- errors, small rewards, warnings. Built
## around art/ui/ui_system_frame.webp (see Frame child's NinePatchRect).
## No queue: a new show_toast() call while one is already showing replaces
## its text and restarts the fade, simplest v0 (matches this project's
## existing bias elsewhere -- e.g. MarkerCard has no queue either).

const DISPLAY_SECONDS := 2.0
const FADE_SECONDS := 0.25

var _fade_tween: Tween

@onready var text_label: Label = $Frame/Label
@onready var fade_timer: Timer = $FadeTimer


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	fade_timer.timeout.connect(_on_fade_timer_timeout)


func show_toast(text: String) -> void:
	text_label.text = text
	visible = true
	fade_timer.stop()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	fade_timer.start(DISPLAY_SECONDS)


func _on_fade_timer_timeout() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_fade_tween.finished.connect(func() -> void: visible = false)
