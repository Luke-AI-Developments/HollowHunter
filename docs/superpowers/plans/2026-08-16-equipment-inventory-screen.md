# §17b Equipment Inventory Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** build the §17b Equipment inventory screen — the browse/maintain layer around the paper-doll §17 already built: a filterable/sortable icon grid, item detail with a Compare-vs-currently-equipped view, a Sets-progress tab, and bulk scrap-to-Essence with a hard structural guard against scrapping locked/equipped items.

**Architecture:** one new pure module (`core/inventory.gd`) for filter/sort/wearer-lookup/compare/scrap-candidate logic, small additions to `HunterState`/`GameLogic`/`ArmorSets`, and one new self-contained screen controller (`scenes/inventory_view.gd`, same `StrongholdView`/`ArmyView` pattern — holds `HunterState` directly, mutates it, saves, emits `state_changed`). The screen is reachable two ways: standalone (its own HUD button, no context, no Compare) and via a new "Browse" button on each gear-slot row in `shadow_gear_view.gd`/`hunter_gear_view.gd` (pre-filtered to that slot+class, carrying the shadow/hunter as Compare context) — the second path is built last, once the screen it opens actually exists, avoiding the forward-reference mistake §17's plan made the first time around.

**Tech Stack:** Godot 4 / GDScript, GUT for `core/` tests, text-format `.tscn` editing.

## Global Constraints

- Static typing everywhere, tabs for indentation, `snake_case` — per `CLAUDE.md`.
- `core/` stays pure/engine-free and unit-tested; `scenes/` stays thin view code, manually verified (no GUT for scene controllers) — per `CLAUDE.md`'s folder-layout rule and this project's established convention.
- The post-edit hook (`.claude/settings.json`) runs `gdformat`+`gdlint`+the full GUT suite on every `core/`/`scenes/` `.gd` save.
- Spec source: `docs/superpowers/specs/2026-08-16-army-equipment-screens-design.md` §3 — read it for the "why"; this plan restates only what's needed to build.
- Inventory soft cap: **200 items**, invented and flagged (design decision #4, already made — do not re-litigate).
- "Scrap all unequipped duplicates" scraps **every** unequipped copy, keeps none spare (design decision #5, already made).
- Compare context hands off via a slot-tap on the gear paper-doll (design decision #6, already made) — the retrofit is Task 7, deliberately last.
- **Instance-id collision fix (decided during this plan's brainstorm, not in the original design doc):** `HunterState.add_to_inventory()` currently derives new ids from `inventory.size()`, which gets reused after a removal and collides with a surviving item's id — bulk scrap is what makes this reachable for the first time. Fixed in Task 2 via a monotonic `next_inventory_id` counter. This does NOT touch the identical (pre-existing, still-unfixed) pattern in `claim_shadow()`'s shadow ids — out of scope, a separate future gap if it's ever needed.
- No `core/` function ever takes a `Node`/engine type. `scenes/inventory_view.gd` is the only place a `GridContainer`/`ScrollContainer` appears.

---

## File Structure

- **Create:** `core/inventory.gd` — filter/sort/wearer-lookup/compare/scrap-candidate logic, pure.
- **Create:** `tests/unit/test_inventory.gd`
- **Modify:** `core/hunter_state.gd` — `next_inventory_id` counter + fixed `add_to_inventory()`, `locked` field on inventory items, `set_item_locked()`, `scrap_item()`, `bulk_scrap()`.
- **Modify:** `tests/unit/test_hunter_state.gd`
- **Modify:** `core/game_logic.gd` — `ESSENCE_PER_SCRAPPED_ITEM` + `essence_for_scrapped_item()`.
- **Modify:** `core/armor_sets.gd` — `owned_set_counts()`.
- **Modify:** `tests/unit/test_game_logic.gd`, `tests/unit/test_armor_sets.gd`
- **Create:** `scenes/inventory_view.gd` — the new screen (built incrementally across Tasks 4-7).
- **Modify:** `scenes/main.tscn` — new `InventoryPanel`, remove the old `InventoryLabel`, new HUD button.
- **Modify:** `scenes/main.gd` — wire the new panel, remove `_refresh_inventory_label()`.
- **Modify:** `scenes/gear_panel_helpers.gd` — a "Browse" button per gear row (shared by both gear panels).
- **Modify:** `scenes/shadow_gear_view.gd`, `scenes/hunter_gear_view.gd` — Browse wiring, carries context into the new screen.

---

### Task 1: `core/inventory.gd` — pure browse/maintain logic

**Files:**
- Create: `core/inventory.gd`
- Test: `tests/unit/test_inventory.gd`

**Interfaces:**
- Consumes: `Content.equipment_by_id()`, `Equip.enhanced_def()`, `Equip.SLOTS` (existing).
- Produces: `Inventory.RARITY_ORDER`, `Inventory.SOFT_CAP`, `filter_by()`, `sort_by()`, `wearer_of()`, `compare_delta()`, `scrap_candidates_below_rarity()`, `scrap_candidates_unequipped_duplicates()`, `is_over_soft_cap()` — consumed by Task 2 (`wearer_of` inside `HunterState.scrap_item`) and Tasks 4-7 (the screen).

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_inventory.gd
extends GutTest
## Inventory: filter/sort/wearer-lookup/compare/scrap-candidate logic (§17b). Pure.

var equipment: Dictionary


func before_all() -> void:
	equipment = Content.load_equipment()


static func _item(instance_id: String, def_id: String, locked: bool = false) -> Dictionary:
	return {
		"instance_id": instance_id, "equipment_def_id": def_id, "enhancement_level": 0, "locked": locked
	}


func test_filter_by_enriches_with_def_data() -> void:
	var inv := [_item("i0", "eq_warcleaver")]
	var result := Inventory.filter_by(inv, equipment, {}, [], {})
	assert_eq(result.size(), 1)
	assert_eq(result[0]["name"], "Warcleaver")
	assert_eq(result[0]["slot"], "WEAPON")
	assert_eq(result[0]["clazz"], "WARRIOR")


func test_filter_by_skips_unknown_def_ids() -> void:
	var inv := [_item("i0", "eq_does_not_exist")]
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {}), [])


func test_filter_by_class_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # WARRIOR
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"class": "WARRIOR"}).size(), 1)
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"class": "MAGE"}).size(), 0)


func test_filter_by_slot_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # WEAPON
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"slot": "WEAPON"}).size(), 1)
	assert_eq(Inventory.filter_by(inv, equipment, {}, [], {"slot": "HEAD"}).size(), 0)


func test_filter_by_equipped_filter() -> void:
	var inv := [_item("i0", "eq_warcleaver"), _item("i1", "eq_warcleaver")]
	var hunter_equipped := {"WEAPON": "i0"}
	var equipped_only := Inventory.filter_by(inv, equipment, hunter_equipped, [], {"equipped": "EQUIPPED"})
	assert_eq(equipped_only.size(), 1)
	assert_eq(equipped_only[0]["instance_id"], "i0")
	var unequipped_only := Inventory.filter_by(
		inv, equipment, hunter_equipped, [], {"equipped": "UNEQUIPPED"}
	)
	assert_eq(unequipped_only.size(), 1)
	assert_eq(unequipped_only[0]["instance_id"], "i1")


func test_sort_by_power_descending() -> void:
	var items := [{"power_bonus": 10}, {"power_bonus": 50}, {"power_bonus": 30}]
	var sorted := Inventory.sort_by(items, "power")
	assert_eq(sorted[0]["power_bonus"], 50)
	assert_eq(sorted[2]["power_bonus"], 10)


func test_sort_by_rarity_rarest_first() -> void:
	var items := [{"rarity": "COMMON"}, {"rarity": "LEGENDARY"}, {"rarity": "RARE"}]
	var sorted := Inventory.sort_by(items, "rarity")
	assert_eq(sorted[0]["rarity"], "LEGENDARY")
	assert_eq(sorted[2]["rarity"], "COMMON")


func test_sort_by_newest_reverses_input_order() -> void:
	var items := [{"instance_id": "i0"}, {"instance_id": "i1"}, {"instance_id": "i2"}]
	var sorted := Inventory.sort_by(items, "newest")
	assert_eq(sorted[0]["instance_id"], "i2")
	assert_eq(sorted[2]["instance_id"], "i0")


func test_wearer_of_hunter() -> void:
	var result := Inventory.wearer_of("i0", {"WEAPON": "i0"}, [])
	assert_eq(result["kind"], "hunter")


func test_wearer_of_shadow() -> void:
	var army := [{"instance_id": "shadow_0", "equipped": {"WEAPON": "i0"}}]
	var result := Inventory.wearer_of("i0", {}, army)
	assert_eq(result["kind"], "shadow")
	assert_eq(result["shadow_instance_id"], "shadow_0")


func test_wearer_of_none() -> void:
	assert_eq(Inventory.wearer_of("i0", {}, [])["kind"], "none")


