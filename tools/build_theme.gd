extends SceneTree
## Headless theme builder. Run: godot --headless --script res://tools/build_theme.gd
## Rebuilds res://ui/theme/hollowhunter.tres from the values below -- edit
## here, never hand-edit the .tres. Font is picked up automatically once
## res://ui/fonts/ChakraPetch-SemiBold.ttf exists (Task 5).

const OUT_PATH := "res://ui/theme/hollowhunter.tres"
const FRAME_TEX := "res://art/ui/ui_system_frame.webp"
const FONT_PATH := "res://ui/fonts/ChakraPetch-SemiBold.ttf"

const CYAN := Color(0.498, 0.941, 1.0, 1.0)


func _flat(
	bg: Color, border_a: float, radius: int, mh: int, mv: int, border_w: int = 2
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = Color(0.498, 0.941, 1.0, border_a)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	return sb


func _banner_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(FRAME_TEX)
	sb.texture_margin_left = 64.0
	sb.texture_margin_top = 64.0
	sb.texture_margin_right = 64.0
	sb.texture_margin_bottom = 64.0
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


func _initialize() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	if FileAccess.file_exists(FONT_PATH):
		t.default_font = load(FONT_PATH)

	# --- Button (standard) ---
	t.set_color("font_color", "Button", CYAN)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_focus_color", "Button", CYAN)
	t.set_color("font_disabled_color", "Button", Color(0.498, 0.941, 1.0, 0.35))
	t.set_font_size("font_size", "Button", 22)
	var btn_hover := _flat(Color(0.09, 0.15, 0.22, 0.98), 0.6, 6, 10, 6)
	t.set_stylebox("normal", "Button", _flat(Color(0.06, 0.10, 0.15, 0.95), 0.35, 6, 10, 6))
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", _flat(Color(0.04, 0.07, 0.11, 1.0), 0.8, 6, 10, 6))
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_stylebox("disabled", "Button", _flat(Color(0.05, 0.07, 0.09, 0.6), 0.12, 6, 10, 6))

	# --- BannerButton (variation of Button) ---
	t.add_type("BannerButton")
	t.set_type_variation("BannerButton", "Button")
	t.set_font_size("font_size", "BannerButton", 26)
	var banner_box := _banner_box()
	for s: String in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(s, "BannerButton", banner_box)

	# --- Panel ---
	var panel_sb := _flat(Color(0.03, 0.06, 0.10, 0.98), 0.20, 4, 0, 0, 1)
	t.set_stylebox("panel", "Panel", panel_sb)

	# --- Label ---
	t.set_color("font_color", "Label", CYAN)
	t.set_font_size("font_size", "Label", 22)
	t.set_constant("outline_size", "Label", 1)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))

	# --- Title (variation of Label) ---
	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	t.set_font_size("font_size", "Title", 30)

	# --- LineEdit ---
	t.set_color("font_color", "LineEdit", CYAN)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("selection_color", "LineEdit", Color(0.498, 0.941, 1.0, 0.25))
	t.set_color("font_placeholder_color", "LineEdit", Color(0.498, 0.941, 1.0, 0.35))
	t.set_stylebox("normal", "LineEdit", _flat(Color(0.04, 0.08, 0.12, 0.95), 0.3, 6, 10, 6))
	t.set_stylebox("focus", "LineEdit", _flat(Color(0.04, 0.08, 0.12, 0.95), 0.7, 6, 10, 6))

	# --- Scrollbars ---
	var g := StyleBoxFlat.new()
	g.bg_color = Color(0.498, 0.941, 1.0, 0.25)
	g.set_corner_radius_all(4)
	var gh := StyleBoxFlat.new()
	gh.bg_color = Color(0.498, 0.941, 1.0, 0.4)
	gh.set_corner_radius_all(4)
	var gp := StyleBoxFlat.new()
	gp.bg_color = Color(0.498, 0.941, 1.0, 0.55)
	gp.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.03)
	for cls: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", cls, g)
		t.set_stylebox("grabber_highlight", cls, gh)
		t.set_stylebox("grabber_pressed", cls, gp)
		t.set_stylebox("scroll", cls, track)

	var dir := DirAccess.open("res://")
	dir.make_dir_recursive("ui/theme")
	var err := ResourceSaver.save(t, OUT_PATH)
	print("[build_theme] saved %s err=%d" % [OUT_PATH, err])
	quit(0 if err == OK else 1)
