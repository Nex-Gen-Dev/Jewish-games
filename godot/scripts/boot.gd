extends Node
## First scene. Mounts a downloaded content update (if any) BEFORE the real app
## loads, then starts the app. Has no dependencies on other game scripts.
## If the app fails to start 3 times in a row with an update, the update is
## thrown away and the bundled version is used instead.

const BASE_CONTENT := 11 ## must equal the content bundled in the newest APK (else a stale cached pack overrides the APK)
const DIR := "user://update"


func _ready() -> void:
	var health := _read(DIR + "/health.json")
	var attempts := int(health.get("attempts", 0))
	var meta := _read(DIR + "/meta.json")
	var pck := DIR + "/content.pck"
	if FileAccess.file_exists(pck) and int(meta.get("content", 0)) > BASE_CONTENT:
		if attempts >= 3:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(pck))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/meta.json"))
			attempts = 0
		else:
			_write(DIR + "/health.json", {"attempts": attempts + 1})
			ProjectSettings.load_resource_pack(pck, true)
	_start.call_deferred()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/app.tscn")


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
