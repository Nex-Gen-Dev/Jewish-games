extends Node
## Renders launcher screens to PNG for visual checks (offline: never calls the server).
## usage: godot --path godot --resolution 540x960 -- --out=/tmp/shots --wide=0
var out := "/tmp/shots"
var app: Node


func _ready() -> void:
	await get_tree().process_frame
	var P: Node = Profile
	P.data["account"] = {"user_id": "PG-TEST0001", "name": "Test User", "username": "tester", "email": "t@example.com", "terms_version": 99, "terms_sent": true}
	P.data["display_name"] = "Test User"
	P.data["onboarded"] = {"app": true, "fighter": true, "runner": true}
	P.data["progress"] = {"completed": ["bedroom", "street", "runner1"], "points": 180}
	P.changed.emit()
	var acct: Dictionary = P.data["account"]
	P.data["account"] = {}
	app.show_launcher()
	for i in 30:
		await get_tree().process_frame
	await _snap(out + "/signin.png")
	P.data["account"] = acct
	app.show_launcher()
	await get_tree().process_frame
	var l: Control = app.current
	for i in 40:
		await get_tree().process_frame
	await _snap(out + "/home.png")
	l.call("_show", "shop")
	for i in 20:
		await get_tree().process_frame
	await _snap(out + "/shop.png")
	l.call("_show", "settings")
	for i in 20:
		await get_tree().process_frame
	await _snap(out + "/settings.png")
	l.call("_show", "play")
	for i in 10:
		await get_tree().process_frame
	var g: Dictionary = P.manifest["games"][0]
	l.call("_open_hub", g)
	for i in 60:
		await get_tree().process_frame
	await _snap(out + "/hub_levels.png")
	l.set("hub_tab", "howto")
	l.call("_hub_render")
	for i in 20:
		await get_tree().process_frame
	await _snap(out + "/hub_howto.png")
	l.set("hub_tab", "options")
	l.call("_hub_render")
	for i in 20:
		await get_tree().process_frame
	await _snap(out + "/hub_options.png")
	l.call("_close_hub")
	var g2: Dictionary = P.manifest["games"][1]
	l.call("_open_hub", g2)
	l.set("hub_tab", "levels")
	l.call("_hub_render")
	for i in 60:
		await get_tree().process_frame
	await _snap(out + "/hub_runner.png")
	# nested taps: card body opens the game page, the Play button inside it starts the level
	l.call("_close_hub")
	l.call("_show", "play")
	for i in 10:
		await get_tree().process_frame
	var card: Control = _find_card(l)
	var rect := card.get_global_rect()
	await _click(rect.position + Vector2(60, 60))
	for i in 5:
		await get_tree().process_frame
	print("TEST tap_card_body_opens_hub: ", "PASS" if l.get("hub") != null else "FAIL")
	l.call("_close_hub")
	for i in 5:
		await get_tree().process_frame
	await _click(rect.position + Vector2(rect.size.x - 120, rect.size.y - 36))
	for i in 5:
		await get_tree().process_frame
	var started: bool = app.current != l and not (app.current is Launcher)
	print("TEST tap_play_button_starts_level_only: ", "PASS" if started and Launcher.resume_hub == "" else "FAIL (current=%s hub=%s)" % [app.current, Launcher.resume_hub])
	app.show_launcher()
	for i in 5:
		await get_tree().process_frame
	l = app.current
	l.call("_open_hub", g2)
	l.set("hub_tab", "levels")
	l.call("_hub_render")
	# flow: play from the hub, end the level, land back on the same game page
	l.call("_launch", g2, "runner1", true)
	for i in 30:
		await get_tree().process_frame
	app.show_launcher()
	for i in 20:
		await get_tree().process_frame
	var l2: Control = app.current
	var back_ok: bool = l2.get("hub") != null and is_instance_valid(l2.get("hub"))
	print("TEST resume_hub_after_level: ", "PASS" if back_ok else "FAIL")
	l2.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	for i in 5:
		await get_tree().process_frame
	var closed: bool = l2.get("hub") == null
	print("TEST back_button_closes_hub: ", "PASS" if closed else "FAIL")
	print("TEST home_visible_after_close: ", "PASS" if l2.get("ui").visible else "FAIL")
	print("TEST resume_cleared: ", "PASS" if str(l2.get("resume_hub")) == "" else "FAIL")
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _find_card(n: Node) -> Control:
	for c in n.get_children():
		if c is PanelContainer and c.clip_contents and c.get_child_count() > 0 and c.get_child(0) is HBoxContainer:
			return c
		var r := _find_card(c)
		if r:
			return r
	return null


func _click(pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = true
	get_viewport().push_input(e)
	await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.position = pos
	u.global_position = pos
	u.pressed = false
	get_viewport().push_input(u)
	await get_tree().process_frame
