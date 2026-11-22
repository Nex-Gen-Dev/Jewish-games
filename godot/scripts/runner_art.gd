extends RefCounted
## Stylised, colourful world for Street Runner. Everything is baked into a few
## vertex-coloured meshes (one draw call per chunk), so it is cheap on tablets.

const LIGHT := Vector3(0.4, 0.85, 0.35)

const WALLS_DAY := ["#ff9e80", "#ffd54f", "#81d4fa", "#a5d6a7", "#f48fb1", "#ce93d8", "#ffcc80", "#80cbc4", "#fff59d", "#ef9a9a", "#90caf9"]
const ROOFS_DAY := ["#b23a2e", "#7a4a3a", "#3f5aa0", "#2e8b6f", "#9a3b73", "#c75b2a"]
const WALLS_NIGHT := ["#4a4fb0", "#7d44b0", "#2b86ad", "#b04480", "#3f78b8", "#5a3fa0"]
const ROOFS_NIGHT := ["#262a66", "#3a2266", "#154a66", "#661f48", "#1d3d66"]
const NEON := ["#ff3df0", "#35f0ff", "#ffe93d", "#7dff4a", "#ff7a3d"]
const CAR_COLORS := ["#e53935", "#1e88e5", "#fdd835", "#43a047", "#8e24aa", "#fb8c00", "#ec407a", "#00acc1", "#f5f5f5"]


class MB extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func _face(pts: Array, col: Color, glow := false) -> void:
		var nrm := (Vector3(pts[1]) - Vector3(pts[0])).cross(Vector3(pts[2]) - Vector3(pts[0])).normalized()
		var shade := 1.0
		if not glow:
			shade = 0.6 + 0.4 * maxf(0.0, absf(nrm.dot(LIGHT.normalized())) if nrm.y > 0.5 else nrm.dot(LIGHT.normalized()))
			if nrm.y < -0.5:
				shade = 0.5
		var cc := Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
		for tri in [[0, 1, 2], [0, 2, 3]] if pts.size() == 4 else [[0, 1, 2]]:
			for i in tri:
				v.append(pts[i])
				n.append(nrm)
				c.append(cc)

	func box(center: Vector3, size: Vector3, col: Color, yaw := 0.0, glow := false) -> void:
		var h := size / 2.0
		var cs: Array = []
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					var p := Vector3(sx * h.x, sy * h.y, sz * h.z)
					if yaw != 0.0:
						p = p.rotated(Vector3.UP, yaw)
					cs.append(center + p)
		# index = (sx>0)*4 + (sy>0)*2 + (sz>0)
		_face([cs[4], cs[5], cs[7], cs[6]], col, glow) # +x
		_face([cs[0], cs[1], cs[3], cs[2]], col, glow) # -x
		_face([cs[2], cs[3], cs[7], cs[6]], col, glow) # +y
		_face([cs[0], cs[1], cs[5], cs[4]], col, glow) # -y
		_face([cs[1], cs[3], cs[7], cs[5]], col, glow) # +z
		_face([cs[0], cs[2], cs[6], cs[4]], col, glow) # -z

	## Gable roof: ridge runs along Z. size.x = width, size.y = height, size.z = length.
	func prism(center: Vector3, size: Vector3, col: Color, gable: Color) -> void:
		var h := size / 2.0
		var a := center + Vector3(-h.x, -h.y, -h.z)
		var b := center + Vector3(h.x, -h.y, -h.z)
		var t0 := center + Vector3(0, h.y, -h.z)
		var a2 := center + Vector3(-h.x, -h.y, h.z)
		var b2 := center + Vector3(h.x, -h.y, h.z)
		var t1 := center + Vector3(0, h.y, h.z)
		_face([a, t0, t1, a2], col)
		_face([b, b2, t1, t0], col.lightened(0.12))
		_face([a, b, t0], gable)
		_face([a2, t1, b2], gable)
		_face([a, a2, b2, b], col.darkened(0.3))

	func cone(center: Vector3, r: float, height: float, col: Color, seg := 7) -> void:
		var top := center + Vector3(0, height / 2.0, 0)
		var base := center - Vector3(0, height / 2.0, 0)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			_face([base + Vector3(cos(a0), 0, sin(a0)) * r, top, base + Vector3(cos(a1), 0, sin(a1)) * r], col)

	func cyl(center: Vector3, r: float, length: float, col: Color, axis := "y", seg := 10, glow := false) -> void:
		var h := length / 2.0
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
			var q: Array = []
			for p in [p0 + Vector3(0, -h, 0), p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), p1 + Vector3(0, -h, 0)]:
				q.append(center + _ax(p, axis))
			_face(q, col, glow)
			_face([center + _ax(Vector3(0, h, 0), axis), center + _ax(p0 + Vector3(0, h, 0), axis), center + _ax(p1 + Vector3(0, h, 0), axis)], col, glow)
			_face([center + _ax(Vector3(0, -h, 0), axis), center + _ax(p1 + Vector3(0, -h, 0), axis), center + _ax(p0 + Vector3(0, -h, 0), axis)], col, glow)

	func _ax(p: Vector3, axis: String) -> Vector3:
		match axis:
			"x":
				return Vector3(p.y, p.x, p.z)
			"z":
				return Vector3(p.x, p.z, p.y)
		return p

	static var _m: StandardMaterial3D

	static func shared_material() -> StandardMaterial3D:
		if _m == null:
			_m = StandardMaterial3D.new()
			_m.vertex_color_use_as_albedo = true
			_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return _m

	func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if v.size() == 0:
			return mesh
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, MB.shared_material())
		return mesh


