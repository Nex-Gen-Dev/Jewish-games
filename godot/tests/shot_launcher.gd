extends SceneTree
func _initialize() -> void:
	var app := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	for i in 20:
		await process_frame
	var l: Control = app.current
	print("launcher=", l, " size=", l.size if l else "-", " children=", l.get_child_count() if l else -1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/shots/launcher.png")
	quit()
