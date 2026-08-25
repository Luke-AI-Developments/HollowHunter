# System UI pop-up panels (§9c) — design spec

**Date:** 2026-08-26
**Status:** Approved by user, ready for implementation planning.

## Summary

`HollowHunter_Concept.md` §9c ("System UI — pop-up notification windows")
specifies a reusable "status window" pop-up — the LitRPG genre-trope visual
language (Solo Leveling, Overlord, etc.) — built around one reusable frame
asset, `art/ui/ui_system_frame.webp` (256×256, fully opaque RGB, angular
cyan corner-brackets on a dark glass fill — no separate background layer
needed, the texture already provides both). This was speced but never
built: every notification in the game today (gate results, Sanctuary/Lore
Stone claims, Stronghold collect, level-ups, the battle result screen,
gate-break alerts, permission errors, ...) goes through one plain,
unstyled status `Label` (`scenes/main.gd`'s `label.text += "\n\n..."`
pattern), reset to just the stats block by `_refresh_label()` before each
new message.

This spec builds the full §9c system in one pass: two reusable pop-up
tiers (Toast, Full ceremonial panel), the "glitch-in" materialize effect,
and reroutes every existing message call-site to the correct tier. The
persistent stats HUD gets the same frame styling as a static (non-animated,
non-dismissable) background, for visual consistency — it is not itself a
"pop-up" per §9c and keeps its current always-on behavior.

## Components

### `SystemToast` (`scenes/system_toast.gd`)

Small, corner-anchored, auto-dismisses after ~2s. One static node under
`GameUI` in `main.tscn`, reused for every toast (no queue — a new
`show_toast()` call while one is showing replaces its text and restarts
the fade timer, simplest v0 per YAGNI). Plain fade-in (no glitch — a toast
is a glance, not a moment), `AnimationPlayer`-free: a `Tween` animating
`modulate.a` from 0→1 on show, then a `Timer` (2.0s) that starts a second
`Tween` fading `modulate.a` 1→0 and setting `visible = false` on
completion.

```gdscript
## scenes/system_toast.gd
class_name SystemToast
extends Control

const DISPLAY_SECONDS := 2.0
const FADE_SECONDS := 0.25

@onready var frame: NinePatchRect = $Frame
@onready var text_label: Label = $Frame/Label
@onready var fade_timer: Timer = $FadeTimer

var _fade_tween: Tween


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
```

### `SystemPanel` (`scenes/system_panel.gd`)

Centered, full-screen dimming `Bg` (same `ColorRect` convention every
other panel in `main.tscn` already uses — `Color(0.05, 0.05, 0.05, 0.95)`),
modal (blocks input to everything behind it while showing, matching
`StrongholdPanel`/`GateBreakPanel`/etc.), tap-anywhere-to-dismiss, glitch-in
materialize on show.

**Glitch-in, kept cheap (no shaders):** a `Tween` alternating `modulate.a`
and a small horizontal `position` offset between a few values before
snapping to fully-opaque/zero-offset — reads as "flicker resolving into
place," not a soft fade.

```gdscript
## scenes/system_panel.gd
class_name SystemPanel
extends Control

signal dismissed

const GLITCH_STEP_SECONDS := 0.04
const GLITCH_OFFSET_PX := 6.0

@onready var bg: ColorRect = $Bg
@onready var frame: NinePatchRect = $Frame
@onready var header_label: Label = $Frame/HeaderLabel
@onready var divider: ColorRect = $Frame/Divider
@onready var body_label: Label = $Frame/BodyLabel

var _base_frame_position: Vector2


func _ready() -> void:
	visible = false
	_base_frame_position = frame.position
	gui_input.connect(_on_gui_input)


## header may be "" (no divider line drawn) for messages that are just a
## single block of body text (most Toast-tier-adjacent-but-important
## messages); non-empty header shows the glowing cyan divider under it.
func show_panel(header: String, body: String) -> void:
	header_label.text = header
	header_label.visible = not header.is_empty()
	divider.visible = not header.is_empty()
	body_label.text = body
	visible = true
	_play_glitch_in()


func _play_glitch_in() -> void:
	frame.modulate.a = 0.0
	frame.position = _base_frame_position
	var tween := create_tween()
	for i in 3:
		var offset := Vector2((randi() % 2) * 2 - 1, 0) * GLITCH_OFFSET_PX
		tween.tween_property(frame, "modulate:a", 0.3 + 0.3 * i, GLITCH_STEP_SECONDS)
		tween.parallel().tween_property(
			frame, "position", _base_frame_position + offset, GLITCH_STEP_SECONDS
		)
	tween.tween_property(frame, "modulate:a", 1.0, GLITCH_STEP_SECONDS)
	tween.parallel().tween_property(
		frame, "position", _base_frame_position, GLITCH_STEP_SECONDS
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		visible = false
		dismissed.emit()
```

`SystemPanel.dismissed` lets callers that need to chain a follow-up action
(none currently do — every existing call-site just fires-and-forgets a
message) hook in later without changing this component.

### HUD frame (static, no new script)

`main.tscn`'s existing `GameUI/Label` (now just the stats block, see
below) gets a `NinePatchRect` sibling placed immediately before it in the
tree (drawn first, so `Label` renders on top of it), using the same
`ui_system_frame.webp`, sized to wrap the stats block's existing
`(40,10)-(1040,200)` rect with a small margin: `(20,0)-(1060,210)`. No
script, no animation, always visible — `z_index` isn't needed for this
one specifically (it draws immediately before `Label`, which already has
`z_index = 1`, and `NinePatchRect` inherits nothing that would fight that).

### `NinePatchRect` texture setup (both `SystemToast` and `SystemPanel`, and the HUD frame)

