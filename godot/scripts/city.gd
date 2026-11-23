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
		"time": 330.0,
		"map": "geula",
		"intro": "Shabbos is coming! Shop for Shabbos, load the trunk, and reach shul before candle lighting.",
		"missions": [
			{"place": "bakery", "text": "Pick up challah at the bakery", "verb": "BUY\nCHALLAH", "item": "challah",
				"msg": "Two warm challos in the bag. The baker: \"Take a third, your mother-in-law is coming.\""},
			{"place": "fish", "text": "Buy fish in Machane Yehuda", "verb": "BUY\nFISH", "item": "fish",
				"msg": "\"Caught this morning!\" says the fish seller. He says that about every fish."},
			{"place": "flowers", "text": "Get hadassim and flowers", "verb": "BUY\nFLOWERS", "item": "flowers",
				"msg": "\"For shalom bayis,\" says the seller, and charges double. The bag is getting heavy!"},
			{"kind": "stow", "need": 3, "text": "Heavy bag! Put the shopping in the car trunk", "verb": "",
				"msg": "The trunk closes with a satisfying thunk. Your back thanks you."},
			{"place": "grocery", "text": "Grab grape juice at the grocery", "verb": "BUY\nJUICE", "item": "juice",
				"msg": "The cashier: \"Did you remember the challah?\" It is in the trunk!"},
			{"place": "shul", "kind": "shul", "text": "Get the shopping out of the trunk, then into shul!", "verb": "ENTER\nSHUL", "msg": ""},
		],
	},
	"city2": {
		"title": "Erev Shabbos in Tiberias",
		"time": 460.0,
		"map": "kinneret",
		"market_en": "TIBERIAS MARKET",
		"market_he": "שוק טבריה",
		"streets": ["HAYARDEN ST", "HAGALIL ST", "KINNERET PROMENADE", "HAKISHON ST", "HAGOLAN ST"],
		"start": {"player": Vector3(-58.8, 0, 28.0), "pyaw": PI, "car": Vector3(-62.4, 0, 31.0), "cyaw": PI, "cam": 0.0},
		"intro": "Fresh fish from the Kinneret! Drive to the marina, take Moshe's boat out, then finish the errands before candle lighting.",
		"missions": [
			{"kind": "reach", "veh": "car", "pos": Vector3(27.0, 0, 70.5), "r": 7.0, "text": "Drive to the marina", "verb": "",
				"msg": "Moshe waves from the pier: \"Park it! The fish don't wait!\""},
			{"kind": "board", "text": "Climb aboard Moshe's boat", "verb": "", "msg": "Moshe: \"Captain, the wheel is yours. Try not to sink.\""},
			{"kind": "boat_stand", "pos": Vector3(-26.0, 0, 98.0), "r": 7.5, "item": "fish", "verb": "BUY\nFISH",
				"text": "Sail to the fisherman's buoy and buy St. Peter's fish",
				"msg": "The fisherman tosses the fish into the cooler. It is still looking at you."},
			{"kind": "reach", "veh": "boat", "pos": Vector3(24.6, 0, 86.5), "r": 5.5, "text": "Sail back to the dock", "verb": "",
				"msg": "Docked! Tap GET OFF to climb out. The fish comes with you."},
			{"kind": "stow", "need": 1, "text": "Put the fish in the car trunk", "verb": "",
				"msg": "The fish is in the trunk. The whole car will smell like Tiberias until Pesach."},
			{"place": "bakery", "text": "Pick up challah at the bakery", "verb": "BUY\nCHALLAH", "item": "challah",
				"msg": "Still warm. The baker: \"Tell your wife it's homemade.\""},
			{"place": "flowers", "text": "Get hadassim and flowers", "verb": "BUY\nFLOWERS", "item": "flowers",
				"msg": "\"For shalom bayis,\" says the seller, and charges double."},
			{"place": "shul", "kind": "shul", "text": "Get the shopping out of the trunk, then into shul!", "verb": "ENTER\nSHUL", "msg": ""},
		],
	},
}
## stand = where you stand to use it; wall = direction from stand to the shop; dist = distance to the facade.
const PLACES := {
	"bakery": {"stand": Vector3(-33, 0, 7.5), "wall": Vector3(0, 0, 1), "dist": 1.5, "he": "מאפיה · חלות טריות", "sign": "BAKERY", "sub": "Fresh challah", "col": Color("#e0963a"), "door": true},
	"fish": {"stand": Vector3(29.5, 0, -30), "wall": Vector3(-1, 0, 0), "dist": 2.0, "he": "דגים טריים", "sign": "FISH", "sub": "Fresh! Fresh!", "col": Color("#3d8ed6"), "door": false},
	"flowers": {"stand": Vector3(36.5, 0, -42), "wall": Vector3(1, 0, 0), "dist": 2.0, "he": "פרחים והדסים", "sign": "FLOWERS", "sub": "Hadassim & more", "col": Color("#d6457f"), "door": false},
	"grocery": {"stand": Vector3(33, 0, -73.5), "wall": Vector3(0, 0, -1), "dist": 1.5, "he": "מכולת", "sign": "GROCERY", "sub": "Wine & grape juice", "col": Color("#3aa86a"), "door": true},
	"shul": {"stand": Vector3(-58.5, 0, -33), "wall": Vector3(1, 0, 0), "dist": 1.5, "he": "בית כנסת", "sign": "SHUL", "sub": "Mincha / Kabbalas Shabbos", "col": Color("#e8c24a"), "door": true},
}
const STREETS := [
	{"pos": Vector3(7.2, 0, 7.2), "text": "MALCHEI YISRAEL ST", "yaw": 0.0},
	{"pos": Vector3(-58.8, 0, 7.2), "text": "SHMUEL HANAVI ST", "yaw": 0.0},
	{"pos": Vector3(73.2, 0, 7.2), "text": "STRAUSS ST", "yaw": 0.0},
	{"pos": Vector3(-7.2, 0, -58.8), "text": "YAFO ROAD", "yaw": 3.14159},
	{"pos": Vector3(-7.2, 0, 7.2), "text": "YIRMIYAHU ST", "yaw": 0.0},
]
const HEB_SHOPS := ["מכולת", "מאפיה", "פירות וירקות", "בגדי ילדים", "יודאיקה", "פיצה", "חלות", "ספרים", "מעדנייה", "קפה", "תבלינים", "יין"]
const HEB_STALLS := ["פירות וירקות", "תבלינים", "דגים", "פרחים", "חלות ומאפים", "יין ומשקאות", "אגוזים ופירות יבשים", "ירקות טריים"]
const PRESETS := {
	"afternoon": {"top": "#4f86d0", "hor": "#d8e6f2", "sun": "#fff0d2", "se": 1.15, "elev": -52.0, "az": -35.0, "amb": "#dfd6c6", "ae": 0.9, "fog": "#e2dccd", "fd": 0.0014},
	"golden": {"top": "#5b86c8", "hor": "#ffd9a8", "sun": "#ffc88a", "se": 1.25, "elev": -21.0, "az": -62.0, "amb": "#d9c4a8", "ae": 0.72, "fog": "#f1c995", "fd": 0.0018},
	"sunset": {"top": "#2a3f8e", "hor": "#ff8f4a", "sun": "#ff7a30", "se": 1.1, "elev": -8.0, "az": -80.0, "amb": "#d79a78", "ae": 0.7, "fog": "#ff9a5c", "fd": 0.0022},
	"night": {"top": "#070d2a", "hor": "#2b3a66", "sun": "#7088cc", "se": 0.3, "elev": -38.0, "az": 30.0, "amb": "#3d4a78", "ae": 0.7, "fog": "#1c2748", "fd": 0.006},
	"morning": {"top": "#6aa0e8", "hor": "#ffe2c0", "sun": "#ffe0b0", "se": 1.3, "elev": -15.0, "az": 50.0, "amb": "#d8d0c8", "ae": 0.8, "fog": "#f3e6d2", "fd": 0.002},
	"overcast": {"top": "#8a97a6", "hor": "#c8ced4", "sun": "#d8dde2", "se": 0.5, "elev": -60.0, "az": 0.0, "amb": "#c5cbd2", "ae": 1.1, "fog": "#c3c9cf", "fd": 0.0016},
}
const FACADE_SHADER := """
shader_type spatial;
uniform sampler2D stone : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D overlay : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float stone_m = 3.2;
uniform vec2 cell = vec2(16.0, 3.2);
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = VERTEX;
	wn = NORMAL;
}
void fragment() {
	vec3 n = abs(wn);
	vec2 su;
	vec2 ou = vec2(0.0);
	float side = 1.0;
	if (n.y > 0.7) {
		su = wp.xz;
		side = 0.0;
	} else if (n.x > n.z) {
		su = vec2(wp.z, -wp.y);
		ou = su / cell;
	} else {
		su = vec2(wp.x, -wp.y);
		ou = su / cell;
	}
	vec3 s = texture(stone, su / stone_m).rgb;
	vec3 s2 = texture(stone, su / (stone_m * 4.7) + vec2(0.37)).rgb;
	vec3 base = s * (0.7 + 0.6 * s2);
	base = mix(vec3(dot(base, vec3(0.3, 0.59, 0.11))), base, 0.62) * 1.0 * COLOR.rgb;
	vec4 o = texture(overlay, ou);
	float a = o.a * side;
	vec3 col = mix(base, o.rgb, a);
	col *= mix(0.6, 1.0, smoothstep(0.0, 2.4, wp.y));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"""
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
var vc_mat: StandardMaterial3D
var vce_mat: ShaderMaterial
var glass_mat: StandardMaterial3D
var heb_font: Font
var preset := ""
var cine := {}
var overlay_tex := {}
const TILE := 74.0
const Vehicles := preload("res://scripts/vehicles.gd")
const DriveControls := preload("res://scripts/drive_controls.gd")
const PIER := Rect2(19.4, 79.0, 3.0, 13.0)
const DOCK := Vector3(24.6, 0.0, 86.5)
const LAKE_Z := 79.0
var map_id := "geula"
var kin := false
var car_p: Dictionary = {}
var boat: Node3D
var boat_p: Dictionary = {}
var in_boat := false
var boat_speed := 0.0
var boat_yaw := PI
var drive_ui: Control
var view_mode := 0
var ck_yaw := 0.0
var ck_pitch := 0.0
var base_fov := 62.0
var bag: Array = []
var trunk: Array = []
var cargo: Array = []
var busy := 0.0
var held_node: Node3D
var bag_node: Node3D
var seat_bag: Node3D
var trunk_vis: Node3D
var cargo_vis: Node3D
var water_solids: Array[Rect2] = []
var aux_marker: Node3D
var seated := false
var braking := false
var water_mat: ShaderMaterial

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
	map_id = str(cfg.get("map", "geula"))
	kin = map_id == "kinneret"
	missions = cfg["missions"]
	time_total = float(cfg["time"]) + (45.0 if Profile.owns("stopwatch") else 0.0)
	time_left = time_total
	rng.seed = 424242
	_load_fonts()
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


func _kind_mat(kind: String) -> Material:
	match kind:
		"vc":
			if vc_mat == null:
				vc_mat = StandardMaterial3D.new()
				vc_mat.vertex_color_use_as_albedo = true
				vc_mat.roughness = 0.85
			return vc_mat
		"vce":
			if vce_mat == null:
				var sh := Shader.new()
				sh.code = "shader_type spatial;\nvoid fragment() { ALBEDO = clamp(COLOR.rgb * 0.5, 0.0, 1.0); EMISSION = COLOR.rgb * 0.8; ROUGHNESS = 0.6; }"
				vce_mat = ShaderMaterial.new()
				vce_mat.shader = sh
			return vce_mat
		"glass":
			if glass_mat == null:
				glass_mat = StandardMaterial3D.new()
				glass_mat.vertex_color_use_as_albedo = true
				glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass_mat.roughness = 0.15
				glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			return glass_mat
	return _facade_mat(int(kind.substr(1)))


