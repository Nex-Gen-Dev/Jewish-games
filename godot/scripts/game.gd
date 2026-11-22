class_name Game
extends Node3D
## One playable level: builds the world, spawns fighters, runs the follow
## camera (portrait + landscape), win/lose flow, points and the HUD.
## Levels: bedroom, street, shul (peaceful davening), market, seder.

signal finished(win: bool)

var level_id := "bedroom"
var app: Node
var player: Player
var hud: Hud
var controls: TouchControls
var cam: Camera3D
var info: Dictionary = {}
var phase := "intro" ## intro, waking, play, over

var yaw := 0.0
var pitch := 0.4
var cam_dist := 5.0
var focus_s := Vector3.ZERO
var focus_init := false
var look_idle := 99.0
var shake := 0.0
var bounds := Rect2()
var portrait := false

var boss: Enemy
var boss_shown := false
var timed := false
var time_left := 0.0
var door_z := -91.0
var alarm_ringing := true
var t := 0.0
var rng := RandomNumberGenerator.new()

# points / combo
var run_points := 0
var combo := 0
var combo_t := 0.0
var committed := false

# yetzer tov
var tovs: Array[Npc] = []
var tov_greeted: Dictionary = {}
var pray_hold := 0.0
var last_hit_t := -10.0

# shul level
var sh_phase := "tefillin"
var tefillin_hold := 0.0
var seat_hold := 0.0
var meter := 0.0
var mistakes := 0
var event: Dictionary = {}
var event_t := 0.0
var next_event := 6.0
var ev_count := 0
var pest: Npc
var whisper: Npc
var away_warned := false
var act_prog := 0.0

# first-person camera, matzah power and the mega bomb
const RUN_LEVELS := ["street", "market", "purim"]
var fp_pitch := 0.0
var fp_hands: Node3D
var fp_on := false
var power_items: Array = []
var power_got := 0
var bomb_ready := false
var boosted := false
var flash: ColorRect


func _ready() -> void:
	rng.randomize()
	_make_environment()
	match level_id:
		"street":
			info = Levels.build_street(self)
		"market":
			info = Levels.build_street(self, {"seed": 5, "dusk": true, "goal_label": "BEIS MEDRASH"})
		"shul":
			info = Levels.build_shul(self)
		"seder":
			info = Levels.build_seder(self)
		"purim":
			info = Levels.build_street(self, {"seed": 9, "goal_label": "PURIM SEUDAH"})
		"finale":
			info = Levels.build_seder(self, {"seed": 71, "wall": "#b9a8d6", "sign": "I'LL SEE YOU TOMORROW"})
		_:
			info = Levels.build_bedroom(self)
	bounds = info["bounds"]
	_make_player()
	_make_camera()
	_make_ui()
	_spawn_tovs()
	_apply_quality()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_begin()


func _exit_tree() -> void:
	_commit_points()
	Engine.time_scale = 1.0
	if get_tree():
		get_tree().paused = false


func _is_indoor() -> bool:
	return level_id in ["bedroom", "shul", "seder", "finale"]


# ---------------------------------------------------------------- setup

func _make_environment() -> void:
	var env := Environment.new()
	if _is_indoor():
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#0b1020")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#7480b8") if level_id == "bedroom" else Color("#c9bfa8")
		env.ambient_light_energy = 0.9 if level_id == "bedroom" else 1.0
	else:
		var dusk := level_id == "market"
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color("#3b4a8a") if dusk else Color("#5d9bdc")
		sm.sky_horizon_color = Color("#f0a070") if dusk else Color("#d7e6f2")
		sm.ground_horizon_color = Color("#f0a070") if dusk else Color("#d7e6f2")
		sm.ground_bottom_color = Color("#6a5a5a") if dusk else Color("#8a8f94")
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.8 if dusk else 1.0
		env.fog_enabled = true
		env.fog_light_color = Color("#f0b090") if dusk else Color("#d7e6f2")
		env.fog_density = 0.005
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = Profile.quality_high()
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Lower quality on phones/tablets (the main cause of slowdowns and crashes).
func _apply_quality() -> void:
	if Profile.quality_high():
		return
	for n in find_children("*", "DirectionalLight3D", true, false):
		(n as DirectionalLight3D).shadow_enabled = false
	cam.far = 110.0


func _make_player() -> void:
	player = Player.new()
	if level_id == "bedroom":
		player.position = info["bed_feet"]
	else:
		player.position = info["stand"]
	add_child(player)
	player.hit_taken.connect(_on_player_hit)
	player.died.connect(_on_player_died)
	player.landed_hit.connect(func(_a, _v): shake = maxf(shake, 0.12))
	if level_id == "bedroom":
		player.rig.rotation = Vector3(PI / 2.0, PI, 0.0)
		player.state = &"sleep"
		cam_dist = 4.4
		pitch = 0.5
		yaw = 0.35
	if level_id == "shul":
		player.combat_enabled = false
		player.move_speed = 4.4
		pitch = 0.55


