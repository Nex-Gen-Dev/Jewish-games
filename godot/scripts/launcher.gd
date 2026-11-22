class_name Launcher
extends Control
## Home of the app. Responsive: bottom tab bar in portrait, side rail in
## landscape / tablets. Everything scrolls by dragging anywhere. First launch
## shows a sign-in (name, username, email or phone) that creates a user ID.
## Tapping a game opens its own "game hub" page (levels, how to play, options).

const APP_VERSION := "1.3"
const MAX_W := 900.0
const Icon := preload("res://scripts/ui_icon.gd")
const AppLog := preload("res://scripts/applog.gd")
const TeaserScript := preload("res://scripts/teaser.gd")
const BgArt := preload("res://scripts/bg_art.gd")
const MARK: Texture2D = preload("res://assets/brand/mark.png")
const F_DISPLAY: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const F_BODY: Font = preload("res://assets/fonts/Barlow-Medium.ttf")
const F_STRONG: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")

## Palette: neutral near-black surfaces, warm white text, one amber accent.
const BG_TOP := Color("#17181b")
const BG_BOTTOM := Color("#08090a")
const SURF := Color("#16181b")
const SURF2 := Color("#1f2226")
const LINE := Color("#2d3137")
const TEXT := Color("#f4f1ea")
const DIM := Color("#a9a59c")
const FAINT := Color("#6f6c65")
const DEF_ACCENT := Color("#f5b027")
const GOLD := Color("#ffc83d")
const GOOD := Color("#46c98b")
const BAD := Color("#ef5a4c")
const INK := Color("#15110a") ## dark text on accent buttons
## Earlier versions saved these as the user's "theme": treat them as "not customised".
const OLD_THEME := {"accent": "#4ea1ff", "bg_top": "#16264a", "bg_bottom": "#0a0f1f"}

static var resume_hub := "" ## after a level ends, come back to this game's page

var tab := "play"
var wide := false
var accent := DEF_ACCENT
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
var f_spaced: FontVariation
var _sig_last := ""
var _toast_node: Control
var _tap_stamp := -1
var _modal_dismissable := true
var bg_art: Control
# game hub (the "app inside the app" page of one game)
var hub: Control
var hub_game: Dictionary = {}
var hub_tab := "levels"
var hub_body: VBoxContainer
var hub_tabs: Dictionary = {}
var hub_scroll: ScrollContainer
var hub_points: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = F_BODY
	f_spaced = FontVariation.new()
	f_spaced.base_font = F_DISPLAY
	f_spaced.spacing_glyph = 2
	accent = _theme_color("accent", DEF_ACCENT)
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
	_resume_hub.call_deferred()


## A colour from the user's private theme, unless it is still an old default.
func _theme_color(key: String, fallback: Color) -> Color:
	var th: Variant = Profile.data.get("theme", {})
	if not th is Dictionary:
		return fallback
	var raw := str(th.get(key, ""))
	if raw == "" or raw.to_lower() == str(OLD_THEME.get(key, "")):
		return fallback
	return Color(raw)


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
	if hub_points and is_instance_valid(hub_points):
		hub_points.text = str(Profile.points())
	var sg := _sig()
	if sg != _sig_last:
		_sig_last = sg
		accent = _theme_color("accent", DEF_ACCENT)
		if content and is_instance_valid(content) and Profile.has_account():
			_show(tab)


func _on_update_status(text: String) -> void:
	if update_status and is_instance_valid(update_status):
		update_status.text = text
	if tab == "play" and ui and (Updater.ready_to_restart or apk_url != ""):
		_show("play")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_node_or_null("Modal"):
			if _modal_dismissable:
				_close_modal()
		elif hub and is_instance_valid(hub):
			_close_hub()


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
	bg_art = BgArt.new()
	bg_art.top = _theme_color("bg_top", BG_TOP)
	bg_art.bottom = _theme_color("bg_bottom", BG_BOTTOM)
	bg_art.accent = accent
	add_child(bg_art)


