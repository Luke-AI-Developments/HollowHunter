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
var next_inventory_id: int = 0  ## §17b: monotonic counter for inventory instance_ids. NOT
## inventory.size() (the old scheme) -- that gets reused after scrap_item() removes an item,
## colliding with a surviving item's id. Bulk scrap is what makes this reachable for the
## first time; fixed here rather than left as a "flagged gap" like the identical (still
## unfixed) pattern in claim_shadow()'s shadow ids, which nothing removes-then-adds fast
## enough to hit in practice today.
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
var current_streak: int  ## Phase 2/P5 step 1: consecutive days with daily EXP applied (§21).
## Updated via DailyExp.next_streak() using the OLD last_exp_date, right before
## mark_exp_applied(today) overwrites it -- see scenes/main.gd's daily-EXP flow.
var hunter_rank: String  ## Phase 2/P6 step 1: EARNED rank (E-S, §28) -- starts "E", only
## advances by clearing that rank's Trial (RankAssessment). Deliberately separate from
## GameLogic.rank_for_level(level), which is just the highest rank whose LEVEL threshold has
## been reached -- §28 is explicit that rank is "earned, not auto-granted". Everywhere that
## used to call rank_for_level(level) to mean "the hunter's rank" (gate spawning, the
## Character screen) was wrong per this section and got fixed to read hunter_rank instead;
## rank_for_level() is still correct and used, just for its real meaning: which Trial is
## currently unlocked for attempt.
var last_gate_break_offer: int  ## Phase 2/P8: Unix seconds of the last Gate Break offer (§8b),
## 0 = never. Same "scene layer supplies the wall clock" convention as
## stronghold_last_collected -- GateBreak.should_trigger() reads this as the cooldown anchor.
var active_party_ids: Array = []  ## Phase 3/step 6: up to 3 gate-squad (§17) shadow
## instance_ids the player has manually chosen to field (you + these 3 = the party of 4,
## §16). Empty = no manual pick yet -- SquadBuilder.resolve_party() falls back to
## auto-picking the strongest 3, the same behavior as before this field existed, so old
## saves (and anyone who never opens the Squad panel) are unaffected.
var crystals: int = 0  ## Phase 4/shop step 1: the premium currency (§14/§26) -- spent on
## Essence/ticket bundles and cosmetics via the Shop panel. Real-money acquisition (Google
## Play Billing) is NOT built (a separate native-plugin integration, out of scope for this
## patch); the one source implemented so far is RankAssessment's rank-up milestone reward
## (§26's "slow trickle from play/achievements").
var owned_cosmetics: Array = []  ## Phase 4/shop step 1: cosmetic ids (content/shop.json)
## the player has purchased. No visual effect yet -- this project is still placeholder-art
## throughout (§9b); ownership is tracked now so the real art pass can swap sprites in by
## data later without touching this system again.
var preset_id: String  ## §9b/§25: the 12 curated preset-hunter portraits
## (art/HollowHunter_ArtDropTool.html's PRESET_IDS -- "f1".."f6"/"m1"..
## "m6"). Picked once during onboarding, permanent -- same no-respec
## precedent as subclass (§21). Combined with GameLogic.stage_for_rank()
## to resolve the rank-appropriate portrait via
## ArtPaths.preset_portrait().
var stronghold_lat: float = 0.0  ## §22 map placement (new): where the player has
var stronghold_lon: float = 0.0  ## deployed their Stronghold, if anywhere yet.
var stronghold_placed: bool = false  ## false until place_stronghold() is called
## once -- old saves (before this field existed) default to false via
## from_dict(), same as a brand-new hunter who hasn't placed one yet: no
## marker shown, no proximity gate active.
var last_sanctuary_claim_at: int = 0  ## Unix seconds of the last Sanctuary
## claim, 0 = never. Global per-player, not per-sanctuary-id -- "a daily
## bonus" (§19) is singular, not stacked across however many Sanctuaries
## happen to be in the player's area.
var discovered_lorestone_ids: Array = []  ## Array[String] of PoiSpawner-
## generated lorestone ids ever discovered -- one-time-per-id-forever
## (§19: "a one-time small reward for finding them"), persists across
## areas so a player who walks to a new area can still discover its stone.


static func new_default(
	hunter_subclass: String = "WARRIOR", hunter_preset: String = "m1"
) -> HunterState:
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
	s.next_inventory_id = 0
	s.equipped = {}
	s.nadir_deepest_floor = 0
	s.stronghold_level = 1
	s.stronghold_facilities = _default_facilities()
	s.stronghold_last_collected = 0
	s.current_streak = 0
	s.hunter_rank = "E"
	s.last_gate_break_offer = 0
	s.active_party_ids = []
	s.crystals = 0
	s.owned_cosmetics = []
	s.preset_id = hunter_preset
	s.stronghold_lat = 0.0
	s.stronghold_lon = 0.0
	s.stronghold_placed = false
	s.last_sanctuary_claim_at = 0
	s.discovered_lorestone_ids = []
	return s


