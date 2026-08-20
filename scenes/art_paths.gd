class_name ArtPaths
## Resolves a content id to its real art file, falling back to `null` when
## no art exists yet for that id -- the placeholder-first convention this
## whole project follows (§24: swap art in by data ID, no code changes).
## Engine-dependent (ResourceLoader/Texture2D), so this lives in scenes/
## rather than core/. Shared by every screen that shows a portrait/icon
## (army roster, inventory grid, battle slots) rather than duplicating the
## same load-if-exists check in each.


static func monster_portrait(monster_id: String) -> Texture2D:
	var path := "res://art/monsters/por_%s.png" % monster_id
	return load(path) if ResourceLoader.exists(path) else null


static func equipment_icon(equipment_def_id: String) -> Texture2D:
	var path := "res://art/equipment/spr_%s.png" % equipment_def_id
	return load(path) if ResourceLoader.exists(path) else null


static func set_showcase(set_id: String) -> Texture2D:
	var path := "res://art/sets/%s.png" % set_id
	return load(path) if ResourceLoader.exists(path) else null
