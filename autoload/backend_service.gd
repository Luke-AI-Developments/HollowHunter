extends Node
## Autoload singleton (registered in project.godot as "BackendService").
## Thin wrapper over Godot's HTTPRequest -- the only place in the project
## that talks to the network (§9/§31, P7 backend + rankings). Pure
## payload building/parsing lives in core/leaderboard_sync.gd; this only
## fires the actual HTTP calls, manages the Supabase anonymous session,
## and persists it to disk (same "only place that touches this kind of
## I/O" convention as SaveService for save data).
##
## §31 P7b status: SUPABASE_URL/SUPABASE_ANON_KEY are now the user's real
## project (filled in once they created it and handed the credentials
## over). is_configured() is true. Two real project-setup steps still
## needed on the Supabase dashboard side before this actually works end
## to end -- neither is doable with just the publishable key (confirmed
## live, not assumed): Anonymous Sign-Ins must be turned on
## (Authentication -> Sign In / Providers), and the `leaderboard` table +
## RLS policies from §31's schema must be run in the SQL Editor. Until
## both are done, ensure_session()/fetch_leaderboard() will fail with a
## real (not placeholder) error from Supabase itself -- is_configured()
## being true doesn't mean the project is fully set up yet.
##
## One request in flight at a time (Godot's HTTPRequest can't run
## concurrent requests on one node) -- a second call while `_busy` fails
## fast rather than queuing. Fine for a leaderboard: these are occasional,
## user-triggered actions, not a high-frequency API.

signal signed_in(success: bool)
signal leaderboard_synced(success: bool)
signal leaderboard_loaded(rows: Array)
signal account_link_result(success: bool, message: String)

enum Op { NONE, SIGN_UP, REFRESH, UPSERT, SELECT, LINK_ACCOUNT }

const SUPABASE_URL := "https://jpuqhnedwgbgxpmddspt.supabase.co"  ## §31 P7b: the user's
## real project
const SUPABASE_ANON_KEY := "sb_publishable_XqKXehGCIckCnpnUDjrf7g_Zlrd6fKU"  ## the project's
## public/publishable key -- safe to embed client-side (and to commit), Row Level Security is
## the real access boundary (§31's schema), not key secrecy. Verified live against the real
## project with curl before wiring this in: both the apikey-only header (anonymous calls) and
## apikey+Authorization:Bearer<same key> (public reads) came back with clean PostgREST/GoTrue
## errors ("anonymous sign-ins disabled", "table not found") rather than a key-format
## rejection, confirming the header handling below is correct for Supabase's newer
## sb_publishable_/sb_secret_ key format (which can't go in Authorization: Bearer UNLESS it's
## the exact same value as apikey -- a real, easy-to-get-wrong nuance, not assumed here).
const SESSION_PATH := "user://backend_session.json"

var _busy := false
var _pending_op: Op = Op.NONE
var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _is_anonymous: bool = true
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_session()


func is_configured() -> bool:
	return SUPABASE_URL != "" and SUPABASE_ANON_KEY != ""


func has_session() -> bool:
	return _access_token != ""


func user_id() -> String:
	return _user_id


func is_anonymous() -> bool:
	return _is_anonymous


## Signs in anonymously if there's no session on disk yet. Safe to call
## every app session -- a no-op success if already signed in.
func ensure_session() -> void:
	if not is_configured():
		signed_in.emit(false)
		return
	if has_session():
		signed_in.emit(true)
		return
	if not _start_request(Op.SIGN_UP):
		return
	_request("POST", "/auth/v1/signup", {"data": {}}, false)


