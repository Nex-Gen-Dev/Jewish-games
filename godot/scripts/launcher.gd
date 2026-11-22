class_name Launcher
extends Control
## Home of the app. Responsive: bottom tab bar in portrait, side rail in
## landscape / tablets. Everything scrolls by dragging anywhere. First launch
## shows a sign-in (name, username, email or phone) that creates a user ID.

const APP_VERSION := "1.2"
const MAX_W := 900.0
const Icon := preload("res://scripts/ui_icon.gd")
const HeroArt := preload("res://scripts/hero_art.gd")
const AppLog := preload("res://scripts/applog.gd")

const TEXT := Color(1, 1, 1, 0.92)
const DIM := Color(1, 1, 1, 0.6)
const FAINT := Color(1, 1, 1, 0.38)
const GOLD := Color("#ffd34a")
const GOOD := Color("#4ade80")
const BAD := Color("#ff6b6b")

var tab := "play"
var wide := false
var accent := Color("#4ea1ff")
var up: Updater
var apk_url := ""
var ui: Control ## everything except the background; rebuilt on rotation
var scroll: ScrollContainer
var content: VBoxContainer
var title_label: Label
var points_label: Label
var nav_items: Dictionary = {}
var update_status: Label
var cloud: Node
var bell_badge: Label
var _sig_last := ""
var _toast_node: Control



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent = Profile.get_color("theme", "accent", Color("#4ea1ff"))
	_build_background()
	up = Updater.new()
	add_child(up)
	up.status_changed.connect(_on_update_status)
	up.apk_required.connect(func(url: String):
		apk_url = url
		if tab == "play":
			_show("play"))
	if not Updater.checked_this_session:
		up.run()
	Profile.changed.connect(_on_profile_changed)
	resized.connect(_on_resized)
	cloud = get_parent().cloud
	cloud.notifications_changed.connect(_on_notes)
	cloud.legal_changed.connect(_check_terms)
	_sig_last = _sig()
	wide = _is_wide()
	_rebuild()
	_check_terms.call_deferred()
	_maybe_tour.call_deferred()


func _is_wide() -> bool:
	return size.x > size.y * 1.15


func _on_resized() -> void:
	if size.x < 10:
		return
	if _is_wide() != wide:
		wide = _is_wide()
		_rebuild()


func _sig() -> String:
	var d := Profile.data
	return JSON.stringify([d.get("message"), d.get("theme"), d.get("entitlements"), d.get("inventory"), d.get("character")])


func _on_profile_changed() -> void:
	if points_label and is_instance_valid(points_label):
		points_label.text = str(Profile.points())
	var sg := _sig()
	if sg != _sig_last:
		_sig_last = sg
		accent = Profile.get_color("theme", "accent", Color("#4ea1ff"))
		if content and is_instance_valid(content) and Profile.has_account():
			_show(tab)


func _on_update_status(text: String) -> void:
	if update_status and is_instance_valid(update_status):
		update_status.text = text
	if tab == "play" and ui and (Updater.ready_to_restart or apk_url != ""):
		_show("play")


func _insets() -> Vector4:
	if OS.get_name() != "Android":
		return Vector4(0, 0, 0, 0)
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0:
		return Vector4(0, 0, 0, 0)
	var k := size.x / win.x
	var sa := DisplayServer.get_display_safe_area()
	var scr := Vector2(DisplayServer.screen_get_size())
	return Vector4(
		clampf(sa.position.x * k, 0, 70), clampf(sa.position.y * k, 0, 70),
		clampf((scr.x - sa.end.x) * k, 0, 70), clampf((scr.y - sa.end.y) * k, 0, 70))


# ---------------------------------------------------------------- background

