# Map POI spawning — Sanctuary, Lore Stone, Stronghold, Incursion badge — design spec

**Date:** 2026-08-24
**Status:** Approved by user, ready for implementation planning.

## Summary

The map renderer (§19b/§19c) and its two working marker types — gate and
player — are done. This spec covers the remaining five marker assets in
`art/map/` (`map_sanctuary.webp`, `map_lorestone.webp`, `map_stronghold.webp`,
`map_incursion.webp`, `map_nadir.webp`), none of which have any backing
game data or spawn logic today. Re-reading §19/§20/§22 closely turned up
that these aren't one uniform feature:

- **Sanctuary** (§19) and **Lore Stone** (§19) are genuine new POI types —
  proximity-based, spawned near the player. Nothing exists for either.
- **Stronghold** (§22) already has a fully working, tested gameplay system
  (`core/stronghold.gd`, `scenes/stronghold_view.gd` — facilities, idle
  production) reachable from the nav bar. It has never had a map location;
  no lat/lon is stored anywhere. This spec adds the map presence, not the
  underlying gameplay (already done).
- **Incursion** (§19) is not a point POI at all — it's an area-wide zone
  effect already implemented (`_active_incursion_family` + a text banner
  in `map_view.gd`'s `_draw()`). This spec only replaces that banner's
  presentation with the real icon.
- **Nadir** (§20) is described exclusively as "reached from the Raids tab"
  everywhere in the design doc — never as a map location. **Decision: it
  gets no map wiring.** `map_nadir.webp` stays unused as a map marker;
  noted explicitly so this reads as a deliberate call, not an oversight.

## Shared building block

**`core/map_geometry.gd` gains two functions**, both pure, both tested:

- `distance_metres(lat1, lon1, lat2, lon2) -> float` — projects both points
  via the existing `lonlat_to_mercator()` and returns the Euclidean
  distance between the results. This is the one proximity check every POI
  type below shares (Sanctuary claim, Lore Stone discovery, Stronghold
  collect/reassign gate) — one implementation, one set of tests, no
  drift between three separately-hand-rolled distance checks.
- `mercator_to_lonlat(x, y) -> Vector2` — the mathematical inverse of
  `lonlat_to_mercator()` (returns `Vector2(lon, lat)`). Needed for the
  Stronghold placement flow: a screen tap has to convert back to a real
  lat/lon. Round-trip-tested against `lonlat_to_mercator()`.

**`core/poi_spawner.gd` (new)**, sibling to `core/gate_spawner.gd`:
deterministic-by-area spawning for Sanctuary and Lore Stone, so every
player in the same area sees the same spots (shared world POIs, unlike
gates' per-session RNG scatter — matches "anchored to real notable
places"). Reuses `Incursion.area_key(lat, lon)` for area bucketing (no new
cell-size constant) and `GateSpawner.MAX_OFFSET_DEGREES` for the same
~300-400m scatter radius gates already use. The RNG is seeded purely from
`hash(area_key + a type tag)` — no time component, so positions are stable
across sessions and days (distinct from Incursion's own week-rotating
family choice, which stays exactly as it is today).

```gdscript
const SANCTUARY_COUNT := 2
const LORESTONE_COUNT := 1

static func spawn_sanctuaries(center_lat: float, center_lon: float, count: int = SANCTUARY_COUNT) -> Array
# -> Array[Dictionary]: {"id": String, "lat": float, "lon": float}
# id = "<area_key>_sanctuary_<index>"

static func spawn_lorestones(center_lat: float, center_lon: float, count: int = LORESTONE_COUNT) -> Array
# -> Array[Dictionary]: {"id": String, "lat": float, "lon": float, "lore_index": int}
# id = "<area_key>_lorestone_<index>"; lore_index picks a LORE_SNIPPETS entry, deterministic per stone

const LORE_SNIPPETS := [
    "...",  # 4-5 short placeholder in-fiction blurbs go here, authored
    "...",  # during implementation (Ascendancy, the families, the Nadir --
    "...",  # clearly placeholder text, not a real writing pass). Picked
]           # round-robin by lore_index, not random.
```

## Sanctuary

- **Spawn:** `PoiSpawner.spawn_sanctuaries()`, called once from
  `MapView.show_position()`'s existing first-fix block (same place gates
  spawn today), stored in a new `_sanctuaries` array parallel to `_gates`.
