class_name HunterState
## The hunter's persistent progression state: level, EXP, subclass, and the
## soft currencies. Pure -- to_dict()/from_dict() are the only interface to
## the outside world, no file I/O here (see autoload/save_service.gd).

var level: int
var exp_into_level: int  ## progress toward exp_to_next(level); resets on level-up
var total_exp: int  ## lifetime total, cosmetic/statistic only
var subclass: String  ## WARRIOR / GUARDIAN / ASSASSIN / MAGE / SUPPORT
var essence: int
var gate_tickets: int
var army: Array  ## Array[Dictionary]: {instance_id, monster_id, grade, level}. Class isn't
## stored per-shadow -- look it up from monster_id via Content when needed, same as the
## design bible's ShadowInstance (don't duplicate content data into save state).
var last_exp_date: String  ## "YYYY-MM-DD" (device-local calendar date) of the last daily-EXP
## grant, "" if never. NOTE: the native plugin's readTodaySteps()/readRecentWorkouts() use a
## rolling 24h window, not a calendar day -- this guard stops same-day relaunch double-counts,
## but doesn't perfectly line up with that window (e.g. playing at 11pm then 1am still counts
## as two different calendar days despite mostly-overlapping step data). Good enough for v0.
var inventory: Array  ## Array[Dictionary]: {instance_id, equipment_def_id, enhancement_level}.
## Like army, doesn't duplicate content data -- look up name/slot/rarity/stat_mods/power_bonus
## from equipment_def_id via Content when needed.
var equipped: Dictionary  ## slot (Equip.SLOTS) -> inventory instance_id. The hunter's own
## 7-slot loadout. Each army shadow carries its own equipped dict too (see claim_shadow()).
var nadir_deepest_floor: int  ## Phase 2/P3 step 1: highest Nadir floor ever cleared (§20) --
## 0 = none cleared yet. Permanent, one-way (clearing is forever, never decreases). The
## design bible's "NadirState" is just this field: everything else here already lives flat
## on HunterState (army/inventory/equipped etc.), so a separate class would break that
## convention for one int.
var stronghold_level: int  ## Phase 2/P4 step 1: Stronghold upgrade level (§22) -- raises
## army roster capacity (Stronghold.army_capacity()). NOTE: capacity is computed/displayed
## but NOT enforced against claim_shadow() in this patch -- claim_shadow is called from
## several places (gate clears, Nadir boss claims) and is already covered by 40+ existing
## tests; retrofitting a hard block felt like scope creep onto an unrelated, heavily-used
## method for what the source treats as a soft progression number. Flagged as a real gap.
var stronghold_facilities: Dictionary  ## facility_id (Stronghold.FACILITY_IDS) -> {level:
## int, assigned: Array[String] (shadow instance_ids)}. A shadow can only be assigned to one
## facility at a time (Stronghold.is_shadow_assigned() enforces it), but assignment does NOT
## exclude a shadow from the auto-filled gate squad (SquadBuilder) in this patch -- the
## source's "assigned shadows are busy" would mean threading Stronghold state through
## SquadBuilder's signature for a fifth time this project; deferred, flagged as a real gap.
var stronghold_last_collected: int  ## Unix seconds of the last Stronghold collection, 0 =
## never (set for real by the scene layer on first game start -- new_default() can't call
## Time.get_unix_time_from_system(), core stays engine-free). Idle production between this
## and "now" (also supplied by the caller) is what Stronghold.accrued() computes.


static func new_default(hunter_subclass: String = "WARRIOR") -> HunterState:
	var s := HunterState.new()
	s.level = 1
	s.exp_into_level = 0
	s.total_exp = 0
	s.subclass = hunter_subclass
	s.essence = 0
	s.gate_tickets = 0
	s.army = []
	s.last_exp_date = ""
	s.inventory = []
	s.equipped = {}
	s.nadir_deepest_floor = 0
	s.stronghold_level = 1
	s.stronghold_facilities = _default_facilities()
	s.stronghold_last_collected = 0
	return s


