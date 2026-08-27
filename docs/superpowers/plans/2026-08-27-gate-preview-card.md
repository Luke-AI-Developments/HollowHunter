# Gate Preview Card (§18) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a small preview card stating a gate's rank and boss name before the fight starts, for both map-tapped gates and ticket gates.

**Architecture:** Pure `scenes/main.gd` wiring. Reuse the existing `MarkerCard` component (`Panel` + `TypeLabel`/`SubtitleLabel`/`ActionButton`) that Sanctuary and Lore Stone already use — no `.tscn` change, no `core/` change. The map-tap gate arm routes through `_on_marker_card_action_pressed()`, whose dispatch is refactored first (Task 1) to fix a live stale-index bug that the gate arm would otherwise inherit.

**Tech Stack:** Godot 4.7 / GDScript. GUT for the existing `core/` suite (must stay green; no new tests — this is scene code). `gdformat` + `gdlint` + full GUT run happen automatically via the post-edit hook (`.claude/settings.json`) on every `.gd` save.

## Global Constraints

- Static typing everywhere: `var x: int = 0`, `func f(a: int) -> void:`. Per `CLAUDE.md`.
- Tabs for indentation; `snake_case` functions/vars; one class per file. Per `CLAUDE.md`.
- `scenes/` is thin view code with no game rules and **no GUT coverage** — verified manually (Godot editor / on-device), per `CLAUDE.md`'s folder-layout rule. `core/` is untouched by this plan, so the full GUT suite count must not change.
- The post-edit hook reformats and lints every saved `.gd` and runs the whole GUT suite — don't hand-fix whitespace nits, and treat a red hook as a blocker.
- Viewport is a fixed `1080 x 2424` (`project.godot`), hardcoded-pixel layout throughout `main.tscn` — no responsive system. Match that convention.
- Manual GUT run (when needed outside the hook): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: Dispatch-locals refactor + Lore Stone stale-index fix

**Files:**
- Modify: `scenes/main.gd:33-35` (card-state vars), `scenes/main.gd:631-634` (`_hide_marker_card()`), `scenes/main.gd:818-825` (`_on_marker_card_action_pressed()`), `scenes/main.gd:848-863` (`_discover_lorestone()`)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `_card_gate: Dictionary` — new card-state member var, reset by `_hide_marker_card()`. Read by Task 3.
  - `_on_marker_card_action_pressed()` now captures `poi_type: String` and `poi_index: int` into locals *before* calling `_hide_marker_card()`, then dispatches on the locals. Tasks 2 and 3 add `match` arms that rely on `poi_index` (and, in Task 3, a captured `gate` local) still being valid after the hide.
  - `_discover_lorestone(index: int) -> void` — signature changed from parameterless; callers pass the captured index.

**Background:** `_on_marker_card_action_pressed()` calls `_hide_marker_card()` (which sets `_card_poi_index = -1`) before its `match`. It already captures `_card_poi_type` into a local to survive that, but `_discover_lorestone()` still reads `_card_poi_index` — so since commit `017b9d4` it reads `-1`, `map_view.get_lorestone(-1)` returns `{}`, and `state.discover_lorestone(stone["id"], ...)` errors on the empty dict. Lore Stone discovery is broken on `master`.

- [ ] **Step 1: Add the `_card_gate` member var**

In `scenes/main.gd`, extend the card-state block (currently lines 33-35):

```gdscript
var _card_poi_type: String = ""  ## which POI MarkerCard's action button currently
var _card_poi_index: int = -1  ## acts on -- set by _show_sanctuary_card()/
## _show_lorestone_card()/_show_gate_card(), read by _on_marker_card_action_pressed().
var _card_gate: Dictionary = {}  ## the gate dict for a "gate"/"ticket_gate" card --
## a ticket gate has no map index to re-fetch by, so the whole dict is stashed here.
```

- [ ] **Step 2: Reset `_card_gate` in `_hide_marker_card()`**

```gdscript
func _hide_marker_card() -> void:
	marker_card.visible = false
	_card_poi_type = ""
	_card_poi_index = -1
	_card_gate = {}
```

