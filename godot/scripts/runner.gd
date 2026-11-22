extends Node3D
## Street Runner: a 3-lane endless-style runner with a finish line.
## Controls: swipe (left/right = change lane, up = jump, down = slide),
## on-screen arrows, keyboard (A/D, W/Space, S) or tilt (Settings > Controls).

const Hero := preload("res://scripts/runner_hero.gd")
const Art := preload("res://scripts/runner_art.gd")
const AppLog := preload("res://scripts/applog.gd")
const LANE := 2.2
const JUMP_V := 12.6
const GRAV := 34.0
const CHASE_WINDOW := 6.0
const LEVELS := {
	"runner1": {"title": "Erev Shabbos Dash", "goal": 900.0, "v0": 11.0, "acc": 0.17, "vmax": 24.0, "gap": 16.0, "cars": false, "dusk": true,
		"intro": "Shabbos is coming! Run to shul before candle lighting."},
	"runner2": {"title": "Night Chase", "goal": 1300.0, "v0": 13.0, "acc": 0.22, "vmax": 30.0, "gap": 13.0, "cars": true, "dusk": false,
		"intro": "The Yetzer Hara is chasing you. Don't stop, don't look back!"},
}

signal finished(win: bool)

var level_id := "runner1"
var app: Node
var cfg: Dictionary
var hero
var cam: Camera3D
var lane := 1
var target_x := 0.0
var dist := 0.0
var speed := 10.0
var y := 0.0
var floor_y := 0.0
var vy := 0.0
var slide_t := 0.0
var hearts := 3
var coins := 0
var invuln := 0.0
var phase := "intro" ## intro, run, caught, over
var run_t := 0.0
var chase_t := 0.0 ## >0 while the Yetzer Hara is right behind you
var chaser
var chaser_gap := 40.0
var carry_t := 0.0
var meshes := {}
var variants: Array = []
var coin_mesh: ArrayMesh
var pad: Array = []
var btn_mode: Button
var t := 0.0
var obstacles: Array = [] ## {node, kind, lane, z, vz}
var pickups: Array = [] ## {node, lane, z, y}
var next_spawn_z := -40.0
var next_chunk_z := 0.0
var rng := RandomNumberGenerator.new()
var mats := {}
var chunks: Array = []
var finish_node: Node3D
var committed := false
var swipe_start := Vector2.ZERO
var swiping := false
var shake := 0.0
var paused := false
var tilt_cool := 0.0
# UI
var ui: CanvasLayer
var l_dist: Label
var l_coins: Label
var l_hearts: Label
var l_banner: Label
var bar: ColorRect
var bar_fill: ColorRect
var overlay: Control


func _ready() -> void:
	cfg = LEVELS.get(level_id, LEVELS["runner1"])
	rng.seed = 1000 + level_id.hash() % 1000
	speed = cfg["v0"]
	_environment()
	_camera()
	hero = Hero.new()
	add_child(hero)
	hero.rotation.y = 0.0
	_build_ui()
	for i in 8:
		_make_chunk()
	_apply_quality()
	get_tree().root.size_changed.connect(_camera)
	_banner(cfg["title"], cfg["intro"], 2.6)
	get_tree().create_timer(2.6).timeout.connect(func():
		if phase == "intro":
			phase = "run")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == "run":
			_pause(true)


func _apply_quality() -> void:
	pass


# ---------------------------------------------------------------- world

func mat(c: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), emissive]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	mats[key] = m
	return m


func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _environment() -> void:
	var env := Environment.new()
	var dusk: bool = cfg["dusk"]
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#3d86e0") if dusk else Color("#1a1f5c")
	sm.sky_horizon_color = Color("#ffc47a") if dusk else Color("#7a5ad0")
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Color("#2a2030")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9 if dusk else 0.7
	env.fog_enabled = true
	env.fog_light_color = Color("#ffd2a0") if dusk else Color("#5a4aa8")
	env.fog_density = 0.007
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1 if dusk else 0.6
	sun.light_color = Color("#ffd2a0") if dusk else Color("#9ab0ff")
	add_child(sun)


