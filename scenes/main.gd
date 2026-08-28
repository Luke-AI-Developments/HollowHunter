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
const MARKER_CARD_MARGIN := 12.0  ## keeps the card off the very edge of the screen
const MARKER_CARD_GAP := 16.0  ## vertical gap between the card and the marker it points at

var bridge: Object
var state: HunterState
var _monsters: Array
var _equipment: Dictionary
var _steps: int = -1
var _workouts_json: String = ""
var _health_applied := false
var _gps_status := "Requesting..."  ## Phase 2/P5 step 2: §21's "health connection" status line
var _pending_preset_id: String = "m1"  ## Holds the onboarding preset pick
## between the PresetPicker and SubclassPicker screens -- no HunterState
## exists yet at pick time (created in _on_subclass_chosen()), same reason
## subclass itself isn't stored until then.
var _health_status := "Requesting..."
var _has_location := false  ## Phase 2/P7 step 1: whether _last_lat/_last_lon are real yet
var _last_lat: float = 0.0  ## most recent GPS fix -- §8a's ticket gate spawns "where you are"
var _last_lon: float = 0.0
var _pending_break_gate: Dictionary = {}  ## Phase 2/P8: the offered-but-not-yet-answered §8b gate
var _card_poi_type: String = ""  ## which POI MarkerCard's action button currently
var _card_poi_index: int = -1  ## acts on -- set by _show_sanctuary_card()/
## _show_lorestone_card()/_show_gate_card(), read by _on_marker_card_action_pressed().
var _card_gate: Dictionary = {}  ## the gate dict for a "gate"/"ticket_gate" card --
## a ticket gate has no map index to re-fetch by, so the whole dict is stashed here.
var _pending_ticket_gate: Dictionary = {}  ## §8a: the ticket gate rolled but not
## yet paid for -- reused across re-presses of Use Ticket so tapping away and
## re-pressing can't re-roll the rank for free. Cleared when the ticket is spent.
var _moves: Array = []  ## Phase 3/step 5: content/moves.json, loaded once (§16 combat overhaul)
var _shop_catalog: Dictionary = {}  ## Phase 4/shop step 1: content/shop.json, loaded once
var _pending_battle_gate: Dictionary = {}  ## the gate a live BattlePanel fight will resolve into
var _pending_battle_prefix: String = ""  ## "[Ticket]"/"[GATE BREAK]" label text, carried through
var _pending_battle_is_break: bool = false  ## whether to apply GateBreak's bonus on a win
var _pending_nadir_floor: int = -1  ## Phase 3/P3-Nadir: >=0 while a BattlePanel fight is
## resolving a Nadir floor instead of a gate -- _on_battle_finished branches on this
var _pending_nadir_is_boss: bool = false  ## whether that floor is a boss floor (§20)
var _pending_nadir_boss_id: String = ""  ## that boss floor's stand-in boss monster id
var _pending_nickname_shadow_id: String = ""  ## §6c: shadow instance_id awaiting an
## optional post-CLAIM nickname prompt; "" when nothing is pending.
var _pending_nickname_species: String = ""  ## species name for that prompt's label text.