- [ ] **Step 3: Refactor the dispatch to capture locals before the hide**

Replace `_on_marker_card_action_pressed()` (currently lines 818-825):

```gdscript
func _on_marker_card_action_pressed() -> void:
	var poi_type := _card_poi_type
	var poi_index := _card_poi_index
	_hide_marker_card()
	match poi_type:
		"sanctuary":
			_claim_sanctuary()
		"lorestone":
			_discover_lorestone(poi_index)
```

- [ ] **Step 4: Change `_discover_lorestone()` to take the index as a parameter**

In `scenes/main.gd`, change the signature and the first line (currently lines 848-849):

```gdscript
func _discover_lorestone(index: int) -> void:
	var stone := map_view.get_lorestone(index)
```

The rest of the function body is unchanged.

- [ ] **Step 5: Let the post-edit hook run, confirm it's green**

Saving `scenes/main.gd` triggers `gdformat` + `gdlint` + the full GUT suite. Expected: format/lint clean, GUT suite green with the **same test count as before** (no `core/` change). If the hook is red, fix before continuing.

- [ ] **Step 6: Manual verification — Lore Stone discovery works again**

Run the project (Godot editor F5, or the `run` skill). With a GPS fix and a Lore Stone marker within `GameLogic.POI_PROXIMITY_RADIUS_M`:
- Tap the Lore Stone marker → card shows "LORE STONE" / "Discover".
- Tap **Discover** → the `SystemPanel` "LORE STONE" ceremony shows the lore snippet + "(+N Essence)", Essence increases, no error in the Godot output panel.
- Tap the same marker again → card shows "Already discovered", button disabled.

Sanctuary path regression check: tap a Sanctuary marker in range → **Claim** → toast "Sanctuary claimed: +N Essence, +N Gate Ticket", still works.

- [ ] **Step 7: Commit**

```bash
git add scenes/main.gd
git commit -m "fix: capture MarkerCard state before hide; repair Lore Stone discovery

_on_marker_card_action_pressed() called _hide_marker_card() (which resets
_card_poi_index to -1) before dispatching, and _discover_lorestone() read
_card_poi_index afterward -- so since 017b9d4 it got -1, get_lorestone(-1)
returned {}, and discover_lorestone(stone[\"id\"]) errored. Now
poi_type/poi_index are captured into locals up front and the index is
passed to _discover_lorestone(index). Adds the _card_gate member var
(reset alongside the other card state) for the gate cards to come.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 2: Map-tap gate preview card

**Files:**
- Modify: `scenes/main.gd:606-617` (`_on_marker_tapped()`), `scenes/main.gd` (new `_show_gate_card()` near the other `_show_*_card()` methods ~line 714), `scenes/main.gd` `_on_marker_card_action_pressed()` `match` (from Task 1)

**Interfaces:**
- Consumes: `_on_marker_card_action_pressed()` dispatching on the `poi_type`/`poi_index` locals (Task 1); `map_view.get_gate(index: int) -> Dictionary` (existing — returns `{}` if out of range); `_enter_gate(index: int) -> void` (existing — `remove_gate` + `_start_gate_battle`); `_position_marker_card(marker_screen_pos: Vector2) -> void` (existing).
- Produces: `_show_gate_card(index: int, screen_pos: Vector2) -> void`; a `"gate"` value for `_card_poi_type`; a `"gate"` arm in the dispatch `match`.

- [ ] **Step 1: Add `_show_gate_card()`**

In `scenes/main.gd`, right after `_show_lorestone_card()` (ends line 713):

```gdscript
## §18: tapping a gate marker opens this card instead of dropping straight
## into the fight -- it states the rank (the map's single universal marker
## no longer encodes it, §19) and names the boss. "Enter Gate" runs the
## existing _enter_gate() path unchanged; tapping empty map cancels.
func _show_gate_card(index: int, screen_pos: Vector2) -> void:
	var gate := map_view.get_gate(index)
	if gate.is_empty():
		return
	_card_poi_type = "gate"
	_card_poi_index = index
	_card_gate = gate
	marker_card_type_label.text = "RANK %s GATE" % gate["rank"]
	marker_card_subtitle_label.text = String(gate["monster_name"])
	marker_card_action_button.text = "Enter Gate"
	marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)
