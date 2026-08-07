class_name GameLogic
extends RefCounted

## Placeholder pure-logic smoke test -- proves core/ + GUT wiring works
## end to end. Real game formulas (EXP, power, clear-probability from the
## concept doc) come later; the plugin spike is still the active task.


static func add(a: int, b: int) -> int:
	return a + b


static func clamp_percent(value: float) -> float:
	return clamp(value, 0.0, 1.0)