@onready var preset_picker: Node2D = $PresetPicker
@onready var preset_grid: GridContainer = $PresetPicker/Grid
@onready var subclass_picker: Node2D = $SubclassPicker
@onready var subclass_title_label: Label = $SubclassPicker/TitleLabel
@onready var welcome_label: Label = $SubclassPicker/WelcomeLabel
@onready var continue_button: Button = $SubclassPicker/ContinueButton
@onready var game_ui: Node2D = $GameUI
@onready var label: Label = $GameUI/Label
@onready var map_view: MapView = $GameUI/MapView
@onready var marker_card: Panel = $GameUI/MarkerCard
@onready var marker_card_type_label: Label = $GameUI/MarkerCard/TypeLabel
@onready var system_toast: SystemToast = $GameUI/SystemToast
@onready var system_panel: SystemPanel = $GameUI/SystemPanel
@onready var marker_card_subtitle_label: Label = $GameUI/MarkerCard/SubtitleLabel
@onready var marker_card_action_button: Button = $GameUI/MarkerCard/ActionButton
@onready var inventory_button: Button = $GameUI/NavScroll/NavRow/InventoryButton
@onready var inventory_view: InventoryView = $GameUI/InventoryPanel
@onready var hunter_gear_button: Button = $GameUI/NavScroll/NavRow/HunterGearButton
@onready var hunter_gear_view: HunterGearView = $GameUI/HunterGearPanel
@onready var shadow_gear_view: ShadowGearView = $GameUI/ShadowGearPanel
@onready var army_button: Button = $GameUI/NavScroll/NavRow/ArmyButton
@onready var army_view: ArmyView = $GameUI/ArmyPanel
@onready var nadir_button: Button = $GameUI/NavScroll/NavRow/NadirButton
@onready var nadir_panel: Node2D = $GameUI/NadirPanel
@onready var nadir_info_label: Label = $GameUI/NadirPanel/InfoLabel
@onready var nadir_take_on_button: Button = $GameUI/NadirPanel/TakeOnButton
@onready var stronghold_button: Button = $GameUI/NavScroll/NavRow/StrongholdButton
@onready var stronghold_view: StrongholdView = $GameUI/StrongholdPanel
@onready var place_stronghold_button: Button = $GameUI/StrongholdPanel/PlaceStrongholdButton
@onready var confirm_stronghold_button: Button = $GameUI/ConfirmStrongholdButton
@onready var cancel_stronghold_button: Button = $GameUI/CancelStrongholdButton
@onready var character_button: Button = $GameUI/NavScroll/NavRow/CharacterButton
@onready var character_view: CharacterView = $GameUI/CharacterPanel
@onready var use_ticket_button: Button = $GameUI/NavScroll/NavRow/UseTicketButton
@onready var shop_button: Button = $GameUI/NavScroll/NavRow/ShopButton
@onready var shop_view: ShopView = $GameUI/ShopPanel
@onready var leaderboard_button: Button = $GameUI/NavScroll/NavRow/LeaderboardButton
@onready var leaderboard_view: LeaderboardView = $GameUI/LeaderboardPanel
@onready var gate_break_panel: Node2D = $GameUI/GateBreakPanel
@onready var gate_break_info_label: Label = $GameUI/GateBreakPanel/InfoLabel
@onready var gate_break_accept_button: Button = $GameUI/GateBreakPanel/AcceptButton
@onready var gate_break_dismiss_button: Button = $GameUI/GateBreakPanel/DismissButton
@onready var gate_break_timer: Timer = $GateBreakTimer
@onready var battle_view: BattleView = $GameUI/BattlePanel
@onready var claim_nickname_panel: Node2D = $GameUI/ClaimNicknamePanel
@onready var claim_nickname_info_label: Label = $GameUI/ClaimNicknamePanel/InfoLabel
@onready var claim_nickname_input: LineEdit = $GameUI/ClaimNicknamePanel/NicknameInput
@onready var claim_nickname_save_button: Button = $GameUI/ClaimNicknamePanel/SaveButton
@onready var claim_nickname_skip_button: Button = $GameUI/ClaimNicknamePanel/SkipButton


func _ready() -> void:
	# Portrait mode: project.godot's display/window/handheld/orientation is
	# correctly "portrait" (verified directly via ProjectSettings), but on
	# this custom Gradle Android build, Godot 4.7.1's own startup sync
	# (GodotIO.setScreenOrientation(), called from engine code before this
	# script ever runs) calls Activity.setRequestedOrientation() with
	# SCREEN_ORIENTATION_LANDSCAPE regardless -- a confirmed engine-side
	# mismatch specific to custom builds, not a project misconfiguration
	# (every manifest attribute and the exported project data were checked
	# directly on-device and are correct). Setting it again here, from our
	# own code, runs after the engine's own call and wins the race.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
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
		preset_picker.visible = false
		subclass_picker.visible = false
		game_ui.visible = true
		_start_game()
	else:
		_show_preset_picker()

	if not Engine.has_singleton("GpsHealthBridge"):
		_gps_status = "Bridge not found"
		_health_status = "Bridge not found"
		system_toast.show_toast("GpsHealthBridge singleton not found")
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


