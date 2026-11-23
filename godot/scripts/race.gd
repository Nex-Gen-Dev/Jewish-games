extends Node3D
## "Shtick Racing": boat and car races against computer racers, with a big steering wheel,
## gas, brake and a real gear shifter (R, N, D or 1-5). Levels race1..race4.

signal finished(win: bool)

const AppLog := preload("res://scripts/applog.gd")
const TrackScript := preload("res://scripts/race_track.gd")
const VehicleScript := preload("res://scripts/race_vehicle.gd")
const ControlsScript := preload("res://scripts/race_controls.gd")

const LEVELS := {
	"race1": {"title": "Kinneret Cup", "boat": true, "laps": 1, "skill": 0.83, "preset": "morning",
		"intro": "Boat race from Tiberias down the Jordan. Rapids, a broken bridge and two dams. Beat the Yetzer Hara to the marina!"},
	"race2": {"title": "Geula Grand Prix", "boat": false, "laps": 3, "skill": 0.87, "preset": "golden",
		"intro": "Three laps around the Geula streets, over the little bridge. Do not let the Yetzer Hara win!"},
	"race3": {"title": "Judean Hills Rally", "boat": false, "laps": 1, "skill": 0.9, "preset": "afternoon",
		"intro": "Up the mountain, across a dam and down again. Hairpins and jumps. First one into town wins."},
	"race4": {"title": "Jordan Canyon Marathon", "boat": true, "laps": 1, "skill": 0.92, "preset": "golden",
		"intro": "The long one: three canyons, three dams, three jumps. Watch your engine and take the boost pads."},
}
const RIVALS := [
	["Yetzer Hara", "#c8201e"], ["Moshe", "#2f6fb5"], ["Yossi", "#e0a63a"],
	["Chaim", "#3a9a5e"], ["Shmuel", "#8a4fb5"], ["Dovid", "#e8e4d8"],
]
const SKILL_OFF := [0.045, 0.02, 0.0, -0.025, -0.05]
const PRESETS := {
	"golden": {"top": "#5b86c8", "hor": "#ffd9a8", "sun": "#ffc88a", "se": 1.25, "elev": -28.0, "az": -62.0, "amb": "#d9c4a8", "ae": 0.78, "fog": "#f1c995", "fd": 0.0011},
	"afternoon": {"top": "#4f86d0", "hor": "#d8e6f2", "sun": "#fff0d2", "se": 1.15, "elev": -52.0, "az": -35.0, "amb": "#dfd6c6", "ae": 0.9, "fog": "#e2dccd", "fd": 0.0009},
	"morning": {"top": "#6aa0e8", "hor": "#ffe2c0", "sun": "#ffe0b0", "se": 1.3, "elev": -22.0, "az": 50.0, "amb": "#d8d0c8", "ae": 0.82, "fog": "#f3e6d2", "fd": 0.001},
}

var level_id := "race1"
var app: Node
var tier := 1
var cfg: Dictionary
var tr
var world: Node3D
var phase := "intro" ## intro, countdown, race, done
var t := 0.0
var race_t := 0.0
var count_t := 0.0
var paused := false
var racers: Array = []
var player
var view_mode := 0
var cam: Camera3D
var cam_yaw := 0.0
var shake := 0.0
var goal := 0.0
var committed := false
var player_auto := false ## test bot: the computer drives the player's racer
var done_t := 0.0
var finish_count := 0
var rank_t := 0.0
var overlay: Control
var sun: DirectionalLight3D
var env: Environment
var fx: Array = []
var fx_i := 0
var fx_acc := {}
var rng := RandomNumberGenerator.new()
var _seen_go := false
# ui
var ui: CanvasLayer
var controls
var l_place: Label
var l_lap: Label
var l_time: Label
var l_banner: Label
var l_toast: Label
var l_best: Label
var mm: Control
var toast_t := 0.0
var last_cd := -1


