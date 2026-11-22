class_name Hud
extends CanvasLayer
## Health bars, boss bar, timer, subtitles, banners, pause and end screens.
## Everything is laid out with anchors so it works in portrait and landscape.

signal pause_pressed
signal resume_pressed
signal retry_pressed
signal next_pressed
signal menu_pressed
signal controls_cycled

class Bar:
	extends Control
	var value := 1.0
	var shown := 1.0
	var color := Color("#4ade80")

	func _process(delta: float) -> void:
		shown = move_toward(shown, value, delta * 0.9)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6), true)
		var inner := size - Vector2(4, 4)
		if shown > value:
			draw_rect(Rect2(Vector2(2, 2), Vector2(inner.x * shown, inner.y)), Color(1, 1, 1, 0.8), true)
		draw_rect(Rect2(Vector2(2, 2), Vector2(inner.x * value, inner.y)), color, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 1.5)

var root: Control
var player_bar: Bar
var boss_bar: Bar
var boss_label: Label
var timer_label: Label
var dist_label: Label
var subtitle: Label
var banner_title: Label
var banner_sub: Label
var prompt: Label
var score_label: Label
var tov_label: Label
var task_label: Label
var mistakes_label: Label
var pause_btn: Button
var overlay: Control
var sub_tween: Tween
var banner_tween: Tween


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hp_label := _label("YOU", 14)
	_place(hp_label, 0, 0, 18, 8, 120, 20)
	root.add_child(hp_label)
	player_bar = Bar.new()
	_place(player_bar, 0, 0, 18, 30, 190, 16)
	player_bar.color = Color("#4ade80")
	root.add_child(player_bar)

	boss_label = _label("", 16)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(boss_label, 0.5, 0, -160, 54, 320, 22)
	boss_label.visible = false
	root.add_child(boss_label)
	boss_bar = Bar.new()
	_place(boss_bar, 0.5, 0, -160, 80, 320, 18)
	boss_bar.color = Color("#ef4444")
	boss_bar.visible = false
	root.add_child(boss_bar)

	timer_label = _label("", 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(timer_label, 0.5, 0, -80, 2, 160, 36)
	root.add_child(timer_label)

	dist_label = _label("", 14)
	dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(dist_label, 0.5, 0, -80, 38, 160, 20)
	root.add_child(dist_label)

	subtitle = _label("", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(subtitle, 0.5, 0, -210, 108, 420, 60)
	subtitle.modulate.a = 0.0
	root.add_child(subtitle)

	banner_title = _label("", 40)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(banner_title, 0.5, 0.5, -230, -120, 460, 100)
	banner_title.modulate.a = 0.0
	root.add_child(banner_title)
	banner_sub = _label("", 20)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(banner_sub, 0.5, 0.5, -230, -10, 460, 80)
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)

	prompt = _label("", 26)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(prompt, 0.5, 1, -200, -200, 400, 40)
	prompt.visible = false
	root.add_child(prompt)

	score_label = _label("", 18)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(score_label, 1, 0, -230, 60, 218, 26)
	root.add_child(score_label)

	task_label = _label("", 15)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(task_label, 0, 0, 18, 52, 200, 80)
	root.add_child(task_label)

	mistakes_label = _label("", 20)
	mistakes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(mistakes_label, 0.5, 0, -100, 100, 200, 26)
	root.add_child(mistakes_label)

	tov_label = _label("", 20)
	tov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tov_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tov_label.modulate = Color(0.6, 1, 0.7, 0.0)
	_place(tov_label, 0.5, 0, -210, 176, 420, 60)
	root.add_child(tov_label)

	pause_btn = Button.new()
	pause_btn.text = "II"
	_place(pause_btn, 1, 0, -64, 10, 52, 44)
	pause_btn.add_theme_font_size_override("font_size", 22)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_btn)


func _process(_delta: float) -> void:
	if prompt.visible:
		prompt.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 250.0)


