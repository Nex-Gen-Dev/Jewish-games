extends Node3D
## Erev Shabbos City: a small open world modeled on Geula and Machane Yehuda (Jerusalem).
## Walk or drive the minivan, run the Shabbos errands, reach shul before candle lighting.
## Controls: joystick = move (camera-relative on foot, steer/gas in the van),
## drag the right side to look around, yellow button = buy / enter / exit.

signal finished(win: bool)

const HALF := 106.0
const ROADS := [-66.0, 0.0, 66.0]
const ZONES := [[-110.0, -75.0], [-57.0, -9.0], [9.0, 57.0], [75.0, 110.0]]
const PR := 0.45
const VR := 1.25
const LEVELS := {
	"city1": {
		"title": "Erev Shabbos in Geula",
		"time": 300.0,
		"intro": "Shabbos is coming! Do the errands and reach shul before candle lighting.",
		"missions": [
			{"place": "bakery", "text": "Pick up challah at the bakery", "verb": "BUY CHALLAH",
				"msg": "Two warm challos. The baker: \"Take a third, your mother-in-law is coming.\""},
			{"place": "fish", "text": "Buy fish in Machane Yehuda", "verb": "BUY FISH",
				"msg": "\"Caught this morning!\" says the fish seller. He says that about every fish."},
			{"place": "flowers", "text": "Get hadassim and flowers", "verb": "BUY FLOWERS",
				"msg": "\"For shalom bayis,\" says the seller, and charges double."},
			{"place": "grocery", "text": "Grab grape juice at the grocery", "verb": "BUY JUICE",
				"msg": "The cashier: \"Did you remember the challah?\" You did!"},
			{"place": "shul", "text": "Hurry to shul before candle lighting!", "verb": "ENTER SHUL", "msg": ""},
		],
	},
}
## stand = where you stand to use it; wall = direction from stand to the shop; dist = distance to the facade.
const PLACES := {
	"bakery": {"stand": Vector3(-33, 0, 7.5), "wall": Vector3(0, 0, 1), "dist": 1.5, "sign": "BAKERY", "sub": "Fresh challah", "col": Color("#e0963a"), "door": true},
	"fish": {"stand": Vector3(29.5, 0, -30), "wall": Vector3(-1, 0, 0), "dist": 2.0, "sign": "FISH", "sub": "Fresh! Fresh!", "col": Color("#3d8ed6"), "door": false},
	"flowers": {"stand": Vector3(36.5, 0, -42), "wall": Vector3(1, 0, 0), "dist": 2.0, "sign": "FLOWERS", "sub": "Hadassim & more", "col": Color("#d6457f"), "door": false},
	"grocery": {"stand": Vector3(33, 0, -73.5), "wall": Vector3(0, 0, -1), "dist": 1.5, "sign": "GROCERY", "sub": "Wine & grape juice", "col": Color("#3aa86a"), "door": true},
	"shul": {"stand": Vector3(-58.5, 0, -33), "wall": Vector3(1, 0, 0), "dist": 1.5, "sign": "SHUL", "sub": "Mincha / Kabbalas Shabbos", "col": Color("#e8c24a"), "door": true},
}
const STREETS := [
	{"pos": Vector3(7.2, 0, 7.2), "text": "MALCHEI YISRAEL ST", "yaw": 0.0},
	{"pos": Vector3(-58.8, 0, 7.2), "text": "SHMUEL HANAVI ST", "yaw": 0.0},
	{"pos": Vector3(73.2, 0, 7.2), "text": "STRAUSS ST", "yaw": 0.0},
	{"pos": Vector3(-7.2, 0, -58.8), "text": "YAFO ROAD", "yaw": 3.14159},
	{"pos": Vector3(-7.2, 0, 7.2), "text": "YIRMIYAHU ST", "yaw": 0.0},
]
const SHOUTS := ["Rak esrim!", "Tapuchim! Tapuchim!", "Dagim tzariyim!", "Challah, challah!", "Sababa prices!", "Hadassim, get 'em here!", "Fresh! Fresh!", "Come, come, taste!"]

var level_id := "city1"
var app: Node
var cfg: Dictionary
var missions: Array = []
var phase := "intro"
var time_total := 300.0
var time_left := 300.0
var mi := 0
var coins := 0
var committed := false
var paused := false
var t := 0.0
var rng := RandomNumberGenerator.new()
var mats := {}
var groups := {}
var unit_box := BoxMesh.new()
var box_arr: Array
var solids: Array[Rect2] = []
var tex_cache := {}

# actors
var pl: Node3D
var pl_person: Dictionary
var pl_vel := Vector3.ZERO
var pl_yaw := 0.0
var in_van := false
var van: Node3D
var van_speed := 0.0
var van_yaw := 0.0
var walkers: Array = []
var chatters: Array = []
var vendors: Array = []
var cars: Array = []
var parked_cars: Array = []
var pickups: Array = []
var markers := {}
var hit_cool := 0.0
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := 0.38
var cam_dist := 5.6
var look_idle := 9.0
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var env_t := 0.0
var warned := {}
var shake := 0.0

# ui
var ui: CanvasLayer
var controls: TouchControls
var l_time: Label
var l_clock: Label
var l_mission: Label
var l_coins: Label
var l_banner: Label
var l_toast: Label
var l_dist: Label
var arrow: Control
var mm: Control
var overlay: Control
var toast_t := 0.0


func _ready() -> void:
	cfg = LEVELS.get(level_id, LEVELS["city1"])
	missions = cfg["missions"]
	time_total = cfg["time"]
	time_left = time_total
	rng.seed = 424242
	_environment()
	_build_world()
	_actors()
	_camera()
	_build_ui()
	_hud_update()
	get_tree().root.size_changed.connect(_camera)
	_banner(cfg["title"], cfg["intro"], 3.0)
	get_tree().create_timer(3.2).timeout.connect(func():
		if phase == "intro":
			phase = "play")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == "play":
			_pause(true)


# ---------------------------------------------------------------- materials / merging

func mat(c: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), emissive]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	mats[key] = m
	return m


func _g(key: String, m: Material) -> SurfaceTool:
	if not groups.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[key] = {"st": st, "mat": m}
	return groups[key]["st"]


## Add a box into the merged static mesh for its colour.
func sbox(c: Color, pos: Vector3, size: Vector3, yaw := 0.0, emissive := 0.0, tilt := Basis.IDENTITY) -> void:
	var st := _g("c%s_%s" % [c.to_html(), emissive], mat(c, emissive))
	var b := Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(size)
	_append(st, box_arr, Transform3D(b, pos))


func _make_box_arr() -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var nn: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = f[2]
		var base := v.size()
		for sgn in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			v.append(nn * 0.5 + u * 0.5 * sgn[0] + w * 0.5 * sgn[1])
			n.append(nn)
		# make winding face outward (counter-clockwise seen from outside)
		var a := v[base]
		var b := v[base + 1]
		var c := v[base + 2]
		if (b - a).cross(c - a).dot(nn) > 0.0:
			ix.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		else:
			ix.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	return _pack_arr(v, n, ix)


func _pack_arr(v: PackedVector3Array, n: PackedVector3Array, ix: PackedInt32Array) -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = ix
	return arr


func _cyl_arr(rt: float, rb: float, h: float, seg: int) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	for i in seg + 1:
		var a := TAU * i / seg
		var cx := cos(a)
		var sz := sin(a)
		var nn := Vector3(cx, (rb - rt) / maxf(h, 0.01), sz).normalized()
		v.append(Vector3(cx * rb, -h / 2.0, sz * rb))
		n.append(nn)
		v.append(Vector3(cx * rt, h / 2.0, sz * rt))
		n.append(nn)
	for i in seg:
		var b := i * 2
		ix.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	# top cap
	var tc := v.size()
	v.append(Vector3(0, h / 2.0, 0))
	n.append(Vector3.UP)
	for i in seg + 1:
		var a := TAU * i / seg
		v.append(Vector3(cos(a) * rt, h / 2.0, sin(a) * rt))
		n.append(Vector3.UP)
	for i in seg:
		ix.append_array(PackedInt32Array([tc, tc + 2 + i, tc + 1 + i]))
	return _pack_arr(v, n, ix)


func _sph_arr(r: float, seg: int, rings: int) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	for j in rings + 1:
		var phi := PI * j / rings
		for i in seg + 1:
			var th := TAU * i / seg
			var nn := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			v.append(nn * r)
			n.append(nn)
	for j in rings:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			ix.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	return _pack_arr(v, n, ix)


func scyl(c: Color, pos: Vector3, rt: float, rb: float, h: float, seg := 8, emissive := 0.0) -> void:
	var st := _g("c%s_%s" % [c.to_html(), emissive], mat(c, emissive))
	_append(st, _cyl_arr(rt, rb, h, seg), Transform3D(Basis.IDENTITY, pos))


