# Custom Shadow Nicknames (§6c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player give any owned shadow an optional, editable, per-instance nickname that replaces its species name everywhere it's listed.

**Architecture:** One new pure `core/` module (`TextFilter`, length + v0 profanity check). `HunterState` gains a `nickname` field per army entry + a `set_shadow_nickname()` mutator. `SquadBuilder.enrich_army()` is the single chokepoint that resolves `nickname` → `display_name`; the four display surfaces already read enriched dicts, so they only swap one key. Two scene entry points to set it: a **Rename** control in the Shadow Gear panel, and an optional prompt shown after a real CLAIM once the battle-result `SystemPanel` is dismissed.

**Tech Stack:** Godot 4.7 / GDScript. GUT for `core/` (TDD). `gdformat` + `gdlint` + the full GUT suite run automatically via the post-edit hook (`.claude/settings.json`) on every `.gd` save.

## Global Constraints

- Static typing everywhere: `var x: int = 0`, `func f(a: int) -> void:`. Per `CLAUDE.md`.
- Tabs for indentation; `snake_case` functions/vars/files; `PascalCase` classes/nodes; `SCREAMING_SNAKE_CASE` consts. One class per file; filename matches the class. Per `CLAUDE.md`.
- `core/` is pure — no `Node`, no scene tree, no engine calls — and unit-tested in `tests/unit/` (`core/x.gd` → `tests/unit/test_x.gd`). `scenes/` is thin view code with **no game rules and no GUT coverage** — verified manually. Per `CLAUDE.md`.
- The post-edit hook reformats + lints every saved `.gd` and runs the whole GUT suite. Don't hand-fix whitespace the formatter reflows; a red hook is a blocker.
- **GUT suite count** must move **only** by the number of new test functions a task adds in `core/`. A scene-only task must leave the count unchanged. (Baseline entering this plan: 511.)
- Viewport is a fixed `1080 x 2424` (`project.godot`); hardcoded-pixel layout is the house style in `main.tscn`.
- `MAX_LENGTH` for a nickname is **20** — an invented v0 number (spec said "~16–20"), flagged in the class doc comment like `ShadowLeveling`'s other invented constants.
- Empty/whitespace-only nickname is **always valid** — it means "use the species name", never a rejected value.
- Nickname **replaces** the species name once set (user decision) — species is not shown alongside it anywhere.
- Commit messages end with the `Co-Authored-By:` and `Claude-Session:` trailers, matching existing history.
- Manual GUT run (outside the hook): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: `TextFilter` — pure nickname validation

**Files:**
- Create: `core/text_filter.gd`
- Create: `tests/unit/test_text_filter.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `TextFilter.MAX_LENGTH: int`, `TextFilter.is_valid_nickname(text: String) -> bool`, `TextFilter.sanitize_nickname(text: String) -> String` — all `static`. Consumed by Task 2 and Task 6.

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
	assert_true(TextFilter.is_valid_nickname("a".repeat(TextFilter.MAX_LENGTH)))


func test_name_over_max_length_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("a".repeat(TextFilter.MAX_LENGTH + 1)))


func test_blocked_word_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("fuck"))


func test_blocked_word_is_invalid_case_insensitive() -> void:
	assert_false(TextFilter.is_valid_nickname("FuCk"))


func test_blocked_word_as_substring_is_invalid() -> void:
	assert_false(TextFilter.is_valid_nickname("xfuckx"))


func test_leading_trailing_whitespace_does_not_count_toward_length() -> void:
	assert_true(TextFilter.is_valid_nickname("  " + "a".repeat(TextFilter.MAX_LENGTH) + "  "))


func test_sanitize_trims_leading_and_trailing_whitespace() -> void:
	assert_eq(TextFilter.sanitize_nickname("  Duskfang  "), "Duskfang")
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_text_filter.gd -gexit`
Expected: FAIL — `Could not find type "TextFilter"`.

- [ ] **Step 3: Write the implementation**