func _camera() -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.current = true
		add_child(cam)
	var vs := get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 88.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 68.0
	cam.far = 220.0


func _make_chunk() -> void:
	if variants.is_empty():
		var night: bool = not cfg["dusk"]
		var vr := RandomNumberGenerator.new()
		vr.seed = 77 + level_id.hash() % 100
		for i in 6:
			variants.append(Art.street_chunk(vr, night, LANE, i == 0))
	var ch := MeshInstance3D.new()
	ch.mesh = variants[rng.randi() % variants.size()]
	ch.position.z = next_chunk_z
	if rng.randf() < 0.5:
		ch.scale.x = -1.0
	add_child(ch)
	chunks.append(ch)
	next_chunk_z -= 30.0


func _mesh(key: String, maker: Callable) -> ArrayMesh:
	if not meshes.has(key):
		meshes[key] = maker.call()
	return meshes[key]


func _mi(parent: Node3D, m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	parent.add_child(mi)
	return mi


func _spawn_row(z: float) -> float:
	var pat := rng.randi() % (8 if cfg["cars"] else 6)
	match pat:
		0, 1:
			_obstacle("crate", rng.randi() % 3, z)
		2:
			var free := rng.randi() % 3
			for l in 3:
				if l != free:
					_obstacle("crate", l, z)
			_coin_line(free, z, 5)
		3:
			_obstacle("hurdle", -1, z)
			_coin_arc(z)
		4:
			_obstacle("beam", -1, z)
			_coin_line(rng.randi() % 3, z + 6.0, 4)
			return 3.0
		5:
			var l := rng.randi() % 3
			_coin_line(l, z, 7)
			_obstacle("crate", (l + 1 + rng.randi() % 2) % 3, z - 10.0)
			return 11.0
		6:
			_obstacle("car", rng.randi() % 3, z)
			return 6.0
		7:
			var bl := rng.randi() % 3
			_obstacle("bus", bl, z)
			_coin_line((bl + 1) % 3, z, 5)
			return 8.0
	return 0.0


func _coin_line(l: int, z: float, n: int) -> void:
	for i in n:
		_pickup(l, z - i * 2.0, 0.9)


func _coin_arc(z: float) -> void:
	var l := rng.randi() % 3
	for i in 5:
		_pickup(l, z + 4.0 - i * 2.0, 0.9 + sin(float(i) / 4.0 * PI) * 1.4)


func _obstacle(kind: String, l: int, z: float) -> void:
	var n := Node3D.new()
	add_child(n)
	var x := (l - 1) * LANE
	var vz := 0.0
	var night: bool = not cfg["dusk"]
	match kind:
		"crate":
			n.position = Vector3(x, 0, z)
			var k := rng.randi() % 3
			_mi(n, _mesh("block%d" % k, func(): return Art.block(k, rng)))
		"hurdle":
			n.position = Vector3(0, 0, z)
			_mi(n, _mesh("hurdle", func(): return Art.hurdle(LANE)))
		"beam":
			n.position = Vector3(0, 0, z)
			_mi(n, _mesh("beam", func(): return Art.beam(LANE, night)))
		"car":
			n.position = Vector3(x, 0, z)
			vz = 5.0
			var ci := rng.randi() % (Art.CAR_COLORS.size() + 1)
			_mi(n, _mesh("car%d" % ci, func(): return Art.car(Color("#ffc61a") if ci == Art.CAR_COLORS.size() else Color(Art.CAR_COLORS[ci]), ci == Art.CAR_COLORS.size())))
		"bus":
			n.position = Vector3(x, 0, z)
			vz = 4.0
			var bi := rng.randi() % 3
			_mi(n, _mesh("bus%d" % bi, func(): return Art.bus(Color(["#2e7dd1", "#e8a020", "#d84a4a"][bi]))))
	obstacles.append({"node": n, "kind": kind, "lane": l, "z": z, "vz": vz})


func _pickup(l: int, z: float, h: float) -> void:
	if coin_mesh == null:
		coin_mesh = Art.coin_mesh()
	var n := MeshInstance3D.new()
	n.mesh = coin_mesh
	n.position = Vector3((l - 1) * LANE, h, z)
	add_child(n)
	pickups.append({"node": n, "lane": l, "z": z, "y": h})


func _build_finish() -> void:
	finish_node = Node3D.new()
	finish_node.position.z = -cfg["goal"]
	add_child(finish_node)
	_mi(finish_node, Art.shul(LANE))
	var lb := Label3D.new()
	lb.text = "SHUL"
	lb.font_size = 120
	lb.pixel_size = 0.03
	lb.modulate = Color("#ffd34a")
	lb.outline_modulate = Color("#6a4a10")
	lb.outline_size = 16
	lb.shaded = false
	lb.position = Vector3(0, 12.0, 0.1)
	lb.no_depth_test = false
	finish_node.add_child(lb)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	l_hearts = _lbl(root, "", 22, Color("#ff6b6b"))
	l_hearts.position = Vector2(18, 14)
	l_coins = _lbl(root, "", 18, Color("#ffd34a"))
	l_coins.position = Vector2(18, 44)
	l_dist = _lbl(root, "", 16, Color(1, 1, 1, 0.8))
	l_dist.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l_dist.position.y = 12
	l_dist.offset_left = -80
	l_dist.offset_right = 80
	l_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = ColorRect.new()
	bar.color = Color(0, 0, 0, 0.45)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left = -110
	bar.offset_right = 110
	bar.offset_top = 38
	bar.offset_bottom = 48
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	bar_fill = ColorRect.new()
	bar_fill.color = Color("#4ade80")
	bar_fill.size = Vector2(0, 10)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_fill)
	l_banner = _lbl(root, "", 34, Color.WHITE)
	l_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l_banner.offset_left = -240
	l_banner.offset_right = 240
	l_banner.offset_top = -120
	l_banner.offset_bottom = -20
	l_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_banner.modulate.a = 0.0
	# pause
	var pb := _mini_button(root, "II", func(): _pause(true))
	pb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pb.offset_left = -76
	pb.offset_right = -22
	pb.offset_top = 14
	pb.offset_bottom = 60
	# on-screen arrows
	var specs := [["<", Control.PRESET_BOTTOM_LEFT, 22, "left"], [">", Control.PRESET_BOTTOM_LEFT, 112, "right"],
		["^", Control.PRESET_BOTTOM_RIGHT, -176, "jump"], ["v", Control.PRESET_BOTTOM_RIGHT, -86, "slide"]]
	for sp in specs:
		var b := _mini_button(root, sp[0], func(): _action(sp[3]))
		b.set_anchors_and_offsets_preset(sp[1])
		if sp[1] == Control.PRESET_BOTTOM_LEFT:
			b.offset_left = sp[2]
			b.offset_right = sp[2] + 74
		else:
			b.offset_left = sp[2]
			b.offset_right = sp[2] + 74
		b.offset_top = -130
		b.offset_bottom = -56
		b.modulate.a = 0.85
		pad.append(b)
	_apply_controls()
	_hud_update()


