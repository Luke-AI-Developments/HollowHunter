extends Node2D

## Phase 1 steps 3-6 (+ subclass picker, daily-EXP double-count guard): real
## daily EXP from Health Connect -> level up, a simple map (live GPS
## position + placeholder gates), gate encounters (3-round clash -> boss
## CLAIM -> shadow), and an army list with an auto-filled class-slotted
## squad -- replacing the native-plugin-spike test harness (checkpoints
## 2-4) with actual game wiring. GPS/Health Connect permission requests
## start immediately regardless of the picker, so they're ready by the
## time a subclass is chosen.

const CLASSES := ["WARRIOR", "GUARDIAN", "ASSASSIN", "MAGE", "SUPPORT"]

var bridge: Object
var state: HunterState
var _monsters: Array
var _equipment: Dictionary
var _steps: int = -1
var _workouts_json: String = ""
var _health_applied := false
var _gps_status := "Requesting..."  ## Phase 2/P5 step 2: §21's "health connection" status line
var _health_status := "Requesting..."
var _has_location := false  ## Phase 2/P7 step 1: whether _last_lat/_last_lon are real yet
var _last_lat: float = 0.0  ## most recent GPS fix -- §8a's ticket gate spawns "where you are"
var _last_lon: float = 0.0
var _pending_break_gate: Dictionary = {}  ## Phase 2/P8: the offered-but-not-yet-answered §8b gate
var _moves: Array = []  ## Phase 3/step 5: content/moves.json, loaded once (§16 combat overhaul)
var _shop_catalog: Dictionary = {}  ## Phase 4/shop step 1: content/shop.json, loaded once
var _pending_battle_gate: Dictionary = {}  ## the gate a live BattlePanel fight will resolve into
var _pending_battle_prefix: String = ""  ## "[Ticket]"/"[GATE BREAK]" label text, carried through
var _pending_battle_is_break: bool = false  ## whether to apply GateBreak's bonus on a win
var _pending_nadir_floor: int = -1  ## Phase 3/P3-Nadir: >=0 while a BattlePanel fight is
## resolving a Nadir floor instead of a gate -- _on_battle_finished branches on this
var _pending_nadir_is_boss: bool = false  ## whether that floor is a boss floor (§20)
var _pending_nadir_boss_id: String = ""  ## that boss floor's stand-in boss monster id

@onready var subclass_picker: Node2D = $SubclassPicker
@onready var subclass_title_label: Label = $SubclassPicker/TitleLabel
@onready var welcome_label: Label = $SubclassPicker/WelcomeLabel
@onready var continue_button: Button = $SubclassPicker/ContinueButton
@onready var game_ui: Node2D = $GameUI
@onready var label: Label = $GameUI/Label
@onready var map_view: MapView = $GameUI/MapView
@onready var enter_gate_button: Button = $GameUI/EnterGateButton
@onready var inventory_button: Button = $GameUI/InventoryButton
@onready var inventory_view: InventoryView = $GameUI/InventoryPanel
@onready var hunter_gear_button: Button = $GameUI/HunterGearButton
@onready var hunter_gear_view: HunterGearView = $GameUI/HunterGearPanel
@onready var shadow_gear_view: ShadowGearView = $GameUI/ShadowGearPanel
@onready var army_button: Button = $GameUI/ArmyButton
@onready var army_view: ArmyView = $GameUI/ArmyPanel
@onready var nadir_button: Button = $GameUI/NadirButton
@onready var nadir_panel: Node2D = $GameUI/NadirPanel
@onready var nadir_info_label: Label = $GameUI/NadirPanel/InfoLabel
@onready var nadir_take_on_button: Button = $GameUI/NadirPanel/TakeOnButton
@onready var stronghold_button: Button = $GameUI/StrongholdButton
@onready var stronghold_view: StrongholdView = $GameUI/StrongholdPanel
@onready var character_button: Button = $GameUI/CharacterButton
@onready var character_view: CharacterView = $GameUI/CharacterPanel
@onready var use_ticket_button: Button = $GameUI/UseTicketButton
@onready var shop_button: Button = $GameUI/ShopButton
@onready var shop_view: ShopView = $GameUI/ShopPanel
@onready var leaderboard_button: Button = $GameUI/LeaderboardButton
@onready var leaderboard_view: LeaderboardView = $GameUI/LeaderboardPanel
@onready var gate_break_panel: Node2D = $GameUI/GateBreakPanel
@onready var gate_break_info_label: Label = $GameUI/GateBreakPanel/InfoLabel
@onready var gate_break_accept_button: Button = $GameUI/GateBreakPanel/AcceptButton
@onready var gate_break_dismiss_button: Button = $GameUI/GateBreakPanel/DismissButton
@onready var gate_break_timer: Timer = $GateBreakTimer
@onready var battle_view: BattleView = $GameUI/BattlePanel


