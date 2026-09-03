class_name StatBar
extends Control
## A draw-based horizontal stat bar (HP / break / gauge). Colour-by-fraction
## for HP; flat amber/gold for break/gauge. `flash()` runs a one-shot white
## pulse for "value just changed hard" moments. All colours/thresholds are v0
## (sub-project C tunes them).

const _TRACK := Color(0.05, 0.13, 0.19)
const _BREAK := Color(0.91, 0.66, 0.29)  ## v0
const _GAUGE := Color(1.0, 0.82, 0.36)  ## v0
const _HP_HIGH := Color(0.34, 0.88, 0.54)  ## v0: fraction >= 0.5
const _HP_MID := Color(0.91, 0.76, 0.29)  ## v0: 0.2 <= fraction < 0.5
const _HP_LOW := Color(0.91, 0.38, 0.29)  ## v0: fraction < 0.2

var _frac: float = 1.0
var _palette: String = "hp"
var _flash: float = 0.0


static func hp_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return _HP_HIGH
	if fraction >= 0.2:
		return _HP_MID
	return _HP_LOW


func set_values(current: float, maximum: float) -> void:
	_frac = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	queue_redraw()


func set_palette(palette: String) -> void:
	_palette = palette
	queue_redraw()


func flash() -> void:
	_flash = 1.0
	var t := create_tween()
	t.tween_method(_set_flash, 1.0, 0.0, 0.2)


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _fill_color() -> Color:
	match _palette:
		"break":
			return _BREAK
		"gauge":
			return _GAUGE
		_:
			return hp_color(_frac)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, _TRACK)
	if _frac > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _frac, size.y)), _fill_color())
	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, 0.6 * _flash))