func ssph(c: Color, pos: Vector3, r: float, seg := 8, rings := 5, emissive := 0.0) -> void:
	var st := _g("c%s_%s" % [c.to_html(), emissive], mat(c, emissive))
	_append(st, _sph_arr(r, seg, rings), Transform3D(Basis.IDENTITY, pos))


func _append(st: SurfaceTool, arr: Array, xf: Transform3D) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	var tv := PackedVector3Array()
	var tn := PackedVector3Array()
	tv.resize(v.size())
	tn.resize(v.size())
	for i in v.size():
		tv[i] = xf * v[i]
		tn[i] = (nb * nrm[i]).normalized()
	for i in idx:
		st.set_normal(tn[i])
		st.add_vertex(tv[i])


func _commit_groups() -> void:
	for k in groups:
		var g: Dictionary = groups[k]
		var st: SurfaceTool = g["st"]
		var mesh := st.commit()
		var mi_node := MeshInstance3D.new()
		mi_node.mesh = mesh
		mi_node.material_override = g["mat"]
		mi_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi_node)
	groups.clear()


func solid(x0: float, z0: float, x1: float, z1: float) -> void:
	solids.append(Rect2(x0, z0, x1 - x0, z1 - z0))


# ---------------------------------------------------------------- environment

func _environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.ground_bottom_color = Color("#6d6355")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e6dccb")
	env.fog_enabled = true
	env.fog_density = 0.0045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	add_child(sun)
	_update_env()


func _update_env() -> void:
	var p := clampf(1.0 - time_left / time_total, 0.0, 1.0)
	sky_mat.sky_top_color = Color("#4a90e2").lerp(Color("#243a86"), p)
	sky_mat.sky_horizon_color = Color("#d6e8ff").lerp(Color("#ff9a52"), p)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.fog_light_color = Color("#e4dccb").lerp(Color("#ffa56a"), p)
	env.ambient_light_energy = lerpf(0.85, 0.7, p)
	env.ambient_light_color = Color("#e8ddc8").lerp(Color("#d9a98a"), p)
	sun.light_color = Color("#fff1d4").lerp(Color("#ff8a3c"), p)
	sun.light_energy = lerpf(1.25, 0.9, p)
	sun.rotation_degrees = Vector3(lerpf(-48.0, -9.0, p), lerpf(-35.0, -80.0, p), 0.0)


func _camera() -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.current = true
		add_child(cam)
	var vs := get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 78.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 62.0
	cam.far = 320.0
	cam.near = 0.15


# ---------------------------------------------------------------- world

func _facade_tex(style: int) -> ImageTexture:
	if tex_cache.has(style):
		return tex_cache[style]
	var W := 128
	var img := Image.create(W, W, false, Image.FORMAT_RGB8)
	var bases := [Color("#dccba4"), Color("#dbbca2"), Color("#dcd2bd")]
	var shuts := [Color("#4d7b4c"), Color("#7b5b3b"), Color("#5a6f88")]
	var base: Color = bases[style]
	var shut: Color = shuts[style]
	var r := RandomNumberGenerator.new()
	r.seed = 77 + style
	for y in W:
		for x in W:
			var n := r.randf_range(-0.04, 0.04)
			var c := Color(base.r + n, base.g + n, base.b + n)
			if y % 11 == 0:
				c = c.darkened(0.12)
			if (x + (y / 11) * 19) % 32 == 0:
				c = c.darkened(0.09)
			img.set_pixel(x, y, c)
	for y in range(W - 5, W):
		for x in W:
			img.set_pixel(x, y, base.darkened(0.22))
	_rect(img, 33, 24, 62, 74, base.lightened(0.25))
	_rect(img, 37, 28, 54, 66, Color("#243247"))
	for y in range(28, 94):
		for x in range(37, 91):
			var k := float(y - 28) / 66.0
			img.set_pixel(x, y, Color("#2a3b55").lerp(Color("#101a2a"), k))
	for i in 14:
		_rect(img, 37 + i, 28 + i, 3, 3, Color("#5a7190"))
	_rect(img, 62, 28, 4, 66, base.lightened(0.25))
	_rect(img, 37, 58, 54, 3, base.lightened(0.25))
	_rect(img, 21, 24, 11, 74, shut)
	_rect(img, 96, 24, 11, 74, shut)
	for i in range(0, 74, 6):
		_rect(img, 21, 24 + i, 11, 1, shut.darkened(0.3))
		_rect(img, 96, 24 + i, 11, 1, shut.darkened(0.3))
	_rect(img, 31, 98, 66, 6, base.lightened(0.3))
	if style == 2:
		_rect(img, 14, 108, 100, 3, Color("#3a3a40"))
		for i in range(14, 114, 6):
			_rect(img, i, 108, 1, 14, Color("#3a3a40"))
		_rect(img, 14, 121, 100, 2, Color("#3a3a40"))
	img.generate_mipmaps()
	var tx := ImageTexture.create_from_image(img)
	tex_cache[style] = tx
	return tx


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


func _facade_mat(style: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _facade_tex(style)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.3125, 0.25)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	return m


func _build_world() -> void:
	unit_box.size = Vector3.ONE
	box_arr = _make_box_arr()
	_ground()
	_roads()
	for ix in 4:
		for iz in 4:
			if ix == 2 and iz == 1:
				continue
			var zx: Array = ZONES[ix]
			var zz: Array = ZONES[iz]
			_zone_block(zx[0], zx[1], zz[0], zz[1])
	_market()
	_places()
	_street_props()
	_hills()
	_commit_groups()
	solid(-HALF - 20.0, -HALF - 20.0, -HALF - 18.0, HALF + 20.0)
	solid(HALF + 18.0, -HALF - 20.0, HALF + 20.0, HALF + 20.0)
	solid(-HALF - 20.0, -HALF - 20.0, HALF + 20.0, -HALF - 18.0)
	solid(-HALF - 20.0, HALF + 18.0, HALF + 20.0, HALF + 20.0)


func _ground() -> void:
	sbox(Color("#c9bda3"), Vector3(0, -0.2, 0), Vector3(520, 0.4, 520))
	sbox(Color("#bfb398"), Vector3(0, -0.05, 0), Vector3(2 * HALF + 12, 0.1, 2 * HALF + 12))


func _roads() -> void:
	var asphalt := Color("#4a4a50")
	for r in ROADS:
		sbox(asphalt, Vector3(r, 0.02, 0), Vector3(12, 0.06, 2 * HALF + 12))
		sbox(asphalt, Vector3(0, 0.02, r), Vector3(2 * HALF + 12, 0.06, 12))
	var white := Color("#e8e6dc")
	for r in ROADS:
		var s := -HALF
		while s < HALF:
			var skip := false
			for o in ROADS:
				if absf(s - o) < 10.5:
					skip = true
			if not skip:
				sbox(white, Vector3(r, 0.06, s), Vector3(0.22, 0.02, 3.0))
				sbox(white, Vector3(s, 0.06, r), Vector3(3.0, 0.02, 0.22))
			s += 7.0
	for rx in ROADS:
		for rz in ROADS:
			for k in 6:
				var o := -2.5 + k
				sbox(white, Vector3(rx + o, 0.06, rz - 7.4), Vector3(0.6, 0.02, 2.4))
				sbox(white, Vector3(rx + o, 0.06, rz + 7.4), Vector3(0.6, 0.02, 2.4))
				sbox(white, Vector3(rx - 7.4, 0.06, rz + o), Vector3(2.4, 0.02, 0.6))
				sbox(white, Vector3(rx + 7.4, 0.06, rz + o), Vector3(2.4, 0.02, 0.6))


func _zone_block(x0: float, x1: float, z0: float, z1: float) -> void:
	var d := 13.0
	var w := x1 - x0
	var dz := z1 - z0
	var nx := maxi(1, roundi(w / 16.0))
	var seg := w / nx
	for i in nx:
		_lot(x0 + i * seg, x0 + (i + 1) * seg, z0, z0 + d)
		_lot(x0 + i * seg, x0 + (i + 1) * seg, z1 - d, z1)
	var side0 := z0 + d
	var side1 := z1 - d
	if side1 - side0 > 1.0:
		_lot(x0, x0 + d, side0, side1)
		_lot(x1 - d, x1, side0, side1)
		_lot(x0 + d, x1 - d, side0, side1, 12.8)


