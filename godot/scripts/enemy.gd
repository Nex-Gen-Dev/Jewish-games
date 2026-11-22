class_name Enemy
extends Fighter
## AI fighters: the Yetzer Hara boss, Snooze Imps, and the Alarm Clock boss.
## Every attack is telegraphed (orange pulse + raised arms / shaking) so touch
## players have time to dodge or jump.

signal taunt(who: String, text: String)
signal enraged_now(e: Enemy)

const DEFS := {
	"yetzer": {
		"name": "The Yetzer Hara", "scale": 1.3, "hp": 260.0, "speed": 3.7, "dmg": 1.0, "boss": true,
		"skin": Color("#b01818"), "shirt": Color("#2a0f33"), "pants": Color("#1a0a22"),
		"horns": true, "tail": true, "eye": Color("#ffe14a"), "hair": Color("#2a0505"),
		"taunts": ["Five more minutes...", "The blanket is so warm...", "Nobody will notice if you skip.", "You can daven later!", "Look how comfy that pillow is."],
		"low_hp": "Fine... see you tomorrow morning.",
	},
	"imp": {
		"name": "Snooze Imp", "scale": 0.8, "hp": 38.0, "speed": 4.2, "dmg": 0.7, "boss": false,
		"skin": Color("#6a3fa0"), "shirt": Color("#3a2a5a"), "pants": Color("#241a3a"),
		"horns": true, "tail": true, "eye": Color("#ffe14a"), "hair": Color("#241a3a"),
		"taunts": [],
	},
	"knife": {
		"name": "Knife Imp", "scale": 0.85, "hp": 46.0, "speed": 5.0, "dmg": 1.0, "boss": false,
		"skin": Color("#a8325a"), "shirt": Color("#2a1a2e"), "pants": Color("#1a1020"),
		"horns": true, "tail": true, "eye": Color("#ffe14a"), "hair": Color("#241a3a"), "weapon": "knife", "taunts": [],
	},
	"rifle": {
		"name": "Rifle Imp", "scale": 0.85, "hp": 40.0, "speed": 3.6, "dmg": 1.0, "boss": false, "ranged": true,
		"skin": Color("#3f5ab0"), "shirt": Color("#1a2030"), "pants": Color("#10141f"),
		"horns": true, "tail": true, "eye": Color("#ff5a3a"), "hair": Color("#10141f"), "weapon": "rifle", "taunts": [],
	},
	"gunslinger": {
		"name": "Yetzer Hara: Gunslinger", "scale": 1.35, "hp": 330.0, "speed": 4.0, "dmg": 1.1, "boss": true, "volley": true,
		"skin": Color("#2a3f9a"), "shirt": Color("#150d24"), "pants": Color("#0d0916"),
		"horns": true, "tail": true, "eye": Color("#ff5a3a"), "hair": Color("#0d0916"), "weapon": "rifle",
		"taunts": ["Nobody shoots straight at midnight.", "Ready, aim...", "One little snack. Just one."],
		"low_hp": "Okay, okay! I'll go away!",
	},
	"king": {
		"name": "The Yetzer Hara (Seder Night)", "scale": 1.5, "hp": 400.0, "speed": 4.0, "dmg": 1.0, "boss": true, "volley": true,
		"skin": Color("#8a1010"), "shirt": Color("#33102a"), "pants": Color("#1d0a1a"),
		"horns": true, "tail": true, "eye": Color("#ffe14a"), "hair": Color("#1d0a1a"), "weapon": "rifle",
		"taunts": ["Just five more minutes of sleep.", "The afikoman can wait.", "Skip the questions, nobody's listening.", "Eat the matzah later!"],
		"low_hp": "Fine. See you next year.",
	},
	"haman": {
		"name": "Yetzer Hara: Purim Edition", "scale": 1.4, "hp": 380.0, "speed": 4.2, "dmg": 1.1, "boss": true, "volley": true,
		"skin": Color("#a02a6a"), "shirt": Color("#2a1030"), "pants": Color("#160a24"),
		"horns": true, "tail": true, "eye": Color("#7dff4a"), "hair": Color("#160a24"), "weapon": "rifle",
		"taunts": ["Who needs a megillah? Sleep in!", "Drink a little more... then a little more.", "Costumes! Nobody will know it's you."],
		"low_hp": "Okay, okay! Chag Purim sameach!",
	},
	"overlord": {
		"name": "The Yetzer Hara: Final Round", "scale": 1.6, "hp": 650.0, "speed": 4.3, "dmg": 1.15, "boss": true, "volley": true,
		"skin": Color("#6a0a3a"), "shirt": Color("#1a0830"), "pants": Color("#10061c"),
		"horns": true, "tail": true, "eye": Color("#ff3a3a"), "hair": Color("#10061c"), "weapon": "rifle",
		"taunts": ["You can't beat me every day.", "Tomorrow, you'll be tired again.", "I'll be back every morning.", "Just skip one tefillah..."],
		"low_hp": "Fine. But I'll see you tomorrow.",
	},
	"clock": {
		"name": "Alarm Clock", "scale": 1.3, "hp": 230.0, "speed": 3.4, "dmg": 1.0, "boss": true,
		"taunts": ["BRRRRING!", "You're LATE!", "Snooze? Never!"],
		"low_hp": "Ding... ding... dong...",
	},
}