func _ready() -> void:
	Engine.max_physics_steps_per_frame = 2 ## slow phones: run slower instead of piling up steps
	cfg = LEVELS.get(level_id, LEVELS["race1"])
	rng.seed = 2026
	_environment()
	AppLog.sample("race load: sky and light")
	world = Node3D.new()
	add_child(world)
	tr = TrackScript.new()
	tier = _gfx_tier()
	AppLog.sample("race load: start (graphics tier %d)" % tier)
	var t0 := Time.get_ticks_msec()
	tr.build_level(level_id)
	var t1 := Time.get_ticks_msec()
	tr.build(world, tier)
	AppLog.sample("race load: track built")
	print("race: TIMING level_script=%d ms mesh_build=%d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
	print("race: %s samples=%d length=%.0f m" % [level_id, tr.n, tr.length])
	_labels()
	_camera()
	_racers()
	AppLog.sample("race load: racers placed")
	_fx_pool()
	_build_ui()
	AppLog.sample("race load: ui built")
	_load_samples()
	get_tree().root.size_changed.connect(_camera)
	goal = tr.length * float(cfg["laps"]) if tr.closed else tr.dist[tr.finish_idx]
	_banner(cfg["title"], cfg["intro"], 2.6)
	phase = "intro"
	count_t = 0.0
	_follow(1.0, true)


## 0 light, 1 phone, 2 desktop. A race that ended in a crash switches itself to light for next time.
func _gfx_tier() -> int:
	if OS.get_environment("RACE_TIER") != "":
		return int(OS.get_environment("RACE_TIER")) ## tests only
	var crashed: bool = str(AppLog.previous_crash.get("level", "")).begins_with("race")
	if crashed and not bool(Profile.get_setting("race_light", false)):
		Profile.set_setting("race_light", true)
	if bool(Profile.get_setting("race_light", false)):
		return 0
	return 2 if Profile.quality_high() else 1


func _load_samples() -> void:
	await get_tree().process_frame
	AppLog.sample("race load: frame 1")
	for k in 40:
		await get_tree().process_frame
	AppLog.sample("race load: frame 41")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == "race":
			_pause(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if phase == "done":
			app.show_launcher()
		else:
			_pause(not paused)


# ---------------------------------------------------------------- setup

func _environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var a: Dictionary = PRESETS[cfg["preset"]]
	sm.sky_top_color = Color(a["top"])
	sm.sky_horizon_color = Color(a["hor"])
	sm.ground_horizon_color = Color(a["hor"])
	sm.ground_bottom_color = Color(a["hor"]).darkened(0.45)
	sm.sun_angle_max = 40.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(a["amb"])
	env.ambient_light_energy = a["ae"]
	env.fog_enabled = true
	env.fog_light_color = Color(a["fog"])
	env.fog_density = a["fd"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.86
	env.glow_enabled = Profile.quality_high()
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(a["sun"])
	sun.light_energy = a["se"]
	sun.rotation_degrees = Vector3(a["elev"], a["az"], 0.0)
	sun.shadow_enabled = Profile.quality_high()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)


func _camera() -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.current = true
		cam.far = [260.0, 340.0, 540.0][tier]
		cam.near = 0.1
		add_child(cam)
	var vs := get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT


func _labels() -> void:
	for g in tr.gantries:
		var i: int = g[0]
		var lab := Label3D.new()
		lab.text = "%s  SHTICK RACING" % g[1] if g[1] == "START" else "FINISH"
		lab.font_size = 96 if tier == 2 else 40
		lab.pixel_size = 0.028 if tier == 2 else 0.067
		lab.modulate = Color("#ffd34a")
		lab.outline_size = 24 if tier == 2 else 6
		lab.outline_modulate = Color(0.1, 0.1, 0.12)
		var h := 11.4 if tr.boat else 9.4
		lab.position = tr.pos[i] + Vector3(0, h + 3.2, 0)
		lab.rotation.y = tr.yaw_at(i)
		world.add_child(lab)


func _racers() -> void:
	var is_boat: bool = cfg["boat"]
	var rows := [[0, -1.0], [0, 1.0], [1, -1.0], [1, 1.0], [2, -1.0], [2, 1.0]]
	if tier == 0:
		rows = rows.slice(0, 4) ## light graphics: 3 rivals instead of 5
	var lat_w := 3.4
	if is_boat:
		lat_w = 9.0
	var player_slot := 3
	var ai_k := 0
	for s in rows.size():
		var v = VehicleScript.new()
		var row: int = rows[s][0]
		var side: float = rows[s][1]
		var i: int = tr.start_idx - 4 - row * 3
		var lap0 := 0
		if tr.closed:
			i = tr.n - 5 - row * 3
			lap0 = -1
		if s == player_slot:
			v.setup(is_boat, Color("#ffb400"), "You", true)
			player = v
		else:
			var rv: Array = RIVALS[ai_k]
			v.setup(is_boat, Color(rv[1]), rv[0], false)
			v.skill = float(cfg["skill"]) + SKILL_OFF[ai_k]
			v.seed_off = ai_k * 1.7
			ai_k += 1
		v.place_at(tr, i, side * lat_w, lap0)
		world.add_child(v.node)
		racers.append(v)
	if player.driver:
		player.driver.visible = true


# ---------------------------------------------------------------- effects

func _fx_pool() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for py in 48:
		for px in 48:
			var d := Vector2(px - 23.5, py - 23.5).length() / 24.0
			img.set_pixel(px, py, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 0.8)))
	var puff_tex := ImageTexture.create_from_image(img)
	for k in [28, 50, 90][tier]:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mt.albedo_color = Color(1, 1, 1, 0.0)
		mt.albedo_texture = puff_tex
		mi.material_override = mt
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		fx.append({"n": mi, "m": mt, "life": 0.0, "max": 1.0, "v": Vector3.ZERO, "s0": 1.0, "s1": 2.0, "a": 0.6, "c": Color.WHITE})


