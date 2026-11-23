extends Node
## Offline test of the tester feed: run with a local server on 127.0.0.1:8765 that serves
## version.json (public) and beta.json. TEST_BETA=1 marks this player as a tester.
func _ready() -> void:
	var beta := OS.get_environment("TEST_BETA") == "1"
	if beta:
		Profile.data["beta"] = true
	var up := Updater.new()
	add_child(up)
	up.status_changed.connect(func(t): print("STATUS ", t))
	await get_tree().create_timer(0.5).timeout
	up.run("http://127.0.0.1:8765")
	await get_tree().create_timer(5.0).timeout
	print("BETA=", beta, " META ", Updater.read_meta(), " file=", FileAccess.file_exists("user://update/content.pck"))
	get_tree().quit()