var kind := "imp"
var def: Dictionary = {}
var display_name := "Enemy"
var is_boss := false
var target: Fighter
var aggro := 15.0
var active := false

var ai_state: StringName = &"approach"
var ai_time := 0.0
var attack_cd := 1.0
var pending: StringName = &"punch"
var tel_time := 0.4
var attack_count := 0
var enraged := false
var taunt_timer := 5.0
var said_low := false
var aim_dir := Vector3.FORWARD
var laser: MeshInstance3D


func setup(kind_id: String, tgt: Fighter) -> void:
	kind = kind_id
	def = DEFS[kind_id]
	target = tgt
	team = 1
	display_name = def["name"]
	is_boss = def["boss"]
	armored = is_boss
	max_health = def["hp"]
	move_speed = def["speed"]
	damage_mult = def["dmg"]
	look["scale"] = def["scale"]
	for key in ["skin", "shirt", "pants", "hair", "eye"]:
		if def.has(key):
			look[key] = def[key]
	look["weapon"] = def.get("weapon", "")
	look["horns"] = def.get("horns", false)
	look["tail"] = def.get("tail", false)
	look["kippah"] = false
	attack_cd = randf_range(0.6, 1.4)


func build_rig() -> void:
	if kind == "clock":
		_build_clock()
	else:
		super()


