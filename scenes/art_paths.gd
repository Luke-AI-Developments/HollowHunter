class_name ArtPaths
## Resolves a content id to its real art file, falling back to `null` when
## no art exists yet for that id -- the placeholder-first convention this
## whole project follows (§24: swap art in by data ID, no code changes).
## Engine-dependent (ResourceLoader/Texture2D), so this lives in scenes/
## rather than core/. Shared by every screen that shows a portrait/icon
## (army roster, inventory grid, battle slots) rather than duplicating the
## same load-if-exists check in each.

## §9b/§25: the 12 curated preset-hunter ids, exactly matching
## art/HollowHunter_ArtDropTool.html's PRESET_IDS constant -- single
## source of truth the onboarding preset-picker screen (scenes/main.gd)
## loops over to build its grid, rather than duplicating this list there.
const PRESET_IDS := ["f1", "f2", "f3", "f4", "f5", "f6", "m1", "m2", "m3", "m4", "m5", "m6"]


static func monster_portrait(monster_id: String) -> Texture2D:
	var path := "res://art/monsters/por_%s.webp" % monster_id
	return load(path) if ResourceLoader.exists(path) else null


static func equipment_icon(equipment_def_id: String) -> Texture2D:
	var path := "res://art/equipment/spr_%s.webp" % equipment_def_id
	return load(path) if ResourceLoader.exists(path) else null


static func set_showcase(set_id: String) -> Texture2D:
	var path := "res://art/sets/%s.webp" % set_id
	return load(path) if ResourceLoader.exists(path) else null


static func preset_portrait(preset_id: String, stage: String) -> Texture2D:
	var path := "res://art/presets/preset_hunter_%s_%s.webp" % [preset_id, stage]
	return load(path) if ResourceLoader.exists(path) else null


## §19: map markers (player position, gate, sanctuary, stronghold,
## incursion, nadir, lorestone) -- marker_id is the bare name, e.g.
## "player" for art/map/map_player.webp.
static func map_marker(marker_id: String) -> Texture2D:
	var path := "res://art/map/map_%s.webp" % marker_id
	return load(path) if ResourceLoader.exists(path) else null
