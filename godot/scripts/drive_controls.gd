extends Control
## In-vehicle controls: gas and brake pedals plus steering by tilt, slide bar, arrow buttons or D-pad.
## Chosen in Settings (Profile setting "drive_controls"): 0 tilt, 1 slide, 2 arrows, 3 D-pad.

signal view_pressed

const NAMES := ["Tilt", "Slide", "Arrows", "D-pad"]
const MX := 76.0
const MY := 64.0

var scheme := 0
var steer := 0.0 ## smoothed output -1..1 (+ = right)
var gas := 0.0
var brake := 0.0
var speed_kmh := 0.0
var gear := "D"
var touches: Dictionary = {}
var slide_val := 0.0
var held := {} ## "left","right","up","down","gas","brake"
var tilt_base := Vector3.ZERO
var tilt_ok := false
## test bot overrides
var bot_on := false
var bot_steer := 0.0
var bot_gas := 0.0
var bot_brake := 0.0
var zones: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func set_scheme(i: int) -> void:
	scheme = clampi(i, 0, 3)
	tilt_ok = false
	touches.clear()
	held.clear()
	slide_val = 0.0
	_layout()


func exclusion_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var s := get_viewport_rect().size
	out.append(Rect2(0, s.y * 0.3, s.x * 0.45, s.y * 0.7))
	for k in ["gas", "brake", "view"]:
		var z: Dictionary = zones[k]
		var r: float = z["r"] + 8.0
		out.append(Rect2(z["p"] - Vector2(r, r), Vector2(r, r) * 2.0))
	return out


func _layout() -> void:
	var s := get_viewport_rect().size
	zones = {
		"gas": {"p": Vector2(s.x - 140.0, s.y - 134.0), "r": 56.0},
		"brake": {"p": Vector2(s.x - 276.0, s.y - 108.0), "r": 46.0},
		"view": {"p": Vector2(s.x - 58.0, 244.0), "r": 28.0},
		"left": {"p": Vector2(MX + 56.0, s.y - MY - 62.0), "r": 54.0},
		"right": {"p": Vector2(MX + 196.0, s.y - MY - 62.0), "r": 54.0},
		"slide": {"p": Vector2(MX + 150.0, s.y - MY - 62.0), "r": 150.0},
		"dpad": {"p": Vector2(MX + 62.0, s.y - MY - 62.0), "r": 46.0},
	}
	queue_redraw()


func _hit(p: Vector2, key: String) -> bool:
	var z: Dictionary = zones[key]
	return p.distance_to(z["p"]) <= float(z["r"]) + 10.0