```

- [ ] **Step 2: Route the map-tap `"gate"` case through the card**

In `_on_marker_tapped()` (lines 606-617), change the `"gate"` arm from entering directly to showing the card:

```gdscript
func _on_marker_tapped(info: Dictionary) -> void:
	match info["type"]:
		"gate":
			_show_gate_card(info["index"], info["screen_pos"])
		"sanctuary":
			_show_sanctuary_card(info["index"], info["screen_pos"])
		"lorestone":
			_show_lorestone_card(info["index"], info["screen_pos"])
		"stronghold":
			_hide_marker_card()
			stronghold_view.open()
```

- [ ] **Step 3: Add the `"gate"` dispatch arm**

In `_on_marker_card_action_pressed()` (from Task 1), add a `"gate"` arm:

```gdscript
	match poi_type:
		"sanctuary":
			_claim_sanctuary()
		"lorestone":
			_discover_lorestone(poi_index)
		"gate":
			_enter_gate(poi_index)
```

- [ ] **Step 4: Let the post-edit hook run, confirm it's green**

Same as Task 1 Step 5 — format/lint clean, GUT count unchanged.

- [ ] **Step 5: Manual verification**

Run the project. With a GPS fix and gate markers on the map:
- Tap a gate marker → card appears anchored above it, "RANK &lt;x&gt; GATE" on the first line, the boss's name on the second, "Enter Gate" button.
- Tap a gate near the top edge of the map → card flips below the marker, stays fully on-screen (existing `_position_marker_card` clamp).
- Tap **Enter Gate** → the battle screen opens against that boss; after the battle, that gate is gone from the map (unchanged behaviour).
- Tap a gate, then tap empty map → card dismisses, gate still there, no battle.
- Tap gate A, then (card still up) tap gate B → card updates to B's rank/boss.

- [ ] **Step 6: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: gate preview card on map tap (§18)

Tapping a gate marker now opens a MarkerCard -- \"RANK <x> GATE\" + boss
name + \"Enter Gate\" -- instead of starting the fight immediately. The
map's one universal gate marker no longer encodes rank (§19), so this is
the only place the player learns it before committing. Enter Gate calls
the existing _enter_gate() path unchanged; tap-away cancels.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 3: Ticket gate preview card (centred)

**Files:**
- Modify: `scenes/main.gd` (new `_position_marker_card_centered()` near `_position_marker_card()` ~line 655), new `_show_ticket_gate_card()` near the other `_show_*_card()` methods, `_on_use_ticket_pressed()` (~lines 768-791), `_on_marker_card_action_pressed()` `match` (from Tasks 1-2)

**Interfaces:**
- Consumes: `_card_gate` (Task 1); `marker_card.size: Vector2` (existing `Panel` geometry); `state.gate_tickets: int` (existing field); `state.spend_gate_ticket() -> bool` (existing); `GateSpawner.spawn_ticket_gate(lat: float, lon: float, hunter_rank: String, monsters: Array, rng: RandomNumberGenerator) -> Dictionary` (existing — returns `{}` on failure); `_start_gate_battle(gate: Dictionary, prefix := "", is_break := false) -> void` (existing).
- Produces: `_position_marker_card_centered() -> void`; `_show_ticket_gate_card(gate: Dictionary) -> void`; a `"ticket_gate"` value for `_card_poi_type`; a `"ticket_gate"` arm in the dispatch `match`.

- [ ] **Step 1: Add `_position_marker_card_centered()`**

In `scenes/main.gd`, right after `_position_marker_card()` (ends line 655):

```gdscript
## Centre MarkerCard in the viewport -- for cards with no marker to anchor
## to (a ticket gate isn't drawn on the map). 1080x2424 is the project's
## fixed viewport (project.godot), same hardcoded-pixel convention as
## _position_marker_card(). marker_card.size reads the .tscn geometry so a
## resize in the editor can't silently break this.
func _position_marker_card_centered() -> void:
	var card_size := marker_card.size
	marker_card.position = (Vector2(1080.0, 2424.0) - card_size) / 2.0
	marker_card.visible = true