## Adds an unenhanced instance of the given equipment def to the inventory.
## Pure -- instance_id is index-based, same convention as claim_shadow().
func add_to_inventory(equipment_def_id: String) -> Dictionary:
	var item := {
		"instance_id": "eq_inst_%d" % inventory.size(),
		"equipment_def_id": equipment_def_id,
		"enhancement_level": 0,
	}
	inventory.append(item)
	return item


func has_applied_exp_today(today: String) -> bool:
	return last_exp_date == today


func mark_exp_applied(today: String) -> void:
	last_exp_date = today


## Adds a level-1 shadow of the given monster/grade to the army. Pure --
## instance_id is just index-based (no wall-clock/UUID dependency, keeps
## this deterministic and testable).
func claim_shadow(monster_id: String, grade: String) -> Dictionary:
	var shadow := {
		"instance_id": "shadow_%d" % army.size(),
		"monster_id": monster_id,
		"grade": grade,
		"level": 1,
		"equipped": {},
		"locked": false,
		"favorite": false,
	}
	army.append(shadow)
	return shadow


## Phase 2/P2 gap closure: "Lock / favorite -- protect key shadows from
## mass-convert and flag favorites" (§17). Locking blocks that shadow from
## SquadBuilder.surplus_shadow_ids' mass-convert pool; it does NOT block an
## explicit single convert_shadow() call on it -- that's a deliberate
## one-shadow action, not the accidental-sweep scenario locking exists for.
## Favorite has no mechanical effect (the source only says "flag
## favorites") -- it's carried through for display/filtering only.
func set_shadow_locked(shadow_instance_id: String, locked: bool) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	army[idx]["locked"] = locked
	return true


func set_shadow_favorite(shadow_instance_id: String, favorite: bool) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	army[idx]["favorite"] = favorite
	return true


## True if the inventory item is currently equipped on the hunter or any
## shadow -- an item instance can only be worn by one wearer at a time.
func is_instance_equipped(instance_id: String) -> bool:
	if equipped.values().has(instance_id):
		return true
	for shadow: Dictionary in army:
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		if shadow_equipped.values().has(instance_id):
			return true
	return false


## Equips an owned item onto the hunter, in its def's slot, if the hunter's
## subclass matches the item's class (Equip.can_equip) and the item isn't
## already worn by the hunter or a shadow. Swaps out whatever was in that
## slot (it becomes free again, not lost -- still in `inventory`). Returns
## true on success; false (no change) otherwise -- caller/UI decides how to
## surface the failure reason.
func equip_to_hunter(instance_id: String, equipment: Dictionary) -> bool:
	var item := _inventory_item(instance_id)
	if item.is_empty() or is_instance_equipped(instance_id):
		return false
	var def := Content.equipment_by_id(equipment, item["equipment_def_id"])
	if def.is_empty() or not Equip.can_equip(def, subclass):
		return false
	equipped = Equip.equip(equipped, def, instance_id, subclass)
	return true


func unequip_from_hunter(slot: String) -> void:
	equipped = Equip.unequip(equipped, slot)


## Same as equip_to_hunter but for a shadow in the army. A shadow's class
## isn't stored on it (see `army` field comment) -- it's looked up from its
## monster_id via Content.
func equip_to_shadow(
	shadow_instance_id: String, item_instance_id: String, equipment: Dictionary, monsters: Array
) -> bool:
	var shadow_idx := _army_index(shadow_instance_id)
	if shadow_idx < 0:
		return false
	var item := _inventory_item(item_instance_id)
	if item.is_empty() or is_instance_equipped(item_instance_id):
		return false
	var monster := Content.monster_by_id(monsters, army[shadow_idx]["monster_id"])
	var shadow_class: String = monster.get("clazz", "")
	var def := Content.equipment_by_id(equipment, item["equipment_def_id"])
	if def.is_empty() or not Equip.can_equip(def, shadow_class):
		return false
	var shadow_equipped: Dictionary = army[shadow_idx].get("equipped", {})
	army[shadow_idx]["equipped"] = Equip.equip(shadow_equipped, def, item_instance_id, shadow_class)
	return true