func _puff(p: Vector3, v: Vector3, s0: float, s1: float, col: Color, life: float, alpha := 0.6) -> void:
	var f: Dictionary = fx[fx_i]
	fx_i = (fx_i + 1) % fx.size()
	f["life"] = life
	f["max"] = life
	f["v"] = v
	f["s0"] = s0
	f["s1"] = s1
	f["a"] = alpha
	f["c"] = col
	var n: MeshInstance3D = f["n"]
	n.position = p
	n.visible = true


func _fx_update(dt: float) -> void:
	for f in fx:
		if f["life"] <= 0.0:
			continue
		f["life"] -= dt
		var n: MeshInstance3D = f["n"]
		if f["life"] <= 0.0:
			n.visible = false
			continue
		var k: float = 1.0 - float(f["life"]) / float(f["max"])
		n.position += (f["v"] as Vector3) * dt
		var s := lerpf(float(f["s0"]), float(f["s1"]), k)
		n.scale = Vector3(s, s, s)
		var c: Color = f["c"]
		(f["m"] as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, float(f["a"]) * (1.0 - k) * (1.0 - k * 0.3))
	for v in racers:
		var near: bool = v.pos.distance_to(cam.global_position) < 90.0
		if not near:
			continue
		var acc: float = fx_acc.get(v, 0.0) + dt
		var sp := absf(v.fwd_speed())
		var back: Vector3 = -v.forward()
		if v.boat:
			if v.grounded and sp > 4.0 and acc > 0.04:
				acc = 0.0
				var side: Vector3 = v.right()
				for sgn in [-1.0, 1.0]:
					_puff(v.pos + back * 2.4 + side * sgn * 0.5 + Vector3(0, 0.1, 0), back * 3.0 * minf(sp / 12.0, 1.5) + side * sgn * 2.2 + Vector3(0, 1.4, 0), 0.9, 2.6, Color(0.92, 0.97, 1.0), 0.9, 0.7)
				if v.boost_t > 0.0:
					_puff(v.pos + back * 2.8 + Vector3(0, 0.6, 0), back * 6.0, 1.0, 3.0, Color(1.0, 0.7, 0.2), 0.5, 0.8)
		else:
			var slip := absf(v.vel.dot(v.right()))
			if v.grounded and slip > 3.5 and acc > 0.05:
				acc = 0.0
				for sgn in [-1.0, 1.0]:
					_puff(v.pos + back * 1.3 + v.right() * sgn * 0.9 + Vector3(0, 0.2, 0), Vector3(0, 0.8, 0), 0.8, 2.6, Color(0.82, 0.8, 0.76), 0.8, 0.5)
			if v.boost_t > 0.0 and acc > 0.04:
				acc = 0.0
				_puff(v.pos + back * 2.4 + Vector3(0, 0.5, 0), back * 5.0, 0.7, 2.2, Color(1.0, 0.7, 0.2), 0.45, 0.8)
		fx_acc[v] = acc
		if v.landed > 0.0:
			var col := Color(0.92, 0.97, 1.0) if v.boat else Color(0.85, 0.82, 0.76)
			for k in 12:
				var a := TAU * k / 12.0
				_puff(v.pos + Vector3(0, 0.3, 0), Vector3(cos(a) * 5.0, 3.0 + rng.randf() * 3.0, sin(a) * 5.0), 1.0, 3.4, col, 0.9, 0.7)
		if v.impact > 6.0 and not v.boat:
			for k in 4:
				_puff(v.pos + Vector3(0, 0.8, 0), Vector3(rng.randf_range(-4, 4), rng.randf_range(1, 4), rng.randf_range(-4, 4)), 0.25, 0.5, Color(1.0, 0.85, 0.3), 0.4, 1.0)