## First onboarding screen for a genuinely new hunter (§25) -- picking a
## preset portrait happens before the subclass picker. Builds the 12-cell
## grid at runtime from ArtPaths.PRESET_IDS rather than hardcoding 12
## .tscn button nodes, same dynamic-cell-into-GridContainer pattern
## inventory_view.gd already uses for its equipment grid.
func _show_preset_picker() -> void:
	preset_picker.visible = true
	subclass_picker.visible = false
	game_ui.visible = false
	for preset_id in ArtPaths.PRESET_IDS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 425)
		button.icon = ArtPaths.preset_portrait(preset_id, "early")
		button.expand_icon = true
		button.pressed.connect(_on_preset_chosen.bind(preset_id))
		preset_grid.add_child(button)


## Permanent pick (§21 no-respec precedent) -- stored for
## _on_subclass_chosen() to pass into SaveService.load_or_create() once
## the HunterState is actually created.
func _on_preset_chosen(preset_id: String) -> void:
	_pending_preset_id = preset_id
	preset_picker.visible = false
	_show_subclass_picker()


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
	state = SaveService.load_or_create(subclass, _pending_preset_id)

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
	inventory_view.bind(state, _equipment, _monsters)
	hunter_gear_view.bind(state, _equipment, inventory_view)
	shadow_gear_view.bind(state, _equipment, _monsters, inventory_view)
	stronghold_view.bind(state)
	map_view.set_stronghold(state.stronghold_lat, state.stronghold_lon, state.stronghold_placed)
	if state.stronghold_placed:
		place_stronghold_button.text = "Move Stronghold"
	character_view.bind(state, _equipment, _monsters)
	leaderboard_view.bind(state, _equipment)
	army_view.bind(state, _equipment, _monsters, shadow_gear_view)
	army_view.refresh_if_open()
	_setup_gear_panels()


## Wires every button once. Idempotency guard (checks
## hunter_gear_button.pressed first) -- _start_game() can run again (e.g.
## after picking a subclass) without double-connecting. Per-panel
## row-building/button-wiring now lives in each panel's own controller
## script (HunterGearView etc.) --
## this only wires the OPEN buttons and the cross-panel signals those
## controllers emit (state_changed for the shared HUD, plus the couple of
## one-off messages -- Stronghold's collect summary, a Trial result --
## that still need the shared main label).
func _setup_gear_panels() -> void:
	if not hunter_gear_button.pressed.is_connected(_on_hunter_gear_button_pressed):
		hunter_gear_button.pressed.connect(_on_hunter_gear_button_pressed)
		hunter_gear_view.state_changed.connect(_on_state_changed)
		shadow_gear_view.state_changed.connect(_on_state_changed)
		army_button.pressed.connect(
			func() -> void:
				_hide_marker_card()
				army_view.open()
		)
		army_view.state_changed.connect(_on_state_changed)
		army_view.mass_convert_result.connect(
			func(msg: String) -> void: system_toast.show_toast(msg.lstrip("\n"))
		)
		army_view.squad_full_message.connect(
			func(msg: String) -> void: system_toast.show_toast(msg.lstrip("\n"))
		)
		inventory_button.pressed.connect(
			func() -> void:
				_hide_marker_card()
				inventory_view.open()
		)
		inventory_view.state_changed.connect(_on_state_changed)
		nadir_button.pressed.connect(_on_nadir_button_pressed)
		$GameUI/NadirPanel/CloseButton.pressed.connect(_on_nadir_close_pressed)
		nadir_take_on_button.pressed.connect(_on_nadir_take_on_pressed)
		stronghold_button.pressed.connect(
			func() -> void:
				_hide_marker_card()
				stronghold_view.open()
		)
		stronghold_view.state_changed.connect(_on_state_changed)
		stronghold_view.collected.connect(
			func(msg: String) -> void: system_panel.show_panel("STRONGHOLD", msg.lstrip("\n"))
		)
		stronghold_view.proximity_denied.connect(
			func() -> void: system_toast.show_toast("Not near your Stronghold")
		)
		place_stronghold_button.pressed.connect(_on_place_stronghold_pressed)
		confirm_stronghold_button.pressed.connect(_on_confirm_stronghold_pressed)
		cancel_stronghold_button.pressed.connect(_on_cancel_stronghold_pressed)
		character_button.pressed.connect(_on_character_button_pressed)
		character_view.state_changed.connect(_on_state_changed)
		character_view.trial_result.connect(_on_character_trial_result)
		use_ticket_button.pressed.connect(_on_use_ticket_pressed)
		shop_button.pressed.connect(_on_shop_button_pressed)
		shop_view.close_requested.connect(func() -> void: shop_view.visible = false)
		shop_view.buy_ticket_bundle_requested.connect(_on_buy_ticket_bundle_requested)
		shop_view.buy_essence_bundle_requested.connect(_on_buy_essence_bundle_requested)
		shop_view.buy_cosmetic_requested.connect(_on_buy_cosmetic_requested)
		leaderboard_button.pressed.connect(
			func() -> void:
				_hide_marker_card()
				leaderboard_view.open()
		)
		gate_break_accept_button.pressed.connect(_on_gate_break_accept_pressed)
		gate_break_dismiss_button.pressed.connect(_on_gate_break_dismiss_pressed)
		gate_break_timer.timeout.connect(_maybe_offer_gate_break)
		map_view.marker_tapped.connect(_on_marker_tapped)
		map_view.map_tapped_empty.connect(_on_map_tapped_empty)
		marker_card_action_button.pressed.connect(_on_marker_card_action_pressed)
		system_panel.dismissed.connect(_on_system_panel_dismissed)
		claim_nickname_save_button.pressed.connect(_on_claim_nickname_save_pressed)
		claim_nickname_skip_button.pressed.connect(_on_claim_nickname_skip_pressed)