# ---------------------------------------------------------------- frame

func _rebuild() -> void:
	var reopen: Dictionary = {}
	if hub and is_instance_valid(hub):
		reopen = hub_game
		_close_hub(false)
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
	if not reopen.is_empty():
		_open_hub(reopen)


func _resume_hub() -> void:
	if resume_hub == "" or not Profile.has_account() or (hub and is_instance_valid(hub)):
		return
	for g in Profile.manifest.get("games", []):
		if str(g["id"]) == resume_hub and _owned(g):
			_open_hub(g)
			return
	resume_hub = ""


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

	# header: title on the left, messages + points on the right
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 18)
	header.add_theme_constant_override("margin_right", 18)
	header.add_theme_constant_override("margin_top", 12)
	header.add_theme_constant_override("margin_bottom", 6)
	main.add_child(header)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	header.add_child(hb)
	if not wide:
		hb.add_child(_logo(32))
	title_label = _title(hb, "Games", 28, TEXT, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_bell_button())
	hb.add_child(_coin_chip(false))

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
		col.add_child(_bottom_nav())


## The brand mark (amber badge with an S).
func _logo(px: float) -> Control:
	var tr := TextureRect.new()
	tr.texture = MARK
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _bell_button() -> Control:
	var bell := PanelContainer.new()
	bell.add_theme_stylebox_override("panel", _box(SURF2, LINE, 8, 1, 8, 10))
	var bstack := Control.new()
	bstack.custom_minimum_size = Vector2(22, 22)
	bell.add_child(bstack)
	bstack.add_child(Icon.new().setup("bell", TEXT, 22))
	bell_badge = Label.new()
	bell_badge.add_theme_font_size_override("font_size", 12)
	bell_badge.add_theme_color_override("font_color", BAD)
	bell_badge.position = Vector2(14, -9)
	bell_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bstack.add_child(bell_badge)
	_tap(bell, _open_inbox)
	_refresh_bell()
	bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bell


func _coin_chip(is_hub: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _box(SURF2, Color(GOLD, 0.55), 8, 1, 6, 12))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 6)
	chip.add_child(cb)
	cb.add_child(Icon.new().setup("coin", GOLD, 18))
	var l := _title(cb, str(Profile.points()), 19, GOLD, true)
	if is_hub:
		hub_points = l
	else:
		points_label = l
	return chip


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


const TABS := [["play", "Games", "pad"], ["shop", "Shop", "shop"], ["settings", "Settings", "gear"]]


func _bottom_nav() -> Control:
	var p := PanelContainer.new()
	var sb := _box(Color("#0e0f11"), LINE, 0, 0, 0, 6)
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	p.add_child(hb)
	for t in TABS:
		hb.add_child(_nav_item(t[0], t[1], t[2], false))
	return p


func _rail() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(190, 0)
	var sb := _box(Color("#0e0f11"), LINE, 0, 0, 18, 12)
	sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 8)
	v.add_child(brand)
	brand.add_child(_logo(38))
	var bw := VBoxContainer.new()
	bw.add_theme_constant_override("separation", -4)
	bw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(bw)
	_title(bw, "SHTICK", 22, TEXT)
	_title(bw, "GAMES", 15, accent)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
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
	panel.custom_minimum_size = Vector2(0, 52)
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, 6, 10))
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if horizontal else 1)
	if not horizontal:
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var ic := Icon.new().setup(icon, DIM, 24)
	if not horizontal:
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := _title(box, text, 16, DIM, true)
	l.text = text.to_upper()
	if not horizontal:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap(panel, func(): _show(id))
	nav_items[id] = {"panel": panel, "icon": ic, "label": l, "horizontal": horizontal}
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
		var nb := _box(Color(accent, 0.12) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, 6, 10)
		if on and not bool(it["horizontal"]):
			nb.border_width_top = 3
			nb.border_color = accent
			nb.set_corner_radius_all(0)
		elif on:
			nb.border_width_left = 3
			nb.border_color = accent
		(it["panel"] as PanelContainer).add_theme_stylebox_override("panel", nb)
	title_label.text = {"play": "SHTICK GAMES", "shop": "SHOP", "settings": "SETTINGS"}.get(which, "")
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
		tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(i * 0.05)
		i += 1


