extends SceneTree
func _initialize() -> void:
	var app := (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	for i in 10: await process_frame
	var P = root.get_node("Profile")
	if not P.has_account(): P.create_account("Moshe Cohen", "moshe_c", "m@x.com", "")
	var l = app.current
	l._rebuild()
	for i in 40: await process_frame
	var tiles := []
	print("before=", l.scroll.scroll_vertical, " max=", l.scroll.get_v_scroll_bar().max_value, " page=", l.scroll.get_v_scroll_bar().page)
	# drag starting on a level tile (y ~ 400 in ui units), upward
	var x := 270.0
	var y := 420.0
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = Vector2(x, y); e.global_position = e.position
	Input.parse_input_event(e)
	for k in range(1, 12):
		await process_frame
		var m := InputEventMouseMotion.new(); m.position = Vector2(x, y - k * 12); m.global_position = m.position; m.relative = Vector2(0, -12); m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
	await process_frame
	var r := InputEventMouseButton.new(); r.button_index = MOUSE_BUTTON_LEFT; r.pressed = false; r.position = Vector2(x, y - 132); r.global_position = r.position
	Input.parse_input_event(r)
	for i in 5: await process_frame
	print("after=", l.scroll.scroll_vertical, " current_is_launcher=", app.current == l)
	quit()