func _g(kind: String, pos: Vector3) -> SurfaceTool:
	var key := "%s|%d_%d" % [kind, floori((pos.x + HALF + 4.0) / TILE), floori((pos.z + HALF + 4.0) / TILE)]
	if not groups.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[key] = {"st": st, "kind": kind}
	return groups[key]["st"]


func _col(c: Color, emissive: float) -> Color:
	var l := c.srgb_to_linear()
	if emissive > 0.0:
		var k := 0.6 + emissive
		return Color(l.r * k, l.g * k, l.b * k, 1.0)
	return l


## Add a box into the merged static mesh (vertex coloured).
func sbox(c: Color, pos: Vector3, size: Vector3, yaw := 0.0, emissive := 0.0, tilt := Basis.IDENTITY) -> void:
	var b := Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(size)
	_append(_g("vce" if emissive > 0.0 else "vc", pos), box_arr, Transform3D(b, pos), _col(c, emissive))


func sglass(c: Color, pos: Vector3, size: Vector3, yaw := 0.0, tilt := Basis.IDENTITY) -> void:
	var b := Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(size)
	_append(_g("glass", pos), box_arr, Transform3D(b, pos), c.srgb_to_linear())


func scyl(c: Color, pos: Vector3, rt: float, rb: float, h: float, seg := 8, emissive := 0.0, rot := Basis.IDENTITY) -> void:
	_append(_g("vce" if emissive > 0.0 else "vc", pos), _cyl_arr(rt, rb, h, seg), Transform3D(rot, pos), _col(c, emissive))


func ssph(c: Color, pos: Vector3, r: float, seg := 8, rings := 5, emissive := 0.0) -> void:
	_append(_g("vce" if emissive > 0.0 else "vc", pos), _sph_arr(r, seg, rings), Transform3D(Basis.IDENTITY, pos), _col(c, emissive))


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


func _append(st: SurfaceTool, arr: Array, xf: Transform3D, col := Color.WHITE) -> void:
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
	st.set_color(col)
	# Godot front faces are clockwise: emit each triangle reversed
	var t := 0
	while t + 2 < idx.size():
		for k in [0, 2, 1]:
			var i: int = idx[t + k]
			st.set_normal(tn[i])
			st.add_vertex(tv[i])
		t += 3


func _commit_groups() -> void:
	for k in groups:
		var g: Dictionary = groups[k]
		var st: SurfaceTool = g["st"]
		var kind: String = g["kind"]
		var mesh := st.commit()
		var mi_node := MeshInstance3D.new()
		mi_node.mesh = mesh
		mi_node.material_override = _kind_mat(kind)
		mi_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (kind == "glass" or kind == "vce") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	sky_mat.sun_angle_max = 40.0
	sky_mat.sky_curve = 0.12
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.glow_enabled = Profile.quality_high()
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = _shadows_on()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	add_child(sun)
	_update_env()


func _shadows_on() -> bool:
	return Profile.quality_high()


func _update_env() -> void:
	var a: Dictionary
	var b: Dictionary
	var k := 0.0
	if preset != "":
		a = PRESETS[preset]
		b = a
	else:
		var p := clampf(1.0 - time_left / time_total, 0.0, 1.0)
		if p < 0.5:
			a = PRESETS["afternoon"]
			b = PRESETS["golden"]
			k = p * 2.0
		else:
			a = PRESETS["golden"]
			b = PRESETS["sunset"]
			k = (p - 0.5) * 2.0
	sky_mat.sky_top_color = Color(a["top"]).lerp(Color(b["top"]), k)
	sky_mat.sky_horizon_color = Color(a["hor"]).lerp(Color(b["hor"]), k)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color.darkened(0.45)
	env.fog_light_color = Color(a["fog"]).lerp(Color(b["fog"]), k)
	env.fog_density = lerpf(a["fd"], b["fd"], k)
	env.ambient_light_color = Color(a["amb"]).lerp(Color(b["amb"]), k)
	env.ambient_light_energy = lerpf(a["ae"], b["ae"], k)
	sun.light_color = Color(a["sun"]).lerp(Color(b["sun"]), k)
	sun.light_energy = lerpf(a["se"], b["se"], k)
	sun.rotation_degrees = Vector3(lerpf(a["elev"], b["elev"], k), lerpf(a["az"], b["az"], k), 0.0)


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
	base_fov = cam.fov
	cam.far = 320.0
	cam.near = 0.08


# ---------------------------------------------------------------- world

func _facade_overlay(style: int) -> ImageTexture:
	if overlay_tex.has(style):
		return overlay_tex[style]
	var W := 1024
	var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.82, 0.76, 0.62, 0.0))
	var shuts := [Color("#4f7d4d"), Color("#7a5634"), Color("#566c86")]
	var shut: Color = shuts[style]
	var r := RandomNumberGenerator.new()
	r.seed = 910 + style
	for c in 4:
		var x0 := c * 256
		var kind := (c + style) % 4
		var lit := r.randf() < 0.3
		match kind:
			0:
				_ov_window(img, x0 + 90, 40, 76, 140, shut, lit, r, false)
			1:
				_ov_window(img, x0 + 78, 34, 100, 160, shut, lit, r, true)
			2:
				_ov_balcony_door(img, x0 + 82, 24, 92, 196, shut, lit, r)
			_:
				_ov_window(img, x0 + 36, 70, 70, 100, shut, lit, r, false)
				_ov_window(img, x0 + 150, 70, 70, 100, shut, lit, r, false)
				if style != 1:
					img.fill_rect(Rect2i(x0 + 100, 190, 56, 40), Color("#c9ccd0"))
					img.fill_rect(Rect2i(x0 + 104, 194, 48, 32), Color("#9ca0a6"))
	img.generate_mipmaps()
	var tx := ImageTexture.create_from_image(img)
	overlay_tex[style] = tx
	return tx


func _ov_glass(img: Image, x: int, y: int, w: int, h: int, lit: bool, r: RandomNumberGenerator) -> void:
	var steps := 10
	for i in steps:
		var k := float(i) / float(steps - 1)
		var c := Color("#6f8ba3").lerp(Color("#1c2838"), k)
		if lit:
			c = Color("#ffd98f").lerp(Color("#e0944a"), k)
		img.fill_rect(Rect2i(x, y + int(h * i / steps), w, int(h / steps) + 1), c)
	if not lit:
		img.fill_rect(Rect2i(x + 4, y + 4, w / 3, h / 4), Color(1, 1, 1, 0.16))


func _ov_window(img: Image, x: int, y: int, w: int, h: int, shut: Color, lit: bool, r: RandomNumberGenerator, arched: bool) -> void:
	var frame := Color("#ebe4d2")
	img.fill_rect(Rect2i(x - 12, y - 10, w + 24, h + 26), Color(0, 0, 0, 0.28))
	if arched:
		var rad := w / 2
		var cx := x + rad
		for k in rad:
			var d := float(rad - k)
			var hw := int(sqrt(maxf(float(rad * rad) - d * d, 0.0)))
			img.fill_rect(Rect2i(cx - hw - 5, y + k - 5, hw * 2 + 10, 1), frame)
		img.fill_rect(Rect2i(x - 5, y + rad - 5, w + 10, h - rad + 10), frame)
		for k in rad:
			var d := float(rad - k)
			var hw := int(sqrt(maxf(float(rad * rad) - d * d, 0.0)))
			var steps := 4
			img.fill_rect(Rect2i(cx - hw, y + k, hw * 2, 1), Color("#27384c") if not lit else Color("#ffd98f"))
		_ov_glass(img, x, y + rad, w, h - rad, lit, r)
		img.fill_rect(Rect2i(cx - 2, y, 4, h), frame)
	else:
		img.fill_rect(Rect2i(x - 5, y - 5, w + 10, h + 10), frame)
		_ov_glass(img, x, y, w, h, lit, r)
		img.fill_rect(Rect2i(x + w / 2 - 2, y, 4, h), frame)
		img.fill_rect(Rect2i(x, y + h * 2 / 5, w, 4), frame)
	if not arched:
		# open shutters on both sides
		var sw := int(w * 0.5)
		img.fill_rect(Rect2i(x - 8 - sw, y - 4, sw, h + 8), shut)
		img.fill_rect(Rect2i(x + w + 8, y - 4, sw, h + 8), shut)
		for i in range(0, h + 8, 7):
			img.fill_rect(Rect2i(x - 8 - sw, y - 4 + i, sw, 2), shut.darkened(0.3))
			img.fill_rect(Rect2i(x + w + 8, y - 4 + i, sw, 2), shut.darkened(0.3))
	img.fill_rect(Rect2i(x - 14, y + h + 6, w + 28, 9), Color("#efe7d2"))
	img.fill_rect(Rect2i(x - 14, y + h + 15, w + 28, 6), Color(0, 0, 0, 0.3))


func _ov_balcony_door(img: Image, x: int, y: int, w: int, h: int, shut: Color, lit: bool, r: RandomNumberGenerator) -> void:
	var frame := Color("#ebe4d2")
	var iron := Color("#25272b")
	img.fill_rect(Rect2i(x - 14, y - 10, w + 28, h + 12), Color(0, 0, 0, 0.26))
	img.fill_rect(Rect2i(x - 5, y - 5, w + 10, h - 20), frame)
	_ov_glass(img, x, y, w, h - 30, lit, r)
	img.fill_rect(Rect2i(x + w / 2 - 2, y, 4, h - 30), frame)
	img.fill_rect(Rect2i(x - 36, y + h - 74, 36, h - 120 + 74 - (h - 74) + 74), Color(0, 0, 0, 0))
	# shutter folded on the right
	img.fill_rect(Rect2i(x + w + 6, y - 4, 26, h - 36), shut)
	# balcony slab and iron railing
	img.fill_rect(Rect2i(x - 40, y + h - 12, w + 80, 12), Color("#dcd2b6"))
	img.fill_rect(Rect2i(x - 40, y + h, w + 80, 8), Color(0, 0, 0, 0.3))
	img.fill_rect(Rect2i(x - 38, y + h - 70, w + 76, 5), iron)
	for i in range(x - 38, x + w + 40, 9):
		img.fill_rect(Rect2i(i, y + h - 66, 3, 56), iron)


func _facade_mat(style: int) -> ShaderMaterial:
	var key := "facade%d" % style
	if mats.has(key):
		return mats[key]
	var sh := Shader.new()
	sh.code = FACADE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var stones := ["res://assets/city/stone_a.jpg", "res://assets/city/stone_b.jpg", "res://assets/city/stone_c.jpg"]
	m.set_shader_parameter("stone", load(stones[style]))
	m.set_shader_parameter("overlay", _facade_overlay(style))
	mats[key] = m
	return m


func _tex_mat(path: String, scale_m: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / scale_m
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.92
	return m


func _slab(pos: Vector3, size: Vector3, m: Material) -> void:
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	n.mesh = b
	n.material_override = m
	n.position = pos
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)


func _lp(o: Vector3, yaw: float, l: Vector3) -> Vector3:
	return o + Basis(Vector3.UP, yaw) * l


func _hlabel(text: String, size: int, pos: Vector3, yaw: float, col := Color.WHITE, vis_end := 60.0) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	if heb_font:
		lb.font = heb_font
	lb.font_size = size
	lb.pixel_size = 0.0085
	lb.outline_size = 8
	lb.modulate = col
	lb.outline_modulate = Color(0, 0, 0, 0.85)
	lb.position = pos
	lb.rotation.y = yaw
	lb.visibility_range_end = vis_end
	add_child(lb)
	return lb


func _load_fonts() -> void:
	var base = load("res://assets/city/NotoSansHebrew.ttf")
	if base is Font:
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("weight"): 700}
		heb_font = fv