# ---------------------------------------------------------------- building blocks

func _box(fill: Color, border: Color, radius := 10, bw := 1, mv := 12, mh := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	return sb


## Game-style panel: two opposite corners are cut bigger than the others.
func _slant(sb: StyleBoxFlat, big := 16, small := 4) -> StyleBoxFlat:
	sb.corner_radius_top_left = big
	sb.corner_radius_bottom_right = big
	sb.corner_radius_top_right = small
	sb.corner_radius_bottom_left = small
	return sb


func _label(parent: Control, text: String, size := 15, color := TEXT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if size >= 19:
		l.add_theme_font_override("font", F_DISPLAY)
		size = int(size * 1.12)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Headline text in the condensed display font.
func _title(parent: Control, text: String, size := 24, color := TEXT, upper := false) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if upper else text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", F_DISPLAY)
	l.add_theme_font_size_override("font_size", int(size * 1.1))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A flat card. Returns its inner VBox.
func _card(parent: Control, border := LINE, fill := SURF, pad := 14) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(fill, border, 10, 1, pad, pad))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(v)
	return v


## Section heading: small accent bar + spaced condensed caps.
func _section(parent: Control, text: String) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(4, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(bar)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", f_spaced)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l)
	return l


## Make any control tappable while still letting the page scroll when dragged.
## When a tappable control sits inside another one, only the inner one fires.
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
					var fr := Engine.get_process_frames()
					if _tap_stamp == fr:
						return
					_tap_stamp = fr
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
	var fill := col if primary else SURF2
	var border := col.lightened(0.2) if primary else LINE
	if danger and not primary:
		border = Color(BAD, 0.6)
	if not enabled:
		fill = SURF
		border = Color(LINE, 0.6)
	var sb := _box(fill, border, 6, 1, 11, 16)
	if primary and enabled:
		_slant(sb, 14, 4)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 48)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", F_DISPLAY)
	l.add_theme_font_size_override("font_size", 20)
	var tc := INK if (primary and enabled and not danger) else ((BAD if danger else TEXT) if enabled else FAINT)
	if danger and primary and enabled:
		tc = Color.WHITE
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
	p.add_theme_stylebox_override("panel", _box(Color(col, 0.16), Color(col, 0.8), 8, 1, 0, 0))
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", F_DISPLAY)
	l.add_theme_font_size_override("font_size", int(size * 0.55))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	return p


func _bar(parent: Control, frac: float, col: Color, h := 6) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(frac, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", _box(Color("#0b0c0e"), LINE, 3, 1, 0, 0))
	pb.add_theme_stylebox_override("fill", _box(col, col, 3, 0, 0, 0))
	parent.add_child(pb)
	return pb


## Black-to-clear fade laid over pictures so text on top stays readable.
func _scrim(parent: Control, from_bottom := true, strength := 0.85) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, strength if from_bottom else 0.0))
	g.set_color(1, Color(0, 0, 0, 0.0 if from_bottom else strength))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 1) if from_bottom else Vector2(0, 0)
	gt.fill_to = Vector2(0, 0) if from_bottom else Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