```gdscript
# core/text_filter.gd
class_name TextFilter
## Pure text-input validation for anywhere the player types a short custom
## name -- currently just shadow nicknames (§6c). Factored out on its own,
## not folded into HunterState, so a future hunter/display-name input can
## reuse MAX_LENGTH / the blocklist instead of duplicating one.
##
## The blocklist is a hardcoded v0 list, not a real profanity-detection
## library -- it won't catch l33tspeak / spacing evasion. Flagged as a real
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
## MAX_LENGTH (after trimming) and contain no blocked word.
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

- [ ] **Step 4: Run tests, verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_text_filter.gd -gexit`
Expected: PASS, 10/10.

- [ ] **Step 5: Commit**

```bash
git add core/text_filter.gd tests/unit/test_text_filter.gd
git commit -m "feat: TextFilter — pure nickname length + profanity validation (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 2: `HunterState` — `nickname` field + `set_shadow_nickname()`

**Files:**
- Modify: `core/hunter_state.gd` — `claim_shadow()` (~`:162-176`); add a method right after `set_shadow_favorite()` (`:192-198`).
- Modify: `tests/unit/test_hunter_state.gd`

**Interfaces:**
- Consumes: `TextFilter.is_valid_nickname()`, `TextFilter.sanitize_nickname()` (Task 1).
- Produces: every army-entry dict carries `"nickname": String` (default `""`); `HunterState.set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool`. Consumed by Task 5 (`shadow_gear_view.gd`) and Task 6 (`main.gd`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_hunter_state.gd`, near the existing lock/favorite tests:

```gdscript
func test_claim_shadow_starts_with_no_nickname() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_eq(shadow["nickname"], "")


func test_set_shadow_nickname_sets_it() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_true(s.set_shadow_nickname(shadow["instance_id"], "Duskfang"))
	assert_eq(s.army[0]["nickname"], "Duskfang")


func test_set_shadow_nickname_trims_whitespace() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(shadow["instance_id"], "  Duskfang  ")
	assert_eq(s.army[0]["nickname"], "Duskfang")


func test_set_shadow_nickname_can_clear_back_to_empty() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(shadow["instance_id"], "Duskfang")
	assert_true(s.set_shadow_nickname(shadow["instance_id"], ""))
	assert_eq(s.army[0]["nickname"], "")


func test_set_shadow_nickname_rejects_too_long() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	var ok := s.set_shadow_nickname(shadow["instance_id"], "a".repeat(TextFilter.MAX_LENGTH + 1))
	assert_false(ok)
	assert_eq(s.army[0]["nickname"], "")


func test_set_shadow_nickname_rejects_blocked_word() -> void:
	var s := HunterState.new_default("WARRIOR")
	var shadow := s.claim_shadow("mon_ashen_warden", "C")
	assert_false(s.set_shadow_nickname(shadow["instance_id"], "fuck"))
	assert_eq(s.army[0]["nickname"], "")


func test_set_shadow_nickname_unknown_shadow_is_a_noop() -> void:
	var s := HunterState.new_default("WARRIOR")
	assert_false(s.set_shadow_nickname("does_not_exist", "Duskfang"))


func test_set_shadow_nickname_is_per_instance_not_per_species() -> void:
	var s := HunterState.new_default("WARRIOR")
	var a := s.claim_shadow("mon_ashen_warden", "C")
	s.claim_shadow("mon_ashen_warden", "C")
	s.set_shadow_nickname(a["instance_id"], "Duskfang")
	assert_eq(s.army[0]["nickname"], "Duskfang")
	assert_eq(s.army[1]["nickname"], "")
```

> If `mon_ashen_warden` / `"C"` don't match the fixtures the neighboring
> `claim_shadow` tests in this file use, copy their exact monster id and
> grade instead — the nickname assertions are what matters, not the ids.

- [ ] **Step 2: Run tests, verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: FAIL — `nickname` key missing on the claimed dict; `set_shadow_nickname` not defined.

