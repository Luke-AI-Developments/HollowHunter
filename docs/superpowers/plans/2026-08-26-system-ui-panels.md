# System UI Pop-up Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the never-implemented §9c "System UI" pop-up system — a small auto-fading `SystemToast` and a centered, glitch-in, tap-to-dismiss `SystemPanel`, both framed with `art/ui/ui_system_frame.webp` — and reroute every existing status-label message to the correct tier, including merging the battle result screen with its post-battle reward breakdown into one ceremonial moment.

**Architecture:** Two new reusable `scenes/` components (`SystemToast`, `SystemPanel`), each a thin presentation controller with no game logic. Every existing `label.text += "..."` call-site in `scenes/main.gd` (plus one signal split in `scenes/stronghold_view.gd` and the battle-result flow in `scenes/battle_view.gd`) gets rerouted to call one of the two new components instead. The persistent stats HUD gets the same frame texture as a static, non-animated background.

**Tech Stack:** Godot 4.7.1 mono, GDScript, `Tween`/`Timer` for animation (no shaders, no GUT tests — `scenes/` is manually verified only per this project's convention).

## Global Constraints

- No `core/` changes anywhere in this plan — entirely a `scenes/` presentation rework.
- Every new `GameUI`-level node this plan adds (`SystemToast`, `SystemPanel`) MUST be the **last** children under `GameUI` in `main.tscn` (after `BattlePanel`), AND have `z_index = 1`. Both parts are load-bearing, for two different, both-already-proven-real bugs this session: (1) `z_index = 1` is required or `MapView`'s opaque per-frame background silently paints over the node (the status-Label bug, fixed twice already); (2) Godot's Control input hit-testing uses **tree order, not z_index** — a node earlier in the tree loses input priority to a later sibling even if it visually renders on top (the tap-to-marker final review's finding #1). `SystemPanel` is modal (tap-anywhere-to-dismiss) and must win input priority over any panel that happens to be open underneath it — being the last child is what guarantees that, `z_index` alone does not.
- Every message string migrated from `label.text += "\n\n..."` loses its leading `\n\n` (that formatting existed only for concatenation onto the shared label, which no longer happens) — either edit the literal directly (call-sites owned by `main.gd`) or call `.lstrip("\n")` on strings arriving from another script's signal (call-sites this plan doesn't otherwise touch).
- `ui_system_frame.webp` is 256×256, fully opaque (RGB, no alpha). Every `NinePatchRect` using it sets `patch_margin_left/top/right/bottom = 64`.
- Static typing everywhere, tabs for indentation, gdformat/gdlint clean — **verify explicitly with `python -m gdtoolkit.formatter --diff <file>` and `python -m gdtoolkit.linter <file>` before every commit**, don't just trust the post-edit hook (it missed a real formatting issue twice already this session).
- `SystemToast.show_toast()` / `SystemPanel.show_panel()` have no queue — a new call while one is already showing replaces its content and restarts the animation/timer (simplest v0, matches this project's existing bias elsewhere).
- Godot executable: `C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe`. Full GUT suite: `"<that exe>" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` — every task in this plan must still show 511/511 passing (no new tests, this plan touches no `core/` file).

---

### Task 1: `SystemToast` component + all Toast-tier message routing

**Files:**
- Create: `scenes/system_toast.gd`
- Modify: `scenes/main.tscn` (add `SystemToast` node tree, add the shared `ui_system_frame.webp` `ExtResource`)
- Modify: `scenes/main.gd` (add `@onready var system_toast`, reroute every Toast-tier call-site)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `SystemToast.show_toast(text: String) -> void`, used directly by this task and read (but not called) by no other task — Toast-tier is fully self-contained in this one task. The shared texture `ExtResource("15")` (`res://art/ui/ui_system_frame.webp`) is declared here and reused verbatim by Tasks 2, 3, and 5.

- [ ] **Step 1: Add the shared texture resource and bump `load_steps`**

In `scenes/main.tscn`, change line 1 from `[gd_scene load_steps=13 format=3]` to `[gd_scene load_steps=16 format=3]` (2 new scripts across this plan's tasks + 1 shared texture), and add after the existing `id="12"` script resource line:

```
[ext_resource type="Script" path="res://scenes/system_toast.gd" id="13"]
[ext_resource type="Texture2D" path="res://art/ui/ui_system_frame.webp" id="15"]
```

(`id="14"` is reserved for Task 2's `system_panel.gd` — added there, not here, so the two tasks' diffs don't collide on the same line.)

- [ ] **Step 2: Add the `SystemToast` node tree**

In `scenes/main.tscn`, insert immediately before the `[node name="BattlePanel"...]` block's own closing (i.e. as the very last child of `GameUI`, after every other node — find the last line of the file's `GameUI`-parented content and append after it, right before any non-`GameUI` content that follows, or at end of file if `BattlePanel`'s subtree is the last content):

```
[node name="SystemToast" type="Control" parent="GameUI"]
visible = false
z_index = 1
offset_left = 660.0
offset_top = 210.0
offset_right = 1040.0
offset_bottom = 290.0
script = ExtResource("13")

[node name="Frame" type="NinePatchRect" parent="GameUI/SystemToast"]
offset_left = 0.0
offset_top = 0.0
offset_right = 380.0
offset_bottom = 80.0
texture = ExtResource("15")
patch_margin_left = 64
patch_margin_top = 64
patch_margin_right = 64
patch_margin_bottom = 64

[node name="Label" type="Label" parent="GameUI/SystemToast/Frame"]
offset_left = 16.0
offset_top = 12.0
offset_right = 364.0
offset_bottom = 68.0
theme_override_colors/font_color = Color(0.498, 0.941, 1.0, 1.0)
theme_override_font_sizes/font_size = 18
autowrap_mode = 3
text = ""

[node name="FadeTimer" type="Timer" parent="GameUI/SystemToast"]
one_shot = true
```

(`Color(0.498, 0.941, 1.0, 1.0)` is `#7ff0ff`, §9c's icy-white/cyan text color.)

- [ ] **Step 3: Write `scenes/system_toast.gd`**

```gdscript
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

- [ ] **Step 4: Format and lint**

```bash
python -m gdtoolkit.formatter --diff scenes/system_toast.gd
python -m gdtoolkit.linter scenes/system_toast.gd
```

Expected: both clean (`1 file would be left unchanged`, `Success: no problems found`).

- [ ] **Step 5: Wire `system_toast` into `main.gd` and reroute every Toast-tier call-site**

Add alongside the other `@onready var` declarations in `scenes/main.gd` (near `marker_card`):

```gdscript
@onready var system_toast: SystemToast = $GameUI/SystemToast
```

Replace each of the following exact current lines/blocks with the shown replacement:

`scenes/main.gd` around line 127 (inside `_ready()`):
```gdscript
		label.text += "\n\nGpsHealthBridge singleton not found"
```
becomes:
```gdscript
		system_toast.show_toast("GpsHealthBridge singleton not found")
```

Around line 315 (`_on_location_permission_result`):
```gdscript
		label.text += "\n\nGPS permission denied"
```
becomes:
```gdscript
		system_toast.show_toast("GPS permission denied")
```

Around line 337 (`_on_health_connect_available`):
```gdscript
		label.text += "\n\nHealth Connect not available"
```
becomes:
```gdscript
		system_toast.show_toast("Health Connect not available")
```

Around line 347 (`_on_health_permission_result`):
```gdscript
		label.text += "\n\nHealth permission denied"
```
becomes:
```gdscript
		system_toast.show_toast("Health permission denied")
```

Around line 407 (`_maybe_apply_daily_exp`, the `rest_bonus` branch only — leave the `levels_gained > 0` branch immediately below it untouched, that one is Task 2's):
```gdscript
	if rest_bonus:
		# Positive, non-comparative framing (§27) -- a welcome-back note,
		# not a "you fell behind" one.
		label.text += "\n\nWelcome back -- rest bonus applied to today's EXP!"
```
becomes:
```gdscript
	if rest_bonus:
		# Positive, non-comparative framing (§27) -- a welcome-back note,
		# not a "you fell behind" one.
		system_toast.show_toast("Welcome back -- rest bonus applied to today's EXP!")
```

Around line 761 (`_on_use_ticket_pressed`):
```gdscript
	if not _has_location:
		label.text += "\n\nNo GPS fix yet -- can't place a ticket gate"
		return
	if not state.spend_gate_ticket():
		label.text += "\n\nNo gate tickets"
		return
```
becomes:
```gdscript
	if not _has_location:
		system_toast.show_toast("No GPS fix yet -- can't place a ticket gate")
		return
	if not state.spend_gate_ticket():
		system_toast.show_toast("No gate tickets")
		return
```

Same function, a few lines further down:
```gdscript
		state.gate_tickets += 1
		label.text += "\n\nTicket gate failed to spawn -- ticket refunded"
		return
```
becomes:
```gdscript
		state.gate_tickets += 1
		system_toast.show_toast("Ticket gate failed to spawn -- ticket refunded")
		return
```

Around line 825 (`_claim_sanctuary`):
```gdscript
	if not claimed:
		label.text += "\n\nAlready claimed today"
		return
	SaveService.save(state)
	_refresh_label()
	label.text += (
		"\n\nSanctuary claimed: +%d Essence, +%d Gate Ticket"
		% [GameLogic.SANCTUARY_ESSENCE_REWARD, GameLogic.SANCTUARY_TICKET_REWARD]
	)
```
becomes:
```gdscript
	if not claimed:
		system_toast.show_toast("Already claimed today")
		return
	SaveService.save(state)
	_refresh_label()
	system_toast.show_toast(
		"Sanctuary claimed: +%d Essence, +%d Gate Ticket"
		% [GameLogic.SANCTUARY_ESSENCE_REWARD, GameLogic.SANCTUARY_TICKET_REWARD]
	)
```

Around line 839 (`_discover_lorestone`), only the "already discovered" early-return -- the successful-discovery branch below it is Task 2's (it becomes a Full panel, since it carries the lore snippet):
```gdscript
	if not discovered:
		label.text += "\n\nAlready discovered"
		return
```
becomes:
```gdscript
	if not discovered:
		system_toast.show_toast("Already discovered")
		return
```

In `_setup_gear_panels()` (around line 266-267):
```gdscript
		army_view.mass_convert_result.connect(func(msg: String) -> void: label.text += msg)
		army_view.squad_full_message.connect(func(msg: String) -> void: label.text += msg)
```
becomes:
```gdscript
		army_view.mass_convert_result.connect(
			func(msg: String) -> void: system_toast.show_toast(msg.lstrip("\n"))
		)
		army_view.squad_full_message.connect(
			func(msg: String) -> void: system_toast.show_toast(msg.lstrip("\n"))
		)
```

- [ ] **Step 6: Format and lint `main.gd`**

```bash
python -m gdtoolkit.formatter --diff scenes/main.gd
python -m gdtoolkit.linter scenes/main.gd
```

- [ ] **Step 7: Run the full test suite**

```bash
"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 511/511 passing (no `core/` changes in this task).

- [ ] **Step 8: On-device sanity check**

Build, install, launch (see `native/android/README.md` for the full export/sign/install pipeline this project already uses). Tap an out-of-range Sanctuary or Lore Stone marker card's action button, or trigger "No gate tickets" via the Use Ticket flow with zero tickets — confirm a small framed cyan toast appears top-right, fades in, and auto-fades after ~2s without blocking taps elsewhere on the map.

- [ ] **Step 9: Commit**

```bash
git add scenes/system_toast.gd scenes/main.tscn scenes/main.gd
git commit -m "feat: add SystemToast component and route Toast-tier messages to it"
```

---

### Task 2: `SystemPanel` component + non-battle Full-panel message routing

**Files:**
- Create: `scenes/system_panel.gd`
- Modify: `scenes/main.tscn` (add `SystemPanel` node tree, add `system_panel.gd`'s `ExtResource`)
- Modify: `scenes/main.gd` (add `@onready var system_panel`, reroute Level-up/Lore-Stone-discovered/Rank-Trial call-sites)
- Modify: `scenes/stronghold_view.gd` (split the `collected` signal: a new `proximity_denied` signal for the three "Not near your Stronghold" emits, `collected` keeps only the real reward summary)

**Interfaces:**
- Consumes: `ExtResource("15")` (`ui_system_frame.webp`) declared by Task 1.
- Produces: `SystemPanel.show_panel(header: String, body: String) -> void` and `SystemPanel.dismissed` signal, both used directly by this task and consumed by Task 4 (battle result merge) and Task 5 (this task's `system_panel` reference is what Task 5's `GateBreakPanel` restyle visually matches, though Task 5 doesn't call `show_panel` itself — `GateBreakPanel` keeps its own Answer/Ignore choice, it only reuses the frame texture). `StrongholdView.proximity_denied` (new, no-arg signal) is produced here and consumed only within this task's own `main.gd` wiring.

- [ ] **Step 1: Add `system_panel.gd`'s `ExtResource`**

In `scenes/main.tscn`, add after the `id="13"` line Task 1 added:

```
[ext_resource type="Script" path="res://scenes/system_panel.gd" id="14"]
```

- [ ] **Step 2: Add the `SystemPanel` node tree**

Insert as the last child of `GameUI` (after `SystemToast`, so it remains the true last child per the Global Constraints input-priority rule):

```
[node name="SystemPanel" type="Control" parent="GameUI"]
visible = false
z_index = 1
offset_left = 0.0
offset_top = 0.0
offset_right = 1080.0
offset_bottom = 2424.0
script = ExtResource("14")

[node name="Bg" type="ColorRect" parent="GameUI/SystemPanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 1080.0
offset_bottom = 2424.0
color = Color(0.05, 0.05, 0.05, 0.95)

[node name="Frame" type="NinePatchRect" parent="GameUI/SystemPanel"]
offset_left = 140.0
offset_top = 900.0
offset_right = 940.0
offset_bottom = 1600.0
texture = ExtResource("15")
patch_margin_left = 64
patch_margin_top = 64
patch_margin_right = 64
patch_margin_bottom = 64

[node name="HeaderLabel" type="Label" parent="GameUI/SystemPanel/Frame"]
offset_left = 40.0
offset_top = 40.0
offset_right = 760.0
offset_bottom = 90.0
theme_override_colors/font_color = Color(0.498, 0.941, 1.0, 1.0)
theme_override_font_sizes/font_size = 32
horizontal_alignment = 1
text = ""

[node name="Divider" type="ColorRect" parent="GameUI/SystemPanel/Frame"]
offset_left = 40.0
offset_top = 100.0
offset_right = 760.0
offset_bottom = 104.0
color = Color(0.498, 0.941, 1.0, 0.6)

[node name="BodyLabel" type="Label" parent="GameUI/SystemPanel/Frame"]
offset_left = 40.0
offset_top = 130.0
offset_right = 760.0
offset_bottom = 660.0
theme_override_colors/font_color = Color(0.498, 0.941, 1.0, 1.0)
theme_override_font_sizes/font_size = 24
autowrap_mode = 3
text = ""
```

- [ ] **Step 3: Write `scenes/system_panel.gd`**

```gdscript
class_name SystemPanel
extends Control
## Centered, modal, tap-anywhere-to-dismiss ceremonial pop-up (§9c "Full
## panel" tier) for moments that matter -- level-ups, rank-ups, gate/Nadir
## rewards, Stronghold collection. Built around art/ui/ui_system_frame.webp
## (see Frame child's NinePatchRect). Must be the LAST child of GameUI in
## main.tscn: Godot's Control input hit-testing uses tree order, not
## z_index, so an earlier sibling would win input priority over this panel
## even while this panel is the one visually on top (the exact bug the
## tap-to-marker plan's final review caught as finding #1 -- see that
## plan's ledger). No queue: a new show_panel() call while one is already
## showing replaces its content and restarts the glitch-in.

signal dismissed

const GLITCH_STEP_SECONDS := 0.04
const GLITCH_OFFSET_PX := 6.0

@onready var frame: NinePatchRect = $Frame
@onready var header_label: Label = $Frame/HeaderLabel
@onready var divider: ColorRect = $Frame/Divider
@onready var body_label: Label = $Frame/BodyLabel

var _base_frame_position: Vector2
var _glitch_tween: Tween


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
```

- [ ] **Step 4: Format and lint**

```bash
python -m gdtoolkit.formatter --diff scenes/system_panel.gd
python -m gdtoolkit.linter scenes/system_panel.gd
```

- [ ] **Step 5: Split `StrongholdView.collected` into `collected` (reward summary) and `proximity_denied` (the "Not near" gate)**

In `scenes/stronghold_view.gd`, add the new signal alongside the existing ones near the top of the file:

```gdscript
signal proximity_denied
```

Replace all three occurrences of this exact line:
```gdscript
		collected.emit("\n\nNot near your Stronghold")
```
with:
```gdscript
		proximity_denied.emit()
```

(These occur in `_on_assign_pressed()`, `_on_unassign_pressed()`, and `_on_collect_pressed()` — three separate functions, each with one occurrence. Leave the real `collected.emit(msg)` call at the end of `_on_collect_pressed()` — the one built from `result["essence_gained"]`/`result["tickets_gained"]`/`shadow_levels_gained` — completely unchanged; that one stays `collected`.)

- [ ] **Step 6: Format and lint `stronghold_view.gd`**

```bash
python -m gdtoolkit.formatter --diff scenes/stronghold_view.gd
python -m gdtoolkit.linter scenes/stronghold_view.gd
```

- [ ] **Step 7: Wire `system_panel` into `main.gd` and reroute the non-battle Full-panel call-sites**

Add alongside the other `@onready var` declarations:

```gdscript
@onready var system_panel: SystemPanel = $GameUI/SystemPanel
```

Replace each exact current block:

Around line 409 (`_maybe_apply_daily_exp`, the `levels_gained > 0` branch):
```gdscript
	if levels_gained > 0:
		label.text += "\n\nLEVEL UP! (+%d)" % levels_gained
```
becomes:
```gdscript
	if levels_gained > 0:
		system_panel.show_panel("LEVEL UP!", "+%d" % levels_gained)
```

Around line 844 (`_discover_lorestone`, the successful-discovery tail):
```gdscript
	SaveService.save(state)
	_refresh_label()
	var lore_index: int = stone["lore_index"]
	label.text += (
		"\n\n%s\n(+%d Essence)"
		% [PoiSpawner.LORE_SNIPPETS[lore_index], GameLogic.LORESTONE_ESSENCE_REWARD]
	)
```
becomes:
```gdscript
	SaveService.save(state)
	_refresh_label()
	var lore_index: int = stone["lore_index"]
	system_panel.show_panel(
		"LORE STONE",
		"%s\n(+%d Essence)" % [PoiSpawner.LORE_SNIPPETS[lore_index], GameLogic.LORESTONE_ESSENCE_REWARD]
	)
```

In `_setup_gear_panels()`, the `stronghold_view.collected` line:
```gdscript
		stronghold_view.collected.connect(func(msg: String) -> void: label.text += msg)
```
becomes two lines (the new `proximity_denied` connection plus the retargeted `collected` connection):
```gdscript
		stronghold_view.collected.connect(
			func(msg: String) -> void: system_panel.show_panel("STRONGHOLD", msg.lstrip("\n"))
		)
		stronghold_view.proximity_denied.connect(
			func() -> void: system_toast.show_toast("Not near your Stronghold")
		)
```

`_on_character_trial_result()` (around line 1035-1037):
```gdscript
func _on_character_trial_result(msg: String) -> void:
	character_view.refresh(_steps, _workouts_json, _gps_status, _health_status)
	label.text += msg
```
becomes:
```gdscript
func _on_character_trial_result(msg: String) -> void:
	character_view.refresh(_steps, _workouts_json, _gps_status, _health_status)
	system_panel.show_panel("RANK TRIAL", msg.lstrip("\n"))
```

- [ ] **Step 8: Format and lint `main.gd`**

```bash
python -m gdtoolkit.formatter --diff scenes/main.gd
python -m gdtoolkit.linter scenes/main.gd
```

- [ ] **Step 9: Run the full test suite**

```bash
"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 511/511 passing.

- [ ] **Step 10: On-device sanity check**

Build, install, launch. Trigger a Lore Stone discovery (or a Stronghold collect while in range) — confirm the glitch-in plays, the frame/header/divider/body render correctly, tapping anywhere dismisses it, and while it's showing, taps on anything behind it (nav bar, map markers) do nothing until it's dismissed.

- [ ] **Step 11: Commit**

```bash
git add scenes/system_panel.gd scenes/main.tscn scenes/main.gd scenes/stronghold_view.gd
git commit -m "feat: add SystemPanel component and route non-battle Full-panel messages to it"
```

---

### Task 3: Persistent stats HUD frame

**Files:**
- Modify: `scenes/main.tscn` (add a static `NinePatchRect` sibling immediately before `GameUI/Label`)

**Interfaces:**
- Consumes: `ExtResource("15")` (`ui_system_frame.webp`) declared by Task 1.
- Produces: nothing consumed by other tasks — this is a self-contained visual change.

- [ ] **Step 1: Add the HUD frame node**

In `scenes/main.tscn`, insert immediately before the existing `[node name="Label" type="Label" parent="GameUI"]` block (so it draws first, `Label` draws on top of it):

```
[node name="HudFrame" type="NinePatchRect" parent="GameUI"]
offset_left = 20.0
offset_top = 0.0
offset_right = 1060.0
offset_bottom = 210.0
texture = ExtResource("15")
patch_margin_left = 64
patch_margin_top = 64
patch_margin_right = 64
patch_margin_bottom = 64
```

No `z_index` needed on this specific node — it draws immediately before `Label`, which already has `z_index = 1` from the earlier session fix, so `HudFrame` inherits the same effective stacking (a `NinePatchRect` with no `z_index` set defaults to 0, but `z_as_relative` defaults to `true` and there is no ancestor `CanvasLayer`/`z_index` override between it and `GameUI`, so its absolute z stays 0 — meaning it still needs to render before `MapView` wins by tree order alone; since it's declared BEFORE `MapView` in the file... wait, no: check tree order below).

**Correctness check before finalizing this step — do not skip:** `Label` (z_index 1) already renders above `MapView` (z_index 0) regardless of tree order, because z_index is compared first. `HudFrame` as written above has no `z_index`, defaulting to 0 — the SAME z_index as `MapView`. Within the same z_index, tree order decides, and `HudFrame` (declared before `MapView` in the file) would lose to `MapView` and render BEHIND the map background, reintroducing the exact bug this plan's Global Constraints warn about. **Add `z_index = 1` to `HudFrame` too** — the block above is missing it; the corrected node must read:

```
[node name="HudFrame" type="NinePatchRect" parent="GameUI"]
z_index = 1
offset_left = 20.0
offset_top = 0.0
offset_right = 1060.0
offset_bottom = 210.0
texture = ExtResource("15")
patch_margin_left = 64
patch_margin_top = 64
patch_margin_right = 64
patch_margin_bottom = 64
```

- [ ] **Step 2: Format and lint**

`.tscn` files aren't covered by gdformat/gdlint (those check `.gd` only) — no lint step needed for this task.

- [ ] **Step 3: Run the full test suite**

```bash
"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 511/511 passing (this task touches no `.gd` file at all).

- [ ] **Step 4: On-device sanity check**

Build, install, launch. Confirm the framed border renders behind the stats text at the top of the screen on a fresh launch, over the map, not behind it.

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn
git commit -m "feat: frame the persistent stats HUD with the system UI border"
```

---

### Task 4: Battle result + reward breakdown, merged into one `SystemPanel` moment

**Files:**
- Modify: `scenes/main.gd` (`_on_battle_finished()` and `_apply_nadir_battle_result()`)

**Interfaces:**
- Consumes: `SystemPanel.show_panel(header: String, body: String)` from Task 2.
- Produces: nothing consumed elsewhere — last task touching `main.gd`.

- [ ] **Step 1: Merge the gate-battle branch**

In `scenes/main.gd`, `_on_battle_finished()` currently ends (after the `if won:` block that builds up `msg`) with:

```gdscript
	SaveService.save(state)
	_refresh_label()
	army_view.refresh_if_open()
```

Change the function's opening `msg` construction and its ending to route through `SystemPanel` instead of the shared label. The full corrected function:

```gdscript
func _on_battle_finished(won: bool) -> void:
	if _pending_nadir_floor >= 0:
		_apply_nadir_battle_result(won)
		return

	var gate := _pending_battle_gate
	var is_break := _pending_battle_is_break
	var header := "VICTORY!" if won else "DEFEAT"
	var body := (
		_pending_battle_prefix.lstrip("\n")
		+ "%s gate (%s): %s" % [gate["rank"], gate["monster_name"], "CLEARED" if won else "LOST"]
	)
	_pending_battle_gate = {}
	_pending_battle_prefix = ""
	_pending_battle_is_break = false

	if won:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GameLogic.attempt_claim(gate.get("monster_extract_chance", 0.0), state.level, rng):
			state.claim_shadow(gate["monster_id"], gate["rank"])
			body += "\nCLAIMED! %s joins your army." % gate["monster_name"]
		else:
			body += "\nBoss escaped (claim failed)."

		var drop := Loot.roll_drop(gate["rank"], _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			body += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]
		var essence_gain := GameLogic.essence_for_gate(gate["rank"])
		if is_break:
			essence_gain = GateBreak.bonus_essence(essence_gain)
			state.gate_tickets += GateBreak.BREAK_TICKET_BONUS
			body += "\n+%d Gate Ticket(s) (Gate Break bonus)" % GateBreak.BREAK_TICKET_BONUS
		elif gate.get("incursion_bonus", false):
			essence_gain = Incursion.bonus_essence(essence_gain)
			body += "\n(Incursion bonus)"
		state.essence += essence_gain
		body += "\nEssence +%d" % essence_gain

	SaveService.save(state)
	_refresh_label()
	army_view.refresh_if_open()
	system_panel.show_panel(header, body)
```

(`_pending_battle_prefix` is set to values like `"\n\n[Ticket]"`/`"\n\n[GATE BREAK]"` elsewhere in this file — `.lstrip("\n")` handles both the normal empty-string case and those prefixed cases without needing to touch every place `_pending_battle_prefix` gets assigned.)

- [ ] **Step 2: Merge the Nadir-floor branch**

`_apply_nadir_battle_result()` currently ends with:

```gdscript
	SaveService.save(state)
	_refresh_nadir_panel()
	army_view.refresh_if_open()
	_refresh_label()
	label.text += msg
```

And builds `msg` starting from:

```gdscript
	var msg := "\n\nNadir Floor %d: %s" % [floor_n, "CLEARED" if won else "LOST"]
```

Change the construction to build a separate `header`/`body` instead of one `msg` string, and change the ending to call `system_panel.show_panel`:

```gdscript
	var header := "FLOOR CLEARED" if won else "FLOOR FAILED"
	var body := "Nadir Floor %d" % floor_n
```

(replaces the `var msg := "\n\nNadir Floor %d: %s" % [...]` line), then every subsequent `msg +=` line in this function (essence gain, loot, boss-claimed/escaped) becomes `body +=` instead — same right-hand-side text on each, only the variable name changes. Finally:

```gdscript
	SaveService.save(state)
	_refresh_nadir_panel()
	army_view.refresh_if_open()
	_refresh_label()
	system_panel.show_panel(header, body)
```

- [ ] **Step 3: Format and lint**

```bash
python -m gdtoolkit.formatter --diff scenes/main.gd
python -m gdtoolkit.linter scenes/main.gd
```

- [ ] **Step 4: Run the full test suite**

```bash
"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 511/511 passing.

- [ ] **Step 5: On-device sanity check**

Win a gate battle (tap a gate marker, then Skip/fight to completion, then press the battle screen's own Continue button — that part is unchanged from this session's earlier fix). Confirm one `SystemPanel` appears showing both the CLEARED/LOST line and the full loot/Essence/CLAIMED breakdown together, not two separate steps. Repeat for a lost battle, and for a Nadir floor if reachable.

- [ ] **Step 6: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: merge battle result and reward breakdown into one SystemPanel moment"
```

---

### Task 5: `GateBreakPanel` frame restyle

**Files:**
- Modify: `scenes/main.tscn` (`GateBreakPanel` node tree)

**Interfaces:**
- Consumes: `ExtResource("15")` (`ui_system_frame.webp`) declared by Task 1.
- Produces: nothing — last task in this plan.

- [ ] **Step 1: Add a frame behind `GateBreakPanel`'s content**

In `scenes/main.tscn`, `GateBreakPanel`'s current children are `Bg`, `InfoLabel` (`(40,400)-(1040,900)`), `AcceptButton` (`(40,940)-(400,1010)`), `DismissButton` (`(420,940)-(780,1010)`) — leave all four exactly as they are (this task is visual-only, the Answer/Ignore choice mechanic doesn't change). Insert a new `Frame` node immediately after `Bg` and before `InfoLabel`, wrapping the label+buttons region with a small margin:

```
[node name="Frame" type="NinePatchRect" parent="GameUI/GateBreakPanel"]
offset_left = 20.0
offset_top = 380.0
offset_right = 1060.0
offset_bottom = 1030.0
texture = ExtResource("15")
patch_margin_left = 64
patch_margin_top = 64
patch_margin_right = 64
patch_margin_bottom = 64
```

(No `z_index` needed here — `GateBreakPanel` and its children are already a later `GameUI` sibling than `MapView`, at the default `z_index = 0` shared by every other panel; this task doesn't change `GateBreakPanel`'s position in the tree, so the existing "later panels draw over the map" behavior is untouched. The `z_index = 1` rule in the Global Constraints applies specifically to `SystemToast`/`SystemPanel`, which must win over *other panels*, not just over the map — `GateBreakPanel`'s frame only needs to win over the map, which tree order alone already provides.)

- [ ] **Step 2: Run the full test suite**

```bash
"C:\Users\luket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: 511/511 passing (no `.gd` file touched).

- [ ] **Step 3: On-device sanity check**

Wait for (or trigger, if there's a debug path already established this session for it) a Gate Break alert. Confirm the frame renders behind the "Gate break!" text and Answer/Ignore buttons, and both buttons still work exactly as before.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn
git commit -m "feat: frame the Gate Break alert panel with the system UI border"
```

---

## Manual on-device verification (after Task 5, not a separate task)

`scenes/` changes are only ever verified manually/on-device per this project's convention — no Task 6 subagent dispatch for this. Full checklist, covering interactions across tasks:

- A Toast (e.g. "No gate tickets") appears, fades in, holds ~2s, fades out, doesn't block map taps.
- A Full panel (e.g. Lore Stone discovery) glitches in, shows header/divider/body correctly, tap-anywhere dismisses it, and while showing, nothing behind it (nav bar, map, HUD) responds to taps.
- Winning AND losing a gate battle both produce one merged result+reward `SystemPanel` (not two separate steps).
- A Nadir floor result (if reachable) produces the same merged treatment.
- The Stronghold proximity-denied case ("Not near your Stronghold") shows as a Toast, not a Full panel — confirms the signal split in Task 2 routes correctly.
- The persistent stats HUD shows its frame on a fresh launch, correctly layered over the map.
- The Gate Break alert shows its frame, Answer/Ignore both still work.
- Trigger two Toasts in quick succession (e.g. tap "Already claimed today" twice) — confirm the second replaces the first cleanly, no stale/overlapping animation state.
