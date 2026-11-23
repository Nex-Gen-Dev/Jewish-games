extends Node
## Root: switches between the launcher and a running game level.

const AppLog := preload("res://scripts/applog.gd")
const CloudScript := preload("res://scripts/cloud.gd")
const RunnerScript := preload("res://scripts/runner.gd")
const CityScript := preload("res://scripts/city.gd")
const RaceScript := preload("res://scripts/race.gd")

var current: Node
var selftest_level := ""
var cloud: Node
var ui_shot_dir := "" ## test only: render launcher screens to PNG files
var teaser_mode := false ## recording promo clips: hide every HUD element


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	Profile.reload() ## pick up data from a downloaded content update
	Updater.boot_content = Updater.installed_content()
	AppLog.begin_session()
	cloud = CloudScript.new()
	cloud.name = "Cloud"
	add_child(cloud)
	if not AppLog.previous_crash.is_empty() and Profile.has_account():
		cloud.send_report("crash", "The app closed unexpectedly during level '%s'.%s" % [AppLog.previous_crash["level"], AppLog.crash_summary()])
	var memt := Timer.new() ## memory readings for crash reports (see AppLog.sample)
	memt.wait_time = 2.0
	memt.timeout.connect(func():
		if AppLog.active:
			AppLog.sample())
	add_child(memt)
	memt.start()
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--nogun":
			pass
		if a.begins_with("--uishot="):
			ui_shot_dir = a.get_slice("=", 1)
		if a == "--teaser":
			teaser_mode = true
		if a.begins_with("--selftest="):
			selftest_level = a.get_slice("=", 1)
	if ui_shot_dir != "":
		Updater.checked_this_session = true ## never contact the server in this test
		var t: Node = load("res://tests/shot_ui.gd").new()
		t.set("out", ui_shot_dir)
		t.set("app", self)
		add_child(t)
	elif selftest_level != "":
		if "--gun" in args:
			Profile.data["inventory"] = ["blaster", "rapid"]
		start_level(selftest_level)
	else:
		show_launcher()


func _process(_d: float) -> void:
	if teaser_mode and current:
		for c in current.get_children():
			if c is CanvasLayer or c is Control:
				c.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		AppLog.paused(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		AppLog.paused(false)


func show_launcher() -> void:
	AppLog.level_ended()
	Engine.time_scale = 1.0
	_swap(Launcher.new())
	## The app started fine: clear the crash-loop counter used by boot.gd.
	var f := FileAccess.open("user://update/health.json", FileAccess.WRITE)
	if f:
		f.store_string('{"attempts":0}')


func start_level(level_id: String) -> void:
	Engine.time_scale = 1.0
	AppLog.level_started(level_id)
	cloud.last_level = level_id
	cloud.sync_progress()
	var g: Node
	if level_id.begins_with("runner"):
		g = RunnerScript.new()
	elif level_id.begins_with("city"):
		g = CityScript.new()
	elif level_id.begins_with("race"):
		g = RaceScript.new()
	else:
		g = Game.new()
	g.level_id = level_id
	g.app = self
	_swap(g)
	if selftest_level != "":
		var bot_path := "res://tests/bot.gd"
		if level_id.begins_with("runner"):
			bot_path = "res://tests/runner_bot.gd"
		elif level_id.begins_with("city"):
			bot_path = "res://tests/city_bot.gd"
		elif level_id.begins_with("race"):
			bot_path = "res://tests/race_bot.gd"
		var bot_script: GDScript = load(bot_path)
		var bot: Node = bot_script.new()
		bot.game = g
		add_child(bot)


func next_level_after(level_id: String) -> String:
	for game in Profile.manifest.get("games", []):
		var lv: Array = game.get("levels", [])
		for i in lv.size():
			if lv[i]["id"] == level_id and i + 1 < lv.size() and not lv[i + 1].get("coming_soon", false):
				return lv[i + 1]["id"]
	return ""


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)
