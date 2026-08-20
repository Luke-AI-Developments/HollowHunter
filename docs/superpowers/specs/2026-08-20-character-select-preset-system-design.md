# Character-select preset system — design spec

**Date:** 2026-08-20
**Status:** Approved by user, ready for implementation planning.

## Summary

Adds a preset-hunter picker to onboarding (§9b/§25 of `HollowHunter_Concept.md`):
before the existing subclass picker, a new hunter picks one of 12 curated
preset portraits (6 feminine-coded, 6 masculine-coded ids: `f1`-`f6`,
`m1`-`m6`). The choice is permanent (same precedent as subclass, §21) and
is stored on `HunterState`. The resulting portrait art — which already has
three rank-tier stages (`early`/`mid`/`late`, covering E-D / C-B / A-S) per
the Midjourney art pack — is then displayed on the Hunter/character screen
(§21), swapping stage automatically as `hunter_rank` advances. This is the
first time §21's "avatar showcase" gets real art; today it's text-only.

No new art is needed — all 36 `art/presets/preset_hunter_<id>_<stage>.png`
files already exist (imported in a prior session).

## Decisions made during design

1. **Onboarding order:** the preset grid is a new screen shown *before* the
   existing subclass picker, not combined with it and not after.
2. **Character-screen payoff is in scope:** this build also wires the
   chosen preset's rank-appropriate portrait into `CharacterView` (§21),
   not just the onboarding picker + storage.
3. **Old-save default:** saves from before this feature get `preset_id`
   auto-defaulted to `"m1"` in `from_dict()` — same pattern as `hunter_rank`
   defaulting to `"E"` for pre-§28 saves. No blank/no-portrait state.
