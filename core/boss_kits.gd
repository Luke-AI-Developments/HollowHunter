class_name BossKits
## The six reusable boss archetype kits (spec §4). Pure -- class_name only,
## all-static, no engine deps. `apply_*` hooks (Tasks 3-6) mutate a passed-in
## `Battle` through its public API. All magnitudes are v0 (spec §4 / §12).

## spec §3.4, v0: family -> kit id. Every value must be a KIT_IDS member.
const FAMILY_KIT := {
	"Ashen Wardens": "warden",
	"Emberdrakes": "berserker",
	"Gravekin": "revenant",
	"Hollow Brood": "broodmother",
	"Abyssal Fiends": "hexer",
	"Rime Sylphs": "colossus",
	"Gloamwing": "revenant",
	"Tarlings": "berserker",
}

## spec §4, v0: the canonical list of kit ids.
const KIT_IDS := ["berserker", "warden", "broodmother", "hexer", "colossus", "revenant"]

## Per-kit cadence + magnitude table (spec §4, v0). Later tasks read/extend
## these keys; this file is the single source for every kit number.
const BOSS_KITS := {
	"berserker":
	{
		"telegraph_interval": 3,
		"phase2_telegraph_interval": 2,
		"signature_power": 2.2,
		"fury_per_round": 0.04,
		"fury_cap": 1.6,
		"fury_cap_phase2": 2.0,
		"burn_frac": 0.25,
		"burn_turns": 3,
	},
	"warden":
	{
		"telegraph_interval": 3,
		"phase2_telegraph_interval": 2,
		"signature_power": 1.8,
		"def_mult": 1.4,
		"break_phys_mult": 0.7,
		"bastion_def_mult": 1.6,
		"bastion_turns": 3,
		"bastion_hp_gate": 0.60,
	},
	"broodmother":
	{
		"telegraph_interval": 3,
		"phase2_telegraph_interval": 2,
		"signature_power": 2.0,
		"devour_heal_frac": 0.40,
		"spawn_interval": 3,
		"spawn_power_frac": 0.15,
		"spawn_cap": 2,
	},
	"hexer":
	{
		"telegraph_interval": 3,
		"phase2_telegraph_interval": 2,
		"doom_power": 1.3,
		"atkdown_mult": 0.8,
		"atkdown_mult_phase2": 0.65,
		"atkdown_turns": 2,
		"siphon_interval": 3,
		"siphon_frac": 0.08,
	},
	"colossus":
	{
		"telegraph_interval": 4,
		"phase2_telegraph_interval": 3,
		"signature_power": 3.0,
		"avalanche_splash_power": 1.0,
		"speed_mult": 0.6,
		"break_max_mult": 1.3,
	},
	"revenant":
	{
		"telegraph_interval": 3,
		"phase2_telegraph_interval": 2,
		"signature_power": 2.0,
		"grave_chill_atkdown": 0.75,
		"atkdown_turns": 2,
		"leech_interval": 3,
		"leech_heal_frac": 0.50,
		"death_window_turns": 2,
		"revive_frac": 0.35,
	},
}


## Called at the top of Battle._resolve_enemy_turn for a kitted boss. Returns
## true if the kit fully resolved this turn (Battle then does nothing further),
## false to fall through to the default basic attack. An implemented arm OWNS
## the whole turn -- it manages `turns_until_big_hit`, does its own basic
## attack when it is neither a telegraph nor an ability turn, and always
## returns true. `return false` is only for a not-yet-implemented kit.
static func on_turn(battle: Battle, boss: Dictionary) -> bool:
	match String(boss.get("kit", "")):
		"berserker":
			return _berserker_turn(battle, boss)
		"colossus":
			return _colossus_turn(battle, boss)
		"warden":
			return _warden_turn(battle, boss)
		"hexer":
			return _hexer_turn(battle, boss)
		"broodmother":
			return _broodmother_turn(battle, boss)
		"revenant":
			return _revenant_turn(battle, boss)
		_:
			return false