static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func col(s: String) -> Color:
	return Color(s)


static func pick(arr: Array, rng: RandomNumberGenerator) -> Color:
	return Color(arr[rng.randi() % arr.size()])


# ---------------------------------------------------------------- street

## One 30 m piece of street (road, sidewalks, houses, trees, lamps) as one mesh.
## Local z runs from 0 (near) to -30 (far).
static func street_chunk(rng: RandomNumberGenerator, night: bool, lane: float, crosswalk: bool) -> ArrayMesh:
	var m := MB.new()
	var half := lane * 1.5 + 0.6
	var road := Color("#3b3f52") if night else Color("#575c70")
	m.box(Vector3(0, -0.2, -15), Vector3(half * 2, 0.4, 30), road)
	for i in range(3):
		m.box(Vector3(-lane / 2.0, 0.005, -2.5 - i * 10.0), Vector3(0.12, 0.02, 4.0), Color("#f2e9a8"))
		m.box(Vector3(lane / 2.0, 0.005, -2.5 - i * 10.0), Vector3(0.12, 0.02, 4.0), Color("#f2e9a8"))
	if crosswalk:
		for k in range(7):
			m.box(Vector3(-half + 0.6 + k * (half * 2 - 1.2) / 6.0, 0.012, -22.0), Vector3(0.6, 0.02, 3.0), Color("#f4f4f4"))
	for side in [-1, 1]:
		var sx: float = side * (half + 1.5)
		m.box(Vector3(sx, -0.05, -15), Vector3(3.0, 0.3, 30), Color("#9a9aa8") if night else Color("#c9c4b8"))
		m.box(Vector3(side * (half + 0.12), 0.02, -15), Vector3(0.25, 0.4, 30), Color("#6a6a7a") if night else Color("#e8e2d4"))
		var zz := 0.0
		while zz < 29.0:
			var w := rng.randf_range(5.5, 8.5)
			var kind := rng.randf()
			if kind < 0.14:
				_tree_row(m, side, half, -zz - w / 2.0, rng)
			else:
				_house(m, side, half + 3.0, -zz - w / 2.0, w, rng, night)
			zz += w + rng.randf_range(0.0, 0.6)
		_lamp(m, side, half + 0.7, -8.0, night)
		_lamp(m, side, half + 0.7, -23.0, night)
	return m.build()


static func _tree_row(m: MB, side: int, half: float, z: float, rng: RandomNumberGenerator) -> void:
	for i in 2:
		var x: float = side * (half + 2.0 + i * 3.4 + rng.randf_range(0, 1.0))
		var zz := z + rng.randf_range(-2.0, 2.0)
		var h := rng.randf_range(2.5, 4.0)
		m.box(Vector3(x, h * 0.28, zz), Vector3(0.35, h * 0.56, 0.35), Color("#7a4e2d"))
		var g := Color.from_hsv(rng.randf_range(0.25, 0.4), rng.randf_range(0.6, 0.85), rng.randf_range(0.6, 0.85))
		m.cone(Vector3(x, h * 0.75, zz), 1.5, h * 0.7, g)
		m.cone(Vector3(x, h * 1.05, zz), 1.1, h * 0.55, g.lightened(0.1))


