class_name Levels
extends RefCounted
## Procedural 3D scenery for each level. Swap these builders for imported glTF
## scenes (or real map data) later without touching gameplay code.

# ---------------------------------------------------------------- helpers

static var _mat_cache: Dictionary = {}


static func unshaded_mat(color: Color) -> StandardMaterial3D:
	var key := "u" + color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


static func mat(color: Color, emit := 0.0, rough := 0.9) -> StandardMaterial3D:
	var key := "%s_%.1f_%.1f" % [color.to_html(), emit, rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	_mat_cache[key] = m
	m.albedo_color = color
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m


static func add_solid(node: Node3D, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	node.add_child(sb)


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, solid := false, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, emit)
	mi.position = pos
	parent.add_child(mi)
	if solid:
		add_solid(mi, size)
	return mi


static func cyl(parent: Node, pos: Vector3, radius: float, height: float, color: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func ball(parent: Node, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label3d(parent: Node, pos: Vector3, text: String, size: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 14
	l.position = pos
	parent.add_child(l)
	return l


static func window_texture(wall: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for y in range(12, 48):
		for x in range(14, 50):
			var edge := x < 16 or x > 47 or y < 14 or y > 45
			var c := Color("#e8e6df") if edge else Color("#3b5873").lerp(Color("#8fb4d4"), float(y - 14) / 32.0 * 0.6)
			if not edge and (x == 31 or x == 32 or y == 29 or y == 30):
				c = Color("#e8e6df")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- bedroom

static func build_bedroom(root: Node3D) -> Dictionary:
	var wall := Color("#cdbb98")
	var wood := Color("#8a5a3a")
	# shell (12 x 12 room)
	box(root, Vector3(0, -0.1, 0), Vector3(12, 0.2, 12), wood, true)
	box(root, Vector3(0, 3.8, 0), Vector3(12, 0.2, 12), Color("#e9e2d6"))
	box(root, Vector3(0, 1.85, -6.2), Vector3(12.8, 3.7, 0.4), wall, true)
	box(root, Vector3(0, 1.85, 6.2), Vector3(12.8, 3.7, 0.4), wall, true)
	box(root, Vector3(-6.2, 1.85, 0), Vector3(0.4, 3.7, 12.8), wall, true)
	box(root, Vector3(6.2, 1.85, 0), Vector3(0.4, 3.7, 12.8), wall, true)
	# baseboards
	box(root, Vector3(0, 0.08, -5.97), Vector3(12, 0.16, 0.06), Color("#f3efe6"))
	box(root, Vector3(-5.97, 0.08, 0), Vector3(0.06, 0.16, 12), Color("#f3efe6"))
	box(root, Vector3(5.97, 0.08, 0), Vector3(0.06, 0.16, 12), Color("#f3efe6"))

	# rug
	box(root, Vector3(0, 0.012, 0.3), Vector3(6.2, 0.02, 4.2), Color("#7a2f3a"))
	box(root, Vector3(0, 0.024, 0.3), Vector3(5.5, 0.02, 3.5), Color("#a24a52"))
	box(root, Vector3(0, 0.036, 0.3), Vector3(4.6, 0.02, 2.6), Color("#7a2f3a"))

	# bed (headboard against the back wall)
	var bed_x := -3.2
	box(root, Vector3(bed_x, 0.25, -4.2), Vector3(2.2, 0.5, 3.6), Color("#5b3a29"), true)
	box(root, Vector3(bed_x, 0.64, -4.2), Vector3(2.0, 0.28, 3.4), Color("#f1efe8"))
	box(root, Vector3(bed_x, 0.85, -5.85), Vector3(2.3, 1.7, 0.22), Color("#4a2e20"), true)
	box(root, Vector3(bed_x, 0.86, -5.3), Vector3(1.1, 0.16, 0.55), Color("#ffffff"))
	var blanket := Node3D.new()
	blanket.position = Vector3(bed_x, 0.0, -3.35)
	root.add_child(blanket)
	box(blanket, Vector3(0, 1.0, 0), Vector3(2.06, 0.26, 1.5), Color("#3b5ba8"))
	box(blanket, Vector3(0, 1.0, 0.0), Vector3(2.08, 0.1, 0.5), Color("#2c4488"))

	# nightstand with lamp and alarm clock
	var ns := Vector3(-0.95, 0.0, -5.4)
	box(root, ns + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.6), Color("#6b4630"), true)
	cyl(root, ns + Vector3(0.15, 0.7, 0), 0.07, 0.2, Color("#c9a85a"))
	var shade := cyl(root, ns + Vector3(0.15, 0.95, 0), 0.2, 0.28, Color("#ffd89a"), 1.6)
	shade.mesh.top_radius = 0.12
	var lamp := OmniLight3D.new()
	lamp.position = ns + Vector3(0.15, 1.0, 0.05)
	lamp.light_color = Color("#ffb86b")
	lamp.light_energy = 1.4
	lamp.omni_range = 9.0
	root.add_child(lamp)
	var clock := build_mini_clock()
	clock.position = ns + Vector3(-0.15, 0.6, 0.02)
	root.add_child(clock)

	# wardrobe
	box(root, Vector3(4.7, 1.2, -5.3), Vector3(2.0, 2.4, 0.8), Color("#7b5238"), true)
	box(root, Vector3(4.25, 1.2, -4.89), Vector3(0.04, 2.2, 0.02), Color("#2a1a10"))
	box(root, Vector3(5.15, 1.2, -4.89), Vector3(0.04, 2.2, 0.02), Color("#2a1a10"))
	box(root, Vector3(4.7, 1.2, -4.89), Vector3(0.03, 2.3, 0.02), Color("#2a1a10"))

	# bookshelf (sefarim!) on the left wall
	box(root, Vector3(-5.7, 1.2, 1.2), Vector3(0.5, 2.4, 2.6), Color("#5b3a29"), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 4:
		var z := 0.0
		while z < 2.4:
			var w := rng.randf_range(0.08, 0.17)
			var h := rng.randf_range(0.32, 0.46)
			var col := Color.from_hsv(rng.randf(), 0.45, 0.55)
			if rng.randf() < 0.5:
				col = Color("#5a2d1f") if rng.randf() < 0.5 else Color("#1f2d5a")
			box(root, Vector3(-5.56, 0.35 + row * 0.57 + h * 0.5, z + 0.1), Vector3(0.28, h, w), col)
			z += w + 0.01

	# desk, chair, tallis bag
	box(root, Vector3(5.3, 0.75, 1.0), Vector3(1.0, 0.08, 2.0), Color("#8a5a3a"), true)
	box(root, Vector3(5.3, 0.37, 1.0), Vector3(0.9, 0.74, 1.9), Color("#6b4630"))
	box(root, Vector3(5.3, 0.82, 0.4), Vector3(0.4, 0.1, 0.3), Color("#1d2f66"))
	box(root, Vector3(5.3, 0.82, 1.4), Vector3(0.3, 0.1, 0.4), Color("#7a1f1f"))
	box(root, Vector3(4.3, 0.28, 1.0), Vector3(0.6, 0.06, 0.6), Color("#3b2a1e"), true)
	box(root, Vector3(4.07, 0.65, 1.0), Vector3(0.06, 0.7, 0.6), Color("#3b2a1e"))
	box(root, Vector3(4.3, 0.55, 1.0), Vector3(0.45, 0.35, 0.3), Color("#1d3b8a"))

	# window (moonlight) on the back wall
	box(root, Vector3(2.2, 2.0, -5.95), Vector3(2.4, 1.8, 0.1), Color("#f2efe8"))
	box(root, Vector3(2.2, 2.0, -5.9), Vector3(2.2, 1.6, 0.06), Color("#27407e"), false, 1.6)
	box(root, Vector3(2.2, 2.0, -5.86), Vector3(0.06, 1.6, 0.05), Color("#f2efe8"))
	box(root, Vector3(2.2, 2.0, -5.86), Vector3(2.2, 0.06, 0.05), Color("#f2efe8"))
	box(root, Vector3(0.8, 2.0, -5.8), Vector3(0.5, 2.4, 0.12), Color("#8a3b3b"))
	box(root, Vector3(3.6, 2.0, -5.8), Vector3(0.5, 2.4, 0.12), Color("#8a3b3b"))
	ball(root, Vector3(2.2, 2.9, -5.8), 0.0001, Color.WHITE)

	# posters
	box(root, Vector3(-5.97, 2.3, -2.0), Vector3(0.03, 1.1, 0.8), Color("#2f6f9f"))
	box(root, Vector3(-5.97, 2.3, -3.0), Vector3(0.03, 1.1, 0.8), Color("#9f6f2f"))
	box(root, Vector3(0.0, 2.4, 5.96), Vector3(1.6, 1.0, 0.03), Color("#4a7c59"))
	label3d(root, Vector3(0.0, 2.4, 5.9), "MODEH ANI", 0.35, Color("#ffffff")).rotation.y = PI

	# lighting
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9bb4ff")
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-35, 15, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 25.0
	root.add_child(moon)
	var ceil_l := OmniLight3D.new()
	ceil_l.position = Vector3(0, 3.3, 0.5)
	ceil_l.light_color = Color("#ffe2b0")
	ceil_l.light_energy = 0.7
	ceil_l.omni_range = 12.0
	root.add_child(ceil_l)

	return {
		"bed_feet": Vector3(bed_x, 0.95, -2.85),
		"blanket": blanket,
		"clock": clock,
		"bounds": Rect2(-5.5, -5.5, 11.0, 11.0),
		"stand": Vector3(-1.3, 0.0, -2.4),
		"enemy_spawn": Vector3(1.8, 0.0, 0.8),
		"tov": [Vector3(3.8, 0, 2.6)],
	}


static func build_mini_clock() -> Node3D:
	var c := Node3D.new()
	var body := cyl(c, Vector3(0, 0.17, 0), 0.17, 0.12, Color("#d63030"))
	body.rotation.x = PI / 2.0
	var face := cyl(c, Vector3(0, 0.17, 0.065), 0.14, 0.01, Color("#f6f1e2"))
	face.rotation.x = PI / 2.0
	box(c, Vector3(0, 0.2, 0.075), Vector3(0.012, 0.09, 0.004), Color.BLACK)
	box(c, Vector3(0.03, 0.17, 0.075), Vector3(0.07, 0.012, 0.004), Color.BLACK)
	ball(c, Vector3(-0.1, 0.34, 0), 0.06, Color("#e8b23a"))
	ball(c, Vector3(0.1, 0.34, 0), 0.06, Color("#e8b23a"))
	# the clock faces the room (+Z)
	return c


# ---------------------------------------------------------------- street

static func build_street(root: Node3D, opts: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 18))
	var z_start := 10.0
	var z_end := -104.0
	var length := z_start - z_end
	var cz := (z_start + z_end) * 0.5

	# ground
	box(root, Vector3(0, -0.15, cz), Vector3(16, 0.3, length), Color("#3a3d44"), true)
	box(root, Vector3(-11.5, -0.1, cz), Vector3(7, 0.4, length), Color("#a9a7a0"), true)
	box(root, Vector3(11.5, -0.1, cz), Vector3(7, 0.4, length), Color("#a9a7a0"), true)
	box(root, Vector3(-8.0, 0.02, cz), Vector3(0.3, 0.2, length), Color("#c9c7c0"))
	box(root, Vector3(8.0, 0.02, cz), Vector3(0.3, 0.2, length), Color("#c9c7c0"))
	# lane markings
	var z := z_start - 2.0
	while z > z_end + 6.0:
		box(root, Vector3(0, 0.02, z), Vector3(0.22, 0.02, 2.4), Color("#e8e4d0"))
		z -= 6.0
	for cw_z in [-10.0, -62.0, -82.0]:
		for i in 9:
			box(root, Vector3(-4.8 + i * 1.2, 0.025, cw_z), Vector3(0.7, 0.02, 3.0), Color("#ecebe5"))

	# buildings
	var wtex := {}
	for side in [-1, 1]:
		var zz := z_start
		while zz > z_end + 8.0:
			var w := rng.randf_range(10.0, 16.0)
			var h := rng.randf_range(9.0, 24.0)
			var d := 16.0
			var tint := Color.from_hsv(rng.randf_range(0.02, 0.12), rng.randf_range(0.12, 0.35), rng.randf_range(0.62, 0.9))
			var key := str(int(tint.h * 100))
			var m := StandardMaterial3D.new()
			m.albedo_color = tint
			m.albedo_texture = window_texture(tint) if not wtex.has(key) else wtex[key]
			wtex[key] = m.albedo_texture
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)
			m.roughness = 0.95
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(d, h, w)
			mi.mesh = bm
			mi.material_override = m
			mi.position = Vector3(side * (11.0 + d * 0.5 - 0.5 + 0.0), h * 0.5, zz - w * 0.5)
			root.add_child(mi)
			add_solid(mi, bm.size)
			box(root, Vector3(mi.position.x, h + 0.2, mi.position.z), Vector3(d + 0.4, 0.4, w + 0.4), Color("#55504a"))
			# shop awning + door at street level
			var awn := Color.from_hsv(rng.randf(), 0.6, 0.75)
			box(root, Vector3(side * 10.4, 3.3, zz - w * 0.5), Vector3(1.4, 0.15, minf(w - 3.0, 6.0)), awn)
			box(root, Vector3(side * 10.95, 1.5, zz - w * 0.5), Vector3(0.1, 3.0, minf(w - 4.0, 4.5)), Color("#27384d"), false, 0.4)
			zz -= w + 0.4

	# trees, lamp posts, parked cars
	z = z_start - 4.0
	while z > z_end + 10.0:
		for side in [-1, 1]:
			cyl(root, Vector3(side * 9.4, 1.3, z), 0.2, 2.6, Color("#5a3d27"))
			ball(root, Vector3(side * 9.4, 3.6, z), 1.7, Color.from_hsv(0.3, 0.55, rng.randf_range(0.35, 0.5)))
			cyl(root, Vector3(side * 8.6, 2.2, z + 7.0), 0.07, 4.4, Color("#2c2f36"))
			box(root, Vector3(side * 8.6, 4.5, z + 7.0), Vector3(0.5, 0.18, 0.3), Color("#fff1c2"), false, 1.2)
		z -= 14.0
	var car_cols := [Color("#b32d2d"), Color("#2d5fb3"), Color("#d8d8d8"), Color("#2f2f33"), Color("#c7a228")]
	for cz2 in [-6.0, -20.0, -34.0, -48.0, -72.0, -88.0]:
		var side2 := -1 if rng.randf() < 0.5 else 1
		var col: Color = car_cols[rng.randi() % car_cols.size()]
		var car := Node3D.new()
		car.position = Vector3(side2 * 6.0, 0, cz2)
		root.add_child(car)
		box(car, Vector3(0, 0.55, 0), Vector3(1.9, 0.7, 4.3), col, true)
		box(car, Vector3(0, 1.15, 0.2), Vector3(1.7, 0.55, 2.3), col.darkened(0.15))
		box(car, Vector3(0, 1.15, 0.2), Vector3(1.72, 0.4, 2.0), Color("#1d2a38"))
		for wx in [-0.95, 0.95]:
			for wz in [-1.4, 1.4]:
				var wh := cyl(car, Vector3(wx, 0.3, wz), 0.32, 0.22, Color("#111111"))
				wh.rotation.z = PI / 2.0

	# the shul
	var door_z := -91.0
	var shul := Node3D.new()
	root.add_child(shul)
	var stone := Color("#e6d5ae")
	box(shul, Vector3(0, 6.5, -97), Vector3(34, 13, 10), stone, true)
	box(shul, Vector3(0, 0.25, -91.0), Vector3(14, 0.5, 2.0), Color("#c9bb98"))
	box(shul, Vector3(0, 0.75, -91.8), Vector3(12, 0.5, 1.2), Color("#c9bb98"))
	box(shul, Vector3(0, 2.4, -91.98), Vector3(3.2, 3.6, 0.1), Color("#ffcf7a"), false, 1.8)
	box(shul, Vector3(0, 4.7, -91.98), Vector3(3.6, 0.5, 0.2), Color("#c9bb98"))
	for cx in [-2.4, 2.4]:
		cyl(shul, Vector3(cx, 2.8, -91.7), 0.38, 4.6, Color("#f4ead0"))
	box(shul, Vector3(0, 5.4, -91.7), Vector3(6.6, 0.6, 1.0), Color("#d9c9a2"))
	for wx in [-9.0, -5.5, 5.5, 9.0]:
		box(shul, Vector3(wx, 5.0, -91.96), Vector3(1.6, 4.2, 0.08), Color("#ff9e4a"), false, 1.2)
		box(shul, Vector3(wx, 7.4, -91.96), Vector3(1.6, 0.9, 0.08), Color("#4a8fff"), false, 1.2)
	# luchos + magen david
	for tx in [-0.8, 0.8]:
		var tablet := box(shul, Vector3(tx, 6.9, -91.9), Vector3(1.3, 1.9, 0.3), Color("#f3efe4"))
		tablet.mesh.size = Vector3(1.3, 1.9, 0.3)
	label3d(shul, Vector3(-0.8, 7.1, -91.72), "I-V", 0.5, Color("#3a3a3a")).outline_size = 0
	label3d(shul, Vector3(0.8, 7.1, -91.72), "VI-X", 0.5, Color("#3a3a3a")).outline_size = 0
	_star(shul, Vector3(0, 10.3, -91.95), 3.0)
	label3d(shul, Vector3(0, 12.2, -91.9), str(opts.get("goal_label", "BEIS KNESSES")), 1.2, Color("#2a5ca8"))
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 5.0
	dm.height = 5.0
	dm.is_hemisphere = true
	dome.mesh = dm
	dome.material_override = mat(Color("#3aa6a0"), 0.0, 0.4)
	dome.position = Vector3(0, 13.0, -97)
	shul.add_child(dome)
	# door arrival marker
	var arrow := box(root, Vector3(0, 0.05, door_z + 3.2), Vector3(3.2, 0.04, 2.0), Color("#ffd24a"), false, 1.0)
	arrow.name = "ShulMat"

	# player bounds
	box(root, Vector3(-7.6, 2.0, cz), Vector3(0.4, 4.0, length), Color(0, 0, 0, 0), true).visible = false
	box(root, Vector3(7.6, 2.0, cz), Vector3(0.4, 4.0, length), Color(0, 0, 0, 0), true).visible = false
	box(root, Vector3(0, 2.0, z_start), Vector3(16, 4.0, 0.4), Color(0, 0, 0, 0), true).visible = false

	# the snooze barrier (a wall of pillows) that only the boss's defeat removes
	var barrier := Node3D.new()
	barrier.position = Vector3(0, 0, -68)
	root.add_child(barrier)
	for row in 3:
		for i in 7:
			var col2 := Color("#f6d6e0") if (row + i) % 2 == 0 else Color("#d6e6f6")
			box(barrier, Vector3(-6.0 + i * 2.0 + (row % 2) * 0.5, 0.5 + row * 1.0, 0), Vector3(1.9, 0.95, 1.2), col2)
	add_solid(barrier, Vector3(16, 4, 1.4))
	(barrier.get_child(barrier.get_child_count() - 1) as StaticBody3D).position = Vector3(0, 2, 0)
	label3d(barrier, Vector3(0, 4.6, 0), "SNOOZE", 1.4, Color("#ff7aa8"))

	# sun + sky
	var sun := DirectionalLight3D.new()
	var dusk: bool = opts.get("dusk", false)
	sun.light_color = Color("#ff9a5a") if dusk else Color("#fff0d0")
	sun.light_energy = 0.9 if dusk else 1.25
	sun.rotation_degrees = Vector3(-14, -60, 0) if dusk else Vector3(-38, -25, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	root.add_child(sun)

	return {
		"door_z": door_z,
		"barrier": barrier,
		"bounds": Rect2(-8.6, -108.0, 17.2, 120.0),
		"stand": Vector3(0, 0.0, 4.0),
		"tov": [Vector3(5.2, 0, -8), Vector3(-5.2, 0, -36), Vector3(5.2, 0, -62), Vector3(-5.2, 0, -84)],
	}


static func _star(parent: Node, pos: Vector3, size: float) -> void:
	for flip in [false, true]:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(size, size * 0.87, 0.2)
		mi.mesh = pm
		mi.material_override = mat(Color("#3a7bff"), 2.0)
		var shift := size * 0.87 / 6.0
		mi.position = pos + Vector3(0, -shift if not flip else shift, 0)
		if flip:
			mi.rotation.z = PI
		parent.add_child(mi)


# ---------------------------------------------------------------- people helpers

const SKINS := ["#e8b894", "#d9a77c", "#c68e6b", "#f1c9a5", "#b97a56"]
const SHIRTS := ["#f2f2f2", "#e8ecf4", "#dfe6ee", "#f4efe2"]
const HAIRS := ["#2a1c10", "#3a2a1c", "#141414", "#5a4630", "#8a8a8a"]


static func spawn_npc(parent: Node, pos: Vector3, face_dir: Vector3, kind: Npc.Kind, rng: RandomNumberGenerator, light := true) -> Npc:
	var n := Npc.new()
	n.kind = kind
	n.look["skin"] = Color(SKINS[rng.randi() % SKINS.size()])
	n.look["shirt"] = Color(SHIRTS[rng.randi() % SHIRTS.size()])
	n.look["pants"] = Color("#15151c")
	n.look["hair"] = Color(HAIRS[rng.randi() % HAIRS.size()])
	n.look["kippah"] = rng.randf() < 0.55
	n.look["hat"] = not n.look["kippah"] and rng.randf() < 0.6
	n.look["kippah_color"] = Color.from_hsv(rng.randf(), 0.4, 0.3)
	n.look["beard"] = rng.randf() < 0.6
	n.look["tallis"] = kind == Npc.Kind.SEATED and rng.randf() < 0.85
	n.look["scale"] = rng.randf_range(0.92, 1.06)
	n.look["light"] = light
	n.look["eye"] = Color.BLACK
	n.sway_amount = rng.randf_range(0.07, 0.16)
	n.move_speed = 2.2
	n.position = pos
	n.face_dir = face_dir.normalized()
	parent.add_child(n)
	return n


static func spawn_tov(parent: Node, pos: Vector3, face_dir: Vector3) -> Npc:
	var n := Npc.new()
	n.kind = Npc.Kind.TOV
	n.look["skin"] = Color("#f6d9bd")
	n.look["shirt"] = Color("#fff6d6")
	n.look["pants"] = Color("#e8d9a0")
	n.look["hair"] = Color("#f0e0a0")
	n.look["kippah"] = true
	n.look["kippah_color"] = Color("#fff2b8")
	n.look["tallis"] = true
	n.look["scale"] = 1.12
	n.look["light"] = false
	n.position = pos
	n.face_dir = face_dir.normalized()
	parent.add_child(n)
	return n


# ---------------------------------------------------------------- the shul (interior)

static func build_shul(root: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var wall := Color("#efe6d0")
	var wood := Color("#7a4b2a")
	# shell: 30 wide (x), 42 deep (z); entrance at +z, aron kodesh at -z
	box(root, Vector3(0, -0.1, 0), Vector3(30, 0.2, 42), Color("#bfa377"), true)
	box(root, Vector3(0, 9.3, 0), Vector3(30, 0.2, 42), Color("#d9cfb8"))
	box(root, Vector3(0, 4.6, -21.2), Vector3(31, 9.4, 0.4), wall, true)
	box(root, Vector3(0, 4.6, 21.2), Vector3(31, 9.4, 0.4), wall, true)
	box(root, Vector3(-15.2, 4.6, 0), Vector3(0.4, 9.4, 43), wall, true)
	box(root, Vector3(15.2, 4.6, 0), Vector3(0.4, 9.4, 43), wall, true)
	# ceiling beams
	for bz in range(-18, 20, 6):
		box(root, Vector3(0, 9.0, bz), Vector3(30, 0.35, 0.5), Color("#6b4630"))
	# red carpet runner down the middle
	box(root, Vector3(0, 0.01, 2), Vector3(3.2, 0.02, 38), Color("#8a1f2c"))
	box(root, Vector3(0, 0.02, 2), Vector3(2.6, 0.02, 38), Color("#a8303d"))

	# --- Aron Kodesh (holy ark) on the front wall
	var az := -19.6
	box(root, Vector3(0, 0.3, az + 1.3), Vector3(11, 0.6, 3.4), Color("#a8865a"), true)
	box(root, Vector3(0, 0.75, az + 0.6), Vector3(9.4, 0.3, 2.2), Color("#b8946a"), true)
	box(root, Vector3(0, 3.6, az), Vector3(5.6, 6.0, 1.3), wood, true)
	box(root, Vector3(0, 3.4, az + 0.72), Vector3(3.9, 4.8, 0.1), Color("#8a1a2a"), false, 0.3)
	box(root, Vector3(0, 3.4, az + 0.8), Vector3(0.06, 4.8, 0.04), Color("#e0b84a"), false, 0.6)
	box(root, Vector3(0, 5.9, az + 0.8), Vector3(3.9, 0.08, 0.04), Color("#e0b84a"), false, 0.6)
	for cx in [-3.2, 3.2]:
		cyl(root, Vector3(cx, 3.3, az + 0.9), 0.35, 6.0, Color("#e9dcc0"))
	box(root, Vector3(0, 6.9, az), Vector3(6.4, 0.5, 1.4), Color("#d9b658"), false, 0.4)
	_star(root, Vector3(0, 8.0, az + 0.5), 1.6)
	for tx in [-0.7, 0.7]:
		box(root, Vector3(tx, 7.5, az + 0.7), Vector3(0.9, 1.3, 0.15), Color("#f3efe4"))
	# ner tamid (eternal light)
	ball(root, Vector3(0, 6.2, az + 1.2), 0.22, Color("#ffd24a")).material_override = mat(Color("#ffd24a"), 3.0)
	var nt := OmniLight3D.new()
	nt.position = Vector3(0, 6.0, az + 1.6)
	nt.light_color = Color("#ffd98a")
	nt.light_energy = 0.8
	nt.omni_range = 10.0
	root.add_child(nt)

	# --- bimah (reader's platform) in the middle-front
	box(root, Vector3(0, 0.25, -6.5), Vector3(5.0, 0.5, 3.8), Color("#8b5a36"), true)
	box(root, Vector3(0, 1.05, -6.5), Vector3(2.6, 1.0, 1.1), Color("#f2eee2"))
	box(root, Vector3(0, 1.62, -6.5), Vector3(2.7, 0.1, 1.2), Color("#e4d8bf"))
	for px in [-2.4, 2.4]:
		for pz in [-8.3, -4.7]:
			cyl(root, Vector3(px, 1.0, pz), 0.07, 1.0, Color("#c9a85a"))
	box(root, Vector3(0, 1.45, -8.3), Vector3(4.8, 0.08, 0.08), Color("#c9a85a"))
	box(root, Vector3(0, 1.45, -4.7), Vector3(4.8, 0.08, 0.08), Color("#c9a85a"))
	box(root, Vector3(-2.4, 1.45, -6.5), Vector3(0.08, 0.08, 3.6), Color("#c9a85a"))
	box(root, Vector3(2.4, 1.45, -6.5), Vector3(0.08, 0.08, 3.6), Color("#c9a85a"))

	# --- seats: two blocks, each person stands at a shtender (lectern) facing the ark
	var seat_positions: Array[Vector3] = []
	var columns := [-11.5, -9.0, -6.5, 6.5, 9.0, 11.5]
	for row in 8:
		var z := -14.0 + row * 3.0
		for cx in columns:
			var p := Vector3(cx, 0.0, z)
			if absf(cx) < 7.0 and z > -9.0 and z < -4.0:
				continue
			box(root, p + Vector3(0, 0.22, 0.95), Vector3(0.5, 0.44, 0.45), Color("#6b4630"))
			var sh := box(root, p + Vector3(0, 0.55, -0.6), Vector3(0.62, 1.1, 0.32), Color("#8b5a36"))
			sh.rotation.x = 0.0
			box(root, p + Vector3(0, 1.12, -0.66), Vector3(0.64, 0.05, 0.4), Color("#a8744a"))
			seat_positions.append(p)
	var player_seat := Vector3(-6.5, 0.0, -2.0)
	# NPC congregants fill most seats except the player's seat and a few empty ones
	var count := 0
	for p in seat_positions:
		if p.distance_to(player_seat) < 0.6:
			continue
		if rng.randf() < 0.62:
			spawn_npc(root, p, Vector3(0, 0, -1), Npc.Kind.SEATED, rng)
			count += 1
	# a few standing groups at the back, chatting quietly
	for gp in [Vector3(-11, 0, 15.5), Vector3(10.5, 0, 15), Vector3(0, 0, 13)]:
		var a := spawn_npc(root, gp, Vector3(1, 0, 0.3), Npc.Kind.WANDERER, rng, false)
		var b := spawn_npc(root, gp + Vector3(1.1, 0, 0), Vector3(-1, 0, 0.3), Npc.Kind.WANDERER, rng, false)
		a.set_physics_process(false)
		b.set_physics_process(false)
	# wanderers walking slowly up and down the side aisles
	var wanderers: Array[Npc] = []
	for wp in [Vector3(-13.6, 0, 6), Vector3(13.6, 0, -2)]:
		var w := spawn_npc(root, wp, Vector3(0, 0, -1), Npc.Kind.WANDERER, rng, false)
		w.move_speed = 1.6
		wanderers.append(w)

	# --- chandeliers
	for cpos in [Vector3(-6, 7.6, -8), Vector3(6, 7.6, -8), Vector3(-6, 7.6, 6), Vector3(6, 7.6, 6), Vector3(0, 7.8, -1)]:
		cyl(root, cpos + Vector3(0, 0.9, 0), 0.03, 1.8, Color("#444444"))
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.9
		tm.outer_radius = 1.0
		ring.mesh = tm
		ring.material_override = mat(Color("#e8c46a"), 1.2)
		ring.position = cpos
		root.add_child(ring)
		for i in 8:
			var a := TAU * i / 8.0
			ball(root, cpos + Vector3(cos(a) * 0.95, 0.15, sin(a) * 0.95), 0.1, Color("#fff2c0")).material_override = mat(Color("#fff2c0"), 3.0)
		var lt := OmniLight3D.new()
		lt.position = cpos + Vector3(0, -0.3, 0)
		lt.light_color = Color("#ffe6b0")
		lt.light_energy = 0.9
		lt.omni_range = 13.0
		root.add_child(lt)

	# --- stained-glass windows on both side walls
	var glass := [Color("#3a6fd8"), Color("#e98a2a"), Color("#8a4ad8"), Color("#2aa86a"), Color("#d83a4a")]
	for side in [-1, 1]:
		for i in 6:
			var wz := -15.0 + i * 6.0
			box(root, Vector3(side * 14.95, 4.6, wz), Vector3(0.12, 4.4, 2.0), Color("#f3ead4"))
			var col: Color = glass[(i + (0 if side < 0 else 2)) % glass.size()]
			box(root, Vector3(side * 14.88, 4.6, wz), Vector3(0.08, 3.9, 1.6), col, false, 1.4)
			box(root, Vector3(side * 14.84, 4.6, wz), Vector3(0.06, 3.9, 0.06), Color("#f3ead4"))
			box(root, Vector3(side * 14.84, 4.6, wz), Vector3(0.06, 0.06, 1.6), Color("#f3ead4"))

	# --- balcony (the gallery) over the entrance
	box(root, Vector3(0, 4.0, 19.4), Vector3(30, 0.3, 3.2), Color("#8b5a36"), true)
	box(root, Vector3(0, 4.9, 17.9), Vector3(30, 1.1, 0.1), Color("#6b4630"))
	for bx in range(-14, 15, 4):
		cyl(root, Vector3(bx, 2.0, 18.0), 0.22, 4.0, Color("#e9dcc0"))

	# --- sefarim bookcases on side walls near the entrance
	for side in [-1, 1]:
		box(root, Vector3(side * 14.6, 1.4, 13.0), Vector3(0.6, 2.8, 5.5), Color("#5b3a29"), true)
		for row in 5:
			var z := 10.4
			while z < 15.4:
				var w := rng.randf_range(0.1, 0.2)
				var h := rng.randf_range(0.38, 0.5)
				var col := Color.from_hsv(rng.randf(), 0.4, 0.5) if rng.randf() < 0.5 else (Color("#5a2d1f") if rng.randf() < 0.5 else Color("#1f2d5a"))
				box(root, Vector3(side * 14.3, 0.3 + row * 0.55 + h * 0.5, z), Vector3(0.3, h, w), col)
				z += w + 0.012

	# --- tefillin shelf near the entrance (the player's bag glows)
	var shelf := Vector3(-11.0, 0.0, 18.5)
	box(root, shelf + Vector3(0, 1.0, 0), Vector3(4.2, 2.0, 0.6), Color("#6b4630"), true)
	for i in 6:
		var bag_col := Color("#2c4aa8") if i != 2 else Color("#ffd34a")
		var bag := box(root, shelf + Vector3(-1.7 + i * 0.68, 1.35, -0.25), Vector3(0.42, 0.3, 0.3), bag_col, false, 1.6 if i == 2 else 0.0)
		bag.name = "TefillinBag%d" % i
	var tefillin_spot := shelf + Vector3(-0.35, 0.0, -1.2)
	# --- entrance doors
	box(root, Vector3(0, 2.3, 21.0), Vector3(3.6, 4.6, 0.15), Color("#5b3a29"))
	box(root, Vector3(0, 2.3, 20.9), Vector3(0.06, 4.6, 0.08), Color("#e0b84a"), false, 0.5)

	# --- player seat marker (pulsed by the game) + signs
	var marker := cyl(root, player_seat + Vector3(0, 0.03, 0), 0.9, 0.04, Color("#ffd34a"), 1.4)
	marker.name = "SeatMarker"
	label3d(root, Vector3(0, 7.2, -20.4), "KEEP QUIET IN SHUL", 0.9, Color("#2a5ca8"))
	label3d(root, Vector3(0, 5.5, 20.7), "SHHH! DAVENING IN PROGRESS", 0.5, Color("#8a1a2a")).rotation.y = PI

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff4dc")
	sun.light_energy = 0.55
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)

	return {
		"bounds": Rect2(-13.8, -18.0, 27.6, 38.0),
		"stand": Vector3(0, 0.0, 17.5),
		"tefillin_spot": tefillin_spot,
		"tefillin_bag": shelf + Vector3(-1.7 + 2 * 0.68, 1.35, -0.25),
		"seat": player_seat,
		"tov": [player_seat + Vector3(-1.6, 0, 0.2)],
		"wanderers": wanderers,
		"crowd": count,
		"marker": marker,
	}


# ---------------------------------------------------------------- the Seder room

static func build_seder(root: Node3D, opts: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 51))
	var wall := Color(str(opts.get("wall", "#dbc9a2")))
	box(root, Vector3(0, -0.1, 0), Vector3(20, 0.2, 16), Color("#8a5a3a"), true)
	box(root, Vector3(0, 3.9, 0), Vector3(20, 0.2, 16), Color("#efe7d6"))
	box(root, Vector3(0, 1.9, -8.2), Vector3(20.8, 3.8, 0.4), wall, true)
	box(root, Vector3(0, 1.9, 8.2), Vector3(20.8, 3.8, 0.4), wall, true)
	box(root, Vector3(-10.2, 1.9, 0), Vector3(0.4, 3.8, 16.8), wall, true)
	box(root, Vector3(10.2, 1.9, 0), Vector3(0.4, 3.8, 16.8), wall, true)
	box(root, Vector3(0, 0.012, 3.0), Vector3(12, 0.02, 8), Color("#2d4f7a"))
	box(root, Vector3(0, 0.024, 3.0), Vector3(11, 0.02, 7), Color("#3d6a9f"))

	# the long Seder table along the back wall
	box(root, Vector3(0, 0.85, -5.6), Vector3(12, 0.12, 2.0), Color("#f8f5ec"), true)
	box(root, Vector3(0, 0.4, -5.6), Vector3(11.6, 0.8, 1.7), Color("#e4dccb"))
	cyl(root, Vector3(0, 0.95, -5.6), 0.38, 0.06, Color("#d9d9de"), 0.0)
	for i in 3:
		box(root, Vector3(-0.4 + i * 0.4, 1.0 + i * 0.04, -5.6), Vector3(0.7, 0.05, 0.7), Color("#e8d4a0"))
	for cx in [-4.5, -3.0, 3.0, 4.5]:
		cyl(root, Vector3(cx, 1.05, -5.2), 0.09, 0.2, Color("#c9ccd4"))
	for cx in [-1.6, 1.6]:
		cyl(root, Vector3(cx, 1.1, -5.9), 0.05, 0.3, Color("#f5f0e0"))
		ball(root, Vector3(cx, 1.3, -5.9), 0.06, Color("#ffb347")).material_override = mat(Color("#ffb347"), 4.0)
	var flame := OmniLight3D.new()
	flame.position = Vector3(0, 1.8, -5.0)
	flame.light_color = Color("#ffcf8a")
	flame.light_energy = 0.9
	flame.omni_range = 9.0
	root.add_child(flame)
	# family seated at the table (backs to the arena, facing the table)
	for i in 7:
		var x := -5.4 + i * 1.8
		box(root, Vector3(x, 0.25, -3.9), Vector3(0.6, 0.5, 0.6), Color("#5b3a29"))
		spawn_npc(root, Vector3(x, 0.3, -3.9), Vector3(0, 0, -1), Npc.Kind.SEATED, rng)

	# sideboard + shelves + window
	box(root, Vector3(-9.2, 0.6, 2.0), Vector3(1.0, 1.2, 4.0), Color("#6b4630"), true)
	box(root, Vector3(9.2, 0.6, 2.0), Vector3(1.0, 1.2, 4.0), Color("#6b4630"), true)
	box(root, Vector3(9.9, 2.0, -2.0), Vector3(0.12, 1.6, 2.4), Color("#27407e"), false, 1.4)
	box(root, Vector3(-9.9, 2.0, -2.0), Vector3(0.12, 1.6, 2.4), Color("#27407e"), false, 1.4)
	label3d(root, Vector3(0, 3.0, -7.9), str(opts.get("sign", "NEXT YEAR IN JERUSALEM")), 0.55, Color("#7a1f1f"))
	# chandelier
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 0.9
	ring.mesh = tm
	ring.material_override = mat(Color("#e8c46a"), 1.2)
	ring.position = Vector3(0, 3.4, 1.0)
	root.add_child(ring)
	var lt := OmniLight3D.new()
	lt.position = Vector3(0, 3.2, 1.0)
	lt.light_color = Color("#ffe6b0")
	lt.light_energy = 1.1
	lt.omni_range = 16.0
	root.add_child(lt)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#a8b8ff")
	sun.light_energy = 0.4
	sun.rotation_degrees = Vector3(-40, 20, 0)
	root.add_child(sun)

	return {
		"bounds": Rect2(-9.5, -7.5, 19.0, 15.0),
		"stand": Vector3(0, 0.0, 5.5),
		"enemy_spawn": Vector3(0, 0.0, -1.0),
		"tov": [Vector3(-8.0, 0, 4.5), Vector3(8.0, 0, 4.5)],
		"pickups": [Vector3(-8.0, 0, -2.0), Vector3(8.0, 0, -2.0), Vector3(0, 0, 2.5)],
	}