func test_compare_delta_against_empty_slot() -> void:
	var candidate := {"power_bonus": 100, "stat_mods": {"STR": 10}}
	var delta := Inventory.compare_delta(candidate, {})
	assert_eq(delta["power_delta"], 100)
	assert_eq(delta["stat_delta"]["STR"], 10)


func test_compare_delta_against_current_item() -> void:
	var candidate := {"power_bonus": 100, "stat_mods": {"STR": 10}}
	var current := {"power_bonus": 60, "stat_mods": {"STR": 15, "VIT": 5}}
	var delta := Inventory.compare_delta(candidate, current)
	assert_eq(delta["power_delta"], 40)
	assert_eq(delta["stat_delta"]["STR"], -5)
	assert_eq(delta["stat_delta"]["VIT"], -5)


func test_scrap_candidates_below_rarity_excludes_locked_and_equipped() -> void:
	var inv := [
		_item("i0", "eq_warcleaver"),  # COMMON, unlocked, unequipped -- candidate
		_item("i1", "eq_warcleaver", true),  # locked -- excluded
	]
	var hunter_equipped := {}
	var candidates := Inventory.scrap_candidates_below_rarity(
		inv, equipment, "UNCOMMON", hunter_equipped, []
	)
	assert_true(candidates.has("i0"))
	assert_false(candidates.has("i1"))


func test_scrap_candidates_below_rarity_excludes_equal_or_above() -> void:
	var inv := [_item("i0", "eq_warcleaver")]  # COMMON
	assert_eq(Inventory.scrap_candidates_below_rarity(inv, equipment, "COMMON", {}, []), [])


func test_scrap_candidates_unequipped_duplicates_keeps_none_spare() -> void:
	var inv := [
		_item("i0", "eq_warcleaver"), _item("i1", "eq_warcleaver"), _item("i2", "eq_warcleaver")
	]
	var hunter_equipped := {"WEAPON": "i0"}
	var candidates := Inventory.scrap_candidates_unequipped_duplicates(inv, hunter_equipped, [])
	assert_eq(candidates.size(), 2)
	assert_true(candidates.has("i1"))
	assert_true(candidates.has("i2"))
	assert_false(candidates.has("i0"))  # worn, excluded even though it's a duplicate


func test_scrap_candidates_unequipped_duplicates_no_duplicates_is_empty() -> void:
	var inv := [_item("i0", "eq_warcleaver")]
	assert_eq(Inventory.scrap_candidates_unequipped_duplicates(inv, {}, []), [])


func test_is_over_soft_cap() -> void:
	var small: Array = []
	for i in 5:
		small.append(_item("i%d" % i, "eq_warcleaver"))
	assert_false(Inventory.is_over_soft_cap(small))
	var big: Array = []
	for i in Inventory.SOFT_CAP:
		big.append(_item("i%d" % i, "eq_warcleaver"))
	assert_true(Inventory.is_over_soft_cap(big))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_inventory.gd -gexit`
Expected: FAIL — `Inventory` class doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```gdscript
# core/inventory.gd
class_name Inventory
## §17b: pure browse/maintain logic for the hunter's equipment inventory --
## filtering, sorting, the equipped-by lookup, stat-delta compare, and
## bulk-scrap candidate selection. Kept separate from Equip (slot/class-
## gating mechanics) per this project's one-class-one-responsibility
## convention -- Equip answers "can this be worn"; this answers "how do I
## browse/bulk-manage a pile of these".

const RARITY_ORDER := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const SOFT_CAP := 200  ## invented v0 number, flagged -- no source figure given
## (§17b design decision #4); generous for a fresh save, reachable mid-game.


## Enriches each inventory item with its resolved (enhancement-scaled) def
## data, then applies `filters`. Filter keys (all optional -- omit or "ALL"
## means no filter on that dimension): class, slot, rarity, set_id,
## equipped ("EQUIPPED"/"UNEQUIPPED"). `hunter_equipped`/`army` are only
## needed to resolve the `equipped` filter -- pass {}/[] if not filtering
## on it. Preserves `inventory`'s own order (acquisition order).
static func filter_by(
	inventory: Array,
	equipment: Dictionary,
	hunter_equipped: Dictionary,
	army: Array,
	filters: Dictionary
) -> Array:
	var result := []
	for item: Dictionary in inventory:
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		var effective := Equip.enhanced_def(def, item.get("enhancement_level", 0))
		var enriched := {
			"instance_id": item.get("instance_id", ""),
			"equipment_def_id": item.get("equipment_def_id", ""),
			"enhancement_level": item.get("enhancement_level", 0),
			"locked": item.get("locked", false),
			"name": def.get("name", ""),
			"slot": def.get("slot", ""),
			"rarity": def.get("rarity", ""),
			"clazz": def.get("clazz", ""),
			"set_id": def.get("set_id", ""),
			"power_bonus": effective.get("power_bonus", 0),
			"stat_mods": effective.get("stat_mods", {}),
		}
		if filters.get("class", "ALL") != "ALL" and enriched["clazz"] != filters["class"]:
			continue
		if filters.get("slot", "ALL") != "ALL" and enriched["slot"] != filters["slot"]:
			continue
		if filters.get("rarity", "ALL") != "ALL" and enriched["rarity"] != filters["rarity"]:
			continue
		if filters.get("set_id", "ALL") != "ALL" and enriched["set_id"] != filters["set_id"]:
			continue
		var equipped_filter: String = filters.get("equipped", "ALL")
		if equipped_filter != "ALL":
			var is_worn := wearer_of(enriched["instance_id"], hunter_equipped, army)["kind"] != "none"
			if equipped_filter == "EQUIPPED" and not is_worn:
				continue
			if equipped_filter == "UNEQUIPPED" and is_worn:
				continue
		result.append(enriched)
	return result


## `mode`: "power" (highest first), "rarity" (rarest first, RARITY_ORDER),
## "slot" (Equip.SLOTS order), "newest" (most-recently-acquired first --
## reverses the input, since filter_by already returns acquisition order).
static func sort_by(items: Array, mode: String) -> Array:
	var result := items.duplicate()
	match mode:
		"power":
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power_bonus"] > b["power_bonus"])
		"rarity":
			result.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return RARITY_ORDER.find(b["rarity"]) < RARITY_ORDER.find(a["rarity"])
			)
		"slot":
			result.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return Equip.SLOTS.find(a["slot"]) < Equip.SLOTS.find(b["slot"])
			)
		"newest":
			result.reverse()
	return result


## Who currently wears `instance_id` -- {"kind": "none"|"hunter"|"shadow",
## "shadow_instance_id": ""}. Backs both the "equipped by <shadow>" label
## and the scrap guard (an item can't be scrapped while worn).
static func wearer_of(instance_id: String, hunter_equipped: Dictionary, army: Array) -> Dictionary:
	if hunter_equipped.values().has(instance_id):
		return {"kind": "hunter", "shadow_instance_id": ""}
	for shadow: Dictionary in army:
		var shadow_equipped: Dictionary = shadow.get("equipped", {})
		if shadow_equipped.values().has(instance_id):
			return {"kind": "shadow", "shadow_instance_id": shadow.get("instance_id", "")}
	return {"kind": "none", "shadow_instance_id": ""}


## Per-stat and power deltas between a candidate item and whatever's
## currently worn in the target slot -- the Compare feature's green/red
## arrows. Both dicts are the enhancement-scaled ("effective") shape
## filter_by's enrichment produces. `current` may be {} (empty slot),
## treated as all-zero.
static func compare_delta(candidate: Dictionary, current: Dictionary) -> Dictionary:
	var stat_delta := {}
	var candidate_stats: Dictionary = candidate.get("stat_mods", {})
	var current_stats: Dictionary = current.get("stat_mods", {})
	for stat in candidate_stats:
		stat_delta[stat] = int(candidate_stats[stat]) - int(current_stats.get(stat, 0))
	for stat in current_stats:
		if not stat_delta.has(stat):
			stat_delta[stat] = -int(current_stats[stat])
	var power_delta := int(candidate.get("power_bonus", 0)) - int(current.get("power_bonus", 0))
	return {"stat_delta": stat_delta, "power_delta": power_delta}


## Eligible-to-scrap instance_ids: rarity strictly below `threshold`,
## excluding locked/equipped items.
static func scrap_candidates_below_rarity(
	inventory: Array,
	equipment: Dictionary,
	threshold: String,
	hunter_equipped: Dictionary,
	army: Array
) -> Array:
	var threshold_idx := RARITY_ORDER.find(threshold)
	var result := []
	for item: Dictionary in inventory:
		if item.get("locked", false):
			continue
		if wearer_of(item.get("instance_id", ""), hunter_equipped, army)["kind"] != "none":
			continue
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		if def.is_empty():
			continue
		var rarity_idx := RARITY_ORDER.find(def.get("rarity", ""))
		if rarity_idx >= 0 and rarity_idx < threshold_idx:
			result.append(item["instance_id"])
	return result