# ---------------------------------------------------------------- UI

func _lbl(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _mini_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
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


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	controls = ControlsScript.new()
	ui.add_child(controls)
	controls.set_mode(int(Profile.get_setting("race_controls", 0)))
	controls.view_pressed.connect(_cycle_view)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	l_place = _lbl(root, "", 44, Color("#ffd34a"))
	l_place.position = Vector2(18, 6)
	l_lap = _lbl(root, "", 18, Color.WHITE)
	l_lap.position = Vector2(20, 62)
	l_time = _lbl(root, "", 22, Color.WHITE)
	l_time.position = Vector2(20, 88)
	l_best = _lbl(root, "", 15, Color(1, 1, 1, 0.75))
	l_best.position = Vector2(20, 118)
	l_banner = _lbl(root, "", 28, Color.WHITE)
	l_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l_banner.offset_left = -300
	l_banner.offset_right = 300
	l_banner.offset_top = -170
	l_banner.offset_bottom = -40
	l_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_banner.modulate.a = 0.0
	l_toast = _lbl(root, "", 20, Color("#ffe27a"))
	l_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l_toast.offset_left = -260
	l_toast.offset_right = 260
	l_toast.offset_top = -330
	l_toast.offset_bottom = -290
	l_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_toast.modulate.a = 0.0
	var pb := _mini_button(root, "II", func(): _pause(true))
	pb.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pb.offset_left = -76
	pb.offset_right = -22
	pb.offset_top = 14
	pb.offset_bottom = 60
	mm = Control.new()
	mm.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mm.offset_left = -150
	mm.offset_right = -22
	mm.offset_top = 70
	mm.offset_bottom = 198
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.draw.connect(_draw_minimap)
	root.add_child(mm)


func _banner(title: String, sub := "", dur := 2.0) -> void:
	l_banner.text = title + ("\n" + sub if sub != "" else "")
	l_banner.add_theme_font_size_override("font_size", 56 if sub == "" else 26)
	var tw := create_tween()
	tw.tween_property(l_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(dur)
	tw.tween_property(l_banner, "modulate:a", 0.0, 0.35)


func _toast(text: String) -> void:
	l_toast.text = text
	l_toast.modulate.a = 1.0
	toast_t = 2.4


func _draw_minimap() -> void:
	var sz := mm.size
	mm.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.45), true)
	mm.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.3), false, 2.0)
	var ex := Vector2(tr.max_xz.x - tr.min_xz.x, tr.max_xz.y - tr.min_xz.y)
	var sc := minf((sz.x - 16.0) / maxf(ex.x, 1.0), (sz.y - 16.0) / maxf(ex.y, 1.0))
	var off := (sz - ex * sc) * 0.5
	var pts := PackedVector2Array()
	var i := 0
	while i < tr.n:
		pts.append(off + (Vector2(tr.pos[i].x, tr.pos[i].z) - tr.min_xz) * sc)
		i += 3
	if tr.closed and pts.size() > 1:
		pts.append(pts[0])
	if pts.size() > 1:
		mm.draw_polyline(pts, Color(1, 1, 1, 0.75), 3.0, true)
	var sp: Vector2 = off + (Vector2(tr.pos[tr.start_idx].x, tr.pos[tr.start_idx].z) - tr.min_xz) * sc
	mm.draw_circle(sp, 4.0, Color.WHITE)
	var fp: Vector2 = off + (Vector2(tr.pos[tr.finish_idx].x, tr.pos[tr.finish_idx].z) - tr.min_xz) * sc
	if not tr.closed:
		mm.draw_rect(Rect2(fp - Vector2(4, 4), Vector2(8, 8)), Color("#ffd34a"), true)
	for v in racers:
		var p: Vector2 = off + (Vector2(v.pos.x, v.pos.z) - tr.min_xz) * sc
		if v == player:
			continue
		mm.draw_circle(p, 3.2, v.color)
	var pp: Vector2 = off + (Vector2(player.pos.x, player.pos.z) - tr.min_xz) * sc
	mm.draw_circle(pp, 5.5, Color("#ffd34a"))
	mm.draw_arc(pp, 5.5, 0, TAU, 14, Color.BLACK, 1.5)