func _build_clock() -> void:
	rig.scale = Vector3.ONE * body_scale
	var red := Color("#d63030")
	var gold := Color("#e8b23a")
	var cream := Color("#f6f1e2")

	for side in [-1, 1]:
		var leg := _pivot(rig, Vector3(0.2 * side, 0.46, 0))
		var lm := CylinderMesh.new()
		lm.top_radius = 0.05
		lm.bottom_radius = 0.05
		lm.height = 0.46
		add_mesh(leg, lm, Color("#222222"), Vector3(0, -0.23, 0))
		var foot := BoxMesh.new()
		foot.size = Vector3(0.2, 0.08, 0.3)
		add_mesh(leg, foot, Color("#111111"), Vector3(0, -0.45, -0.06))
		parts["leg_l" if side < 0 else "leg_r"] = leg

	var torso := _pivot(rig, Vector3(0, 0.95, 0))
	parts["torso"] = torso
	var body := CylinderMesh.new()
	body.top_radius = 0.58
	body.bottom_radius = 0.58
	body.height = 0.46
	body.radial_segments = 28
	var b := add_mesh(torso, body, red)
	b.rotation.x = PI / 2.0

	var face := CylinderMesh.new()
	face.top_radius = 0.49
	face.bottom_radius = 0.49
	face.height = 0.03
	face.radial_segments = 28
	var f := add_mesh(torso, face, cream, Vector3(0, 0, -0.235))
	f.rotation.x = PI / 2.0

	for i in 12:
		var a := TAU * i / 12.0
		var tick := BoxMesh.new()
		tick.size = Vector3(0.03, 0.08 if i % 3 == 0 else 0.05, 0.02)
		var t := add_mesh(torso, tick, Color("#222222"), Vector3(sin(a) * 0.4, cos(a) * 0.4, -0.25))
		t.rotation.z = -a

	var hand_m := _pivot(torso, Vector3(0, 0, -0.26))
	var hand_h := _pivot(torso, Vector3(0, 0, -0.265))
	var mm := BoxMesh.new()
	mm.size = Vector3(0.035, 0.36, 0.02)
	add_mesh(hand_m, mm, Color("#111111"), Vector3(0, 0.15, 0))
	var hm := BoxMesh.new()
	hm.size = Vector3(0.05, 0.24, 0.02)
	add_mesh(hand_h, hm, Color("#111111"), Vector3(0, 0.1, 0))
	hand_h.rotation.z = -1.0
	parts["hand_m"] = hand_m
	parts["hand_h"] = hand_h

	for side in [-1, 1]:
		var ey := SphereMesh.new()
		ey.radius = 0.065
		ey.height = 0.13
		add_mesh(torso, ey, Color.WHITE, Vector3(0.16 * side, 0.2, -0.27))
		var pu := SphereMesh.new()
		pu.radius = 0.03
		pu.height = 0.06
		add_mesh(torso, pu, Color("#a00000"), Vector3(0.16 * side, 0.2, -0.325), true)
		var brow := BoxMesh.new()
		brow.size = Vector3(0.17, 0.035, 0.02)
		var br := add_mesh(torso, brow, Color("#111111"), Vector3(0.16 * side, 0.3, -0.28))
		br.rotation.z = 0.45 * side

	for side in [-1, 1]:
		var bell_pivot := _pivot(torso, Vector3(0.3 * side, 0.52, 0))
		var bm := SphereMesh.new()
		bm.radius = 0.2
		bm.height = 0.2
		bm.is_hemisphere = true
		add_mesh(bell_pivot, bm, gold, Vector3.ZERO)
		parts["bell_l" if side < 0 else "bell_r"] = bell_pivot
		var arm := _pivot(torso, Vector3(0.6 * side, 0.1, 0))
		var am := CapsuleMesh.new()
		am.radius = 0.06
		am.height = 0.5
		add_mesh(arm, am, Color("#222222"), Vector3(0, -0.22, 0))
		var gl := SphereMesh.new()
		gl.radius = 0.1
		gl.height = 0.2
		add_mesh(arm, gl, Color.WHITE, Vector3(0, -0.5, 0))
		parts["arm_l" if side < 0 else "arm_r"] = arm
	var rod := CylinderMesh.new()
	rod.top_radius = 0.015
	rod.bottom_radius = 0.015
	rod.height = 0.3
	add_mesh(torso, rod, Color("#333333"), Vector3(0, 0.66, 0))
	var knob := SphereMesh.new()
	knob.radius = 0.05
	knob.height = 0.1
	add_mesh(torso, knob, Color("#333333"), Vector3(0, 0.82, 0))


# ---------------------------------------------------------------- AI

func think(delta: float) -> void:
	if target == null or not target.alive:
		desired_move = Vector3.ZERO
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else -face_dir
	if not active:
		if dist < aggro:
			active = true
		else:
			desired_move = Vector3.ZERO
			return
	attack_cd -= delta
	_check_phase()
	_taunt_tick(delta)

	if def.get("ranged", false):
		_think_ranged(delta, dist, dir)
		return

	var reach := ATTACKS[&"punch"]["range"] * body_scale
	var stop := reach * 0.62
	var engage := reach * 0.95

	match ai_state:
		&"approach":
			if state != &"idle":
				desired_move = Vector3.ZERO
				return
			face_dir = dir
			if kind == "clock":
				stop = 1.8
			if dist > stop:
				var perp := Vector3(-dir.z, 0, dir.x)
				desired_move = (dir + perp * sin(anim_time * 1.4) * 0.25).normalized()
			else:
				desired_move = Vector3.ZERO
			if attack_cd <= 0.0 and _can_engage(dist, engage):
				_begin_attack(dist)
		&"telegraph":
			desired_move = Vector3.ZERO
			face_dir = dir
			ai_time += delta
			if state != &"idle":
				telegraph = false
				ai_state = &"approach"
				attack_cd = 0.8
			elif ai_time >= tel_time:
				telegraph = false
				if pending == &"volley":
					_fire_volley()
					ai_state = &"recover"
					ai_time = 0.0
				elif start_attack(pending):
					ai_state = &"strike"
				else:
					ai_state = &"approach"
		&"strike":
			desired_move = Vector3.ZERO
			if state == &"hurt":
				ai_state = &"approach"
				attack_cd = 0.9
			elif state == &"idle":
				ai_state = &"recover"
				ai_time = 0.0
		&"recover":
			desired_move = -dir * 0.25 if kind != "clock" else Vector3.ZERO
			ai_time += delta
			if ai_time >= (0.55 if not enraged else 0.3):
				ai_state = &"approach"
				attack_cd = randf_range(0.5, 1.2) * (0.6 if enraged else 1.0) if is_boss else randf_range(0.9, 1.8)


