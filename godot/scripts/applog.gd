extends RefCounted
## Breadcrumb log + crash detection. Used for "Report a problem" and for
## automatically noticing that the app closed in the middle of a level.

const SESSION := "user://session.json"
static var lines: PackedStringArray = PackedStringArray()
static var previous_crash: Dictionary = {}
static var level := ""
const MEM_FILE := "user://mem.log"
const MEM_KEEP := 60
static var mem_lines: PackedStringArray = PackedStringArray() ## this session, also saved to disk after every sample
static var previous_mem: PackedStringArray = PackedStringArray() ## samples from the session that crashed
static var level_t0 := 0
static var active := false ## true while a level is running in the foreground


static func add(msg: String) -> void:
	var t := Time.get_datetime_string_from_system(false, true)
	lines.append("[%s] %s" % [t, msg])
	if lines.size() > 200:
		lines.remove_at(0)
	print("[applog] ", msg)


static func begin_session() -> void:
	var prev := _read()
	previous_mem = _read_mem()
	mem_lines = PackedStringArray()
	_save_mem()
	if bool(prev.get("in_level", false)):
		previous_crash = {"level": str(prev.get("level", "")), "t": prev.get("t", 0)}
		add("Previous session ended unexpectedly during level '%s'" % previous_crash["level"])
	_write({"in_level": false})
	add("Session started. OS=%s model=%s" % [OS.get_name(), OS.get_model_name()])


static func level_started(id: String) -> void:
	level = id
	level_t0 = Time.get_ticks_msec()
	active = true
	add("Level started: " + id)
	sample("level start")
	_write({"in_level": true, "level": id, "t": int(Time.get_unix_time_from_system())})


static func level_ended(how := "") -> void:
	active = false
	if level != "":
		add("Level ended: %s %s" % [level, how])
	_write({"in_level": false})


static func paused(p: bool) -> void:
	if level == "":
		return
	active = not p
	var cur := _read()
	if p:
		_write({"in_level": false, "level": level})
	elif cur.has("level") or level != "":
		_write({"in_level": true, "level": level, "t": int(Time.get_unix_time_from_system())})


## One memory/performance reading, saved to disk right away so it survives a crash
## (a killed app cannot write anything at the moment it dies). Called every 2 s in a level.
static func sample(tag := "") -> void:
	var mi: Dictionary = OS.get_memory_info()
	var mb := 1048576.0
	var s := "t+%ds %s| app %dMB (peak %d) | gpu %dMB (tex %d buf %d) | phone free %d of %dMB | nodes %d obj %d | verts %dk draws %d | %d fps" % [
		int((Time.get_ticks_msec() - level_t0) / 1000.0), (tag + " ") if tag != "" else "",
		int(OS.get_static_memory_usage() / mb), int(OS.get_static_memory_peak_usage() / mb),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb),
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb),
		int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mb),
		int(float(mi.get("available", 0)) / mb), int(float(mi.get("physical", 0)) / mb),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.TIME_FPS))]
	mem_lines.append("[%s] %s: %s" % [Time.get_time_string_from_system(), level, s])
	if mem_lines.size() > MEM_KEEP:
		mem_lines.remove_at(0)
	_save_mem()


## Short text for the problem list: the very last reading before the app died.
static func crash_summary() -> String:
	if previous_mem.is_empty():
		return ""
	return " Last reading before it closed: " + previous_mem[previous_mem.size() - 1].substr(11)


static func _read_mem() -> PackedStringArray:
	if not FileAccess.file_exists(MEM_FILE):
		return PackedStringArray()
	return FileAccess.get_file_as_string(MEM_FILE).split("\n", false)


static func _save_mem() -> void:
	var f := FileAccess.open(MEM_FILE, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(mem_lines))


## Breadcrumbs plus the end of Godot's own log file (when the device writes one).
static func dump() -> String:
	var out := "\n".join(lines)
	if not previous_crash.is_empty() and not previous_mem.is_empty():
		out += "\n--- memory in the last seconds before the crash (oldest first) ---\n" + "\n".join(previous_mem.slice(maxi(previous_mem.size() - 25, 0)))
	if not mem_lines.is_empty():
		out += "\n--- memory this session (last 10) ---\n" + "\n".join(mem_lines.slice(maxi(mem_lines.size() - 10, 0)))
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
