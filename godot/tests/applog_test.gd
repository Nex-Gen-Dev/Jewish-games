extends SceneTree
## godot --headless --path godot --script res://tests/applog_test.gd
func _init() -> void:
	var L := load("res://scripts/applog.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mem.log"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://session.json"))
	L.begin_session()
	L.level_started("race1")
	for i in 3:
		L.sample()
	# simulate a crash: no level_ended(); a new session starts
	L.begin_session()
	var d: String = L.dump()
	print("TEST crash_detected: ", "PASS" if L.previous_crash.get("level", "") == "race1" else "FAIL")
	print("TEST mem_saved_across_crash: ", "PASS" if L.previous_mem.size() == 4 else "FAIL (%d)" % L.previous_mem.size())
	print("TEST dump_has_memory: ", "PASS" if d.contains("memory in the last seconds") and d.contains("app ") else "FAIL")
	print("TEST summary: ", "PASS" if L.crash_summary().contains("phone free") else "FAIL")
	print(L.crash_summary())
	L.level_started("x"); L.level_ended()
	L.begin_session()
	print("TEST no_false_crash: ", "PASS" if L.previous_crash.get("level", "") == "race1" else "FAIL")
	quit()
