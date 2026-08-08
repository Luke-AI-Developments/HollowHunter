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


static func new_default(hunter_subclass: String = "WARRIOR") -> HunterState:
	var s := HunterState.new()
	s.level = 1
	s.exp_into_level = 0
	s.total_exp = 0
	s.subclass = hunter_subclass
	s.essence = 0
	s.gate_tickets = 0
	return s


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
	}


static func from_dict(d: Dictionary) -> HunterState:
	var s := HunterState.new()
	s.level = int(d.get("level", 1))
	s.exp_into_level = int(d.get("exp_into_level", 0))
	s.total_exp = int(d.get("total_exp", 0))
	s.subclass = String(d.get("subclass", "WARRIOR"))
	s.essence = int(d.get("essence", 0))
	s.gate_tickets = int(d.get("gate_tickets", 0))
	return s