func _on_location_permission_result(granted: bool) -> void:
	if granted:
		_gps_status = "Linked"
		bridge.startLocationUpdates()
	else:
		_gps_status = "Permission denied"
		system_toast.show_toast("GPS permission denied")


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
	stronghold_view.update_position(lat, lon)


func _on_health_connect_available(available: bool) -> void:
	if available:
		_health_status = "Requesting permissions..."
		bridge.requestHealthPermissions()
	else:
		_health_status = "Health Connect not available"
		system_toast.show_toast("Health Connect not available")


func _on_health_permission_result(granted: bool) -> void:
	if granted:
		_health_status = "Linked"
		bridge.readTodaySteps()
		bridge.readRecentWorkouts(24)
	else:
		_health_status = "Permission denied"
		system_toast.show_toast("Health permission denied")


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
		system_toast.show_toast("Welcome back -- rest bonus applied to today's EXP!")
	if levels_gained > 0:
		system_panel.show_panel("LEVEL UP!", "+%d" % levels_gained)
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
## Returns {"party": Array, "portraits": Dictionary} -- combatant dicts plus
## a parallel instance_id -> Texture2D lookup for BattleView's party-slot
## icons. Built here (not in core/battle.gd) since this is the one place
## that still has each shadow's real monster_id before it gets flattened
## into a combatant dict; "player" has no portrait entry, same
## "no preset-selection feature exists yet" gap noted elsewhere.
func _build_battle_party(apply_synergy: bool = false) -> Dictionary:
	var chosen := SquadBuilder.resolve_party(
		state.army, _monsters, state.level, state.active_party_ids, _equipment, state.inventory
	)
	var synergy_bonus := _army_synergy_bonus(chosen) if apply_synergy else 0.0
	var party := [
		Battle.make_ally_combatant(
			"player", state.subclass, state.level, state.stats(), "You", synergy_bonus
		)
	]
	var portraits := {}
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
				member["display_name"],
				synergy_bonus
			)
		)
		portraits[member["instance_id"]] = ArtPaths.monster_portrait(member["monster_id"])
	return {"party": party, "portraits": portraits}


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
	_hide_marker_card()
	_pending_battle_gate = gate
	_pending_battle_prefix = prefix
	_pending_battle_is_break = is_break
	var enemies := [
		Battle.make_enemy_combatant(
			gate["monster_id"], gate["monster_base_power"], true, gate["monster_name"]
		)
	]
	var battle_party := _build_battle_party()
	battle_view.start_battle(
		battle_party["party"], enemies, _moves, false, battle_party["portraits"]
	)