`ui_system_frame.webp` is 256×256, fully opaque (no alpha channel — RGB,
not RGBA), corner brackets occupy roughly the outer quarter of the image.
`patch_margin_left/top/right/bottom = 64` on every `NinePatchRect` using
this texture (a reasonable starting value from the image's proportions —
confirm/adjust by eye during on-device verification, since 9-slice margin
tuning is inherently a visual judgment call no amount of pixel-counting
fully replaces).

## `main.tscn` changes

- Add `SystemToast` and `SystemPanel` node trees under `GameUI`, each with
  `z_index = 1` (same reasoning as `MarkerCard` — `MapView._draw_map_geometry()`
  opens with an opaque full-screen background rect every frame; without
  `z_index = 1` a new `GameUI` sibling silently renders behind it, the
  exact bug already found and fixed twice this session).
- `SystemToast` positioned top-right, below the HUD block (which spans
  nearly the full width): `(660,210)-(1040,290)`.
- `SystemPanel` centered: the root `SystemPanel` `Control` node's own rect
  must ALSO span the full `(0,0)-(1080,2424)` (not just its `Bg` child) —
  `gui_input` (used for tap-anywhere-to-dismiss) fires based on the node's
  own rect, not a child's visual extent, so a mismatch here would silently
  make most of the screen untappable for dismissal. `Bg` spans the same
  full rect (matches every other panel's `Bg`), `Frame` centered within
  it, sized generously for multi-line reward text: `(140,900)-(940,1600)`.
- Add the HUD `NinePatchRect` sibling immediately before `GameUI/Label`.

## Message routing — every existing call-site, by tier

**Toast** (`system_toast.show_toast(text)`):
- "GpsHealthBridge singleton not found"
- "GPS permission denied"
- "Health Connect not available" / "Health permission denied"
- "Welcome back — rest bonus applied to today's EXP!"
- "No GPS fix yet — can't place a ticket gate"
- "No gate tickets"
- "Ticket gate failed to spawn — ticket refunded"
- "Already claimed today" (Sanctuary card, disabled-action fallback)
- "Already discovered" (Lore Stone card, disabled-action fallback)
- Sanctuary claimed (+Essence, +Gate Ticket)
- Army panel's squad-full message
- Army panel's mass-convert result

**Full panel** (`system_panel.show_panel(header, body)`):
- Level up — header `"LEVEL UP!"`, body `"+%d"`
- Lore Stone discovered — header `"LORE STONE"`, body the snippet + Essence
  (narrative text deserves more than a 2s glance)
- Stronghold collected — header `"STRONGHOLD"`, body the Essence/Ticket/
  shadow-levels-gained breakdown
- Nadir floor cleared — header `"FLOOR CLEARED"` (or `"FLOOR FAILED"`),
  body Essence/loot/BOSS CLAIMED breakdown
- Rank Trial — header `"%s RANK TRIAL"`, body PASSED/FAILED + promotion
  reward
- Gate cleared/lost + battle result, merged (see below)
- Gate-break alert (existing `GateBreakPanel`'s Answer/Ignore prompt —
  restyle with the same frame; keeps its own two-button layout, doesn't
  become a generic `SystemPanel` call since it needs a choice, not a
  dismiss)

## Battle result + reward breakdown, merged

Today: `battle_view.gd`'s own `ResultLabel`/`CloseButton` show plain
VICTORY!/DEFEAT (just fixed this session — no longer overlapped by other
UI), then pressing Continue closes the battle screen and
`_on_battle_finished()` appends the loot/Essence/CLAIMED breakdown to the
corner label as a separate, disconnected step.

New flow: `_on_close_pressed()` still hides the battle screen and emits
`battle_finished`, but `_on_battle_finished()` now calls
`system_panel.show_panel(...)` with a header of `"VICTORY!"`/`"DEFEAT"`
and a body combining the existing gate-rank/monster-name line with the
existing loot/Essence/CLAIMED breakdown — one ceremonial moment instead of
two disjoint ones. `battle_view.gd`'s own `ResultLabel`/`CloseButton`
still exist and still show the immediate VICTORY!/DEFEAT the instant the
battle ends (that part of the flow is unchanged and already fixed) — this
change is only about what happens *after* Continue is pressed.

## Testing

No `core/` changes — entirely presentation. No automated tests:
`scenes/` is manually/on-device verified only per this project's
convention (no GUT harness for `Tween` animation, touch-dismiss, or
`Control` visibility). Manual on-device checklist:
- A Toast fires (e.g. tap an out-of-range Sanctuary marker) and auto-fades
  after ~2s without blocking input to the map underneath.
- A Full panel's glitch-in plays, tap-anywhere dismisses it, and nothing
  behind it was tappable while it was showing.
- Winning and losing a gate battle both produce the merged
  result+reward `SystemPanel`.
- The HUD's new frame doesn't reintroduce the "drawn behind `MapView`"
  bug (`z_index` ordering) — confirm the frame and stats text are both
  visible over the map on a fresh launch.
- Two rapid triggers of the same tier (e.g. two Toasts back to back)
  don't leave stale animation state (the replace-and-restart behavior in
  `show_toast()`/`show_panel()` above).

## Explicitly out of scope

- No queue for overlapping Toasts/Panels (last call wins, matching this
  project's existing "simplest v0" bias elsewhere).
- No changes to `GateBreakPanel`'s Answer/Ignore choice mechanic — only
  its visual frame.
- No changes to any `core/` file — this is a `scenes/`-only presentation
  layer rework.
- No scan-line shimmer shader (§9c mentions it as a nice-to-have; the
  glitch-in `Tween` above is the actual "materialize" effect specified as
  load-bearing — a shimmer overlay is a separate, purely decorative
  addition that can follow later if wanted).
