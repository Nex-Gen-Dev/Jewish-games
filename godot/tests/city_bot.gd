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
	if scene == "vista":
		_vista()
		return
	if scene == "drive" or scene == "sea":
		_demo(get_physics_process_delta_time())
		return
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
	if game.busy > 0.0:
		return
	step_t += delta
	if step_t < 0.35:
		return
	step_t = 0.0
	var m: Dictionary = game.missions[game.mi]
	var kind: String = m.get("kind", "stand")
	match kind:
		"stand", "shul":
			_on_foot()
			if kind == "shul" and game.bag.size() < game._total_items():
				game.pl.position = game._trunk_spot()
				game.interact()
				return
			game.pl.position = game._stand_pos(game.mi)
			game.interact()
		"stow":
			_on_foot()
			game.pl.position = game._trunk_spot()
			game.interact()
		"reach":
			var tp: Vector3 = m["pos"]
			if str(m.get("veh", "any")) == "boat":
				_ensure_boat()
				game.boat.position = Vector3(tp.x, game.boat.position.y, tp.z)
			else:
				_ensure_car()
				game.van.position = Vector3(tp.x, 0, tp.z)
		"board":
			_on_foot()
			game.pl.position = Vector3(21.0, 0, 85.0)
			game.interact()
		"boat_stand":
			_ensure_boat()
			var bp: Vector3 = m["pos"]
			game.boat.position = Vector3(bp.x, game.boat.position.y, bp.z)
			game.interact()


func _on_foot() -> void:
	if game.in_van:
		game.van_speed = 0.0
		game._exit_car()
	elif game.in_boat:
		game.boat_speed = 0.0
		game.boat.position = Vector3(game.DOCK.x, game.boat.position.y, game.DOCK.z)
		game._exit_boat()


func _ensure_car() -> void:
	if game.in_boat:
		_on_foot()
	if not game.in_van:
		game.pl.position = game.van.position + Vector3(-2.0, 0, 0)
		game.interact()


func _ensure_boat() -> void:
	if game.in_van:
		_on_foot()
	if not game.in_boat:
		game.pl.position = Vector3(21.0, 0, 85.0)
		game.interact()


var vista_i := 0
var vista_t := 0.0
var vista_shots := [
	["market_eye", "golden", Vector3(33, 1.75, -12.5), Vector3(33, 2.6, -46), 68.0],
	["market_aerial", "afternoon", Vector3(60, 62, 30), Vector3(30, 0, -38), 58.0],
	["market_stall", "golden", Vector3(31.5, 1.7, -24.0), Vector3(27.0, 1.8, -30.5), 66.0],
	["geula_street", "golden", Vector3(-3.2, 2.4, 62.0), Vector3(-1.0, 5.0, 10.0), 70.0],
	["market_night", "night", Vector3(33, 1.75, -12.5), Vector3(33, 2.8, -46), 68.0],
	["market_entrance", "sunset", Vector3(33, 2.0, 4.0), Vector3(33, 5.0, -9.4), 64.0],
]


func _vista() -> void:
	if vista_i >= vista_shots.size():
		get_tree().quit(0)
		return
	game.ui.visible = false
	game.phase = "intro"
	var sh: Array = vista_shots[vista_i]
	if vista_t == 0.0:
		game.preset = sh[1]
		game.cine = {"pos": sh[2], "look": sh[3], "fov": sh[4]}
		game._update_env()
	vista_t += get_physics_process_delta_time()
	if vista_t > 1.2:
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [shot_prefix, sh[0]])
		print("shot ", sh[0])
		vista_i += 1
		vista_t = 0.0


var demo_t := 0.0
var demo_step := 0


func _snap(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [shot_prefix, name])
	print("shot ", name)


func _demo(delta: float) -> void:
	demo_t += delta
	game.time_left = 300.0
	game.phase = "play" if game.phase == "intro" and demo_t > 0.3 else game.phase
	if game.phase != "play":
		return
	var di = game.drive_ui
	if scene == "drive":
		match demo_step:
			0:
				game.pl.position = game.van.position + Vector3(-2.2, 0, 0)
				game.interact()
				game.view_mode = 1
				game._apply_view()
				di.bot_on = true
				di.bot_gas = 0.35
				di.bot_steer = 0.0
				demo_step = 1
				demo_t = 0.0
			1:
				di.bot_steer = 0.7 if demo_t > 0.8 else 0.0
				if demo_t > 2.4:
					_snap("car_cockpit")
					game.view_mode = 0
					game._apply_view()
					demo_step = 2
					demo_t = 0.0
			2:
				di.bot_steer = -0.6
				if demo_t > 1.6:
					_snap("car_chase")
					game.view_mode = 2
					demo_step = 3
					demo_t = 0.0
			3:
				if demo_t > 1.0:
					_snap("car_hood")
					di.bot_gas = 0.0
					di.bot_brake = 1.0
					demo_step = 4
					demo_t = 0.0
			4:
				if demo_t > 2.0:
					di.bot_brake = 0.0
					game.view_mode = 0
					game.van_speed = 0.0
					game._exit_car()
					game.bag = ["challah", "fish", "flowers"]
					game._refresh_bag()
					game.pl.position = game._trunk_spot()
					game.pl.rotation.y = game.van_yaw + PI
					game.pl_yaw = game.pl.rotation.y
					game.cam_yaw = game.van_yaw + 0.9
					game.cam_pitch = 0.3
					game.cam_dist = 4.2
					game._trunk_transfer(true)
					demo_step = 5
					demo_t = 0.0
			5:
				if demo_t > 1.45:
					_snap("trunk_loading")
					demo_step = 6
					demo_t = 0.0
			6:
				if demo_t > 2.8:
					_snap("trunk_loaded")
					game.cam_yaw = game.van_yaw + 2.2
					game.pl.position = game._trunk_spot() + Vector3(3, 0, 0)
					game.pl_vel = Vector3.ZERO
					game._give_item("flowers")
					demo_step = 7
					demo_t = 0.0
			7:
				if demo_t > 0.5:
					game.cam_dist = 3.0
					game.cam_yaw = game.pl_yaw + PI + 0.5
					game.cam_pitch = 0.2
				if demo_t > 0.65:
					_snap("carry_hand")
					get_tree().quit(0)
	else:
		match demo_step:
			0:
				game.van.position = Vector3(25.0, 0, 73.5)
				game.van_yaw = 0.0
				game.van.rotation.y = 0.0
				game.pl.position = Vector3(21.0, 0, 85.0)
				game.interact()
				di.bot_on = true
				di.bot_gas = 0.8
				di.bot_steer = 0.0
				demo_step = 1
				demo_t = 0.0
			1:
				if demo_t > 1.2:
					di.bot_steer = 0.6
				if demo_t > 3.2:
					_snap("boat_chase")
					game.view_mode = 1
					game._apply_view()
					demo_step = 2
					demo_t = 0.0
			2:
				if demo_t > 1.0:
					_snap("boat_cockpit")
					game.view_mode = 0
					game._apply_view()
					game.cine = {"pos": Vector3(60, 30, 70), "look": Vector3(10, 0, 95), "fov": 60.0}
					game.preset = "golden"
					game._update_env()
					demo_step = 3
					demo_t = 0.0
			3:
				if demo_t > 1.0:
					game.ui.visible = false
					demo_step = 4
					demo_t = 0.0
			4:
				if demo_t > 0.3:
					_snap("tiberias_aerial")
					get_tree().quit(0)
