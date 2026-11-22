extends Control
## Painted night-sky banner: gradient, twinkling stars, moon, skyline with a
## shul and a golden Star of David. Pure drawing, very cheap.

var top := Color("#1a2a5e")
var bottom := Color("#0b1024")
var glow := Color("#4ea1ff")
var dim := false
var _stars: Array = []
var _bld: Array = []
var _t := 0.0
var _acc := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 70:
		_stars.append([rng.randf(), rng.randf() * 0.7, rng.randf_range(0.8, 2.0), rng.randf() * TAU])
	var x := 0.0
	while x < 1.0:
		var w := rng.randf_range(0.04, 0.09)
		_bld.append([x, w, rng.randf_range(0.12, 0.34), rng.randi()])
		x += w + rng.randf_range(0.0, 0.01)


func _process(delta: float) -> void:
	if dim:
		return
	_acc += delta
	if _acc >= 0.08:
		_t += _acc
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, bottom, bottom]))
	for s in _stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 1.6 + float(s[3])))
		draw_circle(Vector2(float(s[0]) * w, float(s[1]) * h), float(s[2]), Color(1, 1, 1, a * 0.8))
	var moon := Vector2(w * 0.86, h * 0.28)
	var mr := minf(w, h) * 0.12
	draw_circle(moon, mr * 2.4, Color(glow.r, glow.g, glow.b, 0.07))
	draw_circle(moon, mr * 1.6, Color(glow.r, glow.g, glow.b, 0.10))
	draw_circle(moon, mr, Color("#f6efd2"))
	draw_circle(moon + Vector2(mr * .35, -mr * .2), mr * .85, top.lerp(bottom, 0.25))
	var base := h * 0.9
	for b in _bld:
		var bx := float(b[0]) * w
		var bw := float(b[1]) * w
		var bh := float(b[2]) * h
		draw_rect(Rect2(bx, base - bh, bw, bh + 4), Color("#0a0e1c"))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b[3])
		for wy in range(int(bh / 9.0) - 1):
			for wx in range(maxi(int(bw / 9.0) - 1, 0)):
				if rng.randf() < 0.28:
					draw_rect(Rect2(bx + 4 + wx * 9, base - bh + 5 + wy * 9, 4, 5), Color(1, 0.85, 0.45, 0.8))
	# the shul, centre-left
	var cx := w * 0.66
	var sw := minf(w * 0.2, 150.0)
	var sh := h * 0.45
	draw_rect(Rect2(cx - sw / 2, base - sh, sw, sh + 4), Color("#121a33"))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - sw / 2 - 4, base - sh), Vector2(cx, base - sh - sh * 0.42), Vector2(cx + sw / 2 + 4, base - sh)]), Color("#1b2547"))
	var sc := Vector2(cx, base - sh - sh * 0.12)
	var sr := sw * 0.13
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	for i in 3:
		up.append(sc + Vector2.from_angle(-PI / 2 + i * TAU / 3) * sr)
		dn.append(sc + Vector2.from_angle(PI / 2 + i * TAU / 3) * sr)
	up.append(up[0])
	dn.append(dn[0])
	var gold := Color("#ffd34a")
	draw_polyline(up, gold, 1.6, true)
	draw_polyline(dn, gold, 1.6, true)
	for i in 3:
		draw_rect(Rect2(cx - sw * 0.36 + i * sw * 0.27, base - sh * 0.78, sw * 0.14, sh * 0.34), Color(1, 0.82, 0.4, 0.85))
	draw_rect(Rect2(cx - sw * 0.08, base - sh * 0.3, sw * 0.16, sh * 0.3 + 4), Color("#3a2c14"))
	# left scrim so overlaid text stays readable
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.7, 0), Vector2(w * 0.7, h), Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)]))
	# ground fade
	draw_polygon(PackedVector2Array([Vector2(0, base), Vector2(w, base), Vector2(w, h), Vector2(0, h)]), PackedColorArray([Color("#070a16"), Color("#070a16"), bottom, bottom]))
	if dim:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
