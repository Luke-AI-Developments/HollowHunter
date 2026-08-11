# SHADOW HUNTER — Concept & Design Doc
*Working title. A GPS fitness-RPG where your real workouts level a hunter who clears monster gates and builds a shadow army.*

---

## 1. Elevator pitch

You are a hunter. Your body is your character sheet. Real-world exercise — logged automatically from your smartwatch / phone — earns EXP and raises your stats. As you walk through the real world, monster **gates** appear around you on a live map. Whether you can clear a gate depends on your **power level** (your stats + your shadow army), weighted against the gate's rank. Win, and you extract the fallen monsters as **shadow soldiers** and loot **equipment** to make yourself and your army stronger. There's no end — gates and scaling **raids** always rise to meet you, and a **hunter ranking** ladder shows where you stand against everyone else.

The fantasy: *the more you train in real life, the stronger you become in-game.* It's Solo Leveling's numeric power-fantasy, powered by your actual fitness.

> **IP note:** built as *inspired by* Solo Leveling — original name, original hunter, original System UI. The loop (level-by-exercising, power-vs-gate combat, absorb-defeated-enemies-into-an-army) is all game mechanics, which aren't copyrightable, so this is yours to share and even monetize freely.

---

## 2. Core gameplay loop

```
   REAL WORKOUT                WALK AROUND (GPS)              CLEAR A GATE
  (watch / phone)      →      gates spawn near you    →   power vs gate rank
        │                                                        │
        │                                                   win / lose (RNG)
        ▼                                                        │
   EXP + stat gains  ◄──────────  loot: equipment,  ◄───────────┘
   → higher hunter level          shadow extraction
   → stronger power level         → army grows
        │                                                        │
        └──────────────► higher-rank gates + raids appear ◄──────┘
                              (endless scaling)
```

1. **Train** — exercise in the real world; your watch/phone logs it; you gain EXP and stat growth.
2. **Explore** — walk around; gates spawn on the map based on your GPS location and hunter level.
3. **Fight** — enter a gate; your total power is weighted against the gate's rank via a weighted-RNG check.
4. **Reward** — on a clear you extract shadows and loot equipment.
5. **Grow** — bigger army + better gear + higher stats = higher power = access to tougher gates and raids.

---

## 3. The hunter — stats & leveling

### Hunter Level
Driven by total **EXP**. Your level gates which monster ranks spawn for you and contributes a flat base to your power. Endless.

**EXP-to-next-level curve:** `EXP_to_next(level) = 100 × level` (linear — flattened after a pacing check, §29).

| Level | EXP for that level | ~Cumulative |
|------:|-------------------:|------------:|
| 2  | 200   | 200    |
| 5  | 500   | 1,400  |
| 10 | 1,000 | 5,400  |
| 20 | 2,000 | 20,900 |
| 40 | 4,000 | 81,900 |

A typical active day (~8,000 steps + a 30-min workout ≈ **~400 EXP**) is a level or two early on, then a steady climb. Pacing is worked out in §29 so ranks land at sane intervals (S-rank ≈ 7 months of active play, not years).

### Core stats — derived from level + class
Five stats — **STR, AGI, VIT, END, SEN** — but you **don't train them individually**. They're **derived from your hunter level and your subclass** (§21): each level grants stat points split by your class's profile, so every class gains *some* of every stat (**no zero-speed weightlifters**) while leaning into its signature.

| Stat | Governs |
|------|---------|
| **STR** Strength | melee power |
| **AGI** Agility | attack speed, dodge |
| **VIT** Vitality | max HP |
| **END** Endurance | sustain in long fights/raids |
| **SEN** Sense | crit, gate-detection range |

Your **subclass** (Warrior/Guardian/Assassin/Mage/Support) sets the spread — a Warrior is STR-heavy, a Mage SEN-heavy — but all five rise with level. What you *train* only changes how fast you level (§4), never the stat balance. Full class stat profiles are in §16.

---

## 4. Workout → EXP → level (the health integration)

**You don't integrate watches — you read from two OS health stores, and every watch feeds into them:**
- **iOS → Apple HealthKit** (Apple Watch + most third-party watches sync here)
- **Android → Health Connect** (Wear OS, Samsung, Fitbit, Garmin sync here)

Read sensor-validated data (not honor-system typing) so leveling feels earned and is hard to cheat. HealthKit/Health Connect also **tag workouts by type**, which is how your **subclass's signature training** earns bonus EXP.

**EXP model (single track — no per-stat routing):**
```
base_EXP   = (steps ÷ 100) + (active_minutes × 5) + (workout_minutes × 10)
class_mult = 1.5  if the workout matches your subclass's signature training
           = 1.0  otherwise
daily_EXP  = base_EXP, with class_mult applied to the matching workout minutes
```
Steps always count at **1×**. A workout matching your subclass gives **1.5× EXP** on its minutes; any other workout still gives **1×** — so *all* exercise levels you, matched training is just faster. Then EXP → level → stats via your class profile (§3, §16). **No activity ever unbalances your stats.**

**Signature training (1.5×) by subclass — tunable:**
```
Warrior   — strength / weight training
Assassin  — running / sprinting / HIIT
Guardian  — long endurance (cycling, rowing, hiking, long cardio)
Mage      — yoga / pilates / mobility
Support   — swimming / core / cross-training
```
HealthKit / Health Connect workout tags drive the match.

**Health guardrails (bake in from day one):**
- **Daily EXP soft-cap / diminishing returns** so marathoners don't break the curve and nobody's nudged toward overtraining.
- **Rest-day bonus** — reward recovery as part of progression (very on-theme for a leveling system, and healthy).
- Reward **consistency over extremes**.

---

## 5. Gates — the walking-around combat

As you move, gates spawn on the map near your location. Spawn rank is weighted by your hunter level: mostly gates near your power, with rarer higher-rank gates as tempting gambles.

### Gate ranks & power tiers (illustrative midpoints)

| Rank | Gate power | Who it's for |
|:----:|-----------:|--------------|
| E | ~150   | brand-new hunters |
| D | ~400   | early game |
| C | ~1,000 | mid |
| B | ~2,500 | advanced |
| A | ~6,000 | elite |
| S | ~15,000 | endgame / rare |

### Your power level
```
personal_power = (STR×wS + AGI×wA + VIT×wV + END×wE + SEN×wN) + hunter_level×C
army_power     = Σ (shadow_power × equipment_multiplier)
TOTAL_POWER    = personal_power + army_power
```

### Clear check — weighted RNG
Success isn't a hard gate; it's a probability based on how your power compares to the gate's:
```
r = TOTAL_POWER ÷ gate_power
P(clear) = r^k / (r^k + 1)        // k ≈ 3 controls steepness
```

**Worked example — a solid D-rank hunter (power 700):**

| Gate | Power | Clear chance |
|:----:|------:|:------------:|
| E | 150   | 99%  |
| D | 400   | 84%  |
| C | 1,000 | **26%** ← the RNG upset you described |
| B | 2,500 | 2%   |
| A | 6,000 | 0.2% |
| S | 15,000 | ~0% |

So a D-rank *can* punch up into a C gate and pull off an upset ~1 in 4 tries, but has effectively no chance against an A gate — and won't encounter many of them anyway. Exactly the feel you wanted. `k` is the single knob for how swingy vs. deterministic fights feel.

*(Combat resolves on this power check by default — leaning into "your real training is what wins." You can later layer optional active skills to swing a close fight, but the MVP is auto-resolve.)*

---

## 6. Shadow army

The **boss** of a cleared gate can be **extracted** as a shadow via the **CLAIM** command — a dramatic prompt with **3 RNG attempts** (success rises with hunter level; full flow in §18). Only the boss is claimable — trash mobs aren't. Raid bosses can be claimed the same way. (Fiction naming in §14b.)

- **Where they matter:** shadows contribute to power as a **deployed squad of 6 at gates**, and as your **entire army in raids** (§16) — raids are where a big collection truly pays off.
- **Upgrading:** shadows can be strengthened with **equipment** dropped from gates. Each shadow has gear slots; better gear = higher `shadow_power` and a bigger `equipment_multiplier`.
- **Roster depth:** rarer/higher-rank monsters extract into stronger shadows (with a lower extraction chance), giving a collection chase on top of raw power.

### Grades & leveling
- **Grade (static):** every shadow's grade = the **rank of the monster it came from** (E–S), fixed forever — CLAIM a General-grade monster and it stays a General. **No promotion between grades.** Original 6-tier ladder mapped to E→S:
  **Wraith (E) · Soldier (D) · Knight (C) · General (B) · Warlord (A) · Sovereign (S).**
- **Level:** each shadow levels **1 → cap (v0: 10)** by spending **Essence** (the single earned currency, §26); feeding in a **duplicate** you own also costs Essence but grants a big level chunk. Equipment is separate.
- **Grades overlap:** a well-levelled lower grade rivals a fresh higher one — e.g. a maxed General ≈ a low-level Warlord — so leveling favourites stays worthwhile even without higher-grade catches.

---

## 7. Equipment & loot

Clearing gates has a chance to drop **equipment usable on yourself OR on your shadows.**

- **On the hunter:** flat/percent stat boosts (weapon → STR, boots → AGI, armor → VIT, etc.).
- **On shadows:** raises that shadow's power and its equipment multiplier.
- Suggested rarity tiers (common → legendary) with higher-rank gates dropping better loot — the reason to risk punching up.
- Creates a satisfying resource sink and a reason to keep clearing gates even after a level plateaus.

---

## 8. Stationary play — tickets & gate breaks (no walking required)

The **at-home layer**: two ways to play a **gate** without walking to one. (The whole-army endgame *raid* — the Nadir — is separate; see §20.) Both open a normal gate (§18 flow, squad / `GATE_POWER`) — one you trigger, one the game triggers.

### 8a. Gate tickets — spawn a gate where you are
- **Use a single-use ticket** to instantly open a gate at your current location — no walking. Runs as a normal 3-round gate (§18) with your squad.
- Tickets **drop from play and ranking rewards**, and are the shop's core paid item (§14) — convenience for when you can't get out, never power.
- The ticketed gate's rank scales around your level, so it's always worth doing.

### 8b. Gate breaks — game-initiated emergency events (anytime)
Straight from the anime: a gate ruptures and monsters spill into the overworld. The game **pushes you a gate** to take on — no walking, any time.

- **Trigger:** a push notification / in-app alert — *"⚠ Gate break — monsters are flooding out. Answer it?"* Fires on a schedule (weighted to evenings) and/or randomly.
- **How it plays:** accepting opens a gate right where you are (§18 flow) — **no GPS movement required**.
- **Urgency:** a limited response window creates a reason to open the app right then — the retention hook.
- **Rewards:** shadows (boss CLAIM), equipment, tickets, and ranking points; bigger breaks give bigger rewards. Ignoring one is just a missed reward, never a penalty.
- **Purpose:** an evening/at-home activity that softens the "I can only play while walking" constraint — good for retention *and* for anyone who can't walk much.
- **Future co-op:** gate breaks are the natural home for eventual multiplayer (many hunters into one break). Ships solo first.

> Between world gates (walking), tickets, gate breaks, and the Nadir (§20), the game is fully playable without moving — walking earns the most, but there's always something to do at home.

---

## 9. Hunter rankings (social layer)

Solo gameplay, but a leaderboard gives it a competitive spine. Kept simple — it's a bragging board, not a fairness-critical system, so it's fine that build (grindable and buyable) can climb it.

- **Hunter Rank (E→S, §28)** is your prestige tier and groups the board — you compete within your rank.
- **Board:** ranked by standing — total power and/or **deepest Nadir floor** (optionally a hunter-level board too). Bragging rights, nothing gated behind it.
- **Scopes:** friends · regional · global.
- **Tech:** needs backend + accounts (§10) — the only system that leaves the device, and only **aggregates** (level, power, floor reached) go up, **never raw health data** (§27). Anti-cheat trust-based for v1 (§19).
- **Later:** guilds / co-op raids build on this.

---

## 9b. Art direction & character creation

> **Production order: placeholder-first.** Build the whole game with placeholder art (colored shapes + labels, or free CC0 packs from **Kenney.nl**) and do the real art as a single pass at the end. This section is the *target* for that final pass, not day-one work. **Critical enabler:** reference every sprite by a data ID → art-path (never hardcode sprites), so final assets swap in by editing data, not code. Consequence: keep the art MCPs (PixelLab/Aseprite/Blender) **off** during systems development — enable them only for the art phase.

### Art identity — LOCKED v1 (supersedes earlier palette notes)
*Decided with the founder during the marketing key-art work.*
- **Setting: contemporary real-world dark fantasy — NOT medieval, NOT cyberpunk.** Solo-Leveling-style: a *normal modern city* (kept grounded and minimal), and arcane **gates — swirling cyan portals** — open onto the dark, draconic monster-world. Keep the two **visually distinct**: the real world stays grounded/sparse; the dark fantasy lives *inside* the gates. Hunters read modern, never knightly, and never heavy-sci-fi mech (dial the glowing-tech back — the glow belongs to the gate).
- **Mood / hero concept:** *a dark draconic world, and you are the power whose light cuts through it.* Frost-cyan light piercing the black.
- **Palette (LOCKED): frost cyan.** Near-black base `#050b12` / `#03070d`; electric cyan accent `#22d3ee`; icy-white highlight `#7ff0ff`. Cyan = "the light" — reserve it for the hunter's power, gates, and glows against the dark. (Replaces the earlier purple-lead; shadow-monster glows are now cyan.)
- **Hero design (Fire Emblem × Octopath × Solo Leveling mold):** HD-2D pixel-art hero with cinematic lighting / bloom / DoF; a hunter with **hood up and the face lost in shadow (mysterious — NO mask/face-covering), only piercing glowing cyan eyes visible**; **armour blends near-future tech with segmented plate + dark leather** (techwear, functional straps — NOT a medieval knight); glowing cyan energy runes tracing the armour; a tattered dark coat/cloak; a blade wreathed in frost-cyan energy; heroic stance, rim-lit cyan against the draconic gate-world.
- **Key-art image prompt (for image tool / artist):** *"Heroic near-future dark-fantasy shadow hunter, HD-2D style like Octopath Traveler — detailed pixel-art character, cinematic lighting, bloom, tilt-shift DoF; anime hero in the spirit of Fire Emblem and Solo Leveling; NOT medieval. Hunter with hood up and face lost in shadow (no mask), only piercing glowing cyan eyes visible; sleek modern tactical armour blending near-future tech panels with segmented plate and dark leather, functional straps, glowing cyan energy runes; tattered dark coat; blade wreathed in frost-cyan energy with a modern hilt; confident stance, rim-lit electric cyan; dark draconic gate-world behind with a looming dragon shadow and a shaft of cyan light cutting through; palette near-black + cyan #22d3ee + icy white #7ff0ff; portrait poster, dramatic, high contrast, ominous power fantasy. --ar 2:3"*
- **Consistency + AI-art note:** generate a **character sheet** for the recurring hero; **commission/hand-finish the final hero art** (art is the scrutiny point, §23/§27).

### Visual target: HD-2D (Octopath-style), built in Godot 4
The look comes from **rendering, not sprite detail**: pixel-art sprites placed in 3D-lit scenes with real-time lighting, glow/bloom (perfect for the neon-purple magic), tilt-shift depth-of-field, particles, and atmospheric haze. Godot 4's Forward+ renderer supports all of it — `WorldEnvironment` (glow, DoF, fog), `Sprite3D`/billboards, `Light3D`, `GPUParticles`.

**Scope discipline:** full HD-2D depth lives only in the contained **battle / gate scenes** (the set-pieces), *not* an open explorable 3D world. The overworld stays a 2D map view. This is what keeps a Full-HD-2D ambition actually achievable solo.

### Style bible (lock before generating any art)

**Overall:** Octopath-style HD-2D — pixel sprites in 3D-lit dioramas — with a dark modern-fantasy mood (Solo Leveling): high contrast, moody light, neon-arcane magic.