## One-time per-boss effect when it crosses into phase 2 (spec §3.5).
static func on_phase(battle: Battle, boss: Dictionary) -> void:
	match String(boss.get("kit", "")):
		"berserker":
			# §4.1 on-phase: the Fury cap bump is automatic (rising_fury_mult
			# reads `phase`); the free Immolate fires here.
			_boss_signature_hit(battle, boss, BOSS_KITS["berserker"]["signature_power"])
		"warden":
			# §4.2 on-phase: Bastion fires immediately, ignoring the once-per-phase
			# gate; mark the phase used so the ability check does not re-fire it.
			_bastion(battle, boss)
			boss["_bastion_phase_used"] = int(boss.get("phase", 1))
		"hexer":
			# §4.4 on-phase: Doom's deeper atk-down (x0.65) and tighter cadence are
			# read live from `phase` at Doom time -- nothing to fire here.
			pass
		"broodmother":
			# §4.3 on-phase: an immediate Spawn x2. The 2nd is a no-op if the +2
			# cap or the 4-enemy row limit is already hit -- spawn_add guards both.
			battle.spawn_add(boss)
			battle.spawn_add(boss)
		"revenant":
			# §4.6 on-phase: +1 break-bar segment to fill before it can be Broken --
			# a tighter Death-Window race in phase 2.
			boss["break_max"] = float(boss["break_max"]) + float(boss.get("break_segment", 0.0))
		_:
			# colossus §4.5 on-phase: Avalanche cadence -> every 3t is already
			# handled -- _boss_telegraph_interval reads `phase`.
			pass


## §4.1 Berserker passive -- Rising Fury: patk/matk x(1 + fury_per_round per
## round elapsed), capped at fury_cap (fury_cap_phase2 in phase 2). 1.0 for
## any non-berserker boss, so the shared `boss_strike` calc can fold it in
## unconditionally.
static func rising_fury_mult(boss: Dictionary, round_number: int) -> float:
	if String(boss.get("kit", "")) != "berserker":
		return 1.0
	var kit: Dictionary = BOSS_KITS["berserker"]
	var cap: float = kit["fury_cap_phase2"] if int(boss.get("phase", 1)) == 2 else kit["fury_cap"]
	var ramp := 1.0 + float(kit["fury_per_round"]) * float(maxi(0, round_number - 1))
	return minf(ramp, cap)


## Shared telegraphed-signature resolver: `boss` hits `battle._enemy_target()`
## at `power`, via `battle.boss_strike`. If `splash_power > 0` and the boss is
## not shielded from splashing (`not splash_unbroken_only`, or it is not in a
## broken window), every OTHER living party member is also struck at
## `splash_power`. Used by Immolate (no splash) and Avalanche (splash unless
## Broken).
static func _boss_signature_hit(
	battle: Battle,
	boss: Dictionary,
	power: float,
	splash_power := 0.0,
	splash_unbroken_only := false
) -> void:
	var target := battle._enemy_target()
	if target.is_empty():
		return
	battle.boss_strike(boss, target, power)
	if splash_power <= 0.0:
		return
	if splash_unbroken_only and int(boss.get("broken_turns", 0)) != 0:
		return
	for c in battle.living_party():
		if String(c["id"]) != String(target["id"]):
			battle.boss_strike(boss, c, splash_power)


## §4.1 Berserker turn. Telegraph (every telegraph_interval turns): Immolate =
## signature_power x a normal hit on the lowest-HP party member. Off-telegraph
## even kit-turns: a basic attack that also applies the burn poison. Other
## turns: a plain basic attack. Always owns the turn -> returns true.
static func _berserker_turn(battle: Battle, boss: Dictionary) -> bool:
	var kit_turn := int(boss.get("_kit_turn", 0)) + 1
	boss["_kit_turn"] = kit_turn
	var tele := int(boss.get("turns_until_big_hit", BOSS_KITS["berserker"]["telegraph_interval"]))
	if tele <= 0:
		_boss_signature_hit(battle, boss, BOSS_KITS["berserker"]["signature_power"])
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0, kit_turn % 2 == 0)
	return true


## §4.5 Colossus turn. Telegraph (every telegraph_interval turns -> 3 in
## phase 2): Avalanche = signature_power x a hit on the lowest-HP party
## member, plus a 1.0x splash on the rest UNLESS the boss is Broken. No
## ability -- every other turn is a plain basic attack. Always owns the
## turn -> returns true.
static func _colossus_turn(battle: Battle, boss: Dictionary) -> bool:
	var tele := int(boss.get("turns_until_big_hit", BOSS_KITS["colossus"]["telegraph_interval"]))
	if tele <= 0:
		_boss_signature_hit(
			battle,
			boss,
			BOSS_KITS["colossus"]["signature_power"],
			BOSS_KITS["colossus"]["avalanche_splash_power"],
			true
		)
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0)
	return true