func _lot(x0: float, x1: float, z0: float, z1: float, fixed_h := 0.0) -> void:
	var gap := 0.35
	var a := x0 + gap
	var b := x1 - gap
	var c := z0 + gap
	var e := z1 - gap
	var h := fixed_h if fixed_h > 0.0 else 3.2 * (3 + rng.randi() % 5)
	var style := rng.randi() % 3
	var is_shul := x0 < -56.0 and x1 > -45.0 and x1 < -43.0 and z0 <= -33.0 and z1 >= -33.0
	if is_shul:
		h = 16.0
		style = 0
	var key := "f%d" % style
	var st := _g(key, _facade_mat(style))
	_append(st, box_arr, Transform3D(Basis.from_scale(Vector3(b - a, h, e - c)), Vector3((a + b) / 2.0, h / 2.0, (c + e) / 2.0)))
	sbox(Color("#8c8478"), Vector3((a + b) / 2.0, h + 0.2, (c + e) / 2.0), Vector3(b - a + 0.5, 0.4, e - c + 0.5))
	solid(a, c, b, e)
	# roof things
	var cx := (a + b) / 2.0
	var cz := (c + e) / 2.0
	var nprops := 1 + rng.randi() % 3
	for k in nprops:
		var px := cx + rng.randf_range(-(b - a) / 3.0, (b - a) / 3.0)
		var pz := cz + rng.randf_range(-(e - c) / 3.0, (e - c) / 3.0)
		match rng.randi() % 3:
			0:
				scyl(Color("#c8c8c8"), Vector3(px, h + 1.05, pz), 0.7, 0.7, 1.3, 8)
				sbox(Color("#6a6a6a"), Vector3(px, h + 0.6, pz), Vector3(1.0, 0.4, 1.0))
			1:
				var tb := Basis(Vector3.RIGHT, -0.55)
				sbox(Color("#1d3a63"), Vector3(px, h + 0.75, pz), Vector3(1.6, 0.08, 1.1), 0.0, 0.0, tb)
				sbox(Color("#b9b9b9"), Vector3(px, h + 0.9, pz + 0.7), Vector3(1.6, 0.9, 0.08))
			_:
				sbox(Color("#777777"), Vector3(px, h + 1.8, pz), Vector3(0.08, 3.0, 0.08))
				sbox(Color("#777777"), Vector3(px, h + 2.6, pz), Vector3(1.0, 0.06, 0.06))
	# awnings on lots facing a road
	_awnings(a, c, b, e)
	if is_shul:
		ssph(Color("#d9b84a"), Vector3(cx, h + 0.4, cz), 3.4, 14, 7, 0.25)
		sbox(Color("#d9b84a"), Vector3(cx, h + 4.6, cz), Vector3(0.12, 2.0, 0.12), 0.0, 0.25)


func _awnings(a: float, c: float, b: float, e: float) -> void:
	## Striped awnings on the sides that face a road (edges at +-9 from a road centre).
	var cols := [Color("#c9473b"), Color("#2f6fb5"), Color("#e0a63a"), Color("#3a9a5e"), Color("#f2efe6")]
	var col: Color = cols[rng.randi() % cols.size()]
	var tl := Basis(Vector3.RIGHT, 0.2)
	var edges := []
	for r in ROADS:
		if absf(c - (r + 9.0)) < 0.5:
			edges.append("N")
		if absf(e - (r - 9.0)) < 0.5:
			edges.append("S")
		if absf(a - (r + 9.0)) < 0.5:
			edges.append("W")
		if absf(b - (r - 9.0)) < 0.5:
			edges.append("E")
	for ed in edges:
		var len_: float
		match ed:
			"N":
				len_ = b - a
				for k in int(len_ / 5.0):
					var x := a + 2.5 + k * 5.0
					sbox(col, Vector3(x, 3.1, c - 0.5), Vector3(3.6, 0.1, 1.3), 0.0, 0.0, Basis(Vector3.RIGHT, 0.18))
					sbox(Color("#2b2b30"), Vector3(x, 1.4, c - 0.04), Vector3(3.0, 2.6, 0.1))
			"S":
				len_ = b - a
				for k in int(len_ / 5.0):
					var x := a + 2.5 + k * 5.0
					sbox(col, Vector3(x, 3.1, e + 0.5), Vector3(3.6, 0.1, 1.3), 0.0, 0.0, Basis(Vector3.RIGHT, -0.18))
					sbox(Color("#2b2b30"), Vector3(x, 1.4, e + 0.04), Vector3(3.0, 2.6, 0.1))
			"W":
				len_ = e - c
				for k in int(len_ / 5.0):
					var z := c + 2.5 + k * 5.0
					sbox(col, Vector3(a - 0.5, 3.1, z), Vector3(1.3, 0.1, 3.6), 0.0, 0.0, Basis(Vector3.BACK, -0.18))
					sbox(Color("#2b2b30"), Vector3(a - 0.04, 1.4, z), Vector3(0.1, 2.6, 3.0))
			"E":
				len_ = e - c
				for k in int(len_ / 5.0):
					var z := c + 2.5 + k * 5.0
					sbox(col, Vector3(b + 0.5, 3.1, z), Vector3(1.3, 0.1, 3.6), 0.0, 0.0, Basis(Vector3.BACK, 0.18))
					sbox(Color("#2b2b30"), Vector3(b + 0.04, 1.4, z), Vector3(0.1, 2.6, 3.0))


func _market() -> void:
	# paved floor + side buildings (west x 9..22, east x 44..57), alley in the middle
	sbox(Color("#cdbf9f"), Vector3(33, 0.06, -33), Vector3(48, 0.04, 48))
	for i in 3:
		var za := -57.0 + i * 16.0
		_lot(9.0, 22.0, za, za + 16.0)
		_lot(44.0, 57.0, za, za + 16.0)
	var cols := [Color("#c9473b"), Color("#2f6fb5"), Color("#e0a63a"), Color("#3a9a5e"), Color("#e8e4d8"), Color("#8a4fb0")]
	var fruit := [Color("#d9382c"), Color("#f08a24"), Color("#e8d23a"), Color("#4aa84a"), Color("#8a3a8a")]
	for side in 2:
		var cx := 25.75 if side == 0 else 40.25
		var front := 27.5 if side == 0 else 38.5
		var dirn := 1.0 if side == 0 else -1.0
		for k in 8:
			var z := -54.0 + k * 6.0
			var col: Color = cols[(k + side * 3) % cols.size()]
			if (side == 0 and k == 4):
				col = PLACES["fish"]["col"]
			if (side == 1 and k == 2):
				col = PLACES["flowers"]["col"]
			sbox(Color("#7a5a3a"), Vector3(cx, 0.45, z), Vector3(3.5, 0.9, 4.2))
			sbox(Color("#5a4630"), Vector3(cx - dirn * 1.2, 1.2, z), Vector3(1.0, 2.4, 4.2))
			sbox(col, Vector3(front - dirn * 0.1 - dirn * 0.3, 3.3, z), Vector3(2.6, 0.1, 4.4), 0.0, 0.0, Basis(Vector3.BACK, dirn * -0.22))
			for p in 2:
				sbox(Color("#4a3a2a"), Vector3(front + dirn * 0.1, 1.6, z - 2.0 + p * 4.0), Vector3(0.12, 3.2, 0.12))
			for j in 8:
				var fc: Color = fruit[(j + k + side) % fruit.size()]
				sbox(fc, Vector3(front - dirn * 0.5, 1.0, z - 1.7 + j * 0.48), Vector3(0.4, 0.22, 0.4))
				sbox(Color("#a98a5a"), Vector3(front - dirn * 0.5, 0.95, z - 1.7 + j * 0.48), Vector3(0.52, 0.1, 0.52))
			solid(cx - 1.75, z - 2.1, cx + 1.75, z + 2.1)
	# tarps over the alley
	var tarps := [Color("#3a78c8"), Color("#e8e4d8"), Color("#3aa86a"), Color("#e0902a"), Color("#c9473b")]
	for k in 9:
		var z := -55.0 + k * 5.6
		var tc: Color = tarps[k % tarps.size()]
		sbox(tc, Vector3(33.0 + (k % 2) * 0.3, 5.3 + (k % 3) * 0.15, z), Vector3(13.0, 0.08, 5.4), 0.0, 0.0, Basis(Vector3.BACK, (k % 3 - 1) * 0.04))
	for k in 5:
		var z := -55.0 + k * 11.0
		for sx in [-6.2, 6.2]:
			sbox(Color("#4a4a52"), Vector3(33.0 + sx, 2.7, z), Vector3(0.14, 5.4, 0.14))
	# entrance gantries
	for sd in 2:
		var gz := -9.4 if sd == 0 else -56.6
		sbox(Color("#2c5a9a"), Vector3(33, 7.6, gz), Vector3(15, 2.2, 0.3))
		for sx in [-7.0, 7.0]:
			sbox(Color("#4a4a52"), Vector3(33.0 + sx, 3.5, gz), Vector3(0.3, 7.0, 0.3))
		var lb := Label3D.new()
		lb.text = "MACHANE YEHUDA"
		lb.font_size = 96
		lb.pixel_size = 0.012
		lb.outline_size = 10
		lb.modulate = Color("#ffffff")
		lb.position = Vector3(33, 7.6, gz + (0.2 if sd == 0 else -0.2))
		lb.rotation.y = 0.0 if sd == 0 else PI
		add_child(lb)


