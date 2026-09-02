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
		_:
			return false


## One-time per-boss effect when it crosses into phase 2 (spec §3.5).
static func on_phase(battle: Battle, boss: Dictionary) -> void:
	match String(boss.get("kit", "")):
		"berserker":
			# §4.1 on-phase: the Fury cap bump is automatic (rising_fury_mult
			# reads `phase`); the free Immolate fires here.
			_boss_signature_hit(battle, boss, BOSS_KITS["berserker"]["signature_power"])
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


## Called from Battle._land_hit before a lethal blow is written. Returns true
## if the kit intercepts it (Revenant Undying, Task 6) -- Battle then leaves
## the boss at 1 HP instead of 0.
static func on_would_die(_battle: Battle, boss: Dictionary) -> bool:
	match String(boss.get("kit", "")):
		_:
			return false
