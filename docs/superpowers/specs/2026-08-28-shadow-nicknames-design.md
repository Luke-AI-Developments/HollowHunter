# Custom shadow nicknames (§6c) — design spec

**Date:** 2026-08-28
**Status:** Approved by user, ready for implementation planning.
**Supersedes:** the embedded design in
`docs/superpowers/plans/2026-08-16-shadow-nicknames.md`, which drifted —
`_refresh_army_label()` no longer exists (army roster moved to
`scenes/army_view.gd`), and the post-CLAIM prompt now has to coexist with
the §9c `SystemPanel` result ceremony. Tasks 1–3 of that plan are still
sound and carry over.

## Summary

Let a player give any owned shadow an optional, per-instance nickname,
editable later. Once set, the nickname **replaces** the species name
everywhere the shadow is listed (roster, squad picker, battle screen,
Shadow Gear title); grade / level / class / family stay as the
parenthetical secondary text. Empty/whitespace nickname = "use the species
name" (a skip, never a rejected value). Nicknames are **private for v0** —
nothing syncs to the leaderboard or any shared surface.

Two entry points: a **Rename** control in the Shadow Gear panel (edit any
time), and an **optional prompt right after a real CLAIM**, shown *after*
the battle-result `SystemPanel` is dismissed.

Core validation (length + profanity) is one new pure `core/` module.
`SquadBuilder.enrich_army()` is the single chokepoint that resolves
`nickname` → `display_name`, which every display surface already reads
through.

## Part 1 — Core (`core/`), unchanged from the 2026-08-16 plan

Still matches current code (`claim_shadow` and `enrich_army` are
unchanged). Full GUT tests, TDD, per `CLAUDE.md`.

### `core/text_filter.gd` (new)

Pure, no engine dependency. Factored out (not folded into `HunterState`)
so a future hunter/display-name input can reuse it.

- `const MAX_LENGTH := 20` — invented v0 number (spec said "~16–20"),
  flagged like `ShadowLeveling`'s other invented constants.
- `static func is_valid_nickname(text: String) -> bool` — `text.strip_edges()`
  empty → `true` (skip is always valid); else must be `<= MAX_LENGTH` and
  contain no blocked substring.
- `static func sanitize_nickname(text: String) -> String` — `strip_edges()`.
- `const _BLOCKED_SUBSTRINGS` — hardcoded v0 case-insensitive substring
  blocklist. Use the exact 13-entry list from
  `docs/superpowers/plans/2026-08-16-shadow-nicknames.md` Task 1 Step 3
  verbatim (`fuck`, `shit`, `cunt`, `nigger`, `nigga`, `faggot`, `fag`,
  `retard`, `whore`, `slut`, `rape`, `nazi`, `hitler`). Not a real
  profanity library; won't catch l33tspeak/spacing. Flagged as a v0 gap in
  the class doc comment.

### `core/hunter_state.gd`

- `claim_shadow()` — the shadow dict gains `"nickname": ""`.
- New `set_shadow_nickname(shadow_instance_id: String, nickname: String) -> bool`,
  placed right after `set_shadow_favorite()`. Returns `false` (no-op) if the
  shadow is unknown (`_army_index() < 0`) or `TextFilter.is_valid_nickname()`
  rejects the text; otherwise stores `TextFilter.sanitize_nickname(nickname)`
  and returns `true`. An empty string is valid and clears the nickname.
- No `to_dict()` / `from_dict()` change — `army` serialises as a whole
  `Array`, so `nickname` rides along; old saves missing the key read as
  `""` via `.get("nickname", "")` at every consumer.

### `core/squad_builder.gd`

- `enrich_army()`'s per-shadow appended dict gains:
  - `"nickname": shadow.get("nickname", "")`
  - `"display_name": nickname if nickname != "" else monster_name`
- `"monster_name"` stays as a separate key (still used where the raw
  species name is needed, e.g. the CLAIM message strings).

## Part 2 — Display surfaces (replaces old plan Tasks 4 & 5)

Each site swaps the **primary name only**; the `(grade·rank Lv…)`
parenthetical already right after it is the secondary text. All read from
`enrich_army()` output (directly or via `resolve_party()`).

