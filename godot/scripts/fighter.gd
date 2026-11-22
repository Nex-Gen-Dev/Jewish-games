class_name Fighter
extends CharacterBody3D
## Base class for anything that fights: procedural humanoid rig, state machine
## (idle / attack / hurt / dodge / dead / sleep), hit detection and animation.
## Player and Enemy extend this and override think().

signal died(f: Fighter)
signal hit_taken(f: Fighter, amount: float)
signal landed_hit(attacker: Fighter, victim: Fighter)

const GRAVITY := 26.0

const ATTACKS := {
	&"punch": {"dur": 0.36, "hit": 0.13, "hit_end": 0.24, "dmg": 7.0, "range": 1.9, "knock": 4.0, "lunge": 3.0, "heavy": false},
	&"kick": {"dur": 0.56, "hit": 0.24, "hit_end": 0.36, "dmg": 13.0, "range": 2.3, "knock": 8.5, "lunge": 4.0, "heavy": true},
	&"slam": {"dur": 0.9, "hit": 0.5, "hit_end": 0.56, "dmg": 14.0, "range": 3.6, "knock": 7.0, "lunge": 0.0, "heavy": true, "aoe": true},
	&"ring": {"dur": 0.9, "hit": 0.5, "hit_end": 0.56, "dmg": 11.0, "range": 4.2, "knock": 6.0, "lunge": 0.0, "heavy": true, "aoe": true},
	&"stab": {"dur": 0.34, "hit": 0.12, "hit_end": 0.22, "dmg": 9.0, "range": 1.8, "knock": 3.0, "lunge": 6.0, "heavy": false},
	&"dash": {"dur": 0.6, "hit": 0.05, "hit_end": 0.5, "dmg": 12.0, "range": 1.7, "knock": 9.0, "lunge": 14.0, "heavy": true, "constant": true},
}

var team := 0 ## 0 = player side, 1 = enemies
var max_health := 100.0
var health := 100.0
var move_speed := 5.0
var accel := 40.0
var body_scale := 1.0
var damage_mult := 1.0
var power := 1.0 ## level boost (Matzah power)
var alive := true
var armored := false ## bosses ignore light-hit staggers

var state: StringName = &"idle"
var state_time := 0.0
var attack_kind: StringName = &""
var attack_data: Dictionary = {}
var attack_hit_done := false
var attack_fx_done := false
var punch_side := 0
var invuln := 0.0
var dodge_dir := Vector3.FORWARD
var dodge_speed := 11.0

var face_dir := Vector3(0, 0, -1)
var desired_move := Vector3.ZERO
var telegraph := false

var look := {
	"skin": Color("#e8b894"), "shirt": Color("#f2f2f2"), "pants": Color("#1b1d2a"),
	"scale": 1.0, "horns": false, "tail": false, "kippah": false,
	"kippah_color": Color("#1c1c28"), "hair": Color("#3a2a1c"), "eye": Color.BLACK,
	"weapon": "", "light": false, "beard": false, "hat": false, "tallis": false,
}

