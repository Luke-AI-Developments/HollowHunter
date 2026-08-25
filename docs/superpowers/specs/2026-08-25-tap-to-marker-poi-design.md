# Tap-to-marker POI interaction — design spec

**Date:** 2026-08-25
**Status:** Approved by user, ready for implementation planning.

## Summary

Today, interacting with any map POI goes through an always-visible button
at the top of the screen (`Enter Nearest Gate`, `Claim Sanctuary`,
`Lore Stone`) that always acts on whichever POI of that type is nearest —
you can't choose between two gates on screen, and the buttons take up
permanent screen space whether or not anything is actually nearby. The
Stronghold is a separate case, reached via its own nav-bar button into a
full management panel.

This spec replaces the three action buttons with direct interaction: tap
a marker on the map to act on *that* marker. Gates and the Stronghold's
entry point keep their current rules; Sanctuary and Lore Stone keep their
existing 50m proximity gate — this is a `scenes/` input-and-presentation
rework, not a gameplay-rules change. No `core/` code changes.

## Interaction model

- **Gate markers**: tap enters *that* gate (previously: nearest gate,
  chosen for you). Gates have never had a real-world proximity
  requirement — that stays true; tap only changes *which* gate you're
  targeting, not whether you can reach it.
- **Sanctuary / Lore Stone markers**: tap opens a small popup card for
  that POI. The existing 50m proximity check
  (`GameLogic.POI_PROXIMITY_RADIUS_M`) and cooldown/discovery rules are
  unchanged — the card's action button reflects whichever state applies.
