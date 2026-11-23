extends RefCounted
## One racer (player or computer): arcade physics for a car or a motor boat with real gears
## (R, N, D or 1-5), drifting, jumps off ramps, wall bumps, plus a simple AI driver.

const Vehicles := preload("res://scripts/vehicles.gd")
const TrackScript := preload("res://scripts/race_track.gd")
const G := 25.0
const STICK := 0.11
const GEAR_TOP := [0.2, 0.38, 0.57, 0.78, 1.0]
const GEAR_PULL := [2.1, 1.45, 1.05, 0.8, 0.62]

var boat := false
var is_player := false
var title := ""
var color := Color.RED
var node: Node3D
var parts: Dictionary = {}
var driver: Node3D
# physics state
var pos := Vector3.ZERO
var yaw := 0.0
var vel := Vector3.ZERO
var vy := 0.0
var pitch := 0.0
var roll := 0.0
var grounded := true
var air_t := 0.0
var boost_t := 0.0
var impact := 0.0
var landed := 0.0 ## set to the landing speed for one frame after a hard landing
var jumps := 0
var respawned := false
# inputs
var inp_steer := 0.0
var inp_gas := 0.0
var inp_brake := 0.0
var gear_sel := 1 ## -1 R, 0 N, 1 = D (auto) or the chosen gear 1..5
var auto := true
var gear := 1
var rpm := 0.0
var braking := false
# tuning
var top := 34.0
var acc := 5.6
var grip := 6.5
var steer_lo := 1.9
var steer_hi := 0.75
var brake_dec := 28.0
var rev_max := 9.0
var drag := 0.0004
var roll_res := 0.45
var a_lat := 15.0
var skill := 1.0
# race state
var idx := 0
var prev_idx := 0
var lat := 0.0
var lap := 0
var progress := 0.0
var place := 1
var finished := false
var finish_time := 0.0
var safe_idx := 0
var stuck_t := 0.0
var lane := 0.0
var base_lane := 0.0
var seed_off := 0.0
var _vf := 0.0


func setup(is_boat: bool, col: Color, name_: String, player: bool) -> void:
	boat = is_boat
	color = col
	title = name_
	is_player = player
	if boat:
		top = 31.0
		acc = 5.0
		grip = 2.3
		steer_lo = 1.55
		steer_hi = 0.72
		brake_dec = 20.0
		rev_max = 8.0
		drag = 0.0009
		roll_res = 0.5
		a_lat = 9.5
		parts = Vehicles.make_boat()
		_recolor(parts["root"], col)
	else:
		parts = Vehicles.make_car(col)
	node = parts["root"]
	_add_driver()


func _recolor(n: Node, col: Color) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var mt := mi.material_override as StandardMaterial3D
			if mt != null and mt.albedo_color.is_equal_approx(Color("#1f5fa8")):
				mi.material_override = Vehicles.m(col, 0.4)
		_recolor(c, col)