func _build_world() -> void:
	unit_box.size = Vector3.ONE
	box_arr = _make_box_arr()
	_ground()
	_roads()
	for ix in 4:
		for iz in 4:
			if ix == 2 and iz == 1:
				continue
			if kin and iz == 3:
				continue
			var zx: Array = ZONES[ix]
			var zz: Array = ZONES[iz]
			_zone_block(zx[0], zx[1], zz[0], zz[1])
	_market()
	_places()
	_street_props()
	_furniture()
	if kin:
		_lake()
	aux_marker = _make_marker()
	add_child(aux_marker)
	_hills()
	_commit_groups()
	solid(-HALF - 20.0, -HALF - 20.0, -HALF - 18.0, HALF + 20.0)
	solid(HALF + 18.0, -HALF - 20.0, HALF + 20.0, HALF + 20.0)
	solid(-HALF - 20.0, -HALF - 20.0, HALF + 20.0, -HALF - 18.0)
	solid(-HALF - 20.0, HALF + 18.0, HALF + 20.0, HALF + 20.0)


func _ground() -> void:
	if kin:
		var pav := _tex_mat("res://assets/city/pavers.jpg", 3.0, Color(0.8, 0.76, 0.7))
		_slab(Vector3(0, -0.5, -90.5), Vector3(520, 0.9, 339), pav)
		_slab(Vector3(0, -3.6, 0), Vector3(520, 0.9, 520), mat(Color("#27475a")))
		_slab(Vector3(0, -0.02, -16.5), Vector3(2 * HALF + 12, 0.16, 191), _tex_mat("res://assets/city/pavers.jpg", 2.4, Color(1.1, 1.0, 0.9)))
		return
	_slab(Vector3(0, -0.5, 0), Vector3(520, 0.9, 520), _tex_mat("res://assets/city/pavers.jpg", 3.0, Color(0.8, 0.76, 0.7)))
	_slab(Vector3(0, -0.02, 0), Vector3(2 * HALF + 12, 0.16, 2 * HALF + 12), _tex_mat("res://assets/city/pavers.jpg", 2.4, Color(1.1, 1.0, 0.9)))


func _roads() -> void:
	var am := _tex_mat("res://assets/city/asphalt.jpg", 4.0, Color(1.0, 1.25, 1.55))
	var z1 := 78.0 if kin else HALF + 6.0
	for r in ROADS:
		_slab(Vector3(r, 0.0, (z1 - HALF - 6.0) / 2.0), Vector3(12, 0.04, z1 + HALF + 6.0), am)
		_slab(Vector3(0, 0.0, r), Vector3(2 * HALF + 12, 0.04, 12), am)
	var white := Color("#e8e6dc")
	var curb := Color("#c8bfa8")
	var segs := [[-HALF - 6.0, -72.0], [-60.0, -6.0], [6.0, 60.0], [72.0, HALF + 6.0]]
	for r in ROADS:
		for sg in segs:
			var mid: float = (sg[0] + sg[1]) / 2.0
			var ln: float = sg[1] - sg[0]
			var vend: float = minf(sg[1], z1)
			var vmid: float = (sg[0] + vend) / 2.0
			var vln: float = vend - sg[0]
			for sd in [-5.85, 5.85]:
				if vln > 0.5:
					sbox(curb, Vector3(r + sd, 0.05, vmid), Vector3(0.3, 0.1, vln))
				sbox(curb, Vector3(mid, 0.05, r + sd), Vector3(ln, 0.1, 0.3))
		var s_ := -HALF
		while s_ < HALF:
			var skip := false
			for o in ROADS:
				if absf(s_ - o) < 10.5:
					skip = true
			if not skip:
				if not (kin and s_ > 74.0):
					sbox(white, Vector3(r, 0.04, s_), Vector3(0.18, 0.02, 3.0))
				sbox(white, Vector3(s_, 0.04, r), Vector3(3.0, 0.02, 0.18))
			s_ += 7.0
	for rx in ROADS:
		for rz in ROADS:
			for k in 6:
				var o := -2.5 + k
				sbox(white, Vector3(rx + o, 0.04, rz - 7.4), Vector3(0.55, 0.02, 2.4))
				sbox(white, Vector3(rx + o, 0.04, rz + 7.4), Vector3(0.55, 0.02, 2.4))
				sbox(white, Vector3(rx - 7.4, 0.04, rz + o), Vector3(2.4, 0.02, 0.55))
				sbox(white, Vector3(rx + 7.4, 0.04, rz + o), Vector3(2.4, 0.02, 0.55))


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


func _lot(x0: float, x1: float, z0: float, z1: float, fixed_h := 0.0, hero := false, market_side := "") -> void:
	var gap := 0.35
	var a := x0 + gap
	var b := x1 - gap
	var c := z0 + gap
	var e := z1 - gap
	var floors := 3 + rng.randi() % 5
	if fixed_h > 0.0:
		floors = roundi(fixed_h / 3.2)
	var style := rng.randi() % 3
	var tints := [Color(1.04, 0.98, 0.88), Color(1.0, 0.93, 0.82), Color(0.98, 0.97, 0.93), Color(1.07, 1.0, 0.86), Color(0.94, 0.9, 0.84), Color(1.02, 0.95, 0.9)]
	var tint: Color = tints[rng.randi() % tints.size()]
	var is_shul := x0 < -56.0 and x1 > -45.0 and x1 < -43.0 and z0 <= -33.0 and z1 >= -33.0
	if is_shul:
		floors = 5
		style = 0
		tint = Color(1.1, 1.02, 0.86)
		hero = true
	if absf(c - 9.35) < 0.1 or absf(e + 9.35) < 0.1 or absf(a - 9.35) < 0.1 or absf(b + 9.35) < 0.1:
		hero = true
	var h := 3.2 * floors
	var cx := (a + b) / 2.0
	var cz := (c + e) / 2.0
	_append(_g("f%d" % style, Vector3(cx, 0, cz)), box_arr, Transform3D(Basis.from_scale(Vector3(b - a, h, e - c)), Vector3(cx, h / 2.0, cz)), tint)
	solid(a, c, b, e)
	_roof(a, c, b, e, h)
	_massing(a, c, b, e, h, floors, tint)
	var edges := _edges(a, c, b, e, market_side)
	_shopfronts(edges, a, c, b, e, hero, market_side != "")
	if hero:
		_balconies(edges, a, c, b, e, floors, style)
	if is_shul:
		ssph(Color("#d9b84a"), Vector3(cx, h + 1.0, cz), 3.4, 16, 8, 0.25)
		sbox(Color("#d9b84a"), Vector3(cx, h + 5.2, cz), Vector3(0.12, 2.0, 0.12), 0.0, 0.25)


func _massing(a: float, c: float, b: float, e: float, h: float, floors: int, tint: Color) -> void:
	# real depth on every wall: corner pilasters, mid pilasters, floor ledges, plinth
	var st := Color("#d8cbaa") * tint
	st.a = 1.0
	var d := 0.22
	var cx := (a + b) / 2.0
	var cz := (c + e) / 2.0
	for sx in [a, b]:
		for sz in [c, e]:
			sbox(st.darkened(0.06), Vector3(sx, h / 2.0, sz), Vector3(0.7, h, 0.7))
	var nx := maxi(int((b - a) / 8.0), 1)
	var nz := maxi(int((e - c) / 8.0), 1)
	for i in range(1, nx):
		var x := a + (b - a) * i / nx
		sbox(st, Vector3(x, h / 2.0, c - 0.05), Vector3(0.45, h, 0.3))
		sbox(st, Vector3(x, h / 2.0, e + 0.05), Vector3(0.45, h, 0.3))
	for i in range(1, nz):
		var z := c + (e - c) * i / nz
		sbox(st, Vector3(a - 0.05, h / 2.0, z), Vector3(0.3, h, 0.45))
		sbox(st, Vector3(b + 0.05, h / 2.0, z), Vector3(0.3, h, 0.45))
	for f in range(1, floors):
		var y := 3.2 * f
		sbox(st.darkened(0.04), Vector3(cx, y, c), Vector3(b - a + 0.3, 0.16, 0.34))
		sbox(st.darkened(0.04), Vector3(cx, y, e), Vector3(b - a + 0.3, 0.16, 0.34))
		sbox(st.darkened(0.04), Vector3(a, y, cz), Vector3(0.34, 0.16, e - c + 0.3))
		sbox(st.darkened(0.04), Vector3(b, y, cz), Vector3(0.34, 0.16, e - c + 0.3))
	sbox(st.darkened(0.18), Vector3(cx, 0.35, cz), Vector3(b - a + 0.5, 0.7, e - c + 0.5))


func _roof(a: float, c: float, b: float, e: float, h: float) -> void:
	var stone := Color("#cdbf9f")
	var cx := (a + b) / 2.0
	var cz := (c + e) / 2.0
	sbox(stone.darkened(0.12), Vector3(cx, h + 0.12, cz), Vector3(b - a + 0.5, 0.24, e - c + 0.5))
	var ph := 0.85
	var py := h + 0.24 + ph / 2.0
	sbox(stone, Vector3(cx, py, c + 0.14), Vector3(b - a, ph, 0.28))
	sbox(stone, Vector3(cx, py, e - 0.14), Vector3(b - a, ph, 0.28))
	sbox(stone, Vector3(a + 0.14, py, cz), Vector3(0.28, ph, e - c - 0.56))
	sbox(stone, Vector3(b - 0.14, py, cz), Vector3(0.28, ph, e - c - 0.56))
	var rcols := [Color("#a39d90"), Color("#b3ad9e"), Color("#968f82"), Color("#aaa59a")]
	sbox(rcols[rng.randi() % rcols.size()], Vector3(cx, h + 0.26, cz), Vector3(b - a - 0.3, 0.04, e - c - 0.3))
	var ry := h + 0.28
	var nprops := 1 + rng.randi() % 3
	for k in nprops:
		var px := cx + rng.randf_range(-(b - a) / 3.0, (b - a) / 3.0)
		var pz := cz + rng.randf_range(-(e - c) / 3.0, (e - c) / 3.0)
		match rng.randi() % 4:
			0:
				for lx in [-0.45, 0.45]:
					for lz in [-0.45, 0.45]:
						sbox(Color("#5a5a5e"), Vector3(px + lx, ry + 0.4, pz + lz), Vector3(0.08, 0.8, 0.08))
				scyl(Color("#c9c9c9"), Vector3(px, ry + 1.45, pz), 0.7, 0.7, 1.3, 10)
				scyl(Color("#9a9a9a"), Vector3(px, ry + 2.15, pz), 0.55, 0.7, 0.14, 10)
			1:
				var tb := Basis(Vector3.RIGHT, -0.55)
				sbox(Color("#1d3a63"), Vector3(px, ry + 0.85, pz), Vector3(1.8, 0.08, 1.2), 0.0, 0.0, tb)
				sbox(Color("#b9b9b9"), Vector3(px, ry + 0.95, pz + 0.75), Vector3(1.8, 0.9, 0.08))
				scyl(Color("#d8d8d8"), Vector3(px + 1.6, ry + 0.8, pz), 0.35, 0.35, 1.2, 8)
			2:
				sbox(Color("#777777"), Vector3(px, ry + 1.8, pz), Vector3(0.08, 3.0, 0.08))
				sbox(Color("#777777"), Vector3(px, ry + 2.6, pz), Vector3(1.0, 0.06, 0.06))
				sbox(Color("#777777"), Vector3(px, ry + 2.2, pz), Vector3(0.7, 0.06, 0.06))
			_:
				sbox(Color("#bdbdbd"), Vector3(px, ry + 0.4, pz), Vector3(1.1, 0.8, 0.8))
				sbox(Color("#6a6a6a"), Vector3(px, ry + 0.4, pz + 0.41), Vector3(0.9, 0.6, 0.02))


func _edges(a: float, c: float, b: float, e: float, market_side: String) -> Array:
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
	if market_side != "" and not edges.has(market_side):
		edges.append(market_side)
	return edges


func _edge_frame(ed: String, a: float, c: float, b: float, e: float) -> Dictionary:
	match ed:
		"N":
			return {"n": Vector3(0, 0, -1), "along": Vector3(1, 0, 0), "start": Vector3(a, 0, c), "len": b - a}
		"S":
			return {"n": Vector3(0, 0, 1), "along": Vector3(1, 0, 0), "start": Vector3(a, 0, e), "len": b - a}
		"W":
			return {"n": Vector3(-1, 0, 0), "along": Vector3(0, 0, 1), "start": Vector3(a, 0, c), "len": e - c}
	return {"n": Vector3(1, 0, 0), "along": Vector3(0, 0, 1), "start": Vector3(b, 0, c), "len": e - c}