- [ ] **Step 3: Implement**

In `claim_shadow()`, add `nickname` to the shadow dict (keep the existing keys and their order; add this last before `army.append`):

```gdscript
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
```

Add a new method directly after `set_shadow_favorite()`:

```gdscript
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
```

No `to_dict()` / `from_dict()` change — `army` is stored/restored as a whole `Array`, so `nickname` rides along; old saves missing the key read as `""` wherever it's consumed via `.get("nickname", "")`.

- [ ] **Step 4: Run tests, verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_hunter_state.gd -gexit`
Expected: PASS, including every pre-existing `test_hunter_state.gd` test (regression check).

- [ ] **Step 5: Commit**

```bash
git add core/hunter_state.gd tests/unit/test_hunter_state.gd
git commit -m "feat: HunterState.set_shadow_nickname + per-shadow nickname field (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 3: `SquadBuilder.enrich_army()` — resolve `display_name`

**Files:**
- Modify: `core/squad_builder.gd` — `enrich_army()` (`:17-63`), inside the `for shadow` loop's appended dict.
- Modify: `tests/unit/test_squad_builder.gd`

**Interfaces:**
- Consumes: army-entry `nickname` field (Task 2).
- Produces: every enriched dict gains `"nickname": String` and `"display_name": String` (`nickname` if non-empty, else `monster_name`). `monster_name` key stays. Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_squad_builder.gd`, near `test_enrich_army_includes_grade_name` (or the closest existing `enrich_army` test):

```gdscript
func test_enrich_army_display_name_falls_back_to_monster_name() -> void:
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
	assert_eq(enriched[0]["monster_name"], "Ashen Warden")
```

> Use whatever helper this file already has for building a shadow dict and
> whatever monster id/name its other `enrich_army` tests use — `_shadow(...)`
> and `mon_ashen_warden` / `"Ashen Warden"` here are placeholders for the
> file's real fixtures. Match them.

- [ ] **Step 2: Run tests, verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_squad_builder.gd -gexit`
Expected: FAIL — enriched dict has no `"nickname"` / `"display_name"` key.

- [ ] **Step 3: Implement**

In `core/squad_builder.gd`, inside `enrich_army()`'s `for shadow: Dictionary in army:` loop, just before the `enriched.append({...})` call, add two locals:

```gdscript
		var nickname: String = shadow.get("nickname", "")
		var monster_name: String = monster.get("name", "")
```

Then in the appended dict, change the `"monster_name"` line and add two keys next to it:

```gdscript
					"monster_name": monster_name,
					"nickname": nickname,
					"display_name": nickname if nickname != "" else monster_name,
```

Everything else in the dict and the function is unchanged.

- [ ] **Step 4: Run tests, verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_squad_builder.gd -gexit`
Expected: PASS, including every pre-existing `test_squad_builder.gd` test.

- [ ] **Step 5: Commit**

```bash
git add core/squad_builder.gd tests/unit/test_squad_builder.gd
git commit -m "feat: enrich_army resolves nickname -> display_name (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 4: Display surfaces read `display_name`

**Files:**
- Modify: `scenes/army_view.gd` (`_refresh_roster()`, the roster row `.text` — currently `:163`)
- Modify: `scenes/squad_view.gd` (`refresh()` — the row label `:82`, and the `chosen_names` map `:98`)
- Modify: `scenes/main.gd` (`_build_battle_party()` — the `make_ally_combatant` name arg `:476`)

**Interfaces:**
- Consumes: `display_name` on the enriched / resolved-party dicts (Task 3). `resolve_party()` is built from `enrich_army()` output, so it already carries the key — no change there.
- Produces: nothing for later tasks.

This task is `scenes/`-only: no GUT test, verified manually. GUT count must not change.

- [ ] **Step 1: `scenes/army_view.gd` roster row**

In `_refresh_roster()`, the `row.text = (...)` format args currently start with `e["monster_name"]`. Change that one token to `e["display_name"]`. Nothing else on the line changes (`e["grade_name"], e["grade"], e["level"], e["power"], marker` stay).