func _overlay(title: String, body: String, buttons: Array) -> void:
	if overlay:
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#14161b")
	sb.border_color = Color("#ffb400")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(400, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var tt := _lbl(v, title, 28, Color.WHITE)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body != "":
		var bb := _lbl(v, body, 16, Color(1, 1, 1, 0.85))
		bb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for bt in buttons:
		var btn := Button.new()
		btn.text = bt[0]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(bt[1])
		v.add_child(btn)
	ui.add_child(overlay)


func _pause(on: bool) -> void:
	if phase == "done":
		return
	paused = on
	controls.enabled = not on
	if on:
		controls.clear()
		var views := ["Behind", "High behind", "Driver"]
		_overlay("Paused", "", [
			["Resume", func(): _pause(false)],
			["Steering: " + ControlsScript.NAMES[controls.mode], func():
				var m: int = (controls.mode + 1) % 3
				Profile.set_setting("race_controls", m)
				controls.set_mode(m)
				_pause(true)],
			["Gears: " + ("Automatic (R N D)" if controls.auto else "Manual (R N 1-5)"), func():
				controls.toggle_auto()
				_pause(true)],
			["Camera: " + views[view_mode], func():
				_cycle_view()
				_pause(true)],
			["Graphics: " + ("Light" if tier == 0 else "Normal"), func():
				Profile.set_setting("race_light", tier != 0)
				app.start_level(level_id)],
			["Back on track", func():
				player.respawn(tr)
				_pause(false)],
			["Restart race", func(): app.start_level(level_id)],
			["Back to menu", func(): app.show_launcher()]])
	elif overlay:
		overlay.queue_free()
		overlay = null


func _cycle_view() -> void:
	view_mode = (view_mode + 1) % 3
	player.driver.visible = view_mode != 2
	_toast(["Camera: behind", "Camera: high", "Camera: driver's seat"][view_mode])


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	t += delta
	if paused:
		return
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			l_toast.modulate.a = 0.0
	var dt := minf(delta, 1.0 / 30.0)
	match phase:
		"intro":
			count_t += dt
			if count_t > 2.4:
				phase = "countdown"
				count_t = 0.0
				last_cd = -1
		"countdown":
			count_t += dt
			var n := 3 - int(count_t / 0.9)
			if n != last_cd and n >= 1:
				last_cd = n
				_banner(str(n), "", 0.45)
			if count_t > 2.7:
				phase = "race"
				_banner("GO!", "", 0.7)
				_toast("Hold GAS. Steer with the wheel. D = drive, R = reverse.")
	if phase == "race" or phase == "done":
		race_t += dt
	if phase == "race" and race_t > 600.0 and not player.finished:
		player.finished = true
		player.finish_time = race_t
		_player_finished()
	_drive_player(dt)
	_drive_ai(dt)
	for v in racers:
		_step(v, dt)
	_collide()
	_standings(dt)
	_follow(dt, false)
	_fx_update(dt)
	_hud(dt)
	if phase == "done":
		done_t += dt


func _drive_player(dt: float) -> void:
	var live: bool = phase == "race" and not player.finished
	if player_auto and live:
		player.ai_drive(dt, tr, t, 0.0, racers)
		return
	var inp: Dictionary = controls.poll(dt)
	if not live:
		player.inp_gas = 0.0
		player.inp_brake = 0.6 if phase != "race" else 0.5
		player.inp_steer = 0.0
		return
	player.inp_steer = inp["steer"]
	player.inp_gas = inp["gas"]
	player.inp_brake = inp["brake"]
	player.gear_sel = int(inp["gear"])
	player.auto = bool(inp["auto"])


func _drive_ai(dt: float) -> void:
	for v in racers:
		if v == player:
			continue
		if phase != "race" or v.finished:
			v.inp_gas = 0.0
			v.inp_brake = 0.5 if phase != "race" else 0.15
			v.inp_steer = 0.0
			if v.finished:
				v.ai_drive(dt, tr, t, 0.0, racers)
				v.inp_gas = 0.4 if v.fwd_speed() < 14.0 else 0.0
			continue
		var rub := clampf((player.progress - v.progress) / 220.0, -0.06, 0.07)
		v.ai_drive(dt, tr, t, rub, racers)


func _step(v, dt: float) -> void:
	v.step(dt, tr, t)
	if v.respawned and v == player:
		_toast("Back on track!")
	if not v.finished and phase != "intro" and phase != "countdown":
		if v.progress >= goal:
			v.finished = true
			v.finish_time = race_t
			finish_count += 1
			if v == player:
				_player_finished()


func _collide() -> void:
	for a in racers.size():
		for b in range(a + 1, racers.size()):
			var va = racers[a]
			var vb = racers[b]
			var d: Vector3 = vb.pos - va.pos
			d.y = 0.0
			var dist := d.length()
			var min_d := 3.4 if va.boat else 3.0
			if dist < min_d and absf(va.pos.y - vb.pos.y) < 2.0 and dist > 0.01:
				var nrm := d / dist
				var push := (min_d - dist) * 0.5
				va.pos -= nrm * push
				vb.pos += nrm * push
				var rel: float = (va.vel - vb.vel).dot(nrm)
				if rel > 0.0:
					va.vel -= nrm * rel * 0.55
					vb.vel += nrm * rel * 0.55
					if va == player or vb == player:
						shake = maxf(shake, minf(rel * 0.05, 0.5))
						if rel > 4.0 and toast_t <= 0.0:
							_toast("Bump!")


func _standings(dt: float) -> void:
	rank_t -= dt
	if rank_t > 0.0:
		return
	rank_t = 0.15
	var order := racers.duplicate()
	order.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		return a.progress > b.progress)
	for i in order.size():
		order[i].place = i + 1