func unequip_from_shadow(shadow_instance_id: String, slot: String) -> void:
	var shadow_idx := _army_index(shadow_instance_id)
	if shadow_idx < 0:
		return
	var shadow_equipped: Dictionary = army[shadow_idx].get("equipped", {})
	army[shadow_idx]["equipped"] = Equip.unequip(shadow_equipped, slot)


## Phase 2/P2 step 2: levels a shadow up by exactly 1, spending Essence per
## ShadowLeveling.level_up_cost(). No-op (false, nothing changed) if the
## shadow's unknown, already at ShadowLeveling.LEVEL_CAP, or Essence is short.
func level_up_shadow(shadow_instance_id: String) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	var current_level: int = army[idx].get("level", 1)
	if current_level >= ShadowLeveling.LEVEL_CAP:
		return false
	var cost := ShadowLeveling.level_up_cost(current_level + 1)
	if essence < cost:
		return false
	essence -= cost
	army[idx]["level"] = current_level + 1
	return true


## Phase 2/P2 step 3: finds another owned shadow sharing `shadow_instance_id`'s
## monster_id (a duplicate to fuse in) -- "" if none owned. First match in
## army order.
func find_duplicate_of(shadow_instance_id: String) -> String:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return ""
	var monster_id: String = army[idx]["monster_id"]
	for shadow: Dictionary in army:
		if (
			shadow["instance_id"] != shadow_instance_id
			and shadow.get("monster_id", "") == monster_id
		):
			return shadow["instance_id"]
	return ""


## Fuses `duplicate_instance_id` into `target_instance_id`: consumes
## (removes) the duplicate and grants the target ShadowLeveling.
## FUSE_LEVEL_CHUNK levels (capped at LEVEL_CAP), spending Essence per
## ShadowLeveling.fuse_cost(). Both must exist, be different shadows, and
## share a monster_id. No-op (false, nothing changed) otherwise.
func fuse_shadow(target_instance_id: String, duplicate_instance_id: String) -> bool:
	if target_instance_id == duplicate_instance_id:
		return false
	var target_idx := _army_index(target_instance_id)
	var dup_idx := _army_index(duplicate_instance_id)
	if target_idx < 0 or dup_idx < 0:
		return false
	if army[target_idx]["monster_id"] != army[dup_idx]["monster_id"]:
		return false
	var current_level: int = army[target_idx].get("level", 1)
	if current_level >= ShadowLeveling.LEVEL_CAP:
		return false
	var cost := ShadowLeveling.fuse_cost(current_level)
	if essence < cost:
		return false
	essence -= cost
	army[target_idx]["level"] = ShadowLeveling.fuse_result_level(current_level)
	army.remove_at(dup_idx)
	return true


## Phase 2/P2 step 4: removes a shadow from the army, granting Essence per
## its grade (§26's real per-grade table). False (no-op) if unknown shadow.
func convert_shadow(shadow_instance_id: String) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	var grade: String = army[idx].get("grade", "")
	essence += GameLogic.essence_for_converted_shadow(grade)
	army.remove_at(idx)
	return true


## Converts every given shadow instance_id (skipping any not found).
## Returns total Essence gained.
func mass_convert(shadow_instance_ids: Array) -> int:
	var before := essence
	for instance_id in shadow_instance_ids:
		convert_shadow(instance_id)
	return essence - before


## Phase 2/P4 step 1: true if `shadow_instance_id` is currently assigned to
## any Stronghold facility ("busy" per §22).
func is_shadow_assigned(shadow_instance_id: String) -> bool:
	for facility_id in stronghold_facilities:
		var assigned: Array = stronghold_facilities[facility_id]["assigned"]
		if assigned.has(shadow_instance_id):
			return true
	return false


## Assigns an owned, unassigned shadow to `facility_id`, if the facility
## has a free slot (Stronghold.slots_for_level). False (no-op) if the
## shadow's unknown, already assigned somewhere, the facility id is
## invalid, or the facility is full.
func assign_shadow_to_facility(facility_id: String, shadow_instance_id: String) -> bool:
	if _army_index(shadow_instance_id) < 0:
		return false
	if is_shadow_assigned(shadow_instance_id):
		return false
	if not stronghold_facilities.has(facility_id):
		return false
	var facility: Dictionary = stronghold_facilities[facility_id]
	var assigned: Array = facility["assigned"]
	if assigned.size() >= Stronghold.slots_for_level(facility["level"]):
		return false
	assigned.append(shadow_instance_id)
	return true