## Phase 3/P3-Nadir: launches the current Nadir floor (§20) as a real
## fight, same BattlePanel every other encounter uses. Enemy stats derive
## from floor_power (§16's "derived from existing base_power/floor_power").
## Non-boss floors have no named monster in the source, so they use an
## invented placeholder name; boss floors reuse Nadir.boss_monster_id's
## real monster. Army Synergy applies here, unlike gates.
func _start_nadir_battle() -> void:
	_hide_marker_card()
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
	var battle_party := _build_battle_party(true)
	battle_view.start_battle(
		battle_party["party"], enemies, _moves, false, battle_party["portraits"]
	)


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
	var header := "VICTORY!" if won else "DEFEAT"
	var prefix := _pending_battle_prefix.lstrip("\n")
	var body := (
		"%s gate (%s): %s" % [gate["rank"], gate["monster_name"], "CLEARED" if won else "LOST"]
	)
	if not prefix.is_empty():
		body = prefix + "\n" + body
	_pending_battle_gate = {}
	_pending_battle_prefix = ""
	_pending_battle_is_break = false

	if won:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if GameLogic.attempt_claim(gate.get("monster_extract_chance", 0.0), state.level, rng):
			var claimed := state.claim_shadow(gate["monster_id"], gate["rank"])
			_pending_nickname_shadow_id = claimed["instance_id"]
			_pending_nickname_species = gate["monster_name"]
			body += "\nCLAIMED! %s joins your army." % gate["monster_name"]
		else:
			body += "\nBoss escaped (claim failed)."

		var drop := Loot.roll_drop(gate["rank"], _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			body += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]
		var essence_gain := GameLogic.essence_for_gate(gate["rank"])
		if is_break:
			essence_gain = GateBreak.bonus_essence(essence_gain)
			state.gate_tickets += GateBreak.BREAK_TICKET_BONUS
			body += "\n+%d Gate Ticket(s) (Gate Break bonus)" % GateBreak.BREAK_TICKET_BONUS
		elif gate.get("incursion_bonus", false):
			essence_gain = Incursion.bonus_essence(essence_gain)
			body += "\n(Incursion bonus)"
		state.essence += essence_gain
		body += "\nEssence +%d" % essence_gain

	SaveService.save(state)
	_refresh_label()
	army_view.refresh_if_open()
	system_panel.show_panel(header, body)


## §6c: fires on every SystemPanel dismissal (shared signal). Only a real
## gate / Nadir CLAIM arms _pending_nickname_shadow_id, so the guard makes
## this a no-op for level-ups, rewards, stronghold, rank trials, etc. The
## onboarding starter / scripted-first-gate claims never route through
## _on_battle_finished / _apply_nadir_battle_result, so they're excluded
## structurally -- no guard needed for §25's fast onboarding CLAIM.
func _on_system_panel_dismissed() -> void:
	if _pending_nickname_shadow_id == "":
		return
	claim_nickname_info_label.text = (
		"CLAIMED %s! Give it a nickname? (optional, max %d chars)"
		% [_pending_nickname_species, TextFilter.MAX_LENGTH]
	)
	claim_nickname_input.text = ""
	claim_nickname_panel.visible = true
	claim_nickname_input.grab_focus()


## No error UI on an invalid name -- the prompt stays open with the text so
## the player can edit and retry, or Skip.
func _on_claim_nickname_save_pressed() -> void:
	if _pending_nickname_shadow_id == "":
		return
	if state.set_shadow_nickname(_pending_nickname_shadow_id, claim_nickname_input.text):
		SaveService.save(state)
		army_view.refresh_if_open()
		_refresh_label()
		_close_claim_nickname_panel()


