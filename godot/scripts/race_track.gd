extends RefCounted
## Race track for "Shtick Racing": a centre line made from a few simple commands
## (go, arc, jump, dam ...), the 3D meshes around it (water or road, cliffs, dams,
## buildings, trees) and the look-ups the physics needs (height, side distance).
## Convention: heading h, forward = (-sin h, 0, -cos h), right = (cos h, 0, -sin h), + turn = left.

const DS := 2.5
const F_GAP := 1
const F_BOOST := 2
const F_FOAM := 4
const F_DAM := 8
const T_LAKE := 0
const T_CANYON := 1
const T_CITY := 2
const T_HILLS := 3
const T_DAM := 4
const CHUNK := 56

var boat := false
var closed := false
var pos := PackedVector3Array()
var wid := PackedFloat32Array()
var wl := PackedFloat32Array()
var wr := PackedFloat32Array()
var flg := PackedInt32Array()
var thm := PackedInt32Array()
var fwd := PackedVector3Array()
var rgt := PackedVector3Array()
var ks := PackedFloat32Array()
var kss := PackedFloat32Array()
var dist := PackedFloat32Array()
var n := 0
var length := 0.0
var y_ground := 0.0
var start_idx := 0
var finish_idx := 0
var dams: Array = []
var bridges: Array = []
var gantries: Array = []
var reservoirs: Array = []
var min_xz := Vector2.ZERO
var max_xz := Vector2.ZERO
var ground_col := Color("#8d8a6a")
var _p := Vector3.ZERO
var _h := 0.0
var _w := 20.0
var _wl := 1.0
var _wr := 1.0
var _flags := 0
var _theme := 0
var _rng := RandomNumberGenerator.new()
var _grid := {}
var _chunks := {}
var _mat_solid: StandardMaterial3D
var _mat_water: ShaderMaterial

const WATER_SHADER := """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w = sin(wp.x * 0.7 + TIME * 1.2) * 0.5 + sin(wp.z * 0.9 - TIME * 1.5) * 0.5 + sin((wp.x + wp.z) * 0.35 + TIME * 0.8);
	float sp = sin(wp.x * 2.3 + TIME * 2.1) * sin(wp.z * 2.7 - TIME * 1.7);
	vec3 lake_d = vec3(0.05, 0.27, 0.43);
	vec3 lake_s = vec3(0.16, 0.56, 0.68);
	vec3 riv_d = vec3(0.05, 0.30, 0.34);
	vec3 riv_s = vec3(0.16, 0.50, 0.52);
	float k = clamp(0.5 + 0.18 * w, 0.0, 1.0);
	vec3 deep = mix(lake_d, riv_d, COLOR.b);
	vec3 shal = mix(lake_s, riv_s, COLOR.b);
	vec3 col = mix(deep, shal, k) + vec3(max(sp, 0.0) * 0.05);
	float stripes = smoothstep(0.35, 0.95, sin(UV.y * 1.6 - TIME * 9.0 + sin(UV.x * 9.0) * 1.6)) * COLOR.g;
	float foam = clamp(COLOR.r + stripes * 0.55, 0.0, 1.0);
	ALBEDO = mix(col, vec3(0.96, 0.98, 1.0), foam * 0.85);
	ROUGHNESS = mix(0.1, 0.5, foam);
	METALLIC = 0.25;
	SPECULAR = 0.9;
}
"""


# ---------------------------------------------------------------- mesh builder

class MB:
	extends RefCounted
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

	func tri(a: Vector3, b: Vector3, d: Vector3, n_out: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO) -> void:
		var cr := (b - a).cross(d - a)
		if cr.dot(n_out) > 0.0:
			v.append(a); v.append(d); v.append(b)
			uv.append(ua); uv.append(ud); uv.append(ub)
		else:
			v.append(a); v.append(b); v.append(d)
			uv.append(ua); uv.append(ub); uv.append(ud)
		for k in 3:
			nn.append(n_out)
			c.append(col)

	func tri3(a: Vector3, b: Vector3, d: Vector3, n_out: Vector3, ca: Color, cb: Color, cd: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO) -> void:
		var cr := (b - a).cross(d - a)
		if cr.dot(n_out) > 0.0:
			v.append(a); v.append(d); v.append(b)
			c.append(ca); c.append(cd); c.append(cb)
			uv.append(ua); uv.append(ud); uv.append(ub)
		else:
			v.append(a); v.append(b); v.append(d)
			c.append(ca); c.append(cb); c.append(cd)
			uv.append(ua); uv.append(ub); uv.append(ud)
		for k in 3:
			nn.append(n_out)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, n_out: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO, ue := Vector2.ZERO) -> void:
		tri(a, b, d, n_out, col, ua, ub, ud)
		tri(a, d, e, n_out, col, ua, ud, ue)

	func box(center: Vector3, size: Vector3, yaw: float, col: Color, shade := 0.82) -> void:
		var bs := Basis(Vector3.UP, yaw)
		var hx := size.x * 0.5
		var hy := size.y * 0.5
		var hz := size.z * 0.5
		var p: Array[Vector3] = []
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				for sx in [-1.0, 1.0]:
					p.append(center + bs * Vector3(sx * hx, sy * hy, sz * hz))
		# indices: x fastest, then z, then y
		var side := col.darkened(1.0 - shade)
		var ex: Vector3 = bs * Vector3.RIGHT
		var ez: Vector3 = bs * Vector3.BACK
		quad(p[4], p[5], p[7], p[6], Vector3.UP, col.lightened(0.06))
		quad(p[0], p[1], p[3], p[2], Vector3.DOWN, side)
		quad(p[1], p[5], p[7], p[3], ex, side)
		quad(p[0], p[4], p[6], p[2], -ex, side)
		quad(p[2], p[3], p[7], p[6], ez, side)
		quad(p[0], p[1], p[5], p[4], -ez, side)

	func pyramid(base: Vector3, r: float, h: float, sides: int, col: Color, yaw := 0.0, rtop := 0.0) -> void:
		var ring: Array[Vector3] = []
		var top: Array[Vector3] = []
		for k in sides:
			var a := yaw + TAU * k / sides
			ring.append(base + Vector3(cos(a) * r, 0.0, sin(a) * r))
			top.append(base + Vector3(cos(a) * rtop, h, sin(a) * rtop))
		for k in sides:
			var k2 := (k + 1) % sides
			var mid := (ring[k] + ring[k2]) * 0.5 - base
			var nrm := Vector3(mid.x, r * 0.5, mid.z).normalized()
			var shade := col.darkened(0.14 * (0.5 + 0.5 * sin(yaw + TAU * k / sides)))
			if rtop > 0.001:
				quad(ring[k], ring[k2], top[k2], top[k], nrm, shade)
			else:
				tri(ring[k], ring[k2], top[k], nrm, shade)
		if rtop > 0.001:
			for k in range(1, sides - 1):
				tri(top[0], top[k], top[k + 1], Vector3.UP, col.lightened(0.05))

	func cyl(base: Vector3, r: float, h: float, sides: int, col: Color) -> void:
		pyramid(base, r, h, sides, col, 0.0, r)

	func mesh(mat: Material) -> ArrayMesh:
		if v.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, mat)
		return am


