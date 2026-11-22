class_name TouchControls
extends Control
## On-screen controls that adapt to portrait and landscape.
## Modes: floating joystick, fixed D-pad, or tilt (accelerometer).
## Right side of the screen: drag anywhere to look around.

enum Mode { STICK, DPAD, TILT }

const BTN_R := 38.0
const STICK_R := 62.0
## Keep controls away from the screen edges: Android's swipe-home / back /
## app-switch gestures live there and used to yank players out of the game.
const MARGIN_X := 76.0
const MARGIN_Y := 64.0

var mode: Mode = Mode.STICK
var enabled := true
var active_touches: Dictionary = {} ## touch index -> role string
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var stick_value := Vector2.ZERO
var dpad_value := Vector2.ZERO
var look_accum := Vector2.ZERO
var pressed_actions: Dictionary = {}
var held_buttons: Dictionary = {}
var tilt_base := Vector3.ZERO
var tilt_calibrated := false
var exclude_rects: Array[Rect2] = []

## Used by the self-test bot.
var bot_move := Vector2.ZERO

var has_gun := false
var has_bomb := false
var act_label := ""
var act_progress := 0.0
var fight_buttons := true ## false hides punch/kick (shul)

var buttons := {
	"punch": {"label": "PUNCH", "color": Color("#ff9d3d"), "pos": Vector2.ZERO, "r": 38.0},
	"kick": {"label": "KICK", "color": Color("#ff5b5b"), "pos": Vector2.ZERO, "r": 38.0},
	"jump": {"label": "JUMP", "color": Color("#5bd1ff"), "pos": Vector2.ZERO, "r": 38.0},
	"dodge": {"label": "DODGE", "color": Color("#9d7bff"), "pos": Vector2.ZERO, "r": 38.0},
	"shoot": {"label": "SHOOT", "color": Color("#4ef0c8"), "pos": Vector2.ZERO, "r": 38.0},
	"bomb": {"label": "BOMB", "color": Color("#ff4a2a"), "pos": Vector2.ZERO, "r": 44.0},
	"act": {"label": "", "color": Color("#ffd34a"), "pos": Vector2.ZERO, "r": 46.0},
}
var stick_home := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	stick_home = Vector2(MARGIN_X + STICK_R, s.y - MARGIN_Y - STICK_R)
	var c := Vector2(s.x - MARGIN_X - 68, s.y - MARGIN_Y - 94)
	buttons["kick"]["pos"] = c + Vector2(30, 56)
	buttons["punch"]["pos"] = c + Vector2(-50, 44)
	buttons["jump"]["pos"] = c + Vector2(46, -24)
	buttons["dodge"]["pos"] = c + Vector2(-34, -36)
	buttons["shoot"]["pos"] = c + Vector2(-118, 4)
	buttons["act"]["pos"] = c + Vector2(-2, -124)
	buttons["bomb"]["pos"] = c + Vector2(-100, -92)
	queue_redraw()


func _button_visible(id: String) -> bool:
	match id:
		"shoot":
			return has_gun and fight_buttons
		"bomb":
			return has_bomb
		"act":
			return act_label != ""
		"punch", "kick":
			return fight_buttons
	return true


func set_act(label: String, progress := 0.0) -> void:
	if label != act_label or absf(progress - act_progress) > 0.01:
		act_label = label
		act_progress = progress
		queue_redraw()


func is_held(action: String) -> bool:
	return held_buttons.get(action, false) or (action == "act" and Input.is_key_pressed(KEY_E))


func set_mode(m: Mode) -> void:
	mode = m
	stick_value = Vector2.ZERO
	dpad_value = Vector2.ZERO
	tilt_calibrated = false
	queue_redraw()


func cycle_mode() -> String:
	set_mode((mode + 1) % 3 as Mode)
	return ["Joystick", "D-pad", "Tilt"][mode]


func get_move() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	if bot_move != Vector2.ZERO:
		return bot_move
	match mode:
		Mode.STICK:
			return stick_value
		Mode.DPAD:
			return dpad_value
		Mode.TILT:
			return _tilt_vector()
	return Vector2.ZERO


func _tilt_vector() -> Vector2:
	var a := Input.get_accelerometer()
	if a == Vector3.ZERO:
		return Vector2.ZERO
	if not tilt_calibrated:
		tilt_base = a
		tilt_calibrated = true
	var d := a - tilt_base
	var v := Vector2(-d.x, d.y) / 3.5 ## tilt right = move right, tilt top away = forward
	var dead := 0.12
	if v.length() < dead:
		return Vector2.ZERO
	return v.limit_length(1.0)


func take_look() -> Vector2:
	var v := look_accum
	look_accum = Vector2.ZERO
	return v