func _hud(dt: float) -> void:
	l_place.text = "%d / %d" % [player.place, racers.size()]
	var pct := clampf(player.progress / goal, 0.0, 1.0)
	if tr.closed:
		l_lap.text = "LAP %d / %d" % [clampi(player.lap + 1, 1, int(cfg["laps"])), int(cfg["laps"])]
	else:
		l_lap.text = "%d%% of the course" % int(pct * 100.0)
	var rt := race_t
	l_time.text = "%d:%04.1f" % [int(rt) / 60, fmod(rt, 60.0)]
	var ahead := ""
	for v in racers:
		if v.place == player.place - 1:
			ahead = "%s  %dm ahead" % [v.title, int(maxf(v.progress - player.progress, 0.0))]
	l_best.text = ahead
	controls.speed_kmh = absf(player.fwd_speed()) * 3.6
	controls.gear_txt = player.gear_text()
	controls.rpm = player.rpm
	mm.queue_redraw()


# ---------------------------------------------------------------- camera

func _follow(dt: float, snap: bool) -> void:
	var v = player
	var spd := absf(v.fwd_speed())
	var f3: Vector3 = v.forward()
	var want_yaw: float = v.yaw
	if spd > 4.0 and v.grounded and v.fwd_speed() > 0.0:
		want_yaw = lerp_angle(v.yaw, atan2(-v.vel.x, -v.vel.z), 0.3)
	if snap:
		cam_yaw = want_yaw
	else:
		cam_yaw = lerp_angle(cam_yaw, want_yaw, minf(dt * (4.5 if v.grounded else 2.0), 1.0))
	shake = maxf(shake * (1.0 - dt * 5.0), v.impact * 0.04)
	v.impact = maxf(v.impact - dt * 30.0, 0.0)
	var k := clampf(spd / v.top, 0.0, 1.0)
	var fov := 62.0 + k * 14.0 + (8.0 if v.boost_t > 0.0 else 0.0)
	var vs := get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		fov += 14.0
	if view_mode == 2:
		var off: Vector3 = v.parts["cockpit"] if v.parts.has("cockpit") else Vector3(0, 1.4, 0)
		if v.boat:
			off = Vector3(-0.1, 1.55, 0.7)
		var b: Basis = v.node.basis
		cam.global_transform = Transform3D(b, v.node.position + b * off)
		cam.fov = lerpf(cam.fov, fov + 8.0, minf(dt * 4.0, 1.0)) if not snap else fov
		return
	var dist := lerpf(7.2, 10.5, k) + (1.5 if v.boat else 0.0)
	var h := 2.7 + k * 0.7
	if view_mode == 1:
		dist += 4.0
		h += 3.0
	var back := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var base: Vector3 = v.pos + Vector3(0, 1.1, 0)
	var want: Vector3 = base + back * dist + Vector3(0, h, 0)
	if snap:
		cam.position = want
	else:
		var np := cam.position.lerp(want, minf(dt * 9.0, 1.0))
		np.y = lerpf(cam.position.y, want.y, minf(dt * 5.0, 1.0))
		cam.position = np
	if shake > 0.01:
		cam.position += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * 0.3
	cam.look_at(base + f3 * 7.0 + Vector3(0, 0.9, 0))
	cam.fov = fov if snap else lerpf(cam.fov, fov, minf(dt * 4.0, 1.0))


