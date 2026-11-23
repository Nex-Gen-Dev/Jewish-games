extends RefCounted
## Detailed drivable vehicles for the city game (family car, motor boat).
## Built from primitives. Each maker returns a Dictionary of named parts for animation.
## Convention: front of the vehicle is -Z, +X is the right-hand side.

static var _mats := {}


static func m(c: Color, rough := 0.6, metal := 0.0, emis := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s_%s" % [c.to_html(true), rough, metal, emis, alpha]
	if _mats.has(key):
		return _mats[key]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = rough
	mt.metallic = metal
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emis > 0.0:
		mt.emission_enabled = true
		mt.emission = c
		mt.emission_energy_multiplier = emis
	_mats[key] = mt
	return mt


static func glass_mat() -> StandardMaterial3D:
	return m(Color(0.12, 0.2, 0.28, 0.42), 0.05, 0.0, 0.0, 0.42)


static func box(parent: Node3D, size: Vector3, pos: Vector3, mt: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, mt: Material, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sph(parent: Node3D, r: float, pos: Vector3, mt: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mt
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mt: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.ring_segments = 8
	tm.rings = 18
	mi.mesh = tm
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _wheel(root: Node3D, pos: Vector3, front: bool) -> Dictionary:
	var pivot := Node3D.new()
	pivot.position = pos
	root.add_child(pivot)
	var spin := Node3D.new()
	pivot.add_child(spin)
	var side := 1.0 if pos.x > 0.0 else -1.0
	cyl(spin, 0.34, 0.24, Vector3.ZERO, m(Color("#161616"), 0.95), Vector3(0, 0, PI / 2.0), 16)
	cyl(spin, 0.2, 0.26, Vector3(side * 0.01, 0, 0), m(Color("#c9ccd1"), 0.3, 0.8), Vector3(0, 0, PI / 2.0), 12)
	for k in 3:
		box(spin, Vector3(0.27, 0.05, 0.4), Vector3(side * 0.012, 0, 0), m(Color("#8f949b"), 0.3, 0.8), Vector3(k * PI / 3.0, 0, 0))
	cyl(spin, 0.05, 0.3, Vector3(side * 0.02, 0, 0), m(Color("#2a2d31"), 0.4, 0.6), Vector3(0, 0, PI / 2.0), 8)
	return {"pivot": pivot, "spin": spin, "front": front}


## Family hatchback: opening doors and trunk, working steering wheel, dashboard, seats.
static func make_car(body: Color) -> Dictionary:
	var root := Node3D.new()
	var paint := m(body, 0.32, 0.3)
	var dark := m(Color("#15161a"), 0.8)
	var trim := m(Color("#2a2c31"), 0.6)
	var chrome := m(Color("#c9ccd1"), 0.25, 0.9)
	var gl := glass_mat()
	var seat_c := m(Color("#4a4f5a"), 0.9)
	var dash_c := m(Color("#1d1f24"), 0.7)
	# ---- lower body: front block, floor, rear block
	box(root, Vector3(1.84, 0.5, 1.4), Vector3(0, 0.62, -1.5), paint)
	box(root, Vector3(1.84, 0.1, 1.9), Vector3(0, 0.42, 0.2), dark)
	box(root, Vector3(1.84, 0.5, 0.9), Vector3(0, 0.62, 1.75), paint)
	box(root, Vector3(1.84, 0.28, 0.12), Vector3(0, 0.78, 1.14), paint) # cowl behind rear seats
	# hood + cowl
	box(root, Vector3(1.8, 0.1, 1.3), Vector3(0, 0.93, -1.55), paint, Vector3(-0.07, 0, 0))
	box(root, Vector3(1.8, 0.24, 0.35), Vector3(0, 1.0, -0.92), dark)
	# bumpers, grille, plate
	box(root, Vector3(1.82, 0.26, 0.16), Vector3(0, 0.38, -2.24), trim)
	box(root, Vector3(1.82, 0.26, 0.16), Vector3(0, 0.38, 2.24), trim)
	box(root, Vector3(0.9, 0.17, 0.05), Vector3(0, 0.66, -2.2), dark)
	box(root, Vector3(0.9, 0.04, 0.05), Vector3(0, 0.74, -2.21), chrome)
	var plate := box(root, Vector3(0.52, 0.12, 0.02), Vector3(0, 0.6, 2.33), m(Color("#f2c81c"), 0.5))
	var pl_txt := Label3D.new()
	pl_txt.text = "12-345-67"
	pl_txt.font_size = 28
	pl_txt.pixel_size = 0.0016
	pl_txt.modulate = Color("#1a1a1a")
	pl_txt.outline_size = 0
	pl_txt.position = Vector3(0, 0, 0.012)
	pl_txt.rotation.y = PI
	plate.add_child(pl_txt)
	# lights
	var head_mat := m(Color("#fff4cf"), 0.2, 0.0, 0.5)
	var tail_mat := m(Color("#e02424"), 0.3, 0.0, 0.7)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.4, 0.15, 0.06), Vector3(sx * 0.66, 0.82, -2.2), head_mat)
		box(root, Vector3(0.42, 0.16, 0.05), Vector3(sx * 0.66, 0.86, 2.2), tail_mat)
	# ---- roof, pillars, glass
	box(root, Vector3(1.76, 0.07, 1.75), Vector3(0, 1.69, 0.12), paint)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.07, 0.95, 0.07), Vector3(sx * 0.85, 1.31, -0.65), trim, Vector3(0.87, 0, 0))
		box(root, Vector3(0.07, 0.72, 0.07), Vector3(sx * 0.87, 1.33, 0.2), trim)
		box(root, Vector3(0.07, 0.84, 0.07), Vector3(sx * 0.85, 1.33, 1.2), trim, Vector3(-0.92, 0, 0))
	box(root, Vector3(1.62, 0.03, 0.93), Vector3(0, 1.31, -0.65), gl, Vector3(-0.87, 0, 0))
	box(root, Vector3(1.62, 0.03, 0.84), Vector3(0, 1.33, 1.2), gl, Vector3(0.92, 0, 0))
	# ---- doors (hinged at the front edge)
	var doors := {}
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * 0.91, 0.78, -0.72)
		root.add_child(piv)
		box(piv, Vector3(0.07, 0.55, 1.5), Vector3(0, 0, 0.78), paint)
		box(piv, Vector3(0.03, 0.66, 1.34), Vector3(0, 0.6, 0.78), gl)
		box(piv, Vector3(0.05, 0.04, 1.4), Vector3(sx * 0.01, 0.26, 0.78), trim)
		box(piv, Vector3(0.05, 0.05, 0.18), Vector3(sx * 0.05, 0.13, 1.25), chrome)
		doors[sx] = piv
	# side mirrors
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.14, 0.09, 0.2), Vector3(sx * 1.04, 1.1, -0.62), paint)
		box(root, Vector3(0.1, 0.03, 0.03), Vector3(sx * 0.96, 1.07, -0.62), trim)
	# ---- trunk (hinged lid + visible well)
	box(root, Vector3(1.7, 0.05, 1.05), Vector3(0, 0.76, 1.72), dark)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.06, 0.28, 1.05), Vector3(sx * 0.83, 0.9, 1.72), dark)
	box(root, Vector3(1.74, 0.34, 0.06), Vector3(0, 0.92, 2.2), dark)
	box(root, Vector3(1.74, 0.3, 0.06), Vector3(0, 0.9, 1.2), dark)
	var trunk_piv := Node3D.new()
	trunk_piv.position = Vector3(0, 1.06, 1.18)
	root.add_child(trunk_piv)
	box(trunk_piv, Vector3(1.8, 0.06, 1.1), Vector3(0, 0, 0.55), paint)
	box(trunk_piv, Vector3(0.5, 0.04, 0.05), Vector3(0, 0.04, 1.03), chrome)
	# ---- interior
	box(root, Vector3(1.62, 0.2, 0.42), Vector3(0, 1.02, -0.62), dash_c)
	box(root, Vector3(0.62, 0.14, 0.26), Vector3(-0.45, 1.16, -0.52), dash_c)
	for gx in [-0.55, -0.37]:
		cyl(root, 0.075, 0.012, Vector3(gx, 1.13, -0.385), m(Color("#5aa0c8"), 0.3, 0.0, 0.45), Vector3(PI / 2.0, 0, 0), 14)
	box(root, Vector3(0.3, 0.14, 0.02), Vector3(0.1, 1.06, -0.4), m(Color("#2f7fd0"), 0.2, 0.0, 0.6))
	for vx in [0.45, 0.62, 0.79]:
		box(root, Vector3(0.1, 0.04, 0.02), Vector3(vx, 1.08, -0.41), trim)
	box(root, Vector3(0.2, 0.34, 0.5), Vector3(0, 0.62, -0.1), dash_c)  # center console
	cyl(root, 0.022, 0.2, Vector3(0, 0.88, -0.15), chrome, Vector3(0.25, 0, 0), 8)
	sph(root, 0.04, Vector3(0, 0.99, -0.12), dark)
	box(root, Vector3(0.22, 0.07, 0.03), Vector3(0, 1.58, -0.46), dark)  # rear-view mirror
	# steering column + wheel
	var column := Node3D.new()
	column.position = Vector3(-0.45, 1.1, -0.34)
	column.rotation.x = -0.45
	root.add_child(column)
	var steer := Node3D.new()
	column.add_child(steer)
	var wm := m(Color("#1a1a1d"), 0.55)
	torus(steer, 0.15, 0.19, Vector3.ZERO, wm, Vector3(PI / 2.0, 0, 0))
	box(steer, Vector3(0.3, 0.035, 0.035), Vector3.ZERO, wm)
	box(steer, Vector3(0.035, 0.16, 0.035), Vector3(0, -0.09, 0), wm)
	cyl(steer, 0.05, 0.05, Vector3.ZERO, m(Color("#3a3d44"), 0.4, 0.6), Vector3(PI / 2.0, 0, 0), 10)
	box(steer, Vector3(0.035, 0.035, 0.06), Vector3(0, 0.19, 0), m(Color("#d9d9d9"), 0.3, 0.5))  # 12 o'clock marker
	box(root, Vector3(0.06, 0.06, 0.45), Vector3(-0.45, 1.05, -0.5), dark, Vector3(-0.45, 0, 0))
	# seats
	for sx in [-0.45, 0.45]:
		box(root, Vector3(0.52, 0.13, 0.55), Vector3(sx, 0.62, 0.3), seat_c)
		box(root, Vector3(0.52, 0.62, 0.12), Vector3(sx, 1.0, 0.58), seat_c, Vector3(0.12, 0, 0))
		box(root, Vector3(0.28, 0.2, 0.1), Vector3(sx, 1.4, 0.64), seat_c, Vector3(0.12, 0, 0))
	box(root, Vector3(1.5, 0.12, 0.5), Vector3(0, 0.62, 0.98), seat_c)
	box(root, Vector3(1.5, 0.5, 0.1), Vector3(0, 0.95, 1.2), seat_c, Vector3(0.1, 0, 0))
	# ---- wheels
	var wheels: Array = []
	for pz in [-1.35, 1.35]:
		for px in [-0.9, 0.9]:
			wheels.append(_wheel(root, Vector3(px, 0.34, pz), pz < 0.0))
	return {
		"root": root, "wheels": wheels, "steer": steer, "trunk": trunk_piv,
		"door_l": doors[-1.0], "door_r": doors[1.0],
		"tail_mat": tail_mat, "head_mat": head_mat,
		"trunk_anchor": Vector3(0, 0.82, 1.72),
		"seat_driver": Vector3(-0.45, -0.16, 0.34),
		"seat_pass": Vector3(0.45, 0.62, 0.3),
		"cockpit": Vector3(-0.45, 1.42, 0.22),
		"hood_cam": Vector3(0, 1.1, -0.2),
		"trunk_world": Vector3(0, 0, 3.3),  # where the player stands to use the trunk (local)
		"steer_angle": 0.0, "door_t": 0.0, "trunk_t": 0.0,
	}