func _ready() -> void:
	_monsters = Content.load_monsters()
	_equipment = Content.load_equipment()
	_moves = Content.load_moves()
	_shop_catalog = Content.load_shop()
	shop_view.setup(_shop_catalog)
	battle_view.battle_finished.connect(_on_battle_finished)

	# Phase 2/P10: whether GPS/Health permissions get requested below THIS
	# _ready() call, or deferred until after onboarding (§25 -- "value
	# before permissions"). Captured before load_or_create() below, which
	# would otherwise make the file "exist" even for a brand-new hunter.
	var is_new_hunter := not FileAccess.file_exists(SaveService.SAVE_PATH)

	if not is_new_hunter:
		state = SaveService.load_or_create()
		subclass_picker.visible = false
		game_ui.visible = true
		_start_game()
	else:
		_show_subclass_picker()

	if not Engine.has_singleton("GpsHealthBridge"):
		_gps_status = "Bridge not found"
		_health_status = "Bridge not found"
		label.text += "\n\nGpsHealthBridge singleton not found"
		return
	bridge = Engine.get_singleton("GpsHealthBridge")

	bridge.location_permission_result.connect(_on_location_permission_result)
	bridge.location_update.connect(_on_location_update)
	bridge.health_connect_available.connect(_on_health_connect_available)
	bridge.health_permission_result.connect(_on_health_permission_result)
	bridge.steps_result.connect(_on_steps_result)
	bridge.workouts_result.connect(_on_workouts_result)

	if is_new_hunter:
		# Deferred to _on_onboarding_continue_pressed(), after the guided
		# first gate/CLAIM (§25 step 5 comes after step 4, not before it).
		return
	bridge.requestLocationPermission()
	bridge.checkHealthConnectAvailable()


## The subclass is permanent once picked (design bible §21) -- this screen
## only shows for a genuinely new hunter (no save file yet), never again.
func _show_subclass_picker() -> void:
	subclass_picker.visible = true
	game_ui.visible = false
	for clazz in CLASSES:
		var button: Button = subclass_picker.get_node("%sButton" % clazz.capitalize())
		button.pressed.connect(_on_subclass_chosen.bind(clazz))
	continue_button.pressed.connect(_on_onboarding_continue_pressed)


## Phase 2/P10: §25 steps 3-4 -- a free starter shadow, then a scripted,
## guaranteed-win first gate/CLAIM, BEFORE _start_game() or any
## permission request (those wait for _on_onboarding_continue_pressed()).
## Reuses the SubclassPicker screen (WelcomeLabel/ContinueButton) rather
## than a new panel -- same "one screen, swap its content" pattern as
## nothing-new-to-build-here.
func _on_subclass_chosen(subclass: String) -> void:
	state = SaveService.load_or_create(subclass)

	var starter_id := Onboarding.starter_monster_id(subclass, _monsters)
	state.claim_shadow(starter_id, "E")
	var starter_name: String = Content.monster_by_id(_monsters, starter_id).get("name", "")

	var gate_monster_id := Onboarding.guided_gate_monster_id(starter_id, _monsters)
	var result := Onboarding.resolve_guided_gate(gate_monster_id, _monsters)
	state.claim_shadow(result["monster_id"], "E")
	SaveService.save(state)

	for clazz in CLASSES:
		subclass_picker.get_node("%sButton" % clazz.capitalize()).visible = false
	subclass_title_label.visible = false
	welcome_label.visible = true
	continue_button.visible = true
	welcome_label.text = (
		(
			"Welcome, %s hunter.\n\n%s joins you as your first shadow.\n\n"
			+ "A weak gate ruptures nearby -- you clear it and CLAIM %s!\n\n"
			+ "Your real workouts and steps level up your hunter from here."
			+ " Your health data stays on your device and is never sold or shared."
		)
		% [subclass, starter_name, result["monster_name"]]
	)