func _build_background() -> void:
	var top := Profile.get_color("theme", "bg_top", Color("#16264a"))
	var bottom := Profile.get_color("theme", "bg_bottom", Color("#0a0f1f"))
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# two slow drifting colour glows
	for i in 2:
		var g := Gradient.new()
		g.set_color(0, Color(accent.r, accent.g, accent.b, 0.30 if i == 0 else 0.18))
		g.set_color(1, Color(accent.r, accent.g, accent.b, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		var r := TextureRect.new()
		r.texture = t
		r.custom_minimum_size = Vector2(620, 620)
		r.size = Vector2(620, 620)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(-200 + i * 500, -150 + i * 400)
		add_child(r)
		var tw := create_tween().set_loops()
		tw.tween_property(r, "position", r.position + Vector2(160, 120) * (1 if i == 0 else -1), 9.0 + i * 3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(r, "position", r.position, 9.0 + i * 3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- frame

func _rebuild() -> void:
	if ui and is_instance_valid(ui):
		ui.queue_free()
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	nav_items.clear()
	if not Profile.has_account():
		_build_signin()
		return
	_build_frame()
	_show(tab)


func _build_frame() -> void:
	var ins := _insets()
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", int(ins.x))
	outer.add_theme_constant_override("margin_right", int(ins.z))
	outer.add_theme_constant_override("margin_top", int(ins.y))
	outer.add_theme_constant_override("margin_bottom", int(ins.w))
	ui.add_child(outer)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 0)

	# header: tab title on the left, points on the right
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 18)
	header.add_theme_constant_override("margin_right", 18)
	header.add_theme_constant_override("margin_top", 10)
	header.add_theme_constant_override("margin_bottom", 4)
	main.add_child(header)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	header.add_child(hb)
	if not wide:
		hb.add_child(Icon.new().setup("star", GOLD, 24))
	title_label = _label(hb, "Play", 22, TEXT, false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bell := PanelContainer.new()
	bell.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.18), 18, 1, 7, 9))
	hb.add_child(bell)
	var bstack := Control.new()
	bstack.custom_minimum_size = Vector2(22, 22)
	bell.add_child(bstack)
	bstack.add_child(Icon.new().setup("bell", TEXT, 22))
	bell_badge = Label.new()
	bell_badge.add_theme_font_size_override("font_size", 11)
	bell_badge.add_theme_color_override("font_color", Color.WHITE)
	bell_badge.position = Vector2(14, -8)
	bell_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bstack.add_child(bell_badge)
	_tap(bell, _open_inbox)
	_refresh_bell()
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), Color(GOLD, 0.5), 18, 1, 6, 12))
	hb.add_child(chip)
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 6)
	chip.add_child(cb)
	cb.add_child(Icon.new().setup("coin", GOLD, 18))
	points_label = _label(cb, str(Profile.points()), 16, GOLD, false)

	# scrolling content: drag anywhere
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.follow_focus = true
	main.add_child(scroll)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_theme_constant_override("margin_top", 6)
	holder.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(holder)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 14)
	holder.add_child(content)
	## keep a comfortable reading width on big screens
	scroll.resized.connect(func():
		var m := int(maxf(18.0, (scroll.size.x - MAX_W) / 2.0))
		holder.add_theme_constant_override("margin_left", m)
		holder.add_theme_constant_override("margin_right", m))

	if wide:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		outer.add_child(row)
		row.add_child(_rail())
		row.add_child(main)
	else:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		outer.add_child(col)
		col.add_child(main)
		var vs := Label.new()
		vs.text = "  " + _ver()
		vs.add_theme_font_size_override("font_size", 11)
		vs.add_theme_color_override("font_color", FAINT)
		vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(vs)
		col.add_child(_bottom_nav())


func _ver() -> String:
	var v := "v%s.%d" % [APP_VERSION, Updater.boot_content]
	if Updater.ready_to_restart:
		v += "  ·  update ready, restart"
	return v


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s


const TABS := [["play", "Play", "play"], ["shop", "Shop", "shop"], ["settings", "Settings", "gear"]]


func _bottom_nav() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.03, 0.05, 0.12, 0.92), Color(1, 1, 1, 0.08), 0, 0, 6, 8))
	var hb := HBoxContainer.new()
	p.add_child(hb)
	for t in TABS:
		hb.add_child(_nav_item(t[0], t[1], t[2], false))
	return p


func _rail() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(176, 0)
	p.add_theme_stylebox_override("panel", _box(Color(0.03, 0.05, 0.12, 0.8), Color(1, 1, 1, 0.08), 0, 0, 16, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 8)
	v.add_child(brand)
	brand.add_child(Icon.new().setup("star", GOLD, 26))
	var bl := _label(brand, "Private\nGames", 17, TEXT, false)
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)
	for t in TABS:
		v.add_child(_nav_item(t[0], t[1], t[2], true))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_label(v, _ver(), 12, FAINT, false)
	return p


func _nav_item(id: String, text: String, icon: String, horizontal: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 48)
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 12, 0, 6, 10))
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if horizontal else 2)
	if not horizontal:
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var ic := Icon.new().setup(icon, DIM, 22)
	if not horizontal:
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := _label(box, text, 14 if horizontal else 12, DIM, false)
	if not horizontal:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap(panel, func(): _show(id))
	nav_items[id] = {"panel": panel, "icon": ic, "label": l}
	return panel


func _show(which: String) -> void:
	tab = which
	if content == null or not is_instance_valid(content):
		return
	for id in nav_items:
		var on: bool = id == which
		var it: Dictionary = nav_items[id]
		it["icon"].set_color(accent if on else DIM)
		it["label"].add_theme_color_override("font_color", accent if on else DIM)
		(it["panel"] as PanelContainer).add_theme_stylebox_override("panel", _box(Color(accent, 0.16) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 12, 0, 6, 10))
	title_label.text = {"play": "Play", "shop": "Shop", "settings": "Settings"}.get(which, "")
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	match which:
		"shop":
			_build_shop()
		"settings":
			_build_settings()
		_:
			_build_play()
	scroll.scroll_vertical = 0
	_animate_in(content)


