class_name Updater
extends Node
## Over-the-air content updates. Downloads a new content pack (scripts, levels,
## data) from your own HTTPS address and applies it the next time the app starts.
## A new .apk is only needed when `min_binary` in version.json is higher than
## BINARY_VERSION below (i.e. when the native app itself changed).

signal status_changed(text: String)
signal apk_required(url: String)

const FEED_URL := "https://nex-gen-dev.github.io/Jewish-games" ## baked in: users cannot change it
const BINARY_VERSION := 3 ## bump when a new APK must be installed
const BASE_CONTENT := 5 ## content version bundled inside the APK
const DIR := "user://update"

static var last_status := ""
static var ready_to_restart := false
static var checked_this_session := false
static var boot_content := 0 ## content version that is actually running


static func installed_content() -> int:
	var meta := read_meta()
	return maxi(int(meta.get("content", 0)), BASE_CONTENT)


static func read_meta() -> Dictionary:
	var p := DIR + "/meta.json"
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}


func _say(text: String) -> void:
	last_status = text
	status_changed.emit(text)


## Check the address and, if newer content exists, download and stage it.
func run(base_override := "") -> void:
	checked_this_session = true
	var base_url := FEED_URL
	## Only the local test server may override the baked-in address.
	if base_override.begins_with("http://127.0.0.1") or base_override.begins_with("http://localhost"):
		base_url = base_override
	_say("Checking for updates...")
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	var err := req.request(base_url + "/version.json?t=" + str(int(Time.get_unix_time_from_system())))
	if err != OK:
		push_warning("req err %d" % err)
		req.queue_free()
		_say("The update address doesn't look right.")
		return
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_say("Couldn't reach the update server (code %d)." % res[1])
		return
	var info: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not info is Dictionary:
		_say("The update information was not readable.")
		return
	_remember_api(info)
	var content := int(info.get("content", 0))
	if int(info.get("min_binary", 0)) > BINARY_VERSION:
		_say("A new version of the app itself is needed. Download it to continue.")
		apk_required.emit(str(info.get("apk_url", base_url)))
		return
	if content <= installed_content():
		_say("You're up to date (content v%d)." % installed_content())
		return
	var file := str(info.get("file", "content.pck"))
	var want := str(info.get("sha256", "")).to_lower()
	_say("Downloading update v%d..." % content)
	DirAccess.make_dir_recursive_absolute(DIR)
	var tmp := DIR + "/content.tmp"
	var dl := HTTPRequest.new()
	dl.timeout = 120.0
	dl.download_file = tmp
	add_child(dl)
	if dl.request(base_url + "/" + file + "?t=" + str(int(Time.get_unix_time_from_system()))) != OK:
		dl.queue_free()
		_say("Couldn't start the download.")
		return
	var r2: Array = await dl.request_completed
	dl.queue_free()
	if r2[0] != HTTPRequest.RESULT_SUCCESS or r2[1] != 200:
		_say("Download failed (code %d). Try again." % r2[1])
		return
	if want != "" and FileAccess.get_sha256(tmp) != want:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_say("The downloaded update was damaged and was discarded.")
		return
	var final := DIR + "/content.pck"
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(final))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(final))
	var f := FileAccess.open(DIR + "/meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"content": content, "notes": str(info.get("notes", "")), "api_url": str(read_meta().get("api_url", ""))}))
	f.close()
	ready_to_restart = true
	_say("Update v%d installed. Close and reopen the app to use it." % content)


## The feed can announce the backend address ("api_url"), so the server can be
## switched on later without shipping a new app.
func _remember_api(info: Dictionary) -> void:
	var api := str(info.get("api_url", ""))
	if not api.begins_with("https://"):
		return
	var meta := read_meta()
	if meta.get("api_url", "") == api:
		return
	meta["api_url"] = api
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + "/meta.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()
	## the backend just became known: register this player now
	Profile.sync_account()
