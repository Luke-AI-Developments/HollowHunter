class_name Traits
## §6b shadow traits -- roll on CLAIM + resolve for display. Pure (RNG
## only). Traits roll on CLAIM, persist, display, and drive stat effects:
## stat_modifiers() -> GameLogic.shadow_power / shadow_combat_stats (§6b).
## Rarity drives roll weighting; count 1-3.
##
## Weights are v0 (see content/traits.json _comment) -- tunable without
## touching this file's logic.

const RARITY_WEIGHT := {
	"common": 100.0,
	"uncommon": 45.0,
	"rare": 16.0,
	"epic": 5.0,
	"legendary": 1.5,
}
const COUNT_WEIGHT := {1: 55.0, 2: 33.0, 3: 12.0}


## Pass-through so callers depend on Traits, not Content, for the pool.
static func load_pool() -> Array:
	return Content.load_traits()


## 1..3 distinct trait ids, in roll order. Count is COUNT_WEIGHT-weighted;
## each pick is RARITY_WEIGHT-weighted over the traits not yet picked.
static func roll_traits(pool: Array, rng: RandomNumberGenerator) -> Array:
	if pool.is_empty():
		return []
	var count: int = _weighted_key(COUNT_WEIGHT, rng)
	count = mini(count, pool.size())
	var remaining := pool.duplicate()
	var picked: Array = []
	for _i in range(count):
		var idx := _weighted_index_by_rarity(remaining, rng)
		picked.append(remaining[idx]["id"])
		remaining.remove_at(idx)
	return picked


## Array[String] ids -> Array[Dictionary] {id,name,rarity,polarity,effect_text},
## order preserved, unknown ids dropped.
static func resolve(pool: Array, trait_ids: Array) -> Array:
	var by_id := {}
	for t: Dictionary in pool:
		by_id[t["id"]] = t
	var out: Array = []
	for id in trait_ids:
		if by_id.has(id):
			var t: Dictionary = by_id[id]
			(
				out
				. append(
					{
						"id": t["id"],
						"name": t["name"],
						"rarity": t["rarity"],
						"polarity": t["polarity"],
						"effect_text": t["effect_text"],
					}
				)
			)
	return out


## Sums the `mods` of the given trait ids into one modifier dict:
##   { "power_pct": float, "combat_pct": { <STAT>: float, ... } }
## Unknown ids and traits with no mods contribute nothing. combat_pct only
## carries stats at least one trait touches. Order-independent.
static func stat_modifiers(pool: Array, trait_ids: Array) -> Dictionary:
	var by_id := {}
	for t: Dictionary in pool:
		by_id[t["id"]] = t
	var power_pct := 0.0
	var combat_pct := {}
	for id in trait_ids:
		if not by_id.has(id):
			continue
		var mods: Dictionary = by_id[id].get("mods", {})
		power_pct += float(mods.get("power_pct", 0.0))
		var cp: Dictionary = mods.get("combat_pct", {})
		for stat in cp:
			combat_pct[stat] = float(combat_pct.get(stat, 0.0)) + float(cp[stat])
	return {"power_pct": power_pct, "combat_pct": combat_pct}


## §6b: player-facing magnitude lines for ONE trait, from its `mods`.
## combat_pct stats render as "+N% <STAT>"; power_pct renders as "+N% power"
## only for traits with no combat_pct (the combat-only traits' derived
## power_pct from the ranking-visibility pass is an internal value, not a
## shown effect) -- monarchs_favour is the one trait that legitimately shows
## both. Unknown ids / empty mods -> []. Order: power_pct line first (if
## shown), then combat_pct stats in dict order. Used by the claim/detail
## card (scenes/shadow_reveal_card.gd).
static func effect_lines(pool: Array, trait_id: String) -> Array:
	var by_id := {}
	for t: Dictionary in pool:
		by_id[t["id"]] = t
	if not by_id.has(trait_id):
		return []
	var mods: Dictionary = by_id[trait_id].get("mods", {})
	var combat_pct: Dictionary = mods.get("combat_pct", {})
	var lines: Array = []
	var show_power: bool = (
		mods.has("power_pct") and (combat_pct.is_empty() or trait_id == "monarchs_favour")
	)
	if show_power:
		lines.append(_pct_line(float(mods["power_pct"]), "power"))
	for stat in combat_pct:
		lines.append(_pct_line(float(combat_pct[stat]), String(stat)))
	return lines


static func _pct_line(pct: float, label: String) -> String:
	var n := int(round(pct * 100.0))
	return "%s%d%% %s" % ["+" if n >= 0 else "", n, label]


static func _weighted_key(weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll < 0.0:
			return int(key)
	return int(weights.keys()[weights.size() - 1])


static func _weighted_index_by_rarity(entries: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for e: Dictionary in entries:
		total += float(RARITY_WEIGHT.get(e["rarity"], 1.0))
	var roll := rng.randf() * total
	for i in entries.size():
		roll -= float(RARITY_WEIGHT.get(entries[i]["rarity"], 1.0))
		if roll < 0.0:
			return i
	return entries.size() - 1