## Adds an unenhanced instance of the given equipment def to the inventory.
## Pure -- instance_id comes from next_inventory_id, which only ever
## increases, so it's safe across any number of scrap_item() removals.
func add_to_inventory(equipment_def_id: String) -> Dictionary:
	var item := {
		"instance_id": "eq_inst_%d" % next_inventory_id,
		"equipment_def_id": equipment_def_id,
		"enhancement_level": 0,
		"locked": false,
	}
	next_inventory_id += 1
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
		"idle_progress": 0.0,
		"nickname": "",
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


## §6c: sets a per-instance custom nickname, shown in place of the species
## name across the roster / squad picker / battle screen / Shadow Gear
## title (SquadBuilder.enrich_army resolves nickname -> display_name). An
## empty string clears it back to the species name -- always allowed, same
## "skip is always valid" rule TextFilter.is_valid_nickname encodes. False
## (no-op) if the shadow is unknown or the text fails TextFilter (too long
## / blocked word).
func set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	if not TextFilter.is_valid_nickname(nickname):
		return false
	army[idx]["nickname"] = TextFilter.sanitize_nickname(nickname)
	return true


## §17b: locks/unlocks an owned item, protecting it from scrap (single or
## bulk). Same shape as set_shadow_locked(). False (no-op) if unknown item.
func set_item_locked(instance_id: String, locked: bool) -> bool:
	var idx := _inventory_index(instance_id)
	if idx < 0:
		return false
	inventory[idx]["locked"] = locked
	return true


## Phase 3/step 6: toggles whether a shadow is one of the manually-chosen
## fielded 3 (§17's "tweak by hand"). Adding when active_party_ids is
## already at max_party_size is rejected (false, no-op) rather than
## bumping someone else out -- the caller (scene layer) decides how to
## surface that ("field 3 already chosen") rather than this silently
## picking who gets dropped. Removing always succeeds. No army-membership
## check here -- SquadBuilder.resolve_party() already tolerates stale ids
## (a shadow that left the squad) by skipping and backfilling.
func toggle_party_member(
	shadow_instance_id: String, fielded: bool, max_party_size: int = 3
) -> bool:
	var already_in := active_party_ids.has(shadow_instance_id)
	if fielded == already_in:
		return true
	if fielded:
		if active_party_ids.size() >= max_party_size:
			return false
		active_party_ids.append(shadow_instance_id)
	else:
		active_party_ids.erase(shadow_instance_id)
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


## Phase 2/P4 step 4: banks idle production accrued since
## stronghold_last_collected (elapsed = `now_unix_seconds` - that, capped
## at Stronghold.OFFLINE_CAP_HOURS by Stronghold.accrued itself). Reliquary
## -> Essence, Gate Watch -> gate_tickets (both straight int adds); Training
## Yard -> Stronghold.apply_idle_xp() per assigned shadow, updating its
## level/idle_progress and possibly leveling it up for free. Always resets
## stronghold_last_collected to `now_unix_seconds`, even with nothing
## assigned anywhere (0 elapsed accrual either way) -- so idle time never
## silently piles up past the offline cap while nothing's assigned. Returns
## a summary: {essence_gained, tickets_gained, shadow_levels_gained: {
## instance_id: levels}}.
func collect_stronghold(now_unix_seconds: int) -> Dictionary:
	var elapsed := float(max(0, now_unix_seconds - stronghold_last_collected))
	var essence_gained := 0
	var tickets_gained := 0
	var shadow_levels_gained := {}

	for facility_id in stronghold_facilities:
		var facility: Dictionary = stronghold_facilities[facility_id]
		var level: int = facility["level"]
		var assigned: Array = facility["assigned"]
		if assigned.is_empty():
			continue
		match facility_id:
			Stronghold.RELIQUARY:
				var gained := Stronghold.accrued(facility_id, elapsed, level, assigned.size())
				essence_gained += int(round(gained))
			Stronghold.GATE_WATCH:
				var gained := Stronghold.accrued(facility_id, elapsed, level, assigned.size())
				tickets_gained += int(round(gained))
			Stronghold.TRAINING_YARD:
				# Each assigned shadow independently earns the per-shadow rate
				# (assigned.size() isn't a divisor -- more shadows working the
				# yard means more TOTAL leveling, same as the other facilities).
				var idle_xp := Stronghold.accrued(facility_id, elapsed, level, 1)
				for shadow_id in assigned:
					var idx := _army_index(shadow_id)
					if idx < 0:
						continue
					var current_level: int = army[idx].get("level", 1)
					var current_progress: float = army[idx].get("idle_progress", 0.0)
					var result := Stronghold.apply_idle_xp(current_level, current_progress, idle_xp)
					army[idx]["level"] = result["level"]
					army[idx]["idle_progress"] = result["progress"]
					if result["levels_gained"] > 0:
						shadow_levels_gained[shadow_id] = result["levels_gained"]

	essence += essence_gained
	gate_tickets += tickets_gained
	stronghold_last_collected = now_unix_seconds
	return {
		"essence_gained": essence_gained,
		"tickets_gained": tickets_gained,
		"shadow_levels_gained": shadow_levels_gained,
	}