## Anchor a control to a point (ax, ay in 0..1 of the screen) with pixel offsets.
func _place(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox + w
	c.offset_top = oy
	c.offset_bottom = oy + h


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------------------------------------------------------------- API

func set_player_health(v: float, mx: float) -> void:
	player_bar.value = clampf(v / mx, 0.0, 1.0)
	player_bar.color = Color("#4ade80") if player_bar.value > 0.35 else Color("#f59e0b")


func show_boss(name: String) -> void:
	boss_label.text = name
	boss_label.visible = true
	boss_bar.visible = true
	boss_bar.value = 1.0
	boss_bar.shown = 1.0


func set_boss_health(v: float, mx: float) -> void:
	boss_bar.value = clampf(v / mx, 0.0, 1.0)


func hide_boss() -> void:
	boss_label.visible = false
	boss_bar.visible = false


func say(who: String, text: String, dur := 3.0) -> void:
	tov_label.modulate.a = 0.0
	subtitle.text = ("%s: " % who if who != "" else "") + text
	if sub_tween:
		sub_tween.kill()
	subtitle.modulate = Color(1, 0.85, 0.85) if who != "" else Color.WHITE
	subtitle.modulate.a = 0.0
	sub_tween = create_tween()
	sub_tween.tween_property(subtitle, "modulate:a", 1.0, 0.2)
	sub_tween.tween_interval(dur)
	sub_tween.tween_property(subtitle, "modulate:a", 0.0, 0.5)


func banner(title: String, sub := "", dur := 2.4) -> void:
	banner_title.text = title
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween().set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 1.0, 0.3)
	banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.3)
	banner_tween.chain().tween_interval(dur)
	banner_tween.chain().set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 0.0, 0.6)
	banner_tween.tween_property(banner_sub, "modulate:a", 0.0, 0.6)


func set_tasks(text: String) -> void:
	task_label.text = text


func set_score(text: String) -> void:
	score_label.text = text


## Two-voice advice: the Yetzer Hara tempts, the Yetzer Tov says what to do.
func advice(bad: String, good: String, dur := 4.0) -> void:
	if sub_tween:
		sub_tween.kill()
	subtitle.text = "Yetzer Hara: " + bad
	subtitle.modulate = Color(1, 0.55, 0.55, 0.0)
	tov_label.text = "Yetzer Tov: " + good
	tov_label.modulate = Color(0.6, 1, 0.7, 0.0)
	sub_tween = create_tween().set_parallel(true)
	sub_tween.tween_property(subtitle, "modulate:a", 1.0, 0.2)
	sub_tween.tween_property(tov_label, "modulate:a", 1.0, 0.2).set_delay(0.4)
	sub_tween.chain().tween_interval(dur)
	sub_tween.chain().set_parallel(true)
	sub_tween.tween_property(subtitle, "modulate:a", 0.0, 0.5)
	sub_tween.tween_property(tov_label, "modulate:a", 0.0, 0.5)


func show_prompt(text: String) -> void:
	prompt.text = text
	prompt.visible = true


func hide_prompt() -> void:
	prompt.visible = false


# ---------------------------------------------------------------- overlays

func _clear_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _overlay_panel(title: String, body: String) -> VBoxContainer:
	_clear_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#12182b")
	sb.border_color = Color("#4ea1ff")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label(title, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if body != "":
		var b := _label(body, 18)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
	return v


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func show_end(title: String, body: String, can_next: bool) -> void:
	var v := _overlay_panel(title, body)
	if can_next:
		_btn(v, "Next level", func(): next_pressed.emit())
	_btn(v, "Play again", func(): retry_pressed.emit())
	_btn(v, "Back to launcher", func(): menu_pressed.emit())


func show_pause(mode_name: String) -> void:
	var v := _overlay_panel("Paused", "")
	_btn(v, "Resume", func(): resume_pressed.emit())
	var cb := _btn(v, "Controls: %s" % mode_name, func(): controls_cycled.emit())
	cb.name = "ControlsBtn"
	_btn(v, "Restart", func(): retry_pressed.emit())
	_btn(v, "Back to launcher", func(): menu_pressed.emit())


func set_controls_text(mode_name: String) -> void:
	if overlay and overlay.find_child("ControlsBtn", true, false):
		(overlay.find_child("ControlsBtn", true, false) as Button).text = "Controls: %s" % mode_name


func close_overlay() -> void:
	_clear_overlay()