func _places() -> void:
	for key in PLACES:
		var p: Dictionary = PLACES[key]
		var stand: Vector3 = p["stand"]
		var wall: Vector3 = p["wall"]
		var n := -wall
		var fac: Vector3 = stand + wall * float(p["dist"])
		var col: Color = p["col"]
		var yaw := atan2(n.x, n.z)
		if p["door"]:
			var sz := Vector3(2.8, 2.7, 0.22) if absf(wall.z) > 0.5 else Vector3(0.22, 2.7, 2.8)
			sbox(col.darkened(0.15), fac + n * 0.12 + Vector3(0, 1.35, 0), sz, 0.0, 0.15)
			var tl := Basis(Vector3.RIGHT, 0.18 * n.z) if absf(wall.z) > 0.5 else Basis(Vector3.BACK, -0.18 * n.x)
			var asz := Vector3(4.6, 0.12, 1.6) if absf(wall.z) > 0.5 else Vector3(1.6, 0.12, 4.6)
			sbox(col, fac + n * 0.8 + Vector3(0, 3.1, 0), asz, 0.0, 0.0, tl)
		var sign_h := 4.4 if p["door"] else 3.7
		var lb := Label3D.new()
		lb.text = p["sign"]
		lb.font_size = 72
		lb.pixel_size = 0.012
		lb.outline_size = 12
		lb.modulate = Color("#ffffff")
		lb.outline_modulate = col.darkened(0.5)
		lb.position = fac + n * (0.2 if p["door"] else 0.35) + Vector3(0, sign_h, 0)
		lb.rotation.y = yaw
		add_child(lb)
		var sb := Label3D.new()
		sb.text = p["sub"]
		sb.font_size = 40
		sb.pixel_size = 0.01
		sb.outline_size = 8
		sb.position = lb.position + Vector3(0, -0.85, 0) + n * 0.01
		sb.rotation.y = yaw
		add_child(sb)
		# glowing marker
		var mk := Node3D.new()
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 7.0
		cm.radial_segments = 16
		cm.rings = 1
		cyl.mesh = cm
		var mm_ := StandardMaterial3D.new()
		mm_.albedo_color = Color(1.0, 0.85, 0.2, 0.2)
		mm_.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm_.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm_.cull_mode = BaseMaterial3D.CULL_DISABLED
		cyl.material_override = mm_
		cyl.position.y = 3.5
		mk.add_child(cyl)
		var cone := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.0
		cn.bottom_radius = 0.7
		cn.height = 1.2
		cn.radial_segments = 8
		cone.mesh = cn
		cone.material_override = mat(Color("#ffd23a"), 1.2)
		cone.rotation.x = PI
		cone.position.y = 8.0
		cone.name = "cone"
		mk.add_child(cone)
		mk.position = stand
		mk.visible = false
		add_child(mk)
		markers[key] = mk


func _street_props() -> void:
	var lamp := Color("#4b4f58")
	var step := 36.0
	for r in ROADS:
		for side in [-1.0, 1.0]:
			var s := -96.0
			while s <= 96.0:
				var near_x := false
				for o in ROADS:
					if absf(s - o) < 11.0:
						near_x = true
				if not near_x:
					var o: float = side * 6.6
					for ax in 2:
						var pos := Vector3(r + o, 0, s) if ax == 0 else Vector3(s, 0, r + o)
						if _in_market(pos):
							continue
						sbox(lamp, pos + Vector3(0, 2.6, 0), Vector3(0.14, 5.2, 0.14))
						sbox(lamp, pos + Vector3(-side * 0.5 * (1 - ax), 5.2, -side * 0.5 * ax), Vector3(0.9 * (1 - ax) + 0.1 * ax, 0.1, 0.9 * ax + 0.1 * (1 - ax)))
						sbox(Color("#fff2c0"), pos + Vector3(-side * 0.9 * (1 - ax), 5.1, -side * 0.9 * ax), Vector3(0.3, 0.12, 0.3), 0.0, 0.6)
				s += step
	# trees
	for r in ROADS:
		for side in [-1.0, 1.0]:
			var s := -88.0
			while s <= 88.0:
				var near_x := false
				for o in ROADS:
					if absf(s - o) < 12.0:
						near_x = true
				if not near_x:
					for ax in 2:
						var pos := Vector3(r + side * 6.9, 0, s + 18.0) if ax == 0 else Vector3(s + 18.0, 0, r + side * 6.9)
						if _in_market(pos) or absf(pos.x) > HALF or absf(pos.z) > HALF or _near_place(pos, 9.0):
							continue
						scyl(Color("#6b4a2e"), pos + Vector3(0, 1.7, 0), 0.12, 0.18, 3.4, 6)
						var gcol := Color("#4d7a3a") if (int(pos.x + pos.z) % 2 == 0) else Color("#5f8a3a")
						ssph(gcol, pos + Vector3(0, 4.4, 0), 1.35, 8, 4)
						solid(pos.x - 0.25, pos.z - 0.25, pos.x + 0.25, pos.z + 0.25)
				s += 36.0
	# street-name signs
	for sn in STREETS:
		var pos: Vector3 = sn["pos"]
		sbox(Color("#4b4f58"), pos + Vector3(0, 1.4, 0), Vector3(0.1, 2.8, 0.1))
		sbox(Color("#1f4f9a"), pos + Vector3(0, 2.7, 0), Vector3(2.6, 0.42, 0.06), float(sn["yaw"]))
		var lb := Label3D.new()
		lb.text = sn["text"]
		lb.font_size = 32
		lb.pixel_size = 0.0095
		lb.outline_size = 4
		lb.position = pos + Vector3(0, 2.7, 0.04 if float(sn["yaw"]) == 0.0 else -0.04)
		lb.rotation.y = float(sn["yaw"])
		add_child(lb)
	# parked cars
	var pcols := [Color("#d8d8d8"), Color("#2a3a5a"), Color("#8a2a2a"), Color("#222226"), Color("#c8c0a8"), Color("#3a6a4a")]
	var count := 0
	for r in ROADS:
		for side in [-1.0, 1.0]:
			var s := -92.0
			while s <= 92.0:
				var near_x := false
				for o in ROADS:
					if absf(s - o) < 14.0:
						near_x = true
				var vx: float = r + side * 4.6
				if not near_x and rng.randf() < 0.42 and not (r == 0.0 and absf(vx - 4.6) < 0.1 and absf(s - 44.0) < 8.0):
					if not _in_market(Vector3(vx, 0, s)) and absf(s) < HALF - 4.0:
						_parked_car(Vector3(vx, 0, s), 0.0, pcols[count % pcols.size()])
						count += 1
				if not near_x and rng.randf() < 0.42:
					var pz: float = r + side * 4.6
					if not _in_market(Vector3(s, 0, pz)) and absf(s) < HALF - 4.0:
						_parked_car(Vector3(s, 0, pz), PI / 2.0, pcols[(count + 2) % pcols.size()])
						count += 1
				s += 11.0


func _near_place(p: Vector3, r: float) -> bool:
	for key in PLACES:
		var st: Vector3 = PLACES[key]["stand"]
		if Vector2(st.x - p.x, st.z - p.z).length() < r:
			return true
	return false


func _in_market(p: Vector3) -> bool:
	return p.x > 8.0 and p.x < 58.0 and p.z > -58.0 and p.z < -8.0


func _parked_car(pos: Vector3, yaw: float, col: Color) -> void:
	sbox(col, pos + Vector3(0, 0.62, 0), Vector3(1.8, 0.7, 4.0), yaw)
	var off := Vector3(0, 1.2, -0.2)
	off = Basis(Vector3.UP, yaw) * off
	sbox(Color("#1b2430"), pos + off, Vector3(1.6, 0.55, 2.0), yaw)
	sbox(Color("#111111"), pos + Vector3(0, 0.3, 0), Vector3(1.86, 0.4, 3.2), yaw)
	var half := Vector2(1.0, 2.1) if absf(yaw) < 0.1 else Vector2(2.1, 1.0)
	solid(pos.x - half.x, pos.z - half.y, pos.x + half.x, pos.z + half.y)


func _hills() -> void:
	for i in 28:
		var a := TAU * i / 28.0
		var rad := 215.0 + rng.randf_range(-10.0, 25.0)
		var w := rng.randf_range(38.0, 70.0)
		var h := rng.randf_range(14.0, 42.0)
		sbox(Color("#cdbf9b").lerp(Color("#a89a78"), rng.randf()), Vector3(cos(a) * rad, h / 2.0, sin(a) * rad), Vector3(w, h, w * 0.8), a)


# ---------------------------------------------------------------- people, cars

func _pm(c: Color) -> StandardMaterial3D:
	return mat(c)


