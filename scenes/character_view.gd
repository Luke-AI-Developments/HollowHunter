class_name CharacterView
extends Node2D
## The Hunter/character screen (§21) as its own controller script -- see
## HunterGearView's doc comment for the split-out rationale. Owns the
## Rank-Up Trial action too: _current_gate_power() moved here from
## main.gd since it was only ever used by this button (the §16 combat
## overhaul migrated gates themselves off it -- see core/gate_encounter.gd's
## own doc comment for why that function is otherwise dead).
##
## Fitness display data (steps/workouts_json/gps_status/health_status)
## stays owned by main.gd's GPS/Health bridge callbacks -- passed into
## refresh()/open() rather than duplicated here, since it changes
## independently of state and arrives asynchronously (main.gd already has
## to re-call refresh() itself when a signal lands while this panel is open).

signal state_changed
signal trial_result(message: String)

var _state: HunterState
var _equipment: Dictionary
var _monsters: Array

@onready var info_label: Label = $InfoLabel
@onready var fitness_label: Label = $FitnessLabel
@onready var health_label: Label = $HealthStatusLabel
@onready var trial_button: Button = $TrialButton
@onready var portrait_rect: TextureRect = $PortraitRect


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: visible = false)
	trial_button.pressed.connect(_on_trial_pressed)


## Called from main.gd's _start_game() (both the existing-save and
## new-game bootstrap paths) -- state/_equipment/_monsters aren't ready at
## _ready().
func bind(state: HunterState, equipment: Dictionary, monsters: Array) -> void:
	_state = state
	_equipment = equipment
	_monsters = monsters


func open(steps: int, workouts_json: String, gps_status: String, health_status: String) -> void:
	visible = true
	refresh(steps, workouts_json, gps_status, health_status)


## Identity/stats/rank/GATE_POWER + today's fitness breakdown (steps/
## workout minutes/signature match/streak, reusing DailyExp's existing
## pure functions on the already-fetched steps/workouts_json -- no new
## state needed) + a persistent health-connection status line. Shows the
## chosen preset portrait (ArtPaths.preset_portrait(), keyed by the
## hunter's rank-derived art stage via GameLogic.stage_for_rank()) --
## no rank-glow/aura overlay or equipment paper-doll yet (§9b flags both
## as later work), so the portrait itself is still placeholder-simple.
func refresh(steps: int, workouts_json: String, gps_status: String, health_status: String) -> void:
	var stats := _state.stats()
	portrait_rect.texture = ArtPaths.preset_portrait(
		_state.preset_id, GameLogic.stage_for_rank(_state.hunter_rank)
	)
	var exp_needed := GameLogic.exp_to_next(_state.level)
	var pct := 0.0
	if exp_needed > 0:
		pct = float(_state.exp_into_level) / float(exp_needed) * 100.0
	var filled := int(round(pct / 10.0))
	var bar := "[%s%s] %d%%" % ["=".repeat(filled), "-".repeat(10 - filled), int(pct)]

	# §28: Rank is EARNED (state.hunter_rank), not auto-derived from level.
	var next_rank := RankAssessment.next_assessment_rank(_state.level, _state.hunter_rank)
	var assessment_text: String
	if next_rank != "":
		assessment_text = "Assessment available: %s Trial!" % next_rank
		trial_button.disabled = false
	elif _state.hunter_rank == GameLogic.RANK_ORDER[GameLogic.RANK_ORDER.size() - 1]:
		assessment_text = "Rank maxed (Sovereign)"
		trial_button.disabled = true
	else:
		var tier_idx := GameLogic.RANK_ORDER.find(_state.hunter_rank) + 1
		var next_tier: String = GameLogic.RANK_ORDER[tier_idx]
		var need_level: int = GameLogic.RANK_LEVEL.get(next_tier, 0)
		assessment_text = "Next Trial (%s) unlocks at Level %d" % [next_tier, need_level]
		trial_button.disabled = true

	info_label.text = (
		(
			"Necromancer -- %s subclass\nLevel %d   Rank %s (earned)\nEXP: %d / %d  %s"
			+ "\n\nSTR %d  AGI %d  VIT %d  END %d  SEN %d\n\nGATE_POWER: %d\n\n%s"
		)
		% [
			_state.subclass,
			_state.level,
			_state.hunter_rank,
			_state.exp_into_level,
			exp_needed,
			bar,
			stats["STR"],
			stats["AGI"],
			stats["VIT"],
			stats["END"],
			stats["SEN"],
			_state.personal_power(_equipment),
			assessment_text,
		]
	)

	# Reuses GameLogic.daily_exp() directly (rather than DailyExp.
	# exp_for_today(), which would re-parse workouts_json from scratch)
	# since workout_minutes/matched are needed for display anyway.
	var workouts := DailyExp.parse_workouts(workouts_json)
	var workout_minutes := DailyExp.total_workout_minutes(workouts)
	var matched := DailyExp.matches_signature_training(workouts, _state.subclass)
	var steps_display := "%d" % steps if steps >= 0 else "Fetching..."
	var today_exp := 0
	if steps >= 0 and not workouts_json.is_empty():
		today_exp = GameLogic.daily_exp(steps, 0, workout_minutes, matched)

	fitness_label.text = (
		"Today: %s steps, %d workout min%s\nEXP earned today: %d\nStreak: %d day(s)"
		% [
			steps_display,
			workout_minutes,
			"  (1.5x signature!)" if matched else "  (1x)",
			today_exp,
			_state.current_streak,
		]
	)

	health_label.text = "GPS: %s\nHealth Connect: %s" % [gps_status, health_status]


## GATE_POWER (§16): personal power + your fielded party's power (not the
## whole army, unlike raids -- gates weight the party at GATE_ARMY_WEIGHT).
## The source says Rank-Up Assessment Trials also "uses GATE_POWER (you +
## squad)" (§28) -- the only remaining caller since the §16 combat overhaul
## moved gates themselves off it. An understrength (0-2) or empty party is
## fine here -- resolve_party just returns fewer entries, so squad_power is
## simply lower.
func _current_gate_power() -> int:
	var party := SquadBuilder.resolve_party(
		_state.army, _monsters, _state.level, _state.active_party_ids, _equipment, _state.inventory
	)
	var squad_power := 0
	for member: Dictionary in party:
		squad_power += member["power"]
	var personal := _state.personal_power(_equipment)
	return GameLogic.gate_power(personal, squad_power)


## Attempts the currently-unlocked Rank-Up Assessment Trial (§28). No-op
## if none is available (button is disabled in that state too, but this
## guards direct calls). Not claimable -- no CLAIM roll on a clear, unlike
## gates.
func _on_trial_pressed() -> void:
	var target_rank := RankAssessment.next_assessment_rank(_state.level, _state.hunter_rank)
	if target_rank == "":
		return

	var gate_power := _current_gate_power()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := RankAssessment.attempt(gate_power, target_rank, _monsters, rng)

	var msg := "\n\n%s Rank Trial: %s" % [target_rank, "PASSED" if result["cleared"] else "FAILED"]
	if result["cleared"]:
		_state.pass_assessment(target_rank)
		var reward := RankAssessment.essence_reward(target_rank)
		_state.essence += reward
		var crystal_reward := RankAssessment.crystal_reward(target_rank)
		_state.crystals += crystal_reward
		msg += (
			"\nPromoted to Rank %s! +%d Essence, +%d Crystals"
			% [target_rank, reward, crystal_reward]
		)
	else:
		msg += "\nFree retry any time -- train up and come back."

	SaveService.save(_state)
	state_changed.emit()
	trial_result.emit(msg)