## Phase 2/P10: the deferred half of §25 step 5 -- enters the real game
## and only NOW asks for GPS/Health permissions, after the guided
## first-gate win/CLAIM above already showed the payoff.
func _on_onboarding_continue_pressed() -> void:
	subclass_picker.visible = false
	game_ui.visible = true
	_start_game()
	if bridge:
		bridge.requestLocationPermission()
		bridge.checkHealthConnectAvailable()


func _start_game() -> void:
	_refresh_label()
	if not enter_gate_button.pressed.is_connected(_on_enter_gate_pressed):
		enter_gate_button.pressed.connect(_on_enter_gate_pressed)
	inventory_view.bind(state, _equipment, _monsters)
	hunter_gear_view.bind(state, _equipment, inventory_view)
	shadow_gear_view.bind(state, _equipment, _monsters, inventory_view)
	stronghold_view.bind(state)
	character_view.bind(state, _equipment, _monsters)
	leaderboard_view.bind(state, _equipment)
	army_view.bind(state, _equipment, _monsters, shadow_gear_view)
	army_view.refresh_if_open()
	_setup_gear_panels()


## Wires every button once. Idempotency guard (mirrors enter_gate_button
## above) -- _start_game() can run again (e.g. after picking a subclass)
## without double-connecting. Per-panel row-building/button-wiring now
## lives in each panel's own controller script (HunterGearView etc.) --
## this only wires the OPEN buttons and the cross-panel signals those
## controllers emit (state_changed for the shared HUD, plus the couple of
## one-off messages -- Stronghold's collect summary, a Trial result --
## that still need the shared main label).
func _setup_gear_panels() -> void:
	if not hunter_gear_button.pressed.is_connected(_on_hunter_gear_button_pressed):
		hunter_gear_button.pressed.connect(_on_hunter_gear_button_pressed)
		hunter_gear_view.state_changed.connect(_on_state_changed)
		shadow_gear_view.state_changed.connect(_on_state_changed)
		army_button.pressed.connect(func() -> void: army_view.open())
		army_view.state_changed.connect(_on_state_changed)
		army_view.mass_convert_result.connect(func(msg: String) -> void: label.text += msg)
		army_view.squad_full_message.connect(func(msg: String) -> void: label.text += msg)
		inventory_button.pressed.connect(func() -> void: inventory_view.open())
		inventory_view.state_changed.connect(_on_state_changed)
		nadir_button.pressed.connect(_on_nadir_button_pressed)
		$GameUI/NadirPanel/CloseButton.pressed.connect(_on_nadir_close_pressed)
		nadir_take_on_button.pressed.connect(_on_nadir_take_on_pressed)
		stronghold_button.pressed.connect(func() -> void: stronghold_view.open())
		stronghold_view.state_changed.connect(_on_state_changed)
		stronghold_view.collected.connect(func(msg: String) -> void: label.text += msg)
		character_button.pressed.connect(_on_character_button_pressed)
		character_view.state_changed.connect(_on_state_changed)
		character_view.trial_result.connect(_on_character_trial_result)
		use_ticket_button.pressed.connect(_on_use_ticket_pressed)
		shop_button.pressed.connect(_on_shop_button_pressed)
		shop_view.close_requested.connect(func() -> void: shop_view.visible = false)
		shop_view.buy_ticket_bundle_requested.connect(_on_buy_ticket_bundle_requested)
		shop_view.buy_essence_bundle_requested.connect(_on_buy_essence_bundle_requested)
		shop_view.buy_cosmetic_requested.connect(_on_buy_cosmetic_requested)
		leaderboard_button.pressed.connect(func() -> void: leaderboard_view.open())
		gate_break_accept_button.pressed.connect(_on_gate_break_accept_pressed)
		gate_break_dismiss_button.pressed.connect(_on_gate_break_dismiss_pressed)
		gate_break_timer.timeout.connect(_maybe_offer_gate_break)


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		_gps_status = "Linked"
		bridge.startLocationUpdates()
	else:
		_gps_status = "Permission denied"
		label.text += "\n\nGPS permission denied"