func _make_camera() -> void:
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 250.0
	add_child(cam)
	cam.current = true


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	controls = TouchControls.new()
	layer.add_child(controls)
	controls.has_gun = Profile.owns("blaster")
	controls.fight_buttons = level_id != "shul"
	controls.set_mode(Profile.get_setting("controls", 0) as TouchControls.Mode)
	player.controls = controls
	hud = Hud.new()
	add_child(hud)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.retry_pressed.connect(func(): app.start_level(level_id))
	hud.menu_pressed.connect(func(): app.show_launcher())
	hud.next_pressed.connect(func(): app.start_level(app.next_level_after(level_id)))
	hud.controls_cycled.connect(func():
		var name := controls.cycle_mode()
		Profile.set_setting("controls", controls.mode)
		hud.set_controls_text(name))
	hud.set_player_health(player.health, player.max_health)
	_update_score_label()


func _on_resize() -> void:
	var s := get_viewport().get_visible_rect().size
	portrait = s.y > s.x
	var street := not _is_indoor()
	if portrait:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 84.0
		cam_dist = 6.6 if street else 5.6
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 64.0
		cam_dist = 5.2 if street else 4.6
	if level_id == "shul":
		cam_dist += 0.8
	if controls:
		controls.exclude_rects = [Rect2(s.x - 90, 0, 90, 76)]


func _spawn_tovs() -> void:
	for p: Vector3 in info.get("tov", []):
		var face := Vector3(-signf(p.x) if absf(p.x) > 0.5 else 0.0, 0, 0.3 if level_id != "shul" else -1.0)
		if face.length() < 0.1:
			face = Vector3(0, 0, 1)
		tovs.append(Levels.spawn_tov(self, p, face))


func _begin() -> void:
	match level_id:
		"bedroom":
			phase = "intro"
			controls.enabled = false
			hud.banner("Level 1 · Out of Bed", "", 2.4)
			hud.show_prompt("Tap to wake up")
		"street":
			phase = "play"
			timed = true
			time_left = 95.0
			hud.banner("Level 2 · Shul on Time", "Davening starts soon. Run!", 2.4)
			hud.say("", "Snooze imps and an angry alarm clock stand between you and shul.", 4.0)
			hud.set_tasks("Reach the shul before time runs out.")
			_spawn_street_enemies()
		"market":
			phase = "play"
			timed = true
			time_left = 120.0
			hud.banner("Level 4 · Night Market", "Knives and rifles. Buy a blaster in the Shop!", 2.8)
			hud.set_tasks("Reach the Beis Medrash. Watch for red laser lines: dodge or run!")
			_spawn_market_enemies()
		"shul":
			phase = "play"
			hud.banner("Level 3 · Davening", "Walk around. Put on tefillin, then find your seat.", 3.0)
			_setup_shul()
		"purim":
			phase = "play"
			timed = true
			time_left = 130.0
			hud.banner("Level 6 · Purim Street", "Costumes, imps and a bad idea. Reach the Seudah!", 2.8)
			hud.set_tasks("Reach the Purim Seudah before time runs out.")
			_spawn_purim_enemies()
		"finale":
			phase = "play"
			hud.banner("Level 7 · Final Round", "He never gives up. Neither do you.", 2.8)
			_start_arena("overlord", "Grab 3 Torah lights = mega bomb. Pray at a Yetzer Tov to heal.")
		"seder":
			phase = "play"
			hud.banner("Level 5 · Seder Night", "Don't let the Yetzer Hara ruin the Seder!", 2.8)
			_start_arena("king", "Grab 3 Matzahs = mega bomb. Pray at a Yetzer Tov to heal.")


# ---------------------------------------------------------------- level 1 flow

func _input(event_in: InputEvent) -> void:
	if phase == "intro":
		if (event_in is InputEventScreenTouch and event_in.pressed) or (event_in is InputEventKey and event_in.pressed):
			wake()


func wake() -> void:
	if phase != "intro":
		return
	phase = "waking"
	alarm_ringing = false
	hud.hide_prompt()
	var start := player.global_position
	var stand: Vector3 = info["stand"]
	var face := Vector3(0.6, 0.0, 0.8).normalized()
	var target_yaw := atan2(-face.x, -face.z)
	var blanket: Node3D = info["blanket"]
	var btw := create_tween().set_parallel(true)
	btw.tween_property(blanket, "position", blanket.position + Vector3(1.1, 0.0, 1.2), 0.8)
	btw.tween_property(blanket, "rotation_degrees:z", 20.0, 0.8)
	var tw := create_tween()
	tw.tween_method(_wake_step.bind(start, stand, target_yaw), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _wake_done(face))