func _shopfronts(edges: Array, a: float, c: float, b: float, e: float, hero: bool, arch: bool) -> void:
	for ed in edges:
		var f := _edge_frame(ed, a, c, b, e)
		var n: Vector3 = f["n"]
		var along: Vector3 = f["along"]
		var start: Vector3 = f["start"]
		var length: float = f["len"]
		var yaw := atan2(n.x, n.z)
		var count := maxi(1, int(length / 5.0))
		var w := length / count
		for k in count:
			var o := start + along * (w * (k + 0.5))
			if _near_door(o):
				continue
			_storefront(o, yaw, w, hero, arch)


func _near_door(o: Vector3) -> bool:
	for key in PLACES:
		var pl_: Dictionary = PLACES[key]
		if pl_["door"]:
			var st: Vector3 = pl_["stand"]
			if Vector2(o.x - st.x, o.z - st.z).length() < 4.6:
				return true
	return false


func _storefront(o: Vector3, yaw: float, w: float, hero: bool, arch: bool) -> void:
	var cols := [Color("#c9473b"), Color("#2f6fb5"), Color("#e0a63a"), Color("#3a9a5e"), Color("#8a4fb0"), Color("#d96a2a")]
	var col: Color = cols[rng.randi() % cols.size()]
	var glows := [Color("#ffd9a0"), Color("#ffe6b8"), Color("#ffc890"), Color("#fff0d0"), Color("#ffd0b0")]
	var gc: Color = glows[rng.randi() % glows.size()]
	var dark := Color("#26272b")
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0)
	if arch:
		sbox(Color("#d9cdb0"), _lp(o, yaw, Vector3(0, 1.5, 0.07)), Vector3(w - 0.5, 3.0, 0.1), yaw)
		sbox(dark, _lp(o, yaw, Vector3(0, 1.0, 0.14)), Vector3(2.8, 2.0, 0.1), yaw)
		scyl(dark, _lp(o, yaw, Vector3(0, 2.0, 0.14)), 1.4, 1.4, 0.1, 16, 0.0, rot)
		sbox(gc, _lp(o, yaw, Vector3(0, 0.95, 0.2)), Vector3(2.5, 1.9, 0.04), yaw, 0.45)
		scyl(gc, _lp(o, yaw, Vector3(0, 1.9, 0.2)), 1.25, 1.25, 0.04, 16, 0.45, rot)
		sbox(Color("#8a6a44"), _lp(o, yaw, Vector3(0, 0.45, 0.55)), Vector3(2.6, 0.9, 0.8), yaw)
		if hero:
			var tx: String = HEB_SHOPS[rng.randi() % HEB_SHOPS.size()]
			sbox(Color("#1e1a16"), _lp(o, yaw, Vector3(0, 3.7, 0.12)), Vector3(w - 0.8, 0.6, 0.12), yaw)
			_hlabel(tx, 64, _lp(o, yaw, Vector3(0, 3.7, 0.2)), yaw, Color("#ffe9b0"), 40.0)
		return
	sbox(dark, _lp(o, yaw, Vector3(0, 1.4, 0.1)), Vector3(w - 0.6, 2.8, 0.2), yaw)
	sbox(gc, _lp(o, yaw, Vector3(0, 1.3, 0.22)), Vector3(w - 1.2, 2.1, 0.05), yaw, 0.3)
	var stripes := 4 if hero else 2
	var sw := (w - 0.4) / float(stripes)
	for i in stripes:
		var sx := (i - (stripes - 1) / 2.0) * sw
		var sc := col if i % 2 == 0 else Color("#f2eee2")
		sbox(sc, _lp(o, yaw, Vector3(sx, 3.05, 0.8)), Vector3(sw, 0.08, 1.5), yaw, 0.0, Basis(Vector3.RIGHT, 0.2))
	if hero:
		for sgn in [-1.0, 1.0]:
			sbox(dark, _lp(o, yaw, Vector3(sgn * (w - 1.2) / 6.0, 1.3, 0.27)), Vector3(0.07, 2.1, 0.07), yaw)
		sbox(Color("#8a8070"), _lp(o, yaw, Vector3(0, 0.25, 0.22)), Vector3(w - 0.6, 0.5, 0.16), yaw)
		sbox(Color("#1e1a16"), _lp(o, yaw, Vector3(0, 3.65, 0.1)), Vector3(w - 0.6, 0.6, 0.12), yaw)
		var tx2: String = HEB_SHOPS[rng.randi() % HEB_SHOPS.size()]
		_hlabel(tx2, 64, _lp(o, yaw, Vector3(0, 3.65, 0.18)), yaw, Color("#ffe9b0"), 40.0)


func _balconies(edges: Array, a: float, c: float, b: float, e: float, floors: int, style: int) -> void:
	var cidx := ((2 - style) % 4 + 4) % 4
	var iron := Color("#25272b")
	var slab := Color("#dcd2b6")
	for ed in edges:
		var f := _edge_frame(ed, a, c, b, e)
		var n: Vector3 = f["n"]
		var along: Vector3 = f["along"]
		var start: Vector3 = f["start"]
		var length: float = f["len"]
		var yaw := atan2(n.x, n.z)
		var u0 := start.x if absf(along.x) > 0.5 else start.z
		var k := floori((u0 + 1.5 - 4.0 * cidx - 2.0) / 16.0)
		var placed := 0
		while placed < 2:
			var u := 16.0 * k + 4.0 * cidx + 2.0
			k += 1
			if u < u0 + 1.5:
				continue
			if u > u0 + length - 1.5:
				break
			placed += 1
			var o := start + along * (u - u0)
			for fl in range(1, mini(floors, 5)):
				var y := fl * 3.2 + 0.1
				sbox(slab, _lp(o, yaw, Vector3(0, y, 0.5)), Vector3(2.9, 0.16, 1.0), yaw)
				sbox(iron, _lp(o, yaw, Vector3(0, y + 1.0, 0.98)), Vector3(2.9, 0.05, 0.05), yaw)
				for sx in [-1.42, 1.42]:
					sbox(iron, _lp(o, yaw, Vector3(sx, y + 1.0, 0.5)), Vector3(0.05, 0.05, 1.0), yaw)
					sbox(iron, _lp(o, yaw, Vector3(sx, y + 0.55, 0.98)), Vector3(0.05, 0.9, 0.05), yaw)
				for i in 5:
					sbox(iron, _lp(o, yaw, Vector3(-1.2 + 0.6 * i, y + 0.55, 0.98)), Vector3(0.03, 0.85, 0.03), yaw)


func _market() -> void:
	_slab(Vector3(33, 0.03, -33), Vector3(22, 0.08, 48), _tex_mat("res://assets/city/cobble.jpg", 2.6, Color(1.15, 1.05, 0.95)))
	for i in 3:
		var za := -57.0 + i * 16.0
		_lot(9.0, 22.0, za, za + 16.0, 0.0, true, "E")
		_lot(44.0, 57.0, za, za + 16.0, 0.0, true, "W")
	var scol := [Color("#c9473b"), Color("#2f6fb5"), Color("#e0a63a"), Color("#3a9a5e"), Color("#e8e4d8"), Color("#8a4fb0")]
	var fruit := [Color("#d9382c"), Color("#f08a24"), Color("#e8d23a"), Color("#7ab648"), Color("#b3262e"), Color("#5a2a6a"), Color("#4aa84a"), Color("#a82a3a"), Color("#f2a65a")]
	var wood := Color("#7a5634")
	var crate := Color("#b0905c")
	for side in 2:
		var cx := 25.75 if side == 0 else 40.25
		var front := 27.5 if side == 0 else 38.5
		var dirn := 1.0 if side == 0 else -1.0
		for k in 8:
			var z: float = -54.0 + k * 6.0
			var col: Color = scol[(k + side * 3) % scol.size()]
			var special := ""
			var heb: String = HEB_STALLS[(k + side * 3) % HEB_STALLS.size()]
			if side == 0 and k == 4:
				special = "fish"
				col = PLACES["fish"]["col"]
				heb = "דגים"
			if side == 1 and k == 2:
				special = "flowers"
				col = PLACES["flowers"]["col"]
				heb = "פרחים"
			sbox(wood, Vector3(cx, 0.45, z), Vector3(3.5, 0.9, 4.2))
			sbox(wood.darkened(0.3), Vector3(cx - dirn * 1.2, 1.4, z), Vector3(0.9, 2.8, 4.2))
			for pz in [-2.0, 2.0]:
				sbox(Color("#4a3a2a"), Vector3(front + dirn * 0.1, 1.6, z + pz), Vector3(0.12, 3.2, 0.12))
			var sw := 4.4 / 4.0
			for i in 4:
				var sc := col if i % 2 == 0 else Color("#f2eee2")
				sbox(sc, Vector3(front + dirn * 0.6, 3.3, z - 2.2 + sw * (i + 0.5)), Vector3(2.8, 0.1, sw), 0.0, 0.0, Basis(Vector3.BACK, -dirn * 0.2))
			if special == "fish":
				sbox(Color("#dfeaf2"), Vector3(front - dirn * 0.5, 0.98, z), Vector3(1.3, 0.16, 3.6))
				for i in 9:
					var fz := z - 1.5 + i * 0.37
					sbox(Color("#b8c4cf"), Vector3(front - dirn * 0.5 + (i % 2) * 0.25 - 0.12, 1.1, fz), Vector3(0.5, 0.09, 0.17), 0.3 * (i % 3 - 1))
					sbox(Color("#cf4a3a"), Vector3(front - dirn * 0.5 + (i % 2) * 0.25 - 0.12, 1.16, fz), Vector3(0.2, 0.04, 0.12), 0.3 * (i % 3 - 1))
			elif special == "flowers":
				var fcols := [Color("#d6457f"), Color("#f2c230"), Color("#f2f2f2"), Color("#8a4fb0"), Color("#e8603a")]
				for i in 5:
					var bz := z - 1.7 + i * 0.85
					scyl(Color("#6a6e72"), Vector3(front - dirn * 0.5, 1.15, bz), 0.28, 0.22, 0.5, 8)
					for j in 4:
						ssph(fcols[(i + j) % fcols.size()], Vector3(front - dirn * 0.5 + (j % 2 - 0.5) * 0.25, 1.52 + (j / 2) * 0.12, bz + ((j + i) % 2 - 0.5) * 0.25), 0.15, 6, 4)
			else:
				for ci in 3:
					var zc := z - 1.4 + ci * 1.4
					sbox(crate, Vector3(front - dirn * 0.5, 0.98, zc), Vector3(0.95, 0.2, 1.1))
					var fc: Color = fruit[(k * 2 + side + ci * 3) % fruit.size()]
					for i in 6:
						ssph(fc, Vector3(front - dirn * 0.5 + (i % 2 - 0.5) * 0.4, 1.2, zc - 0.4 + (i / 2) * 0.4), 0.13, 6, 4)
			for i in 2:
				sbox(crate, Vector3(cx - dirn * 0.4, 1.0 + i * 0.3, z + 1.2 * (1 - 2 * i)), Vector3(0.7, 0.28, 0.9), 0.2 * i)
			sbox(Color("#241c14"), Vector3(cx - dirn * 0.72, 3.95, z), Vector3(0.1, 0.7, 3.4))
			_hlabel(heb, 72, Vector3(cx - dirn * 0.72 + dirn * 0.08, 3.95, z), dirn * PI / 2.0, Color("#ffe9b0"), 45.0)
			solid(cx - 1.75, z - 2.1, cx + 1.75, z + 2.1)
	# glass and steel canopy
	var hw := 6.4
	var spring := 4.3
	var rise := 2.4
	var rr := (hw * hw + rise * rise) / (2.0 * rise)
	var cy := spring + rise - rr
	var n := 10
	var pts := []
	for i in n + 1:
		var x := -hw + 2.0 * hw * i / n
		pts.append(Vector2(x, cy + sqrt(rr * rr - x * x)))
	var steel := Color("#3b4a58")
	for rb in 10:
		var zr := -55.2 + rb * 4.8
		for i in n:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid := (p0 + p1) / 2.0
			var ln := p0.distance_to(p1)
			var ang := atan2(p1.y - p0.y, p1.x - p0.x)
			sbox(steel, Vector3(33.0 + mid.x, mid.y, zr), Vector3(ln + 0.05, 0.16, 0.16), 0.0, 0.0, Basis(Vector3.BACK, ang))
		for sx in [-hw, hw]:
			sbox(steel, Vector3(33.0 + sx, spring / 2.0, zr), Vector3(0.18, spring, 0.18))
	for i in n + 1:
		var q: Vector2 = pts[i]
		sbox(steel, Vector3(33.0 + q.x, q.y, -33.0), Vector3(0.08, 0.08, 46.5))
	for bay in 9:
		var zc := -55.2 + bay * 4.8 + 2.4
		for i in n:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid := (p0 + p1) / 2.0
			var ln := p0.distance_to(p1)
			var ang := atan2(p1.y - p0.y, p1.x - p0.x)
			sglass(Color(0.74, 0.88, 1.0, 0.26), Vector3(33.0 + mid.x, mid.y + 0.04, zc), Vector3(ln, 0.03, 4.6), 0.0, Basis(Vector3.BACK, ang))
	# string lights
	for lx in [-3.4, 0.0, 3.4]:
		var ly := cy + sqrt(rr * rr - lx * lx) - 0.9
		sbox(Color("#222222"), Vector3(33.0 + lx, ly + 0.05, -33.0), Vector3(0.02, 0.02, 44.0))
		var zz := -55.0
		while zz < -11.0:
			ssph(Color("#ffd68a"), Vector3(33.0 + lx, ly - 0.08, zz), 0.09, 6, 3, 1.4)
			zz += 1.25
	# entrance gantries
	for sd in 2:
		var gz := -9.4 if sd == 0 else -56.6
		var dz := 1.0 if sd == 0 else -1.0
		var yawg := 0.0 if sd == 0 else PI
		sbox(Color("#1f3f7a"), Vector3(33, 7.8, gz), Vector3(15, 2.6, 0.3))
		for sx in [-7.0, 7.0]:
			sbox(Color("#4a4a52"), Vector3(33.0 + sx, 3.9, gz), Vector3(0.3, 7.8, 0.3))
		_hlabel(str(cfg.get("market_he", "מחנה יהודה")), 120, Vector3(33, 8.25, gz + 0.2 * dz), yawg, Color.WHITE, 120.0)
		var lb := Label3D.new()
		lb.text = str(cfg.get("market_en", "MACHANE YEHUDA"))
		lb.font_size = 56
		lb.pixel_size = 0.011
		lb.outline_size = 8
		lb.position = Vector3(33, 7.0, gz + 0.2 * dz)
		lb.rotation.y = yawg
		lb.visibility_range_end = 120.0
		add_child(lb)
	# scattered crates in the walkways
	for i in 14:
		var cxs := 22.9 if i % 2 == 0 else 43.1
		var czs := -55.0 + i * 3.8
		sbox(crate, Vector3(cxs, 0.3, czs), Vector3(0.6, 0.55, 0.8), rng.randf() * 0.5)
		sbox(crate.darkened(0.1), Vector3(cxs + 0.05, 0.85, czs), Vector3(0.55, 0.5, 0.7), rng.randf() * 0.5)


