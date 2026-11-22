extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://update")
	var f := FileAccess.open("user://update/meta.json", FileAccess.WRITE)
	f.store_string('{"api_url":"http://127.0.0.1:8788"}')
	f.close()
	Updater.checked_this_session = true
	var app := (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	for i in 10: await process_frame
	await create_timer(4.0).timeout
	var f2 := FileAccess.open("user://update/meta.json", FileAccess.WRITE)
	f2.store_string('{"api_url":"http://127.0.0.1:8788"}')
	f2.close()
	var P = root.get_node("Profile")
	P.data["account"] = {}
	print("ERR=", P.create_account("Test User", "testuser", "t@x.com", ""))
	P.apply_update({"account": {"terms_version": 1, "terms_sent": false}, "progress": {"completed": ["bedroom"], "points": 77}})
	await create_timer(2.0).timeout
	app.cloud.last_level = "street"
	app.cloud.poll()
	await create_timer(2.0).timeout
	app.cloud.send_report("bug", "test report from godot", true)
	app.cloud.sync_progress()
	await create_timer(3.0).timeout
	print("TOKEN=", str(P.account().get("token", "")).length(), " synced=", P.account().get("synced"), " legal=", app.cloud.legal.get("version"))
	quit()