# ---------------------------------------------------------------- end

const PTS := [0, 150, 100, 70, 40, 25, 15]


func _player_finished() -> void:
	_standings(0.0)
	rank_t = 0.0
	var place: int = player.place
	phase = "done"
	done_t = 0.0
	controls.clear()
	controls.enabled = false
	var win := place <= 3
	var pts: int = PTS[clampi(place, 1, 6)] + player.jumps * 5
	if not committed:
		committed = true
		Profile.add_points(pts)
		Profile.stat_add("race_finishes")
		if place == 1:
			Profile.stat_add("race_wins")
		if player.jumps > 0:
			Profile.stat_add("race_jumps", player.jumps)
		if win:
			Profile.mark_completed(level_id)
	finished.emit(win)
	var ords := ["", "1st", "2nd", "3rd", "4th", "5th", "6th"]
	var title := "You won!" if place == 1 else ("%s place" % ords[clampi(place, 1, 6)])
	var body := "Time %s. Jumps: %d. You earned %d points." % [l_time.text, player.jumps, pts]
	if not win:
		body += "\nFinish in the top 3 to unlock the next race."
	get_tree().create_timer(1.6).timeout.connect(func(): _show_results(title, body, win))


func _show_results(title: String, body: String, win: bool) -> void:
	if overlay != null:
		return
	var rows := racers.duplicate()
	rows.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.progress > b.progress)
	controls.visible = false
	var lines := ""
	for i in rows.size():
		var r = rows[i]
		var tm := "%d:%04.1f" % [int(r.finish_time) / 60, fmod(r.finish_time, 60.0)] if r.finished else "racing..."
		lines += "%d.  %s   %s\n" % [i + 1, r.title, tm]
	var btns: Array = []
	var nxt := ""
	if win and app != null:
		nxt = app.next_level_after(level_id)
	if nxt != "":
		btns.append(["Next race", func(): app.start_level(nxt)])
	btns.append(["Race again", func(): app.start_level(level_id)])
	btns.append(["Back to menu", func(): app.show_launcher()])
	_overlay(title, body + "\n\n" + lines, btns)