# ---------------------------------------------------------------- track commands

func begin(p: Vector3, h: float, w: float, th: int, hl: float, hr: float) -> void:
	_p = p
	_h = h
	_w = w
	_theme = th
	_wl = hl
	_wr = hr
	_flags = 0
	_emit()


func style(th: int, hl: float, hr: float) -> void:
	_theme = th
	_wl = hl
	_wr = hr


func flag_on(f: int) -> void:
	_flags |= f


func flag_off(f: int) -> void:
	_flags &= ~f


func _emit() -> void:
	pos.append(_p)
	wid.append(_w)
	wl.append(_wl)
	wr.append(_wr)
	flg.append(_flags)
	thm.append(_theme)


func go(len: float, turn_deg := 0.0, dy := 0.0, w := -1.0, lin := false) -> void:
	var steps := maxi(1, int(round(len / DS)))
	var sl := len / steps
	var turn := deg_to_rad(turn_deg)
	var y0 := _p.y
	var w0 := _w
	var w1 := w if w > 0.0 else _w
	for i in range(1, steps + 1):
		var u := float(i) / steps
		_h += turn / steps
		_p += Vector3(-sin(_h), 0.0, -cos(_h)) * sl
		var e := u if lin else u * u * (3.0 - 2.0 * u)
		_p.y = y0 + dy * e
		_w = lerpf(w0, w1, u)
		_emit()


func arc(deg: float, radius: float, dy := 0.0, w := -1.0) -> void:
	go(radius * deg_to_rad(absf(deg)), deg, dy, w)


func boost(len: float) -> void:
	flag_on(F_BOOST)
	go(len)
	flag_off(F_BOOST)


## Ramp up, a gap you must fly over, landing a little lower.
func jump(up: float, up_len: float, gap: float, down: float) -> void:
	go(up_len, 0.0, up, -1.0, true)
	bridges.append(pos.size() - 1)
	flag_on(F_GAP)
	go(gap, 0.0, -down)
	flag_off(F_GAP)


## Calm pool, steep spillway with white water, calm runoff.
func dam(pool: float, drop: float, chute: float, runoff: float) -> void:
	flag_on(F_DAM)
	go(pool)
	dams.append(pos.size() - 1)
	flag_on(F_FOAM)
	go(chute, 0.0, -drop)
	flag_off(F_FOAM)
	go(runoff * 0.4)
	flag_off(F_DAM)
	go(runoff * 0.6)


func rapids(len: float, dy: float, w := -1.0) -> void:
	flag_on(F_FOAM)
	flag_on(F_BOOST)
	go(len, 0.0, dy, w)
	flag_off(F_FOAM)
	flag_off(F_BOOST)


func mark_start() -> void:
	start_idx = pos.size() - 1


func mark_finish() -> void:
	finish_idx = pos.size() - 1


func finalize(is_closed: bool) -> void:
	closed = is_closed
	n = pos.size()
	if closed:
		var nf := Vector3(-sin(_h), 0.0, -cos(_h)) * DS
		var err := pos[0] - (pos[n - 1] + nf)
		print("race_track: closing error %.2f m" % err.length())
		for i in n:
			pos[i] += err * (float(i) / n)
	dist.resize(n)
	var acc := 0.0
	for i in n:
		dist[i] = acc
		acc += DS
	length = n * DS if closed else (n - 1) * DS
	fwd.resize(n)
	rgt.resize(n)
	ks.resize(n)
	kss.resize(n)
	var hd := PackedFloat32Array()
	hd.resize(n)
	for i in n:
		var a := pos[_wrap(i - 1)]
		var b := pos[_wrap(i + 1)]
		if not closed:
			a = pos[maxi(i - 1, 0)]
			b = pos[mini(i + 1, n - 1)]
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		fwd[i] = d
		rgt[i] = Vector3(-d.z, 0.0, d.x)
		hd[i] = atan2(-d.x, -d.z)
	for i in n:
		var a2 := hd[_cl(i - 1)]
		var b2 := hd[_cl(i + 1)]
		ks[i] = angle_difference(a2, b2) / (2.0 * DS)
	for i in n:
		var s := 0.0
		for k in range(-4, 5):
			s += ks[_cl(i + k)]
		kss[i] = s / 9.0
	var lo := 1e9
	min_xz = Vector2(1e9, 1e9)
	max_xz = Vector2(-1e9, -1e9)
	for i in n:
		lo = minf(lo, pos[i].y)
		min_xz.x = minf(min_xz.x, pos[i].x)
		min_xz.y = minf(min_xz.y, pos[i].z)
		max_xz.x = maxf(max_xz.x, pos[i].x)
		max_xz.y = maxf(max_xz.y, pos[i].z)
	y_ground = lo - 7.0
	if finish_idx <= 0:
		finish_idx = n - 6 if not closed else 0


func _wrap(i: int) -> int:
	return posmod(i, n)


func _cl(i: int) -> int:
	return posmod(i, n) if closed else clampi(i, 0, n - 1)


# ---------------------------------------------------------------- queries for the physics