func _animate_in(parent: Control) -> void:
	var i := 0
	for c in parent.get_children():
		if not c is Control:
			continue
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 1.0, 0.28).set_delay(i * 0.055)
		i += 1


# ---------------------------------------------------------------- building blocks

func _box(fill: Color, border: Color, radius := 14, bw := 1, mv := 12, mh := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	return sb


func _label(parent: Control, text: String, size := 15, color := TEXT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A rounded card. Returns its inner VBox.
func _card(parent: Control, border := Color(1, 1, 1, 0.1), fill := Color(1, 1, 1, 0.06), pad := 14) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := _box(fill, border, 16, 1, pad, pad)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(v)
	return v


func _section(parent: Control, text: String) -> Label:
	var l := _label(parent, text.to_upper(), 12, FAINT)
	return l


## Make any control tappable while still letting the page scroll when dragged.
func _tap(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.set_meta("down", Vector2(-9999, -9999))
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			var gp := c.get_global_mouse_position()
			if e.pressed:
				c.set_meta("down", gp)
				_fx(c, true)
			else:
				_fx(c, false)
				var d: Vector2 = c.get_meta("down")
				c.set_meta("down", Vector2(-9999, -9999))
				if d.x > -9000 and d.distance_to(gp) < 14.0:
					cb.call()
		elif e is InputEventMouseMotion:
			var d2: Vector2 = c.get_meta("down")
			if d2.x > -9000 and d2.distance_to(c.get_global_mouse_position()) > 14.0:
				c.set_meta("down", Vector2(-9999, -9999))
				_fx(c, false))
	c.mouse_exited.connect(func(): _fx(c, false))


func _fx(c: Control, down: bool) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2(0.97, 0.97) if down else Vector2.ONE, 0.08 if down else 0.14)


func _button(parent: Control, text: String, cb: Callable, primary := true, enabled := true, danger := false) -> Control:
	var p := PanelContainer.new()
	var col := BAD if danger else accent
	var fill := col if primary else Color(1, 1, 1, 0.08)
	var border := col.lightened(0.25) if primary else Color(1, 1, 1, 0.16)
	if not enabled:
		fill = Color(1, 1, 1, 0.05)
		border = Color(1, 1, 1, 0.08)
	p.add_theme_stylebox_override("panel", _box(fill, border, 12, 1, 12, 16))
	p.custom_minimum_size = Vector2(0, 46)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	var tc := Color(0.04, 0.08, 0.16) if (primary and enabled and not danger) else ((BAD if danger else Color.WHITE) if enabled else FAINT)
	l.add_theme_color_override("font_color", tc)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	parent.add_child(p)
	if enabled:
		_tap(p, cb)
	else:
		p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


func _badge(parent: Control, text: String, col: Color, size := 36) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", _box(Color(col, 0.2), Color(col, 0.7), size / 2, 1, 0, 0))
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	return p


func _field(parent: Control, caption: String, placeholder: String, kbd := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	_label(parent, caption, 13, DIM)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.virtual_keyboard_type = kbd
	e.custom_minimum_size = Vector2(0, 44)
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.16), 10, 1, 8, 12))
	e.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0.45), accent, 10, 2, 8, 12))
	e.add_theme_color_override("font_color", Color.WHITE)
	e.add_theme_color_override("font_placeholder_color", FAINT)
	parent.add_child(e)
	e.focus_entered.connect(func():
		await get_tree().create_timer(0.35).timeout
		if scroll and is_instance_valid(scroll) and is_instance_valid(e):
			scroll.ensure_control_visible(e))
	return e


# ---------------------------------------------------------------- sign-in