## Spends Essence to raise one facility's level by 1 (capped at
## Stronghold.FACILITY_LEVEL_CAP). False (no-op) if the facility id is
## unknown, already capped, or Essence is short.
func upgrade_facility(facility_id: String) -> bool:
	if not stronghold_facilities.has(facility_id):
		return false
	var facility: Dictionary = stronghold_facilities[facility_id]
	var current_level: int = facility["level"]
	if current_level >= Stronghold.FACILITY_LEVEL_CAP:
		return false
	var cost := Stronghold.facility_upgrade_cost(current_level + 1)
	if essence < cost:
		return false
	essence -= cost
	facility["level"] = current_level + 1
	return true


## Spends Essence to raise the Stronghold's own level by 1 (capped at
## Stronghold.STRONGHOLD_LEVEL_CAP), raising army_capacity(). False (no-op)
## if already capped or Essence is short.
func upgrade_stronghold() -> bool:
	if stronghold_level >= Stronghold.STRONGHOLD_LEVEL_CAP:
		return false
	var cost := Stronghold.stronghold_upgrade_cost(stronghold_level + 1)
	if essence < cost:
		return false
	essence -= cost
	stronghold_level += 1
	return true


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


## Runs auto_equip_shadow() over every shadow instance_id given -- the
## Squad tab's "Auto-Equip Squad" action (§17 QoL: "auto-equip best gear...
## across the whole squad"). Unknown ids are silently skipped (same
## tolerance auto_equip_shadow's own _army_index lookup already has).
## Returns the total number of slots changed across all shadows.
func auto_equip_squad(instance_ids: Array, equipment: Dictionary, monsters: Array) -> int:
	var count := 0
	for instance_id in instance_ids:
		count += auto_equip_shadow(instance_id, equipment, monsters)
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


## §17b: scraps an owned item for Essence (GameLogic.essence_for_scrapped_item,
## keyed by rarity). False/0 (no-op) if the item's unknown, locked, or
## currently worn by the hunter or any shadow (Inventory.wearer_of) --
## scrapping a worn item is a structural block here, not just a UI
## confirm-dialog.
func scrap_item(instance_id: String, equipment: Dictionary) -> int:
	var idx := _inventory_index(instance_id)
	if idx < 0:
		return 0
	var item: Dictionary = inventory[idx]
	if item.get("locked", false):
		return 0
	if Inventory.wearer_of(instance_id, equipped, army)["kind"] != "none":
		return 0
	var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
	var gained := GameLogic.essence_for_scrapped_item(def.get("rarity", ""))
	essence += gained
	inventory.remove_at(idx)
	return gained


## Scraps every given instance_id, skipping any that don't qualify (same
## shape as mass_convert() for shadows). Returns total Essence gained.
func bulk_scrap(instance_ids: Array, equipment: Dictionary) -> int:
	var before := essence
	for instance_id in instance_ids:
		scrap_item(instance_id, equipment)
	return essence - before


func _inventory_item(instance_id: String) -> Dictionary:
	for item: Dictionary in inventory:
		if item.get("instance_id", "") == instance_id:
			return item
	return {}


func _inventory_index(instance_id: String) -> int:
	for i in inventory.size():
		if inventory[i].get("instance_id", "") == instance_id:
			return i
	return -1


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


## Phase 2/P6 step 1: records passing `target_rank`'s Assessment --
## permanent, one-way (same shape as clear_nadir_floor). No-op (false) if
## `target_rank` isn't actually the very next rank above the current one --
## defensive; callers should already gate the attempt via
## RankAssessment.next_assessment_rank().
func pass_assessment(target_rank: String) -> bool:
	var current_idx := GameLogic.RANK_ORDER.find(hunter_rank)
	var target_idx := GameLogic.RANK_ORDER.find(target_rank)
	if current_idx < 0 or target_idx != current_idx + 1:
		return false
	hunter_rank = target_rank
	return true


## Phase 2/P7 step 1: spends one gate ticket (§8a "single-use ticket... to
## instantly open a gate"). False (no change) if none are held -- caller
## gates the actual gate spawn/encounter on this returning true, same
## pattern as the Essence-spending methods above (enhance_item et al.).
func spend_gate_ticket() -> bool:
	if gate_tickets <= 0:
		return false
	gate_tickets -= 1
	return true