var rig: Node3D
var parts: Dictionary = {}
var mats: Array[StandardMaterial3D] = []
var flash := 0.0
var glow_cache := -1.0
var walk_phase := 0.0
var anim_time := 0.0


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = 2
	collision_mask = 1
	body_scale = look.get("scale", 1.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35 * body_scale
	cap.height = 1.8 * body_scale
	cs.shape = cap
	cs.position.y = 0.9 * body_scale
	add_child(cs)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	build_rig()
	health = max_health


# ---------------------------------------------------------------- building

func make_mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = Color.BLACK
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats.append(m)
	return m


func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = make_mat(color, unshaded)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func build_rig() -> void:
	rig.scale = Vector3.ONE * body_scale
	var skin: Color = look["skin"]
	var shirt: Color = look["shirt"]
	var pants: Color = look["pants"]

	var hips := _pivot(rig, Vector3(0, 0.9, 0))
	parts["hips"] = hips
	for side in [-1, 1]:
		if look["light"]:
			break
		var leg := _pivot(hips, Vector3(0.14 * side, 0, 0))
		var lm := CapsuleMesh.new()
		lm.radius = 0.11
		lm.height = 0.92
		add_mesh(leg, lm, pants, Vector3(0, -0.44, 0))
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.2, 0.1, 0.32)
		add_mesh(leg, shoe, Color("#15151a"), Vector3(0, -0.86, -0.05))
		parts["leg_l" if side < 0 else "leg_r"] = leg

	var torso := _pivot(hips, Vector3.ZERO)
	parts["torso"] = torso
	var tm := BoxMesh.new()
	tm.size = Vector3(0.52, 0.66, 0.29)
	add_mesh(torso, tm, shirt, Vector3(0, 0.37, 0))

	for side in [-1, 1]:
		var arm := _pivot(torso, Vector3(0.34 * side, 0.63, 0))
		var am := CapsuleMesh.new()
		am.radius = 0.085
		am.height = 0.66
		add_mesh(arm, am, shirt, Vector3(0, -0.28, 0))
		var hand := SphereMesh.new()
		hand.radius = 0.09
		hand.height = 0.18
		add_mesh(arm, hand, skin, Vector3(0, -0.6, 0))
		parts["arm_l" if side < 0 else "arm_r"] = arm

	var head := _pivot(torso, Vector3(0, 0.82, 0))
	parts["head"] = head
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.4
	add_mesh(head, hm, skin, Vector3(0, 0.2, 0))
	for side in [-1, 1]:
		if look["light"]:
			break
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		var eye_col: Color = look["eye"]
		add_mesh(head, em, eye_col, Vector3(0.075 * side, 0.22, -0.175), eye_col != Color.BLACK)

	var hair := SphereMesh.new()
	hair.radius = 0.205
	hair.height = 0.205
	hair.is_hemisphere = true
	add_mesh(head, hair, look["hair"], Vector3(0, 0.235, 0.03))
	if look["kippah"]:
		var kp := SphereMesh.new()
		kp.radius = 0.14
		kp.height = 0.14
		kp.is_hemisphere = true
		add_mesh(head, kp, look["kippah_color"], Vector3(0, 0.375, 0.02))

	_build_extras(torso, head)

	if look["horns"]:
		for side in [-1, 1]:
			var hn := CylinderMesh.new()
			hn.top_radius = 0.0
			hn.bottom_radius = 0.06
			hn.height = 0.26
			var h := add_mesh(head, hn, Color("#2a0a0a"), Vector3(0.12 * side, 0.4, -0.02))
			h.rotation.z = -0.4 * side
	if look["tail"]:
		var tl := CylinderMesh.new()
		tl.top_radius = 0.01
		tl.bottom_radius = 0.045
		tl.height = 0.7
		var t := add_mesh(hips, tl, look["skin"], Vector3(0, -0.1, 0.32))
		t.rotation.x = -0.9
		parts["tail"] = t


func _build_extras(torso: Node3D, head: Node3D) -> void:
	var arm_r: Node3D = parts.get("arm_r")
	if look["light"]:
		var robe := BoxMesh.new()
		robe.size = Vector3(0.36, 0.9, 0.24)
		add_mesh(parts["hips"], robe, look["pants"], Vector3(0, -0.45, 0))
	match String(look["weapon"]):
		"knife":
			var blade := BoxMesh.new()
			blade.size = Vector3(0.035, 0.32, 0.015)
			add_mesh(arm_r, blade, Color("#d5dbe3"), Vector3(0, -0.8, 0))
			var grip := BoxMesh.new()
			grip.size = Vector3(0.05, 0.1, 0.05)
			add_mesh(arm_r, grip, Color("#2a1a10"), Vector3(0, -0.64, 0))
		"rifle":
			var body := BoxMesh.new()
			body.size = Vector3(0.07, 0.08, 0.9)
			add_mesh(arm_r, body, Color("#2b2b30"), Vector3(0, -0.6, -0.3))
			var tip := BoxMesh.new()
			tip.size = Vector3(0.05, 0.05, 0.06)
			add_mesh(arm_r, tip, Color("#ff3b3b"), Vector3(0, -0.6, -0.78), true)
		"gun":
			var gb := BoxMesh.new()
			gb.size = Vector3(0.07, 0.09, 0.3)
			add_mesh(arm_r, gb, Color("#3a4a66"), Vector3(0, -0.6, -0.14))
			var gt := BoxMesh.new()
			gt.size = Vector3(0.05, 0.05, 0.05)
			add_mesh(arm_r, gt, Color("#5be0ff"), Vector3(0, -0.6, -0.32), true)
	if look["tallis"]:
		var tm := BoxMesh.new()
		tm.size = Vector3(0.6, 0.12, 0.36)
		add_mesh(torso, tm, Color("#f4f4f0"), Vector3(0, 0.68, 0))
		var tm2 := BoxMesh.new()
		tm2.size = Vector3(0.56, 0.5, 0.33)
		add_mesh(torso, tm2, Color("#f4f4f0"), Vector3(0, 0.4, 0.01))
		for i in 3:
			var st := BoxMesh.new()
			st.size = Vector3(0.57, 0.025, 0.335)
			add_mesh(torso, st, Color("#22304a"), Vector3(0, 0.22 + i * 0.12, 0.012))
	if look["beard"]:
		var bm := SphereMesh.new()
		bm.radius = 0.15
		bm.height = 0.22
		add_mesh(head, bm, look["hair"], Vector3(0, 0.08, -0.06))
	if look["hat"]:
		var hb := CylinderMesh.new()
		hb.top_radius = 0.17
		hb.bottom_radius = 0.17
		hb.height = 0.16
		add_mesh(head, hb, Color("#141418"), Vector3(0, 0.46, 0.0))
		var brim := CylinderMesh.new()
		brim.top_radius = 0.27
		brim.bottom_radius = 0.27
		brim.height = 0.02
		add_mesh(head, brim, Color("#141418"), Vector3(0, 0.39, 0.0))