func _make_marker() -> Node3D:
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
	mk.visible = false
	return mk


const WATER_SHADER := """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w = sin(wp.x * 0.7 + TIME * 1.2) * 0.5 + sin(wp.z * 0.9 - TIME * 1.5) * 0.5 + sin((wp.x + wp.z) * 0.35 + TIME * 0.8);
	float sp = sin(wp.x * 2.3 + TIME * 2.1) * sin(wp.z * 2.7 - TIME * 1.7);
	vec3 deep = vec3(0.05, 0.27, 0.43);
	vec3 shallow = vec3(0.16, 0.56, 0.68);
	ALBEDO = mix(deep, shallow, clamp(0.5 + 0.18 * w, 0.0, 1.0)) + vec3(max(sp, 0.0) * 0.05);
	ROUGHNESS = 0.1;
	METALLIC = 0.3;
	SPECULAR = 0.9;
}
"""


## Kinneret waterfront for level 2: quay wall, promenade, pier, lake, moored boats.
func _lake() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	var wm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(560, 190)
	wm.mesh = pm
	wm.material_override = water_mat
	wm.position = Vector3(0, -0.42, LAKE_Z + 95.0)
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wm)
	var stone := Color("#b3a88e")
	sbox(stone.darkened(0.1), Vector3(0, -0.4, LAKE_Z + 0.2), Vector3(2 * HALF + 40, 0.95, 0.7))
	sbox(stone, Vector3(0, 0.12, LAKE_Z - 0.1), Vector3(2 * HALF + 40, 0.12, 0.9))
	# promenade: lamps, benches, bollards, palms
	var x := -100.0
	var idx := 0
	while x <= 100.0:
		if absf(x - 21.0) > 4.0:
			sbox(Color("#4b4f58"), Vector3(x, 2.4, LAKE_Z - 1.6), Vector3(0.14, 4.8, 0.14))
			sbox(Color("#fff2c0"), Vector3(x, 4.85, LAKE_Z - 1.6), Vector3(0.32, 0.14, 0.32), 0.0, 0.6)
			if idx % 2 == 0:
				var wood := Color("#7a5634")
				sbox(wood, Vector3(x + 5.0, 0.5, LAKE_Z - 2.6), Vector3(1.7, 0.08, 0.5))
				sbox(wood, Vector3(x + 5.0, 0.85, LAKE_Z - 2.85), Vector3(1.7, 0.35, 0.06))
				for sx in [-0.7, 0.7]:
					sbox(Color("#2b2d31"), Vector3(x + 5.0 + sx, 0.25, LAKE_Z - 2.6), Vector3(0.06, 0.5, 0.4))
			else:
				scyl(Color("#6b4a2e"), Vector3(x + 5.0, 2.3, LAKE_Z - 3.2), 0.16, 0.22, 4.6, 6)
				for k in 6:
					var a := TAU * k / 6.0
					var fr := Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.9)
					sbox(Color("#3f7d3a"), Vector3(x + 5.0, 4.7, LAKE_Z - 3.2) + Vector3(cos(a), -0.1, sin(a)) * 0.9, Vector3(2.0, 0.07, 0.5), 0.0, 0.0, fr)
		idx += 1
		x += 18.0
	# pier
	var plank := mat(Color("#8a6a45"))
	_slab(Vector3(PIER.position.x + PIER.size.x / 2.0, 0.0, PIER.position.y + PIER.size.y / 2.0), Vector3(PIER.size.x, 0.12, PIER.size.y), plank)
	for k in 5:
		var pz := PIER.position.y + 1.0 + k * 3.0
		for sx in [PIER.position.x + 0.1, PIER.position.x + PIER.size.x - 0.1]:
			scyl(Color("#5a432c"), Vector3(sx, -0.8, pz), 0.14, 0.14, 1.8, 6)
			sbox(Color("#cfcfcf"), Vector3(sx, 0.35, pz), Vector3(0.18, 0.4, 0.18))
	# moored fishing boats
	var bc := [Color("#c24a3a"), Color("#2f6fb5"), Color("#e0a63a"), Color("#3a9a5e"), Color("#e8e4d8")]
	var bxs := [-70.0, -52.0, -34.0, 0.0, 44.0, 62.0, 80.0]
	for i in bxs.size():
		var bx: float = bxs[i]
		var by := -0.3
		var c: Color = bc[i % bc.size()]
		sbox(c, Vector3(bx, by + 0.15, LAKE_Z + 3.2), Vector3(1.7, 0.7, 4.8))
		sbox(Color("#f2f2f2"), Vector3(bx, by + 0.58, LAKE_Z + 3.2), Vector3(1.6, 0.14, 4.7))
		sbox(Color("#f2f2f2"), Vector3(bx, by + 1.05, LAKE_Z + 4.0), Vector3(1.2, 0.9, 1.5))
		sglass(Color(0.2, 0.3, 0.4, 0.5), Vector3(bx, by + 1.1, LAKE_Z + 3.22), Vector3(1.22, 0.42, 0.04))
		scyl(Color("#555555"), Vector3(bx, by + 2.0, LAKE_Z + 2.4), 0.04, 0.04, 2.4, 6)
	# keep walkers and cars out of the water; boats use their own bounds
	water_solids.append(Rect2(-HALF - 20.0, LAKE_Z + 0.4, PIER.position.x + HALF + 20.0, 90.0))
	water_solids.append(Rect2(PIER.end.x, LAKE_Z + 0.4, HALF + 20.0 - PIER.end.x, 90.0))
	water_solids.append(Rect2(PIER.position.x, PIER.end.y, PIER.size.x, 60.0))


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
		_hlabel(p["he"], 80, lb.position + Vector3(0, 1.0, 0) + n * 0.01, yaw, Color("#ffe9b0"), 80.0)
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
						var gcol := Color("#5a8a3e") if (int(pos.x + pos.z) % 2 == 0) else Color("#6e9a44")
						ssph(gcol, pos + Vector3(0, 4.4, 0), 1.35, 8, 4)
						ssph(gcol.lightened(0.12), pos + Vector3(0.7, 3.9, 0.3), 1.0, 8, 4)
						ssph(gcol.darkened(0.08), pos + Vector3(-0.6, 4.0, -0.4), 1.05, 8, 4)
						solid(pos.x - 0.25, pos.z - 0.25, pos.x + 0.25, pos.z + 0.25)
				s += 36.0
	# street-name signs
	var street_names: Array = cfg.get("streets", [])
	var sni := -1
	for sn in STREETS:
		sni += 1
		var pos: Vector3 = sn["pos"]
		sbox(Color("#4b4f58"), pos + Vector3(0, 1.4, 0), Vector3(0.1, 2.8, 0.1))
		sbox(Color("#1f4f9a"), pos + Vector3(0, 2.7, 0), Vector3(2.6, 0.42, 0.06), float(sn["yaw"]))
		var lb := Label3D.new()
		lb.text = str(street_names[sni]) if sni < street_names.size() else str(sn["text"])
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


func _furniture() -> void:
	var wood := Color("#7a5634")
	var iron := Color("#2b2d31")
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 200:
		tries += 1
		var r: float = ROADS[rng.randi() % 3]
		var side := -8.3 if rng.randf() < 0.5 else 8.3
		var along := rng.randf_range(-95.0, 95.0)
		var vertical := rng.randf() < 0.5
		var pos := Vector3(r + side, 0, along) if vertical else Vector3(along, 0, r + side)
		var near_x := false
		for o in ROADS:
			if absf(along - o) < 13.0:
				near_x = true
		if near_x or _in_market(pos) or _near_place(pos, 6.0):
			continue
		placed += 1
		var yaw := PI / 2.0 if vertical else 0.0
		var face := 1.0 if side < 0.0 else -1.0
		var back := Vector3(0, 0.85, 0.2 * face) if not vertical else Vector3(0.2 * face, 0.85, 0)
		sbox(wood, pos + Vector3(0, 0.5, 0), Vector3(1.6, 0.08, 0.45), yaw)
		sbox(wood, pos + back, Vector3(1.6, 0.35, 0.06), yaw)
		for sx in [-0.7, 0.7]:
			var off := Vector3(sx, 0.25, 0) if not vertical else Vector3(0, 0.25, sx)
			sbox(iron, pos + off, Vector3(0.06, 0.5, 0.4), yaw)
	for i in 22:
		var r: float = ROADS[rng.randi() % 3]
		var side := -6.7 if rng.randf() < 0.5 else 6.7
		var along := rng.randf_range(-95.0, 95.0)
		var pos := Vector3(r + side, 0, along) if rng.randf() < 0.5 else Vector3(along, 0, r + side)
		var near_x := false
		for o in ROADS:
			if absf(along - o) < 12.0:
				near_x = true
		if near_x or _in_market(pos) or _near_place(pos, 5.0):
			continue
		scyl(Color("#2f5d3a"), pos + Vector3(0, 0.45, 0), 0.25, 0.22, 0.9, 8)
		scyl(Color("#1f3d27"), pos + Vector3(0, 0.93, 0), 0.27, 0.27, 0.06, 8)
	# traffic lights at every crossing
	for rx in ROADS:
		for rz in ROADS:
			for sx in [-6.7, 6.7]:
				for sz in [-6.7, 6.7]:
					var p0 := Vector3(rx + sx, 0, rz + sz)
					sbox(iron, p0 + Vector3(0, 1.7, 0), Vector3(0.1, 3.4, 0.1))
					sbox(Color("#1a1a1c"), p0 + Vector3(0, 3.2, 0), Vector3(0.3, 0.85, 0.3))
					sbox(Color("#ff3b30"), p0 + Vector3(0, 3.5, 0.16), Vector3(0.16, 0.16, 0.04), 0.0, 0.9)
					sbox(Color("#ffb020"), p0 + Vector3(0, 3.2, 0.16), Vector3(0.16, 0.16, 0.04), 0.0, 0.2)
					sbox(Color("#30d158"), p0 + Vector3(0, 2.9, 0.16), Vector3(0.16, 0.16, 0.04), 0.0, 0.2)