func _on_location_update(lat: float, lon: float, _accuracy: float, _timestamp_ms: int) -> void:
	# Phase 2/P7 step 1: cached for the ticket gate (§8a "at your current
	# location") -- separate from map_view, which only tracks the position
	# for its own rendering.
	_has_location = true
	_last_lat = lat
	_last_lon = lon
	if state == null:
		return  # subclass not chosen yet
	map_view.show_position(lat, lon, state.hunter_rank)


func _on_health_connect_available(available: bool) -> void:
	if available:
		_health_status = "Requesting permissions..."
		bridge.requestHealthPermissions()
	else:
		_health_status = "Health Connect not available"
		label.text += "\n\nHealth Connect not available"


func _on_health_permission_result(granted: bool) -> void:
	if granted:
		_health_status = "Linked"
		bridge.readTodaySteps()
		bridge.readRecentWorkouts(24)
	else:
		_health_status = "Permission denied"
		label.text += "\n\nHealth permission denied"


func _on_steps_result(count: int) -> void:
	_steps = count
	_maybe_apply_daily_exp()
	# Code-review fix: the Character panel only rendered once, on open --
	# if it's already open when this (async, permission-gated) signal
	# lands, it'd be stuck showing stale/placeholder data all session.
	if character_view.visible:
		character_view.refresh(_steps, _workouts_json, _gps_status, _health_status)


func _on_workouts_result(workouts_json: String) -> void:
	_workouts_json = workouts_json
	_maybe_apply_daily_exp()
	if character_view.visible:
		character_view.refresh(_steps, _workouts_json, _gps_status, _health_status)


## Both signals arrive independently and in either order; wait for both
## (steps defaults to the never-real -1, workouts_result is always at least
## the 2-char "[]" so an empty string means "not arrived yet") before
## computing EXP once. Also waits on `state` existing (subclass not chosen
## yet on a fresh install) and on HunterState's own has_applied_exp_today()
## guard, so relaunching same calendar day no longer double-counts.
func _maybe_apply_daily_exp() -> void:
	if state == null or _health_applied or _steps < 0 or _workouts_json.is_empty():
		return
	_health_applied = true

	var today := Time.get_date_string_from_system()
	if state.has_applied_exp_today(today):
		print("PHASE1: daily EXP already applied for %s, skipping" % today)
		return

	# Phase 2/P10: rest-day bonus (§4/§27) -- computed from the OLD
	# last_exp_date, same "before mark_exp_applied() overwrites it"
	# requirement as next_streak() below.
	var rest_bonus := DailyExp.rest_bonus_applies(today, state.last_exp_date)
	var exp := DailyExp.exp_for_today(_steps, _workouts_json, state.subclass, 0, rest_bonus)
	var levels_gained := state.add_exp(exp)
	# Code-review fix: next_streak() is a pure "is this the next calendar
	# day" check -- it doesn't know about exp, so a 0-steps/0-workouts day
	# (exp == 0) would still extend the streak. A streak is supposed to
	# track real engagement (§21's "motivating core"), so a zero-activity
	# day breaks it here at the call site instead, before
	# mark_exp_applied() overwrites last_exp_date.
	if exp > 0:
		state.current_streak = DailyExp.next_streak(
			today, state.last_exp_date, state.current_streak
		)
	else:
		state.current_streak = 0
	state.mark_exp_applied(today)
	SaveService.save(state)
	_refresh_label()
	if rest_bonus:
		# Positive, non-comparative framing (§27) -- a welcome-back note,
		# not a "you fell behind" one.
		label.text += "\n\nWelcome back -- rest bonus applied to today's EXP!"
	if levels_gained > 0:
		label.text += "\n\nLEVEL UP! (+%d)" % levels_gained
	print(
		(
			"PHASE1: steps=%d workouts=%s exp=%d levels_gained=%d"
			% [_steps, _workouts_json, exp, levels_gained]
		)
	)