- [ ] **Step 2: `scenes/squad_view.gd` row label**

In `refresh()`, the `row["label"].text = (...)` format args currently start with `member["monster_name"]`. Change to `member["display_name"]`.

- [ ] **Step 3: `scenes/squad_view.gd` fielded-summary line**

In the same `refresh()`, the `chosen_names` map:

```gdscript
	var chosen_names: Array = resolved_party.map(
		func(m: Dictionary) -> String: return String(m["display_name"])
	)
```

(was `m["monster_name"]`).

- [ ] **Step 4: `scenes/main.gd` battle party**

In `_build_battle_party()`, the `Battle.make_ally_combatant(...)` call passes `member["monster_name"]` as the name argument. Change to `member["display_name"]`.

- [ ] **Step 5: Let the post-edit hook run; confirm green**

Each `.gd` save triggers `gdformat` + `gdlint` + the full GUT suite. Expected: format/lint clean, GUT count **unchanged** (no `core/` or test file touched). Red hook = fix before commit.

- [ ] **Step 6: Manual verification**

Run the project (Godot editor F5 / `run` skill) with a save that has ≥1 army shadow. Temporarily set a nickname (e.g. via a debug call `state.set_shadow_nickname(state.army[0]["instance_id"], "TestName")` from a breakpoint, or land Task 5 first and use the Rename control). Confirm:
- Army roster row shows `TestName (…)` instead of the species name.
- Squad picker row and the "fielded: …" summary line show `TestName`.
- Entering a gate battle with that shadow fielded shows `TestName` on its battle-screen HP slot.

- [ ] **Step 7: Commit**

```bash
git add scenes/army_view.gd scenes/squad_view.gd scenes/main.gd
git commit -m "feat: roster / squad picker / battle screen show shadow display_name (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 5: Rename control in the Shadow Gear panel

**Files:**
- Modify: `scenes/main.tscn` — add 4 nodes under `GameUI/ShadowGearPanel`.
- Modify: `scenes/shadow_gear_view.gd` — `@onready` refs, `_ready()` wiring, 3 handlers + `_close_rename()`, and the `refresh()` title line.

**Interfaces:**
- Consumes: `HunterState.set_shadow_nickname()` (Task 2); existing `_current_shadow_instance_id() -> String`, `_after_mutation()` (saves + `refresh()` + `state_changed.emit()`), `_state`, `_index`.
- Produces: nothing for later tasks.

`scenes/`-only: no GUT test, manual verification, GUT count unchanged.

- [ ] **Step 1: Add nodes to `scenes/main.tscn`**

Insert these 4 nodes under `GameUI/ShadowGearPanel`, placed in the file **after** `CloseButton` and before `Rows` (so the transient strip is a later sibling than the nav-button row it overlays and wins input when visible). `RenameButton` lives in the free space to the right of `CloseButton` (which ends at `offset_right = 800`); the input strip overlays the Prev/Next/AutoEquip/Close row (`offset_top = 90..140`) and is only visible while renaming:

```
[node name="RenameButton" type="Button" parent="GameUI/ShadowGearPanel"]
offset_left = 820.0
offset_top = 90.0
offset_right = 1040.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 20
text = "Rename"