| File:line | Change |
|---|---|
| `scenes/army_view.gd:163` (`_refresh_roster()`) | roster `Button.text`: `e["monster_name"]` → `e["display_name"]` |
| `scenes/squad_view.gd:82` (`refresh()`) | squad row label: `member["monster_name"]` → `member["display_name"]` |
| `scenes/squad_view.gd:98` (`refresh()`) | `chosen_names` map (the "fielded: …" line): `m["monster_name"]` → `m["display_name"]` |
| `scenes/main.gd:476` (`_build_battle_party()`) | `Battle.make_ally_combatant(...)` name arg → `member["display_name"]` |
| `scenes/inventory_view.gd` (item detail "Currently equipped by: %s") | resolve the wearer name from the army entry's own `nickname` (`nickname if nickname != "" else species`), NOT via `enrich_army` — this surface never enriches |

`army_view.gd::_refresh_squad()` (:223) only forwards to
`squad_view.refresh()` — covered above. The four `enrich_army`-derived
surfaces plus the one hand-resolved `inventory_view.gd` surface are the
complete set of player-facing shadow-name displays (whole-branch review
swept for others: mass-convert is count-only, fuse/convert have no
confirmation UI, every other `main.gd` `monster_name` is an enemy/gate
name). Added to scope during the whole-branch review.

## Part 3a — Rename control in Shadow Gear (replaces old plan Task 6)

### `scenes/main.tscn`, under `GameUI/ShadowGearPanel`

- `RenameButton` (`Button`) — placed near `FavoriteButton` (`:377`).
- A transient strip below `Title` (`:305`), all `visible = false`:
  - `RenameInput` (`LineEdit`, `placeholder_text = "Nickname (optional)"`)
  - `RenameSaveButton` (`Button`, "Save")
  - `RenameCancelButton` (`Button`, "Cancel")
- **No** `build_gear_rows` y-shift — the old plan's `180 → 230` is stale;
  it's already `250.0` (`shadow_gear_view.gd:36`) and the strip only shows
  transiently.

### `scenes/shadow_gear_view.gd`

- `@onready` refs for the four new nodes; wire `.pressed` in `_ready()`.
- `_on_rename_pressed()` — pre-fill `rename_input.text` with
  `_state.army[_index].get("nickname", "")`; show the three transient nodes.