func _wake_step(v: float, start: Vector3, stand: Vector3, target_yaw: float) -> void:
	player.global_position = start.lerp(stand, v) + Vector3(0, sin(v * PI) * 0.7, 0)
	player.rig.rotation = Vector3(lerpf(PI / 2.0, 0.0, v), lerp_angle(PI, target_yaw, v), 0.0)


func _wake_done(face: Vector3) -> void:
	player.face_dir = face
	player.velocity = Vector3.ZERO
	player.state = &"idle"
	phase = "play"
	controls.enabled = true
	yaw = 0.0
	pitch = 0.4
	boss = _spawn_enemy("yetzer", info["enemy_spawn"])
	boss.aggro = 99.0
	boss.appear()
	hud.show_boss(boss.display_name)
	boss_shown = true
	hud.banner("THE YETZER HARA", "\"Five more minutes...\"", 2.2)
	hud.set_tasks("Defeat the Yetzer Hara. Pray with the glowing Yetzer Tov to heal.")


# ---------------------------------------------------------------- enemies

func _spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, player)
	e.position = pos
	add_child(e)
	e.hit_taken.connect(_on_enemy_hit)
	e.died.connect(_on_enemy_died)
	e.taunt.connect(func(who: String, text: String): hud.say(who, text, 2.6))
	e.enraged_now.connect(_on_enraged)
	return e


func _start_arena(boss_kind: String, task: String) -> void:
	hud.set_tasks(task)
	boss = _spawn_enemy(boss_kind, info["enemy_spawn"])
	boss.aggro = 99.0
	boss.appear()
	hud.show_boss(boss.display_name)
	boss_shown = true
	var adds := ["rifle", "rifle"] if boss_kind == "king" else ["rifle", "knife", "rifle"]
	for i in adds.size():
		var imp := _spawn_enemy(adds[i], Vector3(-7 + i * (14.0 / maxf(adds.size() - 1, 1)), 0, 2))
		imp.aggro = 99.0
		imp.appear()
	player.max_health = 160.0
	player.health = 160.0
	hud.set_player_health(player.health, player.max_health)
	var lbl := "TORAH LIGHT" if boss_kind == "overlord" else "MATZAH"
	for p: Vector3 in info.get("pickups", []):
		var n := Node3D.new()
		n.position = p + Vector3(0, 1.0, 0)
		add_child(n)
		Levels.box(n, Vector3.ZERO, Vector3(0.7, 0.08, 0.7), Color("#ffd86a"), false, 2.5)
		for dx in [-0.18, 0.18]:
			Levels.box(n, Vector3(dx, 0.05, 0), Vector3(0.1, 0.04, 0.5), Color("#a8741c"), false, 0.5)
		var l := Levels.label3d(n, Vector3(0, 0.6, 0), lbl, 0.3, Color("#ffe9a0"))
		var light := OmniLight3D.new()
		light.light_color = Color("#ffd86a")
		light.light_energy = 1.2
		light.omni_range = 4.0
		n.add_child(light)
		power_items.append(n)


func _spawn_purim_enemies() -> void:
	var list := [["imp", -2, -14], ["knife", 3, -15], ["imp", -3, -22], ["rifle", 5, -26], ["knife", 0, -32], ["imp", -3, -34],
		["rifle", -6, -40], ["knife", 6, -42], ["imp", 2, -46], ["knife", -2, -52], ["rifle", 4, -74], ["knife", -4, -78],
		["imp", 0, -80], ["rifle", -5, -84], ["knife", 3, -86]]
	for e in list:
		_spawn_enemy(e[0], Vector3(e[1], 0, e[2]))
	boss = _spawn_enemy("haman", Vector3(0, 0, -58))
	boss.aggro = 18.0


func _collect_power(delta: float) -> void:
	for n in power_items.duplicate():
		n.rotation.y += delta * 2.5
		n.position.y = 1.0 + sin(t * 3.0 + n.position.x) * 0.12
		var to: Vector3 = n.global_position - player.global_position
		to.y = 0.0
		if to.length() < 1.3:
			power_items.erase(n)
			n.queue_free()
			power_got += 1
			hud.say("", "Power %d / 3" % power_got, 1.6)
			if power_got >= 3:
				_power_up()


func _power_up() -> void:
	bomb_ready = true
	boosted = true
	controls.has_bomb = true
	controls.queue_redraw()
	player.power = 1.5
	player.move_speed *= 1.15
	player.max_health += 40.0
	player.health = player.max_health
	hud.set_player_health(player.health, player.max_health)
	hud.banner("POWER UP!", "Mega bomb ready (BOMB button) + stronger, faster, more health", 3.2)
	shake = 0.4