[node name="RenameInput" type="LineEdit" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 40.0
offset_top = 90.0
offset_right = 700.0
offset_bottom = 140.0
placeholder_text = "Nickname (optional)"

[node name="RenameSaveButton" type="Button" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 720.0
offset_top = 90.0
offset_right = 860.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 18
text = "Save"

[node name="RenameCancelButton" type="Button" parent="GameUI/ShadowGearPanel"]
visible = false
offset_left = 880.0
offset_top = 90.0
offset_right = 1040.0
offset_bottom = 140.0
theme_override_font_sizes/font_size = 18
text = "Cancel"
```

- [ ] **Step 2: `@onready` refs + wiring in `scenes/shadow_gear_view.gd`**

Alongside the existing `@onready` block:

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

- [ ] **Step 3: Handlers**

Add after `_on_favorite_pressed()` (or the last `_on_*_pressed` handler):

```gdscript
## Opens the rename strip, pre-filled with the current nickname (empty if
## none). The strip overlays the nav-button row while visible -- Save /
## Cancel return you to it. No separate panel, same "small transient
## overlay" weight as this panel's other actions.
func _on_rename_pressed() -> void:
	if _state.army.is_empty():
		return
	rename_input.text = String(_state.army[_index].get("nickname", ""))
	rename_input.visible = true
	rename_save_button.visible = true
	rename_cancel_button.visible = true
	rename_input.grab_focus()


## No error UI on an invalid name (too long / blocked word) -- same
## placeholder-simplicity as the rest of this panel; the strip just stays
## open with the rejected text so the player can edit and retry.
func _on_rename_save_pressed() -> void:
	var shadow_id := _current_shadow_instance_id()
	if shadow_id == "":
		return
	if _state.set_shadow_nickname(shadow_id, rename_input.text):
		_close_rename()
		_after_mutation()


func _on_rename_cancel_pressed() -> void:
	_close_rename()


func _close_rename() -> void:
	rename_input.visible = false
	rename_save_button.visible = false
	rename_cancel_button.visible = false
```

- [ ] **Step 4: Title line + empty-army branch in `refresh()`**

In `refresh()`, the empty-army early-return branch — add `_close_rename()` before `return`.

Change the `title_label.text` assignment so a set nickname **replaces** the species name (the `(grade·grade Lv/cap class · family)` parenthetical and `[i/n]` counter are unchanged):

```gdscript
	var shadow: Dictionary = _state.army[_index]
	var monster := Content.monster_by_id(_monsters, shadow.get("monster_id", ""))
	var locked: bool = shadow.get("locked", false)
	var favorite: bool = shadow.get("favorite", false)
	var family: String = monster.get("family", "?")
	var nickname: String = shadow.get("nickname", "")
	var shown_name: String = nickname if nickname != "" else String(monster.get("name", "?"))
	title_label.text = (
		"%s%s%s (%s·%s Lv%d/%d %s · %s)  [%d/%d]"
		% [
			"★" if favorite else "",
			"🔒" if locked else "",
			shown_name,
			GameLogic.grade_name(shadow.get("grade", "")),
			shadow.get("grade", ""),
			shadow.get("level", 1),
			ShadowLeveling.LEVEL_CAP,
			monster.get("clazz", "?"),
			family,
			_index + 1,
			_state.army.size(),
		]
	)
```

(Only the two new locals and `monster.get("name", "?")` → `shown_name` change.)

- [ ] **Step 5: Let the post-edit hook run; confirm green**

Format/lint clean; GUT count unchanged (no `core/`/test change).

- [ ] **Step 6: Manual verification**

Run the project. Open Shadow Gear on an owned shadow:
- Tap **Rename** → the strip appears over the nav-button row, input empty (or pre-filled if already nicknamed), soft keyboard rises (on device).
- Type a name > 20 chars, tap **Save** → title unchanged, strip stays open with the text (rejected).
- Clear it, type a valid name, **Save** → title's first token becomes the nickname (species name gone), strip closes. The parenthetical grade/level/class/family is unchanged.
- **Prev** / **Next** → the next shadow's title reflects its own nickname (or species name).
- Set a nickname, close the panel, reload the save → the nickname persisted.
- **Cancel** on the strip → no change, strip closes.

- [ ] **Step 7: Commit**

```bash
git add scenes/main.tscn scenes/shadow_gear_view.gd
git commit -m "feat: Rename control in the Shadow Gear panel (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

### Task 6: Optional nickname prompt after a real CLAIM

**Files:**
- Modify: `scenes/main.tscn` — new `ClaimNicknamePanel` under `GameUI`, **as the last child**.
- Modify: `scenes/main.gd` — 2 state vars; capture the claimed shadow at both CLAIM sites; connect `system_panel.dismissed`; 3 handlers.

**Interfaces:**
- Consumes: `HunterState.set_shadow_nickname()` (Task 2), `TextFilter.MAX_LENGTH` (Task 1); existing `system_panel: SystemPanel` with `signal dismissed`, `SaveService.save()`, `army_view.refresh_if_open()`, `_refresh_label()`.
- Produces: nothing for later tasks.

`scenes/`-only: no GUT test, manual verification, GUT count unchanged.

- [ ] **Step 1: Add `ClaimNicknamePanel` to `scenes/main.tscn`**

Add this as the **last child of `GameUI`** (Godot resolves overlapping input by tree order, not `z_index` — an earlier sibling would take the tap; this is the same constraint that moved `SystemToast` in `d53c05f`). `Bg` keeps its default `mouse_filter` (STOP) so it blocks taps to the map — this panel is not tap-to-dismiss.

```
[node name="ClaimNicknamePanel" type="Node2D" parent="GameUI"]
visible = false

[node name="Bg" type="ColorRect" parent="GameUI/ClaimNicknamePanel"]
offset_right = 1080.0
offset_bottom = 2424.0
color = Color(0.02, 0.05, 0.08, 0.96)

[node name="InfoLabel" type="Label" parent="GameUI/ClaimNicknamePanel"]
offset_left = 80.0
offset_top = 900.0
offset_right = 1000.0
offset_bottom = 1040.0
theme_override_font_sizes/font_size = 28
autowrap_mode = 3
text = ""

[node name="NicknameInput" type="LineEdit" parent="GameUI/ClaimNicknamePanel"]
offset_left = 80.0
offset_top = 1070.0
offset_right = 1000.0
offset_bottom = 1130.0
placeholder_text = "Nickname (optional)"

[node name="SaveButton" type="Button" parent="GameUI/ClaimNicknamePanel"]
offset_left = 80.0
offset_top = 1160.0
offset_right = 340.0
offset_bottom = 1220.0
theme_override_font_sizes/font_size = 22
text = "Save"

[node name="SkipButton" type="Button" parent="GameUI/ClaimNicknamePanel"]
offset_left = 360.0
offset_top = 1160.0
offset_right = 620.0
offset_bottom = 1220.0
theme_override_font_sizes/font_size = 22
text = "Skip"
```

- [ ] **Step 2: State vars + `@onready` refs in `scenes/main.gd`**

Alongside the other `_pending_*` vars:

```gdscript
var _pending_nickname_shadow_id: String = ""  ## §6c: shadow instance_id awaiting an
## optional post-CLAIM nickname prompt; "" when nothing is pending.
var _pending_nickname_species: String = ""  ## species name for that prompt's label text.
```

Alongside the other `@onready` node refs:

```gdscript
@onready var claim_nickname_panel: Node2D = $GameUI/ClaimNicknamePanel
@onready var claim_nickname_info_label: Label = $GameUI/ClaimNicknamePanel/InfoLabel
@onready var claim_nickname_input: LineEdit = $GameUI/ClaimNicknamePanel/NicknameInput
@onready var claim_nickname_save_button: Button = $GameUI/ClaimNicknamePanel/SaveButton
@onready var claim_nickname_skip_button: Button = $GameUI/ClaimNicknamePanel/SkipButton
```

- [ ] **Step 3: Wire signals in `_setup_gear_panels()`**

Inside the idempotency-guarded block of `_setup_gear_panels()`, alongside the other `.connect(...)` calls:

```gdscript
		system_panel.dismissed.connect(_on_system_panel_dismissed)
		claim_nickname_save_button.pressed.connect(_on_claim_nickname_save_pressed)
		claim_nickname_skip_button.pressed.connect(_on_claim_nickname_skip_pressed)
```

- [ ] **Step 4: Capture the claimed shadow at both CLAIM sites**

In `_on_battle_finished()`, the successful-claim branch currently reads:

```gdscript
			state.claim_shadow(gate["monster_id"], gate["rank"])
			body += "\nCLAIMED! %s joins your army." % gate["monster_name"]
```

Change to:

```gdscript
			var claimed := state.claim_shadow(gate["monster_id"], gate["rank"])
			_pending_nickname_shadow_id = claimed["instance_id"]
			_pending_nickname_species = gate["monster_name"]
			body += "\nCLAIMED! %s joins your army." % gate["monster_name"]
```

In `_apply_nadir_battle_result()`, the boss-claim branch currently reads:

```gdscript
				state.claim_shadow(boss_id, Nadir.rank_for_floor(floor_n))
				body += "\nBOSS CLAIMED! %s joins your army." % boss_monster.get("name", "")
```

Change to:

```gdscript
				var claimed := state.claim_shadow(boss_id, Nadir.rank_for_floor(floor_n))
				_pending_nickname_shadow_id = claimed["instance_id"]
				_pending_nickname_species = String(boss_monster.get("name", ""))
				body += "\nBOSS CLAIMED! %s joins your army." % boss_monster.get("name", "")
```

- [ ] **Step 5: Handlers**

Add after `_on_battle_finished()` (or near the other panel handlers):

```gdscript
## §6c: fires on every SystemPanel dismissal (shared signal). Only a real
## gate / Nadir CLAIM arms _pending_nickname_shadow_id, so the guard makes
## this a no-op for level-ups, rewards, stronghold, rank trials, etc. The
## onboarding starter / scripted-first-gate claims never route through
## _on_battle_finished / _apply_nadir_battle_result, so they're excluded
## structurally -- no guard needed for §25's fast onboarding CLAIM.
func _on_system_panel_dismissed() -> void:
	if _pending_nickname_shadow_id == "":
		return
	claim_nickname_info_label.text = (
		"CLAIMED %s! Give it a nickname? (optional, max %d chars)"
		% [_pending_nickname_species, TextFilter.MAX_LENGTH]
	)
	claim_nickname_input.text = ""
	claim_nickname_panel.visible = true
	claim_nickname_input.grab_focus()


## No error UI on an invalid name -- the prompt stays open with the text so
## the player can edit and retry, or Skip.
func _on_claim_nickname_save_pressed() -> void:
	if _pending_nickname_shadow_id == "":
		return
	if state.set_shadow_nickname(_pending_nickname_shadow_id, claim_nickname_input.text):
		SaveService.save(state)
		army_view.refresh_if_open()
		_refresh_label()
		_close_claim_nickname_panel()


func _on_claim_nickname_skip_pressed() -> void:
	_close_claim_nickname_panel()


func _close_claim_nickname_panel() -> void:
	_pending_nickname_shadow_id = ""
	_pending_nickname_species = ""
	claim_nickname_panel.visible = false
```

- [ ] **Step 6: Let the post-edit hook run; confirm green**

Format/lint clean; GUT count unchanged (no `core/`/test change).

- [ ] **Step 7: Manual verification**

Run the project.
- Clear a normal gate with a successful CLAIM → the battle-result `SystemPanel` shows first ("VICTORY! … CLAIMED! X joins your army …"). Tap it away → the nickname prompt appears, full-screen, blocking the map. Soft keyboard rises (on device).
- Type a name, **Save** → check Shadow Gear / roster: the shadow shows the nickname.
- Repeat, press **Skip** → the shadow keeps its species name, nothing errors.
- Clear a gate **without** a CLAIM (claim roll fails, or a non-boss) → result panel dismisses with **no** nickname prompt.
- Nadir boss floor with a successful boss CLAIM → same chained prompt after the FLOOR CLEARED panel.
- Trigger a level-up (result panel says "LEVEL UP!") with no claim → dismissing it shows **no** prompt.
- Start a brand-new save → the onboarding scripted first gate does **not** show the prompt.

- [ ] **Step 8: Commit**

```bash
git add scenes/main.tscn scenes/main.gd
git commit -m "feat: optional post-CLAIM nickname prompt, chained after the result panel (§6c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011ZyXxpF6DuowwNkHmsaD2W"
```

---

## Post-plan checklist (controller, after all tasks)

- [ ] Full GUT suite green; count increased by exactly the new `core/` test functions (Task 1: 10, Task 2: 8, Task 3: 2 → +20 over the 511 baseline), nothing existing moved.
- [ ] `gdformat` / `gdlint` clean on every touched `.gd` (hook-enforced per save).
- [ ] Manual run-through of Tasks 4, 5, 6 checks in one session: nickname shows in roster / squad / battle / Shadow Gear title; Rename edits + persists across reload; invalid name is a no-op; post-CLAIM prompt appears after the result panel on a real gate win AND a Nadir boss claim, NOT on the onboarding first gate or a claim-less win; Skip keeps the species name.
- [ ] Soft keyboard verified on device for both `LineEdit`s.
- [ ] Non-goals hold: no profanity library (hardcoded list only); nothing touches `BackendService` / the leaderboard; species name never shown next to a set nickname.

## Self-Review

**Spec coverage:**
- "New pure `core/text_filter.gd`, length + v0 profanity blocklist" → Task 1 (verbatim 13-entry list).
- "`claim_shadow` gains `nickname`; `set_shadow_nickname()` after `set_shadow_favorite()`; no `to_dict` change" → Task 2.
- "`enrich_army` gains `nickname` + `display_name`; `monster_name` stays" → Task 3.
- "4 display surfaces swap primary name only" → Task 4 (army_view roster, squad_view row + fielded line, main.gd battle party).
- "Rename control in Shadow Gear: RenameButton + transient LineEdit/Save/Cancel; no y-shift; title nickname replaces species; empty-army branch closes the strip" → Task 5.
- "ClaimNicknamePanel last child of GameUI; Bg blocks input; chained on `system_panel.dismissed`; armed only by real gate/Nadir claim; onboarding excluded structurally" → Task 6.
- "Empty nickname always valid / clears" → Task 1 `is_valid_nickname("")`, Task 2 `test_set_shadow_nickname_can_clear_back_to_empty`.
- "Per-instance not per-species" → Task 2 `test_set_shadow_nickname_is_per_instance_not_per_species`.
- "MAX_LENGTH = 20, flagged invented" → Task 1 Global Constraints + class doc.
- "Private for v0" → no task references `BackendService` / leaderboard.
- "Soft keyboard = device-verify, not built" → `grab_focus()` only; Tasks 5/6 manual steps + post-plan checklist.

**Placeholder scan:** the `mon_ashen_warden` / `_shadow(...)` / `test_enrich_army_includes_grade_name` fixture names in Tasks 2–3 are explicitly flagged as "match the file's real fixtures" with a concrete fallback instruction — not silent TBDs. Every code step has literal code. Manual steps list concrete taps + expected text.

**Type consistency:**
- `set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool` — defined Task 2, called with `String` args in Task 5 (`_current_shadow_instance_id()`, `rename_input.text`) and Task 6 (`_pending_nickname_shadow_id`, `claim_nickname_input.text`). Consistent.
- `display_name` / `nickname` — `String` in Task 3's enriched dict, read as `String` in Task 4's four sites. Consistent; never spelled `displayName` / `shown_name` anywhere (Task 5's local `shown_name` is a title-only computed string, not the dict key).
- `TextFilter.MAX_LENGTH: int` — defined Task 1, used in Task 6's `%d` format. Consistent.
- `system_panel.dismissed` — `SystemPanel` declares `signal dismissed` (`scenes/system_panel.gd:14`); connected once in Task 6 Step 3.
- `_pending_nickname_shadow_id` / `_pending_nickname_species` — set in Task 6 Step 4 at both claim sites, read+cleared in Step 5's handlers. Consistent.