# ---------------------------------------------------------------- combat

func think(_delta: float) -> void:
	pass


func start_attack(kind: StringName) -> bool:
	if state != &"idle" or not alive:
		return false
	attack_kind = kind
	attack_data = ATTACKS[kind]
	state = &"attack"
	state_time = 0.0
	attack_hit_done = false
	attack_fx_done = false
	if kind == &"punch":
		punch_side = 1 - punch_side
	elif kind == &"stab":
		punch_side = 1
	return true


func start_dodge(dir: Vector3) -> bool:
	if state != &"idle" or not alive:
		return false
	dodge_dir = Vector3.ZERO ## the dodge no longer moves you: steer yourself
	state = &"dodge"
	state_time = 0.0
	invuln = 0.6
	return true


func _do_hit() -> bool:
	var d := attack_data
	var any := false
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f == self or f.team == team or f.team == 2 or not f.alive:
			continue
		var to := f.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		var reach: float = d["range"] * body_scale + f.body_scale * 0.35
		if dist > reach:
			continue
		if d.get("aoe", false):
			if f.global_position.y > global_position.y + 0.55:
				continue ## jumped over the shockwave
		elif dist > 0.6 and face_dir.dot(to / dist) < 0.2:
			continue
		var dmg: float = d["dmg"] * damage_mult * power
		if f.take_hit(dmg, global_position, d["knock"], d["heavy"]):
			any = true
			landed_hit.emit(self, f)
	return any


func take_hit(amount: float, from_pos: Vector3, knock: float, heavy: bool) -> bool:
	if not alive or invuln > 0.0 or state == &"dodge" or state == &"sleep":
		return false
	health = maxf(health - amount, 0.0)
	flash = 1.0
	hit_taken.emit(self, amount)
	var pos := global_position + Vector3(0, 1.2 * body_scale, 0)
	Fx.burst(get_parent(), pos, Color(1, 0.85, 0.35))
	Fx.number(get_parent(), pos + Vector3(0, 0.6, 0), str(int(round(amount))), Color(1, 0.95, 0.5) if team == 1 else Color(1, 0.4, 0.4))
	if health <= 0.0:
		_die()
		return true
	var away := global_position - from_pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -face_dir
	if not armored or heavy:
		state = &"hurt"
		state_time = 0.0
		telegraph = false
		velocity.x = away.x * knock
		velocity.z = away.z * knock
		invuln = 0.12
	else:
		velocity.x = away.x * knock * 0.3
		velocity.z = away.z * knock * 0.3
	return true


func _die() -> void:
	alive = false
	state = &"dead"
	state_time = 0.0
	telegraph = false
	collision_layer = 0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(rig, "rotation:x", PI / 2.0, 0.45)
	tw.tween_property(rig, "position:y", 0.12, 0.45)
	died.emit(self)


# ---------------------------------------------------------------- physics