func _add_driver() -> void:
	var skin := Vehicles.m(Color("#e8c19a"), 0.8)
	var coat := Vehicles.m(Color("#1b1d22") if is_player else color.darkened(0.3), 0.8)
	var hatc := Vehicles.m(Color("#0e0e10"), 0.7)
	driver = Node3D.new()
	if boat:
		driver.position = Vector3(-0.1, 0.0, 0.42)
		(parts["hull"] as Node3D).add_child(driver)
		Vehicles.box(driver, Vector3(0.5, 0.62, 0.3), Vector3(0, 0.98, 0), coat)
		Vehicles.sph(driver, 0.17, Vector3(0, 1.45, -0.02), skin)
		Vehicles.box(driver, Vector3(0.5, 0.05, 0.4), Vector3(0, 1.6, -0.02), hatc)
		Vehicles.box(driver, Vector3(0.32, 0.18, 0.3), Vector3(0, 1.7, -0.02), hatc)
		Vehicles.box(driver, Vector3(0.12, 0.12, 0.5), Vector3(-0.22, 1.02, -0.3), coat, Vector3(0.3, 0, 0))
		Vehicles.box(driver, Vector3(0.12, 0.12, 0.5), Vector3(0.22, 1.02, -0.3), coat, Vector3(0.3, 0, 0))
	else:
		driver.position = Vector3(-0.45, 0.0, 0.34)
		node.add_child(driver)
		Vehicles.box(driver, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.08, 0), coat)
		Vehicles.sph(driver, 0.17, Vector3(0, 1.56, -0.02), skin)
		Vehicles.box(driver, Vector3(0.46, 0.05, 0.38), Vector3(0, 1.69, -0.02), hatc)
		Vehicles.box(driver, Vector3(0.3, 0.16, 0.28), Vector3(0, 1.78, -0.02), hatc)
		Vehicles.box(driver, Vector3(0.12, 0.12, 0.5), Vector3(-0.2, 1.12, -0.32), coat, Vector3(0.3, 0, 0))
		Vehicles.box(driver, Vector3(0.12, 0.12, 0.5), Vector3(0.2, 1.12, -0.32), coat, Vector3(0.3, 0, 0))


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func fwd_speed() -> float:
	return _vf


func gear_text() -> String:
	if gear_sel < 0:
		return "R"
	if gear_sel == 0:
		return "N"
	return ("D" + str(gear)) if auto else str(gear)


func place_at(tr, i: int, lat_off: float, lap0: int) -> void:
	var p: Vector3 = tr.point(i, lat_off)
	pos = Vector3(p.x, tr.pos[_c(tr, i)].y + 0.05, p.z)
	yaw = tr.yaw_at(i)
	vel = Vector3.ZERO
	vy = 0.0
	idx = _c(tr, i)
	prev_idx = idx
	safe_idx = idx
	lap = lap0
	lane = lat_off
	base_lane = lat_off
	grounded = true
	air_t = 0.0
	_vf = 0.0
	progress = lap * tr.length + tr.dist[idx]


func _c(tr, i: int) -> int:
	return posmod(i, tr.n) if tr.closed else clampi(i, 0, tr.n - 1)


func respawn(tr) -> void:
	var i: int = safe_idx - 8
	if tr.closed and i < 0:
		lap -= 1
	i = _c(tr, i)
	var p: Vector3 = tr.point(i, clampf(lane, -3.0, 3.0))
	pos = Vector3(p.x, tr.pos[i].y + 0.4, p.z)
	yaw = tr.yaw_at(i)
	vel = Vector3.ZERO
	vy = 0.0
	idx = i
	prev_idx = i
	grounded = false
	air_t = 0.0
	stuck_t = 0.0
	boost_t = 0.0
	respawned = true


# ---------------------------------------------------------------- engine

func _engine(vf: float, top_eff: float) -> float:
	if gear_sel < 0:
		gear = 1
		rpm = clampf(-vf / rev_max, 0.0, 1.0)
		if inp_gas < 0.02:
			return 0.0
		if vf > 0.5:
			return -brake_dec * 0.5 * inp_gas
		return -acc * 0.9 * inp_gas * clampf(1.0 - (-vf / rev_max), 0.0, 1.0)
	if gear_sel == 0:
		rpm = 0.0
		return 0.0
	var v := maxf(vf, 0.0)
	if auto:
		while gear < 5 and v > GEAR_TOP[gear - 1] * top_eff * 0.86:
			gear += 1
		while gear > 1 and v < GEAR_TOP[gear - 2] * top_eff * 0.6:
			gear -= 1
	else:
		gear = clampi(gear_sel, 1, 5)
	var gt: float = GEAR_TOP[gear - 1] * top_eff
	rpm = clampf(v / gt, 0.0, 1.1)
	var a: float = acc * GEAR_PULL[gear - 1] * inp_gas
	var ratio := clampf(vf / gt, 0.0, 1.3)
	a *= clampf(1.0 - pow(ratio, 3.0), 0.0, 1.0)
	if not auto and vf < 0.2 * gt and gear >= 3:
		a *= 0.5 ## lugging the engine in a tall gear
	if boost_t > 0.0:
		a += 12.0
	if vf < -0.5:
		a += brake_dec * 0.5 * inp_gas ## rolling backwards: gas brakes first
	return a