func _mi(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _pm(c)
	n.position = pos
	n.scale = scl
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


var _bm := {}


func _boxm(size: Vector3) -> BoxMesh:
	var k := str(size)
	if not _bm.has(k):
		var b := BoxMesh.new()
		b.size = size
		_bm[k] = b
	return _bm[k]


var _head_m: SphereMesh
var _cyl_m: CylinderMesh


func _make_person(kind: String, r: RandomNumberGenerator) -> Dictionary:
	if _head_m == null:
		_head_m = SphereMesh.new()
		_head_m.radius = 0.115
		_head_m.height = 0.25
		_head_m.radial_segments = 10
		_head_m.rings = 6
		_cyl_m = CylinderMesh.new()
		_cyl_m.top_radius = 0.5
		_cyl_m.bottom_radius = 0.5
		_cyl_m.height = 1.0
		_cyl_m.radial_segments = 10
		_cyl_m.rings = 1
	var root := Node3D.new()
	var skins := [Color("#f0c9a6"), Color("#e2b08a"), Color("#c98d66"), Color("#9a6642")]
	var skin: Color = skins[r.randi() % skins.size()]
	var black := Color("#16161b")
	var pants := Color("#1d1d26")
	var shirt := Color("#f3f3f1")
	var top := shirt
	var scale_ := 1.0
	var woman := kind == "woman" or kind == "girl"
	match kind:
		"kid":
			scale_ = 0.62
			top = [Color("#e8e8e8"), Color("#5a9ad6"), Color("#d6a23a")][r.randi() % 3]
		"girl":
			scale_ = 0.62
		"tourist":
			top = [Color("#d64a4a"), Color("#4ab0d6"), Color("#e8d84a")][r.randi() % 3]
			pants = Color("#c8b890")
		"man2":
			top = [Color("#7aa0d6"), Color("#e8e8e8"), Color("#9ac08a"), Color("#d6a78a")][r.randi() % 4]
			pants = [Color("#2a3550"), Color("#3a3a3a")][r.randi() % 2]
		"vendor":
			top = [Color("#e8d6a0"), Color("#b0d0e0"), Color("#e0b0b0")][r.randi() % 3]
			pants = Color("#2a2a30")
		"player":
			top = Color("#f6f6f6")
			pants = Color("#243456")
		"woman":
			top = [Color("#c9a0b8"), Color("#6a8ab0"), Color("#a8b890"), Color("#d8c0a0"), Color("#8a6a9a")][r.randi() % 5]
	var parts := {}
	# legs
	var legs := []
	for sx in [-0.1, 0.1]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.9, 0)
		root.add_child(hip)
		var lc := pants
		var lh := 0.9
		if kind == "tourist":
			_mi(hip, _boxm(Vector3(0.17, 0.4, 0.2)), skin, Vector3(0, -0.7, 0))
			_mi(hip, _boxm(Vector3(0.18, 0.5, 0.21)), lc, Vector3(0, -0.25, 0))
		else:
			if woman:
				lc = skin
			_mi(hip, _boxm(Vector3(0.17, lh, 0.2)), lc, Vector3(0, -0.45, 0))
		_mi(hip, _boxm(Vector3(0.18, 0.08, 0.3)), Color("#111111"), Vector3(0, -0.87, -0.04))
		legs.append(hip)
	# body
	if kind == "man":
		_mi(root, _boxm(Vector3(0.5, 1.0, 0.3)), black, Vector3(0, 1.0, 0))
		_mi(root, _boxm(Vector3(0.14, 0.42, 0.02)), shirt, Vector3(0, 1.28, -0.16))
	elif woman:
		var skirt := _mi(root, _cyl_m, top.darkened(0.25), Vector3(0, 0.62, 0), Vector3(0.62, 0.85, 0.5))
		_mi(root, _boxm(Vector3(0.4, 0.55, 0.22)), top, Vector3(0, 1.2, 0))
	else:
		_mi(root, _boxm(Vector3(0.44, 0.62, 0.25)), top, Vector3(0, 1.17, 0))
		if kind == "man2" or kind == "player":
			_mi(root, _boxm(Vector3(0.05, 0.14, 0.02)), Color("#f2f2f2"), Vector3(-0.17, 0.84, -0.14))
	# arms
	var arms := []
	for sx in [-0.3, 0.3]:
		var sh := Node3D.new()
		sh.position = Vector3(sx, 1.45, 0)
		root.add_child(sh)
		var ac := black if kind == "man" else top
		if woman:
			ac = top
		_mi(sh, _boxm(Vector3(0.12, 0.6, 0.14)), ac, Vector3(0, -0.3, 0))
		_mi(sh, _boxm(Vector3(0.1, 0.1, 0.12)), skin, Vector3(0, -0.64, 0))
		arms.append(sh)
	# head
	_mi(root, _head_m, skin, Vector3(0, 1.64, 0), Vector3(1.0, 1.1, 1.0))
	if kind == "man":
		_mi(root, _boxm(Vector3(0.15, 0.13, 0.07)), Color("#2a1c14"), Vector3(0, 1.56, -0.085))
		_mi(root, _cyl_m, black, Vector3(0, 1.74, 0), Vector3(0.52, 0.02, 0.52))
		_mi(root, _cyl_m, black, Vector3(0, 1.8, 0), Vector3(0.29, 0.13, 0.29))
	elif kind == "man2" or kind == "player" or kind == "kid":
		var kc: Color = [Color("#e8e8e8"), Color("#2a4a8a"), Color("#a83a3a"), Color("#3a3a3a")][r.randi() % 4]
		if kind == "player":
			kc = Color("#3a2a6a")
		_mi(root, _cyl_m, kc, Vector3(0, 1.745, 0), Vector3(0.2, 0.03, 0.2))
		if kind != "kid":
			_mi(root, _boxm(Vector3(0.14, 0.08, 0.06)), Color("#3a2a1c"), Vector3(0, 1.58, -0.09))
	elif woman:
		var hc: Color = [Color("#3a2a1a"), Color("#6a4a2a"), Color("#c8c0b8"), Color("#1a1a1a")][r.randi() % 4]
		var scarf := kind == "woman" and r.randf() < 0.6
		_mi(root, _head_m, (top.darkened(0.2) if scarf else hc), Vector3(0, 1.67, 0.03), Vector3(1.12, 1.1, 1.15))
	elif kind == "tourist":
		_mi(root, _cyl_m, Color("#2a4a8a"), Vector3(0, 1.74, 0), Vector3(0.3, 0.09, 0.3))
		_mi(root, _boxm(Vector3(0.24, 0.02, 0.18)), Color("#2a4a8a"), Vector3(0, 1.72, -0.18))
	elif kind == "vendor":
		_mi(root, _boxm(Vector3(0.46, 0.7, 0.04)), Color("#f0f0f0"), Vector3(0, 0.95, -0.14))
	root.scale = Vector3.ONE * scale_
	return {"root": root, "legs": legs, "arms": arms, "phase": r.randf() * TAU}


func _anim(p: Dictionary, speed: float, delta: float) -> void:
	var legs: Array = p["legs"]
	var arms: Array = p["arms"]
	if speed < 0.05:
		for i in 2:
			legs[i].rotation.x = lerpf(legs[i].rotation.x, 0.0, 0.3)
			arms[i].rotation.x = lerpf(arms[i].rotation.x, 0.0, 0.3)
		return
	p["phase"] = float(p["phase"]) + delta * speed * 2.6
	var s := sin(float(p["phase"])) * 0.7
	legs[0].rotation.x = s
	legs[1].rotation.x = -s
	arms[0].rotation.x = -s * 0.8
	arms[1].rotation.x = s * 0.8


