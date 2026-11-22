extends SceneTree
func _initialize() -> void:
	var up := Updater.new()
	root.add_child(up)
	up.status_changed.connect(func(t): print("STATUS ", t))
	await create_timer(0.5).timeout
	up.run("http://127.0.0.1:8765")
	await create_timer(8.0).timeout
	print("META ", Updater.read_meta(), " installed=", Updater.installed_content(), " file=", FileAccess.file_exists("user://update/content.pck"))
	quit()
