class_name HunterState
## The hunter's persistent progression state: level, EXP, subclass, and the
## soft currencies. Pure -- to_dict()/from_dict() are the only interface to
## the outside world, no file I/O here (see autoload/save_service.gd).

var level: int
var exp_into_level: int  ## progress toward exp_to_next(level); resets on level-up
var total_exp: int  ## lifetime total, cosmetic/statistic only
var subclass: String  ## WARRIOR / GUARDIAN / ASSASSIN / MAGE / SUPPORT
var essence: int
var gate_tickets: int
var army: Array  ## Array[Dictionary]: {instance_id, monster_id, grade, level}. Class isn't
## stored per-shadow -- look it up from monster_id via Content when needed, same as the
## design bible's ShadowInstance (don't duplicate content data into save state).
var last_exp_date: String  ## "YYYY-MM-DD" (device-local calendar date) of the last daily-EXP
## grant, "" if never. NOTE: the native plugin's readTodaySteps()/readRecentWorkouts() use a
## rolling 24h window, not a calendar day -- this guard stops same-day relaunch double-counts,
## but doesn't perfectly line up with that window (e.g. playing at 11pm then 1am still counts
## as two different calendar days despite mostly-overlapping step data). Good enough for v0.
var inventory: Array  ## Array[Dictionary]: {instance_id, equipment_def_id, enhancement_level}.
## Like army, doesn't duplicate content data -- look up name/slot/rarity/stat_mods/power_bonus
## from equipment_def_id via Content when needed.


static func new_default(hunter_subclass: String = "WARRIOR") -> HunterState:
	var s := HunterState.new()
	s.level = 1
	s.exp_into_level = 0
	s.total_exp = 0
	s.subclass = hunter_subclass
	s.essence = 0
	s.gate_tickets = 0
	s.army = []
	s.last_exp_date = ""
	s.inventory = []
	return s


## Adds an unenhanced instance of the given equipment def to the inventory.
## Pure -- instance_id is index-based, same convention as claim_shadow().
func add_to_inventory(equipment_def_id: String) -> Dictionary:
	var item := {
		"instance_id": "eq_inst_%d" % inventory.size(),
		"equipment_def_id": equipment_def_id,
		"enhancement_level": 0,
	}
	inventory.append(item)
	return item


func has_applied_exp_today(today: String) -> bool:
	return last_exp_date == today


func mark_exp_applied(today: String) -> void:
	last_exp_date = today


## Adds a level-1 shadow of the given monster/grade to the army. Pure --
## instance_id is just index-based (no wall-clock/UUID dependency, keeps
## this deterministic and testable).
func claim_shadow(monster_id: String, grade: String) -> Dictionary:
	var shadow := {
		"instance_id": "shadow_%d" % army.size(),
		"monster_id": monster_id,
		"grade": grade,
		"level": 1,
	}
	army.append(shadow)
	return shadow


## Stats derived from level x subclass (§16), via GameLogic -- this is the
## "wiring" point between saved state and pure formulas.
func stats() -> Dictionary:
	return GameLogic.stats_from(level, subclass)


## Adds EXP, applies any level-ups (can be more than one), returns how many
## levels were gained. Pure -- no signals, no side effects beyond self.
func add_exp(amount: int) -> int:
	if amount <= 0:
		return 0
	total_exp += amount
	exp_into_level += amount
	var levels_gained := 0
	while exp_into_level >= GameLogic.exp_to_next(level):
		exp_into_level -= GameLogic.exp_to_next(level)
		level += 1
		levels_gained += 1
	return levels_gained


func to_dict() -> Dictionary:
	return {
		"level": level,
		"exp_into_level": exp_into_level,
		"total_exp": total_exp,
		"subclass": subclass,
		"essence": essence,
		"gate_tickets": gate_tickets,
		"army": army,
		"last_exp_date": last_exp_date,
		"inventory": inventory,
	}


static func from_dict(d: Dictionary) -> HunterState:
	var s := HunterState.new()
	s.level = int(d.get("level", 1))
	s.exp_into_level = int(d.get("exp_into_level", 0))
	s.total_exp = int(d.get("total_exp", 0))
	s.subclass = String(d.get("subclass", "WARRIOR"))
	s.essence = int(d.get("essence", 0))
	s.gate_tickets = int(d.get("gate_tickets", 0))
	s.army = d.get("army", [])
	s.last_exp_date = String(d.get("last_exp_date", ""))
	s.inventory = d.get("inventory", [])
	return s