func _role_at(p: Vector2) -> String:
	for k in ["gas", "brake", "view"]:
		if _hit(p, k):
			return k
	match scheme:
		1:
			var z: Dictionary = zones["slide"]
			if absf(p.x - z["p"].x) <= float(z["r"]) + 14.0 and absf(p.y - z["p"].y) <= 60.0:
				return "slide"
		2:
			if _hit(p, "left"):
				return "left"
			if _hit(p, "right"):
				return "right"
		3:
			var c: Vector2 = zones["dpad"]["p"]
			var off := p - c
			if absf(off.x) < 140.0 and absf(off.y) < 140.0 and off.length() > 14.0:
				if absf(off.x) > absf(off.y):
					return "right" if off.x > 0.0 else "left"
				return "down" if off.y > 0.0 else "up"
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
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
			touches[t.index] = role
			_apply(t.index, role, t.position)
		else:
			if touches.has(t.index):
				var role: String = touches[t.index]
				if role == "slide":
					slide_val = 0.0
				held.erase(role)
				touches.erase(t.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if touches.has(d.index):
			var role: String = touches[d.index]
			if role == "slide":
				_apply(d.index, role, d.position)
			elif scheme == 3 and role in ["left", "right", "up", "down"]:
				var nr := _role_at(d.position)
				if nr in ["left", "right", "up", "down"] and nr != role:
					held.erase(role)
					touches[d.index] = nr
					held[nr] = true
		queue_redraw()


func _apply(_idx: int, role: String, p: Vector2) -> void:
	if role == "slide":
		var z: Dictionary = zones["slide"]
		slide_val = clampf((p.x - z["p"].x) / float(z["r"]), -1.0, 1.0)
	else:
		held[role] = true


## Call once per physics frame. Returns {"steer","gas","brake"}.
func poll(delta: float) -> Dictionary:
	if bot_on:
		steer = bot_steer
		gas = bot_gas
		brake = bot_brake
		return {"steer": steer, "gas": gas, "brake": brake}
	var want := 0.0
	var g := 0.0
	var b := 0.0
	if held.get("gas", false):
		g = 1.0
	if held.get("brake", false):
		b = 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		g = 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		b = 1.0
	var kl := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var kr := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	match scheme:
		0:
			var a := Input.get_accelerometer()
			if a != Vector3.ZERO:
				if not tilt_ok:
					tilt_base = a
					tilt_ok = true
				var dx := (a - tilt_base).x
				want = clampf(-dx / 3.2, -1.0, 1.0)
				if absf(want) < 0.08:
					want = 0.0
		1:
			want = slide_val
		2:
			want = (1.0 if held.get("right", false) else 0.0) - (1.0 if held.get("left", false) else 0.0)
		3:
			want = (1.0 if held.get("right", false) else 0.0) - (1.0 if held.get("left", false) else 0.0)
			if held.get("up", false):
				g = 1.0
			if held.get("down", false):
				b = 1.0
	if kl:
		want = -1.0
	if kr:
		want = 1.0
	var rate := 7.0 if scheme == 0 or scheme == 1 else 4.5
	steer = move_toward(steer, want, rate * delta)
	gas = g
	brake = b
	return {"steer": steer, "gas": gas, "brake": brake}


func _pedal(p: Vector2, r: float, col: Color, label: String, on: bool, font: Font) -> void:
	draw_circle(p, r, Color(col.r, col.g, col.b, 0.55 if on else 0.26))
	draw_arc(p, r, 0, TAU, 36, Color(col.r, col.g, col.b, 0.95), 3.0)
	draw_string(font, p + Vector2(-r, 6), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 17, Color(1, 1, 1, 0.97))


func _arrow(p: Vector2, r: float, dir: int, on: bool) -> void:
	draw_circle(p, r, Color(1, 1, 1, 0.42 if on else 0.18))
	draw_arc(p, r, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([p + Vector2(d * 22, 0), p + Vector2(-d * 12, -20), p + Vector2(-d * 12, 20)]), Color(1, 1, 1, 0.85))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


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
	match scheme:
		0:
			var c: Vector2 = zones["slide"]["p"]
			# tilt meter: bar + marker showing the current steering
			draw_rect(Rect2(c + Vector2(-110, -6), Vector2(220, 12)), Color(1, 1, 1, 0.16), true)
			draw_rect(Rect2(c + Vector2(-2, -14), Vector2(4, 28)), Color(1, 1, 1, 0.5), true)
			draw_circle(c + Vector2(steer * 110.0, 0), 13.0, Color("#ffd34a"))
			draw_string(font, c + Vector2(-110, -26), "TILT PHONE TO STEER", HORIZONTAL_ALIGNMENT_CENTER, 220, 14, Color(1, 1, 1, 0.7))
		1:
			var z: Dictionary = zones["slide"]
			var c2: Vector2 = z["p"]
			var hw: float = z["r"]
			draw_rect(Rect2(c2 + Vector2(-hw, -26), Vector2(hw * 2.0, 52)), Color(1, 1, 1, 0.14), true)
			draw_rect(Rect2(c2 + Vector2(-hw, -26), Vector2(hw * 2.0, 52)), Color(1, 1, 1, 0.4), false, 2.0)
			draw_rect(Rect2(c2 + Vector2(-2, -26), Vector2(4, 52)), Color(1, 1, 1, 0.35), true)
			draw_circle(c2 + Vector2(slide_val * (hw - 24.0), 0), 24.0, Color(1, 1, 1, 0.65))
			draw_string(font, c2 + Vector2(-hw, -36), "SLIDE TO STEER", HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, 14, Color(1, 1, 1, 0.7))
		2:
			_arrow(zones["left"]["p"], zones["left"]["r"], -1, held.get("left", false))
			_arrow(zones["right"]["p"], zones["right"]["r"], 1, held.get("right", false))
		3:
			var c3: Vector2 = zones["dpad"]["p"]
			for k in [["up", Vector2.UP], ["down", Vector2.DOWN], ["left", Vector2.LEFT], ["right", Vector2.RIGHT]]:
				var cc: Vector2 = c3 + (k[1] as Vector2) * 46.0
				draw_rect(Rect2(cc - Vector2(30, 30), Vector2(60, 60)), Color(1, 1, 1, 0.45 if held.get(k[0], false) else 0.18), true)
			draw_circle(c3, 12.0, Color(1, 1, 1, 0.2))
	# speedometer
	var sp := Vector2(s.x * 0.5, s.y - 62.0)
	draw_circle(sp, 40.0, Color(0, 0, 0, 0.45))
	draw_arc(sp, 40.0, 0, TAU, 36, Color(1, 1, 1, 0.45), 2.0)
	var frac := clampf(speed_kmh / 90.0, 0.0, 1.0)
	draw_arc(sp, 34.0, PI * 0.75, PI * 0.75 + frac * PI * 1.5, 30, Color("#7dffb0") if frac < 0.8 else Color("#ff8a5a"), 5.0)
	draw_string(font, sp + Vector2(-40, 6), str(int(speed_kmh)), HORIZONTAL_ALIGNMENT_CENTER, 80, 22, Color.WHITE)
	draw_string(font, sp + Vector2(-40, 24), "km/h  " + gear, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 1, 1, 0.7))
