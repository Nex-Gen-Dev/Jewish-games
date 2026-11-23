extends Node
## Headless bot for the racing game: the computer drives the player's racer.
## --scene=idle    -> the player never touches the pedals (expects a back-of-the-pack finish)
## --scene=track   -> only build the track, print its size and self-crossings, then quit
## --shot=<prefix> -> save screenshots at fixed times
var game
var elapsed := 0.0
var shot_prefix := ""
var shot_i := 0
var shot_times := [2.0, 5.0, 8.0, 12.0, 20.0, 30.0]
var scene := ""
var maxt := 400.0
var log_t := 0.0
var tour_i := 0
var tour_t := 0.0
var tour_pts: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_prefix = a.get_slice("=", 1)
		if a.begins_with("--scene="):
			scene = a.get_slice("=", 1)
		if a.begins_with("--maxt="):
			maxt = float(a.get_slice("=", 1))
	game.finished.connect(func(win: bool):
		var p = game.player
		print("RESULT %s level=%s place=%d/%d t=%.1fs jumps=%d" % ["WIN" if win else "LOSE", game.level_id, p.place, game.racers.size(), game.race_t, p.jumps])
		await get_tree().create_timer(0.5, true, false, true).timeout
		get_tree().quit(0 if win else 1))
	if scene == "track":
		_check_track()
		return
	game.player_auto = scene != "idle" and scene != "gears"
	if scene == "gears":
		game.phase = "race"
	if scene == "tour" or scene == "gap":
		_tour_setup()
	if "--teaser" in OS.get_cmdline_user_args() and scene == "":
		_teaser_setup()


func _check_track() -> void:
	var tr = game.tr
	var bad := 0
	var i := 0
	while i < tr.n:
		var j := i + 40
		while j < tr.n:
			var d: float = tr.pos[i].distance_to(tr.pos[j])
			var gap_idx: int = j - i
			if tr.closed:
				gap_idx = mini(gap_idx, tr.n - gap_idx)
			if gap_idx > 30 and d < (tr.wid[i] + tr.wid[j]) * 0.5 + 8.0 and absf(tr.pos[i].y - tr.pos[j].y) < 14.0:
				bad += 1
				if bad < 6:
					print("CROSSING near samples %d and %d (%.1f m apart)" % [i, j, d])
			j += 4
		i += 4
	print("TRACK %s n=%d length=%.0f m crossings=%d" % [game.level_id, tr.n, tr.length, bad])
	get_tree().quit(0)


func _teaser_setup() -> void:
	var tr = game.tr
	var at := 20
	if game.level_id == "race1":
		at = tr.dams[0] - 34
	elif game.level_id == "race3":
		at = tr.bridges[0] - 40
	elif game.level_id == "race4":
		at = tr.bridges[0] - 30
	game.phase = "race"
	var k := 0
	for v in game.racers:
		var row := k / 2
		v.place_at(tr, at - row * 4, (-1.0 if k % 2 == 0 else 1.0) * (9.0 if tr.boat else 3.4), 0)
		v.vel = v.forward() * 22.0
		k += 1
	game.player_auto = true
	game._follow(0.016, true)
	if "--chase" in OS.get_cmdline_user_args():
		game.view_mode = 0


func _tour_setup() -> void:
	var tr = game.tr
	if scene == "gap":
		game.view_mode = 1
		var b0: int = tr.bridges[0]
		tour_pts = [b0 - 14, b0 - 6, b0 - 2, b0 + 2, b0 + 6, b0 + 12]
		return
	var pts: Array = [tr.start_idx - 2, int(tr.n * 0.12)]
	if tr.dams.size() > 0:
		pts.append(tr.dams[0] - 14)
		pts.append(tr.dams[0] + 8)
	if tr.bridges.size() > 0:
		pts.append(tr.bridges[0] - 5)
		pts.append(tr.bridges[0] + 8)
	pts.append(int(tr.n * 0.5))
	pts.append(int(tr.n * 0.75))
	pts.append(maxi(tr.finish_idx - 10, 0))
	tour_pts = pts


