extends Control
## Racing controls: a big steering wheel you turn with your thumb (or arrow buttons / tilt),
## GAS and BRAKE pedals, a gear shifter (R N D, or R N 1-5 in manual) and a VIEW button.
## Setting key "race_controls": 0 wheel (default), 1 arrows, 2 tilt.

signal view_pressed

const NAMES := ["Steering wheel", "Arrow buttons", "Tilt phone"]
const LOCK := 2.1

var mode := 0
var wheel_ang := 0.0
var steer := 0.0
var gas := 0.0
var brake := 0.0
var gear_sel := 1
var auto := true
var enabled := true
var speed_kmh := 0.0
var gear_txt := "D1"
var rpm := 0.0
var touches: Dictionary = {}
var held := {}
var tilt_base := Vector3.ZERO
var tilt_ok := false
var zones: Dictionary = {}
var strip := Rect2()
var auto_rect := Rect2()
## test bot overrides
var bot_on := false
var bot_steer := 0.0
var bot_gas := 0.0
var bot_brake := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func set_mode(m: int) -> void:
	mode = clampi(m, 0, 2)
	touches.clear()
	held.clear()
	tilt_ok = false
	wheel_ang = 0.0
	_layout()


func clear() -> void:
	touches.clear()
	held.clear()
	gas = 0.0
	brake = 0.0


func _layout() -> void:
	var s := get_viewport_rect().size
	zones = {
		"wheel": {"p": Vector2(150.0, s.y - 152.0), "r": 112.0},
		"gas": {"p": Vector2(s.x - 105.0, s.y - 125.0), "r": 68.0},
		"brake": {"p": Vector2(s.x - 252.0, s.y - 98.0), "r": 54.0},
		"view": {"p": Vector2(s.x - 58.0, 244.0), "r": 28.0},
		"left": {"p": Vector2(110.0, s.y - 112.0), "r": 66.0},
		"right": {"p": Vector2(272.0, s.y - 112.0), "r": 66.0},
	}
	strip = Rect2(Vector2(s.x - 384.0, s.y - 290.0), Vector2(70.0, 226.0))
	auto_rect = Rect2(Vector2(s.x - 398.0, s.y - 324.0), Vector2(98.0, 28.0))
	queue_redraw()


func _slots() -> Array:
	if auto:
		return [[1, "D"], [0, "N"], [-1, "R"]]
	return [[5, "5"], [4, "4"], [3, "3"], [2, "2"], [1, "1"], [0, "N"], [-1, "R"]]


func _hit(p: Vector2, key: String, extra := 12.0) -> bool:
	var z: Dictionary = zones[key]
	return p.distance_to(z["p"]) <= float(z["r"]) + extra


func _role_at(p: Vector2) -> String:
	if _hit(p, "gas"):
		return "gas"
	if _hit(p, "brake"):
		return "brake"
	if _hit(p, "view", 8.0):
		return "view"
	if auto_rect.grow(6.0).has_point(p):
		return "auto"
	if strip.grow(10.0).has_point(p):
		return "shift"
	if mode == 0 and _hit(p, "wheel", 46.0):
		return "wheel"
	if mode == 1:
		if _hit(p, "left"):
			return "left"
		if _hit(p, "right"):
			return "right"
	return ""


func _pick_gear(p: Vector2) -> void:
	var sl := _slots()
	var h := strip.size.y / sl.size()
	var k := clampi(int((p.y - strip.position.y) / h), 0, sl.size() - 1)
	gear_sel = int(sl[k][0])


func shift_step(dir: int) -> void:
	var sl := _slots()
	var cur := 0
	for k in sl.size():
		if int(sl[k][0]) == gear_sel:
			cur = k
	cur = clampi(cur - dir, 0, sl.size() - 1)
	gear_sel = int(sl[cur][0])


