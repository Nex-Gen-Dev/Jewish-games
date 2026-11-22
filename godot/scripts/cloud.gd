extends Node
## Talks to the backend (when one is announced by the update feed): progress,
## notifications, terms, problem reports, private-content refresh.
## Lives for the whole app session (child of the app root).

signal notifications_changed
signal legal_changed

const AppLog := preload("res://scripts/applog.gd")
const INBOX := "user://inbox.json"
const LEGAL := "user://legal.json"
const PENDING := "user://pending_reports.json"
const POLL_SECONDS := 20.0

var inbox: Array = [] ## [{id,title,body,created_at,read}]
var legal: Dictionary = {}
var new_since_last_toast: Array = []
var last_level := ""
var _poll_n := 0
var _sync_timer: Timer
var _poll_timer: Timer


func _ready() -> void:
	inbox = _load_array(INBOX)
	legal = _load_legal()
	_sync_timer = Timer.new()
	_sync_timer.one_shot = true
	_sync_timer.wait_time = 3.0
	_sync_timer.timeout.connect(sync_progress)
	add_child(_sync_timer)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.timeout.connect(poll)
	add_child(_poll_timer)
	_poll_timer.start()
	Profile.changed.connect(func(): _sync_timer.start())
	poll.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		poll()


# ---------------------------------------------------------------- state

func has_server() -> bool:
	return Profile.server_url() != "" and str(Profile.account().get("token", "")) != ""


func current_legal() -> Dictionary:
	return legal


func accepted_version() -> int:
	return int(Profile.account().get("terms_version", 0))


func needs_terms() -> bool:
	return int(legal.get("version", 0)) > accepted_version() and Profile.has_account()


func accept_terms() -> void:
	var v := int(legal.get("version", 1))
	var acct := {"terms_version": v, "terms_at": int(Time.get_unix_time_from_system()), "terms_sent": false}
	Profile.apply_update({"account": acct})
	_send_consent()


func unread() -> int:
	var n := 0
	for i in inbox:
		if not bool(i.get("read", false)):
			n += 1
	return n


func mark_all_read() -> void:
	for i in inbox:
		i["read"] = true
	_save(INBOX, inbox)
	notifications_changed.emit()


func alerts_enabled() -> bool:
	return bool(Profile.get_setting("alerts", true))


# ---------------------------------------------------------------- network

func _req(path: String, method := HTTPClient.METHOD_GET, body := {}, auth := true) -> Array:
	var base := Profile.server_url()
	if base == "":
		return [0, {}]
	var r := HTTPRequest.new()
	r.timeout = 20.0
	add_child(r)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth:
		var tok := str(Profile.account().get("token", ""))
		if tok == "":
			r.queue_free()
			return [0, {}]
		headers.append("Authorization: Bearer " + tok)
	var err := r.request(base + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(body))
	if err != OK:
		r.queue_free()
		return [0, {}]
	var res: Array = await r.request_completed
	r.queue_free()
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return [int(res[1]) if res[0] == HTTPRequest.RESULT_SUCCESS else 0, parsed]


func poll() -> void:
	if Profile.server_url() == "":
		return
	_poll_n += 1
	Profile.sync_account()
	if has_server():
		Profile.fetch_updates()
		_fetch_notifications()
		_send_consent()
		_flush_reports()
	if _poll_n == 1 or _poll_n % 6 == 0:
		_fetch_legal()


func _fetch_legal() -> void:
	var r: Array = await _req("/v1/legal", HTTPClient.METHOD_GET, {}, false)
	if r[0] == 200 and r[1] is Dictionary and int(r[1].get("version", 0)) > 0:
		if int(r[1]["version"]) != int(legal.get("version", 0)):
			legal = r[1]
			_save_dict(LEGAL, legal)
			legal_changed.emit()


func _fetch_notifications() -> void:
	var last := 0
	for i in inbox:
		last = maxi(last, int(i.get("id", 0)))
	var r: Array = await _req("/v1/me/notifications?after=%d" % last)
	if r[0] == 200 and r[1] is Array and r[1].size() > 0:
		for n in r[1]:
			n["read"] = false
			inbox.append(n)
			new_since_last_toast.append(n)
		while inbox.size() > 60:
			inbox.remove_at(0)
		_save(INBOX, inbox)
		notifications_changed.emit()


func _send_consent() -> void:
	var a := Profile.account()
	if has_server() and int(a.get("terms_version", 0)) > 0 and not bool(a.get("terms_sent", false)):
		var r: Array = await _req("/v1/me/consent", HTTPClient.METHOD_POST, {"terms_version": int(a["terms_version"])})
		if r[0] == 200:
			Profile.apply_update({"account": {"terms_sent": true}})


func sync_progress() -> void:
	if not has_server():
		return
	var prog: Dictionary = Profile.data.get("progress", {})
	var body := {
		"completed": prog.get("completed", []), "points": Profile.points(),
		"inventory": Profile.data.get("inventory", []), "last_level": last_level,
		"app_version": "1.2", "content_version": Updater.boot_content,
	}
	await _req("/v1/me/sync", HTTPClient.METHOD_POST, body)


## Queue a problem report; it is sent now or retried later if offline.
func send_report(kind: String, message: String, include_logs := true) -> void:
	var rep := {
		"kind": kind, "message": message, "level": AppLog.level if AppLog.level != "" else last_level,
		"device": "%s %s" % [OS.get_name(), OS.get_model_name()], "app_version": "1.2",
		"content_version": Updater.boot_content,
		"logs": AppLog.dump() if include_logs else "",
	}
	var q := _load_array(PENDING)
	q.append(rep)
	_save(PENDING, q)
	AppLog.add("Report queued (%s)" % kind)
	_flush_reports()


func pending_reports() -> int:
	return _load_array(PENDING).size()


var _flushing := false

func _flush_reports() -> void:
	if _flushing or not has_server():
		return
	var q := _load_array(PENDING)
	if q.is_empty():
		return
	_flushing = true
	while not q.is_empty():
		var r: Array = await _req("/v1/me/report", HTTPClient.METHOD_POST, q[0])
		if r[0] == 201 or r[0] == 200:
			q.pop_front()
			_save(PENDING, q)
		else:
			break
	_flushing = false


# ---------------------------------------------------------------- storage

func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return p if p is Array else []


func _load_legal() -> Dictionary:
	for path in [LEGAL, "res://data/legal.json"]:
		if FileAccess.file_exists(path):
			var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if p is Dictionary:
				var cached: Dictionary = p
				if path == LEGAL:
					var bundled: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/legal.json"))
					if bundled is Dictionary and int(bundled.get("version", 0)) > int(cached.get("version", 0)):
						return bundled
				return cached
	return {}


func _save(path: String, arr: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(arr))


func _save_dict(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