func nearest_fast(p: Vector3, hint: int) -> int:
	var best := -1
	var bd := 1e18
	for k in range(hint - 10, hint + 32):
		var i := _cl(k)
		var dx := pos[i].x - p.x
		var dz := pos[i].z - p.z
		var d := dx * dx + dz * dz
		if d < bd:
			bd = d
			best = i
	var lim := wid[best] * 0.5 + 28.0
	if bd > lim * lim:
		bd = 1e18
		var i2 := 0
		while i2 < n:
			var dx2 := pos[i2].x - p.x
			var dz2 := pos[i2].z - p.z
			var d2 := dx2 * dx2 + dz2 * dz2
			if d2 < bd:
				bd = d2
				best = i2
			i2 += 3
	return best


## Returns idx (segment start), f (fractional index), lat (+ right of centre), y (surface height),
## surf (a surface exists here), w (width).
func info(p: Vector3, hint: int) -> Dictionary:
	var b := nearest_fast(p, hint)
	var best_a := b
	var best_t := 0.0
	var best_d := 1e18
	for sg: int in [-1, 0]:
		var a := b + sg
		if not closed and (a < 0 or a + 1 > n - 1):
			continue
		a = _cl(a)
		var c := _cl(a + 1)
		var pa := pos[a]
		var abx := pos[c].x - pa.x
		var abz := pos[c].z - pa.z
		var l2 := abx * abx + abz * abz
		var t := clampf(((p.x - pa.x) * abx + (p.z - pa.z) * abz) / maxf(l2, 0.0001), 0.0, 1.0)
		var qx := pa.x + abx * t
		var qz := pa.z + abz * t
		var dd := (p.x - qx) * (p.x - qx) + (p.z - qz) * (p.z - qz)
		if dd < best_d:
			best_d = dd
			best_a = a
			best_t = t
	var a2 := best_a
	var c2 := _cl(a2 + 1)
	var r := rgt[a2].lerp(rgt[c2], best_t).normalized()
	var q := pos[a2].lerp(pos[c2], best_t)
	var res := {
		"idx": a2, "f": float(a2) + best_t, "t": best_t,
		"lat": (p.x - q.x) * r.x + (p.z - q.z) * r.z,
		"y": q.y,
		"surf": (flg[a2] & F_GAP) == 0 and (flg[c2] & F_GAP) == 0,
		"w": lerpf(wid[a2], wid[c2], best_t),
		"fl": flg[a2] | flg[c2],
		"right": r,
		"fwd": fwd[a2].lerp(fwd[c2], best_t).normalized(),
	}
	return res


func progress_of(idx: int, t: float) -> float:
	return dist[idx] + t * DS


## Point at index i, shifted sideways by lat metres.
func point(i: int, lat := 0.0) -> Vector3:
	var k := _cl(i)
	return pos[k] + rgt[k] * lat


func yaw_at(i: int) -> float:
	var d := fwd[_cl(i)]
	return atan2(-d.x, -d.z)


func max_curv_ahead(i: int, meters: float) -> float:
	var m := 0.0
	var steps := int(meters / DS)
	var k := 0
	while k <= steps:
		m = maxf(m, absf(ks[_cl(i + k)]))
		k += 2
	return m


func flags_ahead(i: int, meters: float) -> int:
	var f := 0
	var steps := int(meters / DS)
	for k in range(0, steps + 1, 2):
		f |= flg[_cl(i + k)]
	return f


# ---------------------------------------------------------------- level recipes

func _lake_bend(sign_: float, deg: float, r: float, w: float) -> void:
	arc(deg * sign_, r, 0.0, w)


func _canyon_run(s: float) -> void:
	style(T_CANYON, 18.0, 18.0)
	arc(55.0 * s, 75.0, 0.0, 34.0)
	go(60.0)
	arc(80.0 * -s, 62.0)
	go(40.0)


func build_level(id: String) -> void:
	boat = id in ["race1", "race4"]
	if id == "race1":
		_race1()
	elif id == "race2":
		_race2()
	elif id == "race3":
		_race3()
	else:
		_race4()


func _race1() -> void:
	ground_col = Color("#9c9672")
	begin(Vector3(0, 0, 0), 0.0, 72.0, T_LAKE, 1.2, 1.2)
	go(48.0)
	mark_start()
	go(150.0)
	arc(70.0, 110.0, 0.0, 66.0)
	go(70.0)
	arc(-110.0, 95.0, 0.0, 54.0)
	go(60.0, 0.0, 0.0, 40.0)
	style(T_CANYON, 18.0, 18.0)
	arc(45.0, 80.0, 0.0, 34.0)
	go(40.0)
	boost(20.0)
	rapids(110.0, 14.0, 30.0)
	arc(-75.0, 70.0)
	go(50.0)
	style(T_DAM, 6.0, 6.0)
	dam(75.0, 17.0, 42.0, 80.0)
	style(T_CANYON, 20.0, 20.0)
	arc(70.0, 65.0, 0.0, 30.0)
	go(35.0)
	boost(30.0)
	jump(3.6, 16.0, 15.0, 2.2)
	go(45.0)
	arc(-120.0, 55.0)
	go(40.0)
	rapids(95.0, 18.0, 26.0)
	arc(75.0, 60.0)
	go(40.0)
	style(T_DAM, 6.0, 6.0)
	dam(70.0, 30.0, 58.0, 90.0)
	style(T_CANYON, 16.0, 16.0)
	arc(-60.0, 90.0, 0.0, 34.0)
	go(50.0)
	arc(70.0, 70.0)
	go(60.0)
	boost(25.0)
	rapids(80.0, -8.0)
	arc(-80.0, 65.0)
	go(50.0)
	style(T_LAKE, 1.2, 1.2)
	arc(50.0, 100.0, 0.0, 70.0)
	go(80.0, 0.0, 0.0, 80.0)
	arc(-40.0, 130.0)
	go(120.0)
	mark_finish()
	go(30.0)
	finalize(false)


func _half_lap() -> void:
	go(120.0)
	arc(90.0, 50.0)
	go(50.0)
	arc(-50.0, 40.0)
	arc(50.0, 40.0)
	go(50.0)
	go(40.0, 0.0, 3.5)
	go(40.0, 0.0, -3.5)
	arc(90.0, 50.0)
	go(40.0)


func _race2() -> void:
	boat = false
	ground_col = Color("#a39a82")
	begin(Vector3(0, 0, 0), 0.0, 17.0, T_CITY, 0.7, 0.7)
	mark_start()
	_half_lap()
	_half_lap()
	finalize(true)