static func _lamp(m: MB, side: int, x: float, z: float, night: bool) -> void:
	var xx: float = side * x
	m.box(Vector3(xx, 2.1, z), Vector3(0.14, 4.2, 0.14), Color("#2a2a36"))
	m.box(Vector3(xx - side * 0.5, 4.2, z), Vector3(1.0, 0.1, 0.1), Color("#2a2a36"))
	m.box(Vector3(xx - side * 0.95, 4.1, z), Vector3(0.5, 0.18, 0.4), Color("#fff2b0"), 0.0, true)


static func _house(m: MB, side: int, x_in: float, z: float, w: float, rng: RandomNumberGenerator, night: bool) -> void:
	var d := rng.randf_range(5.0, 7.0)
	var floors := rng.randi_range(2, 4)
	var h := floors * 3.0
	var wall := pick(WALLS_NIGHT if night else WALLS_DAY, rng)
	var roof := pick(ROOFS_NIGHT if night else ROOFS_DAY, rng)
	var cx: float = side * (x_in + d / 2.0)
	var face: float = side * x_in ## the wall facing the street
	var s: float = -side ## direction from wall to street
	m.box(Vector3(cx, h / 2.0, z), Vector3(d, h, w), wall)
	m.box(Vector3(cx, 0.3, z), Vector3(d + 0.1, 0.6, w + 0.1), wall.darkened(0.25)) ## plinth
	m.box(Vector3(cx, h + 0.1, z), Vector3(d + 0.5, 0.25, w + 0.5), wall.lightened(0.25)) ## cornice
	var roof_h := rng.randf_range(1.8, 3.0)
	if rng.randf() < 0.75:
		m.prism(Vector3(cx, h + 0.2 + roof_h / 2.0, z), Vector3(d + 0.7, roof_h, w + 0.7), roof, wall.lightened(0.1))
	else:
		m.box(Vector3(cx, h + 0.6, z), Vector3(d + 0.3, 0.7, w + 0.3), roof)
	if rng.randf() < 0.6:
		m.box(Vector3(cx + side * d * 0.25, h + roof_h * 0.9, z + w * 0.2), Vector3(0.7, 1.6, 0.7), Color("#8a4a3a"))
	# windows on the street side
	var cols := maxi(int(w / 2.3), 1)
	var gap := w / cols
	for f in floors:
		for k in cols:
			var wz := z - w / 2.0 + gap * (k + 0.5)
			var wy := 1.9 + f * 3.0
			if f == 0 and absf(k - (cols - 1) / 2.0) < 0.6 and cols % 2 == 1:
				continue
			var lit := rng.randf() < (0.7 if night else 0.3)
			var glass := Color("#ffd878") if lit else Color("#9fd8f5")
			m.box(Vector3(face + s * 0.06, wy, wz), Vector3(0.14, 1.45, 1.15), Color("#fdfdfd"))
			m.box(Vector3(face + s * 0.13, wy, wz), Vector3(0.1, 1.2, 0.9), glass, 0.0, lit)
			m.box(Vector3(face + s * 0.14, wy, wz), Vector3(0.12, 0.08, 0.95), Color("#fdfdfd"))
			if f > 0 and rng.randf() < 0.25:
				m.box(Vector3(face + s * 0.5, wy - 0.85, wz), Vector3(1.0, 0.12, 1.5), Color("#4a4a58")) ## balcony
				m.box(Vector3(face + s * 0.95, wy - 0.4, wz), Vector3(0.06, 0.8, 1.5), Color("#2a2a36"))
	# door + step + awning
	var door := pick(["#b23a2e", "#2b6cb0", "#2e8b6f", "#7a4a2d", "#c27b1e"], rng)
	var dz := z + (0.0 if cols % 2 == 1 else gap / 2.0)
	m.box(Vector3(face + s * 0.1, 1.15, dz), Vector3(0.18, 2.3, 1.3), Color("#fdfdfd"))
	m.box(Vector3(face + s * 0.2, 1.1, dz), Vector3(0.12, 2.1, 1.05), door)
	m.box(Vector3(face + s * 0.28, 1.1, dz + 0.35), Vector3(0.08, 0.12, 0.12), Color("#ffd34a"), 0.0, true)
	m.box(Vector3(face + s * 0.6, 0.12, dz), Vector3(1.0, 0.25, 1.8), Color("#bdb8ac"))
	if rng.randf() < 0.5:
		var a1 := pick(["#e53935", "#1e88e5", "#43a047", "#fb8c00"], rng)
		for i in 6:
			m.box(Vector3(face + s * 0.9, 2.65 - i * 0.0, dz - 1.25 + i * 0.5), Vector3(1.3, 0.12, 0.5), a1 if i % 2 == 0 else Color("#f6f6f6"), 0.0)
	if night and rng.randf() < 0.5:
		var nc := Color(NEON[rng.randi() % NEON.size()])
		m.box(Vector3(face + s * 0.2, 3.4, z), Vector3(0.1, 0.18, w * 0.7), nc, 0.0, true)