func _build_signin() -> void:
	var ins := _insets()
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	ui.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(size.x, maxf(size.y - 2.0, 300.0))
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(center)
	var wrap := MarginContainer.new()
	wrap.custom_minimum_size = Vector2(minf(size.x - 36.0, 440.0), 0)
	wrap.add_theme_constant_override("margin_top", int(ins.y) + 18)
	wrap.add_theme_constant_override("margin_bottom", int(ins.w) + 24)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(wrap)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(col)

	var hero := HeroArt.new()
	hero.custom_minimum_size = Vector2(0, 120 if not wide else 100)
	hero.top = Color("#1a2a5e")
	hero.glow = accent
	col.add_child(hero)
	var t := _label(col, "Welcome", 28, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(col, "Create your account to get your own games, themes and updates.", 14, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var card := _card(col, Color(1, 1, 1, 0.12), Color(0, 0, 0, 0.35), 16)
	card.add_theme_constant_override("separation", 6)
	var name_e := _field(card, "Full name", "Your name")
	var user_e := _field(card, "Username", "letters, numbers, _ or .")
	var mail_e := _field(card, "Email", "name@example.com", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	var phone_e := _field(card, "Phone (or email above)", "+1 555 123 4567", LineEdit.KEYBOARD_TYPE_PHONE)
	var agree := {"on": false}
	var arow := PanelContainer.new()
	arow.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.14), 10, 1, 9, 10))
	card.add_child(arow)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 10)
	ah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arow.add_child(ah)
	var tick := Icon.new().setup("check", Color(1, 1, 1, 0.15), 22)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(tick)
	_label(ah, "I am 13 or older and I agree to the Terms of Use and Privacy Policy.", 13, TEXT)
	_tap(arow, func():
		agree["on"] = not agree["on"]
		tick.set_color(accent if agree["on"] else Color(1, 1, 1, 0.15)))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	card.add_child(lrow)
	_button(lrow, "Read Terms", func(): _read_legal("terms"), false).custom_minimum_size = Vector2(0, 38)
	_button(lrow, "Read Privacy", func(): _read_legal("privacy"), false).custom_minimum_size = Vector2(0, 38)
	var err := _label(card, "", 13, BAD)
	_button(card, "Create account", func():
		if not agree["on"]:
			err.text = "Please agree to the Terms and Privacy Policy to continue."
			return
		var msg := Profile.create_account(name_e.text, user_e.text, mail_e.text, phone_e.text)
		if msg != "":
			err.text = msg
			return
		Profile.apply_update({"account": {"terms_version": int(cloud.current_legal().get("version", 1)), "terms_at": int(Time.get_unix_time_from_system()), "terms_sent": false}})
		AppLog.add("Account created")
		tab = "play"
		_rebuild()
		_maybe_tour.call_deferred())
	var note := _label(col, "Your details are used only to give you your own content and updates.", 12, FAINT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_animate_in(col)


# ---------------------------------------------------------------- play tab

func _build_play() -> void:
	var acct := Profile.account()
	var nm := str(Profile.data.get("display_name", "friend"))

	# greeting + stats
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	content.add_child(top)
	_badge(top, nm.substr(0, 1).to_upper(), accent, 46)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tcol.add_theme_constant_override("separation", 0)
	top.add_child(tcol)
	_label(tcol, "Welcome back", 13, DIM)
	_label(tcol, nm, 21, Color.WHITE)

	_update_banner()

	var msg: String = Profile.data.get("message", "")
	if msg != "":
		var b := _card(content, Color(accent, 0.6), Color(accent, 0.14), 12)
		_label(b, msg, 14, TEXT)

	var games: Array = Profile.manifest.get("games", [])
	for game in games:
		_game_block(game)


func _update_banner() -> void:
	if Updater.ready_to_restart:
		var v := _card(content, Color(GOOD, 0.7), Color(GOOD, 0.14), 12)
		_label(v, "An update was downloaded. Close the app and open it again to use it.", 14, TEXT)
		_button(v, "Close app now", func(): get_tree().quit(), true, true)
	elif apk_url != "":
		var v2 := _card(content, Color(GOLD, 0.7), Color(GOLD, 0.12), 12)
		_label(v2, "A new version of the app is ready to install.", 14, TEXT)
		_button(v2, "Download new version", func(): OS.shell_open(apk_url))


func _game_block(game: Dictionary) -> void:
	var soon: bool = game.get("coming_soon", false)
	var owned: bool = _owned(game) and not soon
	var levels: Array = game.get("levels", [])

	# hero banner
	var hero_h := 190.0 if wide else 170.0
	var hp := PanelContainer.new()
	var sbh := _box(Color(0, 0, 0, 0), Color(accent, 0.55) if owned else Color(1, 1, 1, 0.12), 18, 1, 0, 0)
	sbh.shadow_color = Color(0, 0, 0, 0.4)
	sbh.shadow_size = 8
	hp.add_theme_stylebox_override("panel", sbh)
	hp.clip_contents = true
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(hp)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, hero_h if owned else 110.0)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	hp.add_child(stack)
	var art := HeroArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.glow = accent
	art.dim = not owned
	stack.add_child(art)
	var over := VBoxContainer.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.alignment = BoxContainer.ALIGNMENT_END
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_theme_constant_override("separation", 2)
	var om := MarginContainer.new()
	om.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	om.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "bottom", "top"]:
		om.add_theme_constant_override("margin_" + s, 14)
	stack.add_child(om)
	om.add_child(over)
	_label(over, str(game.get("subtitle", "")).to_upper(), 12, accent.lightened(0.3))
	_label(over, str(game["title"]), 30 if owned else 24, Color.WHITE)
	if owned:
		var d := _label(over, str(game.get("desc", "")), 13, DIM)
		d.custom_minimum_size = Vector2(200, 0)
		var go := HBoxContainer.new()
		go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.add_child(go)
		var nxt := _next_level(game)
		var lv_title := _clean_title(nxt)
		var pb := _button(go, "Play  ·  " + lv_title, func(): _launch(game, nxt["id"]))
		pb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pb.custom_minimum_size = Vector2(0, 42)
	elif soon:
		_label(over, "Coming soon", 14, GOLD)
	else:
		_label(over, "Not unlocked for your account", 13, Color(1, 0.6, 0.4))
	if not owned:
		return

	# levels
	var done := 0
	for lv in levels:
		if Profile.is_completed(lv["id"]):
			done += 1
	var hdr := HBoxContainer.new()
	content.add_child(hdr)
	var sh := _section(hdr, "Levels")
	sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(hdr, "%d / %d done" % [done, levels.size()], 12, DIM, false).size_flags_horizontal = Control.SIZE_SHRINK_END
	var grid := GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(grid)
	for i in levels.size():
		_level_tile(grid, game, i)