func _race3() -> void:
	boat = false
	ground_col = Color("#8f8a63")
	begin(Vector3(0, 0, 0), 0.0, 14.0, T_HILLS, 14.0, 1.0)
	mark_start()
	go(140.0)
	go(130.0, 0.0, 20.0)
	arc(-110.0, 38.0, 6.0)
	go(60.0, 0.0, 6.0)
	arc(70.0, 70.0)
	boost(25.0)
	jump(3.2, 14.0, 13.0, 2.0)
	go(60.0, 0.0, 6.0)
	arc(150.0, 30.0, 8.0)
	go(70.0, 0.0, 6.0)
	arc(-150.0, 30.0, 8.0)
	go(90.0, 0.0, 12.0)
	arc(120.0, 45.0, 6.0)
	go(60.0)
	boost(20.0)
	jump(3.2, 14.0, 13.0, 2.0)
	go(70.0, 0.0, 8.0)
	arc(-110.0, 40.0, 6.0)
	go(100.0, 0.0, 10.0)
	arc(-60.0, 80.0)
	# dam crest
	style(T_DAM, 1.1, 1.1)
	flag_on(F_DAM)
	go(90.0, 0.0, 0.0, 15.0)
	reservoirs.append([pos.size() - 1, 0])
	go(160.0)
	reservoirs.append([pos.size() - 1, 1])
	boost(25.0)
	jump(3.6, 16.0, 15.0, 8.0)
	flag_off(F_DAM)
	style(T_HILLS, 1.0, 14.0)
	go(70.0, 0.0, -12.0)
	arc(120.0, 40.0, -10.0, 14.0)
	go(80.0, 0.0, -14.0)
	arc(-140.0, 32.0, -10.0)
	go(100.0, 0.0, -16.0)
	arc(60.0, 70.0)
	go(70.0)
	boost(20.0)
	jump(3.0, 14.0, 12.0, 2.0)
	go(90.0, 0.0, -10.0)
	arc(-90.0, 55.0, -8.0)
	style(T_CITY, 0.7, 0.7)
	go(90.0, 0.0, -6.0, 17.0)
	arc(40.0, 80.0)
	go(100.0)
	mark_finish()
	go(40.0)
	finalize(false)


func _race4() -> void:
	ground_col = Color("#9a9468")
	begin(Vector3(0, 0, 0), 0.0, 76.0, T_LAKE, 1.2, 1.2)
	go(48.0)
	mark_start()
	go(160.0)
	arc(-80.0, 120.0, 0.0, 68.0)
	go(80.0)
	arc(100.0, 100.0, 0.0, 56.0)
	go(60.0, 0.0, 0.0, 40.0)
	for stage in 4:
		var s := 1.0 if stage % 2 == 0 else -1.0
		style(T_CANYON, 18.0, 18.0)
		arc(50.0 * s, 80.0, 0.0, 34.0)
		go(50.0)
		boost(20.0)
		rapids(100.0 + stage * 12.0, 14.0 + stage * 2.0, 30.0)
		arc(-70.0 * s, 65.0)
		go(40.0)
		style(T_DAM, 6.0, 6.0)
		dam(70.0, 16.0 + stage * 5.0, 40.0 + stage * 6.0, 80.0)
		style(T_CANYON, 20.0, 20.0)
		arc(75.0 * s, 60.0, 0.0, 30.0)
		go(35.0)
		boost(30.0)
		jump(3.6, 16.0, 15.0, 2.4)
		go(45.0)
		arc(-110.0 * s, 52.0)
		go(40.0)
		arc(60.0 * s, 70.0)
		go(60.0)
	style(T_CANYON, 16.0, 16.0)
	arc(-50.0, 90.0, 0.0, 34.0)
	go(60.0)
	style(T_LAKE, 1.2, 1.2)
	arc(60.0, 100.0, 0.0, 72.0)
	go(80.0, 0.0, 0.0, 84.0)
	arc(-40.0, 140.0)
	go(140.0)
	mark_finish()
	go(30.0)
	finalize(false)


# ---------------------------------------------------------------- 3D

func _mb(i: int, water := false) -> MB:
	var key := (i / CHUNK) * 2 + (1 if water else 0)
	if not _chunks.has(key):
		_chunks[key] = MB.new()
	return _chunks[key]


func _hash_pos(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / 32.0)), int(floor(z / 32.0)))


func _build_grid() -> void:
	_grid.clear()
	for i in n:
		var k := _hash_pos(pos[i].x, pos[i].z)
		if not _grid.has(k):
			_grid[k] = PackedInt32Array()
		_grid[k].append(i)


## True when nothing of the track (other than samples within `ignore` of idx) is closer than r.
func clear_of_track(x: float, z: float, r: float, idx: int, ignore: int) -> bool:
	var c := _hash_pos(x, z)
	var reach := int(ceil((r + 40.0) / 32.0))
	for ox in range(-reach, reach + 1):
		for oz in range(-reach, reach + 1):
			var k := Vector2i(c.x + ox, c.y + oz)
			if not _grid.has(k):
				continue
			for i in _grid[k]:
				var di := absi(i - idx)
				if closed:
					di = mini(di, n - di)
				var lim := wid[i] * 0.5 + r + 3.0
				var dx := pos[i].x - x
				var dz := pos[i].z - z
				if dx * dx + dz * dz < lim * lim:
					if di > ignore:
						return false
	return true


func _theme_cols(th: int) -> Dictionary:
	match th:
		T_LAKE:
			return {"wall": Color("#b9ad92"), "cap": Color("#c9bf9f"), "slope": Color("#9fa06f"), "road": Color("#4a4d52")}
		T_CANYON:
			return {"wall": Color("#6b5a49"), "cap": Color("#7c7a55"), "slope": Color("#6f7048"), "road": Color("#4a4d52")}
		T_CITY:
			return {"wall": Color("#d4cdbb"), "cap": Color("#cfc7b0"), "slope": Color("#a39a82"), "road": Color("#3d3f44")}
		T_HILLS:
			return {"wall": Color("#8b7d68"), "cap": Color("#80844f"), "slope": Color("#7a7d4a"), "road": Color("#47494e")}
	return {"wall": Color("#aab0b6"), "cap": Color("#9aa0a6"), "slope": Color("#8a8f94"), "road": Color("#47494e")}