func yaw_for(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _actors() -> void:
	# player
	pl = Node3D.new()
	pl_person = _make_person("player", rng)
	pl.add_child(pl_person["root"])
	pl.position = Vector3(7.5, 0, 30.0)
	pl_yaw = PI
	add_child(pl)
	cam_yaw = 0.0
	# the van
	van = _make_van()
	van.position = Vector3(4.6, 0, 46.0)
	van_yaw = 0.0
	van.rotation.y = van_yaw
	add_child(van)
	# walkers on the sidewalks
	var kinds := ["man", "man", "man", "woman", "woman", "man2", "kid", "girl", "tourist", "woman"]
	for i in 22:
		var r: float = ROADS[rng.randi() % 3]
		var side := -7.5 if rng.randf() < 0.5 else 7.5
		var along := rng.randf_range(-90.0, 70.0)
		var span := rng.randf_range(24.0, 40.0)
		var horiz := rng.randf() < 0.5
		var a := Vector3(r + side, 0, along) if not horiz else Vector3(along, 0, r + side)
		var b := Vector3(r + side, 0, along + span) if not horiz else Vector3(along + span, 0, r + side)
		a = _clamp_city(a)
		b = _clamp_city(b)
		_add_walker(kinds[i % kinds.size()], a, b)
	# market walkers
	for i in 12:
		var x := rng.randf_range(29.5, 36.5)
		var za := rng.randf_range(-54.0, -30.0)
		_add_walker(kinds[(i + 3) % kinds.size()], Vector3(x, 0, za), Vector3(x + rng.randf_range(-1.0, 1.0), 0, za + rng.randf_range(10.0, 22.0)))
	# vendors behind the stalls
	for side in 2:
		for k in [1, 3, 5, 6]:
			var cx := 24.2 if side == 0 else 41.8
			var z: float = -54.0 + k * 6.0
			var pr := _make_person("vendor", rng)
			var rt: Node3D = pr["root"]
			rt.position = Vector3(cx, 0, z)
			rt.rotation.y = yaw_for(Vector3(1.0 if side == 0 else -1.0, 0, 0))
			var lb := Label3D.new()
			lb.text = SHOUTS[(k + side * 3) % SHOUTS.size()]
			lb.font_size = 48
			lb.pixel_size = 0.008
			lb.outline_size = 8
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.position = Vector3(0, 2.3, 0)
			lb.modulate = Color("#fff2a0")
			lb.visible = false
			rt.add_child(lb)
			add_child(rt)
			vendors.append({"node": rt, "label": lb, "t": rng.randf() * 6.0, "idx": k + side * 3})
	# chatty neighbours
	var chat_pos := [Vector3(-14.0, 0, 7.4), Vector3(34.5, 0, -5.8), Vector3(-58.4, 0, -14.0)]
	var chat_names := ["Reb Chaim", "Mrs. Rosenfeld", "Yossi from the kollel"]
	for i in 3:
		var pr := _make_person(["man", "woman", "man2"][i], rng)
		var rt: Node3D = pr["root"]
		rt.position = chat_pos[i]
		rt.rotation.y = rng.randf() * TAU
		var lb := Label3D.new()
		lb.text = "Oy, got a minute?"
		lb.font_size = 48
		lb.pixel_size = 0.008
		lb.outline_size = 8
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = Vector3(0, 2.3, 0)
		lb.modulate = Color("#ffd0a0")
		rt.add_child(lb)
		add_child(rt)
		chatters.append({"node": rt, "name": chat_names[i], "used": false})
	# traffic
	var lane_cols := [Color("#d8d8d8"), Color("#e8c63a"), Color("#2a3a5a"), Color("#8a2a2a"), Color("#c8c0a8"), Color("#3a6a4a"), Color("#f0f0f0")]
	var n_cars := 0
	for r in ROADS:
		for dir in [-1.0, 1.0]:
			for k in 2:
				var vertical := (n_cars % 2 == 0)
				cars.append(_make_car(r, dir, vertical, lane_cols[n_cars % lane_cols.size()], -100.0 + k * 100.0 + rng.randf_range(-20.0, 20.0)))
				n_cars += 1
	# shekel coins
	for i in 34:
		var r: float = ROADS[rng.randi() % 3]
		var side := -7.2 if rng.randf() < 0.5 else 7.2
		var along := rng.randf_range(-95.0, 95.0)
		var p := Vector3(r + side, 0.9, along) if rng.randf() < 0.5 else Vector3(along, 0.9, r + side)
		if rng.randf() < 0.3:
			p = Vector3(rng.randf_range(29.0, 37.0), 0.9, rng.randf_range(-54.0, -12.0))
		var cm := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.32
		cy.bottom_radius = 0.32
		cy.height = 0.06
		cy.radial_segments = 12
		cy.rings = 1
		cm.mesh = cy
		cm.material_override = mat(Color("#ffc928"), 0.8)
		cm.position = p
		cm.rotation.x = PI / 2.0
		add_child(cm)
		pickups.append(cm)


func _clamp_city(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF + 2.0, HALF - 2.0), p.y, clampf(p.z, -HALF + 2.0, HALF - 2.0))


func _add_walker(kind: String, a: Vector3, b: Vector3) -> void:
	var pr := _make_person(kind, rng)
	var rt: Node3D = pr["root"]
	rt.position = a
	add_child(rt)
	walkers.append({"p": pr, "node": rt, "a": a, "b": b, "u": rng.randf(), "dir": 1.0,
		"speed": rng.randf_range(1.1, 1.9) * (0.7 if kind == "kid" or kind == "girl" else 1.0), "stun": 0.0, "len": maxf(a.distance_to(b), 1.0)})


func _make_van() -> Node3D:
	var v := Node3D.new()
	_mi(v, _boxm(Vector3(2.0, 1.3, 4.9)), Color("#ececec"), Vector3(0, 1.05, 0))
	_mi(v, _boxm(Vector3(2.02, 0.5, 3.4)), Color("#1b2736"), Vector3(0, 1.45, 0.3))
	_mi(v, _boxm(Vector3(1.9, 0.46, 1.4)), Color("#1b2736"), Vector3(0, 1.4, -1.9))
	_mi(v, _boxm(Vector3(2.04, 0.18, 4.95)), Color("#b0b0b0"), Vector3(0, 0.56, 0))
	_mi(v, _boxm(Vector3(2.1, 0.42, 3.5)), Color("#111111"), Vector3(0, 0.35, 0.2))
	_mi(v, _boxm(Vector3(0.4, 0.2, 0.06)), Color("#fff2b0"), Vector3(-0.7, 0.9, -2.46), Vector3.ONE).material_override = mat(Color("#fff2b0"), 1.0)
	_mi(v, _boxm(Vector3(0.4, 0.2, 0.06)), Color("#fff2b0"), Vector3(0.7, 0.9, -2.46)).material_override = mat(Color("#fff2b0"), 1.0)
	_mi(v, _boxm(Vector3(0.4, 0.2, 0.06)), Color("#d02020"), Vector3(-0.7, 0.95, 2.46)).material_override = mat(Color("#d02020"), 0.8)
	_mi(v, _boxm(Vector3(0.4, 0.2, 0.06)), Color("#d02020"), Vector3(0.7, 0.95, 2.46)).material_override = mat(Color("#d02020"), 0.8)
	_mi(v, _boxm(Vector3(1.4, 0.3, 0.06)), Color("#e8c63a"), Vector3(0, 1.85, 0.2))
	return v