func _field(parent: Control, caption: String, placeholder: String, kbd := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	_label(parent, caption, 13, DIM)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.virtual_keyboard_type = kbd
	e.custom_minimum_size = Vector2(0, 46)
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_stylebox_override("normal", _box(Color("#0e0f11"), LINE, 6, 1, 8, 12))
	e.add_theme_stylebox_override("focus", _box(Color("#0e0f11"), accent, 6, 2, 8, 12))
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", FAINT)
	e.add_theme_color_override("caret_color", accent)
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

	# logo block
	var logo_row := HBoxContainer.new()
	logo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_theme_constant_override("separation", 14)
	logo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo_row)
	logo_row.add_child(_logo(84 if not wide else 64))
	var wm := VBoxContainer.new()
	wm.add_theme_constant_override("separation", -8)
	wm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_row.add_child(wm)
	_title(wm, "SHTICK", 48, TEXT)
	_title(wm, "GAMES", 30, accent)
	var rule := ColorRect.new()
	rule.color = accent
	rule.custom_minimum_size = Vector2(56, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rule)
	var sub := _label(col, "Create your account to get your own games, themes and updates.", 15, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var card := _card(col, LINE, SURF, 16)
	card.add_theme_constant_override("separation", 6)
	var name_e := _field(card, "Full name", "Your name")
	var user_e := _field(card, "Username", "letters, numbers, _ or .")
	var mail_e := _field(card, "Email", "name@example.com", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	var phone_e := _field(card, "Phone (or email above)", "+1 555 123 4567", LineEdit.KEYBOARD_TYPE_PHONE)
	var agree := {"on": false}
	var arow := PanelContainer.new()
	arow.add_theme_stylebox_override("panel", _box(Color("#0e0f11"), LINE, 6, 1, 9, 10))
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
	_button(lrow, "Read Terms", func(): _read_legal("terms"), false).custom_minimum_size = Vector2(0, 40)
	_button(lrow, "Read Privacy", func(): _read_legal("privacy"), false).custom_minimum_size = Vector2(0, 40)
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


# ---------------------------------------------------------------- games tab

func _build_play() -> void:
	var nm := str(Profile.data.get("display_name", "friend"))

	# greeting
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	content.add_child(top)
	_badge(top, nm.substr(0, 1).to_upper(), accent, 46)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tcol.add_theme_constant_override("separation", -2)
	top.add_child(tcol)
	_label(tcol, "WELCOME BACK", 13, FAINT)
	_title(tcol, nm, 26, TEXT)

	_update_banner()

	var msg: String = Profile.data.get("message", "")
	if msg != "":
		var b := _card(content, Color(accent, 0.55), Color(accent, 0.08), 12)
		_label(b, msg, 14, TEXT)

	_section(content, "Your games")
	var games: Array = Profile.manifest.get("games", [])
	for game in games:
		_game_card(content, game)


func _update_banner() -> void:
	if Updater.ready_to_restart:
		var v := _card(content, Color(GOOD, 0.7), Color(GOOD, 0.1), 14)
		_title(v, "Update ready", 22, GOOD, true)
		_label(v, "The app will close and open itself again with the new version.", 14, TEXT)
		_button(v, "Restart now", func(): Updater.restart_app())
	elif apk_url != "":
		var v2 := _card(content, Color(GOLD, 0.7), Color(GOLD, 0.1), 14)
		_title(v2, "New app version", 22, GOLD, true)
		_label(v2, "Tap Download, then open the file when it finishes and tap Install. When Android says it's done, tap Open.", 14, TEXT)
		_button(v2, "Download new version", func(): OS.shell_open(apk_url))


func _done_count(game: Dictionary) -> int:
	var n := 0
	for lv in game.get("levels", []):
		if Profile.is_completed(lv["id"]):
			n += 1
	return n


## One game on the home screen: live preview on the left, title, progress and
## the Play button on the right. Tapping anywhere else opens the game's page.
func _game_card(parent: Control, game: Dictionary) -> void:
	var soon: bool = game.get("coming_soon", false)
	var owned: bool = _owned(game) and not soon
	var levels: Array = game.get("levels", [])
	var done := _done_count(game)
	var tw := 320.0 if wide else 138.0
	var th := 190.0 if wide else 172.0

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _slant(_box(SURF, Color(accent, 0.55) if owned else LINE, 6, 1, 0, 0), 20, 5))
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hb)

	var tbox := Control.new()
	tbox.custom_minimum_size = Vector2(tw, th)
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbox.clip_contents = true
	hb.add_child(tbox)
	var poster: String = str(levels[0]["id"]) if not levels.is_empty() else ""
	var tz := TeaserScript.new().setup(str(game["id"]), poster)
	tz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tbox.add_child(tz)
	if not owned:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tbox.add_child(shade)
	var edge := ColorRect.new()
	edge.color = accent if owned else LINE
	edge.anchor_left = 1.0
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.offset_left = -3.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbox.add_child(edge)

	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 14)
	hb.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(v)
	_title(v, str(game.get("subtitle", "")), 14, accent if owned else FAINT, true)
	_label(v, str(game["title"]), 26, TEXT)
	if owned and not levels.is_empty():
		var nxt := _next_level(game)
		var nl := _label(v, "Next: " + _clean_title(nxt), 13, DIM)
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 8)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pr)
		_bar(pr, float(done) / float(levels.size()), accent)
		_label(pr, "%d/%d" % [done, levels.size()], 13, DIM, false)
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(fill)
		var all_done := done >= levels.size()
		var pb := _button(v, "Replay" if all_done else ("Continue" if done > 0 else "Play"), func(): _launch(game, nxt["id"]))
		pb.custom_minimum_size = Vector2(0, 44)
		_tap(card, func(): _open_hub(game))
	elif soon:
		_label(v, "Coming soon", 14, GOLD)
	else:
		_label(v, "Not unlocked for your account", 13, Color("#ff9a6b"))


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