func _on_claim_nickname_skip_pressed() -> void:
	_close_claim_nickname_panel()


func _close_claim_nickname_panel() -> void:
	_pending_nickname_shadow_id = ""
	_pending_nickname_species = ""
	claim_nickname_panel.visible = false


func _on_marker_tapped(info: Dictionary) -> void:
	match info["type"]:
		"gate":
			_show_gate_card(info["index"], info["screen_pos"])
		"sanctuary":
			_show_sanctuary_card(info["index"], info["screen_pos"])
		"lorestone":
			_show_lorestone_card(info["index"], info["screen_pos"])
		"stronghold":
			_hide_marker_card()
			stronghold_view.open()


func _on_map_tapped_empty() -> void:
	_hide_marker_card()


## Clears MarkerCard's visibility and which POI it was showing (the latter
## also guards _on_marker_card_action_pressed() against acting on a stale
## POI). Called both on ordinary dismissal (tap elsewhere, action taken)
## and before any other full-screen panel/popup opens, so MarkerCard can
## never be left showing -- and its now-inert action button hittable --
## underneath a later-opened panel (Godot picks input by tree order, not
## z_index, so a later GameUI sibling always wins the touch).
func _hide_marker_card() -> void:
	marker_card.visible = false
	_card_poi_type = ""
	_card_poi_index = -1
	_card_gate = {}


## Positions MarkerCard above marker_screen_pos, clamped to stay fully
## on-screen -- flips below the marker instead when there isn't enough
## room above it (near the top of the screen), and never low enough to
## overlap NavScroll (offset_top = 2260.0 in main.tscn) at the bottom.
## 1080.0 is this project's fixed viewport width (project.godot's
## window/size/viewport_width), same hardcoded-pixel convention every
## other node in main.tscn already uses -- there's no responsive layout
## system in this codebase. marker_card.size (not a separate constant)
## reads the panel's actual .tscn geometry, so resizing it in the editor
## can't silently break this math.
func _position_marker_card(marker_screen_pos: Vector2) -> void:
	var card_size := marker_card.size
	var pos := marker_screen_pos - Vector2(card_size.x / 2.0, card_size.y + MARKER_CARD_GAP)
	if pos.y < MARKER_CARD_MARGIN:
		pos.y = marker_screen_pos.y + MARKER_CARD_GAP
	pos.y = clamp(pos.y, MARKER_CARD_MARGIN, 2260.0 - card_size.y - MARKER_CARD_MARGIN)
	pos.x = clamp(pos.x, MARKER_CARD_MARGIN, 1080.0 - card_size.x - MARKER_CARD_MARGIN)
	marker_card.position = pos
	marker_card.visible = true


## Centre MarkerCard in the viewport -- for cards with no marker to anchor
## to (a ticket gate isn't drawn on the map). 1080x2424 is the project's
## fixed viewport (project.godot), same hardcoded-pixel convention as
## _position_marker_card(). marker_card.size reads the .tscn geometry so a
## resize in the editor can't silently break this.
func _position_marker_card_centered() -> void:
	var card_size := marker_card.size
	marker_card.position = (Vector2(1080.0, 2424.0) - card_size) / 2.0
	marker_card.visible = true


func _enter_gate(index: int) -> void:
	var gate := map_view.get_gate(index)
	if gate.is_empty():
		return
	map_view.remove_gate(index)
	_start_gate_battle(gate)


func _show_sanctuary_card(index: int, screen_pos: Vector2) -> void:
	var poi := map_view.get_sanctuary(index)
	var distance := MapGeometry.distance_metres(_last_lat, _last_lon, poi["lat"], poi["lon"])
	var in_range := distance <= GameLogic.POI_PROXIMITY_RADIUS_M
	var now := int(Time.get_unix_time_from_system())
	var on_cooldown := (
		state.last_sanctuary_claim_at != 0
		and now - state.last_sanctuary_claim_at < GameLogic.SANCTUARY_CLAIM_COOLDOWN_S
	)
	_card_poi_type = "sanctuary"
	_card_poi_index = index
	marker_card_type_label.text = "SANCTUARY"
	if not in_range:
		marker_card_subtitle_label.text = "%dm away — too far" % int(distance)
		marker_card_action_button.text = "Too far away"
		marker_card_action_button.disabled = true
	elif on_cooldown:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Already claimed today"
		marker_card_action_button.disabled = true
	else:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Claim"
		marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)