func _fire_volley() -> void:
	var spread := [-0.22, 0.0, 0.22] if enraged else [-0.14, 0.14]
	var base := global_position + Vector3(0, 1.3 * body_scale, 0)
	for a in spread:
		var d := aim_dir.rotated(Vector3.UP, a)
		Projectile.fire(get_parent(), base + d * 0.8, d, 1, 6.0 * damage_mult, 18.0)


## Rifle imps keep their distance, show a red laser line, then fire a bolt.
func _think_ranged(delta: float, dist: float, dir: Vector3) -> void:
	if state != &"idle":
		desired_move = Vector3.ZERO
		_clear_laser()
		return
	face_dir = dir
	if ai_state == &"telegraph":
		desired_move = Vector3.ZERO
		ai_time += delta
		if laser:
			laser.visible = true
		if ai_time >= 0.75:
			telegraph = false
			_clear_laser()
			var base := global_position + Vector3(0, 1.2 * body_scale, 0)
			Projectile.fire(get_parent(), base + aim_dir * 0.9, aim_dir, 1, 7.0 * damage_mult, 20.0)
			ai_state = &"recover"
			ai_time = 0.0
			attack_cd = randf_range(1.5, 2.4)
		return
	if dist < 6.0:
		desired_move = -dir
	elif dist > 12.0:
		desired_move = dir
	else:
		var perp := Vector3(-dir.z, 0, dir.x)
		desired_move = perp * sin(anim_time * 0.9 + float(get_instance_id() % 7))
	if ai_state == &"recover":
		ai_time += delta
		if ai_time > 0.4:
			ai_state = &"approach"
	if attack_cd <= 0.0 and dist < 19.0 and ai_state == &"approach":
		ai_state = &"telegraph"
		ai_time = 0.0
		telegraph = true
		aim_dir = (target.global_position - global_position)
		aim_dir.y = 0.0
		aim_dir = aim_dir.normalized()
		_make_laser()


func _make_laser() -> void:
	_clear_laser()
	laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 18.0)
	laser.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.2, 0.15, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser.material_override = m
	get_parent().add_child(laser)
	laser.global_position = global_position + Vector3(0, 1.2 * body_scale, 0) + aim_dir * 9.5
	laser.look_at(laser.global_position + aim_dir, Vector3.UP)


func _clear_laser() -> void:
	if laser and is_instance_valid(laser):
		laser.queue_free()
	laser = null


func _can_engage(dist: float, engage: float) -> bool:
	if kind == "clock":
		return dist < 7.5
	if def.get("volley", false):
		return dist < 13.0
	return dist < engage


func _begin_attack(dist: float) -> void:
	attack_count += 1
	match kind:
		"imp":
			pending = &"punch"
			tel_time = 0.38
		"knife":
			pending = &"stab"
			tel_time = 0.3
		"yetzer", "gunslinger", "king", "haman", "overlord":
			if def.get("volley", false) and dist > 5.0:
				pending = &"volley"
				tel_time = 0.7 if not enraged else 0.5
				aim_dir = (target.global_position - global_position)
				aim_dir.y = 0.0
				aim_dir = aim_dir.normalized()
				ai_state = &"telegraph"
				ai_time = 0.0
				telegraph = true
				return
			if attack_count % 4 == 0 or (enraged and attack_count % 3 == 0):
				pending = &"slam"
				tel_time = 0.75 if not enraged else 0.55
				Fx.warning_disc(get_parent(), global_position, ATTACKS[&"slam"]["range"] * body_scale, tel_time)
			elif attack_count % 3 == 0:
				pending = &"kick"
				tel_time = 0.5
			else:
				pending = &"punch"
				tel_time = 0.42 if not enraged else 0.3
		"clock":
			if dist > 3.6 and attack_count % 2 == 1:
				pending = &"dash"
				tel_time = 0.65 if not enraged else 0.45
			else:
				pending = &"ring"
				tel_time = 0.7 if not enraged else 0.5
				Fx.warning_disc(get_parent(), global_position, ATTACKS[&"ring"]["range"] * body_scale, tel_time)
	ai_state = &"telegraph"
	ai_time = 0.0
	telegraph = true