func _near_place(p: Vector3, r: float) -> bool:
	for key in PLACES:
		var st: Vector3 = PLACES[key]["stand"]
		if Vector2(st.x - p.x, st.z - p.z).length() < r:
			return true
	return false


func _in_market(p: Vector3) -> bool:
	if kin and p.z > 74.0:
		return true
	return p.x > 8.0 and p.x < 58.0 and p.z > -58.0 and p.z < -8.0


func _near_start(pos: Vector3) -> bool:
	var st: Dictionary = cfg.get("start", {})
	var cp: Vector3 = st.get("car", Vector3(4.6, 0, 46.0))
	return Vector2(pos.x - cp.x, pos.z - cp.z).length() < 9.0


func _parked_car(pos: Vector3, yaw: float, col: Color) -> void:
	if _near_start(pos):
		return
	sbox(col, pos + Vector3(0, 0.62, 0), Vector3(1.8, 0.7, 4.0), yaw)
	var off := Vector3(0, 1.2, -0.2)
	off = Basis(Vector3.UP, yaw) * off
	sbox(Color("#1b2430"), pos + off, Vector3(1.6, 0.55, 2.0), yaw)
	sbox(Color("#111111"), pos + Vector3(0, 0.3, 0), Vector3(1.86, 0.4, 3.2), yaw)
	var half := Vector2(1.0, 2.1) if absf(yaw) < 0.1 else Vector2(2.1, 1.0)
	solid(pos.x - half.x, pos.z - half.y, pos.x + half.x, pos.z + half.y)


func _hills() -> void:
	for i in 22:
		var a := TAU * i / 22.0
		var rad := 225.0 + rng.randf_range(-8.0, 20.0)
		var h := rng.randf_range(16.0, 36.0)
		var col := Color("#c4b690").lerp(Color("#9c9a76"), rng.randf())
		scyl(col, Vector3(cos(a) * rad, h / 2.0 - 1.0, sin(a) * rad), rng.randf_range(10.0, 22.0), rng.randf_range(48.0, 70.0), h, 9)


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
		for sx in [-0.125, 0.125]:
			_mi(root, _boxm(Vector3(0.02, 0.13, 0.02)), Color("#3a2a1c"), Vector3(sx, 1.58, -0.03))
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
	var hold: bool = p.get("hold", false)
	if hold:
		arms[1].rotation.x = lerpf(arms[1].rotation.x, 1.15, 0.3)
	if speed < 0.05:
		for i in 2:
			legs[i].rotation.x = lerpf(legs[i].rotation.x, 0.0, 0.3)
			if not (i == 1 and hold):
				arms[i].rotation.x = lerpf(arms[i].rotation.x, 0.0, 0.3)
		return
	p["phase"] = float(p["phase"]) + delta * speed * 2.6
	var s := sin(float(p["phase"])) * 0.7
	legs[0].rotation.x = s
	legs[1].rotation.x = -s
	arms[0].rotation.x = -s * 0.8
	if not hold:
		arms[1].rotation.x = s * 0.8