func _jit(i: int, amt: float) -> float:
	return (fmod(sin(i * 12.9898) * 43758.5453, 1.0) - 0.5) * 2.0 * amt


func _ext(i: int, side: float, th: int) -> Vector2:
	## cap width and slope run, limited on the inside of a bend
	var p0 := 8.0
	if th == T_LAKE:
		p0 = 34.0
	elif th == T_CITY:
		p0 = 42.0
	elif th == T_CANYON:
		p0 = 14.0
	elif th == T_HILLS:
		p0 = 8.0
	var run := 40.0
	if th == T_DAM:
		run = 3.0
	var avail := 1e9
	var kk := kss[i]
	if (side < 0.0 and kk > 0.0004) or (side > 0.0 and kk < -0.0004):
		var rad := 1.0 / absf(kk)
		avail = maxf(2.0, rad * 0.8 - wid[i] * 0.5)
	var pp := minf(p0, avail * 0.5)
	var ss := minf(run, maxf(avail - pp, 1.0))
	return Vector2(pp, ss)


func build(parent: Node3D, high: bool) -> void:
	_rng.seed = 424242
	_chunks.clear()
	_build_grid()
	_mat_solid = StandardMaterial3D.new()
	_mat_solid.vertex_color_use_as_albedo = true
	_mat_solid.roughness = 0.9
	_mat_solid.cull_mode = BaseMaterial3D.CULL_BACK
	var sh := Shader.new()
	sh.code = WATER_SHADER
	_mat_water = ShaderMaterial.new()
	_mat_water.shader = sh
	var segs := n if closed else n - 1
	for i in segs:
		_segment(i)
	_scenery(high)
	for key in _chunks.keys():
		var mbk: MB = _chunks[key]
		var is_w: bool = (key % 2) == 1
		var am := mbk.mesh(_mat_water if is_w else _mat_solid)
		if am == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 520.0
		parent.add_child(mi)
	# the ground, far below
	var gm := MB.new()
	var cx := (min_xz.x + max_xz.x) * 0.5
	var cz := (min_xz.y + max_xz.y) * 0.5
	var hs := 3000.0
	var g := Vector3(cx, y_ground, cz)
	gm.quad(g + Vector3(-hs, 0, -hs), g + Vector3(hs, 0, -hs), g + Vector3(hs, 0, hs), g + Vector3(-hs, 0, hs), Vector3.UP, ground_col)
	_far_hills(gm, cx, cz)
	var gmi := MeshInstance3D.new()
	gmi.mesh = gm.mesh(_mat_solid)
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gmi)


func _far_hills(gm: MB, cx: float, cz: float) -> void:
	var r2 := RandomNumberGenerator.new()
	r2.seed = 77
	var span := maxf(max_xz.x - min_xz.x, max_xz.y - min_xz.y) * 0.5 + 700.0
	for k in 18:
		var a := TAU * k / 18.0 + r2.randf() * 0.2
		var d := span + r2.randf() * 400.0
		var rad := 260.0 + r2.randf() * 220.0
		var ht := 120.0 + r2.randf() * 150.0
		var col := Color("#9a8f6c").lerp(Color("#7d8a64"), r2.randf())
		gm.pyramid(Vector3(cx + cos(a) * d, y_ground, cz + sin(a) * d), rad, ht, 7, col, r2.randf() * 3.0, rad * 0.12)