func _make_car(r: float, dir: float, vertical: bool, col: Color, start: float) -> Dictionary:
	var n := Node3D.new()
	_mi(n, _boxm(Vector3(1.8, 0.7, 4.0)), col, Vector3(0, 0.62, 0))
	_mi(n, _boxm(Vector3(1.6, 0.55, 2.0)), Color("#1b2430"), Vector3(0, 1.2, 0.2))
	_mi(n, _boxm(Vector3(1.86, 0.4, 3.2)), Color("#111111"), Vector3(0, 0.3, 0))
	add_child(n)
	return {"node": n, "line": r, "dir": dir, "vertical": vertical, "pos": start, "speed": 7.0 + (int(r) % 3) * 0.5, "lane": 2.2 * (-dir if vertical else dir)}


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
	controls = TouchControls.new()
	ui.add_child(controls)
	controls.has_gun = false
	controls.fight_buttons = false
	controls.hide_move_buttons = true
	controls.set_mode(Profile.get_setting("controls", 0) as TouchControls.Mode)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	l_time = _lbl(root, "", 22, Color.WHITE)
	l_time.position = Vector2(18, 10)
	l_clock = _lbl(root, "", 15, Color(1, 1, 1, 0.8))
	l_clock.position = Vector2(18, 40)
	l_mission = _lbl(root, "", 17, Color("#ffe27a"))
	l_mission.position = Vector2(18, 62)
	l_coins = _lbl(root, "", 16, Color("#ffd34a"))
	l_coins.position = Vector2(18, 88)
	l_banner = _lbl(root, "", 28, Color.WHITE)
	l_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l_banner.offset_left = -250
	l_banner.offset_right = 250
	l_banner.offset_top = -150
	l_banner.offset_bottom = -40
	l_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_banner.modulate.a = 0.0
	l_toast = _lbl(root, "", 20, Color("#ff9a8a"))
	l_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l_toast.offset_left = -220
	l_toast.offset_right = 220
	l_toast.offset_top = -190
	l_toast.offset_bottom = -150
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
	arrow = Control.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	arrow.offset_left = -30
	arrow.offset_right = 30
	arrow.offset_top = 8
	arrow.offset_bottom = 68
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(_draw_arrow)
	root.add_child(arrow)
	l_dist = _lbl(root, "", 15, Color.WHITE)
	l_dist.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l_dist.offset_left = -60
	l_dist.offset_right = 60
	l_dist.offset_top = 66
	l_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _banner(title: String, sub := "", dur := 2.0) -> void:
	l_banner.text = title + ("\n" + sub if sub != "" else "")
	l_banner.add_theme_font_size_override("font_size", 30 if sub == "" else 24)
	var tw := create_tween()
	tw.tween_property(l_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(dur)
	tw.tween_property(l_banner, "modulate:a", 0.0, 0.4)


func _toast(text: String) -> void:
	l_toast.text = text
	l_toast.modulate.a = 1.0
	toast_t = 2.2


func _stand_pos(i: int) -> Vector3:
	if i < 0 or i >= missions.size():
		return Vector3.ZERO
	return PLACES[missions[i]["place"]]["stand"]


func _actor_pos() -> Vector3:
	return van.position if in_van else pl.position


func _hud_update() -> void:
	var tl := maxf(time_left, 0.0)
	l_time.text = "Candle lighting in %d:%02d" % [int(tl) / 60, int(tl) % 60]
	l_time.add_theme_color_override("font_color", Color("#ff6b6b") if tl < 60.0 else Color.WHITE)
	var gm := 14.0 * 60.0 + 45.0 + (1.0 - tl / time_total) * 80.0
	l_clock.text = "%d:%02d pm  ·  Erev Shabbos" % [int(gm) / 60 - 12, int(gm) % 60]
	if mi < missions.size():
		l_mission.text = "%d/%d  %s" % [mi + 1, missions.size(), missions[mi]["text"]]
	l_coins.text = "Shekels: %d" % coins


func _draw_minimap() -> void:
	var s := mm.size
	mm.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.06, 0.1, 0.55))
	var k := s.x / (2.0 * (HALF + 4.0))
	var o := s * 0.5
	for r in ROADS:
		mm.draw_rect(Rect2(o + Vector2(r - 5.0, -HALF) * k, Vector2(10.0 * k, 2.0 * HALF * k)), Color(0.75, 0.75, 0.8, 0.5))
		mm.draw_rect(Rect2(o + Vector2(-HALF, r - 5.0) * k, Vector2(2.0 * HALF * k, 10.0 * k)), Color(0.75, 0.75, 0.8, 0.5))
	mm.draw_rect(Rect2(o + Vector2(22.0, -57.0) * k, Vector2(22.0 * k, 48.0 * k)), Color(0.95, 0.6, 0.2, 0.35))
	if mi < missions.size():
		var sp := _stand_pos(mi)
		var pulse := 4.0 + sin(t * 6.0) * 1.5
		mm.draw_circle(o + Vector2(sp.x, sp.z) * k, pulse, Color("#ffd23a"))
	if not in_van:
		mm.draw_rect(Rect2(o + Vector2(van.position.x, van.position.z) * k - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
	var ap := _actor_pos()
	var heading := van_yaw if in_van else pl_yaw
	mm.draw_set_transform(o + Vector2(ap.x, ap.z) * k, -heading + PI, Vector2.ONE)
	mm.draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4.5, 5), Vector2(-4.5, 5)]), Color("#4ae0ff"))
	mm.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	mm.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.35), false, 1.5)


func _draw_arrow() -> void:
	if mi >= missions.size():
		return
	var d := _stand_pos(mi) - _actor_pos()
	d.y = 0.0
	var local := Basis(Vector3.UP, -cam_yaw) * d
	var ang := atan2(local.x, -local.z)
	var c := arrow.size * 0.5
	arrow.draw_set_transform(c, ang, Vector2.ONE)
	arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(17, 16), Vector2(0, 7), Vector2(-17, 16)]), Color("#ffd23a"))
	arrow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	var tt := _lbl(v, title, 28, Color.WHITE)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bb := _lbl(v, body, 16, Color(1, 1, 1, 0.8))
	bb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if on:
		controls.clear()
		var names := ["Joystick", "D-pad", "Tilt"]
		_overlay("Paused", "Joystick: walk, or steer and gas in the van. Drag the right side to look. The yellow button buys, enters and exits.", [
			["Resume", func(): _pause(false)],
			["Controls: " + names[int(controls.mode)], func():
				var nm := controls.cycle_mode()
				Profile.set_setting("controls", int(controls.mode))
				_pause(true)],
			["Restart", func(): app.start_level(level_id)],
			["Back to menu", func(): app.show_launcher()]])
	elif overlay:
		overlay.queue_free()
		overlay = null


# ---------------------------------------------------------------- game logic

func _physics_process(delta: float) -> void:
	t += delta
	if paused:
		return
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			l_toast.modulate.a = 0.0
	hit_cool = maxf(hit_cool - delta, 0.0)
	_update_people(delta)
	_update_cars(delta)
	if phase == "play":
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_lose("Shabbos came in!", "You ran out of time. The candles are lit without you.")
		for w in [60.0, 30.0]:
			if time_left < w and not warned.has(w):
				warned[w] = true
				_toast("%d seconds to candle lighting!" % int(w))
		_move(delta)
		_pickups(delta)
		_interactions()
	if phase != "over":
		_follow(delta)
	env_t += delta
	if env_t > 0.5:
		env_t = 0.0
		_update_env()
		_hud_update()
	if arrow:
		arrow.queue_redraw()
		mm.queue_redraw()
	if mi < missions.size() and phase != "over":
		l_dist.text = "%d m" % int(_actor_pos().distance_to(_stand_pos(mi)))
	for key in markers:
		var m: Node3D = markers[key]
		m.visible = mi < missions.size() and missions[mi]["place"] == key
		if m.visible:
			(m.get_child(0) as Node3D).visible = m.position.distance_to(_actor_pos()) > 3.5
			var cone: Node3D = m.get_node("cone")
			cone.position.y = 8.0 + sin(t * 4.0) * 0.4


func _move(delta: float) -> void:
	var mv := controls.get_move()
	if mv.length() > 1.0:
		mv = mv.normalized()
	var look := controls.take_look()
	if look != Vector2.ZERO:
		cam_yaw -= look.x * 0.006
		cam_pitch = clampf(cam_pitch + look.y * 0.004, 0.12, 1.1)
		look_idle = 0.0
	else:
		look_idle += delta
	if in_van:
		_drive(mv, delta)
		return
	var dirv := Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0.0, mv.y)
	var want := dirv * 6.3
	pl_vel = pl_vel.lerp(want, minf(delta * 10.0, 1.0))
	var np := pl.position + pl_vel * delta
	np = _resolve(np, PR)
	pl.position = Vector3(np.x, 0, np.z)
	var sp := pl_vel.length()
	if sp > 0.4:
		pl_yaw = lerp_angle(pl_yaw, yaw_for(pl_vel), minf(delta * 12.0, 1.0))
	pl.rotation.y = pl_yaw
	_anim(pl_person, sp / 5.5, delta)
	if hit_cool <= 0.0:
		var c = _car_hit(pl.position, PR + 0.15)
		if c != null:
			_penalty(3.0, "Careful! Jerusalem drivers don't stop for anyone.")
			var away: Vector3 = pl.position - c["node"].position
			away.y = 0.0
			pl.position = _resolve(pl.position + away.normalized() * 1.6, PR)


func _drive(mv: Vector2, delta: float) -> void:
	var throttle := -mv.y
	if absf(throttle) < 0.05:
		van_speed = move_toward(van_speed, 0.0, 6.0 * delta)
	elif throttle * van_speed < 0.0:
		van_speed += throttle * 22.0 * delta
	else:
		van_speed += throttle * 10.0 * delta
	van_speed = clampf(van_speed, -6.0, 15.0)
	var grip := clampf(absf(van_speed) / 4.0, 0.0, 1.0) * (1.0 if van_speed >= 0.0 else -1.0)
	van_yaw -= mv.x * 1.9 * grip * delta
	var heading := Vector3(-sin(van_yaw), 0.0, -cos(van_yaw))
	var np := van.position + heading * van_speed * delta
	var res := _resolve(np, VR)
	var moved := (res - np).length()
	if moved > 0.02:
		if absf(van_speed) > 4.0:
			shake = 0.25
		van_speed *= 0.55
	van.position = Vector3(res.x, 0, res.z)
	van.rotation.y = van_yaw
	if hit_cool <= 0.0:
		var c = _car_hit(van.position, VR)
		if c != null:
			van_speed *= 0.3
			_penalty(4.0, "Crash! Watch the traffic.")
			shake = 0.4
		else:
			for w in walkers:
				var wp: Vector3 = w["node"].position
				if Vector2(wp.x - van.position.x, wp.z - van.position.z).length() < VR + 0.6 and absf(van_speed) > 1.5:
					_penalty(3.0, "Beep beep! Watch the pedestrians!")
					w["stun"] = 2.0
					van_speed *= 0.5
					break
	pl.position = van.position