## True once per press.
func consume(action: String) -> bool:
	if pressed_actions.get(action, false):
		pressed_actions[action] = false
		return true
	return false


func press(action: String) -> void:
	pressed_actions[action] = true


func clear() -> void:
	active_touches.clear()
	held_buttons.clear()
	pressed_actions.clear()
	stick_value = Vector2.ZERO
	dpad_value = Vector2.ZERO
	queue_redraw()


# ---------------------------------------------------------------- input

func _button_at(p: Vector2) -> String:
	for id in ["bomb", "act", "shoot", "kick", "punch", "jump", "dodge"]:
		if not _button_visible(id):
			continue
		if p.distance_to(buttons[id]["pos"]) <= float(buttons[id]["r"]) + 10.0:
			return id
	return ""


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var s := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			for r in exclude_rects:
				if r.has_point(t.position):
					return
			var b := _button_at(t.position)
			if b != "":
				active_touches[t.index] = "btn:" + b
				held_buttons[b] = true
				pressed_actions[b] = true
			elif mode != Mode.TILT and t.position.x < s.x * 0.45 and t.position.y > s.y * 0.3:
				if mode == Mode.STICK:
					active_touches[t.index] = "stick"
					stick_origin = t.position
					stick_pos = t.position
					stick_value = Vector2.ZERO
				else:
					active_touches[t.index] = "dpad"
					_update_dpad(t.position)
			else:
				active_touches[t.index] = "look"
		else:
			var role: String = active_touches.get(t.index, "")
			if role == "stick":
				stick_value = Vector2.ZERO
			elif role == "dpad":
				dpad_value = Vector2.ZERO
			elif role.begins_with("btn:"):
				held_buttons[role.substr(4)] = false
			active_touches.erase(t.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var role: String = active_touches.get(d.index, "")
		if role == "stick":
			stick_pos = d.position
			var off := (d.position - stick_origin)
			if off.length() > STICK_R:
				stick_origin = d.position - off.normalized() * STICK_R ## floating base follows
				off = off.normalized() * STICK_R
			stick_value = off / STICK_R
			if stick_value.length() < 0.12:
				stick_value = Vector2.ZERO
		elif role == "dpad":
			_update_dpad(d.position)
		elif role == "look":
			look_accum += d.relative
		queue_redraw()


func _update_dpad(p: Vector2) -> void:
	var off := p - stick_home
	if off.length() < 14.0:
		dpad_value = Vector2.ZERO
		return
	if absf(off.x) > absf(off.y) * 0.6 and absf(off.y) > absf(off.x) * 0.6:
		dpad_value = Vector2(signf(off.x), signf(off.y)).normalized() ## diagonal
	elif absf(off.x) > absf(off.y):
		dpad_value = Vector2(signf(off.x), 0)
	else:
		dpad_value = Vector2(0, signf(off.y))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	match mode:
		Mode.STICK:
			var base := stick_origin if active_touches.values().has("stick") else stick_home
			draw_circle(base, STICK_R, Color(1, 1, 1, 0.10))
			draw_arc(base, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
			var knob := base + stick_value * STICK_R
			draw_circle(knob, 26.0, Color(1, 1, 1, 0.35))
		Mode.DPAD:
			var c := stick_home
			var arm := 34.0
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var on := dpad_value.dot(dir) > 0.5
				var center: Vector2 = c + dir * 44.0
				draw_rect(Rect2(center - Vector2(arm, arm) * 0.6, Vector2(arm, arm) * 1.2), Color(1, 1, 1, 0.45 if on else 0.18), true)
			draw_circle(c, 12.0, Color(1, 1, 1, 0.2))
		Mode.TILT:
			draw_string(font, stick_home + Vector2(-60, 0), "TILT TO MOVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.55))
	for id in buttons:
		if not _button_visible(id):
			continue
		var b: Dictionary = buttons[id]
		var r: float = b["r"]
		var down: bool = held_buttons.get(id, false)
		var col: Color = b["color"]
		draw_circle(b["pos"], r, Color(col.r, col.g, col.b, 0.55 if down else 0.28))
		draw_arc(b["pos"], r, 0, TAU, 32, Color(col.r, col.g, col.b, 0.9), 2.5)
		var text: String = act_label if id == "act" else b["label"]
		var fs := 13 if id != "act" else 12
		var lines := text.split("\n")
		for li in lines.size():
			draw_string(font, b["pos"] + Vector2(-r, 5 + (li - (lines.size() - 1) * 0.5) * 15), lines[li], HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(1, 1, 1, 0.95))
		if id == "act" and act_progress > 0.0:
			draw_arc(b["pos"], r + 5, -PI / 2, -PI / 2 + TAU * act_progress, 40, Color("#7dff9c"), 5.0)