## §4.2 Warden turn. Ability FIRST: when its own HP is under bastion_hp_gate and
## Bastion has not fired this phase, cast Bastion (that IS the turn). Otherwise
## telegraph (every telegraph_interval turns): Shield Bash = signature_power x a
## hit on the lowest-HP party member, plus a 1t stun on it. Every other turn is a
## plain basic attack. Always owns the turn -> returns true.
static func _warden_turn(battle: Battle, boss: Dictionary) -> bool:
	var kit_turn := int(boss.get("_kit_turn", 0)) + 1
	boss["_kit_turn"] = kit_turn
	var phase := int(boss.get("phase", 1))
	if (
		battle._hp_fraction(boss) < float(BOSS_KITS["warden"]["bastion_hp_gate"])
		and int(boss.get("_bastion_phase_used", 0)) != phase
	):
		_bastion(battle, boss)
		boss["_bastion_phase_used"] = phase
		return true
	var tele := int(boss.get("turns_until_big_hit", BOSS_KITS["warden"]["telegraph_interval"]))
	if tele <= 0:
		var t := battle._enemy_target()
		if not t.is_empty():
			battle.boss_strike(boss, t, float(BOSS_KITS["warden"]["signature_power"]))
			if int(t.get("hp", 0)) > 0:
				battle.apply_status(t, "stun", 1)
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0)
	return true


## §4.2 Bastion: self def-buff x bastion_def_mult for bastion_turns AND a full
## self-cleanse (wipe `statuses`, clear any atk-down). Used by the once-per-phase
## ability check and, unconditionally, by the on-phase hook.
static func _bastion(battle: Battle, boss: Dictionary) -> void:
	var kit: Dictionary = BOSS_KITS["warden"]
	var def_mult := maxf(float(boss.get("def_multiplier", 1.0)), float(kit["bastion_def_mult"]))
	boss["def_multiplier"] = def_mult
	boss["def_mod_turns"] = int(kit["bastion_turns"])
	boss["statuses"] = {}
	boss["atk_multiplier"] = maxf(float(boss.get("atk_multiplier", 1.0)), 1.0)
	boss["atk_buff_turns"] = 0
	battle.log.append({"type": "bastion", "actor_id": boss["id"]})


## §4.4 Hexer turn. Telegraph (every telegraph_interval turns): Doom (party-wide,
## see _doom). Otherwise, on every siphon_interval-th kit-turn: Siphon = drain
## siphon_frac of one party member's current HP and self-heal the same. Every
## other turn is a basic attack that, on even kit-turns (Withering Aura), also
## lands an atk-down on the target. Always owns the turn -> returns true.
static func _hexer_turn(battle: Battle, boss: Dictionary) -> bool:
	var kit_turn := int(boss.get("_kit_turn", 0)) + 1
	boss["_kit_turn"] = kit_turn
	var kit: Dictionary = BOSS_KITS["hexer"]
	var tele := int(boss.get("turns_until_big_hit", kit["telegraph_interval"]))
	if tele <= 0:
		_doom(battle, boss)
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	if kit_turn % int(kit["siphon_interval"]) == 0:
		var t := battle._enemy_target()
		if not t.is_empty():
			var drain := int(round(float(t["hp"]) * float(kit["siphon_frac"])))
			t["hp"] = maxi(0, int(t["hp"]) - drain)
			boss["hp"] = mini(int(boss["max_hp"]), int(boss["hp"]) + drain)
			battle.log.append(
				{"type": "siphon", "actor_id": boss["id"], "target_id": t["id"], "amount": drain}
			)
		return true
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0)
		if kit_turn % 2 == 0 and int(target.get("hp", 0)) > 0:
			target["atk_multiplier"] = float(kit["atkdown_mult"])
			target["atk_buff_turns"] = int(kit["atkdown_turns"])
	return true


## §4.4 Doom: hit every living party member at doom_power, then land an atk-down
## on each survivor (atkdown_mult, or the deeper atkdown_mult_phase2 once the boss
## is in phase 2), for atkdown_turns.
static func _doom(battle: Battle, boss: Dictionary) -> void:
	var kit: Dictionary = BOSS_KITS["hexer"]
	var mult := float(kit["atkdown_mult"])
	if int(boss.get("phase", 1)) == 2:
		mult = float(kit["atkdown_mult_phase2"])
	for c in battle.living_party():
		battle.boss_strike(boss, c, float(kit["doom_power"]))
	for c in battle.living_party():
		c["atk_multiplier"] = mult
		c["atk_buff_turns"] = int(kit["atkdown_turns"])
	battle.log.append({"type": "doom", "actor_id": boss["id"], "atkdown": mult})


