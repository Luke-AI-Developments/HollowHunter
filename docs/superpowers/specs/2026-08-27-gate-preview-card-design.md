# Gate preview card (§18) — design spec

**Date:** 2026-08-27
**Status:** Approved by user, ready for implementation planning.

## Summary

Tapping a gate marker currently goes straight into combat
(`_on_marker_tapped()` → `_enter_gate()` → `_start_gate_battle()`), and
spending a Gate Ticket does the same after silently consuming the ticket.
Neither path tells the player the gate's **rank** first. This mattered
less when the map drew six rank-coloured gate markers, but the map now
uses **one universal gate marker** (§19 — "rank is revealed on tap"), so
there is currently no way to know what you're walking into until the
post-battle result screen names it — far too late to be a decision.

This spec adds a small preview card, shown before the fight starts, that
states the rank and names the boss. It is a `scenes/` presentation-and-
wiring change only — no `core/` code, no gameplay-rules change. Losing a
gate still has no penalty (§16/§18); the card is simply the "size it up
and decide" step §18 already specifies.

The **Gate Break** path is left alone — its `GateBreakPanel` already
prints the rank ("A C gate ruptured nearby — Grubmaw is loose").

Because the gate action routes through `_on_marker_card_action_pressed()`,
this spec also corrects a live bug in that function's dispatch: since
commit `017b9d4`, `_discover_lorestone()` reads `_card_poi_index` *after*
`_hide_marker_card()` has reset it to `-1`, so Lore Stone discovery
errors. The fix (capture card state into locals before the hide, pass as
args) is a prerequisite for the gate arm working correctly and fixes
lorestone in passing. See "Action dispatch — and an incidental fix".

## What the card shows

Exactly two facts, both direct reads off the gate dict
(`GateSpawner` output: `rank`, `monster_name`, ...):

- `TypeLabel` → `"RANK %s GATE" % gate["rank"]` (e.g. "RANK C GATE")
- `SubtitleLabel` → `gate["monster_name"]` (the boss)
- `ActionButton` → `"Enter Gate"`, always enabled

Explicitly **not** shown at v0: CLAIM odds, likely drops, trash-mob
preview, party summary. All deferred — the rank is the gap being closed.

## Component

Reuse `MarkerCard` (`GameUI/MarkerCard` — a `Panel` with `TypeLabel` /
`SubtitleLabel` / `ActionButton`), the same component Sanctuary and Lore
Stone already use. **No `main.tscn` structural change.** The gate path
just sets different text and routes the action button to a different
handler, exactly as the sanctuary and lorestone paths already do.

## `scenes/main.gd` changes

### New state

Alongside the existing `_card_poi_type` / `_card_poi_index` (`main.gd:33`):

- `_card_poi_type` gains two valid values: `"gate"` (map-tap) and
  `"ticket_gate"`.
- `_card_poi_index` reused for a map-tap gate's index into `_gates`.
- New: `var _card_gate: Dictionary = {}` — the stashed gate dict. Needed
  because a ticket gate is spawned on the fly and never lives in a
  persistent array to re-fetch by index.
- `_hide_marker_card()` also resets `_card_gate = {}` (it already clears
  `_card_poi_type` and `_card_poi_index`).

### Map-tap path

`_on_marker_tapped()`'s `"gate"` arm stops calling `_enter_gate()`
directly and calls a new method instead:

```gdscript
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

`_position_marker_card()` (existing) anchors the card above the tapped
marker, clamped on-screen — unchanged.

### Ticket path

`_on_use_ticket_pressed()` today: check GPS fix → `state.spend_gate_ticket()`
→ `GateSpawner.spawn_ticket_gate(...)` → `_start_gate_battle(gate, "\n\n[Ticket]")`.

Reordered so nothing is spent until the player confirms on the card:

1. `if not _has_location:` → existing "No GPS fix yet" toast, return.
2. **Peek** ticket count without spending: `if state.gate_tickets <= 0:`
   → existing "No gate tickets" toast, return.
3. **Reuse or roll:** `if _pending_ticket_gate.is_empty():` roll
   `GateSpawner.spawn_ticket_gate(_last_lat, _last_lon, state.hunter_rank,
   _monsters, rng)` into `_pending_ticket_gate`. Otherwise keep the
   existing cached roll — see the re-roll note below.
4. `if _pending_ticket_gate.is_empty():` (spawn failed) → "Ticket gate
   failed to spawn" toast, return. The current refund line is removed —
   it is now unreachable, because the ticket has not been spent.
5. `_show_ticket_gate_card(_pending_ticket_gate)`.

**`_pending_ticket_gate` (new member var).** Because the ticket is spent
only on "Enter Gate" (step 5 below), a naive re-roll on every press of
Use Ticket would let a player tap away and re-press to re-roll the gate's
rank for free — and rank drives loot tier, Essence, and claimed-shadow
grade. Caching the roll in `_pending_ticket_gate` and reusing it until the
ticket is actually spent keeps the pre-feature property that one press
commits one roll. Cleared in the `"ticket_gate"` dispatch arm right after
`state.spend_gate_ticket()` succeeds.

```gdscript
func _show_ticket_gate_card(gate: Dictionary) -> void:
	_card_poi_type = "ticket_gate"
	_card_poi_index = -1  # no map index for a ticket gate; keep it defined
	_card_gate = gate
	marker_card_type_label.text = "RANK %s GATE" % gate["rank"]
	marker_card_subtitle_label.text = String(gate["monster_name"])
	marker_card_action_button.text = "Enter Gate"
	marker_card_action_button.disabled = false
	_position_marker_card_centered()
