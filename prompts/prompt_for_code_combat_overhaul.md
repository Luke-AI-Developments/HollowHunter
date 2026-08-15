Big one: implement the combat system overhaul. Before starting, read **§16 (Combat system)**, **§16b (Battle screen — UI layout)**, and the updated **§17, §18, §20**, plus the superseded-note at the top of **§30**, in `HollowHunter_Concept.md`. That's the full spec — this prompt is the build plan, not a re-explanation, so don't guess at mechanics that are already written there.

**What's changing, in one sentence:** the fight-resolution mechanic for every encounter (gates, gate-breaks, Nadir floors) moves from a single power-check + RNG roll (`GATE_POWER`/`RAID_POWER`/`clear_probability`/`resolve_clear`) to real turn-based party combat — you + 3 chosen shadows vs. a variable number of enemies, DQ/JRPG-style.

This is the biggest change to the game since Phase 1 and it touches already-shipped, tested code. Please don't silently leave the old GUT tests for the deprecated functions green-but-irrelevant — either update them to reflect their new role (as inputs, not resolvers) or clearly mark/remove what no longer applies, and say so in your commit message.

**Suggested build order** (break into your usual step-by-step patches, don't try to land this in one shot):

1. **Combat math core.** Pure static functions (game_logic.gd or a new combat_math.gd, your call) for HP/PATK/MATK/DEF/CRIT_CHANCE and the damage formula, plus enemy stat derivation from `base_power`/`floor_power` (§16). GUT tests against the worked Lv1/Lv40 Warrior example in the doc and a few enemy derivations.

2. **Move/ability data + shadow AI.** The 5 class movesets (name, unlock level, type, power multiplier, target type, cooldown) as data — your call whether that's a moves.json matching the monsters.json/equipment.json pattern, or a const dict. Shadow AI priority logic per class role (§16) as pure, testable functions — given a battle state, does the AI pick the expected action.

3. **Turn engine.** AGI-ordered turn queue; resolves player/shadow/enemy actions; applies damage/heal/buff/debuff/taunt; tracks HP/cooldowns/status; determines win/loss. Build and test this as pure logic before touching the scene/UI.

4. **Battle screen UI**, per §16b exactly: enemy row with boss telegraph icon, turn-order strip, battle stage (floating damage numbers + small System UI toast for automatic actions), party row with cooldown pips, action bar with move buttons + tap-to-target, and the always-available Auto-battle/Skip controls. Reuse the existing preset-hunter and monster portraits as static icons — no new art needed for this screen, per the doc.

5. **Wire it into the gate flow (§18) and Nadir floor flow (§20)**: replace the old GATE_POWER/clear_probability call with launching this battle screen; on win, hand off to the existing Results/CLAIM page (unchanged). Implement the Army Synergy bonus (§16) for raids only — full army power minus the fielded 3, feeding a capped passive stat bonus to the party.

6. **Squad screen tweak (§17).** When entering any fight, let the player pick 3 of their 6 squad members to field alongside themselves. Simple selection UI, not a big screen change.

**Before calling this done:** live-verify a real gate battle on device — one manual playthrough, one with Auto-battle, one with Skip — not just green tests. Commit in your usual logical increments as you go, and flag any scope cuts or deferred edge cases honestly, as always.

Take as many sessions as this needs — check in with a status recap between major pieces rather than trying to push through it all at once.