func toggle_auto() -> void:
	auto = not auto
	if auto and gear_sel > 1:
		gear_sel = 1
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not enabled:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_E:
				shift_step(1)
			elif k.keycode == KEY_Q:
				shift_step(-1)
			elif k.keycode == KEY_R:
				gear_sel = -1
			elif k.keycode == KEY_F:
				gear_sel = 1
			elif k.keycode == KEY_V:
				view_pressed.emit()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var role := _role_at(t.position)
			if role == "":
				return
			if role == "view":
				view_pressed.emit()
				return
			if role == "auto":
				toggle_auto()
				return
			if role == "shift":
				_pick_gear(t.position)
				touches[t.index] = {"role": "shift"}
				return
			if role == "wheel":
				var c: Vector2 = zones["wheel"]["p"]
				touches[t.index] = {"role": "wheel", "a0": (t.position - c).angle(), "w0": wheel_ang}
				return
			touches[t.index] = {"role": role}
			held[role] = true
		else:
			if touches.has(t.index):
				var role2: String = touches[t.index]["role"]
				if role2 in ["gas", "brake", "left", "right"]:
					held.erase(role2)
				touches.erase(t.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if touches.has(d.index):
			var info: Dictionary = touches[d.index]
			if info["role"] == "wheel":
				var c2: Vector2 = zones["wheel"]["p"]
				if d.position.distance_to(c2) > 18.0:
					var a := (d.position - c2).angle()
					wheel_ang = clampf(float(info["w0"]) + angle_difference(float(info["a0"]), a), -LOCK, LOCK)
			elif info["role"] == "shift":
				_pick_gear(d.position)
		queue_redraw()


## Call once per physics frame. Returns {"steer","gas","brake","gear","auto"}.
func poll(delta: float) -> Dictionary:
	if bot_on:
		steer = bot_steer
		gas = bot_gas
		brake = bot_brake
		return {"steer": steer, "gas": gas, "brake": brake, "gear": gear_sel, "auto": auto}
	var want := 0.0
	var g := 1.0 if held.get("gas", false) else 0.0
	var b := 1.0 if held.get("brake", false) else 0.0
	var holding_wheel := false
	for k in touches:
		if touches[k]["role"] == "wheel":
			holding_wheel = true
	match mode:
		0:
			if not holding_wheel:
				wheel_ang = move_toward(wheel_ang, 0.0, 7.0 * delta)
			var x := wheel_ang / LOCK
			want = signf(x) * pow(absf(x), 0.9)
		1:
			want = (1.0 if held.get("right", false) else 0.0) - (1.0 if held.get("left", false) else 0.0)
		2:
			var a := Input.get_accelerometer()
			if a != Vector3.ZERO:
				if not tilt_ok:
					tilt_base = a
					tilt_ok = true
				want = clampf(-(a - tilt_base).x / 3.2, -1.0, 1.0)
				if absf(want) < 0.08:
					want = 0.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		g = 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		b = 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		want = -1.0
		wheel_ang = move_toward(wheel_ang, -LOCK, 6.0 * delta)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		want = 1.0
		wheel_ang = move_toward(wheel_ang, LOCK, 6.0 * delta)
	var rate := 9.0 if mode != 1 else 4.8
	steer = move_toward(steer, want, rate * delta)
	gas = g
	brake = b
	return {"steer": steer, "gas": gas, "brake": brake, "gear": gear_sel, "auto": auto}


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _pedal(p: Vector2, r: float, col: Color, label: String, on: bool, font: Font) -> void:
	draw_circle(p, r, Color(col.r, col.g, col.b, 0.58 if on else 0.28))
	draw_arc(p, r, 0, TAU, 40, Color(col.r, col.g, col.b, 0.95), 3.5)
	draw_string(font, p + Vector2(-r, 7), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, Color(1, 1, 1, 0.97))


func _arrow(p: Vector2, r: float, dir: float, on: bool) -> void:
	draw_circle(p, r, Color(1, 1, 1, 0.42 if on else 0.18))
	draw_arc(p, r, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.5)
	draw_colored_polygon(PackedVector2Array([p + Vector2(dir * 26, 0), p + Vector2(-dir * 14, -24), p + Vector2(-dir * 14, 24)]), Color(1, 1, 1, 0.85))


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	var s := get_viewport_rect().size
	_pedal(zones["gas"]["p"], zones["gas"]["r"], Color("#4cd964"), "GAS", gas > 0.5, font)
	_pedal(zones["brake"]["p"], zones["brake"]["r"], Color("#ff4d4d"), "BRAKE", brake > 0.5, font)
	var vz: Dictionary = zones["view"]
	draw_circle(vz["p"], vz["r"], Color(0, 0, 0, 0.4))
	draw_arc(vz["p"], vz["r"], 0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
	draw_string(font, vz["p"] + Vector2(-vz["r"], 5), "VIEW", HORIZONTAL_ALIGNMENT_CENTER, vz["r"] * 2.0, 12, Color.WHITE)
	# steering
	if mode == 0:
		_draw_wheel(zones["wheel"]["p"], zones["wheel"]["r"], font)
	elif mode == 1:
		_arrow(zones["left"]["p"], zones["left"]["r"], -1.0, held.get("left", false))
		_arrow(zones["right"]["p"], zones["right"]["r"], 1.0, held.get("right", false))
	else:
		var c: Vector2 = Vector2(210.0, s.y - 100.0)
		draw_rect(Rect2(c + Vector2(-110, -6), Vector2(220, 12)), Color(1, 1, 1, 0.16), true)
		draw_circle(c + Vector2(steer * 110.0, 0), 14.0, Color("#ffd34a"))
		draw_string(font, c + Vector2(-110, -26), "TILT PHONE TO STEER", HORIZONTAL_ALIGNMENT_CENTER, 220, 14, Color(1, 1, 1, 0.7))
	# gear shifter
	draw_rect(strip, Color(0, 0, 0, 0.3), true)
	draw_rect(strip, Color(1, 1, 1, 0.4), false, 2.0)
	var sl := _slots()
	var sh := strip.size.y / sl.size()
	for k in sl.size():
		var cy := strip.position.y + sh * (k + 0.5)
		var sel := int(sl[k][0]) == gear_sel
		var lbl: String = sl[k][1]
		var col := Color(1, 1, 1, 0.55)
		if lbl == "R":
			col = Color("#ff8a7a")
		if sel:
			draw_circle(Vector2(strip.position.x + strip.size.x * 0.5, cy), minf(sh * 0.46, 34.0), Color("#ffd34a"))
			col = Color("#1a1a1a")
		var fs := 26 if auto else 20
		draw_string(font, Vector2(strip.position.x, cy + fs * 0.35), lbl, HORIZONTAL_ALIGNMENT_CENTER, strip.size.x, fs, col)
	draw_rect(auto_rect, Color(0, 0, 0, 0.5), true)
	draw_rect(auto_rect, Color("#ffd34a") if auto else Color("#7fd0ff"), false, 2.0)
	draw_string(font, auto_rect.position + Vector2(0, 21), "AUTO" if auto else "MANUAL", HORIZONTAL_ALIGNMENT_CENTER, auto_rect.size.x, 14, Color.WHITE)
	# speedometer with revs
	var sp := Vector2(s.x * 0.5 - 30.0, s.y - 72.0)
	draw_circle(sp, 54.0, Color(0, 0, 0, 0.5))
	draw_arc(sp, 54.0, 0, TAU, 40, Color(1, 1, 1, 0.45), 2.0)
	var frac := clampf(speed_kmh / 140.0, 0.0, 1.0)
	draw_arc(sp, 47.0, PI * 0.75, PI * 0.75 + frac * PI * 1.5, 34, Color("#7dffb0") if frac < 0.8 else Color("#ff8a5a"), 5.0)
	draw_arc(sp, 39.0, PI * 0.75, PI * 0.75 + clampf(rpm, 0.0, 1.0) * PI * 1.5, 30, Color("#ffd34a") if rpm < 0.9 else Color("#ff4d4d"), 3.0)
	draw_string(font, sp + Vector2(-50, 4), str(int(speed_kmh)), HORIZONTAL_ALIGNMENT_CENTER, 100, 28, Color.WHITE)
	draw_string(font, sp + Vector2(-50, 24), "km/h  " + gear_txt, HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color(1, 1, 1, 0.8))


func _draw_wheel(c: Vector2, r: float, font: Font) -> void:
	draw_circle(c, r + 6.0, Color(0, 0, 0, 0.22))
	draw_set_transform(c, wheel_ang, Vector2.ONE)
	var rim := Color(0.1, 0.1, 0.12, 0.88)
	draw_arc(Vector2.ZERO, r - 9.0, 0.0, TAU, 56, rim, 18.0)
	draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 56, Color(1, 1, 1, 0.35), 2.0)
	draw_arc(Vector2.ZERO, r - 17.0, 0.0, TAU, 56, Color(1, 1, 1, 0.22), 2.0)
	draw_line(Vector2(-r + 12.0, 0), Vector2(r - 12.0, 0), rim, 14.0)
	draw_line(Vector2(0, 0), Vector2(0, r - 12.0), rim, 14.0)
	draw_circle(Vector2.ZERO, 24.0, Color(0.16, 0.17, 0.2, 0.95))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 28, Color("#ffd34a"), 2.5)
	draw_string(font, Vector2(-24, 7), "S", HORIZONTAL_ALIGNMENT_CENTER, 48, 20, Color("#ffd34a"))
	draw_rect(Rect2(-6, -r + 2.0, 12, 20), Color("#ffd34a"), true)
	for k in 8:
		var a := -PI * 0.5 + (k + 0.5) * TAU / 8.0 - 0.0
		draw_circle(Vector2(cos(a), sin(a)) * (r - 9.0), 2.2, Color(1, 1, 1, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(font, c + Vector2(-r, r + 22.0), "DRAG THE WHEEL", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 13, Color(1, 1, 1, 0.55))
