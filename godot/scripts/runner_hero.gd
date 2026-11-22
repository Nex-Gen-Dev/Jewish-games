extends Fighter
## The runner's character: same body as the fighter, driven by hand
## (no physics): running, jumping, sliding.

var run_speed := 10.0
var airborne := false
var sliding := false
var caught := false ## being carried away
var grabbing := false ## chaser reaching / carrying


func _init() -> void:
	team = 0
	look["skin"] = Profile.get_color("character", "skin", look["skin"])
	look["shirt"] = Profile.get_color("character", "shirt", look["shirt"])
	look["pants"] = Profile.get_color("character", "pants", look["pants"])
	look["hair"] = Profile.get_color("character", "hair", look["hair"])
	look["kippah"] = Profile.get_flag("character", "kippah", true)
	look["kippah_color"] = Profile.get_color("character", "kippah_color", look["kippah_color"])


func make_chaser() -> void:
	look["skin"] = Color("#b01818")
	look["shirt"] = Color("#2a0f33")
	look["pants"] = Color("#1a0a22")
	look["hair"] = Color("#1a0a22")
	look["kippah"] = false
	look["horns"] = true
	look["tail"] = true
	look["eye"] = Color("#ffe14a")
	look["scale"] = 1.3


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	remove_from_group("fighters")


func _physics_process(delta: float) -> void:
	anim_time += delta
	var k := 1.0 - exp(-22.0 * delta)
	walk_phase += run_speed * delta * 1.25
	var s := sin(walk_phase)
	var a_l := s * 1.4
	var a_r := -s * 1.4
	var l_l := -s * 1.2
	var l_r := s * 1.2
	var t_x := 0.28
	var bob := absf(s) * 0.07
	if airborne:
		a_l = 2.4
		a_r = 2.4
		l_l = 0.7
		l_r = -0.5
		t_x = 0.1
		bob = 0.0
	if sliding:
		a_l = 1.9
		a_r = 1.9
		l_l = -1.3
		l_r = -1.3
		t_x = 1.15
		bob = -0.42
	if caught:
		a_l = 2.9
		a_r = 2.6
		l_l = 0.5 + sin(anim_time * 14.0) * 0.5
		l_r = 0.5 - sin(anim_time * 14.0) * 0.5
		t_x = -0.3
		bob = 0.0
	elif grabbing:
		a_l = 1.5
		a_r = 1.5 + sin(anim_time * 10.0) * 0.2
		t_x = 0.45
	_rot("torso", Vector3(-t_x, 0, 0), k)
	_rot("arm_l", Vector3(a_l, 0, 0.06), k)
	_rot("arm_r", Vector3(a_r, 0, -0.06), k)
	_rot("leg_l", Vector3(l_l, 0, 0), k)
	_rot("leg_r", Vector3(l_r, 0, 0), k)
	var hips: Node3D = parts.get("hips")
	if hips:
		hips.position.y = lerpf(hips.position.y, 0.9 + bob, k)