func step(dt: float, tr, time: float) -> void:
	respawned = false
	landed = 0.0
	var f3 := forward()
	var vf := vel.dot(f3)
	var inf: Dictionary = tr.info(pos, idx)
	idx = inf["idx"]
	var surf: bool = inf["surf"]
	if grounded and surf and (int(inf["fl"]) & TrackScript.F_BOOST) != 0:
		boost_t = 1.3
	boost_t = maxf(boost_t - dt, 0.0)
	var top_eff := top * skill * (1.18 if boost_t > 0.0 else 1.0)
	braking = false
	if grounded:
		var a := _engine(vf, top_eff)
		if inp_gas < 0.02 and gear_sel >= 0 and absf(vf) > 0.3:
			a -= signf(vf) * (1.4 if gear_sel > 0 else 0.5)
		var res := 0.0
		if absf(vf) > 0.05:
			res = drag * vf * absf(vf) + roll_res * signf(vf)
		var nvf := vf + (a - res) * dt
		if inp_brake > 0.02:
			braking = true
			var bd := brake_dec * inp_brake * dt
			if vf > 0.0:
				nvf = maxf(0.0, nvf - bd)
			elif vf < 0.0:
				nvf = minf(0.0, nvf + bd)
		vel += f3 * (nvf - vf)
		var sr := lerpf(steer_lo, steer_hi, clampf(absf(nvf) / top, 0.0, 1.0))
		var gate := clampf(absf(nvf) / 2.5, 0.0, 1.0)
		yaw -= inp_steer * sr * gate * (1.0 if nvf >= -0.1 else -1.0) * dt
		var f4 := forward()
		var r4 := right()
		var vf2 := vel.dot(f4)
		var vs2 := vel.dot(r4)
		var vs3 := vs2 * exp(-grip * dt)
		vf2 -= signf(vf2) * absf(vs2 - vs3) * 0.1
		vel = f4 * vf2 + r4 * vs3
	else:
		yaw -= inp_steer * 0.3 * dt
		air_t += dt
		gear = maxi(gear, 1)
		rpm = lerpf(rpm, 0.2, dt * 3.0)
	_vf = vel.dot(forward())
	pos.x += vel.x * dt
	pos.z += vel.z * dt
	# vertical: ballistic, snap to the surface when we reach it
	vy -= G * dt
	var ny := pos.y + vy * dt
	var inf2: Dictionary = tr.info(pos, idx)
	var h2: float = inf2["y"]
	var s2: bool = inf2["surf"]
	if s2 and (ny <= h2 + 0.001 or (grounded and ny - h2 < STICK)):
		if not grounded:
			var imp := -vy
			if air_t > 0.4 and imp > 5.0:
				landed = imp
				impact = maxf(impact, imp * 0.25)
				if air_t > 0.6:
					jumps += 1
			if imp > 16.0:
				vel *= 0.9
			air_t = 0.0
		vy = clampf((h2 - pos.y) / dt, -45.0, 45.0)
		pos.y = h2
		grounded = true
	else:
		grounded = false
		pos.y = ny
	# walls
	var lim: float = float(inf2["w"]) * 0.5 - 1.15
	var rr: Vector3 = inf2["right"]
	var lt: float = inf2["lat"]
	if lt > lim or lt < -lim:
		var side := 1.0 if lt > 0.0 else -1.0
		pos -= rr * side * (absf(lt) - lim)
		var vn := vel.dot(rr) * side
		if vn > 0.0:
			vel -= rr * side * vn * 1.3
			vel *= 1.0 - clampf(vn / 24.0, 0.0, 0.45) * 0.6
			impact = maxf(impact, vn)
		lt = side * lim
	lat = lt
	# progress and laps
	var ni: int = inf2["idx"]
	if tr.closed:
		if prev_idx > tr.n * 3 / 4 and ni < tr.n / 4:
			lap += 1
		elif prev_idx < tr.n / 4 and ni > tr.n * 3 / 4:
			lap -= 1
	prev_idx = ni
	progress = lap * tr.length + tr.dist[ni] + float(inf2["t"]) * TrackScript.DS
	if grounded and s2:
		safe_idx = ni
	# recover from falling or being stuck
	if (not s2 and pos.y < h2 - 9.0) or pos.y < tr.y_ground + 1.5:
		respawn(tr)
	if absf(_vf) < 1.5 and (inp_gas > 0.5 or not is_player):
		stuck_t += dt
	else:
		stuck_t = maxf(stuck_t - dt * 2.0, 0.0)
	if stuck_t > (6.0 if is_player else 3.5):
		respawn(tr)
	_visual(dt, time)