func _bomb() -> void:
	bomb_ready = false
	controls.has_bomb = false
	controls.queue_redraw()
	shake = 1.2
	if flash == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		flash = ColorRect.new()
		flash.color = Color(1, 0.9, 0.6, 0.0)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(flash)
	flash.color.a = 0.85
	create_tween().tween_property(flash, "color:a", 0.0, 0.7)
	var sph := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sph.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.6, 0.2, 0.55)
	m.emission_enabled = true
	m.emission = Color(1, 0.5, 0.1)
	m.emission_energy_multiplier = 2.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material_override = m
	sph.position = player.global_position + Vector3(0, 1.0, 0)
	add_child(sph)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sph, "scale", Vector3.ONE * 24.0, 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(sph.queue_free)
	var killed := 0
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.team != 1 or not f.alive:
			continue
		f.invuln = 0.0
		if f == boss:
			f.take_hit(f.max_health * 0.3, player.global_position, 8.0, true)
		else:
			f.take_hit(9999.0, player.global_position, 12.0, true)
			killed += 1
	hud.banner("MEGA BOMB!", "%d Yetzer Haras blown away" % killed, 1.6)


func _spawn_street_enemies() -> void:
	for p in [Vector3(-2, 0, -16), Vector3(2.5, 0, -17), Vector3(-3, 0, -30), Vector3(0, 0, -32), Vector3(3, 0, -30),
			Vector3(-2, 0, -42), Vector3(2, 0, -44), Vector3(-3, 0, -80), Vector3(3, 0, -82)]:
		_spawn_enemy("imp", p)
	boss = _spawn_enemy("clock", Vector3(0, 0, -58))
	boss.aggro = 17.0


func _spawn_market_enemies() -> void:
	var list := [["knife", -3, -14], ["knife", 3, -15], ["rifle", -5, -24], ["rifle", 5, -26], ["knife", 0, -34], ["knife", -3, -35],
		["rifle", -6, -40], ["rifle", 6, -42], ["knife", 2, -47], ["rifle", -4, -78], ["rifle", 4, -80], ["knife", 0, -84]]
	for e in list:
		_spawn_enemy(e[0], Vector3(e[1], 0, e[2]))
	boss = _spawn_enemy("gunslinger", Vector3(0, 0, -58))
	boss.aggro = 18.0


func _on_enemy_hit(f: Fighter, _amt: float) -> void:
	if f == boss:
		hud.set_boss_health(f.health, f.max_health)
	shake = maxf(shake, 0.1)


func _on_enemy_died(f: Fighter) -> void:
	_award_kill(f as Enemy)
	if f != boss:
		return
	hud.set_boss_health(0.0, 1.0)
	if level_id in ["bedroom", "seder", "finale"]:
		var msg: String = {"bedroom": "Modeh ani... you're up. Boker tov!", "seder": "Chag sameach! The Seder goes on.", "finale": "You beat him again. See you tomorrow morning!"}[level_id]
		_win("YETZER HARA DEFEATED", msg)
	else:
		hud.hide_boss()
		boss = null
		hud.say("", "The way is clear. Run to the door!", 3.0)
		var barrier: Node3D = info["barrier"]
		var tw := create_tween()
		tw.tween_property(barrier, "scale", Vector3(1, 0.01, 1), 0.5)
		tw.tween_callback(barrier.queue_free)


func _on_enraged(e: Enemy) -> void:
	shake = 0.35
	match level_id:
		"bedroom":
			hud.say(e.display_name, "Get him, boys!", 2.5)
			for off in [Vector3(-3, 0, 0), Vector3(3, 0, 0)]:
				var imp := _spawn_enemy("imp", player.global_position + off)
				imp.aggro = 99.0
				imp.appear()
		"seder", "finale":
			hud.say(e.display_name, "Boys! Knives out!", 2.5)
			for off in [Vector3(-3, 0, 1), Vector3(3, 0, 1)]:
				var imp := _spawn_enemy("knife", player.global_position + off)
				imp.aggro = 99.0
				imp.appear()
		"market":
			hud.say(e.display_name, "Reload!", 2.0)
		_:
			hud.say(e.display_name, "BRRRRRRING!!!", 2.5)


func _on_player_hit(f: Fighter, _amt: float) -> void:
	hud.set_player_health(f.health, f.max_health)
	shake = maxf(shake, 0.3)
	last_hit_t = t
	combo = 0


func _on_player_died(_f: Fighter) -> void:
	if phase == "over":
		return
	phase = "over"
	controls.enabled = false
	controls.clear()
	_commit_points()
	finished.emit(false)
	_slowmo_then(func():
		hud.show_end("You hit snooze...", "Down, but not out. Try again!" if level_id == "bedroom" else "Down, but not out. Try again!", false))