## Phase 3/step 5 (extended step 6): this hunter's + fielded 3 shadows'
## Battle combatants (§16's party of 4) for a real fight. Which 3 is now
## SquadBuilder.resolve_party() -- honors the player's manual Squad-panel
## pick (state.active_party_ids, §17 step 6) when there is one, otherwise
## falls back to the same auto-pick-strongest-3 as before that panel
## existed.
##
## Shadow combat stats use GameLogic.shadow_combat_stats(base_power,
## level, class) -- see its own doc comment for why (grade now matters).
## Gear is still NOT folded into combat stats -- a real, open gap,
## deferred not forgotten.
##
## `apply_synergy` turns on Army Synergy (§16/§20) -- raids/the Nadir only,
## per the doc's own "gates get no synergy bonus" line, so gate callers
## leave this false (the default).
func _build_battle_party(apply_synergy: bool = false) -> Array:
	var chosen := SquadBuilder.resolve_party(
		state.army, _monsters, state.level, state.active_party_ids, _equipment, state.inventory
	)
	var synergy_bonus := _army_synergy_bonus(chosen) if apply_synergy else 0.0
	var party := [
		Battle.make_ally_combatant(
			"player", state.subclass, state.level, state.stats(), "You", synergy_bonus
		)
	]
	for member: Dictionary in chosen:
		var shadow_stats := GameLogic.shadow_combat_stats(
			int(member["base_power"]), int(member["level"]), String(member["clazz"])
		)
		party.append(
			Battle.make_ally_combatant(
				member["instance_id"],
				member["clazz"],
				member["level"],
				shadow_stats,
				member["monster_name"],
				synergy_bonus
			)
		)
	return party


## Army Synergy (§16/§20): "your full army beyond the 3 in your active
## party grants a passive stat bonus... scaling with total army_power".
## Bench power = every owned shadow's power EXCEPT the `chosen` 3 that are
## about to fight -- growing shadows that never enter the party of 4 still
## matters, as a force-multiplier on the ones who do.
func _army_synergy_bonus(chosen: Array) -> float:
	var chosen_ids := {}
	for member: Dictionary in chosen:
		chosen_ids[member["instance_id"]] = true
	var enriched := SquadBuilder.enrich_army(
		state.army, _monsters, state.level, _equipment, state.inventory
	)
	var bench_power := 0
	for e: Dictionary in enriched:
		if not chosen_ids.has(e["instance_id"]):
			bench_power += e["power"]
	return CombatMath.army_synergy_bonus(bench_power)


## Phase 3/step 5: launches the real turn-based fight (§16) for any
## already-spawned gate dict (map gate, ticket gate, or break gate --
## same shape either way). Rewards apply once BattlePanel's
## battle_finished signal fires (_on_battle_finished) -- battles are no
## longer resolved synchronously like the old power-check was, so this
## can't just return a result string the way _resolve_gate() used to.
## `prefix`/`is_break` are only remembered to shape that later message.
func _start_gate_battle(gate: Dictionary, prefix: String = "", is_break: bool = false) -> void:
	_pending_battle_gate = gate
	_pending_battle_prefix = prefix
	_pending_battle_is_break = is_break
	var enemies := [
		Battle.make_enemy_combatant(
			gate["monster_id"], gate["monster_base_power"], true, gate["monster_name"]
		)
	]
	battle_view.start_battle(_build_battle_party(), enemies, _moves, false)


## Phase 3/P3-Nadir: launches the current Nadir floor (§20) as a real
## fight, same BattlePanel every other encounter uses. Enemy stats derive
## from floor_power (§16's "derived from existing base_power/floor_power").
## Non-boss floors have no named monster in the source, so they use an
## invented placeholder name; boss floors reuse Nadir.boss_monster_id's
## real monster. Army Synergy applies here, unlike gates.
func _start_nadir_battle() -> void:
	var floor_n := state.nadir_current_floor()
	_pending_nadir_floor = floor_n
	_pending_nadir_is_boss = Nadir.is_boss_floor(floor_n)
	_pending_nadir_boss_id = (
		Nadir.boss_monster_id(floor_n, _monsters) if _pending_nadir_is_boss else ""
	)
	var enemy_name := "Floor %d Sentinel" % floor_n  # invented v0 placeholder name --
	## non-boss Nadir floors have no monster in the source to name them after
	if _pending_nadir_is_boss and _pending_nadir_boss_id != "":
		var boss_monster := Content.monster_by_id(_monsters, _pending_nadir_boss_id)
		enemy_name = String(boss_monster.get("name", enemy_name))
	var enemies := [
		Battle.make_enemy_combatant(
			"nadir_floor_%d" % floor_n,
			GameLogic.floor_power(floor_n),
			_pending_nadir_is_boss,
			enemy_name
		)
	]
	battle_view.start_battle(_build_battle_party(true), enemies, _moves, false)