## Per-frame visuals: speed (m/s, +forward), steer in [-1, 1] (+ = right).
static func update_car(p: Dictionary, speed: float, steer: float, braking: bool, delta: float) -> void:
	for w in p["wheels"]:
		var spin: Node3D = w["spin"]
		spin.rotation.x -= speed * delta / 0.34
		if w["front"]:
			var piv: Node3D = w["pivot"]
			piv.rotation.y = lerp_angle(piv.rotation.y, -steer * 0.5, minf(delta * 12.0, 1.0))
	var st: Node3D = p["steer"]
	st.rotation.z = lerpf(st.rotation.z, -steer * 2.3, minf(delta * 10.0, 1.0))
	var tm: StandardMaterial3D = p["tail_mat"]
	tm.emission_energy_multiplier = 3.2 if braking else 0.7
	var dl: Node3D = p["door_l"]
	var dr: Node3D = p["door_r"]
	dl.rotation.y = lerpf(dl.rotation.y, -float(p.get("door_open_l", 0.0)), minf(delta * 8.0, 1.0))
	dr.rotation.y = lerpf(dr.rotation.y, float(p.get("door_open_r", 0.0)), minf(delta * 8.0, 1.0))
	var tr: Node3D = p["trunk"]
	tr.rotation.x = lerpf(tr.rotation.x, -1.2 if p.get("trunk_open", false) else 0.0, minf(delta * 7.0, 1.0))