func _segment(i: int) -> void:
	var j := _cl(i + 1)
	var th := thm[i]
	var cols := _theme_cols(th)
	var gap := (flg[i] & F_GAP) != 0 or (flg[j] & F_GAP) != 0
	var mb := _mb(i)
	var pa := pos[i]
	var pb := pos[j]
	var wa := wid[i] * 0.5
	var wb := wid[j] * 0.5
	var la := pa - rgt[i] * wa
	var ra := pa + rgt[i] * wa
	var lb := pb - rgt[j] * wb
	var rb := pb + rgt[j] * wb
	if not gap:
		if boat:
			var wmb := _mb(i, true)
			var foam: float = 1.0 if (flg[i] & F_FOAM) != 0 else 0.0
			var flow := 1.0 if foam > 0.5 else (0.45 if th != T_LAKE else 0.0)
			var tint := 0.0 if th == T_LAKE else 1.0
			var edge_foam := 0.0 if th == T_LAKE else 0.28
			var ca := Color(foam, flow, tint)
			var cm := Color(maxf(foam, 0.0), flow, tint)
			var ce := Color(maxf(foam, edge_foam), flow, tint)
			var ma := pa
			var mbp := pb
			var ua := dist[i] / 6.0
			var ub := ua + DS / 6.0
			var xa := wa / 8.0
			var xb := wb / 8.0
			wmb.tri3(la, ma, mbp, Vector3.UP, ce, cm, cm, Vector2(-xa, ua), Vector2(0, ua), Vector2(0, ub))
			wmb.tri3(la, mbp, lb, Vector3.UP, ce, cm, ce, Vector2(-xa, ua), Vector2(0, ub), Vector2(-xb, ub))
			wmb.tri3(ma, ra, rb, Vector3.UP, cm, ce, ce, Vector2(0, ua), Vector2(xa, ua), Vector2(xb, ub))
			wmb.tri3(ma, rb, mbp, Vector3.UP, cm, ce, cm, Vector2(0, ua), Vector2(xb, ub), Vector2(0, ub))
		else:
			var rc: Color = cols["road"].lerp(Color("#55585d"), 0.5 + 0.5 * sin(i * 0.31)) if th != T_HILLS else cols["road"]
			rc = rc.lightened(_jit(i / 6, 0.04))
			mb.quad(la, ra, rb, lb, Vector3.UP, rc)
			# edge lines
			var e1 := rgt[i] * (wa - 1.4)
			var e1b := rgt[j] * (wb - 1.4)
			var e2 := rgt[i] * (wa - 1.9)
			var e2b := rgt[j] * (wb - 1.9)
			var up := Vector3(0, 0.03, 0)
			mb.quad(pa - e1 + up, pa - e2 + up, pb - e2b + up, pb - e1b + up, Vector3.UP, Color("#e8e8e0"))
			mb.quad(pa + e2 + up, pa + e1 + up, pb + e1b + up, pb + e2b + up, Vector3.UP, Color("#e8e8e0"))
			if (i / 3) % 2 == 0 and wid[i] > 9.0:
				var cw := rgt[i] * 0.16
				var cwb := rgt[j] * 0.16
				mb.quad(pa - cw + up, pa + cw + up, pb + cwb + up, pb - cwb + up, Vector3.UP, Color("#f4f0e0"))
			# red / white kerbs inside the walls
			var kc := Color("#d8342b") if (i / 2) % 2 == 0 else Color("#f1f1ea")
			var ka := rgt[i] * (wa - 0.0)
			var kb := rgt[j] * (wb - 0.0)
			var kin := rgt[i] * (wa - 1.1)
			var kinb := rgt[j] * (wb - 1.1)
			mb.quad(pa - ka + up, pa - kin + up, pb - kinb + up, pb - kb + up, Vector3.UP, kc)
			mb.quad(pa + kin + up, pa + ka + up, pb + kb + up, pb + kinb + up, Vector3.UP, kc)
	if not gap and (flg[i] & F_BOOST) != 0:
		var bc := Color("#ffb400") if (i / 2) % 2 == 0 else Color("#ff6a00")
		var bw := wa * 0.5
		var bu := Vector3(0, 0.07, 0)
		mb.quad(pa - rgt[i] * bw + bu, pa + rgt[i] * bw + bu, pb + rgt[j] * bw + bu, pb - rgt[j] * bw + bu, Vector3.UP, bc)
	# walls, caps and slopes, both sides
	for side: float in [-1.0, 1.0]:
		var hh_a: float = wl[i] if side < 0.0 else wr[i]
		var hh_b: float = wl[j] if side < 0.0 else wr[j]
		var ea := (la if side < 0.0 else ra)
		var eb := (lb if side < 0.0 else rb)
		var ra_out := rgt[i] * side
		var rb_out := rgt[j] * side
		var ext_a := _ext(i, side, th)
		var ext_b := _ext(j, side, thm[j])
		var ta := ea + Vector3(0, hh_a, 0)
		var tb := eb + Vector3(0, hh_b, 0)
		var ca2 := ta + ra_out * ext_a.x
		var cb2 := tb + rb_out * ext_b.x
		var sa := ca2 + ra_out * ext_a.y
		var sb := cb2 + rb_out * ext_b.y
		sa.y = y_ground
		sb.y = y_ground
		if th == T_DAM:
			sa.y = y_ground
		var wcol: Color = cols["wall"]
		var inward := -ra_out
		var jit := _jit(i, 0.05)
		if hh_a > 4.0:
			# strata bands
			var bands := 3
			for b in bands:
				var f0 := float(b) / bands
				var f1 := float(b + 1) / bands
				var c0 := wcol.darkened(0.22 - 0.1 * b + 0.06 * jit).lightened(0.0)
				mb.quad(ea.lerp(ta, f0), eb.lerp(tb, f0), eb.lerp(tb, f1), ea.lerp(ta, f1), inward, c0)
		else:
			mb.quad(ea, eb, tb, ta, inward, wcol.lightened(jit))
		mb.quad(ta, tb, cb2, ca2, Vector3.UP, (cols["cap"] as Color).lightened(jit))
		var sn := (ra_out + Vector3.UP * 0.7).normalized()
		mb.quad(ca2, cb2, sb, sa, sn, (cols["slope"] as Color).lightened(jit))


# ---------------------------------------------------------------- scenery

const BCOL := ["#e8dcc0", "#d9c7a0", "#efe6d2", "#cfb893", "#e3cfa8", "#f2ede0", "#d6b79a", "#c9b08a"]


func _cap_pos(i: int, side: float, off: float) -> Vector3:
	var hh: float = wl[i] if side < 0.0 else wr[i]
	return pos[i] + rgt[i] * side * (wid[i] * 0.5 + off) + Vector3(0, hh, 0)


func _building(mb: MB, i: int, side: float, off: float, depth: float, along: float, ht: float, col: Color) -> void:
	var c := _cap_pos(i, side, off + depth * 0.5)
	if not clear_of_track(c.x, c.z, maxf(depth, along) * 0.6, i, 70):
		return
	var yaw := yaw_at(i)
	mb.box(c + Vector3(0, ht * 0.5, 0), Vector3(depth, ht, along), yaw, col)
	# dark window bands on the side that faces the track
	var face := c - rgt[i] * side * (depth * 0.5 + 0.06)
	var bands := clampi(int(ht / 7.0), 1, 4)
	for b in bands:
		var by := ht * (0.2 + 0.7 * float(b) / maxf(bands, 1))
		mb.box(face + Vector3(0, by, 0), Vector3(0.14, 1.7, along * 0.86), yaw, Color("#3a4a5c"), 1.0)
	mb.box(c + Vector3(0, ht + 0.35, 0), Vector3(depth + 0.6, 0.7, along + 0.6), yaw, col.darkened(0.25))


func _tree(mb: MB, p: Vector3, kind: int, r: float) -> void:
	if kind == 0:
		mb.cyl(p, 0.25, 1.4, 5, Color("#5a4630"))
		mb.pyramid(p + Vector3(0, 0.8, 0), 1.5 + r * 0.6, 9.0 + r * 4.0, 6, Color("#2f5a35").lightened(r * 0.1), r * 3.0, 0.0)
	elif kind == 1:
		mb.cyl(p, 0.3, 2.6, 5, Color("#6a5238"))
		mb.pyramid(p + Vector3(0, 2.2, 0), 2.7 + r, 2.6, 7, Color("#6f8a4c").lightened(r * 0.1), r * 5.0, 0.8)
	else:
		mb.cyl(p, 0.28, 7.0 + r * 2.0, 5, Color("#8a6a45"))
		mb.pyramid(p + Vector3(0, 7.0 + r * 2.0 - 0.2, 0), 3.4, 1.1, 8, Color("#3f7d3a"), r * 2.0, 0.3)


func _rock(mb: MB, p: Vector3, r: float, col: Color) -> void:
	mb.pyramid(p + Vector3(0, -0.2, 0), r, r * 0.9, 6, col, r * 2.0, r * 0.4)


