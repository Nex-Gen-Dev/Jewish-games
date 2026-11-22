class_name Fx
extends RefCounted
## Small visual effects: hit sparks, floating numbers, shockwave rings.


static func _unshaded(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func burst(parent: Node, pos: Vector3, color: Color, amount := 14) -> void:
	if not parent or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _unshaded(color)
	p.mesh = sm
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


static func number(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	if not parent or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.008
	l.modulate = color
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.1, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, dur := 0.45) -> void:
	if not parent or not parent.is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 0.08
	c.radial_segments = 32
	var mat := _unshaded(color, 0.55)
	c.material = mat
	m.mesh = c
	parent.add_child(m)
	m.global_position = Vector3(pos.x, 0.06, pos.z)
	m.scale = Vector3(0.2, 1, 0.2)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius, 1, radius), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(m.queue_free)


## Flat warning disc on the ground showing where a slam/ring will land.
static func warning_disc(parent: Node, pos: Vector3, radius: float, dur: float) -> void:
	if not parent or not parent.is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.03
	c.radial_segments = 32
	var mat := _unshaded(Color(1, 0.25, 0.1), 0.0)
	c.material = mat
	m.mesh = c
	parent.add_child(m)
	m.global_position = Vector3(pos.x, 0.04, pos.z)
	var tw := m.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.35, dur)
	tw.tween_callback(m.queue_free)
