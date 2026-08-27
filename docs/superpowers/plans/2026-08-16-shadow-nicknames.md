# Custom Shadow Naming (§6c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player give any owned shadow a per-instance nickname (optional, editable later), shown in place of its species name across the Army list, Squad picker, and Battle screen, with species+grade kept as secondary text.

**Architecture:** One new pure `core/` module (`TextFilter`) provides length + profanity validation. `HunterState` gets a `nickname` field per army entry and a `set_shadow_nickname()` mutator. `SquadBuilder.enrich_army()` becomes the single chokepoint that resolves `nickname` → `display_name`, which the three display surfaces (army label, squad picker, battle party) already read through. Two scene-layer entry points let the player set it: an optional prompt right after a real CLAIM, and a Rename control in the Shadow Gear panel.

**Tech Stack:** Godot 4 / GDScript, GUT for `core/` unit tests, existing `.tscn` text-format scene editing (no Godot editor session needed).

## Global Constraints

- Static typing everywhere, tabs for indentation, `snake_case` functions/vars, one class per file — per `CLAUDE.md`.
- `core/` stays pure (no `Node`, no engine calls) and unit-tested; `scenes/` stays thin view code with no game rules — per `CLAUDE.md`'s folder-layout rule.
- The post-edit hook (`.claude/settings.json`) runs `gdformat` + `gdlint` + the full GUT suite on every `core/`/`scenes/` `.gd` file save — exact whitespace in this plan's snippets will be reformatted automatically; don't hand-fix formatting nits.
- Nickname max length: **20 characters** (spec said "~16-20" — 20 chosen as the invented v0 number, same "flagged, not derived from the source" convention `ShadowLeveling`/`Stronghold` already use for their own invented constants).
- Empty/whitespace-only nickname is always valid — it means "use the default species name," never a rejected/blocked case.
- **Design assumption, flagged:** the two onboarding CLAIMs (`_on_subclass_chosen`'s free starter shadow and scripted first-gate win) do **not** get a nickname prompt. §25's own goal is a ~30-second onboarding CLAIM moment; inserting a text-entry step there works against that pacing. The prompt only fires on the two "real" CLAIM sites (a normal gate win, a Nadir boss claim) — renaming the starter/tutorial shadow later via Shadow Gear's Rename control is still fully available. Flag this to the user if the intent was "every CLAIM, no exceptions."
- Nicknames stay **private for v0** per the user's own lean — nothing in this plan touches the leaderboard schema or any shared/synced surface. No new task needed to enforce that; there's simply no pipe from `nickname` to `BackendService` anywhere in this plan.
- Scene-layer (`scenes/`) changes are verified manually (Godot editor / on-device, per this project's existing `devmedia/CAPTURE_LOG.md` convention), not via GUT — matches `CLAUDE.md`: scenes have no game rules to unit-test.

---

## File Structure

- **Create:** `core/text_filter.gd` — pure nickname validation (length + a v0 profanity blocklist). New shared module so a future hunter/display-name input can reuse it too.
- **Create:** `tests/unit/test_text_filter.gd`
- **Modify:** `core/hunter_state.gd` — `claim_shadow()` gains a `nickname` field; new `set_shadow_nickname()` mutator.
- **Modify:** `tests/unit/test_hunter_state.gd` — new tests for the above.
- **Modify:** `core/squad_builder.gd` — `enrich_army()` resolves `nickname` → `display_name`.
- **Modify:** `tests/unit/test_squad_builder.gd` — new tests for the above.
- **Modify:** `scenes/main.gd` — army label + battle party read `display_name`; new Claim-nickname prompt wired into the two real CLAIM sites.
- **Modify:** `scenes/squad_view.gd` — squad picker row reads `display_name`.
- **Modify:** `scenes/shadow_gear_view.gd` — Rename control; title shows nickname (primary) + species/grade (secondary line).
- **Modify:** `scenes/main.tscn` — new `ClaimNicknamePanel` under `GameUI`; new `RenameButton`/`RenameInput`/`RenameSaveButton`/`RenameCancelButton` under `ShadowGearPanel`; `SetsLabel` nudged down to make room.

---

### Task 1: `TextFilter` — pure nickname validation

**Files:**
- Create: `core/text_filter.gd`
- Test: `tests/unit/test_text_filter.gd`

**Interfaces:**
- Produces: `TextFilter.MAX_LENGTH: int`, `TextFilter.is_valid_nickname(text: String) -> bool`, `TextFilter.sanitize_nickname(text: String) -> String` — all `static`, used by Task 2.

- [ ] **Step 1: Write the failing tests**

```gdscript
# tests/unit/test_text_filter.gd
extends GutTest
## TextFilter: nickname length + v0 profanity-blocklist validation.


func test_empty_string_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname(""))


func test_whitespace_only_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname("   "))


func test_normal_name_within_length_is_valid() -> void:
	assert_true(TextFilter.is_valid_nickname("Duskfang"))


func test_name_at_exactly_max_length_is_valid() -> void:
	var name := "a".repeat(TextFilter.MAX_LENGTH)
	assert_true(TextFilter.is_valid_nickname(name))


func test_name_over_max_length_is_invalid() -> void:
	var name := "a".repeat(TextFilter.MAX_LENGTH + 1)
	assert_false(TextFilter.is_valid_nickname(name))


func test_blocked_word_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("fuck"))


func test_blocked_word_is_invalid_case_insensitive() -> void:
	assert_false(TextFilter.is_valid_nickname("FuCk"))


func test_blocked_word_as_substring_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("xfuckx"))


func test_sanitize_trims_leading_and_trailing_whitespace() -> void:
	assert_eq(TextFilter.sanitize_nickname("  Duskfang  "), "Duskfang")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_text_filter.gd -gexit`
Expected: FAIL — `Could not find type "TextFilter"` (class doesn't exist yet).

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# core/text_filter.gd
class_name TextFilter
## Pure text-input validation for anywhere the player types a short custom
## name -- currently just shadow nicknames (§6c). Factored out on its own,
## not folded into HunterState, so a future hunter/display-name input
## (§9/§31's "picks a display name" flow -- not yet built, see leaderboard_
## view.gd) can reuse MAX_LENGTH/the blocklist instead of duplicating one.
##
## The blocklist is a hardcoded v0 list, not a real profanity-detection
## library -- it won't catch l33tspeak/spacing evasion. Flagged as a real
## gap if this ever needs to be robust, same "good enough for v0" bar as
## every other invented number in this project (see ShadowLeveling).

const MAX_LENGTH := 20

## v0 blocklist -- invented, not exhaustive. Case-insensitive substring
## match, so it also catches embedded uses (e.g. "xfuckx").
const _BLOCKED_SUBSTRINGS := [
	"fuck",
	"shit",
	"cunt",
	"nigger",
	"nigga",
	"faggot",
	"fag",
	"retard",
	"whore",
	"slut",
	"rape",
	"nazi",
	"hitler",
]


## Empty/whitespace-only text is always valid -- it means "use the default
## species name," a skip, not a rejected value. Otherwise: must fit
## MAX_LENGTH and not contain a blocked word.
static func is_valid_nickname(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed.length() > MAX_LENGTH:
		return false
	return not _contains_blocked_word(trimmed)


static func sanitize_nickname(text: String) -> String:
	return text.strip_edges()


static func _contains_blocked_word(text: String) -> bool:
	var lower := text.to_lower()
	for word in _BLOCKED_SUBSTRINGS:
		if lower.contains(word):
			return true
	return false
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_text_filter.gd -gexit`
Expected: PASS, all 9 tests green.

- [ ] **Step 5: Commit**

```bash
git add core/text_filter.gd tests/unit/test_text_filter.gd
git commit -m "P-shadow-nicknames step 1: TextFilter (§6c length + profanity check)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 2: `HunterState` — nickname field + mutator

**Files:**
- Modify: `core/hunter_state.gd:124-136` (`claim_shadow()`), add a new method after `set_shadow_favorite()` (currently `core/hunter_state.gd:154-159`)
- Modify: `tests/unit/test_hunter_state.gd`

**Interfaces:**
- Consumes: `TextFilter.is_valid_nickname(text: String) -> bool`, `TextFilter.sanitize_nickname(text: String) -> String` (Task 1).
- Produces: every army-entry dict now carries `"nickname": String` (default `""`); `HunterState.set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool`, used by Task 4 (scenes/main.gd) and Task 6 (shadow_gear_view.gd).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_hunter_state.gd` (near the existing `claim_shadow`/lock/favorite tests, e.g. right after `test_claim_shadow_starts_with_no_gear` around line 160):

```gdscript
func test_claim_shadow_starts_with_no_nickname() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_eq(shadow["nickname"], "")


func test_set_shadow_nickname_sets_it() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.set_shadow_nickname(shadow["instance_id"], "Duskfang")
	assert_true(ok)
	assert_eq(s.army[0]["nickname"], "Duskfang")


func test_set_shadow_nickname_trims_whitespace() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(shadow["instance_id"], "  Duskfang  ")
	assert_eq(s.army[0]["nickname"], "Duskfang")


func test_set_shadow_nickname_can_clear_it_back_to_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(shadow["instance_id"], "Duskfang")
	var ok := s.set_shadow_nickname(shadow["instance_id"], "")
	assert_true(ok)
	assert_eq(s.army[0]["nickname"], "")


func test_set_shadow_nickname_rejects_too_long() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var too_long := "a".repeat(TextFilter.MAX_LENGTH + 1)
	var ok := s.set_shadow_nickname(shadow["instance_id"], too_long)
	assert_false(ok)
	assert_eq(s.army[0]["nickname"], "")  # unchanged


func test_set_shadow_nickname_rejects_blocked_word() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.set_shadow_nickname(shadow["instance_id"], "fuck")
	assert_false(ok)
	assert_eq(s.army[0]["nickname"], "")


func test_set_shadow_nickname_unknown_shadow_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.set_shadow_nickname("does_not_exist", "Duskfang"))


func test_set_shadow_nickname_is_per_instance_not_per_species() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	var b := s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(a["instance_id"], "Duskfang")
	assert_eq(s.army[0]["nickname"], "Duskfang")
	assert_eq(s.army[1]["nickname"], "")  # same species, different instance -- untouched
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: FAIL — `nickname` key missing on the claimed dict, `set_shadow_nickname` not defined.

- [ ] **Step 3: Write the minimal implementation**

In `core/hunter_state.gd`, change `claim_shadow()`:

```gdscript
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
```

Add a new method right after `set_shadow_favorite()`:

```gdscript
## §6c: sets a per-instance custom nickname, shown in place of the species
## name across the army list/squad picker/battle screen (SquadBuilder.
## enrich_army resolves nickname -> display_name). An empty string clears
## it back to the default species name -- always allowed, same "skip is
## always valid" rule TextFilter.is_valid_nickname itself encodes. False
## (no-op) if the shadow's unknown or the text fails TextFilter (too long /
## blocked word).
func set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool:
	var idx := _army_index(shadow_instance_id)
	if idx < 0:
		return false
	if not TextFilter.is_valid_nickname(nickname):
		return false
	army[idx]["nickname"] = TextFilter.sanitize_nickname(nickname)
	return true
```

No `to_dict()`/`from_dict()` change needed — `army` is stored/restored as a whole `Array` already (`core/hunter_state.gd:663`/`688`), so `nickname` rides along automatically; old saves missing the key just read as `""` via `.get("nickname", "")` wherever it's consumed (Task 3).

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: PASS, including all pre-existing `test_hunter_state.gd` tests (regression check).

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd tests/unit/test_hunter_state.gd
git commit -m "P-shadow-nicknames step 2: HunterState.set_shadow_nickname (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 3: `SquadBuilder.enrich_army()` — resolve `display_name`

**Files:**
- Modify: `core/squad_builder.gd:17-63` (`enrich_army()`)
- Modify: `tests/unit/test_squad_builder.gd`

**Interfaces:**
- Consumes: army-entry `nickname` field (Task 2).
- Produces: every enriched dict gains `"nickname": String` and `"display_name": String` (nickname if non-empty, else `monster_name`) — consumed by Task 4 (`main.gd`) and Task 5 (`squad_view.gd`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_squad_builder.gd`, near `test_enrich_army_includes_grade_name` (around line 152):

```gdscript
func test_enrich_army_display_name_falls_back_to_monster_name_with_no_nickname() -> void:
	var shadow := _shadow("mon_ashen_warden")
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_eq(enriched[0]["nickname"], "")
	assert_eq(enriched[0]["display_name"], "Ashen Warden")


func test_enrich_army_display_name_uses_nickname_when_set() -> void:
	var shadow := _shadow("mon_ashen_warden")
	shadow["nickname"] = "Duskfang"
	var enriched := SquadBuilder.enrich_army([shadow], monsters, 10)
	assert_eq(enriched[0]["nickname"], "Duskfang")
	assert_eq(enriched[0]["display_name"], "Duskfang")
	assert_eq(enriched[0]["monster_name"], "Ashen Warden")  # species name still available separately
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_squad_builder.gd -gexit`
Expected: FAIL — `enriched[0]` has no `"nickname"`/`"display_name"` key.

- [ ] **Step 3: Write the minimal implementation**

In `core/squad_builder.gd`, inside `enrich_army()`'s loop, extend the appended dict:

```gdscript
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
					"base_power": monster.get("base_power", 0),
					"power": power,
					"locked": shadow.get("locked", false),
					"favorite": shadow.get("favorite", false),
				}
			)
		)
	return enriched
```

(Only the two new lines building `nickname`/`monster_name` locals and the two new dict keys are additions — everything else in the function body is unchanged, shown in full so the diff context is unambiguous.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_squad_builder.gd -gexit`
Expected: PASS, including all pre-existing `test_squad_builder.gd` tests.

- [ ] **Step 5: Commit**

```bash
git add core/squad_builder.gd tests/unit/test_squad_builder.gd
git commit -m "P-shadow-nicknames step 3: enrich_army resolves display_name (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 4: Army label + battle party show the nickname

**Files:**
- Modify: `scenes/main.gd:374` (`_build_battle_party()`), `scenes/main.gd:700` (`_refresh_army_label()`)

**Interfaces:**
- Consumes: `member["display_name"]` / `e["display_name"]` from `SquadBuilder.enrich_army()`/`resolve_party()` (Task 3 — `resolve_party()` is built from `enrich_army()`'s output, so it already carries the new field with no changes needed there).

- [ ] **Step 1: Edit `_build_battle_party()`**

In `scenes/main.gd`, inside the `for member: Dictionary in chosen:` loop (around line 364-377), change the `Battle.make_ally_combatant(...)` call's name argument:

```gdscript
	for member: Dictionary in chosen:
		var shadow_stats := GameLogic.shadow_combat_stats(
			int(member["base_power"]), int(member["level"]), String(member["clazz"])
		)
		party.append(
			Battle.make_ally_combatant(
				member["instance_id"],
				member["clazz"],
				member["level"],
				shadow_stats,
				member["display_name"],
				synergy_bonus
			)
		)
	return party
```

(Only `member["monster_name"]` → `member["display_name"]` changes on that one line.)

- [ ] **Step 2: Edit `_refresh_army_label()`**

In `scenes/main.gd`, inside the `for e: Dictionary in enriched:` loop (around line 688-711), change the format args:

```gdscript
	for e: Dictionary in enriched:
		var marker := " [S]" if squad_ids.has(e["instance_id"]) else ""
		if e["locked"]:
			marker += " [L]"
		if e["favorite"]:
			marker += " [F]"
		(
			lines
			. append(
				(
					" - %s (%s·%s Lv%d/%d %s) pwr:%d%s"
					% [
						e["display_name"],
						e["grade_name"],
						e["grade"],
						e["level"],
						ShadowLeveling.LEVEL_CAP,
						e["clazz"],
						e["power"],
						marker,
					]
				)
			)
		)
	army_label.text = "\n".join(lines)
```

(Only `e["monster_name"]` → `e["display_name"]` changes.) The `(species·grade)` parenthetical already stays right after the name — that's the "secondary text underneath" for this single-line HUD label; a nicknamed shadow reads as `Duskfang (General·B Lv7/10 WARRIOR) pwr:412`.

- [ ] **Step 3: Manual verification**

Run the project (Godot editor, F5, or the `run` skill) with an existing save that has at least one army shadow. Open Shadow Gear once Task 6 lands to set a nickname, or temporarily call `state.set_shadow_nickname(state.army[0]["instance_id"], "TestName")` from a debug breakpoint/print — confirm:
- The home screen's Army list shows `TestName (...)` instead of the species name for that entry.
- Entering a gate battle with that shadow fielded shows `TestName` on its battle-screen HP slot.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.gd
git commit -m "P-shadow-nicknames step 4: army label + battle party show nickname (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 5: Squad picker shows the nickname

**Files:**
- Modify: `scenes/squad_view.gd:77-86` (`refresh()`)

**Interfaces:**
- Consumes: `member["display_name"]` (Task 3).

- [ ] **Step 1: Edit `refresh()`**

In `scenes/squad_view.gd`:

```gdscript
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if i < squad.size():
			var member: Dictionary = squad[i]
			row["instance_id"] = member["instance_id"]
			var fielded := active_party_ids.has(member["instance_id"])
			row["label"].text = (
				"%s (%s·%s Lv%d) pwr:%d"
				% [
					member["display_name"],
					member["grade_name"],
					member["grade"],
					member["level"],
					member["power"],
				]
			)
			row["toggle_btn"].text = "Fielded [x]" if fielded else "Field"
			row["toggle_btn"].disabled = false
		else:
			row["instance_id"] = ""
			row["label"].text = "-- empty squad slot --"
			row["toggle_btn"].text = "Field"
			row["toggle_btn"].disabled = true

	var chosen_names: Array = resolved_party.map(
		func(m: Dictionary) -> String: return String(m["display_name"])
	)
```

(Two changes: `member["monster_name"]` → `member["display_name"]` in the row label, and `m["monster_name"]` → `m["display_name"]` in the `chosen_names` map at the bottom of the function.)

- [ ] **Step 2: Manual verification**

Open the Squad panel with a nicknamed shadow in the squad-of-6 — confirm its row shows the nickname, and the "fielded" summary line at the bottom also uses it.

- [ ] **Step 3: Commit**

```bash
git add scenes/squad_view.gd
git commit -m "P-shadow-nicknames step 5: squad picker shows nickname (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 6: Rename control in Shadow Gear panel

**Files:**
- Modify: `scenes/main.tscn` (add nodes under `GameUI/ShadowGearPanel`, nudge `SetsLabel` down)
- Modify: `scenes/shadow_gear_view.gd`

**Interfaces:**
- Consumes: `HunterState.set_shadow_nickname()` (Task 2).

- [ ] **Step 1: Add nodes to `scenes/main.tscn`**

In `scenes/main.tscn`, insert a `RenameButton` right after the existing `FavoriteButton` block (currently ends at line 342, just before the `Rows` node at line 344):

```
[node name="RenameButton" type="Button" parent="GameUI/ShadowGearPanel"]
offset_left = 1870.0
offset_top = 90.0
offset_right = 2070.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 20
text = "Rename"

[node name="RenameInput" type="LineEdit" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 40.0
offset_top = 150.0
offset_right = 500.0
offset_bottom = 190.0
placeholder_text = "Nickname (optional)"

[node name="RenameSaveButton" type="Button" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 520.0
offset_top = 150.0
offset_right = 680.0
offset_bottom = 190.0
theme_override_font_sizes/font_size = 18
text = "Save"

[node name="RenameCancelButton" type="Button" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 700.0
offset_top = 150.0
offset_right = 860.0
offset_bottom = 190.0
theme_override_font_sizes/font_size = 18
text = "Cancel"
```

Then change the existing `SetsLabel` node (currently `offset_top = 560.0`) to `offset_top = 610.0`, to leave headroom under the taller gear-row grid from Step 2 below:

```
[node name="SetsLabel" type="Label" parent="GameUI/ShadowGearPanel"]
offset_left = 40.0
offset_top = 610.0
offset_right = 2380.0
offset_bottom = 900.0
theme_override_font_sizes/font_size = 18
text = "Active sets: (none)"
```

- [ ] **Step 2: Push the gear-row grid down in `scenes/shadow_gear_view.gd`**

In `_ready()`, change the `y_start` argument so the 7 gear rows start below the new rename row instead of overlapping it:

```gdscript
	_rows = GearPanelHelpers.build_gear_rows($Rows, 230.0)
```

(was `180.0`; `HunterGearView`'s own call is untouched, this only affects `ShadowGearView`.)

- [ ] **Step 3: Wire the Rename control**

In `scenes/shadow_gear_view.gd`, add `@onready` vars alongside the existing ones:

```gdscript
@onready var rename_button: Button = $RenameButton
@onready var rename_input: LineEdit = $RenameInput
@onready var rename_save_button: Button = $RenameSaveButton
@onready var rename_cancel_button: Button = $RenameCancelButton
```

In `_ready()`, alongside the existing `.pressed.connect(...)` calls:

```gdscript
	rename_button.pressed.connect(_on_rename_pressed)
	rename_save_button.pressed.connect(_on_rename_save_pressed)
	rename_cancel_button.pressed.connect(_on_rename_cancel_pressed)
```

New handler functions, placed after `_on_favorite_pressed()`:

```gdscript
## Opens the rename input, pre-filled with the current nickname (empty if
## none set yet) -- toggled visible rather than a separate panel, same
## "small overlay, not a new screen" weight as everything else in this
## project's placeholder UI.
func _on_rename_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	var idx := _shadow_index(shadow_id)
	if idx < 0:
		return
	rename_input.text = String(_state.army[idx].get("nickname", ""))
	rename_input.visible = true
	rename_save_button.visible = true
	rename_cancel_button.visible = true


## No error UI on an invalid name (too long/blocked word) -- same
## placeholder-simplicity as the rest of this panel's actions; the input
## just stays open with the rejected text still in it so the player can
## edit and retry.
func _on_rename_save_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	if _state.set_shadow_nickname(shadow_id, rename_input.text):
		_close_rename_input()
		_after_mutation()


func _on_rename_cancel_pressed() -> void:
	_close_rename_input()


func _close_rename_input() -> void:
	rename_input.visible = false
	rename_save_button.visible = false
	rename_cancel_button.visible = false
```

- [ ] **Step 4: Show the nickname (primary) + species/grade (secondary line) in `refresh()`**

In `scenes/shadow_gear_view.gd`'s `refresh()`, replace the `title_label.text` assignment:

```gdscript
	_index = clampi(_index, 0, _state.army.size() - 1)
	var shadow: Dictionary = _state.army[_index]
	var monster := Content.monster_by_id(_monsters, shadow.get("monster_id", ""))
	var locked: bool = shadow.get("locked", false)
	var favorite: bool = shadow.get("favorite", false)
	var nickname: String = shadow.get("nickname", "")
	var species_name: String = monster.get("name", "?")
	title_label.text = (
		"%s%s%s  [%d/%d]\n%s (%s·%s Lv%d/%d %s)"
		% [
			"★" if favorite else "",
			"🔒" if locked else "",
			nickname if nickname != "" else species_name,
			_index + 1,
			_state.army.size(),
			species_name,
			GameLogic.grade_name(shadow.get("grade", "")),
			shadow.get("grade", ""),
			shadow.get("level", 1),
			ShadowLeveling.LEVEL_CAP,
			monster.get("clazz", "?"),
		]
	)
```

(When there's no nickname, line 1 just repeats the species name and line 2 repeats it again with grade/level/class — slightly redundant but matches the spec's literal "species+grade as secondary text underneath" for both the nicknamed and un-nicknamed case, and costs nothing extra to build.)

Also update `refresh()`'s empty-army early-return branch to keep the rename controls hidden:

```gdscript
	if _state.army.is_empty():
		title_label.text = "No shadows yet"
		for row: Dictionary in _rows:
			row["label"].text = "%s: --" % row["slot"]
		sets_label.text = "Active sets: (none)"
		_close_rename_input()
		return
```

- [ ] **Step 5: Manual verification**

Open Shadow Gear on an owned shadow. Click Rename, type a name over 20 characters, click Save — confirm the title doesn't change (rejected, input stays open with the text). Clear it, type a valid name, Save — confirm the title's first line updates and the second line still shows species/grade/level/class. Click Prev/Next — confirm the next shadow's title reflects its own (separate) nickname state. Reopen the panel later (or reload the save) — confirm the nickname persisted.

- [ ] **Step 6: Commit**

```bash
git add scenes/main.tscn scenes/shadow_gear_view.gd
git commit -m "P-shadow-nicknames step 6: Rename control in Shadow Gear panel (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

### Task 7: Optional nickname prompt right after a real CLAIM

**Files:**
- Modify: `scenes/main.tscn` (new `ClaimNicknamePanel` under `GameUI`)
- Modify: `scenes/main.gd`

**Interfaces:**
- Consumes: `HunterState.set_shadow_nickname()` (Task 2), `TextFilter.MAX_LENGTH` (Task 1).

- [ ] **Step 1: Add `ClaimNicknamePanel` to `scenes/main.tscn`**

Insert this new top-level `GameUI` panel right after `GateBreakPanel`'s `DismissButton` block (currently ends at line 814, just before the `BattlePanel` node at line 815) — same flat "no separate controller script" pattern `GateBreakPanel` itself uses:

```
[node name="ClaimNicknamePanel" type="Node2D" parent="GameUI"]
visible = false

[node name="Bg" type="ColorRect" parent="GameUI/ClaimNicknamePanel"]
offset_left = 0.0
offset_top = 0.0
offset_right = 2424.0
offset_bottom = 1080.0
color = Color(0.02, 0.05, 0.08, 0.95)

[node name="InfoLabel" type="Label" parent="GameUI/ClaimNicknamePanel"]
offset_left = 40.0
offset_top = 300.0
offset_right = 2000.0
offset_bottom = 400.0
theme_override_font_sizes/font_size = 28
text = "Give it a nickname?"

[node name="NicknameInput" type="LineEdit" parent="GameUI/ClaimNicknamePanel"]
offset_left = 40.0
offset_top = 420.0
offset_right = 700.0
offset_bottom = 470.0
placeholder_text = "Nickname (optional)"

[node name="SaveButton" type="Button" parent="GameUI/ClaimNicknamePanel"]
offset_left = 40.0
offset_top = 500.0
offset_right = 300.0
offset_bottom = 560.0
theme_override_font_sizes/font_size = 22
text = "Save"

[node name="SkipButton" type="Button" parent="GameUI/ClaimNicknamePanel"]
offset_left = 320.0
offset_top = 500.0
offset_right = 580.0
offset_bottom = 560.0
theme_override_font_sizes/font_size = 22
text = "Skip"
```

- [ ] **Step 2: Wire it in `scenes/main.gd`**

Add `@onready` vars alongside the existing `gate_break_*` ones (near line 68-72):

```gdscript
@onready var claim_nickname_panel: Node2D = $GameUI/ClaimNicknamePanel
@onready var claim_nickname_info_label: Label = $GameUI/ClaimNicknamePanel/InfoLabel
@onready var claim_nickname_input: LineEdit = $GameUI/ClaimNicknamePanel/NicknameInput
@onready var claim_nickname_save_button: Button = $GameUI/ClaimNicknamePanel/SaveButton
@onready var claim_nickname_skip_button: Button = $GameUI/ClaimNicknamePanel/SkipButton
```

Add a new state var alongside the other `_pending_*` ones (near line 27-36):

```gdscript
var _pending_nickname_shadow_id: String = ""  ## §6c: shadow instance_id awaiting an optional
## post-CLAIM nickname, "" when ClaimNicknamePanel isn't showing.
```

In `_setup_gear_panels()`, inside the idempotency-guarded block, alongside the `gate_break_*` connections (near line 226-228):

```gdscript
		claim_nickname_save_button.pressed.connect(_on_claim_nickname_save_pressed)
		claim_nickname_skip_button.pressed.connect(_on_claim_nickname_skip_pressed)
```

New functions, placed after `_on_battle_finished()` (after line 498):

```gdscript
## §6c: shows the optional nickname prompt for a shadow just CLAIMed.
## Called only from the two "real" CLAIM sites (a gate win, a Nadir boss
## claim) -- NOT from onboarding's starter/guided-gate claims, which stay a
## fast, uninterrupted ~30-second flow per §25.
func _offer_claim_nickname(shadow_instance_id: String, species_name: String) -> void:
	_pending_nickname_shadow_id = shadow_instance_id
	claim_nickname_input.text = ""
	claim_nickname_info_label.text = (
		"CLAIMED %s! Give it a nickname? (optional, max %d characters)"
		% [species_name, TextFilter.MAX_LENGTH]
	)
	claim_nickname_panel.visible = true


## No error UI on an invalid name (too long/blocked word) -- same
## placeholder-simplicity as every other action panel; the prompt just
## stays open so the player can edit and retry, or press Skip instead.
func _on_claim_nickname_save_pressed() -> void:
	if _pending_nickname_shadow_id == "":
		return
	if state.set_shadow_nickname(_pending_nickname_shadow_id, claim_nickname_input.text):
		SaveService.save(state)
		_refresh_army_label()
		_close_claim_nickname_panel()


func _on_claim_nickname_skip_pressed() -> void:
	_close_claim_nickname_panel()


func _close_claim_nickname_panel() -> void:
	_pending_nickname_shadow_id = ""
	claim_nickname_panel.visible = false
```

- [ ] **Step 3: Call it from the gate-win CLAIM**

In `_on_battle_finished()` (around line 470-477), capture the claimed shadow and offer the prompt:

```gdscript
	if won:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GameLogic.attempt_claim(gate.get("monster_extract_chance", 0.0), state.level, rng):
			var claimed := state.claim_shadow(gate["monster_id"], gate["rank"])
			msg += "\nCLAIMED! %s joins your army." % gate["monster_name"]
			_offer_claim_nickname(claimed["instance_id"], gate["monster_name"])
		else:
			msg += "\nBoss escaped (claim failed)."
```

(Only the added `var claimed :=` capture and the `_offer_claim_nickname(...)` call are new; `state.claim_shadow(...)` itself is unchanged, just assigned instead of a bare call.)

- [ ] **Step 4: Call it from the Nadir boss CLAIM**

In `_apply_nadir_battle_result()` (around line 864-870):

```gdscript
		if is_boss and boss_id != "":
			var boss_monster := Content.monster_by_id(_monsters, boss_id)
			if GameLogic.attempt_claim(boss_monster.get("extract_chance", 0.0), state.level, rng):
				var claimed := state.claim_shadow(boss_id, Nadir.rank_for_floor(floor_n))
				msg += "\nBOSS CLAIMED! %s joins your army." % boss_monster.get("name", "")
				_offer_claim_nickname(claimed["instance_id"], boss_monster.get("name", ""))
			else:
				msg += "\nBoss floor -- boss escaped (claim failed)."
```

- [ ] **Step 5: Manual verification**

Clear a normal gate with a successful CLAIM — confirm the nickname panel appears right after (the battle panel has already hidden itself, per `battle_view.gd`'s `visible = false` before it emits `battle_finished`, so there's no overlap). Type a name, Save — confirm it lands (check Shadow Gear or the army label). Repeat and press Skip instead — confirm the shadow keeps its default species name and nothing errors. Confirm the onboarding starter/first-gate claims do NOT show this prompt (per the Task's flagged design assumption).

- [ ] **Step 6: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "P-shadow-nicknames step 7: optional post-CLAIM nickname prompt (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MmQrR71j1qR252fNpAWHFq"
```

---

## Self-Review

**Spec coverage:**
- "Optional — skipping keeps the default species name" → Task 1 (`is_valid_nickname("")` true), Task 2 (`set_shadow_nickname` with `""` clears it), Task 7 (Skip button).
- "Per-instance, not per-species" → Task 2's `test_set_shadow_nickname_is_per_instance_not_per_species`.
- "Editable later from the Army screen" → Task 6 (Shadow Gear's Rename control).
- "Shows in place of species name in Army screen/squad picker/battle screen, with species+grade as secondary text underneath" → Task 3 (`display_name`) feeding Task 4 (army label + battle), Task 5 (squad picker), Task 6 (Shadow Gear title, explicit two-line layout).
- "Character limit (~16-20) and a profanity filter — reuse the hunter-name filter if one already exists" → Task 1; flagged in Global Constraints that no such filter existed to reuse, this is the first one.
- "Private for v0" lean → flagged in Global Constraints; no task touches `BackendService`/leaderboard sync, so there's nothing to build to keep it out.

**Placeholder scan:** no "TBD"/"handle appropriately"/bare references — every step has real code or an exact manual-test procedure.

**Type consistency:** `nickname`/`display_name` are `String` everywhere they appear (Task 2's army dict, Task 3's enriched dict, Task 4/5/6/7's consumers) — no mismatched names (`display_name` is never called `displayName` or `shown_name` anywhere).