# ---------------------------------------------------------------- game hub
# The page of one game: big preview, Play/Continue, then Levels / How to play /
# Options. It sits on top of the launcher like a small app of its own.

const HUB_TABS := [["levels", "Levels"], ["howto", "How to play"], ["options", "Options"]]


func _open_hub(game: Dictionary) -> void:
	_close_hub(false)
	hub_game = game
	hub_tab = "levels"
	resume_hub = str(game["id"])
	if ui and is_instance_valid(ui):
		ui.visible = false
	hub = Control.new()
	hub.name = "Hub"
	hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hub)
	var m := get_node_or_null("Modal")
	if m:
		move_child(m, -1)
	var bgp := BgArt.new()
	bgp.top = _theme_color("bg_top", BG_TOP)
	bgp.bottom = _theme_color("bg_bottom", BG_BOTTOM)
	bgp.accent = accent
	hub.add_child(bgp)

	var ins := _insets()
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", int(ins.x))
	outer.add_theme_constant_override("margin_right", int(ins.z))
	outer.add_theme_constant_override("margin_top", int(ins.y))
	outer.add_theme_constant_override("margin_bottom", int(ins.w))
	hub.add_child(outer)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	outer.add_child(main)

	# header: back, game name, points
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 14)
	header.add_theme_constant_override("margin_right", 18)
	header.add_theme_constant_override("margin_top", 12)
	header.add_theme_constant_override("margin_bottom", 8)
	main.add_child(header)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	header.add_child(hb)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", _box(SURF2, LINE, 8, 1, 10, 12))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(back)
	back.add_child(Icon.new().setup("back", TEXT, 22))
	_tap(back, func(): _close_hub())
	var ht := _title(hb, str(game["title"]), 26, TEXT, true)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_coin_chip(true))

	var left: VBoxContainer = null
	var right_parent: Control = main
	if wide:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 18)
		main.add_child(row)
		var lm := MarginContainer.new()
		lm.custom_minimum_size = Vector2(minf(size.x * 0.4, 440.0), 0)
		lm.add_theme_constant_override("margin_left", 18)
		lm.add_theme_constant_override("margin_bottom", 18)
		row.add_child(lm)
		left = VBoxContainer.new()
		left.add_theme_constant_override("separation", 12)
		lm.add_child(left)
		right_parent = row

	hub_scroll = ScrollContainer.new()
	hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hub_scroll.scroll_deadzone = 8
	right_parent.add_child(hub_scroll)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_theme_constant_override("margin_top", 6)
	holder.add_theme_constant_override("margin_bottom", 28)
	hub_scroll.add_child(holder)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.mouse_filter = Control.MOUSE_FILTER_PASS
	cv.add_theme_constant_override("separation", 12)
	holder.add_child(cv)
	var sc := hub_scroll
	hub_scroll.resized.connect(func():
		var mg := 18 if wide else int(maxf(18.0, (sc.size.x - MAX_W) / 2.0))
		holder.add_theme_constant_override("margin_left", mg)
		holder.add_theme_constant_override("margin_right", 18 if wide else mg))

	var top_parent: Control = left if left else cv
	_hub_hero(top_parent, game)
	_hub_progress(top_parent, game)
	_hub_play_button(top_parent, game)
	_hub_tabbar(cv)
	hub_body = VBoxContainer.new()
	hub_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_body.mouse_filter = Control.MOUSE_FILTER_PASS
	hub_body.add_theme_constant_override("separation", 10)
	cv.add_child(hub_body)
	_hub_render()
	hub.modulate.a = 0.0
	hub.create_tween().tween_property(hub, "modulate:a", 1.0, 0.18)