## Unassigns a shadow from whichever facility it's in (no-op if it isn't
## assigned anywhere).
func unassign_shadow(shadow_instance_id: String) -> void:
	for facility_id in stronghold_facilities:
		var assigned: Array = stronghold_facilities[facility_id]["assigned"]
		assigned.erase(shadow_instance_id)


## Phase 2 patch 1 step 4: equips the single best owned item into `slot` for
## the hunter, if a strictly better one than what's already there exists.
## The slot's current occupant re-competes as its own candidate (excluded
## from `taken`) rather than being auto-skipped -- so a slot that's already
## optimal is left alone instead of being swapped for something worse.
## Returns true if the equipped item changed.
func equip_best_to_hunter(slot: String, equipment: Dictionary) -> bool:
	var current_id: String = equipped.get(slot, "")
	var taken: Array = equipped.values() + _all_shadow_equipped_ids()
	taken.erase(current_id)
	var candidate := Equip.best_candidate(slot, subclass, inventory, equipment, taken)
	if candidate == "":
		return false
	return equip_to_hunter(candidate, equipment)


## Runs equip_best_to_hunter over all 7 slots. Returns how many changed.
func auto_equip_hunter(equipment: Dictionary) -> int:
	var count := 0
	for slot in Equip.SLOTS:
		if equip_best_to_hunter(slot, equipment):
			count += 1
	return count


## Same as equip_best_to_hunter but for a shadow in the army.
func equip_best_to_shadow(
	shadow_instance_id: String, slot: String, equipment: Dictionary, monsters: Array
) -> bool:
	var shadow_idx := _army_index(shadow_instance_id)
	if shadow_idx < 0:
		return false
	var monster := Content.monster_by_id(monsters, army[shadow_idx]["monster_id"])
	var shadow_class: String = monster.get("clazz", "")
	var shadow_equipped: Dictionary = army[shadow_idx].get("equipped", {})
	var current_id: String = shadow_equipped.get(slot, "")
	var taken: Array = equipped.values() + _all_shadow_equipped_ids()
	taken.erase(current_id)
	var candidate := Equip.best_candidate(slot, shadow_class, inventory, equipment, taken)
	if candidate == "":
		return false
	return equip_to_shadow(shadow_instance_id, candidate, equipment, monsters)


## Runs equip_best_to_shadow over all 7 slots for one shadow. Returns how
## many changed.
func auto_equip_shadow(shadow_instance_id: String, equipment: Dictionary, monsters: Array) -> int:
	var count := 0
	for slot in Equip.SLOTS:
		if equip_best_to_shadow(shadow_instance_id, slot, equipment, monsters):
			count += 1
	return count


func _all_shadow_equipped_ids() -> Array:
	var ids := []
	for shadow: Dictionary in army:
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		ids.append_array(shadow_equipped.values())
	return ids


## Phase 2 patch 1 step 5: spends Essence to enhance an owned item by one
## level (0..Equip.MAX_ENHANCEMENT). Mutates the inventory entry in place
## (same convention as equip_to_shadow mutating `army` in place). Returns
## true on success; false (no change) if the item doesn't exist, is already
## maxed, or Essence is short.
func enhance_item(instance_id: String) -> bool:
	var item := _inventory_item(instance_id)
	if item.is_empty():
		return false
	var current_level: int = item.get("enhancement_level", 0)
	if current_level >= Equip.MAX_ENHANCEMENT:
		return false
	var next_level := current_level + 1
	var cost := Equip.enhancement_cost(next_level)
	if essence < cost:
		return false
	essence -= cost
	item["enhancement_level"] = next_level
	return true


func _inventory_item(instance_id: String) -> Dictionary:
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


func _army_index(shadow_instance_id: String) -> int:
	for i in army.size():
		if army[i].get("instance_id", "") == shadow_instance_id:
			return i
	return -1


