class_name SquadBuilder
## §17: enrich the army, sort it for the Party picker (sort_shadows), resolve
## the fielded party (resolve_party), pick mass-convert fodder (surplus_shadow_ids).
## Pure -- no engine deps.

const CLASSES := ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]


## Enriches each owned shadow with its content (name, class) and computed
## power (GameLogic.shadow_power, including equipped gear -- Phase 2 patch 1
## step 3 -- and active armor-set bonuses -- patch 3), for display. Shadows
## whose monster_id isn't found in content are skipped. `equipment`/`inventory`
## default to empty so existing callers (and old tests) that don't care about
## gear keep working with zero gear/set bonus.
static func enrich_army(
	army: Array,
	monsters: Array,
	hunter_level: int,
	equipment: Dictionary = {},
	inventory: Array = [],
	trait_pool: Array = []
) -> Array:
	var pool: Array = trait_pool if not trait_pool.is_empty() else Traits.load_pool()
	var enriched := []
	for shadow: Dictionary in army:
		var monster := Content.monster_by_id(monsters, shadow.get("monster_id", ""))
		if monster.is_empty():
			continue
		var tmods := Traits.stat_modifiers(pool, shadow.get("traits", []))
		var trait_power_pct: float = tmods["power_pct"]
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		var gear := Equip.gear_bonus(shadow_equipped, inventory, equipment)
		var set_bonus := ArmorSets.total_set_bonus(shadow_equipped, inventory, equipment)
		var gear_stat_sum := 0
		for v in gear["stat_mods"].values():
			gear_stat_sum += v
		for v in set_bonus["stat_mods"].values():
			gear_stat_sum += v
		## Per-stat merge of gear + active set stat_mods, for combat: the
		## battle party folds this into shadow_combat_stats the same way the
		## hunter's HunterState.combat_stats folds its own gear + set mods
		## (spec §10.2 -- both sides get gear AND set stat_mods).
		var combat_gear_stat_mods: Dictionary = gear["stat_mods"].duplicate()
		for stat: String in set_bonus["stat_mods"]:
			combat_gear_stat_mods[stat] = (
				int(combat_gear_stat_mods.get(stat, 0)) + int(set_bonus["stat_mods"][stat])
			)
		var power := GameLogic.shadow_power(
			monster.get("base_power", 0),
			shadow.get("level", 1),
			hunter_level,
			gear["power_bonus"],
			gear_stat_sum,
			trait_power_pct
		)
		power = GameLogic.apply_set_power_pct(power, set_bonus["power_pct"])
		var nickname: String = shadow.get("nickname", "")
		var monster_name: String = monster.get("name", "")
		(
			enriched
			. append(
				{
					"instance_id": shadow.get("instance_id", ""),
					"monster_id": shadow.get("monster_id", ""),
					"monster_name": monster_name,
					"nickname": nickname,
					"display_name": nickname if nickname != "" else monster_name,
					"grade": shadow.get("grade", ""),
					"grade_name": GameLogic.grade_name(shadow.get("grade", "")),
					"level": shadow.get("level", 1),
					"clazz": monster.get("clazz", ""),
					"family": monster.get("family", ""),
					"base_power": monster.get("base_power", 0),
					"power": power,
					"traits": Traits.resolve(pool, shadow.get("traits", [])),
					"trait_power_pct": trait_power_pct,
					"trait_combat_pct": tmods["combat_pct"],
					"combat_gear_stat_mods": combat_gear_stat_mods,
					"locked": shadow.get("locked", false),
					"favorite": shadow.get("favorite", false),
				}
			)
		)
	return enriched


## §17 (manual party pick): returns a NEW array of `enriched` sorted by `mode`.
## Does not mutate the input. `mode`:
##   "power" -- power desc
##   "level" -- level desc, then power desc
##   "rank"  -- grade S->E (GameLogic.RANK_ORDER index desc), then power desc
##   "role"  -- class in CLASSES order, then power desc
## Any other `mode` sorts as "power". An unknown grade/class (RANK_ORDER.find
## / CLASSES.find -> -1) sorts to an end; harmless since enrich_army always
## sources `grade`/`clazz` from content.
static func sort_shadows(enriched: Array, mode: String) -> Array:
	var out := enriched.duplicate()
	match mode:
		"level":
			out.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					if a["level"] != b["level"]:
						return a["level"] > b["level"]
					return a["power"] > b["power"]
			)
		"rank":
			out.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					var ra := GameLogic.RANK_ORDER.find(a["grade"])
					var rb := GameLogic.RANK_ORDER.find(b["grade"])
					if ra != rb:
						return ra > rb
					return a["power"] > b["power"]
			)
		"role":
			out.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					var ca := CLASSES.find(a["clazz"])
					var cb := CLASSES.find(b["clazz"])
					if ca != cb:
						return ca < cb
					return a["power"] > b["power"]
			)
		_:
			out.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a["power"] > b["power"]
			)
	return out


## §17 (manual party pick): the party of shadows that fights -- exactly the
## ones the player fielded via the Party picker (HunterState.active_party_ids),
## in pick order, first 3 only. Unknown ids (a shadow that left the army) and
## duplicates are skipped. Empty pick -> empty party (the player fights
## understrength: you + 0..2 shadows). No auto-fill, no backfill.
static func resolve_party(
	army: Array,
	monsters: Array,
	hunter_level: int,
	active_party_ids: Array,
	equipment: Dictionary = {},
	inventory: Array = []
) -> Array:
	var enriched := enrich_army(army, monsters, hunter_level, equipment, inventory)
	var by_id := {}
	for e: Dictionary in enriched:
		by_id[e["instance_id"]] = e
	var chosen := []
	var seen := {}
	for id in active_party_ids:
		if chosen.size() >= GameLogic.PARTY_SIZE:
			break
		if by_id.has(id) and not seen.has(id):
			chosen.append(by_id[id])
			seen[id] = true
	return chosen


## §17 "mass-convert weak shadows": the `count` weakest (lowest power) owned
## shadows that are neither locked nor currently fielded. Returns instance_ids,
## weakest-first. (Was: excluded an auto-optimised squad -- that concept is
## gone; the player's fielded party + locks are the only protection now.)
static func surplus_shadow_ids(
	army: Array,
	monsters: Array,
	hunter_level: int,
	count: int,
	active_party_ids: Array,
	equipment: Dictionary = {},
	inventory: Array = []
) -> Array:
	var enriched := enrich_army(army, monsters, hunter_level, equipment, inventory)
	var pool: Array = enriched.filter(
		func(e: Dictionary) -> bool:
			return not e["locked"] and not active_party_ids.has(e["instance_id"])
	)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] < b["power"])
	var ids := []
	for e: Dictionary in pool.slice(0, count):
		ids.append(e["instance_id"])
	return ids
