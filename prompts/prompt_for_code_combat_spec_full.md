Note on the last two prompts: the file paths I gave you don't exist on this machine — my mistake, not a third party. I was pointing at an internal path from my own session that isn't accessible locally. Ignore those; here's the actual spec content, inline, so there's no file-path dependency at all.

Please **replace the following sections of `ShadowHunter_Concept.md`** with the text below (matching by section number/heading), then proceed with the build order at the bottom of this file.

---

## REPLACE existing "§16. Stat-to-power" section entirely with:

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
- **Enemy turns:** grunts attack simply; bosses get an occasional telegraphed bigger hit (~2x a normal attack) every few turns, so S-rank bosses feel like S-rank bosses. Exact cadence: tune once playable.
- **Win:** all enemies to 0 HP. **Loss:** your party to 0 HP — no penalty, gate/floor stays, come back stronger. Same no-attrition philosophy as before.

### Moves — one moveset per class, used two ways
The same 5 movesets serve double duty: **you** pick manually from your own subclass's list; **shadows** of that class pick automatically from the same list (below). No duplicated design.

**Warrior** (STR) — 1. Strike (Lv1, basic hit) · 2. Power Strike (Lv3, heavier single-target) · 3. Cleave (Lv6, hits all enemies, lighter each) · 4. Rally Cry (Lv10, team attack buff) · 5. Execute (Lv15, big hit, bonus vs. low-HP enemies)

**Guardian** (VIT/END) — 1. Guard Strike (Lv1, basic hit) · 2. Taunt (Lv1, forces enemies to target this Guardian) · 3. Brace (Lv5, big self defense buff) · 4. Shield Ally (Lv8, soaks damage meant for a chosen ally) · 5. Fortress (Lv14, team-wide defense buff)

**Assassin** (AGI/STR) — 1. Quick Strike (Lv1, basic hit) · 2. Weaken (Lv3, lowers enemy defense) · 3. Poison Edge (Lv6, damage-over-time) · 4. Exploit Weakness (Lv10, bonus damage vs. debuffed enemies) · 5. Shadowstep Execute (Lv15, burst finisher)

**Mage** (SEN) — 1. Cyan Bolt (Lv1, single-target magic) · 2. Frost Nova (Lv4, small AoE) · 3. Arcane Barrage (Lv8, bigger single-target hit) · 4. Chain Lightning (Lv12, hits 2-3 targets) · 5. Nova Burst (Lv16, big AoE, on cooldown)

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

~16x growth either side — early fights resolve in a handful of hits (good for a quick tap mid-walk); a Lv40 fight still feels dangerous.

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

## INSERT new "§16b" section right after §16 (before §17):

## 16b. Battle screen — UI layout

The screen §16's combat system actually plays out on. Shared by **every** fight — gates, gate-breaks, and every Nadir floor — so it's built once and reused everywhere. Portrait mobile layout, top to bottom:

**1. Enemy row (top).** Up to 4 enemy slots — sprite/portrait, name, HP bar (current/max). A **telegraph icon** appears above a boss when its next turn is a big hit (§16), so you can see it coming, not just eat it. A gate run is still **up to 3 sequential sub-battles** (*trash → trash → boss*, unchanged `GateInstance` structure, §18) — each sub-battle populates this row fresh; exact enemy-count-per-round is a balance detail to tune once playable, not fixed here.

**2. Turn-order strip.** A slim horizontal row of small portraits (your party + enemies, AGI-sorted) showing the next few turns in sequence — standard JRPG convention, gives the telegraph icon above real weight ("boss goes in 2 turns").