func _show_lorestone_card(index: int, screen_pos: Vector2) -> void:
	var poi := map_view.get_lorestone(index)
	var distance := MapGeometry.distance_metres(_last_lat, _last_lon, poi["lat"], poi["lon"])
	var in_range := distance <= GameLogic.POI_PROXIMITY_RADIUS_M
	var discovered: bool = state.discovered_lorestone_ids.has(poi["id"])
	_card_poi_type = "lorestone"
	_card_poi_index = index
	marker_card_type_label.text = "LORE STONE"
	if not in_range:
		marker_card_subtitle_label.text = "%dm away — too far" % int(distance)
		marker_card_action_button.text = "Too far away"
		marker_card_action_button.disabled = true
	elif discovered:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Already discovered"
		marker_card_action_button.disabled = true
	else:
		marker_card_subtitle_label.text = "%dm away" % int(distance)
		marker_card_action_button.text = "Discover"
		marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)


## §18: tapping a gate marker opens this card instead of dropping straight
## into the fight -- it states the rank (the map's single universal marker
## no longer encodes it, §19) and names the boss. "Enter Gate" runs the
## existing _enter_gate() path unchanged; tapping empty map cancels.
func _show_gate_card(index: int, screen_pos: Vector2) -> void:
	var gate := map_view.get_gate(index)
	if gate.is_empty():
		return
	_card_poi_type = "gate"
	_card_poi_index = index
	_card_gate = gate
	marker_card_type_label.text = "RANK %s GATE" % gate["rank"]
	marker_card_subtitle_label.text = String(gate["monster_name"])
	marker_card_action_button.text = "Enter Gate"
	marker_card_action_button.disabled = false
	_position_marker_card(screen_pos)


## §8a ticket gate: same card as _show_gate_card(), but centred (no map
## marker to anchor to) and shown BEFORE the ticket is spent -- the
## "ticket_gate" dispatch arm does state.spend_gate_ticket(), so tapping
## empty map here costs the player nothing.
func _show_ticket_gate_card(gate: Dictionary) -> void:
	_card_poi_type = "ticket_gate"
	_card_poi_index = -1
	_card_gate = gate
	marker_card_type_label.text = "RANK %s GATE" % gate["rank"]
	marker_card_subtitle_label.text = String(gate["monster_name"])
	marker_card_action_button.text = "Enter Gate"
	marker_card_action_button.disabled = false
	_position_marker_card_centered()


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
				_hide_marker_card()
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
		system_toast.show_toast("No GPS fix yet -- can't place a ticket gate")
		return
	if state.gate_tickets <= 0:
		system_toast.show_toast("No gate tickets")
		return

	if _pending_ticket_gate.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var gate := GateSpawner.spawn_ticket_gate(
			_last_lat, _last_lon, state.hunter_rank, _monsters, rng
		)
		if gate.is_empty():
			# Content has no monster in the rank pool -- shouldn't happen with
			# the real monsters.json. Nothing was spent, so nothing to refund.
			system_toast.show_toast("Ticket gate failed to spawn")
			return
		_pending_ticket_gate = gate
	_show_ticket_gate_card(_pending_ticket_gate)


func _on_place_stronghold_pressed() -> void:
	stronghold_view.visible = false
	map_view.begin_stronghold_placement()
	confirm_stronghold_button.visible = true
	cancel_stronghold_button.visible = true


func _on_confirm_stronghold_pressed() -> void:
	if map_view.has_pending_stronghold_position():
		var lonlat := map_view.pending_stronghold_position()
		state.place_stronghold(lonlat.y, lonlat.x)
		SaveService.save(state)
		map_view.set_stronghold(state.stronghold_lat, state.stronghold_lon, true)
		place_stronghold_button.text = "Move Stronghold"
	map_view.end_stronghold_placement()
	confirm_stronghold_button.visible = false
	cancel_stronghold_button.visible = false