func _next_level(game: Dictionary) -> Dictionary:
	var levels: Array = game["levels"]
	for i in levels.size():
		if _level_ok(game, i) and not Profile.is_completed(levels[i]["id"]):
			return levels[i]
	return levels[0]


func _clean_title(lv: Dictionary) -> String:
	var t := str(lv["title"])
	var parts := t.split(" · ")
	return parts[1] if parts.size() > 1 else t


func _level_tile(parent: Control, game: Dictionary, i: int) -> void:
	var lv: Dictionary = game["levels"][i]
	var ok := _level_ok(game, i)
	var done := Profile.is_completed(lv["id"])
	var p := PanelContainer.new()
	var col := GOOD if done else (accent if ok else FAINT)
	p.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.06 if ok else 0.03), Color(col, 0.45 if ok else 0.18), 14, 1, 10, 12))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	_badge(hb, str(i + 1), col, 38)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	_label(v, _clean_title(lv), 16, TEXT if ok else DIM)
	_label(v, str(lv.get("desc", "")), 12, DIM if ok else FAINT)
	var kind := "check" if done else ("chev" if ok else "lock")
	var ic := Icon.new().setup(kind, col, 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	if ok:
		var id: String = lv["id"]
		_tap(p, func(): _launch(game, id))
	else:
		p.mouse_filter = Control.MOUSE_FILTER_PASS


# ---------------------------------------------------------------- shop tab

func _build_shop() -> void:
	var tip := _card(content, Color(GOLD, 0.5), Color(GOLD, 0.1), 12)
	_label(tip, "Defeat Yetzer Hara's helpers to earn points. Several in a row quickly builds a combo up to x5. Praying, tefillin and davening in peace earn points too.", 13, TEXT)
	var grid := GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(grid)
	for item in Profile.manifest.get("shop", []):
		var v := _card(grid, Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.06), 14)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(hb)
		var nm := _label(hb, str(item["name"]), 18, Color.WHITE)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(Icon.new().setup("coin", GOLD, 16))
		_label(hb, str(item["cost"]), 16, GOLD, false)
		_label(v, str(item["desc"]), 13, DIM)
		var owned := Profile.owns(item["id"])
		var req: String = item.get("requires", "")
		var blocked := req != "" and not Profile.owns(req)
		var cost: int = item["cost"]
		var affordable := Profile.points() >= cost
		var label := "Owned"
		if not owned:
			label = ("Needs %s first" % req) if blocked else ("Buy" if affordable else "Need %d more points" % (cost - Profile.points()))
		var can := not owned and not blocked and affordable
		_button(v, label, func():
			if Profile.buy(item):
				_show("shop"), can, can)


# ---------------------------------------------------------------- settings tab