## Fires once per fight, whether won or lost (§16: "loss... no penalty").
## Same CLAIM/loot/Essence reward shape _resolve_gate() used to apply
## synchronously -- claim flow itself is unchanged (§18: "claim flow
## unchanged -- still fires after winning a boss fight").
func _on_battle_finished(won: bool) -> void:
	if _pending_nadir_floor >= 0:
		_apply_nadir_battle_result(won)
		return

	var gate := _pending_battle_gate
	var is_break := _pending_battle_is_break
	var msg := (
		_pending_battle_prefix
		+ (
			"\n\n%s gate (%s): %s"
			% [gate["rank"], gate["monster_name"], "CLEARED" if won else "LOST"]
		)
	)
	_pending_battle_gate = {}
	_pending_battle_prefix = ""
	_pending_battle_is_break = false

	if won:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GameLogic.attempt_claim(gate.get("monster_extract_chance", 0.0), state.level, rng):
			state.claim_shadow(gate["monster_id"], gate["rank"])
			msg += "\nCLAIMED! %s joins your army." % gate["monster_name"]
		else:
			msg += "\nBoss escaped (claim failed)."

		var drop := Loot.roll_drop(gate["rank"], _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			msg += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]
		var essence_gain := GameLogic.essence_for_gate(gate["rank"])
		if is_break:
			essence_gain = GateBreak.bonus_essence(essence_gain)
			state.gate_tickets += GateBreak.BREAK_TICKET_BONUS
			msg += "\n+%d Gate Ticket(s) (Gate Break bonus)" % GateBreak.BREAK_TICKET_BONUS
		elif gate.get("incursion_bonus", false):
			essence_gain = Incursion.bonus_essence(essence_gain)
			msg += "\n(Incursion bonus)"
		state.essence += essence_gain
		msg += "\nEssence +%d" % essence_gain

	SaveService.save(state)
	_refresh_label()
	army_view.refresh_if_open()
	label.text += msg


func _on_enter_gate_pressed() -> void:
	var idx := map_view.get_nearest_gate_index()
	if idx < 0:
		label.text += "\n\nNo gates nearby"
		return
	var gate := map_view.get_gate(idx)
	map_view.remove_gate(idx)
	_start_gate_battle(gate)


## Phase 2/P8: probabilistic Gate Break offer (§8b), checked on a timer
## (GateBreakTimer, main.tscn) rather than on GPS location updates -- a
## stationary phone gets its location updates throttled/deduped by the OS
## ("blocked - too fast"/"too close" in logcat, confirmed on-device), which
## would make breaks almost never fire exactly when the player is sitting
## still at home. That's backwards for a mechanic §8b explicitly says needs
## "no GPS movement required". A plain Timer isn't tied to movement at all.
## See core/gate_break.gd for why this whole check isn't a real push
## notification. Skips before any GPS fix (no "where you are" to place a
## gate), if a break is already pending/showing, or on cooldown/unlucky
## roll (GateBreak.should_trigger).
func _maybe_offer_gate_break() -> void:
	if state == null or not _has_location:
		return
	if not gate_break_panel.visible and _pending_break_gate.is_empty():
		var now := int(Time.get_unix_time_from_system())
		var hour: int = Time.get_time_dict_from_system()["hour"]
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GateBreak.should_trigger(now, state.last_gate_break_offer, hour, rng):
			state.last_gate_break_offer = now
			var gate := GateSpawner.spawn_ticket_gate(
				_last_lat, _last_lon, state.hunter_rank, _monsters, rng
			)
			SaveService.save(state)
			if not gate.is_empty():
				_pending_break_gate = gate
				gate_break_info_label.text = (
					"⚠ Gate break!\nA %s gate ruptured nearby -- %s is loose.\nAnswer it?"
					% [gate["rank"], gate["monster_name"]]
				)
				gate_break_panel.visible = true