## §4.3 Broodmother turn. Telegraph (every telegraph_interval turns): Devour =
## signature_power x a hit on the lowest-HP party member; the boss then heals
## devour_heal_frac of the HP actually removed. Off-telegraph, on every
## spawn_interval-th kit-turn STAGGERED from the telegraph (kit_turn % 3 == 1):
## Spawn one skirmisher add (capped by spawn_add). Every other turn is a plain
## basic attack. Always owns the turn -> returns true.
static func _broodmother_turn(battle: Battle, boss: Dictionary) -> bool:
	var kit_turn := int(boss.get("_kit_turn", 0)) + 1
	boss["_kit_turn"] = kit_turn
	var kit: Dictionary = BOSS_KITS["broodmother"]
	var tele := int(boss.get("turns_until_big_hit", kit["telegraph_interval"]))
	if tele <= 0:
		var t := battle._enemy_target()
		if not t.is_empty():
			var actual := battle.boss_strike(boss, t, float(kit["signature_power"]))
			var healed := int(round(float(actual) * float(kit["devour_heal_frac"])))
			boss["hp"] = mini(int(boss["max_hp"]), int(boss["hp"]) + healed)
			battle.log.append({"type": "devour_heal", "actor_id": boss["id"], "amount": healed})
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	if kit_turn % int(kit["spawn_interval"]) == 1:
		battle.spawn_add(boss)
		return true
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0)
	return true


## §4.6 Revenant turn. Death-window bookkeeping runs FIRST (an expired,
## un-Broken window revives the boss to `revive_frac` of max HP, then the boss
## still acts). Telegraph (every telegraph_interval turns): Grave Chill =
## signature_power x a hit on the lowest-HP party member, plus atk-down
## x grave_chill_atkdown for atkdown_turns. Off-telegraph, every
## leech_interval-th kit-turn: Leech = a basic attack that heals the boss for
## leech_heal_frac of the HP removed. Every other turn is a plain basic
## attack. Always owns the turn -> returns true.
static func _revenant_turn(battle: Battle, boss: Dictionary) -> bool:
	var kit: Dictionary = BOSS_KITS["revenant"]
	var kt := int(boss.get("_kit_turn", 0)) + 1
	boss["_kit_turn"] = kt
	if bool(boss.get("death_window", false)):
		boss["death_window_turns"] = int(boss.get("death_window_turns", 0)) - 1
		if int(boss["death_window_turns"]) <= 0:
			boss["hp"] = int(round(float(boss["max_hp"]) * float(kit["revive_frac"])))
			boss["death_window"] = false
			battle.log.append(
				{"type": "undying_revive", "actor_id": boss["id"], "hp": int(boss["hp"])}
			)
	var tele := int(boss.get("turns_until_big_hit", kit["telegraph_interval"]))
	if tele <= 0:
		var t := battle._enemy_target()
		if not t.is_empty():
			battle.boss_strike(boss, t, float(kit["signature_power"]))
			if int(t.get("hp", 0)) > 0:
				t["atk_multiplier"] = float(kit["grave_chill_atkdown"])
				t["atk_buff_turns"] = int(kit["atkdown_turns"])
		boss["turns_until_big_hit"] = battle._boss_telegraph_interval(boss)
		return true
	boss["turns_until_big_hit"] = tele - 1
	if kt % int(kit["leech_interval"]) == 0:
		var t2 := battle._enemy_target()
		if not t2.is_empty():
			var a := battle.boss_strike(boss, t2, 1.0)
			var healed := int(round(float(a) * float(kit["leech_heal_frac"])))
			boss["hp"] = mini(int(boss["max_hp"]), int(boss["hp"]) + healed)
			battle.log.append({"type": "leech_heal", "actor_id": boss["id"], "amount": healed})
		return true
	var target := battle._enemy_target()
	if not target.is_empty():
		battle.boss_strike(boss, target, 1.0)
	return true


## Called from Battle._land_hit before a lethal blow is written. Returns true
## if the kit intercepts it (Revenant Undying, §4.6) -- Battle then leaves the
## boss at 1 HP instead of 0 and the Death Window opens for death_window_turns.
static func on_would_die(battle: Battle, boss: Dictionary) -> bool:
	match String(boss.get("kit", "")):
		"revenant":
			if bool(boss.get("undying_spent", false)):
				return false
			boss["undying_spent"] = true
			boss["death_window"] = true
			boss["death_window_turns"] = int(BOSS_KITS["revenant"]["death_window_turns"])
			battle.log.append({"type": "undying", "actor_id": boss["id"]})
			return true
		_:
			return false