func _row(parent: Control, left: String, right: String, right_col := DIM) -> void:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	var l := _label(hb, left, 14, DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := _label(hb, right, 14, right_col, false)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _segment(parent: Control, caption: String, options: Array, current: int, cb: Callable) -> void:
	_label(parent, caption, 14, TEXT)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hb)
	for i in options.size():
		var on := i == current
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _box(Color(accent, 0.25) if on else Color(1, 1, 1, 0.05), accent if on else Color(1, 1, 1, 0.14), 10, 1, 10, 6))
		var l := _label(p, str(options[i]), 14, Color.WHITE if on else DIM, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(p)
		var idx := i
		_tap(p, func():
			cb.call(idx)
			_show("settings"))


func _build_settings() -> void:
	var a := Profile.account()
	var prof := _card(content)
	_section(prof, "Account")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prof.add_child(top)
	_badge(top, str(a.get("name", "?")).substr(0, 1).to_upper(), accent, 44)
	var tv := VBoxContainer.new()
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	_label(tv, str(a.get("name", "")), 18, Color.WHITE)
	_label(tv, "@" + str(a.get("username", "")), 13, DIM)
	_row(prof, "Your ID", str(a.get("user_id", "")), accent.lightened(0.3))
	if str(a.get("email", "")) != "":
		_row(prof, "Email", str(a["email"]))
	if str(a.get("phone", "")) != "":
		_row(prof, "Phone", str(a["phone"]))

	var game := _card(content)
	_section(game, "Game")
	_segment(game, "Controls", ["Joystick", "D-pad", "Tilt"], int(Profile.get_setting("controls", 0)), func(i): Profile.set_setting("controls", i))
	_segment(game, "Camera (Rise & Shine)", ["Behind me", "My eyes"], int(Profile.get_setting("camera_view", 0)), func(i): Profile.set_setting("camera_view", i))
	_label(game, "My eyes: first-person, you see through the character's eyes. Drag the right side of the screen to look around.", 12, FAINT)
	_segment(game, "Runner controls", ["Swipe", "Buttons", "Tilt"], int(Profile.get_setting("runner_controls", 0)), func(i): Profile.set_setting("runner_controls", i))
	_label(game, "Street Runner: swipe on the screen, or show on-screen buttons, or tilt to steer.", 12, FAINT)
	var quals := ["auto", "low", "high"]
	_segment(game, "Graphics", ["Auto", "Smooth", "Best"], maxi(quals.find(str(Profile.get_setting("quality", "auto"))), 0), func(i): Profile.set_setting("quality", quals[i]))
	_label(game, "Smooth keeps tablets cool and fast. Auto picks Smooth on phones.", 12, FAINT)

	var upd := _card(content)
	_section(upd, "App updates")
	update_status = _label(upd, Updater.last_status if Updater.last_status != "" else "Updates install automatically.", 14, Color("#9ad1ff"))
	_button(upd, "Check for updates", func():
		up.run(), false)
	_label(upd, "Version %s  ·  app build %d" % [_ver().trim_prefix("v"), Updater.BINARY_VERSION], 12, FAINT)

	var nt := _card(content)
	_section(nt, "Notifications")
	_segment(nt, "Alerts inside the app", ["On", "Off"], 0 if bool(Profile.get_setting("alerts", true)) else 1, func(i): Profile.set_setting("alerts", i == 0))
	_label(nt, "How it works: when we send news, an update or a message, the app checks every few seconds while it is open and when you come back to it. A banner slides in at the top and the bell shows a number. Alerts that reach your phone while the app is closed are not available yet.", 12, FAINT)
	_button(nt, "Show a test alert", func(): _toast("Test alert", "This is how messages from us will look."), false)
	_button(nt, "Open messages", _open_inbox, false)

	var hp := _card(content)
	_section(hp, "Help and support")
	for g in Profile.manifest.get("games", []):
		if g.has("howto"):
			var gg: Dictionary = g
			_button(hp, "How to play: " + str(g["title"]), func(): _howto(gg), false)
	_button(hp, "Replay the app tour", func(): _pages_modal("Quick tour", Profile.manifest.get("tour", []), Callable()), false)
	_button(hp, "Report a problem", _report_dialog, true)
	_button(hp, "Terms of Use", func(): _read_legal("terms"), false)
	_button(hp, "Privacy Policy", func(): _read_legal("privacy"), false)

	var prog := _card(content)
	_section(prog, "Progress")
	_row(prog, "Points", str(Profile.points()), GOLD)
	_button(prog, "Reset progress, points and items", func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "Reset all progress, points and purchased items?"
		dlg.confirmed.connect(func():
			Profile.apply_update({"progress": {"completed": [], "points": 0}, "inventory": []})
			_show("settings"))
		add_child(dlg)
		dlg.popup_centered(Vector2i(380, 150)), false, true, true)

	var about := _card(content)
	_section(about, "About")
	_label(about, "Private Games v%s. A private launcher with games made for you." % APP_VERSION, 13, DIM)


# ---------------------------------------------------------------- game access

func _owned(game: Dictionary) -> bool:
	return bool(game.get("free", false)) or Profile.has_entitlement(game["id"])


func _level_ok(game: Dictionary, i: int) -> bool:
	if game.get("coming_soon", false) or not _owned(game):
		return false
	var lv: Dictionary = game["levels"][i]
	if lv.get("coming_soon", false):
		return false
	if Profile.data.get("dev_unlock_all", false) or i == 0:
		return true
	return Profile.is_completed(game["levels"][i - 1]["id"])


## Start a level; the first time for a game, show its instructions first.
func _launch(game: Dictionary, level_id: String) -> void:
	var seen: Dictionary = Profile.data.get("onboarded", {})
	if game.has("howto") and not bool(seen.get(game["id"], false)):
		_howto(game, func():
			Profile.apply_update({"onboarded": {game["id"]: true}})
			get_parent().start_level(level_id))
	else:
		get_parent().start_level(level_id)


# ---------------------------------------------------------------- modal helper

func _close_modal() -> void:
	var m := get_node_or_null("Modal")
	if m:
		m.name = "ModalOld"
		m.queue_free()


## Returns {"body": VBox (scrolls), "foot": VBox (buttons)}.
func _modal(title: String, dismissable := true) -> Dictionary:
	_close_modal()
	var ov := Control.new()
	ov.name = "Modal"
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	if dismissable:
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				_close_modal())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var panel := PanelContainer.new()
	var sb := _box(Color("#0f1738"), Color(accent, 0.7), 20, 1, 18, 18)
	sb.shadow_size = 14
	sb.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(minf(size.x - 28.0, 560.0), 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_label(v, title, 21, Color.WHITE)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 8
	var max_h := minf(size.y * 0.55, 480.0)
	sc.custom_minimum_size = Vector2(0, 40)
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.minimum_size_changed.connect(func():
		if is_instance_valid(sc) and is_instance_valid(body):
			sc.custom_minimum_size.y = clampf(body.get_combined_minimum_size().y, 40.0, max_h))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(body)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	ov.modulate.a = 0.0
	ov.create_tween().tween_property(ov, "modulate:a", 1.0, 0.18)
	return {"body": body, "foot": foot}


# ---------------------------------------------------------------- terms

func _legal_text(kind: String) -> String:
	var l: Dictionary = cloud.current_legal()
	return str(l.get(kind, ""))


func _read_legal(kind: String, back: Callable = Callable()) -> void:
	var m := _modal("Terms of Use" if kind == "terms" else "Privacy Policy", back.is_null())
	_label(m["body"], _legal_text(kind), 14, TEXT)
	_button(m["foot"], "Close" if back.is_null() else "Back", func():
		if back.is_null():
			_close_modal()
		else:
			back.call())


func _check_terms() -> void:
	if not Profile.has_account() or not cloud.needs_terms():
		return
	_terms_gate()


func _terms_gate() -> void:
	var m := _modal("Terms & Privacy updated", false)
	_label(m["body"], "We updated our Terms of Use and Privacy Policy (version %d). Please read them and accept to keep using the app." % int(cloud.current_legal().get("version", 1)), 15, TEXT)
	_button(m["foot"], "Read Terms of Use", func(): _read_legal("terms", _terms_gate), false)
	_button(m["foot"], "Read Privacy Policy", func(): _read_legal("privacy", _terms_gate), false)
	_button(m["foot"], "I agree and continue", func():
		cloud.accept_terms()
		_close_modal())


# ---------------------------------------------------------------- notifications

func _refresh_bell() -> void:
	if bell_badge == null or not is_instance_valid(bell_badge) or cloud == null:
		return
	var n: int = cloud.unread()
	bell_badge.text = str(mini(n, 9)) + ("+" if n > 9 else "") if n > 0 else ""
	bell_badge.add_theme_color_override("font_color", Color("#ff6b6b"))


func _on_notes() -> void:
	_refresh_bell()
	if cloud.new_since_last_toast.is_empty():
		return
	var last: Dictionary = cloud.new_since_last_toast[-1]
	cloud.new_since_last_toast.clear()
	if cloud.alerts_enabled():
		_toast(str(last.get("title", "")), str(last.get("body", "")))


func _toast(title: String, body: String) -> void:
	if _toast_node and is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color("#16225a"), accent, 16, 1, 10, 14))
	p.custom_minimum_size = Vector2(minf(size.x - 32.0, 460.0), 0)
	p.position = Vector2((size.x - minf(size.x - 32.0, 460.0)) / 2.0, -120)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	_label(v, title, 16, Color.WHITE)
	if body != "":
		_label(v, body, 13, DIM)
	add_child(p)
	_toast_node = p
	_tap(p, func():
		p.queue_free()
		_open_inbox())
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", 14.0 + _insets().y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(5.0)
	tw.tween_property(p, "position:y", -140.0, 0.3)
	tw.tween_callback(p.queue_free)


