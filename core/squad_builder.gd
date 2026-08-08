class_name SquadBuilder
## Phase 1 step 6: auto-fills a class-slotted squad of GameLogic.SQUAD_SIZE
## (6) from the owned army -- one best-by-power shadow per class (§17's
## "one of each class + a flex"), plus the best remaining shadow of any
## class for the flex slot. Pure -- army + content in, squad out.

const CLASSES := ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]


## Enriches each owned shadow with its content (name, class) and computed
## power (GameLogic.shadow_power, including equipped gear -- Phase 2 patch 1
## step 3), for display and for auto_fill_squad to rank by. Shadows whose
## monster_id isn't found in content are skipped. `equipment`/`inventory`
## default to empty so existing callers (and old tests) that don't care
## about gear keep working with zero gear bonus.
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
		var gear := Equip.gear_bonus(shadow.get("equipped", {}), inventory, equipment)
		var gear_stat_sum := 0
		for v in gear["stat_mods"].values():
			gear_stat_sum += v
		var power := GameLogic.shadow_power(
			monster.get("base_power", 0),
			shadow.get("level", 1),
			hunter_level,
			gear["power_bonus"],
			gear_stat_sum
		)
		(
			enriched
			. append(
				{
					"instance_id": shadow.get("instance_id", ""),
					"monster_id": shadow.get("monster_id", ""),
					"monster_name": monster.get("name", ""),
					"grade": shadow.get("grade", ""),
					"level": shadow.get("level", 1),
					"clazz": monster.get("clazz", ""),
					"power": power,
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
