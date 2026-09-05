class_name BreakBar
## Spec §5 (break bar) / §6.1 (Monarch Gauge) / §3.5 (phase transitions):
## boss stagger bookkeeping and the shared party gauge. State
## (break_current/break_max/broken_turns/break_count on boss dicts,
## `monarch_gauge` on the Battle instance) lives on the Battle instance;
## these static helpers are the logic, split out of core/battle.gd to keep
## it under the file-length lint. Pure -- no engine deps beyond `battle`.


## Adds `amount` (may be negative-safe: it is clamped) to a boss's break
## bar (spec §5.2). No-op for a non-boss, a boss with no bar, or a boss
## that is already broken (it refills from 0 only after the stagger ends).
static func add_break_fill(battle: Battle, boss: Dictionary, amount: float) -> void:
	if not boss.get("is_boss", false) or not boss.has("break_max"):
		return
	if int(boss.get("broken_turns", 0)) > 0:
		return
	var bmax: float = boss["break_max"]
	var before: float = boss["break_current"]
	var raw := before + amount  ## pre-clamp total, so an overshoot is measurable (spec §5.3)
	boss["break_current"] = clampf(raw, 0.0, bmax)
	(
		battle
		. log
		. append(
			{
				"type": "break_fill",
				"target_id": boss["id"],
				"amount": int(round(boss["break_current"] - before)),
				"current": int(round(boss["break_current"])),
				"max": int(round(bmax)),
			}
		)
	)
	maybe_break(battle, boss, raw)


## Spec §5.3: when a boss's bar is full, stagger it. Idempotent while the
## boss is already broken (broken_turns > 0 blocks re-entry, and
## add_break_fill won't have filled it anyway). `raw_fill` is the pre-clamp
## bar total from add_break_fill -- the overshoot the clamp on break_current
## would otherwise erase (spec §5.3's ">=50% overfill -> 2-turn stagger");
## defaults to reading break_current for the direct-poke callers (tests).
static func maybe_break(battle: Battle, boss: Dictionary, raw_fill: float = -1.0) -> void:
	if int(boss.get("broken_turns", 0)) > 0:
		return
	var bmax: float = boss.get("break_max", 0.0)
	if bmax <= 0.0 or float(boss.get("break_current", 0.0)) < bmax:
		return
	var reached: float = raw_fill if raw_fill >= 0.0 else float(boss.get("break_current", 0.0))
	var overfill := (reached - bmax) / bmax
	var stun_turns := (
		battle.BREAK_STUN_TURNS_LONG
		if overfill >= battle.BREAK_OVERFILL_LONG_STUN
		else battle.BREAK_STUN_TURNS_SHORT
	)
	boss["broken_turns"] = stun_turns
	# cancel any pending telegraph
	boss["turns_until_big_hit"] = telegraph_interval(battle, boss)
	var statuses: Dictionary = boss["statuses"]
	statuses["stun"] = maxi(int(statuses.get("stun", 0)), battle.BREAK_STUN_TURNS_SHORT)
	boss["break_count"] = int(boss["break_count"]) + 1
	boss["break_max"] = bmax * battle.BREAK_REFILL_MULT
	boss["break_current"] = 0.0
	(
		battle
		. log
		. append(
			{
				"type": "break",
				"target_id": boss["id"],
				"break_count": boss["break_count"],
				"stun_turns": stun_turns,
				"new_break_max": int(round(boss["break_max"])),
			}
		)
	)
	add_monarch_gauge(battle, battle.MONARCH_GAUGE_ON_BREAK)
	# §4.6 Undying: a Revenant Broken while its Death Window is open dies now,
	# regardless of whether its own turn ever comes up again.
	if boss.get("death_window", false):
		boss["hp"] = 0
		boss["death_window"] = false
		battle.log.append({"type": "undying_shatter", "actor_id": boss["id"]})


## Telegraph cadence (turns between big hits) for this boss. A kitted boss
## reads its kit's `telegraph_interval` (or `phase2_telegraph_interval` once
## in phase 2, spec §3.5); a non-kit boss keeps the phase-agnostic default.
static func telegraph_interval(battle: Battle, boss: Dictionary) -> int:
	var kit := String(boss.get("kit", ""))
	if kit != "" and BossKits.BOSS_KITS.has(kit):
		var t: Dictionary = BossKits.BOSS_KITS[kit]
		return int(
			(
				t["phase2_telegraph_interval"]
				if int(boss.get("phase", 1)) == 2
				else t["telegraph_interval"]
			)
		)
	return battle.BOSS_BIG_HIT_INTERVAL


## Spec §3.5: a multi-phase boss crossing 50% HP downward enters phase 2 --
## flips the flag and logs. The kit's on-phase effect is fired by the kit
## dispatch (Tasks 3-6); the tightened telegraph cadence is read off `phase`
## in _resolve_enemy_turn. No-op for a single-phase boss, one already in
## phase 2, a dead boss, or one still above 50% HP.
static func check_phase_transition(battle: Battle, boss: Dictionary) -> void:
	if not boss.get("is_multiphase", false):
		return
	if int(boss.get("phase", 1)) != 1 or boss.get("hp", 0) <= 0:
		return
	if battle._hp_fraction(boss) > 0.5:
		return
	boss["phase"] = 2
	battle.log.append({"type": "phase", "actor_id": boss["id"], "phase": 2})
	BossKits.on_phase(battle, boss)


## Spec §6.1. Offence-weighted party gauge fill. Emits a `gauge` event
## only on a real change so the log/HUD can react.
static func add_monarch_gauge(battle: Battle, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var before := battle.monarch_gauge
	battle.monarch_gauge = clampf(battle.monarch_gauge + amount, 0.0, battle.MONARCH_GAUGE_MAX)
	if not is_equal_approx(before, battle.monarch_gauge):
		(
			battle
			. log
			. append(
				{
					"type": "gauge",
					"amount": int(round(battle.monarch_gauge - before)),
					"current": int(round(battle.monarch_gauge)),
				}
			)
		)


static func can_use_ultimate(battle: Battle) -> bool:
	return battle.monarch_gauge >= battle.MONARCH_GAUGE_MAX