func _close_hub(restore := true) -> void:
	if hub and is_instance_valid(hub):
		hub.queue_free()
	hub = null
	hub_body = null
	hub_points = null
	hub_tabs.clear()
	if restore:
		resume_hub = ""
		if ui and is_instance_valid(ui):
			ui.visible = true
			if content and is_instance_valid(content):
				_show(tab) ## progress may have changed while playing


func _hub_hero(parent: Control, game: Dictionary) -> void:
	var levels: Array = game.get("levels", [])
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", _slant(_box(SURF, Color(accent, 0.55), 6, 1, 0, 0), 24, 6))
	hp.clip_contents = true
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hp)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 250.0 if wide else 212.0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(stack)
	var poster: String = str(levels[0]["id"]) if not levels.is_empty() else ""
	var tz := TeaserScript.new().setup(str(game["id"]), poster)
	tz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(tz)
	_scrim(stack, true, 0.92)
	var om := MarginContainer.new()
	om.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	om.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "bottom", "top"]:
		om.add_theme_constant_override("margin_" + s, 16)
	stack.add_child(om)
	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_END
	over.add_theme_constant_override("separation", 0)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	om.add_child(over)
	_title(over, str(game.get("subtitle", "")), 15, accent, true)
	_label(over, str(game["title"]), 40, TEXT)
	_label(over, str(game.get("desc", "")), 14, Color(TEXT, 0.8))


func _hub_progress(parent: Control, game: Dictionary) -> void:
	var levels: Array = game.get("levels", [])
	var done := _done_count(game)
	var c := _card(parent, LINE, SURF, 12)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(hb)
	var big := _title(hb, "%d/%d" % [done, levels.size()], 32, accent)
	big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	_label(v, "LEVELS COMPLETE", 13, DIM)
	_bar(v, float(done) / maxf(float(levels.size()), 1.0), accent, 8)


func _hub_play_button(parent: Control, game: Dictionary) -> void:
	var levels: Array = game.get("levels", [])
	if levels.is_empty():
		return
	var nxt := _next_level(game)
	var done := _done_count(game)
	var verb := "Replay" if done >= levels.size() else ("Continue" if done > 0 else "Play")
	var b := _button(parent, "%s  ·  %s" % [verb, _clean_title(nxt)], func(): _launch(game, nxt["id"], true))
	b.custom_minimum_size = Vector2(0, 56)