func _lamp(mb: MB, p: Vector3) -> void:
	mb.cyl(p, 0.12, 6.0, 5, Color("#4b4f58"))
	mb.box(p + Vector3(0, 6.1, 0), Vector3(0.6, 0.18, 0.6), 0.0, Color("#fff2c0"), 1.0)


func _buoy(mb: MB, p: Vector3, col: Color) -> void:
	mb.cyl(p + Vector3(0, -0.2, 0), 0.7, 1.4, 6, col)
	mb.pyramid(p + Vector3(0, 1.2, 0), 0.7, 1.2, 6, Color("#f4f4f0"), 0.0, 0.1)


func _scenery(high: bool) -> void:
	var r := _rng
	for i in n:
		var th := thm[i]
		var mb := _mb(i)
		var fl := flg[i]
		var in_gap := (fl & F_GAP) != 0
		match th:
			T_LAKE:
				if i % 4 == 0 and boat and not in_gap:
					var off := wid[i] * 0.5 - 4.0
					_buoy(mb, pos[i] - rgt[i] * off + Vector3(0, 0.1, 0), Color("#d8342b"))
					_buoy(mb, pos[i] + rgt[i] * off + Vector3(0, 0.1, 0), Color("#2f9a4a"))
				if i % 6 == 0:
					for side: float in [-1.0, 1.0]:
						if r.randf() < 0.8:
							var ext := _ext(i, side, th)
							var dpt := r.randf_range(7.0, 11.0)
							var ht := r.randf_range(9.0, 26.0)
							if ext.x > dpt + 12.0:
								_building(mb, i, side, r.randf_range(5.0, 9.0), dpt, r.randf_range(11.0, 15.0), ht, Color(BCOL[r.randi() % BCOL.size()]))
				if i % 3 == 0:
					for side: float in [-1.0, 1.0]:
						if r.randf() < 0.55:
							var p := _cap_pos(i, side, 2.5)
							if clear_of_track(p.x, p.z, 2.0, i, 60):
								_tree(mb, p, 2, r.randf())
			T_CANYON:
				if i % 3 == 0:
					for side: float in [-1.0, 1.0]:
						var ext2 := _ext(i, side, th)
						if r.randf() < 0.5 and ext2.x > 5.0:
							var p2 := _cap_pos(i, side, r.randf_range(1.5, ext2.x - 2.0))
							if clear_of_track(p2.x, p2.z, 2.5, i, 60):
								if r.randf() < 0.55:
									_rock(mb, p2, r.randf_range(1.2, 3.2), Color("#6e6354").lightened(r.randf() * 0.12))
								else:
									_tree(mb, p2, r.randi() % 2, r.randf())
			T_CITY:
				if i % 5 == 0 and not in_gap:
					for side: float in [-1.0, 1.0]:
						var ext3 := _ext(i, side, th)
						var dpt3 := r.randf_range(10.0, 18.0)
						if ext3.x > dpt3 + 8.0 and r.randf() < 0.9:
							_building(mb, i, side, r.randf_range(3.0, 6.0), dpt3, r.randf_range(11.0, 14.0), r.randf_range(10.0, 40.0), Color(BCOL[r.randi() % BCOL.size()]))
				if i % 12 == 3:
					for side: float in [-1.0, 1.0]:
						_lamp(mb, _cap_pos(i, side, 1.4))
				if i % 8 == 5:
					for side: float in [-1.0, 1.0]:
						if r.randf() < 0.5:
							var p3 := _cap_pos(i, side, 2.2)
							_tree(mb, p3, 1, r.randf())
			T_HILLS:
				if i % 3 == 0:
					for side: float in [-1.0, 1.0]:
						var ext4 := _ext(i, side, th)
						if r.randf() < 0.6 and ext4.x > 4.0:
							var p4 := _cap_pos(i, side, r.randf_range(1.5, ext4.x - 1.0))
							if clear_of_track(p4.x, p4.z, 2.5, i, 60):
								if r.randf() < 0.4:
									_rock(mb, p4, r.randf_range(1.0, 2.6), Color("#8b7d68").lightened(r.randf() * 0.1))
								else:
									_tree(mb, p4, r.randi() % 2, r.randf())
			T_DAM:
				if i % 10 == 0 and not boat:
					for side: float in [-1.0, 1.0]:
						_lamp(mb, _cap_pos(i, side, 0.6))
		# direction boards on the outside of bends (cars)
		if not boat and i % 6 == 0 and absf(kss[i]) > 0.011 and not in_gap:
			var sd := 1.0 if kss[i] > 0.0 else -1.0
			var hh: float = wl[i] if sd < 0.0 else wr[i]
			if hh < 4.0:
				var bp := _cap_pos(i, sd, 1.6)
				mb.box(bp + Vector3(0, 1.4, 0), Vector3(0.3, 2.0, 3.4), yaw_at(i), Color("#f2c81c"), 1.0)
				mb.box(bp + Vector3(0, 1.4, 0) - rgt[i] * sd * 0.18, Vector3(0.1, 0.6, 3.0), yaw_at(i), Color("#1a1a1a"), 1.0)
	# gates, dams, bridges, reservoirs
	_gantry(start_idx, "START")
	gantries.append([start_idx, "START"])
	if not closed:
		_gantry(finish_idx, "FINISH")
		gantries.append([finish_idx, "FINISH"])
	for d in dams:
		_dam_towers(d)
	for b in bridges:
		_bridge(b)
	for rv in reservoirs:
		pass
	if reservoirs.size() >= 2:
		_reservoir(int(reservoirs[0][0]), int(reservoirs[1][0]))
	_grandstand(start_idx)