func _physics_process(delta: float) -> void:
	if state == &"sleep":
		return
	state_time += delta
	invuln = maxf(invuln - delta, 0.0)
	anim_time += delta
	if alive:
		think(delta)

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	match state:
		&"idle":
			hv = hv.move_toward(desired_move * move_speed, accel * delta)
		&"attack":
			var d := attack_data
			var lunge: float = d["lunge"]
			if state_time < d["hit_end"] and lunge > 0.0:
				var s: float = lunge if d.get("constant", false) else lunge * (1.0 - state_time / d["dur"])
				hv = face_dir * s
			else:
				hv = hv.move_toward(Vector3.ZERO, 30.0 * delta)
			if d.get("aoe", false) and not attack_fx_done and state_time >= d["hit"]:
				attack_fx_done = true
				var col := Color(1, 0.4, 0.2) if attack_kind == &"slam" else Color(1, 0.85, 0.2)
				Fx.ring(get_parent(), global_position, d["range"] * body_scale, col)
			if not attack_hit_done and state_time >= d["hit"] and state_time <= d["hit_end"]:
				if _do_hit():
					attack_hit_done = true
			if state_time >= d["dur"]:
				state = &"idle"
				state_time = 0.0
		&"hurt":
			hv = hv.move_toward(Vector3.ZERO, 14.0 * delta)
			if state_time >= 0.3:
				state = &"idle"
				state_time = 0.0
		&"dodge":
			hv = desired_move * move_speed * 0.85
			if state_time >= 0.4:
				state = &"idle"
				state_time = 0.0
		&"dead":
			hv = hv.move_toward(Vector3.ZERO, 12.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()

	_face(delta)
	_update_glow(delta)
	animate(delta)


func _face(delta: float) -> void:
	if state == &"dead" or rig == null:
		return
	var target := atan2(-face_dir.x, -face_dir.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, target, 1.0 - exp(-18.0 * delta))


func _update_glow(delta: float) -> void:
	flash = maxf(flash - delta * 5.0, 0.0)
	var g := flash * 0.8
	var col := Color(1, 1, 1)
	if telegraph:
		var pulse := 0.5 + 0.5 * sin(anim_time * 28.0)
		g = maxf(g, 0.25 + 0.45 * pulse)
		col = Color(1, 0.45, 0.1)
	if absf(g - glow_cache) < 0.01 and not telegraph:
		return
	glow_cache = g
	for m in mats:
		m.emission = col * g


# ---------------------------------------------------------------- animation

func animate(delta: float) -> void:
	var k := 1.0 - exp(-20.0 * delta)
	var speed := Vector2(velocity.x, velocity.z).length()
	var a_l := 0.0
	var a_r := 0.0
	var l_l := 0.0
	var l_r := 0.0
	var t_x := 0.0
	var t_y := 0.0
	var bob := 0.0

	match state:
		&"idle":
			var amt := clampf(speed / maxf(move_speed, 0.1), 0.0, 1.0)
			walk_phase += speed * delta * 2.1
			var s := sin(walk_phase)
			a_l = s * 0.9 * amt
			a_r = -s * 0.9 * amt
			l_l = -s * 0.8 * amt
			l_r = s * 0.8 * amt
			bob = absf(s) * 0.05 * amt + sin(anim_time * 2.0) * 0.008
			t_x = 0.12 * amt
			if not is_on_floor():
				a_l = 1.0
				a_r = 1.0
				l_l = 0.5
				l_r = -0.3
			if telegraph and look["weapon"] != "rifle":
				a_l = 2.6
				a_r = 2.6
				t_x = -0.25
			if look["weapon"] == "rifle":
				a_l = 0.7
				a_r = 0.1
				t_x = 0.1
		&"attack":
			k = 1.0 - exp(-45.0 * delta)
			var p: float = state_time / attack_data["dur"]
			match attack_kind:
				&"punch", &"stab":
					var v := _strike(p)
					if punch_side == 1:
						a_r = v
					else:
						a_l = v
					t_y = -0.5 * clampf(v, -0.5, 1.0) * (1.0 if punch_side == 1 else -1.0)
				&"kick":
					l_r = _strike(p) * 1.1
					a_l = 0.8
					t_x = -0.25 * clampf(_strike(p), 0.0, 1.0)
				&"slam", &"ring":
					a_l = 2.9 if p < 0.5 else 0.2
					a_r = a_l
					t_x = -0.35 if p < 0.5 else 0.6
					bob = 0.0 if p < 0.5 else -0.12
				&"dash":
					t_x = 0.7
					a_l = -0.8
					a_r = -0.8
					l_l = 0.9
					l_r = -0.9
		&"hurt":
			t_x = -0.5
			a_l = 0.6
			a_r = 0.6
			l_l = 0.2
			l_r = -0.2
		&"dodge":
			t_x = 0.95
			a_l = -0.7
			a_r = -0.7
			l_l = 1.0
			l_r = -0.6
			bob = -0.25
		&"dead":
			return

	_rot("torso", Vector3(-t_x, t_y, 0), k) ## t_x > 0 = lean forward
	_rot("arm_l", Vector3(a_l, 0, 0.06), k)
	_rot("arm_r", Vector3(a_r, 0, -0.06), k)
	_rot("leg_l", Vector3(l_l, 0, 0), k)
	_rot("leg_r", Vector3(l_r, 0, 0), k)
	var hips: Node3D = parts.get("hips")
	if hips:
		hips.position.y = lerpf(hips.position.y, 0.9 + bob, k)
	var tail: Node3D = parts.get("tail")
	if tail:
		tail.rotation.z = sin(anim_time * 5.0) * 0.4


## 0 -> wind-up (negative) -> strike (positive) -> recover.
func _strike(p: float) -> float:
	if p < 0.3:
		return lerpf(0.0, -0.9, p / 0.3)
	elif p < 0.55:
		return lerpf(-0.9, 1.6, (p - 0.3) / 0.25)
	return lerpf(1.6, 0.0, (p - 0.55) / 0.45)


func _rot(part: String, target: Vector3, k: float) -> void:
	var n: Node3D = parts.get(part)
	if n:
		n.rotation = n.rotation.lerp(target, k)