func _lose_text(title: String, body: String) -> void:
	if phase == "over":
		return
	phase = "over"
	controls.enabled = false
	controls.clear()
	_commit_points()
	finished.emit(false)
	hud.show_end(title, body, false)


func _win(title: String, body: String) -> void:
	if phase == "over":
		return
	phase = "over"
	controls.enabled = false
	controls.clear()
	run_points += 50
	var gained := run_points
	_commit_points()
	Profile.mark_completed(level_id)
	hud.hide_boss()
	finished.emit(true)
	var can_next: bool = app.next_level_after(level_id) != ""
	var text := "%s\nYou earned %d points." % [body, gained]
	_slowmo_then(func(): hud.show_end(title, text, can_next))


func _slowmo_then(cb: Callable) -> void:
	Engine.time_scale = 0.3
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		if is_inside_tree():
			cb.call())


# ---------------------------------------------------------------- points

func _award_kill(e: Enemy) -> void:
	if e == null:
		return
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 8.0
	var base := 100 if e.is_boss else 10
	var mult := mini(combo, 5)
	run_points += base * mult
	_update_score_label()


func _update_score_label() -> void:
	var txt := "Points: %d" % run_points
	if combo >= 2:
		txt += "   Combo x%d" % mini(combo, 5)
	hud.set_score(txt)


func _commit_points() -> void:
	if committed or run_points <= 0:
		return
	committed = true
	Profile.add_points(run_points)


# ---------------------------------------------------------------- pause

func _pause() -> void:
	if phase != "play" or get_tree().paused:
		return
	get_tree().paused = true
	controls.enabled = false
	controls.clear()
	hud.show_pause(["Joystick", "D-pad", "Tilt"][controls.mode])


func _resume() -> void:
	get_tree().paused = false
	hud.close_overlay()
	controls.enabled = true
	controls.clear()


func _unhandled_key_input(event_in: InputEvent) -> void:
	if event_in.is_pressed() and (event_in as InputEventKey).keycode == KEY_ESCAPE:
		if get_tree().paused:
			_resume()
		else:
			_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_resume()
		else:
			_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		## Leaving the app (or a system gesture) pauses instead of letting the game run blind.
		if is_inside_tree() and hud and not get_tree().paused:
			_pause()


# ---------------------------------------------------------------- Yetzer Tov (prayer help)

func _tov_context() -> Dictionary:
	var best: Npc = null
	var bd := 3.4
	for n in tovs:
		var d := n.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = n
	return {"tov": best, "dist": bd}


func _tov_logic(delta: float) -> String:
	## Returns a context-button label ("" if none). Holding it heals you.
	for n in tovs:
		var d := n.global_position.distance_to(player.global_position)
		if d < 7.0 and not tov_greeted.get(n.get_instance_id(), false):
			tov_greeted[n.get_instance_id()] = true
			if level_id != "shul":
				hud.say("Yetzer Tov", "Come pray with me. I will give you strength.", 3.5)
	if level_id == "shul":
		return ""
	var c := _tov_context()
	if c["tov"] == null:
		pray_hold = 0.0
		return ""
	if player.health >= player.max_health - 0.5:
		return "PRAY\n(full health)"
	if controls.is_held("act") and t - last_hit_t > 0.9 and player.state == &"idle":
		pray_hold += delta
		player.health = minf(player.health + 16.0 * delta, player.max_health)
		hud.set_player_health(player.health, player.max_health)
		return "PRAYING..."
	pray_hold = 0.0
	return "PRAY WITH\nYETZER TOV"


# ---------------------------------------------------------------- shul level (davening)

func _setup_shul() -> void:
	sh_phase = "tefillin"
	hud.set_tasks("1. Put on tefillin (hold the button at the glowing bag).\n2. Find your seat.\n3. Daven in peace.")
	var wanderers: Array = info["wanderers"]
	for w: Npc in wanderers:
		var a: Vector3 = w.global_position
		w.set_meta("path", [a, Vector3(a.x, 0, a.z + (12.0 if a.z < 6.0 else -12.0))])
		w.set_meta("idx", 1)
		w.goto(w.get_meta("path")[1])
	hud.say("Yetzer Tov", "Look around. Everyone here is davening. Find your tefillin first.", 4.5)


