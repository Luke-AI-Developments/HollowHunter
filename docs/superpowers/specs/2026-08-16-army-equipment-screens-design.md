# Army Management (§17) & Equipment Inventory (§17b) Screens — Design

**Goal:** replace the flat home-screen shadow/item lists with the two real management screens the design doc specs — the §17 Army screen first, then the §17b Equipment inventory screen that browses the pool it draws from.

**Build order:** §17 fully working before §17b starts. The paper-doll (§17) is the primary way players interact with gear; the inventory (§17b) is the supporting browse/maintain layer around it — building it first would be backwards. Each screen should be playable and shippable on its own, matching this project's own "each phase must be playable on its own" discipline (§24).

**Both screens follow §10a** (portrait-only, thumb-zone: primary actions in the lower ~40%, info-only in the top band) **and reuse existing conventions**: `core/` stays pure/engine-free and unit-tested, scene controllers stay thin, one controller per screen/panel.

---

## Decisions made during design (read this before the sections below)

These were open questions resolved during brainstorming — recorded here so the plan doesn't re-litigate them:

1. **`element` is dropped, replaced by `family`.** §17's original text listed "element" in the shadow-identity block, but elements were cut project-wide (§14b) and `monsters.json` has no such field. `family` (Hollow Brood, Gravekin, etc.) is the real, still-alive taxonomy that replaced it.
2. **Lore text doesn't exist yet — sourced as a stopgap, not left empty.** No monster has narrative lore anywhere in the repo. Rather than build the "Lore/flavor" section against nothing, each monster's existing §14b art-direction comment (e.g. Grubmaw: *"teardrop larva, one giant toothy maw"*) becomes a new `lore` string field in `monsters.json` — a real, if minimal, one-time content pass across all 57 entries, not invented from scratch.
3. **Shadow traits (§6b) get a placeholder slot, not real content.** §6b is explicitly marked "design pass pending" in the doc itself. The shadow detail hub reserves a Traits line in the identity block now (so the layout doesn't need rework later) but shows nothing real yet — no trait data model, no CLAIM-time rolling, that's a separate future spec.
4. **Inventory capacity soft cap: 200 items, invented and flagged.** No number is given anywhere in the source. 200 follows this project's own established pattern (`ShadowLeveling`'s fuse discount, `Stronghold`'s upgrade costs, etc.) for filling an unspecified v0 number — generous for a fresh save, reachable after real mid-game grinding, documented as a guess to tune later.
5. **"Scrap all unequipped duplicates" scraps every unequipped copy, keeps none spare.** If you own 3 copies of an item and 1 is equipped, the other 2 are both scrapped — no "keep one spare" behavior. Matches the literal wording of the spec.
6. **Compare context hands off via a slot tap.** Tapping a gear-slot row in the shadow detail hub (not just its existing "Equip Best" button) opens the Inventory screen pre-filtered to that slot + the shadow's class, carrying the shadow as Compare context. The Inventory screen is also reachable standalone (its own HUD button) with no shadow context — Compare simply doesn't render there.
7. **The existing Squad panel (`squad_view.gd`) is absorbed as a tab, not rebuilt.** It already implements §17's "auto-optimize + manual tweak" squad-of-6 exactly as specced. It gets re-parented under the new Army screen as a "Squad" tab, logic untouched, with one addition (see §2 below).
8. **Hunter gear stays in the shared inventory pool, confirmed by code, not just design intent.** `core/equip.gd`'s own doc comment says "hunter and shadows share the one inventory pool" — `HunterState.inventory` is a single flat `Array`; `equip_to_hunter()`/`equip_to_shadow()`/`is_instance_equipped()`/`gear_bonus()` all read/write that same pool. §17b is shared with a class filter; it is never split into two bags. Splitting it now would mean restructuring tested, working code for no gameplay reason.

---

## 1. Data model & core modules

### `content/monsters.json`
Add a `"lore"` field to all 57 entries (decision #2 above) — content pass, not logic.

### `core/hunter_state.gd` (modified)
- `add_to_inventory()` — inventory items gain `"locked": false`, mirroring the existing shadow `locked`/`favorite` convention.
- New `set_item_locked(instance_id: String, locked: bool) -> bool`.
- New `scrap_item(instance_id: String) -> int` — essence gained; `0` (no-op) if the item is unknown, locked, or currently worn by the hunter *or any shadow* (checked via `Inventory.wearer_of`).
- New `bulk_scrap(instance_ids: Array) -> int` — same shape as the existing `mass_convert()`: calls `scrap_item` per id, silently skips any that don't qualify, returns the total.
- New `auto_equip_squad(instance_ids: Array, equipment: Dictionary, monsters: Array) -> int` — loops the existing `auto_equip_shadow()` over a set of shadows; returns how many slots changed across all of them.

### New `core/inventory.gd` — pure, unit-tested
Browse/maintain logic, kept separate from `Equip` (slot/class-gating mechanics) per this project's one-class-one-responsibility convention:
- `const RARITY_ORDER := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]`
- `const SOFT_CAP := 200`
- `filter_by(inventory: Array, equipment: Dictionary, filters: Dictionary) -> Array` — `filters` keys: `class`, `slot`, `rarity`, `set_id`, `equipped` (bool, optional/omit = no filter on equipped state)
- `sort_by(items: Array, mode: String) -> Array` — `mode` one of `"power"`, `"rarity"`, `"slot"`, `"newest"`. "Newest" is reverse inventory order — `instance_id`s are already append-order (`"eq_inst_%d" % inventory.size()`), so no new timestamp field is needed.
- `wearer_of(instance_id: String, hunter_equipped: Dictionary, army: Array) -> Dictionary` — `{"kind": "none"|"hunter"|"shadow", "shadow_instance_id": ""}`. Backs both the "currently equipped by `<shadow>`" label and the scrap guard.
- `compare_delta(candidate_def: Dictionary, current_def: Dictionary) -> Dictionary` — per-stat and power deltas for the green/red arrows.
- `scrap_candidates_below_rarity(inventory: Array, equipment: Dictionary, threshold: String, hunter_equipped: Dictionary, army: Array) -> Array` — eligible instance_ids (excludes locked/equipped).
- `scrap_candidates_unequipped_duplicates(inventory: Array, hunter_equipped: Dictionary, army: Array) -> Array` — per decision #5.
- `is_over_soft_cap(inventory: Array) -> bool`.

### `core/game_logic.gd` (modified)
New `ESSENCE_PER_SCRAPPED_ITEM := {"COMMON": 2, "UNCOMMON": 4, "RARE": 8, "EPIC": 16, "LEGENDARY": 32}`, sitting beside the existing `ESSENCE_PER_CONVERTED_SHADOW`. No source number exists for this either — a doubling curve on its own base (not reusing the shadow-conversion numbers), same "don't let two Essence sinks read as directly comparable" reasoning `ShadowLeveling`'s own doc comment already uses for its fuse discount.

### `core/armor_sets.gd` (modified)
New `owned_set_counts(inventory: Array, equipment: Dictionary) -> Dictionary` — sibling to the existing `equipped_set_counts()`, but counting the whole owned inventory instead of just what's worn. Feeds the Sets tab's "3/4" readout.

---

## 2. §17 Army screen

**Shell — new `scenes/army_view.gd`.** One panel, two tabs: **Roster** | **Squad**. Replaces today's standalone "Shadow Gear" HUD button and the flat `ArmyLabel` text with one entry point, matching §17's "one hub with everything" framing.

**Roster tab.** Filter/sort bar pinned top (grade filter, power/grade sort — top-pinned for consistency with §17b's own bar under the shared thumb-zone rule). Below it, 5 collapsible sections (Warrior/Guardian/Assassin/Mage/Support), each a tap-to-collapse header over that class's shadows. Row text keeps the existing format (name/display, grade·level, power, `[S]`/`[L]`/`[F]` markers) but each row becomes a button: tap → opens the shadow detail hub.

**Squad tab.** `squad_view.gd`, re-parented under the new tab, otherwise untouched, **plus one addition**: a new "Auto-Equip Squad" button beside its existing "Auto Fill", wired to `HunterState.auto_equip_squad()`. This is the only new code on this tab — everything else is the already-working, already-tested panel.

**Shadow detail hub — modified `shadow_gear_view.gd`.** Identity block adds Family (replacing element, decision #1), a Lore line (decision #2), and a placeholder Traits line (decision #3), at the bottom per spec. New interaction: **each gear-slot row becomes tappable**, not just its "Equip Best" button — tapping the row opens the Inventory screen pre-filtered to that slot + this shadow's class, with the shadow carried as Compare context (decision #6); "Equip Best" still one-taps as before. This tap-target lives in the *shared* `GearPanelHelpers.build_gear_rows()`, so `HunterGearView` gets the same browse-and-compare flow for free — incidentally satisfying §21's "same inline paper-doll flow" for the hunter's own gear too, at no extra cost.

**Bulk actions, relocated.** "Mass-convert weak shadows" (already built, currently a standalone HUD button) moves into the Roster tab's lower thumb-zone as a bulk-action bar, consistent with §17b putting its own bulk actions in the same zone.

---

## 3. §17b Equipment inventory screen

**Shell — new `scenes/inventory_view.gd`.** Filter/sort bar pinned top (class / slot / rarity / set / equipped-unequipped filters; power / rarity / slot / newest-first sort). Below it, a scrollable ~4-across icon grid — placeholder-art icons for now, same convention as every other screen in this codebase; real `spr_<id>.png` art swaps in later by data ID with no code change.

**Item detail (tap a cell).** Full stats, rarity, set membership, and `Inventory.wearer_of()`'s answer rendered as "equipped by `<shadow>`" or "unequipped". Actions: equip (to the context shadow if one was carried in, otherwise a quick shadow-picker), Lock/Unlock, Scrap. Scrap is **hidden/disabled**, not just confirm-guarded, whenever the item is locked or worn — the UI and the `HunterState.scrap_item()` guard agree, so this is structural, not just a dialog.

**Compare.** Only renders when a shadow was carried in as context (the slot-tap flow from §17, decision #6); each candidate shows `Inventory.compare_delta()` against that shadow's current item in the same slot as green/red per-stat arrows.

**Sets tab.** A second tab on the same screen: all 15 sets, `ArmorSets.owned_set_counts()` for the "3/4" readout, tier-bonus text alongside.

**Bulk-action bar, lower thumb zone.** Multi-select toggle, "Scrap Selected", "Scrap below rarity: [picker]", "Scrap unequipped duplicates" — every path routes through `HunterState.bulk_scrap()`, and every one shows the total Essence yield before the confirm tap commits it.

**Capacity warning.** A non-blocking banner when `Inventory.is_over_soft_cap()` is true (≥200 items, decision #4) — never blocks `add_to_inventory()` itself, so a gate reward is never silently eaten.

**Entry points.** A new standalone "Inventory" HUD button (own panel, no shadow context, no Compare) alongside the slot-tap flow from §17.

---

## 4. Testing

- `core/inventory.gd`, the new `HunterState` methods (`set_item_locked`, `scrap_item`, `bulk_scrap`, `auto_equip_squad`), and `ArmorSets.owned_set_counts()` — fully unit-tested with GUT, pure/no-engine, same bar as every other `core/` file.
- `army_view.gd` / `inventory_view.gd` / the modified `shadow_gear_view.gd` / `gear_panel_helpers.gd` — manual/on-device verification only, per this project's own convention (scenes carry no game rules to unit-test; see `CLAUDE.md`).

---

## Out of scope for this pass

- Shadow traits (§6b) beyond a placeholder UI slot — its own design pass is explicitly still pending.
- Shadow nicknames (§6c) — a separate, already-planned-but-not-yet-greenlit feature (`docs/superpowers/plans/2026-08-16-shadow-nicknames.md`); not folded into this build.
- Real inventory-expansion purchases (spending Essence to raise the soft cap) — the spec only asks for the cap to be *expandable later*, not that this pass builds the expansion flow.
- Real art for inventory icons / shadow portraits — placeholder-art convention continues; swapped in later by data ID.