# ---------------------------------------------------------------- vehicles & blocks

## Front of the car points towards +Z (towards the player).
static func car(color: Color, taxi := false) -> ArrayMesh:
	var m := MB.new()
	m.box(Vector3(0, 0.6, 0), Vector3(1.85, 0.55, 4.1), color)
	m.box(Vector3(0, 0.95, 1.45), Vector3(1.8, 0.2, 1.2), color.lightened(0.08)) ## hood
	m.box(Vector3(0, 1.1, -0.15), Vector3(1.6, 0.6, 2.0), color.darkened(0.08)) ## cabin
	m.box(Vector3(0, 1.43, -0.15), Vector3(1.5, 0.08, 1.9), color.lightened(0.15)) ## roof
	var glass := Color("#6fb9d8")
	m.box(Vector3(0, 1.12, 0.88), Vector3(1.45, 0.45, 0.05), glass) ## windshield
	m.box(Vector3(0, 1.12, -1.18), Vector3(1.4, 0.4, 0.05), glass)
	for sx in [-1, 1]:
		m.box(Vector3(sx * 0.82, 1.14, -0.15), Vector3(0.05, 0.4, 1.7), glass)
		m.box(Vector3(sx * 0.93, 0.62, 0.0), Vector3(0.04, 0.12, 3.6), color.darkened(0.3))
		for sz in [-1.25, 1.25]:
			m.cyl(Vector3(sx * 0.9, 0.36, sz), 0.38, 0.28, Color("#18181e"), "x", 10)
			m.cyl(Vector3(sx * 0.93, 0.36, sz), 0.2, 0.3, Color("#c8ccd4"), "x", 8)
		m.box(Vector3(sx * 0.62, 0.72, 2.07), Vector3(0.4, 0.2, 0.08), Color("#fff6c0"), 0.0, true)
		m.box(Vector3(sx * 0.65, 0.72, -2.07), Vector3(0.35, 0.18, 0.08), Color("#ff3b3b"), 0.0, true)
	m.box(Vector3(0, 0.38, 2.08), Vector3(1.9, 0.22, 0.14), Color("#2b2b34"))
	m.box(Vector3(0, 0.38, -2.08), Vector3(1.9, 0.22, 0.14), Color("#2b2b34"))
	if taxi:
		m.box(Vector3(0, 1.58, -0.15), Vector3(0.7, 0.2, 0.3), Color("#fff6c0"), 0.0, true)
		m.box(Vector3(0, 0.82, -0.15), Vector3(1.88, 0.1, 2.05), Color("#222"))
	return m.build()


static func bus(color: Color) -> ArrayMesh:
	var m := MB.new()
	m.box(Vector3(0, 1.45, 0), Vector3(2.0, 2.2, 7.4), color)
	m.box(Vector3(0, 2.62, 0), Vector3(1.9, 0.12, 7.2), color.lightened(0.25))
	m.box(Vector3(0, 0.55, 0), Vector3(2.02, 0.4, 7.4), color.darkened(0.3))
	for sx in [-1, 1]:
		m.box(Vector3(sx * 1.01, 1.8, 0.0), Vector3(0.05, 0.75, 6.6), Color("#7fc4e8"))
		for sz in [-2.4, 2.4]:
			m.cyl(Vector3(sx * 0.95, 0.45, sz), 0.48, 0.3, Color("#18181e"), "x", 10)
			m.cyl(Vector3(sx * 0.98, 0.45, sz), 0.25, 0.32, Color("#c8ccd4"), "x", 8)
		m.box(Vector3(sx * 0.7, 0.85, 3.72), Vector3(0.4, 0.22, 0.08), Color("#fff6c0"), 0.0, true)
	m.box(Vector3(0, 1.9, 3.72), Vector3(1.8, 0.8, 0.05), Color("#7fc4e8"))
	m.box(Vector3(0, 2.4, 3.74), Vector3(1.2, 0.25, 0.05), Color("#ffe14a"), 0.0, true)
	return m.build()


