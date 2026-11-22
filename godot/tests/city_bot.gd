extends Node
## Headless bot for the city game: visits each errand, then the shul.
## --scene=timeout  -> let the clock run out (expects LOSE)
## --scene=van      -> drive the van for a few seconds first (screenshots)
## --shot=<prefix>  -> save screenshots
var game
var elapsed := 0.0
var shot_prefix := ""
var shot_i := 0
var shot_times := [3.6, 5.0, 7.0]
var scene := ""
var step_t := 0.0
var scene_init := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_prefix = a.get_slice("=", 1)
		if a.begins_with("--scene="):
			scene = a.get_slice("=", 1)
	game.finished.connect(func(win: bool):
		print("RESULT %s level=%s t=%.1fs errands=%d coins=%d left=%.0f" % ["WIN" if win else "LOSE", game.level_id, elapsed, game.mi, game.coins, game.time_left])
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit(0 if win else 1))


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > 120.0:
		print("RESULT TIMEOUT mi=%d" % game.mi)
		get_tree().quit(2)
		return
	if shot_prefix != "" and shot_i < shot_times.size() and elapsed >= shot_times[shot_i]:
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [shot_prefix, shot_i])
		shot_i += 1
	if game.phase != "play":
		return
	if "--teaser" in OS.get_cmdline_user_args():
		# cinematic walk down the market for promo clips
		if not scene_init:
			scene_init = true
			game.pl.position = Vector3(33.5, 0, -10.0)
			game.cam_yaw = 0.0
			game.cam_pitch = 0.3
		game.time_left = maxf(game.time_left, 200.0)
		game.controls.bot_move = Vector2(0.0, -0.55)
		game.cam_yaw = sin(elapsed * 0.5) * 0.25
		if elapsed > 12.0:
			get_tree().quit(0)
		return
	if scene == "timeout":
		if not scene_init:
			scene_init = true
			game.time_left = 2.0
		return
	if scene == "shots":
		# teleport around for screenshots
		if not scene_init:
			scene_init = true
			shot_times = [0.3, 1.0, 1.7, 2.4, 3.1, 3.8]
			elapsed = 0.0
			shot_i = 0
		var spots := [Vector3(7.5, 0, 30), Vector3(-33, 0, 3.5), Vector3(33, 0, -3), Vector3(31, 0, -30), Vector3(-56, 0, -33), Vector3(33, 0, -70)]
		var idx := mini(int(elapsed / 0.7), spots.size() - 1)
		game.pl.position = spots[idx]
		game.cam_yaw = [0.0, PI, 0.0, 1.57, -1.57, PI][idx]
		game.pl.rotation.y = 0.0
		return
	if scene == "van":
		if not scene_init:
			scene_init = true
			shot_times = [1.5, 3.0, 4.5]
			elapsed = 0.0
			shot_i = 0
			game.pl.position = Vector3(7.0, 0, 44.0)
			game.interact()
			print("in_van=", game.in_van)
		game.controls.bot_move = Vector2(0.0, -1.0) if elapsed > 0.5 else Vector2.ZERO
		if elapsed > 6.0:
			print("van pos ", game.van.position, " speed ", game.van_speed)
			get_tree().quit(0)
		return
	if game.mi >= game.missions.size():
		return
	step_t += delta
	var target: Vector3 = game._stand_pos(game.mi)
	if scene == "van":
		pass
	game.pl.position = target
	if step_t > 0.4:
		step_t = 0.0
		game.interact()
