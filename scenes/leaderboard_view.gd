class_name LeaderboardView
extends Node2D
## The Leaderboard screen (§9/§31 -- backend + rankings) as its own
## controller script, same per-screen-controller pattern as
## HunterGearView/StrongholdView/CharacterView. Unlike those, this talks
## to BackendService (a global autoload) directly rather than through
## main.gd -- nothing here mutates HunterState, so there's no
## state_changed-style signal main.gd needs to react to.
##
## §31 P7a status: BackendService.is_configured() is false until the
## user's real Supabase project exists (P7b) -- every action below
## degrades to a clear "not available yet" status line rather than
## hanging or crashing, since BackendService's own signals fire
## synchronously with success=false/empty when unconfigured.

const ROW_COUNT := 20  ## fixed display slots, same positional-rows convention as SquadView

var _state: HunterState
var _equipment: Dictionary
var _order_by: String = "personal_power"
var _rows: Array = []  ## Array[Label], built once

@onready var status_label: Label = $StatusLabel
@onready var rows_container: Node2D = $Rows
@onready var link_panel: Node2D = $LinkPanel
@onready var link_status_label: Label = $LinkPanel/StatusLabel
@onready var email_input: LineEdit = $LinkPanel/EmailInput
@onready var password_input: LineEdit = $LinkPanel/PasswordInput


func _ready() -> void:
	$CloseButton.pressed.connect(func() -> void: visible = false)
	$PowerBoardButton.pressed.connect(_on_power_board_pressed)
	$FloorBoardButton.pressed.connect(_on_floor_board_pressed)
	$LinkPanel/LinkButton.pressed.connect(_on_link_pressed)
	BackendService.signed_in.connect(_on_signed_in)
	BackendService.leaderboard_synced.connect(_on_synced)
	BackendService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	BackendService.account_link_result.connect(_on_link_result)
	_rows = _build_rows(rows_container, 0.0)


## Called from main.gd's _start_game() (both the existing-save and
## new-game bootstrap paths), same as the other controllers -- needed
## for sync_leaderboard()'s payload, not for reading the board itself
## (that's public, §31's RLS).
func bind(state: HunterState, equipment: Dictionary) -> void:
	_state = state
	_equipment = equipment


func open() -> void:
	visible = true
	_refresh_link_panel()
	if not BackendService.is_configured():
		status_label.text = "Leaderboard not available yet (backend not configured, §31 P7b)"
		return
	status_label.text = "Connecting..."
	BackendService.ensure_session()


func _on_power_board_pressed() -> void:
	_order_by = "personal_power"
	_request_board()


func _on_floor_board_pressed() -> void:
	_order_by = "deepest_nadir_floor"
	_request_board()


func _request_board() -> void:
	if not BackendService.is_configured():
		return
	status_label.text = "Loading..."
	BackendService.fetch_leaderboard(_order_by)


func _on_signed_in(success: bool) -> void:
	if not success:
		status_label.text = "Couldn't connect to the leaderboard."
		return
	_refresh_link_panel()
	BackendService.sync_leaderboard(_state, _equipment)


func _on_synced(_success: bool) -> void:
	# Fetch either way -- reading the board is public (§31's RLS) even if
	# this hunter's own push failed, same "still show what you can"
	# spirit as everything else in this project's offline-friendly design.
	_request_board()


func _on_leaderboard_loaded(rows: Array) -> void:
	status_label.text = (
		"Global leaderboard -- %s"
		% ("power" if _order_by == "personal_power" else "deepest Nadir floor")
	)
	for i in _rows.size():
		var label: Label = _rows[i]
		if i < rows.size():
			var row: Dictionary = rows[i]
			label.text = (
				"#%d  %s  (%s, Lv%d)  Power:%d  Floor:%d"
				% [
					row["position"],
					row["display_name"],
					row["hunter_rank"],
					row["hunter_level"],
					row["personal_power"],
					row["deepest_nadir_floor"],
				]
			)
		else:
			label.text = ""


func _on_link_pressed() -> void:
	link_status_label.text = "Linking..."
	BackendService.link_account(email_input.text, password_input.text)


func _on_link_result(success: bool, message: String) -> void:
	link_status_label.text = message
	if success:
		_refresh_link_panel()


func _refresh_link_panel() -> void:
	var linked := BackendService.has_session() and not BackendService.is_anonymous()
	link_panel.visible = not linked
	if linked:
		link_status_label.text = ""


func _build_rows(parent: Node2D, y_start: float) -> Array:
	var rows := []
	var y := y_start
	for i in ROW_COUNT:
		var row_label := Label.new()
		row_label.position = Vector2(40, y)
		row_label.size = Vector2(1000, 30)
		row_label.add_theme_font_size_override("font_size", 18)
		parent.add_child(row_label)
		rows.append(row_label)
		y += 32
	return rows