## Crates / dumpster / market cart: 1.4 m high so a good jump can land on them.
static func block(kind: int, rng: RandomNumberGenerator) -> ArrayMesh:
	var m := MB.new()
	match kind % 3:
		0: # wooden crates
			m.box(Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 1.6), Color("#c98a45"))
			for y in [0.3, 1.1]:
				m.box(Vector3(0, y, 0), Vector3(1.66, 0.18, 1.66), Color("#a8672c"))
			for sx in [-0.78, 0.78]:
				for sz in [-0.78, 0.78]:
					m.box(Vector3(sx, 0.7, sz), Vector3(0.14, 1.42, 0.14), Color("#8a5222"))
		1: # dumpster
			m.box(Vector3(0, 0.62, 0), Vector3(1.7, 1.1, 1.7), Color("#2e9e5a"))
			m.box(Vector3(0, 1.3, 0), Vector3(1.8, 0.2, 1.8), Color("#1d6e3e"))
			m.box(Vector3(0, 0.95, 0.86), Vector3(1.2, 0.2, 0.04), Color("#fdfdfd"))
		2: # market cart
			m.box(Vector3(0, 0.55, 0), Vector3(1.6, 0.8, 1.6), Color("#e8dcc0"))
			for i in 4:
				m.box(Vector3(-0.6 + i * 0.4, 1.3, 0), Vector3(0.4, 0.14, 1.75), Color("#e53935") if i % 2 == 0 else Color("#fdfdfd"))
			for sx in [-0.75, 0.75]:
				m.box(Vector3(sx, 0.9, 0.78), Vector3(0.08, 1.0, 0.08), Color("#6a6a74"))
			m.box(Vector3(0, 0.95, 0), Vector3(1.3, 0.3, 1.3), Color("#ff9e40"))
	return m.build()


static func hurdle(lane: float) -> ArrayMesh:
	var m := MB.new()
	var wdt := lane * 3.0
	var seg := 10
	for i in seg:
		var c := Color("#e53935") if i % 2 == 0 else Color("#fdfdfd")
		m.box(Vector3(-wdt / 2.0 + (i + 0.5) * wdt / seg, 0.78, 0), Vector3(wdt / seg, 0.24, 0.3), c)
		m.box(Vector3(-wdt / 2.0 + (i + 0.5) * wdt / seg, 0.46, 0), Vector3(wdt / seg, 0.24, 0.3), c if i % 2 == 1 else Color("#fdfdfd"))
	for sx in [-1, 1]:
		m.box(Vector3(sx * (wdt / 2.0 - 0.1), 0.45, 0), Vector3(0.18, 0.9, 0.2), Color("#4a4a58"))
		m.box(Vector3(sx * (wdt / 2.0 - 0.1), 1.0, 0), Vector3(0.25, 0.16, 0.25), Color("#ffb300"), 0.0, true)
	return m.build()


static func beam(lane: float, night: bool) -> ArrayMesh:
	var m := MB.new()
	var wdt := lane * 3.1
	m.box(Vector3(0, 1.85, 0), Vector3(wdt, 0.8, 0.35), Color("#7b1fa2") if night else Color("#ff8f00"))
	for i in 8:
		m.box(Vector3(-wdt / 2.0 + (i + 0.5) * wdt / 8.0, 1.85, 0.2), Vector3(wdt / 8.0 * 0.5, 0.4, 0.05), Color("#ffe93d") if i % 2 == 0 else Color("#fdfdfd"), 0.0, true)
	m.box(Vector3(0, 1.38, 0), Vector3(wdt, 0.1, 0.4), Color("#222"))
	for sx in [-1, 1]:
		m.box(Vector3(sx * (wdt / 2.0 - 0.1), 1.1, 0), Vector3(0.28, 2.3, 0.28), Color("#555566"))
	return m.build()


static func coin_mesh() -> ArrayMesh:
	var m := MB.new()
	m.cyl(Vector3.ZERO, 0.34, 0.09, Color("#ffd34a"), "z", 14, true)
	m.cyl(Vector3(0, 0, 0), 0.22, 0.12, Color("#ffb300"), "z", 12, true)
	return m.build()


# ---------------------------------------------------------------- the shul at the finish line