## Every unequipped copy of a def_id owned more than once -- keeps none
## spare (§17b design decision #5: scraps ALL unequipped duplicates, even
## if one copy of that def_id is equipped and stays).
static func scrap_candidates_unequipped_duplicates(
	inventory: Array, hunter_equipped: Dictionary, army: Array
) -> Array:
	var counts := {}
	for item: Dictionary in inventory:
		var def_id: String = item.get("equipment_def_id", "")
		counts[def_id] = counts.get(def_id, 0) + 1
	var result := []
	for item: Dictionary in inventory:
		if item.get("locked", false):
			continue
		var def_id: String = item.get("equipment_def_id", "")
		if counts.get(def_id, 0) <= 1:
			continue
		if wearer_of(item.get("instance_id", ""), hunter_equipped, army)["kind"] != "none":
			continue
		result.append(item["instance_id"])
	return result


static func is_over_soft_cap(inventory: Array) -> bool:
	return inventory.size() >= SOFT_CAP
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_inventory.gd -gexit`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add core/inventory.gd tests/unit/test_inventory.gd
git commit -m "§17b step 1: core/inventory.gd -- filter/sort/wearer/compare/scrap-candidate logic

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 2: `HunterState` — instance-id fix, locking, scrap, bulk-scrap

**Files:**
- Modify: `core/hunter_state.gd`
- Modify: `tests/unit/test_hunter_state.gd`

**Interfaces:**
- Consumes: `Inventory.wearer_of()` (Task 1), `GameLogic.essence_for_scrapped_item()` (Task 3 — write Task 2 and 3 together if convenient, or stub the call and let Task 3 land the constant; the two are independent enough to do in either order, but this plan sequences the pure-logic tasks first for exactly this reason).
- Produces: `HunterState.next_inventory_id: int`, fixed `add_to_inventory()`, `set_item_locked()`, `scrap_item()`, `bulk_scrap()` — consumed by Tasks 4-7 (the screen).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_hunter_state.gd`:

```gdscript
func test_add_to_inventory_ids_survive_a_scrap_without_colliding() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.add_to_inventory("eq_warcleaver")
	var b := s.add_to_inventory("eq_warcleaver")
	var c := s.add_to_inventory("eq_warcleaver")
	s.scrap_item(b["instance_id"], Content.load_equipment())  # removes the middle one
	var d := s.add_to_inventory("eq_warcleaver")
	# d's id must not collide with a's or c's, which are both still present
	assert_ne(d["instance_id"], a["instance_id"])
	assert_ne(d["instance_id"], c["instance_id"])
	var ids: Array = s.inventory.map(func(i: Dictionary) -> String: return i["instance_id"])
	assert_eq(ids.size(), ids.uniq().size())  # no duplicates anywhere


func test_add_to_inventory_starts_unlocked() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	assert_false(item["locked"])


func test_set_item_locked() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	assert_true(s.set_item_locked(item["instance_id"], true))
	assert_true(s.inventory[0]["locked"])


func test_set_item_locked_unknown_item_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.set_item_locked("does_not_exist", true))


func test_scrap_item_grants_essence_and_removes_it() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")  # COMMON
	var before := s.essence
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_true(gained > 0)
	assert_eq(s.essence, before + gained)
	assert_eq(s.inventory.size(), 0)


func test_scrap_item_locked_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	s.set_item_locked(item["instance_id"], true)
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_eq(gained, 0)
	assert_eq(s.inventory.size(), 1)


func test_scrap_item_equipped_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	var item := s.add_to_inventory("eq_warcleaver")
	s.equip_to_hunter(item["instance_id"], Content.load_equipment())
	var gained := s.scrap_item(item["instance_id"], Content.load_equipment())
	assert_eq(gained, 0)
	assert_eq(s.inventory.size(), 1)


func test_scrap_item_unknown_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_eq(s.scrap_item("does_not_exist", Content.load_equipment()), 0)


func test_bulk_scrap_sums_essence_and_skips_ineligible() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.add_to_inventory("eq_warcleaver")
	var b := s.add_to_inventory("eq_warcleaver")
	s.set_item_locked(b["instance_id"], true)  # ineligible, skipped
	var gained := s.bulk_scrap([a["instance_id"], b["instance_id"]], Content.load_equipment())
	assert_true(gained > 0)
	assert_eq(s.inventory.size(), 1)  # only b (locked) survives
	assert_eq(s.inventory[0]["instance_id"], b["instance_id"])


func test_next_inventory_id_persists_through_dict_round_trip() -> void:
	var s := HunterState.new_default("WARRIOR")
	s.add_to_inventory("eq_warcleaver")
	s.add_to_inventory("eq_warcleaver")
	var d := s.to_dict()
	var restored := HunterState.from_dict(d)
	assert_eq(restored.next_inventory_id, s.next_inventory_id)


func test_from_dict_migrates_old_saves_without_next_inventory_id() -> void:
	# an old save's dict has no "next_inventory_id" key at all
	var old_dict := HunterState.new_default("WARRIOR").to_dict()
	old_dict["inventory"] = [
		{"instance_id": "eq_inst_0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
		{"instance_id": "eq_inst_1", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0},
	]
	old_dict.erase("next_inventory_id")
	var restored := HunterState.from_dict(old_dict)
	# must default to inventory.size() (2), NOT 0 -- else the next add_to_inventory()
	# would generate "eq_inst_0" again and collide with the existing first item
	assert_eq(restored.next_inventory_id, 2)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: FAIL — `next_inventory_id`/`set_item_locked`/`scrap_item`/`bulk_scrap` don't exist yet, and `add_to_inventory()`'s id scheme still collides.

- [ ] **Step 3: Write the implementation**

In `core/hunter_state.gd`, add a new field near the other `var` declarations (after `inventory`):

```gdscript
var next_inventory_id: int = 0  ## §17b: monotonic counter for inventory instance_ids. NOT
## inventory.size() (the old scheme) -- that gets reused after scrap_item() removes an item,
## colliding with a surviving item's id. Bulk scrap is what makes this reachable for the
## first time; fixed here rather than left as a "flagged gap" like the identical (still
## unfixed) pattern in claim_shadow()'s shadow ids, which nothing removes-then-adds fast
## enough to hit in practice today.
```

Replace `add_to_inventory()`:

```gdscript
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
```

Add new methods after `set_shadow_favorite()` (or any convenient spot near the other lock-style methods):

```gdscript
## §17b: locks/unlocks an owned item, protecting it from scrap (single or
## bulk). Same shape as set_shadow_locked(). False (no-op) if unknown item.
func set_item_locked(instance_id: String, locked: bool) -> bool:
	var idx := _inventory_index(instance_id)
	if idx < 0:
		return false
	inventory[idx]["locked"] = locked
	return true
```

Add after `enhance_item()` (near the other inventory-item methods):

```gdscript
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
```

Add the new private helper near `_inventory_item()`:

```gdscript
func _inventory_index(instance_id: String) -> int:
	for i in inventory.size():
		if inventory[i].get("instance_id", "") == instance_id:
			return i
	return -1
```

Update `to_dict()` — add one key:

```gdscript
		"inventory": inventory,
		"next_inventory_id": next_inventory_id,
```

(placed right after the existing `"inventory": inventory,` line)

Update `from_dict()` — the default must be `inventory.size()`, NOT `0` (see the migration test above):

```gdscript
	s.inventory = d.get("inventory", [])
	s.next_inventory_id = int(d.get("next_inventory_id", s.inventory.size()))
```

(placed right after the existing `s.inventory = d.get("inventory", [])` line — `s.inventory` must already be assigned before this line reads its `.size()`)

Update `new_default()` — add one line:

```gdscript
	s.next_inventory_id = 0