func _shul_process(delta: float) -> String:
	var ctx := ""
	var prog := 0.0
	# wanderers pace the side aisles
	for w: Npc in info["wanderers"]:
		if not w.has_goal:
			var path: Array = w.get_meta("path")
			var i: int = 1 - int(w.get_meta("idx"))
			w.set_meta("idx", i)
			w.goto(path[i])
	var marker: MeshInstance3D = info["marker"]
	marker.visible = sh_phase != "tefillin"
	marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(t * 4.0))
	match sh_phase:
		"tefillin":
			var spot: Vector3 = info["tefillin_spot"]
			if player.global_position.distance_to(spot) < 2.4:
				ctx = "PUT ON\nTEFILLIN"
				if controls.is_held("act"):
					tefillin_hold += delta
				else:
					tefillin_hold = maxf(tefillin_hold - delta * 2.0, 0.0)
				prog = tefillin_hold / 2.0
				if tefillin_hold >= 2.0:
					_equip_tefillin()
					sh_phase = "seat"
					hud.set_tasks("1. Tefillin: done\n2. Walk to the glowing circle (your seat).\n3. Daven in peace.")
					hud.say("Yetzer Tov", "Good. Now go to your seat. Walk, don't run, in shul.", 4.0)
		"seat":
			var seat: Vector3 = info["seat"]
			if player.global_position.distance_to(seat) < 1.5:
				ctx = "START\nDAVENING"
				if controls.is_held("act"):
					seat_hold += delta
				else:
					seat_hold = maxf(seat_hold - delta * 2.0, 0.0)
				prog = seat_hold / 1.0
				if seat_hold >= 1.0:
					_start_davening()
			else:
				seat_hold = 0.0
		"daven":
			ctx = _daven_process(delta)
			prog = 0.0
	act_prog = prog
	return ctx


func _equip_tefillin() -> void:
	var head: Node3D = player.parts["head"]
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.09, 0.09)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = Levels.mat(Color("#0c0c10"))
	mi.position = Vector3(0, 0.33, -0.2)
	head.add_child(mi)
	var arm: Node3D = player.parts["arm_l"]
	for i in 4:
		var band := CylinderMesh.new()
		band.top_radius = 0.1
		band.bottom_radius = 0.1
		band.height = 0.035
		var b := MeshInstance3D.new()
		b.mesh = band
		b.material_override = Levels.mat(Color("#0c0c10"))
		b.position = Vector3(0, -0.12 - i * 0.07, 0)
		arm.add_child(b)
	var bx := BoxMesh.new()
	bx.size = Vector3(0.13, 0.1, 0.1)
	var bm := MeshInstance3D.new()
	bm.mesh = bx
	bm.material_override = Levels.mat(Color("#0c0c10"))
	bm.position = Vector3(0, -0.05, -0.1)
	arm.add_child(bm)
	run_points += 20
	_update_score_label()


func _start_davening() -> void:
	sh_phase = "daven"
	meter = 0.0
	mistakes = 0
	next_event = 6.0
	var seat: Vector3 = info["seat"]
	player.global_position = seat
	player.face_dir = Vector3(0, 0, -1)
	hud.show_boss("Davening")
	hud.boss_bar.color = Color("#4ade80")
	hud.set_boss_health(0.0, 100.0)
	hud.boss_bar.shown = 0.0
	hud.set_tasks("Stay at your seat. Hold FOCUS to daven faster.\nDon't answer, don't talk back, don't signal!")
	hud.mistakes_label.text = "Mistakes: 0 / 3"
	hud.advice("Nobody's watching. Look at your phone.", "Stay with the words. I'm right here.", 4.0)
	controls.consume("act")


func _daven_process(delta: float) -> String:
	var seat: Vector3 = info["seat"]
	var in_seat := player.global_position.distance_to(seat) < 1.8
	var ctx := ""
	if event.is_empty():
		var focusing := controls.is_held("act")
		ctx = "FOCUS\n(hold)"
		if in_seat:
			away_warned = false
			meter += (2.0 * (2.4 if focusing else 1.0)) * delta
			next_event -= delta
			if next_event <= 0.0:
				_start_event()
		elif not away_warned:
			away_warned = true
			hud.say("Yetzer Tov", "Come back to your seat to keep davening.", 2.5)
		for a in ["punch", "kick", "jump", "dodge", "shoot"]:
			controls.consume(a)
		if not focusing:
			controls.consume("act")
	else:
		ctx = String(event["label"])
		event_t -= delta
		if event["type"] == "phone" and fmod(t, 0.6) < delta:
			shake = maxf(shake, 0.06)
		if controls.consume("act"):
			_mistake(String(event["wrong"]))
		else:
			for a in ["punch", "kick", "jump", "dodge", "shoot"]:
				if controls.consume(a):
					_mistake("You signaled! Stay straight and still.")
					break
		if not event.is_empty() and event_t <= 0.0:
			_resolve_event()
	hud.set_boss_health(meter, 100.0)
	if meter >= 100.0 and phase == "play":
		_finish_davening()
	return ctx