```

New positioning helper, mirroring `_position_marker_card()` but with no
anchor — a ticket gate has no marker on screen:

```gdscript
## Centre MarkerCard in the viewport -- used for cards with no marker to
## anchor to (ticket gates). 1080x2424 is the project's fixed viewport
## (project.godot), same hardcoded-pixel convention as _position_marker_card().
func _position_marker_card_centered() -> void:
	var card_size := marker_card.size
	marker_card.position = (Vector2(1080.0, 2424.0) - card_size) / 2.0
	marker_card.visible = true
```

### Action dispatch — and an incidental fix

`_on_marker_card_action_pressed()` currently captures `_card_poi_type`
into a local, calls `_hide_marker_card()`, then dispatches on the local.
`_hide_marker_card()` resets `_card_poi_index = -1` and (new) `_card_gate
= {}`, so **any handler that reads card state after the hide gets stale
values**. This is already a live bug: `_discover_lorestone()` reads
`_card_poi_index` and, since commit `017b9d4`, gets `-1` →
`map_view.get_lorestone(-1)` → `{}` → `state.discover_lorestone(stone["id"],
...)` errors on the empty dict. The new `"gate"` arm would hit the same
trap.

Fix the pattern once: capture **everything the handlers need** into locals
before the hide, and pass them as arguments.

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
				_pending_ticket_gate = {}
				_start_gate_battle(gate, "\n\n[Ticket]")
			else:
				system_toast.show_toast("No gate tickets")
```

- `_discover_lorestone()` changes signature to take `index: int` and use
  it instead of reading `_card_poi_index`. One-line body change; fixes the
  `017b9d4` regression as a side effect of touching this function.
- `_enter_gate()` already takes an index — unchanged, just now called
  from here with the captured local.
- The `ticket_gate` arm's `spend_gate_ticket()` is the real spend — a
  belt-and-braces re-check that cannot actually fail in this synchronous
  single-player codebase, but if it ever did, it toasts rather than
  starting a free fight.

`_claim_sanctuary()` reads no card state, so it stays parameterless.

## Edge cases

- **Card up, player taps another gate:** `_show_gate_card()` overwrites
  `_card_*` and re-shows with fresh content. Same as sanctuary/lorestone
  today.
- **Card up, Gate Break fires:** `_on_gate_break_accept_pressed()` and
  `_start_gate_battle()` already call `_hide_marker_card()`, so a stale
  card cannot sit under the break panel. No new guard.
- **Card up, player taps empty map:** existing `map_tapped_empty` →
  `_hide_marker_card()`. Ticket gate: card gone, ticket never spent. The
  rolled gate stays in `_pending_ticket_gate` — see next.
- **Player dismisses a ticket card, then presses Use Ticket again:** they
  get the **same** rolled gate back (from `_pending_ticket_gate`), not a
  fresh roll. This is deliberate — re-rolling the rank for free by
  tap-away-and-retry would matter (rank drives loot/Essence/claim grade).
  The cache is only cleared when the ticket is actually spent.
- **Ticket peek finds 0 / spawn returns `{}`:** handled in the reordered
  `_on_use_ticket_pressed()` above; card never shows. A failed spawn
  leaves `_pending_ticket_gate` empty, so the next press retries.

## Non-goals

- **CLAIM odds / likely drops / trash preview / party summary** on the
  card — deferred. Rank + boss only.
- **Gate persists on loss.** `_enter_gate()` calls
  `map_view.remove_gate()` *before* the battle resolves, so a lost gate
  disappears from the map — but §18:1306 says "on loss ... the gate
  stays." That is a real discrepancy but a **separate** behavioural fix
  (it belongs in `_on_battle_finished()` and needs its own manual test);
  this spec does not touch gate removal timing.
- **Rewording `GateBreakPanel`** to match the card's phrasing — optional
  polish, out of scope.
- Ticket and Gate Break entry points otherwise unchanged.

## Testing

Entirely scene-layer (`main.gd` wiring; no rules, no `core/` change), so
per `CLAUDE.md` this is manual verification, not GUT. The full GUT suite
must stay green (nothing in `core/` is touched).

Manual checklist:

- Tap a map gate → card shows `RANK <x> GATE` + correct boss name,
  anchored above the marker, clamped on-screen near edges.
- Enter Gate → battle starts against that boss; gate is gone from the map
  afterward (unchanged current behaviour).
- Tap empty map with the card up → card dismisses, gate still on the map.
- Use Ticket with ≥1 ticket → centred card, correct rank + boss.
- Enter Gate from the ticket card → ticket count decrements by exactly 1,
  battle starts with the `[Ticket]` prefix.
- Tap away from the ticket card → **ticket count unchanged**, no battle,
  no gate.
- Use Ticket with 0 tickets → "No gate tickets" toast, no card.
- Trigger a Gate Break → its panel still appears and still states the
  rank (regression check — unchanged path).
- **Lore Stone regression check:** tap a Lore Stone marker → Discover →
  the lore snippet + Essence reward apply (this path errors on `master`
  today; the dispatch-locals change is what fixes it).
- On-device screenshot of the map-tap card saved to `devmedia/` per the
  capture-log convention.
