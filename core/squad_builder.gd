class_name SquadBuilder
## Phase 1 step 6: auto-fills a class-slotted squad of GameLogic.SQUAD_SIZE
## (6) from the owned army -- one best-by-power shadow per class (§17's
## "one of each class + a flex"), plus the best remaining shadow of any
## class for the flex slot. Pure -- army + content in, squad out.

const CLASSES := ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]


## Enriches each owned shadow with its content (name, class) and computed
## power (GameLogic.shadow_power, including equipped gear -- Phase 2 patch 1
## step 3 -- and active armor-set bonuses -- patch 3), for display and for
## auto_fill_squad to rank by. Shadows whose monster_id isn't found in
## content are skipped. `equipment`/`inventory` default to empty so existing
## callers (and old tests) that don't care about gear keep working with
## zero gear/set bonus.
static func enrich_army(
	army: Array,
	monsters: Array,
	hunter_level: int,
	equipment: Dictionary = {},
	inventory: Array = []
) -> Array:
	var enriched := []
	for shadow: Dictionary in army:
		var monster := Content.monster_by_id(monsters, shadow.get("monster_id", ""))
		if monster.is_empty():
			continue
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		var gear := Equip.gear_bonus(shadow_equipped, inventory, equipment)
		var set_bonus := ArmorSets.total_set_bonus(shadow_equipped, inventory, equipment)
		var gear_stat_sum := 0
		for v in gear["stat_mods"].values():
			gear_stat_sum += v
		for v in set_bonus["stat_mods"].values():
			gear_stat_sum += v
		var power := GameLogic.shadow_power(
			monster.get("base_power", 0),
			shadow.get("level", 1),
			hunter_level,
			gear["power_bonus"],
			gear_stat_sum
		)
		power = GameLogic.apply_set_power_pct(power, set_bonus["power_pct"])
		(
			enriched
			. append(
				{
					"instance_id": shadow.get("instance_id", ""),
					"monster_id": shadow.get("monster_id", ""),
					"monster_name": monster.get("name", ""),
					"grade": shadow.get("grade", ""),
					"grade_name": GameLogic.grade_name(shadow.get("grade", "")),
					"level": shadow.get("level", 1),
					"clazz": monster.get("clazz", ""),
					"power": power,
					"locked": shadow.get("locked", false),
					"favorite": shadow.get("favorite", false),
				}
			)
		)
	return enriched


static func auto_fill_squad(
	army: Array,
	monsters: Array,
	hunter_level: int,
	equipment: Dictionary = {},
	inventory: Array = []
) -> Array:
	var enriched := enrich_army(army, monsters, hunter_level, equipment, inventory)
	var squad := []
	var used_ids := {}

	for clazz in CLASSES:
		var best: Variant = null
		for e: Dictionary in enriched:
			if e["clazz"] != clazz or used_ids.has(e["instance_id"]):
				continue
			if best == null or e["power"] > best["power"]:
				best = e
		if best != null:
			squad.append(best)
			used_ids[best["instance_id"]] = true

	var flex: Variant = null
	for e: Dictionary in enriched:
		if used_ids.has(e["instance_id"]):
			continue
		if flex == null or e["power"] > flex["power"]:
			flex = e
	if flex != null:
		squad.append(flex)

	return squad


## Phase 3/step 5: the strongest `count` (default 3, §16's party size) of
## the auto-filled squad-of-6 -- the auto-pick default for which 3
## shadows join a fight, until step 6 adds a manual picker letting the
## player choose their own 3 of the 6. Simplest reasonable interpretation
## of "auto-optimize" extended to a smaller party -- the source doesn't
## say HOW the 3 should be auto-chosen once a manual picker also exists,
## only that they can be.
static func auto_fill_party(
	army: Array,
	monsters: Array,
	hunter_level: int,
	equipment: Dictionary = {},
	inventory: Array = [],
	count: int = 3
) -> Array:
	var squad := auto_fill_squad(army, monsters, hunter_level, equipment, inventory)
	squad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] > b["power"])
	return squad.slice(0, count)


## Phase 2/P2 step 4: the `count` weakest (lowest power) owned shadows that
## AREN'T in the auto-filled squad -- a "surplus" selection for mass-convert
## (§17). No formal definition of "surplus" is given in the source;
## not-in-squad plus lowest-power is the simplest reading. Returns
## instance_ids only, ascending by power (weakest first). Locked shadows
## (gap-closure QoL, §17 "Lock... protect key shadows from mass-convert")
## never appear in this pool, regardless of power or squad status.
static func surplus_shadow_ids(
	army: Array,
	monsters: Array,
	hunter_level: int,
	count: int,
	equipment: Dictionary = {},
	inventory: Array = []
) -> Array:
	var enriched := enrich_army(army, monsters, hunter_level, equipment, inventory)
	var squad := auto_fill_squad(army, monsters, hunter_level, equipment, inventory)
	var squad_ids := {}
	for member: Dictionary in squad:
		squad_ids[member["instance_id"]] = true

	var surplus: Array = enriched.filter(
		func(e: Dictionary) -> bool: return not squad_ids.has(e["instance_id"]) and not e["locked"]
	)
	surplus.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] < b["power"])

	var ids := []
	for e: Dictionary in surplus.slice(0, count):
		ids.append(e["instance_id"])
	return ids