func _start_event() -> void:
	ev_count += 1
	var kind := "phone" if ev_count % 2 == 1 else "talker"
	if kind == "phone":
		event = {"type": "phone", "label": "ANSWER\nCALL", "wrong": "You answered your phone in shul!"}
		event_t = 5.5
		hud.banner("Your phone is ringing!", "", 1.6)
		hud.advice("It could be important! Just pick it up for a second.", "Don't pick it up. Let it ring. Stay with Hashem.", 5.0)
	else:
		event = {"type": "talker", "label": "TALK\nBACK", "wrong": "You talked in the middle of davening!"}
		event_t = 6.5
		var lines := ["Psst! Did you see the game last night?", "Hey, what time is the kiddush? Come on, answer me.", "Hey! Wanna grab lunch after this?"]
		var from := player.global_position + Vector3(-9.0 if rng.randf() < 0.5 else 9.0, 0, 5.0)
		pest = Levels.spawn_npc(self, from, Vector3(0, 0, -1), Npc.Kind.PEST, rng, false)
		pest.move_speed = 2.8
		pest.look_at_pos = player.global_position
		pest.goto(player.global_position + Vector3(1.4, 0, 0.5))
		hud.advice(lines[(ev_count / 2) % lines.size()], "Don't talk back and don't signal. Just keep davening quietly.", 5.5)
	_spawn_whisper()
	controls.consume("act")


func _spawn_whisper() -> void:
	if whisper and is_instance_valid(whisper):
		whisper.queue_free()
	whisper = Npc.new()
	whisper.kind = Npc.Kind.WHISPER
	whisper.look["skin"] = Color("#7a3fc0")
	whisper.look["shirt"] = Color("#3a2a5a")
	whisper.look["pants"] = Color("#241a3a")
	whisper.look["horns"] = true
	whisper.look["tail"] = true
	whisper.look["eye"] = Color("#ffe14a")
	whisper.look["scale"] = 0.45
	whisper.look["light"] = true
	whisper.position = player.global_position + Vector3(0.9, 1.0, 0.1)
	whisper.face_dir = Vector3(-1, 0, 0)
	add_child(whisper)


func _clear_event_actors() -> void:
	if whisper and is_instance_valid(whisper):
		whisper.queue_free()
	whisper = null
	if pest and is_instance_valid(pest):
		pest.look_at_pos = Vector3.ZERO
		pest.goto(Vector3(0, 0, 19.0))
		var p := pest
		get_tree().create_timer(7.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())
	pest = null


func _resolve_event() -> void:
	## The player stayed quiet and still: success.
	_clear_event_actors()
	event = {}
	meter += 8.0
	run_points += 25
	_update_score_label()
	next_event = rng.randf_range(7.0, 10.0)
	hud.say("Yetzer Tov", "Well done. You didn't give in. Keep going.", 3.0)


func _mistake(reason: String) -> void:
	mistakes += 1
	shake = 0.25
	_clear_event_actors()
	event = {}
	next_event = rng.randf_range(8.0, 11.0)
	meter = maxf(meter - 12.0, 0.0)
	hud.mistakes_label.text = "Mistakes: %d / 3" % mistakes
	hud.advice("Ha ha, got you.", reason, 3.5)
	if mistakes >= 3:
		hud.hide_boss()
		_lose_text("Your concentration broke", "Three mistakes. Try again and stay strong.")


func _finish_davening() -> void:
	_clear_event_actors()
	event = {}
	hud.mistakes_label.text = ""
	var bonus := (3 - mistakes) * 30
	run_points += 100 + bonus
	hud.hide_boss()
	_win("AMEN!", "You davened with kavanah and stayed quiet.")


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	t += delta
	if player == null:
		return
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
			_update_score_label()
	if phase == "intro" and alarm_ringing:
		var clock: Node3D = info["clock"]
		clock.rotation.z = sin(t * 70.0) * 0.07
		clock.position.x = -0.95 - 0.15 + sin(t * 90.0) * 0.006
	_update_camera(delta)
	player.cam_yaw = yaw

	if phase == "play":
		var ctx := ""
		var prog := 0.0
		if level_id == "shul":
			ctx = _shul_process(delta)
			prog = act_prog
		if ctx == "":
			ctx = _tov_logic(delta)
			prog = 0.0
		controls.set_act(ctx, prog)
		if not power_items.is_empty():
			_collect_power(delta)
		if controls.consume("bomb") and bomb_ready:
			_bomb()

	if boss and not boss_shown and boss.active and level_id in RUN_LEVELS:
		boss_shown = true
		hud.show_boss(boss.display_name)
		hud.banner(boss.display_name.to_upper(), "Jump the shockwaves! Dodge the volleys!" if level_id != "street" else "Jump the shockwaves!", 2.0)
	if level_id in RUN_LEVELS and phase == "play":
		var dist := maxf(player.global_position.z - door_z, 0.0)
		hud.dist_label.text = "Goal: %d m" % int(dist)
		time_left -= delta
		var secs := maxi(int(ceil(time_left)), 0)
		hud.timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
		hud.timer_label.modulate = Color(1, 0.4, 0.4) if time_left < 15.0 else Color.WHITE
		if player.global_position.z <= door_z + 1.4:
			_win("YOU MADE IT!", "You got there with %d seconds to spare." % secs)
		elif time_left <= 0.0:
			_lose_text("You're late!", "Time ran out. Try again!")