- `_on_rename_save_pressed()` —
  `if _state.set_shadow_nickname(_current_shadow_instance_id(), rename_input.text):`
  then `_close_rename()` + `_after_mutation()` (which already saves +
  refreshes). Invalid → no-op; the strip stays open with the text still in
  it (no error UI — matches this panel's other actions).
- `_on_rename_cancel_pressed()` — `_close_rename()` (hide the three nodes).
- `refresh()`'s empty-army early-return branch also calls `_close_rename()`.
- `refresh()` title line (`shadow_gear_view.gd:249`): when
  `shadow.get("nickname", "")` is non-empty, the nickname **replaces** the
  species name — `Duskfang (General·B Lv7/10 WARRIOR · Undead) [3/12]`.
  Unchanged (species name) when there's no nickname. The species name is
  not shown alongside the nickname anywhere; the roster/Shadow-Gear
  portrait icon still identifies the species visually.

## Part 3b — Post-CLAIM prompt, chained after the result screen

The player sees the battle-result `SystemPanel` ("VICTORY! … CLAIMED!
Ashen Warden joins your army …") first, and only when they dismiss it does
the nickname prompt appear.

### `scenes/main.tscn`

New `ClaimNicknamePanel` under `GameUI`, **as the last child of GameUI**
(Godot resolves overlapping input by tree order, not `z_index` — same
constraint that moved `SystemToast` in `d53c05f` and that `SystemPanel`'s
class doc calls out). Nodes:

- `Bg` (`ColorRect`, full 1080×2424, near-opaque) — default `mouse_filter`
  = STOP, so it blocks taps to the map. This panel is **not**
  tap-anywhere-to-dismiss; it has explicit Save/Skip buttons.
- `InfoLabel` (`Label`)
- `NicknameInput` (`LineEdit`, `placeholder_text = "Nickname (optional)"`)
- `SaveButton` (`Button`, "Save")
- `SkipButton` (`Button`, "Skip")

### `scenes/main.gd`

- State: `var _pending_nickname_shadow_id: String = ""`,
  `var _pending_nickname_species: String = ""`.
- `_on_battle_finished()` (`:585`) — the currently-discarded
  `state.claim_shadow(gate["monster_id"], gate["rank"])` becomes
  `var claimed := state.claim_shadow(...)`; then
  `_pending_nickname_shadow_id = claimed["instance_id"]` and
  `_pending_nickname_species = gate["monster_name"]`. Only on the
  successful-claim branch (not "Boss escaped").
- `_apply_nadir_battle_result()` (`:1084`) — same, at the boss claim;
  species from `boss_monster.get("name", "")`.
- Connect `system_panel.dismissed` → new `_on_system_panel_dismissed()`
  once, in the same setup block that wires the other panel signals.
  Handler:
  - `if _pending_nickname_shadow_id == "": return`
  - else set `InfoLabel.text = "CLAIMED %s! Give it a nickname? (optional, max %d chars)" % [_pending_nickname_species, TextFilter.MAX_LENGTH]`,
    `nickname_input.text = ""`, `claim_nickname_panel.visible = true`,
    `nickname_input.grab_focus()`.
- `_on_claim_nickname_save_pressed()` —
  `if state.set_shadow_nickname(_pending_nickname_shadow_id, nickname_input.text):`
  then `SaveService.save(state)`, `army_view.refresh_if_open()`,
  `_refresh_label()`, `_close_claim_nickname_panel()`. Invalid → no-op,
  panel stays open with the text.
- `_on_claim_nickname_skip_pressed()` — `_close_claim_nickname_panel()`.
- `_close_claim_nickname_panel()` — clears both pending vars,
  `claim_nickname_panel.visible = false`.

### Why this is safe

- **Onboarding is excluded for free.** The guided starter claim and the
  scripted first-gate claim both happen entirely inside
  `_on_subclass_chosen()` (`Onboarding.resolve_guided_gate` +
  `state.claim_shadow`), never through `_on_battle_finished()` or
  `_apply_nadir_battle_result()`. No guard needed — §25's fast onboarding
  CLAIM moment is untouched.
- **`system_panel.dismissed` is shared** (fires for LEVEL UP!, STRONGHOLD,
  RANK TRIAL, lore stones, every result). The
  `_pending_nickname_shadow_id == ""` guard means only a real gate/Nadir
  claim arms it. If a level-up panel and the result panel both fire during
  one battle resolution, `dismissed` still fires only on the player's
  single tap — the handler runs once.
- `Bg` at STOP blocks the map while the prompt is up; being the last
  GameUI child, the panel's own buttons win input.

## Non-goals

- **No profanity library** — hardcoded v0 substring blocklist only.
- **No leaderboard / sync** — nicknames private for v0; no task touches
  `BackendService`.
- **No nickname on the onboarding claims** (excluded structurally, above).
- **No Android soft-keyboard handling built speculatively** — Godot 4
  raises the OS keyboard on `LineEdit.grab_focus()` by default
  (`virtual_keyboard_enabled`). Manual pass verifies it on device; if it
  misbehaves, that's a follow-up, not this spec.
- **Species name is not shown next to a set nickname** anywhere (user
  decision: the shadow "becomes" the nickname). Species stays identifiable
  via the portrait icon.

## Testing

- **`core/`** (`text_filter.gd`, `hunter_state.gd`, `squad_builder.gd`):
  full GUT, TDD. New tests only add to the suite count — nothing existing
  moves.
- **`scenes/`**: manual per `CLAUDE.md` (no game rules to unit-test). GUT
  count must move only by the new `core/` tests.
- Manual checklist:
  - Rename via Shadow Gear → title updates, nickname replaces species;
    Prev/Next shows each shadow's own nickname; reload the save → persists.
  - Nickname shows in the roster, squad picker rows + "fielded" line, and
    the battle screen HP slot.
  - Invalid name (>20 chars, or a blocked word) → Save is a no-op, strip
    stays open with the text.
  - Real gate win with a successful CLAIM → result `SystemPanel` first,
    then (on dismiss) the nickname prompt. Save → nickname sticks; Skip →
    species name kept.
  - Nadir boss claim → same chained prompt.
  - Onboarding first gate → **no** prompt.
  - Soft keyboard rises when the prompt's `LineEdit` focuses (on device).