**Resolution targets (keep consistent):**
- Battle/map character & monster sprites: **64×64–96×96** base (rendered larger in-scene).
- Bosses: larger canvas (e.g. 128×128+).
- Portraits (menus/dialogue): higher-res **~512×512**, painted, more detail.

**Palette (locked to §9b's frost-cyan — see note there):**
- Base: dark and desaturated — charcoal/near-black backgrounds.
- Accent (single, not two): high-saturation **electric cyan** (`#22d3ee`) + icy-white (`#7ff0ff`) highlight for magic, auras, glows. No purple/violet — cyan is "the light," reserved for the hunter's power, gates, and glows against the dark.
- Shadows (extracted monsters): inky near-black silhouette with a **cyan** inner glow + smoky particle edges — a *unified treatment* so any monster instantly reads as "a shadow."

**Rendering (Godot `WorldEnvironment`):** strong bloom/glow on magic and rim lights, tilt-shift depth-of-field (top/bottom blur), subtle volumetric haze, high contrast.

**Sprite rules:** subtle dark outline so sprites pop against 3D backgrounds; selective rim lighting in an accent color; silhouette-first (readable at a glance).

**Rank visual language (ties art to progression):** E-rank = ragged, desaturated, no glow → higher ranks add gear detail, aura intensity, particle density, and shadow-army presence. Progression is *visible*.

**Consistency rig:** a fixed generation prompt template + fixed seed + reference image, and every output post-processed (downscale to target res + palette-snap to the locked palette). *Consistency across assets — not single-image quality — is the real challenge with AI art.*

**Reusable prompt template (fill the brackets):**
> *"[subject], pixel art game sprite, [64x64], dark fantasy, moody cinematic lighting, limited palette of charcoal-black + electric cyan accent, subtle dark outline, dramatic rim light, glowing cyan [element] magic, clean readable silhouette, [front/8-direction] view, transparent background, HD-2D asset"*
>
> Shadow variant: append *"rendered as an inky black shadow silhouette with glowing cyan inner light and smoky edges."*

### Recommended art tooling (Claude Code + external)
Minimal stack — generate → clean → integrate:
- **PixelLab MCP** — game-ready pixel sprites (characters, 4/8-dir views, idle/walk/run animations, tilesets); plugs into Claude Code *and* Godot. Your primary sprite generator.
- **Godot MCP** (e.g. mkdevkit/godot-mcp or GDAI) — lets Claude control the Godot 4 editor: build scenes/nodes/scripts and **read editor errors**. Biggest offset to Claude's weaker Godot training. ~15-min setup.
- **Aseprite + `pixel-plugin`** — the standard pixel editor, drivable by natural language, for the essential cleanup/palette-snap/animation/export step.
- **Blender MCP** — *later*, for HD-2D battle backdrops: rough 3D layout + lighting + Poly Haven HDRIs. Good for blockouts, weak on organic detail.
- **Raw image gens (optional):** Sprite AI, Flux 2 (concept art), SDXL + pixel-art LoRA, Leonardo.Ai. For hard consistency, local Stable Diffusion (ComfyUI) + a LoRA trained on your own style.

*Rule of thumb from the field: pipeline + post-processing beat prompt-crafting. Raw AI output is never a drop-in asset — build a repeatable clean-up pass.*

### Character creation — preset-first, progression-driven
- **No full modular creator.** AI can't keep mix-and-match parts consistent, and it's a solo-dev trap.
- **Curated preset hunters:** generate many, hand-pick ~8–12 most on-style; the player picks one.
- **Cheap customization:** name + palette-swap recolors (hair / skin / accent).
- **Progression *is* the customization:** you don't pick a class — your real workouts define your build. The avatar visibly evolves with rank: E-rank ragged and plain → S-rank glowing with shadow aura. Visual rank-up is a core motivator.
- **Equipment = paper-doll overlays:** looted gear (weapon / armor / aura) shows on the avatar — a small, controlled layer set, not full-body customization.
- **Two asset types:** a detailed **portrait** for menus/dialogue + a simpler **battle/map sprite** (where the light pixelization lives).

---

## 9c. System UI — pop-up notification windows

**The genre convention, on-brand.** LitRPG/progression-fantasy shows (Solo Leveling, Overlord, Slime, countless web novels) all use a "status window" pop-up as the visual language of leveling up — it's a genre trope, not owned by any one IP, and it's exactly the shorthand that tells a viewer "this is that kind of power fantasy" in half a second. We build our own version in the locked frost-cyan identity (§9b), not a copy of anyone's specific panel design.

**Visual treatment:**
- A dark, semi-transparent glass panel with an **angular, rune-etched cyan border** — sharp geometric corner-brackets, not rounded corners, matching the near-future dark-fantasy identity.
- Text in icy-white (`#7ff0ff`), a thin glowing cyan divider line under any header, subtle scan-line shimmer on appear.
- Materializes with a quick "glitch-in" (a few frames of noise/flicker resolving into the panel), not a soft fade — reinforces the "System" feel.

**Two tiers, matched to the moment:**
- **Toast** — small, corner-anchored, auto-fades after ~2s. Used for: EXP gained, minor loot, small stat gains.
- **Full ceremonial panel** — centered, tap-anywhere/anywhere-to-dismiss, the glitch-in materialize. Used for: **rank up**, **boss CLAIM success** (§18), **gate cleared** reward breakdown, **Nadir floor cleared** (§20), **gate-break alert** (§8).

**Why this is low-risk to build:** it's a UI skin on systems already fully spec'd (CLAIM, gate clear, Nadir floors, rank-up) — no new game logic, just a shared panel component Code can wire to existing event triggers.

**Asset need:** one reusable **System UI frame/border graphic** (see Midjourney UI pack, §7) that the panel component stretches/tiles around whatever text or reward summary it's showing.

---

## 10. Tech stack & architecture

**Engine: Godot 4 (Forward+ renderer)** — chosen to hit Full HD-2D. Godot runs the whole game: UI, map, combat, and the HD-2D battle scenes. The trade vs. React Native: you gain real HD-2D rendering, but **device integration (GPS, health, push) becomes the hardest part of the build.**

| Layer | Recommendation | Why / note |
|-------|---------------|-----------|
| Engine | **Godot 4, Forward+** | HD-2D: 3D lighting, glow/bloom, DoF, particles |
| Language | **GDScript** (primary), C# optional | GDScript = fast to write; C# for heavier logic |
| GPS / location | **native plugin bridge** | ⚠ biggest integration risk — see below |
| Health data | **native plugin:** HealthKit (iOS) + Health Connect (Android) | ⚠ likely custom Kotlin/Swift via GDExtension/platform plugins |
| Map | OSM tiles via MapLibre + PMTiles on Cloudflare R2 (§19) | rendered on-device; ~free hosting, DIY vs an SDK |
| Local data | Godot resources / SQLite module | stats, shadows, inventory on-device |
| Push / events | native notification plugin | gate-break alerts |
| Backend (rankings + events) | **Supabase/Firebase via REST** | Godot calls HTTP from GDScript |
| Game logic | pure GDScript/C# modules | formulas live here, fully testable |

**⚠ The risk to plan around first:** Godot's GPS + HealthKit/Health Connect + push story is far less mature than React Native's. Expect to write or adapt **native plugins** (Kotlin for Android, Swift/Obj-C for iOS) to bridge health + location into the engine — the spiciest, least AI-assisted part of the project. **Prototype this bridge before building the game on top of it.**

**Architecture principle:** keep all game logic (EXP, power, clear-probability, loot rolls) as pure, testable GDScript/C# independent of scenes — same discipline as before, just in Godot.

---

## 11. First milestone (MVP) — what "playable" means

Aim for the smallest thing that proves the core fantasy: **train → get stronger → clear a gate.**

**MVP scope:**
0. **Plugin spike (do first):** prove a native bridge reads steps/workouts from HealthKit/Health Connect and gets GPS into Godot. Everything below assumes this works.
1. Feed workout data → compute daily EXP.
2. Hunter Level + one or two stats + a visible power number.
3. A map view in Godot showing your position and **spawning E/D gates** near you.
4. Tap a gate → auto-resolve clear check with the RNG formula → win/lose screen.
5. On win: gain a shadow (simple list) + one piece of equipment; power goes up.
6. All on-device, single-player. **No backend, no rankings, no raids yet.**
7. **Placeholder art only** — colored shapes + labels or Kenney.nl packs. Every sprite referenced by a data ID → art-path so real art swaps in later without code changes. Real art is a separate final pass.

**Then layer in the rest as patches — full ordered roadmap in §24** (equipment & sets → shadow grades → Nadir → stationary play → Stronghold → incursions → backend + rankings → shop).

**Rough effort:** the MVP is a realistic few-weekends vibe-coding target. The long tail (content, balance, art, polish) is where the real time goes — true of every game, not a tech limit.

---

## 11b. Dev environment setup — install before coding

> **When you're ready to start coding, ask Claude Code to audit what you already have vs. what's missing.** Suggested opening prompt:
>
> *"Before we write any code, audit my dev environment for a Godot 4 mobile game targeting Android and iOS with native GPS + health-data plugins. Check what's installed vs. missing and give exact install commands for my OS: Godot 4 (the .NET build if we'll use C#), Git, Android Studio + Android SDK/NDK + a JDK (for Android export and native plugins), and — if I'm on a Mac — Xcode + CocoaPods (for iOS export and native plugins). Confirm Godot's Android and iOS export templates are installed. Then set up a Git repo, a Godot .gitignore, a project structure that keeps game logic in pure testable scripts, the GUT unit-test addon, and gdtoolkit (gdformat/gdlint) with post-edit hooks that run format + lint + tests.*
> *Also review every Claude Code plugin and MCP server I currently have enabled, and DISABLE any that aren't useful for a Godot/GDScript game — they load tool definitions into context every session and waste tokens. Keep only what's relevant to Godot, code quality, and the art pipeline (see the keep/disable list below)."*

**The checklist it should verify (skip anything you already have):**

| Tool | Why | Note |
|------|-----|------|
| **Godot 4** (.NET build if using C#) | the engine | Forward+ renderer for HD-2D |
| **Git + GitHub account** | version control / rollback safety | commit often |
| **Android Studio + SDK + NDK + JDK** | Android export **and** native GPS/health plugins | required for the plugin bridge |
| **Xcode + CocoaPods** | iOS export + native plugins | Mac only |
| **Godot export templates** (Android/iOS) | needed to build to a device | install from Godot |
| **VS Code** | edit GDScript + native (Kotlin/Swift) plugin code | run Claude Code in its terminal |
| **GUT (Godot Unit Test) addon** | unit-test the game-logic math | per-project |
| **gdtoolkit** (`gdformat` + `gdlint`) | auto-format + lint GDScript; wire into post-edit hooks | `pip install gdtoolkit` |
| **Physical Android/iOS device** | GPS + health need real hardware | simulators won't cut it |

**Claude Code MCPs & plugins — enable vs. disable (prune to save context tokens):**

| Enable — useful here | For |
|----------------------|-----|
| **Godot MCP** (mkdevkit/godot-mcp or GDAI) | Claude builds scenes/nodes/scripts + reads editor errors — on the whole time |
| **PixelLab MCP** | game-ready pixel sprites — *art phase only; keep OFF during systems dev* |
| **Aseprite + `pixel-plugin`** | pixel cleanup/palette-snap/export — *art phase only; OFF during systems dev* |
| **Blender MCP** | *art phase only* — HD-2D battle backdrops + lighting blockouts |
| **context7** | live Godot / plugin docs (offsets weaker Godot training) |
| **karpathy-skills** | code-quality guardrails (merge into `CLAUDE.md`) |
| **code-review, code-simplifier** | the check-then-clean quality loop |
| **github, claude-md-management, feature-dev** | version control + workflow |
| **frontend-design** (situational) | UI mockups only — sketch the "System" look as web mockups, then rebuild in Godot; **OFF during core coding** |
| **Figma MCP** (optional) | only if you design UI in Figma — bridges designs toward implementation specs |

| Disable — dead weight for a Godot game | Why |
|----------------------------------------|-----|
| **caveman** | forces terse replies — counterproductive while learning Godot |
| **typescript-lsp, playwright** | web/TS-oriented; irrelevant unless you later build a web leaderboard |
| **gstack** | shelve until the project has real momentum |

> Every enabled MCP/plugin loads its tool definitions into the context window each session, so prune aggressively — e.g. keep Blender MCP off until you actually reach backdrops.

**Setup steps beyond installs (highest-leverage):**
- **Prototype the native GPS + health plugin FIRST** — it's the #1 technical risk; prove it before building the game on top.
- Generate a **`CLAUDE.md`** (`/init`) with conventions: GDScript style, folder layout, "game logic stays pure & testable," naming.
- Keep game logic pure and covered by **GUT** tests; commit whenever tests are green.
- Wire **post-edit hooks** to run `gdformat` + `gdlint` + GUT, so Claude auto-formats, lints, and tests its own GDScript (the quality loop for Godot).
- Loop: small change → format/lint/tests green → commit → repeat.

*Note: Claude is less trained on GDScript + Godot native plugins than on mainstream web stacks, so expect to lean on Godot docs/community for the plugin-bridging parts.*

---

## 11c. First build — the Android health/GPS spike (do this before anything else)

**Decisions locked:** target **Android first**, **foreground-only** location. The spike is a *throwaway* prototype whose only job is to prove real GPS + real step/workout data reach GDScript on a physical phone. No game, no art. If it works, the rest is normal Godot dev; if it doesn't, you've learned that cheaply.

### Native pieces involved
- **GPS:** Android `FusedLocationProviderClient` (Kotlin), foreground, `ACCESS_FINE_LOCATION` only — no background permission needed.
- **Health:** **Health Connect** (`androidx.health.connect:connect-client`, Kotlin) — read Steps, ExerciseSession, ActiveCaloriesBurned, HeartRate, Distance.
- **Bridge:** a Godot 4 **Android plugin** — a Kotlin class extending `GodotPlugin`, methods exposed with `@UsedByGodot`, async results returned to GDScript via **signals** (`emitSignal`), built as an AAR with Gradle. Use Godot 4.2+ v2 Android plugin system. Device-only — none of this runs in the editor.

### Checkpoints (each is a go/no-go gate)
1. **Blank Godot app runs on your real phone.** Android export preset + export templates + USB debugging + one-click deploy. *Biggest hidden hurdle — prove the whole pipeline before touching native code.*
2. **Hello-world plugin.** GDScript calls a plugin method, gets a string back. Proves the bridge + Gradle build independent of the messy platform APIs.
3. **GPS.** Plugin requests location permission at runtime, returns live lat/long to GDScript via a signal, shown on a label. Walk around, watch it update.
4. **Health Connect.** Request Health Connect permissions (its own permission flow, *not* standard runtime perms), read today's aggregated steps + most recent ExerciseSession, return to GDScript via signal, show on screen.

**Done when:** one screen shows your live location + today's steps + last workout, pulled from GDScript, on device.

**Immediately after (still simple):** feed those numbers into the §4 EXP formula so a workout visibly raises a number. That closes the core input loop and de-risks everything downstream.

### Android-specific gotchas
- **Health Connect availability:** needs Android 8+ (API 26); it's built into the OS on Android 14+, a separate installable app below that. Confirm your test device before starting.
- **Everything is async** — return data through signals, never method return values.
- **Health Connect permissions** use a dedicated permission contract, separate from location's runtime permission.
- **Release (not spike-blocking):** Health Connect requires declaring the data types you read + a privacy policy; plan for it at store-submission time.

### How to work it with your tooling
- **context7** — pull current Health Connect + Godot Android-plugin docs (this is the exact spot Claude's training is thin).
- **Godot MCP** — let Claude build the test scene, wire the label + signal, and read editor/export errors.
- Expect to **hand-write the Kotlin** with Claude assisting — the plugin bridge is the least-automatable part.

### Fallback gate
If checkpoints 1–2 become a multi-week fight, that's the native-plugin risk materializing → pivot to the React Native route (mature health/GPS libraries) + an embedded engine view for HD-2D combat. Decide by the end of checkpoint 2, not later.

---

## 12. Open questions / decisions to revisit

- **Stat weights (wS, wA, …) and level constant C** — need tuning once real workout data is flowing.
- **`k` steepness** — how swingy should fights feel? (3 = the numbers in §5.)
- **Extraction chance** — always? rank-based? a resource?
- **Anti-cheat depth** — reading from health stores covers most of it; do you care about spoofed GPS / fake workouts for the leaderboard?
- **Godot native-plugin bridging (TOP RISK)** — HealthKit/Health Connect/GPS/push have no mature Godot support; prototype the native bridge before anything else. If it proves too painful, the fallback is React Native for the app shell + an embedded engine view for HD-2D combat (hybrid).
- **Energy/battery** — constant GPS drains phones; may want a low-power background mode.
- **Gate-break cadence & notifications** — how often do breaks fire, how long is the response window, and how do you avoid notification fatigue? (Let players set quiet hours / frequency.)
- **Gate-break power** — do breaks scale to your power like keyed raids, or come in fixed E→S severities you choose to answer?
- **Testing** — build a "dev mode" fake-location + fake-workout toggle early, or field-testing a GPS game becomes miserable.
- **Art** — original monster/shadow designs and System UI; biggest non-code time sink.

---

## 13. Data model (ready to code once the spike passes)

Three layers: **Definitions** (static authored content — Godot `Resource` files, immutable), **State** (mutable save data), and **Transient** (runtime-only). All power/EXP math lives in **pure functions** over these — no state inside them — so they're unit-testable with GUT. Every visual is a `sprite_id` / art-path reference, so placeholder → final art is a data swap, never a code change.

### Definitions (content — add a monster = add one of these)
```
MonsterDef                 # a species/type
  id: String
  name: String
  rank: Rank               # E, D, C, B, A, S
  clazz: Class             # WARRIOR, GUARDIAN, ASSASSIN, MAGE, SUPPORT — gates equipment
  base_power: int
  extract_chance: float    # base per-try CLAIM chance when this monster is a BOSS (scaled by hunter level, 3 tries — §18)
  loot_table_id: String
  sprite_id: String        # placeholder now, real art later
  portrait_id: String

EquipmentDef
  id: String
  name: String
  slot: Slot               # WEAPON, HEAD, BODY, HANDS, FEET, ACCESSORY, AURA
  rarity: Rarity           # COMMON .. LEGENDARY
  target: Target           # HUNTER, SHADOW, BOTH
  allowed_classes: Array[Class]  # which classes can equip it (empty = any)
  stat_mods: Dictionary    # {"STR": 5, "AGI": 2}
  power_bonus: int
  set_id: String           # optional — belongs to a set (see §15)
  source: String           # where it drops (gate rank / raid / crate)
  sprite_id: String

GateTierDef
  rank: Rank
  power_min: int
  power_max: int
  monster_pool: Array[String]   # MonsterDef ids
  loot_table_id: String
  spawn_weight: float           # how often this rank appears for eligible players

LootTableDef
  id: String
  entries: Array                # [{type:"equipment"|"shadow", ref:id, weight, rarity}]
```

### State (save data)
```
HunterState
  hunter_level: int
  total_exp: int
  stats: StatBlock
  rank: Rank                    # derived from level/power thresholds
  equipped: Dictionary          # {Slot: equipment_instance_id}
  inventory: Array[EquipmentInstance]
  army: Array[ShadowInstance]
  gate_tickets: int
  settings: Dictionary          # quiet hours, notif frequency, etc.

StatBlock
  STR: int; AGI: int; VIT: int; END: int; SEN: int
  # optional: per-stat exp if stats level independently

ShadowInstance
  instance_id: String
  monster_def_id: String
  grade: Rank                   # = MonsterDef.rank, STATIC (Wraith..Sovereign = E..S)
  level: int                    # 1..cap (v0 cap 10); raised by merging duplicate copies
  equipped: Dictionary          # {Slot: equipment_instance_id}

EquipmentInstance
  instance_id: String
  equipment_def_id: String
  # room for rolled affixes later
```

### Transient (runtime, not long-term saved)
```
GateInstance
  id; rank; power: int
  location: {lat, lng}
  boss_id: String               # the claimable boss (round 3)
  trash_ids: Array[String]      # rounds 1–2 (non-claimable filler)
  loot_table_id: String
  expires_at: int               # gate-break response window

RaidInstance
  source: String                # "key" | "gate_break"
  power: int                    # = total_power * difficulty_mult
  difficulty_mult: float
  loot_table_id: String
```

### Derived — pure functions (the testable core, no state inside)
```
exp_to_next(level) -> int                            # 100 * level (linear, §3/§29)
apply_workout(hunter, workout) -> exp                # §4: base EXP × class signature 1.5×, + daily cap
stats_from(level, subclass) -> StatBlock             # level × class profile (§16) — no per-stat training
personal_power(stats, level, equipped) -> int
shadow_power(shadow) -> int                          # base + level + gear
army_power(army) -> int                              # Σ shadow_power
total_power(hunter) -> int                           # personal + army
gate_power(gate_tier) -> int                         # rolled in [min, max]
clear_probability(total_power, gate_power, k=3) -> float   # r^k / (r^k + 1)
resolve_clear(total_power, gate_power) -> bool       # RNG vs probability
roll_loot(loot_table, gate_rank) -> Array            # equipment + maybe a shadow
```

This keeps **content and logic fully separate**: adding a creature is authoring a `MonsterDef` + a `sprite_id`; all the math is pure and unit-tested — exactly the discipline §10 calls for.

---

## 14. Monetization — item shop

**Design principle: don't sell power.** The core fantasy is *earning* strength through real effort. Selling stats/levels directly undercuts that (and is the most-resented monetization). Sell **cosmetics, convenience, and access**; keep earned progression earned.

**Currencies:**
- **Essence** (soft) — the single earned currency; from gates/raids and converting surplus shadows. Pays for *all* in-game upgrades (shadows, gear, Stronghold). See §26.
- **Crystals** (premium) — bought with real money, slowly earnable; spent on **Essence, gate tickets, and cosmetics** (§26). Buys build/pace, not level.

**Shop offerings (deliberately lean):**
- **Gate tickets.** Single-use tickets that **spawn a gate at your location** (§8a); also earnable through play.
- **Essence.** The earned currency (§26) — buyable with Crystals to accelerate your **build** (gear enhancement, shadow leveling, Stronghold).
- **Cosmetics.** Hunter / shadow-army skins, weapon & aura effects — pure vanity.

**The one hard line: you cannot buy EXP / hunter level.** Level comes *only* from real exercise (§4), and it gates gate-rank access and a core slice of power. So money buys **pace and build** (Essence, tickets) and **looks** (cosmetics) — never your level. Show up and train, or you don't rank up. **No loot boxes.**

**Retention philosophy — no dark patterns.** No daily-login streaks, spin-wheels, energy timers, or engagement-bait. People should open the game because it's *good*, not because a mechanic guilt-trips them. Retention is earned through quality — a loop worth coming back to.

**Guardrails:** money buys **build acceleration** (Essence), **convenience** (tickets), and **looks** (cosmetics) — but **can't buy hunter level** (exercise-only), so it never fully replaces training; **health-first** — never monetize in a way that pressures unhealthy over-exercising.

**⚠ Critical interaction with content (§14b):** microtransactions make this a *commercial product*, which massively raises the stakes on using anyone else's IP. Free fan games get cease-and-desists; paid ones get lawsuits. This is why content must be original-named (see below).

## 14b. Content bible (original, inspired-by)

**Approach:** Solo Leveling is the *reference* for structure and archetypes only. All named content below is **original** — safe to monetize and distribute. This is a seed roster; expand as needed. (Generic genre terms — *hunter, gate, dungeon, rank E–S, shadow* — are free to use; only specific names/characters/designs must be original.)

### Fiction & terminology (original names; all swappable)
- **The Ascendancy** — the in-fiction leveling force (replaces the "System"). Grants levels, stats, and the extraction power.
- **CLAIM** — the extraction command/moment when you bind a defeated monster into a shadow (replaces the placeholder "Arise" wording used earlier in the doc).
- **The Umbral Host** — collective name for your shadow army; individual soldiers are **Wraiths**.
- **Working title:** "Shadow Hunter" is a placeholder — run a trademark/name check before launch (many games use it).

### Creature families by rank (original archetypes)
| Rank | Family | Flavor |
|:----:|--------|--------|
| E–D | **Hollow Brood** | insectoid hive swarm — chittering, chitinous |
| E–D | **Gravekin** | feral tusked beastfolk raiders |
| C–B | **Ashen Wardens** | armored undead knights, cold and disciplined |
| C–B | **Rime Sylphs** | frost fae, fragile but fast |
| A | **Emberdrakes** | lesser dragons, fire/aerial |
| A | **Abyssal Fiends** | lesser demons of the deep gates |
| S | **Apex** | unique bosses (see below) |

### Signature bosses & the shadows they yield (original examples)
- **Kaeric, the First Warden** — an Ashen Warden knight; an early A-rank boss and the first *elite* Wraith you can CLAIM (your disciplined vanguard).
- **Xir'Vok, Brood Sovereign** — the Hollow Brood hive-king; a swarm-commander Wraith that buffs your smaller shadows.
- **The Pale Sovereign** — S-rank demon king, boss of the signature raid.
- **Vharûn, the Cinder Wyrm** — S-rank apex dragon, endgame raid target.

### Signature raid
- **The Nadir** — the endgame **raid tower**: a single persistent, whole-army floor-climb and the endgame ladder (full design in §20), culminating in the Pale Sovereign on a deep boss floor.

### Regions / gate themes (seed)
Broodlands (insectoid), the Ashen March (undead knights), Rimefell (frost), the Ember Reaches (dragons), the Abyss Gates (demons) — each themes the monsters, palette, and loot of gates that spawn there.

### Design rule: influence, don't splice
Draw on many sources as a *mood board* (Solo Leveling's tone, Dragon Quest's iconic legible silhouettes, folklore, etc.), then design creatures that don't point back to any one specific protected character. **Never** combine specific copyrighted characters (e.g. "2/3 character X + 1/3 monster Y") — that's a derivative of *both* and infringes both. Ratios don't matter; recognizability does. The test: could anyone name the source character it came from? If yes, redesign. Borrow *sensibilities* (clean silhouettes + dark arcane palette), not characters.

### Classes (gate equipment loadouts)
Every monster — and therefore its shadow — has a **class**. **Classes matter for exactly two things:** (1) **gear gating** — a caster can't hold a greatsword, a bruiser can't wear robes, so gearing each shadow is a small puzzle; and (2) the **gate-squad class slots** (§17) — one of each class + a flex, which forces a balanced team and a reason to collect all five. Combat itself is just summed power (§30), so classes deliberately carry **no** combat-role mechanics — those two jobs are enough.

| Class | Role | Weapons | Armor | Stat lean |
|-------|------|---------|-------|-----------|
| **Warrior** | melee DPS / bruiser | blades, axes, maces | heavy | STR / VIT |
| **Guardian** | tank / wall | shields, spears, greatshields | heaviest | VIT / END |
| **Assassin** | fast burst (melee or dive) | daggers, claws, light blades | light | AGI / STR |
| **Mage** | ranged / elemental / DoT | staves, tomes, orbs | robes | SEN |
| **Support** | buff / summon / control | banners, totems, relics | medium | SEN / VIT |

Data: `MonsterDef.clazz` and `ShadowInstance` (inherits from its `MonsterDef`) carry the class; `EquipmentDef.allowed_classes` gates what fits. **The hunter** is a **Necromancer** (base shadow-commander class) with a freely-chosen, permanent **subclass** = one of these same five — it gates the hunter's own 7-slot gear, sets their stat profile (§16), and defines their 1.5× signature training (§4). Full detail in §21.

**Class assignments (all ~61):**
- **Warrior (16):** Grubmaw, Ashen Warden, Tuskrend, Hivewarden, Kaeric, Gravemarch Footman, Tarling, Grublet, Mudtusk, Nipclaw, Rotknight, Boartusk, Gnollpike, Direwarden, Glacial Revenant, Ur-Grakh
- **Guardian (6):** Carapax, Sepulcher Knight, Hollowhorn, Tarhulk, Beetlback, Ashen Cataphract
- **Assassin (15):** Runtclaw, Cindervane, Frostquill, Bonegnasher, Ashwing, Dreadmaw, Gloamwing, Bonerat, Duskmaw, Cryptrat Swarm, Grimhound, Broodlancer, Glimmerhound, Emberling, Duskdrake
- **Mage (18):** Cindermaw Drake, Hoarfrost Matron, Voidcaller, Vharûn, The Pale Sovereign, Sporecrawler, Glacewisp, Cindergnat, Mirewisp, Sporebloat, Palewisp, Sporelord, Frostbite Sylph, Grinlet, Cindercreep, Fiendlord, Rimewarden Sovereign, Nyxaris
- **Support (6):** Warhowl, Xir'Vok, Snarlpack Alpha, Broodqueen Vassal, Broodmother, Ashen Lord Commander

> **Elements cut.** The `element` field (Blight/Dread/Frost/…) was flavor only with no combat effect, so it's removed. The **Family** already conveys a monster's theme — any `element` / `Elem` values shown in the roster below are **deprecated and ignored**.

### Fleshed-out roster (first entries)
```
MonsterDef  Grubmaw
  id: "mon_grubmaw"; rank: E; element: "Blight"
  base_power: 120;  extract_chance: 0.40
  loot_table_id: "loot_common_e"
  sprite_id: "spr_grubmaw"; portrait_id: "por_grubmaw"
  # teardrop larva, one giant toothy maw; charcoal-violet shell, cyan maw-glow
  # shadow: cheap swarm token, minor army power in bulk

MonsterDef  Ashen Warden
  id: "mon_ashen_warden"; rank: C; element: "Dread"
  base_power: 900;  extract_chance: 0.15
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_ashen_warden"; portrait_id: "por_ashen_warden"
  # tall skeletal knight, greatsword + hollow helm; ash plate, violet eye-lights & runes
  # shadow: frontline vanguard Wraith — first real elite you can CLAIM

MonsterDef  Cindervane
  id: "mon_cindervane"; rank: A; element: "Ember"
  base_power: 4500; extract_chance: 0.06
  loot_table_id: "loot_rare_a"
  sprite_id: "spr_cindervane"; portrait_id: "por_cindervane"
  # compact wyvern, membrane wings + crest; obsidian scales, arcane violet-cyan ember cracks
  # shadow: aerial striker Wraith, strong in raids

MonsterDef  Tuskrend
  id: "mon_tuskrend"; rank: D; element: "Feral"
  base_power: 350; extract_chance: 0.25
  loot_table_id: "loot_common_d"
  sprite_id: "spr_tuskrend"; portrait_id: "por_tuskrend"
  # hunched tusked brute, bone cleaver; ashen hide, violet warpaint, cyan eyes
  # shadow: cheap frontline muscle, soaks hits for squishier shadows

# === ECOLOGY: few super-common species at the bottom; variety rises with rank; S = unique bosses ===
# (Existing above: Grubmaw E, Tuskrend D, Ashen Warden C, Cindervane A.)
# Exotic families (Rime Sylphs, Emberdrakes, Abyssal Fiends) only appear from rank C up —
# beginner E/D gates stay mundane (Brood, Gravekin, Ashen).

# --- Rank E (only 2 species, super common, seen constantly) ---
MonsterDef  Runtclaw
  id: "mon_runtclaw"; rank: E; element: "Feral"
  base_power: 200; extract_chance: 0.40
  loot_table_id: "loot_common_e"
  sprite_id: "spr_runtclaw"; portrait_id: "por_runtclaw"
  # small hunched scavenger, darts in and bites; ashen hide, cyan eyes
  # SUPER COMMON. shadow: fast cheap chip, swarm filler

# --- Rank D (only 3 species, common) ---
MonsterDef  Carapax
  id: "mon_carapax"; rank: D; element: "Blight"
  base_power: 500; extract_chance: 0.24
  loot_table_id: "loot_common_d"
  sprite_id: "spr_carapax"; portrait_id: "por_carapax"
  # armored beetle, tucks into a rolling ball; charcoal shell, violet seams
  # COMMON. shadow: tanky wall, blocks a lane

MonsterDef  Gravemarch Footman
  id: "mon_gravemarch_footman"; rank: D; element: "Dread"
  base_power: 450; extract_chance: 0.24
  loot_table_id: "loot_common_d"
  sprite_id: "spr_gravemarch_footman"; portrait_id: "por_gravemarch_footman"
  # lesser skeletal soldier, rusted spear + torn tabard; ash bone, faint violet glow
  # COMMON. shadow: cheap disposable frontline

# --- Rank C (variety opens up) ---
MonsterDef  Sporecrawler
  id: "mon_sporecrawler"; rank: C; element: "Blight"
  base_power: 1050; extract_chance: 0.13
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_sporecrawler"; portrait_id: "por_sporecrawler"
  # bloated many-legged crawler leaking spores; sickly cyan gut-glow
  # shadow: damage-over-time, poison cloud

MonsterDef  Bonegnasher
  id: "mon_bonegnasher"; rank: C; element: "Feral"
  base_power: 1200; extract_chance: 0.13
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_bonegnasher"; portrait_id: "por_bonegnasher"
  # hyena-like pack alpha, jaw too big for its skull; violet warpaint
  # shadow: bleed striker, hunts wounded targets

MonsterDef  Glacewisp
  id: "mon_glacewisp"; rank: C; element: "Frost"
  base_power: 950; extract_chance: 0.14
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_glacewisp"; portrait_id: "por_glacewisp"
  # small drifting frost fae, ring of ice shards; pale cyan, violet core
  # shadow: ranged shard volley

MonsterDef  Ashwing
  id: "mon_ashwing"; rank: C; element: "Ember"
  base_power: 1300; extract_chance: 0.12
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_ashwing"; portrait_id: "por_ashwing"
  # juvenile drake, oversized wings, gangly; obsidian scale, violet ember cracks
  # shadow: aerial striker (weaker Cindervane)

MonsterDef  Dreadmaw
  id: "mon_dreadmaw"; rank: C; element: "Abyss"
  base_power: 1150; extract_chance: 0.13
  loot_table_id: "loot_uncommon_c"
  sprite_id: "spr_dreadmaw"; portrait_id: "por_dreadmaw"
  # eyeless abyssal hound, split jaw, smoking hide; charcoal + violet maw-light
  # shadow: pursuit striker, closes distance fast

# --- Rank B ---
MonsterDef  Frostquill
  id: "mon_frostquill"; rank: B; element: "Frost"
  base_power: 2200; extract_chance: 0.10
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_frostquill"; portrait_id: "por_frostquill"
  # slender floating fae, icicle limbs + crystalline wings; ice-white/cyan, violet core
  # glass cannon. shadow: fast striker that chills/slows enemies

MonsterDef  Hivewarden
  id: "mon_hivewarden"; rank: B; element: "Blight"
  base_power: 2400; extract_chance: 0.09
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_hivewarden"; portrait_id: "por_hivewarden"
  # soldier-caste brood, twin scythe-arms, plated thorax; violet chitin, cyan joints
  # shadow: frontline bruiser

MonsterDef  Warhowl
  id: "mon_warhowl"; rank: B; element: "Feral"
  base_power: 2600; extract_chance: 0.08
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_warhowl"; portrait_id: "por_warhowl"
  # hulking Gravekin chieftain, trophy-bone armor, war banner; violet paint
  # shadow: warcry buffs allied shadows' attack

MonsterDef  Sepulcher Knight
  id: "mon_sepulcher_knight"; rank: B; element: "Dread"
  base_power: 2300; extract_chance: 0.09
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_sepulcher_knight"; portrait_id: "por_sepulcher_knight"
  # elite Ashen Warden with tower greatshield; ash plate, dense violet runes
  # shadow: tanky guardian, protects the Host

MonsterDef  Cindermaw Drake
  id: "mon_cindermaw_drake"; rank: B; element: "Ember"
  base_power: 2700; extract_chance: 0.08
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_cindermaw_drake"; portrait_id: "por_cindermaw_drake"
  # mature drake, heavy jaw, breath-cone attack; obsidian scale, bright violet-cyan glow
  # shadow: AoE aerial striker

MonsterDef  Hollowhorn
  id: "mon_hollowhorn"; rank: B; element: "Abyss"
  base_power: 2500; extract_chance: 0.08
  loot_table_id: "loot_uncommon_b"
  sprite_id: "spr_hollowhorn"; portrait_id: "por_hollowhorn"
  # horned demon brute, cracked stone skin, molten violet core; hulking silhouette
  # shadow: heavy frontline, high HP

# --- Rank A (elites) ---
MonsterDef  Hoarfrost Matron
  id: "mon_hoarfrost_matron"; rank: A; element: "Frost"
  base_power: 4000; extract_chance: 0.06
  loot_table_id: "loot_rare_a"
  sprite_id: "spr_hoarfrost_matron"; portrait_id: "por_hoarfrost_matron"
  # greater frost fae, regal, trailing blizzard veil; ice-white + deep violet
  # shadow: AoE slow across the enemy line

MonsterDef  Kaeric, the First Warden
  id: "mon_kaeric"; rank: A; element: "Dread"
  base_power: 3500; extract_chance: 0.05
  loot_table_id: "loot_rare_a"
  sprite_id: "spr_kaeric"; portrait_id: "por_kaeric"
  # NAMED elite Ashen Warden commander, crowned helm, twin blades; ornate violet runes
  # shadow: vanguard commander — first true elite Wraith (buffs frontline)

MonsterDef  Voidcaller
  id: "mon_voidcaller"; rank: A; element: "Abyss"
  base_power: 4200; extract_chance: 0.05
  loot_table_id: "loot_rare_a"
  sprite_id: "spr_voidcaller"; portrait_id: "por_voidcaller"
  # robed demon sorcerer, floating, ringed by sigils; charcoal robe, violet sigil-light
  # shadow: summons lesser fiends in raids

# --- Rank S (unique named bosses; very rare to CLAIM) ---
MonsterDef  Xir'Vok, Brood Sovereign
  id: "mon_xirvok"; rank: S; element: "Blight"
  base_power: 9000; extract_chance: 0.03
  loot_table_id: "loot_epic_s"
  sprite_id: "spr_xirvok"; portrait_id: "por_xirvok"
  # colossal hive-king, crowned carapace, many limbs; violet chitin, cyan brood-glow
  # shadow: buffs ALL your smaller shadows (swarm commander)

MonsterDef  Vharûn, the Cinder Wyrm
  id: "mon_vharun"; rank: S; element: "Ember"
  base_power: 12000; extract_chance: 0.02
  loot_table_id: "loot_epic_s"
  sprite_id: "spr_vharun"; portrait_id: "por_vharun"
  # apex dragon, vast wings, molten violet-cyan veins; endgame raid target
  # shadow: devastating aerial nuke

MonsterDef  The Pale Sovereign
  id: "mon_pale_sovereign"; rank: S; element: "Abyss"
  base_power: 13000; extract_chance: 0.02
  loot_table_id: "loot_epic_s"
  sprite_id: "spr_pale_sovereign"; portrait_id: "por_pale_sovereign"
  # demon king, pale crowned figure wreathed in violet flame; Nadir boss
  # shadow: ultimate Wraith — the capstone of the Host
```

### Expanded roster (batch 2 — bottom-heavy fill to ~60 total)
Fills out the common tiers so encounters are mostly low-rank, with rares staying rare. Two new **common fodder families** added: **Tarlings** (shadow-tar oozes, Blight — slime-simple silhouettes) and **Gloamwing** (leathery bats/vermin, Dread).

*Conventions for this batch:* `loot_table_id` by rank — E `loot_common_e`, D `loot_common_d`, C `loot_uncommon_c`, B `loot_uncommon_b`, A `loot_rare_a`, S `loot_epic_s`. `sprite_id` = `spr_<id>`, `portrait_id` = `por_<id>`. Every monster's **shadow form** is gained via CLAIM — no separate data; the Notes column is that shadow's role.

**Rank E (super-common fodder):**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Tarling | mon_tarling | Tarlings | Blight | 110 | 0.45 | shadow-tar blob, one violet eye; expendable chip |
| Grublet | mon_grublet | Hollow Brood | Blight | 160 | 0.40 | tiny Grubmaw cousin; swarm chip |
| Cindergnat | mon_cindergnat | Hollow Brood | Blight | 150 | 0.40 | ember-mote gnat; ranged-spit chip |
| Gloamwing | mon_gloamwing | Gloamwing | Dread | 130 | 0.42 | small leathery bat; evasive flyer |
| Bonerat | mon_bonerat | Ashen Wardens | Dread | 120 | 0.44 | skeletal vermin; filler |
| Mirewisp | mon_mirewisp | Ashen Wardens | Dread | 100 | 0.45 | pale drifting spirit-mote; distraction |
| Mudtusk | mon_mudtusk | Gravekin | Feral | 180 | 0.40 | piglet-brute runt; cheap charger |
| Nipclaw | mon_nipclaw | Gravekin | Feral | 210 | 0.38 | crab scuttler, pincers; chip |

**Rank D (common):**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Tarhulk | mon_tarhulk | Tarlings | Blight | 420 | 0.26 | bigger ooze, splits when hit; tanky splitter |
| Beetlback | mon_beetlback | Hollow Brood | Blight | 500 | 0.24 | spiked armored beetle; wall |
| Sporebloat | mon_sporebloat | Hollow Brood | Blight | 600 | 0.22 | bloated spore-sac, bursts on death; DoT bomb |
| Duskmaw | mon_duskmaw | Gloamwing | Dread | 480 | 0.24 | dire bat, screech; flyer striker |
| Rotknight | mon_rotknight | Ashen Wardens | Dread | 560 | 0.23 | decayed foot knight; frontline |
| Cryptrat Swarm | mon_cryptrat | Ashen Wardens | Dread | 380 | 0.26 | pack of bone-vermin; swarm |
| Palewisp | mon_palewisp | Ashen Wardens | Dread | 350 | 0.27 | draining spirit-mote; leech |
| Boartusk | mon_boartusk | Gravekin | Feral | 520 | 0.24 | boar-brute, gore charge; charger |
| Gnollpike | mon_gnollpike | Gravekin | Feral | 540 | 0.23 | hyena-kin spearman; reach frontline |
| Grimhound | mon_grimhound | Gravekin | Feral | 470 | 0.24 | feral hound; pursuit |

**Rank C (variety):**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Sporelord | mon_sporelord | Hollow Brood | Blight | 1100 | 0.13 | mushroom-crowned brood; spore cloud DoT |
| Broodlancer | mon_broodlancer | Hollow Brood | Blight | 1200 | 0.13 | mantis impaler; piercing striker |
| Direwarden | mon_direwarden | Ashen Wardens | Dread | 1300 | 0.12 | heavy undead knight, mace; frontline |
| Snarlpack Alpha | mon_snarlpack | Gravekin | Feral | 1350 | 0.12 | beastfolk warleader; pack buffer |
| Frostbite Sylph | mon_frostbite_sylph | Rime Sylphs | Frost | 1000 | 0.14 | biting frost fae; ranged frost |
| Glimmerhound | mon_glimmerhound | Rime Sylphs | Frost | 980 | 0.14 | ice-hound; fast frost striker |
| Emberling | mon_emberling | Emberdrakes | Ember | 1250 | 0.12 | wyrmling; aerial chip |
| Grinlet | mon_grinlet | Abyssal Fiends | Abyss | 1150 | 0.13 | cackling imp, teleports; evasive caster |
| Cindercreep | mon_cindercreep | Abyssal Fiends | Abyss | 1400 | 0.12 | crawling ember-demon; burn DoT |

**Rank B:**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Broodqueen Vassal | mon_broodqueen_vassal | Hollow Brood | Blight | 2450 | 0.09 | royal-guard brood; summons grubs |
| Ashen Cataphract | mon_ashen_cataphract | Ashen Wardens | Dread | 2500 | 0.09 | mounted heavy knight; charging tank |
| Glacial Revenant | mon_glacial_revenant | Rime Sylphs | Frost | 2600 | 0.08 | towering ice-fae warrior; frost bruiser |
| Duskdrake | mon_duskdrake | Emberdrakes | Ember | 2650 | 0.08 | night-hunting drake; aerial ambusher |
| Fiendlord | mon_fiendlord | Abyssal Fiends | Abyss | 2800 | 0.08 | greater horned demon commander; frontline caster |

**Rank A (elites):**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Broodmother | mon_broodmother | Hollow Brood | Blight | 3800 | 0.06 | massive egg-layer; continuous summon |
| Rimewarden Sovereign | mon_rimewarden_sovereign | Rime Sylphs | Frost | 4100 | 0.05 | frost-fae royalty; AoE freeze |
| Ashen Lord Commander | mon_ashen_lord_commander | Ashen Wardens | Dread | 3900 | 0.05 | undead general; army-wide buff |

**Rank S (unique bosses):**
| Name | id | Family | Elem | Power | Extract | Notes / shadow role |
|------|----|--------|------|------:|:-------:|---------------------|
| Ur-Grakh, the Bonemarch King | mon_ur_grakh | Gravekin | Feral | 10000 | 0.02 | colossal warlord of the dead hordes; buffs all frontline |
| Nyxaris, the Hollow Star | mon_nyxaris | Abyssal Fiends | Abyss | 14000 | 0.02 | void-entity apex, endgame; reality-tearing nuke |

**Roster total now ~61**, distributed bottom-heavy: E 10 · D 13 · C 15 · B 11 · A 7 · S 5. Commons (E+D+C) are ~62% of species, so encounters skew low-rank as intended.

*Everything here is a starting seed — add families, bosses, and regions as the game grows.*

---

## 15. Equipment, loot crates & sets

### Slots (standard; same for hunter and shadows)
Six functional slots + one cosmetic:
**Weapon · Head · Body · Hands · Feet · Accessory** — plus **Aura** (cosmetic, the Solo-Leveling flair; a good premium/cosmetic surface).
Each shadow and the hunter have one of each. Gear raises stats via `stat_mods` and adds `power_bonus`.

### Class gating (from §14b classes)
- **Weapon type** is class-locked: Warrior blades/axes/maces · Guardian shields/spears · Assassin daggers/claws · Mage staves/tomes/orbs · Support banners/totems/relics.
- **Armor weight** (Head/Body/Hands/Feet) matches class: heavy (Warrior/Guardian), light (Assassin), robes (Mage), medium (Support).
- **Accessory + Aura** are universal.
`EquipmentDef.allowed_classes` enforces it. A staff literally can't be slotted on a Warrior.

### Rarity → power (scales with gate rank/source)
| Rarity | Drops from | ~power_bonus | Stat mods |
|--------|-----------|-------------:|-----------|
| Common | E/D gates | +10–30 | 1 small |
| Uncommon | C gates | +40–80 | 1–2 |
| Rare | B gates | +100–200 | 2 |
| Epic | A gates | +300–500 | 2–3 |
| Legendary | S gates / raids | +700–1200 | 3 + often a `set_id` |

### Example gear (illustrative)
```
Rendspike Greataxe   WEAPON  Rare      [Warrior]   +STR, power+160
Ashplate Cuirass     BODY    Uncommon  [Warrior,Guardian]  +VIT, power+60
Warden's Bulwark     WEAPON  Epic      [Guardian]  +VIT +END, power+380
Twin Fangs           WEAPON  Rare      [Assassin]  +AGI +STR, power+150
Gloamstep Boots      FEET    Uncommon  [Assassin]  +AGI, power+55
Blightwood Staff     WEAPON  Uncommon  [Mage]      +SEN, power+70
Sovereign's Grimoire WEAPON  Legendary [Mage]      +SEN big, power+950, set: obsidian_keep
Bonemarch Banner     WEAPON  Epic      [Support]   +SEN, allied-shadow buff, power+300
```

### Base equipment catalogue (50 pieces — 10 per class)
*Conventions: `target: BOTH` (hunter or shadow); `allowed_classes` = the section's class; `sprite_id` = `spr_<id>`; stat mods use STR/AGI/VIT/END/SEN; power = `power_bonus`.*

**Warrior (STR/VIT — blades/axes/maces, heavy):**
| Name | id | Slot | Rarity | Stat mods | Power |
|------|----|------|--------|-----------|------:|
| Warcleaver | eq_warcleaver | WEAPON | Common | STR+3 | +25 |
| Gravebite Greataxe | eq_gravebite_greataxe | WEAPON | Rare | STR+9, VIT+4 | +170 |
| Ironbrow Helm | eq_ironbrow_helm | HEAD | Uncommon | VIT+5 | +60 |
| Ashplate Cuirass | eq_ashplate_cuirass | BODY | Uncommon | VIT+7 | +70 |
| Juggernaut Plate | eq_juggernaut_plate | BODY | Epic | STR+10, VIT+14 | +420 |
| Bruiser's Gauntlets | eq_bruiser_gauntlets | HANDS | Common | STR+2 | +22 |
| Trampling Sabatons | eq_trampling_sabatons | FEET | Rare | VIT+8, STR+5 | +150 |
| Marching Greaves | eq_marching_greaves | FEET | Uncommon | END+5 | +55 |
| Berserker's Signet | eq_berserker_signet | ACCESSORY | Rare | STR+11 | +160 |
| Warlord's Torc | eq_warlord_torc | ACCESSORY | Epic | STR+14, VIT+10 | +400 |

**Guardian (VIT/END — shields/spears, heaviest):**
| Name | id | Slot | Rarity | Stat mods | Power |
|------|----|------|--------|-----------|------:|
| Bulwark Shield | eq_bulwark_shield | WEAPON | Common | VIT+3 | +25 |
| Aegis Wall | eq_aegis_wall | WEAPON | Rare | VIT+10, END+6 | +180 |
| Warden's Barbute | eq_wardens_barbute | HEAD | Uncommon | END+6 | +60 |
| Sentinel Cuirass | eq_sentinel_cuirass | BODY | Uncommon | VIT+8 | +70 |
| Immovable Plate | eq_immovable_plate | BODY | Epic | VIT+18, END+10 | +450 |
| Ramguard Gauntlets | eq_ramguard_gauntlets | HANDS | Common | VIT+3 | +24 |
| Rootstep Greaves | eq_rootstep_greaves | FEET | Rare | END+9, VIT+6 | +150 |
| Anchor Sabatons | eq_anchor_sabatons | FEET | Uncommon | END+6 | +58 |
| Stoneheart Charm | eq_stoneheart_charm | ACCESSORY | Rare | VIT+12 | +160 |
| Bastion Sigil | eq_bastion_sigil | ACCESSORY | Epic | VIT+15, END+12 | +410 |

**Assassin (AGI/STR — daggers/claws, light):**
| Name | id | Slot | Rarity | Stat mods | Power |
|------|----|------|--------|-----------|------:|
| Shadowfang Dagger | eq_shadowfang_dagger | WEAPON | Common | AGI+3 | +25 |
| Twin Fangs | eq_twin_fangs | WEAPON | Rare | AGI+9, STR+5 | +170 |
| Gloamhood | eq_gloamhood | HEAD | Uncommon | AGI+5 | +60 |
| Nightweave Vest | eq_nightweave_vest | BODY | Uncommon | AGI+6 | +65 |
| Phantom Leathers | eq_phantom_leathers | BODY | Epic | AGI+14, STR+8 | +400 |
| Silent Grips | eq_silent_grips | HANDS | Common | AGI+2 | +22 |
| Gloamstep Boots | eq_gloamstep_boots | FEET | Rare | AGI+10 | +150 |
| Fleetfoot Shoes | eq_fleetfoot_shoes | FEET | Uncommon | AGI+5 | +55 |
| Killer's Band | eq_killers_band | ACCESSORY | Rare | AGI+11 | +160 |
| Umbral Pendant | eq_umbral_pendant | ACCESSORY | Epic | AGI+13, STR+9 | +400 |

**Mage (SEN — staves/tomes/orbs, robes):**
| Name | id | Slot | Rarity | Stat mods | Power |
|------|----|------|--------|-----------|------:|
| Blightwood Wand | eq_blightwood_wand | WEAPON | Common | SEN+3 | +25 |
| Cindercore Staff | eq_cindercore_staff | WEAPON | Rare | SEN+12 | +180 |
| Seer's Cowl | eq_seers_cowl | HEAD | Uncommon | SEN+6 | +60 |
| Runespun Robe | eq_runespun_robe | BODY | Uncommon | SEN+7 | +70 |
| Archon Vestments | eq_archon_vestments | BODY | Epic | SEN+20 | +430 |
| Channeler's Gloves | eq_channelers_gloves | HANDS | Common | SEN+3 | +22 |
| Wraithsilk Slippers | eq_wraithsilk_slippers | FEET | Rare | SEN+9, AGI+4 | +150 |
| Wanderer's Sandals | eq_wanderers_sandals | FEET | Uncommon | SEN+5 | +55 |
| Mana Sigil | eq_mana_sigil | ACCESSORY | Rare | SEN+12 | +160 |
| Oracle's Eye | eq_oracles_eye | ACCESSORY | Epic | SEN+16 | +400 |

**Support (SEN/VIT — banners/totems/relics, medium):**
| Name | id | Slot | Rarity | Stat mods | Power |
|------|----|------|--------|-----------|------:|
| Rally Totem | eq_rally_totem | WEAPON | Common | SEN+3 | +25 |
| Bonemarch Banner | eq_bonemarch_banner | WEAPON | Rare | SEN+9, VIT+4 | +170 |
| Chaplain's Hood | eq_chaplains_hood | HEAD | Uncommon | SEN+5, VIT+3 | +60 |
| Warden-Priest Robe | eq_wardenpriest_robe | BODY | Uncommon | VIT+6, SEN+4 | +70 |
| Hierophant Vestments | eq_hierophant_vestments | BODY | Epic | SEN+14, VIT+12 | +420 |
| Blessing Gloves | eq_blessing_gloves | HANDS | Common | SEN+2 | +22 |
| Shepherd's Treads | eq_shepherds_treads | FEET | Rare | VIT+7, SEN+5 | +150 |
| Acolyte Sandals | eq_acolyte_sandals | FEET | Uncommon | SEN+5 | +55 |
| Wardsong Charm | eq_wardsong_charm | ACCESSORY | Rare | SEN+11 | +160 |
| Aegis of the Host | eq_aegis_of_the_host | ACCESSORY | Epic | SEN+13, VIT+10 | +400 |

### Set bonuses (grind the same content to complete)
Sets are themed to a **region or raid**, and their pieces only drop from that content — so completing one means repeated runs (exactly the grind hook you wanted). Equipping 2 / 4 / 6 pieces unlocks escalating bonuses.

```
SetDef  Nadir Regalia          # drops from the Nadir raid / Pale Sovereign
  id: "set_obsidian_keep"
  piece_ids: [ ...6 legendary pieces... ]
  bonuses:
    2: power +5%
    4: power +10%, shadow max-HP +15%
    6: power +20%, + signature effect: "revive one fallen shadow at raid start"
  source: "raid_obsidian_keep"
```
Seed sets, one per region/raid: **Broodlands, Ashen March, Rimefell, Ember Reaches, Abyss Gates, Nadir.** Each grindable from its own gates/raid.

### Armor sets (15 — 3 per class, tiered D / B / S)
Each class has **three** sets at rising tiers, so there's a set worth chasing at every stage:
- **D set (early)** — pieces **Rare**, modest bonuses; from D-rank gates.
- **B set (mid)** — pieces **Epic**, strong bonuses; from B-rank gates/raids.
- **S set (endgame)** — pieces **Legendary**, build-defining; from S raids.

Each set = 4 armor pieces (Head / Body / Hands / Feet) sharing a `set_id`, **class-locked**, dropping **only** from its source — completing one means repeated runs. Bonuses at 2 and 4 pieces (pieces also carry big base stats per their rarity tier).
*Convention: pieces = `eq_<setid>_head/body/hands/feet`; `sprite_id` = `spr_<piece id>`.*

**Warrior:**
| Tier | Set | set_id | Source | 2-piece | 4-piece |
|:----:|-----|--------|--------|---------|---------|
| D | Ashen Vanguard Plate | set_ashen_vanguard_plate | Ashen March (D gates) | VIT+6 | +6% power while frontline |
| B | Emberforged Regalia | set_emberforged_regalia | Ember Reaches (B gates) | STR+12 | attacks add ember damage; +10% power |
| S | Bonemarch Warplate | set_bonemarch_warplate | Ur-Grakh raid (S) | STR+22, VIT+12 | +15% melee power; rage stacks through the fight |

**Guardian:**
| Tier | Set | set_id | Source | 2-piece | 4-piece |
|:----:|-----|--------|--------|---------|---------|
| D | Warden's Eternal Guard | set_wardens_eternal_guard | Ashen March (D gates) | VIT+7 | block chance up; shadows behind take less damage |
| B | Rimefell Aegis | set_rimefell_aegis | Rimefell (B gates) | END+12 | frost shield absorbs one hit each turn; +8% power |
| S | Obsidian Bastion | set_obsidian_bastion | Nadir raid (S) | VIT+26, END+14 | +20% max HP; taunt pulls enemy focus off allies |

**Assassin:**
| Tier | Set | set_id | Source | 2-piece | 4-piece |
|:----:|-----|--------|--------|---------|---------|
| D | Gloamstalker Garb | set_gloamstalker_garb | Gloamwing dens (D gates) | AGI+7 | +10% crit |
| B | Voidcreep Shroud | set_voidcreep_shroud | Abyss Gates (B) | AGI+12, STR+5 | attacks apply stacking bleed; +10% power |
| S | Cinderdance Leathers | set_cinderdance_leathers | Vharûn raid (S) | AGI+24 | first strike is a guaranteed crit; dodge grants a speed burst |

**Mage:**
| Tier | Set | set_id | Source | 2-piece | 4-piece |
|:----:|-----|--------|--------|---------|---------|
| D | Broodcaller Vestments | set_broodcaller_vestments | Broodlands (D gates) | SEN+7 | summon a weak spore-ally in raids |
| B | Hoarfrost Weave | set_hoarfrost_weave | Rimefell (B gates) | SEN+12 | spells slow on hit; +10% power |
| S | Sovereign's Regalia | set_sovereigns_regalia | Nadir / Pale Sovereign (S) | SEN+26 | +20% spell power; spells chain to a second target |

**Support:**
| Tier | Set | set_id | Source | 2-piece | 4-piece |
|:----:|-----|--------|--------|---------|---------|
| D | Sanctified Ward | set_sanctified_ward | Ashen March (D gates) | VIT+6, SEN+4 | small heal to your shadows each turn |
| B | Warhowl's Standard | set_warhowls_standard | Gravekin warbands / Warhowl (B) | SEN+12 | allied-shadow attack buff; +8% power |
| S | Hive-Sovereign Raiment | set_hive_sovereign_raiment | Xir'Vok raid (S) | SEN+22, VIT+12 | your smaller shadows gain big HP + attack |

### Loot & drops (no loot boxes)
Equipment and consumables drop **directly** from gates and raids via `LootTableDef` (rarity weighted by gate rank) — no crate/lootbox layer, by design. **Gate tickets** and **Essence** are the shop's paid items (§14) and also drop from play. The economy stays transparent: you can see exactly what a gate can give, and you earn it by clearing content.

### Consumables
```
ConsumableDef types:
  gate_ticket     — spawn a gate at your current location (§8a)
  exp_draught     — bonus EXP for a period
  claim_charm     — boosts extract_chance on the next clear
  shadow_balm     — revive/heal a shadow mid-raid
  gate_lure       — spawn/refresh a nearby gate
  # (shadow leveling + gear enhancement are paid in Essence — §26; no separate materials)
```

### Data-model additions (beyond §13)
```
Slot enum: WEAPON, HEAD, BODY, HANDS, FEET, ACCESSORY, AURA
EquipmentDef: + set_id, + source        (already added in §13)
SetDef:       id, name, piece_ids[], bonuses{threshold: effect}, source
ConsumableDef: id, name, type, effect, rarity, sprite_id
HunterState / ShadowInstance: equipped uses the 7 slots; hunter also holds
  consumables[] (incl. gate tickets) and essence/crystals.
```

---

## 16. Combat system — active party battle (v0, expect heavy tuning)

**LOCKED, replaces the old single power-check + RNG resolve.** Every encounter — gates *and* raids — is now real turn-based party combat: you + 3 chosen shadows vs the enemies, DQ/JRPG-style. Deliberate scope decision: this applies **everywhere**, not just bosses/raids (see the honest trade-off note in §18). Stats and gear still matter exactly as designed — they just feed real combat stats instead of a single comparison number.

### Party composition
- Your **squad of 6** (class-slotted, §17) stays your prepared roster — unchanged.
- For any given fight, you field a **party of 4**: yourself + **3 shadows chosen from your squad**.
- You pick your own moves each turn; shadows act automatically via class-role AI (below) — you never pick a shadow's move.

### Turn order & flow
- **Speed-based on AGI** — every combatant (your party + enemies) acts in descending AGI order, every round.
- **Your turn:** pick one unlocked move, pick a target (single, or all enemies for an AoE move).
- **Shadow turns:** automatic, per class-role priority (below) — every class can attack *and* has role-flavored moves, so nobody's a one-note bot.
- **Enemy turns:** grunts attack simply; bosses get an occasional telegraphed bigger hit (~2× a normal attack) every few turns, so S-rank bosses feel like S-rank bosses. Exact cadence: tune once playable.
- **Win:** all enemies to 0 HP. **Loss:** your party to 0 HP — no penalty, gate/floor stays, come back stronger. Same no-attrition philosophy as before.

### Moves — one moveset per class, used two ways
The same 5 movesets serve double duty: **you** pick manually from your own subclass's list; **shadows** of that class pick automatically from the same list (below). No duplicated design.

**Warrior** (STR) — 1. Strike (Lv1, basic hit) · 2. Power Strike (Lv3, heavier single-target) · 3. Cleave (Lv6, hits all enemies, lighter each) · 4. Rally Cry (Lv10, team attack buff) · 5. Execute (Lv15, big hit, bonus vs. low-HP enemies)

**Guardian** (VIT/END) — 1. Guard Strike (Lv1, basic hit) · 2. Taunt (Lv1, forces enemies to target this Guardian) · 3. Brace (Lv5, big self defense buff) · 4. Shield Ally (Lv8, soaks damage meant for a chosen ally) · 5. Fortress (Lv14, team-wide defense buff)

**Assassin** (AGI/STR) — 1. Quick Strike (Lv1, basic hit) · 2. Weaken (Lv3, lowers enemy defense) · 3. Poison Edge (Lv6, damage-over-time) · 4. Exploit Weakness (Lv10, bonus damage vs. debuffed enemies) · 5. Shadowstep Execute (Lv15, burst finisher)

**Mage** (SEN) — 1. Cyan Bolt (Lv1, single-target magic) · 2. Frost Nova (Lv4, small AoE) · 3. Arcane Barrage (Lv8, bigger single-target hit) · 4. Chain Lightning (Lv12, hits 2–3 targets) · 5. Nova Burst (Lv16, big AoE, on cooldown)

**Support** (SEN/VIT) — 1. Mend (Lv1, heal lowest-HP ally) · 2. Ward (Lv3, defense buff on an ally) · 3. Blessing (Lv6, small team heal/attack buff) · 4. Cleanse (Lv9, removes a debuff) · 5. Sanctuary (Lv14, strong team heal)

Stronger moves sit on a simple **cooldown-turns** system (e.g. "usable every 3 turns") rather than a mana/resource economy — one less number to track, consistent with how lean the rest of the systems are.

### Shadow AI — automatic, role-appropriate priority
- **Warrior:** finish low-HP enemies with Execute when available; Cleave into groups; otherwise attack the lowest-HP target.
- **Guardian:** keep Taunt active at all times; Brace when its own HP drops; Shield Ally on the lowest-HP teammate; Guard Strike otherwise.
- **Assassin:** debuff fresh (undebuffed) targets; finish already-debuffed/low-HP targets; Quick Strike otherwise.
- **Mage:** AoE when 2+ enemies are up; otherwise the strongest single-target spell available.
- **Support:** heal whoever's low; cleanse debuffs; buff proactively; **attack when the team's topped up and nothing else is needed** — Support isn't dead weight in an easy fight.

### Stats → combat math (v0, tunable — same spirit as the rest of this doc)
```
HP   = 50 + VIT×4 + END×2
PATK = 5 + STR×1.5
MATK = 5 + SEN×1.5
DEF  = END×0.5 + VIT×0.2
CRIT_CHANCE = min(35%, 5% + AGI×0.05%)   # Assassins crit noticeably more — reinforces their identity
SPEED = AGI                               # turn order
```
**Damage on hit:** `max(1, move_power × ATK/MATK − target_DEF) × variance(0.9–1.1) × (1.5 if crit)`
`move_power`: ~1.0 basics · 1.3–1.8 stronger moves · ~0.6–0.8 per target for AoE · 2.0–2.5 finishers.

**Worked example (Lv1 vs. Lv40 Warrior, using existing `stats_from`):**

| | Lv1 | Lv40 |
|---|---:|---:|
| HP | 82 | 1,350 |
| PATK | 20 | 605 |

~16× growth either side — early fights resolve in a handful of hits (good for a quick tap mid-walk); a Lv40 fight still feels dangerous.

### Enemy stats — derived from existing base_power / floor_power, not re-authored
Every monster already has a tuned `base_power` (§14b, Grubmaw=120 up to Xir'Vok=9000) and the Nadir already has a tuned floor curve (`floor_power(n) = 300 × 1.12^n`, §20). Rather than hand-authoring HP/ATK for 61 monsters (or every Nadir floor) from scratch, derive combat stats straight from those existing numbers:
```
enemy_HP  = base_power × 0.6
enemy_ATK = base_power × 0.15
```
This preserves every balancing decision already made in `monsters.json` and the Nadir floor curve — nothing gets re-authored, it's just reinterpreted as combat stats instead of a single compare-and-roll number. (Split ratios are v0/tunable, same as everything else here.)

### Army Synergy — how raids still reward your WHOLE collection
The original design deliberately made raids "a test of your army" (old `RAID_ARMY_WEIGHT` ×1.0) vs. gates being "a test of you" (×0.25). Real combat can't literally have 40 shadows all take a turn, so that philosophy now carries forward as a passive bonus instead of a literal power sum: **in raids/the Nadir, your full army beyond the 3 in your active party grants a passive stat bonus** to that party, scaling with total `army_power` (§16's old formula, still alive and useful as an input):
```
ARMY_SYNERGY (raids only, v0) = +1% party HP/PATK/MATK/DEF per 10,000 total army_power, capped at +50%
```
Gates get no synergy bonus — keeping "gates reward training, raids reward your collection" intact. This is the one deliberate, honest change from the original raid design: the Nadir no longer has your entire army physically fighting, but growing it still matters just as much, as a force-multiplier on the 4 who are.

### Auto-battle & Skip — keeping this workable mid-walk
Every fight, gate or raid, offers three ways to run it:
- **Manual** — pick your own moves and targets each turn.
- **Auto-battle** — the game picks your moves too, using the same role-priority logic as your shadows. One tap starts it, watch it resolve.
- **Skip** — auto-battle resolves instantly, results only.
This is what keeps a routine E-rank gate a genuine one-tap action even though the underlying resolution is now real combat, not a single dice roll — the trade-off named in §18.

### What this replaces vs. what's still alive
**Deprecated as the resolve mechanic:** `GATE_POWER`, `RAID_POWER`, `clear_probability`, `resolve_clear`, and `GATE_ARMY_WEIGHT`/`RAID_ARMY_WEIGHT` as literal power-sum weights.
**Still fully alive, now feeding combat instead of a single number:** `stats_from` + class profiles (below), `SQUAD_SIZE` (6), `personal_power`'s underlying stats, `shadow_power`'s base_power/level scaling (now a shadow's own HP/ATK), `floor_power` (now feeds Nadir enemy stat derivation), `CLAIM_*` (claim flow unchanged — still fires after winning a boss fight, §18).

### Class stat profiles (level → stats) — unchanged
Each level grants `STAT_POINTS_PER_LEVEL` (25) points, split by your subclass's profile. Every class still gains all five stats — just leaned:

| Class | STR | AGI | VIT | END | SEN |
|-------|----:|----:|----:|----:|----:|
| Warrior | 40% | 10% | 25% | 15% | 10% |
| Guardian | 20% | 5% | 35% | 30% | 10% |
| Assassin | 25% | 40% | 15% | 10% | 10% |
| Mage | 15% | 15% | 15% | 10% | 45% |
| Support | 20% | 10% | 25% | 15% | 30% |

`stats_from(level, class) = level × 25 × profile%`. E.g. a L20 Warrior ≈ STR 200 / VIT 125 / END 75 / AGI 50 / SEN 50.

---

## 16b. Battle screen — UI layout

The screen §16's combat system actually plays out on. Shared by **every** fight — gates, gate-breaks, and every Nadir floor — so it's built once and reused everywhere. Portrait mobile layout, top to bottom:

**1. Enemy row (top).** Up to 4 enemy slots — sprite/portrait, name, HP bar (current/max). A **telegraph icon** appears above a boss when its next turn is a big hit (§16), so you can see it coming, not just eat it. A gate run is still **up to 3 sequential sub-battles** (*trash → trash → boss*, unchanged `GateInstance` structure, §18) — each sub-battle populates this row fresh; exact enemy-count-per-round is a balance detail to tune once playable, not fixed here.

**2. Turn-order strip.** A slim horizontal row of small portraits (your party + enemies, AGI-sorted) showing the next few turns in sequence — standard JRPG convention, gives the telegraph icon above real weight ("boss goes in 2 turns").

**3. Battle stage (middle).** Mostly empty space — background is the "inside the gate" dark-fantasy world (§9b's world-separation: real world outside, near-black frost-cyan world within), not the map. Floating damage numbers pop here on hits (crits visually distinct — bigger/brighter), and a brief **System UI toast** (§9c, small tier) names the action taken — *"Ashen Warden used Taunt!"* — since shadow/enemy turns are automatic and still need to read clearly without full animation. Keeps faith with the original "no real animation, AI-art-friendly" philosophy — this is readable text + numbers + sprite flashes, not a fight choreography.

**4. Party row.** Your 4 combatants (you + 3 chosen shadows) — portrait, class icon, HP bar, cooldown pips on any move currently unavailable. The unit whose turn is active gets a highlight ring.

**5. Action bar (bottom, your turn only).** Your unlocked moves as a row of buttons (name + cooldown state). Tap a move → if it needs a target, enemy portraits highlight as tappable, tap one to resolve; AoE moves resolve immediately with no target tap. During shadow/enemy turns this area shows a simple **"[Name] is acting…"** state instead — no dead air, no player input possible.

**6. Always-available controls (corner, all turns).** **Auto-battle** toggle (AI plays your turns too, using your subclass's same role-priority logic as shadows) and **Skip** (resolves the rest instantly, straight to results) — both from §16, both critical to keeping a routine gate a one-tap action mid-walk.

**Transitions:** enters from the gate preview card (§18) or a Nadir "Take on floor" tap (§20); on win, hands off straight into the existing Results page (§18's CLAIM ceremony, unchanged).

**No new art required.** The existing preset-hunter portraits and monster portraits (already in the Midjourney pack) work directly as static battle-HUD icons — this screen is menu-driven, not directional/animated, so it doesn't need the separate "simpler battle/map sprite" asset type §9b originally flagged. A real scope-saver from the overhaul, not a cost.

---

## 17. Army management screen

**Vibe:** a clean, functional command menu — speed of management over spectacle.

**Roster — grouped by class.** Collapsible sections (Warrior / Guardian / Assassin / Mage / Support), each listing your shadows. **Sort/filter by grade (rank) and by power.**

**Gate squad — one squad, no presets, class-slotted.** A single team of 6 you maintain, with **fixed class slots: one each of Warrior · Guardian · Assassin · Mage · Support + 1 Flex** (any class). This *forces* a balanced comp and a reason to collect (and gear) every class. **Since the §16 combat overhaul, this now has real mechanical teeth** — for any fight, you pick **3 of these 6** to actually field (you + those 3 = your party of 4, §16), and a team missing a Guardian's taunt or a Support's heals genuinely plays worse, not just symbolically. Auto-optimize fills each slot with your strongest of that class; tweak by hand. Early on, empty slots are fine — fill them as you collect. *(Raids also draw their 3 from this squad — your wider army instead contributes the passive Army Synergy bonus, §16.)*

**Shadow detail (tap a shadow) — one hub with everything:**
- **Identity:** grade + level (with progress to cap), class/role, element, current power.
- **Inline gear (paper-doll):** equip/swap all 7 slots right here; class-gating enforced; one-tap **auto-equip best gear**.
- **Inline leveling:** spend **Essence** (and optionally feed a duplicate) to level up, in place.
- **Lore/flavor** at the bottom.

**Quality-of-life:**
- **Auto-equip best gear** — per shadow or across the whole squad.
- **Mass-convert** surplus/weak shadows into **Essence** (upgrade fuel).
- **Lock / favorite** — protect key shadows from mass-convert and flag favorites.

**Duplicates:** kept in the roster and **merged to level** the copy you're building (fuel toward the level cap).

**Raid readiness:** since raids are whole-army and automatic, just a small readout of total **RAID_POWER** — no per-raid roster management.

**Hunter gear (open):** the player's own loadout (the §14b open question) can live on a sibling **Hunter** tab using the same inline paper-doll — finalize once the hunter's class/loadout is decided.

---

## 18. Gate encounter screen & flow

**Superseded fight mechanic:** combat is now the active party battle system in §16 (you + 3 chosen shadows, real turns), not the old single power-check. Honest trade-off, decided deliberately: this trades some of the original "never stop walking" frictionlessness for a genuinely more engaging fight — offset by **Auto-battle** and **Skip** (§16), which keep a routine gate a one-tap action when you don't want to play it out.

**1. Gate preview (tap a gate on the map).** A card shows the gate's **rank** (E–S), the enemies you'll face (trash + boss, derived stats per §16), and your current party. You size it up and decide whether to engage, auto-battle, or skip.

**2. The run — active party battle.** Tap **Start** to enter the battle screen: you + your 3 chosen shadows vs. the gate's enemies (*trash → trash → boss*, §16's turn-based flow). Pick moves manually, or tap **Auto** (AI plays your turns too) or **Skip** (resolves instantly, results only) — same three modes either way.

**3. On loss.** You simply **walk away — the gate stays**. Retry when you're stronger. No penalty.

**4. Results page (on winning).**
- **CLAIM the boss** — a big dramatic prompt (§9c System UI ceremonial panel). Only the boss is claimable. **3 free RNG attempts**; chance rises with hunter level. Miss all three → no claim this run (gate stays, so you can retry).
  `claim_chance/try = min(CLAIM_CAP 0.90, boss.extract_chance + hunter_level × CLAIM_LEVEL_BONUS 0.01)`, over `CLAIM_TRIES 3` → overall `1 − (1−p)³`.
  Success → the boss joins your Host as a shadow (grade = boss's rank).
- **Loot** — gear, Essence, EXP earned, in a summary. Loot drops on clear **regardless** of the claim result.

**Notes:**
- Low gates just have a **trash-tier boss** (e.g. a Grubmaw), so early on you're claiming trash to seed the army — exactly right for common shadows.
- The **CLAIM charm** consumable can later be wired to boost odds if desired (currently the 3 tries are free).
- Data: a `GateInstance` carries `boss_id` (round 3) + `trash_ids` (rounds 1–2) — unchanged; they now resolve as real combat instead of a compare-and-roll.

---

## 19. Overworld / map screen

The home screen and the heart of the game's identity.

**Visual:** a **stylized dark-fantasy overlay** — real streets reskinned into the moody arcane world (recolored dark roads, low-light palette, glowing gate markers). Immersive and on-brand. Built on real map tiles + theming/shaders — more art work than a plain map, flagged.

**Player & movement:** foreground-only GPS (§11c). Your **hunter avatar** sits at your real location; the map shows the area around you. Gates are **anchored to real-world points of interest** near you — parks, landmarks, notable places pulled from OSM data — like Pokémon Go gyms, so the *world* places them rather than random spawn. Moving around your area surfaces different gates, but you **don't need to walk to a gate to use it** (no proximity requirement). *Design note: this makes fitness the power source (exercise → EXP → power, §4) rather than a hard gate on play — more accessible, softer GPS.*

**Gates on the map:**
- **POI-anchored, no pinpoint proximity** — gates sit on real POIs near you; tap any gate **within your local map view** to open its preview card (§18). You don't have to stand on it, but you can only reach gates in your area.
- **Capped zoom-out** — the map won't let you zoom out far. You can only see and interact with gates in your immediate surroundings, so you **can't zoom way out and tap distant gates**. Keeps play local without forcing a walk to each pin.
- **Rank-matched (±1 rank)** — you only see gates within **±1 of your hunter rank** (§28), weighted to your own rank. A C-rank hunter mostly sees C gates, with the occasional B (a risk worth gambling) or D (easy farm). Ranks you've outgrown stop cluttering the map; ranks far above you don't appear.
- **Sparse & high-value** — a modest number of gates in your area, refreshing slowly, so each is worth doing.
- **Randomly themed** — each gate rolls a family/element (no geographic regions). *Set pieces (§15) drop from gates of that theme wherever they appear — "Ashen March gates" = Ashen/undead-themed gates, not a place.*
- **Markers show rank + family + boss hint** — color/icon convey rank (E–S) and theme, plus a hint of the boss inside, so you can pick fights that drop what you want.
- **Daily free gate** — everyone gets at least one guaranteed gate a day even without walking, so quiet areas and rest days still have something to do (backstop alongside tickets + gate-breaks, §8).

**World — points of interest (beyond gates):**
The map isn't only gates — a few POI types give the world texture and reasons to roam:
- **Sanctuaries** — anchored to notable real places (big parks, landmarks). A rest/reward hub: a daily bonus, a free gate ticket, and a small temporary buff. **You must be near a Sanctuary to use it** (proximity required) — unlike gates, these are a real reason to walk to a specific spot.
- **Lore Stones** — discoverable POIs that reveal worldbuilding (the Ascendancy, the families, the Nadir) plus a one-time small reward for finding them. Optional depth for players who want the setting.
- **Gate-breaks** — dynamic emergency events (§8b) surface here as live map events.
- *(Expandable later: outposts/vendors, elite/rare gates, seasonal event nodes.)*

**Incursions — a living, changing world.** Where Pokémon Go's map sits static, ours *changes*. Periodically an **incursion** sweeps a real area for a few days:
- One **family/element** floods the zone (an Abyss rift, a Rimefell frost surge, a Brood swarm), shown as a themed overlay on the map.
- Inside the zone, gates are all that family, denser, a rank higher, with **event rewards** — event currency, boosted set-piece drops for that family (great for finishing that family's armor set, §15), and a shot at rare/event shadows.
- **Reason to roam:** a specific place to go and a limited window to farm a family you're chasing.
- **Escalation (optional):** ignore one long enough and it intensifies or spawns a roaming mini-boss.
- **Tech:** v1 can generate incursions **client-side, deterministically by area + week** (no backend — everyone in a region sees the same event for free); later **server-driven** incursions enable global/shared events (§9).

**HUD (persistent):**
- **Power / level / rank** — your `GATE_POWER`, hunter level, hunter rank.
- **Currencies** — Essence, Crystals.
- **Quick action** — a button for active **gate-breaks / raid entry** (stationary content), so at-home play is one tap away.
- *(No fitness ring here — the workout→EXP summary lives on the Hunter screen.)*

**Navigation:** a **bottom nav bar** — **Map · Army · Raids · Shop** — with the map as home base.

**Stationary play:** gate tickets and gate-breaks (§8) open gates you can run at home; the **Nadir** raid (§20) is reachable from the **Raids** tab.

### Map tech & cost (locked)
**Not** a reskinned Google Maps (their ToS forbids restyling, and it's costly for games). The stack:
- **Data:** **OpenStreetMap** — free, open street/water/building data (the same source Pokémon Go switched to in 2017). Attribution required; no per-use fee.
- **The "reskin":** a custom **MapLibre** style applied to the OSM *vector* data (dark roads, glowing gates, hidden labels) — MapLibre is the free, open-source renderer, no vendor lock-in.
- **Serving:** **Protomaps / PMTiles** — the basemap as a single static file on **Cloudflare R2**, read via HTTP range requests. **No tile server, no API keys, and R2 egress is always free.**
- **Rendering:** on-device in Godot (community OSM/MapLibre tile plugins) — no server render cost.

**Cost / scaling (the "when do we pay?" answer):**
- **Solo / friends / a few hundred players → $0.** A **regional PMTiles extract** fits R2's free 10 GB storage; the full planet (~130 GB) is ~**$2/mo flat** regardless of players.
- **The map essentially never bills** — free R2 egress + heavy on-device tile caching (a walking player fetches very few tiles).
- **First real wall ≈ 1,000–5,000 monthly active users**, and it's the **backend** (Supabase egress, 5 GB/mo free), **not the map**. In daily terms, ~a few hundred to ~1,500 DAU.
- **Crossing it is cheap:** Supabase Pro ~**$25/mo** covers tens of thousands of users; R2 overage is pennies.
- **Lever:** stay **local-first** (progress on-device; backend only for leaderboards / gate-breaks / optional cloud-save, with cached fetches) to push the free ceiling toward the 50k-MAU auth cap.

**Notes / tuning:**
- Walking isn't required for gates, but it still surfaces new POI gates and feeds EXP (steps, §4) — tune POI density/refresh so a player's area always has a few level-matched gates.
- **Safety:** no hard speed-lock — with no proximity requirement there's no reason to chase gates while driving, so the risk is low; a light "you're moving fast" note is optional.
- **Anti-cheat:** trust-based for v1; add mock-location / impossible-jump detection when leaderboard integrity starts to matter (§9).
- Gate-break alerts surface here as a map event + push (§8b).
- Gate lifetime: gates persist in your area, refreshing over time (tunable).

---

## 20. Raid — the Nadir

The whole-army endgame ladder: **one deep, persistent tower** you climb over the life of the game. Reached from the **Raids** tab. **Free to attempt** — no tickets.

**How it works:**
- One tower (the **Nadir**), many floors. Clear a floor **once** and it's done **forever**; it unlocks the next. You take floors on **manually, one at a time**.
- **Your party of 4** (you + 3 chosen shadows) fights the floor via the active combat system (§16) — real turns, not a single power-check. Your **full army still matters**: everything beyond the 3 in your party grants a passive **Army Synergy** stat bonus to your party (§16), so the whole-collection endgame fantasy stays intact even though only 4 fighters are ever on screen. **No attrition** — losing just means the floor stays for a retry.
- Progress is **permanent and saved**. Hit a floor you can't beat → leave, get stronger (workouts / bigger army / gear), come back and continue from there.

**Floor power curve (v0, tunable):** `floor_power(n) = 300 × 1.12^n` — floor 1 trivial, deep floors enormous (≈2,900 at floor 20, ≈87,000 at floor 50).

**Occasional boss floors:** at milestones, a **boss floor** — tougher, with a **claimable boss** (3 tries, §18) and a reward spike (set pieces). Not every floor, so they land like events.

**Rewards (one-time per floor, all kept):** each cleared floor grants loot (Essence, gear, EXP) scaling with depth; boss floors add **set pieces** + tickets/crystals; your **deepest floor reached is a leaderboard/ranking stat** (§9).

**Presentation — floor list:** a scrollable list of floors:
- Cleared floors marked ✓,
- The **current floor** with a **Take on floor** button (shows its power, boss if any, and rewards),
- Locked floors ahead greyed out with their power requirement; boss floors flagged.
Tap the current floor → sprite-clash resolve → **win** (bank reward, next floor unlocks) or **lose** (floor stays; come back stronger). Skip available like gates.

**Why it works:** a permanent, personal difficulty ladder that your real-world training pushes you deeper into over weeks and months — a long-tail goal that always reflects exactly how strong you've become.

---

## 21. Hunter / character screen

The fitness half of the game made visible.

**Base identity — Necromancer.** Every hunter is a **Necromancer** — the hidden shadow-commander class. It's what lets you CLAIM and command an army. Universal to all players; pure identity, not a gear class.

**Subclass — freely chosen, permanent.** At the start you pick a **subclass**: one of **Warrior / Guardian / Assassin / Mage / Support**. It:
- gates your **hunter gear** — the hunter has a full **7-slot loadout** with the same class-gating as shadows (§15),
- sets your **stat profile** (level → stat spread, §16),
- defines your **signature training** for 1.5× EXP (§4).
It's a **commitment** — no respec; to change class you start a **new character**. The game *recommends* a subclass from your recent training, but the choice is yours. Because stats come from level (not activity), a Warrior who only lifts still gains agility — nobody's left behind.

**Layout — avatar showcase.** A big **hunter render** dominates the screen: it shows your **equipped gear** and your **rank glow** — the E→S visual progression (§9b), from a ragged E-rank hunter to a radiant Sovereign-tier one. Stats and info arranged around it. Tap into an inline **paper-doll** to manage the hunter's 7 gear slots (same inline flow as the army screen, §17).

**Rich fitness breakdown (the motivating core):**
- Today's **steps, workout minutes, and EXP gained**, plus your **streak**.
- Which activities counted, and whether each hit your **1.5× signature** or 1×.
- A progress bar to the next level.
- *(History/trend graphs can come later.)*

**Stats & rank.** The five stats (derived from level × subclass), your **hunter level**, and **hunter rank** (E→S, the ranking-ladder tier — §9), plus a clear readout of your `GATE_POWER` contribution.

**Health connection.** A status line showing the HealthKit / Health Connect link + permissions, so it's transparent where the data comes from and easy to reconnect.

---

## 22. Stronghold — your home base

Born from making the Sanctuary something deeper. Your **Stronghold** is a personal, upgradeable base — the seat of your Necromancer domain — reachable anytime. It gives your **whole collection a job** between raids, so bench shadows aren't dead weight.

**Idle production (Palworld-base style).** Assign off-squad shadows to facilities that generate resources over real time:
- **Reliquary** — produces **Essence** (the currency for all upgrades, §26).
- **Training Yard** — slowly **levels the assigned shadows** (idle XP) — the bench grows.
- **Gate Watch** — slowly produces **gate tickets**.
Assigned shadows are "busy" until reassigned; bigger/more facilities = more slots and higher rates.

**Upgrades.** Spend **Essence** to upgrade facilities (higher output, more slots) and the Stronghold itself (raises **army roster capacity**, and later maybe squad size).

**Rest / passive growth.** Off-squad shadows here gain a trickle of idle XP, so the collection is always slowly improving even while you focus on a squad.

**Idle balance — keep active play primary.** The Stronghold is a **supplement, not a replacement**: idle output is modest (a day's idle Essence ≈ a *fraction* of an active day of gate-clearing), so **going out and playing is always the better path** — the base rewards having a collection, it never lets you skip the fitness loop. Two guardrails:
- Idle accrual **caps after ~8–12h offline** — collect on return; being away for days doesn't dump a fortune, and there's **no FOMO pressure** to check obsessively (§14 no dark patterns).
- The Stronghold **can't touch hunter level** (exercise-only, §26) — it only yields Essence, shadow XP, and tickets.

**Fitness tie-in (optional, on-theme).** Base production gets a small boost from your recent real-world activity — so working out speeds even your idle economy. Keeps exercise relevant to every system.

**Deploy near home.** You place your Stronghold at a real-world spot **within reach of your house** — a one-time deployment near your actual location (re-locatable if you move). It appears on your map as your base, and its interior is your own personal space. Its location is **private to you** (not shown to other players).

**Tend it in person.** Idle production accrues while you're away; you **collect resources and reassign shadows when you're near your Stronghold** (proximity) — so it's a genuine home base you keep coming back to. Remote viewing is fine; hands-on management happens on-site.

**Solo for now.** No base PvP / raid-defense in v1 (matches the solo design); base raids and co-op are a later expansion.

**Tech:** fully **on-device** — just idle timers + resource math, no backend. Cheap to build, high value.

**Why it matters:** it gives the ~60-shadow collection a *second* purpose — an idle economy — alongside raids (whole-army combat), and turns Sanctuaries from a PokéStop tap into the doorway to a real base. That's a chunk of the "this isn't just Pokémon Go" differentiation.

---

## 23. Art production plan (the final pass)

§9b set the *style*; this is the plan for the **real art pass** that replaces placeholders. The hard part isn't any single image — it's making **hundreds of assets look like one game**. Everything here follows the placeholder-first rule (§9b): built last, swapped in by data (sprite IDs), no code changes.

### Asset inventory (what actually needs making)
| Asset | Count | Notes |
|-------|------:|-------|
| Monster **battle sprites** | ~61 | one per species (§14b) |
| Monster **portraits** | ~20 bespoke + shared | bosses/notables get bespoke; commons share a simpler frame |
| **Shadow variants** | 61 | **not new art** — a recolor shader (see savers) |
| **Hunter avatars** | 5 | one per subclass; rank glow via VFX, not redraws |
| **Equipment icons** | ~110 | inventory icons (50 base + 60 set pieces) |
| **Equipment on avatar** | ~a few per class | silhouette tiers by set/rarity, **not** per-piece |
| **Gate/battle backdrops** | ~6–8 | one per family/theme |
| **Boss art (bespoke)** | ~8–10 | S bosses + named elites, larger |
| **Map style** | 1 | the MapLibre reskin (§19), a style file not sprites |
| **UI kit** | 1 set | panels, frames, buttons, icons, fonts |
| **VFX set** | 1 set | glow, bloom, particles, sprite fly-off, CLAIM burst, level-up, incursion overlay |
| **Stronghold** | ~1 + 4 facilities | base backdrop + facility art + upgrade states (§22) |

### Consistency at scale — the real challenge
1. Lock the **style bible** (§9b).
2. Generate a **small seed set**, hand-pick the best.
3. **Train a custom style LoRA** on those approved assets — this is the key move; it makes every later generation match *your* look instead of drifting. (Local Stable Diffusion / ComfyUI.)
4. Generate the full inventory against the LoRA + fixed seed/reference.
5. **Hand-clean in Aseprite** (§9b tooling): fix artifacts, downscale, **palette-snap** to the locked palette.
6. Integrate via sprite IDs.

### Cost-savers (make it survivable solo)
- **Shadow forms = a shader, not art.** A defeated monster's shadow is the base sprite recolored to inky-black + **cyan** inner glow + smoky edge via a Godot shader. **61 shadows for near-free**, and they auto-read as "a shadow."
- **Equipment: icons + a few avatar tiers.** Draw ~110 *inventory icons* (small, fast), but on the hunter/shadow avatar only show a **handful of visual tiers by set/rarity**, not 110 paper-doll layers. Avoids a combinatorial art explosion.
- **Grade/rank shown via aura VFX** — a shader glow whose intensity/color rises with grade (Wraith→Sovereign), so higher-grade shadows *look* stronger without redrawing them.
- **Reuse backdrops** per family/theme rather than per-gate.
- **Rank glow on the hunter avatar** (E→S progression, §9b) is also VFX, not 6 redraws.

### Where the "HD-2D feel" actually comes from
Not the sprites — the **VFX and lighting**: Godot bloom/glow, tilt-shift depth-of-field, particles on hits/CLAIM/level-up, and the sprite fly-off on win/loss. Budget real time here; it's the difference between "flat pixel art" and "Octopath vibe."

### UI kit
An original "System" aesthetic — dark glass panels, electric-cyan accents, rune-etched frames — a cohesive set of panels/buttons/icons/fonts (now fully spec'd in §9c). Do this early: consistent UI makes the whole app feel finished even while sprites are still rough.

### Order of the art pass
1. **UI kit + VFX** (makes everything feel real).
2. **Hunter avatars + common monster sprites** (what players see most).
3. **Shadow shader + equipment icons.**
4. **Backdrops + bosses.**
5. **Long tail** (rare monsters, set-piece tiers, Stronghold), polish.

### Reality check
Even with the savers, this is the single biggest time sink in the project — but the shader-shadows, icon-not-paperdoll, and VFX-driven grades cut it from "impossible solo" to "a long but doable pass." *(Audio/music is a separate polish track, not covered here.)*

---

## 24. Development roadmap (basic game → patches)

The design is deliberately large. To actually *ship*, build a **minimum lovable version first**, then layer the rest as patches. Everything is on-device and Android-first until noted; placeholder art throughout until the art pass. **The discipline: each phase must be playable and shippable on its own — don't build a later system until the core loop already feels good.**

### Phase 0 — Spike (de-risk)
The Android GPS + Health Connect → GDScript plugin (§11c). Nothing else starts until this works; if it can't, pivot (§12).

### Phase 1 — The basic game (minimum lovable)
The smallest slice that's genuinely fun: *exercise makes you stronger; walk, fight, collect shadows, grow.*
- Health → EXP → **level** (single track, §4); pick one **subclass** at start (§21); stats from level × class (§16).
- A **map** with level-matched **POI gates** near you (§19); walk into the area to run one.
- **Gate encounter** (§18): 3-round auto sprite-clash + boss **CLAIM** (3 tries). Loot = EXP + Essence + the claimed shadow.
- Basic **army**: collect shadows into a **squad of 6** (auto-fill); squad power feeds combat (§16).
- Core loop closed: level up → beat higher gates → bigger army. **Placeholder art, on-device, no backend, no gear/shop/raids yet.**
This is §11's MVP kernel, now the target for a first playable you'd actually enjoy.

### Phase 2+ — Patches (roughly by value / dependency)
- **P1 — Equipment & sets** (§15) + hunter gear loadout (§21): first big depth layer for power/army.
- **P2 — Shadow grades, leveling & merge** (§6): duplicates + upgrade economy, army depth.
- **P3 — Nadir** (§20): the whole-army endgame floor ladder — the long-tail goal.
- **P4 — Stationary play** (§8): gate tickets + gate-breaks — accessibility + at-home retention.
- **P5 — Stronghold** (§22): idle economy — a second job for the collection.
- **P6 — Incursions** (§19): the living, changing world.
- **P7 — Backend + rankings** (§9): accounts + leaderboards (first real server cost/complexity).
- **P8 — Shop & cosmetics** (§14): tickets + cosmetic monetization.

### Ongoing tracks (parallel, later)
- **Art pass** (§23): replace placeholders — real sprites, shadow shader, VFX, UI kit.
  - **Full art blitz (Midjourney), one focused paid month — 147 images:** hero key art (3 formats) + 4 promo/social variants + all 61 monster portraits + all 50 equipment icons + all 15 armor-set showcases + 14 UI/store assets (app icon, feature graphic, class icons, rank badges). Style locked: frost-cyan, near-total darkness, silhouette-first, crisp linework (`--style raw`), one shared `--sref` code for consistency. Full prompt pack in **ShadowHunter_MidjourneyArtPack.md**; save/organize via **ShadowHunter_ArtDropTool.html** (auto-renames + files into `/hero /promo /monsters /equipment /sets /ui`, matching monsters.json/equipment.json ids — drops straight into the game later). Subscribe → blitz in Relax mode → cancel. Reference images are **written descriptions only** — no copyrighted frames used as input (IP safety; UK CDPA s.9(3) gives us authorship of computer-generated work since we make the creative arrangements — see note below).
- **Polish**: onboarding/first-run, wellbeing (rest-day framing, no overtraining nudges), safety, accessibility.
- **iOS port**: HealthKit + CoreLocation plugins, once Android is solid.

### Still-open design threads (worth a pass before the relevant patch)
- **Onboarding / first five minutes** — subclass pick, health-permission flow, first gate/CLAIM. Undesigned.
- **The economy** — the §26 structure is set (single Essence currency); income vs. sink *rates* and upgrade curves still need real tuning (v0 numbers).
- **Health-data compliance & wellbeing** — privacy policy, store review, minors, accessibility (steps-based excludes some). A real gate for Phase 1 release.

---

## 25. Onboarding — the first five minutes

Goal: hook the player **before** the scary health-permission ask, teach the loop by doing, and land a first CLAIM fast. Principle throughout: **value before permissions; one decision at a time; a win + a CLAIM inside the first few minutes.**

1. **Cold open (value-first).** Straight into a short stylised intro to being a hunter/Necromancer, then create your hunter — quick avatar pick + name. **No permission wall yet.**
2. **"How do you train?" → subclass.** Ask one friendly question — what exercise you do most (lifting / running / long cardio / yoga-mobility / mixed) — and **recommend the matching subclass** (Warrior/Assassin/Guardian/Mage/Support), while letting the player override. Ties fitness identity to the character from minute one and teaches the 1.5× signature bonus. (Make clear it's permanent, §21.)
3. **Free starter shadow.** Grant one Wraith-grade shadow so the army isn't empty and the first fight works — a gentle first taste of the CLAIM fantasy ("your first soldier").
4. **Guided first gate.** A scripted low-E gate right where you are (no walking for this first one): run the 3-round clash (win guaranteed), then the **first CLAIM** — a big, can't-miss moment. Teaches gate → fight → CLAIM in ~30 seconds.
5. **The health-permission ask — now, framed well.** *After* they've seen the fun, request HealthKit / Health Connect access clearly: *"Your real workouts and steps level up your hunter. Your health data stays on your device and is never sold or shared."* Explain the payoff and be honest about handling (§24 compliance).
6. **Graceful decline.** If they say no, let them keep exploring, but be honest that progression needs the health connection — a gentle, repeatable nudge to enable it later, never a hard lock that feels like a bait-and-switch.
7. **Point them outward.** Show the map, the nearest real gate, and the daily free gate — then hand over control. Light prompts, learn-by-doing, no text walls.

**The one real decision:** whether step 5 (permission) comes *after* the guided first gate (recommended — value first) or up front (simpler, but higher drop-off at the permission wall). Recommended: value first.

---

## 26. Economy (v0)

**One earned currency: Essence.** To keep the UI clean, a **single** currency — **Essence** — pays for *everything* in-game: leveling and fusing shadows, enhancing gear, and upgrading the Stronghold. No gold, no sigils, no whetstones. (*Essence* is a working name — rename freely.) Essence is **earned through play and also buyable with Crystals** (premium). **Crystals** buy Essence, tickets, and cosmetics.

**The unbuyable core is your fitness.** Money can accelerate your *build* (buy Essence → level shadows/enhance gear faster), but **hunter level / EXP is exercise-only and cannot be bought** (§4). Since level gates gate-rank access and a core slice of power, the true progression ceiling stays behind real training — you can pay to build faster, never to skip showing up. *(This is a pay-for-build model, not cosmetics-only; the army-driven Nadir & leaderboard will partly reflect spend.)*

**Resources (short list — the point of one currency):**
| Resource | Type | Main sources | Main sinks |
|----------|------|--------------|------------|
| **EXP** | progression | real workouts + steps (§4) | → hunter level (auto) |
| **Essence** | the earned currency | gate/raid loot, converting surplus shadows (§17), Stronghold Reliquary, daily | **level/fuse shadows**, **enhance gear**, **Stronghold upgrades** |
| **Duplicates** | fuel | catching a shadow you already own | **fuse to level** that shadow (a big level chunk — but still **costs Essence**) |
| **Gate Tickets** | consumable | daily, Sanctuaries, Stronghold Gate Watch, ranking, shop | **spawn a gate at your location** (§8a) |
| **Crystals** | premium | real money; slow trickle from play/achievements | **Essence, gate tickets, cosmetics** — buys build/pace, **never hunter level** |

**Everything runs on Essence:**
- **Shadows** — spend Essence to level (1→cap); fusing a **duplicate** you own gives a big chunk but *also* costs Essence (a real sink, not free).
- **Equipment enhancement (extends §15)** — enhance gear (+1…+10) for Essence, raising its stats/power.
- **Stronghold** — upgrade facilities and roster capacity for Essence (§22).
Because one pool funds all three, *where* you spend is a real choice: gear vs. shadows vs. base.

**Tickets are lightly limited** — a couple free per day (daily + a Sanctuary) so stationary play *supplements* walking rather than replacing it; the shop sells more as fair convenience.

**v0 illustrative rates (tune later):**
- Essence per gate ≈ E 20 · D 50 · C 120 · B 300 · A 700 · S 1,500.
- Essence per converted shadow ≈ E 1 · D 2 · C 4 · B 8 · A 15 · S 30 (by grade).
- Shadow leveling, gear enhancement & Stronghold upgrades: escalating Essence costs — steep enough to keep you a little resource-hungry, never starved.

**Balance philosophy:** keep players *slightly* Essence-hungry (a reason to play, never a grind wall); every sink improves your **build**, not your **ceiling**; and **no dark patterns** (§14) — the economy respects the player's time.

---

## 27. Health-data compliance & wellbeing

Reading HealthKit / Health Connect carries real legal + store obligations and a duty of care. This is a **Phase-1 release gate**, not optional — no privacy policy + declarations = no store approval.

### Store & legal compliance (verified, 2026)
- **Privacy policy (required by both stores)** — publish one disclosing exactly what health data you read, how it's used, stored, and (not) shared.
- **Strict use limits** — health data may **not** be used for advertising, audience profiling, or third-party sharing, and never sold. (Both Apple and Google enforce this. Our monetization is cosmetics/tickets — stays clean; keep it that way.)
- **Apple specifics** — do **not** store HealthKit data in iCloud; request **only** the permissions actually used (steps, workouts, active energy) — asking for all categories spikes review scrutiny; make no clinical/wellness claims.
- **Google specifics (2026)** — complete the **Play Health Apps Declaration**, justify each Health Connect data type as essential to core function, and expect to need a **verified Organization Account**; don't use age-restricted signals for health profiling (now explicitly banned).
- **Accurate labels** — fill Apple's Privacy "Nutrition" labels and Google Play's Data Safety form truthfully.
- **User rights** — support data access + deletion (GDPR/CCPA).

### The local-first advantage (design that lightens the burden)
Our design already helps: health data is read **on-device** to compute EXP and **never needs to leave the phone**. Only non-health aggregates (level, power, leaderboard score) go to the backend. **Make this an explicit rule** — sensitive data staying local means far less compliance exposure and user risk.

### Minors (a real decision — the audience skews young)
- Simplest safe path: **age-gate to 13+** (16+ where GDPR requires), and don't transmit any health/personal data for under-age users.
- Allowing younger users would require **verifiable parental consent** (COPPA / GDPR-K) — a heavy burden; avoid for v1.
- Never use age signals for profiling.

### Wellbeing (duty of care)
- **Soft EXP cap / diminishing returns** (already §4) so the game never rewards overtraining.
- **Reward rest** — recovery days give a small bonus; no harsh streak punishment (login streaks already cut, §14).
- **Positive, non-comparative messaging** — never body-shaming or unhealthy comparison.
- **Not a medical device** — clear disclaimer; make no health claims.

### Accessibility (don't exclude non-walkers)
- **Count any activity, not just steps.** The §4 EXP model already leans on **active minutes + workout minutes** (not steps alone), so running, cycling, swimming, wheelchair pushes, yoga, etc. all progress you — keep steps a *bonus*, never a requirement, so wheelchair users and non-walkers aren't excluded.
- The **walk-optional** design (POI gates usable from anywhere, §19) already helps — reinforce it.
- Standard a11y: text scaling, **colourblind-safe** rank markers (never colour alone), a reduced-motion option.

---

## 28. Hunter rank & Rank-Up Assessments

"Hunter rank" (E→S) is referenced throughout but was never defined. It's the game's **prestige spine** — and a perfect Solo-Leveling beat (the reassessment).

**Two progression axes:**
- **Level** — continuous, from real exercise (§4); drives stats/power.
- **Rank (E→S)** — milestone tiers you *earn*, not auto-granted.

**Rank-Up Assessments.** Reaching a **level threshold** unlocks a one-off **Assessment** for the next rank: a fixed, tougher-than-normal solo challenge (a special gate with a target-rank boss). Clear it → your hunter is **promoted**. Fail → train / build up and retry. A rank means you've *proven* it, not just banked EXP.
- Unlocks (tuned in §29): **D @ L5 · C @ L12 · B @ L20 · A @ L30 · S @ L40**.

**What the Trial actually is:**
- A **special, non-repeating solo Trial** (not a normal gate), unlocked at the level threshold — flagged on the Hunter screen (§21) and by a notification.
- **Format:** a short **gauntlet** ending in a **Trial Boss** tuned *above* a normal gate of that rank (≈ ×1.2 power), so you must be genuinely *ready*, not just barely at the level. Uses `GATE_POWER` (you + squad) — a test of **you**, which keeps rank tied to your level.
- **Idle-consistent:** still an auto power-check (§30), just tuned harder.
- **Retry:** free and repeatable (optional short cooldown) — fail, train/build, come back. No penalty.
- **First-clear reward:** a **rank insignia** (cosmetic badge) + a one-off milestone reward (Essence / a signature cosmetic). The Trial Boss is **not** claimable — it's a trial, not a wild monster.
- **On pass:** permanent promotion → higher gate ranks appear (§19), plus unlocks and your new leaderboard tier.

**What rank does:**
- **Gate spawns** — the map shows gates within **±1 of your rank** (§19); rank, not raw level, sets what content appears.
- **Unlocks** — higher ranks open things (deeper Nadir floors, features, a rank insignia).
- **Leaderboard tier** (§9) — standings grouped by rank.
- **Identity** — your rank badge *is* your status: the E-rank-to-Sovereign fantasy made concrete.

**Why it's good:** it turns a long continuous grind into a series of **named milestones each with a real test**, gives the fitness a proving-ground moment, and reinforces the power fantasy. And it keeps the pay-for-build player honest — buying Essence helps you *prepare*, but you still have to **pass the Assessment** yourself.

**The one decision:** does rank **hard-gate** which gates you can enter (nothing above rank+1), or just filter what *spawns* while letting you attempt anything you stumble on? **Recommended: soft** — spawns filter by rank, and the Assessments are the real gate to each new tier.

---

## 29. Progression pacing (sanity check)

A pass over how the game feels over time — and it forced a fix. **Finding:** the original level curve made S-rank take ~13 *years*. Flattened to `EXP_to_next = 100 × level` (§3) with rank thresholds **D5 · C12 · B20 · A30 · S40** (§28), the pacing is healthy. (Numbers assume ~400 EXP per active day; casual ~200, keen ~700.)

| Milestone | cum EXP | casual | active | keen |
|-----------|--------:|-------:|-------:|------|
| **D-rank** (L5) | 1,400 | ~1 wk | ~4 days | ~2 days |
| **C-rank** (L12) | 7,700 | ~5.5 wk | ~3 wk | ~1.5 wk |
| **B-rank** (L20) | 20,900 | ~3.5 mo | ~7 wk | ~1 mo |
| **A-rank** (L30) | 46,400 | ~7.5 mo | ~4 mo | ~2 mo |
| **S-rank** (L40) | 81,900 | ~14 mo | ~7 mo | ~4 mo |

**Key principle this exposes:** **level (fitness) is the slow prestige spine** — it can't be rushed and shouldn't be the bulk of your power. **The fast-moving power is your army + gear**, which you grind (and buy) by *playing*, independent of the level clock. So the player feels progress *every session* (Essence, shadows, gear, deeper floors) between the slower rank-ups.

**The journey:**
- **First session (~5 min):** onboarding → subclass → first gate → first CLAIM. Hooked.
- **Day 1:** a few gates, 2–3 shadows, first gear, ~L1–2. Learn the loop.
- **First week:** ~D-rank, a squad of 6, first equipment, discover Sanctuaries + the daily free gate, deploy the Stronghold.
- **First month:** ~C-rank, army growing, first set pieces, first Nadir floors, first incursion. Systems opening up.
- **Months 2–4:** B→A rank, army maturing (grades, leveling, merges), Stronghold humming, pushing the Castle, chasing sets. The "main game."
- **6–12 months:** S-rank, deep Castle floors, completed sets, a broad leveled army. Endless endgame: incursions, leaderboard, deeper floors.

**Does it hang together?** Yes — a reward at every timescale: a CLAIM/loot each **gate** (minutes), Essence + a shadow to level each **session**, a set piece or Castle floor **weekly**, a rank-up assessment **monthly-ish**, and the fitness itself trending up (the meta-reward). No dead stretches, and nothing gates *fun* behind the slow fitness clock, because army/gear moves fast.

**Caveat:** all v0 — real tuning happens in-engine with live data. But the *shape* now holds.

---

## 30. Combat balance (sanity check)

> **Superseded by the §16 combat overhaul.** This analysis is for the old single power-check resolve and no longer reflects how a fight actually plays out — kept below for historical reference only. Real balance for active party combat needs playtesting (real HP/damage numbers, move timing, AI behavior in practice), not a paper formula — that's a follow-up pass once §16 is built and playable, not something to fake here.

Plugging real numbers into the clear check (`P = r^k/(r^k+1)`, k=3; §5) for a **rank-matched hunter** across the journey, using `GATE_POWER = personal + squad×0.25` (§16):

| Your rank | Win % **own-rank** gate | **+1 rank** (gamble up) | **−1 rank** (farm) |
|-----------|:----:|:----:|:----:|
| D | 97% | 68% | 100% |
| C | 98% | 75% | 100% |
| B | 97% | 70% | 100% |
| A | 93% | 45% | 99% |
| S | 68% | — | 97% |

**Shape is healthy:** own-rank gates are reliably winnable, punching up a rank is a genuine **45–75% gamble**, and lower ranks are easy farming.

**Key conclusion (a conscious choice):** combat itself carries **almost no risk on your own rank** — the tension lives in the **CLAIM roll** (3-try RNG, §18) and in **gambling up a tier**, *not* in losing fights you should win. That's exactly right for the intentionally-idle, don't-stop-walking design (§18): you shouldn't lose a gate mid-walk to bad luck.

**Tuning levers:**
- **k** (swinginess) — higher = more deterministic, lower = more upsets.
- **Gate-power scale** — if own-rank gates should feel *less* trivial, nudge gate powers up so own-rank sits ~80–85% instead of ~97%.
- **S-rank squad depth** — S own-rank shows 68% only because stacking six S-tier shadows is hard; a bit of extra bite at the very top is fine, or tune squad/gear assumptions.

**Caveat:** rests on v0 gear/squad estimates — real tuning happens in-engine. But the curve behaves as intended.

---

*Numbers here are all illustrative starting points chosen so the systems interlock — every formula is a tunable knob, not a final value.*
