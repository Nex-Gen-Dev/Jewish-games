extends SceneTree
func _initialize() -> void:
	var tab := "play"
	var out := "/tmp/shots/x.png"
	var acct := true
	var scrolly := 0
	var todo := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tab="): tab = a.substr(6)
		if a.begins_with("--out="): out = a.substr(6)
		if a == "--noacct": acct = false
		if a.begins_with("--scroll="): scrolly = int(a.substr(9))
		if a.begins_with("--do="): todo = a.substr(5)
	var app := (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	for i in 10:
		await process_frame
	var P = root.get_node("Profile")
	if acct and not P.has_account():
		P.create_account("Moshe Cohen", "moshe_c", "moshe@example.com", "")
	else:
		if not acct:
			P.data["account"] = {}
	if acct:
		P.apply_update({"account": {"terms_version": 1}, "onboarded": {"app": todo != "tour", "fighter": true, "runner": true}})
	for i in 10:
		await process_frame
	var l = app.current
	l._rebuild()
	for i in 5:
		await process_frame
	if acct:
		l._show(tab)
	for i in 40:
		await process_frame
	match todo:
		"inbox":
			app.cloud.inbox = [{"id":1,"title":"Terms & Privacy updated","body":"Please review and accept.","created_at":1,"read":false},{"id":2,"title":"New level!","body":"Night Chase is ready in Street Runner.","created_at":1,"read":false}]
			l._open_inbox()
		"report": l._report_dialog()
		"terms": l._terms_gate()
		"howto": l._howto(P.manifest["games"][0])
		"toast": l._toast("New level!", "Night Chase is ready in Street Runner.")
	for i in 30:
		await process_frame
	if scrolly > 0 and l.scroll:
		l.scroll.scroll_vertical = scrolly
		for i in 5:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " size=", l.size, " wide=", l.wide)
	quit()
