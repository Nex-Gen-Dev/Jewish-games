class_name Npc
extends Fighter
## Non-hostile people: mispallelim in the shul, family at the Seder, the
## talker who disturbs your davening, and the Yetzer Tov who guides you.
## Static NPCs have physics off and just sway (shuckling) for performance.

enum Kind { SEATED, WANDERER, TOV, PEST, WHISPER }

var kind: Kind = Kind.SEATED
var sway_phase := 0.0
var sway_amount := 0.1
var goal := Vector3.ZERO
var has_goal := false
var arrived := false
var look_at_pos := Vector3.ZERO
var tov_label: Label3D
var halo: MeshInstance3D
var cooldown_until := 0.0


func _init() -> void:
	team = 2


func make_mat(color: Color, unshaded := false) -> StandardMaterial3D:
	return Levels.mat(color, 0.0, 0.8) if not unshaded else Levels.unshaded_mat(color)


func _ready() -> void:
	super()
	collision_layer = 1 ## solid for the player
	remove_from_group("fighters")
	add_to_group("npcs")
	sway_phase = randf() * TAU
	match kind:
		Kind.SEATED:
			set_physics_process(false)
			_pose_holding_book()
		Kind.TOV:
			set_physics_process(false)
			_pose_holding_book()
			_make_tov_extras()
		Kind.WHISPER:
			set_physics_process(false)
		_:
			pass


func _pose_holding_book() -> void:
	for n in ["arm_l", "arm_r"]:
		var a: Node3D = parts.get(n)
		if a:
			a.rotation = Vector3(1.05, 0, 0.0)


func _make_tov_extras() -> void:
	halo = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.26
	halo.mesh = tm
	halo.material_override = Levels.mat(Color("#ffe27a"), 2.5)
	halo.position = Vector3(0, 2.3 * body_scale, 0)
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffe9a8")
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position = Vector3(0, 1.6, 0)
	add_child(light)
	tov_label = Label3D.new()
	tov_label.text = "Yetzer Tov"
	tov_label.font_size = 64
	tov_label.pixel_size = 0.006
	tov_label.modulate = Color("#fff3b0")
	tov_label.outline_size = 12
	tov_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tov_label.no_depth_test = true
	tov_label.position = Vector3(0, 2.75 * body_scale, 0)
	add_child(tov_label)


func _process(delta: float) -> void:
	if rig == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	match kind:
		Kind.SEATED, Kind.TOV, Kind.WHISPER:
			var tor: Node3D = parts.get("torso")
			if tor:
				tor.rotation.x = -(0.08 + sin(t * 1.7 + sway_phase) * sway_amount)
			if kind == Kind.WHISPER and rig:
				rig.position.y = 0.15 * sin(t * 3.0)
		_:
			pass
	if halo:
		halo.rotation.y += delta * 1.5
		halo.position.y = 2.3 * body_scale + sin(t * 2.0) * 0.05


func goto(pos: Vector3) -> void:
	goal = pos
	has_goal = true
	arrived = false


func think(_delta: float) -> void:
	if not has_goal:
		desired_move = Vector3.ZERO
		if look_at_pos != Vector3.ZERO:
			var to := look_at_pos - global_position
			to.y = 0.0
			if to.length() > 0.1:
				face_dir = to.normalized()
		return
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.35:
		desired_move = Vector3.ZERO
		has_goal = false
		arrived = true
		return
	desired_move = to.normalized()
	face_dir = desired_move