```

- [ ] **Step 2: Add `_show_ticket_gate_card()`**

Right after `_show_gate_card()` (from Task 2):

```gdscript
## §8a ticket gate: same card as _show_gate_card(), but centred (no map
## marker to anchor to) and shown BEFORE the ticket is spent -- the
## "ticket_gate" dispatch arm does state.spend_gate_ticket(), so tapping
## empty map here costs the player nothing.
func _show_ticket_gate_card(gate: Dictionary) -> void:
	_card_poi_type = "ticket_gate"
	_card_poi_index = -1
	_card_gate = gate
	marker_card_type_label.text = "RANK %s GATE" % gate["rank"]
	marker_card_subtitle_label.text = String(gate["monster_name"])
	marker_card_action_button.text = "Enter Gate"
	marker_card_action_button.disabled = false
	_position_marker_card_centered()
```

- [ ] **Step 3: Reorder `_on_use_ticket_pressed()` to preview before spending**

Replace the body of `_on_use_ticket_pressed()` (currently lines 768-791). The key change: peek `state.gate_tickets` instead of spending, spawn the gate, show the card, and let the dispatch arm do the actual spend.

```gdscript
func _on_use_ticket_pressed() -> void:
	if not _has_location:
		system_toast.show_toast("No GPS fix yet -- can't place a ticket gate")
		return
	if state.gate_tickets <= 0:
		system_toast.show_toast("No gate tickets")
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gate := GateSpawner.spawn_ticket_gate(
		_last_lat, _last_lon, state.hunter_rank, _monsters, rng
	)
	if gate.is_empty():
		# Content has no monster in the rank pool -- shouldn't happen with
		# the real monsters.json. Nothing was spent, so nothing to refund.
		system_toast.show_toast("Ticket gate failed to spawn")
		return
	_show_ticket_gate_card(gate)
```

- [ ] **Step 4: Add the `"ticket_gate"` dispatch arm**

In `_on_marker_card_action_pressed()`, capture the gate into a local alongside the others and add the arm:

```gdscript
func _on_marker_card_action_pressed() -> void:
	var poi_type := _card_poi_type
	var poi_index := _card_poi_index
	var gate := _card_gate
	_hide_marker_card()
	match poi_type:
		"sanctuary":
			_claim_sanctuary()
		"lorestone":
			_discover_lorestone(poi_index)
		"gate":
			_enter_gate(poi_index)
		"ticket_gate":
			if state.spend_gate_ticket():
				_start_gate_battle(gate, "\n\n[Ticket]")
			else:
				system_toast.show_toast("No gate tickets")