func _gantry(idx: int, _label: String) -> void:
	var mb := _mb(idx)
	var p := pos[idx]
	var yaw := yaw_at(idx)
	var h := 10.0 if not boat else 12.0
	var half := wid[idx] * 0.5 + 1.6
	for side: float in [-1.0, 1.0]:
		var base := p + rgt[idx] * side * half
		mb.box(base + Vector3(0, h * 0.5, 0), Vector3(1.6, h, 1.6), yaw, Color("#e8e8e0"))
	var cnt := int(half * 2.0 / 4.0)
	for k in cnt:
		var u := (float(k) + 0.5) / cnt * 2.0 - 1.0
		var col := Color("#d8342b") if k % 2 == 0 else Color("#f4f4f0")
		mb.box(p + rgt[idx] * u * half + Vector3(0, h + 0.8, 0), Vector3(1.0, 1.8, 4.0 * 1.0), yaw, col, 1.0)
	# chequered line on the surface
	var cells := int(wid[idx] / 1.6)
	var up := Vector3(0, 0.05, 0)
	for k in cells:
		for row in 2:
			if (k + row) % 2 == 0:
				var a := -wid[idx] * 0.5 + wid[idx] * float(k) / cells
				var b := -wid[idx] * 0.5 + wid[idx] * float(k + 1) / cells
				var f0 := fwd[idx] * (row * 1.4 - 1.4)
				var f1 := fwd[idx] * ((row + 1) * 1.4 - 1.4)
				var qa := p + rgt[idx] * a + f0 + up
				var qb := p + rgt[idx] * b + f0 + up
				var qc := p + rgt[idx] * b + f1 + up
				var qd := p + rgt[idx] * a + f1 + up
				mb.quad(qa, qb, qc, qd, Vector3.UP, Color("#16161a"))


func _dam_towers(idx: int) -> void:
	var mb := _mb(idx)
	var p := pos[idx]
	var yaw := yaw_at(idx)
	var conc := Color("#b4b8bc")
	var half := wid[idx] * 0.5 + 3.5
	for side: float in [-1.0, 1.0]:
		var base := p + rgt[idx] * side * half
		mb.box(base + Vector3(0, 8.0, 0), Vector3(5.0, 36.0, 5.0), yaw, conc)
		mb.box(base + Vector3(0, 27.0, 0), Vector3(6.2, 2.0, 6.2), yaw, conc.darkened(0.15))
		for g in 3:
			mb.box(base + Vector3(0, 6.0 + g * 5.0, 0) - rgt[idx] * side * 2.6, Vector3(0.2, 1.4, 1.4), yaw, Color("#2f6fb5"), 1.0)
	mb.box(p + Vector3(0, 26.0, 0), Vector3(half * 2.0 + 4.0, 1.0, 3.0), yaw, conc.lightened(0.06))
	for g in 5:
		var u := (float(g) + 0.5) / 5.0 * 2.0 - 1.0
		mb.box(p + rgt[idx] * u * half * 0.9 + Vector3(0, 22.0, 0), Vector3(2.4, 7.0, 0.6), yaw, Color("#2f6fb5"), 1.0)


func _bridge(lip: int) -> void:
	var gi := _cl(lip + 4)
	var mb := _mb(gi)
	var p := pos[gi]
	var yaw := yaw_at(gi)
	var top := maxf(wl[gi], wr[gi]) + 1.0
	if top < 5.0:
		top = 6.0
	var span := wid[gi] * 0.5 + _ext(gi, -1.0, thm[gi]).x + 4.0
	mb.box(p + Vector3(0, top + 0.5, 0), Vector3(span * 2.0, 1.4, 9.0), yaw, Color("#c7bfa8"))
	mb.box(p + Vector3(0, top + 1.5, 0) + rgt[gi] * (span - 0.4), Vector3(0.6, 1.0, 9.0), yaw, Color("#a79f88"))
	mb.box(p + Vector3(0, top + 1.5, 0) - rgt[gi] * (span - 0.4), Vector3(0.6, 1.0, 9.0), yaw, Color("#a79f88"))
	for side: float in [-1.0, 1.0]:
		var hh: float = wl[gi] if side < 0.0 else wr[gi]
		var c := p + rgt[gi] * side * (wid[gi] * 0.5 + 3.0)
		var h := top - hh + 0.2
		mb.box(Vector3(c.x, p.y + hh + h * 0.5, c.z), Vector3(3.0, h, 7.0), yaw, Color("#b7ae96"))


func _reservoir(i0: int, i1: int) -> void:
	var mb := _mb(i0, true)
	var lo := mini(i0, i1)
	var hi := maxi(i0, i1)
	var depth := 6.0
	for i in range(lo, hi - 1, 2):
		var j := mini(i + 2, hi)
		var a0 := pos[i] - rgt[i] * (wid[i] * 0.5 + 0.5) + Vector3(0, -depth, 0)
		var a1 := pos[i] - rgt[i] * 170.0 + Vector3(0, -depth, 0)
		var b0 := pos[j] - rgt[j] * (wid[j] * 0.5 + 0.5) + Vector3(0, -depth, 0)
		var b1 := pos[j] - rgt[j] * 170.0 + Vector3(0, -depth, 0)
		var cc := Color(0.0, 0.1, 1.0)
		var ua := dist[i] / 6.0
		var ub := dist[j] / 6.0
		mb.tri3(a1, a0, b0, Vector3.UP, cc, cc, cc, Vector2(-20, ua), Vector2(0, ua), Vector2(0, ub))
		mb.tri3(a1, b0, b1, Vector3.UP, cc, cc, cc, Vector2(-20, ua), Vector2(0, ub), Vector2(-20, ub))


func _grandstand(idx: int) -> void:
	var mb := _mb(idx)
	var side := 1.0
	var yaw := yaw_at(idx)
	var base := _cap_pos(idx, side, 4.0) + fwd[idx] * 6.0
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	if not clear_of_track(base.x, base.z, 14.0, idx, 80):
		side = -1.0
		base = _cap_pos(idx, side, 4.0) + fwd[idx] * 6.0
		if not clear_of_track(base.x, base.z, 14.0, idx, 80):
			return
	for row in 5:
		var c := base + rgt[idx] * side * (row * 2.2 + 1.0) + Vector3(0, row * 1.1 + 0.5, 0)
		mb.box(c, Vector3(2.2, 1.0 + row * 0.2, 30.0), yaw, Color("#8a8f98"))
		for k in 14:
			var cc := Color.from_hsv(rr.randf(), 0.5 + rr.randf() * 0.4, 0.55 + rr.randf() * 0.4)
			var fp := c + fwd[idx] * (-13.0 + k * 2.0 + rr.randf()) + Vector3(0, 1.0 + row * 0.1, 0)
			mb.box(fp, Vector3(0.7, 1.2, 0.7), yaw, cc, 1.0)
	mb.box(base + rgt[idx] * side * 12.0 + Vector3(0, 8.0, 0), Vector3(0.4, 0.4, 0.4), yaw, Color.WHITE, 1.0)