static func shul(lane: float) -> ArrayMesh:
	var m := MB.new()
	var stone := Color("#f2e6c8")
	var gold := Color("#ffd34a")
	var roof := Color("#3f5aa0")
	# steps
	m.box(Vector3(0, 0.15, 1.0), Vector3(12.0, 0.3, 3.0), Color("#d8ccb0"))
	m.box(Vector3(0, 0.4, 0.2), Vector3(11.0, 0.3, 2.0), Color("#e2d6ba"))
	# main hall
	m.box(Vector3(0, 5.0, -6.0), Vector3(13.0, 10.0, 11.0), stone)
	m.box(Vector3(0, 10.25, -6.0), Vector3(13.6, 0.5, 11.6), stone.darkened(0.15))
	m.prism(Vector3(0, 12.4, -6.0), Vector3(13.8, 3.8, 11.8), roof, stone)
	# towers
	for sx in [-1, 1]:
		m.box(Vector3(sx * 6.9, 6.5, -2.2), Vector3(2.6, 13.0, 3.0), stone.darkened(0.06))
		m.box(Vector3(sx * 6.9, 13.1, -2.2), Vector3(2.9, 0.4, 3.3), stone.darkened(0.2))
		m.cone(Vector3(sx * 6.9, 15.0, -2.2), 2.1, 3.6, roof.lightened(0.1), 4)
		m.box(Vector3(sx * 6.9, 9.5, -0.62), Vector3(1.0, 2.0, 0.1), Color("#ffe08a"), 0.0, true)
	# columns + door
	for i in 4:
		m.cyl(Vector3(-3.6 + i * 2.4, 3.2, -0.3), 0.38, 6.2, Color("#fffaf0"), "y", 10)
	m.box(Vector3(0, 6.5, -0.1), Vector3(10.4, 0.6, 1.2), Color("#fffaf0"))
	m.box(Vector3(0, 2.4, -0.55), Vector3(3.0, 4.6, 0.3), Color("#7a4a2d"))
	m.box(Vector3(0, 2.4, -0.38), Vector3(0.1, 4.4, 0.06), gold)
	m.cyl(Vector3(0, 4.7, -0.55), 1.5, 0.3, Color("#7a4a2d"), "z", 14)
	# arched windows (stained glass colours)
	var wc := ["#e53935", "#1e88e5", "#43a047", "#fdd835"]
	for i in 4:
		var x := -5.2 + i * 3.47
		if absf(x) < 1.0:
			continue
		m.box(Vector3(x, 6.8, -0.5), Vector3(1.5, 2.8, 0.15), Color(wc[i % 4]), 0.0, true)
		m.cyl(Vector3(x, 8.2, -0.5), 0.75, 0.15, Color(wc[i % 4]), "z", 10, true)
	# tablets (luchos) on the front
	for sx in [-1, 1]:
		m.box(Vector3(sx * 0.95, 8.9, -0.35), Vector3(1.5, 1.3, 0.3), Color("#fffaf0"))
		m.cyl(Vector3(sx * 0.95, 9.55, -0.35), 0.75, 0.3, Color("#fffaf0"), "z", 12)
		m.box(Vector3(sx * 0.95, 9.0, -0.18), Vector3(0.9, 0.12, 0.05), gold, 0.0, true)
		m.box(Vector3(sx * 0.95, 8.7, -0.18), Vector3(0.9, 0.12, 0.05), gold, 0.0, true)
		m.box(Vector3(sx * 0.95, 8.4, -0.18), Vector3(0.9, 0.12, 0.05), gold, 0.0, true)
	# finish arch across the road
	for sx in [-1, 1]:
		m.box(Vector3(sx * (lane * 1.5 + 0.4), 2.5, 4.0), Vector3(0.5, 5.0, 0.5), Color("#4a4a58"))
	m.box(Vector3(0, 5.2, 4.0), Vector3(lane * 3.0 + 1.5, 1.0, 0.5), Color("#1e88e5"))
	for i in 12:
		m.box(Vector3(-lane * 1.5 + (i + 0.5) * lane * 3.0 / 12.0, 5.2, 4.3), Vector3(lane * 3.0 / 12.0, 0.9, 0.06), Color("#fdfdfd") if i % 2 == 0 else Color("#222"))
	# checkered finish line
	for i in 12:
		for j in 2:
			m.box(Vector3(-lane * 1.5 + (i + 0.5) * lane * 3.0 / 12.0, 0.02, 4.0 + j * 0.5 - 0.25), Vector3(lane * 3.0 / 12.0, 0.03, 0.5), Color("#fdfdfd") if (i + j) % 2 == 0 else Color("#222"))
	return m.build()