func _resolve(p: Vector3, r: float) -> Vector3:
	for it in 2:
		for s in solids:
			if p.x > s.position.x - r and p.x < s.end.x + r and p.z > s.position.y - r and p.z < s.end.y + r:
				var l := p.x - (s.position.x - r)
				var rr := (s.end.x + r) - p.x
				var u := p.z - (s.position.y - r)
				var dn := (s.end.y + r) - p.z
				var m := minf(minf(l, rr), minf(u, dn))
				if m == l:
					p.x = s.position.x - r
				elif m == rr:
					p.x = s.end.x + r
				elif m == u:
					p.z = s.position.y - r
				else:
					p.z = s.end.y + r
	p.x = clampf(p.x, -HALF, HALF)
	p.z = clampf(p.z, -HALF, HALF)
	return p


func _car_hit(p: Vector3, r: float):
	for c in cars:
		var n: Node3D = c["node"]
		var local := n.global_transform.affine_inverse() * p
		if absf(local.x) < 0.9 + r and absf(local.z) < 2.0 + r:
			return c
	return null


func _penalty(sec: float, msg: String) -> void:
	hit_cool = 2.0
	time_left = maxf(time_left - sec, 1.0)
	_toast("%s  (-%d s)" % [msg, int(sec)])


func _update_people(delta: float) -> void:
	var ap := _actor_pos()
	for w in walkers:
		var n: Node3D = w["node"]
		if float(w["stun"]) > 0.0:
			w["stun"] = float(w["stun"]) - delta
			_anim(w["p"], 0.0, delta)
			continue
		var u: float = w["u"] + float(w["dir"]) * float(w["speed"]) * delta / float(w["len"])
		if u > 1.0:
			u = 1.0
			w["dir"] = -1.0
		elif u < 0.0:
			u = 0.0
			w["dir"] = 1.0
		w["u"] = u
		var a: Vector3 = w["a"]
		var b: Vector3 = w["b"]
		var np := a.lerp(b, u)
		var dv := (b - a) * float(w["dir"])
		n.position = np
		if dv.length() > 0.01:
			n.rotation.y = lerp_angle(n.rotation.y, yaw_for(dv), minf(delta * 8.0, 1.0))
		_anim(w["p"], float(w["speed"]), delta)
		n.visible = n.position.distance_to(ap) < 90.0
		if phase == "play" and not in_van and hit_cool <= 0.0 and n.position.distance_to(pl.position) < 0.75:
			var away := pl.position - n.position
			away.y = 0.0
			pl.position = _resolve(pl.position + away.normalized() * 0.6, PR)
			hit_cool = 1.2
			time_left = maxf(time_left - 1.0, 1.0)
			_toast(["Slicha!", "Oy, watch it!", "Excuse me!"][rng.randi() % 3] + "  (-1 s)")
	for v in vendors:
		var lb: Label3D = v["label"]
		var near: bool = (v["node"] as Node3D).position.distance_to(ap) < 16.0
		v["t"] = float(v["t"]) + delta
		if near:
			var ph := fmod(float(v["t"]), 6.0)
			lb.visible = ph < 2.4
			lb.text = SHOUTS[(int(float(v["t"]) / 6.0) + int(v["idx"])) % SHOUTS.size()]
		else:
			lb.visible = false
	for c in chatters:
		if c["used"]:
			continue
		var cn: Node3D = c["node"]
		if phase == "play" and cn.position.distance_to(ap) < (3.2 if in_van else 2.0):
			c["used"] = true
			(cn.get_child(cn.get_child_count() - 1) as Label3D).text = "Nu, go! Go!"
			time_left = maxf(time_left - 8.0, 1.0)
			_toast("%s stops you for a chat.  (-8 s)" % c["name"])
			if in_van:
				van_speed *= 0.3
			else:
				pl_vel = Vector3.ZERO


func _update_cars(delta: float) -> void:
	for c in cars:
		var p: float = c["pos"] + float(c["dir"]) * float(c["speed"]) * delta
		if p > HALF + 8.0:
			p = -HALF - 8.0
		elif p < -HALF - 8.0:
			p = HALF + 8.0
		c["pos"] = p
		var n: Node3D = c["node"]
		var ln: float = c["line"] + float(c["lane"])
		if c["vertical"]:
			n.position = Vector3(ln, 0, p)
			n.rotation.y = yaw_for(Vector3(0, 0, float(c["dir"])))
		else:
			n.position = Vector3(p, 0, ln)
			n.rotation.y = yaw_for(Vector3(float(c["dir"]), 0, 0))
		n.visible = n.position.distance_to(_actor_pos()) < 110.0


func _pickups(delta: float) -> void:
	var ap := _actor_pos()
	var rad := 2.2 if in_van else 1.3
	for pk in pickups.duplicate():
		var n: Node3D = pk
		n.rotation.z += delta * 3.0
		if absf(n.position.x - ap.x) < rad and absf(n.position.z - ap.z) < rad:
			coins += 1
			pickups.erase(pk)
			n.queue_free()


func _near_stand() -> bool:
	if mi >= missions.size():
		return false
	var sp := _stand_pos(mi)
	var ap := _actor_pos()
	return Vector2(sp.x - ap.x, sp.z - ap.z).length() < (6.0 if in_van else 4.2)


func _interactions() -> void:
	var label := ""
	if _near_stand():
		label = missions[mi]["verb"]
	elif in_van:
		label = "EXIT VAN"
	elif Vector2(van.position.x - pl.position.x, van.position.z - pl.position.z).length() < 4.0:
		label = "DRIVE"
	controls.set_act(label)
	if controls.consume("act") or Input.is_action_just_pressed("ui_accept"):
		interact()


## Used by the touch button and by the headless test bot.
func interact() -> void:
	if phase != "play":
		return
	if _near_stand():
		var m: Dictionary = missions[mi]
		mi += 1
		if mi >= missions.size():
			_win()
			return
		_banner("Done! " + m["verb"].capitalize(), m["msg"], 2.6)
		_hud_update()
		return
	if in_van:
		in_van = false
		var side := Vector3(cos(van_yaw), 0, -sin(van_yaw))
		pl.position = _resolve(van.position + side * 2.2, PR)
		pl.visible = true
		van_speed = 0.0
		cam_pitch = 0.38
	elif Vector2(van.position.x - pl.position.x, van.position.z - pl.position.z).length() < 4.0:
		in_van = true
		pl.visible = false
		pl_vel = Vector3.ZERO
		_toast("Beep beep! Joystick up = gas, left/right = steer.")


func _follow(delta: float) -> void:
	var ap := _actor_pos()
	if in_van and look_idle > 1.2 and absf(van_speed) > 2.0:
		cam_yaw = lerp_angle(cam_yaw, van_yaw if van_speed > 0.0 else van_yaw + PI, minf(delta * 1.8, 1.0))
	var dist := cam_dist + (2.4 if in_van else 0.0)
	var target := ap + Vector3(0, 1.5 if not in_van else 1.8, 0)
	var off := Basis(Vector3.UP, cam_yaw) * Vector3(0, sin(cam_pitch) * dist, cos(cam_pitch) * dist)
	var want := target + off
	# keep the camera out of buildings
	var best := 1.0
	for i in range(1, 9):
		var f := float(i) / 8.0
		var q := target.lerp(want, f)
		var hit := false
		for s in solids:
			if q.y < 30.0 and q.x > s.position.x - 0.3 and q.x < s.end.x + 0.3 and q.z > s.position.y - 0.3 and q.z < s.end.y + 0.3:
				hit = true
				break
		if hit:
			best = maxf(float(i - 1) / 8.0, 0.3)
			break
	var lifted := target.lerp(want, best)
	lifted.y += (1.0 - best) * 2.2
	want = lifted
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
		want += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
	cam.position = cam.position.lerp(want, minf(delta * 9.0, 1.0)) if cam.position.distance_to(want) < 14.0 else want
	cam.look_at(target + Vector3(0, 0.2, 0))


# ---------------------------------------------------------------- end

func _points() -> int:
	return coins * 2 + int(time_left)


func _commit() -> int:
	if committed:
		return 0
	committed = true
	var pts := _points()
	if pts > 0:
		Profile.add_points(pts)
	return pts


func _lose(title: String, body: String) -> void:
	if phase == "over":
		return
	phase = "over"
	controls.set_act("")
	var pts := _commit()
	finished.emit(false)
	_overlay(title, body + "\nErrands done: %d of %d. You earned %d points." % [mi, missions.size() - 1, pts], [
		["Try again", func(): app.start_level(level_id)], ["Back to menu", func(): app.show_launcher()]])


func _win() -> void:
	if phase == "over":
		return
	phase = "over"
	controls.set_act("")
	Profile.mark_completed(level_id)
	var pts := _commit() + 100
	Profile.add_points(100)
	finished.emit(true)
	var left := int(time_left)
	_overlay("Gut Shabbos!", "You made it with %d:%02d to spare and %d shekels. You earned %d points." % [left / 60, left % 60, coins, pts], [
		["Play again", func(): app.start_level(level_id)], ["Back to menu", func(): app.show_launcher()]])