func _on_gate_break_accept_pressed() -> void:
	var gate := _pending_break_gate
	_pending_break_gate = {}
	gate_break_panel.visible = false
	_start_gate_battle(gate, "\n\n[GATE BREAK]", true)


## No penalty for ignoring a break (§8b: "just a missed reward") -- the
## cooldown already started the moment the offer was rolled, in
## _maybe_offer_gate_break(), so dismissing doesn't need to touch state.
func _on_gate_break_dismiss_pressed() -> void:
	_pending_break_gate = {}
	gate_break_panel.visible = false


## Phase 2/P7 step 1: spends a gate ticket to open a gate right where the
## hunter is standing, no walking required (§8a). No-op with a status
## message (no error UI elsewhere in this project either) if there's no
## ticket to spend or no GPS fix yet to place it at.
func _on_use_ticket_pressed() -> void:
	if not _has_location:
		label.text += "\n\nNo GPS fix yet -- can't place a ticket gate"
		return
	if not state.spend_gate_ticket():
		label.text += "\n\nNo gate tickets"
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gate := GateSpawner.spawn_ticket_gate(
		_last_lat, _last_lon, state.hunter_rank, _monsters, rng
	)
	if gate.is_empty():
		# Content has no monster anywhere in the rank pool -- shouldn't
		# happen with the real monsters.json, but refund rather than eat
		# the ticket on a gate that can't exist.
		state.gate_tickets += 1
		label.text += "\n\nTicket gate failed to spawn -- ticket refunded"
		return
	_start_gate_battle(gate, "\n\n[Ticket]")


func _on_shop_button_pressed() -> void:
	shop_view.visible = true
	_refresh_shop_view()


func _on_buy_ticket_bundle_requested(id: String) -> void:
	var bundle := Content.shop_item_by_id(_shop_catalog.get("ticket_bundles", []), id)
	if not _spend_on_shop_item(bundle):
		return
	state.gate_tickets += int(bundle.get("tickets", 0))
	SaveService.save(state)
	_refresh_shop_view()
	_refresh_label()


func _on_buy_essence_bundle_requested(id: String) -> void:
	var bundle := Content.shop_item_by_id(_shop_catalog.get("essence_bundles", []), id)
	if not _spend_on_shop_item(bundle):
		return
	state.essence += int(bundle.get("essence", 0))
	SaveService.save(state)
	_refresh_shop_view()
	_refresh_label()


## No visual effect yet (§9b placeholder-art era) -- just records ownership.
func _on_buy_cosmetic_requested(id: String) -> void:
	var cosmetic := Content.shop_item_by_id(_shop_catalog.get("cosmetics", []), id)
	if state.owned_cosmetics.has(id) or not _spend_on_shop_item(cosmetic):
		return
	state.unlock_cosmetic(id)
	SaveService.save(state)
	_refresh_shop_view()


## Shared afford-then-spend step for every shop purchase kind.
func _spend_on_shop_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	return state.spend_crystals(int(item.get("crystal_cost", 0)))


func _refresh_shop_view() -> void:
	shop_view.refresh(state.crystals, state.owned_cosmetics)


func _refresh_label() -> void:
	var stats := state.stats()
	label.text = (
		(
			"Lv %d %s\nEXP: %d / %d\nEssence: %d  Tickets: %d  Crystals: %d\n"
			+ "STR %d AGI %d VIT %d END %d SEN %d\nPower: %d"
		)
		% [
			state.level,
			state.subclass,
			state.exp_into_level,
			GameLogic.exp_to_next(state.level),
			state.essence,
			state.gate_tickets,
			state.crystals,
			stats["STR"],
			stats["AGI"],
			stats["VIT"],
			stats["END"],
			stats["SEN"],
			state.personal_power(_equipment),
		]
	)


func _on_hunter_gear_button_pressed() -> void:
	hunter_gear_view.open()


func _on_nadir_button_pressed() -> void:
	nadir_panel.visible = true
	_refresh_nadir_panel()


func _on_nadir_close_pressed() -> void:
	nadir_panel.visible = false