func _open_inbox() -> void:
	var m := _modal("Messages")
	var items: Array = cloud.inbox.duplicate()
	items.reverse()
	if items.is_empty():
		_label(m["body"], "No messages yet. News and updates from us will show up here.", 14, DIM)
	for it in items:
		var c := _card(m["body"], Color(accent, 0.5) if not bool(it.get("read", false)) else Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.05), 10)
		_label(c, str(it.get("title", "")), 16, Color.WHITE)
		if str(it.get("body", "")) != "":
			_label(c, str(it["body"]), 13, DIM)
		_label(c, _ago(int(it.get("created_at", 0))), 11, FAINT)
	_button(m["foot"], "Close", _close_modal, false)
	cloud.mark_all_read()
	_refresh_bell()


func _ago(ms: int) -> String:
	if ms <= 0:
		return ""
	var s := int(Time.get_unix_time_from_system()) - ms / 1000
	if s < 90:
		return "just now"
	if s < 3600:
		return "%d min ago" % (s / 60)
	if s < 86400:
		return "%d h ago" % (s / 3600)
	return "%d days ago" % (s / 86400)


# ---------------------------------------------------------------- how to play

func _controls_text() -> String:
	var mode := int(Profile.get_setting("controls", 0))
	var move: String = ["Left side: drag the round joystick to walk in any direction.",
		"Left side: use the arrow pad to walk.",
		"Tilt your device to walk. The arrow keys also work on a computer."][mode]
	return move + "\nRight side buttons: PUNCH (fast), KICK (strong), JUMP, DODGE (roll away from danger). After you buy the blaster, a SHOOT button appears. An ACT button shows up when you can do something (pick up tefillin, sit, pray with the Yetzer Tov). You can change the control style in Settings > Game.\nPause with the pause button at the top."