**3. Battle stage (middle).** Mostly empty space — background is the "inside the gate" dark-fantasy world (§9b's world-separation: real world outside, near-black frost-cyan world within), not the map. Floating damage numbers pop here on hits (crits visually distinct — bigger/brighter), and a brief **System UI toast** (§9c, small tier) names the action taken — *"Ashen Warden used Taunt!"* — since shadow/enemy turns are automatic and still need to read clearly without full animation. Keeps faith with the original "no real animation, AI-art-friendly" philosophy — this is readable text + numbers + sprite flashes, not a fight choreography.

**4. Party row.** Your 4 combatants (you + 3 chosen shadows) — portrait, class icon, HP bar, cooldown pips on any move currently unavailable. The unit whose turn is active gets a highlight ring.

**5. Action bar (bottom, your turn only).** Your unlocked moves as a row of buttons (name + cooldown state). Tap a move → if it needs a target, enemy portraits highlight as tappable, tap one to resolve; AoE moves resolve immediately with no target tap. During shadow/enemy turns this area shows a simple **"[Name] is acting…"** state instead — no dead air, no player input possible.

**6. Always-available controls (corner, all turns).** **Auto-battle** toggle (AI plays your turns too, using your subclass's same role-priority logic as shadows) and **Skip** (resolves the rest instantly, straight to results) — both from §16, both critical to keeping a routine gate a one-tap action mid-walk.

**Transitions:** enters from the gate preview card (§18) or a Nadir "Take on floor" tap (§20); on win, hands off straight into the existing Results page (§18's CLAIM ceremony, unchanged).

**No new art required.** The existing preset-hunter portraits and monster portraits (already generated/planned) work directly as static battle-HUD icons — this screen is menu-driven, not directional/animated, so it doesn't need a separate "simpler battle/map sprite" asset type. A real scope-saver from the overhaul, not a cost.

---

## REPLACE the "Gate squad" paragraph in §17 (Army management screen) with:

**Gate squad — one squad, no presets, class-slotted.** A single team of 6 you maintain, with **fixed class slots: one each of Warrior · Guardian · Assassin · Mage · Support + 1 Flex** (any class). This *forces* a balanced comp and a reason to collect (and gear) every class. **Since the §16 combat overhaul, this now has real mechanical teeth** — for any fight, you pick **3 of these 6** to actually field (you + those 3 = your party of 4, §16), and a team missing a Guardian's taunt or a Support's heals genuinely plays worse, not just symbolically. Auto-optimize fills each slot with your strongest of that class; tweak by hand. Early on, empty slots are fine — fill them as you collect. *(Raids also draw their 3 from this squad — your wider army instead contributes the passive Army Synergy bonus, §16.)*

---

## REPLACE §18 "Gate encounter screen & flow" section entirely with:

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
- Data: a `GateInstance` carries `boss_id` (round 3) + `trash_ids` (rounds 1-2) — unchanged; they now resolve as real combat instead of a compare-and-roll.

---

## REPLACE the "How it works" first bullet-block in §20 (Raid — the Nadir) with:

**How it works:**
- One tower (the **Nadir**), many floors. Clear a floor **once** and it's done **forever**; it unlocks the next. You take floors on **manually, one at a time**.
- **Your party of 4** (you + 3 chosen shadows) fights the floor via the active combat system (§16) — real turns, not a single power-check. Your **full army still matters**: everything beyond the 3 in your party grants a passive **Army Synergy** stat bonus to your party (§16), so the whole-collection endgame fantasy stays intact even though only 4 fighters are ever on screen. **No attrition** — losing just means the floor stays for a retry.
- Progress is **permanent and saved**. Hit a floor you can't beat → leave, get stronger (workouts / bigger army / gear), come back and continue from there.

(The rest of §20 — floor power curve, boss floors, rewards, presentation — is unchanged.)

---

## ADD this note at the very top of §30 (Combat balance sanity check), before its first paragraph:

> **Superseded by the §16 combat overhaul.** This analysis is for the old single power-check resolve and no longer reflects how a fight actually plays out — kept below for historical reference only. Real balance for active party combat needs playtesting (real HP/damage numbers, move timing, AI behavior in practice), not a paper formula — that's a follow-up pass once §16 is built and playable, not something to fake here.

(The rest of §30 stays as historical reference, unchanged.)

---

# BUILD ORDER (once the doc is updated)

This is the biggest change to the game since Phase 1 and it touches already-shipped, tested code. Please don't silently leave the old GUT tests for the deprecated functions green-but-irrelevant — either update them to reflect their new role (as inputs, not resolvers) or clearly mark/remove what no longer applies, and say so in your commit message.

Suggested build order — break into your usual step-by-step patches, don't try to land this in one shot:

1. **Combat math core.** Pure static functions (game_logic.gd or a new combat_math.gd, your call) for HP/PATK/MATK/DEF/CRIT_CHANCE and the damage formula, plus enemy stat derivation from `base_power`/`floor_power` (§16). GUT tests against the worked Lv1/Lv40 Warrior example above and a few enemy derivations.

2. **Move/ability data + shadow AI.** The 5 class movesets (name, unlock level, type, power multiplier, target type, cooldown) as data — your call whether that's a moves.json matching the monsters.json/equipment.json pattern, or a const dict. Shadow AI priority logic per class role (§16) as pure, testable functions — given a battle state, does the AI pick the expected action.

3. **Turn engine.** AGI-ordered turn queue; resolves player/shadow/enemy actions; applies damage/heal/buff/debuff/taunt; tracks HP/cooldowns/status; determines win/loss. Build and test this as pure logic before touching the scene/UI.

4. **Battle screen UI**, per §16b exactly: enemy row with boss telegraph icon, turn-order strip, battle stage (floating damage numbers + small System UI toast for automatic actions), party row with cooldown pips, action bar with move buttons + tap-to-target, and the always-available Auto-battle/Skip controls. Reuse the existing preset-hunter and monster portraits as static icons — no new art needed for this screen, per the doc.

5. **Wire it into the gate flow (§18) and Nadir floor flow (§20)**: replace the old GATE_POWER/clear_probability call with launching this battle screen; on win, hand off to the existing Results/CLAIM page (unchanged). Implement the Army Synergy bonus (§16) for raids only — full army power minus the fielded 3, feeding a capped passive stat bonus to the party.

6. **Squad screen tweak (§17).** When entering any fight, let the player pick 3 of their 6 squad members to field alongside themselves. Simple selection UI, not a big screen change.

**Before calling this done:** live-verify a real gate battle on device — one manual playthrough, one with Auto-battle, one with Skip — not just green tests. Commit in your usual logical increments as you go, and flag any scope cuts or deferred edge cases honestly, as always.

Take as many sessions as this needs — check in with a status recap between major pieces rather than trying to push through it all at once.