func _tour(delta: float) -> void:
	tour_t += delta
	if tour_i >= tour_pts.size():
		get_tree().quit(0)
		return
	var tr = game.tr
	var p = game.player
	if tour_t < delta * 1.5:
		var idx: int = tour_pts[tour_i]
		game.phase = "race"
		game.player_auto = false
		p.place_at(tr, idx, 0.0, 0)
		p.vel = p.forward() * 20.0
		p.inp_gas = 1.0
		var k := 0
		for v in game.racers:
			if v != p:
				k += 1
				v.place_at(tr, idx + 5 + k * 5, (-1.0 if k % 2 == 0 else 1.0) * 3.0, 0)
				v.vel = v.forward() * 20.0
		if scene == "tour":
			game.view_mode = 2 if tour_i == tour_pts.size() - 1 else 0
		game.player.driver.visible = game.view_mode != 2
		game._follow(0.016, true)
	p.inp_gas = 1.0
	if tour_t > 1.3:
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [shot_prefix, tour_i])
		print("shot %d idx=%d" % [tour_i, tour_pts[tour_i]])
		tour_i += 1
		tour_t = 0.0


func _gears(delta: float) -> void:
	var p = game.player
	game.player_auto = false
	game.phase = "race"
	game.controls.bot_on = true
	var c = game.controls
	if elapsed < 6.0:
		c.gear_sel = 1
		c.auto = true
		c.bot_gas = 1.0
		c.bot_brake = 0.0
	elif elapsed < 9.0:
		c.bot_gas = 0.0
		c.bot_brake = 1.0
	elif elapsed < 12.0:
		c.gear_sel = -1
		c.bot_gas = 1.0
		c.bot_brake = 0.0
	elif elapsed < 15.0:
		c.gear_sel = 3
		c.auto = false
		c.bot_gas = 1.0
	else:
		print("GEARS ok")
		get_tree().quit(0)
	if int(elapsed * 10.0) % 10 == 0 and int(elapsed * 60.0) % 6 == 0:
		print("t=%.1f sel=%d gear=%s speed=%.1f m/s rpm=%.2f" % [elapsed, c.gear_sel, p.gear_text(), p.fwd_speed(), p.rpm])


func _stats() -> void:
	var rss := 0
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f:
		for ln in f.get_as_text().split("\n"):
			if ln.begins_with("VmRSS"):
				rss = int(ln.get_slice(":", 1).strip_edges().get_slice(" ", 0)) / 1024
	print("STATS t=%.0f rssMB=%d staticMB=%d vramMB=%d texMB=%d nodes=%d objs=%d prims=%d draws=%d" % [elapsed, rss,
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])


func _physics_process(delta: float) -> void:
	elapsed += delta
	if "--stats" in OS.get_cmdline_user_args() and int(elapsed * 60.0) % 300 == 0:
		_stats()
	if scene == "gears":
		_gears(delta)
		return
	if scene == "tour" or scene == "gap":
		_tour(delta)
		return
	if shot_prefix != "" and shot_i < shot_times.size() and elapsed >= shot_times[shot_i]:
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [shot_prefix, shot_i])
		shot_i += 1
	log_t += delta
	var pp = game.player
	if pp.landed > 0.0:
		print("LANDED t=%.1f idx=%d impact=%.1f speed=%.0f km/h jumps=%d" % [elapsed, pp.idx, pp.landed, absf(pp.fwd_speed()) * 3.6, pp.jumps])
	if pp.respawned:
		print("RESPAWN t=%.1f idx=%d" % [elapsed, pp.idx])
	if log_t > 10.0:
		log_t = 0.0
		var p = game.player
		print("t=%.0f phase=%s place=%d prog=%.0f/%.0f speed=%.0f km/h gear=%s lat=%.1f y=%.1f jumps=%d" % [elapsed, game.phase, p.place, p.progress, game.goal, absf(p.fwd_speed()) * 3.6, p.gear_text(), p.lat, p.pos.y, p.jumps])
	if elapsed > maxt:
		print("RESULT TIMEOUT place=%d prog=%.0f/%.0f" % [game.player.place, game.player.progress, game.goal])
		get_tree().quit(2)