- **Stronghold marker**: tap opens the existing Stronghold panel directly
  (`stronghold_view.open()`), the same panel the nav-bar `Stronghold`
  button already opens. No popup card — the panel has multiple actions,
  not one. The nav-bar button **stays**, since it's the only way to open
  the panel before a Stronghold has ever been placed (you can't tap a
  marker that doesn't exist yet), and it's consistent with every other
  full-panel feature (Army, Inventory, Character, ...) being reached via
  the nav bar rather than a marker tap.

## Removed

`EnterGateButton`, `ClaimSanctuaryButton`, `LoreStoneButton` and their
`main.tscn` layout slots. The underlying logic each called (gate battle
start, `state.claim_sanctuary(...)`, `state.discover_lorestone(...)`) is
kept as-is and now invoked from the tap path with a specific POI index
instead of "nearest in range". The status `Label` moves up to fill the
freed vertical space at the top of the screen.

## `scenes/map_view.gd` changes

One new method:

```gdscript
## Returns {"type": "gate"|"sanctuary"|"lorestone"|"stronghold", "index": int,
## "screen_pos": Vector2} for whichever marker is closest to screen_pos among
## all markers within their tap tolerance, or {} if nothing is in range.
## "index" is -1 for "stronghold" (there's only ever one).
func hit_test_marker(screen_pos: Vector2) -> Dictionary:
```

Each marker type already has an on-screen size constant
(`GATE_MARKER_SIZE`, `SANCTUARY_MARKER_SIZE`, `LORESTONE_MARKER_SIZE`,
`STRONGHOLD_MARKER_SIZE`, all in the 40-44px range). Tap tolerance radius
for a marker = `marker_size / 2.0 + TAP_TOLERANCE_PX` where
`TAP_TOLERANCE_PX := 16.0` (new const) — comfortable finger-sized hit
area without the icon itself needing to grow. `hit_test_marker()` computes
each visible marker's current screen position the same way `_draw()`
already does (`_world_to_screen(_project(lat, lon))`), collects every
marker within its own tolerance radius of `screen_pos`, and returns the
one whose *centre* is closest to `screen_pos` (not draw order) — so two
markers rendered close together at low zoom resolve predictably to
"whichever one you actually tapped nearer to".

Two new signals:

```gdscript
signal marker_tapped(info: Dictionary)  ## info is a hit_test_marker() result
signal map_tapped_empty
```

`_unhandled_input()` gains a plain-single-tap branch: outside placement
mode, a touch that starts and ends at roughly the same point (not part of
a pinch gesture — same distinction the existing tap-to-place-Stronghold
branch already draws) calls `hit_test_marker()` on the release position
and emits `marker_tapped(info)` if non-empty, else `map_tapped_empty`.
Placement mode's existing tap-to-place behaviour is unchanged and takes
priority — this new branch only runs when `_placement_mode` is false.

## `scenes/main.gd` changes

Connects `map_view.marker_tapped` and `map_view.map_tapped_empty`.

On `marker_tapped`:
- `"gate"` — same as today's `_on_enter_gate_pressed()` body, but using
  `info["index"]` instead of `map_view.get_nearest_gate_index()`. No card;
  battle starts immediately (gates were already a single, unconditional
  action).
- `"sanctuary"` / `"lorestone"` — positions and fills `MarkerCard` (see
  below) with that POI's data, computing its state (enabled / too far /
  already done) via the exact same calls `_on_claim_sanctuary_pressed()`
  and `_on_lorestone_pressed()` make today
  (`MapGeometry.distance_metres(...)` vs `GameLogic.POI_PROXIMITY_RADIUS_M`,
  and `state`'s existing cooldown/discovery checks), just evaluated
  read-only for display instead of being invoked immediately. The card's
  action button, when enabled, calls the same claim/discover code path
  that runs today and prints the same result message to the status label.
- `"stronghold"` — calls `stronghold_view.open()` directly; no card.

On `map_tapped_empty`: hides `MarkerCard` if visible.

## `MarkerCard` (new scene node)

A small `Panel` under `GameUI`, hidden by default, containing a type
label, a subtitle label, and one action `Button`. Reused for both
Sanctuary and Lore Stone (Gate never shows a card; Stronghold never shows
a card).

| `info["type"]` | Label | Subtitle | Action button |
|---|---|---|---|
| `sanctuary` | `SANCTUARY` | `"%dm away" % distance` if in range, `"%dm away — too far"` if not | `Claim` (enabled, in range + off cooldown) / `Too far away` (disabled, out of range) / `Already claimed today` (disabled, on cooldown) |
| `lorestone` | `LORE STONE` | same distance format | `Discover` (enabled) / `Too far away` (disabled) / `Already discovered` (disabled) |

Positioning: anchored above `info["screen_pos"]` (matches the approved
mockup), horizontally clamped to stay fully on screen (min/max against
card width + a screen-edge margin), and flipped to render *below* the
marker instead of above when there isn't enough room above it (near the
top of the screen). Recomputed every time a new `marker_tapped` arrives;
no persistent state beyond "currently showing card for POI X" needed.

Dismissal: `map_tapped_empty` hides it. Tapping a different marker
replaces its contents/position (no explicit close button). Tapping the
same marker again is a harmless no-op re-show.

## Testing

This is entirely `scenes/` (engine-dependent, manually verified per
`CLAUDE.md`) — `hit_test_marker()`'s geometry reuses already-tested
`core/map_geometry.gd` projection functions, and the claim/discover/battle
code paths being called are unchanged and already covered by existing
`core/` tests. No new `core/` code, so no new automated tests. Manual
on-device verification: tap each of the four marker types (in range and
out of range for Sanctuary/Lore Stone), confirm two nearby markers each
resolve to the tapped one, confirm card edge-clamping near screen edges,
confirm Stronghold nav-bar button still opens the panel with nothing
placed yet.

## Explicitly out of scope

- No change to gate proximity rules (deliberately staying proximity-free —
  see "Interaction model" above).
- No change to any `core/` file.
- No "already discovered" Lore Stone re-reading its snippet from the card
  (matches today's button behaviour: `Already discovered`, no text shown
  again).
- No explicit close (`×`) button on `MarkerCard` — tap-elsewhere dismissal
  only.