## No longer shows a RAID_POWER-vs-target comparison -- real combat
## decides the outcome now, not a power-check, so that pairing would be
## misleading. Shows the floor's derived enemy power (informational) and
## the current Army Synergy bonus instead.
func _refresh_nadir_panel() -> void:
	var floor_n := state.nadir_current_floor()
	var enemy_power := GameLogic.floor_power(floor_n)
	var boss_tag := "  [BOSS FLOOR]" if Nadir.is_boss_floor(floor_n) else ""
	var chosen := SquadBuilder.resolve_party(
		state.army, _monsters, state.level, state.active_party_ids, _equipment, state.inventory
	)
	var synergy_pct := int(round(_army_synergy_bonus(chosen) * 100.0))
	nadir_info_label.text = (
		(
			"Deepest cleared: %d\n\nFloor %d%s\nEnemy power: %d\nArmy Synergy: +%d%% party stats"
			+ "\nEstimated Essence reward: %d\nGear rarity: %s"
		)
		% [
			state.nadir_deepest_floor,
			floor_n,
			boss_tag,
			enemy_power,
			synergy_pct,
			Nadir.essence_for_floor(floor_n),
			Nadir.rank_for_floor(floor_n),
		]
	)
	nadir_take_on_button.text = "Take on Floor %d" % floor_n


## Phase 3/P3-Nadir status update: no longer resolves synchronously via a
## single clear-check -- launches the real turn-based fight (§16/§20)
## instead, same BattlePanel every other encounter uses. Rewards apply
## once it finishes, via _apply_nadir_battle_result (_on_battle_finished's
## Nadir branch).
func _on_nadir_take_on_pressed() -> void:
	_start_nadir_battle()


## Permanent progress + Essence/gear reward on a win, nothing on a loss
## (§20: "floor stays; come back stronger") -- same reward shape
## _on_nadir_take_on_pressed used to apply synchronously. Boss-floor CLAIM
## reuses GameLogic.attempt_claim against the boss monster's own real
## extract_chance, same pattern the gate flow already uses (§18: "claim
## flow unchanged").
func _apply_nadir_battle_result(won: bool) -> void:
	var floor_n := _pending_nadir_floor
	var is_boss := _pending_nadir_is_boss
	var boss_id := _pending_nadir_boss_id
	_pending_nadir_floor = -1
	_pending_nadir_is_boss = false
	_pending_nadir_boss_id = ""

	var msg := "\n\nNadir Floor %d: %s" % [floor_n, "CLEARED" if won else "LOST"]
	if won:
		state.clear_nadir_floor(floor_n)
		var rng := RandomNumberGenerator.new()
		rng.randomize()

		var essence_gain := Nadir.essence_for_floor(floor_n)
		state.essence += essence_gain
		msg += "\nEssence +%d" % essence_gain

		var drop := Loot.roll_drop(Nadir.rank_for_floor(floor_n), _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			msg += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]

		if is_boss and boss_id != "":
			var boss_monster := Content.monster_by_id(_monsters, boss_id)
			if GameLogic.attempt_claim(boss_monster.get("extract_chance", 0.0), state.level, rng):
				state.claim_shadow(boss_id, Nadir.rank_for_floor(floor_n))
				msg += "\nBOSS CLAIMED! %s joins your army." % boss_monster.get("name", "")
			else:
				msg += "\nBoss floor -- boss escaped (claim failed)."

	SaveService.save(state)
	_refresh_nadir_panel()
	army_view.refresh_if_open()
	_refresh_label()
	label.text += msg


func _on_character_button_pressed() -> void:
	character_view.open(_steps, _workouts_json, _gps_status, _health_status)


## The one handler every panel controller's state_changed signal connects
## to -- refreshes the shared HUD (Essence/Tickets/Crystals/army). Always
## refreshing both regardless of which panel fired is deliberately simple
## (cheap string formatting, not a perf concern) rather than tracking which
## specific label actually needs updating.
func _on_state_changed() -> void:
	_refresh_label()
	army_view.refresh_if_open()


func _on_character_trial_result(msg: String) -> void:
	character_view.refresh(_steps, _workouts_json, _gps_status, _health_status)
	label.text += msg