func _on_cancel_stronghold_pressed() -> void:
	map_view.end_stronghold_placement()
	confirm_stronghold_button.visible = false
	cancel_stronghold_button.visible = false


func _on_marker_card_action_pressed() -> void:
	var poi_type := _card_poi_type
	var poi_index := _card_poi_index
	var gate := _card_gate
	_hide_marker_card()
	match poi_type:
		"sanctuary":
			_claim_sanctuary()
		"lorestone":
			_discover_lorestone(poi_index)
		"gate":
			_enter_gate(poi_index)
		"ticket_gate":
			if state.spend_gate_ticket():
				_pending_ticket_gate = {}
				_start_gate_battle(gate, "\n\n[Ticket]")
			else:
				system_toast.show_toast("No gate tickets")


func _claim_sanctuary() -> void:
	var claimed := state.claim_sanctuary(
		Time.get_unix_time_from_system(),
		GameLogic.SANCTUARY_ESSENCE_REWARD,
		GameLogic.SANCTUARY_TICKET_REWARD,
		GameLogic.SANCTUARY_CLAIM_COOLDOWN_S
	)
	if not claimed:
		system_toast.show_toast("Already claimed today")
		return
	SaveService.save(state)
	_refresh_label()
	system_toast.show_toast(
		(
			"Sanctuary claimed: +%d Essence, +%d Gate Ticket"
			% [GameLogic.SANCTUARY_ESSENCE_REWARD, GameLogic.SANCTUARY_TICKET_REWARD]
		)
	)


func _discover_lorestone(index: int) -> void:
	var stone := map_view.get_lorestone(index)
	var discovered := state.discover_lorestone(stone["id"], GameLogic.LORESTONE_ESSENCE_REWARD)
	if not discovered:
		system_toast.show_toast("Already discovered")
		return
	SaveService.save(state)
	_refresh_label()
	var lore_index: int = stone["lore_index"]
	system_panel.show_panel(
		"LORE STONE",
		(
			"%s\n(+%d Essence)"
			% [PoiSpawner.LORE_SNIPPETS[lore_index], GameLogic.LORESTONE_ESSENCE_REWARD]
		)
	)


func _on_shop_button_pressed() -> void:
	_hide_marker_card()
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
	_hide_marker_card()
	hunter_gear_view.open()


func _on_nadir_button_pressed() -> void:
	_hide_marker_card()
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

	var header := "FLOOR CLEARED" if won else "FLOOR FAILED"
	var body := "Nadir Floor %d" % floor_n
	if won:
		state.clear_nadir_floor(floor_n)
		var rng := RandomNumberGenerator.new()
		rng.randomize()

		var essence_gain := Nadir.essence_for_floor(floor_n)
		state.essence += essence_gain
		body += "\nEssence +%d" % essence_gain

		var drop := Loot.roll_drop(Nadir.rank_for_floor(floor_n), _equipment, rng)
		if not drop.is_empty():
			state.add_to_inventory(drop["id"])
			body += "\nLoot: %s (%s)" % [drop["name"], drop["rarity"]]

		if is_boss and boss_id != "":
			var boss_monster := Content.monster_by_id(_monsters, boss_id)
			if GameLogic.attempt_claim(boss_monster.get("extract_chance", 0.0), state.level, rng):
				var claimed := state.claim_shadow(boss_id, Nadir.rank_for_floor(floor_n))
				_pending_nickname_shadow_id = claimed["instance_id"]
				_pending_nickname_species = String(boss_monster.get("name", ""))
				body += "\nBOSS CLAIMED! %s joins your army." % boss_monster.get("name", "")
			else:
				body += "\nBoss floor -- boss escaped (claim failed)."

	SaveService.save(state)
	_refresh_nadir_panel()
	army_view.refresh_if_open()
	_refresh_label()
	system_panel.show_panel(header, body)


func _on_character_button_pressed() -> void:
	_hide_marker_card()
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
	system_panel.show_panel("RANK TRIAL", msg.lstrip("\n"))