```

- [ ] **Step 5: Let the post-edit hook run, confirm it's green**

Same as Task 1 Step 5.

- [ ] **Step 6: Manual verification**

Run the project. With a GPS fix:
- Ensure the save has ≥1 gate ticket. Press the ticket action → a card appears **centred** on screen, "RANK &lt;x&gt; GATE" + boss name + "Enter Gate".
- Tap **Enter Gate** → ticket count drops by exactly 1 (check the HUD), the battle screen opens, and the result text carries the `[Ticket]` prefix.
- Repeat with ≥1 ticket, but tap **empty map** instead → card dismisses, **ticket count unchanged**, no battle.
- Spend down to 0 tickets, press the ticket action → "No gate tickets" toast, no card.

Regressions:
- Map-tap gate card (Task 2) still anchors above the marker, not centred.
- Trigger a Gate Break → its own panel still appears and still reads "A &lt;x&gt; gate ruptured nearby -- &lt;boss&gt; is loose."

- [ ] **Step 7: On-device capture**

Build + install on the physical device (same pipeline as the portrait-mode / map-render work: `godot --export-debug`, re-patch the Gradle manifest overrides, `gradlew` with the `-P` props, sign with the debug keystore, `adb install`). Screenshot the map-tap gate card over the real Darlington basemap and save to `devmedia/2026-08-27/` with a one-line entry appended to `devmedia/CAPTURE_LOG.md`.

- [ ] **Step 8: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: gate preview card for ticket gates (§8a/§18)

_on_use_ticket_pressed() now peeks the ticket count, spawns the gate, and
shows the same preview card centred (no marker to anchor to). The
\"ticket_gate\" dispatch arm does the real state.spend_gate_ticket() on
Enter Gate, so tapping away costs nothing -- and a failed spawn no longer
needs a refund because nothing was spent yet.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

## Post-plan checklist (controller, after all tasks)

- [ ] Full GUT suite green, **same count as before this plan** (no `core/` change anywhere).
- [ ] `gdformat` / `gdlint` clean on `scenes/main.gd` (the hook enforces this per save).
- [ ] Manual checks from Tasks 1, 2, 3 all pass in one run-through: Lore Stone discovery, Sanctuary claim, map-tap gate card (anchored, Enter, cancel, re-tap), ticket gate card (centred, spends on Enter only, no-ticket toast), Gate Break panel unchanged.
- [ ] `devmedia/` screenshot of the map-tap card over the real basemap, logged in `CAPTURE_LOG.md`.
- [ ] Spec's non-goals still hold: no CLAIM odds / drops / party on the card; gate-persists-on-loss NOT addressed (still flagged for a separate task); `GateBreakPanel` wording untouched.

## Self-Review

**Spec coverage:**
- "Card shows RANK + boss, both direct field reads" → Task 2 Step 1 (`_show_gate_card`), Task 3 Step 2 (`_show_ticket_gate_card`).
- "Reuse MarkerCard, no .tscn change" → no task touches `main.tscn`; all three `_show_*` set the same three existing widgets.
- "Map-tap: `_on_marker_tapped` calls `_show_gate_card` not `_enter_gate`" → Task 2 Step 2.
- "Ticket: peek not spend, card before spawn-fail refund removed, centred" → Task 3 Step 3.
- "Ticket: spend happens in the dispatch arm" → Task 3 Step 4.
- "New `_card_gate` var, reset in `_hide_marker_card`" → Task 1 Steps 1-2.
- "Dispatch captures locals before hide; `_discover_lorestone(index)`" → Task 1 Steps 3-4.
- "Incidental Lore Stone fix" → Task 1 (whole task).
- "Gate Break untouched" → no task modifies `_on_gate_break_*` or `GateBreakPanel`; called out in both manual-verification sections as a regression check.
- "Non-goals: no odds/drops/party; gate-persists-on-loss separate" → Post-plan checklist; nothing in any task touches `_enter_gate`'s `remove_gate` call or adds card fields.
- Testing "scene-layer, manual not GUT, suite stays green" → every task's hook step says "same test count as before"; no task writes a GUT test.

**Placeholder scan:** No TBD/TODO. Every code step has literal code. Manual-verification steps list concrete taps and expected UI text, not "verify it works".

**Type consistency:**
- `_card_poi_type` values: `"sanctuary"`, `"lorestone"`, `"gate"`, `"ticket_gate"` — set in `_show_*` methods, matched in `_on_marker_card_action_pressed()`. Consistent across Tasks 1-3.
- `_card_gate: Dictionary` — declared Task 1, assigned in `_show_gate_card`/`_show_ticket_gate_card` (Tasks 2-3), read as the `gate` local in the `"ticket_gate"` arm (Task 3). Consistent.
- `_discover_lorestone(index: int)` — signature set in Task 1 Step 4, called with `poi_index` in Task 1 Step 3 and unchanged in Tasks 2-3's shown `match` blocks. Consistent.
- `_show_gate_card(index: int, screen_pos: Vector2)` vs `_show_ticket_gate_card(gate: Dictionary)` — map-tap has an index + anchor; ticket has only the dict + centred placement. Deliberate, matches the spec.
- `_position_marker_card_centered()` — defined Task 3 Step 1, called in `_show_ticket_gate_card` (same task). Consistent with existing `_position_marker_card(screen_pos)`.
- `state.gate_tickets` (int, peeked) and `state.spend_gate_ticket()` (bool, the real decrement) — used exactly as in the current `_on_use_ticket_pressed()`.