func _check_phase() -> void:
	if is_boss and not enraged and health < max_health * 0.5:
		enraged = true
		move_speed *= 1.25
		enraged_now.emit(self)
	if is_boss and not said_low and health < max_health * 0.2 and def.has("low_hp"):
		said_low = true
		taunt.emit(display_name, def["low_hp"])


func _taunt_tick(delta: float) -> void:
	var lines: Array = def.get("taunts", [])
	if lines.is_empty():
		return
	taunt_timer -= delta
	if taunt_timer <= 0.0:
		taunt_timer = randf_range(6.0, 9.0)
		taunt.emit(display_name, lines[randi() % lines.size()])


func _die() -> void:
	_clear_laser()
	super()
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_inside_tree():
			var tw := create_tween()
			tw.tween_property(rig, "scale", Vector3.ZERO, 0.35)
			tw.tween_callback(queue_free))


func appear() -> void:
	rig.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(rig, "scale", Vector3.ONE * body_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.7, 0.1, 0.9), 24)


# ---------------------------------------------------------------- animation

func animate(delta: float) -> void:
	if kind != "clock":
		super(delta)
		return
	var k := 1.0 - exp(-20.0 * delta)
	var speed := Vector2(velocity.x, velocity.z).length()
	var a := 0.0
	var l_l := 0.0
	var l_r := 0.0
	var t_x := 0.0
	var sway := 0.0
	var bob := 0.0
	var ringing := telegraph or state == &"attack"
	match state:
		&"idle":
			var amt := clampf(speed / maxf(move_speed, 0.1), 0.0, 1.0)
			walk_phase += speed * delta * 2.6
			var s := sin(walk_phase)
			l_l = s * 0.8 * amt
			l_r = -s * 0.8 * amt
			sway = s * 0.12 * amt
			bob = absf(s) * 0.07 * amt
			if telegraph:
				a = 2.5
		&"attack":
			k = 1.0 - exp(-40.0 * delta)
			var p: float = state_time / attack_data["dur"]
			if attack_kind == &"dash":
				t_x = 0.6
				a = -0.8
				var s := sin(anim_time * 30.0)
				l_l = s
				l_r = -s
			else:
				a = 2.8 if p < 0.5 else 0.2
				bob = 0.25 if p < 0.5 else -0.12
		&"hurt":
			t_x = -0.5
			a = 0.9
		&"dead":
			return
	_rot("torso", Vector3(-t_x, 0, sway), k)
	_rot("arm_l", Vector3(a, 0, 0.1), k)
	_rot("arm_r", Vector3(a, 0, -0.1), k)
	_rot("leg_l", Vector3(l_l, 0, 0), k)
	_rot("leg_r", Vector3(l_r, 0, 0), k)
	var torso: Node3D = parts["torso"]
	torso.position.y = lerpf(torso.position.y, 0.95 + bob, k)
	var amp := 0.12 + (0.9 if ringing else 0.0)
	var freq := 45.0 if ringing else 4.0
	var bl: Node3D = parts["bell_l"]
	var br: Node3D = parts["bell_r"]
	bl.rotation.z = 0.5 + sin(anim_time * freq) * amp * 0.5
	br.rotation.z = -0.5 - sin(anim_time * freq) * amp * 0.5
	rig.position.x = sin(anim_time * 90.0) * 0.035 if telegraph else lerpf(rig.position.x, 0.0, k)
	var hm: Node3D = parts["hand_m"]
	var hh: Node3D = parts["hand_h"]
	hm.rotation.z -= delta * (9.0 if ringing else 0.6)
	hh.rotation.z -= delta * (0.75 if ringing else 0.05)