## Phase 4/shop step 1: spends Crystals on a shop bundle/cosmetic (§14).
## False (no change) if the balance is short -- same afford-then-mutate
## pattern as spend_gate_ticket()/enhance_item(); the caller (scenes/
## main.gd) checks this before applying whatever the purchase actually
## grants (tickets/Essence/a cosmetic unlock), same as every other reward
## flow in this project.
func spend_crystals(amount: int) -> bool:
	if crystals < amount:
		return false
	crystals -= amount
	return true


## True if the cosmetic wasn't already owned (and is now). Duplicate
## purchases of an already-owned cosmetic should be blocked by the shop UI
## itself (nothing left to buy), but this stays idempotent/safe either way
## rather than assuming the caller always checks first.
func unlock_cosmetic(cosmetic_id: String) -> bool:
	if owned_cosmetics.has(cosmetic_id):
		return false
	owned_cosmetics.append(cosmetic_id)
	return true


## §22 map placement (new): sets/moves the Stronghold's map location.
## Callable any number of times -- re-placement is just calling this
## again, no separate first-time-vs-move code path.
func place_stronghold(lat: float, lon: float) -> void:
	stronghold_lat = lat
	stronghold_lon = lon
	stronghold_placed = true


## §19 Sanctuary claim (new): true and applies the reward if the cooldown
## has elapsed since the last claim; false (no change) otherwise. `now_unix`
## and the reward amounts are supplied by the caller (GameLogic constants +
## the scene layer's wall clock) -- stays pure, same convention as
## collect_stronghold().
func claim_sanctuary(
	now_unix: int, essence_reward: int, ticket_reward: int, cooldown_seconds: int
) -> bool:
	if last_sanctuary_claim_at != 0 and now_unix - last_sanctuary_claim_at < cooldown_seconds:
		return false
	essence += essence_reward
	gate_tickets += ticket_reward
	last_sanctuary_claim_at = now_unix
	return true


## §19 Lore Stone discovery (new): true and applies the reward if `stone_id`
## hasn't been discovered before; false (no change) if it has.
func discover_lorestone(stone_id: String, essence_reward: int) -> bool:
	if discovered_lorestone_ids.has(stone_id):
		return false
	discovered_lorestone_ids.append(stone_id)
	essence += essence_reward
	return true


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
		"next_inventory_id": next_inventory_id,
		"equipped": equipped,
		"nadir_deepest_floor": nadir_deepest_floor,
		"stronghold_level": stronghold_level,
		"stronghold_facilities": stronghold_facilities,
		"stronghold_last_collected": stronghold_last_collected,
		"current_streak": current_streak,
		"hunter_rank": hunter_rank,
		"last_gate_break_offer": last_gate_break_offer,
		"active_party_ids": active_party_ids,
		"crystals": crystals,
		"owned_cosmetics": owned_cosmetics,
		"preset_id": preset_id,
		"stronghold_lat": stronghold_lat,
		"stronghold_lon": stronghold_lon,
		"stronghold_placed": stronghold_placed,
		"last_sanctuary_claim_at": last_sanctuary_claim_at,
		"discovered_lorestone_ids": discovered_lorestone_ids,
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
	s.next_inventory_id = int(d.get("next_inventory_id", s.inventory.size()))
	s.equipped = d.get("equipped", {})
	s.nadir_deepest_floor = int(d.get("nadir_deepest_floor", 0))
	s.stronghold_level = int(d.get("stronghold_level", 1))
	s.stronghold_facilities = d.get("stronghold_facilities", _default_facilities())
	s.stronghold_last_collected = int(d.get("stronghold_last_collected", 0))
	s.current_streak = int(d.get("current_streak", 0))
	s.hunter_rank = String(d.get("hunter_rank", "E"))
	s.last_gate_break_offer = int(d.get("last_gate_break_offer", 0))
	s.active_party_ids = d.get("active_party_ids", [])
	s.crystals = int(d.get("crystals", 0))
	s.owned_cosmetics = d.get("owned_cosmetics", [])
	s.preset_id = String(d.get("preset_id", "m1"))
	s.stronghold_lat = float(d.get("stronghold_lat", 0.0))
	s.stronghold_lon = float(d.get("stronghold_lon", 0.0))
	s.stronghold_placed = bool(d.get("stronghold_placed", false))
	s.last_sanctuary_claim_at = int(d.get("last_sanctuary_claim_at", 0))
	s.discovered_lorestone_ids = d.get("discovered_lorestone_ids", [])
	return s


static func _default_facilities() -> Dictionary:
	return {
		"RELIQUARY": {"level": 1, "assigned": []},
		"TRAINING_YARD": {"level": 1, "assigned": []},
		"GATE_WATCH": {"level": 1, "assigned": []},
	}