func _runner_controls_text() -> String:
	var mode := int(Profile.get_setting("runner_controls", 0))
	var head: String = ["Swipe left or right to change lane. Swipe up to jump. Swipe down to slide.",
		"On-screen buttons: left and right arrows to change lane, ^ to jump, v to slide.",
		"Tilt your device left or right to change lane. Swipe up to jump and down to slide."][mode]
	return head + "\nJump high to land on top of cars and crates! You can change this in Settings > Game > Runner controls, or from the pause menu."


func _howto(game: Dictionary, then: Callable = Callable()) -> void:
	var pages: Array = game.get("howto", [])
	if pages.is_empty():
		if not then.is_null():
			then.call()
		return
	_pages_modal("How to play: " + str(game["title"]), pages, then)


func _pages_modal(title: String, pages: Array, then: Callable, i := 0) -> void:
	var pg: Dictionary = pages[i]
	var body := str(pg["body"]).replace("{controls}", _controls_text()).replace("{runner_controls}", _runner_controls_text())
	var m := _modal(title, false)
	var c := _card(m["body"], Color(accent, 0.5), Color(accent, 0.1), 14)
	_label(c, "%d / %d" % [i + 1, pages.size()], 12, accent.lightened(0.3))
	_label(c, str(pg["title"]), 22, Color.WHITE)
	_label(c, body, 15, TEXT)
	var last := i == pages.size() - 1
	_button(m["foot"], "Got it" if last else "Next", func():
		if last:
			_close_modal()
			if not then.is_null():
				then.call()
		else:
			_pages_modal(title, pages, then, i + 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	m["foot"].add_child(row)
	if i > 0:
		_button(row, "Back", func(): _pages_modal(title, pages, then, i - 1), false)
	if not last:
		_button(row, "Skip", func():
			_close_modal()
			if not then.is_null():
				then.call(), false)


func _maybe_tour() -> void:
	if not Profile.has_account():
		return
	var seen: Dictionary = Profile.data.get("onboarded", {})
	if bool(seen.get("app", false)) or get_node_or_null("Modal"):
		return
	_pages_modal("Quick tour", Profile.manifest.get("tour", []), func(): Profile.apply_update({"onboarded": {"app": true}}))


# ---------------------------------------------------------------- report a problem

func _report_dialog() -> void:
	var m := _modal("Report a problem")
	_label(m["body"], "Tell us what went wrong. We also send technical details about your app so we can find the cause.", 14, DIM)
	var te := TextEdit.new()
	te.placeholder_text = "What happened? What were you doing?"
	te.custom_minimum_size = Vector2(0, 120)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 15)
	te.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.16), 10, 1, 8, 10))
	te.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0.45), accent, 10, 2, 8, 10))
	m["body"].add_child(te)
	var logs := {"on": true}
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.14), 10, 1, 10, 12))
	m["body"].add_child(row)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	var tick := Icon.new().setup("check", accent, 20)
	hb.add_child(tick)
	var tl := _label(hb, "Include technical logs (recommended)", 14, TEXT)
	_tap(row, func():
		logs["on"] = not logs["on"]
		tick.set_color(accent if logs["on"] else Color(1, 1, 1, 0.15)))
	var st := _label(m["body"], "", 13, GOOD)
	if cloud.pending_reports() > 0:
		st.text = "%d earlier report(s) waiting to be sent." % cloud.pending_reports()
	_button(m["foot"], "Send report", func():
		var txt := te.text.strip_edges()
		if txt == "":
			st.text = "Please describe the problem first."
			st.add_theme_color_override("font_color", BAD)
			return
		cloud.send_report("bug", txt, logs["on"])
		_close_modal()
		var d := _modal("Thank you")
		_label(d["body"], "Your report was sent." if cloud.has_server() else "Saved. It will be sent automatically as soon as the app can reach our server.", 15, TEXT)
		_button(d["foot"], "OK", _close_modal))
	_button(m["foot"], "Cancel", _close_modal, false)