func _visual(dt: float, time: float) -> void:
	var sp := absf(_vf)
	var tp := atan2(vy, maxf(sp, 4.0)) * (1.0 if _vf >= 0.0 else -1.0)
	if grounded:
		tp = clampf(tp, -0.6, 0.6) + clampf(inp_gas - inp_brake, -1.0, 1.0) * 0.012 * minf(sp, 10.0)
	else:
		tp = clampf(tp, -0.7, 0.7)
	pitch = lerpf(pitch, tp, minf(dt * 7.0, 1.0))
	var k := clampf(sp / top, 0.0, 1.0)
	var tr_roll := (-inp_steer if boat else inp_steer) * 0.07 * k
	roll = lerpf(roll, tr_roll, minf(dt * 5.0, 1.0))
	node.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	node.position = pos + Vector3(0, -0.12 if boat else 0.0, 0)
	if boat:
		Vehicles.update_boat(parts, _vf, inp_steer, time, dt)
	else:
		Vehicles.update_car(parts, _vf, inp_steer, braking, dt)


# ---------------------------------------------------------------- computer driver

func ai_drive(dt: float, tr, time: float, rubber: float, others: Array) -> void:
	var f3 := forward()
	var r3 := right()
	var vf := vel.dot(f3)
	# keep clear of other racers
	var pushed := false
	for o in others:
		if o == self:
			continue
		var rel: Vector3 = o.pos - pos
		var ahead := rel.dot(f3)
		var side := rel.dot(r3)
		if ahead > 0.0 and ahead < 18.0 and absf(side) < 3.6 and absf(o.pos.y - pos.y) < 3.0:
			lane += (-1.0 if side > 0.0 else 1.0) * 7.0 * dt
			pushed = true
	if not pushed:
		lane = move_toward(lane, base_lane, 2.0 * dt)
	var half: float = tr.wid[idx] * 0.5 - 6.0
	lane = clampf(lane, -half, half)
	var look := 10.0 + absf(vf) * 0.6
	var ti := idx + int(look / TrackScript.DS)
	var target: Vector3 = tr.point(ti, lane)
	var to := target - pos
	var want := atan2(-to.x, -to.z)
	var err := angle_difference(yaw, want)
	inp_steer = clampf(-err * 2.4 + sin(time * 1.3 + seed_off) * 0.03, -1.0, 1.0)
	var vmax := top * skill * (1.0 + rubber)
	var kmax: float = tr.max_curv_ahead(idx, 18.0 + maxf(vf, 0.0) * 1.3)
	var vc := sqrt(a_lat / maxf(kmax, 0.0008))
	var vt := minf(vmax, vc)
	var fa: int = tr.flags_ahead(idx, 40.0)
	if (fa & TrackScript.F_GAP) != 0:
		vt = vmax
		lane = move_toward(lane, 0.0, 6.0 * dt)
	gear_sel = 1
	auto = true
	if vf < vt:
		inp_gas = 1.0
		inp_brake = 0.0
	else:
		inp_gas = 0.0
		inp_brake = clampf((vf - vt - 1.5) / 5.0, 0.0, 1.0)
	if not grounded:
		inp_steer = 0.0