- **Claim:** a new **"Claim Sanctuary"** button in `GameUI`, next to
  "Enter Nearest Gate". Follows that button's exact convention — always
  visible, no per-frame enable/disable bookkeeping; pressing it when
  nothing qualifies just appends a status message to the shared label
  (matches `_on_enter_gate_pressed()`'s "No gates nearby" and
  `_on_use_ticket_pressed()`'s "No GPS fix yet" pattern).
- On press: find the nearest sanctuary within `POI_PROXIMITY_RADIUS_M`
  (50.0, `core/game_logic.gd`) of the player's live position via
  `MapGeometry.distance_metres()`; if none, message "No Sanctuary
  nearby"; if found but already claimed within the last 24h, message
  "Already claimed today"; otherwise apply the reward and update
  `HunterState`.
- **Reward:** `SANCTUARY_ESSENCE_REWARD := 30` Essence (roughly an E-rank
  gate's worth) + 1 gate ticket, both existing `HunterState` fields —
  no new currency/item types.
- **Cooldown:** `HunterState.last_sanctuary_claim_at: int` (unix
  timestamp), gate is `now - last_sanctuary_claim_at >= 86400`. Global
  per-player, not per-sanctuary-id (matches "a daily bonus", singular).
- **Marker:** `map_sanctuary` texture via `ArtPaths.map_marker("sanctuary")`,
  drawn for every entry in `_sanctuaries` the same way gates draw today —
  universal icon, no per-sanctuary variation, same placeholder-circle
  fallback pattern if the art is ever missing.

## Lore Stone

- **Spawn:** `PoiSpawner.spawn_lorestones()`, same first-fix call site,
  stored in `_lorestones`.
- **Discover:** a new **"Lore Stone"** button, same always-visible /
  message-on-press convention as Sanctuary. On press: nearest lorestone
  within `POI_PROXIMITY_RADIUS_M`; if none, "No Lore Stone nearby"; if
  found but its `id` is already in `HunterState.discovered_lorestone_ids`,
  "Already discovered"; otherwise mark discovered, grant
  `LORESTONE_ESSENCE_REWARD := 15` Essence, and show the stone's
  `LORE_SNIPPETS[lore_index]` text in the shared label (same "message
  appended to `label.text`" convention as everything else on this screen
  — no new popup panel).
- **Persistence:** `HunterState.discovered_lorestone_ids: Array` (of
  String ids), one-time-per-id-forever, survives across areas (a player
  who walks to a new area can discover that area's stone too).
- **Marker:** `map_lorestone` texture, same universal/fallback pattern.

## Stronghold — map placement

- **New state on `HunterState`:** `stronghold_lat: float = 0.0`,
  `stronghold_lon: float = 0.0`, `stronghold_placed: bool = false`. Added
  to `to_dict()`/`from_dict()` following the file's existing explicit-
  field convention (no reflection) — old saves default to `placed = false`,
  same pattern `hunter_rank`/`preset_id` already use for backward
  compatibility.
- **Mutator:** `HunterState.place_stronghold(lat: float, lon: float) -> void`
  — sets all three fields. Callable any number of times (re-placement is
  just calling it again — no separate "first time" vs "move" code path).
- **Placement flow:** a **"Place Stronghold"** button in `StrongholdView`
  (`scenes/main.tscn`'s StrongholdPanel) puts `MapView` into a placement
  mode (`MapView.begin_stronghold_placement()`). `MapView` has no existing
  tap-gesture detection (pan is gone, `_unhandled_input` only tracks
  touches for pinch) — while placement mode is active, a plain
  `InputEventScreenTouch` with `pressed == true` and exactly one active
  touch is treated as the tap, using that touch's raw position directly
  (no down/up/movement-delta gesture recognition; pinch's existing
  two-touch handling is unaffected since this only fires when
  `_active_touches.size() == 1`). The tapped screen position converts back
  to world position via `_world_to_screen()`'s inverse, then to lat/lon via
  `MapGeometry.mercator_to_lonlat()`, and shows as a temporary pending
  marker (draw-only, not yet saved).
  `MapView` exposes `pending_stronghold_position() -> Vector2` (lat, lon)
  and the placement UI shows **Confirm**/**Cancel** buttons; Confirm calls
  `state.place_stronghold(...)` + `SaveService.save()` +
  `map_view.set_stronghold(lat, lon, true)` (the "confirmed, always-drawn"
  setter) and exits placement mode; Cancel just exits it. Re-placement
  later reuses the identical flow (button relabels to "Move Stronghold"
  once `stronghold_placed` is true).
- **Marker:** `map_stronghold` texture at the stored location, drawn
  whenever `stronghold_placed` is true — always visible to the player on
  their own map (no other-player visibility exists in this build, so the
  spec's "private to you" requirement is already satisfied trivially).

## Stronghold — proximity gate on existing actions

- Scoped to exactly what §22 says requires being on-site: **Collect**
  (`_on_collect_pressed`) and **reassign** (`_on_assign_pressed`/
  `_on_unassign_pressed`) in `scenes/stronghold_view.gd`. Viewing/refresh
  and both upgrade actions (`_on_facility_upgrade_pressed`,
  `_on_upgrade_stronghold_pressed`) stay unrestricted — the spec
  explicitly allows remote viewing, and upgrades aren't named as requiring
  presence.
- `StrongholdView` needs the player's live position, which it doesn't have
  today (only `HunterState`). New `StrongholdView.update_position(lat, lon)`,
  called from `main.gd`'s existing `_on_location_update()` alongside the
  `map_view.show_position()` call already there.
- Each gated handler checks `MapGeometry.distance_metres(player_lat,
  player_lon, state.stronghold_lat, state.stronghold_lon) <=
  POI_PROXIMITY_RADIUS_M` (also requires `state.stronghold_placed` and a
  GPS fix) before proceeding; on failure, same message-not-silent-disable
  convention as the rest of this screen ("Not near your Stronghold").

## Incursion badge

- `MapView._draw()`'s existing incursion block:
  ```gdscript
  if _active_incursion_family != "":
      draw_string(ThemeDB.fallback_font, Vector2(-100, -60), "⚡ Incursion: %s" % _active_incursion_family, ...)
  ```
  becomes an icon (via `ArtPaths.map_marker("incursion")`, fixed
  screen-space position, not world-space — it's a zone effect, not a
  point) drawn next to the same text, in the same place. Falls back to
  the current text-only rendering if the art is missing. No change to
  `_active_incursion_family`'s own detection logic (`core/incursion.gd`
  untouched).

## Nadir — explicitly no-op

No spawn logic, no marker draw call. `art_paths.gd`'s `map_marker()`
already resolves `"nadir"` generically (nothing marker-specific to build
there), it simply never gets called with that id from `map_view.gd`. This
line in the spec is the record of that being deliberate.

## Files touched (for the implementation plan to break into tasks)

- `core/map_geometry.gd` (+tests): `distance_metres()`, `mercator_to_lonlat()`.
- `core/poi_spawner.gd` (new, +tests): `spawn_sanctuaries()`, `spawn_lorestones()`, `LORE_SNIPPETS`.
- `core/game_logic.gd`: `POI_PROXIMITY_RADIUS_M`, `SANCTUARY_ESSENCE_REWARD`, `SANCTUARY_TICKET_REWARD`, `LORESTONE_ESSENCE_REWARD`, `SANCTUARY_CLAIM_COOLDOWN_S`.
- `core/hunter_state.gd` (+tests): new fields, `to_dict()`/`from_dict()`, `place_stronghold()`.
- `scenes/map_view.gd`: sanctuary/lorestone spawn+draw, stronghold draw + placement mode + pending-position query, incursion badge, nearest-sanctuary/nearest-lorestone-in-range queries.
- `scenes/stronghold_view.gd`: `update_position()`, proximity gate on collect/assign/unassign.
- `scenes/main.tscn`: "Claim Sanctuary", "Lore Stone" buttons in GameUI; "Place Stronghold"/Confirm/Cancel buttons in StrongholdPanel.
- `scenes/main.gd`: wire the four new buttons, feed `stronghold_view.update_position()` from the existing GPS callback, placement-mode confirm/cancel handlers.

## Explicitly out of scope (flagged, not silently dropped)

- Sanctuary's "small temporary buff" (§19) — no temp-effect system exists
  anywhere in the codebase; building one just for this is deferred. Only
  the Essence + ticket reward ships.
- Lore Stone content is placeholder text, not a real writing pass.
- No UI polish beyond reusing this screen's existing plain-label/button
  conventions — no new panel styling, no ceremonial ("§9c System UI")
  treatment for claim/discover moments.