func _nearest_enemy_dir() -> Vector3:
	var best := 11.0
	var out := Vector3.ZERO
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.team != 1 or not f.alive:
			continue
		var to := f.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d < best and d > 0.1:
			best = d
			out = to / d
	return out


func _update_camera(delta: float) -> void:
	var look := controls.take_look()
	if phase == "intro" or phase == "waking":
		look = Vector2.ZERO
	fp_on = int(Profile.get_setting("camera_view", 0)) == 1 and phase == "play"
	if look != Vector2.ZERO:
		yaw -= look.x * 0.006
		if fp_on:
			fp_pitch = clampf(fp_pitch - look.y * 0.004, -1.1, 1.1)
		else:
			pitch = clampf(pitch + look.y * 0.004, 0.05, 1.1)
		look_idle = 0.0
	else:
		look_idle += delta

	if phase == "play" and look_idle > 1.2:
		var dir := _nearest_enemy_dir()
		if dir != Vector3.ZERO:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), 1.0 - exp(-1.6 * delta))
		elif level_id in RUN_LEVELS:
			yaw = lerp_angle(yaw, 0.0, 1.0 - exp(-0.8 * delta))

	player.fp_lock = fp_on
	if fp_on:
		_first_person(delta)
		return
	player.visible = true
	if fp_hands:
		fp_hands.visible = false
	var fy := 0.9 if phase == "intro" else 1.3
	var focus := player.global_position + Vector3(0, fy, 0)
	if not focus_init:
		focus_s = focus
		focus_init = true
	else:
		focus_s = focus_s.lerp(focus, 1.0 - exp(-12.0 * delta))
	var offs := Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, -pitch) * Vector3(0, 0, cam_dist))
	var pos := focus_s + offs
	pos.x = clampf(pos.x, bounds.position.x, bounds.end.x)
	pos.z = clampf(pos.z, bounds.position.y, bounds.end.y)
	var ymax := 3.3 if level_id in ["bedroom", "seder", "finale"] else (8.0 if level_id == "shul" else 14.0)
	pos.y = clampf(pos.y, 0.6, ymax)
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
		shake = move_toward(shake, 0.0, delta * 1.4)
	cam.global_position = pos
	var aim := focus_s + Vector3(0, 0.15, 0)
	if aim.distance_to(pos) > 0.1:
		cam.look_at(aim, Vector3.UP)


## The camera is the character's eyes: you see your hands, not your body.
func _first_person(delta: float) -> void:
	player.visible = false
	if look_idle > 1.0:
		fp_pitch = lerpf(fp_pitch, 0.0, 1.0 - exp(-2.0 * delta))
	if fp_hands == null:
		fp_hands = Node3D.new()
		cam.add_child(fp_hands)
		var skin: Color = player.look["skin"]
		var sleeve: Color = player.look["shirt"]
		for sx in [-1, 1]:
			var arm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.09, 0.09, 0.5)
			arm.mesh = bm
			arm.material_override = Levels.mat(sleeve)
			arm.position = Vector3(sx * 0.34, -0.42, -0.45)
			fp_hands.add_child(arm)
			var fist := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.12, 0.12, 0.14)
			fist.mesh = fm
			fist.material_override = Levels.mat(skin)
			fist.position = Vector3(sx * 0.34, -0.42, -0.78)
			fp_hands.add_child(fist)
		if Profile.owns("blaster"):
			var gun := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.1, 0.12, 0.5)
			gun.mesh = gm
			gun.material_override = Levels.mat(Color("#2a2f3a"))
			gun.position = Vector3(0.3, -0.28, -0.95)
			fp_hands.add_child(gun)
	fp_hands.visible = true
	var punch: float = 1.0 if (player.state == &"attack" or player.shoot_pose > 0.0) else 0.0
	fp_hands.position.z = lerpf(fp_hands.position.z, -0.45 * punch, 1.0 - exp(-24.0 * delta))
	fp_hands.position.y = lerpf(fp_hands.position.y, 0.18 * punch - (0.25 if player.state == &"dodge" else 0.0), 1.0 - exp(-14.0 * delta))
	var pos := player.global_position + Vector3(0, 1.55 if player.state != &"dodge" else 1.1, 0)
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.12
		shake = move_toward(shake, 0.0, delta * 1.4)
	cam.global_position = pos
	cam.rotation = Vector3(fp_pitch, yaw, 0.0)