func _ctl() -> int:
	return int(Profile.get_setting("runner_controls", 0))


func _apply_controls() -> void:
	for b in pad:
		b.visible = _ctl() == 1


func _pause_hint() -> String:
	match _ctl():
		1:
			return "Use the arrow buttons: left, right, jump (^) and slide (v)."
		2:
			return "Tilt your device left or right to change lane. Swipe up to jump, down to slide."
	return "Swipe left or right to change lanes, up to jump, down to slide."


func _lbl(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _mini_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _banner(title: String, sub := "", dur := 2.0) -> void:
	l_banner.text = title + ("\n" + sub if sub != "" else "")
	l_banner.add_theme_font_size_override("font_size", 34 if sub == "" else 28)
	var tw := create_tween()
	tw.tween_property(l_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(dur)
	tw.tween_property(l_banner, "modulate:a", 0.0, 0.4)


func _hud_update() -> void:
	l_hearts.text = "♥ ".repeat(hearts).strip_edges() if hearts > 0 else "—"
	l_hearts.text = "Lives: %d" % hearts
	l_coins.text = "Coins: %d" % coins
	l_dist.text = "%d / %d m" % [int(dist), int(cfg["goal"])]
	bar_fill.size.x = bar.size.x * clampf(dist / cfg["goal"], 0.0, 1.0)


func _overlay(title: String, body: String, buttons: Array) -> void:
	if overlay:
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#101a3c")
	sb.border_color = Color("#4ea1ff")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(340, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := _lbl(v, title, 28, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _lbl(v, body, 16, Color(1, 1, 1, 0.8))
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for bt in buttons:
		var btn := Button.new()
		btn.text = bt[0]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(bt[1])
		v.add_child(btn)
	ui.add_child(overlay)


func _pause(on: bool) -> void:
	if phase == "over":
		return
	paused = on
	get_tree().paused = false
	if on:
		var names := ["Swipe", "Buttons", "Tilt"]
		_overlay("Paused", _pause_hint(), [
			["Resume", func(): _pause(false)],
			["Controls: " + names[_ctl()], func():
				Profile.set_setting("runner_controls", (_ctl() + 1) % 3)
				_apply_controls()
				_pause(true)],
			["Restart", func(): app.start_level(level_id)], ["Back to menu", func(): app.show_launcher()]])
	elif overlay:
		overlay.queue_free()
		overlay = null


# ---------------------------------------------------------------- input

func _action(a: String) -> void:
	if phase != "run" or paused:
		return
	match a:
		"left":
			lane = maxi(lane - 1, 0)
		"right":
			lane = mini(lane + 1, 2)
		"jump":
			if y <= floor_y + 0.02 and slide_t <= 0.0:
				vy = JUMP_V
		"slide":
			slide_t = 0.7
			if y > floor_y + 0.05:
				vy = -22.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_A, KEY_LEFT: _action("left")
			KEY_D, KEY_RIGHT: _action("right")
			KEY_W, KEY_UP, KEY_SPACE: _action("jump")
			KEY_S, KEY_DOWN: _action("slide")
	elif _ctl() == 1:
		return
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			swipe_start = e.position
			swiping = true
		else:
			swiping = false
	elif e is InputEventMouseMotion and swiping:
		var d: Vector2 = e.position - swipe_start
		if d.length() > 38.0:
			swiping = false
			if absf(d.x) > absf(d.y):
				_action("right" if d.x > 0 else "left")
			else:
				_action("slide" if d.y > 0 else "jump")


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	t += delta
	if phase == "run" and not paused:
		_step(delta)
	elif phase == "caught":
		_caught_step(delta)
	_follow(delta)


const HALF_LEN := {"crate": 0.85, "car": 2.1, "bus": 3.75}
const TOPS := {"crate": 1.4, "car": 1.45, "bus": 2.75}


func _floor_at(px: float, old_y: float) -> float:
	var best := 0.0
	var hz := -dist
	for o in obstacles:
		var k: String = o["kind"]
		if not TOPS.has(k):
			continue
		var top: float = TOPS[k]
		if absf(o["z"] - hz) < HALF_LEN[k] + 0.2 and absf(o["node"].position.x - px) < 1.0 and old_y >= top - 0.35:
			best = maxf(best, top)
	return best


func _step(delta: float) -> void:
	run_t += delta
	speed = minf(cfg["v0"] + cfg["acc"] * run_t, cfg["vmax"])
	if invuln > 0.0:
		speed *= 0.8
	dist += speed * delta
	invuln = maxf(invuln - delta, 0.0)
	if _ctl() == 2:
		tilt_cool -= delta
		var tx := Input.get_accelerometer().x
		if tilt_cool <= 0.0 and absf(tx) > 2.6:
			_action("right" if tx < 0 else "left")
			tilt_cool = 0.35
	target_x = (lane - 1) * LANE
	var px := lerpf(hero.position.x, target_x, 1.0 - exp(-14.0 * delta))
	var old_y := y
	vy -= GRAV * delta
	y += vy * delta
	floor_y = _floor_at(px, old_y)
	if y <= floor_y and vy <= 0.0:
		y = floor_y
		vy = 0.0
	slide_t = maxf(slide_t - delta, 0.0)
	hero.position = Vector3(px, y, -dist)
	hero.run_speed = speed
	hero.airborne = y > floor_y + 0.1
	hero.sliding = slide_t > 0.0 and y < floor_y + 0.2
	hero.visible = invuln <= 0.0 or int(t * 14.0) % 2 == 0
	# chaser
	if chase_t > 0.0:
		chase_t -= delta
		chaser_gap = 3.4 + (CHASE_WINDOW - chase_t) * 1.9
		if chase_t <= 0.0 and chaser:
			chaser.queue_free()
			chaser = null
		elif chaser:
			chaser.position = Vector3(lerpf(chaser.position.x, px, 1.0 - exp(-6.0 * delta)), 0.0, -dist + chaser_gap)
			chaser.run_speed = speed
	# world
	while -next_chunk_z < dist + 150.0:
		_make_chunk()
	while chunks.size() > 0 and chunks[0].position.z - 40.0 > -dist + 40.0:
		chunks.pop_front().queue_free()
	var spawn_to: float = minf(dist + 120.0, cfg["goal"] - 30.0)
	while -next_spawn_z < spawn_to:
		var extra := _spawn_row(next_spawn_z)
		var sf := clampf(speed / cfg["v0"], 1.0, 1.8)
		next_spawn_z -= cfg["gap"] * sf + rng.randf_range(0.0, 8.0) + extra
	if finish_node == null and dist > cfg["goal"] - 160.0:
		_build_finish()
	_collide(delta)
	_hud_update()
	if dist >= cfg["goal"] and phase == "run":
		_win()


func _collide(delta: float) -> void:
	var hz := -dist
	for o in obstacles.duplicate():
		var n: Node3D = o["node"]
		if o["vz"] != 0.0:
			o["z"] += o["vz"] * delta
			n.position.z = o["z"]
		var dz: float = o["z"] - hz
		if dz > 9.0:
			n.queue_free()
			obstacles.erase(o)
			continue
		var kind: String = o["kind"]
		var reach: float = HALF_LEN.get(kind, 0.4) + 0.35
		if absf(dz) > reach or invuln > 0.0 or phase != "run":
			continue
		var hit := false
		match kind:
			"crate", "car", "bus":
				hit = absf(n.position.x - hero.position.x) < 1.0 and y < float(TOPS[kind]) - 0.35
			"hurdle":
				hit = y < 0.62
			"beam":
				hit = not (slide_t > 0.0 and y < 0.25)
		if hit:
			AppLog.add("Runner hit: %s at %d m" % [kind, int(dist)])
			_hurt()
	for pk in pickups.duplicate():
		var n2: Node3D = pk["node"]
		var dz2: float = pk["z"] - hz
		if dz2 > 9.0:
			n2.queue_free()
			pickups.erase(pk)
			continue
		n2.rotation.y += delta * 5.0
		if absf(dz2) < 1.0 and absf(n2.position.x - hero.position.x) < 1.1 and absf(n2.position.y - (y + 0.9)) < 1.3:
			coins += 1
			n2.queue_free()
			pickups.erase(pk)


func _spawn_chaser() -> void:
	if chaser:
		return
	chaser = Hero.new()
	chaser.make_chaser()
	add_child(chaser)
	chaser.position = Vector3(hero.position.x, 0.0, -dist + 12.0)


func _hurt() -> void:
	hearts -= 1
	invuln = 1.6
	shake = 0.45
	if chase_t > 0.0 or hearts <= 0:
		_caught()
		return
	chase_t = CHASE_WINDOW
	_spawn_chaser()
	_banner("Ouch! He's right behind you!", "", 1.2)


## The Yetzer Hara catches up, grabs the runner and carries him away.
func _caught() -> void:
	if phase != "run":
		return
	phase = "caught"
	carry_t = 0.0
	if overlay:
		overlay.queue_free()
		overlay = null
	_spawn_chaser()
	hero.visible = true
	hero.airborne = false
	hero.sliding = false
	hero.position.y = floor_y
	AppLog.add("Runner caught at %d m" % int(dist))


func _caught_step(delta: float) -> void:
	carry_t += delta
	if chaser == null:
		return
	if carry_t < 0.55:
		# he sprints up and grabs
		chaser.grabbing = true
		chaser.run_speed = 22.0
		var tz: float = hero.position.z + 1.3
		chaser.position.z = move_toward(chaser.position.z, tz, 22.0 * delta)
		chaser.position.x = lerpf(chaser.position.x, hero.position.x, 1.0 - exp(-12.0 * delta))
		hero.run_speed = 3.0
		hero.caught = carry_t > 0.35
	else:
		# turns and drags him off to the side
		hero.caught = true
		chaser.grabbing = true
		chaser.rotation.y = lerp_angle(chaser.rotation.y, -PI / 2.0, 1.0 - exp(-9.0 * delta))
		chaser.run_speed = 16.0
		chaser.position.x += (4.0 + carry_t * 9.0) * delta
		chaser.position.z -= 1.2 * delta
		hero.position = chaser.position + Vector3(0.0, 1.9, 0.0)
		hero.rotation = Vector3(0.0, chaser.rotation.y, 1.35)
	if carry_t > 2.0 and phase == "caught":
		_lose()


func _follow(delta: float) -> void:
	if phase == "caught":
		var focus: Vector3 = hero.position
		var tgt2 := Vector3(focus.x * 0.5 + 1.0, 3.2, hero.position.z + 7.5) if carry_t < 0.55 else cam.position
		cam.position = cam.position.lerp(tgt2, 1.0 - exp(-5.0 * delta))
		cam.look_at(Vector3(chaser.position.x if chaser else focus.x, 1.4, (chaser.position.z if chaser else focus.z) - 1.0))
		return
	var tgt := Vector3(hero.position.x * 0.6, 3.6 + y * 0.4, hero.position.z + 6.4)
	cam.position = cam.position.lerp(tgt, 1.0 - exp(-8.0 * delta)) if cam.position.length() > 1.0 else tgt
	shake = maxf(shake - delta * 2.0, 0.0)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.15
	cam.position += off
	cam.look_at(Vector3(hero.position.x * 0.5, 1.2 + y * 0.3, hero.position.z - 7.0))


# ---------------------------------------------------------------- end

func _points() -> int:
	return coins * 2 + int(dist / 10.0)


func _commit() -> int:
	if committed:
		return 0
	committed = true
	var pts := _points()
	if pts > 0:
		Profile.add_points(pts)
	return pts


func _lose() -> void:
	if phase == "over":
		return
	phase = "over"
	var pts := _commit()
	finished.emit(false)
	_overlay("Caught!", "You made it %d m and collected %d coins (+%d points)." % [int(dist), coins, pts], [
		["Try again", func(): app.start_level(level_id)], ["Back to menu", func(): app.show_launcher()]])


func _win() -> void:
	if phase == "over":
		return
	phase = "over"
	Profile.mark_completed(level_id)
	var pts := _commit() + 50
	Profile.add_points(50)
	finished.emit(true)
	var nxt: String = app.next_level_after(level_id)
	var btns := []
	if nxt != "":
		btns.append(["Next level", func(): app.start_level(nxt)])
	btns.append(["Play again", func(): app.start_level(level_id)])
	btns.append(["Back to menu", func(): app.show_launcher()])
	_overlay("You made it!", "%d coins collected. You earned %d points." % [coins, pts], btns)