4. **Permanence:** the preset pick is permanent, like subclass (§21: "no
   respec; to change class you start a new character"). No in-game
   "change look" affordance.
5. **Grid presentation:** a plain, unlabeled grid of all 12 early-stage
   portraits — no text names, no visual F/M grouping. The player picks by
   look alone, matching §9b's "preset-first" framing.

## Data model

`core/hunter_state.gd`:
- New field `preset_id: String` — one of `ArtPaths.PRESET_IDS` (12 values,
  see below). Permanent once set, same as `subclass`.
- `new_default(hunter_subclass: String = "WARRIOR", hunter_preset: String = "m1") -> HunterState`
  gains the second parameter, mirroring the existing subclass default-arg
  pattern. Sets `s.preset_id = hunter_preset`.
- `to_dict()` adds `"preset_id": preset_id`.
- `from_dict()` adds `s.preset_id = String(d.get("preset_id", "m1"))` — old
  saves silently get the same fixed default as a brand-new default hunter.

`autoload/save_service.gd`:
- `load_or_create(default_subclass: String = "WARRIOR", default_preset: String = "m1") -> HunterState`
  gains the second parameter, threaded through to both `new_default()`
  call sites inside it (the "no save file" path and the "unreadable save"
  fallback path).

Pure, engine-free — fully covered by `core/` unit-test convention.

## Art data & path resolution

`scenes/art_paths.gd` (`ArtPaths`, already the single place that resolves
content ids to art files):
- New constant `PRESET_IDS := ["f1", "f2", "f3", "f4", "f5", "f6", "m1", "m2", "m3", "m4", "m5", "m6"]`
  — the fixed list of 12, in the same order as
  `art/HollowHunter_ArtDropTool.html`'s `PRESET_IDS`. This is the single
  source of truth the onboarding screen iterates over — no duplicate list
  in `main.gd`.
- New function:
  ```gdscript
  static func preset_portrait(preset_id: String, stage: String) -> Texture2D:
      var path := "res://art/presets/preset_hunter_%s_%s.png" % [preset_id, stage]
      return load(path) if ResourceLoader.exists(path) else null
  ```
  Same load-if-exists/null-fallback convention as the other three
  `ArtPaths` functions.

`core/game_logic.gd` (already owns `RANK_ORDER := ["E", "D", "C", "B", "A", "S"]`):
- New pure function `stage_for_rank(rank: String) -> String` mapping:
  - `"E"`, `"D"` → `"early"`
  - `"C"`, `"B"` → `"mid"`
  - `"A"`, `"S"` → `"late"`
  - Any other/unknown value → `"early"` (safe fallback, mirrors how other
    `GameLogic` lookups degrade rather than error on bad input).

## Onboarding flow

`scenes/main.tscn`:
- New `PresetPicker` `Node2D` node (parallel structure to the existing
  `SubclassPicker`): a title `Label` + an empty `GridContainer` that
  `main.gd` populates at runtime with 12 `Button`s (one per
  `ArtPaths.PRESET_IDS`).

`scenes/main.gd`:
- New `@onready var preset_picker: Node2D = $PresetPicker` and
  `@onready var preset_grid: GridContainer = $PresetPicker/Grid` (exact
  child path set by the plan/implementer to match the `.tscn` layout).
- New `var _pending_preset_id: String = "m1"` — holds the chosen preset
  between the two onboarding screens (no `HunterState` exists yet at pick
  time, same reason `subclass` isn't stored until `_on_subclass_chosen`
  creates the state).
- `_ready()`'s `is_new_hunter` branch now calls a new `_show_preset_picker()`
  instead of `_show_subclass_picker()` directly.
- New `_show_preset_picker() -> void`: shows `preset_picker`, hides
  `subclass_picker`/`game_ui` (mirrors `_show_subclass_picker()`'s
  visibility handling), and builds the 12 buttons into `preset_grid`:
  ```gdscript
  for preset_id in ArtPaths.PRESET_IDS:
      var button := Button.new()
      button.custom_minimum_size = Vector2(160, 160)
      button.icon = ArtPaths.preset_portrait(preset_id, "early")
      button.pressed.connect(_on_preset_chosen.bind(preset_id))
      preset_grid.add_child(button)
  ```
- New `_on_preset_chosen(preset_id: String) -> void`: sets
  `_pending_preset_id = preset_id`, hides `preset_picker`, calls
  `_show_subclass_picker()` (existing, unmodified).
- `_on_subclass_chosen(subclass: String)`'s existing
  `state = SaveService.load_or_create(subclass)` line becomes
  `state = SaveService.load_or_create(subclass, _pending_preset_id)`. No
  other change to that function.

`SubclassPicker` itself, its 5 class buttons, and everything from
`_on_subclass_chosen()` onward (starter shadow, guided gate, permission
flow) are untouched.

## Character screen payoff

`scenes/main.tscn`, `GameUI/CharacterPanel`:
- New `TextureRect` node `PortraitRect`, placed on the panel's unused right
  side (existing labels occupy roughly `offset_left 40 → 1400` of the
  2424-wide panel) — e.g. `offset_left = 1500, offset_top = 170, offset_right = 2380, offset_bottom = 900`,
  `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`
  (same two properties `inventory_view.gd` already sets on its
  `ArtPaths.set_showcase()` icons).

`scenes/character_view.gd`:
- New `@onready var portrait_rect: TextureRect = $PortraitRect`.
- `refresh()` gains one line, near the top alongside the other per-refresh
  reads of `_state`:
  ```gdscript
  portrait_rect.texture = ArtPaths.preset_portrait(
      _state.preset_id, GameLogic.stage_for_rank(_state.hunter_rank)
  )
  ```
- The class doc comment's "No hunter render/rank-glow art -- text only,
  same placeholder-art convention as the rest of this project's UI." line
  gets updated to reflect that the portrait now exists (rank-glow overlay
  itself remains out of scope — see below).

## Testing scope

Per this project's `core`/`scenes` split (`core/` pure + GUT-tested,
`scenes/` thin + manually verified):

- `tests/unit/test_game_logic.gd`: new cases for `stage_for_rank()` —
  all six ranks map correctly, plus one unknown-input case.
- `tests/unit/test_hunter_state.gd`: `new_default()` sets `preset_id` from
  its param (and defaults to `"m1"` with no arg); `from_dict()` defaults
  missing `preset_id` to `"m1"` (old-save case) and round-trips an explicit
  value through `to_dict()` → `from_dict()`.
- No GUT tests for `ArtPaths.preset_portrait()`/`PRESET_IDS`, the
  `PresetPicker` screen, or `CharacterPanel`'s new `TextureRect` — same
  convention already applied to the rest of `ArtPaths` and to
  `SubclassPicker`.

## Out of scope for this pass

- No in-game way to change a preset after onboarding.
- No rank-glow/aura visual overlay on the portrait itself (§9b mentions
  "aura intensity, particle density" as part of rank progression — the
  three art *stages* already carry visible rank progression in the source
  art; a dynamic glow/particle layer on top is a separate, later effort).
- No equipment paper-doll overlay on the portrait (§9b's "Equipment = a
  paper-doll overlays" is explicitly future work there too).
- No changes to `content/*.json` — this feature is pure state + UI, no
  data-driven content involved.