## Stats derived from level x subclass (§16), via GameLogic -- this is the
## "wiring" point between saved state and pure formulas.
func stats() -> Dictionary:
	return GameLogic.stats_from(level, subclass)


## personal_power including equipped gear AND active armor-set bonuses
## (Phase 2 patch 1 step 3 + patch 3). Merges gear + set stat_mods into base
## stats (personal_power sums the whole stats dict, so these have to be
## folded in BEFORE calling it, not passed separately like shadow_power's
## scalar gear_stat_bonus), passes gear's power_bonus straight through, then
## applies any active set's power%% on top (ArmorSets.apply_set_power_pct).
func personal_power(equipment: Dictionary) -> int:
	var bonus := Equip.gear_bonus(equipped, inventory, equipment)
	var set_bonus := ArmorSets.total_set_bonus(equipped, inventory, equipment)
	var combined := stats().duplicate()
	for stat in bonus["stat_mods"]:
		combined[stat] = combined.get(stat, 0) + bonus["stat_mods"][stat]
	for stat in set_bonus["stat_mods"]:
		combined[stat] = combined.get(stat, 0) + set_bonus["stat_mods"][stat]
	var base := GameLogic.personal_power(combined, level, bonus["power_bonus"])
	return GameLogic.apply_set_power_pct(base, set_bonus["power_pct"])


## Adds EXP, applies any level-ups (can be more than one), returns how many
## levels were gained. Pure -- no signals, no side effects beyond self.
func add_exp(amount: int) -> int:
	if amount <= 0:
		return 0
	total_exp += amount
	exp_into_level += amount
	var levels_gained := 0
	while exp_into_level >= GameLogic.exp_to_next(level):
		exp_into_level -= GameLogic.exp_to_next(level)
		level += 1
		levels_gained += 1
	return levels_gained


## Phase 2/P3 step 1: the next Nadir floor to attempt -- one past the
## deepest ever cleared. Floor numbering starts at 1 (§20's "floor 1
## trivial").
func nadir_current_floor() -> int:
	return nadir_deepest_floor + 1


## Records a floor clear. One-way -- `max()` means clearing the current (or
## any) floor can only advance or hold deepest_floor, never move it
## backward, so calling this out of order (or twice) is always safe.
func clear_nadir_floor(floor_n: int) -> void:
	nadir_deepest_floor = max(nadir_deepest_floor, floor_n)


func to_dict() -> Dictionary:
	return {
		"level": level,
		"exp_into_level": exp_into_level,
		"total_exp": total_exp,
		"subclass": subclass,
		"essence": essence,
		"gate_tickets": gate_tickets,
		"army": army,
		"last_exp_date": last_exp_date,
		"inventory": inventory,
		"equipped": equipped,
		"nadir_deepest_floor": nadir_deepest_floor,
		"stronghold_level": stronghold_level,
		"stronghold_facilities": stronghold_facilities,
		"stronghold_last_collected": stronghold_last_collected,
	}


static func from_dict(d: Dictionary) -> HunterState:
	var s := HunterState.new()
	s.level = int(d.get("level", 1))
	s.exp_into_level = int(d.get("exp_into_level", 0))
	s.total_exp = int(d.get("total_exp", 0))
	s.subclass = String(d.get("subclass", "WARRIOR"))
	s.essence = int(d.get("essence", 0))
	s.gate_tickets = int(d.get("gate_tickets", 0))
	s.army = d.get("army", [])
	s.last_exp_date = String(d.get("last_exp_date", ""))
	s.inventory = d.get("inventory", [])
	s.equipped = d.get("equipped", {})
	s.nadir_deepest_floor = int(d.get("nadir_deepest_floor", 0))
	s.stronghold_level = int(d.get("stronghold_level", 1))
	s.stronghold_facilities = d.get("stronghold_facilities", _default_facilities())
	s.stronghold_last_collected = int(d.get("stronghold_last_collected", 0))
	return s


static func _default_facilities() -> Dictionary:
	return {
		"RELIQUARY": {"level": 1, "assigned": []},
		"TRAINING_YARD": {"level": 1, "assigned": []},
		"GATE_WATCH": {"level": 1, "assigned": []},
	}
