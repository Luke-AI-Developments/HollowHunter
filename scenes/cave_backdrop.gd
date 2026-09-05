class_name CaveBackdrop
extends Control
## Battle VFX Polish §2: a static, drawn cave backdrop behind the enemy arena
## -- one shared look for every battle, no animation, no particles, no
## parallax (same constraints the original battle-screen rebuild set for
## itself). Built from a vertical GradientTexture2D (near-black top, warm
## ember-brown bottom) plus two hand-authored jagged rock-silhouette polygons
## framing the top (stalactites) and bottom (cave floor) edges. All literals
## here are new v0 palette/shape choices -- there is nothing existing to
## inherit from, so every one is tagged.

const _TOP_COLOR := Color(0.02, 0.03, 0.05)  ## v0
const _BOTTOM_COLOR := Color(0.08, 0.05, 0.04)  ## v0
const _ROCK_COLOR := Color(0.01, 0.01, 0.015, 0.95)  ## v0

var _gradient_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, _TOP_COLOR)
	grad.set_color(1, _BOTTOM_COLOR)
	_gradient_tex = GradientTexture2D.new()
	_gradient_tex.gradient = grad
	_gradient_tex.fill = GradientTexture2D.FILL_LINEAR
	_gradient_tex.fill_from = Vector2(0.5, 0.0)
	_gradient_tex.fill_to = Vector2(0.5, 1.0)
	_gradient_tex.width = 4
	_gradient_tex.height = 64
	queue_redraw()


func set_band_size(band_size: Vector2) -> void:
	size = band_size
	queue_redraw()


func _draw() -> void:
	if _gradient_tex == null:
		return
	draw_texture_rect(_gradient_tex, Rect2(Vector2.ZERO, size), false)
	var w := size.x
	## v0: a jagged stalactite silhouette across the top ~14% of the band.
	var top_h := size.y * 0.14  ## v0
	var top_points := PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(0, top_h * 0.3),
			Vector2(w * 0.08, top_h),
			Vector2(w * 0.18, top_h * 0.4),
			Vector2(w * 0.3, top_h * 0.9),
			Vector2(w * 0.42, top_h * 0.25),
			Vector2(w * 0.55, top_h),
			Vector2(w * 0.68, top_h * 0.35),
			Vector2(w * 0.8, top_h * 0.85),
			Vector2(w * 0.92, top_h * 0.3),
			Vector2(w, top_h * 0.5),
			Vector2(w, 0),
		]
	)
	draw_colored_polygon(top_points, _ROCK_COLOR)
	## v0: a jagged cave-floor silhouette across the bottom ~10% of the band.
	var bot_h := size.y * 0.1  ## v0
	var bot_y := size.y
	var bot_points := PackedVector2Array(
		[
			Vector2(0, bot_y),
			Vector2(0, bot_y - bot_h * 0.4),
			Vector2(w * 0.12, bot_y - bot_h),
			Vector2(w * 0.25, bot_y - bot_h * 0.3),
			Vector2(w * 0.4, bot_y - bot_h * 0.9),
			Vector2(w * 0.55, bot_y - bot_h * 0.25),
			Vector2(w * 0.7, bot_y - bot_h * 0.8),
			Vector2(w * 0.85, bot_y - bot_h * 0.3),
			Vector2(w, bot_y - bot_h * 0.5),
			Vector2(w, bot_y),
		]
	)
	draw_colored_polygon(bot_points, _ROCK_COLOR)