## Motor boat with console, steering wheel, cargo cooler, outboard.
static func make_boat() -> Dictionary:
	var root := Node3D.new()
	var hull := Node3D.new()  # bobs separately
	root.add_child(hull)
	var white := m(Color("#f1f3f5"), 0.35, 0.1)
	var blue := m(Color("#1f5fa8"), 0.4)
	var gl := glass_mat()
	var dark := m(Color("#202328"), 0.7)
	var wood := m(Color("#a4784a"), 0.8)
	var chrome := m(Color("#c9ccd1"), 0.25, 0.9)
	# hull: keel plate, flared sides, bow and transom
	box(hull, Vector3(1.3, 0.1, 4.4), Vector3(0, 0.12, 0.1), blue)
	for sx in [-1.0, 1.0]:
		box(hull, Vector3(0.1, 0.62, 4.2), Vector3(sx * 0.78, 0.45, 0.2), white, Vector3(0, 0, -sx * 0.22))
		box(hull, Vector3(0.1, 0.62, 1.7), Vector3(sx * 0.42, 0.45, -2.45), white, Vector3(0, sx * 0.5, -sx * 0.18))
		box(hull, Vector3(0.12, 0.09, 4.2), Vector3(sx * 0.84, 0.74, 0.2), blue)
		box(hull, Vector3(0.05, 0.05, 4.1), Vector3(sx * 0.86, 0.96, 0.2), chrome)
		for rz in [-1.4, -0.2, 1.0, 2.0]:
			cyl(hull, 0.018, 0.25, Vector3(sx * 0.85, 0.85, rz), chrome, Vector3.ZERO, 6)
	box(hull, Vector3(1.6, 0.62, 0.1), Vector3(0, 0.45, 2.3), white)
	box(hull, Vector3(0.85, 0.09, 0.9), Vector3(0, 0.62, -2.05), white, Vector3(-0.1, 0, 0))
	box(hull, Vector3(1.4, 0.06, 1.1), Vector3(0, 0.66, -1.85), white)
	box(hull, Vector3(1.5, 0.06, 1.0), Vector3(0, 0.62, 1.8), white)
	box(hull, Vector3(1.3, 0.04, 2.6), Vector3(0, 0.32, 0.0), wood)  # cockpit floor
	# console + windshield + wheel
	box(hull, Vector3(0.95, 0.55, 0.5), Vector3(0, 0.88, -0.6), white)
	box(hull, Vector3(0.9, 0.08, 0.36), Vector3(0, 1.17, -0.62), dark)
	box(hull, Vector3(0.28, 0.14, 0.02), Vector3(0.22, 1.14, -0.4), m(Color("#4aa8ff"), 0.2, 0.0, 1.2))
	cyl(hull, 0.06, 0.012, Vector3(-0.2, 1.14, -0.4), m(Color("#9ad8ff"), 0.3, 0.0, 1.4), Vector3(PI / 2.0, 0, 0), 12)
	box(hull, Vector3(1.4, 0.55, 0.04), Vector3(0, 1.45, -0.95), gl, Vector3(-0.45, 0, 0))
	box(hull, Vector3(1.46, 0.05, 0.05), Vector3(0, 1.74, -0.82), chrome)
	for sx in [-1.0, 1.0]:
		box(hull, Vector3(0.05, 0.62, 0.05), Vector3(sx * 0.7, 1.43, -0.9), chrome, Vector3(-0.45, 0, 0))
	var column := Node3D.new()
	column.position = Vector3(0, 1.0, -0.38)
	column.rotation.x = -0.7
	hull.add_child(column)
	var steer := Node3D.new()
	column.add_child(steer)
	var wm := m(Color("#2a1c12"), 0.5)
	torus(steer, 0.12, 0.155, Vector3.ZERO, wm, Vector3(PI / 2.0, 0, 0))
	for k in 3:
		box(steer, Vector3(0.3, 0.03, 0.03), Vector3.ZERO, chrome, Vector3(0, 0, k * PI / 3.0))
	cyl(steer, 0.04, 0.05, Vector3.ZERO, chrome, Vector3(PI / 2.0, 0, 0), 8)
	# captain's seat + bench
	box(hull, Vector3(0.6, 0.16, 0.5), Vector3(-0.1, 0.62, 0.35), dark)
	box(hull, Vector3(0.6, 0.55, 0.12), Vector3(-0.1, 0.95, 0.62), dark, Vector3(0.1, 0, 0))
	box(hull, Vector3(1.2, 0.18, 0.45), Vector3(0, 0.62, 1.4), dark)
	# cargo cooler (fish box)
	var cool := box(hull, Vector3(0.7, 0.36, 0.5), Vector3(0.0, 0.84, 1.9), blue)
	box(hull, Vector3(0.74, 0.05, 0.54), Vector3(0.0, 1.04, 1.9), white)
	# outboard motor + propeller
	box(hull, Vector3(0.36, 0.55, 0.42), Vector3(0, 0.82, 2.5), dark)
	box(hull, Vector3(0.3, 0.14, 0.34), Vector3(0, 1.14, 2.5), m(Color("#c8352b"), 0.4))
	cyl(hull, 0.05, 0.7, Vector3(0, 0.3, 2.55), dark, Vector3.ZERO, 8)
	var prop := Node3D.new()
	prop.position = Vector3(0, -0.02, 2.55)
	hull.add_child(prop)
	box(prop, Vector3(0.04, 0.4, 0.07), Vector3.ZERO, chrome)
	box(prop, Vector3(0.04, 0.07, 0.4), Vector3.ZERO, chrome)
	# flag
	cyl(hull, 0.012, 1.0, Vector3(0.6, 1.2, 2.0), chrome, Vector3.ZERO, 6)
	box(hull, Vector3(0.02, 0.28, 0.42), Vector3(0.6, 1.6, 2.22), white)
	box(hull, Vector3(0.022, 0.04, 0.42), Vector3(0.6, 1.7, 2.22), blue)
	box(hull, Vector3(0.022, 0.04, 0.42), Vector3(0.6, 1.5, 2.22), blue)
	return {
		"root": root, "hull": hull, "steer": steer, "prop": prop, "cooler": cool,
		"cargo_anchor": Vector3(0, 1.12, 1.9),
		"cockpit": Vector3(-0.1, 1.9, 0.62),
		"seat_driver": Vector3(-0.1, -0.18, 0.3),
		"bob": 0.0,
	}


static func update_boat(p: Dictionary, speed: float, steer: float, t: float, delta: float) -> void:
	var hull: Node3D = p["hull"]
	var k := clampf(absf(speed) / 12.0, 0.0, 1.0)
	hull.position.y = sin(t * 1.7) * 0.05 + k * 0.05
	hull.rotation.x = sin(t * 1.3) * 0.015 - k * 0.07
	hull.rotation.z = lerpf(hull.rotation.z, -steer * k * 0.18 + sin(t * 1.1) * 0.02, minf(delta * 4.0, 1.0))
	var st: Node3D = p["steer"]
	st.rotation.z = lerpf(st.rotation.z, -steer * 2.6, minf(delta * 8.0, 1.0))
	var pr: Node3D = p["prop"]
	pr.rotation.x += (6.0 + absf(speed) * 3.0) * delta