```

(placed right after the existing `s.inventory = []` line)

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: PASS, plus every pre-existing test in the file still green (the `add_to_inventory` signature/return shape is unchanged, only its internal id source and the new `locked` key are new — no existing caller reads/asserts the old id formula directly, but check `test_hunter_state_shop.gd` and any other file with `add_to_inventory(` calls too, since this is a shared method).

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (full suite, since `HunterState` is used everywhere)
Expected: all 421+ tests still passing.

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd tests/unit/test_hunter_state.gd
git commit -m "§17b step 2: HunterState item locking, scrap, bulk-scrap; fix inventory-id collision

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 3: `GameLogic.essence_for_scrapped_item` + `ArmorSets.owned_set_counts`

**Files:**
- Modify: `core/game_logic.gd`
- Modify: `core/armor_sets.gd`
- Modify: `tests/unit/test_game_logic.gd`, `tests/unit/test_armor_sets.gd`

**Interfaces:**
- Produces: `GameLogic.ESSENCE_PER_SCRAPPED_ITEM`, `GameLogic.essence_for_scrapped_item(rarity) -> int` (consumed by Task 2's `HunterState.scrap_item` — if Task 2 was done first, its calls to this function will fail to compile until this task lands; do these two tasks back-to-back, or write this one first if executing out of the given order). `ArmorSets.owned_set_counts(inventory, equipment) -> Dictionary` (consumed by Task 5, the Sets tab).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_game_logic.gd`:

```gdscript
func test_essence_for_scrapped_item_by_rarity() -> void:
	assert_eq(GameLogic.essence_for_scrapped_item("COMMON"), 2)
	assert_eq(GameLogic.essence_for_scrapped_item("LEGENDARY"), 32)


func test_essence_for_scrapped_item_unknown_rarity_is_zero() -> void:
	assert_eq(GameLogic.essence_for_scrapped_item("NOT_A_RARITY"), 0)
```

Add to `tests/unit/test_armor_sets.gd`:

```gdscript
func test_owned_set_counts_counts_whole_inventory_not_just_equipped() -> void:
	var equipment := Content.load_equipment()
	var inventory := [
		{"instance_id": "i0", "equipment_def_id": "eq_warhowls_hood", "enhancement_level": 0},
		{"instance_id": "i1", "equipment_def_id": "eq_warhowls_robe", "enhancement_level": 0},
	]
	var counts := ArmorSets.owned_set_counts(inventory, equipment)
	assert_eq(counts.get("set_warhowls_standard", 0), 2)


func test_owned_set_counts_ignores_non_set_items() -> void:
	var equipment := Content.load_equipment()
	var inventory := [{"instance_id": "i0", "equipment_def_id": "eq_warcleaver", "enhancement_level": 0}]
	assert_eq(ArmorSets.owned_set_counts(inventory, equipment), {})
```

(Adjust the set-piece equipment ids above if `eq_warhowls_hood`/`eq_warhowls_robe` aren't the exact ids in `content/equipment.json` — check the file first; any two pieces sharing `set_id: "set_warhowls_standard"` work for this test.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_game_logic.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_armor_sets.gd -gexit`
Expected: both FAIL — the new functions don't exist yet.

- [ ] **Step 3: Write the implementation**

In `core/game_logic.gd`, beside the existing `ESSENCE_PER_CONVERTED_SHADOW` constant:

```gdscript
## §17b: Essence granted scrapping an unwanted item, by rarity. No source
## number exists for this either -- a doubling curve on its own base (not
## reusing ESSENCE_PER_CONVERTED_SHADOW's numbers), same "don't let two
## Essence sinks read as directly comparable" reasoning ShadowLeveling's
## own fuse-discount comment already uses.
const ESSENCE_PER_SCRAPPED_ITEM := {"COMMON": 2, "UNCOMMON": 4, "RARE": 8, "EPIC": 16, "LEGENDARY": 32}
```

Add a function beside `essence_for_converted_shadow()`:

```gdscript
static func essence_for_scrapped_item(rarity: String) -> int:
	return int(ESSENCE_PER_SCRAPPED_ITEM.get(rarity, 0))
```

In `core/armor_sets.gd`, add beside `equipped_set_counts()`:

```gdscript
## §17b: owned piece count per set_id across the WHOLE inventory (not just
## equipped) -- feeds the Inventory screen's Sets tab "3/4" readout.
## Sibling to equipped_set_counts(), same counting logic, a different
## source array (every owned copy counts, worn or not).
static func owned_set_counts(inventory: Array, equipment: Dictionary) -> Dictionary:
	var counts := {}
	for item: Dictionary in inventory:
		var def := Content.equipment_by_id(equipment, item.get("equipment_def_id", ""))
		var set_id: String = def.get("set_id", "")
		if set_id == "":
			continue
		counts[set_id] = counts.get(set_id, 0) + 1
	return counts
```

- [ ] **Step 4: Run tests to verify they pass**

Run both focused test files again; expect PASS. Then run the full suite once.

- [ ] **Step 5: Commit**

```bash
git add core/game_logic.gd core/armor_sets.gd tests/unit/test_game_logic.gd tests/unit/test_armor_sets.gd
git commit -m "§17b step 3: GameLogic.essence_for_scrapped_item, ArmorSets.owned_set_counts

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 4: `inventory_view.gd` — the Grid tab (filter/sort/grid/detail, no Compare yet)

**Files:**
- Create: `scenes/inventory_view.gd`
- Modify: `scenes/main.tscn` — new `InventoryPanel` (Grid tab only for now; the Sets tab and bulk-scrap bar are added in later tasks by extending this same node tree), remove `InventoryLabel`, new HUD button.
- Modify: `scenes/main.gd` — wire the standalone entry point, remove `_refresh_inventory_label()`.

**Interfaces:**
- Consumes: `Inventory.filter_by()`, `Inventory.sort_by()`, `Inventory.wearer_of()` (Task 1); `HunterState.set_item_locked()`, `scrap_item()` (Task 2).
- Produces: `InventoryView.bind(state, equipment, monsters)`, `InventoryView.open()` (no-context/standalone form) — consumed by Task 6 (bulk scrap extends this file) and Task 7 (the context-carrying `open_for_slot()` variant).

- [ ] **Step 1: Add the `InventoryPanel` node tree to `scenes/main.tscn`**

Check the file's current `[ext_resource ...]` header block for the next free numeric id (it was `"11"` for `army_view.gd` at the time this plan was written — confirm the actual next-free id yourself before using it, the same lesson §17's Task 5 already learned the hard way) and add:

```
[ext_resource type="Script" path="res://scenes/inventory_view.gd" id="<next_free_id>"]
```

Then add the panel itself as a new top-level `GameUI` child (find where `ArmyPanel`'s node block ends and insert after it):

```
[node name="InventoryPanel" type="Node2D" parent="GameUI"]
visible = false
script = ExtResource("<next_free_id>")

[node name="Bg" type="ColorRect" parent="GameUI/InventoryPanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 2424.0
offset_bottom = 1080.0
color = Color(0.05, 0.05, 0.05, 0.95)

[node name="GridTabButton" type="Button" parent="GameUI/InventoryPanel"]
offset_left = 40.0
offset_top = 20.0
offset_right = 260.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Grid"

[node name="CloseButton" type="Button" parent="GameUI/InventoryPanel"]
offset_left = 2260.0
offset_top = 20.0
offset_right = 2380.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Close"

[node name="GridTab" type="Node2D" parent="GameUI/InventoryPanel"]

[node name="FilterBar" type="Node2D" parent="GameUI/InventoryPanel/GridTab"]
position = Vector2(0, 90)

[node name="ClassFilterButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 40.0
offset_top = 0.0
offset_right = 260.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Class: ALL"

[node name="SlotFilterButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 280.0
offset_top = 0.0
offset_right = 500.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Slot: ALL"

[node name="RarityFilterButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 520.0
offset_top = 0.0
offset_right = 740.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Rarity: ALL"

[node name="SetFilterButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 760.0
offset_top = 0.0
offset_right = 980.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Set: ALL"

[node name="EquippedFilterButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 1000.0
offset_top = 0.0
offset_right = 1220.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Show: ALL"

[node name="SortButton" type="Button" parent="GameUI/InventoryPanel/GridTab/FilterBar"]
offset_left = 1240.0
offset_top = 0.0
offset_right = 1460.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 16
text = "Sort: Power"

[node name="GridScroll" type="ScrollContainer" parent="GameUI/InventoryPanel/GridTab"]
offset_left = 0.0
offset_top = 160.0
offset_right = 2424.0
offset_bottom = 890.0

[node name="Grid" type="GridContainer" parent="GameUI/InventoryPanel/GridTab/GridScroll"]
layout_mode = 2
columns = 4

[node name="CapacityWarningLabel" type="Label" parent="GameUI/InventoryPanel/GridTab"]
offset_left = 40.0
offset_top = 900.0
offset_right = 2380.0
offset_bottom = 940.0
theme_override_font_sizes/font_size = 18
text = ""

[node name="DetailPanel" type="Node2D" parent="GameUI/InventoryPanel"]
visible = false

[node name="DetailBg" type="ColorRect" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 2424.0
offset_bottom = 1080.0
color = Color(0.03, 0.03, 0.03, 0.98)

[node name="BackButton" type="Button" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 40.0
offset_top = 20.0
offset_right = 200.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "< Back"

[node name="NameLabel" type="Label" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 40.0
offset_top = 90.0
offset_right = 2380.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 28
text = ""

[node name="StatsLabel" type="Label" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 40.0
offset_top = 150.0
offset_right = 2380.0
offset_bottom = 400.0
theme_override_font_sizes/font_size = 18
text = ""

[node name="WearerLabel" type="Label" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 40.0
offset_top = 410.0
offset_right = 2380.0
offset_bottom = 450.0
theme_override_font_sizes/font_size = 18
text = ""

[node name="CompareLabel" type="Label" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 40.0
offset_top = 460.0
offset_right = 2380.0
offset_bottom = 650.0
theme_override_font_sizes/font_size = 18
text = ""

[node name="EquipButton" type="Button" parent="GameUI/InventoryPanel/DetailPanel"]
visible = false
offset_left = 40.0
offset_top = 900.0
offset_right = 300.0
offset_bottom = 950.0
theme_override_font_sizes/font_size = 20
text = "Equip"

[node name="LockButton" type="Button" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 320.0
offset_top = 900.0
offset_right = 580.0
offset_bottom = 950.0
theme_override_font_sizes/font_size = 20
text = "Lock"

[node name="ScrapButton" type="Button" parent="GameUI/InventoryPanel/DetailPanel"]
offset_left = 600.0
offset_top = 900.0
offset_right = 860.0
offset_bottom = 950.0
theme_override_font_sizes/font_size = 20
text = "Scrap"
```

Remove the existing `InventoryLabel` node block entirely (`scenes/main.tscn`, currently a `Label` under `GameUI` reading `"Inventory: (none yet)"`).

Add a new HUD button in its place — find a free gap in the button row (there's empty space between `ArmyButton`'s right edge and `NadirButton`'s left edge in the current layout):

```
[node name="InventoryButton" type="Button" parent="GameUI"]
offset_left = 400.0
offset_top = 370.0
offset_right = 620.0
offset_bottom = 410.0
theme_override_font_sizes/font_size = 18
text = "Inventory"
```

- [ ] **Step 2: Write `scenes/inventory_view.gd` (Grid tab + item detail, no Compare/Equip logic yet)**

```gdscript
class_name InventoryView
extends Node2D
## §17b: the Equipment inventory screen -- filterable/sortable icon grid
## over the whole owned pool (hunter + every shadow share one inventory,
## see core/equip.gd's own doc comment), item detail, and (added in later
## tasks) a Sets-progress tab and bulk scrap-to-Essence. Self-contained
## controller (holds HunterState directly, mutates it, saves), same
## pattern as ArmyView/StrongholdView.
##
## This task builds the Grid tab and item detail WITHOUT Compare or Equip
## -- those need a context (which shadow/hunter slot triggered the open),
## which only exists once Task 7 retrofits the gear panels to carry it in.
## Standalone opens (this task's only entry point) have no context.

signal state_changed

const CLASS_OPTIONS := ["ALL", "WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]
const EQUIPPED_OPTIONS := ["ALL", "EQUIPPED", "UNEQUIPPED"]
const SORT_MODES := ["power", "rarity", "slot", "newest"]

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array
var _slot_options: Array = ["ALL"]  ## filled in bind() from Equip.SLOTS
var _set_options: Array = ["ALL"]  ## filled in bind() from equipment["armor_sets"]
var _filters := {"class": "ALL", "slot": "ALL", "rarity": "ALL", "set_id": "ALL", "equipped": "ALL"}
var _sort_mode: String = "power"
var _selected_instance_id: String = ""
var _grid_items: Array = []  ## the last filtered+sorted list, so detail can look an item back up

@onready var grid: GridContainer = $GridTab/GridScroll/Grid
@onready var class_filter_button: Button = $GridTab/FilterBar/ClassFilterButton
@onready var slot_filter_button: Button = $GridTab/FilterBar/SlotFilterButton
@onready var rarity_filter_button: Button = $GridTab/FilterBar/RarityFilterButton
@onready var set_filter_button: Button = $GridTab/FilterBar/SetFilterButton
@onready var equipped_filter_button: Button = $GridTab/FilterBar/EquippedFilterButton
@onready var sort_button: Button = $GridTab/FilterBar/SortButton
@onready var capacity_warning_label: Label = $GridTab/CapacityWarningLabel
@onready var detail_panel: Node2D = $DetailPanel
@onready var name_label: Label = $DetailPanel/NameLabel
@onready var stats_label: Label = $DetailPanel/StatsLabel
@onready var wearer_label: Label = $DetailPanel/WearerLabel
@onready var lock_button: Button = $DetailPanel/LockButton
@onready var scrap_button: Button = $DetailPanel/ScrapButton


func _ready() -> void:
	$GridTabButton.pressed.connect(_on_grid_tab_pressed)
	$CloseButton.pressed.connect(func() -> void: visible = false)
	class_filter_button.pressed.connect(_on_class_filter_pressed)
	slot_filter_button.pressed.connect(_on_slot_filter_pressed)
	rarity_filter_button.pressed.connect(_on_rarity_filter_pressed)
	set_filter_button.pressed.connect(_on_set_filter_pressed)
	equipped_filter_button.pressed.connect(_on_equipped_filter_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	$DetailPanel/BackButton.pressed.connect(_on_detail_back_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	scrap_button.pressed.connect(_on_scrap_pressed)


func bind(state: HunterState, equipment: Dictionary, monsters: Array) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_slot_options = ["ALL"] + Equip.SLOTS
	_set_options = ["ALL"]
	for set_def: Dictionary in equipment.get("armor_sets", []):
		_set_options.append(String(set_def.get("id", "")))


## Standalone entry point -- no shadow/hunter context, Compare never
## renders (Task 7 adds a second, context-carrying open variant).
func open() -> void:
	visible = true
	$GridTabButton.visible = true  # re-shown in case a later task's tab hid it
	_on_grid_tab_pressed()


func _on_grid_tab_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	_refresh_grid()


func _cycle(options: Array, current: String) -> String:
	return options[(options.find(current) + 1) % options.size()]


func _on_class_filter_pressed() -> void:
	_filters["class"] = _cycle(CLASS_OPTIONS, _filters["class"])
	class_filter_button.text = "Class: %s" % _filters["class"]
	_refresh_grid()


func _on_slot_filter_pressed() -> void:
	_filters["slot"] = _cycle(_slot_options, _filters["slot"])
	slot_filter_button.text = "Slot: %s" % _filters["slot"]
	_refresh_grid()


func _on_rarity_filter_pressed() -> void:
	_filters["rarity"] = _cycle(["ALL"] + Inventory.RARITY_ORDER, _filters["rarity"])
	rarity_filter_button.text = "Rarity: %s" % _filters["rarity"]
	_refresh_grid()


func _on_set_filter_pressed() -> void:
	_filters["set_id"] = _cycle(_set_options, _filters["set_id"])
	set_filter_button.text = "Set: %s" % _filters["set_id"]
	_refresh_grid()


func _on_equipped_filter_pressed() -> void:
	_filters["equipped"] = _cycle(EQUIPPED_OPTIONS, _filters["equipped"])
	equipped_filter_button.text = "Show: %s" % _filters["equipped"]
	_refresh_grid()


func _on_sort_pressed() -> void:
	_sort_mode = SORT_MODES[(SORT_MODES.find(_sort_mode) + 1) % SORT_MODES.size()]
	sort_button.text = "Sort: %s" % _sort_mode.capitalize()
	_refresh_grid()


func _refresh_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var filtered := Inventory.filter_by(_state.inventory, _equipment, _state.equipped, _state.army, _filters)
	_grid_items = Inventory.sort_by(filtered, _sort_mode)

	for item: Dictionary in _grid_items:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(560, 160)
		var lock_mark := " [L]" if item["locked"] else ""
		cell.text = "%s\n%s · %s%s\npwr:%d" % [item["name"], item["rarity"], item["slot"], lock_mark, item["power_bonus"]]
		cell.pressed.connect(_on_cell_pressed.bind(item["instance_id"]))
		grid.add_child(cell)

	if Inventory.is_over_soft_cap(_state.inventory):
		capacity_warning_label.text = (
			"⚠ Inventory is large (%d items) -- consider scrapping unwanted gear." % _state.inventory.size()
		)
	else:
		capacity_warning_label.text = ""


func _on_cell_pressed(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_show_detail()


func _find_grid_item(instance_id: String) -> Dictionary:
	for item: Dictionary in _grid_items:
		if item["instance_id"] == instance_id:
			return item
	return {}


func _show_detail() -> void:
	var item := _find_grid_item(_selected_instance_id)
	if item.is_empty():
		_on_detail_back_pressed()
		return
	$GridTab.visible = false
	detail_panel.visible = true
	name_label.text = "%s%s" % [item["name"], " [LOCKED]" if item["locked"] else ""]
	var stat_lines := ["Rarity: %s" % item["rarity"], "Slot: %s" % item["slot"], "Class: %s" % item["clazz"]]
	stat_lines.append("Power bonus: +%d" % item["power_bonus"])
	for stat in item["stat_mods"]:
		stat_lines.append("%s: +%d" % [stat, item["stat_mods"][stat]])
	if item["set_id"] != "":
		stat_lines.append("Set: %s" % item["set_id"])
	stats_label.text = "\n".join(stat_lines)

	var wearer := Inventory.wearer_of(_selected_instance_id, _state.equipped, _state.army)
	match wearer["kind"]:
		"hunter":
			wearer_label.text = "Currently equipped by: you (the hunter)"
		"shadow":
			var shadow_idx := _state.army.find_custom(
				func(s: Dictionary) -> bool: return s["instance_id"] == wearer["shadow_instance_id"]
			)
			var shadow_name := "a shadow"
			if shadow_idx >= 0:
				var monster := Content.monster_by_id(_monsters, _state.army[shadow_idx].get("monster_id", ""))
				shadow_name = monster.get("name", "a shadow")
			wearer_label.text = "Currently equipped by: %s" % shadow_name
		_:
			wearer_label.text = "Unequipped"

	lock_button.text = "Unlock" if item["locked"] else "Lock"
	var worn := wearer["kind"] != "none"
	scrap_button.visible = not worn and not item["locked"]


func _on_detail_back_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	_selected_instance_id = ""


func _on_lock_pressed() -> void:
	if _selected_instance_id == "":
		return
	var item := _find_grid_item(_selected_instance_id)
	_state.set_item_locked(_selected_instance_id, not item.get("locked", false))
	_after_mutation()
	_show_detail()


## Structural guard already lives in HunterState.scrap_item() (returns 0
## for locked/equipped) -- this button is also hidden for those cases in
## _show_detail(), so the guard and the UI agree, not just a confirm
## dialog papering over a UI-only restriction.
func _on_scrap_pressed() -> void:
	if _selected_instance_id == "":
		return
	_state.scrap_item(_selected_instance_id, _equipment)
	_after_mutation()
	_on_detail_back_pressed()


func _after_mutation() -> void:
	SaveService.save(_state)
	state_changed.emit()
	_refresh_grid()
```

- [ ] **Step 3: Wire the standalone entry point in `scenes/main.gd`**

Remove `inventory_label` (`@onready var`), `_refresh_inventory_label()`, and its 4 call sites (`_start_game()`, and wherever else it's called — grep the file for `_refresh_inventory_label` to find every one, same "find them all, don't trust stale line numbers" lesson §17's Task 6 already learned).

Add:

```gdscript
@onready var inventory_button: Button = $GameUI/InventoryButton
@onready var inventory_view: InventoryView = $GameUI/InventoryPanel
```

In `_start_game()`, alongside the other `.bind()` calls:

```gdscript
	inventory_view.bind(state, _equipment, _monsters)
```

In `_setup_gear_panels()`, alongside the other panel wiring:

```gdscript
		inventory_button.pressed.connect(func() -> void: inventory_view.open())
		inventory_view.state_changed.connect(_on_state_changed)
```

- [ ] **Step 4: Run gdformat/gdlint + full GUT suite**

Run gdformat/gdlint on `scenes/inventory_view.gd` and `scenes/main.gd`. Run the full suite as a regression check (this task adds no new `core/` logic, so nothing should move). Also do a headless boot check (same technique §17 used) for `SCRIPT ERROR`/`Node not found` — this task's `.tscn` surgery is substantial.

- [ ] **Step 5: Manual verification**

Open Inventory from the new HUD button. Confirm: the grid populates from real owned gear; each filter button cycles and visibly narrows the grid; sort visibly reorders it; tapping a cell opens detail with correct stats/wearer text; Lock toggles and the Scrap button visibility follows; Scrap actually removes the item and returns to the grid; the capacity warning appears only once inventory size reaches 200 (hard to trigger by hand — at minimum confirm the label stays empty on a normal-sized inventory).

- [ ] **Step 6: Commit**

```bash
git add scenes/inventory_view.gd scenes/main.tscn scenes/main.gd
git commit -m "§17b step 4: Inventory screen Grid tab + item detail (standalone, no Compare yet)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 5: Sets tab

**Files:**
- Modify: `scenes/main.tscn` — `SetsTabButton` + `SetsTab` node tree under `InventoryPanel`.
- Modify: `scenes/inventory_view.gd`

**Interfaces:**
- Consumes: `ArmorSets.owned_set_counts()` (Task 3), `equipment["armor_sets"]` (existing content).

- [ ] **Step 1: Add the Sets tab nodes to `scenes/main.tscn`**

Add a `SetsTabButton` beside `GridTabButton` (same row, x 280-500), and a `SetsTab` container with a `ScrollContainer` > row-list pattern (mirroring `GridTab`'s scroll setup):

```
[node name="SetsTabButton" type="Button" parent="GameUI/InventoryPanel"]
offset_left = 280.0
offset_top = 20.0
offset_right = 500.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 20
text = "Sets"

[node name="SetsTab" type="Node2D" parent="GameUI/InventoryPanel"]
visible = false

[node name="SetsScroll" type="ScrollContainer" parent="GameUI/InventoryPanel/SetsTab"]
offset_left = 0.0
offset_top = 90.0
offset_right = 2424.0
offset_bottom = 1000.0

[node name="SetsRows" type="Node2D" parent="GameUI/InventoryPanel/SetsTab/SetsScroll"]
```

- [ ] **Step 2: Wire it in `scenes/inventory_view.gd`**

Add to `_ready()`:

```gdscript
	$SetsTabButton.pressed.connect(_on_sets_tab_pressed)
```

Add `@onready var sets_rows: Node2D = $SetsTab/SetsScroll/SetsRows`.

New methods:

```gdscript
func _on_grid_tab_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = true
	$SetsTab.visible = false
	_refresh_grid()


func _on_sets_tab_pressed() -> void:
	detail_panel.visible = false
	$GridTab.visible = false
	$SetsTab.visible = true
	_refresh_sets()


## Rebuilds one row per set in equipment["armor_sets"] -- name, owned/4
## (ArmorSets.owned_set_counts), and both tier bonus strings verbatim
## (same "display only, see core/armor_sets.gd for what's mechanical"
## convention GearPanelHelpers.active_sets_display already uses).
func _refresh_sets() -> void:
	for child in sets_rows.get_children():
		child.queue_free()
	var counts := ArmorSets.owned_set_counts(_state.inventory, _equipment)
	var y := 0.0
	for set_def: Dictionary in _equipment.get("armor_sets", []):
		var owned: int = counts.get(set_def.get("id", ""), 0)
		var label := Label.new()
		label.position = Vector2(40, y)
		label.size = Vector2(2340, 80)
		label.add_theme_font_size_override("font_size", 18)
		label.text = (
			"%s  %d/4\n  2pc: %s\n  4pc: %s"
			% [set_def.get("name", ""), owned, set_def.get("bonus_2pc", ""), set_def.get("bonus_4pc", "")]
		)
		sets_rows.add_child(label)
		y += 90
```

(Note: `_on_grid_tab_pressed()` above is the SAME method Task 4 already wrote, extended here with the one new line `$SetsTab.visible = false` — this is a straightforward edit to existing code, not a new method.)

- [ ] **Step 3: Run gdformat/gdlint + full GUT suite (regression check), then a headless boot check**

- [ ] **Step 4: Manual verification**

Open Inventory → Sets tab. Confirm all 15 sets list with correct owned/4 counts (cross-check against a known owned piece), and both bonus strings render.

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn scenes/inventory_view.gd
git commit -m "§17b step 5: Inventory screen Sets tab

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 6: Bulk scrap — multi-select, "below rarity", "unequipped duplicates", confirm-with-yield

**Files:**
- Modify: `scenes/main.tscn` — `BulkBar` under `GridTab`, plus a `ConfirmScrapPanel` overlay.
- Modify: `scenes/inventory_view.gd`

**Interfaces:**
- Consumes: `Inventory.scrap_candidates_below_rarity()`, `Inventory.scrap_candidates_unequipped_duplicates()` (Task 1); `HunterState.bulk_scrap()` (Task 2); `GameLogic.essence_for_scrapped_item()` (Task 3, for computing the yield preview before committing).

- [ ] **Step 1: Add the bulk-action bar and confirm overlay to `scenes/main.tscn`**

```
[node name="BulkBar" type="Node2D" parent="GameUI/InventoryPanel/GridTab"]
position = Vector2(0, 940)

[node name="MultiSelectToggleButton" type="Button" parent="GameUI/InventoryPanel/GridTab/BulkBar"]
offset_left = 40.0
offset_top = 0.0
offset_right = 340.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Select Multiple"

[node name="ScrapSelectedButton" type="Button" parent="GameUI/InventoryPanel/GridTab/BulkBar"]
offset_left = 360.0
offset_top = 0.0
offset_right = 640.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Scrap Selected"

[node name="ScrapBelowRarityButton" type="Button" parent="GameUI/InventoryPanel/GridTab/BulkBar"]
offset_left = 660.0
offset_top = 0.0
offset_right = 1020.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Scrap Below: UNCOMMON"

[node name="ScrapDuplicatesButton" type="Button" parent="GameUI/InventoryPanel/GridTab/BulkBar"]
offset_left = 1040.0
offset_top = 0.0
offset_right = 1400.0
offset_bottom = 50.0
theme_override_font_sizes/font_size = 18
text = "Scrap Unequipped Duplicates"

[node name="ConfirmScrapPanel" type="Node2D" parent="GameUI/InventoryPanel"]
visible = false

[node name="ConfirmBg" type="ColorRect" parent="GameUI/InventoryPanel/ConfirmScrapPanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 2424.0
offset_bottom = 1080.0
color = Color(0.0, 0.0, 0.0, 0.85)

[node name="ConfirmLabel" type="Label" parent="GameUI/InventoryPanel/ConfirmScrapPanel"]
offset_left = 400.0
offset_top = 400.0
offset_right = 2024.0
offset_bottom = 550.0
theme_override_font_sizes/font_size = 26
text = ""

[node name="ConfirmButton" type="Button" parent="GameUI/InventoryPanel/ConfirmScrapPanel"]
offset_left = 400.0
offset_top = 900.0
offset_right = 700.0
offset_bottom = 950.0
theme_override_font_sizes/font_size = 20
text = "Confirm Scrap"

[node name="CancelButton" type="Button" parent="GameUI/InventoryPanel/ConfirmScrapPanel"]
offset_left = 720.0
offset_top = 900.0
offset_right = 960.0
offset_bottom = 950.0
theme_override_font_sizes/font_size = 20
text = "Cancel"
```

Reposition `GridScroll`/`CapacityWarningLabel` if they now overlap the new `BulkBar` at y=940 (check the actual current offsets before editing — `GridScroll` was placed `offset_bottom = 890` and `CapacityWarningLabel` at `900-940` in Task 4, which already clears this bar's `y=940` start, so no change should be needed; verify rather than assume, per the standing lesson from §17).

- [ ] **Step 2: Wire it in `scenes/inventory_view.gd`**

Add state:

```gdscript
var _multi_select_mode: bool = false
var _multi_selected: Dictionary = {}  ## instance_id -> true, only meaningful while _multi_select_mode
var _pending_scrap_ids: Array = []  ## computed by whichever bulk action was tapped, awaiting confirm
const RARITY_BELOW_OPTIONS := ["UNCOMMON", "RARE", "EPIC", "LEGENDARY"]  ## "below COMMON" would be empty, excluded
var _rarity_below_threshold: String = "UNCOMMON"
```

Add to `_ready()`:

```gdscript
	$GridTab/BulkBar/MultiSelectToggleButton.pressed.connect(_on_multi_select_toggle_pressed)
	$GridTab/BulkBar/ScrapSelectedButton.pressed.connect(_on_scrap_selected_pressed)
	$GridTab/BulkBar/ScrapBelowRarityButton.pressed.connect(_on_scrap_below_rarity_pressed)
	$GridTab/BulkBar/ScrapDuplicatesButton.pressed.connect(_on_scrap_duplicates_pressed)
	$ConfirmScrapPanel/ConfirmButton.pressed.connect(_on_confirm_scrap_pressed)
	$ConfirmScrapPanel/CancelButton.pressed.connect(_on_cancel_scrap_pressed)
```

Multi-select changes the grid-cell tap behavior — modify `_on_cell_pressed()` from Task 4:

```gdscript
func _on_cell_pressed(instance_id: String) -> void:
	if _multi_select_mode:
		if _multi_selected.has(instance_id):
			_multi_selected.erase(instance_id)
		else:
			_multi_selected[instance_id] = true
		_refresh_grid()  # redraw so selected cells can show a mark
		return
	_selected_instance_id = instance_id
	_show_detail()


func _on_multi_select_toggle_pressed() -> void:
	_multi_select_mode = not _multi_select_mode
	_multi_selected.clear()
	$GridTab/BulkBar/MultiSelectToggleButton.text = (
		"Cancel Multi-Select" if _multi_select_mode else "Select Multiple"
	)
	_refresh_grid()
```

Update `_refresh_grid()`'s cell-building loop (from Task 4) to show a selected mark — add one line inside the `for item: Dictionary in _grid_items:` loop, right after computing `lock_mark`:

```gdscript
		var select_mark := " [✓]" if _multi_selected.has(item["instance_id"]) else ""
```

and include it in the cell's `.text` format string alongside `lock_mark`.

New bulk-action handlers, computing candidates + total yield, then opening the confirm overlay rather than scrapping immediately (per spec: "show total Essence yield before confirming"):

```gdscript
func _on_scrap_selected_pressed() -> void:
	if _multi_selected.is_empty():
		return
	_offer_scrap_confirm(_multi_selected.keys())


func _on_scrap_below_rarity_pressed() -> void:
	_rarity_below_threshold = RARITY_BELOW_OPTIONS[
		(RARITY_BELOW_OPTIONS.find(_rarity_below_threshold) + 1) % RARITY_BELOW_OPTIONS.size()
	]
	$GridTab/BulkBar/ScrapBelowRarityButton.text = "Scrap Below: %s" % _rarity_below_threshold
	# Cycling the threshold is a separate tap from committing to it -- a second, explicit
	# "go" isn't specced, so this button both cycles AND immediately offers the confirm
	# for whatever it now reads, matching "no extra taps beyond what's needed" elsewhere
	# in this project's placeholder UI.
	var candidates := Inventory.scrap_candidates_below_rarity(
		_state.inventory, _equipment, _rarity_below_threshold, _state.equipped, _state.army
	)
	_offer_scrap_confirm(candidates)


func _on_scrap_duplicates_pressed() -> void:
	var candidates := Inventory.scrap_candidates_unequipped_duplicates(
		_state.inventory, _state.equipped, _state.army
	)
	_offer_scrap_confirm(candidates)


func _offer_scrap_confirm(instance_ids: Array) -> void:
	if instance_ids.is_empty():
		return
	_pending_scrap_ids = instance_ids
	var total := 0
	for instance_id in instance_ids:
		var item := _state.inventory[_state.inventory.find_custom(
			func(i: Dictionary) -> bool: return i["instance_id"] == instance_id
		)]
		var def := Content.equipment_by_id(_equipment, item.get("equipment_def_id", ""))
		total += GameLogic.essence_for_scrapped_item(def.get("rarity", ""))
	$ConfirmScrapPanel/ConfirmLabel.text = "Scrap %d item(s) for %d Essence?" % [instance_ids.size(), total]
	$ConfirmScrapPanel.visible = true


func _on_confirm_scrap_pressed() -> void:
	$ConfirmScrapPanel.visible = false
	_state.bulk_scrap(_pending_scrap_ids, _equipment)
	_pending_scrap_ids = []
	_multi_selected.clear()
	_after_mutation()


func _on_cancel_scrap_pressed() -> void:
	$ConfirmScrapPanel.visible = false
	_pending_scrap_ids = []
```

- [ ] **Step 3: Run gdformat/gdlint + full GUT suite (regression), headless boot check**

- [ ] **Step 4: Manual verification**

Toggle multi-select, pick 2-3 items, Scrap Selected → confirm shows the right count/yield, confirming actually scraps and clears selection. Scrap Below: cycles rarity and offers a confirm each cycle. Scrap Unequipped Duplicates → offers a confirm matching what `core/inventory.gd`'s own tests already proved (every unequipped copy, keeping none spare). Cancel on any of these leaves inventory untouched.

- [ ] **Step 5: Commit**

```bash
git add scenes/main.tscn scenes/inventory_view.gd
git commit -m "§17b step 6: bulk scrap -- multi-select, below-rarity, unequipped-duplicates, confirm+yield

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 7: The slot-tap-to-browse retrofit — Compare, Equip-from-detail, gear panel wiring

**Files:**
- Modify: `scenes/gear_panel_helpers.gd` — a "Browse" button per gear row.
- Modify: `scenes/shadow_gear_view.gd`, `scenes/hunter_gear_view.gd` — Browse opens Inventory pre-filtered+contexted.
- Modify: `scenes/inventory_view.gd` — a context-carrying open variant, Compare display, Equip-from-detail.
- Modify: `scenes/main.gd` — pass `inventory_view` into both gear panels' `bind()`.

This is the one task in this plan that touches §17's already-shipped files — deliberately last, since it needs the Inventory screen (Tasks 4-6) to already exist. Same reasoning §17's own plan used for sequencing its slot-tap deferral.

**Interfaces:**
- Consumes: `Inventory.compare_delta()` (Task 1); `HunterState.equip_to_hunter()`, `equip_to_shadow()` (existing); `InventoryView`'s Task 4-6 internals (extended here, not replaced).

- [ ] **Step 1: Add a "Browse" button to `GearPanelHelpers.build_gear_rows()`**

In `scenes/gear_panel_helpers.gd`, add a 5th button per row, after `enhance_btn`:

```gdscript
		var browse_btn := Button.new()
		browse_btn.position = Vector2(1140, y)
		browse_btn.size = Vector2(130, 40)
		browse_btn.text = "Browse"
		parent.add_child(browse_btn)
```

Add `"browse_btn": browse_btn,` to the row dict this function returns (alongside `"equip_btn"`/`"unequip_btn"`/`"enhance_btn"`).

- [ ] **Step 2: Add a context-carrying open variant to `scenes/inventory_view.gd`**

New signal + method:

```gdscript
signal item_equipped  ## fired after a successful Equip-from-detail, so the caller (a gear
## panel) can refresh itself -- distinct from state_changed, which the shared HUD listens to;
## this one specifically tells "your paper-doll may now be stale, refresh your own display"

var _context := {"kind": "none", "shadow_instance_id": ""}  ## set by open_for_slot(), cleared by open()
var _context_slot: String = ""


## Called from a gear panel's new "Browse" button -- opens pre-filtered to
## `slot` and (if given) `class_filter`, with `context` carried through so
## Compare and Equip-from-detail both work. `context`: {"kind": "hunter"|
## "shadow", "shadow_instance_id": ""}.
func open_for_slot(slot: String, class_filter: String, context: Dictionary) -> void:
	_context = context
	_context_slot = slot
	_filters["slot"] = slot
	_filters["class"] = class_filter
	visible = true
	_on_grid_tab_pressed()
```

Update `open()` (Task 4) to clear context, since it's the no-context standalone path:

```gdscript
func open() -> void:
	_context = {"kind": "none", "shadow_instance_id": ""}
	_context_slot = ""
	visible = true
	$GridTabButton.visible = true
	_on_grid_tab_pressed()
```

Extend `_show_detail()` (Task 4) to add Compare (only when `_context["kind"] != "none"` and the item's own slot matches `_context_slot` -- comparing a WEAPON candidate against a HEAD slot's current occupant would be meaningless) and to show/wire the Equip button:

```gdscript
	var equip_button: Button = $DetailPanel/EquipButton
	equip_button.visible = _context["kind"] != "none" and item["slot"] == _context_slot
	$DetailPanel/CompareLabel.text = ""
	if equip_button.visible:
		var current_def := _current_context_def()
		var delta := Inventory.compare_delta(item, current_def)
		var lines := ["vs. currently equipped:", "Power: %+d" % delta["power_delta"]]
		for stat in delta["stat_delta"]:
			lines.append("%s: %+d" % [stat, delta["stat_delta"][stat]])
		$DetailPanel/CompareLabel.text = "\n".join(lines)
```

(Add this block to the END of `_show_detail()`, after the existing `scrap_button.visible = ...` line — everything already in that method from Task 4 stays unchanged.)

New helper + the Equip handler:

```gdscript
## The def dict (enhancement-scaled, same shape filter_by's enrichment
## produces) of whatever's currently in _context_slot for the current
## context -- {} if the slot's empty. compare_delta() treats {} as
## all-zero, so an empty slot just shows the full candidate as pure gain.
func _current_context_def() -> Dictionary:
	var current_instance_id := ""
	if _context["kind"] == "hunter":
		current_instance_id = _state.equipped.get(_context_slot, "")
	elif _context["kind"] == "shadow":
		var idx := _state.army.find_custom(
			func(s: Dictionary) -> bool: return s["instance_id"] == _context["shadow_instance_id"]
		)
		if idx >= 0:
			current_instance_id = _state.army[idx].get("equipped", {}).get(_context_slot, "")
	if current_instance_id == "":
		return {}
	var current_items := Inventory.filter_by(_state.inventory, _equipment, _state.equipped, _state.army, {})
	for i: Dictionary in current_items:
		if i["instance_id"] == current_instance_id:
			return i
	return {}


func _on_equip_pressed() -> void:
	if _selected_instance_id == "" or _context["kind"] == "none":
		return
	var ok := false
	if _context["kind"] == "hunter":
		ok = _state.equip_to_hunter(_selected_instance_id, _equipment)
	elif _context["kind"] == "shadow":
		ok = _state.equip_to_shadow(_context["shadow_instance_id"], _selected_instance_id, _equipment, _monsters)
	if not ok:
		return
	_after_mutation()
	item_equipped.emit()
	_on_detail_back_pressed()
```

Wire the new button in `_ready()`:

```gdscript
	$DetailPanel/EquipButton.pressed.connect(_on_equip_pressed)
```

- [ ] **Step 3: Wire Browse in `scenes/shadow_gear_view.gd`**

Add `var _inventory_view: InventoryView` and extend `bind()`'s signature to accept it:

```gdscript
func bind(state: HunterState, equipment: Dictionary, monsters: Array, inventory_view: InventoryView) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters
	_inventory_view = inventory_view
```

In `_ready()`, wire each row's new Browse button (alongside the existing `equip_btn`/`unequip_btn`/`enhance_btn` connections):

```gdscript
		row["browse_btn"].pressed.connect(_on_browse_pressed.bind(slot))
```

New handler:

```gdscript
func _on_browse_pressed(slot: String) -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var monster := Content.monster_by_id(_monsters, _state.army[_index].get("monster_id", ""))
	_inventory_view.open_for_slot(slot, monster.get("clazz", ""), {"kind": "shadow", "shadow_instance_id": shadow_id})
```

Also connect `_inventory_view.item_equipped` in `_ready()` so this panel refreshes when Inventory equips something onto the currently-viewed shadow:

```gdscript
	_inventory_view.item_equipped.connect(refresh)
```

- [ ] **Step 4: Wire Browse in `scenes/hunter_gear_view.gd`**

Same pattern, simpler (no per-shadow index, and the class is just `_state.subclass`):

```gdscript
func bind(state: HunterState, equipment: Dictionary, inventory_view: InventoryView) -> void:
	_state = state
	_equipment = equipment
	_inventory_view = inventory_view
```

```gdscript
		row["browse_btn"].pressed.connect(_on_browse_pressed.bind(slot))
```

```gdscript
func _on_browse_pressed(slot: String) -> void:
	_inventory_view.open_for_slot(slot, _state.subclass, {"kind": "hunter", "shadow_instance_id": ""})
```

```gdscript
	_inventory_view.item_equipped.connect(refresh)
```

- [ ] **Step 5: Update `scenes/main.gd`'s `bind()` calls**

Both gear panels' `.bind()` calls in `_start_game()` need the new parameter — `inventory_view` must already be bound itself by this point (check `_start_game()`'s current ordering; if `inventory_view.bind(...)` from Task 4 runs after these two calls, reorder so it runs first):

```gdscript
	hunter_gear_view.bind(state, _equipment, inventory_view)
	shadow_gear_view.bind(state, _equipment, _monsters, inventory_view)
```

- [ ] **Step 6: Run gdformat/gdlint + full GUT suite, headless boot check**

This task touches the most files of any in this plan (5 `.gd` files) — the headless boot check matters more here than anywhere else in this plan.

- [ ] **Step 7: Manual verification**

From Shadow Gear, tap "Browse" on a slot — confirm Inventory opens pre-filtered to that slot+class, with the shadow as context. Select a candidate item — confirm Compare shows correct green/red deltas against what that shadow currently has equipped (or "all gain" if the slot's empty) — cross-check the numbers by hand against the two items' known stats. Tap Equip — confirm it actually equips onto that exact shadow, closes back to detail-cleared state, and the Shadow Gear panel (if reopened) reflects the change. Repeat from Hunter Gear. Confirm a standalone Inventory open (via the HUD button) still shows no Compare/Equip button anywhere.

- [ ] **Step 8: Commit**

```bash
git add scenes/gear_panel_helpers.gd scenes/shadow_gear_view.gd scenes/hunter_gear_view.gd scenes/inventory_view.gd scenes/main.gd
git commit -m "§17b step 7: slot-tap-to-browse retrofit -- Compare, Equip-from-detail, gear panel wiring

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

## Self-Review

**Spec coverage:** scrollable ~4-across grid (Task 4, `GridContainer`+`ScrollContainer`), filter bar pinned top / bulk bar lower thumb zone (Tasks 4/6, §10a-consistent), all 5 filter dimensions + 4 sort modes (Task 1/4), item detail with stats/rarity/set/wearer (Task 4), Compare with green/red-equivalent deltas (Task 7 — text-based +/- since this project has no icon/color system yet for placeholder UI, same convention as everywhere else), Sets tab with owned/total (Task 5), bulk scrap incl. multi-select/below-rarity/unequipped-duplicates with a structural locked/equipped guard and a shown-before-committing yield (Task 6, guard enforced at the `HunterState` layer in Task 2 not just the UI), capacity soft-cap warning that never blocks `add_to_inventory()` (Task 1/4), shared inventory with no hunter/shadow split (unchanged throughout, per design decision #7/#8 already settled) — all covered.

**Placeholder scan:** no TBD/TODO. One judgment call flagged inline in Task 6 (the "cycle-and-offer" behavior for Scrap Below Rarity, since the spec doesn't say whether cycling and committing are separate taps) — resolved with reasoning given, not left open.

**Type consistency:** `context` dicts (`{"kind": ..., "shadow_instance_id": ...}`) use the exact same shape `Inventory.wearer_of()` already returns, everywhere they appear (Task 1's tests, Task 7's `open_for_slot`/`_current_context_def`) — no drift between "kind" vs some other key name across tasks.

**New data-integrity fix:** the `next_inventory_id` counter (Task 2) is the one piece of this plan not in the original design spec — surfaced during this plan's own brainstorm when re-reading `add_to_inventory()` against what bulk scrap would newly expose, decided with the user before writing the task.
