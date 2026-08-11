class_name Incursion
## Phase 2/P9: Incursions -- "a living, changing world" (§19). Pure.
##
## Scope decision, flagged: §19's Incursions are one piece of a much
## bigger map overhaul (real MapLibre/OSM vector tiles served from
## Cloudflare R2, Sanctuaries, Lore Stones) that this project's placeholder
## dot-map (scenes/map_view.gd) doesn't have and isn't gaining here -- that
## real map tech needs external hosting/accounts this session can't
## provision, and is its own project on top of everything else built so
## far. What IS in scope and buildable purely: the deterministic
## area+week incursion-zone GENERATION rule the source calls out as the
## v1, no-backend approach ("client-side, deterministically by area +
## week -- everyone in a region sees the same event for free"), plus the
## family-restricted/rank-boosted gate content it implies. Wired onto the
## existing placeholder map: since that map has no concept of walking
## between "zones", the whole map is simply either under one incursion or
## not, decided once at the first GPS fix (same "rolled once" convention
## MapView already uses for its normal gates).
##
## Numbers below (cell size, cadence, odds, rank boost via GateSpawner,
## Essence multiplier) are all invented v0 -- the source gives none of
## them, only the shape of the mechanic ("a few days", "denser, a rank
## higher", "boosted set-piece drops").

const AREA_CELL_DEGREES := 0.05  ## ~5.5km grid cells -- coarse enough that GPS jitter
## and "walking around your area" (§19) still land in the same cell/incursion.
const WEEK_SECONDS := 7 * 24 * 60 * 60  ## incursion cadence -- "a few days" rounded up to a
## clean, drift-free unit so it's a pure function of wall-clock time, not a stored expiry.
const INCURSION_CHANCE_DENOMINATOR := 3  ## invented v0: roughly 1-in-3 area-weeks are
## under an incursion -- most areas/weeks are quiet, matching "periodically... sweeps".
const ESSENCE_MULTIPLIER := 1.3  ## invented v0: incursion gates' "boosted... drops" --
## deliberately a different multiplier than GateBreak's 1.5x so the two bonus systems
## don't read as the same number reused.


## Coarse grid-cell key for a lat/lon -- the same real area always maps to
## the same key, independent of exact GPS jitter.
static func area_key(lat: float, lon: float) -> String:
	var cell_lat := int(floor(lat / AREA_CELL_DEGREES))
	var cell_lon := int(floor(lon / AREA_CELL_DEGREES))
	return "%d,%d" % [cell_lat, cell_lon]


## A deterministic, ever-increasing week index from a Unix timestamp --
## the same real week always gives the same number, everywhere, without a
## server to coordinate it.
static func week_number(now_unix: int) -> int:
	return int(floor(float(now_unix) / float(WEEK_SECONDS)))


## The family under incursion in `area` this `week`, or "" if that
## area+week isn't currently under one. Deterministic (Godot's String
## hash() is stable across runs for the same input) -- no RNG, so every
## hunter in the same area during the same week sees the same event.
static func active_family(area: String, week: int, families: Array) -> String:
	if families.is_empty():
		return ""
	var h := hash("%s|%d" % [area, week])
	var slot := h % (families.size() * INCURSION_CHANCE_DENOMINATOR)
	if slot < 0:
		slot += families.size() * INCURSION_CHANCE_DENOMINATOR
	if slot >= families.size():
		return ""
	return families[slot]


## The boosted Essence reward for clearing a gate inside an active
## incursion zone, on top of the normal per-rank gate reward
## (GameLogic.essence_for_gate).
static func bonus_essence(base_essence: int) -> int:
	return int(round(base_essence * ESSENCE_MULTIPLIER))
