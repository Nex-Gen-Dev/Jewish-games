extends Node
## Headless self-test: plays a level by itself and prints a result line.
## Run: godot --headless --fixed-fps 60 --path . -- --selftest=bedroom

var game: Game
var elapsed := 0.0
var acted := 0.0
var log_t := 0.0
var dodged_for: Fighter = null
var result := ""
var shot_prefix := ""
var shot_times := [0.4, 4.0, 9.0]
var shot_i := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_prefix = a.get_slice("=", 1)
		if a == "--fp":
			Profile.set_setting("camera_view", 1)
	await get_tree().process_frame
	game.finished.connect(func(win: bool):
		result = "WIN" if win else "LOSE"
		print("RESULT %s level=%s t=%.1fs player_hp=%.0f" % [result, game.level_id, elapsed, game.player.health])
		await get_tree().create_timer(0.5, true, false, true).timeout
		get_tree().quit(0 if win else 1))


func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	elapsed += delta
	if elapsed > 150.0:
		print("RESULT TIMEOUT level=%s phase=%s" % [game.level_id, game.phase])
		get_tree().quit(2)
		return
	if shot_prefix != "" and shot_i < shot_times.size() and elapsed >= shot_times[shot_i]:
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [shot_prefix, shot_i])
		shot_i += 1
	var p := game.player
	var c := game.controls
	if game.phase == "intro":
		if elapsed > 0.5:
			game.wake()
		return
	if game.phase != "play":
		return

	if game.level_id == "shul":
		_shul_bot(delta)
		return

	var target: Fighter = null
	var best := 1e9
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.team == p.team or not f.alive:
			continue
		var d := p.global_position.distance_to(f.global_position)
		var engaged: bool = (f as Enemy).active or d < 14.0
		if engaged and d < best:
			best = d
			target = f

	var dir := Vector3.ZERO
	if target:
		var to := target.global_position - p.global_position
		to.y = 0
		if to.length() > 1.5:
			dir = to.normalized()
		acted -= delta
		if to.length() < 2.6 and acted <= 0.0:
			c.press("kick" if randf() < 0.4 else "punch")
			acted = 0.28
		if c.has_gun and best > 4.0 and best < 18.0 and acted <= 0.0:
			c.press("shoot")
		if not target.telegraph:
			dodged_for = null
		if target.telegraph and best < 14.0 and dodged_for != target and (target as Enemy).ai_time >= (target as Enemy).tel_time - 0.3:
			dodged_for = target
			if (target as Enemy).pending == &"ring" or (target as Enemy).pending == &"slam":
				c.press("jump")
			else:
				c.press("dodge")
	else:
		dir = Vector3(-p.global_position.x * 0.25, 0, -1).normalized()
	if game.bomb_ready:
		c.press("bomb")
	if not game.power_items.is_empty() and best > 3.0:
		var near: Node3D = game.power_items[0]
		var pto: Vector3 = near.global_position - p.global_position
		pto.y = 0
		dir = pto.normalized()
	var local := Basis(Vector3.UP, game.yaw).inverse() * dir
	c.bot_move = Vector2(local.x, local.z)

	log_t += delta
	if log_t > 5.0:
		log_t = 0.0
		print("t=%.0f hp=%.0f pos=(%.1f,%.1f) enemy=%s" % [elapsed, p.health, p.global_position.x, p.global_position.z, ("%s %.0f" % [(target as Enemy).display_name, target.health]) if target else "-"])


var wps: Array = []
var wp_i := 0


func _walk_to(p: Vector3, tol := 1.0) -> bool:
	var to := p - game.player.global_position
	to.y = 0
	if to.length() < tol:
		game.controls.bot_move = Vector2.ZERO
		return true
	var local := Basis(Vector3.UP, game.yaw).inverse() * to.normalized()
	game.controls.bot_move = Vector2(local.x, local.z)
	return false


func _shul_bot(_delta: float) -> void:
	var c := game.controls
	var i: Dictionary = game.info
	if wps.is_empty():
		wps = [i["tefillin_spot"], Vector3(0, 0, 17.3), Vector3(0, 0, -2.0), i["seat"]]
	match game.sh_phase:
		"tefillin":
			if wp_i == 0:
				if _walk_to(wps[0], 1.2):
					c.held_buttons["act"] = true
			else:
				c.held_buttons["act"] = false
		"seat":
			c.held_buttons["act"] = false
			if wp_i == 0:
				wp_i = 1
			if wp_i < 3:
				if _walk_to(wps[wp_i], 1.2):
					wp_i += 1
			else:
				if _walk_to(wps[3], 0.8):
					c.held_buttons["act"] = true
		"daven":
			c.bot_move = Vector2.ZERO
			c.held_buttons["act"] = game.event.is_empty()
	log_t += _delta
	if log_t > 5.0:
		log_t = 0.0
		print("t=%.0f shul phase=%s meter=%.0f mistakes=%d event=%s" % [elapsed, game.sh_phase, game.meter, game.mistakes, str(game.event.get("type", "-"))])
