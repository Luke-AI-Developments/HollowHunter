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
