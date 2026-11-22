extends Node
## Headless bot for the runner: dodges by lane / jump / slide.
var game
var elapsed := 0.0
var shot_prefix := ""
var shot_i := 0
var shot_times := [1.0, 6.0, 14.0]
var scene := ""
var scene_done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_prefix = a.get_slice("=", 1)
		if a.begins_with("--scene="):
			scene = a.get_slice("=", 1)
	game.finished.connect(func(win: bool):
		print("RESULT %s level=%s t=%.1fs dist=%d coins=%d hearts=%d" % ["WIN" if win else "LOSE", game.level_id, elapsed, game.dist, game.coins, game.hearts])
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit(0 if win else 1))


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > 140.0:
		print("RESULT TIMEOUT dist=%d" % game.dist)
		get_tree().quit(2)
		return
	if shot_prefix != "" and shot_i < shot_times.size() and elapsed >= shot_times[shot_i]:
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [shot_prefix, shot_i])
		shot_i += 1
	if scene != "" and not scene_done and game.phase == "run":
		scene_done = true
		match scene:
			"finish":
				game.dist = game.cfg["goal"] - 45.0
				game.next_spawn_z = -game.cfg["goal"] - 400.0
				shot_times = [0.5, 1.5, 2.0]
				elapsed = 0.0
			"caught":
				game.chase_t = 3.0
				game._spawn_chaser()
				shot_times = [1.5, 2.1, 3.0]
				elapsed = 0.0
				get_tree().create_timer(1.0).timeout.connect(func(): game.invuln = 0.0; game._hurt())
	if scene == "caught" and game.phase != "run":
		return
	if game.phase != "run":
		return
	var hz: float = -game.dist
	var danger := {}
	var jump := false
	var slide := false
	var look: float = 4.0 + game.speed * 0.45
	for o in game.obstacles:
		var dz: float = o["z"] - hz
		var hl: float = {"crate": 0.85, "car": 2.1, "bus": 3.75}.get(o["kind"], 0.0)
		dz += hl
		var rel: float = 0.0 if o["vz"] == 0.0 else float(o["vz"]) * 0.45
		if dz > -1.0 or dz < -look - 2.0 - rel * 2.0:
			continue
		var dist_ahead: float = -dz - rel * 2.0
		match o["kind"]:
			"crate", "car", "bus":
				danger[o["lane"]] = minf(danger.get(o["lane"], 99.0), dist_ahead)
			"hurdle":
				if dist_ahead < look * 0.7:
					jump = true
			"beam":
				if dist_ahead < look * 0.8:
					slide = true
	if danger.has(game.lane):
		var best: int = game.lane
		var best_d: float = danger[game.lane]
		for l in [game.lane - 1, game.lane + 1]:
			if l < 0 or l > 2:
				continue
			var dd: float = danger.get(l, 99.0)
			if dd > best_d + 2.0:
				best = l
				best_d = dd
		if best != game.lane:
			game._action("right" if best > game.lane else "left")
	if jump:
		game._action("jump")
	if slide:
		game._action("slide")
