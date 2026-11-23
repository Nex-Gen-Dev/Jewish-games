class_name Player
extends Fighter
## The human-controlled fighter. Reads TouchControls (or keyboard on desktop).
## Look (skin, shirt, kippah...) comes from the user's profile so the server can
## push a different character to each user.

const JUMP_SPEED := 9.0

var controls: TouchControls
var cam_yaw := 0.0
var combo := 0
var combo_timer := 0.0
var queued := ""
var queued_time := 0.0
var coyote_jump := true
var shoot_cd := 0.0
var shoot_pose := 0.0
var fp_lock := false ## first-person: always face where the camera looks
var combat_enabled := true ## false in the shul: no fighting there


func _init() -> void:
	team = 0
	max_health = 120.0 + (30.0 if Profile.owns("armor") else 0.0)
	move_speed = 6.2
	look["skin"] = Profile.get_color("character", "skin", look["skin"])
	look["shirt"] = Profile.get_color("character", "shirt", look["shirt"])
	look["pants"] = Profile.get_color("character", "pants", look["pants"])
	look["hair"] = Profile.get_color("character", "hair", look["hair"])
	look["kippah"] = Profile.get_flag("character", "kippah", true)
	look["kippah_color"] = Profile.get_color("character", "kippah_color", look["kippah_color"])
	if Profile.owns("blaster"):
		look["weapon"] = "gun"


func _key_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	return v.normalized() if v.length() > 1.0 else v


func _unhandled_key_input(event: InputEvent) -> void:
	if controls == null or not event.is_pressed() or event.is_echo():
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_J: controls.press("punch")
		KEY_K: controls.press("kick")
		KEY_SPACE: controls.press("jump")
		KEY_SHIFT, KEY_L: controls.press("dodge")
		KEY_H: controls.press("shoot")
		KEY_B: controls.press("bomb")


func animate(delta: float) -> void:
	super(delta)
	shoot_pose = maxf(shoot_pose - delta, 0.0)
	if shoot_pose > 0.0 and state == &"idle":
		var arm: Node3D = parts.get("arm_r")
		if arm:
			arm.rotation.x = 1.45


func think(delta: float) -> void:
	if controls == null:
		return
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0
	queued_time = maxf(queued_time - delta, 0.0)
	if queued_time <= 0.0:
		queued = ""

	var mv := controls.get_move() + _key_vector()
	if mv.length() > 1.0:
		mv = mv.normalized()
	desired_move = Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0.0, mv.y)
	if fp_lock and state == &"idle":
		face_dir = Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	elif state == &"idle" and desired_move.length() > 0.15:
		face_dir = desired_move.normalized()

	for action in ["punch", "kick", "jump", "dodge", "shoot"]:
		if controls.consume(action):
			queued = action
			queued_time = 0.28

	if queued != "" and state == &"idle":
		var a := queued
		queued = ""
		_perform(a)


func _perform(action: String) -> void:
	if not combat_enabled and action != "jump" and action != "dodge":
		return
	match action:
		"shoot":
			_shoot()
		"punch", "kick":
			_auto_aim()
			if action == "punch":
				combo += 1
				combo_timer = 0.7
				damage_mult = (1.0 if combo < 3 else 1.7) * _glove()
			else:
				damage_mult = _glove()
				combo = 0
			start_attack(&"punch" if action == "punch" else &"kick")
			if action == "punch" and combo >= 3:
				attack_data = attack_data.duplicate()
				attack_data["heavy"] = true ## third punch staggers bosses
				attack_data["knock"] = 7.0
				combo = 0
		"jump":
			if is_on_floor():
				velocity.y = JUMP_SPEED
		"dodge":
			start_dodge(desired_move if desired_move.length() > 0.1 else face_dir)


func _glove() -> float:
	return 1.3 if Profile.owns("iron_gloves") else 1.0


func _shoot() -> void:
	if not Profile.owns("blaster") or shoot_cd > 0.0:
		return
	var best: Fighter = null
	var best_score := -1.0
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.team != 1 or not f.alive:
			continue
		var to := f.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 28.0 or d < 0.1:
			continue
		var facing := face_dir.dot(to / d)
		var score := facing * 2.0 - d * 0.03
		if facing > 0.35 and score > best_score:
			best_score = score
			best = f
	var dir := face_dir
	if best:
		dir = best.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized()
	face_dir = dir
	shoot_cd = 0.18 if Profile.owns("rapid") else 0.38
	shoot_pose = 0.2
	Projectile.fire(get_parent(), global_position + Vector3(0, 1.35, 0) + dir * 0.9, dir, 0, 14.0 if Profile.owns("golden_blaster") else 8.0, 30.0)


## Turn toward the nearest enemy so touch players don't need pixel-perfect aim.
func _auto_aim() -> void:
	var best: Fighter = null
	var best_d := 3.6
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.team != 1 or not f.alive:
			continue
		var d := global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	if best:
		var to := best.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			face_dir = to.normalized()
