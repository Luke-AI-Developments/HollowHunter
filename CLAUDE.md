# HollowHunter — Conventions

Godot 4 mobile game. Android first, foreground-only GPS, native Health Connect
+ GPS plugins. No game code before the environment/plugin setup checklist
(see chat history / setup prompt) is done.

## Folder layout

| Folder | Contents |
|---|---|
| `core/` | Pure GDScript. No `Node`, no scene tree, no engine calls. Data in, data out. Unit-tested. |
| `scenes/` | `.tscn` files + thin view scripts that wire `core/` classes to nodes. No game rules. |
| `tests/unit/` | GUT tests, one file per `core/` script (`core/x.gd` -> `tests/unit/test_x.gd`). |
| `addons/` | Third-party addons (GUT, etc.). |
| `native/android/` | Custom native Android plugin source (GPS, Health Connect). Not named `android/` — that path is Godot's auto-generated, gitignored Gradle build folder. |

## The rule: game logic stays pure and unit-tested

Anything that decides a game outcome — stats, inventory, quest state,
geofence/distance math, health-data aggregation, save data — is a plain
GDScript class in `core/` with no engine dependency, and has a test in
`tests/unit/`. Scenes only display state and forward input; they never
compute it. If a bug can only be reproduced by clicking through the running
game, that's a sign the logic needs to move to `core/` and get a test.

## GDScript style

- **Static typing everywhere**: `var hp: int = 100`, `func take_damage(amount: int) -> void:`.
- **Naming**: `snake_case` for variables/functions/files, `PascalCase` for
  classes/nodes, `SCREAMING_SNAKE_CASE` for constants and enums.
- Tabs for indentation (Godot/gdformat default) — don't fight the formatter.
- One class per file; filename matches the class (`Inventory` -> `inventory.gd`).
- Prefer signals over polling for cross-node communication.
- `class_name` only on classes referenced from other files/scenes; skip it
  for anything used in exactly one place.
- Format with `gdformat`, lint with `gdlint` before every commit — the
  post-edit hook does this automatically (see `.claude/settings.json`).

## Engineering principles (Karpathy)

- **Think before coding.** State assumptions explicitly; if uncertain, ask.
  Present real interpretations rather than silently picking one. Push back
  if a simpler approach exists.
- **Simplicity first.** Minimum code that solves the problem. No speculative
  abstractions, no unrequested configurability, no error handling for
  impossible scenarios. If it could be a third the size, rewrite it.
- **Surgical changes.** Touch only what the task requires. Don't refactor or
  reformat adjacent code. Match existing style. Remove only the imports/vars
  your own change orphaned — leave pre-existing dead code, just mention it.
- **Goal-driven, tests-first.** Turn every task into a verifiable goal before
  writing implementation:
  - "Add X" -> write a failing test for X, then make it pass.
  - "Fix bug Y" -> write a test that reproduces Y, then make it pass.
  For multi-step work, state the plan as `[step] -> verify: [check]` first.

## Native plugins (GPS / Health Connect)

GPS and Health Connect do not work in the Android emulator — all native
plugin work is verified on a physical device with USB debugging enabled.
Foreground-only: no background location/health polling.
