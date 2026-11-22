extends Node
## Per-user profile. Defaults ship with the app; the server can push private
## updates (theme, character look, unlocked games, messages) that get merged
## on top and saved locally.

signal changed

const SAVE_PATH := "user://profile.json"
const DEFAULT_PATH := "res://data/profile_default.json"
const MANIFEST_PATH := "res://data/manifest.json"

## Backend address. Normally empty here: the update feed (version.json "api_url")
## announces it once the backend exists. Empty = offline, accounts stay on the device.
const SERVER_URL := ""
const META_PATH := "user://update/meta.json"

var data: Dictionary = {}
var manifest: Dictionary = {}


func _ready() -> void:
	manifest = _read_json(MANIFEST_PATH)
	load_profile()
	sync_account.call_deferred()


func load_profile() -> void:
	data = _merge(_read_json(DEFAULT_PATH), _read_json(SAVE_PATH))
	changed.emit()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


## Apply a private update pushed for this user (from server or local file).
func apply_update(update: Dictionary) -> void:
	data = _merge(data, update)
	save()
	changed.emit()


# ---- points, inventory, settings

func points() -> int:
	return int(data.get("progress", {}).get("points", 0))


func add_points(n: int) -> void:
	apply_update({"progress": {"points": points() + n}})


func owns(item: String) -> bool:
	return item in data.get("inventory", [])


func buy(item: Dictionary) -> bool:
	var cost: int = item.get("cost", 0)
	if owns(item["id"]) or points() < cost:
		return false
	var inv: Array = data.get("inventory", []).duplicate()
	inv.append(item["id"])
	apply_update({"inventory": inv, "progress": {"points": points() - cost}})
	return true


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return data.get("settings", {}).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	apply_update({"settings": {key: value}})


## "auto" = low quality on phones/tablets/web (shadows and glow off), high on desktop.
func quality_high() -> bool:
	var q: String = str(get_setting("quality", "auto"))
	if q == "high":
		return true
	if q == "low":
		return false
	return not (OS.has_feature("mobile") or OS.has_feature("web"))


func reload() -> void:
	manifest = _read_json(MANIFEST_PATH)
	load_profile()


func get_color(section: String, key: String, fallback: Color) -> Color:
	var sec: Variant = data.get(section, {})
	if sec is Dictionary and sec.has(key):
		return Color.from_string(str(sec[key]), fallback)
	return fallback


func get_flag(section: String, key: String, fallback := false) -> bool:
	var sec: Variant = data.get(section, {})
	if sec is Dictionary and sec.has(key):
		return bool(sec[key])
	return fallback


func has_entitlement(game_id: String) -> bool:
	return game_id in data.get("entitlements", [])


func is_completed(level_id: String) -> bool:
	return level_id in data.get("progress", {}).get("completed", [])


func mark_completed(level_id: String) -> void:
	var done: Array = data.get("progress", {}).get("completed", [])
	if level_id not in done:
		done.append(level_id)
		apply_update({"progress": {"completed": done}})


## A level is playable if the user owns the game, it isn't "coming soon", and
## the previous level is finished (or dev_unlock_all is on).
func level_unlocked(game: Dictionary, index: int) -> bool:
	if game.get("coming_soon", false) or not has_entitlement(game["id"]):
		return false
	var lv: Dictionary = game["levels"][index]
	if lv.get("coming_soon", false):
		return false
	if data.get("dev_unlock_all", false) or index == 0:
		return true
	return is_completed(game["levels"][index - 1]["id"])


func server_url() -> String:
	var meta := _read_json(META_PATH)
	var u := str(meta.get("api_url", ""))
	return u if u != "" else SERVER_URL


# ---- account (name / username / email or phone -> generated ID)

func has_account() -> bool:
	return str(data.get("account", {}).get("user_id", "")) != ""


func account() -> Dictionary:
	return data.get("account", {})


func new_user_id() -> String:
	var alphabet := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ" ## no 0/O/1/I confusion
	var bytes := Crypto.new().generate_random_bytes(8)
	var id := "PG-"
	for b in bytes:
		id += alphabet[b % alphabet.length()]
	return id


## Returns "" on success or an error message for the sign-in form.
func create_account(full_name: String, username: String, email: String, phone: String) -> String:
	full_name = full_name.strip_edges()
	username = username.strip_edges().to_lower()
	email = email.strip_edges().to_lower()
	var digits := ""
	for ch in phone:
		if ch >= "0" and ch <= "9":
			digits += ch
	if phone.strip_edges().begins_with("+"):
		digits = "+" + digits
	if full_name.length() < 2:
		return "Please enter your name."
	var ure := RegEx.create_from_string("^[a-z0-9_.]{3,20}$")
	if ure.search(username) == null:
		return "Username: 3-20 letters, numbers, _ or ."
	if email == "" and digits.length() < 7:
		return "Enter an email or a phone number."
	if email != "" and RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").search(email) == null:
		return "That email doesn't look right."
	if phone.strip_edges() != "" and digits.length() < 7:
		return "That phone number looks too short."
	var acct := {
		"user_id": new_user_id(), "name": full_name, "username": username,
		"email": email, "phone": digits, "created": int(Time.get_unix_time_from_system()),
		"synced": false,
	}
	apply_update({"account": acct, "display_name": full_name, "user_id": acct["user_id"]})
	sync_account()
	return ""


## Send the new account to the backend once one exists; retried on every start.
func sync_account() -> void:
	var base := server_url()
	if base == "" or not has_account() or bool(account().get("synced", false)):
		return
	var a := account()
	var body := {
		"user_id": a["user_id"], "name": a["name"], "username": a["username"],
		"email": a["email"], "phone": a["phone"], "platform": OS.get_name(),
		"model": OS.get_model_name(),
	}
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, resp: PackedByteArray):
		if code == 200 or code == 201:
			var parsed: Variant = JSON.parse_string(resp.get_string_from_utf8())
			var upd := {"account": {"synced": true}}
			if parsed is Dictionary and parsed.has("token"):
				upd["account"]["token"] = str(parsed["token"])
			apply_update(upd)
			fetch_updates()
		req.queue_free())
	req.request(base + "/v1/register", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))


## Ask the backend for private updates for this user (themes, games, messages...).
## Response: JSON in the shape of profile_default.json, only the changed fields.
func fetch_updates() -> void:
	var base := server_url()
	var token := str(account().get("token", ""))
	if base == "" or token == "":
		return
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		if code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary:
				parsed.erase("account")
				parsed.erase("progress")
				apply_update(parsed)
		req.queue_free())
	req.request(base + "/v1/me/profile", PackedStringArray(["Authorization: Bearer " + token]))
