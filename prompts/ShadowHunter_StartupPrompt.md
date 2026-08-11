# SHADOW HUNTER — project kickoff prompt

Paste into Claude Code AFTER the setup prompt has finished and the project is scaffolded.
First: copy `ShadowHunter_Concept.md` into the project repo so Claude Code can read it.

---

We're building "Shadow Hunter" (working title) — a Godot 4 Android fitness RPG.
The full design bible is in ShadowHunter_Concept.md in this repo — read it, and
treat it as the source of truth (especially §11c, §4, §16).

Quick summary: real workouts (steps + Health Connect) earn EXP → level up a hunter
whose stats come from level × class. You walk to POI gates on a stylised map, fight
them via an auto power-check (GATE_POWER vs gate power), and CLAIM defeated bosses
into a shadow army. Everything is on-device and Android-first; placeholder art only.

DO NOT start building the game yet. Our entire first task is the throwaway
de-risking SPIKE from §11c — prove the native bridge works before anything else.
Build it checkpoint by checkpoint, and STOP and report after each one:

  Checkpoint 1 — a blank Godot app exported and running on my physical Android phone
    (sort out export preset, templates, signing, USB deploy first — this is the
    biggest hidden hurdle).
  Checkpoint 2 — a "hello world" Godot 4 Android plugin: a Kotlin class extending
    GodotPlugin with a method exposed via @UsedByGodot that returns a string to
    GDScript. Prove the bridge + Gradle/AAR build works.
  Checkpoint 3 — GPS: the plugin requests ACCESS_FINE_LOCATION at runtime and returns
    live lat/long to GDScript via a signal, shown on a label. I walk, it updates.
  Checkpoint 4 — Health Connect: request permissions, read today's step count + my
    most recent workout, return them to GDScript via a signal, show on screen.

Done when one screen shows my live location + today's steps + last workout, pulled
from GDScript, on my real device. Everything is async — return data via signals,
never method return values. Use the Godot 4.2+ v2 Android plugin system.

Lean on context7 for current Health Connect + Godot-plugin docs (this is the exact
area you're least trained on). Keep all game logic out of this — it's just the bridge.

If Checkpoints 1-2 become a multi-week fight, tell me — that's the signal to consider
the React Native fallback (§12), and we decide before going further.

Start with Checkpoint 1. Tell me what you need from me (device, cables, accounts).
