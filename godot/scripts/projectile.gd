class_name Projectile
extends Node3D
## Energy bolt fired by the player's blaster or by rifle imps / volley bosses.

var velocity := Vector3.ZERO
var team := 0
var damage := 6.0
var life := 1.6
var radius := 0.7
var prev := Vector3.ZERO


static func fire(parent: Node, pos: Vector3, dir: Vector3, from_team: int, dmg: float, speed := 26.0) -> Projectile:
	var p := Projectile.new()
	p.team = from_team
	p.damage = dmg
	p.velocity = dir.normalized() * speed
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.55)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#6be8ff") if from_team == 0 else Color("#ff4a3a")
	mi.material_override = m
	p.add_child(mi)
	parent.add_child(p)
	p.global_position = pos
	p.prev = pos
	if dir.length() > 0.01:
		p.look_at(pos + dir, Vector3.UP)
	return p


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var step := velocity * delta
	var from := global_position
	var to := from + step
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if not space.intersect_ray(q).is_empty():
		queue_free()
		return
	global_position = to
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or not f.alive or f.team == team or f.team == 2:
			continue
		var d := Vector2(f.global_position.x - to.x, f.global_position.z - to.z).length()
		var dy := to.y - f.global_position.y
		if d < 0.55 * f.body_scale + 0.15 and dy > -0.1 and dy < 2.0 * f.body_scale:
			f.take_hit(damage, from - velocity.normalized(), 3.0, false)
			queue_free()
			return