func yaw_for(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _actors() -> void:
	# player
	pl = Node3D.new()
	pl_person = _make_person("player", rng)
	pl.add_child(pl_person["root"])
	var start: Dictionary = cfg.get("start", {})
	pl.position = start.get("player", Vector3(7.5, 0, 30.0))
	pl_yaw = float(start.get("pyaw", PI))
	add_child(pl)
	cam_yaw = float(start.get("cam", 0.0))
	# the family car
	car_p = Vehicles.make_car(Color("#e9ecef"))
	van = car_p["root"]
	van.position = start.get("car", Vector3(4.6, 0, 46.0))
	van_yaw = float(start.get("cyaw", 0.0))
	van.rotation.y = van_yaw
	add_child(van)
	trunk_vis = Node3D.new()
	van.add_child(trunk_vis)
	seat_bag = Node3D.new()
	seat_bag.position = car_p["seat_pass"]
	van.add_child(seat_bag)
	if kin:
		boat_p = Vehicles.make_boat()
		boat = boat_p["root"]
		boat.position = Vector3(DOCK.x, -0.5, DOCK.z)
		boat_yaw = PI
		boat.rotation.y = boat_yaw
		add_child(boat)
		cargo_vis = Node3D.new()
		(boat_p["hull"] as Node3D).add_child(cargo_vis)
	_refresh_bag()
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
		if kin and p.z > 74.0:
			p.z = 60.0
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
	return Vector3(clampf(p.x, -HALF + 2.0, HALF - 2.0), p.y, clampf(p.z, -HALF + 2.0, (73.0 if kin else HALF - 2.0)))


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
	drive_ui = DriveControls.new()
	ui.add_child(drive_ui)
	drive_ui.set_scheme(int(Profile.get_setting("drive_controls", 2)))
	drive_ui.visible = false
	drive_ui.view_pressed.connect(_cycle_view)
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
	var m: Dictionary = missions[i]
	var kind: String = m.get("kind", "stand")
	if kind == "stow":
		return _trunk_spot()
	if kind == "board":
		return Vector3(boat.position.x, 0, boat.position.z) if boat != null else Vector3.ZERO
	if m.has("pos"):
		return m["pos"]
	return PLACES[m["place"]]["stand"]


func _actor_pos() -> Vector3:
	if in_boat:
		return boat.position
	return van.position if in_van else pl.position


func _trunk_spot() -> Vector3:
	var o := Basis(Vector3.UP, van_yaw) * Vector3(0, 0, 3.4)
	return Vector3(van.position.x + o.x, 0, van.position.z + o.z)


func _total_items() -> int:
	var n := 0
	for m in missions:
		if str(m.get("item", "")) != "":
			n += 1
	return n


func _hud_update() -> void:
	if l_time == null:
		return
	var tl := maxf(time_left, 0.0)
	l_time.text = "Candle lighting in %d:%02d" % [int(tl) / 60, int(tl) % 60]
	l_time.add_theme_color_override("font_color", Color("#ff6b6b") if tl < 60.0 else Color.WHITE)
	var gm := 14.0 * 60.0 + 45.0 + (1.0 - tl / time_total) * 80.0
	l_clock.text = "%d:%02d pm  ·  Erev Shabbos" % [int(gm) / 60 - 12, int(gm) % 60]
	if mi < missions.size():
		l_mission.text = "%d/%d  %s" % [mi + 1, missions.size(), missions[mi]["text"]]
	l_coins.text = "Shekels: %d   Bag: %d   Trunk: %d" % [coins, bag.size(), trunk.size()]


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
	if kin:
		mm.draw_rect(Rect2(o + Vector2(-HALF, LAKE_Z) * k, Vector2(2.0 * HALF * k, (HALF + 4.0 - LAKE_Z) * k)), Color(0.2, 0.5, 0.8, 0.55))
		if not in_boat:
			mm.draw_rect(Rect2(o + Vector2(boat.position.x, boat.position.z) * k - Vector2(2, 2), Vector2(4, 4)), Color("#7ad0ff"))
	if not in_van:
		mm.draw_rect(Rect2(o + Vector2(van.position.x, van.position.z) * k - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
	var ap := _actor_pos()
	var heading := boat_yaw if in_boat else (van_yaw if in_van else pl_yaw)
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
		_overlay("Paused", "On foot: joystick to walk. In a vehicle: gas and brake pedals plus your steering style. Drag the right side to look. The yellow button buys, opens the trunk, gets in and out.", [
			["Resume", func(): _pause(false)],
			["Walking controls: " + names[int(controls.mode)], func():
				var nm := controls.cycle_mode()
				Profile.set_setting("controls", int(controls.mode))
				_pause(true)],
			["Car and boat controls: " + DriveControls.NAMES[drive_ui.scheme], func():
				var ni: int = (int(drive_ui.scheme) + 1) % 4
				Profile.set_setting("drive_controls", ni)
				drive_ui.set_scheme(ni)
				controls.exclude_rects = drive_ui.exclusion_rects()
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
		busy = maxf(busy - delta, 0.0)
		_move(delta)
		_pickups(delta)
		_check_auto()
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
		m.visible = mi < missions.size() and str(missions[mi].get("place", "")) == key
		if m.visible:
			(m.get_child(0) as Node3D).visible = m.position.distance_to(_actor_pos()) > 3.5
			var cone: Node3D = m.get_node("cone")
			cone.position.y = 8.0 + sin(t * 4.0) * 0.4
	if aux_marker != null:
		var am: Dictionary = missions[mi] if mi < missions.size() else {}
		var ak: String = am.get("kind", "stand")
		aux_marker.visible = phase != "over" and ak in ["reach", "boat_stand", "stow", "board"]
		if aux_marker.visible:
			aux_marker.position = _stand_pos(mi)
			(aux_marker.get_child(0) as Node3D).visible = aux_marker.position.distance_to(_actor_pos()) > 3.5
			(aux_marker.get_node("cone") as Node3D).position.y = 8.0 + sin(t * 4.0) * 0.4


func _move(delta: float) -> void:
	var driving := in_van or in_boat
	var mv := controls.get_move()
	if mv.length() > 1.0:
		mv = mv.normalized()
	var look := controls.take_look()
	if look != Vector2.ZERO:
		if driving and view_mode > 0:
			ck_yaw = clampf(ck_yaw - look.x * 0.006, -1.5, 1.5)
			ck_pitch = clampf(ck_pitch - look.y * 0.003, -0.45, 0.55)
		else:
			cam_yaw -= look.x * 0.006
			cam_pitch = clampf(cam_pitch + look.y * 0.004, 0.12, 1.1)
		look_idle = 0.0
	else:
		look_idle += delta
		if not driving and absf(mv.x) > 0.12:
			cam_yaw -= mv.x * 1.9 * delta
	if in_van:
		_drive(delta)
		return
	if in_boat:
		_sail(delta)
		return
	var dirv := Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0.0, mv.y)
	var want := dirv * (6.3 if bag.size() < 3 else 4.9)
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


func _drive(delta: float) -> void:
	var di: Dictionary = drive_ui.poll(delta)
	var gas: float = di["gas"]
	var brk: float = di["brake"]
	var st: float = di["steer"]
	var maxs := 19.0 if Profile.owns("turbo_van") else 15.0
	if brk > 0.5:
		if van_speed > 0.3:
			van_speed = maxf(van_speed - 26.0 * delta, 0.0)
		elif van_speed < -0.3:
			van_speed = minf(van_speed + 26.0 * delta, 0.0)
		else:
			van_speed = move_toward(van_speed, -4.5, 7.0 * delta) if gas < 0.05 else 0.0
	elif gas > 0.05:
		van_speed += (10.0 if van_speed >= 0.0 else 22.0) * gas * delta
	else:
		van_speed = move_toward(van_speed, 0.0, 4.5 * delta)
	van_speed = clampf(van_speed, -6.0, maxs)
	braking = brk > 0.5 and absf(van_speed) > 0.4
	var grip := clampf(absf(van_speed) / 4.0, 0.0, 1.0) * (1.0 if van_speed >= 0.0 else -1.0)
	van_yaw -= st * 1.9 * grip * delta
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
	Vehicles.update_car(car_p, van_speed, st, braking, delta)
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
	pl.position = van.position + Basis(Vector3.UP, van_yaw) * (car_p["seat_driver"] as Vector3)
	pl.rotation.y = van_yaw
	drive_ui.speed_kmh = absf(van_speed) * 3.6
	drive_ui.gear = "R" if van_speed < -0.3 else ("D" if van_speed > 0.3 else "N")


func _boat_resolve(p: Vector3) -> Vector3:
	var q := Vector2(clampf(p.x, -HALF + 3.0, HALF - 3.0), clampf(p.z, LAKE_Z + 2.8, HALF + 3.0))
	var pr := PIER.grow(1.7)
	if pr.has_point(q):
		var l := q.x - pr.position.x
		var r := pr.end.x - q.x
		var d := pr.end.y - q.y
		var m := minf(minf(l, r), d)
		if m == l:
			q.x = pr.position.x
		elif m == r:
			q.x = pr.end.x
		else:
			q.y = pr.end.y
	return Vector3(q.x, p.y, q.y)


func _sail(delta: float) -> void:
	var di: Dictionary = drive_ui.poll(delta)
	var gas: float = di["gas"]
	var brk: float = di["brake"]
	var st: float = di["steer"]
	var maxs := 14.0
	if brk > 0.5:
		if boat_speed > 0.3:
			boat_speed = maxf(boat_speed - 9.0 * delta, 0.0)
		else:
			boat_speed = move_toward(boat_speed, -3.0, 4.0 * delta)
	elif gas > 0.05:
		boat_speed += 6.0 * gas * delta
	else:
		boat_speed = move_toward(boat_speed, 0.0, 2.2 * delta)
	boat_speed = clampf(boat_speed, -3.5, maxs)
	var grip := clampf(absf(boat_speed) / 3.0, 0.0, 1.0) * (1.0 if boat_speed >= 0.0 else -1.0)
	boat_yaw -= st * 1.2 * grip * delta
	var heading := Vector3(-sin(boat_yaw), 0.0, -cos(boat_yaw))
	var np := boat.position + heading * boat_speed * delta
	var res := _boat_resolve(np)
	if (res - np).length() > 0.02:
		if absf(boat_speed) > 4.0:
			shake = 0.3
		boat_speed *= 0.5
	boat.position = Vector3(res.x, boat.position.y, res.z)
	boat.rotation.y = boat_yaw
	Vehicles.update_boat(boat_p, boat_speed, st, t, delta)
	pl.position = boat.position + Basis(Vector3.UP, boat_yaw) * (boat_p["seat_driver"] as Vector3)
	pl.rotation.y = boat_yaw
	drive_ui.speed_kmh = absf(boat_speed) * 3.6 * 1.3
	drive_ui.gear = "R" if boat_speed < -0.3 else "F"


func _resolve(p: Vector3, r: float) -> Vector3:
	var all: Array[Rect2] = solids if water_solids.is_empty() else solids + water_solids
	for it in 2:
		for s in all:
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
		n.visible = n.position.distance_to(ap) < 90.0 and (cine.is_empty() or n.position.distance_to(cine["pos"]) > 6.0)
		if phase == "play" and not (in_van or in_boat) and hit_cool <= 0.0 and n.position.distance_to(pl.position) < 0.75:
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
		if phase == "play" and cn.position.distance_to(ap) < (3.2 if (in_van or in_boat) else 2.0):
			c["used"] = true
			(cn.get_child(cn.get_child_count() - 1) as Label3D).text = "Nu, go! Go!"
			time_left = maxf(time_left - 8.0, 1.0)
			_toast("%s stops you for a chat.  (-8 s)" % c["name"])
			if in_van:
				van_speed *= 0.3
			elif in_boat:
				boat_speed *= 0.3
			else:
				pl_vel = Vector3.ZERO


func _update_cars(delta: float) -> void:
	for c in cars:
		var p: float = c["pos"] + float(c["dir"]) * float(c["speed"]) * delta
		var hi := HALF + 8.0
		if kin and c["vertical"]:
			hi = 74.0
		if p > hi:
			p = -HALF - 8.0
		elif p < -HALF - 8.0:
			p = hi
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
	if in_boat:
		return
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
	var k: String = missions[mi].get("kind", "stand")
	if k != "stand" and k != "shul":
		return false
	var sp := _stand_pos(mi)
	var ap := _actor_pos()
	return Vector2(sp.x - ap.x, sp.z - ap.z).length() < 4.2


## What the yellow button does right now: {"label","do"} or empty.
func _act_info() -> Dictionary:
	if busy > 0.0 or phase != "play":
		return {}
	var m: Dictionary = missions[mi] if mi < missions.size() else {}
	var kind: String = m.get("kind", "stand")
	var foot := not (in_van or in_boat)
	if foot and (kind == "stand" or kind == "shul") and _near_stand():
		return {"label": str(m["verb"]), "do": "mission"}
	if in_boat and kind == "boat_stand":
		var bp: Vector3 = m["pos"]
		if Vector2(boat.position.x - bp.x, boat.position.z - bp.z).length() < float(m.get("r", 7.0)):
			return {"label": str(m["verb"]), "do": "mission"}
	if in_van:
		return {"label": "GET\nOUT", "do": "exit_car"}
	if in_boat:
		if Vector2(boat.position.x - DOCK.x, boat.position.z - DOCK.z).length() < 8.0:
			return {"label": "GET\nOFF", "do": "exit_boat"}
		return {}
	var ts := _trunk_spot()
	if Vector2(pl.position.x - ts.x, pl.position.z - ts.z).length() < 2.5:
		if trunk.size() > 0 and (bag.is_empty() or kind == "shul"):
			return {"label": "TAKE\nOUT", "do": "from_trunk"}
		if bag.size() > 0:
			return {"label": "PUT IN\nTRUNK", "do": "to_trunk"}
	if boat != null and Vector2(boat.position.x - pl.position.x, boat.position.z - pl.position.z).length() < 4.8:
		return {"label": "BOARD\nBOAT", "do": "board"}
	if Vector2(van.position.x - pl.position.x, van.position.z - pl.position.z).length() < 3.6:
		return {"label": "DRIVE", "do": "enter_car"}
	return {}


func _interactions() -> void:
	var info := _act_info()
	controls.set_act(str(info.get("label", "")))
	if controls.consume("act") or Input.is_action_just_pressed("ui_accept"):
		interact()


## Used by the touch button and by the headless test bot.
func interact() -> void:
	var info := _act_info()
	if info.is_empty():
		return
	match str(info["do"]):
		"mission":
			_do_mission()
		"exit_car":
			_exit_car()
		"exit_boat":
			_exit_boat()
		"to_trunk":
			_trunk_transfer(true)
		"from_trunk":
			_trunk_transfer(false)
		"board":
			_enter_boat()
		"enter_car":
			_enter_car()


func _advance(m: Dictionary) -> void:
	mi += 1
	Profile.stat_add("city_errands")
	if mi >= missions.size():
		_win()
		return
	var title := str(m.get("verb", "")).replace("\n", " ").capitalize()
	if title == "":
		title = "Nice"
	if str(m.get("msg", "")) != "":
		_banner("Done! " + title, str(m["msg"]), 2.8)
	_hud_update()


func _do_mission() -> void:
	var m: Dictionary = missions[mi]
	var kind: String = m.get("kind", "stand")
	if kind == "shul":
		if bag.size() < _total_items():
			_toast("Where is the shopping? Check the trunk!")
			return
		bag.clear()
		_refresh_bag()
		_advance(m)
		return
	var item := str(m.get("item", ""))
	if item != "":
		if kind == "boat_stand":
			cargo.append(item)
			_refresh_cargo()
		else:
			_give_item(item)
	_advance(m)


func _check_auto() -> void:
	if mi >= missions.size():
		return
	var m: Dictionary = missions[mi]
	match str(m.get("kind", "stand")):
		"reach":
			var veh := str(m.get("veh", "any"))
			var ok := veh == "any" or (veh == "car" and in_van) or (veh == "boat" and in_boat)
			var tp: Vector3 = m["pos"]
			var ap := _actor_pos()
			if ok and Vector2(ap.x - tp.x, ap.z - tp.z).length() < float(m.get("r", 6.0)):
				_advance(m)
		"stow":
			if busy <= 0.0 and trunk.size() >= int(m.get("need", 3)):
				_advance(m)
		"board":
			if in_boat:
				_advance(m)


# ---------------------------------------------------------------- vehicles in and out

func _vehicle_ui(on: bool) -> void:
	drive_ui.visible = on
	controls.hide_move_ui = on
	controls.exclude_rects = drive_ui.exclusion_rects() if on else ([] as Array[Rect2])
	controls.clear()


func _set_seated(on: bool) -> void:
	seated = on
	var legs: Array = pl_person["legs"]
	var arms: Array = pl_person["arms"]
	for l in legs:
		(l as Node3D).rotation.x = 1.4 if on else 0.0
	for a in arms:
		(a as Node3D).rotation.x = 1.05 if on else 0.0
	pl_person["hold"] = false


func _door_anim(open_r: bool, left: bool) -> void:
	if left:
		car_p["door_open_l"] = 1.05 if open_r else 0.0
	if open_r and left:
		get_tree().create_timer(1.1).timeout.connect(func(): car_p["door_open_l"] = 0.0)


func _enter_car() -> void:
	in_van = true
	pl_vel = Vector3.ZERO
	van_speed = 0.0
	_set_seated(true)
	_door_anim(true, true)
	_vehicle_ui(true)
	_refresh_bag()
	_apply_view()
	_toast("Hop in! Gas and brake on the right. VIEW switches the camera.")


func _exit_car() -> void:
	if absf(van_speed) > 3.0:
		_toast("Stop the car first!")
		return
	in_van = false
	van_speed = 0.0
	_set_seated(false)
	var left := Basis(Vector3.UP, van_yaw) * Vector3(-1, 0, 0)
	pl.position = _resolve(van.position + left * 2.3, PR)
	pl.rotation.y = van_yaw
	pl_yaw = van_yaw
	pl.visible = true
	_door_anim(true, true)
	_vehicle_ui(false)
	_refresh_bag()
	cam_pitch = 0.38
	cam_yaw = van_yaw
	braking = false
	Vehicles.update_car(car_p, 0.0, 0.0, false, 0.016)


func _enter_boat() -> void:
	in_boat = true
	boat_speed = 0.0
	pl_vel = Vector3.ZERO
	_set_seated(true)
	_vehicle_ui(true)
	_refresh_bag()
	_apply_view()
	cam_yaw = boat_yaw
	_toast("Captain on deck! Gas to sail, brake to stop.")


func _exit_boat() -> void:
	if absf(boat_speed) > 3.0:
		_toast("Slow down before you jump off!")
		return
	in_boat = false
	boat_speed = 0.0
	_set_seated(false)
	boat.position = Vector3(DOCK.x, boat.position.y, DOCK.z)
	boat_yaw = PI
	boat.rotation.y = boat_yaw
	pl.position = Vector3(PIER.position.x + 1.5, 0, DOCK.z - 0.5)
	pl.visible = true
	_vehicle_ui(false)
	if not cargo.is_empty():
		bag.append_array(cargo)
		cargo.clear()
		_refresh_cargo()
		_toast("You grab the fish. It is still wiggling.")
	_refresh_bag()
	cam_pitch = 0.38
	cam_yaw = PI


func _cycle_view() -> void:
	if not (in_van or in_boat):
		return
	view_mode = (view_mode + 1) % (3 if in_van else 2)
	ck_yaw = 0.0
	ck_pitch = 0.0
	_apply_view()
	_toast(["Chase camera", "Driver's seat", "Hood camera"][view_mode])


func _apply_view() -> void:
	if not (in_van or in_boat):
		pl.visible = true
		return
	pl.visible = view_mode != 1


# ---------------------------------------------------------------- carrying: hand, bag, trunk

func _item_model(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"challah":
			var c := Vehicles.m(Color("#c98a3c"), 0.7)
			var c2 := Vehicles.m(Color("#e0a552"), 0.6)
			for k in 4:
				Vehicles.sph(n, 0.07, Vector3((k - 1.5) * 0.085, 0.0, 0.035 * (1 if k % 2 == 0 else -1)), c, Vector3(1.3, 0.85, 1.0))
			for k in 3:
				Vehicles.sph(n, 0.055, Vector3((k - 1.0) * 0.1, 0.055, -0.03 * (1 if k % 2 == 0 else -1)), c2, Vector3(1.3, 0.8, 1.0))
		"fish":
			var sil := Vehicles.m(Color("#aeb9c2"), 0.3, 0.5)
			Vehicles.sph(n, 0.1, Vector3.ZERO, sil, Vector3(2.2, 0.62, 0.55))
			Vehicles.sph(n, 0.07, Vector3(0, -0.02, 0), Vehicles.m(Color("#e8eef2"), 0.5), Vector3(2.0, 0.5, 0.5))
			Vehicles.box(n, Vector3(0.1, 0.13, 0.02), Vector3(0.24, 0, 0), sil, Vector3(0, 0, 0.0))
			Vehicles.box(n, Vector3(0.06, 0.07, 0.015), Vector3(0.0, 0.07, 0), Vehicles.m(Color("#6c7c8a"), 0.5))
			Vehicles.sph(n, 0.016, Vector3(-0.17, 0.02, 0.05), Vehicles.m(Color("#101010"), 0.3))
		"flowers":
			var green := Vehicles.m(Color("#3f8a3a"), 0.8)
			var paper := Vehicles.m(Color("#f2c4d4"), 0.9)
			Vehicles.box(n, Vector3(0.16, 0.26, 0.04), Vector3(0, -0.02, 0.02), paper, Vector3(-0.15, 0, 0))
			for k in 5:
				var a := TAU * k / 5.0
				Vehicles.cyl(n, 0.008, 0.28, Vector3(cos(a) * 0.04, 0.1, sin(a) * 0.04), green, Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2), 5)
			var cols := [Color("#e63b52"), Color("#f2d23a"), Color("#f08ac0"), Color("#ffffff"), Color("#c06ae0")]
			for k in 5:
				var a2 := TAU * k / 5.0
				Vehicles.sph(n, 0.045, Vector3(cos(a2) * 0.07, 0.24 + 0.02 * (k % 2), sin(a2) * 0.07), Vehicles.m(cols[k], 0.6))
			Vehicles.sph(n, 0.04, Vector3(0, 0.27, 0), Vehicles.m(Color("#3f8a3a"), 0.8))
		"juice":
			var purple := Vehicles.m(Color("#5b1f6e"), 0.25, 0.1)
			Vehicles.cyl(n, 0.05, 0.22, Vector3(0, 0, 0), purple, Vector3.ZERO, 10)
			Vehicles.cyl(n, 0.022, 0.1, Vector3(0, 0.15, 0), purple, Vector3.ZERO, 8)
			Vehicles.cyl(n, 0.027, 0.03, Vector3(0, 0.215, 0), Vehicles.m(Color("#d9b84a"), 0.4, 0.6), Vector3.ZERO, 8)
			Vehicles.box(n, Vector3(0.1, 0.09, 0.005), Vector3(0, 0.0, 0.0505), Vehicles.m(Color("#f4f1e8"), 0.7))
		_:
			Vehicles.box(n, Vector3(0.2, 0.15, 0.2), Vector3.ZERO, Vehicles.m(Color("#b0905c"), 0.9))
	return n


func _build_bag(parent: Node3D, items: Array, sc := 1.0) -> void:
	var kraft := Vehicles.m(Color("#c29a62"), 0.9)
	var dark := Vehicles.m(Color("#8a6a3e"), 0.9)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * sc
	parent.add_child(holder)
	Vehicles.box(holder, Vector3(0.3, 0.34, 0.2), Vector3(0, -0.17, 0), kraft)
	Vehicles.box(holder, Vector3(0.1, 0.34, 0.205), Vector3(0, -0.17, 0), dark)
	Vehicles.box(holder, Vector3(0.012, 0.16, 0.012), Vector3(-0.07, 0.07, 0), dark)
	Vehicles.box(holder, Vector3(0.012, 0.16, 0.012), Vector3(0.07, 0.07, 0), dark)
	Vehicles.box(holder, Vector3(0.15, 0.012, 0.012), Vector3(0, 0.15, 0), dark)
	var n := mini(items.size(), 6)
	for i in n:
		var im := _item_model(str(items[i]))
		holder.add_child(im)
		im.scale = Vector3.ONE * 0.9
		im.position = Vector3((i % 3 - 1) * 0.085, 0.0 + 0.02 * (i / 3), (i / 3) * 0.04 - 0.02)
		if str(items[i]) == "fish":
			im.rotation.z = 0.5
			im.position.y += 0.07


func _refresh_bag() -> void:
	if bag_node != null:
		bag_node.queue_free()
	bag_node = Node3D.new()
	(pl_person["arms"][0] as Node3D).add_child(bag_node)
	bag_node.position = Vector3(0.0, -0.64, -0.03)
	_build_bag(bag_node, bag)
	bag_node.visible = not (in_van or in_boat)
	for c in seat_bag.get_children():
		c.queue_free()
	_build_bag(seat_bag, bag, 1.5)
	seat_bag.visible = in_van
	seat_bag.position = (car_p["seat_pass"] as Vector3) + Vector3(0, 0.34, 0)
	_hud_update()


func _refresh_trunk() -> void:
	for c in trunk_vis.get_children():
		c.queue_free()
	var a: Vector3 = car_p["trunk_anchor"]
	for i in trunk.size():
		var im := _item_model(str(trunk[i]))
		trunk_vis.add_child(im)
		im.position = a + _trunk_slot(i)
		if str(trunk[i]) == "fish":
			im.position.y += 0.06
	_hud_update()


func _trunk_slot(i: int) -> Vector3:
	return Vector3((i % 3 - 1) * 0.42, 0.0, (i / 3) * 0.34 - 0.12)


func _refresh_cargo() -> void:
	if cargo_vis == null:
		return
	for c in cargo_vis.get_children():
		c.queue_free()
	var a: Vector3 = boat_p["cargo_anchor"]
	for i in cargo.size():
		var im := _item_model(str(cargo[i]))
		cargo_vis.add_child(im)
		im.position = a + Vector3((i - (cargo.size() - 1) * 0.5) * 0.25, 0.1, 0)
	_hud_update()


func _give_item(kind: String) -> void:
	busy = 1.45
	held_node = _item_model(kind)
	(pl_person["arms"][1] as Node3D).add_child(held_node)
	held_node.position = Vector3(0, -0.68, 0.0)
	pl_person["hold"] = true
	_toast({"challah": "Fresh challah!", "fish": "A whole fish, wrapped in newspaper", "flowers": "Hadassim and flowers", "juice": "Grape juice"}.get(kind, "Got it!"))
	get_tree().create_timer(0.85).timeout.connect(func():
		if held_node == null:
			return
		var node := held_node
		var from := node.global_position
		var mouth := (pl_person["arms"][0] as Node3D).to_global(Vector3(0, -0.64, -0.03))
		var tw := create_tween()
		tw.tween_method(func(u: float):
			if is_instance_valid(node):
				node.global_position = from.lerp(mouth, u) + Vector3(0, sin(u * PI) * 0.22, 0), 0.0, 1.0, 0.4)
		tw.tween_callback(func():
			if is_instance_valid(node):
				node.queue_free()
			held_node = null
			pl_person["hold"] = false
			bag.append(kind)
			_refresh_bag()))


func _trunk_transfer(to_trunk: bool) -> void:
	var src: Array = bag if to_trunk else trunk
	if src.is_empty():
		return
	var items := src.duplicate()
	var total := 0.7 + 0.32 * items.size()
	busy = total + 0.5
	car_p["trunk_open"] = true
	var a_local: Vector3 = car_p["trunk_anchor"]
	var hand := pl.to_global(Vector3(0.0, 1.05, -0.45))
	if to_trunk:
		bag.clear()
		_refresh_bag()
	else:
		trunk.clear()
		_refresh_trunk()
	for i in items.size():
		var kind := str(items[i])
		var node := _item_model(kind)
		add_child(node)
		var spot := van.to_global(a_local + _trunk_slot(i))
		var a := hand if to_trunk else spot
		var b := spot if to_trunk else hand
		node.global_position = a
		var tw := create_tween()
		tw.tween_interval(0.5 + i * 0.32)
		tw.tween_method(func(u: float):
			if is_instance_valid(node):
				node.global_position = a.lerp(b, u) + Vector3(0, sin(u * PI) * 0.7, 0), 0.0, 1.0, 0.36)
		tw.tween_callback(node.queue_free)
	get_tree().create_timer(total).timeout.connect(func():
		if to_trunk:
			trunk.append_array(items)
		else:
			bag.append_array(items)
		_refresh_bag()
		_refresh_trunk()
		car_p["trunk_open"] = false
		_toast("Everything is in the trunk." if to_trunk else "Shopping is back in your hands.")
		)


# ---------------------------------------------------------------- camera

func _follow(delta: float) -> void:
	if not cine.is_empty():
		cam.position = cine["pos"]
		cam.look_at(cine["look"])
		cam.fov = float(cine.get("fov", 62.0))
		for pk in pickups:
			(pk as Node3D).visible = false
		return
	var driving := in_van or in_boat
	if driving and view_mode > 0:
		var node: Node3D = van if in_van else boat
		var yaw := van_yaw if in_van else boat_yaw
		var local: Vector3
		if in_van:
			local = (car_p["cockpit"] if view_mode == 1 else car_p["hood_cam"]) as Vector3
		else:
			local = boat_p["cockpit"] as Vector3
		if look_idle > 1.2:
			ck_yaw = lerpf(ck_yaw, 0.0, minf(delta * 3.0, 1.0))
			ck_pitch = lerpf(ck_pitch, 0.0, minf(delta * 3.0, 1.0))
		var bob := 0.0
		if shake > 0.0:
			shake = maxf(shake - delta, 0.0)
			bob = randf_range(-1, 1) * shake * 0.06
		cam.position = node.position + Basis(Vector3.UP, yaw) * Vector3(local.x, 0.0, local.z) + Vector3(0, node.position.y + local.y + bob, 0)
		cam.rotation = Vector3(-0.05 + ck_pitch, yaw + ck_yaw, 0.0)
		cam.fov = base_fov + (8.0 if view_mode == 1 else 2.0)
		return
	cam.fov = base_fov
	var ap := _actor_pos()
	var vs := van_speed if in_van else boat_speed
	var vyaw := van_yaw if in_van else boat_yaw
	if driving and look_idle > 1.2 and absf(vs) > 2.0:
		cam_yaw = lerp_angle(cam_yaw, vyaw if vs > 0.0 else vyaw + PI, minf(delta * 1.8, 1.0))
	var dist := cam_dist + (2.4 if driving else 0.0)
	var target := ap + Vector3(0, 1.5 if not driving else 1.8, 0)
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
	Profile.stat_add("city_wins")
	Profile.stat_max("city_best_left", int(time_left))
	var pts := _commit() + 100
	Profile.add_points(100)
	finished.emit(true)
	var left := int(time_left)
	_overlay("Gut Shabbos!", "You made it with %d:%02d to spare and %d shekels. You earned %d points." % [left / 60, left % 60, coins, pts], [
		["Play again", func(): app.start_level(level_id)], ["Back to menu", func(): app.show_launcher()]])