## Upserts this hunter's row (§31's schema). Fails fast (signal, no
## request) if not configured or not signed in yet -- call ensure_session()
## first.
func sync_leaderboard(state: HunterState, equipment: Dictionary) -> void:
	if not is_configured() or not has_session():
		leaderboard_synced.emit(false)
		return
	if not _start_request(Op.UPSERT):
		return
	var payload := LeaderboardSync.upsert_payload(state, equipment)
	payload["user_id"] = _user_id
	var headers := _authed_headers()
	headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	_http.request(
		SUPABASE_URL + "/rest/v1/leaderboard",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


## Top `limit` rows of one board (§9: personal_power / deepest_nadir_floor
## / hunter_level), grouped by rank tier when `rank_filter` is non-empty
## (§28's "standings grouped by rank"). Public read (RLS: select using
## (true)), so this works even before ensure_session() -- the leaderboard
## itself is visible without an account.
func fetch_leaderboard(
	order_by: String = "personal_power", limit: int = 50, rank_filter: String = ""
) -> void:
	if not is_configured():
		leaderboard_loaded.emit([])
		return
	if not _start_request(Op.SELECT):
		return
	var query := "?select=*&order=%s.desc&limit=%d" % [order_by, limit]
	if rank_filter != "":
		query += "&hunter_rank=eq.%s" % rank_filter
	var headers := ["apikey: " + SUPABASE_ANON_KEY, "Authorization: Bearer " + SUPABASE_ANON_KEY]
	_http.request(SUPABASE_URL + "/rest/v1/leaderboard" + query, headers, HTTPClient.METHOD_GET)


## Upgrades the current anonymous session to a permanent account in
## place (same UID, §31's "decided: build it now") -- Supabase emails a
## confirmation link; the account becomes non-anonymous once confirmed.
func link_account(email: String, password: String) -> void:
	if not is_configured() or not has_session():
		account_link_result.emit(false, "Not signed in yet")
		return
	if not LeaderboardSync.is_valid_email(email):
		account_link_result.emit(false, "Enter a valid email")
		return
	if password.length() < 6:
		account_link_result.emit(false, "Password must be at least 6 characters")
		return
	if not _start_request(Op.LINK_ACCOUNT):
		return
	_request("PUT", "/auth/v1/user", {"email": email, "password": password}, true)


func _start_request(op: Op) -> bool:
	if _busy:
		return false
	_busy = true
	_pending_op = op
	return true


func _authed_headers() -> Array:
	return [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + _access_token,
	]


func _request(method: String, path: String, body: Dictionary, authed: bool) -> void:
	var headers := (
		_authed_headers()
		if authed
		else ["Content-Type: application/json", "apikey: " + SUPABASE_ANON_KEY]
	)
	var http_method := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_PUT
	_http.request(SUPABASE_URL + path, headers, http_method, JSON.stringify(body))


func _on_request_completed(
	_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var op := _pending_op
	_busy = false
	_pending_op = Op.NONE
	var ok := response_code >= 200 and response_code < 300
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())

	match op:
		Op.SIGN_UP:
			_handle_sign_up(ok, data)
		Op.UPSERT:
			leaderboard_synced.emit(ok)
		Op.SELECT:
			leaderboard_loaded.emit(LeaderboardSync.rank_rows(data) if ok and data is Array else [])
		Op.LINK_ACCOUNT:
			_handle_link_account(ok, data)


func _handle_sign_up(ok: bool, data: Variant) -> void:
	if not ok or not (data is Dictionary) or not data.has("access_token"):
		signed_in.emit(false)
		return
	_access_token = String(data.get("access_token", ""))
	_refresh_token = String(data.get("refresh_token", ""))
	var user: Dictionary = data.get("user", {})
	_user_id = String(user.get("id", ""))
	_is_anonymous = bool(user.get("is_anonymous", true))
	_save_session()
	signed_in.emit(true)


func _handle_link_account(ok: bool, data: Variant) -> void:
	if not ok:
		var message := "Link failed"
		if data is Dictionary and data.has("msg"):
			message = String(data["msg"])
		account_link_result.emit(false, message)
		return
	_is_anonymous = false
	_save_session()
	account_link_result.emit(true, "Check your email to confirm the link.")


func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	(
		f
		. store_string(
			(
				JSON
				. stringify(
					{
						"access_token": _access_token,
						"refresh_token": _refresh_token,
						"user_id": _user_id,
						"is_anonymous": _is_anonymous,
					}
				)
			)
		)
	)
	f.close()


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		_access_token = String(data.get("access_token", ""))
		_refresh_token = String(data.get("refresh_token", ""))
		_user_id = String(data.get("user_id", ""))
		_is_anonymous = bool(data.get("is_anonymous", true))