func _hub_tabbar(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hb)
	hub_tabs.clear()
	for t in HUB_TABS:
		var id: String = t[0]
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.text = str(t[1]).to_upper()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", F_DISPLAY)
		l.add_theme_font_size_override("font_size", 21)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		hb.add_child(p)
		_tap(p, func():
			hub_tab = id
			_hub_render())
		hub_tabs[id] = {"panel": p, "label": l}


func _hub_style_tabs() -> void:
	for id in hub_tabs:
		var on: bool = id == hub_tab
		var it: Dictionary = hub_tabs[id]
		var sb := _box(Color(0, 0, 0, 0), accent if on else LINE, 0, 0, 10, 6)
		sb.border_width_bottom = 3 if on else 1
		(it["panel"] as PanelContainer).add_theme_stylebox_override("panel", sb)
		(it["label"] as Label).add_theme_color_override("font_color", TEXT if on else FAINT)


func _hub_render() -> void:
	if hub_body == null or not is_instance_valid(hub_body):
		return
	_hub_style_tabs()
	for c in hub_body.get_children():
		hub_body.remove_child(c)
		c.queue_free()
	match hub_tab:
		"howto":
			_hub_howto(hub_body, hub_game)
		"options":
			_hub_options(hub_body, hub_game)
		_:
			_hub_levels(hub_body, hub_game)
	_animate_in(hub_body)


func _hub_levels(parent: Control, game: Dictionary) -> void:
	var levels: Array = game.get("levels", [])
	var nxt := _next_level(game)
	for i in levels.size():
		_level_row(parent, game, i, str(levels[i]["id"]) == str(nxt["id"]))


