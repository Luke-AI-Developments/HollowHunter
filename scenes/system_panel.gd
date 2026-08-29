class_name SystemPanel
extends Control
## Centered, modal, tap-anywhere-to-dismiss ceremonial pop-up (§9c "Full
## panel" tier) for moments that matter -- level-ups, rank-ups, gate/Nadir
## rewards, Stronghold collection. Built around art/ui/ui_system_frame.webp
## (see Frame child's NinePatchRect). Must be the LAST child of GameUI in
## main.tscn, with one permitted exception (ShadowRevealPanel, added after
## it in §6b/§6c): Godot's Control input hit-testing uses tree order, not
## z_index, so an earlier sibling would win input priority over this panel
## even while this panel is the one visually on top (the exact bug the
## tap-to-marker plan's final review caught as finding #1 -- see that
## plan's ledger). ShadowRevealPanel is safe as a later sibling because
## _on_gui_input() sets visible = false before emitting dismissed, so this
## panel and ShadowRevealPanel are never visible at the same time -- but
## any OTHER later panel would reintroduce the bug. No queue: a new
## show_panel() call while one is already showing replaces its content and
## restarts the glitch-in.

signal dismissed

const GLITCH_STEP_SECONDS := 0.04
const GLITCH_OFFSET_PX := 6.0

var _base_frame_position: Vector2
var _glitch_tween: Tween

@onready var frame: NinePatchRect = $Frame
@onready var header_label: Label = $Frame/HeaderLabel
@onready var divider: ColorRect = $Frame/Divider
@onready var body_label: Label = $Frame/BodyLabel


func _ready() -> void:
	visible = false
	_base_frame_position = frame.position
	gui_input.connect(_on_gui_input)


## header may be "" (no divider line drawn) for messages that are just a
## single block of body text; non-empty header shows the glowing cyan
## divider under it.
func show_panel(header: String, body: String) -> void:
	header_label.text = header
	header_label.visible = not header.is_empty()
	divider.visible = not header.is_empty()
	body_label.text = body
	visible = true
	_play_glitch_in()


func _play_glitch_in() -> void:
	if _glitch_tween != null and _glitch_tween.is_valid():
		_glitch_tween.kill()
	frame.modulate.a = 0.0
	frame.position = _base_frame_position
	_glitch_tween = create_tween()
	for i in 3:
		var offset := Vector2((randi() % 2) * 2 - 1, 0) * GLITCH_OFFSET_PX
		_glitch_tween.tween_property(frame, "modulate:a", 0.3 + 0.3 * i, GLITCH_STEP_SECONDS)
		_glitch_tween.parallel().tween_property(
			frame, "position", _base_frame_position + offset, GLITCH_STEP_SECONDS
		)
	_glitch_tween.tween_property(frame, "modulate:a", 1.0, GLITCH_STEP_SECONDS)
	_glitch_tween.parallel().tween_property(
		frame, "position", _base_frame_position, GLITCH_STEP_SECONDS
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		visible = false
		dismissed.emit()
