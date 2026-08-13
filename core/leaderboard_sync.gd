class_name LeaderboardSync
## Phase 5/P7a: pure payload-building/parsing for the leaderboard sync
## (§9/§31 -- backend + rankings scoping). No network here -- that's
## autoload/backend_service.gd's job; this only shapes JSON in and out,
## so it's testable without a live Supabase project. Matches the same
## pure/impure split as everything else in this project (core/ = logic,
## autoload/ = the actual I/O).


## The row this hunter's leaderboard entry upserts to (§31's schema --
## user_id/display_name/updated_at are added by BackendService, not
## here, since they come from the session/a separate name-claim call,
## not from HunterState). personal_power needs `equipment` the same way
## state.personal_power() already does everywhere else in this project.
static func upsert_payload(state: HunterState, equipment: Dictionary) -> Dictionary:
	return {
		"hunter_rank": state.hunter_rank,
		"hunter_level": state.level,
		"personal_power": state.personal_power(equipment),
		"deepest_nadir_floor": state.nadir_deepest_floor,
	}


## Numbers a raw Supabase response (already sorted by whichever board the
## caller queried -- personal_power/deepest_nadir_floor/hunter_level,
## §9) into 1-based leaderboard positions, defaulting any missing field
## rather than failing on a malformed row.
static func rank_rows(rows: Array) -> Array:
	var ranked := []
	for i in rows.size():
		var row: Dictionary = rows[i]
		(
			ranked
			. append(
				{
					"position": i + 1,
					"display_name": String(row.get("display_name", "Hunter")),
					"hunter_rank": String(row.get("hunter_rank", "E")),
					"hunter_level": int(row.get("hunter_level", 1)),
					"personal_power": int(row.get("personal_power", 0)),
					"deepest_nadir_floor": int(row.get("deepest_nadir_floor", 0)),
				}
			)
		)
	return ranked


## Minimal client-side sanity check before spending a network round trip
## on the account-linking form (§31) -- real validation is Supabase's own
## job (confirmation email, uniqueness), this just catches "forgot the @"
## typos early. Deliberately simple, not a full RFC 5322 validator.
static func is_valid_email(email: String) -> bool:
	var at := email.find("@")
	if at <= 0 or at != email.rfind("@"):
		return false
	var domain := email.substr(at + 1)
	return domain.find(".") > 0 and not domain.ends_with(".")
