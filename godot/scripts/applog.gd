extends RefCounted
## Breadcrumb log + crash detection. Used for "Report a problem" and for
## automatically noticing that the app closed in the middle of a level.

const SESSION := "user://session.json"
static var lines: PackedStringArray = PackedStringArray()
static var previous_crash: Dictionary = {}
static var level := ""


static func add(msg: String) -> void:
	var t := Time.get_datetime_string_from_system(false, true)
	lines.append("[%s] %s" % [t, msg])
	if lines.size() > 200:
		lines.remove_at(0)
	print("[applog] ", msg)


static func begin_session() -> void:
	var prev := _read()
	if bool(prev.get("in_level", false)):
		previous_crash = {"level": str(prev.get("level", "")), "t": prev.get("t", 0)}
		add("Previous session ended unexpectedly during level '%s'" % previous_crash["level"])
	_write({"in_level": false})
	add("Session started. OS=%s model=%s" % [OS.get_name(), OS.get_model_name()])


static func level_started(id: String) -> void:
	level = id
	add("Level started: " + id)
	_write({"in_level": true, "level": id, "t": int(Time.get_unix_time_from_system())})


static func level_ended(how := "") -> void:
	if level != "":
		add("Level ended: %s %s" % [level, how])
	_write({"in_level": false})


static func paused(p: bool) -> void:
	if level == "":
		return
	var cur := _read()
	if p:
		_write({"in_level": false, "level": level})
	elif cur.has("level") or level != "":
		_write({"in_level": true, "level": level, "t": int(Time.get_unix_time_from_system())})


## Breadcrumbs plus the end of Godot's own log file (when the device writes one).
static func dump() -> String:
	var out := "\n".join(lines)
	var path := "user://logs/godot.log"
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var all := txt.split("\n")
		var from := maxi(all.size() - 150, 0)
		out += "\n--- engine log (last lines) ---\n" + "\n".join(all.slice(from))
	return out.right(40000)


static func _read() -> Dictionary:
	if not FileAccess.file_exists(SESSION):
		return {}
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION))
	return p if p is Dictionary else {}


static func _write(d: Dictionary) -> void:
	var f := FileAccess.open(SESSION, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