func _level_row(parent: Control, game: Dictionary, i: int, is_next: bool) -> void:
	var lv: Dictionary = game["levels"][i]
	var ok := _level_ok(game, i)
	var done := Profile.is_completed(lv["id"])
	var col := GOOD if done else (accent if ok else FAINT)
	var p := PanelContainer.new()
	var border := Color(accent, 0.8) if (is_next and ok) else (Color(GOOD, 0.35) if done else LINE)
	p.add_theme_stylebox_override("panel", _slant(_box(SURF if ok else Color("#111214"), border, 6, 1, 0, 0), 14, 4))
	p.clip_contents = true
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)

	# picture of the level (real screenshot from the game)
	var tb := Control.new()
	tb.custom_minimum_size = Vector2(132, 82)
	tb.clip_contents = true
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tb)
	var path := "res://assets/levels/%s.jpg" % str(lv["id"])
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not ok:
			tr.modulate = Color(0.35, 0.35, 0.35)
		tb.add_child(tr)
	else:
		var ph := ColorRect.new()
		ph.color = SURF2
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(ph)
	var num := PanelContainer.new()
	num.add_theme_stylebox_override("panel", _slant(_box(Color(0, 0, 0, 0.72), Color(0, 0, 0, 0), 4, 0, 1, 9), 8, 2))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb.add_child(num)
	_title(num, str(i + 1), 20, col)
	if not ok:
		var lk := Icon.new().setup("lock", TEXT, 26)
		lk.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lk.position = Vector2(132 / 2.0 - 13, 82 / 2.0 - 13)
		tb.add_child(lk)

	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 8)
	mc.add_theme_constant_override("margin_bottom", 8)
	hb.add_child(mc)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(v)
	_label(v, _clean_title(lv), 21, TEXT if ok else DIM)
	var dl := _label(v, str(lv.get("desc", "")), 12, DIM if ok else FAINT)
	dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_right", 12)
	rm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(rm)
	if done:
		var ic := Icon.new().setup("check", GOOD, 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rm.add_child(ic)
	elif ok:
		var ic2 := Icon.new().setup("chev", accent if is_next else DIM, 22)
		ic2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rm.add_child(ic2)
	if ok:
		var id: String = lv["id"]
		_tap(p, func(): _launch(game, id, true))
	else:
		p.mouse_filter = Control.MOUSE_FILTER_PASS


func _hub_howto(parent: Control, game: Dictionary) -> void:
	var pages: Array = game.get("howto", [])
	if pages.is_empty():
		_label(parent, "No guide for this game yet.", 14, DIM)
		return
	for pg in pages:
		var body := str(pg["body"]).replace("{controls}", _controls_text()).replace("{runner_controls}", _runner_controls_text())
		var c := _card(parent, LINE, SURF, 14)
		_title(c, str(pg["title"]), 22, accent, true)
		_label(c, body, 15, TEXT)


func _hub_options(parent: Control, game: Dictionary) -> void:
	var c := _card(parent, LINE, SURF, 14)
	_section(c, "Controls and view")
	match str(game["id"]):
		"fighter":
			_segment(c, "Controls", ["Joystick", "D-pad", "Tilt"], int(Profile.get_setting("controls", 0)), func(i): Profile.set_setting("controls", i), _hub_render)
			_segment(c, "Camera", ["Behind me", "My eyes"], int(Profile.get_setting("camera_view", 0)), func(i): Profile.set_setting("camera_view", i), _hub_render)
			_label(c, "My eyes: first-person, you see through the character's eyes. Drag the right side of the screen to look around.", 12, FAINT)
		"runner":
			_segment(c, "Runner controls", ["Swipe", "Buttons", "Tilt"], int(Profile.get_setting("runner_controls", 0)), func(i): Profile.set_setting("runner_controls", i), _hub_render)
			_label(c, "Swipe on the screen, or show on-screen buttons, or tilt to steer.", 12, FAINT)
		_:
			_label(c, "This game has no special controls to set.", 13, DIM)
	var quals := ["auto", "low", "high"]
	_segment(c, "Graphics", ["Auto", "Smooth", "Best"], maxi(quals.find(str(Profile.get_setting("quality", "auto"))), 0), func(i): Profile.set_setting("quality", quals[i]), _hub_render)
	_label(c, "Smooth keeps tablets cool and fast. Auto picks Smooth on phones.", 12, FAINT)
	_button(c, "Show the how-to-play pop-up again", func(): _howto(game), false)


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
		var v := _card(grid, LINE, SURF, 14)
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




func _row(parent: Control, left: String, right: String, right_col := DIM) -> void:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	var l := _label(hb, left, 14, DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := _label(hb, right, 14, right_col, false)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT



func _segment(parent: Control, caption: String, options: Array, current: int, cb: Callable, refresh := Callable()) -> void:
	_label(parent, caption, 14, TEXT)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hb)
	for i in options.size():
		var on := i == current
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _box(Color(accent, 0.2) if on else Color("#0e0f11"), accent if on else LINE, 6, 1, 10, 6))
		var l := _label(p, str(options[i]), 14, TEXT if on else DIM, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(p)
		var idx := i
		_tap(p, func():
			cb.call(idx)
			if refresh.is_null():
				_show("settings")
			else:
				refresh.call())


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
	update_status = _label(upd, Updater.last_status if Updater.last_status != "" else "Updates install automatically.", 14, accent.lightened(0.2))
	if Updater.ready_to_restart:
		_button(upd, "Restart now", func(): Updater.restart_app())
	elif apk_url != "":
		_button(upd, "Download new version", func(): OS.shell_open(apk_url))
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
	_label(about, "Shtick Games v%s. Games made for you." % APP_VERSION, 13, DIM)


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
func _launch(game: Dictionary, level_id: String, from_hub := false) -> void:
	resume_hub = str(game["id"]) if from_hub else ""
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
	_modal_dismissable = dismissable
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
	var sb := _slant(_box(SURF, Color(accent, 0.6), 6, 1, 18, 18), 20, 6)
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
	p.add_theme_stylebox_override("panel", _slant(_box(SURF2, accent, 6, 1, 10, 14), 14, 4))
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
